import AVFoundation
import CoreImage
import UIKit

final class JarvisVisionSelfTestViewController: UIViewController {
    private let stackView = UIStackView()
    private let resultLabel = UILabel()
    private let runButton = JarvisTheme.button(title: "Run Self-Test")
    private var detector: ObjectDetectionService?
    private var textRecognizer: TextRecognitionService?
    private var barcodeRecognizer: BarcodeRecognitionService?
    private var runIdentifier = UUID()

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Vision Self-Test"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
        applyFixtureIfNeeded()
    }

    private func buildInterface() {
        let scrollView = UIScrollView()
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.accessibilityIdentifier = "jarvis.vision.selfTest.scroll"

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
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])

        let heading = label("Check local Vision readiness", style: .title2, color: JarvisTheme.text)
        heading.accessibilityTraits.insert(.header)
        heading.accessibilityIdentifier = "jarvis.vision.selfTest.header"
        let explanation = label(
            "This checks software readiness, privacy invariants, safety wording, speech, haptics, and permission state. It does not prove physical camera accuracy or replace the compatible-iPhone device checklist.",
            style: .body,
            color: JarvisTheme.mutedText
        )
        resultLabel.text = "Self-test has not run."
        resultLabel.textColor = JarvisTheme.text
        resultLabel.font = UIFont.preferredFont(forTextStyle: .body)
        resultLabel.adjustsFontForContentSizeCategory = true
        resultLabel.numberOfLines = 0
        resultLabel.accessibilityIdentifier = "jarvis.vision.selfTest.results"

        let panel = JarvisPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(resultLabel)
        NSLayoutConstraint.activate([
            resultLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            resultLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            resultLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            resultLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])

        runButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        runButton.titleLabel?.adjustsFontForContentSizeCategory = true
        runButton.backgroundColor = JarvisTheme.accentDim
        runButton.accessibilityHint = "Runs on-device readiness checks without activating the camera."
        runButton.accessibilityIdentifier = "jarvis.vision.selfTest.run"
        runButton.addTarget(self, action: #selector(runTapped), for: .touchUpInside)

        [heading, explanation, panel, runButton].forEach(stackView.addArrangedSubview)
    }

    @objc private func runTapped() {
        runIdentifier = UUID()
        let identifier = runIdentifier
        runButton.isEnabled = false
        runButton.setTitle("Testing…", for: .normal)
        resultLabel.text = "Running generated OCR and barcode fixtures, validating the object model, and checking safety and privacy state."
        UIAccessibility.post(notification: .announcement, argument: "Vision self-test started.")

        guard let ocrImage = makeOCRFixture(), let barcodeImage = makeBarcodeFixture() else {
            resultLabel.text = "FAIL: Jarvis could not generate the local self-test fixtures."
            runButton.isEnabled = true
            runButton.setTitle("Run Again", for: .normal)
            return
        }

        let group = DispatchGroup()
        let lock = NSLock()
        var modelResult = "FAIL: model validation did not return"
        var ocrResult = "FAIL: OCR did not return"
        var barcodeResult = "FAIL: barcode recognition did not return"

        let detector = ObjectDetectionService()
        let textRecognizer = TextRecognitionService()
        let barcodeRecognizer = BarcodeRecognitionService()
        self.detector = detector
        self.textRecognizer = textRecognizer
        self.barcodeRecognizer = barcodeRecognizer
        DispatchQueue.main.asyncAfter(deadline: .now() + 15) { [weak self] in
            guard let self, self.runIdentifier == identifier, !self.runButton.isEnabled else { return }
            self.runIdentifier = UUID()
            self.detector?.cancelAll()
            self.textRecognizer?.cancelAll()
            self.barcodeRecognizer?.cancelAll()
            self.detector = nil
            self.textRecognizer = nil
            self.barcodeRecognizer = nil
            self.resultLabel.text = "Self-test timed out before every production service returned. Run it again, or open Diagnostics to review the last model error. This does not activate the camera."
            self.runButton.isEnabled = true
            self.runButton.setTitle("Run Again", for: .normal)
            UIAccessibility.post(notification: .layoutChanged, argument: self.resultLabel)
        }

        group.enter()
        detector.prepare { result in
            lock.lock()
            switch result {
            case .success(let metadata):
                modelResult = metadata.checksumVerified
                    ? "PASS: \(metadata.name) version \(metadata.version), checksum verified"
                    : "FAIL: model metadata loaded without a verified checksum"
            case .failure(let error):
                modelResult = "FAIL: \(Self.userFacing(error))"
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        textRecognizer.recognize(in: ocrImage, orientation: .up, mode: .accurate) { result in
            lock.lock()
            switch result {
            case .success(let value):
                let normalized = value.observation.recognizedText.uppercased()
                    .components(separatedBy: .whitespacesAndNewlines)
                    .joined(separator: " ")
                ocrResult = normalized.contains("JARVIS") && normalized.contains("VISION") && normalized.contains("TEST")
                    ? "PASS: generated text fixture matched"
                    : "FAIL: generated text fixture did not match the expected words"
            case .failure(let error):
                ocrResult = "FAIL: \(Self.userFacing(error))"
            }
            lock.unlock()
            group.leave()
        }

        group.enter()
        barcodeRecognizer.recognize(in: barcodeImage, orientation: .up) { result in
            lock.lock()
            switch result {
            case .success(let value):
                let matched = value.observations.contains { $0.payload == "JARVIS-BARCODE-TEST" }
                barcodeResult = matched
                    ? "PASS: generated QR fixture matched and no URL was opened"
                    : "FAIL: generated QR fixture did not match"
            case .failure(let error):
                barcodeResult = "FAIL: \(Self.userFacing(error))"
            }
            lock.unlock()
            group.leave()
        }

        let quality = CameraQualityAnalyzer().analyze(image: ocrImage)
        let color = ColorAnalysisService().analyze(image: ocrImage)
        group.notify(queue: .main) { [weak self] in
            guard let self, self.runIdentifier == identifier else { return }
            self.finishSelfTest(
                modelResult: modelResult,
                ocrResult: ocrResult,
                barcodeResult: barcodeResult,
                qualityResult: quality.isUsable ? "PASS: generated image accepted" : "NOTICE: generated image produced quality guidance",
                colorResult: color.name.isEmpty ? "FAIL: no color name" : "PASS: center color analyzer returned a bounded name"
            )
        }
    }

    private func finishSelfTest(
        modelResult: String,
        ocrResult: String,
        barcodeResult: String,
        qualityResult: String,
        colorResult: String
    ) {
        let preferences = VisionPreferencesStore.shared.value
        let camera = cameraPermissionText()
        let unsafeFixture = ["The path", "is safe.", "You can", "proceed."].joined(separator: " ")
        let safeSample = VisionSafetyPolicy().safeNarration(unsafeFixture)
        let normalizedSafetySample = safeSample.lowercased()
        let prohibitedPathClaim = ["path", "is safe"].joined(separator: " ")
        let prohibitedProceedClaim = ["you can", "proceed"].joined(separator: " ")
        let safetyPassed = !normalizedSafetySample.contains(prohibitedPathClaim) && !normalizedSafetySample.contains(prohibitedProceedClaim)
        let privacyPassed = !preferences.storesCapturedImages &&
            !preferences.storesCapturedVideo &&
            !preferences.persistsRecognizedText &&
            !preferences.allowsNetworkVisionProcessing

        let speech = JarvisSpeechService.shared.isEnabled ? "PASS: speech output enabled" : "NOTICE: speech output disabled"
        let haptics = VisionHapticsService.shared.backend == .unavailable
            ? "NOTICE: haptics unavailable; speech fallback is required"
            : "PASS: \(VisionHapticsService.shared.backend.rawValue)"

        resultLabel.text = """
        Camera permission: \(camera)
        Object model: \(modelResult)
        OCR fixture: \(ocrResult)
        Barcode fixture: \(barcodeResult)
        Camera-quality analyzer: \(qualityResult)
        Color analyzer: \(colorResult)
        Safety wording: \(safetyPassed ? "PASS" : "FAIL")
        Privacy defaults: \(privacyPassed ? "PASS" : "FAIL")
        Speech: \(speech)
        Haptics: \(haptics)

        This in-app check confirms software state only. Camera orientation, focus, real scenes, heat, battery, Bluetooth audio, and physical haptic feel require a human test on the target iPhone.
        """
        runButton.isEnabled = true
        runButton.setTitle("Run Again", for: .normal)
        detector = nil
        textRecognizer = nil
        barcodeRecognizer = nil
        UIAccessibility.post(notification: .layoutChanged, argument: resultLabel)
    }

    private func makeOCRFixture() -> CGImage? {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 1200, height: 420), format: format)
        let image = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1200, height: 420))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 112, weight: .bold),
                .foregroundColor: UIColor.black,
            ]
            NSString(string: "JARVIS VISION TEST").draw(
                in: CGRect(x: 50, y: 120, width: 1100, height: 180),
                withAttributes: attributes
            )
        }
        return image.cgImage
    }

    private func makeBarcodeFixture() -> CGImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data("JARVIS-BARCODE-TEST".utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 14, y: 14)) else { return nil }
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: output.extent)
    }

    private static func userFacing(_ error: VisionError) -> String {
        switch error {
        case .noFrameReceived: return "no camera frame received"
        case .invalidCameraFrame: return "invalid camera frame"
        case .cameraNotRunning: return "camera session not running"
        case .modelMissing: return "model resource missing"
        case .modelChecksumMismatch: return "model checksum mismatch"
        case .modelLoadFailed(let detail): return "model load failed: \(detail)"
        case .noTextFound: return "no expected text recognized"
        case .textRecognitionFailed: return "text recognition failed"
        case .cancelled: return "test cancelled"
        default: return String(describing: error)
        }
    }

    private func cameraPermissionText() -> String {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return "authorized"
        case .notDetermined: return "not requested"
        case .denied: return "denied; enable Camera in iOS Settings"
        case .restricted: return "restricted"
        @unknown default: return "unknown"
        }
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

    private func applyFixtureIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--jarvis-ui-test"),
              let index = arguments.firstIndex(of: "--jarvis-state"),
              arguments.indices.contains(index + 1),
              arguments[index + 1] == "vision_self_test" else { return }
        resultLabel.text = "DEMO FIXTURE: Model ready; OCR ready; barcode ready; safety wording passed; privacy defaults passed. No physical camera test was performed."
        runButton.setTitle("Run Self-Test", for: .normal)
    }
}
