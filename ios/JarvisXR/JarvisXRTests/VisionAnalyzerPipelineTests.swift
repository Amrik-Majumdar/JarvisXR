import CoreML
import Foundation
import ImageIO
import XCTest
@testable import JarvisXR

final class VisionAnalyzerPipelineTests: XCTestCase {
    #if DEBUG
    func testReplayLabCoversAllRequiredScenariosWithOriginalFrames() {
        XCTAssertEqual(VisionReplayScenarioKind.allCases.count, 17)
        for kind in VisionReplayScenarioKind.allCases {
            let scenario = VisionReplayScenarioFactory.make(kind)
            XCTAssertEqual(scenario.kind, kind)
            XCTAssertFalse(scenario.frames.isEmpty, "\(kind.rawValue) must contain replay input")
            XCTAssertTrue(scenario.frames.allSatisfy { $0.image.width == 640 && $0.image.height == 480 })
            XCTAssertTrue(scenario.frames.allSatisfy { $0.orientation == .up })
        }
    }
    #endif

    func testMultiArrayDecoderMapsExactLabelCoordinatesAndRequestedTarget() throws {
        let confidence = try makeMultiArray(shape: [2, 80], dataType: .double)
        let coordinates = try makeMultiArray(shape: [2, 4], dataType: .double)
        set(confidence, [0, 56], 0.91) // chair
        set(confidence, [1, 39], 0.72) // bottle
        [0.50, 0.55, 0.40, 0.50].enumerated().forEach { set(coordinates, [0, $0.offset], $0.element) }
        [0.15, 0.50, 0.10, 0.30].enumerated().forEach { set(coordinates, [1, $0.offset], $0.element) }

        let observations = try ObjectDetectionDecoder.decode(
            confidence: confidence,
            coordinates: coordinates,
            minimumConfidence: 0.20,
            requestedClassIdentifier: "chair",
            modelVersion: "fixture-model"
        )

        XCTAssertEqual(observations.map(\.classIdentifier), ["chair", "bottle"])
        let chair = try XCTUnwrap(observations.first)
        XCTAssertEqual(chair.name, "chair")
        XCTAssertEqual(chair.confidence, 0.91, accuracy: 0.000_001)
        XCTAssertEqual(chair.boundingBox.x, 0.30, accuracy: 0.000_001)
        XCTAssertEqual(chair.boundingBox.y, 0.30, accuracy: 0.000_001)
        XCTAssertEqual(chair.boundingBox.width, 0.40, accuracy: 0.000_001)
        XCTAssertEqual(chair.boundingBox.height, 0.50, accuracy: 0.000_001)
        XCTAssertEqual(chair.horizontalRegion, .center)
        XCTAssertTrue(chair.isRequested)
        XCTAssertEqual(chair.modelVersion, "fixture-model")
    }

    func testMultiArrayDecoderHandlesTransposedStridedSchemaAndSuppressesDuplicates() throws {
        let confidence = try makeMultiArray(shape: [80, 2], dataType: .float32)
        let coordinates = try makeMultiArray(shape: [4, 2], dataType: .float32)
        set(confidence, [56, 0], 0.85)
        set(confidence, [56, 1], 0.75)
        let boxes = [
            [0.50, 0.50, 0.50, 0.50],
            [0.51, 0.50, 0.50, 0.50]
        ]
        for component in 0..<4 {
            set(coordinates, [component, 0], boxes[0][component])
            set(coordinates, [component, 1], boxes[1][component])
        }

        let observations = try ObjectDetectionDecoder.decode(
            confidence: confidence,
            coordinates: coordinates,
            minimumConfidence: 0.20,
            duplicateIntersectionOverUnion: 0.50
        )
        XCTAssertEqual(observations.count, 1)
        XCTAssertEqual(observations.first?.classIdentifier, "chair")
        XCTAssertEqual(observations.first?.confidence ?? 0, 0.85, accuracy: 0.001)
    }

    func testMultiArrayDecoderRejectsMalformedCoordinatesExplicitly() throws {
        let confidence = try makeMultiArray(shape: [1, 80], dataType: .double)
        let coordinates = try makeMultiArray(shape: [1, 5], dataType: .double)
        XCTAssertThrowsError(try ObjectDetectionDecoder.decode(
            confidence: confidence,
            coordinates: coordinates,
            minimumConfidence: 0.20
        )) { error in
            XCTAssertEqual(error as? VisionError, .invalidModelOutput)
        }
    }

    func testTextReadingOrderIsTopToBottomThenLeftToRight() {
        let lines = TextRecognitionService.readingOrder(texts: [
            ("lower right", 0.9, NormalizedRect(x: 0.55, y: 0.30, width: 0.35, height: 0.10)),
            ("upper right", 0.9, NormalizedRect(x: 0.55, y: 0.75, width: 0.35, height: 0.10)),
            ("lower left", 0.9, NormalizedRect(x: 0.05, y: 0.31, width: 0.35, height: 0.10)),
            ("upper left", 0.9, NormalizedRect(x: 0.05, y: 0.76, width: 0.35, height: 0.10))
        ])
        XCTAssertEqual(lines.map(\.text), ["upper left", "upper right", "lower left", "lower right"])
        XCTAssertEqual(lines.map(\.readingOrder), [0, 1, 2, 3])
    }

    func testCameraQualityDetectsCoveredOverexposedBlurAndMotion() {
        let coveredAnalyzer = CameraQualityAnalyzer()
        let start = Date(timeIntervalSince1970: 1_000)
        let startupBlack = coveredAnalyzer.evaluate(
            luminanceSamples: [UInt8](repeating: 0, count: 64),
            width: 8,
            height: 8,
            at: start
        )
        XCTAssertFalse(startupBlack.warnings.contains(.cameraCovered))
        XCTAssertEqual(startupBlack.condition, .blackFrame)
        _ = coveredAnalyzer.evaluate(
            luminanceSamples: [UInt8](repeating: 0, count: 64),
            width: 8,
            height: 8,
            at: start.addingTimeInterval(0.7)
        )
        let covered = coveredAnalyzer.evaluate(
            luminanceSamples: [UInt8](repeating: 0, count: 64),
            width: 8,
            height: 8,
            at: start.addingTimeInterval(1.3)
        )
        XCTAssertFalse(covered.isUsable)
        XCTAssertTrue(covered.warnings.contains(.cameraCovered))
        XCTAssertEqual(covered.condition, .obstructed)

        let brightAnalyzer = CameraQualityAnalyzer()
        let bright = brightAnalyzer.evaluate(luminanceSamples: [UInt8](repeating: 255, count: 64), width: 8, height: 8)
        XCTAssertFalse(bright.isUsable)
        XCTAssertTrue(bright.warnings.contains(.overexposed))

        let blurAnalyzer = CameraQualityAnalyzer()
        let blur = blurAnalyzer.evaluate(luminanceSamples: [UInt8](repeating: 128, count: 64), width: 8, height: 8)
        XCTAssertTrue(blur.isUsable, "A valid low-detail frame must still reach inference")
        XCTAssertTrue(blur.warnings.contains(.blurry))
        XCTAssertTrue(blur.warnings.contains(.poorFraming))
        XCTAssertFalse(blur.warnings.contains(.cameraCovered))

        let motionAnalyzer = CameraQualityAnalyzer()
        let checkerboard: [UInt8] = (0..<64).map { index in
            ((index + index / 8) % 2) == 0 ? 0 : 255
        }
        _ = motionAnalyzer.evaluate(luminanceSamples: checkerboard, width: 8, height: 8)
        let inverted: [UInt8] = checkerboard.map { 255 - $0 }
        let motion = motionAnalyzer.evaluate(luminanceSamples: inverted, width: 8, height: 8)
        XCTAssertTrue(motion.warnings.contains(VisionWarning.excessiveMotion))
    }

    func testCameraQualityDistinguishesInvalidDarkAndValidNoDetectionFrames() {
        let invalid = CameraQualityAnalyzer().evaluate(luminanceSamples: [0, 1, 2], width: 8, height: 8)
        XCTAssertEqual(invalid.condition, .invalidPixelBuffer)
        XCTAssertTrue(invalid.warnings.contains(.invalidFrame))
        XCTAssertFalse(invalid.warnings.contains(.cameraCovered))

        let darkTexture: [UInt8] = (0..<64).map { $0.isMultiple(of: 2) ? 5 : 15 }
        let dark = CameraQualityAnalyzer().evaluate(luminanceSamples: darkTexture, width: 8, height: 8)
        XCTAssertEqual(dark.condition, .underexposed)
        XCTAssertTrue(dark.warnings.contains(.lowLight))
        XCTAssertFalse(dark.warnings.contains(.cameraCovered))

        let blank = CameraQualityAnalyzer().evaluate(
            luminanceSamples: [UInt8](repeating: 128, count: 64),
            width: 8,
            height: 8
        )
        XCTAssertTrue(blank.isUsable)
        XCTAssertFalse(blank.warnings.contains(.cameraCovered))
    }

    func testCameraQualityAcceptsDetailedBalancedFrame() {
        let analyzer = CameraQualityAnalyzer()
        let checkerboard: [UInt8] = (0..<256).map { index in
            ((index + index / 16) % 2) == 0 ? 70 : 190
        }
        let report = analyzer.evaluate(luminanceSamples: checkerboard, width: 16, height: 16)
        XCTAssertTrue(report.isUsable)
        XCTAssertGreaterThan(report.sharpness, 0.2)
        XCTAssertFalse(report.warnings.contains(.lowLight))
        XCTAssertFalse(report.warnings.contains(.overexposed))
    }

    func testColorClassifierUsesCommonNamesAndReportsUncertainty() {
        XCTAssertEqual(ColorAnalysisService.classify(red: 0.95, green: 0.05, blue: 0.04).name, "red")
        XCTAssertEqual(ColorAnalysisService.classify(red: 0.05, green: 0.15, blue: 0.90).name, "blue")
        XCTAssertEqual(ColorAnalysisService.classify(red: 0.50, green: 0.51, blue: 0.49).name, "gray")

        let mixed = ColorAnalysisService.classify(red: 0.8, green: 0.1, blue: 0.1, variance: 0.20)
        XCTAssertTrue(mixed.isUncertain)
        XCTAssertEqual(mixed.sampledRegion, ColorAnalysisService.centerRegion)
    }

    func testBarcodeDeduplicationKeepsStrongestAndNeverOpensURL() {
        let service = BarcodeRecognitionService(configuration: BarcodeRecognitionConfiguration(
            duplicateSuppressionInterval: 2,
            minimumConfidence: 0.2
        ))
        let start = Date(timeIntervalSince1970: 1_000)
        let weaker = BarcodeObservation(
            symbology: "VNBarcodeSymbologyQR",
            payload: "https://example.invalid/untrusted",
            confidence: 0.60,
            boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3),
            capturedAt: start
        )
        let stronger = BarcodeObservation(
            symbology: "VNBarcodeSymbologyQR",
            payload: "https://example.invalid/untrusted",
            confidence: 0.91,
            boundingBox: NormalizedRect(x: 0.1, y: 0.1, width: 0.3, height: 0.3),
            capturedAt: start
        )
        let first = service.deduplicateForTesting([weaker, stronger], at: start)
        XCTAssertEqual(first.count, 1)
        XCTAssertEqual(first.first?.confidence ?? 0, 0.91, accuracy: 0.000_001)
        XCTAssertTrue(service.deduplicateForTesting([stronger], at: start.addingTimeInterval(1)).isEmpty)
        XCTAssertEqual(service.deduplicateForTesting([stronger], at: start.addingTimeInterval(3)).count, 1)

        let result = BarcodeRecognitionResult(observations: first, latency: 0.01, capturedAt: start)
        XCTAssertFalse(result.automaticallyOpenedURL)
    }

    func testFaceAndPersonFusionCountsPresenceWithoutDoubleCountingFace() {
        let body = NormalizedRect(x: 0.2, y: 0.1, width: 0.5, height: 0.8)
        let faceInsideBody = NormalizedRect(x: 0.35, y: 0.68, width: 0.18, height: 0.18)
        let separateFace = NormalizedRect(x: 0.78, y: 0.68, width: 0.12, height: 0.12)
        let merged = FaceAndPersonService.mergePersonAndFaceBoxes(
            humans: [(body, 0.90)],
            faces: [(faceInsideBody, 0.80), (separateFace, 0.70)]
        )
        XCTAssertEqual(merged.count, 2)
    }

    func testBundledModelExecutesRealDeskChairInferenceAndWritesNativeObservations() throws {
        let fixtureURL = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "Desk_chair", withExtension: "jpg"))
        let source = try XCTUnwrap(CGImageSourceCreateWithURL(fixtureURL as CFURL, nil))
        let image = try XCTUnwrap(CGImageSourceCreateImageAtIndex(source, 0, nil))
        let service = ObjectDetectionService(bundle: .main)

        let preparation = expectation(description: "validated compiled detector loads")
        service.prepare { result in
            if case .failure(let error) = result {
                XCTFail("The bundled production model must load; missing or invalid models are failures: \(error)")
            }
            preparation.fulfill()
        }
        wait(for: [preparation], timeout: 30)

        var nativeResult: ObjectDetectionResult?
        let inference = expectation(description: "real Desk_chair inference")
        service.detectObjects(in: image, orientation: .up, requestedClassIdentifier: "chair") { result in
            switch result {
            case .success(let value): nativeResult = value
            case .failure(let error): XCTFail("Real bundled inference failed explicitly: \(error)")
            }
            inference.fulfill()
        }
        wait(for: [inference], timeout: 45)

        let result = try XCTUnwrap(nativeResult)
        let chair = result.observations.first(where: { $0.classIdentifier == "chair" })
        let summary = result.observations
            .map { "\($0.classIdentifier)=\(String(format: "%.3f", $0.confidence))" }
            .joined(separator: ", ")
        print("VISION_FIXTURE_DETECTIONS: \(summary.isEmpty ? "none" : summary)")

        let evaluationData = try nativeEvaluationData(result: result, chair: chair)
        print("VISION_NATIVE_OBSERVATIONS_BASE64:\(evaluationData.base64EncodedString())")
        if let output = ProcessInfo.processInfo.environment["VISION_EVALUATION_OUTPUT"], !output.isEmpty {
            let outputURL = URL(fileURLWithPath: output)
            try FileManager.default.createDirectory(
                at: outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try evaluationData.write(to: outputURL, options: .atomic)
        }

        XCTAssertTrue(result.latency.isFinite)
        XCTAssertGreaterThanOrEqual(result.latency, 0)
        for observation in result.observations {
            XCTAssertTrue(VisionClassCatalog.rawIdentifiers.contains(observation.classIdentifier))
            XCTAssertTrue(observation.confidence.isFinite)
            XCTAssertTrue((0...1).contains(observation.confidence))
            XCTAssertTrue(observation.boundingBox.x.isFinite)
            XCTAssertTrue(observation.boundingBox.y.isFinite)
            XCTAssertTrue(observation.boundingBox.width.isFinite)
            XCTAssertTrue(observation.boundingBox.height.isFinite)
            XCTAssertGreaterThan(observation.boundingBox.width, 0)
            XCTAssertGreaterThan(observation.boundingBox.height, 0)
        }
    }

    private func nativeEvaluationData(
        result: ObjectDetectionResult,
        chair: ObjectObservation?
    ) throws -> Data {
        let detections: [[String: Any]] = result.observations.map { observation in
            [
                "label": observation.classIdentifier,
                "confidence": observation.confidence,
                "spatial_region": observation.horizontalRegion.rawValue,
                "vertical_region": observation.verticalRegion.rawValue,
                "bounding_box": [
                    "x": observation.boundingBox.x,
                    "y": 1 - observation.boundingBox.maxY,
                    "width": observation.boundingBox.width,
                    "height": observation.boundingBox.height
                ]
            ]
        }
        let narration = chair.map {
            "I may be seeing a \($0.name) \($0.horizontalRegion.spokenLocation)."
        } ?? "I do not have enough evidence to describe this image."
        let payload: [String: Any] = [
            "schema_version": 1,
            "fixtures": [[
                "fixture_id": "desk-chair-public-domain",
                "inference_completed": true,
                "detections": detections,
                "narration": narration,
                "latency_ms": result.latency * 1_000,
                "policy_decision": "uncertain_grounded_single_frame"
            ]]
        ]
        let validation = VisionSafetyPolicy().validateNarration(narration)
        XCTAssertTrue(validation.isAllowed, "Fixture narration must pass the production safety policy")
        return try JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted, .sortedKeys])
    }

    private func set(_ array: MLMultiArray, _ indices: [Int], _ value: Double) {
        array[indices.map { NSNumber(value: $0) }] = NSNumber(value: value)
    }

    private func makeMultiArray(
        shape: [NSNumber],
        dataType: MLMultiArrayDataType
    ) throws -> MLMultiArray {
        let array = try MLMultiArray(shape: shape, dataType: dataType)
        for index in 0..<array.count {
            array[index] = NSNumber(value: 0)
        }
        return array
    }
}
