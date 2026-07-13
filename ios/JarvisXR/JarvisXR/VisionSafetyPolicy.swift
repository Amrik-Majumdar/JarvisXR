import Foundation

enum VisionSafetySuppressionReason: String, Codable, Equatable, Sendable {
    case invalidConfidence
    case belowMinimumConfidence
    case insufficientStability
    case unusableFrame
}

enum VisionEvidenceDecision: Codable, Equatable, Sendable {
    case suppressed(VisionSafetySuppressionReason)
    case uncertain
    case supported
}

struct VisionSafetyConfiguration: Codable, Equatable, Sendable {
    var minimumConfidence: Double
    var requestedMinimumConfidence: Double
    var supportedConfidence: Double
    var requiredStableFrames: Int
    var requestedStableFrames: Int

    static let conservative = VisionSafetyConfiguration(
        minimumConfidence: 0.58,
        requestedMinimumConfidence: 0.54,
        supportedConfidence: 0.82,
        requiredStableFrames: 3,
        requestedStableFrames: 2
    )

    static let balanced = VisionSafetyConfiguration(
        minimumConfidence: 0.52,
        requestedMinimumConfidence: 0.50,
        supportedConfidence: 0.78,
        requiredStableFrames: 3,
        requestedStableFrames: 2
    )

    static let moreSensitive = VisionSafetyConfiguration(
        minimumConfidence: 0.45,
        requestedMinimumConfidence: 0.43,
        supportedConfidence: 0.74,
        requiredStableFrames: 2,
        requestedStableFrames: 2
    )
}

struct VisionSafetyValidation: Equatable, Sendable {
    let isAllowed: Bool
    let violations: [String]
}

struct VisionSafetyPolicy: Sendable {
    let configuration: VisionSafetyConfiguration

    init(configuration: VisionSafetyConfiguration = .conservative) {
        self.configuration = configuration
    }

    func decision(
        confidence: Double,
        consecutiveFrames: Int,
        isRequested: Bool,
        frameUsable: Bool
    ) -> VisionEvidenceDecision {
        guard frameUsable else {
            return .suppressed(.unusableFrame)
        }
        guard confidence.isFinite, confidence >= 0, confidence <= 1 else {
            return .suppressed(.invalidConfidence)
        }

        let minimum = isRequested ? configuration.requestedMinimumConfidence : configuration.minimumConfidence
        guard confidence >= minimum else {
            return .suppressed(.belowMinimumConfidence)
        }

        let requiredFrames = isRequested ? configuration.requestedStableFrames : configuration.requiredStableFrames
        guard consecutiveFrames >= requiredFrames else {
            return .suppressed(.insufficientStability)
        }

        return confidence >= configuration.supportedConfidence ? .supported : .uncertain
    }

    func decision(for observation: TrackedObservation, frameUsable: Bool) -> VisionEvidenceDecision {
        decision(
            confidence: observation.smoothedConfidence,
            consecutiveFrames: observation.consecutiveFrameCount,
            isRequested: observation.observation.isRequested,
            frameUsable: frameUsable
        )
    }

    func validateNarration(
        _ text: String,
        contentKind: NarrationContentKind = .scene,
        isVerbatim: Bool = false
    ) -> VisionSafetyValidation {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return VisionSafetyValidation(isAllowed: false, violations: ["empty narration"])
        }

        // OCR and barcode payloads can contain arbitrary words. They are permitted only when
        // explicitly typed as verbatim content; callers must never execute them as commands.
        if isVerbatim, contentKind == .reading || contentKind == .barcode {
            return VisionSafetyValidation(isAllowed: true, violations: [])
        }

        let normalized = normalize(trimmed)
        var violations: [String] = []
        for rule in Self.prohibitedRules where Self.matches(normalized, pattern: rule.pattern) {
            violations.append(rule.label)
        }

        return VisionSafetyValidation(isAllowed: violations.isEmpty, violations: violations)
    }

    func safeNarration(
        _ proposed: String,
        fallback: String = "I cannot provide a reliable description from this image."
    ) -> String {
        if validateNarration(proposed).isAllowed {
            return proposed
        }
        if validateNarration(fallback).isAllowed {
            return fallback
        }
        return "I cannot verify that."
    }

    func qualifiedAbsence(region: SpatialRegion? = nil) -> String {
        let location = region.map { " \($0.spokenLocation)" } ?? ""
        return "I do not detect a supported object\(location) right now, but I may be missing something."
    }

    func isQualifiedAbsence(_ text: String) -> Bool {
        let normalized = normalize(text)
        let describesAbsence = normalized.contains("do not detect") ||
            normalized.contains("did not detect") ||
            normalized.contains("have not found")
        let includesUncertainty = normalized.contains("may be missing") ||
            normalized.contains("cannot verify") ||
            normalized.contains("not confident")
        return !describesAbsence || includesUncertainty
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static let prohibitedRules: [(label: String, pattern: String)] = [
        (
            "navigation safety claim",
            #"\b(the\s+)?(path|road|street|crosswalk)\s+(is|looks|appears)\s+(safe|clear)\b"#
        ),
        (
            "crossing or proceeding instruction",
            #"\b(safe\s+to|you\s+can)\s+(cross|proceed|continue|go|go\s+ahead)\b"#
        ),
        (
            "all-clear claim",
            #"\b(all\s+clear|nothing\s+(is\s+)?(ahead|in\s+front|there))\b"#
        ),
        (
            "unsupported absence guarantee",
            #"\b(there\s+(are|is)|i\s+(see|detect))\s+no\s+(obstacles?|hazards?|vehicles?|people|persons?)\b"#
        ),
        (
            "certainty guarantee",
            #"\b(definitely|certainly|guaranteed|infallible)\b"#
        ),
        (
            "unsupported precise visual distance",
            #"\b\d+(\.\d+)?\s*(feet|foot|ft|inches|inch|meters|meter|metres|metre|yards|yard)\b"#
        )
    ]

    private static func matches(_ value: String, pattern: String) -> Bool {
        guard let expression = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return false
        }
        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        return expression.firstMatch(in: value, options: [], range: range) != nil
    }
}
