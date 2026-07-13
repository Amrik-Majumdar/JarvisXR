# Features and Limits

## Implemented

- Native Swift and UIKit interface with VoiceOver labels, Dynamic Type, contrast support, and reduced-motion behavior
- Natural typed commands plus ready-to-listen and accessible in-app voice control through Speech and AVAudioEngine
- Local speech output through `AVSpeechSynthesizer`, including persistent distinct profile configuration, installed-voice fallback, rate adjustment, and session-scoped priority for warnings, requested targets, scene changes, and essential status
- Persistent voice and Vision preferences, notes, and command history with explicit clear controls
- Accessible contact selection and in-memory message drafting with readback, explicit confirmation, and the standard iOS message composer
- AVFoundation rear or front camera preview, continuous task frames, optional internal still capture, torch, focus, exposure, white balance, first-frame diagnostics, interruption handling, and foreground lifecycle
- Six Jarvis Vision modes: Describe, Live Guide, Find, Read Text, Barcode, and Color
- Checksum-pinned `YOLOv3TinyInt8LUT` Core ML detector with 80 documented classes, manifest validation, and bundled license notice
- Model-agnostic detector interface, frame backpressure, generation-token cancellation, temporal tracking, scene fusion, debug-only replay, and bounded session memory
- Vision OCR, spoken reading controls, barcode and QR deduplication, face and person counting, common-color naming, and temporal camera-quality guidance that distinguishes invalid, black, light, blur, motion, and sustained obstruction states
- Safety policy that filters weak or stale observations, qualifies absence, rejects unsupported targets, and prohibits path-clear claims
- Direction, target-found, target-lost, warning, and completion haptics with speech fallback
- Diagnostics for model and analyzer availability, camera state, dropped frames, latency, haptics backend, thermal state, and degradation profile
- Low Power Mode and thermal degradation for continuous processing
- App Intents, `jarvis://` deep links, Control Mesh public-API guidance, and Guided Access setup guidance

## Device or Configuration Dependent

- Speech recognition quality and whether Apple can process it fully on-device
- Installed speech voices, volume, silent behavior, interruptions, and Bluetooth or wired audio routing
- Camera, front-camera, torch, autofocus, exposure, and Core Haptics availability
- Physical-device detector accuracy, frame rate, sustained latency, heat, memory pressure, and battery use
- VoiceOver rotor and focus behavior with the user's selected accessibility settings
- External app URL schemes
- Shortcuts, Vocal Shortcuts, Voice Control, and Guided Access configuration
- Sideload signing duration and refresh behavior

## Detector Limits

The bundled detector can identify only the classes recorded in `JarvisObjectDetector.manifest.json`. Door, stairs, curb, step, and exit sign are not model classes and are reported as unsupported. Broad left, center, and right guidance is camera-relative, not a measurement of safe walking space. Text, barcode, person, camera-quality, and color analyzers provide additional evidence but do not fill unsupported object classes by inference.

## Not Implemented

- Safety-certified navigation, obstacle avoidance, crossing clearance, or depth measurement
- Face recognition or identity inference
- Automatic opening of scanned links
- Automatic storage or upload of camera frames, recognized text, or barcode values
- Background Live Guide or background wake word
- Arbitrary global floating assistant overlay
- Hidden reading of other apps
- Injected taps or scrolling in other apps
- Lock-screen replacement
- SpringBoard hooks
- Root or launchd daemon
- Global hardware-button remapping
- Firmware replacement
- Guaranteed offline general-purpose language-model reasoning

These limits follow stock iOS security, public API boundaries, the selected detector's documented schema, and explicit safety policy. The shipping app does not include private APIs, jailbreak hooks, CUDA, TensorRT, DeepStream, or a remote inference backend.
