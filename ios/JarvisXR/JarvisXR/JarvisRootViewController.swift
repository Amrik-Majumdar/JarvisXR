import UIKit

final class JarvisRootViewController: UIViewController, UITextFieldDelegate {
    private let assistant = JarvisAssistantCore()
    private let memory = JarvisMemoryStore.shared
    private let speech = JarvisSpeechService.shared
    private let voiceInput = JarvisVoiceInputService.shared

    private let backgroundLayer = CAGradientLayer()
    private let wordmarkLabel = UILabel()
    private let subtitleLabel = UILabel()
    private let orbView = JarvisOrbView()
    private let stateLabel = UILabel()
    private let hintLabel = UILabel()
    private let transientResponseLabel = UILabel()
    private let inputContainer = JarvisPanelView()
    private let commandField = UITextField()
    private let submitButton = UIButton(type: .system)
    private let menuButton = UIButton(type: .system)
    private let helpButton = UIButton(type: .system)

    private var inputBottomConstraint: NSLayoutConstraint?
    private var wordmarkTopConstraint: NSLayoutConstraint?
    private var orbCenterYConstraint: NSLayoutConstraint?
    private var orbWidthMultiplierConstraint: NSLayoutConstraint?
    private var orbMaxWidthConstraint: NSLayoutConstraint?
    private var responseHideWorkItem: DispatchWorkItem?
    private var didCheckFirstLaunch = false
    private var interfaceState: JarvisInteractionState = .standby
    private var longPressSuppressesNextTap = false
    private var didApplyVisualProofState = false
    private var pendingVisionRequestAfterOnboarding: JarvisVisionLaunchRequest?
    private var isUITestMode: Bool {
        let arguments = ProcessInfo.processInfo.arguments
        return arguments.contains("-JARVIS_UI_TESTING") || arguments.contains("--jarvis-ui-test")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "JARVIS"
        view.backgroundColor = JarvisTheme.background
        navigationController?.setNavigationBarHidden(true, animated: false)
        buildInterface()
        wireVoice()
        NotificationCenter.default.addObserver(self, selector: #selector(deepLinkReceived(_:)), name: .jarvisDeepLinkReceived, object: nil)
        setInterfaceState(speech.isEnabled ? .standby : .quiet, hint: "Ready when you are.")
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        navigationController?.setNavigationBarHidden(true, animated: animated)
        if let pending = JarvisPendingIntentStore.consumeAction() {
            handle(action: pending)
            return
        }
        applyVisualProofStateIfNeeded()
        if !didCheckFirstLaunch {
            didCheckFirstLaunch = true
            showFirstLaunchIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        // The Vision screen temporarily owns the shared in-app voice callbacks.
        // Rewire them whenever the user returns to the main Jarvis surface.
        wireVoice()
        if interfaceState == .inspection {
            setInterfaceState(.ready, hint: "Jarvis Vision closed. Ready when you are.")
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        voiceInput.cancel()
    }

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        .portrait
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backgroundLayer.frame = view.bounds
    }

    private func buildInterface() {
        backgroundLayer.colors = [
            UIColor(red: 0.002, green: 0.005, blue: 0.009, alpha: 1).cgColor,
            UIColor(red: 0.010, green: 0.020, blue: 0.026, alpha: 1).cgColor,
            UIColor(red: 0.000, green: 0.000, blue: 0.000, alpha: 1).cgColor
        ]
        backgroundLayer.locations = [0, 0.48, 1]
        view.layer.insertSublayer(backgroundLayer, at: 0)

        wordmarkLabel.text = "JARVIS"
        wordmarkLabel.textColor = JarvisTheme.text
        wordmarkLabel.font = UIFontMetrics(forTextStyle: .largeTitle).scaledFont(for: JarvisTheme.titleFont(size: 32))
        wordmarkLabel.adjustsFontForContentSizeCategory = true
        wordmarkLabel.textAlignment = .center
        wordmarkLabel.letterSpacing(5.5)
        wordmarkLabel.accessibilityLabel = "JARVIS"
        wordmarkLabel.accessibilityIdentifier = "jarvis.wordmark"

        subtitleLabel.text = "Voice-first visual assistance"
        subtitleLabel.textColor = JarvisTheme.mutedText
        subtitleLabel.font = UIFont.preferredFont(forTextStyle: .footnote)
        subtitleLabel.adjustsFontForContentSizeCategory = true
        subtitleLabel.textAlignment = .center
        subtitleLabel.accessibilityIdentifier = "jarvis.subtitle"

        orbView.translatesAutoresizingMaskIntoConstraints = false
        orbView.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: self, action: #selector(orbTapped))
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(orbLongPressed(_:)))
        longPress.minimumPressDuration = 0.72
        tap.require(toFail: longPress)
        orbView.addGestureRecognizer(tap)
        orbView.addGestureRecognizer(longPress)
        orbView.accessibilityHint = "Tap to wake, listen, or process. Long hold to standby."
        orbView.accessibilityIdentifier = "jarvis.orb"

        stateLabel.textColor = JarvisTheme.accentHot
        stateLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        stateLabel.adjustsFontForContentSizeCategory = true
        stateLabel.textAlignment = .center
        stateLabel.accessibilityIdentifier = "jarvis.state"

        hintLabel.textColor = JarvisTheme.mutedText
        hintLabel.font = UIFont.preferredFont(forTextStyle: .body)
        hintLabel.adjustsFontForContentSizeCategory = true
        hintLabel.textAlignment = .center
        hintLabel.numberOfLines = 2
        hintLabel.accessibilityIdentifier = "jarvis.hint"

        transientResponseLabel.textColor = JarvisTheme.text
        transientResponseLabel.font = UIFont.preferredFont(forTextStyle: .body)
        transientResponseLabel.adjustsFontForContentSizeCategory = true
        transientResponseLabel.textAlignment = .center
        transientResponseLabel.numberOfLines = 3
        transientResponseLabel.alpha = 0
        transientResponseLabel.accessibilityIdentifier = "jarvis.transientResponse"

        commandField.delegate = self
        commandField.attributedPlaceholder = NSAttributedString(
            string: "Command JARVIS",
            attributes: [.foregroundColor: JarvisTheme.mutedText]
        )
        commandField.textColor = JarvisTheme.text
        commandField.tintColor = JarvisTheme.accent
        commandField.font = UIFont.preferredFont(forTextStyle: .body)
        commandField.adjustsFontForContentSizeCategory = true
        commandField.autocorrectionType = .no
        commandField.autocapitalizationType = .sentences
        commandField.returnKeyType = .send
        commandField.borderStyle = .none
        commandField.setLeftPadding(4)
        commandField.accessibilityLabel = "Command input"
        commandField.accessibilityIdentifier = "jarvis.commandInput"

        submitButton.setTitle("Send", for: .normal)
        submitButton.setTitleColor(JarvisTheme.background, for: .normal)
        submitButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        submitButton.titleLabel?.adjustsFontForContentSizeCategory = true
        submitButton.backgroundColor = JarvisTheme.accentHot
        submitButton.layer.cornerRadius = 14
        submitButton.addTarget(self, action: #selector(submitTapped), for: .touchUpInside)
        submitButton.accessibilityLabel = "Send command"
        submitButton.accessibilityIdentifier = "jarvis.send"

        menuButton.setTitle("Vision", for: .normal)
        menuButton.setTitleColor(JarvisTheme.mutedText, for: .normal)
        menuButton.titleLabel?.font = UIFontMetrics(forTextStyle: .caption1).scaledFont(for: JarvisTheme.titleFont(size: 12))
        menuButton.titleLabel?.adjustsFontForContentSizeCategory = true
        menuButton.titleLabel?.adjustsFontSizeToFitWidth = true
        menuButton.titleLabel?.minimumScaleFactor = 0.7
        menuButton.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        menuButton.layer.cornerRadius = 13
        menuButton.layer.borderWidth = 1
        menuButton.layer.borderColor = UIColor.white.withAlphaComponent(0.10).cgColor
        menuButton.showsMenuAsPrimaryAction = true
        menuButton.menu = utilityMenu()
        menuButton.accessibilityLabel = "Jarvis Vision and systems"
        menuButton.accessibilityIdentifier = "jarvis.meshMenu"

        helpButton.setTitle("?", for: .normal)
        helpButton.setTitleColor(JarvisTheme.accentHot, for: .normal)
        helpButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title2)
        helpButton.titleLabel?.adjustsFontForContentSizeCategory = true
        helpButton.backgroundColor = UIColor.white.withAlphaComponent(0.06)
        helpButton.layer.cornerRadius = 18
        helpButton.layer.borderWidth = 1
        helpButton.layer.borderColor = JarvisTheme.accent.withAlphaComponent(0.42).cgColor
        helpButton.addTarget(self, action: #selector(helpTapped), for: .touchUpInside)
        helpButton.accessibilityLabel = "JARVIS help"
        helpButton.accessibilityIdentifier = "jarvis.help"

        let inputRow = UIStackView(arrangedSubviews: [commandField, submitButton])
        inputRow.axis = .horizontal
        inputRow.alignment = .center
        inputRow.spacing = 10
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        inputContainer.addSubview(inputRow)
        inputContainer.backgroundColor = UIColor(red: 0.025, green: 0.033, blue: 0.040, alpha: 0.92)
        inputContainer.layer.cornerRadius = JarvisDesignSystem.Radius.commandBar

        [wordmarkLabel, subtitleLabel, orbView, stateLabel, hintLabel, transientResponseLabel, inputContainer, menuButton, helpButton].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview($0)
        }

        inputBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor, constant: -10)
        inputBottomConstraint?.priority = .defaultHigh
        let inputSafeBottomConstraint = inputContainer.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10)
        inputSafeBottomConstraint.priority = .defaultLow
        wordmarkTopConstraint = wordmarkLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8)
        orbCenterYConstraint = orbView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor, constant: -54)
        orbWidthMultiplierConstraint = orbView.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.74)
        orbMaxWidthConstraint = orbView.widthAnchor.constraint(lessThanOrEqualToConstant: 320)

        NSLayoutConstraint.activate([
            wordmarkTopConstraint!,
            wordmarkLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            wordmarkLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            subtitleLabel.topAnchor.constraint(equalTo: wordmarkLabel.bottomAnchor, constant: 4),
            subtitleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            subtitleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            menuButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            menuButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 18),
            menuButton.widthAnchor.constraint(equalToConstant: JarvisDesignSystem.Size.meshWidth),
            menuButton.heightAnchor.constraint(equalToConstant: max(44, JarvisDesignSystem.Size.meshHeight)),

            helpButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 7),
            helpButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -18),
            helpButton.widthAnchor.constraint(equalToConstant: max(44, JarvisDesignSystem.Size.helpButton)),
            helpButton.heightAnchor.constraint(equalToConstant: max(44, JarvisDesignSystem.Size.helpButton)),

            orbView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            orbCenterYConstraint!,
            orbWidthMultiplierConstraint!,
            orbView.heightAnchor.constraint(equalTo: orbView.widthAnchor),
            orbMaxWidthConstraint!,

            stateLabel.topAnchor.constraint(equalTo: orbView.bottomAnchor, constant: 18),
            stateLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stateLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            hintLabel.topAnchor.constraint(equalTo: stateLabel.bottomAnchor, constant: 8),
            hintLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 30),
            hintLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -30),

            transientResponseLabel.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 18),
            transientResponseLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 32),
            transientResponseLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -32),

            inputContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            inputContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            inputContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: JarvisDesignSystem.Size.commandBarHeight),
            inputContainer.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            inputSafeBottomConstraint,
            inputBottomConstraint!,

            inputRow.leadingAnchor.constraint(equalTo: inputContainer.leadingAnchor, constant: 14),
            inputRow.trailingAnchor.constraint(equalTo: inputContainer.trailingAnchor, constant: -10),
            inputRow.topAnchor.constraint(equalTo: inputContainer.topAnchor, constant: 8),
            inputRow.bottomAnchor.constraint(equalTo: inputContainer.bottomAnchor, constant: -8),
            submitButton.widthAnchor.constraint(equalToConstant: JarvisDesignSystem.Size.sendWidth),
            submitButton.heightAnchor.constraint(greaterThanOrEqualToConstant: JarvisDesignSystem.Size.sendHeight)
        ])
    }

    private func utilityMenu() -> UIMenu {
        UIMenu(title: "Vision and systems", children: [
            UIAction(title: "Open Jarvis Vision") { [weak self] _ in self?.execute("open vision", source: "menu") },
            UIAction(title: "Describe") { [weak self] _ in self?.execute("describe this", source: "menu") },
            UIAction(title: "Live Guide") { [weak self] _ in self?.execute("start live guide", source: "menu") },
            UIAction(title: "Find") { [weak self] _ in
                self?.openVision(JarvisVisionLaunchRequest(mode: .find, command: .run, source: "menu"))
            },
            UIAction(title: "Read Text") { [weak self] _ in self?.execute("read this", source: "menu") },
            UIAction(title: "Scan Barcode") { [weak self] _ in self?.execute("scan barcode", source: "menu") },
            UIAction(title: "Control Mesh") { [weak self] _ in self?.controlMeshTapped() },
            UIAction(title: "Settings") { [weak self] _ in self?.settingsTapped() },
            UIAction(title: "Diagnostics") { [weak self] _ in self?.diagnosticsTapped() },
            UIAction(title: "Memory") { [weak self] _ in self?.execute("show notes", source: "menu") },
            UIAction(title: "Help") { [weak self] _ in self?.helpTapped() }
        ])
    }

    private func wireVoice() {
        speech.onSpeechStart = { [weak self] in
            self?.setInterfaceState(.speaking, hint: "Speaking.")
        }
        speech.onSpeechFinish = { [weak self] in
            guard let self else { return }
            if JarvisSpeechService.shared.isEnabled {
                self.setInterfaceState(.ready, hint: "Ready when you are.")
            } else {
                self.setInterfaceState(.quiet, hint: "Quiet mode.")
            }
        }
        voiceInput.onStateChange = { [weak self] state in
            switch state {
            case .standby:
                self?.setInterfaceState(.standby, hint: "Ready when you are.")
            case .listening:
                self?.speech.stop()
                self?.setInterfaceState(.listening, hint: "Listening.")
            case .heardYou(let transcript):
                self?.setInterfaceState(.heardYou, hint: transcript)
            case .processing:
                self?.setInterfaceState(.processing, hint: "Working.")
            case .noSpeech:
                self?.setInterfaceState(.ready, hint: "No speech heard.")
            case .unavailable(let message):
                self?.setInterfaceState(.attention, hint: message)
                self?.showTransient(message)
            }
        }
        voiceInput.onPartialTranscript = { [weak self] transcript in
            self?.hintLabel.text = transcript.isEmpty ? "Listening." : transcript
        }
        voiceInput.onFinalTranscript = { [weak self] transcript in
            self?.execute(transcript, source: "voice")
        }
    }

    private func execute(_ text: String, source: String = "typed") {
        let commandText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !commandText.isEmpty else {
            setInterfaceState(.ready, hint: "Ready when you are.")
            return
        }

        setInterfaceState(.processing, hint: "Working.")
        let command = JarvisCommand(commandText)
        let decision = assistant.decide(commandText)
        let response = decision.response
        if decision.plan?.shouldPersistGeneralHistory != false {
            let historyCommand = source == "typed" ? command.rawText : "\(source): \(command.rawText)"
            memory.appendHistory(command: historyCommand, response: response.displayResponse)
        }
        var visionRequest = decision.plan?.visionLaunchRequest
        visionRequest?.source = source
        render(response: response, visionRequest: visionRequest)
    }

    private func render(response: JarvisResponse, visionRequest: JarvisVisionLaunchRequest? = nil) {
        showTransient(response.displayResponse)
        if response.status == .refused || response.status == .unavailable || response.status == .error {
            setInterfaceState(.ready, hint: response.displayResponse)
        }

        if let visionRequest {
            setInterfaceState(.inspection, hint: "Opening \(visionRequest.mode.visionDisplayName).")
            openVision(visionRequest)
            return
        } else if response.data["action"] == "open_camera" || response.data["action"] == "inspect" {
            let hint = response.data["vision"] == "ocr" ? "Reading target." : response.data["vision"] == "visual_classification" ? "Opening visual scan." : "Opening inspection."
            setInterfaceState(.inspection, hint: hint)
            openCamera()
        } else if response.data["action"] == "diagnostics" {
            diagnosticsTapped()
        } else if response.data["action"] == "settings" {
            settingsTapped()
        } else if response.data["action"] == "control_mesh" {
            controlMeshTapped()
        } else if response.data["url_scheme"] != nil {
            openExternalRoute(response.data["url_scheme"])
        } else if response.data["mode"] == "standby" {
            setInterfaceState(.standby, hint: "JARVIS is standing by.")
        } else if response.data["mode"] == "ready" {
            setInterfaceState(.ready, hint: "JARVIS ready.")
        } else if response.data["mode"] == "quiet" {
            setInterfaceState(.quiet, hint: "Speech output is muted.")
        }

        if response.shouldSpeak && speech.isEnabled && (response.status == .ok || response.status == .confirmationRequired) {
            setInterfaceState(.speaking, hint: "Speaking.")
            speech.speak(response.spokenResponse)
        } else if response.status == .ok && response.data["action"] == nil {
            setInterfaceState(speech.isEnabled ? .done : .quiet, hint: response.spokenResponse)
        }
    }

    private func setInterfaceState(_ state: JarvisInteractionState, hint: String) {
        interfaceState = state
        stateLabel.text = state.rawValue
        stateLabel.accessibilityLabel = state.rawValue
        hintLabel.text = hint
        switch state {
        case .standby:
            stateLabel.textColor = JarvisTheme.accent
            orbView.setState(.standby)
        case .ready:
            stateLabel.textColor = JarvisTheme.accentHot
            orbView.setState(.idle)
        case .listening:
            stateLabel.textColor = JarvisTheme.accentHot
            orbView.setState(.listening)
        case .heardYou:
            stateLabel.textColor = JarvisTheme.success
            orbView.setState(.processing)
        case .processing:
            stateLabel.textColor = JarvisTheme.accentHot
            orbView.setState(.processing)
        case .speaking:
            stateLabel.textColor = JarvisTheme.success
            orbView.setState(.speaking)
        case .inspection:
            stateLabel.textColor = JarvisTheme.accentHot
            orbView.setState(.inspection)
        case .done:
            stateLabel.textColor = JarvisTheme.accent
            orbView.setState(.idle)
        case .quiet:
            stateLabel.textColor = JarvisTheme.warning
            orbView.setState(.quiet)
        case .attention:
            stateLabel.textColor = JarvisTheme.warning
            orbView.setState(.error)
        }
    }

    private func showTransient(_ text: String) {
        responseHideWorkItem?.cancel()
        transientResponseLabel.text = compactDisplay(text)
        UIView.animate(withDuration: 0.18) {
            self.transientResponseLabel.alpha = 1
        }
        let work = DispatchWorkItem { [weak self] in
            UIView.animate(withDuration: 0.35) {
                self?.transientResponseLabel.alpha = 0.18
            }
        }
        responseHideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.0, execute: work)
    }

    private func compactDisplay(_ text: String) -> String {
        let lines = text
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let joined = lines.prefix(2).joined(separator: " ")
        return joined.count > 150 ? String(joined.prefix(147)) + "..." : joined
    }

    private func openExternalRoute(_ route: String?) {
        guard let route, let url = URL(string: route) else { return }
        UIApplication.shared.open(url) { [weak self] success in
            guard !success else { return }
            self?.showTransient("Use Control Mesh: say Open \(url.host ?? "the app") or open it from Home.")
        }
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        submitCurrentCommand()
        return true
    }

    @objc private func submitTapped() {
        submitCurrentCommand()
    }

    @objc private func orbTapped() {
        if longPressSuppressesNextTap {
            longPressSuppressesNextTap = false
            return
        }
        if isUITestMode {
            handleUITestOrbTap()
            return
        }
        switch interfaceState {
        case .standby:
            speech.isEnabled = true
            setInterfaceState(.ready, hint: "JARVIS ready.")
            speech.speak("JARVIS ready.", notifyState: false)
        case .ready, .done, .attention, .quiet:
            voiceInput.startListening()
        case .listening, .heardYou:
            voiceInput.stopListening(process: true)
        case .processing:
            showTransient("Processing.")
        case .speaking:
            speech.stop()
            setInterfaceState(.ready, hint: "Speech stopped.")
        case .inspection:
            voiceInput.startListening()
        }
    }

    @objc private func helpTapped() {
        let controller = JarvisHelpViewController()
        controller.modalPresentationStyle = .pageSheet
        if let sheet = controller.sheetPresentationController {
            sheet.detents = [.medium(), .large()]
            sheet.prefersGrabberVisible = true
        }
        present(controller, animated: true)
    }

    @objc private func orbLongPressed(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            longPressSuppressesNextTap = true
            enterStandbyFromLongPress()
        } else if gesture.state == .ended || gesture.state == .cancelled || gesture.state == .failed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.longPressSuppressesNextTap = false
            }
        }
    }

    private func enterStandbyFromLongPress() {
        responseHideWorkItem?.cancel()
        transientResponseLabel.alpha = 0
        if voiceInput.isListening {
            voiceInput.stopListening(process: false)
        } else {
            voiceInput.cancel()
        }
        speech.stop()
        commandField.resignFirstResponder()
        setInterfaceState(.standby, hint: "Standby.")
    }

    private func handleUITestOrbTap() {
        switch interfaceState {
        case .standby:
            speech.isEnabled = true
            setInterfaceState(.ready, hint: "JARVIS ready.")
        case .ready, .done, .attention, .quiet, .inspection:
            speech.stop()
            setInterfaceState(.listening, hint: "Listening.")
        case .listening, .heardYou:
            let transcript = (commandField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if transcript.isEmpty {
                setInterfaceState(.ready, hint: "No speech heard.")
                showTransient("No speech heard.")
            } else {
                execute(transcript, source: "voice")
            }
        case .processing:
            showTransient("Processing.")
        case .speaking:
            speech.stop()
            setInterfaceState(.ready, hint: "Speech stopped.")
        }
    }

    private func submitCurrentCommand() {
        let text = commandField.text ?? ""
        execute(text)
        commandField.text = ""
        commandField.resignFirstResponder()
    }

    private func controlMeshTapped() {
        setInterfaceState(.processing, hint: "Opening Control Mesh.")
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(JarvisControlMeshViewController(), animated: true)
    }

    private func diagnosticsTapped() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(JarvisDiagnosticsViewController(), animated: true)
    }

    private func settingsTapped() {
        navigationController?.setNavigationBarHidden(false, animated: true)
        navigationController?.pushViewController(JarvisSettingsViewController(), animated: true)
    }

    private func openCamera() {
        let preferred = VisionPreferencesStore.shared.value.defaultMode
        let mode = preferred == .inactive || preferred == .identifyColor ? VisionMode.describe : preferred
        openVision(JarvisVisionLaunchRequest(mode: mode, command: .run, source: "legacy"))
    }

    private func openVision(_ request: JarvisVisionLaunchRequest) {
        if !isUITestMode, JarvisVisionFirstRunStore.shared.shouldPresent {
            pendingVisionRequestAfterOnboarding = request
            showFirstLaunchIfNeeded()
            return
        }
        navigationController?.setNavigationBarHidden(false, animated: true)
        if let controller = navigationController?.topViewController as? JarvisCameraViewController {
            controller.apply(request)
            return
        }
        navigationController?.pushViewController(
            JarvisCameraViewController(launchRequest: request),
            animated: !UIAccessibility.isReduceMotionEnabled
        )
    }

    @objc private func deepLinkReceived(_ notification: Notification) {
        guard let action = notification.object as? JarvisDeepLinkAction else { return }
        handle(action: action)
    }

    private func handle(action: JarvisDeepLinkAction) {
        switch action {
        case .command(let text):
            execute(text, source: "deep link")
        case .vision(var request):
            request.source = "deep_link"
            openVision(request)
        case .inspect:
            openVision(JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "deep_link"))
        case .diagnostics:
            diagnosticsTapped()
        case .settings:
            settingsTapped()
        case .standby:
            execute("standby", source: "deep link")
        case .online:
            execute("status", source: "deep link")
        case .controlMesh:
            controlMeshTapped()
        case .unknown(let raw):
            render(response: JarvisResponse(status: .refused, spokenResponse: "Deep link not recognized.", displayResponse: "Unknown JARVIS deep link: \(raw)", shouldSpeak: false))
        }
    }

    private func showFirstLaunchIfNeeded() {
        guard !isUITestMode else { return }
        guard JarvisVisionFirstRunStore.shared.shouldPresent else { return }
        if let existing = (presentedViewController as? UINavigationController)?.viewControllers.first as? JarvisVisionOnboardingViewController {
            configureOnboarding(existing)
            return
        }
        let controller = JarvisVisionOnboardingViewController()
        configureOnboarding(controller)
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .pageSheet
        if let sheet = navigation.sheetPresentationController {
            sheet.detents = [.large()]
            sheet.prefersGrabberVisible = true
        }
        present(navigation, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    private func configureOnboarding(_ controller: JarvisVisionOnboardingViewController) {
        controller.onOpenVision = { [weak self] in
            guard let self else { return }
            let request = self.pendingVisionRequestAfterOnboarding
                ?? JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "onboarding")
            self.pendingVisionRequestAfterOnboarding = nil
            self.openVision(request)
        }
        controller.onContinue = { [weak self] in
            guard let self, let request = self.pendingVisionRequestAfterOnboarding else { return }
            self.pendingVisionRequestAfterOnboarding = nil
            self.openVision(request)
        }
    }

    private func applyVisualProofStateIfNeeded() {
        guard isUITestMode, !didApplyVisualProofState else { return }
        didApplyVisualProofState = true
        let arguments = ProcessInfo.processInfo.arguments
        let stateKey = arguments.firstIndex(of: "--jarvis-state") ?? arguments.firstIndex(of: "-JARVIS_VISUAL_STATE")
        guard let index = stateKey,
              arguments.indices.contains(index + 1) else { return }
        switch arguments[index + 1] {
        case "ready":
            setInterfaceState(.ready, hint: "JARVIS ready.")
        case "listening":
            setInterfaceState(.listening, hint: "Listening.")
        case "no_speech":
            setInterfaceState(.ready, hint: "No speech heard.")
            showTransient("No speech heard.")
        case "long_hold_standby":
            setInterfaceState(.standby, hint: "Standby.")
        case "processing":
            execute("status", source: "visual proof")
        case "speaking":
            setInterfaceState(.speaking, hint: "Speaking.")
            showTransient("JARVIS is speaking.")
        case "keyboard":
            setInterfaceState(.ready, hint: "JARVIS ready.")
            commandField.becomeFirstResponder()
        case "help":
            helpTapped()
        case "inspection":
            openCamera()
        case "object_model_missing":
            openCamera()
        case "vision_idle", "vision_describe_listening", "vision_describe_analyzing", "vision_describe_result",
             "vision_live_active", "vision_find_searching", "vision_find_centered", "vision_reading",
             "vision_scan_result", "vision_permission_denied", "vision_model_unavailable":
            openVision(JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "ui_fixture"))
        case "vision_settings":
            navigationController?.setNavigationBarHidden(false, animated: false)
            navigationController?.pushViewController(JarvisSettingsViewController(initialSection: .vision), animated: false)
        case "vision_help":
            navigationController?.setNavigationBarHidden(false, animated: false)
            navigationController?.pushViewController(JarvisHelpViewController(initialSection: .vision), animated: false)
        case "vision_self_test":
            navigationController?.setNavigationBarHidden(false, animated: false)
            navigationController?.pushViewController(JarvisVisionSelfTestViewController(), animated: false)
        case "vision_onboarding":
            let controller = JarvisVisionOnboardingViewController()
            present(UINavigationController(rootViewController: controller), animated: false)
        case "settings":
            settingsTapped()
        case "diagnostics":
            diagnosticsTapped()
        case "mesh":
            controlMeshTapped()
        default:
            break
        }
    }
}

private extension UITextField {
    func setLeftPadding(_ amount: CGFloat) {
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))
        leftView = padding
        leftViewMode = .always
    }
}

private extension UILabel {
    func letterSpacing(_ value: CGFloat) {
        guard let text = text else { return }
        attributedText = NSAttributedString(
            string: text,
            attributes: [.kern: value, .foregroundColor: textColor as Any, .font: font as Any]
        )
    }
}
