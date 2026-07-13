import CoreMedia
import CoreVideo
import Foundation
import ImageIO

struct VisionPipelineToken: Codable, Equatable, Hashable, Sendable {
    let sessionIdentifier: UUID
    let generation: UInt64
    let mode: VisionMode
    let startedAt: Date
}

enum VisionReadingStatus: String, Codable, CaseIterable, Sendable {
    case inactive
    case recognizing
    case ready
    case paused
    case completed
    case failed
}

struct VisionReadingState: Codable, Equatable, Sendable {
    let status: VisionReadingStatus
    let lines: [TextLine]
    let currentLineIndex: Int?
    let updatedAt: Date

    var lineCount: Int { lines.count }

    var currentLine: TextLine? {
        guard let currentLineIndex, lines.indices.contains(currentLineIndex) else { return nil }
        return lines[currentLineIndex]
    }

    static let inactive = VisionReadingState(
        status: .inactive,
        lines: [],
        currentLineIndex: nil,
        updatedAt: Date(timeIntervalSince1970: 0)
    )
}

struct VisionPipelineStatistics: Codable, Equatable, Sendable {
    let token: VisionPipelineToken?
    let submittedFrameCount: Int
    let analyzedFrameCount: Int
    let droppedFrameCount: Int
    let isAnalyzerRequestInFlight: Bool
    let processingProfile: VisionProcessingProfile
    let lastAnalysisLatency: TimeInterval?
    let averageAnalysisLatency: TimeInterval?
    let lastAcceptedFrameAt: Date?
}

final class VisionPipelineCoordinator: @unchecked Sendable {
    var onStateChange: ((VisionMode, VisionSessionState) -> Void)?
    var onSnapshot: ((SceneSnapshot) -> Void)?
    var onNarration: ((SceneNarration) -> Void)?
    var onError: ((VisionError) -> Void)?
    var onStatistics: ((VisionPipelineStatistics) -> Void)?
    var onReadingStateChange: ((VisionReadingState) -> Void)?
    var onColorResult: ((ColorAnalysisResult) -> Void)?
    var onGenerationChange: ((VisionPipelineToken) -> Void)?

    private enum AnalysisInput {
        case frame(CVPixelBuffer, CMTime)
        case still(CGImage)

        var isStill: Bool {
            if case .still = self { return true }
            return false
        }
    }

    private let detector: VisionDetecting
    private let textRecognizer: TextRecognitionService
    private let barcodeRecognizer: BarcodeRecognitionService
    private let peopleRecognizer: FaceAndPersonService
    private let qualityAnalyzer: CameraQualityAnalyzer
    private let colorAnalyzer: ColorAnalysisService
    private let memory: VisionSessionMemory
    private let diagnostics: VisionDiagnosticsStore
    private var tracker: TemporalObjectTracker
    private let fusion: SceneFusionEngine
    private let narrationServiceLock = NSLock()
    private var narrationService: VisionNarrationService

    private let stateQueue = DispatchQueue(label: "com.amrik.jarvisxr.vision.pipeline.state")
    private let analysisQueue = DispatchQueue(label: "com.amrik.jarvisxr.vision.pipeline.analysis", qos: .userInitiated)
    private weak var camera: CameraSessionService?

    private var modeValue: VisionMode = .inactive
    private var sessionStateValue: VisionSessionState = .idle
    private var tokenValue: VisionPipelineToken?
    private var generation: UInt64 = 0
    private var targetClassIdentifier: String?
    private var submittedFrames = 0
    private var analyzedFrames = 0
    private var droppedFrames = 0
    private var totalAnalysisLatency: TimeInterval = 0
    private var lastAnalysisLatency: TimeInterval?
    private var lastAcceptedFrameDate: Date?
    private var lastAcceptedFrameUptime: TimeInterval?
    private var inFlightGeneration: UInt64?
    private var acceptedFrameCountForSession = 0
    private var processingProfile: VisionProcessingProfile = .full
    private var thermalState: VisionThermalState = .nominal
    private var lowPowerMode = false
    private var readingStateValue: VisionReadingState = .inactive
    private var narrationVerbosity: NarrationVerbosity = .standard
    private var importantChangesOnly = true
    private var memoryEnabled = true
    private var processingPreference: VisionProcessingPreference = .automatic
    private var lastQualityNarrationKey: String?
    private var lastQualityNarrationAt: Date?
    private var latestSnapshotIdentifier: UUID?

    init(
        detector: VisionDetecting = ObjectDetectionService(),
        textRecognizer: TextRecognitionService = TextRecognitionService(),
        barcodeRecognizer: BarcodeRecognitionService = BarcodeRecognitionService(),
        peopleRecognizer: FaceAndPersonService = FaceAndPersonService(),
        qualityAnalyzer: CameraQualityAnalyzer = CameraQualityAnalyzer(),
        colorAnalyzer: ColorAnalysisService = ColorAnalysisService(),
        tracker: TemporalObjectTracker = TemporalObjectTracker(),
        fusion: SceneFusionEngine = SceneFusionEngine(),
        narrationService: VisionNarrationService = VisionNarrationService(),
        memory: VisionSessionMemory = VisionSessionMemory(),
        diagnostics: VisionDiagnosticsStore = .shared
    ) {
        self.detector = detector
        self.textRecognizer = textRecognizer
        self.barcodeRecognizer = barcodeRecognizer
        self.peopleRecognizer = peopleRecognizer
        self.qualityAnalyzer = qualityAnalyzer
        self.colorAnalyzer = colorAnalyzer
        self.tracker = tracker
        self.fusion = fusion
        self.narrationService = narrationService
        self.memory = memory
        self.diagnostics = diagnostics
        diagnostics.setAnalyzerAvailability(ocr: true, barcode: true)
    }

    var currentMode: VisionMode { stateQueue.sync { modeValue } }
    var sessionState: VisionSessionState { stateQueue.sync { sessionStateValue } }
    var currentToken: VisionPipelineToken? { stateQueue.sync { tokenValue } }
    var currentGeneration: UInt64 { stateQueue.sync { generation } }
    var statistics: VisionPipelineStatistics { stateQueue.sync { makeStatistics() } }
    var readingState: VisionReadingState { stateQueue.sync { readingStateValue } }

    func bind(to camera: CameraSessionService) {
        let previous = stateQueue.sync { () -> CameraSessionService? in
            let old = self.camera
            self.camera = camera
            return old
        }
        if previous !== camera {
            previous?.onFrame = nil
            previous?.onDroppedFrame = nil
            previous?.onStateChange = nil
        }
        camera.onFrame = { [weak self] pixelBuffer, timestamp, orientation in
            self?.submitFrame(pixelBuffer, timestamp: timestamp, orientation: orientation)
        }
        camera.onDroppedFrame = { [weak self] in self?.recordDroppedFrame() }
        camera.onStateChange = { [weak self] state in self?.handle(cameraState: state) }
    }

    func unbindCamera() {
        let bound = stateQueue.sync { () -> CameraSessionService? in
            defer { camera = nil }
            return camera
        }
        bound?.onFrame = nil
        bound?.onDroppedFrame = nil
        bound?.onStateChange = nil
    }

    func apply(preferences: VisionPreferences) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.narrationVerbosity = preferences.narrationVerbosity
            self.importantChangesOnly = preferences.importantChangesOnly
            self.memoryEnabled = preferences.temporarySessionMemoryEnabled
            self.processingPreference = preferences.processingPreference
            self.recalculateProcessingProfile()
            let profile = self.processingProfile
            self.diagnostics.setProcessingProfile(profile)
            self.emitStatistics(for: self.generation)
        }
        let safetyConfiguration = preferences.detectionSensitivity.safetyConfiguration
        analysisQueue.async { [weak self] in
            guard let self else { return }
            self.tracker = TemporalObjectTracker(configuration: TemporalObjectTrackerConfiguration(
                minimumConfidence: safetyConfiguration.minimumConfidence,
                confirmationFrames: safetyConfiguration.requiredStableFrames,
                intersectionOverUnionThreshold: 0.25,
                maximumMissedFrames: 3,
                maximumTrackAge: 1.5,
                smoothingFactor: 0.4,
                movementThreshold: 0.07,
                scaleChangeThreshold: 0.18
            ))
            self.setNarrationService(VisionNarrationService(
                safetyPolicy: VisionSafetyPolicy(configuration: safetyConfiguration)
            ))
        }
    }

    func start(mode: VisionMode, target: String? = nil) {
        guard mode != .inactive else {
            stop()
            return
        }
        switch beginSession(mode: mode, target: target) {
        case .failure(let error):
            publish(error: error, generation: currentGeneration)
        case .success(let requestGeneration):
            activate(generation: requestGeneration, mode: mode)
        }
    }

    func stop() {
        cancelAnalyzerWork()
        let stoppedGeneration = stateQueue.sync { () -> UInt64 in
            generation &+= 1
            modeValue = .inactive
            sessionStateValue = .stopped
            targetClassIdentifier = nil
            inFlightGeneration = nil
            readingStateValue = .inactive
            latestSnapshotIdentifier = nil
            tokenValue = VisionPipelineToken(
                sessionIdentifier: tokenValue?.sessionIdentifier ?? UUID(),
                generation: generation,
                mode: .inactive,
                startedAt: Date()
            )
            diagnostics.setActive(mode: .inactive, sessionState: .stopped)
            diagnostics.setProcessingProfile(.stopped)
            return generation
        }
        analysisQueue.async { [weak self] in
            self?.tracker.reset()
            self?.fusion.reset()
            self?.qualityAnalyzer.resetMotionHistory()
        }
        memory.clear()
        emitState(mode: .inactive, state: .stopped, generation: stoppedGeneration)
        emitReadingState(.inactive, generation: stoppedGeneration)
        emitTokenAndStatistics(generation: stoppedGeneration)
    }

    func pause() {
        cancelAnalyzerWork()
        let update: (UInt64, VisionMode, VisionPipelineToken)? = stateQueue.sync {
            guard sessionStateValue == .active || sessionStateValue == .preparing else { return nil }
            generation &+= 1
            sessionStateValue = .paused
            inFlightGeneration = nil
            let token = VisionPipelineToken(
                sessionIdentifier: tokenValue?.sessionIdentifier ?? UUID(),
                generation: generation,
                mode: modeValue,
                startedAt: tokenValue?.startedAt ?? Date()
            )
            tokenValue = token
            diagnostics.setActive(mode: modeValue, sessionState: .paused)
            return (generation, modeValue, token)
        }
        guard let update else { return }
        emitState(mode: update.1, state: .paused, generation: update.0)
        emitTokenAndStatistics(generation: update.0)
    }

    func resume() {
        let update: (UInt64, VisionMode)? = stateQueue.sync {
            guard sessionStateValue == .paused, modeValue != .inactive else { return nil }
            generation &+= 1
            sessionStateValue = .active
            tokenValue = VisionPipelineToken(
                sessionIdentifier: tokenValue?.sessionIdentifier ?? UUID(),
                generation: generation,
                mode: modeValue,
                startedAt: tokenValue?.startedAt ?? Date()
            )
            diagnostics.setActive(mode: modeValue, sessionState: .active)
            return (generation, modeValue)
        }
        guard let update else { return }
        emitState(mode: update.1, state: .active, generation: update.0)
        emitTokenAndStatistics(generation: update.0)
    }

    func submitFrame(
        _ pixelBuffer: CVPixelBuffer,
        timestamp: CMTime,
        orientation: CGImagePropertyOrientation
    ) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.submittedFrames += 1
            guard self.sessionStateValue == .active,
                  self.modeValue != .inactive,
                  self.inFlightGeneration == nil else {
                self.dropFrameLocked()
                return
            }
            let now = ProcessInfo.processInfo.systemUptime
            if let prior = self.lastAcceptedFrameUptime,
               now - prior < self.minimumFrameInterval(mode: self.modeValue) {
                self.dropFrameLocked()
                return
            }
            self.lastAcceptedFrameUptime = now
            self.lastAcceptedFrameDate = Date()
            self.inFlightGeneration = self.generation
            self.acceptedFrameCountForSession += 1
            let generation = self.generation
            let mode = self.modeValue
            let target = self.targetClassIdentifier
            self.emitStatistics(for: generation)
            self.analysisQueue.async {
                self.analyze(
                    input: .frame(pixelBuffer, timestamp),
                    orientation: orientation,
                    mode: mode,
                    target: target,
                    generation: generation,
                    startedAtUptime: now
                )
            }
        }
    }

    func analyzeStillImage(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation,
        mode: VisionMode,
        target: String? = nil
    ) {
        guard mode != .inactive else {
            publish(error: .cancelled, generation: currentGeneration)
            return
        }
        switch beginSession(mode: mode, target: target) {
        case .failure(let error):
            publish(error: error, generation: currentGeneration)
        case .success(let requestGeneration):
            activate(generation: requestGeneration, mode: mode) { [weak self] in
                self?.enqueueStill(
                    image,
                    orientation: orientation,
                    mode: mode,
                    generation: requestGeneration
                )
            }
        }
    }

    func updateRuntimeConditions(thermalState: ProcessInfo.ThermalState, lowPowerMode: Bool) {
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.thermalState = Self.map(thermalState)
            self.lowPowerMode = lowPowerMode
            self.recalculateProcessingProfile()
            self.diagnostics.setThermalState(self.thermalState, profile: self.processingProfile)
            self.emitStatistics(for: self.generation)
        }
    }

    func resetSession() {
        cancelAnalyzerWork()
        memory.clear()
        barcodeRecognizer.clearDeduplicationHistory()
        analysisQueue.async { [weak self] in
            self?.tracker.reset()
            self?.fusion.reset()
            self?.qualityAnalyzer.resetMotionHistory()
        }
        stateQueue.async { [weak self] in
            guard let self else { return }
            self.readingStateValue = .inactive
            self.acceptedFrameCountForSession = 0
            self.lastQualityNarrationKey = nil
            self.lastQualityNarrationAt = nil
            self.latestSnapshotIdentifier = nil
            self.emitReadingState(.inactive, generation: self.generation)
        }
    }

    func repeatLastNarration() -> SceneNarration? {
        memory.lastNarration()
    }

    func narration(moreDetailed: Bool) -> SceneNarration? {
        guard let snapshot = memory.latestSnapshot() else { return nil }
        let target = stateQueue.sync { targetClassIdentifier }
        let value = narrationServiceSnapshot().narrate(
            snapshot: snapshot,
            verbosity: moreDetailed ? .detailed : .concise,
            targetClassIdentifier: target
        )
        if stateQueue.sync(execute: { memoryEnabled }) { memory.record(narration: value) }
        return value
    }

    func setReadingPaused(_ paused: Bool) {
        let update: (VisionReadingState, UInt64)? = stateQueue.sync {
            guard !readingStateValue.lines.isEmpty else { return nil }
            let status: VisionReadingStatus = paused ? .paused : .ready
            readingStateValue = VisionReadingState(
                status: status,
                lines: readingStateValue.lines,
                currentLineIndex: readingStateValue.currentLineIndex,
                updatedAt: Date()
            )
            return (readingStateValue, generation)
        }
        if let update { emitReadingState(update.0, generation: update.1) }
    }

    func advanceReadingLine(by offset: Int) {
        let update: (VisionReadingState, UInt64, UUID?)? = stateQueue.sync {
            guard !readingStateValue.lines.isEmpty else { return nil }
            let current = readingStateValue.currentLineIndex ?? -1
            let requested = current + offset
            let clamped = min(max(requested, 0), readingStateValue.lines.count)
            let status: VisionReadingStatus = clamped >= readingStateValue.lines.count ? .completed : .ready
            readingStateValue = VisionReadingState(
                status: status,
                lines: readingStateValue.lines,
                currentLineIndex: status == .completed ? nil : clamped,
                updatedAt: Date()
            )
            return (readingStateValue, generation, latestSnapshotIdentifier)
        }
        guard let update else { return }
        emitReadingState(update.0, generation: update.1)
        if let line = update.0.currentLine,
           let snapshotIdentifier = update.2,
           let narration = narrationServiceSnapshot().verbatimNarration(
               line.text,
               snapshotIdentifier: snapshotIdentifier,
               kind: .reading
           ) {
            publish(narration: narration, generation: update.1)
        }
    }

    func currentReadingLine() -> TextLine? {
        stateQueue.sync { readingStateValue.currentLine }
    }

    private func beginSession(mode: VisionMode, target: String?) -> Result<UInt64, VisionError> {
        let resolvedTarget: Result<String?, VisionError>
        if mode == .find {
            guard let target, !target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return .failure(.unsupportedTarget("Say the name of an object to search for."))
            }
            switch VisionClassCatalog.resolveTarget(target) {
            case .supported(let definition), .supportedWithLimitation(let definition, _):
                resolvedTarget = .success(definition.identifier)
            case .ambiguous(_, let explanation), .unsupported(let explanation):
                resolvedTarget = .failure(.unsupportedTarget(explanation))
            }
        } else if let target,
                  case .supported(let definition) = VisionClassCatalog.resolveTarget(target) {
            resolvedTarget = .success(definition.identifier)
        } else {
            resolvedTarget = .success(nil)
        }
        guard case .success(let identifier) = resolvedTarget else {
            if case .failure(let error) = resolvedTarget { return .failure(error) }
            return .failure(.unsupportedTarget(target ?? ""))
        }

        cancelAnalyzerWork()
        memory.clear()
        barcodeRecognizer.clearDeduplicationHistory()
        analysisQueue.async { [weak self] in
            self?.tracker.reset()
            self?.fusion.reset()
            self?.qualityAnalyzer.resetMotionHistory()
        }
        let result = stateQueue.sync { () -> UInt64 in
            generation &+= 1
            modeValue = mode
            sessionStateValue = Self.requiresObjectDetector(mode) ? .preparing : .active
            targetClassIdentifier = identifier
            inFlightGeneration = nil
            acceptedFrameCountForSession = 0
            lastAcceptedFrameUptime = nil
            readingStateValue = mode == .readText
                ? VisionReadingState(status: .recognizing, lines: [], currentLineIndex: nil, updatedAt: Date())
                : .inactive
            lastQualityNarrationKey = nil
            lastQualityNarrationAt = nil
            latestSnapshotIdentifier = nil
            let token = VisionPipelineToken(
                sessionIdentifier: UUID(),
                generation: generation,
                mode: mode,
                startedAt: Date()
            )
            tokenValue = token
            diagnostics.setActive(mode: mode, sessionState: sessionStateValue)
            diagnostics.setProcessingProfile(processingProfile)
            return generation
        }
        emitState(mode: mode, state: Self.requiresObjectDetector(mode) ? .preparing : .active, generation: result)
        emitReadingState(readingState, generation: result)
        emitTokenAndStatistics(generation: result)
        return .success(result)
    }

    private func activate(generation requestGeneration: UInt64, mode: VisionMode, onReady: (() -> Void)? = nil) {
        guard Self.requiresObjectDetector(mode) else {
            onReady?()
            return
        }
        detector.prepare { [weak self] result in
            guard let self else { return }
            self.stateQueue.async {
                guard self.generation == requestGeneration, self.modeValue == mode else { return }
                switch result {
                case .success:
                    self.sessionStateValue = .active
                    self.diagnostics.setActive(mode: mode, sessionState: .active)
                    self.emitState(mode: mode, state: .active, generation: requestGeneration)
                    self.emitStatistics(for: requestGeneration)
                    onReady?()
                case .failure(let error):
                    self.sessionStateValue = .failed
                    self.inFlightGeneration = nil
                    self.diagnostics.setActive(mode: mode, sessionState: .failed)
                    self.diagnostics.record(error: error)
                    self.emitState(mode: mode, state: .failed, generation: requestGeneration)
                    self.publish(error: error, generation: requestGeneration)
                    self.emitStatistics(for: requestGeneration)
                }
            }
        }
    }

    private func enqueueStill(
        _ image: CGImage,
        orientation: CGImagePropertyOrientation,
        mode: VisionMode,
        generation requestGeneration: UInt64
    ) {
        stateQueue.async { [weak self] in
            guard let self,
                  self.generation == requestGeneration,
                  self.sessionStateValue == .active,
                  self.inFlightGeneration == nil else { return }
            self.submittedFrames += 1
            self.acceptedFrameCountForSession += 1
            self.inFlightGeneration = requestGeneration
            self.lastAcceptedFrameDate = Date()
            let target = self.targetClassIdentifier
            let started = ProcessInfo.processInfo.systemUptime
            self.emitStatistics(for: requestGeneration)
            self.analysisQueue.async {
                self.analyze(
                    input: .still(image),
                    orientation: orientation,
                    mode: mode,
                    target: target,
                    generation: requestGeneration,
                    startedAtUptime: started
                )
            }
        }
    }

    private func analyze(
        input: AnalysisInput,
        orientation: CGImagePropertyOrientation,
        mode: VisionMode,
        target: String?,
        generation requestGeneration: UInt64,
        startedAtUptime: TimeInterval
    ) {
        guard isCurrent(requestGeneration) else { return }
        let quality: CameraQualityReport
        switch input {
        case .frame(let pixelBuffer, _): quality = qualityAnalyzer.analyze(pixelBuffer: pixelBuffer)
        case .still(let image): quality = qualityAnalyzer.analyze(image: image)
        }
        guard quality.isUsable else {
            finishScene(
                input: input,
                mode: mode,
                target: target,
                generation: requestGeneration,
                quality: quality,
                startedAtUptime: startedAtUptime
            )
            return
        }

        switch mode {
        case .describe:
            detectObjects(input: input, orientation: orientation, target: target) { [weak self] detection in
                guard let self else { return }
                switch detection {
                case .failure(let error):
                    self.failPipeline(error, generation: requestGeneration, startedAtUptime: startedAtUptime)
                case .success(let result):
                    self.detectPeople(input: input, orientation: orientation) { people in
                        self.recognizeText(input: input, orientation: orientation, mode: .fast) { text in
                            self.finishScene(
                                input: input,
                                mode: mode,
                                target: target,
                                generation: requestGeneration,
                                objects: result.observations,
                                text: text.map { [$0.observation] } ?? [],
                                people: people?.people ?? [],
                                quality: quality,
                                startedAtUptime: startedAtUptime
                            )
                        }
                    }
                }
            }
        case .liveGuide, .find:
            detectObjects(input: input, orientation: orientation, target: target) { [weak self] detection in
                guard let self else { return }
                switch detection {
                case .failure(let error):
                    self.failPipeline(error, generation: requestGeneration, startedAtUptime: startedAtUptime)
                case .success(let result):
                    self.finishScene(
                        input: input,
                        mode: mode,
                        target: target,
                        generation: requestGeneration,
                        objects: result.observations,
                        quality: quality,
                        startedAtUptime: startedAtUptime
                    )
                }
            }
        case .readText:
            recognizeText(input: input, orientation: orientation, mode: .accurate) { [weak self] text in
                guard let self else { return }
                guard let text else {
                    self.failPipeline(.noTextFound, generation: requestGeneration, startedAtUptime: startedAtUptime, terminal: false)
                    return
                }
                self.finishScene(
                    input: input,
                    mode: mode,
                    target: target,
                    generation: requestGeneration,
                    text: [text.observation],
                    quality: quality,
                    startedAtUptime: startedAtUptime
                )
            }
        case .scanBarcode:
            recognizeBarcodes(input: input, orientation: orientation) { [weak self] result in
                guard let self else { return }
                switch result {
                case .failure(let error):
                    self.failPipeline(error, generation: requestGeneration, startedAtUptime: startedAtUptime, terminal: false)
                case .success(let value):
                    self.finishScene(
                        input: input,
                        mode: mode,
                        target: target,
                        generation: requestGeneration,
                        barcodes: value.observations,
                        quality: quality,
                        startedAtUptime: startedAtUptime
                    )
                }
            }
        case .identifyColor:
            let result: ColorAnalysisResult
            switch input {
            case .frame(let pixelBuffer, _): result = colorAnalyzer.analyze(pixelBuffer: pixelBuffer)
            case .still(let image): result = colorAnalyzer.analyze(image: image)
            }
            finishColor(
                result,
                quality: quality,
                generation: requestGeneration,
                startedAtUptime: startedAtUptime
            )
        case .inactive:
            failPipeline(.cancelled, generation: requestGeneration, startedAtUptime: startedAtUptime)
        }
    }

    private func finishScene(
        input: AnalysisInput,
        mode: VisionMode,
        target: String?,
        generation requestGeneration: UInt64,
        objects: [ObjectObservation] = [],
        text: [TextObservation] = [],
        barcodes: [BarcodeObservation] = [],
        people: [PersonObservation] = [],
        quality: CameraQualityReport,
        startedAtUptime: TimeInterval
    ) {
        analysisQueue.async { [weak self] in
            guard let self, self.isCurrent(requestGeneration) else { return }
            let narrator = self.narrationServiceSnapshot()
            let timestamp = Date()
            let tracking = self.tracker.update(with: objects, at: timestamp)
            let fused = self.fusion.fuse(
                mode: mode,
                trackingUpdate: tracking,
                text: text,
                barcodes: barcodes,
                people: people,
                quality: quality,
                at: timestamp
            )
            let snapshot: SceneSnapshot
            if input.isStill, tracking.confirmed.isEmpty, !tracking.active.isEmpty {
                snapshot = SceneSnapshot(
                    mode: mode,
                    capturedAt: timestamp,
                    objects: tracking.active,
                    text: text,
                    barcodes: barcodes,
                    people: people,
                    quality: quality,
                    changes: tracking.changes
                )
            } else {
                snapshot = fused
            }
            if self.stateQueue.sync(execute: { self.memoryEnabled }) {
                self.memory.record(snapshot: snapshot)
            }
            self.stateQueue.sync {
                guard self.generation == requestGeneration else { return }
                self.latestSnapshotIdentifier = snapshot.id
            }
            self.publish(snapshot: snapshot, generation: requestGeneration)

            var narration: SceneNarration?
            var terminal = false
            switch mode {
            case .describe:
                if !quality.isUsable {
                    narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity())
                    terminal = true
                } else if input.isStill {
                    narration = self.singleFrameNarration(snapshot: snapshot, target: target)
                    terminal = true
                } else if !snapshot.objects.isEmpty {
                    narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity())
                    terminal = true
                } else if self.acceptedCount() >= self.requiredObservationFrames() {
                    narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity())
                    terminal = true
                }
            case .liveGuide:
                if !quality.isUsable {
                    if self.shouldNarrateQuality(quality, at: timestamp) {
                        narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity())
                    }
                } else {
                    let meaningful = snapshot.changes.contains { change in
                        switch change.kind {
                        case .appeared, .approaching, .lost: return true
                        case .moved, .receding: return !self.changesOnlyImportant()
                        case .persisted, .uncertain: return false
                        }
                    }
                    if meaningful {
                        narration = narrator.narrateChanges(in: snapshot, verbosity: self.verbosity())
                    }
                }
            case .find:
                if !quality.isUsable {
                    narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity(), targetClassIdentifier: target)
                    terminal = input.isStill
                } else if let target, snapshot.object(classIdentifier: target) != nil {
                    narration = narrator.narrate(
                        snapshot: snapshot,
                        verbosity: self.verbosity(),
                        targetClassIdentifier: target
                    )
                    terminal = true
                } else if input.isStill {
                    narration = self.singleFrameNarration(snapshot: snapshot, target: target)
                    terminal = true
                }
            case .readText:
                if !quality.isUsable {
                    narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity())
                    self.setReadingFailure(generation: requestGeneration)
                    terminal = true
                } else if let observation = text.first {
                    terminal = true
                    let lines = observation.linesInReadingOrder
                    self.setReading(lines: lines, generation: requestGeneration)
                    if let first = lines.first {
                        narration = narrator.verbatimNarration(
                            first.text,
                            snapshotIdentifier: snapshot.id,
                            kind: .reading,
                            createdAt: timestamp
                        )
                    }
                }
            case .scanBarcode:
                if !quality.isUsable {
                    narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity())
                    terminal = true
                } else if let barcode = barcodes.first {
                    narration = narrator.verbatimNarration(
                        barcode.payload,
                        snapshotIdentifier: snapshot.id,
                        kind: .barcode,
                        createdAt: timestamp
                    )
                    terminal = true
                }
            case .identifyColor:
                if !quality.isUsable {
                    narration = narrator.narrate(snapshot: snapshot, verbosity: self.verbosity())
                    terminal = true
                }
            case .inactive:
                break
            }
            if let narration { self.publish(narration: narration, generation: requestGeneration) }
            self.finishAnalysis(
                generation: requestGeneration,
                startedAtUptime: startedAtUptime,
                terminal: terminal,
                mode: mode
            )
        }
    }

    private func finishColor(
        _ result: ColorAnalysisResult,
        quality: CameraQualityReport,
        generation requestGeneration: UInt64,
        startedAtUptime: TimeInterval
    ) {
        analysisQueue.async { [weak self] in
            guard let self, self.isCurrent(requestGeneration) else { return }
            let narrator = self.narrationServiceSnapshot()
            let snapshot = SceneSnapshot(mode: .identifyColor, quality: quality)
            if self.stateQueue.sync(execute: { self.memoryEnabled }) { self.memory.record(snapshot: snapshot) }
            self.stateQueue.sync {
                guard self.generation == requestGeneration else { return }
                self.latestSnapshotIdentifier = snapshot.id
            }
            self.publish(snapshot: snapshot, generation: requestGeneration)
            self.publish(color: result, generation: requestGeneration)
            let phrase = result.isUncertain
                ? "The center may be \(result.name), but the color is not consistent enough for a confident answer."
                : "The center appears \(result.name)."
            let narration = SceneNarration(
                snapshotIdentifier: snapshot.id,
                text: narrator.safetyPolicy.safeNarration(phrase),
                priority: .target,
                verbosity: self.verbosity(),
                contentKind: .scene
            )
            self.publish(narration: narration, generation: requestGeneration)
            self.finishAnalysis(
                generation: requestGeneration,
                startedAtUptime: startedAtUptime,
                terminal: true,
                mode: .identifyColor
            )
        }
    }

    private func singleFrameNarration(snapshot: SceneSnapshot, target: String?) -> SceneNarration {
        let narrator = narrationServiceSnapshot()
        let minimum = target == nil ? 0.58 : 0.54
        let candidates = snapshot.objects.filter {
            $0.smoothedConfidence >= minimum && (target == nil || $0.classIdentifier == target)
        }.sorted { $0.smoothedConfidence > $1.smoothedConfidence }
        let text: String
        if let first = candidates.first {
            text = "In this single image, I may be seeing \(first.name) \(first.horizontalRegion.spokenLocation)."
        } else if let target {
            let name = VisionClassCatalog.definition(forIdentifier: target)?.displayName ?? target
            text = "I have not found \(name) in this image. I may be missing it."
        } else {
            text = narrator.safetyPolicy.qualifiedAbsence()
        }
        return SceneNarration(
            snapshotIdentifier: snapshot.id,
            text: narrator.safetyPolicy.safeNarration(text),
            priority: target == nil ? .prominent : .target,
            verbosity: verbosity(),
            contentKind: target == nil ? .scene : .target,
            groundedObservationIdentifiers: candidates.prefix(1).map { $0.observation.id }
        )
    }

    private func finishAnalysis(
        generation requestGeneration: UInt64,
        startedAtUptime: TimeInterval,
        terminal: Bool,
        mode: VisionMode
    ) {
        let latency = max(0, ProcessInfo.processInfo.systemUptime - startedAtUptime)
        stateQueue.async { [weak self] in
            guard let self,
                  self.generation == requestGeneration,
                  self.inFlightGeneration == requestGeneration else { return }
            self.inFlightGeneration = nil
            self.analyzedFrames += 1
            self.totalAnalysisLatency += latency
            self.lastAnalysisLatency = latency
            self.diagnostics.recordInference(latency: latency)
            if terminal {
                self.sessionStateValue = .stopped
                self.diagnostics.setActive(mode: mode, sessionState: .stopped)
                self.emitState(mode: mode, state: .stopped, generation: requestGeneration)
            }
            self.emitStatistics(for: requestGeneration)
        }
    }

    private func failPipeline(
        _ error: VisionError,
        generation requestGeneration: UInt64,
        startedAtUptime: TimeInterval,
        terminal: Bool = true
    ) {
        let latency = max(0, ProcessInfo.processInfo.systemUptime - startedAtUptime)
        stateQueue.async { [weak self] in
            guard let self, self.generation == requestGeneration else { return }
            if self.inFlightGeneration == requestGeneration { self.inFlightGeneration = nil }
            self.analyzedFrames += 1
            self.totalAnalysisLatency += latency
            self.lastAnalysisLatency = latency
            self.diagnostics.record(error: error)
            if terminal {
                self.sessionStateValue = .failed
                self.diagnostics.setActive(mode: self.modeValue, sessionState: .failed)
                self.emitState(mode: self.modeValue, state: .failed, generation: requestGeneration)
            }
            self.publish(error: error, generation: requestGeneration)
            self.emitStatistics(for: requestGeneration)
        }
    }

    private func detectObjects(
        input: AnalysisInput,
        orientation: CGImagePropertyOrientation,
        target: String?,
        completion: @escaping (Result<ObjectDetectionResult, VisionError>) -> Void
    ) {
        switch input {
        case .frame(let pixelBuffer, _):
            detector.detectObjects(
                in: pixelBuffer,
                orientation: orientation,
                requestedClassIdentifier: target,
                completion: completion
            )
        case .still(let image):
            detector.detectObjects(
                in: image,
                orientation: orientation,
                requestedClassIdentifier: target,
                completion: completion
            )
        }
    }

    private func recognizeText(
        input: AnalysisInput,
        orientation: CGImagePropertyOrientation,
        mode: TextRecognitionMode,
        completion: @escaping (TextRecognitionResult?) -> Void
    ) {
        let callback: (Result<TextRecognitionResult, VisionError>) -> Void = { result in
            switch result {
            case .success(let value): completion(value)
            case .failure(.noTextFound): completion(nil)
            case .failure: completion(nil)
            }
        }
        switch input {
        case .frame(let pixelBuffer, _):
            textRecognizer.recognize(in: pixelBuffer, orientation: orientation, mode: mode, completion: callback)
        case .still(let image):
            textRecognizer.recognize(in: image, orientation: orientation, mode: mode, completion: callback)
        }
    }

    private func recognizeBarcodes(
        input: AnalysisInput,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (Result<BarcodeRecognitionResult, VisionError>) -> Void
    ) {
        switch input {
        case .frame(let pixelBuffer, _):
            barcodeRecognizer.recognize(in: pixelBuffer, orientation: orientation, completion: completion)
        case .still(let image):
            barcodeRecognizer.recognize(in: image, orientation: orientation, completion: completion)
        }
    }

    private func detectPeople(
        input: AnalysisInput,
        orientation: CGImagePropertyOrientation,
        completion: @escaping (FaceAndPersonResult?) -> Void
    ) {
        let callback: (Result<FaceAndPersonResult, VisionError>) -> Void = { result in
            if case .success(let value) = result { completion(value) } else { completion(nil) }
        }
        switch input {
        case .frame(let pixelBuffer, _):
            peopleRecognizer.analyze(pixelBuffer: pixelBuffer, orientation: orientation, completion: callback)
        case .still(let image):
            peopleRecognizer.analyze(image: image, orientation: orientation, completion: callback)
        }
    }

    private func setReading(lines: [TextLine], generation requestGeneration: UInt64) {
        let state = stateQueue.sync { () -> VisionReadingState? in
            guard generation == requestGeneration else { return nil }
            readingStateValue = VisionReadingState(
                status: lines.isEmpty ? .failed : .ready,
                lines: lines,
                currentLineIndex: lines.isEmpty ? nil : 0,
                updatedAt: Date()
            )
            return readingStateValue
        }
        if let state { emitReadingState(state, generation: requestGeneration) }
    }

    private func setReadingFailure(generation requestGeneration: UInt64) {
        let state = stateQueue.sync { () -> VisionReadingState? in
            guard generation == requestGeneration else { return nil }
            readingStateValue = VisionReadingState(
                status: .failed,
                lines: [],
                currentLineIndex: nil,
                updatedAt: Date()
            )
            return readingStateValue
        }
        if let state { emitReadingState(state, generation: requestGeneration) }
    }

    private func cancelAnalyzerWork() {
        detector.cancelAll()
        textRecognizer.cancelAll()
        barcodeRecognizer.cancelAll()
        peopleRecognizer.cancelAll()
    }

    private func recordDroppedFrame() {
        stateQueue.async { [weak self] in
            self?.dropFrameLocked()
        }
    }

    private func dropFrameLocked() {
        droppedFrames += 1
        diagnostics.recordDroppedFrame()
        emitStatistics(for: generation)
    }

    private func handle(cameraState: CameraSessionService.State) {
        switch cameraState {
        case .running:
            diagnostics.setCameraSessionState(.active)
        case .interrupted:
            diagnostics.setCameraSessionState(.paused)
            pause()
            publish(error: .cameraInterrupted, generation: currentGeneration)
        case .unavailable:
            cancelAnalyzerWork()
            let update = stateQueue.sync { () -> (UInt64, VisionMode) in
                generation &+= 1
                sessionStateValue = .unavailable
                inFlightGeneration = nil
                tokenValue = VisionPipelineToken(
                    sessionIdentifier: tokenValue?.sessionIdentifier ?? UUID(),
                    generation: generation,
                    mode: modeValue,
                    startedAt: tokenValue?.startedAt ?? Date()
                )
                diagnostics.setActive(mode: modeValue, sessionState: .unavailable)
                return (generation, modeValue)
            }
            emitState(mode: update.1, state: .unavailable, generation: update.0)
            publish(error: .cameraUnavailable, generation: update.0)
            emitTokenAndStatistics(generation: update.0)
        case .stopped:
            diagnostics.setCameraSessionState(.stopped)
        case .idle:
            diagnostics.setCameraSessionState(.idle)
        case .requestingPermission, .configuring:
            diagnostics.setCameraSessionState(.preparing)
        }
    }

    private func acceptedCount() -> Int { stateQueue.sync { acceptedFrameCountForSession } }
    private func verbosity() -> NarrationVerbosity { stateQueue.sync { narrationVerbosity } }
    private func changesOnlyImportant() -> Bool { stateQueue.sync { importantChangesOnly } }

    private func requiredObservationFrames() -> Int {
        narrationServiceSnapshot().safetyPolicy.configuration.requiredStableFrames
    }

    private func narrationServiceSnapshot() -> VisionNarrationService {
        narrationServiceLock.lock()
        defer { narrationServiceLock.unlock() }
        return narrationService
    }

    private func setNarrationService(_ service: VisionNarrationService) {
        narrationServiceLock.lock()
        narrationService = service
        narrationServiceLock.unlock()
    }

    private func shouldNarrateQuality(_ quality: CameraQualityReport, at date: Date) -> Bool {
        let key = quality.warnings.map(\.rawValue).sorted().joined(separator: ",")
        return stateQueue.sync {
            let elapsed = lastQualityNarrationAt.map { date.timeIntervalSince($0) } ?? .infinity
            guard key != lastQualityNarrationKey || elapsed >= 5 else { return false }
            lastQualityNarrationKey = key
            lastQualityNarrationAt = date
            return true
        }
    }

    private func minimumFrameInterval(mode: VisionMode) -> TimeInterval {
        let base: TimeInterval
        switch processingProfile {
        case .full: base = mode == .liveGuide || mode == .find ? 0.45 : 0.22
        case .balanced: base = mode == .liveGuide || mode == .find ? 0.75 : 0.40
        case .reduced: base = mode == .liveGuide || mode == .find ? 1.35 : 0.75
        case .targetOnly: base = 0.65
        case .stopped: base = .infinity
        }
        return base
    }

    private func recalculateProcessingProfile() {
        if thermalState == .critical || thermalState == .serious {
            processingProfile = .reduced
        } else if processingPreference == .reducedPower || lowPowerMode {
            processingProfile = modeValue == .find ? .targetOnly : .balanced
        } else if processingPreference == .standard {
            processingProfile = .full
        } else {
            processingProfile = thermalState == .fair ? .balanced : .full
        }
    }

    private static func requiresObjectDetector(_ mode: VisionMode) -> Bool {
        mode == .describe || mode == .liveGuide || mode == .find
    }

    private static func map(_ value: ProcessInfo.ThermalState) -> VisionThermalState {
        switch value {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .unknown
        }
    }

    private func isCurrent(_ requestGeneration: UInt64) -> Bool {
        stateQueue.sync { generation == requestGeneration }
    }

    private func makeStatistics() -> VisionPipelineStatistics {
        VisionPipelineStatistics(
            token: tokenValue,
            submittedFrameCount: submittedFrames,
            analyzedFrameCount: analyzedFrames,
            droppedFrameCount: droppedFrames,
            isAnalyzerRequestInFlight: inFlightGeneration != nil,
            processingProfile: processingProfile,
            lastAnalysisLatency: lastAnalysisLatency,
            averageAnalysisLatency: analyzedFrames > 0 ? totalAnalysisLatency / Double(analyzedFrames) : nil,
            lastAcceptedFrameAt: lastAcceptedFrameDate
        )
    }

    private func publish(snapshot: SceneSnapshot, generation requestGeneration: UInt64) {
        deliver(generation: requestGeneration) { [weak self] in self?.onSnapshot?(snapshot) }
    }

    private func publish(narration: SceneNarration, generation requestGeneration: UInt64) {
        if stateQueue.sync(execute: { memoryEnabled }) { memory.record(narration: narration) }
        deliver(generation: requestGeneration) { [weak self] in self?.onNarration?(narration) }
    }

    private func publish(error: VisionError, generation requestGeneration: UInt64) {
        deliver(generation: requestGeneration) { [weak self] in self?.onError?(error) }
    }

    private func publish(color: ColorAnalysisResult, generation requestGeneration: UInt64) {
        deliver(generation: requestGeneration) { [weak self] in self?.onColorResult?(color) }
    }

    private func emitState(mode: VisionMode, state: VisionSessionState, generation requestGeneration: UInt64) {
        deliver(generation: requestGeneration) { [weak self] in self?.onStateChange?(mode, state) }
    }

    private func emitReadingState(_ state: VisionReadingState, generation requestGeneration: UInt64) {
        deliver(generation: requestGeneration) { [weak self] in self?.onReadingStateChange?(state) }
    }

    private func emitTokenAndStatistics(generation requestGeneration: UInt64) {
        let values = stateQueue.sync { (tokenValue, makeStatistics()) }
        if let token = values.0 {
            deliver(generation: requestGeneration) { [weak self] in self?.onGenerationChange?(token) }
        }
        deliver(generation: requestGeneration) { [weak self] in self?.onStatistics?(values.1) }
    }

    private func emitStatistics(for requestGeneration: UInt64) {
        let value = makeStatistics()
        deliver(generation: requestGeneration) { [weak self] in self?.onStatistics?(value) }
    }

    private func deliver(generation requestGeneration: UInt64, _ action: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard self?.isCurrent(requestGeneration) == true else { return }
            action()
        }
    }
}
