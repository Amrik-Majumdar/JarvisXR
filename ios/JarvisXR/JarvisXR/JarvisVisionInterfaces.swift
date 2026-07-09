import Foundation
import UIKit
import CoreML
import Vision

enum JarvisVisionCapability: String, CaseIterable {
    case ocr
    case qrBarcode
    case imageClassification
    case objectDetection
    case sceneLabels
}

struct JarvisVisionRequest {
    let image: UIImage
    let capability: JarvisVisionCapability
}

struct JarvisVisionResult {
    let capability: JarvisVisionCapability
    let status: String
    let summary: String
    let observations: [String]
}

protocol JarvisVisionAnalyzing {
    func analyze(_ request: JarvisVisionRequest) async -> JarvisVisionResult
}

final class JarvisVisionPlaceholderAnalyzer: JarvisVisionAnalyzing {
    func analyze(_ request: JarvisVisionRequest) async -> JarvisVisionResult {
        JarvisVisionResult(
            capability: request.capability,
            status: "future",
            summary: "Vision scan routes are active for OCR, codes, and built-in image classification. A custom Core ML object detector can be added later.",
            observations: []
        )
    }
}

enum JarvisObjectDetectionModel {
    static let expectedModelNames = [
        "JarvisObjectDetector",
        "YOLO",
        "YOLOv8n",
        "ObjectDetector"
    ]

    static func bundledModelURL() -> URL? {
        for name in expectedModelNames {
            if let url = Bundle.main.url(forResource: name, withExtension: "mlmodelc") {
                return url
            }
        }
        return nil
    }

    static func isReady() -> Bool {
        bundledModelURL() != nil
    }

    static func statusLine() -> String {
        isReady()
            ? "Object detection ready with bundled Core ML model."
            : "Visual scan ready: text, codes, and image classification are active."
    }

    static func diagnosticLine() -> String {
        isReady()
            ? "Bundled Core ML object detector: available."
            : "Bundled Core ML object detector: not bundled. Built-in Vision classification fallback: active."
    }

    static func makeVisionModel() -> VNCoreMLModel? {
        guard let url = bundledModelURL(),
              let model = try? MLModel(contentsOf: url),
              let visionModel = try? VNCoreMLModel(for: model) else {
            return nil
        }
        return visionModel
    }
}
