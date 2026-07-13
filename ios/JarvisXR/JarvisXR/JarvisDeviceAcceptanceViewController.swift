import AVFoundation
import CoreImage
import Speech
import UIKit

/// A voice-first physical-device acceptance flow. It never uploads its report and
/// distinguishes automated checks from user-confirmed physical observations.
final class JarvisDeviceAcceptanceViewController: UIViewController {
    private enum Prompt {
        case flashlightOn
        case flashlightOff
        case haptics
        case voices
        case coverCamera
        case uncoverCamera
    }

    private let scrollView = UIScrollView()
    private let stack = UIStackView()
    private let statusLabel = UILabel()
    private let reportLabel = UILabel()
    private let voiceButton = JarvisTheme.button(title: "Answer by Voice")
    private let skipButton = JarvisTheme.button(title: "Skip Current Question")
    private let stopButton = JarvisTheme.button(title: "Stop Device Test")
    private let shareButton = JarvisTheme.button(title: "Share Report")
    private let speech = JarvisSpeechService.shared
    private let voiceInput = JarvisVoiceInputService.shared
    private let camera = CameraSessionService()
    private let pipeline = VisionPipelineCoordinator()
    private var detector: ObjectDetectionService?
    private var textRecognizer: TextRecognitionService?
    private var barcodeRecognizer: BarcodeRecognitionService?
    private var hapticSessionID: UUID?
    private var pendingPrompt: Prompt?
    private var promptText = ""
    private var report: JarvisDeviceAcceptanceReport!
    private var exportedReportURL: URL?
    private var runIdentifier = UUID()
    private var voiceSampleStage = 0
    private var isFinished = false
    private var originalSpeechProfile: JarvisVoiceProfile?
    private var isUITestMode: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("--jarvis-ui-test") || arguments.contains("-JARVIS_UI_TESTING")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Complete Device Test"
        view.backgroundColor = JarvisTheme.background
        buildInterface()
        isUITestMode ? applyFixtureState() : begin()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isMovingFromParent || navigationController?.topViewController !== self else { return }
        stopWork()
    }

    deinit { stopWork() }

    private func buildInterface() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        stack.spacing = 14
        view.addSubview(scrollView)
        scrollView.addSubview(stack)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
        ])

        let heading = label("Complete Device Test", style: .title2, color: JarvisTheme.text)
        heading.accessibilityTraits.insert(.header)
        heading.accessibilityIdentifier = "jarvis.deviceTest.header"
        let explanation = label(
            "Jarvis runs local checks first, then asks a few short spoken questions for physical behavior. Say yes, no, different, continue, repeat, skip, or stop. The report stays on this iPhone until you choose Share Report.",
            style: .body,
            color: JarvisTheme.mutedText
        )
        statusLabel.text = "Preparing device test."
        statusLabel.textColor = JarvisTheme.accentHot
        statusLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.numberOfLines = 0
        statusLabel.accessibilityIdentifier = "jarvis.deviceTest.status"

        reportLabel.text = "No checks recorded yet."
        reportLabel.textColor = JarvisTheme.text
        reportLabel.font = UIFont.preferredFont(forTextStyle: .body)
        reportLabel.adjustsFontForContentSizeCategory = true
        reportLabel.numberOfLines = 0
        reportLabel.accessibilityIdentifier = "jarvis.deviceTest.report"
        let panel = JarvisPanelView()
        panel.translatesAutoresizingMaskIntoConstraints = false
        reportLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(reportLabel)
        NSLayoutConstraint.activate([
            reportLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            reportLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            reportLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            reportLabel.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])

        voiceButton.accessibilityHint = "Starts listening for yes, no, different, continue, repeat, skip, or stop."
        voiceButton.accessibilityIdentifier = "jarvis.deviceTest.voice"
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        skipButton.accessibilityHint = "Marks the current physical question as skipped and continues the device test."
        skipButton.accessibilityIdentifier = "jarvis.deviceTest.skip"
        skipButton.addTarget(self, action: #selector(skipTapped), for: .touchUpInside)
        stopButton.backgroundColor = JarvisTheme.error
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.accessibilityHint = "Stops the test, camera, speech, and haptics and saves a partial local report."
        stopButton.accessibilityIdentifier = "jarvis.deviceTest.stop"
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        shareButton.isEnabled = false
        shareButton.accessibilityHint = "Opens the iOS share sheet for the local JSON device report."
        shareButton.accessibilityIdentifier = "jarvis.deviceTest.share"
        shareButton.addTarget(self, action: #selector(shareTapped), for: .touchUpInside)
        [heading, explanation, statusLabel, panel, voiceButton, skipButton, stopButton, shareButton].forEach(stack.addArrangedSubview)
    }

    private func begin() {
        originalSpeechProfile = speech.profile
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        report = JarvisDeviceAcceptanceReport(
            appVersion: version,
            build: build,
            iOSVersion: UIDevice.current.systemVersion,
            deviceCapabilitySummary: capabilitySummary()
        )
        wireVoiceInput()
        status("Running automatic local checks.")
        speak("Starting the complete device test. I will run local checks, then ask short questions.")
        runAutomaticChecks()
    }

    private func applyFixtureState() {
        report = JarvisDeviceAcceptanceReport(
            appVersion: "fixture",
            build: "fixture",
            iOSVersion: UIDevice.current.systemVersion,
            deviceCapabilitySummary: ["device_family": "fixture"]
        )
        record("application.launch", "Application and iOS", .passed, .automated, ["fixture": "true"])
        record("camera.frames", "Live camera frame arrival", .skipped, .unavailable, ["fixture": "camera not active"])
        record("live_guide.processing", "Live Guide processing", .passed, .automated, ["fixture": "deterministic state"])
        report.complete()
        isFinished = true
        status("DEMO FIXTURE: Device test report surface. No camera, microphone, torch, or haptic hardware was tested.")
        refreshReport()
    }

    private func runAutomaticChecks() {
        record("application.launch", "Application and iOS", .passed, .automated, [
            "version": report.appVersion,
            "build": report.build,
            "ios": report.iOSVersion,
            "minimum_ios": "18.0",
        ])
        let preferences = VisionPreferencesStore.shared.value
        let privateByDefault = !preferences.storesCapturedImages && !preferences.storesCapturedVideo &&
            !preferences.persistsRecognizedText && !preferences.allowsNetworkVisionProcessing
        record("privacy.defaults", "Privacy defaults", privateByDefault ? .passed : .attention, .automated, [
            "stores_images": "\(preferences.storesCapturedImages)",
            "stores_video": "\(preferences.storesCapturedVideo)",
            "persists_text": "\(preferences.persistsRecognizedText)",
            "network_vision": "\(preferences.allowsNetworkVisionProcessing)",
        ])
        let configuration = speech.resolvedConfiguration(for: speech.profile)
        record("audio.configuration", "Speech configuration", speech.isEnabled ? .passed : .attention, .automated, [
            "voice_identifier": configuration.voiceIdentifier ?? "fallback",
            "locale": configuration.locale,
            "rate": "\(configuration.rate)",
            "pitch": "\(configuration.pitch)",
            "volume": "\(configuration.volume)",
            "microphone_authorization": authorizationText(AVCaptureDevice.authorizationStatus(for: .audio)),
            "speech_authorization": speechAuthorizationText(SFSpeechRecognizer.authorizationStatus()),
            "audio_input_available": "\(AVAudioSession.sharedInstance().isInputAvailable)",
        ])
        record("accessibility.environment", "Accessibility environment", .passed, .automated, [
            "voiceover": "\(UIAccessibility.isVoiceOverRunning)",
            "reduce_motion": "\(UIAccessibility.isReduceMotionEnabled)",
            "increased_contrast": "\(UIAccessibility.isDarkerSystemColorsEnabled)",
            "dynamic_type": UIApplication.shared.preferredContentSizeCategory.rawValue,
            "primary_identifiers": "jarvis.orb, jarvis.vision.voice, jarvis.vision.stop",
        ])
        record("haptics.capability", "Haptic capability", VisionHapticsService.shared.backend == .unavailable ? .attention : .passed, .automated, [
            "backend": VisionHapticsService.shared.backend.rawValue,
        ])

        let fixture = makeFixtureImage()
        let barcode = makeBarcodeFixture()
        guard let fixture, let barcode else {
            record("fixtures.generation", "Local test fixtures", .attention, .automated, [:], "Could not generate a local fixture.")
            startLiveCameraValidation()
            return
        }
        let group = DispatchGroup()
        let lock = NSLock()
        var results: [JarvisDeviceAcceptanceCheck] = []
        let detector = ObjectDetectionService()
        let text = TextRecognitionService()
        let barcodeRecognizer = BarcodeRecognitionService()
        self.detector = detector
        textRecognizer = text
        self.barcodeRecognizer = barcodeRecognizer

        group.enter()
        detector.prepare { result in
            lock.lock(); defer { lock.unlock() }
            switch result {
            case .success(let metadata):
                results.append(JarvisDeviceAcceptanceCheck(
                    identifier: "model.resource", title: "Object model resource", status: metadata.checksumVerified ? .passed : .attention,
                    method: .automated, measuredValues: ["name": metadata.name, "version": metadata.version, "checksum_verified": "\(metadata.checksumVerified)"], error: nil, recordedAt: Date()
                ))
            case .failure(let error):
                results.append(JarvisDeviceAcceptanceCheck(identifier: "model.resource", title: "Object model resource", status: .attention, method: .automated, measuredValues: [:], error: String(describing: error), recordedAt: Date()))
            }
            group.leave()
        }
        group.enter()
        detector.detectObjects(in: fixture, orientation: .up) { result in
            lock.lock(); defer { lock.unlock() }
            switch result {
            case .success(let observations):
                results.append(JarvisDeviceAcceptanceCheck(identifier: "model.inference", title: "Object model execution", status: .passed, method: .automated, measuredValues: ["observation_count": "\(observations.observations.count)", "latency_seconds": "\(observations.latency)"], error: nil, recordedAt: Date()))
            case .failure(let error):
                results.append(JarvisDeviceAcceptanceCheck(identifier: "model.inference", title: "Object model execution", status: .attention, method: .automated, measuredValues: [:], error: String(describing: error), recordedAt: Date()))
            }
            group.leave()
        }
        group.enter()
        text.recognize(in: fixture, orientation: .up, mode: .accurate) { result in
            lock.lock(); defer { lock.unlock() }
            switch result {
            case .success(let value):
                let recognized = value.observation.recognizedText.uppercased().contains("JARVIS")
                results.append(JarvisDeviceAcceptanceCheck(identifier: "vision.ocr", title: "OCR availability", status: recognized ? .passed : .attention, method: .automated, measuredValues: ["recognized_jarvis": "\(recognized)"], error: nil, recordedAt: Date()))
            case .failure(let error):
                results.append(JarvisDeviceAcceptanceCheck(identifier: "vision.ocr", title: "OCR availability", status: .attention, method: .automated, measuredValues: [:], error: String(describing: error), recordedAt: Date()))
            }
            group.leave()
        }
        group.enter()
        barcodeRecognizer.recognize(in: barcode, orientation: .up) { result in
            lock.lock(); defer { lock.unlock() }
            switch result {
            case .success(let value):
                let matched = value.observations.contains { $0.payload == "JARVIS-DEVICE-TEST" }
                results.append(JarvisDeviceAcceptanceCheck(identifier: "vision.barcode", title: "Barcode availability", status: matched ? .passed : .attention, method: .automated, measuredValues: ["matched_fixture": "\(matched)"], error: nil, recordedAt: Date()))
            case .failure(let error):
                results.append(JarvisDeviceAcceptanceCheck(identifier: "vision.barcode", title: "Barcode availability", status: .attention, method: .automated, measuredValues: [:], error: String(describing: error), recordedAt: Date()))
            }
            group.leave()
        }
        group.notify(queue: .main) { [weak self] in
            guard let self, !self.isFinished else { return }
            results.forEach { self.report.append($0) }
            self.refreshReport()
            self.startLiveCameraValidation()
        }
    }

    private func startLiveCameraValidation() {
        status("Starting the rear camera and Live Guide test.")
        pipeline.bind(to: camera)
        pipeline.onNarration = { [weak self] narration in
            DispatchQueue.main.async {
                guard let self, !self.isFinished, narration.contentKind == .system else { return }
                self.record("live_guide.heartbeat", "Live Guide activity feedback", .passed, .automated, ["text": narration.text])
            }
        }
        pipeline.onError = { [weak self] error in
            DispatchQueue.main.async {
                guard let self, !self.isFinished else { return }
                self.record("live_guide.last_error", "Live Guide recoverable error", .attention, .automated, [:], String(describing: error))
            }
        }
        camera.requestAccessAndStart(position: .rear) { [weak self] result in
            guard let self, !self.isFinished else { return }
            switch result {
            case .failure(let error):
                self.record("camera.start", "Camera startup", .attention, .automated, [:], error.localizedDescription)
                self.askHapticQuestion()
            case .success:
                self.pipeline.start(mode: .liveGuide)
                DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.evaluateLiveCamera() }
            }
        }
    }

    private func evaluateLiveCamera() {
        guard !isFinished else { return }
        let frames = camera.frameDiagnostics
        let snapshot = VisionDiagnosticsStore.shared.snapshot()
        let framePassed = frames.deliveredFrameCount > 0
        record("camera.frames", "Live camera frame arrival", framePassed ? .passed : .attention, .automated, [
            "delivered": "\(frames.deliveredFrameCount)", "dropped": "\(frames.droppedFrameCount)",
            "width": frames.lastFrameWidth.map { String($0) } ?? "unknown",
            "height": frames.lastFrameHeight.map { String($0) } ?? "unknown",
            "pixel_format": frames.lastPixelFormat.map { String($0) } ?? "unknown",
            "orientation": frames.lastOrientation.map { String(describing: $0) } ?? "unknown",
            "condition": snapshot.lastFrameCondition?.rawValue ?? "unknown",
            "brightness": snapshot.lastFrameBrightness.map { String($0) } ?? "unknown",
        ], frames.lastIssue?.diagnosticLabel)
        record("live_guide.processing", "Live Guide processing", pipeline.statistics.analyzedFrameCount > 0 ? .passed : .attention, .automated, [
            "analyzed_frames": "\(pipeline.statistics.analyzedFrameCount)",
            "mode": pipeline.currentMode.rawValue,
            "state": pipeline.sessionState.rawValue,
        ])
        askFlashlightOnQuestion()
    }

    private func askFlashlightOnQuestion() {
        guard camera.state == .running else { askHapticQuestion(); return }
        camera.setTorch(enabled: true) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let enabled):
                self.record("flashlight.on", "Flashlight activation", enabled ? .passed : .attention, .automated, ["reported_on": "\(enabled)"])
                self.ask(.flashlightOn, "I turned on the flashlight. Say yes if the light is on, no if it is not, or skip.")
            case .failure(let error):
                self.record("flashlight.on", "Flashlight activation", .attention, .automated, [:], error.localizedDescription)
                self.askHapticQuestion()
            }
        }
    }

    private func askFlashlightOffQuestion() {
        camera.setTorch(enabled: false) { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let enabled):
                self.record("flashlight.off", "Flashlight deactivation", !enabled ? .passed : .attention, .automated, ["reported_on": "\(enabled)"])
                self.ask(.flashlightOff, "I turned off the flashlight. Say yes if the light is off, no if it is still on, or skip.")
            case .failure(let error):
                self.record("flashlight.off", "Flashlight deactivation", .attention, .automated, [:], error.localizedDescription)
                self.askHapticQuestion()
            }
        }
    }

    private func askHapticQuestion() {
        let haptics = VisionHapticsService.shared
        if haptics.backend == .unavailable {
            record("haptics.physical", "Physical haptic confirmation", .skipped, .unavailable, ["backend": haptics.backend.rawValue])
            askVoiceQuestion()
            return
        }
        hapticSessionID = haptics.beginSession()
        if let hapticSessionID { haptics.play(.targetAcquired, intensity: .standard, sessionID: hapticSessionID) }
        ask(.haptics, "You should feel three pulses. Say yes if you felt them, no if you did not, or skip.")
    }

    private func askVoiceQuestion() {
        voiceSampleStage = 0
        pendingPrompt = .voices
        status("Playing two speech profiles.")
        speakNextVoiceSample()
    }

    private func speakNextVoiceSample() {
        switch voiceSampleStage {
        case 0:
            voiceSampleStage = 1
            _ = speech.selectProfile(.natural)
            speech.speak("First voice sample. Jarvis is ready.")
        case 1:
            voiceSampleStage = 2
            _ = speech.selectProfile(.crisp)
            speech.speak("Second voice sample. Jarvis is ready.")
        default:
            ask(.voices, "Say different if the two voices sounded different, no if they did not, or skip.", speaksImmediately: false)
        }
    }

    private func askCoverQuestion() {
        ask(.coverCamera, "Cover the rear camera now. When it is covered, say continue. You can also say skip or stop.")
    }

    private func askUncoverQuestion() {
        ask(.uncoverCamera, "Uncover the rear camera now and point it toward a lit room. When it is uncovered, say continue. You can also say skip or stop.")
    }

    private func ask(_ prompt: Prompt, _ text: String, speaksImmediately: Bool = true) {
        pendingPrompt = prompt
        promptText = text
        status(text)
        if speaksImmediately { speak(text) } else { beginListeningForAnswer() }
    }

    private func wireVoiceInput() {
        voiceInput.onPartialTranscript = { [weak self] text in self?.status("Listening: \(text)") }
        voiceInput.onFinalTranscript = { [weak self] raw in self?.handleVoice(raw) }
        voiceInput.onStateChange = { [weak self] state in
            guard let self else { return }
            if case .unavailable(let message) = state {
                self.record("audio.voice_input", "Voice response input", .attention, .unavailable, [:], message)
                self.status("\(message) Use Skip Current Question or Stop Device Test.")
            }
        }
        speech.onSpeechFinish = { [weak self] in
            guard let self, !self.isFinished else { return }
            if self.pendingPrompt == .voices, self.voiceSampleStage < 3 {
                self.speakNextVoiceSample()
            } else if self.pendingPrompt != nil {
                self.beginListeningForAnswer()
            }
        }
    }

    private func beginListeningForAnswer() {
        guard pendingPrompt != nil, !isFinished else { return }
        voiceButton.setTitle("Listening…", for: .normal)
        voiceInput.startListening()
    }

    private func handleVoice(_ raw: String) {
        voiceButton.setTitle("Answer by Voice", for: .normal)
        let normalized = JarvisCommandPlanner().normalize(raw)
        let answer = JarvisDeviceAcceptanceResponse.parse(normalized)
        guard let prompt = pendingPrompt else {
            speak("There is no question waiting. The device test is continuing.")
            return
        }
        switch answer {
        case .repeat:
            speak(promptText)
        case .stop:
            finish(stoppedByUser: true)
        case .skip:
            record("confirmation.\(promptKey(prompt))", promptTitle(prompt), .skipped, .userConfirmed, ["response": "skip"])
            advance(after: prompt)
        case .yes, .different:
            record("confirmation.\(promptKey(prompt))", promptTitle(prompt), .passed, .userConfirmed, ["response": normalized])
            advance(after: prompt)
        case .no:
            record("confirmation.\(promptKey(prompt))", promptTitle(prompt), .attention, .userConfirmed, ["response": "no"])
            advance(after: prompt)
        case .continue where prompt == .coverCamera:
            pendingPrompt = nil
            status("Checking sustained covered-camera evidence.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.evaluateCoverState() }
        case .continue where prompt == .uncoverCamera:
            pendingPrompt = nil
            status("Checking camera recovery.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in self?.evaluateUncoveredState() }
        case .continue:
            speak("Please answer yes, no, different, repeat, skip, or stop.")
        case .unknown:
            speak("I did not understand. Say yes, no, different, continue, repeat, skip, or stop.")
        }
    }

    private func advance(after prompt: Prompt) {
        pendingPrompt = nil
        switch prompt {
        case .flashlightOn: askFlashlightOffQuestion()
        case .flashlightOff: askHapticQuestion()
        case .haptics: askVoiceQuestion()
        case .voices: askCoverQuestion()
        case .coverCamera: askUncoverQuestion()
        case .uncoverCamera: verifyStopCancellation()
        }
    }

    private func evaluateCoverState() {
        let condition = VisionDiagnosticsStore.shared.snapshot().lastFrameCondition
        let passed = condition == .obstructed
        record("camera.covered_transition", "Covered-camera transition", passed ? .passed : .attention, .automated, ["condition": condition?.rawValue ?? "unknown"])
        askUncoverQuestion()
    }

    private func evaluateUncoveredState() {
        let condition = VisionDiagnosticsStore.shared.snapshot().lastFrameCondition
        let passed = condition != .obstructed && condition != .invalidPixelBuffer
        record("camera.uncovered_transition", "Uncovered-camera recovery", passed ? .passed : .attention, .automated, ["condition": condition?.rawValue ?? "unknown"])
        verifyStopCancellation()
    }

    private func verifyStopCancellation() {
        pendingPrompt = nil
        if let hapticSessionID {
            VisionHapticsService.shared.endSession(hapticSessionID)
            self.hapticSessionID = nil
        }
        pipeline.stop()
        camera.stop()
        speech.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self else { return }
            let stopped = self.pipeline.sessionState == .stopped
            self.record("stop.cancellation", "Stop cancellation", stopped ? .passed : .attention, .automated, ["pipeline_state": self.pipeline.sessionState.rawValue])
            self.finish(stoppedByUser: false)
        }
    }

    private func finish(stoppedByUser: Bool) {
        guard !isFinished else { return }
        isFinished = true
        pendingPrompt = nil
        stopWork()
        if stoppedByUser {
            record("test.completion", "Device test completion", .skipped, .userConfirmed, ["reason": "stopped by user"])
            report.limitations.append("The user stopped the device test before all physical confirmations were completed.")
        }
        if let originalSpeechProfile { _ = speech.selectProfile(originalSpeechProfile) }
        report.limitations.append("Physical camera focus, real-scene detection accuracy, battery life, heat, Bluetooth routing, and VoiceOver traversal still need human judgment.")
        report.complete()
        do {
            exportedReportURL = try JarvisDeviceAcceptanceReportStore.write(report)
            shareButton.isEnabled = true
            status("Device test complete. Your local JSON report is ready to share.")
            speak("Device test complete. The local report is ready to share.")
        } catch {
            status("Device test complete, but Jarvis could not save the report. \(error.localizedDescription)")
        }
        refreshReport()
        UIAccessibility.post(notification: .layoutChanged, argument: reportLabel)
    }

    private func stopWork() {
        runIdentifier = UUID()
        voiceInput.cancel()
        pipeline.stop()
        pipeline.unbindCamera()
        camera.stop()
        camera.shutdown()
        detector?.cancelAll()
        textRecognizer?.cancelAll()
        barcodeRecognizer?.cancelAll()
        if let hapticSessionID { VisionHapticsService.shared.endSession(hapticSessionID) }
        hapticSessionID = nil
    }

    private func record(
        _ identifier: String,
        _ title: String,
        _ status: JarvisDeviceAcceptanceStatus,
        _ method: JarvisDeviceAcceptanceMethod,
        _ values: [String: String],
        _ error: String? = nil
    ) {
        guard report != nil else { return }
        report.append(JarvisDeviceAcceptanceCheck(identifier: identifier, title: title, status: status, method: method, measuredValues: values, error: error, recordedAt: Date()))
        refreshReport()
    }

    private func refreshReport() {
        guard report != nil else { return }
        let passed = report.checks.filter { $0.status == .passed }.count
        let attention = report.checks.filter { $0.status == .attention }.count
        let skipped = report.checks.filter { $0.status == .skipped }.count
        let latest = report.checks.suffix(6).map { "\($0.status.rawValue.uppercased()): \($0.title)" }.joined(separator: "\n")
        reportLabel.text = "Checks: \(report.checks.count) • Passed: \(passed) • Attention: \(attention) • Skipped: \(skipped)\n\n\(latest)"
    }

    private func status(_ text: String) {
        statusLabel.text = text
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func speak(_ text: String) {
        guard speech.isEnabled else {
            beginListeningForAnswer()
            return
        }
        speech.speak(text)
    }

    @objc private func voiceTapped() { beginListeningForAnswer() }
    @objc private func skipTapped() {
        guard let prompt = pendingPrompt else { return }
        record("confirmation.\(promptKey(prompt))", promptTitle(prompt), .skipped, .userConfirmed, ["response": "touch skip"])
        advance(after: prompt)
    }
    @objc private func stopTapped() { finish(stoppedByUser: true) }
    @objc private func shareTapped() {
        guard let exportedReportURL else { return }
        present(UIActivityViewController(activityItems: [exportedReportURL], applicationActivities: nil), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    private func capabilitySummary() -> [String: String] {
        let rear = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
        let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
        return [
            "device_family": UIDevice.current.userInterfaceIdiom == .phone ? "iPhone" : "non-iPhone",
            "rear_camera": "\(rear != nil)",
            "front_camera": "\(front != nil)",
            "torch": "\(rear?.hasTorch ?? false)",
            "haptics_backend": VisionHapticsService.shared.backend.rawValue,
            "low_power_mode": "\(ProcessInfo.processInfo.isLowPowerModeEnabled)",
            "thermal_state": "\(ProcessInfo.processInfo.thermalState.rawValue)",
        ]
    }

    private func makeFixtureImage() -> CGImage? {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 960, height: 360))
        return renderer.image { context in
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 960, height: 360))
            NSString(string: "JARVIS DEVICE TEST").draw(in: CGRect(x: 42, y: 112, width: 880, height: 140), withAttributes: [
                .font: UIFont.systemFont(ofSize: 72, weight: .bold), .foregroundColor: UIColor.black,
            ])
        }.cgImage
    }

    private func makeBarcodeFixture() -> CGImage? {
        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(Data("JARVIS-DEVICE-TEST".utf8), forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        guard let image = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 14, y: 14)) else { return nil }
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(image, from: image.extent)
    }

    private func promptKey(_ prompt: Prompt) -> String {
        switch prompt {
        case .flashlightOn: return "flashlight_on"
        case .flashlightOff: return "flashlight_off"
        case .haptics: return "haptics"
        case .voices: return "voices"
        case .coverCamera: return "cover_camera"
        case .uncoverCamera: return "uncover_camera"
        }
    }

    private func promptTitle(_ prompt: Prompt) -> String {
        switch prompt {
        case .flashlightOn: return "Physical flashlight-on confirmation"
        case .flashlightOff: return "Physical flashlight-off confirmation"
        case .haptics: return "Physical haptic confirmation"
        case .voices: return "Physical voice-profile confirmation"
        case .coverCamera: return "Covered-camera preparation"
        case .uncoverCamera: return "Uncovered-camera preparation"
        }
    }

    private func authorizationText(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not_determined"
        @unknown default: return "unknown"
        }
    }

    private func speechAuthorizationText(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized: return "authorized"
        case .denied: return "denied"
        case .restricted: return "restricted"
        case .notDetermined: return "not_determined"
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
}
