import XCTest

// Media capture only. Uses the existing native app and its documented UI-test
// entry point. The voice stage supplies text to the existing test hook and is
// not a microphone or speech-recognition test.
final class PAIROCACMediaTests: XCTestCase {
    func testNativeWalkthrough() throws {
        continueAfterFailure = false
        let app = XCUIApplication()
        app.launchArguments = ["--jarvis-ui-test", "--jarvis-state", "ready"]
        app.launch()
        let input = app.textFields["jarvis.commandInput"]
        XCTAssertTrue(input.waitForExistence(timeout: 15))
        func cue(_ name: String) {
            print("CAC_CUE|\(name)|\(Date().timeIntervalSince1970)")
            let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            attachment.name = "cac-" + name
            attachment.lifetime = .keepAlways
            add(attachment)
        }
        func command(_ text: String) {
            input.tap()
            if let old = input.value as? String, !old.isEmpty, old != "Command JARVIS" {
                input.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: old.count))
            }
            input.typeText(text)
            app.buttons["jarvis.send"].tap()
        }
        command("quiet mode")
        sleep(2)
        cue("ready")
        sleep(4)
        cue("typing")
        command("remember this Atlas test is Friday")
        XCTAssertTrue(app.staticTexts["jarvis.transientResponse"].waitForExistence(timeout: 5))
        cue("saved")
        sleep(5)
        cue("recall_typing")
        command("search notes Atlas")
        let response = app.staticTexts["jarvis.transientResponse"]
        XCTAssertTrue(response.label.contains("Friday"), response.label)
        cue("recalled")
        sleep(6)
        // Actual local note persistence across process relaunch.
        app.terminate()
        app.launch()
        XCTAssertTrue(input.waitForExistence(timeout: 10))
        command("search notes Atlas")
        XCTAssertTrue(response.label.contains("Friday"), response.label)
        cue("reopened")
        sleep(5)
        command("normal mode")
        sleep(4)
        input.tap()
        input.typeText("show notes")
        // Dismiss the keyboard without submitting, then use the existing
        // simulated transcript route. No microphone is involved.
        app.staticTexts["jarvis.wordmark"].tap()
        cue("voice_prepared")
        app.otherElements["jarvis.orb"].tap()
        cue("voice_listening")
        sleep(4)
        app.otherElements["jarvis.orb"].tap()
        cue("voice_reply")
        sleep(7)
        app.buttons["jarvis.meshMenu"].tap()
        XCTAssertTrue(app.buttons["Settings"].waitForExistence(timeout: 5))
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["jarvis.settings.header"].waitForExistence(timeout: 5))
        cue("settings")
        sleep(5)
        app.swipeUp()
        cue("settings_scroll")
        sleep(4)
        cue("end")
    }
}
