import Foundation

enum JarvisVisionCommand: String, Codable, Equatable, Sendable {
    case run
    case stop
    case pause
    case resume
    case repeatLast
    case moreDetail
    case lessDetail
    case whatChanged
    case nextReadingLine
    case previousReadingLine
    case flashlightOn
    case flashlightOff
    case flashlightStatus
    case checkQuality
}

/// Typed launch information shared by commands, deep links, App Intents, and the
/// native Vision screen. OCR and barcode result payloads never belong here.
struct JarvisVisionLaunchRequest: Codable, Equatable, Sendable {
    var mode: VisionMode
    var command: JarvisVisionCommand
    var target: String?
    var region: SpatialRegion?
    var source: String
    var startsImmediately: Bool

    init(
        mode: VisionMode = .describe,
        command: JarvisVisionCommand = .run,
        target: String? = nil,
        region: SpatialRegion? = nil,
        source: String = "in_app",
        startsImmediately: Bool = false
    ) {
        self.mode = mode
        self.command = command
        self.target = target?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.region = region
        self.source = source
        self.startsImmediately = startsImmediately
    }

    var excludesResultFromGeneralHistory: Bool {
        mode == .readText || mode == .scanBarcode || command == .repeatLast
    }
}

extension VisionMode {
    var visionDisplayName: String {
        switch self {
        case .inactive: return "Vision"
        case .describe: return "Describe"
        case .liveGuide: return "Live"
        case .find: return "Find"
        case .readText: return "Read"
        case .scanBarcode: return "Scan"
        case .identifyColor: return "Color"
        }
    }

    var visionPrimaryActionTitle: String {
        switch self {
        case .inactive, .describe: return "Describe What Is Here"
        case .liveGuide: return "Start Live Guide"
        case .find: return "Choose an Object to Find"
        case .readText: return "Read Visible Text"
        case .scanBarcode: return "Start Barcode Scan"
        case .identifyColor: return "Identify Color"
        }
    }

    var visionReadyGuidance: String {
        switch self {
        case .inactive, .describe:
            return "Point the rear camera toward the area you want described."
        case .liveGuide:
            return "Live Guide announces stable, important changes while Jarvis remains in the foreground."
        case .find:
            return "Name a supported object, then pan the phone slowly."
        case .readText:
            return "Hold printed text steady and fill the camera view."
        case .scanBarcode:
            return "Move the camera slowly across the package or code."
        case .identifyColor:
            return "Fill the center of the camera with the surface to identify."
        }
    }
}

extension Notification.Name {
    static let jarvisVisionPreferencesDidChange = Notification.Name("JarvisVisionPreferencesDidChange")
}

final class VisionPreferencesStore {
    static let shared = VisionPreferencesStore()

    private let key = "JarvisXR.vision.preferences.v1"
    private let defaults: UserDefaults
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private var storedValue: VisionPreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let decoded = try? decoder.decode(VisionPreferences.self, from: data) {
            storedValue = decoded
        } else {
            storedValue = .default
        }
    }

    var value: VisionPreferences {
        lock.lock()
        defer { lock.unlock() }
        return storedValue
    }

    func update(_ mutation: (inout VisionPreferences) -> Void) {
        lock.lock()
        mutation(&storedValue)
        let value = storedValue
        let data = try? encoder.encode(value)
        lock.unlock()
        if let data {
            defaults.set(data, forKey: key)
        }
        NotificationCenter.default.post(name: .jarvisVisionPreferencesDidChange, object: value)
    }

    func reset() {
        lock.lock()
        storedValue = .default
        lock.unlock()
        defaults.removeObject(forKey: key)
        NotificationCenter.default.post(name: .jarvisVisionPreferencesDidChange, object: VisionPreferences.default)
    }
}

final class JarvisVisionFirstRunStore {
    static let shared = JarvisVisionFirstRunStore()

    private let defaults: UserDefaults
    private let completedKey = "JarvisXR.vision.firstRun.completed.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var shouldPresent: Bool {
        !defaults.bool(forKey: completedKey)
    }

    func markCompleted() {
        defaults.set(true, forKey: completedKey)
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
