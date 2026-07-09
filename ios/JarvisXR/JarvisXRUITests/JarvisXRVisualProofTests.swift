import XCTest

final class JarvisXRVisualProofTests: XCTestCase {
    private var app: XCUIApplication!
    private var didCaptureFailureScreenshot = false

    override func setUpWithError() throws {
        continueAfterFailure = false
        didCaptureFailureScreenshot = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    func testProofStandby() throws {
        try printVisualProofStart()
        launch(state: "standby")
        waitForOrb()
        waitFor(app.staticTexts["jarvis.wordmark"], named: "JARVIS wordmark")
        saveScreenshot("standby")
    }

    func testProofReady() throws {
        try printVisualProofStart()
        launch(state: "ready")
        waitForOrb()
        waitForState("Ready")
        saveScreenshot("ready")
    }

    func testProofListening() throws {
        try printVisualProofStart()
        launch(state: "listening")
        waitForOrb()
        waitForState("Listening")
        saveScreenshot("listening")
    }

    func testProofNoSpeech() throws {
        try printVisualProofStart()
        launch(state: "no_speech")
        waitForOrb()
        waitForHintContaining("No speech heard")
        saveScreenshot("no-speech")
    }

    func testProofProcessing() throws {
        try printVisualProofStart()
        launch(state: "processing")
        waitForOrb()
        waitForAnyState(["Speaking", "Done", "Ready"])
        saveScreenshot("processing")
    }

    func testProofLongHoldStandby() throws {
        try printVisualProofStart()
        launch(state: "long_hold_standby")
        waitForOrb()
        waitForState("Standby")
        saveScreenshot("long-hold-standby")
    }

    func testProofHelp() throws {
        try printVisualProofStart()
        launch(state: "help")
        waitFor(app.staticTexts["jarvis.help.header"], named: "Help header")
        saveScreenshot("help")
    }

    func testProofMesh() throws {
        try printVisualProofStart()
        launch(state: "mesh")
        waitFor(app.staticTexts["jarvis.mesh.header"], named: "Control Mesh header")
        saveScreenshot("mesh")
    }

    func testProofInspection() throws {
        try printVisualProofStart()
        launch(state: "inspection")
        waitFor(app.staticTexts["jarvis.inspection.status"], named: "Inspection status")
        saveScreenshot("inspection")
    }

    func testProofObjectModelMissing() throws {
        try printVisualProofStart()
        launch(state: "object_model_missing")
        waitForInspectionStatusContaining("Visual scan ready")
        saveScreenshot("object-model-missing")
    }

    func testProofSettings() throws {
        try printVisualProofStart()
        launch(state: "settings")
        waitFor(app.switches["jarvis.settings.speechSwitch"], named: "Settings speech switch")
        saveScreenshot("settings")
    }

    func testProofDiagnostics() throws {
        try printVisualProofStart()
        launch(state: "diagnostics")
        waitFor(app.textViews["jarvis.diagnostics.text"], named: "Diagnostics text")
        saveScreenshot("diagnostics")
    }

    func testProofKeyboard() throws {
        try printVisualProofStart()
        launch(state: "keyboard")
        waitForOrb()
        waitFor(app.textFields["jarvis.commandInput"], named: "command input")
        saveScreenshot("keyboard")
    }

    private func printVisualProofStart() throws {
        let outputDirectory = try visualProofDirectory()
        print("JARVIS visual proof output: \(outputDirectory.path)")
        printVisualProofEnvironment()
    }

    private func launch(state: String? = nil) {
        app = XCUIApplication()
        app.launchArguments = ["--jarvis-ui-test"]
        if let state {
            app.launchArguments += ["--jarvis-state", state]
        }
        app.launch()
    }

    private func waitForOrb() {
        waitFor(app.otherElements["jarvis.orb"], named: "JARVIS orb", timeout: 8)
    }

    private func waitForState(_ state: String) {
        let label = app.staticTexts["jarvis.state"]
        waitFor(label, named: "state label")
        waitUntil("state \(state)") {
            label.label == state
        }
    }

    private func waitForAnyState(_ states: [String]) {
        let label = app.staticTexts["jarvis.state"]
        waitFor(label, named: "state label")
        waitUntil("one of states \(states.joined(separator: ", "))") {
            states.contains(label.label)
        }
    }

    private func waitForHintContaining(_ text: String) {
        let hint = app.staticTexts["jarvis.hint"]
        waitFor(hint, named: "hint label")
        waitUntil("hint containing \(text)") {
            hint.label.contains(text)
        }
    }

    private func waitForInspectionStatusContaining(_ text: String) {
        let status = app.staticTexts["jarvis.inspection.status"]
        waitFor(status, named: "inspection status")
        waitUntil("inspection status containing \(text)") {
            status.label.contains(text)
        }
    }

    private func waitFor(_ element: XCUIElement, named name: String, timeout: TimeInterval = 5) {
        if !element.waitForExistence(timeout: timeout) {
            print("JARVIS UI test missing element: \(name)")
            print(app.debugDescription)
            XCTFail("Missing \(name). Current UI:\n\(app.debugDescription)")
        }
    }

    private func waitUntil(_ name: String, timeout: TimeInterval = 8, condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return }
            RunLoop.current.run(until: Date().addingTimeInterval(0.2))
        }
        XCTFail("Timed out waiting for \(name). Current UI:\n\(app.debugDescription)")
    }

    private func saveScreenshot(_ name: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)

        let directory: URL
        do {
            directory = try visualProofDirectory()
            let url = directory.appendingPathComponent("\(name).png")
            try screenshot.pngRepresentation.write(to: url)
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? NSNumber
            XCTAssertGreaterThan(size?.intValue ?? 0, 0, "Screenshot \(name) was empty at \(url.path)")
            print("JARVIS saved screenshot: \(url.path) size=\(size?.intValue ?? 0)")
        } catch {
            XCTFail("Could not write screenshot \(name): \(error)")
        }
    }

    private func visualProofDirectory() throws -> URL {
        let environment = ProcessInfo.processInfo.environment
        let rawDirectory = environment["VISUAL_PROOF_DIR"] ?? environment["JARVIS_SCREENSHOT_DIR"] ?? derivedVisualProofDirectory()
        guard let rawDirectory, !rawDirectory.isEmpty else {
            throw NSError(
                domain: "JarvisXRVisualProof",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "VISUAL_PROOF_DIR or JARVIS_SCREENSHOT_DIR must be set for screenshot proof."]
            )
        }
        let directory = URL(fileURLWithPath: rawDirectory, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func derivedVisualProofDirectory(filePath: String = #filePath) -> String? {
        let marker = "/ios/JarvisXR/"
        guard let range = filePath.range(of: marker) else { return nil }
        let projectRoot = String(filePath[..<range.upperBound])
        return projectRoot + "build/visual-proof"
    }

    private func printVisualProofEnvironment() {
        let keys = ProcessInfo.processInfo.environment.keys
            .filter { $0.contains("VISUAL") || $0.contains("SCREENSHOT") || $0.contains("GITHUB") || $0.contains("XCTest") }
            .sorted()
        print("JARVIS visual proof environment keys: \(keys.joined(separator: ", "))")
        if let value = ProcessInfo.processInfo.environment["VISUAL_PROOF_DIR"] {
            print("VISUAL_PROOF_DIR=\(value)")
        }
        if let value = ProcessInfo.processInfo.environment["JARVIS_SCREENSHOT_DIR"] {
            print("JARVIS_SCREENSHOT_DIR=\(value)")
        }
    }

    override func record(_ issue: XCTIssue) {
        if !didCaptureFailureScreenshot, app != nil {
            didCaptureFailureScreenshot = true
            saveFailureScreenshot()
            print("JARVIS UI failure current app tree:\n\(app.debugDescription)")
        }
        super.record(issue)
    }

    private func saveFailureScreenshot() {
        let environment = ProcessInfo.processInfo.environment
        guard let rawDirectory = environment["VISUAL_PROOF_DIR"] ?? environment["JARVIS_SCREENSHOT_DIR"] ?? derivedVisualProofDirectory(),
              !rawDirectory.isEmpty else {
            print("JARVIS could not write failure screenshot because VISUAL_PROOF_DIR was missing.")
            return
        }
        do {
            let directory = URL(fileURLWithPath: rawDirectory, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appendingPathComponent("failure-current-screen.png")
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: url)
            print("JARVIS saved failure screenshot: \(url.path)")
        } catch {
            print("JARVIS could not write failure screenshot: \(error)")
        }
    }
}

private extension XCUIElement {
    func clearText() {
        if let value = value as? String, !value.isEmpty {
            tap()
            let deleteString = String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count)
            typeText(deleteString)
        }
    }
}
