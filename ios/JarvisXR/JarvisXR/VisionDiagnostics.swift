import Foundation

enum VisionAuthorizationState: String, Codable, CaseIterable, Sendable {
    case notDetermined
    case authorized
    case denied
    case restricted
    case unavailable
}

enum VisionThermalState: String, Codable, CaseIterable, Sendable {
    case unknown
    case nominal
    case fair
    case serious
    case critical
}

enum VisionProcessingProfile: String, Codable, CaseIterable, Sendable {
    case stopped
    case full
    case balanced
    case reduced
    case targetOnly
}

struct VisionDiagnosticsSnapshot: Codable, Equatable, Sendable {
    var cameraPermission: VisionAuthorizationState
    var microphonePermission: VisionAuthorizationState
    var speechRecognitionPermission: VisionAuthorizationState
    var activeCamera: VisionCameraChoice?
    var cameraSessionState: VisionSessionState
    var activeVisionMode: VisionMode
    var lastVisionMode: VisionMode?
    var modelLoaded: Bool
    var modelMetadata: ModelMetadata?
    var ocrAvailable: Bool
    var barcodeAvailable: Bool
    var hapticsAvailable: Bool
    var hapticsBackend: VisionHapticsBackendKind
    var thermalState: VisionThermalState
    var processingProfile: VisionProcessingProfile
    var inferenceMetrics: InferenceMetrics
    var lastFrameCondition: CameraFrameCondition?
    var lastFrameWidth: Int?
    var lastFrameHeight: Int?
    var lastPixelFormat: UInt32?
    var lastFrameBrightness: Double?
    var lastFrameSharpness: Double?
    var obstructionEvidenceFrames: Int
    var lastFrameEvaluatedAt: Date?
    var lastRecoverableError: String?
    var offlinePrivacyEnabled: Bool
    var applicationBuildVersion: String
    var updatedAt: Date
}

final class VisionDiagnosticsStore: @unchecked Sendable {
    static let shared = VisionDiagnosticsStore()

    private let lock = NSLock()
    private var value: VisionDiagnosticsSnapshot

    init(applicationBuildVersion: String? = nil) {
        let version = applicationBuildVersion ??
            (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown")
        value = VisionDiagnosticsSnapshot(
            cameraPermission: .notDetermined,
            microphonePermission: .notDetermined,
            speechRecognitionPermission: .notDetermined,
            activeCamera: nil,
            cameraSessionState: .idle,
            activeVisionMode: .inactive,
            lastVisionMode: nil,
            modelLoaded: false,
            modelMetadata: nil,
            ocrAvailable: false,
            barcodeAvailable: false,
            hapticsAvailable: false,
            hapticsBackend: .unavailable,
            thermalState: .unknown,
            processingProfile: .stopped,
            inferenceMetrics: InferenceMetrics(),
            lastFrameCondition: nil,
            lastFrameWidth: nil,
            lastFrameHeight: nil,
            lastPixelFormat: nil,
            lastFrameBrightness: nil,
            lastFrameSharpness: nil,
            obstructionEvidenceFrames: 0,
            lastFrameEvaluatedAt: nil,
            lastRecoverableError: nil,
            offlinePrivacyEnabled: true,
            applicationBuildVersion: version,
            updatedAt: Date()
        )
    }

    func snapshot() -> VisionDiagnosticsSnapshot {
        withLock { value }
    }

    func setPermissions(
        camera: VisionAuthorizationState? = nil,
        microphone: VisionAuthorizationState? = nil,
        speechRecognition: VisionAuthorizationState? = nil
    ) {
        mutate {
            if let camera { $0.cameraPermission = camera }
            if let microphone { $0.microphonePermission = microphone }
            if let speechRecognition { $0.speechRecognitionPermission = speechRecognition }
        }
    }

    func setActiveCamera(_ camera: VisionCameraChoice?) {
        mutate { $0.activeCamera = camera }
    }

    func setCameraSessionState(_ state: VisionSessionState) {
        mutate { $0.cameraSessionState = state }
    }

    func setActive(mode: VisionMode, sessionState: VisionSessionState) {
        mutate {
            if mode != .inactive {
                $0.lastVisionMode = mode
            }
            $0.activeVisionMode = mode
            $0.cameraSessionState = sessionState
        }
    }

    func updateModel(metadata: ModelMetadata?, loaded: Bool) {
        mutate {
            $0.modelMetadata = metadata
            $0.modelLoaded = loaded && metadata?.checksumVerified == true
        }
    }

    func setAnalyzerAvailability(ocr: Bool, barcode: Bool) {
        mutate {
            $0.ocrAvailable = ocr
            $0.barcodeAvailable = barcode
        }
    }

    func setHapticsAvailability(_ available: Bool, backend: VisionHapticsBackendKind) {
        mutate {
            $0.hapticsAvailable = available
            $0.hapticsBackend = backend
        }
    }

    func setThermalState(_ thermalState: VisionThermalState, profile: VisionProcessingProfile) {
        mutate {
            $0.thermalState = thermalState
            $0.processingProfile = profile
        }
    }

    func setProcessingProfile(_ profile: VisionProcessingProfile) {
        mutate { $0.processingProfile = profile }
    }

    func recordModelLoad(duration: TimeInterval) {
        guard duration.isFinite, duration >= 0 else { return }
        mutate { $0.inferenceMetrics.modelLoadDuration = duration }
    }

    func recordInference(latency: TimeInterval, droppedFrames: Int = 0, at date: Date = Date()) {
        mutate {
            $0.inferenceMetrics.recordInference(duration: latency, droppedFrames: droppedFrames, at: date)
        }
    }

    func recordDroppedFrame(count: Int = 1) {
        guard count > 0 else { return }
        mutate { $0.inferenceMetrics.droppedFrameCount += count }
    }

    func recordNarrationDelay(_ duration: TimeInterval) {
        guard duration.isFinite, duration >= 0 else { return }
        mutate { $0.inferenceMetrics.narrationDelay = duration }
    }

    func record(frameQuality: CameraQualityReport) {
        mutate {
            $0.lastFrameCondition = frameQuality.condition
            $0.lastFrameWidth = frameQuality.frameWidth > 0 ? frameQuality.frameWidth : nil
            $0.lastFrameHeight = frameQuality.frameHeight > 0 ? frameQuality.frameHeight : nil
            $0.lastPixelFormat = frameQuality.pixelFormat
            $0.lastFrameBrightness = frameQuality.brightness
            $0.lastFrameSharpness = frameQuality.sharpness
            $0.obstructionEvidenceFrames = frameQuality.obstructionEvidenceFrames
            $0.lastFrameEvaluatedAt = frameQuality.evaluatedAt
        }
    }

    func record(error: VisionError) {
        mutate { $0.lastRecoverableError = String(describing: error) }
    }

    func clearLastError() {
        mutate { $0.lastRecoverableError = nil }
    }

    private func mutate(_ work: (inout VisionDiagnosticsSnapshot) -> Void) {
        withLock {
            work(&value)
            value.updatedAt = Date()
        }
    }

    @discardableResult
    private func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
