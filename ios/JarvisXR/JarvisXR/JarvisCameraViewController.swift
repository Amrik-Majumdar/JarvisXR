import AVFoundation
import ImageIO
import UIKit
import Vision

final class JarvisCameraViewController: UIViewController, AVCapturePhotoCaptureDelegate, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
    private let session = AVCaptureSession()
    private let output = AVCapturePhotoOutput()
    private var activeCamera: AVCaptureDevice?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let statusLabel = UILabel()
    private let imageView = UIImageView()
    private let scanOverlay = JarvisScanOverlayView()
    private let torchButton = JarvisTheme.button(title: "Light")
    private var torchEnabled = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Inspection"
        view.backgroundColor = JarvisTheme.background
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .plain, target: self, action: #selector(doneTapped))
        buildInterface()
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-JARVIS_UI_TESTING") || arguments.contains("--jarvis-ui-test") {
            statusLabel.text = "Visual scan ready. \(JarvisObjectDetectionModel.statusLine())"
            return
        }
        requestCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = imageView.bounds
    }

    private func buildInterface() {
        statusLabel.text = "Camera ready. Align target."
        statusLabel.textColor = JarvisTheme.text
        statusLabel.font = JarvisTheme.bodyFont(size: 15)
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "jarvis.inspection.status"

        imageView.backgroundColor = JarvisTheme.panel
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.accessibilityIdentifier = "jarvis.inspection.preview"
        JarvisTheme.stylePanel(imageView)
        scanOverlay.translatesAutoresizingMaskIntoConstraints = false
        scanOverlay.accessibilityIdentifier = "jarvis.inspection.overlay"
        imageView.addSubview(scanOverlay)

        let captureButton = JarvisTheme.button(title: "Scan")
        captureButton.addTarget(self, action: #selector(captureTapped), for: .touchUpInside)

        torchButton.addTarget(self, action: #selector(torchTapped), for: .touchUpInside)

        let hooksLabel = UILabel()
        hooksLabel.text = "Text, code, and image classification run after capture. \(JarvisObjectDetectionModel.statusLine())"
        hooksLabel.textColor = JarvisTheme.mutedText
        hooksLabel.font = JarvisTheme.bodyFont(size: 12)
        hooksLabel.numberOfLines = 0

        captureButton.accessibilityLabel = "Capture inspection photo"
        captureButton.accessibilityIdentifier = "jarvis.inspection.scan"
        torchButton.accessibilityLabel = "Toggle inspection torch"
        torchButton.accessibilityIdentifier = "jarvis.inspection.light"

        let buttonRow = UIStackView(arrangedSubviews: [captureButton, torchButton])
        buttonRow.axis = .horizontal
        buttonRow.spacing = 8
        buttonRow.distribution = .fillEqually

        let stack = UIStackView(arrangedSubviews: [statusLabel, imageView, buttonRow, hooksLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            imageView.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.62),
            scanOverlay.topAnchor.constraint(equalTo: imageView.topAnchor),
            scanOverlay.leadingAnchor.constraint(equalTo: imageView.leadingAnchor),
            scanOverlay.trailingAnchor.constraint(equalTo: imageView.trailingAnchor),
            scanOverlay.bottomAnchor.constraint(equalTo: imageView.bottomAnchor)
        ])
    }

    private func requestCamera() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    granted ? self?.configureSession() : self?.showUnavailable("Camera permission denied.")
                }
            }
        default:
            showUnavailable("Camera permission unavailable. Enable camera access in Settings.")
        }
    }

    private func configureSession() {
        guard session.inputs.isEmpty else { return }
        session.beginConfiguration()
        session.sessionPreset = .photo
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: camera),
              session.canAddInput(input),
              session.canAddOutput(output) else {
            session.commitConfiguration()
            showUnavailable("Camera preview could not be configured.")
            return
        }
        activeCamera = camera
        configureCameraControls(camera)
        session.addInput(input)
        session.addOutput(output)
        session.commitConfiguration()

        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        imageView.layer.addSublayer(layer)
        previewLayer = layer
        DispatchQueue.global(qos: .userInitiated).async { [session] in
            session.startRunning()
        }
        let torch = camera.hasTorch ? "available" : "not available"
        let focus = camera.isFocusModeSupported(.continuousAutoFocus) ? "continuous autofocus" : "default focus"
        let exposure = camera.isExposureModeSupported(.continuousAutoExposure) ? "continuous auto exposure" : "default exposure"
        statusLabel.text = "Rear camera ready. Torch \(torch). \(focus). \(exposure)."
    }

    private func configureCameraControls(_ camera: AVCaptureDevice) {
        do {
            try camera.lockForConfiguration()
            if camera.isFocusModeSupported(.continuousAutoFocus) {
                camera.focusMode = .continuousAutoFocus
            }
            if camera.isExposureModeSupported(.continuousAutoExposure) {
                camera.exposureMode = .continuousAutoExposure
            }
            camera.unlockForConfiguration()
        } catch {
            statusLabel.text = "Camera ready. Focus or exposure configuration was unavailable."
        }
    }

    @objc private func captureTapped() {
        guard !session.inputs.isEmpty else {
            showUnavailable("Camera is not ready.")
            return
        }
        statusLabel.text = "Capturing."
        output.capturePhoto(with: AVCapturePhotoSettings(), delegate: self)
    }

    @objc private func torchTapped() {
        guard let camera = activeCamera, camera.hasTorch else {
            showUnavailable("Torch is unavailable on this camera.")
            return
        }
        do {
            try camera.lockForConfiguration()
            torchEnabled.toggle()
            camera.torchMode = torchEnabled ? .on : .off
            camera.unlockForConfiguration()
            statusLabel.text = torchEnabled ? "Light enabled." : "Light disabled."
        } catch {
            showUnavailable("Torch could not be changed.")
        }
    }

    @objc private func pickerTapped() {
        guard UIImagePickerController.isSourceTypeAvailable(.camera) else {
            showUnavailable("UIImagePicker camera source is unavailable.")
            return
        }
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = self
        present(picker, animated: true)
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            showUnavailable("Capture failed: \(error.localizedDescription)")
            return
        }
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else {
            showUnavailable("Capture data unavailable.")
            return
        }
        imageView.image = image
        analyzeCapturedImage(image, bytes: data.count)
    }

    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        picker.dismiss(animated: true)
        if let image = info[.originalImage] as? UIImage {
            imageView.image = image
            analyzeCapturedImage(image, bytes: 0)
        }
    }

    private func analyzeCapturedImage(_ image: UIImage, bytes: Int) {
        guard let cgImage = image.cgImage else {
            statusLabel.text = "Capture complete. Image metadata unavailable."
            return
        }
        statusLabel.text = "Reading text. Scanning codes. Classifying image."
        let textRequest = VNRecognizeTextRequest()
        textRequest.recognitionLevel = .fast
        textRequest.usesLanguageCorrection = true

        let barcodeRequest = VNDetectBarcodesRequest()
        let classificationRequest = VNClassifyImageRequest()
        let objectModel = JarvisObjectDetectionModel.makeVisionModel()
        let objectRequest = objectModel.map { model in
            VNCoreMLRequest(model: model)
        }
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: CGImagePropertyOrientation(image.imageOrientation), options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            var lines: [String] = []
            var codes: [String] = []
            var objects: [String] = []
            var classifications: [String] = []
            do {
                var requests: [VNRequest] = [textRequest, barcodeRequest, classificationRequest]
                if let objectRequest {
                    requests.append(objectRequest)
                }
                try handler.perform(requests)
                lines = (textRequest.results ?? [])
                    .compactMap { $0.topCandidates(1).first?.string }
                    .prefix(4)
                    .map { $0 }
                codes = (barcodeRequest.results ?? [])
                    .compactMap { $0.payloadStringValue }
                    .prefix(3)
                    .map { $0 }
                classifications = (classificationRequest.results ?? [])
                    .filter { $0.confidence >= 0.18 }
                    .prefix(4)
                    .map { "\($0.identifier) \(Int($0.confidence * 100))%" }
                if let classifications = objectRequest?.results as? [VNClassificationObservation] {
                    objects = classifications
                        .filter { $0.confidence >= 0.20 }
                        .prefix(4)
                        .map { "\($0.identifier) \(Int($0.confidence * 100))%" }
                } else if let recognizedObjects = objectRequest?.results as? [VNRecognizedObjectObservation] {
                    objects = recognizedObjects
                        .compactMap { observation in
                            observation.labels.first.map { "\($0.identifier) \(Int($0.confidence * 100))%" }
                        }
                        .prefix(4)
                        .map { $0 }
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusLabel.text = "Capture complete. Vision analysis unavailable on this frame."
                }
                return
            }
            DispatchQueue.main.async {
                var summary = "Capture complete. \(Int(image.size.width)) x \(Int(image.size.height))"
                if bytes > 0 {
                    summary += ". \(bytes) bytes."
                }
                if lines.isEmpty && codes.isEmpty && objects.isEmpty && classifications.isEmpty {
                    summary += "\nResults ready. No readable text, codes, or image labels found."
                } else {
                    summary += "\nResults ready."
                    if !lines.isEmpty {
                        summary += "\nText: " + lines.joined(separator: " | ")
                    }
                    if !codes.isEmpty {
                        summary += "\nCode: " + codes.joined(separator: " | ")
                    }
                    if !objects.isEmpty {
                        summary += "\nObjects: " + objects.joined(separator: " | ")
                    }
                    if !classifications.isEmpty {
                        summary += "\nImage: " + classifications.joined(separator: " | ")
                    } else if objects.isEmpty {
                        summary += "\n" + JarvisObjectDetectionModel.statusLine()
                    }
                }
                self.statusLabel.text = summary
                self.speakInspectionSummary(textLines: lines, codes: codes, objects: objects, classifications: classifications)
            }
        }
    }

    private func speakInspectionSummary(textLines: [String], codes: [String], objects: [String], classifications: [String]) {
        guard JarvisSpeechService.shared.isEnabled else { return }
        if let firstLine = textLines.first {
            JarvisSpeechService.shared.speak("Text found. \(firstLine)")
        } else if let firstCode = codes.first {
            JarvisSpeechService.shared.speak("Code found. \(firstCode)")
        } else if let firstObject = objects.first {
            JarvisSpeechService.shared.speak("Object signal. \(firstObject)")
        } else if let firstClassification = classifications.first {
            JarvisSpeechService.shared.speak("Visual scan complete. I see \(firstClassification).")
        } else {
            JarvisSpeechService.shared.speak("Scan complete. I did not find readable text, codes, or image labels.")
        }
    }

    private func showUnavailable(_ message: String) {
        statusLabel.text = message
    }

    @objc private func doneTapped() {
        if let camera = activeCamera, camera.hasTorch, camera.torchMode == .on {
            do {
                try camera.lockForConfiguration()
                camera.torchMode = .off
                camera.unlockForConfiguration()
            } catch {
                // Leaving the view should still succeed if torch configuration is unavailable.
            }
        }
        session.stopRunning()
        navigationController?.popViewController(animated: true)
    }
}

private final class JarvisScanOverlayView: UIView {
    private let border = CAShapeLayer()
    private let scanLine = CAGradientLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        layer.addSublayer(border)
        layer.addSublayer(scanLine)
        scanLine.colors = [
            UIColor.clear.cgColor,
            JarvisTheme.accentHot.withAlphaComponent(0.55).cgColor,
            UIColor.clear.cgColor
        ]
        scanLine.startPoint = CGPoint(x: 0, y: 0.5)
        scanLine.endPoint = CGPoint(x: 1, y: 0.5)
        startScan()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        border.frame = bounds
        border.path = UIBezierPath(roundedRect: bounds.insetBy(dx: 14, dy: 14), cornerRadius: 14).cgPath
        border.fillColor = UIColor.clear.cgColor
        border.strokeColor = JarvisTheme.accent.withAlphaComponent(0.62).cgColor
        border.lineWidth = 1.2
        border.lineDashPattern = [10, 8]
        scanLine.frame = CGRect(x: 18, y: 24, width: max(0, bounds.width - 36), height: 5)
    }

    private func startScan() {
        let animation = CABasicAnimation(keyPath: "position.y")
        animation.fromValue = 30
        animation.toValue = 520
        animation.duration = 2.4
        animation.autoreverses = true
        animation.repeatCount = .infinity
        scanLine.add(animation, forKey: "scan")
    }
}

private extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .down: self = .down
        case .left: self = .left
        case .right: self = .right
        case .upMirrored: self = .upMirrored
        case .downMirrored: self = .downMirrored
        case .leftMirrored: self = .leftMirrored
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
