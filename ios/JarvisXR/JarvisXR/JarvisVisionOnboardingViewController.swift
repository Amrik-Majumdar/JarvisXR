import UIKit

final class JarvisVisionOnboardingViewController: UIViewController {
    var onOpenVision: (() -> Void)?
    var onContinue: (() -> Void)?

    private let stackView = UIStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Welcome to Jarvis Vision"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
    }

    private func buildInterface() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "jarvis.vision.onboarding.scroll"
        stackView.translatesAutoresizingMaskIntoConstraints = false
        stackView.axis = .vertical
        stackView.spacing = 16

        view.addSubview(scrollView)
        scrollView.addSubview(stackView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 24),
            stackView.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 18),
            stackView.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -18),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -28),
        ])

        let heading = label("Practical sight from your iPhone camera", style: .largeTitle, color: JarvisTheme.text)
        heading.accessibilityTraits.insert(.header)
        heading.accessibilityIdentifier = "jarvis.vision.onboarding.header"
        stackView.addArrangedSubview(heading)

        let intro = label(
            "Jarvis Vision can describe visible objects, follow important changes, find supported objects, read print, and scan barcodes.",
            style: .body,
            color: JarvisTheme.mutedText
        )
        stackView.addArrangedSubview(intro)

        addPoint(
            title: "Private by default",
            text: "Core camera analysis runs on device. Jarvis does not automatically save camera photos, video, recognized text, or barcode values."
        )
        addPoint(
            title: "Useful, not infallible",
            text: "Camera and model results can be wrong or incomplete. Jarvis states uncertainty and may ask for better light or a steadier view."
        )
        addPoint(
            title: "Keep mobility practices",
            text: "Jarvis Vision is not a replacement for a cane, guide dog, human assistance, or safe mobility practices. Never treat a camera result as permission to cross or proceed."
        )
        addPoint(
            title: "You stay in control",
            text: "Ask Jarvis naturally or choose the large visible task control. The red Stop control remains visible and stops camera analysis, narration, haptics, and voice input."
        )
        addPoint(
            title: "Permissions when needed",
            text: "Camera access is requested only when you start a Vision action. Microphone and Speech access are requested only when you use voice input."
        )

        let hapticButton = actionButton("Try a Short Haptic Tutorial", identifier: "jarvis.vision.onboarding.haptics", action: #selector(hapticTutorialTapped))
        hapticButton.accessibilityHint = "Demonstrates left, center, right, and target found patterns."
        stackView.addArrangedSubview(hapticButton)

        let openButton = actionButton("Open Jarvis Vision", identifier: "jarvis.vision.onboarding.open", action: #selector(openVisionTapped))
        openButton.backgroundColor = JarvisTheme.accentHot
        openButton.setTitleColor(JarvisTheme.background, for: .normal)
        stackView.addArrangedSubview(openButton)

        let continueButton = actionButton("Continue to JARVIS", identifier: "jarvis.vision.onboarding.continue", action: #selector(continueTapped))
        let skipButton = actionButton("Skip for Now", identifier: "jarvis.vision.onboarding.skip", action: #selector(continueTapped))
        stackView.addArrangedSubview(horizontalRow([continueButton, skipButton]))
    }

    private func addPoint(title: String, text: String) {
        let heading = label(title, style: .headline, color: JarvisTheme.accentHot)
        heading.accessibilityTraits.insert(.header)
        let body = label(text, style: .body, color: JarvisTheme.text)
        let stack = UIStackView(arrangedSubviews: [heading, body])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false

        let panel = JarvisPanelView()
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])
        stackView.addArrangedSubview(panel)
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

    private func actionButton(_ title: String, identifier: String, action: Selector) -> UIButton {
        let button = JarvisTheme.button(title: title)
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.accessibilityIdentifier = identifier
        button.addTarget(self, action: action, for: .touchUpInside)
        return button
    }

    private func horizontalRow(_ views: [UIView]) -> UIStackView {
        let row = UIStackView(arrangedSubviews: views)
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    @objc private func hapticTutorialTapped() {
        let service = VisionHapticsService.shared
        guard service.backend != .unavailable else {
            let alert = UIAlertController(title: "Haptics Unavailable", message: "This device will use spoken direction guidance instead.", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
            return
        }
        let sessionID = service.beginSession()
        let cues: [(VisionHapticCue, String)] = [
            (.directionLeft, "Left"),
            (.directionCenter, "Center"),
            (.directionRight, "Right"),
            (.targetAcquired, "Target found"),
        ]
        for (index, cue) in cues.enumerated() {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(index) * 0.8) {
                UIAccessibility.post(notification: .announcement, argument: cue.1)
                service.play(cue.0, intensity: .standard, sessionID: sessionID)
                if index == cues.count - 1 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { service.endSession(sessionID) }
                }
            }
        }
    }

    @objc private func openVisionTapped() {
        JarvisVisionFirstRunStore.shared.markCompleted()
        let completion = onOpenVision
        dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { completion?() }
    }

    @objc private func continueTapped() {
        JarvisVisionFirstRunStore.shared.markCompleted()
        let completion = onContinue
        dismiss(animated: !UIAccessibility.isReduceMotionEnabled) { completion?() }
    }
}
