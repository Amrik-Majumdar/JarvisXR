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
        JarvisPendingIntentStore.save(route: "inspect")
        return .result(dialog: "Opening JARVIS inspection.")
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
            intent: StartInspectionIntent(),
            phrases: ["\(.applicationName) inspect", "Start \(.applicationName) inspection"],
            shortTitle: "Inspect",
            systemImageName: "viewfinder"
        )
        AppShortcut(
            intent: SetQuietModeIntent(),
            phrases: ["\(.applicationName) quiet", "Set \(.applicationName) quiet mode"],
            shortTitle: "Quiet",
            systemImageName: "speaker.slash"
        )
        AppShortcut(
            intent: SetNormalModeIntent(),
            phrases: ["\(.applicationName) normal", "Set \(.applicationName) normal mode"],
            shortTitle: "Normal",
            systemImageName: "speaker.wave.2"
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
        AppShortcut(
            intent: VoiceTestIntent(),
            phrases: ["\(.applicationName) voice test", "Test \(.applicationName) voice"],
            shortTitle: "Voice Test",
            systemImageName: "waveform"
        )
    }
}
#endif
