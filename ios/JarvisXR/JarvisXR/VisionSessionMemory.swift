import Foundation

struct VisionSessionMemoryState: Equatable, Sendable {
    let snapshotCount: Int
    let narrationCount: Int
    let latestSnapshotIdentifier: UUID?
    let latestNarrationIdentifier: UUID?
}

/// Bounded, process-memory-only storage for the active vision session.
/// It has no image field and performs no file or UserDefaults writes.
final class VisionSessionMemory: @unchecked Sendable {
    let maxSnapshots: Int
    let maxNarrations: Int
    let retentionInterval: TimeInterval

    let persistsImages = false
    let usesPersistentStorage = false

    private let lock = NSLock()
    private var snapshots: [SceneSnapshot] = []
    private var narrations: [SceneNarration] = []

    init(
        maxSnapshots: Int = 12,
        maxNarrations: Int = 20,
        retentionInterval: TimeInterval = 120
    ) {
        self.maxSnapshots = max(1, maxSnapshots)
        self.maxNarrations = max(1, maxNarrations)
        self.retentionInterval = max(1, retentionInterval)
    }

    func record(snapshot: SceneSnapshot) {
        withLock {
            pruneLocked(referenceDate: snapshot.capturedAt)
            snapshots.append(snapshot)
            if snapshots.count > maxSnapshots {
                snapshots.removeFirst(snapshots.count - maxSnapshots)
            }
        }
    }

    func record(narration: SceneNarration) {
        withLock {
            pruneLocked(referenceDate: narration.createdAt)
            narrations.append(narration)
            if narrations.count > maxNarrations {
                narrations.removeFirst(narrations.count - maxNarrations)
            }
        }
    }

    func latestSnapshot(at date: Date = Date()) -> SceneSnapshot? {
        withLock {
            pruneLocked(referenceDate: date)
            return snapshots.last
        }
    }

    func lastNarration(at date: Date = Date()) -> SceneNarration? {
        withLock {
            pruneLocked(referenceDate: date)
            return narrations.last
        }
    }

    func changes(since date: Date, at referenceDate: Date = Date()) -> [SceneChange] {
        withLock {
            pruneLocked(referenceDate: referenceDate)
            return snapshots
                .flatMap(\.changes)
                .filter { $0.occurredAt >= date }
                .sorted { $0.occurredAt < $1.occurredAt }
        }
    }

    func lastSeen(classIdentifier: String, at date: Date = Date()) -> TrackedObservation? {
        withLock {
            pruneLocked(referenceDate: date)
            for snapshot in snapshots.reversed() {
                if let observation = snapshot.objects.first(where: { $0.classIdentifier == classIdentifier }) {
                    return observation
                }
            }
            return nil
        }
    }

    func state(at date: Date = Date()) -> VisionSessionMemoryState {
        withLock {
            pruneLocked(referenceDate: date)
            return VisionSessionMemoryState(
                snapshotCount: snapshots.count,
                narrationCount: narrations.count,
                latestSnapshotIdentifier: snapshots.last?.id,
                latestNarrationIdentifier: narrations.last?.id
            )
        }
    }

    func clear() {
        withLock {
            snapshots.removeAll(keepingCapacity: false)
            narrations.removeAll(keepingCapacity: false)
        }
    }

    private func pruneLocked(referenceDate: Date) {
        let cutoff = referenceDate.addingTimeInterval(-retentionInterval)
        snapshots.removeAll { $0.capturedAt < cutoff }
        narrations.removeAll { $0.createdAt < cutoff }
    }

    @discardableResult
    private func withLock<T>(_ work: () -> T) -> T {
        lock.lock()
        defer { lock.unlock() }
        return work()
    }
}
