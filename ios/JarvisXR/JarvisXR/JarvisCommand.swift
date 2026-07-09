import Foundation

struct JarvisCommand {
    let rawText: String
    let normalizedText: String

    init(_ rawText: String) {
        self.rawText = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedText = self.rawText
            .lowercased()
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}
