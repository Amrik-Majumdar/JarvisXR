import UIKit

final class JarvisHelpViewController: UIViewController {
    private let scrollView = UIScrollView()
    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Help"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
    }

    private func buildInterface() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.accessibilityIdentifier = "jarvis.help.scroll"
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 12

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 22),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28)
        ])

        let header = UILabel()
        header.text = "Operate JARVIS"
        header.textColor = JarvisTheme.text
        header.font = JarvisTheme.titleFont(size: 26)
        header.textAlignment = .left
        header.accessibilityIdentifier = "jarvis.help.header"
        stackView.addArrangedSubview(header)

        let intro = UILabel()
        intro.text = "Use the orb for voice. Use the command bar when typing is better."
        intro.textColor = JarvisTheme.mutedText
        intro.font = JarvisTheme.bodyFont(size: 15)
        intro.numberOfLines = 0
        stackView.addArrangedSubview(intro)

        addSection("Start", [
            "Tap once from standby to wake JARVIS.",
            "Tap again to listen.",
            "Tap while listening to process the command.",
            "Tap while JARVIS is speaking to stop.",
            "Long hold the orb to return to standby."
        ])
        addSection("Voice", [
            "JARVIS listens while this app is open.",
            "A short pause ends the command.",
            "Background wake word is not available in this build."
        ])
        addSection("Typing", [
            "Use the command bar when voice is not ideal.",
            "Return or Send routes the command."
        ])
        addSection("Vision", [
            "Try: scan this, read this, look at this, detect objects.",
            "OCR, barcode scan, and image classification run after capture.",
            "A custom Core ML detector can be bundled later for stronger object labels."
        ])
        addSection("Control Mesh", [
            "Use Mesh for phone-level actions.",
            "Voice Control handles Show Grid, Tap, Scroll, Go Home, and screenshots.",
            "Shortcuts and jarvis:// links return actions back to JARVIS."
        ])
        addSection("States", [
            "Ready means JARVIS is awake.",
            "Listening means it is hearing you.",
            "Heard you means it captured your command.",
            "Processing means it is routing the command.",
            "Speaking means it is responding."
        ])
        addSection("Limits", [
            "No hidden phone ownership through public iOS app APIs.",
            "Phone-level actions use Control Mesh, Voice Control, or Shortcuts.",
            "Background wake word and full phone ownership require system access not available in this build.",
            "JARVIS stays honest about anything iOS does not expose."
        ])
    }

    private func addSection(_ title: String, _ rows: [String]) {
        let panel = JarvisPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false

        let vertical = UIStackView()
        vertical.translatesAutoresizingMaskIntoConstraints = false
        vertical.axis = .vertical
        vertical.spacing = 8
        panel.addSubview(vertical)

        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.textColor = JarvisTheme.accentHot
        titleLabel.font = JarvisTheme.titleFont(size: 17)
        vertical.addArrangedSubview(titleLabel)

        for row in rows {
            let label = UILabel()
            label.text = row
            label.textColor = JarvisTheme.text
            label.font = JarvisTheme.bodyFont(size: 15)
            label.numberOfLines = 0
            vertical.addArrangedSubview(label)
        }

        NSLayoutConstraint.activate([
            vertical.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            vertical.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            vertical.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            vertical.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14)
        ])

        stackView.addArrangedSubview(panel)
    }
}
