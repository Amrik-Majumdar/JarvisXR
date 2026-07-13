import Foundation

enum JarvisCapabilityRoute: String {
    case inAppVision
    case inAppSpeech
    case inAppMemory
    case inAppMessage
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
    case liveGuide
    case findObject
    case scanBarcode
    case identifyColor
    case visionControl
    case openSettings
    case openDiagnostics
    case runDeviceAcceptance
    case openControlMesh
    case openURL
    case guideVoiceControl
    case guideShortcut
    case memory
    case speech
    case composeMessage
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
    let visionLaunchRequest: JarvisVisionLaunchRequest?
    let shouldPersistGeneralHistory: Bool
}

final class JarvisCommandPlanner {
    func plan(_ rawCommand: String) -> JarvisCommandPlan {
        let text = normalize(rawCommand)

        if matches(text, ["run the complete device test", "run complete device test", "complete device test", "device acceptance test"]) {
            return plan(
                text,
                intent: "complete device test",
                route: .inAppDiagnostics,
                action: .runDeviceAcceptance,
                display: "Opening the voice-first complete device test.",
                spoken: "Starting the complete device test.",
                state: .processing,
                routeLabel: "On-device acceptance test",
                confidence: 0.99,
                requiresUserAction: false,
                data: ["action": "device_acceptance"],
                shouldPersistGeneralHistory: false
            )
        }

        if let message = JarvisMessageCommandParser.parse(text, raw: rawCommand) {
            var data = [
                "action": "message",
                "message_action": message.action.rawValue,
            ]
            if let recipientHint = message.recipientHint { data["message_recipient_hint"] = recipientHint }
            if let body = message.body { data["message_body"] = body }
            return plan(
                text,
                intent: "message composition",
                route: .inAppMessage,
                action: .composeMessage,
                display: "Preparing an accessible system message draft.",
                spoken: "Preparing a message draft.",
                state: .processing,
                routeLabel: "System message composer",
                confidence: 0.98,
                requiresUserAction: true,
                data: data,
                shouldPersistGeneralHistory: false
            )
        }

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

        if matches(text, ["stop", "stop vision", "stop live guide", "stop guide", "stop searching", "stop reading", "cancel vision"]) {
            return visionPlan(
                text,
                intent: "stop vision",
                action: .visionControl,
                display: "Stopping Vision and speech.",
                spoken: "Stopping Vision.",
                request: JarvisVisionLaunchRequest(mode: .liveGuide, command: .stop, source: "command"),
                confidence: 0.99
            )
        }

        if matches(text, ["pause live guide", "pause guide", "pause guiding", "pause vision", "pause reading"]) {
            let mode: VisionMode = text.contains("reading") ? .readText : .liveGuide
            return visionPlan(
                text,
                intent: "pause vision",
                action: .visionControl,
                display: "Pausing \(mode.visionDisplayName).",
                spoken: "Pausing \(mode.visionDisplayName).",
                request: JarvisVisionLaunchRequest(mode: mode, command: .pause, source: "command"),
                confidence: 0.98
            )
        }

        if matches(text, ["resume live guide", "resume guide", "continue guiding", "resume vision", "resume reading"]) {
            let mode: VisionMode = text.contains("reading") ? .readText : .liveGuide
            return visionPlan(
                text,
                intent: "resume vision",
                action: .visionControl,
                display: "Resuming \(mode.visionDisplayName).",
                spoken: "Resuming \(mode.visionDisplayName).",
                request: JarvisVisionLaunchRequest(mode: mode, command: .resume, source: "command"),
                confidence: 0.98
            )
        }

        if matches(text, ["repeat that", "repeat vision result", "repeat last alert", "repeat last vision result"]) {
            return visionPlan(
                text,
                intent: "repeat vision",
                action: .visionControl,
                display: "Repeating the latest Vision result.",
                spoken: "Repeating the latest Vision result.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .repeatLast, source: "command"),
                confidence: 0.96,
                persistHistory: false
            )
        }

        if matches(text, ["give me more detail", "more detail", "describe more", "tell me more about that"]) {
            return visionPlan(
                text,
                intent: "more vision detail",
                action: .visionControl,
                display: "Expanding the latest grounded Vision result.",
                spoken: "More detail.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .moreDetail, source: "command"),
                confidence: 0.95
            )
        }

        if matches(text, ["describe less", "be concise", "be more concise", "be quieter", "only important changes", "only tell me important changes", "speak only important changes"]) {
            return visionPlan(
                text,
                intent: "concise vision",
                action: .visionControl,
                display: text.contains("important") ? "Live Guide will prioritize important changes." : "Vision descriptions are now concise.",
                spoken: text.contains("important") ? "Only important changes." : "Descriptions are now concise.",
                request: JarvisVisionLaunchRequest(mode: .liveGuide, command: .lessDetail, source: "command"),
                confidence: 0.94
            )
        }

        if matches(text, ["what changed", "what has changed", "where was it last seen"]) {
            return visionPlan(
                text,
                intent: "vision change",
                action: .visionControl,
                display: "Reporting the latest confirmed Vision change.",
                spoken: "Latest confirmed change.",
                request: JarvisVisionLaunchRequest(mode: .liveGuide, command: .whatChanged, source: "command"),
                confidence: 0.95
            )
        }

        if matches(text, ["next line", "read next line", "continue reading"]) {
            return visionPlan(
                text,
                intent: "next reading line",
                action: .visionControl,
                display: "Moving to the next recognized line.",
                spoken: "Next line.",
                request: JarvisVisionLaunchRequest(mode: .readText, command: .nextReadingLine, source: "command"),
                confidence: 0.96,
                persistHistory: false,
                legacyVision: "ocr"
            )
        }

        if matches(text, ["previous line", "read previous line", "go back one line"]) {
            return visionPlan(
                text,
                intent: "previous reading line",
                action: .visionControl,
                display: "Moving to the previous recognized line.",
                spoken: "Previous line.",
                request: JarvisVisionLaunchRequest(mode: .readText, command: .previousReadingLine, source: "command"),
                confidence: 0.96,
                persistHistory: false,
                legacyVision: "ocr"
            )
        }

        if matches(text, ["start live guide", "start live guidance", "start guiding me", "guide me", "live guide", "guide me live"]) {
            return visionPlan(
                text,
                intent: "live guide",
                action: .liveGuide,
                display: "Opening foreground Live Guide.",
                spoken: "Starting Live Guide.",
                request: JarvisVisionLaunchRequest(mode: .liveGuide, command: .run, source: "command", startsImmediately: true),
                confidence: 0.98
            )
        }

        if matches(text, ["scan barcode", "scan this barcode", "scan this code", "scan product code", "read barcode", "read this code", "what is this code", "barcode"]) {
            return visionPlan(
                text,
                intent: "scan barcode",
                action: .scanBarcode,
                display: "Opening barcode scan. Detected links will not open automatically.",
                spoken: "Opening barcode scan.",
                request: JarvisVisionLaunchRequest(mode: .scanBarcode, command: .run, source: "command", startsImmediately: true),
                confidence: 0.98,
                persistHistory: false,
                legacyVision: "barcode"
            )
        }

        if matches(text, ["read this", "read this label", "read the sign", "read the sign in front of me", "read this sign", "read what is on screen", "read the screen", "read paper", "what does this say", "summarize this text"]) {
            return visionPlan(
                text,
                intent: "read text",
                action: .readText,
                display: "Opening on-device text reading.",
                spoken: "Opening Read Text.",
                request: JarvisVisionLaunchRequest(mode: .readText, command: .run, source: "command", startsImmediately: true),
                confidence: 0.98,
                persistHistory: false,
                legacyVision: "ocr"
            )
        }

        if matches(text, ["what color is this", "identify this color", "identify color", "what colour is this", "color"] ) {
            return visionPlan(
                text,
                intent: "identify color",
                action: .identifyColor,
                display: "Opening approximate on-device color identification.",
                spoken: "Opening color identification.",
                request: JarvisVisionLaunchRequest(mode: .identifyColor, command: .run, source: "command", startsImmediately: true),
                confidence: 0.96,
                legacyVision: "color"
            )
        }

        if matches(text, ["is the camera blocked", "camera quality", "check camera quality", "is it too dark", "is the image blurry"]) {
            return visionPlan(
                text,
                intent: "camera quality",
                action: .visionControl,
                display: "Checking camera quality on device.",
                spoken: "Checking camera quality.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .checkQuality, source: "command", startsImmediately: true),
                confidence: 0.96,
                legacyVision: "quality"
            )
        }

        if matches(text, ["flashlight on", "turn on flashlight", "turn on the flashlight", "light on"]) {
            return visionPlan(
                text,
                intent: "flashlight on",
                action: .visionControl,
                display: "Opening Vision and turning on the flashlight.",
                spoken: "Turning on the flashlight.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .flashlightOn, source: "command", startsImmediately: true),
                confidence: 0.98,
                legacyVision: "flashlight"
            )
        }

        if matches(text, ["flashlight off", "turn off flashlight", "turn off the flashlight", "light off"]) {
            return visionPlan(
                text,
                intent: "flashlight off",
                action: .visionControl,
                display: "Turning off the Vision flashlight.",
                spoken: "Turning off the flashlight.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .flashlightOff, source: "command"),
                confidence: 0.98,
                legacyVision: "flashlight"
            )
        }

        if matches(text, ["is the flashlight on", "flashlight status", "is the light on"]) {
            return visionPlan(
                text,
                intent: "flashlight status",
                action: .visionControl,
                display: "Checking the Vision flashlight state.",
                spoken: "Checking the flashlight.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .flashlightStatus, source: "command"),
                confidence: 0.98,
                legacyVision: "flashlight"
            )
        }

        if let target = findTarget(in: text) {
            return visionPlan(
                text,
                intent: "find object",
                action: .findObject,
                display: "Opening Find for \(target). Jarvis will verify whether the installed model supports it.",
                spoken: "Finding \(target).",
                request: JarvisVisionLaunchRequest(mode: .find, command: .run, target: target, source: "command", startsImmediately: true),
                confidence: 0.96,
                legacyVision: "find"
            )
        }

        if let region = descriptionRegion(in: text) {
            return visionPlan(
                text,
                intent: "regional scene description",
                action: .detectObjects,
                display: "Opening a \(region.rawValue)-side scene description.",
                spoken: "Describing the \(region.rawValue) side.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .run, region: region, source: "command", startsImmediately: true),
                confidence: 0.97,
                legacyVision: "visual_classification"
            )
        }

        if matches(text, [
            "what is in front of me", "what is ahead", "describe what is in front of me", "describe this room",
            "describe my surroundings", "describe surroundings", "what am i holding", "describe this",
            "what do you see", "detect objects", "identify this", "identify this object",
            "what object is this", "find objects", "look at this", "what am i looking at",
            "what am i pointing at", "scan this", "scan this paper", "inspect this", "analyze this",
            "take photo", "scan paper", "is there a person ahead", "is there a person in front of me",
            "how many people are visible", "how many people do you see"
        ]) {
            return visionPlan(
                text,
                intent: "scene description",
                action: .detectObjects,
                display: "Visual scan ready. Opening an on-device scene description.",
                spoken: "Opening Describe.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "command", startsImmediately: true),
                confidence: 0.97,
                legacyVision: "visual_classification"
            )
        }

        if matches(text, ["open camera", "camera", "open vision", "vision", "inspect mode", "inspect", "inspection mode"]) {
            return visionPlan(
                text,
                intent: "open vision",
                action: .inspect,
                display: "Opening Jarvis Vision.",
                spoken: "Opening Jarvis Vision.",
                request: JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "command", startsImmediately: false),
                confidence: 0.96
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
            display: "Try: describe this, start live guide, find a chair, read this, or scan a barcode.",
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

    private func findTarget(in text: String) -> String? {
        let prefixes = [
            "help me locate the ", "help me locate a ", "help me locate ",
            "find the ", "find a ", "find an ", "find my ", "find ",
            "where is the ", "where is a ", "where is ", "locate the ", "locate "
        ]
        for prefix in prefixes where text.hasPrefix(prefix) {
            let target = String(text.dropFirst(prefix.count)).trimmingCharacters(in: .whitespacesAndNewlines)
            if !target.isEmpty && target != "objects" { return target }
        }
        return nil
    }

    private func descriptionRegion(in text: String) -> SpatialRegion? {
        if matches(text, ["describe left", "describe the left", "describe the left side", "what is on the left"]) { return .left }
        if matches(text, ["describe center", "describe the center", "describe the centre", "what is in the center"]) { return .center }
        if matches(text, ["describe right", "describe the right", "describe the right side", "what is on the right"]) { return .right }
        return nil
    }

    private func matches(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains(text)
    }

    private func visionPlan(
        _ text: String,
        intent: String,
        action: JarvisPlannedAction,
        display: String,
        spoken: String,
        request: JarvisVisionLaunchRequest,
        confidence: Double,
        persistHistory: Bool = true,
        legacyVision: String? = nil
    ) -> JarvisCommandPlan {
        var data = [
            "action": "inspect",
            "vision_mode": request.mode.rawValue,
            "vision_command": request.command.rawValue,
            "planner_route": "vision",
        ]
        if let target = request.target { data["vision_target"] = target }
        if let region = request.region { data["vision_region"] = region.rawValue }
        if let legacyVision { data["vision"] = legacyVision }
        return plan(
            text,
            intent: intent,
            route: .inAppVision,
            action: action,
            display: display,
            spoken: spoken,
            state: .inspection,
            routeLabel: "On-device Vision",
            confidence: confidence,
            data: data,
            visionLaunchRequest: request,
            shouldPersistGeneralHistory: persistHistory
        )
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
        data: [String: String] = [:],
        visionLaunchRequest: JarvisVisionLaunchRequest? = nil,
        shouldPersistGeneralHistory: Bool = true
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
            data: data,
            visionLaunchRequest: visionLaunchRequest,
            shouldPersistGeneralHistory: shouldPersistGeneralHistory
        )
    }
}
