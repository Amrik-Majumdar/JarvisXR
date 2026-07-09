import UIKit

final class JarvisSettingsViewController: UIViewController {
    private let speechSwitch = UISwitch()
    private let voiceProfileControl = UISegmentedControl(items: ["Natural", "Friendly", "Crisp", "Quiet", "Formal"])
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Settings"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
    }

    private func buildInterface() {
        let speechLabel = UILabel()
        speechLabel.text = "Speech Output"
        speechLabel.textColor = JarvisTheme.text
        speechLabel.font = JarvisTheme.bodyFont(size: 16)
        speechLabel.accessibilityIdentifier = "jarvis.settings.speechLabel"

        speechSwitch.isOn = JarvisSpeechService.shared.isEnabled
        speechSwitch.addTarget(self, action: #selector(speechChanged), for: .valueChanged)
        speechSwitch.accessibilityIdentifier = "jarvis.settings.speechSwitch"

        let row = UIStackView(arrangedSubviews: [speechLabel, speechSwitch])
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing

        voiceProfileControl.selectedSegmentIndex = index(for: JarvisSpeechService.shared.profile)
        voiceProfileControl.selectedSegmentTintColor = JarvisTheme.accent
        voiceProfileControl.setTitleTextAttributes([.foregroundColor: JarvisTheme.text], for: .normal)
        voiceProfileControl.setTitleTextAttributes([.foregroundColor: JarvisTheme.background], for: .selected)
        voiceProfileControl.addTarget(self, action: #selector(profileChanged), for: .valueChanged)
        voiceProfileControl.accessibilityIdentifier = "jarvis.settings.voiceProfile"

        textView.isEditable = false
        textView.textColor = JarvisTheme.text
        textView.font = JarvisTheme.bodyFont(size: 14)
        textView.accessibilityIdentifier = "jarvis.settings.text"
        JarvisTheme.stylePanel(textView)
        textView.text = """
        JARVIS appliance settings

        Voice:
        Default profile is Natural. Speech is generated locally through AVSpeechSynthesizer. Personal Voice can be created in iOS Accessibility. JARVIS can request authorization on supported iOS versions, but it does not train, clone, or upload a voice.

        Control Mesh:
        Use Voice Control, Vocal Shortcuts, Shortcuts, and the jarvis:// URL scheme for official phone-level coordination.

        Guided Access setup:
        1. Open JARVIS.
        2. Triple-click the side button.
        3. Start Guided Access.
        4. Test exit first.

        Install reminder:
        Free Apple ID sideloaded builds usually need refresh after 7 days. Reinstall the newest IPA with AltServer when needed.

        Local data:
        Notes and command history are stored locally on this device. Do not store sensitive secrets by default.

        Guided Access can keep JARVIS foreground.
        It cannot provide system UI ownership, lock screen control, background daemon install, arbitrary app control, or hidden screen control.
        """

        let clearNotesButton = JarvisTheme.button(title: "Clear Notes")
        clearNotesButton.addTarget(self, action: #selector(clearNotesTapped), for: .touchUpInside)

        let clearHistoryButton = JarvisTheme.button(title: "Clear History")
        clearHistoryButton.addTarget(self, action: #selector(clearHistoryTapped), for: .touchUpInside)

        let voiceTestButton = JarvisTheme.button(title: "Voice Test")
        voiceTestButton.addTarget(self, action: #selector(voiceTestTapped), for: .touchUpInside)

        let profilePreviewButton = JarvisTheme.button(title: "Preview Profiles")
        profilePreviewButton.addTarget(self, action: #selector(profilePreviewTapped), for: .touchUpInside)

        let personalVoiceButton = JarvisTheme.button(title: "Personal Voice")
        personalVoiceButton.addTarget(self, action: #selector(personalVoiceTapped), for: .touchUpInside)

        let aboutButton = JarvisTheme.button(title: "About")
        aboutButton.addTarget(self, action: #selector(aboutTapped), for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [clearNotesButton, clearHistoryButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually

        let secondButtonRow = UIStackView(arrangedSubviews: [voiceTestButton, profilePreviewButton])
        secondButtonRow.axis = .horizontal
        secondButtonRow.spacing = 8
        secondButtonRow.distribution = .fillEqually

        let thirdButtonRow = UIStackView(arrangedSubviews: [personalVoiceButton, aboutButton])
        thirdButtonRow.axis = .horizontal
        thirdButtonRow.spacing = 8
        thirdButtonRow.distribution = .fillEqually

        let profileLabel = UILabel()
        profileLabel.text = "Voice Profile"
        profileLabel.textColor = JarvisTheme.mutedText
        profileLabel.font = JarvisTheme.bodyFont(size: 12)

        let stack = UIStackView(arrangedSubviews: [row, profileLabel, voiceProfileControl, buttonRow, secondButtonRow, thirdButtonRow, textView])
        stack.axis = .vertical
        stack.spacing = 16
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.heightAnchor.constraint(equalToConstant: 340)
        ])
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

    @objc private func clearNotesTapped() {
        confirm(title: "Clear notes?", message: "This removes local JARVIS notes stored on this device.") {
            JarvisMemoryStore.shared.clearNotes()
        }
    }

    @objc private func clearHistoryTapped() {
        confirm(title: "Clear history?", message: "This removes local command history stored on this device.") {
            JarvisMemoryStore.shared.clearHistory()
        }
    }

    @objc private func voiceTestTapped() {
        JarvisSpeechService.shared.speak(JarvisSpeechService.shared.testPhrase())
    }

    @objc private func profilePreviewTapped() {
        JarvisSpeechService.shared.previewAllProfiles()
    }

    @objc private func personalVoiceTapped() {
        JarvisSpeechService.shared.personalVoiceStatusText { [weak self] message in
            guard let self else { return }
            let alert = UIAlertController(title: "Personal Voice", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Use If Available", style: .default) { _ in
                JarvisSpeechService.shared.prefersPersonalVoice = true
            })
            alert.addAction(UIAlertAction(title: "Use System Voice", style: .default) { _ in
                JarvisSpeechService.shared.prefersPersonalVoice = false
            })
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
            self.present(alert, animated: true)
        }
    }

    private func confirm(title: String, message: String, action: @escaping () -> Void) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Confirm", style: .destructive) { _ in action() })
        present(alert, animated: true)
    }

    @objc private func aboutTapped() {
        navigationController?.pushViewController(JarvisAboutViewController(), animated: true)
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
}
