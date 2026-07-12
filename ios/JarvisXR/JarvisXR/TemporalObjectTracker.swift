import Foundation

struct TemporalObjectTrackerConfiguration: Codable, Equatable, Sendable {
    var minimumConfidence: Double
    var confirmationFrames: Int
    var intersectionOverUnionThreshold: Double
    var maximumMissedFrames: Int
    var maximumTrackAge: TimeInterval
    var smoothingFactor: Double
    var movementThreshold: Double
    var scaleChangeThreshold: Double

    init(
        minimumConfidence: Double = 0.45,
        confirmationFrames: Int = 3,
        intersectionOverUnionThreshold: Double = 0.25,
        maximumMissedFrames: Int = 3,
        maximumTrackAge: TimeInterval = 1.5,
        smoothingFactor: Double = 0.4,
        movementThreshold: Double = 0.07,
        scaleChangeThreshold: Double = 0.18
    ) {
        self.minimumConfidence = min(max(minimumConfidence, 0), 1)
        self.confirmationFrames = max(1, confirmationFrames)
        self.intersectionOverUnionThreshold = min(max(intersectionOverUnionThreshold, 0), 1)
        self.maximumMissedFrames = max(0, maximumMissedFrames)
        self.maximumTrackAge = max(0, maximumTrackAge)
        self.smoothingFactor = min(max(smoothingFactor, 0), 1)
        self.movementThreshold = max(0, movementThreshold)
        self.scaleChangeThreshold = max(0, scaleChangeThreshold)
    }
}

final class TemporalObjectTracker {
    let configuration: TemporalObjectTrackerConfiguration
    private var tracks: [UUID: TrackedObservation] = [:]

    init(configuration: TemporalObjectTrackerConfiguration = TemporalObjectTrackerConfiguration()) {
        self.configuration = configuration
    }

    func update(with observations: [ObjectObservation], at timestamp: Date = Date()) -> TrackingUpdate {
        let validObservations = observations
            .filter {
                $0.confidence.isFinite &&
                    $0.confidence >= configuration.minimumConfidence &&
                    $0.confidence <= 1
            }
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.confidence > $1.confidence
            }

        var unmatchedTrackIdentifiers = Set(tracks.keys)
        var changes: [SceneChange] = []

        for observation in validObservations {
            if let match = bestMatch(for: observation, among: unmatchedTrackIdentifiers) {
                unmatchedTrackIdentifiers.remove(match)
                let previous = tracks[match]!
                let updated = update(previous, with: observation, at: timestamp)
                tracks[match] = updated
                changes.append(change(from: previous, to: updated, at: timestamp))
            } else {
                let created = makeTrack(from: observation, at: timestamp)
                tracks[created.trackIdentifier] = created
                changes.append(
                    SceneChange(
                        kind: created.isConfirmed ? .appeared : .uncertain,
                        trackIdentifier: created.trackIdentifier,
                        classIdentifier: created.classIdentifier,
                        name: created.name,
                        currentRegion: created.horizontalRegion,
                        confidenceBand: .from(created.smoothedConfidence),
                        occurredAt: timestamp
                    )
                )
            }
        }

        for identifier in unmatchedTrackIdentifiers {
            guard var track = tracks[identifier] else { continue }
            track.missedFrameCount += 1
            let elapsed = max(0, timestamp.timeIntervalSince(track.lastSeenAt))
            let expired = track.missedFrameCount > configuration.maximumMissedFrames || elapsed > configuration.maximumTrackAge
            if expired {
                tracks.removeValue(forKey: identifier)
                if track.isConfirmed {
                    changes.append(
                        SceneChange(
                            kind: .lost,
                            trackIdentifier: identifier,
                            classIdentifier: track.classIdentifier,
                            name: track.name,
                            previousRegion: track.horizontalRegion,
                            confidenceBand: .from(track.smoothedConfidence),
                            occurredAt: timestamp
                        )
                    )
                }
            } else {
                tracks[identifier] = track
            }
        }

        let current = tracks.values
            .filter { $0.missedFrameCount == 0 }
            .sorted(by: Self.stableOrder)
        return TrackingUpdate(
            active: current,
            confirmed: current.filter(\.isConfirmed),
            changes: changes.sorted(by: Self.changeOrder),
            timestamp: timestamp
        )
    }

    func reset() {
        tracks.removeAll(keepingCapacity: false)
    }

    func markAnnounced(trackIdentifier: UUID, at date: Date = Date()) {
        guard var track = tracks[trackIdentifier] else { return }
        track.lastAnnouncedAt = date
        track.observation.isNewlyAnnounced = true
        tracks[trackIdentifier] = track
    }

    var activeTracks: [TrackedObservation] {
        tracks.values.sorted(by: Self.stableOrder)
    }

    private func bestMatch(for observation: ObjectObservation, among candidates: Set<UUID>) -> UUID? {
        var bestIdentifier: UUID?
        var bestOverlap = configuration.intersectionOverUnionThreshold

        for identifier in candidates.sorted(by: { $0.uuidString < $1.uuidString }) {
            guard let track = tracks[identifier], track.classIdentifier == observation.classIdentifier else { continue }
            let overlap = track.smoothedBoundingBox.intersectionOverUnion(with: observation.boundingBox)
            if overlap > bestOverlap || (overlap == bestOverlap && bestIdentifier == nil) {
                bestOverlap = overlap
                bestIdentifier = identifier
            }
        }
        return bestIdentifier
    }

    private func makeTrack(from observation: ObjectObservation, at timestamp: Date) -> TrackedObservation {
        let trackIdentifier = UUID()
        var trackedObservation = observation
        trackedObservation.trackIdentifier = trackIdentifier
        trackedObservation.firstSeenAt = timestamp
        trackedObservation.lastSeenAt = timestamp
        trackedObservation.consecutiveFrameCount = 1
        trackedObservation.temporalStability = min(1, 1 / Double(configuration.confirmationFrames))

        return TrackedObservation(
            trackIdentifier: trackIdentifier,
            observation: trackedObservation,
            smoothedBoundingBox: trackedObservation.boundingBox,
            smoothedConfidence: trackedObservation.confidence,
            firstSeenAt: timestamp,
            lastSeenAt: timestamp,
            consecutiveFrameCount: 1,
            missedFrameCount: 0,
            isConfirmed: configuration.confirmationFrames == 1,
            lastAnnouncedAt: nil
        )
    }

    private func update(
        _ previous: TrackedObservation,
        with observation: ObjectObservation,
        at timestamp: Date
    ) -> TrackedObservation {
        let consecutiveFrames = previous.missedFrameCount == 0 ? previous.consecutiveFrameCount + 1 : 1
        let box = previous.smoothedBoundingBox.smoothed(
            toward: observation.boundingBox,
            factor: configuration.smoothingFactor
        )
        let confidence = previous.smoothedConfidence +
            (observation.confidence - previous.smoothedConfidence) * configuration.smoothingFactor
        let motion = motionState(from: previous.smoothedBoundingBox, to: box)

        var currentObservation = observation
        currentObservation.trackIdentifier = previous.trackIdentifier
        currentObservation.confidence = confidence
        currentObservation.confidenceBand = .from(confidence)
        currentObservation.boundingBox = box
        currentObservation.horizontalRegion = box.horizontalRegion
        currentObservation.verticalRegion = box.verticalRegion
        currentObservation.relativeSize = box.area
        currentObservation.motionState = motion
        currentObservation.temporalStability = min(1, Double(consecutiveFrames) / Double(configuration.confirmationFrames))
        currentObservation.firstSeenAt = previous.firstSeenAt
        currentObservation.lastSeenAt = timestamp
        currentObservation.consecutiveFrameCount = consecutiveFrames

        return TrackedObservation(
            trackIdentifier: previous.trackIdentifier,
            observation: currentObservation,
            smoothedBoundingBox: box,
            smoothedConfidence: confidence,
            firstSeenAt: previous.firstSeenAt,
            lastSeenAt: timestamp,
            consecutiveFrameCount: consecutiveFrames,
            missedFrameCount: 0,
            isConfirmed: previous.isConfirmed || consecutiveFrames >= configuration.confirmationFrames,
            lastAnnouncedAt: previous.lastAnnouncedAt
        )
    }

    private func motionState(from oldBox: NormalizedRect, to newBox: NormalizedRect) -> MotionState {
        if oldBox.area > 0 {
            let scaleDelta = (newBox.area - oldBox.area) / oldBox.area
            if scaleDelta >= configuration.scaleChangeThreshold { return .approaching }
            if scaleDelta <= -configuration.scaleChangeThreshold { return .receding }
        }

        let deltaX = newBox.centerX - oldBox.centerX
        let deltaY = newBox.centerY - oldBox.centerY
        if abs(deltaX) < configuration.movementThreshold && abs(deltaY) < configuration.movementThreshold {
            return .stationary
        }
        if abs(deltaX) >= abs(deltaY) {
            return deltaX < 0 ? .movedLeft : .movedRight
        }
        return deltaY < 0 ? .movedDown : .movedUp
    }

    private func change(from previous: TrackedObservation, to current: TrackedObservation, at timestamp: Date) -> SceneChange {
        let kind: SceneChangeKind
        if !previous.isConfirmed && current.isConfirmed {
            kind = .appeared
        } else {
            switch current.observation.motionState {
            case .approaching: kind = .approaching
            case .receding: kind = .receding
            case .movedLeft, .movedRight, .movedUp, .movedDown: kind = .moved
            case .unknown, .stationary: kind = current.isConfirmed ? .persisted : .uncertain
            }
        }

        return SceneChange(
            kind: kind,
            trackIdentifier: current.trackIdentifier,
            classIdentifier: current.classIdentifier,
            name: current.name,
            previousRegion: previous.horizontalRegion,
            currentRegion: current.horizontalRegion,
            confidenceBand: .from(current.smoothedConfidence),
            occurredAt: timestamp
        )
    }

    private static func stableOrder(_ lhs: TrackedObservation, _ rhs: TrackedObservation) -> Bool {
        if lhs.firstSeenAt == rhs.firstSeenAt {
            return lhs.trackIdentifier.uuidString < rhs.trackIdentifier.uuidString
        }
        return lhs.firstSeenAt < rhs.firstSeenAt
    }

    private static func changeOrder(_ lhs: SceneChange, _ rhs: SceneChange) -> Bool {
        if lhs.occurredAt == rhs.occurredAt {
            return lhs.id.uuidString < rhs.id.uuidString
        }
        return lhs.occurredAt < rhs.occurredAt
    }
}
