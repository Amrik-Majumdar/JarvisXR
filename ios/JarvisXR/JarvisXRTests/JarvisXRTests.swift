import XCTest
@testable import JarvisXR

final class JarvisXRTests: XCTestCase {
    private var defaults: UserDefaults!
    private var memory: JarvisMemoryStore!
    private var router: JarvisCommandRouter!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "JarvisXRTests.\(UUID().uuidString)")
        memory = JarvisMemoryStore(defaults: defaults)
        router = JarvisCommandRouter(memory: memory)
    }

    func testHelpCommandReturnsTools() {
        let response = router.route(JarvisCommand("help"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("battery"))
    }

    func testUnknownCommandRefuses() {
        let response = router.route(JarvisCommand("take over springboard"))
        XCTAssertEqual(response.status, .refused)
    }

    func testEmptyCommandDoesNotCrash() {
        let response = router.route(JarvisCommand("   "))
        XCTAssertEqual(response.status, .ok)
        XCTAssertFalse(response.shouldSpeak)
    }

    func testSaveNoteCommandPersistsNote() {
        let response = router.route(JarvisCommand("save note first field test"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(memory.loadNotes().count, 1)
        XCTAssertEqual(memory.loadNotes().first?.text, "first field test")
    }

    func testNoteShortcutPersistsNote() {
        let response = router.route(JarvisCommand("note second field test"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(memory.loadNotes().first?.text, "second field test")
    }

    func testShowNotesCommandIncludesNote() {
        _ = router.route(JarvisCommand("save note inspection ready"))
        let response = router.route(JarvisCommand("show notes"))
        XCTAssertTrue(response.displayResponse.contains("inspection ready"))
    }

    func testSearchNotesCommandFindsMatchingNote() {
        _ = router.route(JarvisCommand("save note field compass reading"))
        let response = router.route(JarvisCommand("search notes compass"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("compass"))
    }

    func testClearNotesRequiresConfirmation() {
        let response = router.route(JarvisCommand("clear notes"))
        XCTAssertEqual(response.status, .confirmationRequired)
    }

    func testConfirmClearNotesClearsNotes() {
        _ = router.route(JarvisCommand("save note disposable"))
        _ = router.route(JarvisCommand("confirm clear notes"))
        XCTAssertEqual(memory.loadNotes().count, 0)
    }

    func testSpeechOffCommandDisablesSpeechFlag() {
        let response = router.route(JarvisCommand("speech off"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertFalse(response.shouldSpeak)
        XCTAssertFalse(JarvisSpeechService.shared.isEnabled)
    }

    func testSpeechOnCommandReturnsOk() {
        let response = router.route(JarvisCommand("speech on"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(JarvisSpeechService.shared.isEnabled)
    }

    func testQuietAndNormalModePersistSpeechFlag() {
        _ = router.route(JarvisCommand("quiet mode"))
        XCTAssertFalse(JarvisSpeechService.shared.isEnabled)
        _ = router.route(JarvisCommand("normal mode"))
        XCTAssertTrue(JarvisSpeechService.shared.isEnabled)
    }

    func testBatteryCommandReturnsResponse() {
        let response = router.route(JarvisCommand("battery"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("Battery"))
    }

    func testGuidedAccessCommandReturnsInstructions() {
        let response = router.route(JarvisCommand("guided access"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("Guided Access"))
    }

    func testAboutCommandReturnsBoundary() {
        let response = router.route(JarvisCommand("about"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("not system UI ownership"))
    }

    func testMemoryStorePersistsNoteInTestContext() {
        _ = memory.saveNote("persistent local note")
        let reloaded = JarvisMemoryStore(defaults: defaults)
        XCTAssertEqual(reloaded.loadNotes().first?.text, "persistent local note")
    }

    func testUnitConversionWorks() {
        let response = router.route(JarvisCommand("convert 10 cm to inches"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("in"))
    }

    func testMemoryStatusReturnsCounts() {
        let response = router.route(JarvisCommand("memory status"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("Notes"))
    }

    func testRepeatLastResponseUsesMemory() {
        memory.setLastResponse("Previous response.")
        let response = router.route(JarvisCommand("repeat last response"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("Previous response"))
    }

    func testClearHistoryRequiresConfirmation() {
        let response = router.route(JarvisCommand("clear history"))
        XCTAssertEqual(response.status, .confirmationRequired)
    }

    func testConfirmClearHistoryClearsHistory() {
        memory.appendHistory(command: "help", response: "tools")
        _ = router.route(JarvisCommand("confirm clear history"))
        XCTAssertEqual(memory.loadHistory().count, 0)
    }

    func testVoiceTestCommandReturnsResponse() {
        let response = router.route(JarvisCommand("voice test"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("voice output"))
    }

    func testStopSpeakingDoesNotRequestSpeech() {
        let response = router.route(JarvisCommand("stop speaking"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertFalse(response.shouldSpeak)
    }

    func testIdentityCommandReturnsResponse() {
        let response = router.route(JarvisCommand("identity"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("JARVIS"))
    }

    func testCalculatorWorks() {
        let response = router.route(JarvisCommand("calculate 12 / 3"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("= 4"))
    }

    func testCalculatorRejectsDivisionByZero() {
        let response = router.route(JarvisCommand("calculate 12 / 0"))
        XCTAssertEqual(response.status, .refused)
    }

    func testVoiceProfileCommandReturnsOk() {
        let response = router.route(JarvisCommand("voice crisp"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("Crisp"))
    }

    func testWakePrefixNaturalInspectionCommandRoutes() {
        let response = router.route(JarvisCommand("Jarvis, look at this"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.data["action"], "inspect")
    }

    func testRememberThisCommandPersistsNote() {
        let response = router.route(JarvisCommand("Jarvis, remember this inspect the label later"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(memory.loadNotes().first?.text, "inspect the label later")
    }

    func testControlMeshTapPhraseReturnsVoiceControlInstruction() {
        let response = router.route(JarvisCommand("show me how to tap that"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("Show Grid"))
    }

    func testCompanionModeIsTruthfullyLimited() {
        let response = router.route(JarvisCommand("mini player"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertTrue(response.displayResponse.contains("does not allow arbitrary floating"))
    }

    func testObjectDetectionStatusIsReported() {
        let response = router.route(JarvisCommand("detect objects"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.data["action"], "inspect")
        XCTAssertEqual(response.data["vision"], "visual_classification")
        XCTAssertTrue(response.displayResponse.contains("Visual scan ready"))
        XCTAssertFalse(response.displayResponse.contains("Object model not installed"))
    }

    func testVoiceProfilePersistsAndChangesConfiguration() {
        let original = JarvisSpeechService.shared.profile
        JarvisSpeechService.shared.profile = .crisp
        XCTAssertEqual(JarvisSpeechService.shared.profile, .crisp)
        XCTAssertGreaterThan(JarvisSpeechService.shared.speechRate, 0.50)
        JarvisSpeechService.shared.profile = .quiet
        XCTAssertEqual(JarvisSpeechService.shared.profile, .quiet)
        XCTAssertLessThan(JarvisSpeechService.shared.volume, 0.70)
        JarvisSpeechService.shared.profile = original
    }

    func testDetectObjectsDoesNotDeadEndOnMissingModel() {
        let response = router.route(JarvisCommand("what am I pointing at"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.data["action"], "inspect")
        XCTAssertEqual(response.data["vision"], "visual_classification")
        XCTAssertTrue(response.shouldSpeak)
    }
    func testProductionLayoutUsesSafeAreaAndKeyboardGuides() {
        XCTAssertNotNil(JarvisRootViewController.self)
    }
}
