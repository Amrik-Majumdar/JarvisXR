import CoreVideo
import Foundation
import ImageIO
import Vision

struct BarcodeRecognitionConfiguration: Equatable, Sendable {
    var duplicateSuppressionInterval: TimeInterval
    var minimumConfidence: Double

    init(duplicateSuppressionInterval: TimeInterval = 2.5, minimumConfidence: Double = 0.20) {
        self.duplicateSuppressionInterval = max(0, duplicateSuppressionInterval)
        self.minimumConfidence = min(max(minimumConfidence, 0), 1)
    }
}

struct BarcodeRecognitionResult: Equatable, Sendable {
    let observations: [BarcodeObservation]
    let latency: TimeInterval
    let capturedAt: Date

    /// Payloads are data only. The service never opens, executes, or routes a URL.
    let automaticallyOpenedURL = false
}

final class BarcodeRecognitionService: @unchecked Sendable {
    static let supportedSymbologies: [VNBarcodeSymbology] = [
        .aztec,
        .code39,
        .code93,
        .code128,
        .dataMatrix,
        .ean8,
        .ean13,
        .itf14,
        .pdf417,
        .qr,
        .upce
    ]

    let configuration: BarcodeRecognitionConfiguration

    private enum Input {
        case pixelBuffer(CVPixelBuffer)
        case image(CGImage)
    }

    private let workQueue = DispatchQueue(label: "com.amrik.jarvisxr.vision.barcode", qos: .userInitiated)
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var currentRequest: VNDetectBarcodesRequest?
    private var lastEmittedAt: [String: Date] = [:]

    init(configuration: BarcodeRecognitionConfiguration = BarcodeRecognitionConfiguration()) {
        self.configuration = configuration
    }

    func recognize(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<BarcodeRecognitionResult, VisionError>) -> Void
    ) {
        recognize(input: .pixelBuffer(pixelBuffer), orientation: orientation, completion: completion)
    }

    func recognize(
        in image: CGImage,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<BarcodeRecognitionResult, VisionError>) -> Void
    ) {
        recognize(input: .image(image), orientation: orientation, completion: completion)
    }

    func clearDeduplicationHistory() {
        workQueue.async { [weak self] in self?.lastEmittedAt.removeAll(keepingCapacity: false) }
    }

    func cancelAll() {
        withLock {
            generation &+= 1
            currentRequest?.cancel()
            currentRequest = nil
        }
    }

    private func recognize(
        input: Input,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<BarcodeRecognitionResult, VisionError>) -> Void
    ) {
        let requestGeneration = withLock { generation }
        workQueue.async { [weak self] in
            guard let self else {
                completion(.failure(.cancelled))
                return
            }
            guard self.withLock({ self.generation == requestGeneration }) else {
                completion(.failure(.cancelled))
                return
            }
            let started = ProcessInfo.processInfo.systemUptime
            var requestResult: Result<[BarcodeObservation], VisionError>?
            let request = VNDetectBarcodesRequest { [configuration] request, error in
                guard error == nil else {
                    requestResult = .failure(.invalidModelOutput)
                    return
                }
                let capturedAt = Date()
                let observations = (request.results as? [VNBarcodeObservation] ?? []).compactMap { value -> BarcodeObservation? in
                    guard let payload = value.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines),
                          !payload.isEmpty else { return nil }
                    let confidence = Double(value.confidence)
                    guard confidence.isFinite, confidence >= configuration.minimumConfidence, confidence <= 1 else {
                        return nil
                    }
                    return BarcodeObservation(
                        symbology: value.symbology.rawValue,
                        payload: payload,
                        confidence: confidence,
                        boundingBox: NormalizedRect(value.boundingBox),
                        capturedAt: capturedAt
                    )
                }
                requestResult = .success(observations)
            }
            request.symbologies = Self.supportedSymbologies
            self.withLock { self.currentRequest = request }
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
                requestResult = request.isCancelled ? .failure(.cancelled) : .failure(.invalidModelOutput)
            }
            self.withLock {
                if self.currentRequest === request { self.currentRequest = nil }
            }
            guard self.withLock({ self.generation == requestGeneration }), !request.isCancelled else {
                completion(.failure(.cancelled))
                return
            }

            switch requestResult ?? .failure(.invalidModelOutput) {
            case .failure(let error):
                completion(.failure(error))
            case .success(let values):
                let capturedAt = Date()
                let deduplicated = self.deduplicate(values, at: capturedAt)
                completion(.success(BarcodeRecognitionResult(
                    observations: deduplicated,
                    latency: max(0, ProcessInfo.processInfo.systemUptime - started),
                    capturedAt: capturedAt
                )))
            }
        }
    }

    /// Exposed to the unit-test target through `@testable` without involving Vision request state.
    func deduplicateForTesting(_ values: [BarcodeObservation], at date: Date) -> [BarcodeObservation] {
        workQueue.sync { deduplicate(values, at: date) }
    }

    private func deduplicate(_ values: [BarcodeObservation], at date: Date) -> [BarcodeObservation] {
        let grouped = Dictionary(grouping: values, by: key)
        let strongest = grouped.values.compactMap { group in
            group.sorted {
                if $0.confidence == $1.confidence { return $0.id.uuidString < $1.id.uuidString }
                return $0.confidence > $1.confidence
            }.first
        }.sorted {
            if $0.confidence == $1.confidence { return key($0) < key($1) }
            return $0.confidence > $1.confidence
        }
        let cutoff = date.addingTimeInterval(-configuration.duplicateSuppressionInterval)
        lastEmittedAt = lastEmittedAt.filter { $0.value >= cutoff }

        var emitted: [BarcodeObservation] = []
        for observation in strongest {
            let observationKey = key(observation)
            if let previous = lastEmittedAt[observationKey], date.timeIntervalSince(previous) < configuration.duplicateSuppressionInterval {
                continue
            }
            lastEmittedAt[observationKey] = date
            emitted.append(observation)
        }
        return emitted
    }

    private func key(_ observation: BarcodeObservation) -> String {
        observation.symbology.lowercased() + "\u{1f}" + observation.payload
    }

    @discardableResult
    private func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
