import AVFoundation
import Foundation
import Speech

enum JarvisVoiceInputState {
    case standby
    case listening
    case heardYou(String)
    case processing
    case noSpeech
    case unavailable(String)
}

final class JarvisVoiceInputService {
    static let shared = JarvisVoiceInputService()

    var onStateChange: ((JarvisVoiceInputState) -> Void)?
    var onPartialTranscript: ((String) -> Void)?
    var onFinalTranscript: ((String) -> Void)?

    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private let audioEngine = AVAudioEngine()
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var lastTranscript = ""
    private var listenStartedAt: Date?
    private var silenceTimer: Timer?
    private var maxListenTimer: Timer?
    private var noSpeechTimer: Timer?
    private var finishing = false

    private let minimumListenDuration: TimeInterval = 0.8
    private let silenceAfterSpeech: TimeInterval = 1.2
    private let maximumListenDuration: TimeInterval = 8.0
    private let noSpeechTimeout: TimeInterval = 4.0

    var isListening: Bool {
        audioEngine.isRunning
    }

    var currentTranscript: String {
        lastTranscript
    }

    private init() {}

    func toggleListening() {
        isListening ? stopListening(process: true) : startListening()
    }

    func startListening() {
        guard !audioEngine.isRunning else { return }
        guard let recognizer, recognizer.isAvailable else {
            onStateChange?(.unavailable("Speech recognition is unavailable on this device right now."))
            return
        }

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                switch status {
                case .authorized:
                    self.beginAudioRecognition(with: recognizer)
                case .denied:
                    self.onStateChange?(.unavailable("Speech recognition is denied. Enable it in iOS Settings."))
                case .restricted:
                    self.onStateChange?(.unavailable("Speech recognition is restricted on this device."))
                case .notDetermined:
                    self.onStateChange?(.unavailable("Speech recognition permission has not been granted."))
                @unknown default:
                    self.onStateChange?(.unavailable("Speech recognition permission is unavailable."))
                }
            }
        }
    }

    func stopListening(process: Bool = true) {
        guard audioEngine.isRunning else { return }
        finishRecognition(process: process)
    }

    func cancel() {
        clearTimers()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
        lastTranscript = ""
        finishing = false
        onStateChange?(.standby)
    }

    private func beginAudioRecognition(with recognizer: SFSpeechRecognizer) {
        clearTimers()
        task?.cancel()
        task = nil
        lastTranscript = ""
        finishing = false
        listenStartedAt = Date()

        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            onStateChange?(.unavailable("Microphone session could not start."))
            return
        }

        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        if #available(iOS 13.0, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        request = recognitionRequest

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            onStateChange?(.unavailable("Microphone could not start."))
            return
        }

        onStateChange?(.listening)
        startEndpointTimers()

        task = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else { return }
            if let result {
                self.lastTranscript = result.bestTranscription.formattedString
                DispatchQueue.main.async {
                    self.onPartialTranscript?(self.lastTranscript)
                    if !self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        self.scheduleSilenceEndpoint()
                    }
                }
                if result.isFinal {
                    self.finishRecognition(process: true)
                }
            }
            if error != nil {
                self.finishRecognition(process: true)
            }
        }
    }

    private func finishRecognition(process: Bool) {
        guard !finishing else { return }
        finishing = true
        clearTimers()
        let final = lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.audioEngine.stop()
            self.audioEngine.inputNode.removeTap(onBus: 0)
            self.request = nil
            self.task = nil
            if !process {
                self.lastTranscript = ""
                self.onStateChange?(.standby)
            } else if final.isEmpty {
                self.onStateChange?(.noSpeech)
            } else {
                self.onStateChange?(.heardYou(final))
                self.onStateChange?(.processing)
                self.onFinalTranscript?(final)
            }
            self.finishing = false
        }
    }

    private func startEndpointTimers() {
        noSpeechTimer = Timer.scheduledTimer(withTimeInterval: noSpeechTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            if self.lastTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                self.finishRecognition(process: true)
            }
        }
        maxListenTimer = Timer.scheduledTimer(withTimeInterval: maximumListenDuration, repeats: false) { [weak self] _ in
            self?.finishRecognition(process: true)
        }
    }

    private func scheduleSilenceEndpoint() {
        silenceTimer?.invalidate()
        silenceTimer = Timer.scheduledTimer(withTimeInterval: silenceAfterSpeech, repeats: false) { [weak self] _ in
            guard let self else { return }
            let elapsed = Date().timeIntervalSince(self.listenStartedAt ?? Date())
            if elapsed < self.minimumListenDuration {
                self.scheduleSilenceEndpoint()
            } else {
                self.finishRecognition(process: true)
            }
        }
    }

    private func clearTimers() {
        silenceTimer?.invalidate()
        maxListenTimer?.invalidate()
        noSpeechTimer?.invalidate()
        silenceTimer = nil
        maxListenTimer = nil
        noSpeechTimer = nil
    }
}
