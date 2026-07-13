import XCTest
@testable import JarvisXR

final class VisionSpeechAndHapticsTests: XCTestCase {
    func testQuietGuideKeepsEssentialSystemStatusButSuppressesAmbientSceneSpeech() {
        let systemStatus = makeNarration(
            "Live Guide is active.",
            priority: .ambient,
            contentKind: .system
        )
        let ambientScene = makeNarration(
            "A chair remains near the center.",
            priority: .ambient,
            contentKind: .scene
        )

        XCTAssertFalse(JarvisSpeechService.shouldSuppressVisionNarration(systemStatus, quietModeEnabled: true))
        XCTAssertTrue(JarvisSpeechService.shouldSuppressVisionNarration(ambientScene, quietModeEnabled: true))
        XCTAssertFalse(JarvisSpeechService.shouldSuppressVisionNarration(ambientScene, quietModeEnabled: false))
    }

    func testHigherPriorityNarrationInterruptsAndMovesToFront() {
        let sessionID = UUID()
        let now = Date()
        var queue = VisionSpeechPriorityQueue()
        queue.beginSession(sessionID)

        let ambient = item(
            "A chair is near the center.",
            priority: .ambient,
            sessionID: sessionID,
            createdAt: now
        )
        XCTAssertEqual(queue.enqueue(ambient, current: nil, at: now), .queued)
        let current = queue.next(at: now)
        XCTAssertEqual(current, ambient)

        let warning = item(
            "Possible obstruction near the center.",
            priority: .warning,
            sessionID: sessionID,
            createdAt: now.addingTimeInterval(0.1)
        )
        XCTAssertEqual(queue.enqueue(warning, current: current, at: now), .interruptCurrent)
        XCTAssertEqual(queue.next(at: now), warning)
    }

    func testRepeatedLowPriorityNarrationIsSuppressed() {
        let sessionID = UUID()
        let now = Date()
        var queue = VisionSpeechPriorityQueue(duplicateSuppressionInterval: 5)
        queue.beginSession(sessionID)
        let first = item("Chair on the left.", priority: .ambient, sessionID: sessionID, createdAt: now)

        XCTAssertEqual(queue.enqueue(first, current: nil, at: now), .queued)
        let spoken = try! XCTUnwrap(queue.next(at: now))
        queue.markCompleted(spoken, at: now)

        let repeated = item(
            "  chair   on the LEFT. ",
            priority: .ambient,
            sessionID: sessionID,
            createdAt: now.addingTimeInterval(1)
        )
        XCTAssertEqual(
            queue.enqueue(repeated, current: nil, at: now.addingTimeInterval(1)),
            .suppressedDuplicate
        )
    }

    func testModeChangeRejectsStaleSpeechAndCancellationEmptiesQueue() {
        let firstSession = UUID()
        let secondSession = UUID()
        let now = Date()
        var queue = VisionSpeechPriorityQueue()
        queue.beginSession(firstSession)
        let stale = item("Old frame result.", priority: .prominent, sessionID: firstSession, createdAt: now)
        XCTAssertEqual(queue.enqueue(stale, current: nil, at: now), .queued)

        queue.beginSession(secondSession)
        XCTAssertEqual(queue.enqueue(stale, current: nil, at: now), .rejectedStaleSession)
        XCTAssertNil(queue.next(at: now))

        let current = item("New frame result.", priority: .target, sessionID: secondSession, createdAt: now)
        XCTAssertEqual(queue.enqueue(current, current: nil, at: now), .queued)
        queue.cancelSession(secondSession)
        XCTAssertNil(queue.activeSessionID)
        XCTAssertNil(queue.next(at: now))
    }

    func testExpiredNarrationCannotEnterQueue() {
        let sessionID = UUID()
        let now = Date()
        var queue = VisionSpeechPriorityQueue()
        queue.beginSession(sessionID)
        let narration = makeNarration("Expired.", priority: .ambient, createdAt: now.addingTimeInterval(-10))
        let expired = VisionSpeechQueueItem(
            sessionID: sessionID,
            narration: narration,
            expiresAt: now.addingTimeInterval(-1)
        )
        XCTAssertEqual(queue.enqueue(expired, current: nil, at: now), .rejectedExpired)
    }

    @MainActor
    func testHapticVocabularyIsDistinctAndBackendReportsHonestly() {
        XCTAssertEqual(VisionHapticCue.allCases.count, 7)
        XCTAssertEqual(Set(VisionHapticCue.allCases.map(\.accessibilityLabel)).count, 7)
        XCTAssertNotEqual(VisionHapticCue.directionLeft.pulses, VisionHapticCue.directionCenter.pulses)
        XCTAssertNotEqual(VisionHapticCue.directionCenter.pulses, VisionHapticCue.directionRight.pulses)
        XCTAssertNotEqual(VisionHapticCue.targetAcquired.pulses, VisionHapticCue.targetLost.pulses)

        let backend = VisionHapticsService().backend
        XCTAssertTrue(VisionHapticsBackendKind.allCases.contains(backend))
    }

    private func item(
        _ text: String,
        priority: SpeechPriority,
        sessionID: UUID,
        createdAt: Date
    ) -> VisionSpeechQueueItem {
        VisionSpeechQueueItem(
            sessionID: sessionID,
            narration: makeNarration(text, priority: priority, createdAt: createdAt)
        )
    }

    private func makeNarration(
        _ text: String,
        priority: SpeechPriority,
        createdAt: Date = Date(),
        contentKind: NarrationContentKind = .scene
    ) -> SceneNarration {
        SceneNarration(
            snapshotIdentifier: UUID(),
            text: text,
            priority: priority,
            verbosity: .standard,
            contentKind: contentKind,
            createdAt: createdAt
        )
    }
}
