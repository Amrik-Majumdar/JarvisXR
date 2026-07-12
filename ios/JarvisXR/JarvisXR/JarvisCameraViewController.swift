import AVFoundation
import UIKit

/// The accessible Jarvis Vision product surface. Camera ownership, analysis,
/// tracking, safety policy, and narration remain in their dedicated services.
final class JarvisCameraViewController: UIViewController {
    private let camera = CameraSessionService()
    private let pipeline = VisionPipelineCoordinator()
    private let speech = JarvisSpeechService.shared
    private let voiceInput = JarvisVoiceInputService.shared
    private let haptics = VisionHapticsService.shared
    private let preferencesStore = VisionPreferencesStore.shared

    private var launchRequest: JarvisVisionLaunchRequest
    private var currentMode: VisionMode
    private var currentState: VisionSessionState = .idle
    private var currentTarget: String?
    private var requestedRegion: SpatialRegion?
    private var speechSessionID: UUID?
    private var hapticSessionID: UUID?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasAppliedInitialRequest = false
    private var isFixtureDriven = false
    private var ignoredAutomaticNarrationSnapshotID: UUID?
    private var latestSnapshot: SceneSnapshot?
    private var lastPresentedNarration: SceneNarration?
    private var lastAnnouncement: (text: String, date: Date)?
    private var lastTargetCentered = false

    private let scrollView = UIScrollView()
    private let contentStack = UIStackView()
    private let fixtureBanner = UILabel()
    private let modeScrollView = UIScrollView()
    private let modeStack = UIStackView()
    private var modeButtons: [VisionMode: UIButton] = [:]
    private let modeLabel = UILabel()
    private let stateLabel = UILabel()
    private let guidanceLabel = UILabel()
    private let previewView = UIView()
    private let resultPanel = JarvisPanelView()
    private let resultLabel = UILabel()
    private let failurePanel = JarvisPanelView()
    private let failureLabel = UILabel()
    private let openSystemSettingsButton = JarvisTheme.button(title: "Open iOS Settings")
    private let retryButton = JarvisTheme.button(title: "Try Again")
    private let primaryButton = UIButton(type: .system)
    private let repeatButton = JarvisTheme.button(title: "Repeat")
    private let lightButton = JarvisTheme.button(title: "Flashlight Off")
    private let moreDetailButton = JarvisTheme.button(title: "More Detail")
    private let readingControls = UIStackView()
    private let previousLineButton = JarvisTheme.button(title: "Previous Line")
    private let pauseReadingButton = JarvisTheme.button(title: "Pause Reading")
    private let nextLineButton = JarvisTheme.button(title: "Next Line")
    private let bottomBar = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
    private let voiceButton = UIButton(type: .system)
    private let stopButton = UIButton(type: .system)

    private var preferences: VisionPreferences { preferencesStore.value }

    init(launchRequest: JarvisVisionLaunchRequest = JarvisVisionLaunchRequest()) {
        self.launchRequest = launchRequest
        self.currentMode = launchRequest.mode == .inactive ? .describe : launchRequest.mode
        self.currentTarget = launchRequest.target
        self.requestedRegion = launchRequest.region
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        launchRequest = JarvisVisionLaunchRequest()
        currentMode = .describe
        super.init(coder: coder)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Jarvis Vision"
        view.backgroundColor = JarvisTheme.background
        navigationItem.largeTitleDisplayMode = .never
        buildInterface()
        wireServices()
        setMode(currentMode, announce: false)
        renderState(.idle, guidance: currentMode.visionReadyGuidance, announce: false)
        applyFixtureStateIfNeeded()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !hasAppliedInitialRequest else { return }
        hasAppliedInitialRequest = true
        guard !isFixtureDriven else { return }
        apply(launchRequest)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        guard isMovingFromParent || navigationController?.topViewController !== self else { return }
        stopVision(announce: false, message: "Vision stopped.")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = previewView.bounds
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        pipeline.stop()
        pipeline.unbindCamera()
        camera.stop()
        voiceInput.cancel()
    }

    func apply(_ request: JarvisVisionLaunchRequest) {
        launchRequest = request
        if request.command == .run || request.command == .checkQuality {
            currentTarget = request.mode == .find ? request.target : nil
            requestedRegion = request.region
        } else if let target = request.target {
            currentTarget = target
        }

        let selectsMode: Bool
        switch request.command {
        case .run, .checkQuality:
            selectsMode = true
        case .pause, .resume, .nextReadingLine, .previousReadingLine:
            selectsMode = currentState != .active && currentState != .paused
        default:
            selectsMode = false
        }
        if selectsMode, request.mode != .inactive {
            if request.mode != currentMode,
               currentState == .active || currentState == .paused || currentState == .preparing {
                stopVision(announce: false, message: "Previous Vision mode stopped.")
            }
            setMode(request.mode, announce: true)
        }

        switch request.command {
        case .run:
            if request.startsImmediately {
                beginCurrentMode()
            }
        case .stop:
            stopVision(announce: true, message: "Vision and speech stopped.")
        case .pause:
            pauseVision()
        case .resume:
            resumeVision()
        case .repeatLast:
            repeatLastResult()
        case .moreDetail:
            presentMoreDetail()
        case .lessDetail:
            preferencesStore.update {
                $0.narrationVerbosity = .concise
                if request.mode == .liveGuide { $0.importantChangesOnly = true }
            }
            showResult(
                request.mode == .liveGuide ? "Live Guide will speak only important changes." : "Descriptions are now concise.",
                announce: true
            )
        case .whatChanged:
            repeatLastResult(prefix: "Latest confirmed change. ")
        case .nextReadingLine:
            pipeline.advanceReadingLine(by: 1)
            speakCurrentReadingLine()
        case .previousReadingLine:
            pipeline.advanceReadingLine(by: -1)
            speakCurrentReadingLine()
        case .flashlightOn:
            setFlashlight(true)
        case .flashlightOff:
            setFlashlight(false)
        case .checkQuality:
            setMode(.describe, announce: true)
            beginCurrentMode()
        }
    }

    private func buildInterface() {
        configureNavigation()
        configureFixtureBanner()
        configureModePicker()
        configureStatus()
        configurePreview()
        configureResultPanel()
        configureFailurePanel()
        configureActions()
        configureBottomBar()

        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.alwaysBounceVertical = true
        scrollView.keyboardDismissMode = .interactive
        scrollView.accessibilityIdentifier = "jarvis.vision.scroll"

        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.axis = .vertical
        contentStack.spacing = 14

        [
            fixtureBanner,
            makeSectionLabel("Mode"),
            modeScrollView,
            makeStatusPanel(),
            guidanceLabel,
            previewView,
            failurePanel,
            resultPanel,
            primaryButton,
            makeSecondaryActionRow(),
            readingControls,
        ].forEach(contentStack.addArrangedSubview)

        view.addSubview(scrollView)
        scrollView.addSubview(contentStack)
        view.addSubview(bottomBar)

        NSLayoutConstraint.activate([
            bottomBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBar.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomBar.topAnchor),

            contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 14),
            contentStack.leadingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.leadingAnchor, constant: 16),
            contentStack.trailingAnchor.constraint(equalTo: scrollView.frameLayoutGuide.trailingAnchor, constant: -16),
            contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -20),
        ])

        view.accessibilityElements = [scrollView, bottomBar]
    }

    private func configureNavigation() {
        let help = UIBarButtonItem(
            title: "Help",
            style: .plain,
            target: self,
            action: #selector(helpTapped)
        )
        help.accessibilityLabel = "Vision Help"
        help.accessibilityHint = "Opens task-based help and safety limits."
        help.accessibilityIdentifier = "jarvis.vision.help"

        let settings = UIBarButtonItem(
            title: "Settings",
            style: .plain,
            target: self,
            action: #selector(settingsTapped)
        )
        settings.accessibilityLabel = "Vision Settings"
        settings.accessibilityHint = "Opens speech, haptic, camera, and privacy settings."
        settings.accessibilityIdentifier = "jarvis.vision.settings"
        navigationItem.rightBarButtonItems = [settings, help]
    }

    private func configureFixtureBanner() {
        fixtureBanner.text = "DEMO FIXTURE • Camera is not active"
        fixtureBanner.textColor = JarvisTheme.background
        fixtureBanner.backgroundColor = JarvisTheme.warning
        fixtureBanner.font = UIFont.preferredFont(forTextStyle: .caption1)
        fixtureBanner.adjustsFontForContentSizeCategory = true
        fixtureBanner.textAlignment = .center
        fixtureBanner.numberOfLines = 0
        fixtureBanner.layer.cornerRadius = 8
        fixtureBanner.clipsToBounds = true
        fixtureBanner.isHidden = true
        fixtureBanner.accessibilityIdentifier = "jarvis.vision.fixtureBanner"
        fixtureBanner.accessibilityLabel = "Demonstration fixture. Camera is not active."
        fixtureBanner.heightAnchor.constraint(greaterThanOrEqualToConstant: 34).isActive = true
    }

    private func configureModePicker() {
        modeScrollView.translatesAutoresizingMaskIntoConstraints = false
        modeScrollView.showsHorizontalScrollIndicator = false
        modeScrollView.accessibilityIdentifier = "jarvis.vision.modePicker"
        modeScrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 52).isActive = true

        modeStack.translatesAutoresizingMaskIntoConstraints = false
        modeStack.axis = .horizontal
        modeStack.spacing = 8
        modeScrollView.addSubview(modeStack)
        NSLayoutConstraint.activate([
            modeStack.topAnchor.constraint(equalTo: modeScrollView.contentLayoutGuide.topAnchor),
            modeStack.bottomAnchor.constraint(equalTo: modeScrollView.contentLayoutGuide.bottomAnchor),
            modeStack.leadingAnchor.constraint(equalTo: modeScrollView.contentLayoutGuide.leadingAnchor),
            modeStack.trailingAnchor.constraint(equalTo: modeScrollView.contentLayoutGuide.trailingAnchor),
            modeStack.heightAnchor.constraint(equalTo: modeScrollView.frameLayoutGuide.heightAnchor),
        ])

        let visibleModes: [VisionMode] = [.describe, .liveGuide, .find, .readText, .scanBarcode]
        for mode in visibleModes {
            let button = UIButton(type: .system)
            button.setTitle(mode.visionDisplayName, for: .normal)
            button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
            button.titleLabel?.adjustsFontForContentSizeCategory = true
            button.setTitleColor(JarvisTheme.text, for: .normal)
            button.backgroundColor = JarvisTheme.panelRaised
            button.layer.borderColor = JarvisTheme.panelBorder.cgColor
            button.layer.borderWidth = 1
            button.layer.cornerRadius = 12
            button.contentEdgeInsets = UIEdgeInsets(top: 11, left: 15, bottom: 11, right: 15)
            button.heightAnchor.constraint(greaterThanOrEqualToConstant: 48).isActive = true
            button.accessibilityLabel = "(mode.visionDisplayName) mode"
            button.accessibilityHint = mode.visionReadyGuidance
            button.accessibilityIdentifier = "jarvis.vision.mode.\(mode.rawValue)"
            button.addAction(UIAction { [weak self] _ in self?.modeSelected(mode) }, for: .touchUpInside)
            modeStack.addArrangedSubview(button)
            modeButtons[mode] = button
        }
    }

    private func configureStatus() {
        modeLabel.textColor = JarvisTheme.accentHot
        modeLabel.font = UIFont.preferredFont(forTextStyle: .title2)
        modeLabel.adjustsFontForContentSizeCategory = true
        modeLabel.numberOfLines = 0
        modeLabel.accessibilityIdentifier = "jarvis.vision.currentMode"

        stateLabel.textColor = JarvisTheme.text
        stateLabel.font = UIFont.preferredFont(forTextStyle: .headline)
        stateLabel.adjustsFontForContentSizeCategory = true
        stateLabel.numberOfLines = 0
        stateLabel.accessibilityIdentifier = "jarvis.vision.state"

        guidanceLabel.textColor = JarvisTheme.mutedText
        guidanceLabel.font = UIFont.preferredFont(forTextStyle: .body)
        guidanceLabel.adjustsFontForContentSizeCategory = true
        guidanceLabel.numberOfLines = 0
        guidanceLabel.accessibilityIdentifier = "jarvis.inspection.status"
    }

    private func makeStatusPanel() -> UIView {
        let panel = JarvisPanelView()
        let stack = UIStackView(arrangedSubviews: [modeLabel, stateLabel])
        stack.axis = .vertical
        stack.spacing = 4
        stack.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: panel.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -14),
        ])
        panel.accessibilityElements = [modeLabel, stateLabel]
        return panel
    }

    private func configurePreview() {
        previewView.translatesAutoresizingMaskIntoConstraints = false
        previewView.backgroundColor = UIColor(white: 0.04, alpha: 1)
        previewView.layer.borderColor = JarvisTheme.panelBorder.cgColor
        previewView.layer.borderWidth = 1
        previewView.layer.cornerRadius = 14
        previewView.clipsToBounds = true
        previewView.heightAnchor.constraint(equalToConstant: 164).isActive = true
        previewView.isAccessibilityElement = true
        previewView.accessibilityLabel = "Camera preview"
        previewView.accessibilityHint = "The spoken result contains the useful camera information."
        previewView.accessibilityIdentifier = "jarvis.vision.preview"

        let previewMessage = UILabel()
        previewMessage.text = "Camera starts only when you choose an action."
        previewMessage.textColor = JarvisTheme.mutedText
        previewMessage.font = UIFont.preferredFont(forTextStyle: .footnote)
        previewMessage.adjustsFontForContentSizeCategory = true
        previewMessage.numberOfLines = 0
        previewMessage.textAlignment = .center
        previewMessage.translatesAutoresizingMaskIntoConstraints = false
        previewView.addSubview(previewMessage)
        NSLayoutConstraint.activate([
            previewMessage.centerYAnchor.constraint(equalTo: previewView.centerYAnchor),
            previewMessage.leadingAnchor.constraint(equalTo: previewView.leadingAnchor, constant: 24),
            previewMessage.trailingAnchor.constraint(equalTo: previewView.trailingAnchor, constant: -24),
        ])
    }

    private func configureResultPanel() {
        let title = makeSectionLabel("Result")
        title.accessibilityIdentifier = "jarvis.vision.resultHeading"
        resultLabel.text = "No result yet."
        resultLabel.textColor = JarvisTheme.text
        resultLabel.font = UIFont.preferredFont(forTextStyle: .body)
        resultLabel.adjustsFontForContentSizeCategory = true
        resultLabel.numberOfLines = 0
        resultLabel.accessibilityIdentifier = "jarvis.vision.result"

        let stack = UIStackView(arrangedSubviews: [title, resultLabel])
        stack.axis = .vertical
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        resultPanel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: resultPanel.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: resultPanel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: resultPanel.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: resultPanel.bottomAnchor, constant: -14),
        ])
        resultPanel.accessibilityElements = [title, resultLabel]
    }

    private func configureFailurePanel() {
        failureLabel.textColor = JarvisTheme.text
        failureLabel.font = UIFont.preferredFont(forTextStyle: .body)
        failureLabel.adjustsFontForContentSizeCategory = true
        failureLabel.numberOfLines = 0
        failureLabel.accessibilityIdentifier = "jarvis.vision.failure"

        openSystemSettingsButton.addTarget(self, action: #selector(openSystemSettingsTapped), for: .touchUpInside)
        openSystemSettingsButton.accessibilityHint = "Opens the Jarvis page in iOS Settings so camera access can be changed."
        openSystemSettingsButton.accessibilityIdentifier = "jarvis.vision.openSystemSettings"
        retryButton.addTarget(self, action: #selector(retryTapped), for: .touchUpInside)
        retryButton.accessibilityIdentifier = "jarvis.vision.retry"
        [openSystemSettingsButton, retryButton].forEach(configureDynamicButton)

        let buttons = UIStackView(arrangedSubviews: [openSystemSettingsButton, retryButton])
        buttons.axis = .horizontal
        buttons.spacing = 8
        buttons.distribution = .fillEqually
        let stack = UIStackView(arrangedSubviews: [makeSectionLabel("Needs Attention"), failureLabel, buttons])
        stack.axis = .vertical
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        failurePanel.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: failurePanel.topAnchor, constant: 14),
            stack.leadingAnchor.constraint(equalTo: failurePanel.leadingAnchor, constant: 14),
            stack.trailingAnchor.constraint(equalTo: failurePanel.trailingAnchor, constant: -14),
            stack.bottomAnchor.constraint(equalTo: failurePanel.bottomAnchor, constant: -14),
        ])
        failurePanel.layer.borderColor = JarvisTheme.warning.cgColor
        failurePanel.isHidden = true
        failurePanel.accessibilityIdentifier = "jarvis.vision.failurePanel"
    }

    private func configureActions() {
        primaryButton.setTitleColor(JarvisTheme.background, for: .normal)
        primaryButton.backgroundColor = JarvisTheme.accentHot
        primaryButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .title3)
        primaryButton.titleLabel?.adjustsFontForContentSizeCategory = true
        primaryButton.titleLabel?.numberOfLines = 0
        primaryButton.titleLabel?.textAlignment = .center
        primaryButton.layer.cornerRadius = 16
        primaryButton.contentEdgeInsets = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        primaryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 58).isActive = true
        primaryButton.addTarget(self, action: #selector(primaryTapped), for: .touchUpInside)
        primaryButton.accessibilityIdentifier = "jarvis.vision.primaryAction"

        repeatButton.addTarget(self, action: #selector(repeatTapped), for: .touchUpInside)
        repeatButton.accessibilityLabel = "Repeat last Vision result"
        repeatButton.accessibilityHint = "Speaks the latest result again without taking another photo."
        repeatButton.accessibilityIdentifier = "jarvis.vision.repeat"
        lightButton.addTarget(self, action: #selector(lightTapped), for: .touchUpInside)
        lightButton.accessibilityLabel = "Flashlight"
        lightButton.accessibilityIdentifier = "jarvis.vision.flashlight"
        moreDetailButton.addTarget(self, action: #selector(moreDetailTapped), for: .touchUpInside)
        moreDetailButton.accessibilityLabel = "More detail"
        moreDetailButton.accessibilityHint = "Describes the latest scene in more detail without taking another photo."
        moreDetailButton.accessibilityIdentifier = "jarvis.vision.moreDetail"
        [repeatButton, lightButton, moreDetailButton, previousLineButton, pauseReadingButton, nextLineButton]
            .forEach(configureDynamicButton)

        readingControls.axis = .horizontal
        readingControls.spacing = 8
        readingControls.distribution = .fillEqually
        readingControls.addArrangedSubview(previousLineButton)
        readingControls.addArrangedSubview(pauseReadingButton)
        readingControls.addArrangedSubview(nextLineButton)
        readingControls.isHidden = true
        previousLineButton.addTarget(self, action: #selector(previousLineTapped), for: .touchUpInside)
        pauseReadingButton.addTarget(self, action: #selector(pauseReadingTapped), for: .touchUpInside)
        nextLineButton.addTarget(self, action: #selector(nextLineTapped), for: .touchUpInside)
        previousLineButton.accessibilityIdentifier = "jarvis.vision.read.previous"
        pauseReadingButton.accessibilityIdentifier = "jarvis.vision.read.pause"
        nextLineButton.accessibilityIdentifier = "jarvis.vision.read.next"
    }

    private func makeSecondaryActionRow() -> UIView {
        let stack = UIStackView(arrangedSubviews: [repeatButton, moreDetailButton, lightButton])
        stack.axis = .horizontal
        stack.spacing = 8
        stack.distribution = .fillEqually
        return stack
    }

    private func configureBottomBar() {
        bottomBar.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.accessibilityIdentifier = "jarvis.vision.persistentActions"

        voiceButton.setTitle("Voice", for: .normal)
        voiceButton.setTitleColor(JarvisTheme.text, for: .normal)
        voiceButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        voiceButton.titleLabel?.adjustsFontForContentSizeCategory = true
        voiceButton.backgroundColor = JarvisTheme.panelRaised
        voiceButton.layer.cornerRadius = 14
        voiceButton.layer.borderColor = JarvisTheme.panelBorder.cgColor
        voiceButton.layer.borderWidth = 1
        voiceButton.addTarget(self, action: #selector(voiceTapped), for: .touchUpInside)
        voiceButton.accessibilityLabel = "Voice command inside Vision"
        voiceButton.accessibilityHint = "Starts or stops listening for a Vision command."
        voiceButton.accessibilityIdentifier = "jarvis.vision.voice"

        stopButton.setTitle("Stop", for: .normal)
        stopButton.setTitleColor(.white, for: .normal)
        stopButton.titleLabel?.font = UIFont.preferredFont(forTextStyle: .headline)
        stopButton.titleLabel?.adjustsFontForContentSizeCategory = true
        stopButton.backgroundColor = JarvisTheme.error
        stopButton.layer.cornerRadius = 14
        stopButton.addTarget(self, action: #selector(stopTapped), for: .touchUpInside)
        stopButton.accessibilityLabel = "Stop Vision and speech"
        stopButton.accessibilityHint = "Immediately stops camera analysis, narration, haptics, and voice input."
        stopButton.accessibilityIdentifier = "jarvis.vision.stop"

        let row = UIStackView(arrangedSubviews: [voiceButton, stopButton])
        row.axis = .horizontal
        row.spacing = 12
        row.distribution = .fillEqually
        row.translatesAutoresizingMaskIntoConstraints = false
        bottomBar.contentView.addSubview(row)
        NSLayoutConstraint.activate([
            row.topAnchor.constraint(equalTo: bottomBar.contentView.topAnchor, constant: 10),
            row.leadingAnchor.constraint(equalTo: bottomBar.contentView.leadingAnchor, constant: 16),
            row.trailingAnchor.constraint(equalTo: bottomBar.contentView.trailingAnchor, constant: -16),
            row.bottomAnchor.constraint(equalTo: bottomBar.safeAreaLayoutGuide.bottomAnchor, constant: -10),
            voiceButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
            stopButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 54),
        ])
        bottomBar.accessibilityElements = [voiceButton, stopButton]
    }

    private func makeSectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.textColor = JarvisTheme.mutedText
        label.font = UIFont.preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.numberOfLines = 0
        label.accessibilityTraits.insert(.header)
        return label
    }

    private func configureDynamicButton(_ button: UIButton) {
        button.titleLabel?.font = UIFont.preferredFont(forTextStyle: .body)
        button.titleLabel?.adjustsFontForContentSizeCategory = true
        button.titleLabel?.numberOfLines = 0
        button.titleLabel?.textAlignment = .center
    }

    private func wireServices() {
        pipeline.bind(to: camera)
        pipeline.apply(preferences: preferences)

        pipeline.onStateChange = { [weak self] mode, state in
            DispatchQueue.main.async { self?.pipelineStateChanged(mode: mode, state: state) }
        }
        pipeline.onSnapshot = { [weak self] snapshot in
            DispatchQueue.main.async { self?.received(snapshot: snapshot) }
        }
        pipeline.onNarration = { [weak self] narration in
            DispatchQueue.main.async { self?.received(narration: narration) }
        }
        pipeline.onError = { [weak self] error in
            DispatchQueue.main.async { self?.handle(error: error) }
        }
        pipeline.onReadingStateChange = { [weak self] readingState in
            DispatchQueue.main.async { self?.readingStateChanged(readingState) }
        }
        pipeline.onColorResult = { [weak self] result in
            DispatchQueue.main.async {
                self?.guidanceLabel.text = result.isUncertain
                    ? "The center color varies across the sampled area."
                    : "Center color identified from the current image."
            }
        }

        voiceInput.onStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .idle:
                self.voiceButton.setTitle("Voice", for: .normal)
            case .requestingPermission:
                self.renderState(self.currentState, guidance: "Requesting microphone and Speech access.", announce: false)
            case .listening:
                self.voiceButton.setTitle("Finish", for: .normal)
                self.renderState(self.currentState, guidance: "Listening for a Vision command.", announce: true)
            case .heardYou(let transcript):
                self.guidanceLabel.text = "Heard: \(transcript)"
            case .processing:
                self.guidanceLabel.text = "Processing voice command."
            case .noSpeech:
                self.renderState(self.currentState, guidance: "No speech heard. Try again or use a button.", announce: true)
            case .unavailable(let message):
                self.showFailure(message, offersSettings: true)
            }
        }
        voiceInput.onPartialTranscript = { [weak self] text in
            guard !text.isEmpty else { return }
            self?.guidanceLabel.text = "Listening: \(text)"
        }
        voiceInput.onFinalTranscript = { [weak self] text in
            self?.handleVisionVoiceCommand(text)
        }

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationEnteredBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(preferencesChanged),
            name: .jarvisVisionPreferencesDidChange,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(runtimeConditionsChanged),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(runtimeConditionsChanged),
            name: .NSProcessInfoPowerStateDidChange,
            object: nil
        )
    }

    private func modeSelected(_ mode: VisionMode) {
        if currentState == .active || currentState == .paused || currentState == .preparing {
            stopVision(announce: false, message: "Previous Vision mode stopped.")
        }
        currentTarget = mode == .find ? currentTarget : nil
        requestedRegion = nil
        latestSnapshot = nil
        lastPresentedNarration = nil
        resultLabel.text = "No result yet."
        setMode(mode, announce: true)
        if mode == .find {
            promptForFindTarget()
        }
    }

    private func setMode(_ mode: VisionMode, announce: Bool) {
        currentMode = mode == .inactive ? .describe : mode
        modeLabel.text = "\(currentMode.visionDisplayName) mode"
        for (buttonMode, button) in modeButtons {
            let selected = buttonMode == currentMode
            button.backgroundColor = selected ? JarvisTheme.accentDim : JarvisTheme.panelRaised
            button.layer.borderColor = (selected ? JarvisTheme.accentHot : JarvisTheme.panelBorder).cgColor
            if selected {
                button.accessibilityTraits.insert(.selected)
            } else {
                button.accessibilityTraits.remove(.selected)
            }
        }
        readingControls.isHidden = currentMode != .readText
        moreDetailButton.isHidden = currentMode == .readText || currentMode == .scanBarcode
        primaryButton.setTitle(primaryTitle(), for: .normal)
        renderState(.idle, guidance: currentMode.visionReadyGuidance, announce: false)
        if announce {
            postAnnouncement("\(currentMode.visionDisplayName) mode. \(currentMode.visionReadyGuidance)", force: true)
            playHaptic(.success)
        }
    }

    private func beginCurrentMode() {
        guard !isFixtureDriven else { return }
        if currentMode == .find, currentTarget?.isEmpty != false {
            promptForFindTarget()
            return
        }
        latestSnapshot = nil
        lastPresentedNarration = nil
        resultLabel.text = "Waiting for a confirmed result."
        failurePanel.isHidden = true
        resetFeedbackSessions()
        renderState(.preparing, guidance: "Preparing the camera.", announce: true)
        ensureFeedbackSessions()
        let position: CameraSessionService.CameraPosition = preferences.cameraChoice == .front ? .front : .rear
        camera.requestAccessAndStart(position: position) { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.handleCameraStartFailure(error)
            case .success:
                self.attachPreviewIfNeeded()
                VisionDiagnosticsStore.shared.setPermissions(camera: .authorized)
                VisionDiagnosticsStore.shared.setActiveCamera(
                    self.preferences.cameraChoice == .front ? .front : .rear
                )
                self.pipeline.updateRuntimeConditions(
                    thermalState: ProcessInfo.processInfo.thermalState,
                    lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
                )
                self.pipeline.apply(preferences: self.preferences)
                self.speech.setQuietVisionGuideEnabled(self.preferences.importantChangesOnly)
                self.pipeline.start(mode: self.currentMode, target: self.currentTarget)
                self.updateScreenAwake()
                switch self.currentMode {
                case .describe, .readText, .identifyColor:
                    self.captureStillForCurrentMode()
                case .liveGuide, .find, .scanBarcode:
                    self.renderState(.active, guidance: self.activeGuidance(), announce: true)
                case .inactive:
                    break
                }
            }
        }
    }

    private func captureStillForCurrentMode() {
        renderState(.active, guidance: currentMode == .readText ? "Capturing text. Hold steady." : "Capturing and analyzing.", announce: true)
        camera.captureHighResolutionPhoto { [weak self] result in
            guard let self else { return }
            switch result {
            case .failure(let error):
                self.showFailure(error.localizedDescription, offersSettings: false)
            case .success(let captured):
                guard let cgImage = captured.image.cgImage else {
                    self.handle(error: .cameraUnavailable)
                    return
                }
                self.pipeline.analyzeStillImage(
                    cgImage,
                    orientation: captured.orientation,
                    mode: self.currentMode,
                    target: self.currentTarget
                )
            }
        }
    }

    private func pauseVision() {
        guard currentState == .active else {
            showResult("Vision is not currently active.", announce: true)
            return
        }
        pipeline.pause()
        speech.pauseVisionNarration()
        renderState(.paused, guidance: "Vision paused. The camera is not being analyzed.", announce: true)
        updateScreenAwake()
    }

    private func resumeVision() {
        guard currentState == .paused else {
            beginCurrentMode()
            return
        }
        pipeline.resume()
        speech.resumeVisionNarration()
        renderState(.active, guidance: activeGuidance(), announce: true)
        updateScreenAwake()
    }

    private func stopVision(announce: Bool, message: String) {
        voiceInput.cancel()
        pipeline.stop()
        camera.stop()
        if let speechSessionID {
            speech.cancelVisionNarrationSession(speechSessionID)
            self.speechSessionID = nil
        } else {
            speech.stop()
        }
        if let hapticSessionID {
            haptics.endSession(hapticSessionID)
            self.hapticSessionID = nil
        }
        latestSnapshot = nil
        lastPresentedNarration = nil
        resultLabel.text = "Vision stopped. Session result cleared."
        VisionDiagnosticsStore.shared.setActiveCamera(nil)
        UIApplication.shared.isIdleTimerDisabled = false
        currentState = .stopped
        stateLabel.text = "Stopped"
        guidanceLabel.text = message
        primaryButton.setTitle(primaryTitle(), for: .normal)
        pauseReadingButton.setTitle("Pause Reading", for: .normal)
        if announce {
            postAnnouncement(message, force: true)
        }
    }

    private func pipelineStateChanged(mode: VisionMode, state: VisionSessionState) {
        guard mode == currentMode || mode == .inactive else { return }
        renderState(state, guidance: guidance(for: state), announce: state == .failed || state == .unavailable)
        if state == .stopped && (currentMode == .describe || currentMode == .readText || currentMode == .identifyColor) {
            camera.stop()
            VisionDiagnosticsStore.shared.setActiveCamera(nil)
        }
        updateScreenAwake()
    }

    private func received(snapshot: SceneSnapshot) {
        guard snapshot.mode == currentMode else { return }
        latestSnapshot = snapshot
        if let guidance = snapshot.quality.guidance.first, !snapshot.quality.isUsable {
            guidanceLabel.text = guidance
            playHaptic(.warning)
        }

        if let region = requestedRegion, currentMode == .describe {
            let narration = VisionNarrationService().narrate(
                snapshot: snapshot,
                verbosity: preferences.narrationVerbosity,
                region: region
            )
            ignoredAutomaticNarrationSnapshotID = snapshot.id
            received(narration: narration)
        }

        if currentMode == .find {
            updateFindHaptics(from: snapshot)
        }
    }

    private func received(narration: SceneNarration) {
        guard narration.snapshotIdentifier != ignoredAutomaticNarrationSnapshotID else {
            ignoredAutomaticNarrationSnapshotID = nil
            return
        }
        lastPresentedNarration = narration
        showResult(narration.text, announce: !speech.isEnabled)
        ensureFeedbackSessions()
        if let speechSessionID {
            speech.enqueueVisionNarration(narration, sessionID: speechSessionID)
        }
        switch narration.priority {
        case .warning:
            playHaptic(.warning)
        case .target:
            playHaptic(.targetAcquired)
        default:
            if narration.contentKind == .reading || narration.contentKind == .barcode {
                playHaptic(.success)
            }
        }
    }

    private func readingStateChanged(_ state: VisionReadingState) {
        readingControls.isHidden = currentMode != .readText
        let isPaused = state.status == .paused
        pauseReadingButton.setTitle(isPaused ? "Resume Reading" : "Pause Reading", for: .normal)
        pauseReadingButton.accessibilityLabel = isPaused ? "Resume reading" : "Pause reading"
    }

    private func handle(error: VisionError) {
        VisionDiagnosticsStore.shared.record(error: error)
        let message: String
        let offersSettings: Bool
        switch error {
        case .cameraPermissionDenied:
            message = "Camera access is off. Enable Camera in iOS Settings, then return and try again."
            offersSettings = true
        case .cameraUnavailable, .cameraInterrupted:
            message = "The camera is unavailable right now. Stop other camera use and try again."
            offersSettings = false
        case .modelMissing, .modelChecksumMismatch, .modelLoadFailed(_), .invalidModelOutput:
            message = "The on-device object model is unavailable or failed validation. Read Text and Scan may still work."
            offersSettings = false
        case .unsupportedTarget(let target):
            message = "Jarvis cannot reliably find \(target) with the installed model. Choose a supported object."
            offersSettings = false
        case .targetNotFound(let target):
            message = "I have not found \(target). Pan slowly, or stop and try from another position."
            offersSettings = false
        case .noTextFound:
            message = "No readable text was confirmed. Move closer, hold steadier, and try again."
            offersSettings = false
        case .flashlightUnavailable:
            message = "The flashlight is unavailable on this camera."
            offersSettings = false
        case .thermalDegraded:
            message = "Vision is running less often because the device is warm."
            offersSettings = false
        case .textRecognitionFailed:
            message = "Text recognition could not finish. Hold the phone steady and try again."
            offersSettings = false
        case .speechUnavailable:
            message = "Speech output is unavailable. Results remain visible on screen."
            offersSettings = true
        case .hapticsUnavailable:
            message = "Haptics are unavailable. Direction guidance will use speech."
            offersSettings = false
        case .insufficientMemory:
            message = "Vision stopped because memory is constrained. Close other apps and try again."
            offersSettings = false
        case .cancelled:
            return
        }
        showFailure(message, offersSettings: offersSettings)
        switch error {
        case .cameraInterrupted, .thermalDegraded, .flashlightUnavailable, .speechUnavailable, .hapticsUnavailable:
            break
        default:
            camera.stop()
            VisionDiagnosticsStore.shared.setActiveCamera(nil)
            UIApplication.shared.isIdleTimerDisabled = false
        }
    }

    private func handleCameraStartFailure(_ error: Error) {
        let authorization = CameraSessionService.authorizationStatus
        let diagnosticState: VisionAuthorizationState = authorization == .denied
            ? .denied
            : (authorization == .restricted ? .restricted : .unavailable)
        VisionDiagnosticsStore.shared.setPermissions(camera: diagnosticState)
        let message = authorization == .restricted
            ? "Camera access is restricted on this device. A device administrator or parental-control setting may need to change it."
            : error.localizedDescription
        showFailure(message, offersSettings: authorization == .denied)
    }

    private func renderState(_ state: VisionSessionState, guidance: String, announce: Bool) {
        currentState = state
        stateLabel.text = stateDisplayName(state)
        guidanceLabel.text = guidance
        primaryButton.setTitle(primaryTitle(), for: .normal)
        if announce {
            postAnnouncement("\(modeLabel.text ?? "Vision"). \(stateLabel.text ?? ""). \(guidance)")
        }
    }

    private func stateDisplayName(_ state: VisionSessionState) -> String {
        switch state {
        case .idle: return "Ready"
        case .preparing: return "Preparing"
        case .active:
            if currentMode == .find, let currentTarget { return "Searching for \(currentTarget)" }
            if currentMode == .readText { return "Reading"
            }
            return "Active"
        case .paused: return "Paused"
        case .stopping: return "Stopping"
        case .stopped: return "Stopped"
        case .unavailable: return "Unavailable"
        case .failed: return "Needs attention"
        }
    }

    private func guidance(for state: VisionSessionState) -> String {
        switch state {
        case .idle: return currentMode.visionReadyGuidance
        case .preparing: return "Preparing on-device Vision."
        case .active: return activeGuidance()
        case .paused: return "Vision is paused."
        case .stopping: return "Stopping camera analysis and narration."
        case .stopped: return "Vision is stopped."
        case .unavailable: return "Vision is unavailable. Review the recovery action below."
        case .failed: return "Vision could not finish. Review the recovery action below."
        }
    }

    private func activeGuidance() -> String {
        switch currentMode {
        case .liveGuide: return "Live Guide is active in the foreground. Stop is always available below."
        case .find: return "Searching for \(currentTarget ?? "the selected object"). Pan slowly."
        case .scanBarcode: return "Scanning for a barcode. Jarvis will not open links automatically."
        case .readText: return "Reading captured text on this device."
        case .identifyColor: return "Identifying the center color."
        case .describe, .inactive: return "Analyzing the captured scene on this device."
        }
    }

    private func primaryTitle() -> String {
        if currentState == .paused { return "Resume \(currentMode.visionDisplayName)" }
        if currentState == .active {
            switch currentMode {
            case .liveGuide: return "Pause Live Guide"
            case .find: return "Change Find Target"
            case .scanBarcode: return "Pause Barcode Scan"
            default: break
            }
        }
        if currentMode == .find, let currentTarget {
            return "Find \(currentTarget)"
        }
        return currentMode.visionPrimaryActionTitle
    }

    private func showResult(_ text: String, announce: Bool) {
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        resultLabel.text = clean
        failurePanel.isHidden = true
        if announce {
            postAnnouncement(clean)
        }
    }

    private func showFailure(_ message: String, offersSettings: Bool) {
        currentState = .unavailable
        stateLabel.text = "Needs attention"
        guidanceLabel.text = message
        failureLabel.text = message
        failurePanel.isHidden = false
        openSystemSettingsButton.isHidden = !offersSettings
        retryButton.isHidden = false
        playHaptic(.warning)
        postAnnouncement("Vision needs attention. \(message)", force: true)
    }

    private func repeatLastResult(prefix: String = "") {
        guard let narration = lastPresentedNarration ?? pipeline.repeatLastNarration() else {
            if resultLabel.text != "No result yet." {
                postAnnouncement("\(prefix)\(resultLabel.text ?? "")", force: true)
            } else {
                showResult("There is no Vision result to repeat yet.", announce: true)
            }
            return
        }
        let text = prefix + narration.text
        showResult(text, announce: !speech.isEnabled)
        ensureFeedbackSessions()
        if let speechSessionID {
            let repeated = SceneNarration(
                snapshotIdentifier: narration.snapshotIdentifier,
                text: text,
                priority: narration.priority,
                verbosity: narration.verbosity,
                contentKind: narration.contentKind,
                groundedObservationIdentifiers: narration.groundedObservationIdentifiers,
                isVerbatim: narration.isVerbatim
            )
            speech.enqueueVisionNarration(repeated, sessionID: speechSessionID)
        }
    }

    private func presentMoreDetail() {
        let narration: SceneNarration?
        if let latestSnapshot, let requestedRegion {
            narration = VisionNarrationService().narrate(
                snapshot: latestSnapshot,
                verbosity: .detailed,
                region: requestedRegion
            )
        } else {
            narration = pipeline.narration(moreDetailed: true)
        }
        guard let narration else {
            showResult("Capture a scene before asking for more detail.", announce: true)
            return
        }
        received(narration: narration)
    }

    private func speakCurrentReadingLine() {
        guard let line = pipeline.currentReadingLine() else {
            showResult("No additional reading line is available.", announce: true)
            return
        }
        showResult(line.text, announce: false)
        let narration = SceneNarration(
            snapshotIdentifier: UUID(),
            text: line.text,
            priority: .prominent,
            verbosity: .standard,
            contentKind: .reading,
            groundedObservationIdentifiers: [line.id],
            isVerbatim: true
        )
        ensureFeedbackSessions()
        if let speechSessionID {
            speech.enqueueVisionNarration(narration, sessionID: speechSessionID)
        }
    }

    private func updateFindHaptics(from snapshot: SceneSnapshot) {
        guard let target = currentTarget?.lowercased() else { return }
        let match = snapshot.objects.first {
            $0.isConfirmed && (
                $0.name.lowercased() == target ||
                $0.classIdentifier.lowercased() == target ||
                $0.name.lowercased().contains(target)
            )
        }
        guard let match else {
            if lastTargetCentered { playHaptic(.targetLost) }
            lastTargetCentered = false
            return
        }
        switch match.horizontalRegion {
        case .left: playHaptic(.directionLeft)
        case .right: playHaptic(.directionRight)
        case .center:
            playHaptic(lastTargetCentered ? .directionCenter : .targetAcquired)
            lastTargetCentered = true
        }
    }

    private func ensureFeedbackSessions() {
        if speechSessionID == nil {
            speechSessionID = speech.beginVisionNarrationSession()
        }
        if hapticSessionID == nil, preferences.hapticsEnabled {
            hapticSessionID = haptics.beginSession()
        }
    }

    private func resetFeedbackSessions() {
        if let speechSessionID {
            speech.cancelVisionNarrationSession(speechSessionID)
            self.speechSessionID = nil
        }
        if let hapticSessionID {
            haptics.endSession(hapticSessionID)
            self.hapticSessionID = nil
        }
    }

    private func playHaptic(_ cue: VisionHapticCue) {
        guard preferences.hapticsEnabled else { return }
        ensureFeedbackSessions()
        guard let hapticSessionID else { return }
        haptics.play(cue, intensity: preferences.hapticIntensity, sessionID: hapticSessionID)
    }

    private func updateScreenAwake() {
        UIApplication.shared.isIdleTimerDisabled = currentMode == .liveGuide && currentState == .active && preferences.keepScreenAwakeDuringLiveGuide
    }

    private func setFlashlight(_ enabled: Bool) {
        guard camera.state == .running else {
            let position: CameraSessionService.CameraPosition = preferences.cameraChoice == .front ? .front : .rear
            renderState(.preparing, guidance: "Preparing the camera for the flashlight.", announce: true)
            camera.requestAccessAndStart(position: position) { [weak self] result in
                guard let self else { return }
                switch result {
                case .success:
                    self.attachPreviewIfNeeded()
                    VisionDiagnosticsStore.shared.setPermissions(camera: .authorized)
                    VisionDiagnosticsStore.shared.setActiveCamera(
                        self.preferences.cameraChoice == .front ? .front : .rear
                    )
                    self.renderState(.active, guidance: "Camera active for flashlight control. Stop turns it off.", announce: false)
                    self.setFlashlight(enabled)
                case .failure(let error):
                    self.handleCameraStartFailure(error)
                }
            }
            return
        }
        camera.setTorch(enabled: enabled) { [weak self] result in
            switch result {
            case .success(let actual):
                self?.lightButton.setTitle(actual ? "Flashlight On" : "Flashlight Off", for: .normal)
                self?.lightButton.accessibilityValue = actual ? "On" : "Off"
                self?.showResult(actual ? "Flashlight turned on." : "Flashlight turned off.", announce: true)
            case .failure:
                self?.handle(error: .flashlightUnavailable)
            }
        }
    }

    private func attachPreviewIfNeeded() {
        guard previewLayer == nil else { return }
        let layer = AVCaptureVideoPreviewLayer(session: camera.session)
        layer.videoGravity = .resizeAspectFill
        previewView.layer.insertSublayer(layer, at: 0)
        previewLayer = layer
        view.setNeedsLayout()
    }

    private func handleVisionVoiceCommand(_ raw: String) {
        voiceButton.setTitle("Voice", for: .normal)
        let normalized = JarvisCommandPlanner().normalize(raw)
        if ["stop", "stop vision", "stop live guide", "stop reading", "stop speaking", "cancel"].contains(normalized) {
            apply(JarvisVisionLaunchRequest(mode: currentMode, command: .stop, source: "vision_voice"))
            return
        }
        if normalized == "help" || normalized == "vision help" {
            helpTapped()
            return
        }
        if normalized == "settings" || normalized == "vision settings" {
            settingsTapped()
            return
        }
        let plan = JarvisCommandPlanner().plan(raw)
        guard let request = plan.visionLaunchRequest else {
            showResult("That is not a recognized Vision command. Try describe, live guide, find, read, scan, repeat, more detail, flashlight, or stop.", announce: true)
            return
        }
        var sourced = request
        sourced.source = "vision_voice"
        apply(sourced)
    }

    private func promptForFindTarget() {
        let alert = UIAlertController(
            title: "Find an Object",
            message: "Name an object supported by the installed model. Jarvis will tell you honestly when a target is unsupported.",
            preferredStyle: .alert
        )
        alert.addTextField { field in
            field.placeholder = "Example: chair or door"
            field.accessibilityLabel = "Object to find"
            field.textContentType = .none
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Start Finding", style: .default) { [weak self, weak alert] _ in
            guard let self else { return }
            let target = alert?.textFields?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !target.isEmpty else {
                self.showResult("Name an object before starting Find.", announce: true)
                return
            }
            self.currentTarget = target
            self.primaryButton.setTitle(self.primaryTitle(), for: .normal)
            self.beginCurrentMode()
        })
        present(alert, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    private func postAnnouncement(_ text: String, force: Bool = false) {
        guard UIAccessibility.isVoiceOverRunning else { return }
        let now = Date()
        if !force, let lastAnnouncement {
            guard lastAnnouncement.text != text,
                  now.timeIntervalSince(lastAnnouncement.date) >= 1.2 else { return }
        }
        lastAnnouncement = (text, now)
        UIAccessibility.post(notification: .announcement, argument: text)
    }

    private func applyFixtureStateIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("-JARVIS_UI_TESTING") || arguments.contains("--jarvis-ui-test") else { return }
        let stateKey = arguments.firstIndex(of: "--jarvis-state") ?? arguments.firstIndex(of: "-JARVIS_VISUAL_STATE")
        let fixture = stateKey.flatMap { arguments.indices.contains($0 + 1) ? arguments[$0 + 1] : nil } ?? "inspection"
        guard fixture == "inspection" || fixture == "object_model_missing" || fixture.hasPrefix("vision_") else { return }
        isFixtureDriven = true
        fixtureBanner.isHidden = false
        previewView.accessibilityLabel = "Fixture preview. Camera is not active."

        switch fixture {
        case "vision_describe_listening":
            setMode(.describe, announce: false)
            stateLabel.text = "Listening"
            guidanceLabel.text = "Listening for a Vision command."
        case "vision_describe_analyzing":
            setMode(.describe, announce: false)
            renderState(.active, guidance: "Analyzing a demonstration fixture on this device.", announce: false)
        case "vision_describe_result":
            setMode(.describe, announce: false)
            renderState(.stopped, guidance: "Fixture analysis complete.", announce: false)
            showResult("I may be seeing a chair near the center and a table on the left.", announce: false)
        case "vision_live_active":
            setMode(.liveGuide, announce: false)
            renderState(.active, guidance: "Live Guide fixture is active. Camera is not active.", announce: false)
            showResult("A person-sized fixture moved from center to the right.", announce: false)
        case "vision_find_searching":
            currentTarget = "chair"
            setMode(.find, announce: false)
            renderState(.active, guidance: "Searching fixture for chair. Pan slowly.", announce: false)
        case "vision_find_centered":
            currentTarget = "chair"
            setMode(.find, announce: false)
            renderState(.active, guidance: "Target centered in demonstration fixture.", announce: false)
            showResult("I detect a chair near the center.", announce: false)
        case "vision_reading":
            setMode(.readText, announce: false)
            renderState(.active, guidance: "Reading demonstration text. Camera is not active.", announce: false)
            showResult("Jarvis Vision fixture: local processing, no image saved.", announce: false)
        case "vision_scan_result":
            setMode(.scanBarcode, announce: false)
            renderState(.active, guidance: "Barcode fixture found. No link was opened.", announce: false)
            showResult("Barcode fixture: 012345678905", announce: false)
        case "vision_permission_denied":
            setMode(.describe, announce: false)
            showFailure("Camera access is off. Enable Camera in iOS Settings, then return and try again.", offersSettings: true)
        case "vision_model_unavailable", "object_model_missing":
            setMode(.describe, announce: false)
            showFailure("The on-device object model is unavailable or failed validation. Read Text and Scan may still work.", offersSettings: false)
            guidanceLabel.text = "Visual scan ready. The on-device object model is unavailable."
        default:
            setMode(.describe, announce: false)
            renderState(.idle, guidance: "Vision is ready. Demonstration fixture only; camera is not active.", announce: false)
        }
    }

    @objc private func primaryTapped() {
        if isFixtureDriven {
            if currentState == .active {
                renderState(.paused, guidance: "Fixture Vision paused. Camera is not active.", announce: false)
            } else {
                renderState(.active, guidance: "Fixture Vision active. Camera is not active.", announce: false)
            }
            return
        }
        if currentState == .paused {
            resumeVision()
        } else if currentState == .active && (currentMode == .liveGuide || currentMode == .scanBarcode) {
            pauseVision()
        } else if currentState == .active && currentMode == .find {
            promptForFindTarget()
        } else {
            beginCurrentMode()
        }
    }

    @objc private func stopTapped() {
        stopVision(announce: true, message: "Vision and speech stopped.")
    }

    @objc private func voiceTapped() {
        if voiceInput.isListening {
            voiceInput.stopListening(process: true)
        } else {
            voiceInput.startListening()
        }
    }

    @objc private func repeatTapped() { repeatLastResult() }
    @objc private func moreDetailTapped() { presentMoreDetail() }
    @objc private func lightTapped() { setFlashlight(!camera.isTorchEnabled) }
    @objc private func retryTapped() { beginCurrentMode() }
    @objc private func previousLineTapped() {
        pipeline.advanceReadingLine(by: -1)
        speakCurrentReadingLine()
    }
    @objc private func nextLineTapped() {
        pipeline.advanceReadingLine(by: 1)
        speakCurrentReadingLine()
    }
    @objc private func pauseReadingTapped() {
        let shouldPause = pauseReadingButton.currentTitle != "Resume Reading"
        pipeline.setReadingPaused(shouldPause)
        if shouldPause { speech.pauseVisionNarration() } else { speech.resumeVisionNarration() }
    }

    @objc private func helpTapped() {
        let controller = JarvisHelpViewController(initialSection: .vision)
        navigationController?.pushViewController(controller, animated: !UIAccessibility.isReduceMotionEnabled)
    }

    @objc private func settingsTapped() {
        navigationController?.pushViewController(JarvisSettingsViewController(initialSection: .vision), animated: !UIAccessibility.isReduceMotionEnabled)
    }

    @objc private func openSystemSettingsTapped() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @objc private func applicationEnteredBackground() {
        guard currentState == .active || currentState == .preparing || currentState == .paused else { return }
        stopVision(announce: false, message: "Vision stopped because Jarvis moved to the background.")
    }

    @objc private func preferencesChanged() {
        pipeline.apply(preferences: preferences)
        speech.setQuietVisionGuideEnabled(preferences.importantChangesOnly)
        updateScreenAwake()
    }

    @objc private func runtimeConditionsChanged() {
        pipeline.updateRuntimeConditions(
            thermalState: ProcessInfo.processInfo.thermalState,
            lowPowerMode: ProcessInfo.processInfo.isLowPowerModeEnabled
        )
    }
}
