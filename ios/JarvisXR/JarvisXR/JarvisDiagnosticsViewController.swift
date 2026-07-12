import AVFoundation
import CoreMotion
import UIKit

final class JarvisDiagnosticsViewController: UIViewController {
    private let textView = UITextView()
    private let motionManager = CMMotionManager()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Diagnostics"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
        refresh()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refresh()
    }

    private func buildInterface() {
        let heading = UILabel()
        heading.text = "Jarvis and Vision status"
        heading.textColor = JarvisTheme.text
        heading.font = UIFont.preferredFont(forTextStyle: .title2)
        heading.adjustsFontForContentSizeCategory = true
        heading.numberOfLines = 0
        heading.accessibilityTraits.insert(.header)
        heading.accessibilityIdentifier = "jarvis.diagnostics.header"

        let explanation = UILabel()
        explanation.text = "Diagnostics shows current software state. It never displays recognized private text, barcode values, or camera frames."
        explanation.textColor = JarvisTheme.mutedText
        explanation.font = UIFont.preferredFont(forTextStyle: .body)
        explanation.adjustsFontForContentSizeCategory = true
        explanation.numberOfLines = 0

        textView.isEditable = false
        textView.isSelectable = true
        textView.textColor = JarvisTheme.text
        textView.font = UIFont.preferredFont(forTextStyle: .body)
        textView.adjustsFontForContentSizeCategory = true
        textView.accessibilityLabel = "Jarvis diagnostics report"
        textView.accessibilityIdentifier = "jarvis.diagnostics.text"
        textView.textContainerInset = UIEdgeInsets(top: 14, left: 12, bottom: 14, right: 12)
        JarvisTheme.stylePanel(textView)

        let refreshButton = JarvisTheme.button(title: "Refresh")
        refreshButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        refreshButton.titleLabel?.adjustsFontForContentSizeCategory = true
        refreshButton.accessibilityHint = "Reads current camera, model, performance, and accessibility state."
        refreshButton.accessibilityIdentifier = "jarvis.diagnostics.refresh"
        refreshButton.addTarget(self, action: #selector(refreshTapped), for: .touchUpInside)

        let selfTestButton = JarvisTheme.button(title: "Vision Self-Test")
        selfTestButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        selfTestButton.titleLabel?.adjustsFontForContentSizeCategory = true
        selfTestButton.accessibilityHint = "Checks local software readiness without activating the camera."
        selfTestButton.accessibilityIdentifier = "jarvis.diagnostics.selfTest"
        selfTestButton.addTarget(self, action: #selector(selfTestTapped), for: .touchUpInside)

        let buttons = UIStackView(arrangedSubviews: [refreshButton, selfTestButton])
        buttons.axis = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [heading, explanation, buttons, textView])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -14),
        ])
    }

    private func refresh() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let batteryLevel = UIDevice.current.batteryLevel
        let battery = batteryLevel >= 0 ? "\(Int(batteryLevel * 100)) percent" : "unavailable"
        let snapshot = VisionDiagnosticsStore.shared.snapshot()
        let preferences = VisionPreferencesStore.shared.value
        let metadata = snapshot.modelMetadata

        let modelStatus: String
        if snapshot.modelLoaded, let metadata {
            modelStatus = "validated and loaded (\(metadata.name), version \(metadata.version))"
        } else if let metadata {
            modelStatus = "not ready (manifest \(metadata.name), checksum verified: \(yesNo(metadata.checksumVerified)))"
        } else {
            modelStatus = "not loaded or manifest not yet validated"
        }

        let latency: String
        if let value = snapshot.inferenceMetrics.lastInferenceDuration {
            latency = "\(Int(value * 1_000)) milliseconds on the current environment"
        } else {
            latency = "no recorded inference"
        }

        let lastError = snapshot.lastRecoverableError ?? "none"
        let camera = authorizationText(AVCaptureDevice.authorizationStatus(for: .video))
        let microphone = authorizationText(AVCaptureDevice.authorizationStatus(for: .audio))
        let speechOutput = JarvisSpeechService.shared.isEnabled ? "enabled" : "disabled"
        let guidedAccess = UIAccessibility.isGuidedAccessEnabled ? "active" : "not active"
        let reduceMotion = UIAccessibility.isReduceMotionEnabled ? "enabled" : "disabled"
        let darkerColors = UIAccessibility.isDarkerSystemColorsEnabled ? "enabled" : "disabled"
        let voiceOver = UIAccessibility.isVoiceOverRunning ? "running" : "not running"
        let screenAwake = preferences.keepScreenAwakeDuringLiveGuide ? "enabled for active Live Guide" : "disabled"

        textView.text = """
        VISION
        Camera permission: \(camera)
        Active camera: \(snapshot.activeCamera?.rawValue ?? "none")
        Camera session: \(snapshot.cameraSessionState.rawValue)
        Active mode: \(snapshot.activeVisionMode.visionDisplayName)
        Last mode: \(snapshot.lastVisionMode?.visionDisplayName ?? "none")
        Object model: \(modelStatus)
        OCR service: \(snapshot.ocrAvailable ? "available" : "not confirmed")
        Barcode service: \(snapshot.barcodeAvailable ? "available" : "not confirmed")
        Processing profile: \(snapshot.processingProfile.rawValue)
        Thermal state: \(snapshot.thermalState.rawValue)
        Last inference: \(latency)
        Frames analyzed: \(snapshot.inferenceMetrics.framesAnalyzed)
        Dropped frames: \(snapshot.inferenceMetrics.droppedFrameCount)
        Last recoverable error: \(lastError)

        ACCESSIBILITY AND AUDIO
        Speech output: \(speechOutput)
        Microphone permission: \(microphone)
        Haptics: \(snapshot.hapticsAvailable ? snapshot.hapticsBackend.rawValue : "unavailable; speech fallback")
        VoiceOver: \(voiceOver)
        Reduce Motion: \(reduceMotion)
        Increase Contrast: \(darkerColors)
        Guided Access: \(guidedAccess)
        Keep screen awake: \(screenAwake)

        PRIVACY
        Offline core Vision processing: \(yesNo(snapshot.offlinePrivacyEnabled))
        Save captured images: no
        Save captured video: no
        Persist recognized text: no
        Open barcode links automatically: no

        DEVICE AND APP
        Device: \(UIDevice.current.model)
        iOS: \(UIDevice.current.systemVersion)
        App version: \(snapshot.applicationBuildVersion)
        Battery: \(battery)
        Low Power Mode: \(ProcessInfo.processInfo.isLowPowerModeEnabled ? "enabled" : "disabled")
        Motion sensors: \(motionManager.isDeviceMotionAvailable ? "available" : "unavailable")
        Notes: \(JarvisMemoryStore.shared.loadNotes().count)
        General command history: \(JarvisMemoryStore.shared.loadHistory().count)

        Diagnostics does not prove physical iPhone XR camera accuracy, orientation, heat, battery life, Bluetooth routing, or haptic feel. Those checks require a human on the device.
        """
    }

    private func authorizationText(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .notDetermined: return "not requested"
        case .denied: return "denied"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
    }

    private func yesNo(_ value: Bool) -> String { value ? "yes" : "no" }

    @objc private func refreshTapped() {
        refresh()
        UIAccessibility.post(notification: .layoutChanged, argument: textView)
    }

    @objc private func selfTestTapped() {
        navigationController?.pushViewController(JarvisVisionSelfTestViewController(), animated: !UIAccessibility.isReduceMotionEnabled)
    }
}
