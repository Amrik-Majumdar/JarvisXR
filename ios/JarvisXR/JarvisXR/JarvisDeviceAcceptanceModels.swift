import Foundation

enum JarvisDeviceAcceptanceStatus: String, Codable, Sendable {
    case passed
    case attention
    case skipped
    case pending
}

enum JarvisDeviceAcceptanceMethod: String, Codable, Sendable {
    case automated
    case userConfirmed
    case unavailable
}

struct JarvisDeviceAcceptanceCheck: Codable, Equatable, Sendable {
    let identifier: String
    let title: String
    let status: JarvisDeviceAcceptanceStatus
    let method: JarvisDeviceAcceptanceMethod
    let measuredValues: [String: String]
    let error: String?
    let recordedAt: Date
}

struct JarvisDeviceAcceptanceReport: Codable, Sendable {
    let schemaVersion: Int
    let startedAt: Date
    var completedAt: Date?
    let appVersion: String
    let build: String
    let iOSVersion: String
    let deviceCapabilitySummary: [String: String]
    var checks: [JarvisDeviceAcceptanceCheck]
    var limitations: [String]
    var overallStatus: JarvisDeviceAcceptanceStatus

    init(
        startedAt: Date = Date(),
        appVersion: String,
        build: String,
        iOSVersion: String,
        deviceCapabilitySummary: [String: String]
    ) {
        self.schemaVersion = 1
        self.startedAt = startedAt
        self.appVersion = appVersion
        self.build = build
        self.iOSVersion = iOSVersion
        self.deviceCapabilitySummary = deviceCapabilitySummary
        checks = []
        limitations = []
        overallStatus = .pending
    }

    mutating func append(_ check: JarvisDeviceAcceptanceCheck) {
        checks.removeAll { $0.identifier == check.identifier }
        checks.append(check)
        if check.status == .attention { overallStatus = .attention }
    }

    mutating func complete() {
        completedAt = Date()
        if overallStatus == .pending {
            overallStatus = checks.contains(where: { $0.status == .attention }) ? .attention : .passed
        }
    }
}

enum JarvisDeviceAcceptanceResponse: Equatable, Sendable {
    case yes
    case no
    case different
    case `repeat`
    case skip
    case stop
    case `continue`
    case unknown

    static func parse(_ normalized: String) -> JarvisDeviceAcceptanceResponse {
        switch normalized.trimmingCharacters(in: .whitespacesAndNewlines) {
        case "yes", "yeah", "yep", "correct", "it is on": return .yes
        case "no", "nope", "not working", "it is off": return .no
        case "different", "they sound different": return .different
        case "repeat", "say that again": return .repeat
        case "skip", "skip this": return .skip
        case "stop", "stop test", "cancel", "cancel test": return .stop
        case "continue", "ready", "done": return .continue
        default: return .unknown
        }
    }
}

enum JarvisDeviceAcceptanceReportStore {
    static func write(_ report: JarvisDeviceAcceptanceReport) throws -> URL {
        let base = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent("JarvisXR/DeviceAcceptanceReports", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: report.startedAt)
            .replacingOccurrences(of: ":", with: "-")
        let url = directory.appendingPathComponent("jarvis-device-acceptance-\(timestamp).json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(report).write(to: url, options: .atomic)
        return url
    }
}
