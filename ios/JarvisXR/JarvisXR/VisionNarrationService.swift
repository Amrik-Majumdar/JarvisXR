import Foundation

struct VisionNarrationConfiguration: Codable, Equatable, Sendable {
    var conciseObjectLimit: Int
    var standardObjectLimit: Int
    var detailedObjectLimit: Int

    init(conciseObjectLimit: Int = 2, standardObjectLimit: Int = 3, detailedObjectLimit: Int = 5) {
        self.conciseObjectLimit = max(1, conciseObjectLimit)
        self.standardObjectLimit = max(conciseObjectLimit, standardObjectLimit)
        self.detailedObjectLimit = max(standardObjectLimit, detailedObjectLimit)
    }
}

final class VisionNarrationService {
    let safetyPolicy: VisionSafetyPolicy
    let configuration: VisionNarrationConfiguration

    init(
        safetyPolicy: VisionSafetyPolicy = VisionSafetyPolicy(),
        configuration: VisionNarrationConfiguration = VisionNarrationConfiguration()
    ) {
        self.safetyPolicy = safetyPolicy
        self.configuration = configuration
    }

    func narrate(
        snapshot: SceneSnapshot,
        verbosity: NarrationVerbosity = .standard,
        region: SpatialRegion? = nil,
        targetClassIdentifier: String? = nil
    ) -> SceneNarration {
        guard snapshot.quality.isUsable else {
            return qualityNarration(for: snapshot, verbosity: verbosity)
        }

        var candidates = region.map { snapshot.objects(in: $0) } ?? snapshot.objects
        if let targetClassIdentifier {
            candidates = candidates.filter { $0.classIdentifier == targetClassIdentifier }
            return targetNarration(
                classIdentifier: targetClassIdentifier,
                candidates: candidates,
                snapshot: snapshot,
                verbosity: verbosity
            )
        }

        let limit = objectLimit(for: verbosity)
        let speakable = candidates.compactMap { tracked -> (TrackedObservation, VisionEvidenceDecision)? in
            let decision = safetyPolicy.decision(for: tracked, frameUsable: snapshot.quality.isUsable)
            if case .suppressed = decision { return nil }
            return (tracked, decision)
        }

        guard !speakable.isEmpty else {
            var text = safetyPolicy.qualifiedAbsence(region: region)
            if !snapshot.text.isEmpty {
                text += " I also detect readable text."
            }
            return makeNarration(
                snapshot: snapshot,
                text: text,
                priority: .prominent,
                verbosity: verbosity,
                contentKind: .scene
            )
        }

        var sentences = speakable.prefix(limit).map { tracked, decision in
            describe(tracked, decision: decision, verbosity: verbosity)
        }
        if !snapshot.text.isEmpty, verbosity != .concise {
            let textRegion = snapshot.text.first?.boundingBox.horizontalRegion.spokenLocation ?? "in view"
            sentences.append("I also detect readable text \(textRegion).")
        }
        if !snapshot.quality.warnings.isEmpty, let guidance = snapshot.quality.guidance.first {
            sentences.append(guidance)
        }

        let groundedIdentifiers = speakable.prefix(limit).map { $0.0.observation.id }
        let priority: SpeechPriority = speakable.contains(where: { $0.0.observation.isRequested }) ? .target : .prominent
        return makeNarration(
            snapshot: snapshot,
            text: sentences.joined(separator: " "),
            priority: priority,
            verbosity: verbosity,
            contentKind: .scene,
            groundedIdentifiers: groundedIdentifiers
        )
    }

    func narrateChanges(
        in snapshot: SceneSnapshot,
        verbosity: NarrationVerbosity = .standard
    ) -> SceneNarration {
        guard snapshot.quality.isUsable else {
            return qualityNarration(for: snapshot, verbosity: verbosity)
        }

        let meaningful = snapshot.changes.filter {
            switch $0.kind {
            case .appeared, .moved, .approaching, .receding, .lost: return true
            case .persisted, .uncertain: return false
            }
        }

        guard !meaningful.isEmpty else {
            return makeNarration(
                snapshot: snapshot,
                text: "I do not have a confirmed visual change to report.",
                priority: .change,
                verbosity: verbosity,
                contentKind: .change
            )
        }

        let limit = objectLimit(for: verbosity)
        let selected = meaningful.prefix(limit)
        let sentences = selected.map(changeDescription)
        return makeNarration(
            snapshot: snapshot,
            text: sentences.joined(separator: " "),
            priority: meaningful.contains(where: { $0.kind == .approaching }) ? .warning : .change,
            verbosity: verbosity,
            contentKind: .change,
            groundedIdentifiers: selected.map(\.trackIdentifier)
        )
    }

    func verbatimNarration(
        _ content: String,
        snapshotIdentifier: UUID,
        kind: NarrationContentKind,
        createdAt: Date = Date()
    ) -> SceneNarration? {
        guard kind == .reading || kind == .barcode else { return nil }
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return SceneNarration(
            snapshotIdentifier: snapshotIdentifier,
            text: trimmed,
            priority: .target,
            verbosity: .standard,
            contentKind: kind,
            isVerbatim: true,
            createdAt: createdAt
        )
    }

    private func targetNarration(
        classIdentifier: String,
        candidates: [TrackedObservation],
        snapshot: SceneSnapshot,
        verbosity: NarrationVerbosity
    ) -> SceneNarration {
        let definition = VisionClassCatalog.definition(forIdentifier: classIdentifier)
        let targetName = definition?.displayName ?? classIdentifier
        guard let candidate = candidates.first(where: {
            if case .suppressed = safetyPolicy.decision(for: $0, frameUsable: snapshot.quality.isUsable) {
                return false
            }
            return true
        }) else {
            return makeNarration(
                snapshot: snapshot,
                text: "I have not found \(targetName) yet. Pan slowly; I may be missing it.",
                priority: .target,
                verbosity: verbosity,
                contentKind: .target
            )
        }

        let decision = safetyPolicy.decision(for: candidate, frameUsable: snapshot.quality.isUsable)
        let phrase = objectPhrase(candidate)
        let text: String
        switch decision {
        case .supported:
            text = "I detect \(phrase) \(candidate.horizontalRegion.spokenLocation)."
        case .uncertain:
            text = "I may be seeing \(phrase) \(candidate.horizontalRegion.spokenLocation)."
        case .suppressed:
            text = "I have not found \(targetName) yet. Pan slowly; I may be missing it."
        }
        return makeNarration(
            snapshot: snapshot,
            text: text,
            priority: .target,
            verbosity: verbosity,
            contentKind: .target,
            groundedIdentifiers: [candidate.observation.id]
        )
    }

    private func describe(
        _ tracked: TrackedObservation,
        decision: VisionEvidenceDecision,
        verbosity: NarrationVerbosity
    ) -> String {
        let phrase = objectPhrase(tracked)
        let evidence: String
        switch decision {
        case .supported: evidence = "I detect \(phrase)"
        case .uncertain: evidence = "I may be seeing \(phrase)"
        case .suppressed: return ""
        }

        var details = " \(tracked.horizontalRegion.spokenLocation)"
        if verbosity == .detailed {
            switch tracked.verticalRegion {
            case .high: details += ", high in the view"
            case .low: details += ", low in the view"
            case .middle: break
            }
            if tracked.observation.relativeDistance == .possiblyClose {
                details += ". It may be relatively close based only on its size in the image"
            } else if tracked.observation.relativeDistance == .fartherAway {
                details += ". It appears smaller and may be farther away"
            }
        }
        return evidence + details + "."
    }

    private func objectPhrase(_ tracked: TrackedObservation) -> String {
        if let definition = VisionClassCatalog.definition(forIdentifier: tracked.classIdentifier) {
            if let article = definition.indefiniteArticle {
                return "\(article) \(definition.displayName)"
            }
            return definition.displayName
        }
        let name = tracked.name
        guard let first = name.lowercased().first else { return "an object" }
        let article = "aeiou".contains(first) ? "an" : "a"
        return "\(article) \(name)"
    }

    private func changeDescription(_ change: SceneChange) -> String {
        let phrase = change.name
        switch change.kind {
        case .appeared:
            return "I now detect \(phrase) \((change.currentRegion ?? .center).spokenLocation)."
        case .moved:
            if let previous = change.previousRegion, let current = change.currentRegion, previous != current {
                return "The \(phrase) moved from \(previous.spokenLocation) to \(current.spokenLocation)."
            }
            return "The \(phrase) moved within the view."
        case .approaching:
            return "The \(phrase) is getting larger in the image \((change.currentRegion ?? .center).spokenLocation)."
        case .receding:
            return "The \(phrase) is getting smaller in the image \((change.currentRegion ?? .center).spokenLocation)."
        case .lost:
            return "I lost the \(phrase). It was last seen \((change.previousRegion ?? .center).spokenLocation)."
        case .persisted, .uncertain:
            return ""
        }
    }

    private func qualityNarration(for snapshot: SceneSnapshot, verbosity: NarrationVerbosity) -> SceneNarration {
        let text: String
        if snapshot.quality.warnings.contains(.cameraCovered) {
            text = "The camera may be covered. Uncover it and try again."
        } else if snapshot.quality.warnings.contains(.lowLight) {
            text = "The image is too dark for a reliable description. More light may help."
        } else if snapshot.quality.warnings.contains(.overexposed) {
            text = "The image is too bright for a reliable description. Point away from the strongest light and try again."
        } else if snapshot.quality.warnings.contains(.blurry) || snapshot.quality.warnings.contains(.excessiveMotion) {
            text = "The image is too blurry for a reliable description. Hold the phone steadier and try again."
        } else if let guidance = snapshot.quality.guidance.first {
            text = "I cannot identify the scene reliably. \(guidance)"
        } else {
            text = "I cannot provide a reliable description from this image."
        }
        return makeNarration(
            snapshot: snapshot,
            text: text,
            priority: .warning,
            verbosity: verbosity,
            contentKind: .system
        )
    }

    private func makeNarration(
        snapshot: SceneSnapshot,
        text: String,
        priority: SpeechPriority,
        verbosity: NarrationVerbosity,
        contentKind: NarrationContentKind,
        groundedIdentifiers: [UUID] = []
    ) -> SceneNarration {
        let safeText = safetyPolicy.safeNarration(text)
        return SceneNarration(
            snapshotIdentifier: snapshot.id,
            text: safeText,
            priority: priority,
            verbosity: verbosity,
            contentKind: contentKind,
            groundedObservationIdentifiers: groundedIdentifiers,
            createdAt: snapshot.capturedAt
        )
    }

    private func objectLimit(for verbosity: NarrationVerbosity) -> Int {
        switch verbosity {
        case .concise: return configuration.conciseObjectLimit
        case .standard: return configuration.standardObjectLimit
        case .detailed: return configuration.detailedObjectLimit
        }
    }
}
