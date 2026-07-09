import Foundation

struct JarvisNote: Codable {
    let id: UUID
    let text: String
    let createdAt: Date
}

struct JarvisHistoryItem: Codable {
    let command: String
    let response: String
    let createdAt: Date
}

final class JarvisMemoryStore {
    static let shared = JarvisMemoryStore()

    private let notesKey = "JarvisXR.notes"
    private let historyKey = "JarvisXR.history"
    private let lastResponseKey = "JarvisXR.lastResponse"
    private let firstLaunchSeenKey = "JarvisXR.firstLaunchSeen"
    private let defaults: UserDefaults
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private(set) var lastStorageError: String?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.decoder.dateDecodingStrategy = .iso8601
        self.encoder.dateEncodingStrategy = .iso8601
    }

    func saveNote(_ text: String) -> JarvisNote {
        var notes = loadNotes()
        let note = JarvisNote(id: UUID(), text: text, createdAt: Date())
        notes.insert(note, at: 0)
        saveNotes(notes)
        return note
    }

    func loadNotes() -> [JarvisNote] {
        guard let data = defaults.data(forKey: notesKey),
              let notes = decode([JarvisNote].self, from: data) else {
            return []
        }
        return notes
    }

    func searchNotes(_ query: String) -> [JarvisNote] {
        let normalized = query.lowercased()
        return loadNotes().filter { $0.text.lowercased().contains(normalized) }
    }

    func clearNotes() {
        defaults.removeObject(forKey: notesKey)
    }

    func clearHistory() {
        defaults.removeObject(forKey: historyKey)
    }

    func noteSummary() -> String {
        let notes = loadNotes()
        let history = loadHistory()
        return "Notes: \(notes.count)\nCommand history: \(history.count)\nLast response: \(lastResponse() ?? "none")"
    }

    func notesSummaryForClipboard() -> String {
        let notes = loadNotes()
        guard !notes.isEmpty else {
            return "JARVIS notes: none"
        }
        return notes.enumerated().map { index, note in
            "\(index + 1). \(note.createdAt.formatted(date: .abbreviated, time: .shortened)) - \(note.text)"
        }.joined(separator: "\n")
    }

    func appendHistory(command: String, response: String) {
        var items = loadHistory()
        items.insert(JarvisHistoryItem(command: command, response: response, createdAt: Date()), at: 0)
        if items.count > 50 {
            items = Array(items.prefix(50))
        }
        saveHistory(items)
        setLastResponse(response)
    }

    func loadHistory() -> [JarvisHistoryItem] {
        guard let data = defaults.data(forKey: historyKey),
              let history = decode([JarvisHistoryItem].self, from: data) else {
            return []
        }
        return history
    }

    func setLastResponse(_ response: String) {
        defaults.set(response, forKey: lastResponseKey)
    }

    func lastResponse() -> String? {
        defaults.string(forKey: lastResponseKey)
    }

    func shouldShowFirstLaunchMessage() -> Bool {
        if defaults.bool(forKey: firstLaunchSeenKey) {
            return false
        }
        defaults.set(true, forKey: firstLaunchSeenKey)
        return true
    }

    private func saveNotes(_ notes: [JarvisNote]) {
        if let data = encode(notes) {
            defaults.set(data, forKey: notesKey)
        }
    }

    private func saveHistory(_ history: [JarvisHistoryItem]) {
        if let data = encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }

    private func encode<T: Encodable>(_ value: T) -> Data? {
        do {
            lastStorageError = nil
            return try encoder.encode(value)
        } catch {
            lastStorageError = error.localizedDescription
            return nil
        }
    }

    private func decode<T: Decodable>(_ type: T.Type, from data: Data) -> T? {
        do {
            lastStorageError = nil
            return try decoder.decode(type, from: data)
        } catch {
            lastStorageError = error.localizedDescription
            defaults.removeObject(forKey: notesKey)
            defaults.removeObject(forKey: historyKey)
            return nil
        }
    }
}
