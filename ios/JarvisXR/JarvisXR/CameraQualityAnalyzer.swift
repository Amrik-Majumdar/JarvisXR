import CoreGraphics
import CoreImage
import CoreVideo
import Foundation

final class CameraQualityAnalyzer: @unchecked Sendable {
    let configuration: CameraQualityConfiguration

    private let context: CIContext
    private let engine: CameraQualityMetricsEngine
    private let sampleWidth = 64
    private let sampleHeight = 64

    init(
        configuration: CameraQualityConfiguration = CameraQualityConfiguration(),
        context: CIContext = CIContext(options: [.cacheIntermediates: false])
    ) {
        self.configuration = configuration
        self.context = context
        self.engine = CameraQualityMetricsEngine(configuration: configuration)
    }

    func analyze(pixelBuffer: CVPixelBuffer, at date: Date = Date()) -> CameraQualityReport {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let pixelFormat = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard width > 1, height > 1 else {
            return report(
                from: engine.evaluate(luminanceSamples: [], width: 0, height: 0, at: date),
                at: date,
                frameWidth: width,
                frameHeight: height,
                pixelFormat: pixelFormat
            )
        }
        guard let samples = sampleLuminance(
            from: pixelBuffer,
            pixelFormat: pixelFormat,
            sourceWidth: width,
            sourceHeight: height
        ) else {
            return report(
                from: engine.evaluate(luminanceSamples: [], width: 0, height: 0, at: date),
                at: date,
                frameWidth: width,
                frameHeight: height,
                pixelFormat: pixelFormat
            )
        }
        return report(
            from: engine.evaluate(
                luminanceSamples: samples,
                width: sampleWidth,
                height: sampleHeight,
                at: date
            ),
            at: date,
            frameWidth: width,
            frameHeight: height,
            pixelFormat: pixelFormat
        )
    }

    func analyze(image: CGImage, at date: Date = Date()) -> CameraQualityReport {
        let ciImage = CIImage(cgImage: image)
        guard !ciImage.extent.isEmpty, ciImage.extent.width.isFinite, ciImage.extent.height.isFinite else {
            return report(
                from: engine.evaluate(luminanceSamples: [], width: 0, height: 0, at: date),
                at: date,
                frameWidth: image.width,
                frameHeight: image.height,
                pixelFormat: nil
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
        let luma = stride(from: 0, to: rgba.count, by: 4).map { index -> UInt8 in
            let red = Double(rgba[index])
            let green = Double(rgba[index + 1])
            let blue = Double(rgba[index + 2])
            return UInt8(clamping: Int((0.2126 * red + 0.7152 * green + 0.0722 * blue).rounded()))
        }
        return report(
            from: engine.evaluate(luminanceSamples: luma, width: sampleWidth, height: sampleHeight, at: date),
            at: date,
            frameWidth: image.width,
            frameHeight: image.height,
            pixelFormat: nil
        )
    }

    func resetMotionHistory() {
        engine.resetTemporalHistory()
    }

    /// Pure metric path used by production after downsampling and by deterministic tests.
    func evaluate(
        luminanceSamples: [UInt8],
        width: Int,
        height: Int,
        at date: Date = Date()
    ) -> CameraQualityReport {
        report(
            from: engine.evaluate(luminanceSamples: luminanceSamples, width: width, height: height, at: date),
            at: date,
            frameWidth: width,
            frameHeight: height,
            pixelFormat: nil
        )
    }

    private func sampleLuminance(
        from pixelBuffer: CVPixelBuffer,
        pixelFormat: OSType,
        sourceWidth: Int,
        sourceHeight: Int
    ) -> [UInt8]? {
        guard CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        var samples = [UInt8](repeating: 0, count: sampleWidth * sampleHeight)
        switch pixelFormat {
        case kCVPixelFormatType_32BGRA:
            guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            let pointer = base.assumingMemoryBound(to: UInt8.self)
            for sampleY in 0..<sampleHeight {
                let sourceY = min(sourceHeight - 1, sampleY * sourceHeight / sampleHeight)
                for sampleX in 0..<sampleWidth {
                    let sourceX = min(sourceWidth - 1, sampleX * sourceWidth / sampleWidth)
                    let offset = sourceY * bytesPerRow + sourceX * 4
                    let blue = Double(pointer[offset])
                    let green = Double(pointer[offset + 1])
                    let red = Double(pointer[offset + 2])
                    samples[sampleY * sampleWidth + sampleX] = UInt8(clamping: Int(
                        (0.2126 * red + 0.7152 * green + 0.0722 * blue).rounded()
                    ))
                }
            }
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
             kCVPixelFormatType_420YpCbCr8BiPlanarFullRange:
            guard CVPixelBufferGetPlaneCount(pixelBuffer) > 0,
                  let base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0) else { return nil }
            let planeWidth = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0)
            let planeHeight = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0)
            let bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0)
            let pointer = base.assumingMemoryBound(to: UInt8.self)
            for sampleY in 0..<sampleHeight {
                let sourceY = min(planeHeight - 1, sampleY * planeHeight / sampleHeight)
                for sampleX in 0..<sampleWidth {
                    let sourceX = min(planeWidth - 1, sampleX * planeWidth / sampleWidth)
                    samples[sampleY * sampleWidth + sampleX] = pointer[sourceY * bytesPerRow + sourceX]
                }
            }
        default:
            return nil
        }
        return samples
    }

    private func report(
        from metrics: CameraQualityMetrics,
        at date: Date,
        frameWidth: Int,
        frameHeight: Int,
        pixelFormat: OSType?
    ) -> CameraQualityReport {
        var warnings: [VisionWarning] = []
        var guidance: [String] = []
        switch metrics.condition {
        case .invalidPixelBuffer:
            warnings.append(.invalidFrame)
            guidance.append("The camera frame is invalid. Jarvis will keep trying; restart Vision if frames do not recover.")
        case .blackFrame:
            warnings.append(.blackFrame)
            guidance.append("The camera image is black while exposure settles. Hold steady; if this continues, check the lens.")
        case .underexposed:
            warnings.append(.lowLight)
            guidance.append("The image is too dark for a reliable answer. More light may help.")
        case .overexposed:
            warnings.append(.overexposed)
            guidance.append("The image is too bright. Point away from the strongest light and try again.")
        case .obstructed:
            warnings.append(.cameraCovered)
            guidance.append("The lens appears covered across several frames. Check the camera and try again.")
        case .blurred:
            warnings.append(.blurry)
            guidance.append("The image may be blurry. Hold the phone steadier.")
        case .excessiveMotion:
            warnings.append(.excessiveMotion)
            guidance.append("The camera is moving too quickly. Pause briefly and hold the phone steadier.")
        case .poorlyFramed:
            warnings.append(.poorFraming)
            guidance.append("The view has very little detail. Pan slowly toward the subject.")
        case .valid:
            break
        }
        if metrics.isBlurred, !warnings.contains(.blurry), metrics.condition != .obstructed {
            warnings.append(.blurry)
        }
        if metrics.hasPoorFraming, !warnings.contains(.poorFraming) {
            warnings.append(.poorFraming)
        }
        return CameraQualityReport(
            condition: metrics.condition,
            brightness: metrics.brightness,
            sharpness: metrics.sharpness,
            overexposure: metrics.overexposure,
            motion: metrics.motion,
            obstruction: metrics.obstruction,
            isUsable: metrics.isUsable,
            warnings: warnings,
            guidance: guidance,
            evaluatedAt: date,
            frameWidth: frameWidth,
            frameHeight: frameHeight,
            pixelFormat: pixelFormat,
            sampleCount: metrics.sampleCount,
            obstructionEvidenceFrames: metrics.obstructionEvidenceFrames
        )
    }
}
