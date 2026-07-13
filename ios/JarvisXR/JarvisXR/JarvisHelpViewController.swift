import UIKit

enum JarvisHelpSection {
    case overview
    case vision
}

final class JarvisHelpViewController: UIViewController {
    private let initialSection: JarvisHelpSection
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    init(initialSection: JarvisHelpSection = .overview) {
        self.initialSection = initialSection
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        initialSection = .overview
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = initialSection == .vision ? "Vision Help" : "Help"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
    }

    private func buildInterface() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "jarvis.help.scroll"

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
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 20),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
        ])

        let header = label(
            initialSection == .vision ? "Use Jarvis Vision" : "Operate JARVIS",
            style: .largeTitle,
            color: JarvisTheme.text
        )
        header.accessibilityTraits.insert(.header)
        header.accessibilityIdentifier = "jarvis.help.header"
        stackView.addArrangedSubview(header)

        let intro = label(
            "Use touch, the in-app Voice button, natural phrases, Shortcuts, or jarvis:// links. Every camera result is available as speech and visible text.",
            style: .body,
            color: JarvisTheme.mutedText
        )
        stackView.addArrangedSubview(intro)

        addCallout(
            "Safety first",
            "Jarvis can miss or misidentify things. It is not a replacement for a cane, guide dog, human help, or safe mobility practices. Never use a camera result as permission to cross or proceed."
        )

        addSection("Describe surroundings", [
            "Choose Describe, point the phone, then select Describe What Is Here.",
            "Try: “What is in front of me?”, “Describe this room,” or “Describe the left side.”",
            "Use More Detail to expand the latest grounded result without taking another photo.",
        ])
        addSection("Start Live Guide", [
            "Choose Live, then Start Live Guide. Stable, meaningful changes are announced while Jarvis stays in the foreground.",
            "Try: “Start live guide,” “Pause live guide,” “Only important changes,” or “What changed?”",
            "Live Guide stops when Jarvis moves to the background. It is informational assistance, not navigation certification.",
        ])
        addSection("Find an object", [
            "Choose Find, name a supported object, and pan slowly.",
            "Try: “Find the chair,” “Where is the person?”, or “Find the door.”",
            "Jarvis reports broad left, center, or right guidance and says when a requested target is unsupported or lost.",
        ])
        addSection("Read text", [
            "Say “Read this” or choose Read, then hold printed text steady while Jarvis continuously looks for a useful frame.",
            "Try: “Start from the top,” “Read the largest text,” “Spell that,” Pause Reading, Previous Line, and Next Line for control.",
            "Recognized text remains session-only and is not added to general command history.",
        ])
        addSection("Scan a barcode", [
            "Choose Scan and move slowly across the package or code.",
            "Try: “Scan this barcode.” Jarvis speaks the value only in Scan mode and never opens a detected link automatically.",
        ])
        addSection("Identify color and camera quality", [
            "Try: “What color is this?” Keep the surface in the center of the camera.",
            "Try: “Is the camera blocked?” Jarvis may suggest more light, less motion, or different framing.",
            "Color names are approximate and can change with lighting and camera exposure.",
        ])
        addSection("Use the flashlight", [
            "Select Flashlight, or say “Turn on the flashlight” and “Turn off the flashlight.”",
            "Ask “Is the flashlight on?” to hear the current Vision flashlight state.",
            "The flashlight turns off when Vision stops or the app leaves the foreground.",
        ])
        addSection("Prepare a message", [
            "Say “Message Alex” or “Tell Alex I will arrive soon,” then select the intended contact and phone number in the accessible system contact picker.",
            "Jarvis reads the selected recipient and draft back. Say “Open the message composer” only when you are ready to review it in the standard iOS composer.",
            "Sending or cancelling happens in the system composer. Jarvis does not silently send messages or upload contacts and message contents.",
        ])
        addSection("Stop, repeat, and speech", [
            "The red Stop control stays visible at the bottom of Vision. It stops camera analysis, speech, haptics, and voice input.",
            "Try: “Stop,” “Repeat that,” “Give me more detail,” or “Describe less.”",
            "Tap Voice inside Vision to give these commands without returning to the main screen.",
        ])
        addSection("Understand haptics", [
            "Direction cues distinguish left, center, and right. Separate patterns indicate target found, target lost, warning, and completion.",
            "Haptics can be reduced or disabled in Vision Settings. Spoken direction remains available.",
        ])
        addSection("Privacy", [
            "Core Vision processing is on device and does not require a vision network service.",
            "Jarvis does not automatically save camera photos, video, recognized text, or barcode values.",
            "Stopping a Vision session clears its temporary scene memory unless you explicitly save separate information.",
        ])
        addSection("Troubleshooting", [
            "Camera access off: use Open iOS Settings in the recovery panel, enable Camera, return, and Try Again.",
            "Model unavailable: Read and Scan may still work; Diagnostics shows validation and availability details.",
            "Dark or blurry view: add light, move closer, and steady the phone. Jarvis keeps looking for a useful frame while the task is active.",
            "No speech: confirm Speech Output in Settings and check the current audio route.",
        ])
        addSection("Main JARVIS and Control Mesh", [
            "JARVIS begins listening after launch when permissions and onboarding allow it. Tap the orb to listen again from standby.",
            "Tap while listening to process what you said.",
            "Tap while JARVIS is speaking to stop speech. Long hold to return to standby.",
            "Try: scan this, read this, detect objects, or open Control Mesh.",
            "Control Mesh explains supported Voice Control, Shortcuts, and phone-level routes without claiming hidden system control.",
        ])

        let done = JarvisTheme.button(title: "Done")
        done.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        done.titleLabel?.adjustsFontForContentSizeCategory = true
        done.accessibilityIdentifier = "jarvis.help.done"
        done.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        stackView.addArrangedSubview(done)
    }

    private func addCallout(_ title: String, _ text: String) {
        let panel = makePanel(title: title, rows: [text])
        panel.layer.borderColor = JarvisTheme.warning.cgColor
        panel.accessibilityIdentifier = "jarvis.help.safety"
        stackView.addArrangedSubview(panel)
    }

    private func addSection(_ title: String, _ rows: [String]) {
        stackView.addArrangedSubview(makePanel(title: title, rows: rows))
    }

    private func makePanel(title: String, rows: [String]) -> JarvisPanelView {
        let panel = JarvisPanelView()
        let vertical = UIStackView()
        vertical.translatesAutoresizingMaskIntoConstraints = false
        vertical.axis = .vertical
        vertical.spacing = 9
        panel.addSubview(vertical)

        let titleLabel = label(title, style: .headline, color: JarvisTheme.accentHot)
        titleLabel.accessibilityTraits.insert(.header)
        vertical.addArrangedSubview(titleLabel)
        for row in rows {
            vertical.addArrangedSubview(label(row, style: .body, color: JarvisTheme.text))
        }

        NSLayoutConstraint.activate([
            vertical.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            vertical.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            vertical.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            vertical.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])
        return panel
    }

    private func label(_ text: String, style: UIFont.TextStyle, color: UIColor) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = color
        label.font = UIFont.preferredFont(forTextStyle: style)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        return label
    }

    @objc private func doneTapped() {
        if presentingViewController != nil, navigationController == nil {
            dismiss(animated: !UIAccessibility.isReduceMotionEnabled)
        } else if navigationController?.viewControllers.first !== self {
            navigationController?.popViewController(animated: !UIAccessibility.isReduceMotionEnabled)
        } else {
            dismiss(animated: !UIAccessibility.isReduceMotionEnabled)
        }
    }
}
