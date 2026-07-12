# Jarvis Vision Pipeline

Jarvis Vision is an accessibility-first, on-device camera assistant. It uses AVFoundation for capture, Vision and Core ML for analysis, and UIKit, `AVSpeechSynthesizer`, and Core Haptics or UIKit feedback for output. It does not use a remote vision service.

It is informational assistance, not a safety-certified navigation or mobility system. A result can be incomplete, stale, or wrong. Jarvis never treats detection as permission to cross or proceed and never claims that an unobserved area is safe.

## Modes

| Mode | Analysis and interaction |
|---|---|
| Describe | Fuses supported object, person, text, and spatial observations into a bounded scene description |
| Live Guide | Samples frames with backpressure, tracks stable objects, and announces meaningful changes while foregrounded |
| Find | Resolves a requested supported class, tracks it, and reports broad left, center, or right guidance plus found and lost state |
| Read Text | Runs accurate OCR, preserves reading order, and exposes pause, previous-line, and next-line controls |
| Barcode | Recognizes and deduplicates supported symbologies, speaks values only in Scan mode, and never opens a URL automatically |
| Color | Classifies the center region into common color names and qualifies results when lighting or confidence is poor |

Camera-quality analysis can report dark, overexposed, blurry, moving, low-detail, or likely covered frames. Face and person observations support counts without identifying who a person is.

## Processing Flow

1. `CameraSessionService` owns camera authorization, rear or front selection, preview, still capture, sample delivery, focus, exposure, white balance, torch, interruption recovery, and foreground lifecycle.
2. `VisionPipelineCoordinator` creates a session generation token and accepts only the latest permitted work. It drops excess frames instead of building an unbounded queue.
3. Mode-specific analyzers run behind typed interfaces. `VisionDetecting` keeps capture, tracking, fusion, narration, and accessibility independent of one model implementation.
4. `TemporalObjectTracker` stabilizes identity and broad spatial location. `SceneFusionEngine` creates a bounded snapshot from object, text, barcode, person, quality, and color evidence.
5. `VisionSafetyPolicy` filters unsupported, weak, stale, or unsafe claims. `VisionNarrationService` produces grounded summaries and qualified absence language.
6. `VisionSpeechPriorityQueue` orders warnings and requested targets ahead of changes and ambient detail. Session tokens prevent old speech from leaking into a new or stopped session.
7. `VisionHapticsService` provides a compact direction, found, lost, warning, and completion vocabulary. Speech remains the fallback when haptics are unavailable or disabled.
8. `VisionSessionMemory` retains only bounded observations needed for the active session. Stop and background transitions clear temporary results and cancel analysis and output.

## Bundled Object Detector

The build fetches Apple's native Core ML `YOLOv3TinyInt8LUT.mlmodel` and stores it locally as `JarvisObjectDetector.mlmodel`. It verifies all of the following before Xcode compiles and bundles the model:

- exact size: 8,913,366 bytes
- SHA-256: `cde8af2528d6eca1d1580fdd0f0147cb6613d40ba962656b5f683c65f571870e`
- Core ML specification version 3
- 416 by 416 RGB image input plus confidence and intersection-over-union threshold inputs
- non-maximum-suppression confidence and coordinate outputs
- the documented 80-class catalog
- manifest and human-readable license notice

The app validates the compiled model interface and class metadata when loading it. `ObjectDetectionService` supports Vision recognized-object output and the model's multi-array output schema, including coordinate conversion and duplicate suppression.

The selected detector does not recognize door, stairs, curb, step, or exit sign. Find requests for those targets return an explicit unsupported response. The model selection record and rejected NVIDIA candidates are documented in [Jarvis Vision Model Decision](JARVIS_VISION_MODEL_DECISION.md).

## Privacy and Persistence

- Core vision inference runs on the device after the app is installed.
- Camera photos and video are not automatically saved.
- Recognized text and barcode values are not added to general command history.
- Vision does not make network requests or expose a network-processing setting.
- Temporary scene memory is bounded to the active session and cleared on stop.
- Debug output records operational metadata, not camera frames or recognized private content.

Speech recognition is separate from camera analysis and may use Apple services depending on the language, device, and system availability described in the project privacy policy.

## Runtime Degradation

Automatic processing profiles react to Low Power Mode and iOS thermal state. The pipeline reduces sampling and analyzer frequency at serious or critical thermal levels. Diagnostics exposes the active profile, recent latency, dropped frames, model state, camera state, and analyzer availability. These controls require sustained physical-device testing before performance claims can be made for iPhone XR.

## Verification Scope

The repository includes unit tests for analyzers, output decoding, tracking, fusion, narration policy, speech priority, haptic vocabulary, and privacy invariants. The simulator unit target also compiles the fetched model and performs real inference on the public-domain `Desk_chair.jpg` fixture, then emits native observations for an independent execution and output-contract evaluator. The fixture is not treated as proof of general detector accuracy: the pinned model produced no detections for it in the first authoritative simulator run, while the request completed without a model or decoder error. The workflow defines privacy, safety, model, fixture, screenshot, and IPA audits and requires 28 visual proof states.

Run-specific CI evidence for the rewrite is pending until recorded in [Jarvis Vision Completion Ledger](JARVIS_VISION_COMPLETION_LEDGER.md). Physical iPhone XR camera accuracy, sustained latency, heat, battery use, audio routing, haptic feel, and VoiceOver interaction remain pending until a person completes the [First-Run and Physical-Device Checklist](FIRST_RUN_CHECKLIST.md).
