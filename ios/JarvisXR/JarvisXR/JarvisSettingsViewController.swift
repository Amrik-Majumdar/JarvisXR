import UIKit

enum JarvisSettingsSection {
    case general
    case vision
}

final class JarvisSettingsViewController: UIViewController {
    private let initialSection: JarvisSettingsSection
    private let preferencesStore = VisionPreferencesStore.shared
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    private let speechSwitch = UISwitch()
    private let voiceProfileControl = UISegmentedControl(items: ["Natural", "Friendly", "Crisp", "Quiet", "Formal"])
    private let narrationControl = UISegmentedControl(items: ["Concise", "Standard", "Detailed"])
    private let cameraControl = UISegmentedControl(items: ["Rear", "Front"])
    private let defaultModeControl = UISegmentedControl(items: ["Describe", "Live", "Find", "Read", "Scan"])
    private let sensitivityControl = UISegmentedControl(items: ["Conservative", "Balanced", "Sensitive"])
    private let processingControl = UISegmentedControl(items: ["Auto", "Standard", "Reduced"])
    private let importantChangesSwitch = UISwitch()
    private let screenAwakeSwitch = UISwitch()
    private let hapticsSwitch = UISwitch()
    private let directionSpeechSwitch = UISwitch()
    private let sessionMemorySwitch = UISwitch()
    private let autoLightSwitch = UISwitch()
    private let debugOverlaySwitch = UISwitch()
    private let hapticIntensityControl = UISegmentedControl(items: ["Reduced", "Standard", "Strong"])

    init(initialSection: JarvisSettingsSection = .general) {
        self.initialSection = initialSection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        initialSection = .general
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = initialSection == .vision ? "Vision Settings" : "Settings"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
        loadValues()
    }

    private func buildInterface() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "jarvis.settings.scroll"
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 14

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
        ])

        let header = textLabel(
            initialSection == .vision ? "Accessible Vision preferences" : "JARVIS preferences",
            style: .title2,
            color: JarvisTheme.text
        )
        header.accessibilityTraits.insert(.header)
        header.accessibilityIdentifier = "jarvis.settings.header"
        stackView.addArrangedSubview(header)

        configureSwitch(
            speechSwitch,
            label: "Speech Output",
            hint: "Speaks JARVIS and Vision results.",
            identifier: "jarvis.settings.speechSwitch",
            action: #selector(speechChanged)
        )
        stackView.addArrangedSubview(settingRow(title: "Speech Output", control: speechSwitch, identifier: "jarvis.settings.speechLabel"))

        configureSegmented(voiceProfileControl, identifier: "jarvis.settings.voiceProfile", action: #selector(profileChanged))
        stackView.addArrangedSubview(settingPanel(title: "Voice Profile", detail: "Changes the local system voice pace, pitch, and volume.", control: voiceProfileControl))

        stackView.addArrangedSubview(sectionHeading("Vision narration"))
        configureSegmented(defaultModeControl, identifier: "jarvis.settings.vision.defaultMode", action: #selector(defaultModeChanged))
        stackView.addArrangedSubview(settingPanel(title: "Default Vision Mode", detail: "Used when opening Vision without a specific command.", control: defaultModeControl))
        configureSegmented(narrationControl, identifier: "jarvis.settings.vision.verbosity", action: #selector(narrationChanged))
        stackView.addArrangedSubview(settingPanel(title: "Detail Level", detail: "Choose shorter updates or more grounded scene detail.", control: narrationControl))
        configureSwitch(importantChangesSwitch, label: "Only Important Changes", hint: "Suppresses low-priority Live Guide narration.", identifier: "jarvis.settings.vision.importantChanges", action: #selector(importantChangesChanged))
        stackView.addArrangedSubview(settingRow(title: "Only Important Changes", control: importantChangesSwitch))
        configureSwitch(directionSpeechSwitch, label: "Speak Direction", hint: "Adds broad left, center, and right guidance.", identifier: "jarvis.settings.vision.directionSpeech", action: #selector(directionSpeechChanged))
        stackView.addArrangedSubview(settingRow(title: "Speak Direction", control: directionSpeechSwitch))

        stackView.addArrangedSubview(sectionHeading("Camera and Live Guide"))
        configureSegmented(cameraControl, identifier: "jarvis.settings.vision.camera", action: #selector(cameraChanged))
        stackView.addArrangedSubview(settingPanel(title: "Camera", detail: "Rear camera is recommended for understanding surroundings.", control: cameraControl))
        configureSwitch(screenAwakeSwitch, label: "Keep Screen Awake in Live Guide", hint: "Prevents screen lock only while Live Guide is active in the foreground.", identifier: "jarvis.settings.vision.screenAwake", action: #selector(screenAwakeChanged))
        stackView.addArrangedSubview(settingRow(title: "Keep Screen Awake in Live Guide", control: screenAwakeSwitch))
        configureSwitch(autoLightSwitch, label: "Suggest More Light", hint: "Allows camera-quality guidance to suggest the flashlight. It never turns on automatically.", identifier: "jarvis.settings.vision.autoLight", action: #selector(autoLightChanged))
        stackView.addArrangedSubview(settingRow(title: "Suggest More Light", control: autoLightSwitch))
        configureSegmented(sensitivityControl, identifier: "jarvis.settings.vision.sensitivity", action: #selector(sensitivityChanged))
        stackView.addArrangedSubview(settingPanel(title: "Detection Sensitivity", detail: "Conservative requires stronger, more stable evidence. More sensitive can increase false detections.", control: sensitivityControl))
        configureSegmented(processingControl, identifier: "jarvis.settings.vision.processing", action: #selector(processingChanged))
        stackView.addArrangedSubview(settingPanel(title: "Processing", detail: "Automatic adapts for heat and Low Power Mode. Reduced uses fewer analyses.", control: processingControl))

        stackView.addArrangedSubview(sectionHeading("Haptics"))
        configureSwitch(hapticsSwitch, label: "Vision Haptics", hint: "Provides direction, target, warning, and completion patterns.", identifier: "jarvis.settings.vision.haptics", action: #selector(hapticsChanged))
        stackView.addArrangedSubview(settingRow(title: "Vision Haptics", control: hapticsSwitch))
        configureSegmented(hapticIntensityControl, identifier: "jarvis.settings.vision.hapticIntensity", action: #selector(hapticIntensityChanged))
        stackView.addArrangedSubview(settingPanel(title: "Haptic Intensity", detail: "Adjusts Vision patterns when haptics are enabled.", control: hapticIntensityControl))
        let hapticTutorialButton = actionButton("Try Haptic Tutorial", identifier: "jarvis.settings.vision.hapticTutorial", action: #selector(hapticTutorialTapped))
        stackView.addArrangedSubview(hapticTutorialButton)

        stackView.addArrangedSubview(sectionHeading("Privacy and diagnostics"))
        configureSwitch(sessionMemorySwitch, label: "Temporary Session Memory", hint: "Keeps short-lived scene changes until Vision stops. Images are never stored in session memory.", identifier: "jarvis.settings.vision.sessionMemory", action: #selector(sessionMemoryChanged))
        stackView.addArrangedSubview(settingRow(title: "Temporary Session Memory", control: sessionMemorySwitch))
        configureSwitch(debugOverlaySwitch, label: "Diagnostics Overlay", hint: "Shows advanced diagnostic details. Off by default.", identifier: "jarvis.settings.vision.debugOverlay", action: #selector(debugOverlayChanged))
        stackView.addArrangedSubview(settingRow(title: "Diagnostics Overlay", control: debugOverlaySwitch))

        let privacy = textLabel(
            "Privacy defaults cannot be disabled: camera images and video are not automatically saved, recognized text and barcode values are not added to general history, and core Vision analysis stays on device.",
            style: .body,
            color: JarvisTheme.text
        )
        privacy.accessibilityIdentifier = "jarvis.settings.vision.privacy"
        let privacyPanel = wrapInPanel(privacy)
        privacyPanel.layer.borderColor = JarvisTheme.success.cgColor
        stackView.addArrangedSubview(privacyPanel)

        let selfTestButton = actionButton("Run Accessible Vision Self-Test", identifier: "jarvis.settings.vision.selfTest", action: #selector(selfTestTapped))
        let diagnosticsButton = actionButton("Open Diagnostics", identifier: "jarvis.settings.diagnostics", action: #selector(diagnosticsTapped))
        stackView.addArrangedSubview(horizontalRow([selfTestButton, diagnosticsButton]))

        stackView.addArrangedSubview(sectionHeading("Local data and voice tools"))
        let clearNotesButton = actionButton("Clear Notes", identifier: "jarvis.settings.clearNotes", action: #selector(clearNotesTapped))
        let clearHistoryButton = actionButton("Clear History", identifier: "jarvis.settings.clearHistory", action: #selector(clearHistoryTapped))
        stackView.addArrangedSubview(horizontalRow([clearNotesButton, clearHistoryButton]))

        let voiceTestButton = actionButton("Voice Test", identifier: "jarvis.settings.voiceTest", action: #selector(voiceTestTapped))
        let profilePreviewButton = actionButton("Preview Profiles", identifier: "jarvis.settings.profilePreview", action: #selector(profilePreviewTapped))
        stackView.addArrangedSubview(horizontalRow([voiceTestButton, profilePreviewButton]))

        let personalVoiceButton = actionButton("Personal Voice", identifier: "jarvis.settings.personalVoice", action: #selector(personalVoiceTapped))
        let aboutButton = actionButton("About", identifier: "jarvis.settings.about", action: #selector(aboutTapped))
        stackView.addArrangedSubview(horizontalRow([personalVoiceButton, aboutButton]))

        let resetButton = actionButton("Reset Vision Settings", identifier: "jarvis.settings.vision.reset", action: #selector(resetVisionTapped))
        resetButton.setTitleColor(JarvisTheme.warning, for: .normal)
        stackView.addArrangedSubview(resetButton)

        // Compatibility identifier retained for existing UI automation while the
        // content now comes from real controls and stores rather than a fixed text page.
        let compatibilityText = textLabel("JARVIS appliance settings", style: .caption1, color: JarvisTheme.mutedText)
        compatibilityText.accessibilityIdentifier = "jarvis.settings.text"
        stackView.addArrangedSubview(compatibilityText)
    }

    private func loadValues() {
        let preferences = preferencesStore.value
        speechSwitch.isOn = JarvisSpeechService.shared.isEnabled
        voiceProfileControl.selectedSegmentIndex = index(for: JarvisSpeechService.shared.profile)
        narrationControl.selectedSegmentIndex = index(for: preferences.narrationVerbosity)
        defaultModeControl.selectedSegmentIndex = index(for: preferences.defaultMode)
        cameraControl.selectedSegmentIndex = preferences.cameraChoice == .rear ? 0 : 1
        sensitivityControl.selectedSegmentIndex = index(for: preferences.detectionSensitivity)
        processingControl.selectedSegmentIndex = index(for: preferences.processingPreference)
        importantChangesSwitch.isOn = preferences.importantChangesOnly
        screenAwakeSwitch.isOn = preferences.keepScreenAwakeDuringLiveGuide
        hapticsSwitch.isOn = preferences.hapticsEnabled
        directionSpeechSwitch.isOn = preferences.directionSpeechEnabled
        sessionMemorySwitch.isOn = preferences.temporarySessionMemoryEnabled
        autoLightSwitch.isOn = preferences.automaticFlashlightSuggestion
        debugOverlaySwitch.isOn = preferences.debugOverlayEnabled
        hapticIntensityControl.selectedSegmentIndex = index(for: preferences.hapticIntensity)
    }

    private func configureSwitch(_ control: UISwitch, label: String, hint: String, identifier: String, action: Selector) {
        control.addTarget(self, action: action, for: .valueChanged)
        control.accessibilityLabel = label
        control.accessibilityHint = hint
        control.accessibilityIdentifier = identifier
    }

    private func configureSegmented(_ control: UISegmentedControl, identifier: String, action: Selector) {
        control.selectedSegmentTintColor = JarvisTheme.accent
        control.setTitleTextAttributes([.foregroundColor: JarvisTheme.text], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: JarvisTheme.background], for: .selected)
        control.addTarget(self, action: action, for: .valueChanged)
        control.accessibilityIdentifier = identifier
        control.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
    }

    private func settingRow(title: String, control: UIView, identifier: String? = nil) -> UIView {
        let label = textLabel(title, style: .body, color: JarvisTheme.text)
        label.accessibilityIdentifier = identifier
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let row = UIStackView(arrangedSubviews: [label, control])
        row.axis = .horizontal
        row.alignment = .center
        row.spacing = 12
        row.distribution = .equalSpacing
        let panel = wrapInPanel(row)
        panel.accessibilityElements = [control]
        return panel
    }

    private func settingPanel(title: String, detail: String, control: UIView) -> UIView {
        let heading = textLabel(title, style: .headline, color: JarvisTheme.text)
        heading.accessibilityTraits.insert(.header)
        let detailLabel = textLabel(detail, style: .footnote, color: JarvisTheme.mutedText)
        let stack = UIStackView(arrangedSubviews: [heading, detailLabel, control])
        stack.axis = .vertical
        stack.spacing = 8
        return wrapInPanel(stack)
    }

    private func sectionHeading(_ title: String) -> UILabel {
        let label = textLabel(title, style: .title3, color: JarvisTheme.accentHot)
        label.accessibilityTraits.insert(.header)
        return label
    }

    private func wrapInPanel(_ content: UIView) -> JarvisPanelView {
        let panel = JarvisPanelView()
        content.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(content)
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            content.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            content.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            content.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])
        return panel
    }

    private func horizontalRow(_ views: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    private func actionButton(_ title: String, identifier: String, action: Selector) -> UIButton {
        let button = JarvisTheme.button(title: title)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func textLabel(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = UIFont.preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    @objc private func speechChanged() {
        JarvisSpeechService.shared.isEnabled = speechSwitch.isOn
        if speechSwitch.isOn {
            JarvisSpeechService.shared.speak("Speech output enabled.")
        } else {
            JarvisSpeechService.shared.stop()
        }
    }

    @objc private func profileChanged() {
        switch voiceProfileControl.selectedSegmentIndex {
        case 1: JarvisSpeechService.shared.profile = .friendly
        case 2: JarvisSpeechService.shared.profile = .crisp
        case 3: JarvisSpeechService.shared.profile = .quiet
        case 4: JarvisSpeechService.shared.profile = .formal
        default: JarvisSpeechService.shared.profile = .natural
        }
        JarvisSpeechService.shared.speak(JarvisSpeechService.shared.testPhrase())
    }

    @objc private func narrationChanged() {
        let value: NarrationVerbosity = narrationControl.selectedSegmentIndex == 0 ? .concise : (narrationControl.selectedSegmentIndex == 2 ? .detailed : .standard)
        preferencesStore.update { $0.narrationVerbosity = value }
    }

    @objc private func defaultModeChanged() {
        let modes: [VisionMode] = [.describe, .liveGuide, .find, .readText, .scanBarcode]
        preferencesStore.update { $0.defaultMode = modes[min(max(defaultModeControl.selectedSegmentIndex, 0), modes.count - 1)] }
    }

    @objc private func cameraChanged() {
        preferencesStore.update { $0.cameraChoice = cameraControl.selectedSegmentIndex == 0 ? .rear : .front }
    }

    @objc private func importantChangesChanged() { preferencesStore.update { $0.importantChangesOnly = importantChangesSwitch.isOn } }
    @objc private func screenAwakeChanged() { preferencesStore.update { $0.keepScreenAwakeDuringLiveGuide = screenAwakeSwitch.isOn } }
    @objc private func hapticsChanged() { preferencesStore.update { $0.hapticsEnabled = hapticsSwitch.isOn } }
    @objc private func directionSpeechChanged() { preferencesStore.update { $0.directionSpeechEnabled = directionSpeechSwitch.isOn } }
    @objc private func sessionMemoryChanged() { preferencesStore.update { $0.temporarySessionMemoryEnabled = sessionMemorySwitch.isOn } }
    @objc private func autoLightChanged() { preferencesStore.update { $0.automaticFlashlightSuggestion = autoLightSwitch.isOn } }
    @objc private func debugOverlayChanged() { preferencesStore.update { $0.debugOverlayEnabled = debugOverlaySwitch.isOn } }

    @objc private func hapticIntensityChanged() {
        let value: VisionHapticIntensity = hapticIntensityControl.selectedSegmentIndex == 0 ? .reduced : (hapticIntensityControl.selectedSegmentIndex == 2 ? .strong : .standard)
        preferencesStore.update { $0.hapticIntensity = value }
    }

    @objc private func sensitivityChanged() {
        let value: VisionDetectionSensitivity = sensitivityControl.selectedSegmentIndex == 0 ? .conservative : (sensitivityControl.selectedSegmentIndex == 2 ? .moreSensitive : .balanced)
        preferencesStore.update { $0.detectionSensitivity = value }
    }

    @objc private func processingChanged() {
        let value: VisionProcessingPreference = processingControl.selectedSegmentIndex == 0 ? .automatic : (processingControl.selectedSegmentIndex == 2 ? .reducedPower : .standard)
        preferencesStore.update { $0.processingPreference = value }
    }

    @objc private func hapticTutorialTapped() {
        guard preferencesStore.value.hapticsEnabled else {
            accessibleAlert(title: "Haptics Are Off", message: "Enable Vision Haptics before starting the tutorial.")
            return
        }
        let sessionID = VisionHapticsService.shared.beginSession()
        let intensity = preferencesStore.value.hapticIntensity
        let cues: [(VisionHapticCue, String)] = [
            (.directionLeft, "Left"),
            (.directionCenter, "Center"),
            (.directionRight, "Right"),
            (.targetAcquired, "Target found"),
            (.targetLost, "Target lost"),
            (.warning, "Warning"),
        ]
        for (index, item) in cues.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.75) {
                UIAccessibility.post(notification: .announcement, argument: item.1)
                VisionHapticsService.shared.play(item.0, intensity: intensity, sessionID: sessionID)
                if index == cues.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        VisionHapticsService.shared.endSession(sessionID)
                    }
                }
            }
        }
    }

    @objc private func clearNotesTapped() {
        confirm(title: "Clear notes?", message: "This removes local JARVIS notes stored on this device.") {
            JarvisMemoryStore.shared.clearNotes()
        }
    }

    @objc private func clearHistoryTapped() {
        confirm(title: "Clear history?", message: "This removes local command history. Vision OCR and barcode results are not stored there.") {
            JarvisMemoryStore.shared.clearHistory()
        }
    }

    @objc private func voiceTestTapped() { JarvisSpeechService.shared.speak(JarvisSpeechService.shared.testPhrase()) }
    @objc private func profilePreviewTapped() { JarvisSpeechService.shared.previewAllProfiles() }

    @objc private func personalVoiceTapped() {
        JarvisSpeechService.shared.personalVoiceStatusText { [weak self] message in
            guard let self else { return }
            let alert = UIAlertController(title: "Personal Voice", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Use If Available", style: .default) { _ in JarvisSpeechService.shared.prefersPersonalVoice = true })
            alert.addAction(UIAlertAction(title: "Use System Voice", style: .default) { _ in JarvisSpeechService.shared.prefersPersonalVoice = false })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }

    @objc private func selfTestTapped() {
        navigationController?.pushViewController(JarvisVisionSelfTestViewController(), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    @objc private func diagnosticsTapped() {
        navigationController?.pushViewController(JarvisDiagnosticsViewController(), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    @objc private func aboutTapped() {
        navigationController?.pushViewController(JarvisAboutViewController(), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    @objc private func resetVisionTapped() {
        confirm(title: "Reset Vision settings?", message: "This restores accessible Vision defaults. It does not change camera permission in iOS Settings.") { [weak self] in
            self?.preferencesStore.reset()
            self?.loadValues()
        }
    }

    private func confirm(title: String, message: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: .destructive) { _ in action() })
        present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    private func accessibleAlert(title: String, message: String) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    private func index(for profile: JarvisVoiceProfile) -> Int {
        switch profile {
        case .natural: return 0
        case .friendly: return 1
        case .crisp: return 2
        case .quiet: return 3
        case .formal: return 4
        }
    }

    private func index(for verbosity: NarrationVerbosity) -> Int {
        switch verbosity {
        case .concise: return 0
        case .standard: return 1
        case .detailed: return 2
        }
    }

    private func index(for intensity: VisionHapticIntensity) -> Int {
        switch intensity {
        case .reduced: return 0
        case .standard: return 1
        case .strong: return 2
        }
    }

    private func index(for mode: VisionMode) -> Int {
        switch mode {
        case .liveGuide: return 1
        case .find: return 2
        case .readText: return 3
        case .scanBarcode: return 4
        default: return 0
        }
    }

    private func index(for sensitivity: VisionDetectionSensitivity) -> Int {
        switch sensitivity {
        case .conservative: return 0
        case .balanced: return 1
        case .moreSensitive: return 2
        }
    }

    private func index(for processing: VisionProcessingPreference) -> Int {
        switch processing {
        case .automatic: return 0
        case .standard: return 1
        case .reducedPower: return 2
        }
    }
}
