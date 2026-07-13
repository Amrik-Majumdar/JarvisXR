#if DEBUG
import CoreImage
import Foundation
import ImageIO
import UIKit

enum VisionReplayScenarioKind: String, CaseIterable {
    case normalIndoorLighting
    case darkRoom
    case overexposure
    case lensCovered
    case briefObstruction
    case cameraMotion
    case blur
    case oneProminentObject
    case severalObjects
    case targetEntering
    case targetMovingLeftToCenter
    case targetLost
    case readablePrintedText
    case poorlyFramedText
    case barcode
    case noSupportedObject
    case validSceneNoDetectorResult

    var displayName: String {
        rawValue
            .replacingOccurrences(of: "([a-z0-9])([A-Z])", with: "$1 $2", options: .regularExpression)
            .capitalized
    }
}

struct VisionReplayFrame {
    let label: String
    let image: CGImage
    let capturedAt: Date
    let orientation: CGImagePropertyOrientation
}

struct VisionReplayScenario {
    let kind: VisionReplayScenarioKind
    let frames: [VisionReplayFrame]
}

struct VisionReplayResult {
    let scenario: VisionReplayScenarioKind
    let mode: VisionMode
    let snapshots: [SceneSnapshot]
    let narrations: [SceneNarration]
    let errors: [VisionError]
    let finalStatistics: VisionPipelineStatistics
    let stoppedCleanly: Bool
}

/// Hidden development harness that submits original synthetic frames through the same
/// coordinator and analyzers used by AVCaptureSession. It does not inject observations.
final class VisionReplayLab {
    private let coordinator: VisionPipelineCoordinator
    private var scenario: VisionReplayScenario?
    private var mode: VisionMode = .inactive
    private var target: String?
    private var frameIndex = 0
    private var awaitingFrame = false
    private var snapshots: [SceneSnapshot] = []
    private var narrations: [SceneNarration] = []
    private var errors: [VisionError] = []
    private var baselineAnalyzedFrames = 0
    private var completion: ((VisionReplayResult) -> Void)?
    private var lastStatistics: VisionPipelineStatistics

    init(coordinator: VisionPipelineCoordinator = VisionPipelineCoordinator()) {
        self.coordinator = coordinator
        self.lastStatistics = coordinator.statistics
    }

    func run(
        scenario: VisionReplayScenario,
        mode: VisionMode,
        target: String? = nil,
        completion: @escaping (VisionReplayResult) -> Void
    ) {
        stop()
        self.scenario = scenario
        self.mode = mode
        self.target = target
        frameIndex = 0
        awaitingFrame = false
        snapshots = []
        narrations = []
        errors = []
        baselineAnalyzedFrames = coordinator.statistics.analyzedFrameCount
        lastStatistics = coordinator.statistics
        self.completion = completion
        bindCallbacks()
        coordinator.start(mode: mode, target: target)
    }

    func pause() {
        coordinator.pause()
    }

    func resume() {
        coordinator.resume()
    }

    func stop() {
        if completion != nil {
            complete(stoppedCleanly: true)
        } else if coordinator.currentMode != .inactive {
            coordinator.stop()
        }
    }

    private func bindCallbacks() {
        coordinator.onStateChange = { [weak self] _, state in
            guard let self else { return }
            switch state {
            case .active:
                self.submitNextFrameIfReady()
            case .failed, .unavailable:
                self.complete(stoppedCleanly: false)
            case .stopped:
                if self.completion != nil { self.complete(stoppedCleanly: true) }
            default:
                break
            }
        }
        coordinator.onSnapshot = { [weak self] snapshot in self?.snapshots.append(snapshot) }
        coordinator.onNarration = { [weak self] narration in self?.narrations.append(narration) }
        coordinator.onError = { [weak self] error in self?.errors.append(error) }
        coordinator.onStatistics = { [weak self] statistics in
            guard let self else { return }
            self.lastStatistics = statistics
            let completed = statistics.analyzedFrameCount - self.baselineAnalyzedFrames
            if self.awaitingFrame, completed >= self.frameIndex {
                self.awaitingFrame = false
            }
            self.submitNextFrameIfReady()
        }
    }

    private func submitNextFrameIfReady() {
        guard !awaitingFrame,
              coordinator.sessionState == .active,
              let scenario else { return }
        guard frameIndex < scenario.frames.count else {
            complete(stoppedCleanly: true)
            return
        }
        let frame = scenario.frames[frameIndex]
        frameIndex += 1
        awaitingFrame = true
        coordinator.submitReplayFrame(
            frame.image,
            capturedAt: frame.capturedAt,
            orientation: frame.orientation
        )
    }

    private func complete(stoppedCleanly: Bool) {
        guard let completion, let scenario else { return }
        self.completion = nil
        coordinator.stop()
        completion(VisionReplayResult(
            scenario: scenario.kind,
            mode: mode,
            snapshots: snapshots,
            narrations: narrations,
            errors: errors,
            finalStatistics: lastStatistics,
            stoppedCleanly: stoppedCleanly
        ))
    }
}

enum VisionReplayScenarioFactory {
    private static let size = CGSize(width: 640, height: 480)

    static func make(_ kind: VisionReplayScenarioKind, start: Date = Date(timeIntervalSince1970: 20_000)) -> VisionReplayScenario {
        let images: [(String, CGImage)]
        switch kind {
        case .normalIndoorLighting:
            images = [("balanced room", roomImage())]
        case .darkRoom:
            images = [("dark textured room", roomImage(background: UIColor(white: 0.035, alpha: 1), foreground: UIColor(white: 0.08, alpha: 1)))]
        case .overexposure:
            images = [("bright washout", solidImage(.white))]
        case .lensCovered:
            images = (0..<4).map { ("covered \($0 + 1)", solidImage(UIColor(red: 0.01, green: 0.005, blue: 0.004, alpha: 1))) }
        case .briefObstruction:
            images = [
                ("room before", roomImage()),
                ("brief cover", solidImage(.black)),
                ("room recovered", roomImage())
            ]
        case .cameraMotion:
            images = [
                ("object left", shapeImage(rects: [(CGRect(x: 40, y: 130, width: 180, height: 220), .systemBlue)])),
                ("object right", shapeImage(rects: [(CGRect(x: 420, y: 80, width: 180, height: 300), .systemBlue)]))
            ]
        case .blur:
            images = [("blurred room", blurred(roomImage()))]
        case .oneProminentObject:
            images = [("one object", shapeImage(rects: [(CGRect(x: 180, y: 80, width: 280, height: 330), .systemBlue)]))]
        case .severalObjects:
            images = [("several objects", shapeImage(rects: [
                (CGRect(x: 35, y: 220, width: 150, height: 170), .systemOrange),
                (CGRect(x: 245, y: 100, width: 150, height: 290), .systemBlue),
                (CGRect(x: 455, y: 190, width: 130, height: 200), .systemGreen)
            ]))]
        case .targetEntering:
            images = [
                ("empty", roomImage()),
                ("target at edge", shapeImage(rects: [(CGRect(x: 500, y: 160, width: 120, height: 250), .systemBlue)])),
                ("target visible", shapeImage(rects: [(CGRect(x: 350, y: 120, width: 190, height: 290), .systemBlue)]))
            ]
        case .targetMovingLeftToCenter:
            images = [
                ("target left", shapeImage(rects: [(CGRect(x: 30, y: 120, width: 190, height: 290), .systemBlue)])),
                ("target middle left", shapeImage(rects: [(CGRect(x: 150, y: 120, width: 190, height: 290), .systemBlue)])),
                ("target centered", shapeImage(rects: [(CGRect(x: 225, y: 120, width: 190, height: 290), .systemBlue)]))
            ]
        case .targetLost:
            images = [
                ("target centered", shapeImage(rects: [(CGRect(x: 225, y: 120, width: 190, height: 290), .systemBlue)])),
                ("target leaving", shapeImage(rects: [(CGRect(x: 510, y: 120, width: 110, height: 290), .systemBlue)])),
                ("target lost", roomImage())
            ]
        case .readablePrintedText:
            images = [("large printed text", textImage("JARVIS REPLAY\nREAD FROM THE TOP", origin: CGPoint(x: 70, y: 150), fontSize: 44))]
        case .poorlyFramedText:
            images = [("cropped text", textImage("MOVE CLOSER AND HOLD STEADY", origin: CGPoint(x: 480, y: 420), fontSize: 38))]
        case .barcode:
            images = [("QR code", barcodeImage())]
        case .noSupportedObject:
            images = [("abstract unsupported scene", shapeImage(rects: [
                (CGRect(x: 80, y: 80, width: 480, height: 40), .systemPurple),
                (CGRect(x: 120, y: 190, width: 400, height: 40), .systemPink),
                (CGRect(x: 170, y: 300, width: 300, height: 40), .systemTeal)
            ]))]
        case .validSceneNoDetectorResult:
            images = [("valid blank wall", solidImage(UIColor(white: 0.52, alpha: 1)))]
        }
        let frames = images.enumerated().map { index, item in
            VisionReplayFrame(
                label: item.0,
                image: item.1,
                capturedAt: start.addingTimeInterval(Double(index) * 0.7),
                orientation: .up
            )
        }
        return VisionReplayScenario(kind: kind, frames: frames)
    }

    private static func roomImage(
        background: UIColor = UIColor(white: 0.24, alpha: 1),
        foreground: UIColor = UIColor(white: 0.68, alpha: 1)
    ) -> CGImage {
        shapeImage(background: background, rects: [
            (CGRect(x: 0, y: 310, width: 640, height: 170), foreground.withAlphaComponent(0.45)),
            (CGRect(x: 75, y: 80, width: 180, height: 250), foreground),
            (CGRect(x: 390, y: 150, width: 160, height: 180), foreground.withAlphaComponent(0.72))
        ])
    }

    private static func solidImage(_ color: UIColor) -> CGImage {
        shapeImage(background: color, rects: [])
    }

    private static func shapeImage(
        background: UIColor = UIColor(white: 0.16, alpha: 1),
        rects: [(CGRect, UIColor)]
    ) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            for (rect, color) in rects {
                color.setFill()
                UIBezierPath(roundedRect: rect, cornerRadius: 24).fill()
            }
        }.cgImage!
    }

    private static func textImage(_ text: String, origin: CGPoint, fontSize: CGFloat) -> CGImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .bold),
                .foregroundColor: UIColor.black
            ]
            NSString(string: text).draw(
                in: CGRect(x: origin.x, y: origin.y, width: 560, height: 220),
                withAttributes: attributes
            )
        }.cgImage!
    }

    private static func barcodeImage() -> CGImage {
        let data = Data("JARVIS-REPLAY-12345".utf8)
        let filter = CIFilter(name: "CIQRCodeGenerator")!
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("H", forKey: "inputCorrectionLevel")
        let code = filter.outputImage!.transformed(by: CGAffineTransform(scaleX: 12, y: 12))
        let renderer = UIGraphicsImageRenderer(size: size)
        let background = renderer.image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }.cgImage!
        let composite = code.composited(over: CIImage(cgImage: background))
            .cropped(to: CGRect(origin: .zero, size: size))
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(composite, from: composite.extent)!
    }

    private static func blurred(_ image: CGImage) -> CGImage {
        let source = CIImage(cgImage: image)
        let filter = CIFilter(name: "CIGaussianBlur")!
        filter.setValue(source, forKey: kCIInputImageKey)
        filter.setValue(16, forKey: kCIInputRadiusKey)
        let output = filter.outputImage!.cropped(to: source.extent)
        return CIContext(options: [.cacheIntermediates: false]).createCGImage(output, from: source.extent)!
    }
}
#endif
