import Foundation
import UIKit

extension Notification.Name {
    static let jarvisDeepLinkReceived = Notification.Name("JarvisDeepLinkReceived")
}

enum JarvisDeepLinkAction {
    case command(String)
    case vision(JarvisVisionLaunchRequest)
    case inspect
    case diagnostics
    case settings
    case standby
    case online
    case controlMesh
    case unknown(String)

    var commandText: String? {
        switch self {
        case .command(let text): return text
        case .vision(let request):
            switch (request.mode, request.command) {
            case (_, .stop): return "stop vision"
            case (.liveGuide, .run): return "start live guide"
            case (.readText, .run): return "read this"
            case (.scanBarcode, .run): return "scan barcode"
            case (.identifyColor, .run): return "what color is this"
            case (.find, .run): return request.target.map { "find \($0)" }
            case (_, .repeatLast): return "repeat that"
            default: return nil
            }
        case .inspect: return "inspect mode"
        case .standby: return "standby"
        case .online: return "status"
        case .controlMesh: return "control mesh"
        default: return nil
        }
    }
}

enum JarvisDeepLinkRouter {
    static func action(from url: URL) -> JarvisDeepLinkAction {
        guard url.scheme?.lowercased() == "jarvis" else {
            return .unknown(url.absoluteString)
        }
        let host = url.host?.lowercased() ?? ""
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        let pathComponents = url.path
            .split(separator: "/")
            .map { $0.lowercased() }

        if host == "vision" {
            return visionAction(path: pathComponents, components: components, raw: url.absoluteString)
        }

        let route = host.isEmpty ? (pathComponents.first ?? "") : host
        switch route {
        case "command":
            let text = queryValue("text", in: components) ?? ""
            return text.isEmpty ? .unknown(url.absoluteString) : .command(text)
        case "inspect":
            return .inspect
        case "describe":
            return .vision(JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "deep_link", startsImmediately: true))
        case "read":
            return .vision(JarvisVisionLaunchRequest(mode: .readText, command: .run, source: "deep_link", startsImmediately: true))
        case "barcode", "scan":
            return .vision(JarvisVisionLaunchRequest(mode: .scanBarcode, command: .run, source: "deep_link", startsImmediately: true))
        case "diagnostics":
            return .diagnostics
        case "settings":
            return .settings
        case "standby":
            return .standby
        case "online":
            return .online
        case "control", "controlmesh", "control-mesh":
            return .controlMesh
        default:
            return .unknown(url.absoluteString)
        }
    }

    static func post(_ action: JarvisDeepLinkAction) {
        NotificationCenter.default.post(name: .jarvisDeepLinkReceived, object: action)
    }

    static func handle(_ url: URL) -> Bool {
        let action = action(from: url)
        if case .unknown = action {
            post(action)
            return false
        }
        post(action)
        return true
    }

    private static func visionAction(
        path: [String],
        components: URLComponents?,
        raw: String
    ) -> JarvisDeepLinkAction {
        guard let route = path.first else {
            return .vision(JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "deep_link"))
        }
        switch route {
        case "describe":
            let region = queryValue("region", in: components).flatMap(SpatialRegion.init(rawValue:))
            return .vision(JarvisVisionLaunchRequest(mode: .describe, command: .run, region: region, source: "deep_link", startsImmediately: true))
        case "live":
            let operation = path.dropFirst().first ?? "start"
            let command: JarvisVisionCommand = operation == "stop" ? .stop : (operation == "pause" ? .pause : (operation == "resume" ? .resume : .run))
            return .vision(JarvisVisionLaunchRequest(mode: .liveGuide, command: command, source: "deep_link", startsImmediately: command == .run))
        case "read":
            return .vision(JarvisVisionLaunchRequest(mode: .readText, command: .run, source: "deep_link", startsImmediately: true))
        case "find":
            guard let target = queryValue("target", in: components)?.trimmingCharacters(in: .whitespacesAndNewlines), !target.isEmpty else {
                return .vision(JarvisVisionLaunchRequest(mode: .find, command: .run, source: "deep_link"))
            }
            return .vision(JarvisVisionLaunchRequest(mode: .find, command: .run, target: target, source: "deep_link", startsImmediately: true))
        case "barcode", "scan":
            return .vision(JarvisVisionLaunchRequest(mode: .scanBarcode, command: .run, source: "deep_link", startsImmediately: true))
        case "color":
            return .vision(JarvisVisionLaunchRequest(mode: .identifyColor, command: .run, source: "deep_link", startsImmediately: true))
        case "repeat":
            return .vision(JarvisVisionLaunchRequest(mode: .describe, command: .repeatLast, source: "deep_link"))
        default:
            return .unknown(raw)
        }
    }

    private static func queryValue(_ name: String, in components: URLComponents?) -> String? {
        components?.queryItems?.first(where: { $0.name.lowercased() == name.lowercased() })?.value
    }
}

enum JarvisPendingIntentStore {
    private static let commandKey = "JarvisXR.pendingCommand"
    private static let routeKey = "JarvisXR.pendingRoute"
    private static let visionRequestKey = "JarvisXR.pendingVisionRequest.v1"

    static func save(command: String) {
        UserDefaults.standard.set(command, forKey: commandKey)
    }

    static func save(route: String) {
        UserDefaults.standard.set(route, forKey: routeKey)
    }

    static func save(visionRequest: JarvisVisionLaunchRequest) {
        if let data = try? JSONEncoder().encode(visionRequest) {
            UserDefaults.standard.set(data, forKey: visionRequestKey)
        }
    }

    static func consumeAction() -> JarvisDeepLinkAction? {
        if let data = UserDefaults.standard.data(forKey: visionRequestKey),
           let request = try? JSONDecoder().decode(JarvisVisionLaunchRequest.self, from: data) {
            UserDefaults.standard.removeObject(forKey: visionRequestKey)
            return .vision(request)
        }
        if let command = UserDefaults.standard.string(forKey: commandKey), !command.isEmpty {
            UserDefaults.standard.removeObject(forKey: commandKey)
            return .command(command)
        }
        if let route = UserDefaults.standard.string(forKey: routeKey), !route.isEmpty {
            UserDefaults.standard.removeObject(forKey: routeKey)
            switch route {
            case "inspect": return .inspect
            case "diagnostics": return .diagnostics
            case "settings": return .settings
            case "standby": return .standby
            case "controlMesh", "controlmesh", "control-mesh": return .controlMesh
            default: return .unknown(route)
            }
        }
        return nil
    }
}
