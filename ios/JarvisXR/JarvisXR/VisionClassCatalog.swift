import Foundation

struct VisionClassDefinition: Codable, Equatable, Hashable, Sendable {
    let index: Int
    let identifier: String
    let displayName: String
    let pluralName: String
    let aliases: [String]
    let mayBeSafetyRelevant: Bool
    let usesIndefiniteArticle: Bool

    func spokenName(count: Int) -> String {
        count == 1 ? displayName : pluralName
    }

    var indefiniteArticle: String? {
        guard usesIndefiniteArticle else { return nil }
        guard let first = displayName.lowercased().first else { return "a" }
        return "aeiou".contains(first) ? "an" : "a"
    }
}

enum VisionTargetResolution: Equatable, Sendable {
    case supported(VisionClassDefinition)
    case supportedWithLimitation(VisionClassDefinition, String)
    case ambiguous([VisionClassDefinition], String)
    case unsupported(String)
}

enum VisionClassCatalog {
    /// Exact contiguous label order embedded in Apple's YOLOv3 Tiny Core ML models.
    /// Legacy spellings are stable model identifiers and must not be modernized here.
    static let rawIdentifiers: [String] = [
        "person", "bicycle", "car", "motorbike", "aeroplane", "bus", "train", "truck", "boat", "traffic light",
        "fire hydrant", "stop sign", "parking meter", "bench", "bird", "cat", "dog", "horse", "sheep", "cow",
        "elephant", "bear", "zebra", "giraffe", "backpack", "umbrella", "handbag", "tie", "suitcase", "frisbee",
        "skis", "snowboard", "sports ball", "kite", "baseball bat", "baseball glove", "skateboard", "surfboard", "tennis racket", "bottle",
        "wine glass", "cup", "fork", "knife", "spoon", "bowl", "banana", "apple", "sandwich", "orange",
        "broccoli", "carrot", "hot dog", "pizza", "donut", "cake", "chair", "sofa", "pottedplant", "bed",
        "diningtable", "toilet", "tvmonitor", "laptop", "mouse", "remote", "keyboard", "cell phone", "microwave", "oven",
        "toaster", "sink", "refrigerator", "book", "clock", "vase", "scissors", "teddy bear", "hair drier", "toothbrush"
    ]

    static let classes: [VisionClassDefinition] = rawIdentifiers.enumerated().map { index, identifier in
        let displayName = displayNames[identifier] ?? identifier
        return VisionClassDefinition(
            index: index,
            identifier: identifier,
            displayName: displayName,
            pluralName: pluralNames[identifier] ?? defaultPlural(for: displayName),
            aliases: Array(Set(([identifier, displayName] + (additionalAliases[identifier] ?? [])).map(normalize))).sorted(),
            mayBeSafetyRelevant: safetyRelevantIdentifiers.contains(identifier),
            usesIndefiniteArticle: !pluralOnlyIdentifiers.contains(identifier)
        )
    }

    static func definition(forIdentifier identifier: String) -> VisionClassDefinition? {
        let target = normalize(identifier)
        return classes.first { normalize($0.identifier) == target }
    }

    static func resolveTarget(_ rawTarget: String) -> VisionTargetResolution {
        let original = normalize(rawTarget)
        guard !original.isEmpty else {
            return .unsupported("Say the name of an object to search for.")
        }

        var target = stripCommandLanguage(original)
        let requestedOwnership = target.hasPrefix("my ")
        if requestedOwnership {
            target = String(target.dropFirst(3)).trimmingCharacters(in: .whitespaces)
        }
        target = stripLeadingArticle(target)

        if let message = unsupportedTargets[target] {
            return .unsupported(message)
        }

        if target == "bike" {
            return ambiguous(["bicycle", "motorbike"], "Bike could mean a bicycle or a motorcycle. Say which one you want.")
        }
        if target == "mouse" {
            return ambiguous(["mouse"], "The model supports a computer mouse, not a mouse animal. Say computer mouse to continue.")
        }
        if target == "bat" {
            return ambiguous(["baseball bat"], "The model supports a baseball bat, not a bat animal. Say baseball bat to continue.")
        }
        if target == "glass" {
            return ambiguous(["wine glass", "cup"], "Glass could mean a wine glass or a cup. Say which one you want.")
        }
        if target == "plant" {
            guard let definition = definition(forIdentifier: "pottedplant") else {
                return .unsupported("Plant detection is unavailable.")
            }
            return .supportedWithLimitation(definition, "The model can detect some potted plants, not plants in general.")
        }
        if target == "guide dog" {
            guard let definition = definition(forIdentifier: "dog") else {
                return .unsupported("Dog detection is unavailable.")
            }
            return .supportedWithLimitation(definition, "The model can detect a dog but cannot verify that it is a guide dog.")
        }
        if target == "traffic light color" || target == "traffic signal color" || target == "traffic light state" {
            guard let definition = definition(forIdentifier: "traffic light") else {
                return .unsupported("Traffic-light detection is unavailable.")
            }
            return .supportedWithLimitation(definition, "The model can detect a traffic light but cannot reliably identify its signal state.")
        }

        guard let definition = classes.first(where: { $0.aliases.contains(target) }) else {
            return .unsupported("The current detector does not support \(target).")
        }

        if requestedOwnership {
            return .supportedWithLimitation(
                definition,
                "I can search for \(definition.displayName), but I cannot verify that an item belongs to you."
            )
        }
        if definition.identifier == "person" {
            return .supportedWithLimitation(
                definition,
                "I can detect a person's presence and broad position, but I cannot identify anyone."
            )
        }
        return .supported(definition)
    }

    private static func ambiguous(_ identifiers: [String], _ explanation: String) -> VisionTargetResolution {
        let definitions = identifiers.compactMap(definition(forIdentifier:))
        return .ambiguous(definitions, explanation)
    }

    private static let displayNames: [String: String] = [
        "motorbike": "motorcycle",
        "aeroplane": "airplane",
        "tie": "necktie",
        "frisbee": "flying disc",
        "sports ball": "ball",
        "sofa": "couch",
        "pottedplant": "potted plant",
        "diningtable": "table",
        "tvmonitor": "television or monitor",
        "mouse": "computer mouse",
        "remote": "remote control",
        "cell phone": "phone",
        "hair drier": "hair dryer"
    ]

    private static let pluralNames: [String: String] = [
        "person": "people",
        "sheep": "sheep",
        "mouse": "computer mice",
        "knife": "knives",
        "sports ball": "balls",
        "pottedplant": "potted plants",
        "diningtable": "tables",
        "tvmonitor": "televisions or monitors",
        "hair drier": "hair dryers",
        "skis": "sets of skis",
        "scissors": "pairs of scissors"
    ]

    private static let additionalAliases: [String: [String]] = [
        "person": ["people", "human"],
        "bicycle": ["bicycle bike"],
        "motorbike": ["motorcycle", "motor bike"],
        "aeroplane": ["airplane", "plane"],
        "handbag": ["purse"],
        "tie": ["necktie"],
        "frisbee": ["flying disc"],
        "sports ball": ["ball"],
        "sofa": ["couch"],
        "pottedplant": ["potted plant"],
        "diningtable": ["table", "dining table"],
        "tvmonitor": ["television", "tv", "monitor", "television monitor"],
        "mouse": ["computer mouse"],
        "remote": ["remote control"],
        "cell phone": ["phone", "mobile phone", "smartphone"],
        "refrigerator": ["fridge"],
        "hair drier": ["hair dryer"]
    ]

    private static let safetyRelevantIdentifiers: Set<String> = [
        "person", "bicycle", "car", "motorbike", "bus", "train", "truck", "traffic light", "stop sign", "knife", "scissors"
    ]

    private static let pluralOnlyIdentifiers: Set<String> = ["skis", "scissors"]

    private static let unsupportedTargets: [String: String] = {
        let navigation = "The current detector does not support that navigation feature. I cannot use its absence to judge whether travel is safe."
        let generic = "The current detector does not support that target."
        var values: [String: String] = [:]
        for target in [
            "door", "doorway", "stairs", "stair", "steps", "step", "staircase", "escalator", "elevator",
            "exit sign", "exit", "curb", "crosswalk", "sidewalk", "road", "path", "pothole", "railing", "handrail"
        ] {
            values[target] = navigation
        }
        for target in [
            "sign", "wall", "window", "pole", "tree", "building", "cane", "white cane", "wheelchair", "walker",
            "crutch", "keys", "wallet", "eyeglasses", "glasses", "headphones", "fire", "smoke", "spilled liquid",
            "wet floor", "gun"
        ] {
            values[target] = generic
        }
        return values
    }()

    private static func stripCommandLanguage(_ value: String) -> String {
        var result = value
        for prefix in ["find ", "locate ", "center ", "where is ", "where are ", "look for "] where result.hasPrefix(prefix) {
            result = String(result.dropFirst(prefix.count))
            break
        }
        return result.trimmingCharacters(in: .whitespaces)
    }

    private static func stripLeadingArticle(_ value: String) -> String {
        for prefix in ["a ", "an ", "the "] where value.hasPrefix(prefix) {
            return String(value.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        }
        return value
    }

    private static func normalize(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private static func defaultPlural(for value: String) -> String {
        if value.hasSuffix("s") { return value }
        if value.hasSuffix("y"), let preceding = value.dropLast().last, !"aeiou".contains(preceding) {
            return String(value.dropLast()) + "ies"
        }
        if value.hasSuffix("ch") || value.hasSuffix("sh") || value.hasSuffix("x") {
            return value + "es"
        }
        return value + "s"
    }
}
