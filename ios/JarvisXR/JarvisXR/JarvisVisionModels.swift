import CoreGraphics
import Foundation

enum VisionMode: String, Codable, CaseIterable, Sendable {
    case inactive
    case describe
    case liveGuide
    case find
    case readText
    case scanBarcode
    case identifyColor
}

enum VisionSessionState: String, Codable, CaseIterable, Sendable {
    case idle
    case preparing
    case active
    case paused
    case stopping
    case stopped
    case unavailable
    case failed
}

enum VisionAnalyzerSource: String, Codable, CaseIterable, Sendable {
    case objectDetection
    case textRecognition
    case barcodeRecognition
    case faceAndPerson
    case sceneClassification
    case cameraQuality
    case colorAnalysis
}

enum SpatialRegion: String, Codable, CaseIterable, Sendable {
    case left
    case center
    case right

    static func from(normalizedX x: Double) -> SpatialRegion {
        guard x.isFinite else { return .center }
        if x < 1.0 / 3.0 { return .left }
        if x > 2.0 / 3.0 { return .right }
        return .center
    }

    var spokenLocation: String {
        switch self {
        case .left: return "on the left"
        case .center: return "near the center"
        case .right: return "on the right"
        }
    }
}

enum VerticalRegion: String, Codable, CaseIterable, Sendable {
    case high
    case middle
    case low

    /// Uses Vision's normalized coordinate convention after orientation has been corrected.
    static func from(normalizedY y: Double) -> VerticalRegion {
        guard y.isFinite else { return .middle }
        if y < 1.0 / 3.0 { return .low }
        if y > 2.0 / 3.0 { return .high }
        return .middle
    }
}

enum RelativeDistance: String, Codable, CaseIterable, Sendable {
    case unknown
    case possiblyClose
    case fartherAway
}

enum MotionState: String, Codable, CaseIterable, Sendable {
    case unknown
    case stationary
    case movedLeft
    case movedRight
    case movedUp
    case movedDown
    case approaching
    case receding
}

enum ConfidenceBand: String, Codable, CaseIterable, Comparable, Sendable {
    case insufficient
    case low
    case medium
    case high

    static func from(_ confidence: Double) -> ConfidenceBand {
        guard confidence.isFinite, confidence >= 0, confidence <= 1 else {
            return .insufficient
        }
        switch confidence {
        case ..<0.45: return .insufficient
        case ..<0.65: return .low
        case ..<0.82: return .medium
        default: return .high
        }
    }

    private var rank: Int {
        switch self {
        case .insufficient: return 0
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        }
    }

    static func < (lhs: ConfidenceBand, rhs: ConfidenceBand) -> Bool {
        lhs.rank < rhs.rank
    }
}

enum SpeechPriority: Int, Codable, CaseIterable, Comparable, Sendable {
    case diagnostics = 0
    case ambient = 1
    case prominent = 2
    case change = 3
    case target = 4
    case warning = 5

    static func < (lhs: SpeechPriority, rhs: SpeechPriority) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum VisionWarning: String, Codable, CaseIterable, Sendable {
    case possibleObstruction
    case lowLight
    case overexposed
    case blurry
    case cameraCovered
    case excessiveMotion
    case poorFraming
    case thermalDegraded
    case modelUnavailable
    case targetLost
}

enum VisionError: Error, Codable, Equatable, Sendable {
    case cameraPermissionDenied
    case cameraUnavailable
    case cameraInterrupted
    case modelMissing
    case modelChecksumMismatch
    case modelLoadFailed(String)
    case invalidModelOutput
    case insufficientMemory
    case thermalDegraded
    case flashlightUnavailable
    case textRecognitionFailed
    case noTextFound
    case unsupportedTarget(String)
    case targetNotFound(String)
    case speechUnavailable
    case hapticsUnavailable
    case cancelled
}

enum NarrationVerbosity: String, Codable, CaseIterable, Sendable {
    case concise
    case standard
    case detailed
}

enum NarrationContentKind: String, Codable, CaseIterable, Sendable {
    case scene
    case change
    case target
    case reading
    case barcode
    case system
}

struct NormalizedRect: Codable, Equatable, Hashable, Sendable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    init(x: Double, y: Double, width: Double, height: Double) {
        let safeX = Self.unit(x)
        let safeY = Self.unit(y)
        self.x = safeX
        self.y = safeY
        self.width = min(Self.unit(width), 1 - safeX)
        self.height = min(Self.unit(height), 1 - safeY)
    }

    init(_ rect: CGRect) {
        self.init(
            x: rect.origin.x,
            y: rect.origin.y,
            width: rect.size.width,
            height: rect.size.height
        )
    }

    static let zero = NormalizedRect(x: 0, y: 0, width: 0, height: 0)

    var cgRect: CGRect {
        CGRect(x: x, y: y, width: width, height: height)
    }

    var minX: Double { x }
    var maxX: Double { x + width }
    var minY: Double { y }
    var maxY: Double { y + height }
    var centerX: Double { x + width / 2 }
    var centerY: Double { y + height / 2 }
    var area: Double { width * height }
    var horizontalRegion: SpatialRegion { .from(normalizedX: centerX) }
    var verticalRegion: VerticalRegion { .from(normalizedY: centerY) }

    func intersectionArea(with other: NormalizedRect) -> Double {
        let intersectionWidth = max(0, min(maxX, other.maxX) - max(minX, other.minX))
        let intersectionHeight = max(0, min(maxY, other.maxY) - max(minY, other.minY))
        return intersectionWidth * intersectionHeight
    }

    func intersectionOverUnion(with other: NormalizedRect) -> Double {
        let intersection = intersectionArea(with: other)
        let union = area + other.area - intersection
        return union > 0 ? intersection / union : 0
    }

    func centerDistance(to other: NormalizedRect) -> Double {
        hypot(centerX - other.centerX, centerY - other.centerY)
    }

    func smoothed(toward other: NormalizedRect, factor: Double) -> NormalizedRect {
        let amount = min(max(factor.isFinite ? factor : 0, 0), 1)
        return NormalizedRect(
            x: x + (other.x - x) * amount,
            y: y + (other.y - y) * amount,
            width: width + (other.width - width) * amount,
            height: height + (other.height - height) * amount
        )
    }

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

struct ObjectObservation: Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var trackIdentifier: UUID?
    var classIdentifier: String
    var name: String
    var confidence: Double
    var confidenceBand: ConfidenceBand
    var boundingBox: NormalizedRect
    var horizontalRegion: SpatialRegion
    var verticalRegion: VerticalRegion
    var relativeSize: Double
    var relativeDistance: RelativeDistance
    var motionState: MotionState
    var temporalStability: Double
    var firstSeenAt: Date
    var lastSeenAt: Date
    var consecutiveFrameCount: Int
    var isNewlyAnnounced: Bool
    var isRequested: Bool
    var mayBeSafetyRelevant: Bool
    var source: VisionAnalyzerSource
    var modelVersion: String?

    init(
        id: UUID = UUID(),
        trackIdentifier: UUID? = nil,
        classIdentifier: String,
        name: String? = nil,
        confidence: Double,
        boundingBox: NormalizedRect,
        relativeDistance: RelativeDistance = .unknown,
        motionState: MotionState = .unknown,
        temporalStability: Double = 0,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date? = nil,
        consecutiveFrameCount: Int = 1,
        isNewlyAnnounced: Bool = false,
        isRequested: Bool = false,
        mayBeSafetyRelevant: Bool = false,
        source: VisionAnalyzerSource = .objectDetection,
        modelVersion: String? = nil
    ) {
        self.id = id
        self.trackIdentifier = trackIdentifier
        self.classIdentifier = classIdentifier
        self.name = name ?? classIdentifier
        self.confidence = confidence
        self.confidenceBand = .from(confidence)
        self.boundingBox = boundingBox
        self.horizontalRegion = boundingBox.horizontalRegion
        self.verticalRegion = boundingBox.verticalRegion
        self.relativeSize = boundingBox.area
        self.relativeDistance = relativeDistance
        self.motionState = motionState
        self.temporalStability = min(max(temporalStability, 0), 1)
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt ?? firstSeenAt
        self.consecutiveFrameCount = max(1, consecutiveFrameCount)
        self.isNewlyAnnounced = isNewlyAnnounced
        self.isRequested = isRequested
        self.mayBeSafetyRelevant = mayBeSafetyRelevant
        self.source = source
        self.modelVersion = modelVersion
    }
}

struct TextLine: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let text: String
    let confidence: Double
    let boundingBox: NormalizedRect
    let readingOrder: Int

    init(id: UUID = UUID(), text: String, confidence: Double, boundingBox: NormalizedRect, readingOrder: Int) {
        self.id = id
        self.text = text
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.readingOrder = readingOrder
    }
}

struct TextBlock: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let lines: [TextLine]
    let boundingBox: NormalizedRect
    let readingOrder: Int

    init(id: UUID = UUID(), lines: [TextLine], boundingBox: NormalizedRect, readingOrder: Int) {
        self.id = id
        self.lines = lines.sorted { $0.readingOrder < $1.readingOrder }
        self.boundingBox = boundingBox
        self.readingOrder = readingOrder
    }
}

struct TextObservation: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let blocks: [TextBlock]
    let confidence: Double
    let boundingBox: NormalizedRect
    let capturedAt: Date
    let source: VisionAnalyzerSource

    init(
        id: UUID = UUID(),
        blocks: [TextBlock],
        confidence: Double,
        boundingBox: NormalizedRect,
        capturedAt: Date = Date(),
        source: VisionAnalyzerSource = .textRecognition
    ) {
        self.id = id
        self.blocks = blocks.sorted { $0.readingOrder < $1.readingOrder }
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.capturedAt = capturedAt
        self.source = source
    }

    var linesInReadingOrder: [TextLine] {
        blocks.sorted { $0.readingOrder < $1.readingOrder }.flatMap { $0.lines }
    }

    var recognizedText: String {
        linesInReadingOrder.map(\.text).joined(separator: "\n")
    }
}

struct BarcodeObservation: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let symbology: String
    let payload: String
    let confidence: Double
    let boundingBox: NormalizedRect
    let capturedAt: Date
    let source: VisionAnalyzerSource

    init(
        id: UUID = UUID(),
        symbology: String,
        payload: String,
        confidence: Double,
        boundingBox: NormalizedRect,
        capturedAt: Date = Date(),
        source: VisionAnalyzerSource = .barcodeRecognition
    ) {
        self.id = id
        self.symbology = symbology
        self.payload = payload
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.capturedAt = capturedAt
        self.source = source
    }
}

struct PersonObservation: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    var trackIdentifier: UUID?
    var confidence: Double
    var confidenceBand: ConfidenceBand
    var boundingBox: NormalizedRect
    var horizontalRegion: SpatialRegion
    var verticalRegion: VerticalRegion
    var firstSeenAt: Date
    var lastSeenAt: Date
    var consecutiveFrameCount: Int
    let source: VisionAnalyzerSource

    init(
        id: UUID = UUID(),
        trackIdentifier: UUID? = nil,
        confidence: Double,
        boundingBox: NormalizedRect,
        firstSeenAt: Date = Date(),
        lastSeenAt: Date? = nil,
        consecutiveFrameCount: Int = 1,
        source: VisionAnalyzerSource = .faceAndPerson
    ) {
        self.id = id
        self.trackIdentifier = trackIdentifier
        self.confidence = confidence
        self.confidenceBand = .from(confidence)
        self.boundingBox = boundingBox
        self.horizontalRegion = boundingBox.horizontalRegion
        self.verticalRegion = boundingBox.verticalRegion
        self.firstSeenAt = firstSeenAt
        self.lastSeenAt = lastSeenAt ?? firstSeenAt
        self.consecutiveFrameCount = max(1, consecutiveFrameCount)
        self.source = source
    }
}

enum VisionObservation: Codable, Equatable, Hashable, Sendable {
    case object(ObjectObservation)
    case text(TextObservation)
    case barcode(BarcodeObservation)
    case person(PersonObservation)
}

enum SceneChangeKind: String, Codable, CaseIterable, Sendable {
    case appeared
    case persisted
    case moved
    case approaching
    case receding
    case lost
    case uncertain
}

struct SceneChange: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let kind: SceneChangeKind
    let trackIdentifier: UUID
    let classIdentifier: String
    let name: String
    let previousRegion: SpatialRegion?
    let currentRegion: SpatialRegion?
    let confidenceBand: ConfidenceBand
    let occurredAt: Date

    init(
        id: UUID = UUID(),
        kind: SceneChangeKind,
        trackIdentifier: UUID,
        classIdentifier: String,
        name: String,
        previousRegion: SpatialRegion? = nil,
        currentRegion: SpatialRegion? = nil,
        confidenceBand: ConfidenceBand,
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.trackIdentifier = trackIdentifier
        self.classIdentifier = classIdentifier
        self.name = name
        self.previousRegion = previousRegion
        self.currentRegion = currentRegion
        self.confidenceBand = confidenceBand
        self.occurredAt = occurredAt
    }
}

struct TrackedObservation: Codable, Equatable, Hashable, Sendable {
    let trackIdentifier: UUID
    var observation: ObjectObservation
    var smoothedBoundingBox: NormalizedRect
    var smoothedConfidence: Double
    var firstSeenAt: Date
    var lastSeenAt: Date
    var consecutiveFrameCount: Int
    var missedFrameCount: Int
    var isConfirmed: Bool
    var lastAnnouncedAt: Date?

    var classIdentifier: String { observation.classIdentifier }
    var name: String { observation.name }
    var horizontalRegion: SpatialRegion { smoothedBoundingBox.horizontalRegion }
    var verticalRegion: VerticalRegion { smoothedBoundingBox.verticalRegion }
}

struct TrackingUpdate: Codable, Equatable, Sendable {
    let active: [TrackedObservation]
    let confirmed: [TrackedObservation]
    let changes: [SceneChange]
    let timestamp: Date
}

struct CameraQualityReport: Codable, Equatable, Hashable, Sendable {
    let brightness: Double
    let sharpness: Double
    let overexposure: Double
    let motion: Double
    let obstruction: Double
    let isUsable: Bool
    let warnings: [VisionWarning]
    let guidance: [String]
    let evaluatedAt: Date

    init(
        brightness: Double,
        sharpness: Double,
        overexposure: Double,
        motion: Double,
        obstruction: Double,
        isUsable: Bool,
        warnings: [VisionWarning] = [],
        guidance: [String] = [],
        evaluatedAt: Date = Date()
    ) {
        self.brightness = Self.unit(brightness)
        self.sharpness = Self.unit(sharpness)
        self.overexposure = Self.unit(overexposure)
        self.motion = Self.unit(motion)
        self.obstruction = Self.unit(obstruction)
        self.isUsable = isUsable
        self.warnings = warnings
        self.guidance = guidance
        self.evaluatedAt = evaluatedAt
    }

    static func acceptable(at date: Date = Date()) -> CameraQualityReport {
        CameraQualityReport(
            brightness: 0.5,
            sharpness: 0.8,
            overexposure: 0,
            motion: 0,
            obstruction: 0,
            isUsable: true,
            evaluatedAt: date
        )
    }

    private static func unit(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(max(value, 0), 1)
    }
}

struct SceneSnapshot: Codable, Equatable, Sendable {
    let id: UUID
    let mode: VisionMode
    let capturedAt: Date
    let objects: [TrackedObservation]
    let text: [TextObservation]
    let barcodes: [BarcodeObservation]
    let people: [PersonObservation]
    let quality: CameraQualityReport
    let changes: [SceneChange]

    init(
        id: UUID = UUID(),
        mode: VisionMode,
        capturedAt: Date = Date(),
        objects: [TrackedObservation] = [],
        text: [TextObservation] = [],
        barcodes: [BarcodeObservation] = [],
        people: [PersonObservation] = [],
        quality: CameraQualityReport = .acceptable(),
        changes: [SceneChange] = []
    ) {
        self.id = id
        self.mode = mode
        self.capturedAt = capturedAt
        self.objects = objects
        self.text = text
        self.barcodes = barcodes
        self.people = people
        self.quality = quality
        self.changes = changes
    }
}

struct SceneNarration: Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let snapshotIdentifier: UUID
    let text: String
    let priority: SpeechPriority
    let verbosity: NarrationVerbosity
    let contentKind: NarrationContentKind
    let groundedObservationIdentifiers: [UUID]
    let isVerbatim: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        snapshotIdentifier: UUID,
        text: String,
        priority: SpeechPriority,
        verbosity: NarrationVerbosity,
        contentKind: NarrationContentKind,
        groundedObservationIdentifiers: [UUID] = [],
        isVerbatim: Bool = false,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.snapshotIdentifier = snapshotIdentifier
        self.text = text
        self.priority = priority
        self.verbosity = verbosity
        self.contentKind = contentKind
        self.groundedObservationIdentifiers = groundedObservationIdentifiers
        self.isVerbatim = isVerbatim
        self.createdAt = createdAt
    }
}

struct ModelMetadata: Codable, Equatable, Hashable, Sendable {
    let name: String
    let version: String
    let checksumSHA256: String
    let checksumVerified: Bool
    let supportedClassIdentifiers: [String]
    let sourceURL: String
    let licenseName: String
    let licenseURL: String
}

struct InferenceMetrics: Codable, Equatable, Hashable, Sendable {
    var modelLoadDuration: TimeInterval?
    var lastInferenceDuration: TimeInterval?
    var averageInferenceDuration: TimeInterval?
    var slowestInferenceDuration: TimeInterval?
    var framesAnalyzed: Int
    var droppedFrameCount: Int
    var analyzedFramesPerSecond: Double?
    var narrationDelay: TimeInterval?
    var lastUpdatedAt: Date?

    init(
        modelLoadDuration: TimeInterval? = nil,
        lastInferenceDuration: TimeInterval? = nil,
        averageInferenceDuration: TimeInterval? = nil,
        slowestInferenceDuration: TimeInterval? = nil,
        framesAnalyzed: Int = 0,
        droppedFrameCount: Int = 0,
        analyzedFramesPerSecond: Double? = nil,
        narrationDelay: TimeInterval? = nil,
        lastUpdatedAt: Date? = nil
    ) {
        self.modelLoadDuration = modelLoadDuration
        self.lastInferenceDuration = lastInferenceDuration
        self.averageInferenceDuration = averageInferenceDuration
        self.slowestInferenceDuration = slowestInferenceDuration
        self.framesAnalyzed = framesAnalyzed
        self.droppedFrameCount = droppedFrameCount
        self.analyzedFramesPerSecond = analyzedFramesPerSecond
        self.narrationDelay = narrationDelay
        self.lastUpdatedAt = lastUpdatedAt
    }

    mutating func recordInference(duration: TimeInterval, droppedFrames: Int = 0, at date: Date = Date()) {
        guard duration.isFinite, duration >= 0 else { return }
        let priorCount = framesAnalyzed
        let priorAverage = averageInferenceDuration ?? 0
        framesAnalyzed += 1
        lastInferenceDuration = duration
        averageInferenceDuration = ((priorAverage * Double(priorCount)) + duration) / Double(framesAnalyzed)
        slowestInferenceDuration = max(slowestInferenceDuration ?? 0, duration)
        droppedFrameCount += max(0, droppedFrames)
        lastUpdatedAt = date
    }
}
