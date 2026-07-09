import UIKit
import AVFoundation
import CoreMotion

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

    private func buildInterface() {
        textView.isEditable = false
        textView.textColor = JarvisTheme.text
        textView.font = JarvisTheme.bodyFont(size: 14)
        textView.accessibilityIdentifier = "jarvis.diagnostics.text"
        JarvisTheme.stylePanel(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(textView)

        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func refresh() {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let percent = level >= 0 ? "\(Int(level * 100))%" : "unavailable"
        let batteryState: String
        switch UIDevice.current.batteryState {
        case .charging: batteryState = "charging"
        case .full: batteryState = "full"
        case .unplugged: batteryState = "unplugged"
        default: batteryState = "unknown"
        }

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.1"
        let notes = JarvisMemoryStore.shared.loadNotes().count
        let history = JarvisMemoryStore.shared.loadHistory().count
        let guided = UIAccessibility.isGuidedAccessEnabled ? "active" : "ready when enabled"
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? "enabled" : "disabled"
        let speech = JarvisSpeechService.shared.isEnabled ? "enabled" : "disabled"
        let voiceInput = "available after microphone and Speech permission are granted."
        let motion = motionManager.isDeviceMotionAvailable ? "available" : "unavailable"
        let accelerometer = motionManager.isAccelerometerAvailable ? "available" : "unavailable"
        let gyro = motionManager.isGyroAvailable ? "available" : "unavailable"
        let magnetometer = motionManager.isMagnetometerAvailable ? "available" : "unavailable"
        let orientation = UIDevice.current.orientation.isValidInterfaceOrientation ? "\(UIDevice.current.orientation)" : "portrait app surface active"
        let coreML = "Vision OCR, barcode scan, and image classification run after capture. \(JarvisObjectDetectionModel.diagnosticLine())"
        let controlMesh = "active. URL scheme, Voice Control setup, Shortcuts setup, and App Intents source are present."
        let camera: String
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: camera = "authorized"
        case .notDetermined: camera = "not requested"
        case .denied: camera = "denied"
        case .restricted: camera = "restricted"
        @unknown default: camera = "unknown"
        }

        textView.text = """
        Hardware Status

        Device model: \(UIDevice.current.model)
        System version: \(UIDevice.current.systemVersion)
        Camera: \(camera)
        Voice output: \(speech)
        Voice input: \(voiceInput)
        Motion sensors: \(motion)
        Vision and Core ML: \(coreML)
        Control Mesh: \(controlMesh)
        Guided Access readiness: \(guided)

        Device diagnostics
        Battery level: \(percent)
        Battery state: \(batteryState)
        Low Power Mode: \(lowPower)
        Orientation: \(orientation)
        App version: \(version)
        Notes count: \(notes)
        Command history count: \(history)
        Accelerometer: \(accelerometer)
        Gyroscope: \(gyro)
        Magnetometer or compass source: \(magnetometer)
        Install mode: sideloaded unsigned IPA path

        Boundary:
        No system UI ownership, lock screen control, background daemon install, arbitrary app control, or true OS ownership is claimed.
        """
    }
}
