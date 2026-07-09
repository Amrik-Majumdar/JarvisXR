import Foundation

enum JarvisCapabilityRoute: String {
    case inAppVision
    case inAppSpeech
    case inAppMemory
    case inAppSettings
    case inAppDiagnostics
    case appOpenURL
    case shortcutRoute
    case voiceControlRoute
    case controlMeshGuide
    case unsupportedRequiresSystemAccess
    case unknown
}

enum JarvisPlannedAction: String {
    case none
    case inspect
    case readText
    case detectObjects
    case openSettings
    case openDiagnostics
    case openControlMesh
    case openURL
    case guideVoiceControl
    case guideShortcut
    case memory
    case speech
}

struct JarvisCommandPlan {
    let normalizedCommand: String
    let intentLabel: String
    let route: JarvisCapabilityRoute
    let action: JarvisPlannedAction
    let displayText: String
    let spokenText: String
    let nextState: JarvisInteractionState
    let routeLabel: String
    let confidence: Double
    let requiresUserAction: Bool
    let data: [String: String]
}

final class JarvisCommandPlanner {
    func plan(_ rawCommand: String) -> JarvisCommandPlan {
        let text = normalize(rawCommand)

        if text.isEmpty || matches(text, ["ready", "jarvis ready"]) {
            return plan(
                text,
                intent: "ready",
                route: .inAppSpeech,
                action: .none,
                display: "JARVIS ready.",
                spoken: "JARVIS ready.",
                state: .ready,
                routeLabel: "In-app voice",
                confidence: 0.99,
                data: ["mode": "ready"]
            )
        }

        if matches(text, ["scan this", "scan this paper", "inspect this", "analyze this", "open camera", "take photo"]) {
            return plan(
                text,
                intent: "vision inspection",
                route: .inAppVision,
                action: .inspect,
                display: "Opening inspection.",
                spoken: "Opening inspection.",
                state: .inspection,
                routeLabel: "Local camera",
                confidence: 0.95,
                data: ["action": "inspect", "planner_route": "vision"]
            )
        }

        if matches(text, ["read this", "read this label", "read what is on screen", "read the screen", "read paper", "what does this say", "summarize this text"]) {
            return plan(
                text,
                intent: "read text",
                route: .inAppVision,
                action: .readText,
                display: "Opening text scan.",
                spoken: "Opening text scan.",
                state: .inspection,
                routeLabel: "Vision OCR",
                confidence: 0.94,
                data: ["action": "inspect", "vision": "ocr", "planner_route": "ocr"]
            )
        }

        if matches(text, ["detect objects", "identify this", "identify this object", "what object is this", "find objects", "look at this", "what am i looking at", "what am i pointing at"]) {
            return plan(
                text,
                intent: "visual classification",
                route: .inAppVision,
                action: .detectObjects,
                display: "Opening visual scan. \(JarvisObjectDetectionModel.statusLine())",
                spoken: "Opening visual scan.",
                state: .inspection,
                routeLabel: JarvisObjectDetectionModel.isReady() ? "Core ML Vision" : "Built-in Vision classification",
                confidence: 0.94,
                data: ["action": "inspect", "vision": "visual_classification", "planner_route": "object_detection"]
            )
        }

        if matches(text, ["listen", "start listening", "stop listening", "stop speaking", "quiet mode", "normal voice", "normal mode", "talk normally", "be quiet"]) {
            return plan(
                text,
                intent: "voice session",
                route: .inAppSpeech,
                action: .speech,
                display: text.contains("quiet") || text == "be quiet" ? "Quiet mode." : "Voice session command.",
                spoken: text.contains("quiet") || text == "be quiet" ? "Quiet mode." : "Voice command ready.",
                state: text.contains("quiet") || text == "be quiet" ? .quiet : .ready,
                routeLabel: "In-app voice",
                confidence: 0.86
            )
        }

        if text.hasPrefix("remember this") || text.hasPrefix("save note") || matches(text, ["show notes", "list notes", "what did i say", "forget this"]) {
            return plan(
                text,
                intent: "memory",
                route: .inAppMemory,
                action: .memory,
                display: "Memory route.",
                spoken: "Memory route.",
                state: .processing,
                routeLabel: "Local memory",
                confidence: 0.84
            )
        }

        if let mesh = JarvisControlMeshPlanner().route(for: text) {
            return plan(
                text,
                intent: mesh.intent,
                route: mesh.capabilityRoute,
                action: mesh.action,
                display: mesh.displayText,
                spoken: mesh.spokenText,
                state: .done,
                routeLabel: mesh.routeLabel,
                confidence: mesh.confidence,
                requiresUserAction: mesh.requiresUserAction,
                data: mesh.data
            )
        }

        if matches(text, ["help", "how do i use this", "what can you do", "tools"]) {
            return plan(
                text,
                intent: "help",
                route: .controlMeshGuide,
                action: .none,
                display: "Help route.",
                spoken: "Help route.",
                state: .done,
                routeLabel: "Help",
                confidence: 0.90
            )
        }

        return plan(
            text,
            intent: "unknown",
            route: .unknown,
            action: .none,
            display: "Try: scan this, read this, detect objects, show grid.",
            spoken: "Command not recognized.",
            state: .attention,
            routeLabel: "No route",
            confidence: 0.20
        )
    }

    func normalize(_ raw: String) -> String {
        var text = raw
            .lowercased()
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "what's", with: "what is")
            .replacingOccurrences(of: "whats", with: "what is")
        text = text.components(separatedBy: CharacterSet(charactersIn: ",.?;!\"")).joined(separator: " ")
        for prefix in ["hey jarvis ", "okay jarvis ", "ok jarvis ", "jarvis "] {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }
        if text.hasPrefix("please ") {
            text = String(text.dropFirst("please ".count))
        }
        return text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.joined(separator: " ")
    }

    private func matches(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains(text)
    }

    private func plan(
        _ text: String,
        intent: String,
        route: JarvisCapabilityRoute,
        action: JarvisPlannedAction,
        display: String,
        spoken: String,
        state: JarvisInteractionState,
        routeLabel: String,
        confidence: Double,
        requiresUserAction: Bool = false,
        data: [String: String] = [:]
    ) -> JarvisCommandPlan {
        JarvisCommandPlan(
            normalizedCommand: text,
            intentLabel: intent,
            route: route,
            action: action,
            displayText: display,
            spokenText: spoken,
            nextState: state,
            routeLabel: routeLabel,
            confidence: confidence,
            requiresUserAction: requiresUserAction,
            data: data
        )
    }
}
