import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

struct CameraQualityConfiguration: Equatable, Sendable {
    var darkBrightnessThreshold: Double
    var overexposedFractionThreshold: Double
    var blurSharpnessThreshold: Double
    var excessiveMotionThreshold: Double
    var coveredBrightnessThreshold: Double
    var coveredVarianceThreshold: Double

    init(
        darkBrightnessThreshold: Double = 0.13,
        overexposedFractionThreshold: Double = 0.58,
        blurSharpnessThreshold: Double = 0.055,
        excessiveMotionThreshold: Double = 0.52,
        coveredBrightnessThreshold: Double = 0.055,
        coveredVarianceThreshold: Double = 0.0025
    ) {
        self.darkBrightnessThreshold = Self.unit(darkBrightnessThreshold)
        self.overexposedFractionThreshold = Self.unit(overexposedFractionThreshold)
        self.blurSharpnessThreshold = Self.unit(blurSharpnessThreshold)
        self.excessiveMotionThreshold = Self.unit(excessiveMotionThreshold)
        self.coveredBrightnessThreshold = Self.unit(coveredBrightnessThreshold)
        self.coveredVarianceThreshold = Self.unit(coveredVarianceThreshold)
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

final class CameraQualityAnalyzer: @unchecked Sendable {
    let configuration: CameraQualityConfiguration

    private let context: CIContext
    private let lock = NSLock()
    private var previousLuminance: [Double]?
    private let sampleWidth = 64
    private let sampleHeight = 64

    init(
        configuration: CameraQualityConfiguration = CameraQualityConfiguration(),
        context: CIContext = CIContext(options: [.cacheIntermediates: false])
    ) {
        self.configuration = configuration
        self.context = context
    }

    func analyze(pixelBuffer: CVPixelBuffer, at date: Date = Date()) -> CameraQualityReport {
        analyze(ciImage: CIImage(cvPixelBuffer: pixelBuffer), at: date)
    }

    func analyze(image: CGImage, at date: Date = Date()) -> CameraQualityReport {
        analyze(ciImage: CIImage(cgImage: image), at: date)
    }

    func resetMotionHistory() {
        lock.lock()
        previousLuminance = nil
        lock.unlock()
    }

    private func analyze(ciImage: CIImage, at date: Date) -> CameraQualityReport {
        guard !ciImage.extent.isEmpty,
              ciImage.extent.width.isFinite,
              ciImage.extent.height.isFinite else {
            return CameraQualityReport(
                brightness: 0,
                sharpness: 0,
                overexposure: 0,
                motion: 0,
                obstruction: 1,
                isUsable: false,
                warnings: [.cameraCovered],
                guidance: ["The camera image is unavailable. Check that the lens is uncovered and try again."],
                evaluatedAt: date
            )
        }
        let translated = ciImage.transformed(by: CGAffineTransform(
            translationX: -ciImage.extent.minX,
            y: -ciImage.extent.minY
        ))
        let scaled = translated.transformed(by: CGAffineTransform(
            scaleX: CGFloat(sampleWidth) / ciImage.extent.width,
            y: CGFloat(sampleHeight) / ciImage.extent.height
        ))
        var rgba = [UInt8](repeating: 0, count: sampleWidth * sampleHeight * 4)
        context.render(
            scaled,
            toBitmap: &rgba,
            rowBytes: sampleWidth * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleWidth, height: sampleHeight),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        var luma: [UInt8] = []
        luma.reserveCapacity(sampleWidth * sampleHeight)
        for index in stride(from: 0, to: rgba.count, by: 4) {
            let red = Double(rgba[index])
            let green = Double(rgba[index + 1])
            let blue = Double(rgba[index + 2])
            luma.append(UInt8(clamping: Int((0.2126 * red + 0.7152 * green + 0.0722 * blue).rounded())))
        }
        return evaluate(luminanceSamples: luma, width: sampleWidth, height: sampleHeight, at: date)
    }

    /// Pure metric path used by production after downsampling and by deterministic unit tests.
    func evaluate(
        luminanceSamples: [UInt8],
        width: Int,
        height: Int,
        at date: Date = Date()
    ) -> CameraQualityReport {
        guard width > 1, height > 1, luminanceSamples.count == width * height else {
            return CameraQualityReport(
                brightness: 0,
                sharpness: 0,
                overexposure: 0,
                motion: 0,
                obstruction: 1,
                isUsable: false,
                warnings: [.cameraCovered],
                guidance: ["The camera image is unavailable. Check that the lens is uncovered and try again."],
                evaluatedAt: date
            )
        }

        let normalized = luminanceSamples.map { Double($0) / 255 }
        let brightness = normalized.reduce(0, +) / Double(normalized.count)
        let variance = normalized.reduce(0) { $0 + pow($1 - brightness, 2) } / Double(normalized.count)
        let overexposure = Double(normalized.filter { $0 >= 0.965 }.count) / Double(normalized.count)

        var edgeSum = 0.0
        var edgeCount = 0
        for y in 0..<height {
            for x in 0..<width {
                let current = normalized[y * width + x]
                if x + 1 < width {
                    edgeSum += abs(current - normalized[y * width + x + 1])
                    edgeCount += 1
                }
                if y + 1 < height {
                    edgeSum += abs(current - normalized[(y + 1) * width + x])
                    edgeCount += 1
                }
            }
        }
        let rawEdge = edgeCount > 0 ? edgeSum / Double(edgeCount) : 0
        let sharpness = Self.unit(rawEdge * 4.5)

        let motion: Double = lock.withLock {
            defer { previousLuminance = normalized }
            guard let previousLuminance, previousLuminance.count == normalized.count else { return 0 }
            let difference = zip(previousLuminance, normalized).reduce(0) { $0 + abs($1.0 - $1.1) }
            return Self.unit((difference / Double(normalized.count)) * 3.0)
        }

        let veryDarkAndUniform = brightness <= configuration.coveredBrightnessThreshold &&
            variance <= configuration.coveredVarianceThreshold
        let obstruction: Double
        if veryDarkAndUniform {
            obstruction = Self.unit(0.82 + (configuration.coveredBrightnessThreshold - brightness) * 3)
        } else if variance < configuration.coveredVarianceThreshold * 0.45 && sharpness < 0.015 {
            obstruction = 0.45
        } else {
            obstruction = 0
        }

        var warnings: [VisionWarning] = []
        var guidance: [String] = []
        if obstruction >= 0.72 {
            warnings.append(.cameraCovered)
            guidance.append("The camera may be covered. Uncover the lens and try again.")
        } else if brightness < configuration.darkBrightnessThreshold {
            warnings.append(.lowLight)
            guidance.append("The image is too dark for a reliable answer. More light may help.")
        }
        if overexposure >= configuration.overexposedFractionThreshold {
            warnings.append(.overexposed)
            guidance.append("The image is too bright. Point away from the strongest light and try again.")
        }
        if sharpness < configuration.blurSharpnessThreshold && obstruction < 0.72 {
            warnings.append(.blurry)
            guidance.append("The image may be blurry. Hold the phone steadier and try again.")
        }
        if motion >= configuration.excessiveMotionThreshold {
            warnings.append(.excessiveMotion)
            guidance.append("The camera is moving too quickly. Pause briefly and hold the phone steadier.")
        }
        if variance < configuration.coveredVarianceThreshold * 0.60,
           brightness >= configuration.darkBrightnessThreshold,
           overexposure < configuration.overexposedFractionThreshold,
           obstruction < 0.72 {
            warnings.append(.poorFraming)
            guidance.append("The view has very little detail. Aim the center of the camera at the subject and try again.")
        }

        let unusable = obstruction >= 0.72 ||
            brightness < configuration.darkBrightnessThreshold ||
            overexposure >= configuration.overexposedFractionThreshold ||
            sharpness < configuration.blurSharpnessThreshold ||
            motion >= configuration.excessiveMotionThreshold
        return CameraQualityReport(
            brightness: brightness,
            sharpness: sharpness,
            overexposure: overexposure,
            motion: motion,
            obstruction: obstruction,
            isUsable: !unusable,
            warnings: warnings,
            guidance: guidance,
            evaluatedAt: date
        )
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

private extension NSLock {
    @discardableResult
    func withLock<T>(_ work: () -> T) -> T {
        lock()
        defer { unlock() }
        return work()
    }
}
