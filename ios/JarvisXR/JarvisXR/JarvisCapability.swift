import Foundation

struct JarvisCapability {
    let id: String
    let name: String
    let route: JarvisCapabilityRoute
    let offlineAvailable: Bool
    let requiresUserAction: Bool
}

enum JarvisCapabilityCatalog {
    static let primary: [JarvisCapability] = [
        JarvisCapability(id: "vision.inspect", name: "Inspection", route: .inAppVision, offlineAvailable: true, requiresUserAction: false),
        JarvisCapability(id: "vision.ocr", name: "Text scan", route: .inAppVision, offlineAvailable: true, requiresUserAction: false),
        JarvisCapability(id: "vision.objects", name: "Visual classification", route: .inAppVision, offlineAvailable: true, requiresUserAction: false),
        JarvisCapability(id: "voice.session", name: "Voice session", route: .inAppSpeech, offlineAvailable: true, requiresUserAction: true),
        JarvisCapability(id: "memory.local", name: "Local memory", route: .inAppMemory, offlineAvailable: true, requiresUserAction: false),
        JarvisCapability(id: "control.mesh", name: "Control Mesh", route: .controlMeshGuide, offlineAvailable: true, requiresUserAction: true)
    ]
}
