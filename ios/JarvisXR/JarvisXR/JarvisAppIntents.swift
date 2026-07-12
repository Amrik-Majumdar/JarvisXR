import Foundation

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.0, *)
struct RunJarvisCommandIntent: AppIntent {
    static var title: LocalizedStringResource = "Run JARVIS Command"
    static var description = IntentDescription("Send a command into JARVIS.")
    static var openAppWhenRun = true

    @Parameter(title: "Command")
    var command: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(command: command)
        return .result(dialog: "Command sent to JARVIS.")
    }
}

@available(iOS 16.0, *)
struct StartInspectionIntent: AppIntent {
    static var title: LocalizedStringResource = "Start JARVIS Inspection"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(visionRequest: JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "app_intent"))
        return .result(dialog: "Opening Jarvis Vision.")
    }
}

@available(iOS 16.0, *)
struct DescribeVisionIntent: AppIntent {
    static var title: LocalizedStringResource = "Describe with JARVIS Vision"
    static var description = IntentDescription("Capture and describe the visible scene on device.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(visionRequest: JarvisVisionLaunchRequest(mode: .describe, command: .run, source: "app_intent", startsImmediately: true))
        return .result(dialog: "Opening Describe.")
    }
}

@available(iOS 16.0, *)
struct ReadTextVisionIntent: AppIntent {
    static var title: LocalizedStringResource = "Read Text with JARVIS Vision"
    static var description = IntentDescription("Capture and read visible text on device.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(visionRequest: JarvisVisionLaunchRequest(mode: .readText, command: .run, source: "app_intent", startsImmediately: true))
        return .result(dialog: "Opening Read Text.")
    }
}

@available(iOS 16.0, *)
struct StartLiveGuideIntent: AppIntent {
    static var title: LocalizedStringResource = "Start JARVIS Live Guide"
    static var description = IntentDescription("Start foreground-only Live Guide.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(visionRequest: JarvisVisionLaunchRequest(mode: .liveGuide, command: .run, source: "app_intent", startsImmediately: true))
        return .result(dialog: "Starting foreground Live Guide.")
    }
}

@available(iOS 16.0, *)
struct StopLiveGuideIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop JARVIS Live Guide"
    static var description = IntentDescription("Stop Vision analysis and narration.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(visionRequest: JarvisVisionLaunchRequest(mode: .liveGuide, command: .stop, source: "app_intent"))
        return .result(dialog: "Stopping JARVIS Live Guide.")
    }
}

@available(iOS 16.0, *)
struct FindObjectVisionIntent: AppIntent {
    static var title: LocalizedStringResource = "Find an Object with JARVIS"
    static var description = IntentDescription("Search for an object supported by the installed on-device model.")
    static var openAppWhenRun = true

    @Parameter(title: "Object")
    var target: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let clean = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else {
            return .result(dialog: "Name an object for JARVIS to find.")
        }
        JarvisPendingIntentStore.save(visionRequest: JarvisVisionLaunchRequest(mode: .find, command: .run, target: clean, source: "app_intent", startsImmediately: true))
        return .result(dialog: "Opening Find for \(clean).")
    }
}

@available(iOS 16.0, *)
struct RepeatVisionIntent: AppIntent {
    static var title: LocalizedStringResource = "Repeat JARVIS Vision Result"
    static var description = IntentDescription("Repeat the latest session-only Vision narration.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(visionRequest: JarvisVisionLaunchRequest(mode: .describe, command: .repeatLast, source: "app_intent"))
        return .result(dialog: "Repeating the latest Vision result in JARVIS.")
    }
}

@available(iOS 16.0, *)
struct SetQuietModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set JARVIS Quiet Mode"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(command: "quiet mode")
        return .result(dialog: "JARVIS quiet mode requested.")
    }
}

@available(iOS 16.0, *)
struct SetNormalModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Set JARVIS Normal Mode"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(command: "normal mode")
        return .result(dialog: "JARVIS normal mode requested.")
    }
}

@available(iOS 16.0, *)
struct OpenJarvisDiagnosticsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open JARVIS Diagnostics"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(route: "diagnostics")
        return .result(dialog: "Opening JARVIS diagnostics.")
    }
}

@available(iOS 16.0, *)
struct OpenControlMeshIntent: AppIntent {
    static var title: LocalizedStringResource = "Open JARVIS Control Mesh"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(route: "control-mesh")
        return .result(dialog: "Opening JARVIS Control Mesh.")
    }
}

@available(iOS 16.0, *)
struct ReturnToJarvisIntent: AppIntent {
    static var title: LocalizedStringResource = "Return to JARVIS"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(route: "standby")
        return .result(dialog: "Returning to JARVIS.")
    }
}

@available(iOS 16.0, *)
struct VoiceTestIntent: AppIntent {
    static var title: LocalizedStringResource = "Test JARVIS Voice"
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult & ProvidesDialog {
        JarvisPendingIntentStore.save(command: "voice test")
        return .result(dialog: "JARVIS voice test requested.")
    }
}

@available(iOS 16.0, *)
struct JarvisAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: DescribeVisionIntent(),
            phrases: ["\(.applicationName) describe this", "What is in front of me with \(.applicationName)"],
            shortTitle: "Describe",
            systemImageName: "camera.viewfinder"
        )
        AppShortcut(
            intent: ReadTextVisionIntent(),
            phrases: ["\(.applicationName) read this", "Read text with \(.applicationName)"],
            shortTitle: "Read Text",
            systemImageName: "text.viewfinder"
        )
        AppShortcut(
            intent: StartLiveGuideIntent(),
            phrases: ["Start \(.applicationName) Live Guide", "\(.applicationName) guide me live"],
            shortTitle: "Start Live",
            systemImageName: "dot.radiowaves.left.and.right"
        )
        AppShortcut(
            intent: StopLiveGuideIntent(),
            phrases: ["Stop \(.applicationName) Live Guide", "\(.applicationName) stop vision"],
            shortTitle: "Stop Live",
            systemImageName: "stop.fill"
        )
        AppShortcut(
            intent: FindObjectVisionIntent(),
            phrases: ["\(.applicationName) find \(\.$target)"],
            shortTitle: "Find Object",
            systemImageName: "scope"
        )
        AppShortcut(
            intent: RepeatVisionIntent(),
            phrases: ["\(.applicationName) repeat that", "Repeat the \(.applicationName) Vision result"],
            shortTitle: "Repeat Vision",
            systemImageName: "repeat"
        )
        AppShortcut(
            intent: SetQuietModeIntent(),
            phrases: ["\(.applicationName) quiet", "Set \(.applicationName) quiet mode"],
            shortTitle: "Quiet",
            systemImageName: "speaker.slash"
        )
        AppShortcut(
            intent: OpenJarvisDiagnosticsIntent(),
            phrases: ["\(.applicationName) diagnostics", "Open \(.applicationName) diagnostics"],
            shortTitle: "Diagnostics",
            systemImageName: "gauge"
        )
        AppShortcut(
            intent: OpenControlMeshIntent(),
            phrases: ["\(.applicationName) mesh", "Open \(.applicationName) control mesh"],
            shortTitle: "Mesh",
            systemImageName: "point.3.connected.trianglepath.dotted"
        )
        AppShortcut(
            intent: ReturnToJarvisIntent(),
            phrases: ["Return to \(.applicationName)", "\(.applicationName) return"],
            shortTitle: "Return",
            systemImageName: "arrow.uturn.backward"
        )
    }
}
#endif
