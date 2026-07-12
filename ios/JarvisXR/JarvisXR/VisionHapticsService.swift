import CoreHaptics
import Foundation
import UIKit

enum VisionHapticsBackendKind: String, Codable, CaseIterable, Sendable {
    case coreHaptics
    case uikitFallback
    case unavailable
}

enum VisionHapticCue: String, Codable, CaseIterable, Sendable {
    case directionLeft
    case directionCenter
    case directionRight
    case targetAcquired
    case targetLost
    case warning
    case success

    var accessibilityLabel: String {
        switch self {
        case .directionLeft: return "Direction left"
        case .directionCenter: return "Direction center"
        case .directionRight: return "Direction right"
        case .targetAcquired: return "Target acquired"
        case .targetLost: return "Target lost"
        case .warning: return "Vision warning"
        case .success: return "Action complete"
        }
    }

    var pulses: [VisionHapticPulse] {
        switch self {
        case .directionLeft:
            return [
                VisionHapticPulse(time: 0.00, intensity: 0.95, sharpness: 0.70),
                VisionHapticPulse(time: 0.11, intensity: 0.40, sharpness: 0.35),
            ]
        case .directionCenter:
            return [VisionHapticPulse(time: 0.00, intensity: 0.74, sharpness: 0.52)]
        case .directionRight:
            return [
                VisionHapticPulse(time: 0.00, intensity: 0.40, sharpness: 0.35),
                VisionHapticPulse(time: 0.11, intensity: 0.95, sharpness: 0.70),
            ]
        case .targetAcquired:
            return [
                VisionHapticPulse(time: 0.00, intensity: 0.62, sharpness: 0.45),
                VisionHapticPulse(time: 0.10, intensity: 0.92, sharpness: 0.78),
            ]
        case .targetLost:
            return [
                VisionHapticPulse(time: 0.00, intensity: 0.72, sharpness: 0.65),
                VisionHapticPulse(time: 0.14, intensity: 0.38, sharpness: 0.25),
            ]
        case .warning:
            return [
                VisionHapticPulse(time: 0.00, intensity: 1.00, sharpness: 0.92),
                VisionHapticPulse(time: 0.10, intensity: 0.82, sharpness: 0.82),
                VisionHapticPulse(time: 0.20, intensity: 1.00, sharpness: 0.92),
            ]
        case .success:
            return [
                VisionHapticPulse(time: 0.00, intensity: 0.44, sharpness: 0.30),
                VisionHapticPulse(time: 0.12, intensity: 0.72, sharpness: 0.46),
            ]
        }
    }
}

struct VisionHapticPulse: Equatable, Sendable {
    let time: TimeInterval
    let intensity: Float
    let sharpness: Float
}

/// Session-scoped haptics for live vision guidance. A caller must begin a session and
/// pass the returned token for every cue, which prevents stale analysis callbacks from
/// producing feedback after the camera has stopped or changed mode.
@MainActor
final class VisionHapticsService {
    static let shared = VisionHapticsService()

    private var engine: CHHapticEngine?
    private var activeSessionID: UUID?
    private var lastPlayedAt: Date?
    private let minimumCueInterval: TimeInterval = 0.09

    private(set) var backend: VisionHapticsBackendKind = .unavailable

    init() {
        configureBackend()
    }

    @discardableResult
    func beginSession() -> UUID {
        let identifier = UUID()
        activeSessionID = identifier
        lastPlayedAt = nil
        startEngineIfNeeded()
        return identifier
    }

    func play(
        _ cue: VisionHapticCue,
        intensity: VisionHapticIntensity = .standard,
        sessionID: UUID,
        at date: Date = Date()
    ) {
        guard activeSessionID == sessionID else { return }
        if let lastPlayedAt,
           date.timeIntervalSince(lastPlayedAt) < minimumCueInterval,
           cue != .warning {
            return
        }
        self.lastPlayedAt = date

        switch backend {
        case .coreHaptics:
            playCoreHaptics(cue, scale: intensity.scale)
        case .uikitFallback:
            playUIKitFallback(cue, scale: intensity.scale)
        case .unavailable:
            break
        }
    }

    func endSession(_ sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        lastPlayedAt = nil
        engine?.stop()
    }

    func stopAll() {
        activeSessionID = nil
        lastPlayedAt = nil
        engine?.stop()
    }

    private func configureBackend() {
        if CHHapticEngine.capabilitiesForHardware().supportsHaptics {
            do {
                let engine = try CHHapticEngine()
                engine.playsHapticsOnly = true
                engine.isAutoShutdownEnabled = true
                engine.resetHandler = { [weak self] in
                    Task { @MainActor [weak self] in
                        self?.startEngineIfNeeded()
                    }
                }
                self.engine = engine
                backend = .coreHaptics
            } catch {
                engine = nil
                backend = .uikitFallback
            }
        } else if UIDevice.current.userInterfaceIdiom == .phone {
            backend = .uikitFallback
        } else {
            backend = .unavailable
        }
        VisionDiagnosticsStore.shared.setHapticsAvailability(
            backend != .unavailable,
            backend: backend
        )
    }

    private func startEngineIfNeeded() {
        guard backend == .coreHaptics else { return }
        do {
            try engine?.start()
        } catch {
            backend = .uikitFallback
            VisionDiagnosticsStore.shared.setHapticsAvailability(true, backend: backend)
        }
    }

    private func playCoreHaptics(_ cue: VisionHapticCue, scale: Float) {
        guard let engine else { return }
        let events = cue.pulses.map { pulse in
            CHHapticEvent(
                eventType: .hapticTransient,
                parameters: [
                    CHHapticEventParameter(
                        parameterID: .hapticIntensity,
                        value: min(max(pulse.intensity * scale, 0), 1)
                    ),
                    CHHapticEventParameter(
                        parameterID: .hapticSharpness,
                        value: pulse.sharpness
                    ),
                ],
                relativeTime: pulse.time
            )
        }
        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)
        } catch {
            backend = .uikitFallback
            VisionDiagnosticsStore.shared.setHapticsAvailability(true, backend: backend)
            playUIKitFallback(cue, scale: scale)
        }
    }

    private func playUIKitFallback(_ cue: VisionHapticCue, scale: Float) {
        switch cue {
        case .warning, .targetLost:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.warning)
        case .success, .targetAcquired:
            let generator = UINotificationFeedbackGenerator()
            generator.prepare()
            generator.notificationOccurred(.success)
        case .directionLeft, .directionCenter, .directionRight:
            let style: UIImpactFeedbackGenerator.FeedbackStyle = scale >= 0.85 ? .heavy : (scale >= 0.6 ? .medium : .light)
            let generator = UIImpactFeedbackGenerator(style: style)
            generator.prepare()
            generator.impactOccurred(intensity: CGFloat(scale))
        }
    }
}
