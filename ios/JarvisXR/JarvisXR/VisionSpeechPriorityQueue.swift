import Foundation

struct VisionSpeechQueueItem: Equatable, Sendable {
    let id: UUID
    let sessionID: UUID
    let narration: SceneNarration
    let expiresAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        narration: SceneNarration,
        expiresAt: Date? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.narration = narration
        self.expiresAt = expiresAt ?? narration.createdAt.addingTimeInterval(
            Self.lifetime(for: narration.priority)
        )
    }

    private static func lifetime(for priority: SpeechPriority) -> TimeInterval {
        switch priority {
        case .warning, .target: return 4.0
        case .change, .prominent: return 2.8
        case .ambient: return 1.8
        case .diagnostics: return 1.2
        }
    }
}

enum VisionSpeechEnqueueDisposition: Equatable, Sendable {
    case queued
    case interruptCurrent
    case suppressedDuplicate
    case suppressedQuietMode
    case rejectedStaleSession
    case rejectedExpired
}

/// Platform-independent queue policy used by the AVSpeechSynthesizer adapter.
/// It is deliberately value-based so ordering, deduplication, interruption, expiry,
/// and session cancellation can be tested without audio hardware.
struct VisionSpeechPriorityQueue: Sendable {
    private(set) var activeSessionID: UUID?
    private(set) var pending: [VisionSpeechQueueItem] = []
    private(set) var lastCompletedText: String?
    private(set) var lastCompletedAt: Date?

    let maximumPendingCount: Int
    let duplicateSuppressionInterval: TimeInterval

    init(maximumPendingCount: Int = 12, duplicateSuppressionInterval: TimeInterval = 4.0) {
        self.maximumPendingCount = max(1, maximumPendingCount)
        self.duplicateSuppressionInterval = max(0, duplicateSuppressionInterval)
    }

    mutating func beginSession(_ sessionID: UUID) {
        activeSessionID = sessionID
        pending.removeAll(keepingCapacity: true)
        lastCompletedText = nil
        lastCompletedAt = nil
    }

    mutating func enqueue(
        _ item: VisionSpeechQueueItem,
        current: VisionSpeechQueueItem?,
        at date: Date = Date()
    ) -> VisionSpeechEnqueueDisposition {
        guard item.sessionID == activeSessionID else {
            return .rejectedStaleSession
        }
        guard item.expiresAt > date else {
            return .rejectedExpired
        }

        discardExpired(at: date)
        let normalized = Self.normalized(item.narration.text)
        guard !normalized.isEmpty else {
            return .suppressedDuplicate
        }
        let repeatsCurrent = current.map { Self.normalized($0.narration.text) == normalized } ?? false
        let repeatsPending = pending.contains { Self.normalized($0.narration.text) == normalized }
        let repeatsRecentCompletion = lastCompletedText.map { Self.normalized($0) == normalized } == true &&
            date.timeIntervalSince(lastCompletedAt ?? .distantPast) < duplicateInterval(for: item.narration.priority)

        if repeatsCurrent || repeatsPending || repeatsRecentCompletion {
            return .suppressedDuplicate
        }

        pending.append(item)
        pending.sort(by: Self.precedes)
        if pending.count > maximumPendingCount {
            pending.removeLast(pending.count - maximumPendingCount)
        }

        if let current,
           item.narration.priority > current.narration.priority {
            return .interruptCurrent
        }
        return .queued
    }

    mutating func next(at date: Date = Date()) -> VisionSpeechQueueItem? {
        discardExpired(at: date)
        guard !pending.isEmpty else { return nil }
        return pending.removeFirst()
    }

    mutating func markCompleted(_ item: VisionSpeechQueueItem, at date: Date = Date()) {
        guard item.sessionID == activeSessionID else { return }
        lastCompletedText = item.narration.text
        lastCompletedAt = date
    }

    mutating func cancelSession(_ sessionID: UUID) {
        guard activeSessionID == sessionID else { return }
        activeSessionID = nil
        pending.removeAll(keepingCapacity: false)
        lastCompletedText = nil
        lastCompletedAt = nil
    }

    mutating func cancelAll() {
        activeSessionID = nil
        pending.removeAll(keepingCapacity: false)
        lastCompletedText = nil
        lastCompletedAt = nil
    }

    private mutating func discardExpired(at date: Date) {
        guard let activeSessionID else {
            pending.removeAll(keepingCapacity: false)
            return
        }
        pending.removeAll { item in
            item.sessionID != activeSessionID || item.expiresAt <= date
        }
    }

    private func duplicateInterval(for priority: SpeechPriority) -> TimeInterval {
        switch priority {
        case .warning, .target:
            return min(0.8, duplicateSuppressionInterval)
        case .change:
            return min(2.0, duplicateSuppressionInterval)
        case .prominent, .ambient, .diagnostics:
            return duplicateSuppressionInterval
        }
    }

    private static func precedes(_ left: VisionSpeechQueueItem, _ right: VisionSpeechQueueItem) -> Bool {
        if left.narration.priority != right.narration.priority {
            return left.narration.priority > right.narration.priority
        }
        if left.narration.createdAt != right.narration.createdAt {
            return left.narration.createdAt < right.narration.createdAt
        }
        return left.id.uuidString < right.id.uuidString
    }

    private static func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .joined(separator: " ")
    }
}
