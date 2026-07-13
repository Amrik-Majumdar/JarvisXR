import Foundation

enum CameraFrameCondition: String, Codable, CaseIterable, Sendable {
    case valid
    case invalidPixelBuffer
    case blackFrame
    case underexposed
    case overexposed
    case blurred
    case excessiveMotion
    case poorlyFramed
    case obstructed
}

struct CameraQualityConfiguration: Equatable, Sendable {
    var darkBrightnessThreshold: Double
    var overexposedFractionThreshold: Double
    var blurSharpnessThreshold: Double
    var excessiveMotionThreshold: Double
    var coveredBrightnessThreshold: Double
    var coveredVarianceThreshold: Double
    var coveredConfirmationFrames: Int
    var coveredConfirmationDuration: TimeInterval

    init(
        darkBrightnessThreshold: Double = 0.13,
        overexposedFractionThreshold: Double = 0.58,
        blurSharpnessThreshold: Double = 0.055,
        excessiveMotionThreshold: Double = 0.52,
        coveredBrightnessThreshold: Double = 0.055,
        coveredVarianceThreshold: Double = 0.0025,
        coveredConfirmationFrames: Int = 3,
        coveredConfirmationDuration: TimeInterval = 1.25
    ) {
        self.darkBrightnessThreshold = Self.unit(darkBrightnessThreshold)
        self.overexposedFractionThreshold = Self.unit(overexposedFractionThreshold)
        self.blurSharpnessThreshold = Self.unit(blurSharpnessThreshold)
        self.excessiveMotionThreshold = Self.unit(excessiveMotionThreshold)
        self.coveredBrightnessThreshold = Self.unit(coveredBrightnessThreshold)
        self.coveredVarianceThreshold = Self.unit(coveredVarianceThreshold)
        self.coveredConfirmationFrames = max(2, coveredConfirmationFrames)
        self.coveredConfirmationDuration = max(0.5, coveredConfirmationDuration.isFinite ? coveredConfirmationDuration : 1.25)
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

struct CameraQualityMetrics: Equatable, Sendable {
    let condition: CameraFrameCondition
    let brightness: Double
    let variance: Double
    let sharpness: Double
    let overexposure: Double
    let motion: Double
    let obstruction: Double
    let isUsable: Bool
    let isBlackFrame: Bool
    let isUnderexposed: Bool
    let isOverexposed: Bool
    let isBlurred: Bool
    let hasExcessiveMotion: Bool
    let hasPoorFraming: Bool
    let obstructionEvidenceFrames: Int
    let sampleCount: Int
}

/// Foundation-only quality engine shared by live camera analysis and local replay tests.
/// A dark, uniform frame is only called an obstruction after sustained evidence; startup
/// black frames and malformed inputs have distinct conditions.
final class CameraQualityMetricsEngine: @unchecked Sendable {
    let configuration: CameraQualityConfiguration

    private let lock = NSLock()
    private var previousLuminance: [Double]?
    private var obstructionCandidateStartedAt: Date?
    private var obstructionCandidateFrames = 0

    init(configuration: CameraQualityConfiguration = CameraQualityConfiguration()) {
        self.configuration = configuration
    }

    func resetTemporalHistory() {
        lock.lock()
        previousLuminance = nil
        obstructionCandidateStartedAt = nil
        obstructionCandidateFrames = 0
        lock.unlock()
    }

    func evaluate(
        luminanceSamples: [UInt8],
        width: Int,
        height: Int,
        at date: Date = Date()
    ) -> CameraQualityMetrics {
        guard width > 1, height > 1, luminanceSamples.count == width * height else {
            resetObstructionEvidence()
            return CameraQualityMetrics(
                condition: .invalidPixelBuffer,
                brightness: 0,
                variance: 0,
                sharpness: 0,
                overexposure: 0,
                motion: 0,
                obstruction: 0,
                isUsable: false,
                isBlackFrame: false,
                isUnderexposed: false,
                isOverexposed: false,
                isBlurred: false,
                hasExcessiveMotion: false,
                hasPoorFraming: false,
                obstructionEvidenceFrames: 0,
                sampleCount: luminanceSamples.count
            )
        }

        let normalized = luminanceSamples.map { Double($0) / 255 }
        let brightness = normalized.reduce(0, +) / Double(normalized.count)
        let variance = normalized.reduce(0) { $0 + pow($1 - brightness, 2) } / Double(normalized.count)
        let overexposure = Double(normalized.filter { $0 >= 0.965 }.count) / Double(normalized.count)

        var edgeSum = 0.0
        var edgeCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let current = normalized[y * width + x]
                if x + 1 < width {
                    edgeSum += abs(current - normalized[y * width + x + 1])
                    edgeCount += 1
                }
                if y + 1 < height {
                    edgeSum += abs(current - normalized[(y + 1) * width + x])
                    edgeCount += 1
                }
            }
        }
        let rawEdge = edgeCount > 0 ? edgeSum / Double(edgeCount) : 0
        let sharpness = Self.unit(rawEdge * 4.5)

        let motion: Double = lock.withLock {
            defer { previousLuminance = normalized }
            guard let previousLuminance, previousLuminance.count == normalized.count else { return 0 }
            let difference = zip(previousLuminance, normalized).reduce(0) { $0 + abs($1.0 - $1.1) }
            return Self.unit((difference / Double(normalized.count)) * 3.0)
        }

        let isBlackFrame = brightness <= 0.008 && variance <= 0.0002
        let obstructionCandidate = brightness <= configuration.coveredBrightnessThreshold &&
            variance <= configuration.coveredVarianceThreshold &&
            sharpness < configuration.blurSharpnessThreshold
        let obstructionEvidence = updateObstructionEvidence(candidate: obstructionCandidate, at: date)
        let isObstructed = obstructionCandidate &&
            obstructionEvidence.frames >= configuration.coveredConfirmationFrames &&
            obstructionEvidence.duration >= configuration.coveredConfirmationDuration
        let obstruction = isObstructed
            ? Self.unit(0.82 + (configuration.coveredBrightnessThreshold - brightness) * 3)
            : (obstructionCandidate ? 0.35 : 0)
        let isUnderexposed = brightness < configuration.darkBrightnessThreshold && !isObstructed
        let isOverexposed = overexposure >= configuration.overexposedFractionThreshold
        let isBlurred = sharpness < configuration.blurSharpnessThreshold && !isObstructed
        let hasExcessiveMotion = motion >= configuration.excessiveMotionThreshold
        let hasPoorFraming = variance < configuration.coveredVarianceThreshold * 0.60 &&
            brightness >= configuration.darkBrightnessThreshold &&
            !isOverexposed &&
            !isObstructed

        let condition: CameraFrameCondition
        if isObstructed {
            condition = .obstructed
        } else if isBlackFrame {
            condition = .blackFrame
        } else if isUnderexposed {
            condition = .underexposed
        } else if isOverexposed {
            condition = .overexposed
        } else if hasExcessiveMotion {
            condition = .excessiveMotion
        } else if isBlurred {
            condition = .blurred
        } else if hasPoorFraming {
            condition = .poorlyFramed
        } else {
            condition = .valid
        }

        // Blur and a low-detail scene remain analyzable. They may reduce confidence, but
        // they are not proof that the camera is unavailable or covered.
        let isUsable = condition != .invalidPixelBuffer &&
            condition != .blackFrame &&
            condition != .underexposed &&
            condition != .overexposed &&
            condition != .excessiveMotion &&
            condition != .obstructed

        return CameraQualityMetrics(
            condition: condition,
            brightness: brightness,
            variance: variance,
            sharpness: sharpness,
            overexposure: overexposure,
            motion: motion,
            obstruction: obstruction,
            isUsable: isUsable,
            isBlackFrame: isBlackFrame,
            isUnderexposed: isUnderexposed,
            isOverexposed: isOverexposed,
            isBlurred: isBlurred,
            hasExcessiveMotion: hasExcessiveMotion,
            hasPoorFraming: hasPoorFraming,
            obstructionEvidenceFrames: obstructionEvidence.frames,
            sampleCount: luminanceSamples.count
        )
    }

    private func updateObstructionEvidence(candidate: Bool, at date: Date) -> (frames: Int, duration: TimeInterval) {
        lock.withLock {
            guard candidate else {
                obstructionCandidateStartedAt = nil
                obstructionCandidateFrames = 0
                return (0, 0)
            }
            if let started = obstructionCandidateStartedAt, date >= started {
                obstructionCandidateFrames += 1
                return (obstructionCandidateFrames, date.timeIntervalSince(started))
            }
            obstructionCandidateStartedAt = date
            obstructionCandidateFrames = 1
            return (1, 0)
        }
    }

    private func resetObstructionEvidence() {
        lock.withLock {
            obstructionCandidateStartedAt = nil
            obstructionCandidateFrames = 0
        }
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}
