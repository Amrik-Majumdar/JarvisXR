import Foundation

struct SceneFusionConfiguration: Codable, Equatable, Sendable {
    var maximumObjectsPerSnapshot: Int
    var maximumTextObservationsPerSnapshot: Int
    var maximumBarcodesPerSnapshot: Int

    init(
        maximumObjectsPerSnapshot: Int = 8,
        maximumTextObservationsPerSnapshot: Int = 4,
        maximumBarcodesPerSnapshot: Int = 3
    ) {
        self.maximumObjectsPerSnapshot = max(1, maximumObjectsPerSnapshot)
        self.maximumTextObservationsPerSnapshot = max(0, maximumTextObservationsPerSnapshot)
        self.maximumBarcodesPerSnapshot = max(0, maximumBarcodesPerSnapshot)
    }
}

final class SceneFusionEngine {
    let configuration: SceneFusionConfiguration
    private(set) var lastSnapshot: SceneSnapshot?

    init(configuration: SceneFusionConfiguration = SceneFusionConfiguration()) {
        self.configuration = configuration
    }

    func fuse(
        mode: VisionMode,
        trackingUpdate: TrackingUpdate,
        text: [TextObservation] = [],
        barcodes: [BarcodeObservation] = [],
        people: [PersonObservation] = [],
        quality: CameraQualityReport,
        at timestamp: Date = Date()
    ) -> SceneSnapshot {
        let rankedObjects = trackingUpdate.confirmed
            .sorted(by: Self.relevanceOrder)
            .prefix(configuration.maximumObjectsPerSnapshot)

        let orderedText = text
            .sorted {
                if $0.boundingBox.maxY == $1.boundingBox.maxY {
                    return $0.boundingBox.minX < $1.boundingBox.minX
                }
                return $0.boundingBox.maxY > $1.boundingBox.maxY
            }
            .prefix(configuration.maximumTextObservationsPerSnapshot)

        let orderedBarcodes = barcodes
            .sorted {
                if $0.confidence == $1.confidence {
                    return $0.id.uuidString < $1.id.uuidString
                }
                return $0.confidence > $1.confidence
            }
            .prefix(configuration.maximumBarcodesPerSnapshot)

        let orderedPeople = people.sorted {
            if $0.confidence == $1.confidence {
                return $0.id.uuidString < $1.id.uuidString
            }
            return $0.confidence > $1.confidence
        }

        let snapshot = SceneSnapshot(
            mode: mode,
            capturedAt: timestamp,
            objects: Array(rankedObjects),
            text: Array(orderedText),
            barcodes: Array(orderedBarcodes),
            people: orderedPeople,
            quality: quality,
            changes: trackingUpdate.changes
        )
        lastSnapshot = snapshot
        return snapshot
    }

    func reset() {
        lastSnapshot = nil
    }

    private static func relevanceOrder(_ lhs: TrackedObservation, _ rhs: TrackedObservation) -> Bool {
        let left = relevanceScore(lhs)
        let right = relevanceScore(rhs)
        if left == right {
            return lhs.trackIdentifier.uuidString < rhs.trackIdentifier.uuidString
        }
        return left > right
    }

    private static func relevanceScore(_ value: TrackedObservation) -> Double {
        var score = value.smoothedConfidence * 100
        score += min(value.smoothedBoundingBox.area, 1) * 90
        if value.observation.isRequested { score += 1_000 }
        if value.classIdentifier == "person" { score += 300 }
        if value.observation.mayBeSafetyRelevant { score += 180 }
        if value.horizontalRegion == .center { score += 35 }
        if value.observation.motionState == .approaching { score += 80 }
        return score
    }
}

extension SceneSnapshot {
    func objects(in region: SpatialRegion) -> [TrackedObservation] {
        objects.filter { $0.horizontalRegion == region }
    }

    func object(classIdentifier: String) -> TrackedObservation? {
        objects.first { $0.classIdentifier == classIdentifier }
    }
}
