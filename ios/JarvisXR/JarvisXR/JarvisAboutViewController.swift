import UIKit

final class JarvisAboutViewController: UIViewController {
    private let textView = UITextView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Identity"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
    }

    private func buildInterface() {
        textView.isEditable = false
        textView.textColor = JarvisTheme.text
        textView.font = JarvisTheme.bodyFont(size: 14)
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 14, bottom: 16, right: 14)
        JarvisTheme.stylePanel(textView)
        textView.translatesAutoresizingMaskIntoConstraints = false
        textView.text = """
        JARVIS Appliance Mode

        JARVIS is designed to make this iPhone feel like a dedicated command device.

        Current ownership layer:
        Guided Access after the app is installed and tested.

        Local capabilities:
        Offline commands, local notes, command history, speech output, camera inspection, diagnostics, and device setup guidance.

        Boundaries:
        This build does not claim system UI ownership, lock screen control, background daemon install, system-wide button remaps, arbitrary app control, or true OS ownership.

        Practical identity:
        JARVIS is the foreground appliance shell. iOS remains the operating system.
        """
        view.addSubview(textView)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            textView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            textView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            textView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }
}
