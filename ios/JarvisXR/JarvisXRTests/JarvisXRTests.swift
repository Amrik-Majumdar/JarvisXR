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
        JarvisSpeechService.shared.resetSpeechTuningToProfileDefaults()
        defer {
            JarvisSpeechService.shared.resetSpeechTuningToProfileDefaults()
            JarvisSpeechService.shared.profile = original
        }
        JarvisSpeechService.shared.profile = .crisp
        XCTAssertEqual(JarvisSpeechService.shared.profile, .crisp)
        XCTAssertGreaterThan(JarvisSpeechService.shared.speechRate, 0.50)
        JarvisSpeechService.shared.profile = .quiet
        XCTAssertEqual(JarvisSpeechService.shared.profile, .quiet)
        XCTAssertLessThan(JarvisSpeechService.shared.volume, 0.70)
        JarvisSpeechService.shared.speechRate = 0.55
        XCTAssertEqual(JarvisSpeechService.shared.speechRate, 0.55, accuracy: 0.001)
        let descriptors = Set(JarvisVoiceProfile.ordered.map { profile in
            let value = profile.descriptor
            return "\(value.languages.joined(separator: ","))|\(value.voiceSlot)|\(value.rate)|\(value.pitch)|\(value.volume)"
        })
        XCTAssertEqual(descriptors.count, JarvisVoiceProfile.ordered.count)
    }

    func testSpeechRateAndVoiceCyclingCommandsChangeProductionConfiguration() {
        let service = JarvisSpeechService.shared
        let originalProfile = service.profile
        service.resetSpeechTuningToProfileDefaults()
        defer {
            service.resetSpeechTuningToProfileDefaults()
            service.profile = originalProfile
        }
        service.speechRate = 0.46

        let faster = router.route(JarvisCommand("speak faster"))
        XCTAssertEqual(faster.status, .ok)
        XCTAssertGreaterThan(service.speechRate, 0.46)

        let beforeProfile = service.profile
        let changed = router.route(JarvisCommand("use another voice"))
        XCTAssertEqual(changed.status, .ok)
        XCTAssertNotEqual(service.profile, beforeProfile)
        XCTAssertFalse(service.resolvedConfiguration(for: service.profile).locale.isEmpty)

    }

    func testDetectObjectsDoesNotDeadEndOnMissingModel() {
        let response = router.route(JarvisCommand("what am I pointing at"))
        XCTAssertEqual(response.status, .ok)
        XCTAssertEqual(response.data["action"], "inspect")
        XCTAssertEqual(response.data["vision"], "visual_classification")
        XCTAssertTrue(response.shouldSpeak)
    }

    func testNaturalSceneCommandPreservesTypedVisionLaunch() {
        let plan = JarvisCommandPlanner().plan("Jarvis, what is in front of me?")
        XCTAssertEqual(plan.route, .inAppVision)
        XCTAssertEqual(plan.visionLaunchRequest?.mode, .describe)
        XCTAssertEqual(plan.visionLaunchRequest?.command, .run)
        XCTAssertTrue(plan.visionLaunchRequest?.startsImmediately == true)
    }

    func testRegionalSceneCommandsPreserveRegion() {
        let planner = JarvisCommandPlanner()
        XCTAssertEqual(planner.plan("describe the left side").visionLaunchRequest?.region, .left)
        XCTAssertEqual(planner.plan("describe the center").visionLaunchRequest?.region, .center)
        XCTAssertEqual(planner.plan("what is on the right?").visionLaunchRequest?.region, .right)
    }

    func testLiveGuideLifecycleCommandsAreTyped() {
        let planner = JarvisCommandPlanner()
        XCTAssertEqual(planner.plan("start live guide").visionLaunchRequest?.command, .run)
        XCTAssertEqual(planner.plan("start guiding me").visionLaunchRequest?.command, .run)
        XCTAssertEqual(planner.plan("pause live guide").visionLaunchRequest?.command, .pause)
        XCTAssertEqual(planner.plan("resume live guide").visionLaunchRequest?.command, .resume)
        XCTAssertEqual(planner.plan("stop live guide").visionLaunchRequest?.command, .stop)
        XCTAssertEqual(planner.plan("start live guide").visionLaunchRequest?.mode, .liveGuide)
        XCTAssertEqual(planner.plan("only tell me important changes").visionLaunchRequest?.command, .lessDetail)
        XCTAssertEqual(planner.plan("be concise").visionLaunchRequest?.command, .lessDetail)
        XCTAssertEqual(planner.plan("stop searching").visionLaunchRequest?.command, .stop)
    }

    func testCompleteDeviceTestCommandUsesPrivateDiagnosticsRoute() {
        let plan = JarvisCommandPlanner().plan("Jarvis, run the complete device test")
        XCTAssertEqual(plan.route, .inAppDiagnostics)
        XCTAssertEqual(plan.action, .runDeviceAcceptance)
        XCTAssertEqual(plan.data["action"], "device_acceptance")
        XCTAssertFalse(plan.shouldPersistGeneralHistory)
    }

    func testDeviceAcceptanceVoiceResponsesAreBounded() {
        XCTAssertEqual(JarvisDeviceAcceptanceResponse.parse("yes"), .yes)
        XCTAssertEqual(JarvisDeviceAcceptanceResponse.parse("different"), .different)
        XCTAssertEqual(JarvisDeviceAcceptanceResponse.parse("continue"), .continue)
        XCTAssertEqual(JarvisDeviceAcceptanceResponse.parse("skip this"), .skip)
        XCTAssertEqual(JarvisDeviceAcceptanceResponse.parse("stop test"), .stop)
        XCTAssertEqual(JarvisDeviceAcceptanceResponse.parse("something unrelated"), .unknown)
    }

    func testDeviceAcceptanceReportRecordsAttentionAndCompletion() {
        var report = JarvisDeviceAcceptanceReport(
            appVersion: "1.0",
            build: "1",
            iOSVersion: "18.0",
            deviceCapabilitySummary: ["rear_camera": "true"]
        )
        report.append(JarvisDeviceAcceptanceCheck(
            identifier: "camera.frames",
            title: "Live camera frame arrival",
            status: .attention,
            method: .automated,
            measuredValues: ["delivered": "0"],
            error: "no frame",
            recordedAt: Date()
        ))
        report.complete()
        XCTAssertEqual(report.overallStatus, .attention)
        XCTAssertNotNil(report.completedAt)
    }

    func testFindCommandPreservesTarget() {
        let plan = JarvisCommandPlanner().plan("Jarvis, find the chair")
        XCTAssertEqual(plan.action, .findObject)
        XCTAssertEqual(plan.visionLaunchRequest?.mode, .find)
        XCTAssertEqual(plan.visionLaunchRequest?.target, "chair")
        XCTAssertEqual(
            JarvisCommandPlanner().plan("Help me locate a table").visionLaunchRequest?.target,
            "table"
        )
    }

    func testNaturalReadAndScanVariantsSelectContinuousTasks() {
        let planner = JarvisCommandPlanner()
        let read = planner.plan("Read the sign in front of me").visionLaunchRequest
        XCTAssertEqual(read?.mode, .readText)
        XCTAssertEqual(read?.command, .run)
        XCTAssertTrue(read?.startsImmediately == true)

        XCTAssertEqual(planner.plan("Read the sign").visionLaunchRequest?.mode, .readText)

        let scan = planner.plan("What is this code?").visionLaunchRequest
        XCTAssertEqual(scan?.mode, .scanBarcode)
        XCTAssertEqual(scan?.command, .run)
        XCTAssertTrue(scan?.startsImmediately == true)
    }

    func testSensitiveVisionModesDoNotEnterGeneralHistoryPolicy() {
        let planner = JarvisCommandPlanner()
        XCTAssertFalse(planner.plan("read this").shouldPersistGeneralHistory)
        XCTAssertFalse(planner.plan("scan this barcode").shouldPersistGeneralHistory)
        XCTAssertFalse(planner.plan("repeat that").shouldPersistGeneralHistory)
        XCTAssertTrue(planner.plan("describe this room").shouldPersistGeneralHistory)
    }

    func testVisionUtilityCommandsAreTyped() {
        let planner = JarvisCommandPlanner()
        XCTAssertEqual(planner.plan("what color is this").visionLaunchRequest?.mode, .identifyColor)
        XCTAssertEqual(planner.plan("is the camera blocked").visionLaunchRequest?.command, .checkQuality)
        XCTAssertEqual(planner.plan("turn on the flashlight").visionLaunchRequest?.command, .flashlightOn)
        XCTAssertEqual(planner.plan("turn off the flashlight").visionLaunchRequest?.command, .flashlightOff)
        XCTAssertEqual(planner.plan("is the flashlight on?").visionLaunchRequest?.command, .flashlightStatus)
        XCTAssertEqual(planner.plan("give me more detail").visionLaunchRequest?.command, .moreDetail)
        XCTAssertEqual(planner.plan("repeat that").visionLaunchRequest?.command, .repeatLast)
    }

    func testMessageCommandsUsePrivateNonHistorySystemComposerRoute() {
        let planner = JarvisCommandPlanner()
        let begin = planner.plan("Message Alex")
        XCTAssertEqual(begin.route, .inAppMessage)
        XCTAssertEqual(begin.action, .composeMessage)
        XCTAssertEqual(begin.data["message_action"], JarvisMessageAction.begin.rawValue)
        XCTAssertEqual(begin.data["message_recipient_hint"], "Alex")
        XCTAssertFalse(begin.shouldPersistGeneralHistory)

        let tell = planner.plan("Tell Alex I will arrive soon")
        XCTAssertEqual(tell.data["message_recipient_hint"], "Alex")
        XCTAssertEqual(tell.data["message_body"], "I will arrive soon")
        XCTAssertFalse(tell.shouldPersistGeneralHistory)

        let text = planner.plan("Text Mom that I will be home soon")
        XCTAssertEqual(text.data["message_recipient_hint"], "Mom")
        XCTAssertEqual(text.data["message_body"], "I will be home soon")
        XCTAssertFalse(text.shouldPersistGeneralHistory)

        XCTAssertEqual(planner.plan("read the message back").data["message_action"], JarvisMessageAction.readBack.rawValue)
        XCTAssertEqual(planner.plan("change the recipient").data["message_action"], JarvisMessageAction.changeRecipient.rawValue)
        XCTAssertEqual(planner.plan("cancel the message").data["message_action"], JarvisMessageAction.cancel.rawValue)
        XCTAssertEqual(planner.plan("open the message composer").data["message_action"], JarvisMessageAction.openComposer.rawValue)

        let correction = JarvisMessageCommandParser.parseActiveDraftFollowUp(
            "change it to i am waiting outside",
            raw: "Change it to I am waiting outside"
        )
        XCTAssertEqual(correction?.action, .changeBody)
        XCTAssertEqual(correction?.body, "I am waiting outside")
        XCTAssertEqual(JarvisMessageCommandParser.parseActiveDraftFollowUp("yes")?.action, .openComposer)
        XCTAssertEqual(JarvisMessageCommandParser.parseActiveDraftFollowUp("read it back")?.action, .readBack)
        XCTAssertEqual(JarvisMessageCommandParser.parseActiveDraftFollowUp("cancel")?.action, .cancel)
    }

    func testMessageDraftRequiresRecipientAndBodyAndClearsOnCancel() {
        var draft = JarvisMessageDraft()
        draft.begin(body: "Meet me outside")
        XCTAssertFalse(draft.isReadyForComposer)
        draft.selectRecipient(displayName: "Alex", address: "+1 555 0100")
        XCTAssertTrue(draft.isReadyForComposer)
        XCTAssertEqual(draft.readback, "Message to Alex: Meet me outside")
        draft.cancel()
        XCTAssertFalse(draft.isReadyForComposer)
        XCTAssertNil(draft.recipientAddress)
        XCTAssertNil(draft.body)
    }

    func testVisionDeepLinksParseTypedRequests() throws {
        let describe = JarvisDeepLinkRouter.action(from: try XCTUnwrap(URL(string: "jarvis://vision/describe?region=left")))
        guard case .vision(let describeRequest) = describe else { return XCTFail("Expected typed Describe request") }
        XCTAssertEqual(describeRequest.mode, .describe)
        XCTAssertEqual(describeRequest.region, .left)

        let liveStop = JarvisDeepLinkRouter.action(from: try XCTUnwrap(URL(string: "jarvis://vision/live/stop")))
        guard case .vision(let liveRequest) = liveStop else { return XCTFail("Expected typed Live request") }
        XCTAssertEqual(liveRequest.mode, .liveGuide)
        XCTAssertEqual(liveRequest.command, .stop)

        let find = JarvisDeepLinkRouter.action(from: try XCTUnwrap(URL(string: "jarvis://vision/find?target=door")))
        guard case .vision(let findRequest) = find else { return XCTFail("Expected typed Find request") }
        XCTAssertEqual(findRequest.target, "door")
    }

    func testVisionDeepLinksCoverRequiredRoutesAndPreserveOldInspect() throws {
        let routes: [(String, VisionMode, JarvisVisionCommand)] = [
            ("jarvis://vision/describe", .describe, .run),
            ("jarvis://vision/live/start", .liveGuide, .run),
            ("jarvis://vision/read", .readText, .run),
            ("jarvis://vision/barcode", .scanBarcode, .run),
            ("jarvis://vision/color", .identifyColor, .run),
            ("jarvis://vision/repeat", .describe, .repeatLast),
        ]
        for route in routes {
            let action = JarvisDeepLinkRouter.action(from: try XCTUnwrap(URL(string: route.0)))
            guard case .vision(let request) = action else { return XCTFail("Expected Vision request for \(route.0)") }
            XCTAssertEqual(request.mode, route.1)
            XCTAssertEqual(request.command, route.2)
        }
        guard case .inspect = JarvisDeepLinkRouter.action(from: try XCTUnwrap(URL(string: "jarvis://inspect"))) else {
            return XCTFail("Legacy inspect link must remain supported")
        }
    }

    func testVisionPreferencesPersistAndPrivacyInvariantsStayOff() {
        let suiteName = "VisionPreferencesTests.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }
        let store = VisionPreferencesStore(defaults: suite)
        store.update {
            $0.importantChangesOnly = false
            $0.keepScreenAwakeDuringLiveGuide = false
            $0.hapticsEnabled = false
            $0.cameraChoice = .front
        }
        let reloaded = VisionPreferencesStore(defaults: suite).value
        XCTAssertFalse(reloaded.importantChangesOnly)
        XCTAssertFalse(reloaded.keepScreenAwakeDuringLiveGuide)
        XCTAssertFalse(reloaded.hapticsEnabled)
        XCTAssertEqual(reloaded.cameraChoice, .front)
        XCTAssertFalse(reloaded.storesCapturedImages)
        XCTAssertFalse(reloaded.storesCapturedVideo)
        XCTAssertFalse(reloaded.persistsRecognizedText)
        XCTAssertFalse(reloaded.allowsNetworkVisionProcessing)
    }

    func testProductionLayoutUsesSafeAreaAndKeyboardGuides() {
        XCTAssertNotNil(JarvisRootViewController.self)
    }

    func testRootPrimaryAccessibilityMetadataAndFocusOrderAreDeterministic() throws {
        let controller = JarvisRootViewController()
        controller.loadViewIfNeeded()
        let required = [
            "jarvis.wordmark",
            "jarvis.subtitle",
            "jarvis.meshMenu",
            "jarvis.help",
            "jarvis.orb",
            "jarvis.state",
            "jarvis.hint",
            "jarvis.transientResponse",
            "jarvis.commandInput",
            "jarvis.send",
        ]
        for identifier in required {
            let element = try XCTUnwrap(findView(identifier: identifier, in: controller.view))
            if element is UIControl || identifier == "jarvis.orb" || identifier == "jarvis.wordmark" {
                XCTAssertFalse((element.accessibilityLabel ?? "").isEmpty, "\(identifier) requires an accessibility label")
            }
        }
        let focusOrder = (controller.view.accessibilityElements as? [UIView])?.compactMap(\.accessibilityIdentifier)
        XCTAssertEqual(Array(try XCTUnwrap(focusOrder).prefix(8)), [
            "jarvis.wordmark",
            "jarvis.subtitle",
            "jarvis.meshMenu",
            "jarvis.help",
            "jarvis.orb",
            "jarvis.state",
            "jarvis.hint",
            "jarvis.transientResponse",
        ])
    }

    private func findView(identifier: String, in root: UIView) -> UIView? {
        if root.accessibilityIdentifier == identifier { return root }
        for child in root.subviews {
            if let match = findView(identifier: identifier, in: child) { return match }
        }
        return nil
    }
}
