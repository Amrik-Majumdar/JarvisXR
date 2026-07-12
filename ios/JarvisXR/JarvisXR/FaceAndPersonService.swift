import CoreVideo
import Foundation
import ImageIO
import Vision

struct FaceAndPersonResult: Equatable, Sendable {
    let people: [PersonObservation]
    let detectedFaceCount: Int
    let latency: TimeInterval
    let capturedAt: Date

    /// This analyzer is deliberately presence-only.
    let identityInferencePerformed = false
    let sensitiveAttributeInferencePerformed = false

    var personCount: Int { people.count }
    var hasPerson: Bool { !people.isEmpty }
}

final class FaceAndPersonService: @unchecked Sendable {
    private enum Input {
        case pixelBuffer(CVPixelBuffer)
        case image(CGImage)
    }

    private let workQueue = DispatchQueue(label: "com.amrik.jarvisxr.vision.people", qos: .userInitiated)
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var currentRequests: [VNRequest] = []

    func analyze(
        pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<FaceAndPersonResult, VisionError>) -> Void
    ) {
        analyze(input: .pixelBuffer(pixelBuffer), orientation: orientation, completion: completion)
    }

    func analyze(
        image: CGImage,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<FaceAndPersonResult, VisionError>) -> Void
    ) {
        analyze(input: .image(image), orientation: orientation, completion: completion)
    }

    func cancelAll() {
        withLock {
            generation &+= 1
            currentRequests.forEach { $0.cancel() }
            currentRequests.removeAll(keepingCapacity: false)
        }
    }

    private func analyze(
        input: Input,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<FaceAndPersonResult, VisionError>) -> Void
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
            var humanBoxes: [(NormalizedRect, Double)] = []
            var faceBoxes: [(NormalizedRect, Double)] = []
            var requestError: VisionError?

            let peopleRequest = VNDetectHumanRectanglesRequest { request, error in
                if error != nil {
                    requestError = .invalidModelOutput
                    return
                }
                humanBoxes = (request.results ?? []).compactMap { value in
                    guard let observation = value as? VNDetectedObjectObservation else { return nil }
                    let confidence = Double(observation.confidence)
                    guard confidence.isFinite, confidence > 0 else { return nil }
                    return (NormalizedRect(observation.boundingBox), min(confidence, 1))
                }
            }
            peopleRequest.upperBodyOnly = false

            let faceRequest = VNDetectFaceRectanglesRequest { request, error in
                if error != nil {
                    requestError = .invalidModelOutput
                    return
                }
                faceBoxes = (request.results as? [VNFaceObservation] ?? []).compactMap { observation in
                    let confidence = Double(observation.confidence)
                    guard confidence.isFinite, confidence > 0 else { return nil }
                    return (NormalizedRect(observation.boundingBox), min(confidence, 1))
                }
            }
            self.withLock { self.currentRequests = [peopleRequest, faceRequest] }

            do {
                let handler: VNImageRequestHandler
                switch input {
                case .pixelBuffer(let pixelBuffer):
                    handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
                case .image(let image):
                    handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
                }
                try handler.perform([peopleRequest, faceRequest])
            } catch {
                requestError = peopleRequest.isCancelled || faceRequest.isCancelled ? .cancelled : .invalidModelOutput
            }
            self.withLock { self.currentRequests.removeAll(keepingCapacity: false) }
            guard self.withLock({ self.generation == requestGeneration }),
                  !peopleRequest.isCancelled,
                  !faceRequest.isCancelled else {
                completion(.failure(.cancelled))
                return
            }
            if let requestError {
                completion(.failure(requestError))
                return
            }

            let capturedAt = Date()
            let merged = Self.mergePersonAndFaceBoxes(humans: humanBoxes, faces: faceBoxes)
            let people = merged.map { box, confidence in
                PersonObservation(
                    confidence: confidence,
                    boundingBox: box,
                    firstSeenAt: capturedAt,
                    source: .faceAndPerson
                )
            }.sorted {
                if $0.boundingBox.minX == $1.boundingBox.minX { return $0.id.uuidString < $1.id.uuidString }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            completion(.success(FaceAndPersonResult(
                people: people,
                detectedFaceCount: faceBoxes.count,
                latency: max(0, ProcessInfo.processInfo.systemUptime - started),
                capturedAt: capturedAt
            )))
        }
    }

    static func mergePersonAndFaceBoxes(
        humans: [(NormalizedRect, Double)],
        faces: [(NormalizedRect, Double)]
    ) -> [(NormalizedRect, Double)] {
        var merged = humans.filter { $0.0.area > 0 }
        for face in faces where face.0.area > 0 {
            let representedByHuman = merged.contains { human in
                let overlap = human.0.intersectionArea(with: face.0)
                return overlap / max(face.0.area, 0.000_001) >= 0.45 ||
                    (human.0.minX <= face.0.centerX && human.0.maxX >= face.0.centerX &&
                        human.0.minY <= face.0.centerY && human.0.maxY >= face.0.centerY)
            }
            if !representedByHuman { merged.append(face) }
        }
        return merged
    }

    @discardableResult
    private func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
