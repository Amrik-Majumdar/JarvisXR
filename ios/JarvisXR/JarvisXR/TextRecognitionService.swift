import CoreVideo
import Foundation
import ImageIO
import Vision

enum TextRecognitionMode: String, Codable, CaseIterable, Sendable {
    case fast
    case accurate
}

struct TextRecognitionConfiguration: Equatable, Sendable {
    var recognitionLanguages: [String]
    var usesLanguageCorrection: Bool
    var minimumConfidence: Double
    var maximumCandidatesPerLine: Int

    init(
        recognitionLanguages: [String] = [],
        usesLanguageCorrection: Bool = true,
        minimumConfidence: Double = 0.20,
        maximumCandidatesPerLine: Int = 1
    ) {
        self.recognitionLanguages = recognitionLanguages
        self.usesLanguageCorrection = usesLanguageCorrection
        self.minimumConfidence = min(max(minimumConfidence, 0), 1)
        self.maximumCandidatesPerLine = max(1, maximumCandidatesPerLine)
    }
}

struct TextRecognitionResult: Equatable, Sendable {
    let observation: TextObservation
    let mode: TextRecognitionMode
    let latency: TimeInterval
}

final class TextRecognitionService: @unchecked Sendable {
    let configuration: TextRecognitionConfiguration

    private enum Input {
        case pixelBuffer(CVPixelBuffer)
        case image(CGImage)
    }

    private struct Candidate: Equatable {
        let text: String
        let confidence: Double
        let boundingBox: NormalizedRect
    }

    private let workQueue = DispatchQueue(label: "com.amrik.jarvisxr.vision.text", qos: .userInitiated)
    private let lock = NSLock()
    private var generation: UInt64 = 0
    private var currentRequest: VNRecognizeTextRequest?

    init(configuration: TextRecognitionConfiguration = TextRecognitionConfiguration()) {
        self.configuration = configuration
    }

    func recognize(
        in pixelBuffer: CVPixelBuffer,
        orientation: CGImagePropertyOrientation,
        mode: TextRecognitionMode,
        completion: @escaping (Result<TextRecognitionResult, VisionError>) -> Void
    ) {
        recognize(input: .pixelBuffer(pixelBuffer), orientation: orientation, mode: mode, completion: completion)
    }

    func recognize(
        in image: CGImage,
        orientation: CGImagePropertyOrientation,
        mode: TextRecognitionMode,
        completion: @escaping (Result<TextRecognitionResult, VisionError>) -> Void
    ) {
        recognize(input: .image(image), orientation: orientation, mode: mode, completion: completion)
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
        mode: TextRecognitionMode,
        completion: @escaping (Result<TextRecognitionResult, VisionError>) -> Void
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
            var recognitionResult: Result<[Candidate], VisionError>?
            let request = VNRecognizeTextRequest { [configuration] request, error in
                if error != nil {
                    recognitionResult = .failure(.textRecognitionFailed)
                    return
                }
                let candidates = (request.results as? [VNRecognizedTextObservation] ?? []).compactMap { observation -> Candidate? in
                    guard let candidate = observation.topCandidates(configuration.maximumCandidatesPerLine).first else {
                        return nil
                    }
                    let confidence = Double(candidate.confidence)
                    let value = candidate.string.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !value.isEmpty, confidence.isFinite, confidence >= configuration.minimumConfidence else {
                        return nil
                    }
                    return Candidate(
                        text: value,
                        confidence: confidence,
                        boundingBox: NormalizedRect(observation.boundingBox)
                    )
                }
                recognitionResult = .success(candidates)
            }
            request.recognitionLevel = mode == .accurate ? .accurate : .fast
            request.usesLanguageCorrection = mode == .accurate && self.configuration.usesLanguageCorrection
            request.automaticallyDetectsLanguage = self.configuration.recognitionLanguages.isEmpty
            if !self.configuration.recognitionLanguages.isEmpty {
                request.recognitionLanguages = self.configuration.recognitionLanguages
            }
            request.minimumTextHeight = mode == .fast ? 0.025 : 0.012
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
                recognitionResult = request.isCancelled ? .failure(.cancelled) : .failure(.textRecognitionFailed)
            }
            self.withLock {
                if self.currentRequest === request { self.currentRequest = nil }
            }
            guard self.withLock({ self.generation == requestGeneration }), !request.isCancelled else {
                completion(.failure(.cancelled))
                return
            }

            switch recognitionResult ?? .failure(.textRecognitionFailed) {
            case .failure(let error):
                completion(.failure(error))
            case .success(let candidates):
                guard !candidates.isEmpty else {
                    completion(.failure(.noTextFound))
                    return
                }
                let ordered = Self.readingOrder(for: candidates)
                let lines = ordered.enumerated().map { index, candidate in
                    TextLine(
                        text: candidate.text,
                        confidence: candidate.confidence,
                        boundingBox: candidate.boundingBox,
                        readingOrder: index
                    )
                }
                let blocks = lines.map {
                    TextBlock(lines: [$0], boundingBox: $0.boundingBox, readingOrder: $0.readingOrder)
                }
                let enclosing = Self.enclosingRectangle(lines.map(\.boundingBox))
                let confidence = lines.map(\.confidence).reduce(0, +) / Double(lines.count)
                let observation = TextObservation(
                    blocks: blocks,
                    confidence: confidence,
                    boundingBox: enclosing,
                    capturedAt: Date()
                )
                completion(.success(TextRecognitionResult(
                    observation: observation,
                    mode: mode,
                    latency: max(0, ProcessInfo.processInfo.systemUptime - started)
                )))
            }
        }
    }

    /// Deterministic row clustering for Vision's lower-left normalized coordinates.
    static func readingOrder(
        texts: [(text: String, confidence: Double, boundingBox: NormalizedRect)]
    ) -> [TextLine] {
        let candidates = texts.map { Candidate(text: $0.text, confidence: $0.confidence, boundingBox: $0.boundingBox) }
        return readingOrder(for: candidates).enumerated().map { index, candidate in
            TextLine(
                text: candidate.text,
                confidence: candidate.confidence,
                boundingBox: candidate.boundingBox,
                readingOrder: index
            )
        }
    }

    private static func readingOrder(for candidates: [Candidate]) -> [Candidate] {
        let vertical = candidates.sorted {
            if abs($0.boundingBox.maxY - $1.boundingBox.maxY) < 0.000_001 {
                if $0.boundingBox.minX == $1.boundingBox.minX { return $0.text < $1.text }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
            return $0.boundingBox.maxY > $1.boundingBox.maxY
        }
        var rows: [[Candidate]] = []
        var rowCenterYs: [Double] = []
        for candidate in vertical {
            let candidateCenter = candidate.boundingBox.centerY
            let tolerance = max(0.02, candidate.boundingBox.height * 0.55)
            if let rowIndex = rowCenterYs.indices.first(where: { abs(rowCenterYs[$0] - candidateCenter) <= tolerance }) {
                rows[rowIndex].append(candidate)
                let centers = rows[rowIndex].map { $0.boundingBox.centerY }
                rowCenterYs[rowIndex] = centers.reduce(0, +) / Double(centers.count)
            } else {
                rows.append([candidate])
                rowCenterYs.append(candidateCenter)
            }
        }
        let orderedRows = zip(rows, rowCenterYs).sorted {
            if $0.1 == $1.1 {
                return ($0.0.map { $0.boundingBox.minX }.min() ?? 0) < ($1.0.map { $0.boundingBox.minX }.min() ?? 0)
            }
            return $0.1 > $1.1
        }
        return orderedRows.flatMap { row, _ in
            row.sorted {
                if $0.boundingBox.minX == $1.boundingBox.minX { return $0.text < $1.text }
                return $0.boundingBox.minX < $1.boundingBox.minX
            }
        }
    }

    private static func enclosingRectangle(_ boxes: [NormalizedRect]) -> NormalizedRect {
        guard let first = boxes.first else { return .zero }
        let minX = boxes.dropFirst().reduce(first.minX) { min($0, $1.minX) }
        let minY = boxes.dropFirst().reduce(first.minY) { min($0, $1.minY) }
        let maxX = boxes.dropFirst().reduce(first.maxX) { max($0, $1.maxX) }
        let maxY = boxes.dropFirst().reduce(first.maxY) { max($0, $1.maxY) }
        return NormalizedRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }

    @discardableResult
    private func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
