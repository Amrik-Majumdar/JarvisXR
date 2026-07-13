import Foundation
import AVFoundation
import CoreMotion
import UIKit

final class JarvisCommandRouter {
    private let memory: JarvisMemoryStore
    private let dateFormatter: DateFormatter
    private let timeFormatter: DateFormatter
    private let motionManager = CMMotionManager()
    private let planner = JarvisCommandPlanner()
    private let controlMeshPlanner = JarvisControlMeshPlanner()

    init(memory: JarvisMemoryStore = .shared) {
        self.memory = memory
        self.dateFormatter = DateFormatter()
        self.timeFormatter = DateFormatter()
        dateFormatter.dateStyle = .full
        timeFormatter.timeStyle = .short
    }

    func route(_ command: JarvisCommand) -> JarvisResponse {
        let text = canonicalCommand(command.normalizedText)
        if text.isEmpty {
            return .ok("Ready.", display: "Enter a command.", shouldSpeak: false)
        }
        let plan = planner.plan(command.rawText)
        if let planned = plannedResponse(for: plan, raw: command.rawText) {
            return planned
        }
        if matches(text, ["help", "tools", "list tools", "what can you do", "what can you do locally", "commands"]) {
            return help()
        }
        if matches(text, ["companion mode", "pip", "picture in picture", "mini player"]) {
            return .ok(
                "Companion overlay is not available.",
                display: "iOS does not allow arbitrary floating JARVIS UI over other apps in this build. JARVIS can continue through audio, Shortcuts, Voice Control, and return-to-JARVIS."
            )
        }
        if matches(text, ["control mesh", "control setup", "use control mesh", "open control mesh", "mesh", "open mesh"]) {
            return .ok("Control Mesh ready.", display: controlMeshSummary(), data: ["action": "control_mesh", "mode": "control_mesh"])
        }
        if matches(text, ["status", "system status"]) {
            return status()
        }
        if text == "install status" || text == "deployment status" {
            return installStatus()
        }
        if matches(text, ["battery", "battery status", "show battery"]) {
            return battery()
        }
        if matches(text, ["device status", "xr hardware", "hardware advantage"]) {
            return hardwareAdvantage()
        }
        if matches(text, ["listen", "start listening"]) {
            return .ok("Tap the orb to listen.", display: "Tap the orb. JARVIS will listen inside the app only.", data: ["mode": "listening_hint"])
        }
        if matches(text, ["stop listening"]) {
            return .ok("Listening stopped.", display: "Listening is controlled by the orb in this build.", data: ["mode": "standby"], shouldSpeak: false)
        }
        if matches(text, ["sensor status", "motion status", "compass status", "orientation", "orientation status", "low power status", "field mode"]) {
            return sensorStatus(command: text)
        }
        if matches(text, ["storage", "show storage", "storage status"]) {
            return storage()
        }
        if matches(text, ["time", "what time is it"]) {
            return .ok("The time is \(timeFormatter.string(from: Date())).")
        }
        if matches(text, ["date", "what date is it"]) {
            return .ok("The date is \(dateFormatter.string(from: Date())).")
        }
        if matches(text, [
            "open camera", "camera", "camera status", "take photo", "scan this", "scan this paper",
            "read this", "read this label", "read what is on screen", "read the screen", "detect objects",
            "what am i looking at", "what am i pointing at", "look at this", "read paper", "scan paper"
        ]) {
            if text == "camera status" {
                return cameraStatus()
            }
            if matches(text, ["read this", "read this label", "read what is on screen", "read the screen", "read paper"]) {
                return .ok("Opening inspection.", display: "Opening inspection. Text recognition looks continuously for a useful live frame.", data: ["action": "inspect", "vision": "ocr"])
            }
            if matches(text, ["detect objects", "what am i looking at", "what am i pointing at", "look at this"]) {
                return .ok("Opening visual scan.", display: "Opening inspection. \(JarvisObjectDetectionModel.statusLine())", data: ["action": "inspect", "vision": "visual_classification"])
            }
            if matches(text, ["scan this", "scan this paper", "scan paper", "take photo"]) {
                return .ok("Opening inspection.", display: "Opening inspection.", data: ["action": "inspect"])
            }
            return .ok("Opening camera.", display: "Opening local inspection.", data: ["action": "open_camera"])
        }
        if matches(text, ["inspect mode", "inspect", "inspection mode"]) {
            return .ok("Opening inspection.", display: "Opening inspection.", data: ["action": "inspect"])
        }
        if matches(text, ["flashlight on", "turn on flashlight", "light on"]) {
            return .ok("Opening inspection.", display: "Opening inspection. Use Light to enable torch after camera access.", data: ["action": "inspect", "camera_command": "torch_on"])
        }
        if matches(text, ["flashlight off", "turn off flashlight", "light off"]) {
            return .ok("Opening inspection.", display: "Opening inspection. Use Light to disable torch if active.", data: ["action": "inspect", "camera_command": "torch_off"])
        }
        if text.hasPrefix("remember this") {
            return rememberThis(from: command.rawText)
        }
        if text.hasPrefix("save note") || text.hasPrefix("note ") {
            return saveNote(from: command.rawText)
        }
        if text == "show notes" || text == "list notes" {
            return showNotes()
        }
        if text.hasPrefix("search notes") {
            return searchNotes(from: command.rawText)
        }
        if text == "clear notes with confirmation" || text == "clear notes" {
            return JarvisResponse(status: .confirmationRequired, spokenResponse: "Confirmation required.", displayResponse: "Type confirm clear notes to erase local notes.", data: ["confirmation": "clear_notes"])
        }
        if text == "confirm clear notes" {
            memory.clearNotes()
            return .ok("Local notes cleared.", display: "Notes cleared.")
        }
        if text == "clear history" || text == "clear command history" {
            return JarvisResponse(status: .confirmationRequired, spokenResponse: "Confirmation required.", displayResponse: "Type confirm clear history to erase local command history.", data: ["confirmation": "clear_history"])
        }
        if text == "confirm clear history" {
            memory.clearHistory()
            return .ok("Command history cleared.", display: "Command history cleared.")
        }
        if text.hasPrefix("speak this") {
            let spoken = trimmedArgument(command.rawText, prefix: "speak this")
            return .ok(spoken.isEmpty ? "Nothing to speak." : spoken, display: spoken.isEmpty ? "No speech text provided." : "Speaking: \(spoken)")
        }
        if text == "repeat last response" || text == "repeat" {
            let last = memory.lastResponse() ?? "No previous response is stored."
            return .ok(last, display: last)
        }
        if text == "stop speaking" || text == "stop speech" {
            JarvisSpeechService.shared.stop()
            return .ok("Speech stopped.", display: "Speech output stopped.", shouldSpeak: false)
        }
        if text == "quiet mode" || text == "speech off" || text == "mute" || text == "be quiet" {
            JarvisSpeechService.shared.isEnabled = false
            return .ok("Quiet mode enabled.", display: "Quiet mode enabled.", data: ["mode": "quiet"], shouldSpeak: false)
        }
        if text == "normal mode" || text == "wake" || text == "unmute" || text == "talk normally" {
            JarvisSpeechService.shared.isEnabled = true
            return .ok("Normal mode restored.", display: "Normal mode restored.", data: ["mode": "core"])
        }
        if text == "speech on" {
            JarvisSpeechService.shared.isEnabled = true
            return .ok("Speech output enabled.", display: "Speech output enabled.")
        }
        if text == "voice test" {
            let phrase = JarvisSpeechService.shared.testPhrase()
            return .ok(phrase, display: phrase)
        }
        if text == "voice profiles" || text == "preview voices" || text == "test all voices" {
            JarvisSpeechService.shared.previewAllProfiles()
            return .ok("Previewing voice profiles.", display: "Previewing Natural, Friendly, Crisp, Quiet, and Formal.")
        }
        if text == "speak faster" || text == "talk faster" || text == "faster speech" {
            let rate = JarvisSpeechService.shared.adjustSpeechRate(by: 0.03)
            return .ok("I will speak faster.", display: "Speech rate: \(String(format: "%.2f", rate)).")
        }
        if text == "speak slower" || text == "talk slower" || text == "slower speech" {
            let rate = JarvisSpeechService.shared.adjustSpeechRate(by: -0.03)
            return .ok("I will speak slower.", display: "Speech rate: \(String(format: "%.2f", rate)).")
        }
        if text == "use another voice" || text == "change voice" || text == "next voice" {
            let configuration = JarvisSpeechService.shared.selectNextProfile()
            return voiceSelectionResponse(configuration)
        }
        if text == "voice natural" || text == "natural voice" || text == "voice default" || text == "default voice" {
            return voiceSelectionResponse(JarvisSpeechService.shared.selectProfile(.natural))
        }
        if text == "voice friendly" || text == "friendly voice" {
            return voiceSelectionResponse(JarvisSpeechService.shared.selectProfile(.friendly))
        }
        if text == "voice formal" || text == "formal voice" {
            return voiceSelectionResponse(JarvisSpeechService.shared.selectProfile(.formal))
        }
        if text == "voice crisp" || text == "crisp voice" {
            return voiceSelectionResponse(JarvisSpeechService.shared.selectProfile(.crisp))
        }
        if text == "voice quiet" || text == "quiet voice" {
            return voiceSelectionResponse(JarvisSpeechService.shared.selectProfile(.quiet))
        }
        if text == "diagnostics" {
            return .ok("Diagnostics are available.", display: "Open Diagnostics for battery, system version, notes count, and install notes.", data: ["action": "diagnostics"])
        }
        if text == "use my voice" || text == "personal voice" {
            return .ok("Personal Voice setup is in Settings.", display: "Open Settings. JARVIS can request Personal Voice authorization on supported iOS versions, but no custom voice is trained or uploaded.", data: ["action": "settings"])
        }
        if text == "open settings" || text == "settings" {
            return .ok("Opening settings.", display: "Opening JARVIS settings.", data: ["action": "settings"])
        }
        if text == "system check" {
            return systemCheck()
        }
        if text == "guided access instructions" || text == "guided access" || text == "lockdown instructions" {
            return guidedAccess()
        }
        if text == "about jarvis" || text == "about" || text == "identity" {
            return about()
        }
        if text == "standby" || text == "standby mode" {
            JarvisSpeechService.shared.isEnabled = false
            return .ok("Standby.", display: "Standby.", data: ["mode": "standby"], shouldSpeak: false)
        }
        if let meshResponse = controlMeshCommand(text) {
            return meshResponse
        }
        if text == "offline mode" {
            return .ok("Offline mode is active.", display: "JARVIS uses local commands, notes, diagnostics, speech output, and camera inspection without cloud services.")
        }
        if text == "memory status" {
            return .ok("Memory summary ready.", display: memory.noteSummary())
        }
        if text == "next steps" {
            return nextSteps()
        }
        if text.hasPrefix("convert ") {
            return convert(command.rawText)
        }
        if text.hasPrefix("calculate ") || text.hasPrefix("calc ") {
            return calculate(command.rawText)
        }
        if text.hasPrefix("copy last response") {
            UIPasteboard.general.string = memory.lastResponse() ?? ""
            return .ok("Last response copied.", display: "Last response copied to clipboard.")
        }
        if text.hasPrefix("copy notes summary") || text.hasPrefix("copy notes") {
            UIPasteboard.general.string = memory.notesSummaryForClipboard()
            return .ok("Notes copied.", display: "Local notes summary copied to clipboard.")
        }
        return JarvisResponse(status: .refused, spokenResponse: "Command not recognized.", displayResponse: fallbackText(), data: [:], shouldSpeak: false)
    }

    private func help() -> JarvisResponse {
        let commands = """
        Vision: describe this room, what is in front of me, describe left, start live guide, stop live guide
        Find: find the chair, where is the person, find the door
        Read and scan: read this, next line, scan this barcode, what color is this
        Vision control: repeat that, more detail, only important changes, camera quality, flashlight on, flashlight off, stop
        Messages: message a contact, tell a contact a message, read the message back, change the recipient, cancel the message, open the message composer
        Voice: JARVIS ready, listen, stop listening, stop speaking, quiet mode, normal mode
        Memory: remember this, save note, show notes, search notes, what did I say
        Control Mesh: Mesh, show grid, tap that, scroll down, go home, take screenshot, return to JARVIS
        System: status, battery, storage, time, date, diagnostics
        """
        return .ok("Inspection tools are ready.", display: commands)
    }

    private func plannedResponse(for plan: JarvisCommandPlan, raw: String) -> JarvisResponse? {
        switch plan.route {
        case .inAppSpeech where plan.action == .speech:
            return nil
        case .inAppVision:
            return .ok(plan.spokenText, display: plan.displayText, data: plan.data)
        case .inAppMessage:
            return .ok(plan.spokenText, display: plan.displayText, data: plan.data, shouldSpeak: false)
        case .controlMeshGuide where plan.action == .openControlMesh:
            return .ok(plan.spokenText, display: controlMeshSummary(), data: ["action": "control_mesh", "route_label": plan.routeLabel])
        case .voiceControlRoute, .shortcutRoute, .appOpenURL:
            return .ok(plan.spokenText, display: plan.displayText, data: plan.data)
        case .unsupportedRequiresSystemAccess:
            return JarvisResponse(status: .unavailable, spokenResponse: plan.spokenText, displayResponse: plan.displayText, data: plan.data)
        default:
            return nil
        }
    }

    private func status() -> JarvisResponse {
        let guided = UIAccessibility.isGuidedAccessEnabled ? "Guided Access active." : "Guided Access ready when enabled."
        let speech = JarvisSpeechService.shared.isEnabled ? "on" : "off"
        return .ok("JARVIS is running locally.", display: "Mode: Control Mesh core.\nSpeech: \(speech)\n\(guided)\nGlobal layer: iOS Voice Control and Shortcuts when configured.\nSystem-level ownership is not claimed in this build.")
    }

    private func installStatus() -> JarvisResponse {
        let display = """
        Install path: GitHub Actions unsigned IPA.
        Windows install tool: AltServer.
        Lockdown layer after testing: Guided Access.
        Refresh note: free Apple ID installs usually need refresh after 7 days.
        Boundary: system-level ownership is not claimed in this build.
        """
        return .ok("Install status ready.", display: display)
    }

    private func battery() -> JarvisResponse {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel
        let percent = level >= 0 ? Int(level * 100) : -1
        let state: String
        switch UIDevice.current.batteryState {
        case .charging: state = "charging"
        case .full: state = "full"
        case .unplugged: state = "unplugged"
        default: state = "unknown"
        }
        let display = percent >= 0 ? "Battery: \(percent)%\nState: \(state)" : "Battery level unavailable.\nState: \(state)"
        return .ok("Battery diagnostics ready.", display: display, data: ["battery_state": state])
    }

    private func hardwareAdvantage() -> JarvisResponse {
        let display = """
        Hardware advantage
        Camera: local inspection, capture, torch, focus, exposure.
        Vision: continuous OCR, barcode scan, and bundled on-device object detection while a Vision task is active.
        Voice: local speech output and in-app push-to-talk.
        Sensors: motion availability, battery, storage, Low Power Mode.
        Security: Guided Access and device restrictions are the current lockdown layer.
        Connectivity: Wi-Fi is optional.
        """
        return .ok("Hardware summary ready.", display: display)
    }

    private func sensorStatus(command: String) -> JarvisResponse {
        let motion = motionManager.isDeviceMotionAvailable ? "available" : "unavailable"
        let accelerometer = motionManager.isAccelerometerAvailable ? "available" : "unavailable"
        let gyro = motionManager.isGyroAvailable ? "available" : "unavailable"
        let magnetometer = motionManager.isMagnetometerAvailable ? "available" : "unavailable"
        let orientation = UIDevice.current.orientation.isValidInterfaceOrientation ? "\(UIDevice.current.orientation)" : "portrait app surface, physical orientation not currently resolved"
        let lowPower = ProcessInfo.processInfo.isLowPowerModeEnabled ? "enabled" : "disabled"
        let headingNote = "Compass heading requires CoreLocation permission and is not requested in this build."
        let fieldNote = command == "field mode" ? "\nField mode: use inspection, camera status, sensor status, notes, low power status, and battery diagnostics. Location is not requested by default." : ""
        let display = """
        Sensor status

        Orientation: \(orientation)
        Device motion: \(motion)
        Accelerometer: \(accelerometer)
        Gyroscope: \(gyro)
        Magnetometer: \(magnetometer)
        Compass heading: \(headingNote)
        Low Power Mode: \(lowPower)
        Battery: use battery or diagnostics for live battery state.\(fieldNote)
        """
        let spoken = command == "field mode" ? "Field mode ready." : "Sensor status ready."
        return .ok(spoken, display: display, data: ["mode": command == "field mode" ? "field" : "sensor"])
    }

    private func storage() -> JarvisResponse {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let free = attributes[.systemFreeSize] as? NSNumber {
            let gb = Double(truncating: free) / 1_073_741_824.0
            return .ok("Storage diagnostics ready.", display: String(format: "Approximate free storage: %.2f GB", gb))
        }
        return JarvisResponse(status: .unavailable, spokenResponse: "Storage is unavailable.", displayResponse: "Storage attributes could not be read.", data: [:])
    }

    private func saveNote(from raw: String) -> JarvisResponse {
        let prefix = raw.lowercased().hasPrefix("note ") ? "note" : "save note"
        let text = trimmedArgument(raw, prefix: prefix)
        guard !text.isEmpty else {
            return JarvisResponse(status: .refused, spokenResponse: "No note text provided.", displayResponse: "Use: save note your text", data: [:], shouldSpeak: false)
        }
        let note = memory.saveNote(text)
        return .ok("Note saved.", display: "Saved note: \(note.text)\nTime: \(shortDate(note.createdAt))")
    }

    private func rememberThis(from raw: String) -> JarvisResponse {
        let lower = raw.lowercased()
        let marker = "remember this"
        guard let range = lower.range(of: marker) else {
            return JarvisResponse(status: .refused, spokenResponse: "Tell me what to remember.", displayResponse: "Use: remember this your note", data: [:], shouldSpeak: false)
        }
        let text = raw[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":")))
        guard !text.isEmpty else {
            return JarvisResponse(status: .refused, spokenResponse: "Tell me what to remember.", displayResponse: "Use: remember this your note", data: [:], shouldSpeak: false)
        }
        let note = memory.saveNote(text)
        return .ok("Remembered.", display: "Saved note: \(note.text)")
    }

    private func showNotes() -> JarvisResponse {
        let notes = memory.loadNotes()
        guard !notes.isEmpty else {
            return .ok("No local notes.", display: "No notes saved.")
        }
        let display = notes.enumerated().map { "\($0.offset + 1). [\(shortDate($0.element.createdAt))] \($0.element.text)" }.joined(separator: "\n")
        return .ok("Showing \(notes.count) notes.", display: display)
    }

    private func searchNotes(from raw: String) -> JarvisResponse {
        let query = trimmedArgument(raw, prefix: "search notes")
        guard !query.isEmpty else {
            return JarvisResponse(status: .refused, spokenResponse: "No search text provided.", displayResponse: "Use: search notes your query", data: [:], shouldSpeak: false)
        }
        let results = memory.searchNotes(query)
        let display = results.isEmpty ? "No note matches." : results.map { "[\(shortDate($0.createdAt))] \($0.text)" }.joined(separator: "\n")
        return .ok("Found \(results.count) matching notes.", display: display)
    }

    private func guidedAccess() -> JarvisResponse {
        let display = "Open JARVIS, triple-click the side button, start Guided Access, and test exit first. Guided Access can keep JARVIS foreground. It cannot provide system UI ownership or lock screen control."
        return .ok("Guided Access instructions ready.", display: display)
    }

    private func about() -> JarvisResponse {
        let display = """
        JARVIS Appliance Mode

        Purpose: make this iPhone feel like a dedicated JARVIS device.
        Core: native Swift and UIKit, local commands, local memory, speech output, camera inspection, diagnostics.
        Control Mesh: Voice Control, Vocal Shortcuts, Shortcuts, URL scheme, and App Intents where available.
        Lockdown: Guided Access after testing.
        Boundary: not a website, not a chatbot, and not system UI ownership.
        """
        return .ok("JARVIS appliance mode.", display: display)
    }

    private func systemCheck() -> JarvisResponse {
        UIDevice.current.isBatteryMonitoringEnabled = true
        let battery = UIDevice.current.batteryLevel >= 0 ? "\(Int(UIDevice.current.batteryLevel * 100))%" : "unavailable"
        let speech = JarvisSpeechService.shared.isEnabled ? "enabled" : "disabled"
        let guided = UIAccessibility.isGuidedAccessEnabled ? "active" : "ready when enabled"
        let display = """
        JARVIS systems online.
        Mode: Control Mesh core.
        iOS: \(UIDevice.current.systemVersion)
        Battery: \(battery)
        Speech: \(speech)
        Notes: \(memory.loadNotes().count)
        Command history: \(memory.loadHistory().count)
        Guided Access: \(guided)
        Global control: Voice Control and Shortcuts after setup.
        Network: optional enhancement only.
        """
        return .ok("System check complete.", display: display)
    }

    private func cameraStatus() -> JarvisResponse {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        let display: String
        switch status {
        case .authorized:
            display = "Camera permission: authorized. Inspection preview can open."
        case .notDetermined:
            display = "Camera permission: not requested yet. Open Camera or Inspect to request access."
        case .denied:
            display = "Camera permission: denied. Enable Camera in iOS Settings for JARVIS."
        case .restricted:
            display = "Camera permission: restricted by iOS policy."
        @unknown default:
            display = "Camera permission: unknown."
        }
        let modelStatus = JarvisObjectDetectionModel.diagnosticLine()
        return .ok("Camera status ready.", display: "\(display)\n\(modelStatus)")
    }

    private func nextSteps() -> JarvisResponse {
        let display = """
        1. Test help, status, battery, notes, speech, camera, diagnostics, and settings.
        2. Close and reopen JARVIS to confirm local memory persists.
        3. Turn Wi-Fi off and verify offline commands still work.
        4. Enable Guided Access only after you have tested the exit path.
        """
        return .ok("Readiness checklist ready.", display: display)
    }

    private func voiceSelectionResponse(_ configuration: JarvisResolvedVoiceConfiguration) -> JarvisResponse {
        let fallback = configuration.usedFallbackVoice ? " A fallback installed voice is being used." : ""
        return .ok(
            "\(configuration.profile.displayName) voice selected.\(fallback)",
            display: "Voice: \(configuration.profile.displayName) — \(configuration.voiceName), \(configuration.locale), rate \(String(format: "%.2f", configuration.rate)), pitch \(String(format: "%.2f", configuration.pitch)).\(fallback)"
        )
    }

    private func convert(_ raw: String) -> JarvisResponse {
        let text = raw.lowercased()
        let pattern = #"convert\s+([0-9]+(?:\.[0-9]+)?)\s+(cm|centimeters|in|inch|inches|ft|feet|m|meters|kg|kilograms|lb|lbs|pounds)\s+to\s+(cm|centimeters|in|inch|inches|ft|feet|m|meters|kg|kilograms|lb|lbs|pounds)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges == 4,
              let valueRange = Range(match.range(at: 1), in: text),
              let fromRange = Range(match.range(at: 2), in: text),
              let toRange = Range(match.range(at: 3), in: text),
              let value = Double(text[valueRange]) else {
            return JarvisResponse(status: .refused, spokenResponse: "Conversion format not recognized.", displayResponse: "Use: convert 10 cm to inches", shouldSpeak: false)
        }
        let from = canonicalUnit(String(text[fromRange]))
        let to = canonicalUnit(String(text[toRange]))
        guard let result = convert(value: value, from: from, to: to) else {
            return JarvisResponse(status: .refused, spokenResponse: "Those units are not compatible.", displayResponse: "Supported groups: length to length, weight to weight.", shouldSpeak: false)
        }
        return .ok("Conversion ready.", display: String(format: "%.3f %@ = %.3f %@", value, from, result, to))
    }

    private func canonicalUnit(_ unit: String) -> String {
        switch unit {
        case "centimeters": return "cm"
        case "inch", "inches": return "in"
        case "feet": return "ft"
        case "meters": return "m"
        case "kilograms": return "kg"
        case "lb", "lbs", "pounds": return "lb"
        default: return unit
        }
    }

    private func convert(value: Double, from: String, to: String) -> Double? {
        let lengthToMeters = ["cm": 0.01, "in": 0.0254, "ft": 0.3048, "m": 1.0]
        let weightToKg = ["kg": 1.0, "lb": 0.45359237]
        if let fromBase = lengthToMeters[from], let toBase = lengthToMeters[to] {
            return value * fromBase / toBase
        }
        if let fromBase = weightToKg[from], let toBase = weightToKg[to] {
            return value * fromBase / toBase
        }
        return nil
    }

    private func fallbackText() -> String {
        "Try: scan this, look at this, read this, detect objects, remember this, show grid, battery, or help."
    }

    private func controlMeshSummary() -> String {
        """
        JARVIS Control Mesh

        Direct app control: local commands, speech, memory, camera inspection, diagnostics, and settings.
        Global iOS control: enable Voice Control for Show Grid, Tap, Scroll, Go Home, Dictate, Paste, and app opening.
        Wake/action phrases: configure Vocal Shortcuts such as Jarvis inspect, Jarvis quiet, Jarvis normal, Jarvis diagnostics, and Jarvis standby.
        Automation bridge: create Shortcuts that open jarvis:// links.
        Return route: jarvis://standby or the JARVIS Return Shortcut.
        Boundary: SpringBoard hooks, lock screen hooks, root daemons, hidden screen reading, and injected taps require system-level access.
        """
    }

    private func controlMeshCommand(_ text: String) -> JarvisResponse? {
        if let route = controlMeshPlanner.route(for: text) {
            return .ok(route.spokenText, display: route.displayText, data: route.data)
        }
        let map: [String: (spoken: String, display: String, data: [String: String])] = [
            "scroll down": ("Use Voice Control.", "Say: Scroll Down.", [:]),
            "scroll this page": ("Use Voice Control.", "Say: Scroll Down.", [:]),
            "scroll page": ("Use Voice Control.", "Say: Scroll Down.", [:]),
            "scroll up": ("Use Voice Control.", "Say: Scroll Up.", [:]),
            "tap": ("Use Voice Control grid.", "Say: Show Grid, then Tap the number.", [:]),
            "tap that": ("Use Voice Control grid.", "Say: Show Grid, then Tap the target number.", [:]),
            "show me how to tap that": ("Use Voice Control grid.", "Say: Show Grid, then Tap the target number.", [:]),
            "how do i tap that": ("Use Voice Control grid.", "Say: Show Grid, then Tap the target number.", [:]),
            "show grid": ("Show the Voice Control grid.", "Say: Show Grid.", [:]),
            "go home": ("Use Voice Control.", "Say: Go Home.", [:]),
            "go back to jarvis": ("Return to JARVIS.", "Use the JARVIS Return Shortcut, or say Open JARVIS.", [:]),
            "back to jarvis": ("Return to JARVIS.", "Use the JARVIS Return Shortcut, or say Open JARVIS.", [:]),
            "take screenshot": ("Use Voice Control.", "Say: Take Screenshot.", [:]),
            "take a screenshot": ("Use Voice Control.", "Say: Take Screenshot.", [:]),
            "paste": ("Use Voice Control.", "Say: Paste in the target field.", [:]),
            "dictate": ("Use Voice Control dictation.", "Place the cursor, then dictate.", [:]),
            "return to jarvis": ("Return to JARVIS.", "Use the JARVIS Return Shortcut or open JARVIS from Home.", [:]),
            "open spotify": ("Opening Spotify.", "Opening Spotify.", dataURL("spotify://")),
            "open safari": ("Opening Safari.", "Opening Safari.", dataURL("https://www.google.com")),
            "open youtube": ("Opening YouTube.", "Opening YouTube.", dataURL("youtube://")),
            "search web": ("Open Safari for search.", "Opening Safari. Use local tools offline.", dataURL("https://www.google.com/search?q=")),
            "night mode": ("Use the JARVIS Night Shortcut.", "Run the JARVIS Night Shortcut for brightness, Focus, or appearance.", [:]),
            "turn on night mode": ("Use the JARVIS Night Shortcut.", "Run the JARVIS Night Shortcut for brightness, Focus, or appearance.", [:]),
            "make the screen darker": ("Use the JARVIS Dim Shortcut.", "Run the JARVIS Dim Shortcut, or say Turn Brightness Down with Voice Control.", [:]),
            "dim the screen": ("Use the JARVIS Dim Shortcut.", "Run the JARVIS Dim Shortcut, or say Turn Brightness Down with Voice Control.", [:]),
            "turn brightness down": ("Use the JARVIS Dim Shortcut.", "Run the JARVIS Dim Shortcut, or say Turn Brightness Down with Voice Control.", [:]),
            "volume up": ("Use Voice Control.", "Say: Turn Volume Up.", [:]),
            "volume down": ("Use Voice Control.", "Say: Turn Volume Down.", [:]),
            "dark mode": ("JARVIS is already dark.", "JARVIS is already using a dark interface.", [:]),
            "turn on dark mode": ("JARVIS is already dark.", "JARVIS is already using a dark interface.", [:])
        ]
        guard let result = map[text] else { return nil }
        return .ok(result.spoken, display: result.display, data: result.data)
    }

    private func dataURL(_ url: String) -> [String: String] {
        ["url_scheme": url]
    }

    private func canonicalCommand(_ value: String) -> String {
        var text = value
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "what's", with: "what is")
            .replacingOccurrences(of: "whats", with: "what is")
        let punctuation = CharacterSet(charactersIn: ",.?;!\"")
        text = text.components(separatedBy: punctuation).joined(separator: " ")
        for prefix in ["hey jarvis ", "okay jarvis ", "ok jarvis ", "jarvis "] {
            if text.hasPrefix(prefix) {
                text = String(text.dropFirst(prefix.count))
                break
            }
        }
        if text.hasPrefix("please ") {
            text = String(text.dropFirst("please ".count))
        }
        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private func matches(_ text: String, _ phrases: [String]) -> Bool {
        phrases.contains(text)
    }

    private func calculate(_ raw: String) -> JarvisResponse {
        let expression = raw
            .replacingOccurrences(of: "calculate", with: "", options: [.caseInsensitive])
            .replacingOccurrences(of: "calc", with: "", options: [.caseInsensitive])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let pattern = #"^\s*(-?[0-9]+(?:\.[0-9]+)?)\s*([+\-*/])\s*(-?[0-9]+(?:\.[0-9]+)?)\s*$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: expression, range: NSRange(expression.startIndex..., in: expression)),
              match.numberOfRanges == 4,
              let leftRange = Range(match.range(at: 1), in: expression),
              let opRange = Range(match.range(at: 2), in: expression),
              let rightRange = Range(match.range(at: 3), in: expression),
              let left = Double(expression[leftRange]),
              let right = Double(expression[rightRange]) else {
            return JarvisResponse(status: .refused, spokenResponse: "Calculation format not recognized.", displayResponse: "Use: calculate 12 / 3", shouldSpeak: false)
        }
        let op = String(expression[opRange])
        if op == "/" && right == 0 {
            return JarvisResponse(status: .refused, spokenResponse: "Division by zero is not allowed.", displayResponse: "Cannot divide by zero.", shouldSpeak: false)
        }
        let result: Double
        switch op {
        case "+": result = left + right
        case "-": result = left - right
        case "*": result = left * right
        case "/": result = left / right
        default:
            return JarvisResponse(status: .refused, spokenResponse: "Unsupported operator.", displayResponse: "Supported operators: +, -, *, /", shouldSpeak: false)
        }
        return .ok("Calculation complete.", display: String(format: "%.4g %@ %.4g = %.4g", left, op, right, result))
    }

    private func trimmedArgument(_ raw: String, prefix: String) -> String {
        let lower = raw.lowercased()
        guard lower.hasPrefix(prefix) else { return "" }
        let index = raw.index(raw.startIndex, offsetBy: prefix.count)
        return String(raw[index...]).trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: ":")))
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
