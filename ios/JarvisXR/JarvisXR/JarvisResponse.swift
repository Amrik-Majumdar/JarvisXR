import Foundation

enum JarvisResponseStatus: String, Codable {
    case ok
    case confirmationRequired
    case refused
    case unavailable
    case error
}

struct JarvisResponse: Codable {
    let status: JarvisResponseStatus
    let spokenResponse: String
    let displayResponse: String
    let data: [String: String]
    let shouldSpeak: Bool

    init(status: JarvisResponseStatus, spokenResponse: String, displayResponse: String, data: [String: String] = [:], shouldSpeak: Bool = true) {
        self.status = status
        self.spokenResponse = spokenResponse
        self.displayResponse = displayResponse
        self.data = data
        self.shouldSpeak = shouldSpeak
    }

    static func ok(_ spoken: String, display: String? = nil, data: [String: String] = [:], shouldSpeak: Bool = true) -> JarvisResponse {
        JarvisResponse(status: .ok, spokenResponse: spoken, displayResponse: display ?? spoken, data: data, shouldSpeak: shouldSpeak)
    }
}
