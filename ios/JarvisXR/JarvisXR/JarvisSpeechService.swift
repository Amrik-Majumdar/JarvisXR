import AVFoundation

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
}

final class JarvisSpeechService: NSObject, AVSpeechSynthesizerDelegate {
    static let shared = JarvisSpeechService()

    private let synthesizer = AVSpeechSynthesizer()
    private let enabledKey = "JarvisXR.speechEnabled"
    private let rateKey = "JarvisXR.speechRate"
    private let pitchKey = "JarvisXR.speechPitch"
    private let volumeKey = "JarvisXR.speechVolume"
    private let profileKey = "JarvisXR.voiceProfile"
    private let personalVoiceKey = "JarvisXR.preferPersonalVoice"
    private var suppressNextCallbacks = false
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
            switch profile {
            case .natural: return 0.46
            case .friendly: return 0.47
            case .formal: return 0.42
            case .crisp: return 0.51
            case .quiet: return 0.38
            }
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.35), 0.55), forKey: rateKey)
        }
    }

    var pitch: Float {
        get {
            switch profile {
            case .natural: return 1.03
            case .friendly: return 1.05
            case .formal: return 0.98
            case .crisp: return 1.04
            case .quiet: return 0.98
            }
        }
        set {
            UserDefaults.standard.set(min(max(newValue, 0.85), 1.08), forKey: pitchKey)
        }
    }

    var volume: Float {
        get {
            if profile == .quiet {
                return 0.58
            }
            let stored = UserDefaults.standard.float(forKey: volumeKey)
            return stored > 0 ? stored : 0.88
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
    }

    func speak(_ text: String, notifyState: Bool = true) {
        guard isEnabled else { return }
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = makeUtterance(text, profile: profile)
        suppressNextCallbacks = !notifyState
        synthesizer.speak(utterance)
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    func testPhrase() -> String {
        "JARVIS voice output is ready."
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
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = speechRate(for: utteranceProfile)
        utterance.pitchMultiplier = pitch(for: utteranceProfile)
        utterance.volume = volume(for: utteranceProfile)
        if let voice = preferredVoice(for: utteranceProfile) {
            utterance.voice = voice
        }
        return utterance
    }

    private func speechRate(for utteranceProfile: JarvisVoiceProfile) -> Float {
        switch utteranceProfile {
        case .natural: return 0.46
        case .friendly: return 0.47
        case .formal: return 0.42
        case .crisp: return 0.51
        case .quiet: return 0.38
        }
    }

    private func pitch(for utteranceProfile: JarvisVoiceProfile) -> Float {
        switch utteranceProfile {
        case .natural: return 1.03
        case .friendly: return 1.05
        case .formal: return 0.98
        case .crisp: return 1.04
        case .quiet: return 0.98
        }
    }

    private func volume(for utteranceProfile: JarvisVoiceProfile) -> Float {
        if utteranceProfile == .quiet {
            return 0.58
        }
        let stored = UserDefaults.standard.float(forKey: volumeKey)
        return stored > 0 ? stored : 0.88
    }

    private func preferredVoice() -> AVSpeechSynthesisVoice? {
        preferredVoice(for: profile)
    }

    private func preferredVoice(for voiceProfile: JarvisVoiceProfile) -> AVSpeechSynthesisVoice? {
        if prefersPersonalVoice, let personal = personalVoices().first {
            return personal
        }
        let voices = AVSpeechSynthesisVoice.speechVoices()
        let preferredLanguages: [String]
        switch voiceProfile {
        case .formal:
            preferredLanguages = ["en-GB", "en-US", "en-AU", "en-IE", "en-ZA"]
        default:
            preferredLanguages = ["en-US", "en-GB", "en-AU", "en-IE", "en-ZA"]
        }
        for language in preferredLanguages {
            if let enhanced = voices.first(where: { $0.language == language && $0.quality == .enhanced }) {
                return enhanced
            }
        }
        for language in preferredLanguages {
            if let voice = voices.first(where: { $0.language == language }) {
                return voice
            }
        }
        return voices.first(where: { $0.language.hasPrefix("en") && $0.quality == .enhanced }) ??
            voices.first(where: { $0.language.hasPrefix("en") }) ??
            AVSpeechSynthesisVoice(language: "en-US")
    }

    private func personalVoices() -> [AVSpeechSynthesisVoice] {
        guard #available(iOS 17.0, *) else { return [] }
        return AVSpeechSynthesisVoice.speechVoices().filter { voice in
            voice.voiceTraits.contains(.isPersonalVoice)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        guard !suppressNextCallbacks else { return }
        onSpeechStart?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        if suppressNextCallbacks {
            suppressNextCallbacks = false
            return
        }
        onSpeechFinish?()
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        if suppressNextCallbacks {
            suppressNextCallbacks = false
            return
        }
        onSpeechFinish?()
    }
}
