import Foundation
import UIKit

extension Notification.Name {
    static let jarvisDeepLinkReceived = Notification.Name("JarvisDeepLinkReceived")
}

enum JarvisDeepLinkAction {
    case command(String)
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
        let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let route = host.isEmpty ? path : host

        switch route {
        case "command":
            let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            let text = components?.queryItems?.first(where: { $0.name == "text" })?.value ?? ""
            return text.isEmpty ? .unknown(url.absoluteString) : .command(text)
        case "inspect":
            return .inspect
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
}

enum JarvisPendingIntentStore {
    private static let commandKey = "JarvisXR.pendingCommand"
    private static let routeKey = "JarvisXR.pendingRoute"

    static func save(command: String) {
        UserDefaults.standard.set(command, forKey: commandKey)
    }

    static func save(route: String) {
        UserDefaults.standard.set(route, forKey: routeKey)
    }

    static func consumeAction() -> JarvisDeepLinkAction? {
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
