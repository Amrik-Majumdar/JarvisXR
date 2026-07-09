import UIKit

final class JarvisControlMeshViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Control Mesh"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
    }

    private func buildInterface() {
        let header = UILabel()
        header.text = "JARVIS CONTROL MESH"
        header.textColor = JarvisTheme.text
        header.font = JarvisTheme.titleFont(size: 22)
        header.textAlignment = .center
        header.accessibilityIdentifier = "jarvis.mesh.header"

        let status = JarvisModeChipView(text: "Official iOS Layers", color: JarvisTheme.accent)

        textView.isEditable = false
        textView.textColor = JarvisTheme.text
        textView.font = JarvisTheme.bodyFont(size: 13)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        textView.accessibilityIdentifier = "jarvis.mesh.text"
        JarvisTheme.stylePanel(textView)
        textView.text = """
        JARVIS coordinates phone-level actions through official iOS layers. It gives the next safe route instead of pretending to control private system surfaces.

        Voice Control commands:
        Show Grid
        Tap the target number
        Scroll Down
        Go Home
        Take Screenshot
        Open Spotify

        Return routes:
        jarvis://inspect
        jarvis://command?text=system%20check
        jarvis://settings
        jarvis://standby

        Recommended Vocal Shortcuts:
        Jarvis inspect
        Jarvis quiet
        Jarvis normal
        Jarvis return
        Jarvis night

        Boundaries:
        Boundary:
        Hidden taps, lock screen control, SpringBoard hooks, background system control, arbitrary floating UI, and root daemons require system-level access and are not claimed in this build.
        """

        let inspectButton = JarvisTheme.button(title: "Run Inspect Link")
        inspectButton.addTarget(self, action: #selector(inspectTapped), for: .touchUpInside)

        let quietButton = JarvisTheme.button(title: "Set Quiet")
        quietButton.addTarget(self, action: #selector(quietTapped), for: .touchUpInside)

        let voiceButton = JarvisTheme.button(title: "Voice Test")
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)

        let buttonRow = UIStackView(arrangedSubviews: [inspectButton, quietButton, voiceButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [header, status, textView, buttonRow])
        stack.axis = .vertical
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    @objc private func inspectTapped() {
        JarvisDeepLinkRouter.post(.inspect)
    }

    @objc private func quietTapped() {
        JarvisDeepLinkRouter.post(.command("quiet mode"))
    }

    @objc private func voiceTapped() {
        JarvisDeepLinkRouter.post(.command("voice test"))
    }
}
