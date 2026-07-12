import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

struct NormalizedRGBColor: Codable, Equatable, Hashable, Sendable {
    let red: Double
    let green: Double
    let blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = Self.unit(red)
        self.green = Self.unit(green)
        self.blue = Self.unit(blue)
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value.isFinite ? value : 0, 0), 1)
    }
}

struct ColorAnalysisResult: Codable, Equatable, Hashable, Sendable {
    let name: String
    let averageColor: NormalizedRGBColor
    let confidence: Double
    let isUncertain: Bool
    let sampleVariance: Double
    let sampledRegion: NormalizedRect
    let capturedAt: Date
}

final class ColorAnalysisService {
    static let centerRegion = NormalizedRect(x: 0.35, y: 0.35, width: 0.30, height: 0.30)

    private let context: CIContext
    private let sampleSide = 32

    init(context: CIContext = CIContext(options: [.cacheIntermediates: false])) {
        self.context = context
    }

    func analyze(pixelBuffer: CVPixelBuffer, at date: Date = Date()) -> ColorAnalysisResult {
        analyze(ciImage: CIImage(cvPixelBuffer: pixelBuffer), at: date)
    }

    func analyze(image: CGImage, at date: Date = Date()) -> ColorAnalysisResult {
        analyze(ciImage: CIImage(cgImage: image), at: date)
    }

    private func analyze(ciImage: CIImage, at date: Date) -> ColorAnalysisResult {
        let extent = ciImage.extent
        guard !extent.isEmpty, extent.width.isFinite, extent.height.isFinite else {
            return Self.classify(red: 0, green: 0, blue: 0, variance: 1, capturedAt: date)
        }
        let crop = CGRect(
            x: extent.minX + extent.width * Self.centerRegion.x,
            y: extent.minY + extent.height * Self.centerRegion.y,
            width: extent.width * Self.centerRegion.width,
            height: extent.height * Self.centerRegion.height
        )
        let translated = ciImage
            .cropped(to: crop)
            .transformed(by: CGAffineTransform(translationX: -crop.minX, y: -crop.minY))
        let scaled = translated.transformed(by: CGAffineTransform(
            scaleX: CGFloat(sampleSide) / crop.width,
            y: CGFloat(sampleSide) / crop.height
        ))
        var rgba = [UInt8](repeating: 0, count: sampleSide * sampleSide * 4)
        context.render(
            scaled,
            toBitmap: &rgba,
            rowBytes: sampleSide * 4,
            bounds: CGRect(x: 0, y: 0, width: sampleSide, height: sampleSide),
            format: .RGBA8,
            colorSpace: CGColorSpaceCreateDeviceRGB()
        )
        let count = Double(sampleSide * sampleSide)
        var red = 0.0
        var green = 0.0
        var blue = 0.0
        for index in stride(from: 0, to: rgba.count, by: 4) {
            red += Double(rgba[index]) / 255
            green += Double(rgba[index + 1]) / 255
            blue += Double(rgba[index + 2]) / 255
        }
        red /= count
        green /= count
        blue /= count

        var variance = 0.0
        for index in stride(from: 0, to: rgba.count, by: 4) {
            let sampleRed = Double(rgba[index]) / 255
            let sampleGreen = Double(rgba[index + 1]) / 255
            let sampleBlue = Double(rgba[index + 2]) / 255
            variance += (pow(sampleRed - red, 2) + pow(sampleGreen - green, 2) + pow(sampleBlue - blue, 2)) / 3
        }
        variance /= count
        return Self.classify(red: red, green: green, blue: blue, variance: variance, capturedAt: date)
    }

    static func classify(
        red: Double,
        green: Double,
        blue: Double,
        variance: Double = 0,
        capturedAt: Date = Date()
    ) -> ColorAnalysisResult {
        let color = NormalizedRGBColor(red: red, green: green, blue: blue)
        let maximum = max(color.red, color.green, color.blue)
        let minimum = min(color.red, color.green, color.blue)
        let chroma = maximum - minimum
        let saturation = maximum > 0 ? chroma / maximum : 0
        let brightness = maximum

        let name: String
        let categoryStrength: Double
        if brightness <= 0.10 {
            name = "black"
            categoryStrength = 1 - brightness / 0.10
        } else if brightness >= 0.90, saturation <= 0.13 {
            name = "white"
            categoryStrength = min((brightness - 0.80) / 0.20, 1) * (1 - saturation)
        } else if saturation <= 0.14 {
            name = "gray"
            categoryStrength = 1 - saturation / 0.14
        } else {
            let hue = hueDegrees(red: color.red, green: color.green, blue: color.blue, maximum: maximum, chroma: chroma)
            switch hue {
            case 15..<43 where brightness < 0.62:
                name = "brown"
            case 15..<43:
                name = "orange"
            case 43..<70:
                name = "yellow"
            case 70..<165:
                name = "green"
            case 165..<195:
                name = "teal"
            case 195..<255:
                name = "blue"
            case 255..<300:
                name = "purple"
            case 300..<345:
                name = "pink"
            default:
                name = "red"
            }
            categoryStrength = min(max(saturation, 0), 1)
        }

        let safeVariance = min(max(variance.isFinite ? variance : 1, 0), 1)
        let coherence = min(max(1 - sqrt(safeVariance) * 2.8, 0), 1)
        let confidence = min(max((0.35 + 0.65 * categoryStrength) * coherence, 0), 1)
        return ColorAnalysisResult(
            name: name,
            averageColor: color,
            confidence: confidence,
            isUncertain: confidence < 0.58 || safeVariance > 0.055,
            sampleVariance: safeVariance,
            sampledRegion: centerRegion,
            capturedAt: capturedAt
        )
    }

    private static func hueDegrees(
        red: Double,
        green: Double,
        blue: Double,
        maximum: Double,
        chroma: Double
    ) -> Double {
        guard chroma > 0 else { return 0 }
        let sector: Double
        if maximum == red {
            sector = ((green - blue) / chroma).truncatingRemainder(dividingBy: 6)
        } else if maximum == green {
            sector = ((blue - red) / chroma) + 2
        } else {
            sector = ((red - green) / chroma) + 4
        }
        let degrees = sector * 60
        return degrees < 0 ? degrees + 360 : degrees
    }
}
