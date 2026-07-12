import CoreML
import CoreVideo
import Foundation
import ImageIO
import Vision

enum VisionDetectorReadiness: Equatable, Sendable {
    case notPrepared
    case loading
    case ready(ModelMetadata)
    case unavailable(VisionError)
}

struct ObjectDetectionResult: Equatable, Sendable {
    let observations: [ObjectObservation]
    let latency: TimeInterval
    let capturedAt: Date
}

/// Model-agnostic object detector boundary used by the pipeline and deterministic tests.
protocol VisionDetecting: AnyObject {
    var readiness: VisionDetectorReadiness { get }
    var metadata: ModelMetadata? { get }

    func prepare(completion: @escaping (Result<ModelMetadata, VisionError>) -> Void)
    func detectObjects(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        requestedClassIdentifier: String?,
        completion: @escaping (Result<ObjectDetectionResult, VisionError>) -> Void
    )
    func detectObjects(
        in image: CGImage,
        orientation: CGImagePropertyOrientation,
        requestedClassIdentifier: String?,
        completion: @escaping (Result<ObjectDetectionResult, VisionError>) -> Void
    )
    func cancelAll()
}

struct ObjectDetectionConfiguration: Equatable, Sendable {
    var minimumConfidence: Double
    var duplicateIntersectionOverUnion: Double
    var computeUnits: MLComputeUnits

    init(
        minimumConfidence: Double = 0.20,
        duplicateIntersectionOverUnion: Double = 0.50,
        computeUnits: MLComputeUnits = .all
    ) {
        self.minimumConfidence = min(max(minimumConfidence, 0), 1)
        self.duplicateIntersectionOverUnion = min(max(duplicateIntersectionOverUnion, 0), 1)
        self.computeUnits = computeUnits
    }

    static func == (lhs: ObjectDetectionConfiguration, rhs: ObjectDetectionConfiguration) -> Bool {
        lhs.minimumConfidence == rhs.minimumConfidence &&
            lhs.duplicateIntersectionOverUnion == rhs.duplicateIntersectionOverUnion &&
            lhs.computeUnits.rawValue == rhs.computeUnits.rawValue
    }
}

final class ObjectDetectionService: VisionDetecting, @unchecked Sendable {
    private enum PinnedContract {
        static let schemaVersion = 1
        static let modelID = "jarvis-object-detector-yolov3-tiny-int8lut"
        static let bundleResourceName = "JarvisObjectDetector"
        static let compiledResourceName = "JarvisObjectDetector.mlmodelc"
        static let sourceArtifactName = "JarvisObjectDetector.mlmodel"
        static let sourceSHA256 = "cde8af2528d6eca1d1580fdd0f0147cb6613d40ba962656b5f683c65f571870e"
        static let sourceSize = 8_913_366
        static let imageInputName = "image"
        static let imageWidth = 416
        static let imageHeight = 416
        static let iouInputName = "iouThreshold"
        static let confidenceInputName = "confidenceThreshold"
        static let confidenceOutputName = "confidence"
        static let coordinatesOutputName = "coordinates"
        static let classCount = 80
    }

    private enum DetectionInput {
        case pixelBuffer(CVPixelBuffer)
        case image(CGImage)
    }

    let configuration: ObjectDetectionConfiguration

    private let bundle: Bundle
    private let diagnostics: VisionDiagnosticsStore
    private let stateQueue = DispatchQueue(label: "com.amrik.jarvisxr.vision.detector.state")
    private let workQueue = DispatchQueue(label: "com.amrik.jarvisxr.vision.detector.work", qos: .userInitiated)
    private var state: VisionDetectorReadiness = .notPrepared
    private var loadingCompletions: [(Result<ModelMetadata, VisionError>) -> Void] = []
    private var visionModel: VNCoreMLModel?
    private var currentRequest: VNCoreMLRequest?
    private var cancellationGeneration: UInt64 = 0

    init(
        bundle: Bundle = .main,
        configuration: ObjectDetectionConfiguration = ObjectDetectionConfiguration(),
        diagnostics: VisionDiagnosticsStore = .shared
    ) {
        self.bundle = bundle
        self.configuration = configuration
        self.diagnostics = diagnostics
    }

    var readiness: VisionDetectorReadiness {
        stateQueue.sync { state }
    }

    var metadata: ModelMetadata? {
        stateQueue.sync {
            guard case .ready(let metadata) = state else { return nil }
            return metadata
        }
    }

    func prepare(completion: @escaping (Result<ModelMetadata, VisionError>) -> Void) {
        var shouldLoad = false
        var immediateResult: Result<ModelMetadata, VisionError>?
        stateQueue.sync {
            switch state {
            case .ready(let metadata):
                immediateResult = .success(metadata)
            case .unavailable(let error):
                immediateResult = .failure(error)
            case .loading:
                loadingCompletions.append(completion)
            case .notPrepared:
                state = .loading
                loadingCompletions.append(completion)
                shouldLoad = true
            }
        }

        if let immediateResult {
            completion(immediateResult)
            return
        }

        guard shouldLoad else { return }
        workQueue.async { [weak self] in
            self?.loadModel()
        }
    }

    func detectObjects(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        requestedClassIdentifier: String? = nil,
        completion: @escaping (Result<ObjectDetectionResult, VisionError>) -> Void
    ) {
        detect(
            input: .pixelBuffer(pixelBuffer),
            orientation: orientation,
            requestedClassIdentifier: requestedClassIdentifier,
            completion: completion
        )
    }

    func detectObjects(
        in image: CGImage,
        orientation: CGImagePropertyOrientation,
        requestedClassIdentifier: String? = nil,
        completion: @escaping (Result<ObjectDetectionResult, VisionError>) -> Void
    ) {
        detect(
            input: .image(image),
            orientation: orientation,
            requestedClassIdentifier: requestedClassIdentifier,
            completion: completion
        )
    }

    func cancelAll() {
        stateQueue.sync {
            cancellationGeneration &+= 1
            currentRequest?.cancel()
            currentRequest = nil
        }
    }

    private func detect(
        input: DetectionInput,
        orientation: CGImagePropertyOrientation,
        requestedClassIdentifier: String?,
        completion: @escaping (Result<ObjectDetectionResult, VisionError>) -> Void
    ) {
        prepare { [weak self] preparation in
            guard let self else {
                completion(.failure(.cancelled))
                return
            }
            switch preparation {
            case .failure(let error):
                completion(.failure(error))
            case .success(let metadata):
                let generation = self.stateQueue.sync { self.cancellationGeneration }
                self.workQueue.async {
                    self.performDetection(
                        input: input,
                        orientation: orientation,
                        requestedClassIdentifier: requestedClassIdentifier,
                        metadata: metadata,
                        generation: generation,
                        completion: completion
                    )
                }
            }
        }
    }

    private func loadModel() {
        let started = ProcessInfo.processInfo.systemUptime
        let result: Result<(VNCoreMLModel, ModelMetadata), VisionError>
        do {
            let manifestURL = try resourceURL(
                name: PinnedContract.bundleResourceName,
                fileExtension: "manifest.json"
            )
            let manifest = try ObjectDetectorManifest.load(from: manifestURL)
            try validate(manifest: manifest)
            let modelURL = try compiledModelURL()

            let modelConfiguration = MLModelConfiguration()
            modelConfiguration.computeUnits = configuration.computeUnits
            let coreMLModel = try MLModel(contentsOf: modelURL, configuration: modelConfiguration)
            try validate(modelDescription: coreMLModel.modelDescription)
            let preparedVisionModel = try VNCoreMLModel(for: coreMLModel)
            preparedVisionModel.inputImageFeatureName = PinnedContract.imageInputName
            preparedVisionModel.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
                PinnedContract.iouInputName: MLFeatureValue(
                    double: configuration.duplicateIntersectionOverUnion
                ),
                PinnedContract.confidenceInputName: MLFeatureValue(
                    double: configuration.minimumConfidence
                ),
            ])

            let metadata = ModelMetadata(
                name: manifest.displayName,
                version: manifest.modelID,
                checksumSHA256: manifest.artifact.sha256.lowercased(),
                checksumVerified: true,
                supportedClassIdentifiers: manifest.classes,
                sourceURL: manifest.source.downloadURL,
                licenseName: manifest.license.name,
                licenseURL: manifest.license.licenseURL
            )
            result = .success((preparedVisionModel, metadata))
        } catch let error as VisionError {
            result = .failure(error)
        } catch {
            result = .failure(.modelLoadFailed(error.localizedDescription))
        }

        let duration = max(0, ProcessInfo.processInfo.systemUptime - started)
        let completions: [(Result<ModelMetadata, VisionError>) -> Void] = stateQueue.sync {
            let callbacks = loadingCompletions
            loadingCompletions.removeAll(keepingCapacity: false)
            switch result {
            case .success(let value):
                visionModel = value.0
                state = .ready(value.1)
            case .failure(let error):
                visionModel = nil
                state = .unavailable(error)
            }
            return callbacks
        }
        switch result {
        case .success(let value):
            diagnostics.recordModelLoad(duration: duration)
            diagnostics.updateModel(metadata: value.1, loaded: true)
            completions.forEach { $0(.success(value.1)) }
        case .failure(let error):
            diagnostics.updateModel(metadata: nil, loaded: false)
            diagnostics.record(error: error)
            completions.forEach { $0(.failure(error)) }
        }
    }

    private func performDetection(
        input: DetectionInput,
        orientation: CGImagePropertyOrientation,
        requestedClassIdentifier: String?,
        metadata: ModelMetadata,
        generation: UInt64,
        completion: @escaping (Result<ObjectDetectionResult, VisionError>) -> Void
    ) {
        guard let model = stateQueue.sync(execute: { visionModel }) else {
            completion(.failure(.modelLoadFailed("The validated model was released before inference.")))
            return
        }
        guard stateQueue.sync(execute: { cancellationGeneration == generation }) else {
            completion(.failure(.cancelled))
            return
        }

        let started = ProcessInfo.processInfo.systemUptime
        var callbackResult: Result<[ObjectObservation], VisionError>?
        let request = VNCoreMLRequest(model: model) { [configuration] request, error in
            if let error {
                callbackResult = .failure(.modelLoadFailed("Vision inference failed: \(error.localizedDescription)"))
                return
            }
            do {
                let observations = try ObjectDetectionDecoder.decode(
                    requestResults: request.results ?? [],
                    minimumConfidence: configuration.minimumConfidence,
                    duplicateIntersectionOverUnion: configuration.duplicateIntersectionOverUnion,
                    requestedClassIdentifier: requestedClassIdentifier,
                    modelVersion: metadata.version
                )
                callbackResult = .success(observations)
            } catch let error as VisionError {
                callbackResult = .failure(error)
            } catch {
                callbackResult = .failure(.invalidModelOutput)
            }
        }
        request.imageCropAndScaleOption = .scaleFill
        stateQueue.sync { currentRequest = request }

        do {
            let handler: VNImageRequestHandler
            switch input {
            case .pixelBuffer(let pixelBuffer):
                handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
            case .image(let image):
                handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
            }
            try handler.perform([request])
        } catch {
            let wasCancelled = stateQueue.sync { cancellationGeneration != generation }
            callbackResult = wasCancelled
                ? .failure(.cancelled)
                : .failure(.modelLoadFailed("Vision inference failed: \(error.localizedDescription)"))
        }

        stateQueue.sync {
            if currentRequest === request {
                currentRequest = nil
            }
        }
        guard stateQueue.sync(execute: { cancellationGeneration == generation }) else {
            completion(.failure(.cancelled))
            return
        }

        let latency = max(0, ProcessInfo.processInfo.systemUptime - started)
        switch callbackResult ?? .failure(.invalidModelOutput) {
        case .success(let observations):
            diagnostics.recordInference(latency: latency)
            completion(.success(ObjectDetectionResult(observations: observations, latency: latency, capturedAt: Date())))
        case .failure(let error):
            diagnostics.record(error: error)
            completion(.failure(error))
        }
    }

    private func resourceURL(name: String, fileExtension: String) throws -> URL {
        if let nested = bundle.url(forResource: name, withExtension: fileExtension, subdirectory: "Models") {
            return nested
        }
        if let flat = bundle.url(forResource: name, withExtension: fileExtension) {
            return flat
        }
        throw VisionError.modelMissing
    }

    private func compiledModelURL() throws -> URL {
        if let nested = bundle.url(
            forResource: PinnedContract.bundleResourceName,
            withExtension: "mlmodelc",
            subdirectory: "Models"
        ) {
            return nested
        }
        if let flat = bundle.url(forResource: PinnedContract.bundleResourceName, withExtension: "mlmodelc") {
            return flat
        }
        throw VisionError.modelMissing
    }

    private func validate(manifest: ObjectDetectorManifest) throws {
        guard manifest.schemaVersion == PinnedContract.schemaVersion,
              manifest.modelID == PinnedContract.modelID,
              manifest.bundleResourceName == PinnedContract.bundleResourceName,
              manifest.compiledResourceName == PinnedContract.compiledResourceName,
              manifest.sourceArtifactFilename == PinnedContract.sourceArtifactName,
              manifest.artifact.sha256.lowercased() == PinnedContract.sourceSHA256,
              manifest.artifact.sizeBytes == PinnedContract.sourceSize,
              manifest.interface.primaryInput.name == PinnedContract.imageInputName,
              manifest.interface.primaryInput.type == "image",
              manifest.interface.primaryInput.width == PinnedContract.imageWidth,
              manifest.interface.primaryInput.height == PinnedContract.imageHeight,
              manifest.interface.classCount == PinnedContract.classCount,
              manifest.interface.nonMaximumSuppression,
              manifest.classes == VisionClassCatalog.rawIdentifiers,
              manifest.classes.count == PinnedContract.classCount,
              manifest.source.downloadURL.hasPrefix("https://ml-assets.apple.com/"),
              !manifest.license.name.isEmpty,
              manifest.license.licenseURL.hasPrefix("https://") else {
            throw VisionError.modelChecksumMismatch
        }

        let thresholds = Dictionary(uniqueKeysWithValues: manifest.interface.thresholdInputs.map { ($0.name, $0.type) })
        guard thresholds[PinnedContract.iouInputName] == "double",
              thresholds[PinnedContract.confidenceInputName] == "double" else {
            throw VisionError.modelLoadFailed("The detector manifest threshold interface is not pinned to the expected schema.")
        }
        let outputs = Dictionary(uniqueKeysWithValues: manifest.interface.outputs.map { ($0.name, $0.type) })
        guard outputs[PinnedContract.confidenceOutputName] == "multiArray",
              outputs[PinnedContract.coordinatesOutputName] == "multiArray" else {
            throw VisionError.modelLoadFailed("The detector manifest output interface is not pinned to the expected schema.")
        }
    }

    private func validate(modelDescription: MLModelDescription) throws {
        let inputs = modelDescription.inputDescriptionsByName
        guard let image = inputs[PinnedContract.imageInputName], image.type == .image,
              let imageConstraint = image.imageConstraint,
              imageConstraint.pixelsWide == PinnedContract.imageWidth,
              imageConstraint.pixelsHigh == PinnedContract.imageHeight else {
            throw VisionError.modelLoadFailed("The compiled detector image input schema does not match 416 by 416 RGB input.")
        }
        guard inputs[PinnedContract.iouInputName]?.type == .double,
              inputs[PinnedContract.confidenceInputName]?.type == .double else {
            throw VisionError.modelLoadFailed("The compiled detector threshold inputs are missing or have the wrong type.")
        }

        let outputs = modelDescription.outputDescriptionsByName
        guard let confidence = outputs[PinnedContract.confidenceOutputName], confidence.type == .multiArray,
              let coordinates = outputs[PinnedContract.coordinatesOutputName], coordinates.type == .multiArray else {
            throw VisionError.modelLoadFailed("The compiled detector output schema is missing confidence or coordinates arrays.")
        }
        try ObjectDetectionDecoder.validateOutputConstraints(
            confidence: confidence.multiArrayConstraint,
            coordinates: coordinates.multiArrayConstraint
        )
    }
}

enum ObjectDetectionDecoder {
    static func validateOutputConstraints(
        confidence: MLMultiArrayConstraint?,
        coordinates: MLMultiArrayConstraint?
    ) throws {
        guard let confidence, let coordinates else {
            throw VisionError.modelLoadFailed("The detector multi-array constraints are unavailable.")
        }
        let confidenceShape = confidence.shape.map(\.intValue).filter { $0 > 1 }
        let coordinateShape = coordinates.shape.map(\.intValue).filter { $0 > 1 }
        if !confidenceShape.isEmpty, !confidenceShape.contains(VisionClassCatalog.rawIdentifiers.count) {
            throw VisionError.modelLoadFailed("The detector confidence output does not contain exactly 80 classes.")
        }
        if !coordinateShape.isEmpty, !coordinateShape.contains(4) {
            throw VisionError.modelLoadFailed("The detector coordinates output does not contain four box coordinates.")
        }
    }

    static func decode(
        requestResults: [VNObservation],
        minimumConfidence: Double,
        duplicateIntersectionOverUnion: Double,
        requestedClassIdentifier: String?,
        modelVersion: String?
    ) throws -> [ObjectObservation] {
        let recognized = requestResults.compactMap { $0 as? VNRecognizedObjectObservation }
        if !recognized.isEmpty {
            let decoded = try recognized.compactMap {
                try decode(
                    recognized: $0,
                    minimumConfidence: minimumConfidence,
                    requestedClassIdentifier: requestedClassIdentifier,
                    modelVersion: modelVersion
                )
            }
            return suppressDuplicates(decoded, intersectionOverUnion: duplicateIntersectionOverUnion)
        }

        let features = requestResults.compactMap { $0 as? VNCoreMLFeatureValueObservation }
        let confidence = features.first { $0.featureName == "confidence" }?.featureValue.multiArrayValue
        let coordinates = features.first { $0.featureName == "coordinates" }?.featureValue.multiArrayValue
        guard let confidence, let coordinates else {
            if requestResults.isEmpty { return [] }
            throw VisionError.invalidModelOutput
        }
        return try decode(
            confidence: confidence,
            coordinates: coordinates,
            minimumConfidence: minimumConfidence,
            duplicateIntersectionOverUnion: duplicateIntersectionOverUnion,
            requestedClassIdentifier: requestedClassIdentifier,
            modelVersion: modelVersion
        )
    }

    static func decode(
        confidence: MLMultiArray,
        coordinates: MLMultiArray,
        minimumConfidence: Double,
        duplicateIntersectionOverUnion: Double = 0.50,
        requestedClassIdentifier: String? = nil,
        modelVersion: String? = nil
    ) throws -> [ObjectObservation] {
        let boxes = try coordinateRows(from: coordinates)
        guard !boxes.isEmpty || confidence.count == 0 else { throw VisionError.invalidModelOutput }
        let scoreRows = try confidenceRows(from: confidence, expectedDetections: boxes.count)
        guard boxes.count == scoreRows.count else { throw VisionError.invalidModelOutput }

        var observations: [ObjectObservation] = []
        observations.reserveCapacity(boxes.count)
        for (boxValues, scores) in zip(boxes, scoreRows) {
            guard scores.count == VisionClassCatalog.rawIdentifiers.count,
                  let best = scores.enumerated().max(by: { $0.element < $1.element }),
                  best.element.isFinite,
                  best.element >= minimumConfidence,
                  best.element <= 1,
                  boxValues.count == 4,
                  boxValues.allSatisfy(\.isFinite) else { continue }

            let centerX = boxValues[0]
            let centerY = boxValues[1]
            let width = boxValues[2]
            let height = boxValues[3]
            guard width > 0, height > 0, width <= 1.5, height <= 1.5 else { continue }
            let rectangle = NormalizedRect(
                x: centerX - width / 2,
                y: centerY - height / 2,
                width: width,
                height: height
            )
            guard rectangle.area > 0,
                  let definition = VisionClassCatalog.definition(forIdentifier: VisionClassCatalog.rawIdentifiers[best.offset]) else {
                throw VisionError.invalidModelOutput
            }
            observations.append(makeObservation(
                definition: definition,
                confidence: best.element,
                box: rectangle,
                requestedClassIdentifier: requestedClassIdentifier,
                modelVersion: modelVersion
            ))
        }
        return suppressDuplicates(observations, intersectionOverUnion: duplicateIntersectionOverUnion)
    }

    private static func decode(
        recognized: VNRecognizedObjectObservation,
        minimumConfidence: Double,
        requestedClassIdentifier: String?,
        modelVersion: String?
    ) throws -> ObjectObservation? {
        guard let label = recognized.labels.first else { return nil }
        let confidence = Double(label.confidence)
        guard confidence.isFinite, confidence >= minimumConfidence, confidence <= 1 else { return nil }
        guard let definition = VisionClassCatalog.definition(forIdentifier: label.identifier) else {
            throw VisionError.invalidModelOutput
        }
        let box = NormalizedRect(recognized.boundingBox)
        guard box.area > 0 else { return nil }
        return makeObservation(
            definition: definition,
            confidence: confidence,
            box: box,
            requestedClassIdentifier: requestedClassIdentifier,
            modelVersion: modelVersion
        )
    }

    private static func makeObservation(
        definition: VisionClassDefinition,
        confidence: Double,
        box: NormalizedRect,
        requestedClassIdentifier: String?,
        modelVersion: String?
    ) -> ObjectObservation {
        let distance: RelativeDistance
        if box.area >= 0.35 {
            distance = .possiblyClose
        } else if box.area <= 0.04 {
            distance = .fartherAway
        } else {
            distance = .unknown
        }
        return ObjectObservation(
            classIdentifier: definition.identifier,
            name: definition.displayName,
            confidence: confidence,
            boundingBox: box,
            relativeDistance: distance,
            isRequested: requestedClassIdentifier == definition.identifier,
            mayBeSafetyRelevant: definition.mayBeSafetyRelevant,
            source: .objectDetection,
            modelVersion: modelVersion
        )
    }

    private static func coordinateRows(from array: MLMultiArray) throws -> [[Double]] {
        let tensor = try TensorValues(array)
        if tensor.shape.count == 1 {
            guard tensor.values.count.isMultiple(of: 4) else { throw VisionError.invalidModelOutput }
            return stride(from: 0, to: tensor.values.count, by: 4).map {
                Array(tensor.values[$0..<min($0 + 4, tensor.values.count)])
            }
        }
        if tensor.shape.last == 4 {
            return stride(from: 0, to: tensor.values.count, by: 4).map {
                Array(tensor.values[$0..<$0 + 4])
            }
        }
        if tensor.shape.count == 2, tensor.shape.first == 4 {
            let count = tensor.shape[1]
            return (0..<count).map { column in
                (0..<4).map { row in tensor.values[row * count + column] }
            }
        }
        throw VisionError.invalidModelOutput
    }

    private static func confidenceRows(from array: MLMultiArray, expectedDetections: Int) throws -> [[Double]] {
        let tensor = try TensorValues(array)
        let classCount = VisionClassCatalog.rawIdentifiers.count
        guard expectedDetections >= 0 else { throw VisionError.invalidModelOutput }
        if expectedDetections == 0 { return [] }

        if tensor.shape.count == 1 {
            guard tensor.values.count == expectedDetections * classCount else { throw VisionError.invalidModelOutput }
            return stride(from: 0, to: tensor.values.count, by: classCount).map {
                Array(tensor.values[$0..<$0 + classCount])
            }
        }
        if tensor.shape.last == classCount,
           tensor.values.count == expectedDetections * classCount {
            return stride(from: 0, to: tensor.values.count, by: classCount).map {
                Array(tensor.values[$0..<$0 + classCount])
            }
        }
        if tensor.shape.count == 2,
           tensor.shape.first == classCount,
           tensor.shape[1] == expectedDetections {
            return (0..<expectedDetections).map { column in
                (0..<classCount).map { row in tensor.values[row * expectedDetections + column] }
            }
        }
        throw VisionError.invalidModelOutput
    }

    private static func suppressDuplicates(
        _ observations: [ObjectObservation],
        intersectionOverUnion: Double
    ) -> [ObjectObservation] {
        let ordered = observations.sorted {
            if $0.confidence == $1.confidence { return $0.id.uuidString < $1.id.uuidString }
            return $0.confidence > $1.confidence
        }
        var selected: [ObjectObservation] = []
        for candidate in ordered {
            let duplicate = selected.contains {
                $0.classIdentifier == candidate.classIdentifier &&
                    $0.boundingBox.intersectionOverUnion(with: candidate.boundingBox) >= intersectionOverUnion
            }
            if !duplicate { selected.append(candidate) }
        }
        return selected
    }

    private struct TensorValues {
        let shape: [Int]
        let values: [Double]

        init(_ array: MLMultiArray) throws {
            let originalShape = array.shape.map(\.intValue)
            guard !originalShape.isEmpty, originalShape.allSatisfy({ $0 >= 0 }) else {
                throw VisionError.invalidModelOutput
            }
            var logicalShape = originalShape.filter { $0 != 1 }
            if logicalShape.isEmpty { logicalShape = [array.count] }
            shape = logicalShape
            values = try Self.readValues(array, shape: originalShape)
        }

        private static func readValues(_ array: MLMultiArray, shape: [Int]) throws -> [Double] {
            guard shape.reduce(1, *) == array.count else { throw VisionError.invalidModelOutput }
            if array.count == 0 { return [] }
            var output: [Double] = []
            output.reserveCapacity(array.count)
            var indices = Array(repeating: 0, count: shape.count)
            for linear in 0..<array.count {
                var remainder = linear
                for axis in shape.indices.reversed() {
                    let dimension = shape[axis]
                    indices[axis] = dimension > 0 ? remainder % dimension : 0
                    remainder = dimension > 0 ? remainder / dimension : 0
                }
                let numberIndices = indices.map { NSNumber(value: $0) }
                output.append(array[numberIndices].doubleValue)
            }
            return output
        }
    }
}

private struct ObjectDetectorManifest: Decodable {
    struct Source: Decodable {
        let downloadURL: String

        enum CodingKeys: String, CodingKey {
            case downloadURL = "download_url"
        }
    }

    struct Artifact: Decodable {
        let sizeBytes: Int
        let sha256: String

        enum CodingKeys: String, CodingKey {
            case sizeBytes = "size_bytes"
            case sha256
        }
    }

    struct Input: Decodable {
        let name: String
        let type: String
        let width: Int?
        let height: Int?
    }

    struct NamedType: Decodable {
        let name: String
        let type: String
    }

    struct Interface: Decodable {
        let primaryInput: Input
        let thresholdInputs: [NamedType]
        let outputs: [NamedType]
        let nonMaximumSuppression: Bool
        let classCount: Int

        enum CodingKeys: String, CodingKey {
            case primaryInput = "primary_input"
            case thresholdInputs = "threshold_inputs"
            case outputs
            case nonMaximumSuppression = "non_maximum_suppression"
            case classCount = "class_count"
        }
    }

    struct License: Decodable {
        let name: String
        let licenseURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case licenseURL = "license_url"
        }
    }

    let schemaVersion: Int
    let modelID: String
    let displayName: String
    let bundleResourceName: String
    let sourceArtifactFilename: String
    let compiledResourceName: String
    let source: Source
    let artifact: Artifact
    let interface: Interface
    let classes: [String]
    let license: License

    enum CodingKeys: String, CodingKey {
        case schemaVersion = "schema_version"
        case modelID = "model_id"
        case displayName = "display_name"
        case bundleResourceName = "bundle_resource_name"
        case sourceArtifactFilename = "source_artifact_filename"
        case compiledResourceName = "compiled_resource_name"
        case source
        case artifact
        case interface
        case classes
        case license
    }

    static func load(from url: URL) throws -> ObjectDetectorManifest {
        do {
            return try JSONDecoder().decode(ObjectDetectorManifest.self, from: Data(contentsOf: url))
        } catch {
            throw VisionError.modelLoadFailed("The bundled detector manifest is unreadable: \(error.localizedDescription)")
        }
    }
}
