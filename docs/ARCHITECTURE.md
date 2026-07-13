# Architecture

## Shipping iOS App

`ios/JarvisXR` is the current product target. It is a Swift and UIKit application generated with XcodeGen.

```text
UIKit and accessible interaction
  -> command and deep-link routing
  -> local memory and preferences
  -> Speech + AVAudioEngine input
  -> priority AVSpeechSynthesizer output
  -> AVFoundation camera session
     -> model-agnostic analyzers
     -> tracking and scene fusion
     -> safety policy and narration
     -> session-scoped speech and haptics
  -> App Intents, URL routes, and Control Mesh guidance
```

The app runs in the normal iOS sandbox and uses public frameworks. It has no private API, root daemon, injected input, global overlay, remote vision backend, CUDA, or TensorRT dependency.

## Command Flow

1. The app becomes ready to listen after launch when permissions and onboarding allow it; the user may speak naturally, tap the orb or Voice control, or submit text.
2. The interface enters Listening or Processing.
3. `JarvisCommandRouter` normalizes the command and creates a local response or action.
4. In-app actions open native screens such as Jarvis Vision, Settings, Help, or Diagnostics.
5. Vision commands route to a typed `VisionMode` and `JarvisVisionCommand` through the active camera experience, which maintains task-scoped conversational context for Find, Read, Scan, and Message follow-ups.
6. Supported external routes use public URLs, App Intents, or Control Mesh guidance.
7. `JarvisSpeechService` speaks non-vision responses when output is enabled.
8. `JarvisMemoryStore` persists allowed notes, settings, and history locally.

## Vision Flow

1. `CameraSessionService` owns camera permission, preview, continuous sample delivery, optional internal still capture, camera choice, focus, exposure, white balance, torch, interruptions, first-frame diagnostics, and foreground lifecycle.
2. `VisionPipelineCoordinator` owns the active mode and session generation. Frame backpressure and generation checks prevent unbounded queues and stale completion delivery.
3. `ObjectDetectionService`, `TextRecognitionService`, `BarcodeRecognitionService`, `FaceAndPersonService`, `CameraQualityAnalyzer`, and `ColorAnalysisService` return typed observations. `CameraQualityMetricsEngine` distinguishes invalid, startup-black, light, detail, motion, framing, and temporal obstruction states without treating a valid no-detection frame as a covered camera. The `VisionDetecting` interface keeps the detector replaceable without changing downstream features.
4. `TemporalObjectTracker` stabilizes object identity and movement. `SceneFusionEngine` combines bounded evidence into a `SceneSnapshot`.
5. `VisionSafetyPolicy` applies confidence, stability, age, supported-class, and prohibited-language rules. `VisionNarrationService` describes only grounded evidence and qualifies absence.
6. `VisionSpeechPriorityQueue` orders warnings and requested targets above changes and ambient detail. Session tokens cancel stale or stopped-session speech.
7. `VisionHapticsService` maps broad direction and status into a small documented vocabulary, with spoken guidance as fallback.
8. `VisionSessionMemory` keeps temporary observations in memory and clears them when the session stops. `VisionDiagnosticsStore` retains bounded operational metrics without frames or recognized content.
9. Runtime conditions select full, balanced, reduced-power, target-only, or stopped processing profiles. Serious or critical thermal state selects reduced processing.
10. In debug builds, `VisionReplayLab` submits original local frames through this same coordinator and analyzer path; it is deliberately excluded from ordinary user navigation.

## Model Supply Chain

`JarvisObjectDetector.manifest.json` is the source of truth for the selected Apple-hosted `YOLOv3TinyInt8LUT` artifact, exact digest, size, Core ML interface, 80 classes, known unsupported targets, and upstream license. `tools/fetch_vision_model.py` obtains the exact binary before project generation. Xcode compiles it into `JarvisObjectDetector.mlmodelc`, while the manifest and notice remain visible in the app bundle and IPA audit.

The model binary is fetched rather than committed. Changing the URL, digest, schema, class list, or license requires an intentional manifest update, fixture review, build, simulator inference, audit, and physical-device validation.

## Privacy Boundary

Camera frames flow from AVFoundation directly into on-device analyzers. Normal settings cannot enable frame storage, video storage, recognized-text persistence, or network vision processing. OCR, barcode values, and scene observations remain session-scoped. This boundary is distinct from the app's explicit local notes and history features and from Apple's separate Speech framework behavior.

## Supporting Python Core

`core/`, `tests/`, and `tools/` contain tested registry, adapter, routing, device-profile, daemon-contract, model-fetch, fixture-evaluation, privacy, safety, asset, IPA-audit, and CI support code. These modules validate the shipping target; they are not a root daemon installed by the app.

## Legacy Prototypes

`native/` preserves Objective-C shell, daemon, and jailbreak-era contracts from earlier research. They are not included in the current app target and do not prove system hooks or jailbreak support.
