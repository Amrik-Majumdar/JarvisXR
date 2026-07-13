import AVFoundation
import UIKit

enum JarvisVoiceProfile: String {
    static let ordered: [JarvisVoiceProfile] = [.natural, .friendly, .crisp, .quiet, .formal]

    case natural
    case friendly
    case formal
    case crisp
    case quiet

    var displayName: String {
        rawValue.prefix(1).uppercased() + rawValue.dropFirst()
    }

    var descriptor: JarvisVoiceProfileDescriptor {
        switch self {
        case .natural:
            return JarvisVoiceProfileDescriptor(languages: ["en-US", "en-CA"], voiceSlot: 0, rate: 0.46, pitch: 1.00, volume: 0.90)
        case .friendly:
            return JarvisVoiceProfileDescriptor(languages: ["en-AU", "en-US"], voiceSlot: 1, rate: 0.47, pitch: 1.08, volume: 0.92)
        case .formal:
            return JarvisVoiceProfileDescriptor(languages: ["en-GB", "en-IE"], voiceSlot: 0, rate: 0.42, pitch: 0.94, volume: 0.88)
        case .crisp:
            return JarvisVoiceProfileDescriptor(languages: ["en-US", "en-GB"], voiceSlot: 2, rate: 0.53, pitch: 1.03, volume: 0.96)
        case .quiet:
            return JarvisVoiceProfileDescriptor(languages: ["en-IE", "en-GB", "en-US"], voiceSlot: 3, rate: 0.38, pitch: 0.92, volume: 0.58)
        }
    }
}

struct JarvisVoiceProfileDescriptor: Equatable {
    let languages: [String]
    let voiceSlot: Int
    let rate: Float
    let pitch: Float
    let volume: Float
}

struct JarvisResolvedVoiceConfiguration: Equatable {
    let profile: JarvisVoiceProfile
    let voiceIdentifier: String?
    let voiceName: String
    let locale: String
    let rate: Float
    let pitch: Float
    let volume: Float
    let usedFallbackVoice: Bool
}

/// UIKit-owned speech adapter. Production callers and notification recovery enter
/// through the main thread; AVSpeechSynthesizer remains encapsulated here.
final class JarvisSpeechService: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
    static let shared = JarvisSpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private let enabledKey = "JarvisXR.speechEnabled"
    private let rateKey = "JarvisXR.speechRate"
    private let pitchKey = "JarvisXR.speechPitch"
    private let volumeKey = "JarvisXR.speechVolume"
    private let profileKey = "JarvisXR.voiceProfile"
    private let personalVoiceKey = "JarvisXR.preferPersonalVoice"
    private var suppressNextCallbacks = false
    private var visionQueue = VisionSpeechPriorityQueue()
    private var activeVisionItem: VisionSpeechQueueItem?
    private var activeVisionUtterance: AVSpeechUtterance?
    private var visionQueuePaused = false
    private var visionWasPausedByAudioInterruption = false
    private var quietVisionGuideEnabled = false
    var onSpeechStart: (() -> Void)?
    var onSpeechFinish: (() -> Void)?

    var isEnabled: Bool {
        get {
            if UserDefaults.standard.object(forKey: enabledKey) == nil {
                return true
            }
            return UserDefaults.standard.bool(forKey: enabledKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: enabledKey)
        }
    }

    var speechRate: Float {
        get {
            if UserDefaults.standard.object(forKey: rateKey) != nil {
                return min(max(UserDefaults.standard.float(forKey: rateKey), 0.35), 0.58)
            }
            return profile.descriptor.rate
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.35), 0.55), forKey: rateKey)
        }
    }

    var pitch: Float {
        get {
            if UserDefaults.standard.object(forKey: pitchKey) != nil {
                return min(max(UserDefaults.standard.float(forKey: pitchKey), 0.85), 1.10)
            }
            return profile.descriptor.pitch
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.85), 1.08), forKey: pitchKey)
        }
    }

    var volume: Float {
        get {
            if UserDefaults.standard.object(forKey: volumeKey) != nil {
                return min(max(UserDefaults.standard.float(forKey: volumeKey), 0.4), 1.0)
            }
            return profile.descriptor.volume
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.4), 1.0), forKey: volumeKey)
        }
    }

    var profile: JarvisVoiceProfile {
        get {
            guard let raw = UserDefaults.standard.string(forKey: profileKey),
                  let value = JarvisVoiceProfile(rawValue: raw) else {
                return .natural
            }
            return value
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: profileKey)
        }
    }

    var prefersPersonalVoice: Bool {
        get { UserDefaults.standard.bool(forKey: personalVoiceKey) }
        set { UserDefaults.standard.set(newValue, forKey: personalVoiceKey) }
    }

    private override init() {
        super.init()
        synthesizer.delegate = self
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioRouteChange(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: AVAudioSession.sharedInstance()
        )
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    /// Begins a new vision narration scope. Starting another scope invalidates queued
    /// results from the previous mode so an old frame cannot speak after a mode change.
    @MainActor
    func beginVisionNarrationSession() -> UUID {
        let sessionID = UUID()
        let wasSpeakingVision = activeVisionItem != nil
        activeVisionItem = nil
        activeVisionUtterance = nil
        visionQueue.beginSession(sessionID)
        visionQueuePaused = false
        if wasSpeakingVision {
            synthesizer.stopSpeaking(at: .immediate)
        }
        return sessionID
    }

    @MainActor
    func setQuietVisionGuideEnabled(_ enabled: Bool) {
        quietVisionGuideEnabled = enabled
        if enabled {
            // Preserve only target and warning results already waiting to speak.
            let sessionID = visionQueue.activeSessionID
            visionQueue.cancelAll()
            if let sessionID {
                visionQueue.beginSession(sessionID)
            }
        }
    }

    @MainActor
    @discardableResult
    func enqueueVisionNarration(
        _ narration: SceneNarration,
        sessionID: UUID,
        at date: Date = Date()
    ) -> VisionSpeechEnqueueDisposition {
        guard isEnabled else { return .rejectedExpired }
        if Self.shouldSuppressVisionNarration(narration, quietModeEnabled: quietVisionGuideEnabled) {
            return .suppressedQuietMode
        }

        let item = VisionSpeechQueueItem(sessionID: sessionID, narration: narration)
        let disposition = visionQueue.enqueue(item, current: activeVisionItem, at: date)
        switch disposition {
        case .queued:
            speakNextVisionItemIfPossible()
        case .interruptCurrent:
            activeVisionItem = nil
            activeVisionUtterance = nil
            if synthesizer.stopSpeaking(at: .immediate) {
                DispatchQueue.main.async { [weak self] in
                    self?.speakNextVisionItemIfPossible()
                }
            } else {
                speakNextVisionItemIfPossible()
            }
        case .suppressedDuplicate, .suppressedQuietMode, .rejectedStaleSession, .rejectedExpired:
            break
        }
        return disposition
    }

    static func shouldSuppressVisionNarration(
        _ narration: SceneNarration,
        quietModeEnabled: Bool
    ) -> Bool {
        quietModeEnabled && narration.priority < .target && narration.contentKind != .system
    }

    @MainActor
    func pauseVisionNarration() {
        visionQueuePaused = true
        if activeVisionItem != nil, synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }

    @MainActor
    func resumeVisionNarration() {
        visionQueuePaused = false
        if activeVisionItem != nil, synthesizer.isPaused {
            synthesizer.continueSpeaking()
        } else {
            speakNextVisionItemIfPossible()
        }
    }

    @MainActor
    func cancelVisionNarrationSession(_ sessionID: UUID) {
        visionQueue.cancelSession(sessionID)
        guard activeVisionItem?.sessionID == sessionID else { return }
        activeVisionItem = nil
        activeVisionUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSessionIfIdle()
    }

    @MainActor
    var lastCompletedVisionNarrationText: String? {
        visionQueue.lastCompletedText
    }

    func speak(_ text: String, notifyState: Bool = true) {
        guard isEnabled else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        activeVisionItem = nil
        activeVisionUtterance = nil
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = makeUtterance(text, profile: profile)
        suppressNextCallbacks = !notifyState
        activateAudioSession()
        synthesizer.speak(utterance)
    }

    func stop() {
        visionQueue.cancelAll()
        activeVisionItem = nil
        activeVisionUtterance = nil
        visionQueuePaused = false
        synthesizer.stopSpeaking(at: .immediate)
        deactivateAudioSessionIfIdle()
    }

    func testPhrase() -> String {
        let configuration = resolvedConfiguration(for: profile)
        let fallback = configuration.usedFallbackVoice ? " A fallback system voice is active." : ""
        return "\(profile.displayName) voice. JARVIS voice output is ready.\(fallback)"
    }

    func previewAllProfiles() {
        guard isEnabled else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let current = profile
        for previewProfile in JarvisVoiceProfile.ordered {
            let utterance = makeUtterance("\(previewProfile.displayName). JARVIS is ready.", profile: previewProfile)
            utterance.postUtteranceDelay = 0.16
            synthesizer.speak(utterance)
        }
        profile = current
    }

    @discardableResult
    func selectProfile(_ newProfile: JarvisVoiceProfile) -> JarvisResolvedVoiceConfiguration {
        profile = newProfile
        return resolvedConfiguration(for: newProfile)
    }

    @discardableResult
    func adjustSpeechRate(by delta: Float) -> Float {
        speechRate = speechRate + delta
        return speechRate
    }

    @discardableResult
    func selectNextProfile() -> JarvisResolvedVoiceConfiguration {
        let profiles = JarvisVoiceProfile.ordered
        let current = profiles.firstIndex(of: profile) ?? 0
        return selectProfile(profiles[(current + 1) % profiles.count])
    }

    func resetSpeechTuningToProfileDefaults() {
        UserDefaults.standard.removeObject(forKey: rateKey)
        UserDefaults.standard.removeObject(forKey: pitchKey)
        UserDefaults.standard.removeObject(forKey: volumeKey)
    }

    func resolvedConfiguration(for voiceProfile: JarvisVoiceProfile) -> JarvisResolvedVoiceConfiguration {
        let selection = resolvedVoice(for: voiceProfile)
        return JarvisResolvedVoiceConfiguration(
            profile: voiceProfile,
            voiceIdentifier: selection.voice?.identifier,
            voiceName: selection.voice?.name ?? "System English",
            locale: selection.voice?.language ?? voiceProfile.descriptor.languages.first ?? "en-US",
            rate: speechRate(for: voiceProfile),
            pitch: pitch(for: voiceProfile),
            volume: volume(for: voiceProfile),
            usedFallbackVoice: selection.usedFallback
        )
    }

    func personalVoiceStatusText(completion: @escaping (String) -> Void) {
        guard #available(iOS 17.0, *) else {
            completion("Personal Voice requires iOS 17 or later.")
            return
        }

        func describe(_ status: AVSpeechSynthesizer.PersonalVoiceAuthorizationStatus) -> String {
            switch status {
            case .authorized:
                let count = personalVoices().count
                return count > 0
                    ? "Personal Voice authorized. Available personal voices: \(count)."
                    : "Personal Voice authorized, but no personal voice is currently available to JARVIS."
            case .denied:
                return "Personal Voice access denied. Enable it in iOS Settings, Accessibility, Personal Voice."
            case .notDetermined:
                return "Personal Voice permission has not been decided."
            case .unsupported:
                return "Personal Voice is unsupported on this device or configuration."
            @unknown default:
                return "Personal Voice status is unknown."
            }
        }

        let current = AVSpeechSynthesizer.personalVoiceAuthorizationStatus
        if current == .notDetermined {
            AVSpeechSynthesizer.requestPersonalVoiceAuthorization { updated in
                DispatchQueue.main.async {
                    completion(describe(updated))
                }
            }
        } else {
            completion(describe(current))
        }
    }

    private func makeUtterance(_ text: String, profile utteranceProfile: JarvisVoiceProfile) -> AVSpeechUtterance {
        let configuration = resolvedConfiguration(for: utteranceProfile)
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = configuration.rate
        utterance.pitchMultiplier = configuration.pitch
        utterance.volume = configuration.volume
        if let identifier = configuration.voiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: configuration.locale)
        }
        utterance.prefersAssistiveTechnologySettings = UIAccessibility.isVoiceOverRunning
        return utterance
    }

    private func speechRate(for utteranceProfile: JarvisVoiceProfile) -> Float {
        if UserDefaults.standard.object(forKey: rateKey) != nil {
            return min(max(UserDefaults.standard.float(forKey: rateKey), 0.35), 0.58)
        }
        return utteranceProfile.descriptor.rate
    }

    private func pitch(for utteranceProfile: JarvisVoiceProfile) -> Float {
        if UserDefaults.standard.object(forKey: pitchKey) != nil {
            return min(max(UserDefaults.standard.float(forKey: pitchKey), 0.85), 1.10)
        }
        return utteranceProfile.descriptor.pitch
    }

    private func volume(for utteranceProfile: JarvisVoiceProfile) -> Float {
        if UserDefaults.standard.object(forKey: volumeKey) != nil {
            return min(max(UserDefaults.standard.float(forKey: volumeKey), 0.4), 1.0)
        }
        return utteranceProfile.descriptor.volume
    }

    private func resolvedVoice(for voiceProfile: JarvisVoiceProfile) -> (voice: AVSpeechSynthesisVoice?, usedFallback: Bool) {
        if prefersPersonalVoice, let personal = personalVoices().first {
            return (personal, false)
        }
        let voices = AVSpeechSynthesisVoice.speechVoices().sorted { lhs, rhs in
            if lhs.quality != rhs.quality { return lhs.quality.rawValue > rhs.quality.rawValue }
            return lhs.identifier < rhs.identifier
        }
        let descriptor = voiceProfile.descriptor
        for language in descriptor.languages {
            let candidates = voices.filter { $0.language == language }
            if !candidates.isEmpty {
                return (candidates[descriptor.voiceSlot % candidates.count], false)
            }
        }
        let english = voices.filter { $0.language.hasPrefix("en") }
        if !english.isEmpty {
            return (english[descriptor.voiceSlot % english.count], true)
        }
        return (AVSpeechSynthesisVoice(language: descriptor.languages.first ?? "en-US"), true)
    }

    private func personalVoices() -> [AVSpeechSynthesisVoice] {
        guard #available(iOS 17.0, *) else { return [] }
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.voiceTraits.contains(.isPersonalVoice)
        }
    }

    private func speakNextVisionItemIfPossible() {
        guard isEnabled, !visionQueuePaused else { return }
        guard activeVisionItem == nil else { return }
        guard !synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        guard let item = visionQueue.next() else {
            deactivateAudioSessionIfIdle()
            return
        }

        let utterance = makeUtterance(item.narration.text, profile: profile)
        activeVisionItem = item
        activeVisionUtterance = utterance
        let delay = max(0, Date().timeIntervalSince(item.narration.createdAt))
        VisionDiagnosticsStore.shared.recordNarrationDelay(delay)
        activateAudioSession()
        synthesizer.speak(utterance)
    }

    private func activateAudioSession() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(
                .playback,
                mode: .spokenAudio,
                options: [.duckOthers, .interruptSpokenAudioAndMixWithOthers, .allowBluetoothA2DP]
            )
            try audioSession.setActive(true)
        } catch {
            // AVSpeechSynthesizer can still use the system route when explicit session
            // activation is unavailable, so this remains a recoverable degradation.
        }
    }

    private func deactivateAudioSessionIfIdle() {
        guard activeVisionItem == nil, !synthesizer.isSpeaking, !synthesizer.isPaused else { return }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let rawType = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: rawType) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            switch type {
            case .began:
                self.visionWasPausedByAudioInterruption = self.activeVisionItem != nil
                if self.visionWasPausedByAudioInterruption {
                    self.visionQueuePaused = true
                    self.synthesizer.pauseSpeaking(at: .word)
                }
            case .ended:
                let rawOptions = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt ?? 0
                let shouldResume = AVAudioSession.InterruptionOptions(rawValue: rawOptions).contains(.shouldResume)
                if self.visionWasPausedByAudioInterruption {
                    self.visionWasPausedByAudioInterruption = false
                    self.visionQueuePaused = false
                    if shouldResume, self.synthesizer.isPaused {
                        self.activateAudioSession()
                        self.synthesizer.continueSpeaking()
                    } else if shouldResume {
                        self.speakNextVisionItemIfPossible()
                    }
                }
            @unknown default:
                break
            }
        }
    }

    @objc private func handleAudioRouteChange(_ notification: Notification) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.activeVisionItem != nil else { return }
            self.activateAudioSession()
            if !self.visionQueuePaused {
                self.speakNextVisionItemIfPossible()
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard !suppressNextCallbacks else { return }
        onSpeechStart?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if activeVisionUtterance === utterance, let completed = activeVisionItem {
            visionQueue.markCompleted(completed)
            activeVisionItem = nil
            activeVisionUtterance = nil
            speakNextVisionItemIfPossible()
            if activeVisionItem == nil {
                onSpeechFinish?()
                deactivateAudioSessionIfIdle()
            }
            return
        }
        if suppressNextCallbacks {
            suppressNextCallbacks = false
            deactivateAudioSessionIfIdle()
            return
        }
        onSpeechFinish?()
        speakNextVisionItemIfPossible()
        deactivateAudioSessionIfIdle()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if activeVisionUtterance === utterance {
            activeVisionItem = nil
            activeVisionUtterance = nil
            speakNextVisionItemIfPossible()
            if activeVisionItem == nil {
                onSpeechFinish?()
                deactivateAudioSessionIfIdle()
            }
            return
        }
        if suppressNextCallbacks {
            suppressNextCallbacks = false
            deactivateAudioSessionIfIdle()
            return
        }
        onSpeechFinish?()
        speakNextVisionItemIfPossible()
        deactivateAudioSessionIfIdle()
    }
}
