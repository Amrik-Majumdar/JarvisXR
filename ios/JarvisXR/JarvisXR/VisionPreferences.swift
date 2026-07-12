import Foundation

enum VisionDetectionSensitivity: String, Codable, CaseIterable, Sendable {
    case conservative
    case balanced
    case moreSensitive

    var safetyConfiguration: VisionSafetyConfiguration {
        switch self {
        case .conservative: return .conservative
        case .balanced: return .balanced
        case .moreSensitive: return .moreSensitive
        }
    }

    var explanation: String {
        switch self {
        case .conservative:
            return "Requires stronger, more stable detections and may omit uncertain objects."
        case .balanced:
            return "Balances missed detections with false detections."
        case .moreSensitive:
            return "Reports weaker detections and may produce more false detections."
        }
    }
}

enum VisionHapticIntensity: String, Codable, CaseIterable, Sendable {
    case reduced
    case standard
    case strong

    var scale: Float {
        switch self {
        case .reduced: return 0.48
        case .standard: return 0.72
        case .strong: return 1.0
        }
    }
}

enum VisionProcessingPreference: String, Codable, CaseIterable, Sendable {
    case automatic
    case standard
    case reducedPower
}

enum VisionCameraChoice: String, Codable, CaseIterable, Sendable {
    case rear
    case front
}

struct VisionPreferences: Codable, Equatable, Sendable {
    var defaultMode: VisionMode
    var narrationVerbosity: NarrationVerbosity
    var importantChangesOnly: Bool
    var speechRate: Float
    var automaticFlashlightSuggestion: Bool
    var hapticsEnabled: Bool
    var hapticIntensity: VisionHapticIntensity
    var directionSpeechEnabled: Bool
    var earconsEnabled: Bool
    var detectionSensitivity: VisionDetectionSensitivity
    var processingPreference: VisionProcessingPreference
    var keepScreenAwakeDuringLiveGuide: Bool
    var cameraChoice: VisionCameraChoice
    var temporarySessionMemoryEnabled: Bool
    var debugOverlayEnabled: Bool

    /// Privacy invariants are intentionally not configurable in normal settings.
    let storesCapturedImages = false
    let storesCapturedVideo = false
    let persistsRecognizedText = false
    let allowsNetworkVisionProcessing = false

    private enum CodingKeys: String, CodingKey {
        case defaultMode
        case narrationVerbosity
        case importantChangesOnly
        case speechRate
        case automaticFlashlightSuggestion
        case hapticsEnabled
        case hapticIntensity
        case directionSpeechEnabled
        case earconsEnabled
        case detectionSensitivity
        case processingPreference
        case keepScreenAwakeDuringLiveGuide
        case cameraChoice
        case temporarySessionMemoryEnabled
        case debugOverlayEnabled
    }

    static let `default` = VisionPreferences()

    init(
        defaultMode: VisionMode = .describe,
        narrationVerbosity: NarrationVerbosity = .standard,
        importantChangesOnly: Bool = true,
        speechRate: Float = 0.46,
        automaticFlashlightSuggestion: Bool = true,
        hapticsEnabled: Bool = true,
        hapticIntensity: VisionHapticIntensity = .standard,
        directionSpeechEnabled: Bool = true,
        earconsEnabled: Bool = false,
        detectionSensitivity: VisionDetectionSensitivity = .conservative,
        processingPreference: VisionProcessingPreference = .automatic,
        keepScreenAwakeDuringLiveGuide: Bool = true,
        cameraChoice: VisionCameraChoice = .rear,
        temporarySessionMemoryEnabled: Bool = true,
        debugOverlayEnabled: Bool = false
    ) {
        self.defaultMode = defaultMode
        self.narrationVerbosity = narrationVerbosity
        self.importantChangesOnly = importantChangesOnly
        self.speechRate = min(max(speechRate, 0.35), 0.55)
        self.automaticFlashlightSuggestion = automaticFlashlightSuggestion
        self.hapticsEnabled = hapticsEnabled
        self.hapticIntensity = hapticIntensity
        self.directionSpeechEnabled = directionSpeechEnabled
        self.earconsEnabled = earconsEnabled
        self.detectionSensitivity = detectionSensitivity
        self.processingPreference = processingPreference
        self.keepScreenAwakeDuringLiveGuide = keepScreenAwakeDuringLiveGuide
        self.cameraChoice = cameraChoice
        self.temporarySessionMemoryEnabled = temporarySessionMemoryEnabled
        self.debugOverlayEnabled = debugOverlayEnabled
    }
}
