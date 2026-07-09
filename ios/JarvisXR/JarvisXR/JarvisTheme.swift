import UIKit

enum JarvisTheme {
    static let background = JarvisDesignSystem.Color.void
    static let panel = JarvisDesignSystem.Color.surface
    static let panelRaised = JarvisDesignSystem.Color.glass
    static let panelBorder = JarvisDesignSystem.Color.line
    static let text = UIColor(white: 0.92, alpha: 1.0)
    static let mutedText = UIColor(white: 0.60, alpha: 1.0)
    static let accent = JarvisDesignSystem.Color.cyanSoft
    static let accentHot = JarvisDesignSystem.Color.cyan
    static let accentDim = UIColor(red: 0.10, green: 0.32, blue: 0.38, alpha: 1.0)
    static let warning = JarvisDesignSystem.Color.attention
    static let success = JarvisDesignSystem.Color.speaking
    static let error = UIColor(red: 0.95, green: 0.30, blue: 0.24, alpha: 1.0)

    static func titleFont(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .semibold)
    }

    static func bodyFont(size: CGFloat) -> UIFont {
        UIFont.systemFont(ofSize: size, weight: .regular)
    }

    static func monoFont(size: CGFloat, weight: UIFont.Weight = .regular) -> UIFont {
        UIFont.monospacedSystemFont(ofSize: size, weight: weight)
    }

    static func stylePanel(_ view: UIView) {
        view.backgroundColor = panel
        view.layer.borderColor = panelBorder.cgColor
        view.layer.borderWidth = 1
        view.layer.cornerRadius = 10
    }

    static func button(title: String) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        button.setTitleColor(text, for: .normal)
        button.titleLabel?.font = bodyFont(size: 14)
        button.backgroundColor = panelRaised
        button.layer.borderColor = panelBorder.cgColor
        button.layer.borderWidth = 1
        button.layer.cornerRadius = 10
        button.contentEdgeInsets = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
        return button
    }
}

final class JarvisPanelView: UIView {
    override init(frame: CGRect) {
        super.init(frame: frame)
        JarvisTheme.stylePanel(self)
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.35
        layer.shadowRadius = 12
        layer.shadowOffset = CGSize(width: 0, height: 8)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

final class JarvisModeChipView: UILabel {
    private var chipColor: UIColor

    init(text: String, color: UIColor = JarvisTheme.accent) {
        self.chipColor = color
        super.init(frame: .zero)
        self.text = text
        textColor = chipColor
        font = JarvisTheme.bodyFont(size: 11)
        textAlignment = .center
        backgroundColor = chipColor.withAlphaComponent(0.12)
        layer.borderColor = chipColor.withAlphaComponent(0.55).cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 11
        clipsToBounds = true
        setContentHuggingPriority(.required, for: .horizontal)
        setContentCompressionResistancePriority(.required, for: .horizontal)
        heightAnchor.constraint(greaterThanOrEqualToConstant: 24).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + 18, height: max(24, size.height + 8))
    }

    func update(text: String, color: UIColor) {
        self.text = text
        chipColor = color
        textColor = color
        backgroundColor = color.withAlphaComponent(0.12)
        layer.borderColor = color.withAlphaComponent(0.55).cgColor
    }
}

final class JarvisCommandButton: UIButton {
    init(title: String) {
        super.init(frame: .zero)
        setTitle(title, for: .normal)
        setTitleColor(JarvisTheme.text, for: .normal)
        setTitleColor(JarvisTheme.accent, for: .highlighted)
        titleLabel?.font = JarvisTheme.bodyFont(size: 13)
        titleLabel?.adjustsFontSizeToFitWidth = true
        titleLabel?.minimumScaleFactor = 0.78
        backgroundColor = JarvisTheme.panelRaised
        layer.borderColor = JarvisTheme.panelBorder.cgColor
        layer.borderWidth = 1
        layer.cornerRadius = 10
        accessibilityLabel = title
        heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

enum JarvisOrbState {
    case idle
    case listening
    case processing
    case speaking
    case standby
    case quiet
    case inspection
    case error
}

final class JarvisOrbView: UIView {
    private let assetLayer = CALayer()
    private let ringLayer = CAShapeLayer()
    private let secondaryRingLayer = CAShapeLayer()
    private let scanLayer = CAShapeLayer()
    private let tickLayer = CAShapeLayer()
    private let deepRingLayer = CAShapeLayer()
    private let innerLayer = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()
    private let coreLayer = CAShapeLayer()
    private let coreGlowLayer = CAShapeLayer()
    private var state: JarvisOrbState = .idle

    override init(frame: CGRect) {
        super.init(frame: frame)
        isAccessibilityElement = true
        accessibilityLabel = "Jarvis status orb. Systems online."
        backgroundColor = .clear
        layer.shadowColor = JarvisTheme.accent.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowRadius = 30
        layer.shadowOffset = .zero
        if let image = UIImage(named: "JarvisOrb") {
            assetLayer.contents = image.cgImage
            assetLayer.contentsGravity = .resizeAspectFill
            assetLayer.opacity = 0.72
            layer.addSublayer(assetLayer)
        }
        [pulseLayer, deepRingLayer, tickLayer, ringLayer, secondaryRingLayer, scanLayer, innerLayer, coreGlowLayer, coreLayer].forEach { layer.addSublayer($0) }
        startIdleAnimation()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let rect = bounds.insetBy(dx: 10, dy: 10)
        let path = UIBezierPath(ovalIn: rect)
        let palette = colors(for: state)
        assetLayer.frame = bounds.insetBy(dx: 2, dy: 2)
        assetLayer.cornerRadius = min(assetLayer.bounds.width, assetLayer.bounds.height) / 2
        assetLayer.masksToBounds = true
        pulseLayer.path = path.cgPath
        pulseLayer.fillColor = palette.fill.withAlphaComponent(state == .standby ? 0.12 : 0.25).cgColor
        pulseLayer.strokeColor = palette.primary.withAlphaComponent(state == .standby ? 0.08 : 0.16).cgColor
        pulseLayer.lineWidth = 22

        deepRingLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 18, dy: 18)).cgPath
        deepRingLayer.fillColor = UIColor(red: 0.006, green: 0.012, blue: 0.016, alpha: 0.92).cgColor
        deepRingLayer.strokeColor = UIColor(white: 0.28, alpha: state == .standby ? 0.18 : 0.42).cgColor
        deepRingLayer.lineWidth = 5

        ringLayer.path = path.cgPath
        ringLayer.fillColor = UIColor.clear.cgColor
        ringLayer.strokeColor = palette.primary.cgColor
        ringLayer.lineWidth = 2.8
        ringLayer.shadowColor = palette.primary.cgColor
        ringLayer.shadowOpacity = state == .quiet ? 0.35 : 0.92
        ringLayer.shadowRadius = state == .quiet ? 10 : 24

        secondaryRingLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 22, dy: 22)).cgPath
        secondaryRingLayer.fillColor = UIColor.clear.cgColor
        secondaryRingLayer.strokeColor = palette.secondary.withAlphaComponent(0.62).cgColor
        secondaryRingLayer.lineWidth = 1.2
        secondaryRingLayer.lineDashPattern = [8, 8]

        tickLayer.path = tickPath(center: CGPoint(x: bounds.midX, y: bounds.midY), inner: min(bounds.width, bounds.height) * 0.355, outer: min(bounds.width, bounds.height) * 0.415).cgPath
        tickLayer.fillColor = UIColor.clear.cgColor
        tickLayer.strokeColor = palette.primary.withAlphaComponent(0.48).cgColor
        tickLayer.lineWidth = 1

        scanLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 14, dy: 14)).cgPath
        scanLayer.fillColor = UIColor.clear.cgColor
        scanLayer.strokeColor = palette.primary.withAlphaComponent(state == .inspection ? 0.95 : 0.50).cgColor
        scanLayer.lineWidth = state == .inspection ? 2.4 : 1.5
        scanLayer.lineCap = .round
        scanLayer.strokeStart = 0.02
        scanLayer.strokeEnd = state == .idle ? 0.13 : 0.24

        innerLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 38, dy: 38)).cgPath
        innerLayer.fillColor = UIColor(red: 0.012, green: 0.020, blue: 0.025, alpha: 0.95).cgColor
        innerLayer.strokeColor = palette.primary.withAlphaComponent(0.55).cgColor
        innerLayer.lineWidth = 1

        coreGlowLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 55, dy: 55)).cgPath
        coreGlowLayer.fillColor = palette.primary.withAlphaComponent(state == .quiet ? 0.15 : 0.28).cgColor
        coreGlowLayer.shadowColor = palette.primary.cgColor
        coreGlowLayer.shadowOpacity = state == .quiet ? 0.25 : 0.82
        coreGlowLayer.shadowRadius = state == .quiet ? 8 : 18

        coreLayer.path = UIBezierPath(ovalIn: bounds.insetBy(dx: 68, dy: 68)).cgPath
        coreLayer.fillColor = palette.primary.withAlphaComponent(state == .quiet ? 0.26 : 0.68).cgColor
        coreLayer.shadowColor = palette.primary.cgColor
        coreLayer.shadowOpacity = state == .quiet ? 0.38 : 0.95
        coreLayer.shadowRadius = state == .quiet ? 10 : 22
    }

    func setState(_ newState: JarvisOrbState) {
        state = newState
        let label: String
        switch newState {
        case .idle: label = "Ready"
        case .listening: label = "Listening"
        case .processing: label = "Processing"
        case .speaking: label = "Speaking"
        case .standby: label = "Standby"
        case .quiet: label = "Quiet"
        case .inspection: label = "Inspecting"
        case .error: label = "Attention"
        }
        accessibilityLabel = "Jarvis status orb. \(label)."
        setNeedsLayout()
        animateForState(newState)
    }

    private func colors(for state: JarvisOrbState) -> (primary: UIColor, secondary: UIColor, fill: UIColor) {
        switch state {
        case .idle:
            return (JarvisTheme.accentHot, JarvisTheme.accent, JarvisTheme.accentDim)
        case .listening:
            return (UIColor(red: 0.25, green: 0.96, blue: 1.0, alpha: 1.0), UIColor(red: 0.42, green: 0.80, blue: 1.0, alpha: 1.0), UIColor(red: 0.07, green: 0.34, blue: 0.46, alpha: 1.0))
        case .processing:
            return (UIColor(red: 0.65, green: 0.86, blue: 1.0, alpha: 1.0), JarvisTheme.accent, JarvisTheme.accentDim)
        case .speaking:
            return (JarvisTheme.success, JarvisTheme.accent, UIColor(red: 0.10, green: 0.35, blue: 0.24, alpha: 1.0))
        case .standby:
            return (UIColor(white: 0.42, alpha: 1.0), UIColor(white: 0.24, alpha: 1.0), UIColor(white: 0.08, alpha: 1.0))
        case .quiet:
            return (JarvisTheme.warning, UIColor(red: 0.45, green: 0.33, blue: 0.13, alpha: 1.0), UIColor(red: 0.20, green: 0.15, blue: 0.08, alpha: 1.0))
        case .inspection:
            return (UIColor(red: 0.72, green: 0.78, blue: 1.0, alpha: 1.0), JarvisTheme.accent, UIColor(red: 0.18, green: 0.20, blue: 0.38, alpha: 1.0))
        case .error:
            return (JarvisTheme.error, JarvisTheme.warning, UIColor(red: 0.34, green: 0.08, blue: 0.06, alpha: 1.0))
        }
    }

    private func startIdleAnimation() {
        animateForState(.idle)
    }

    private func animateForState(_ state: JarvisOrbState) {
        pulseLayer.removeAllAnimations()
        ringLayer.removeAllAnimations()
        secondaryRingLayer.removeAllAnimations()
        scanLayer.removeAllAnimations()
        tickLayer.removeAllAnimations()
        coreGlowLayer.removeAllAnimations()
        coreLayer.removeAllAnimations()

        let pulse = CABasicAnimation(keyPath: "transform.scale")
        pulse.fromValue = 0.98
        pulse.toValue = state == .quiet || state == .standby ? 1.015 : state == .listening ? 1.095 : 1.065
        pulse.duration = state == .listening ? 0.85 : state == .processing ? 0.7 : 2.0
        pulse.autoreverses = true
        pulse.repeatCount = .infinity
        pulseLayer.add(pulse, forKey: "pulse")

        let rotate = CABasicAnimation(keyPath: "transform.rotation.z")
        rotate.fromValue = 0
        rotate.toValue = CGFloat.pi * 2
        rotate.duration = state == .processing ? 2.2 : 7.5
        rotate.repeatCount = .infinity
        secondaryRingLayer.add(rotate, forKey: "ringRotation")
        tickLayer.add(rotate, forKey: "tickRotation")

        let scanRotate = CABasicAnimation(keyPath: "transform.rotation.z")
        scanRotate.fromValue = 0
        scanRotate.toValue = CGFloat.pi * 2
        scanRotate.duration = state == .inspection ? 1.4 : state == .processing ? 2.4 : state == .listening ? 3.2 : 5.8
        scanRotate.repeatCount = .infinity
        scanLayer.add(scanRotate, forKey: "scanRotation")

        if state == .speaking || state == .listening {
            let glow = CABasicAnimation(keyPath: "opacity")
            glow.fromValue = state == .listening ? 0.22 : 0.45
            glow.toValue = 1.0
            glow.duration = state == .listening ? 0.72 : 0.42
            glow.autoreverses = true
            glow.repeatCount = .infinity
            coreLayer.add(glow, forKey: "voiceGlow")
            coreGlowLayer.add(glow, forKey: "voiceGlow")
        }
    }

    private func tickPath(center: CGPoint, inner: CGFloat, outer: CGFloat) -> UIBezierPath {
        let path = UIBezierPath()
        for index in 0..<72 {
            let angle = CGFloat(index) * CGFloat.pi * 2 / 72
            let tickOuter = index % 6 == 0 ? outer + 4 : outer
            let x1 = center.x + cos(angle) * inner
            let y1 = center.y + sin(angle) * inner
            let x2 = center.x + cos(angle) * tickOuter
            let y2 = center.y + sin(angle) * tickOuter
            path.move(to: CGPoint(x: x1, y: y1))
            path.addLine(to: CGPoint(x: x2, y: y2))
        }
        return path
    }
}
