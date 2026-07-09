import Foundation

struct ControlMeshRoute {
    let intent: String
    let capabilityRoute: JarvisCapabilityRoute
    let action: JarvisPlannedAction
    let spokenText: String
    let displayText: String
    let routeLabel: String
    let confidence: Double
    let requiresUserAction: Bool
    let data: [String: String]
}

final class JarvisControlMeshPlanner {
    func route(for command: String) -> ControlMeshRoute? {
        let routes: [String: ControlMeshRoute] = [
            "control mesh": guide(),
            "use control mesh": guide(),
            "open control mesh": guide(),
            "show grid": voice("grid", "Use Voice Control.", "Say: Show Grid."),
            "tap": voice("tap", "Use Voice Control grid.", "Say: Show Grid, then Tap the target number."),
            "tap that": voice("tap", "Use Voice Control grid.", "Say: Show Grid, then Tap the target number."),
            "show me how to tap that": voice("tap", "Use Voice Control grid.", "Say: Show Grid, then Tap the target number."),
            "scroll down": voice("scroll", "Use Voice Control.", "Say: Scroll Down."),
            "scroll this page": voice("scroll", "Use Voice Control.", "Say: Scroll Down."),
            "scroll up": voice("scroll", "Use Voice Control.", "Say: Scroll Up."),
            "go home": voice("home", "Use Voice Control.", "Say: Go Home."),
            "take screenshot": voice("screenshot", "Use Voice Control.", "Say: Take Screenshot."),
            "take a screenshot": voice("screenshot", "Use Voice Control.", "Say: Take Screenshot."),
            "return to jarvis": shortcut("return", "Return to JARVIS.", "Use the JARVIS Return Shortcut or open jarvis://standby.", ["url_scheme": "jarvis://standby"]),
            "come back to jarvis": shortcut("return", "Return to JARVIS.", "Use the JARVIS Return Shortcut or open jarvis://standby.", ["url_scheme": "jarvis://standby"]),
            "go back to jarvis": shortcut("return", "Return to JARVIS.", "Use the JARVIS Return Shortcut or open jarvis://standby.", ["url_scheme": "jarvis://standby"]),
            "open youtube": app("youtube", "Opening YouTube.", "Opening YouTube.", "youtube://"),
            "open safari": app("safari", "Opening Safari.", "Opening Safari.", "https://www.google.com"),
            "open spotify": app("spotify", "Opening Spotify.", "Opening Spotify.", "spotify://"),
            "make the screen darker": shortcut("brightness", "Use the JARVIS Dim Shortcut.", "Run the JARVIS Dim Shortcut, or say Turn Brightness Down with Voice Control.", [:]),
            "turn on night mode": shortcut("night", "Use the JARVIS Night Shortcut.", "Run the JARVIS Night Shortcut for brightness, Focus, or appearance.", [:]),
            "night mode": shortcut("night", "Use the JARVIS Night Shortcut.", "Run the JARVIS Night Shortcut for brightness, Focus, or appearance.", [:])
        ]
        return routes[command]
    }

    private func guide() -> ControlMeshRoute {
        ControlMeshRoute(
            intent: "control mesh",
            capabilityRoute: .controlMeshGuide,
            action: .openControlMesh,
            spokenText: "Control Mesh ready.",
            displayText: "Control Mesh ready.",
            routeLabel: "Official iOS control layers",
            confidence: 0.95,
            requiresUserAction: true,
            data: ["action": "control_mesh"]
        )
    }

    private func voice(_ intent: String, _ spoken: String, _ display: String) -> ControlMeshRoute {
        ControlMeshRoute(
            intent: intent,
            capabilityRoute: .voiceControlRoute,
            action: .guideVoiceControl,
            spokenText: spoken,
            displayText: display,
            routeLabel: "Voice Control",
            confidence: 0.92,
            requiresUserAction: true,
            data: ["control_mesh": "voice_control"]
        )
    }

    private func shortcut(_ intent: String, _ spoken: String, _ display: String, _ data: [String: String]) -> ControlMeshRoute {
        ControlMeshRoute(
            intent: intent,
            capabilityRoute: .shortcutRoute,
            action: .guideShortcut,
            spokenText: spoken,
            displayText: display,
            routeLabel: "Shortcuts",
            confidence: 0.86,
            requiresUserAction: true,
            data: data
        )
    }

    private func app(_ intent: String, _ spoken: String, _ display: String, _ url: String) -> ControlMeshRoute {
        ControlMeshRoute(
            intent: intent,
            capabilityRoute: .appOpenURL,
            action: .openURL,
            spokenText: spoken,
            displayText: display,
            routeLabel: "Public URL route",
            confidence: 0.82,
            requiresUserAction: false,
            data: ["url_scheme": url]
        )
    }
}
