# Architecture

## Shipping iOS App

`ios/JarvisXR` is the current product target. It is a Swift and UIKit application generated with XcodeGen.

```text
UIKit interface
  -> interaction state controller
  -> local command router
  -> local memory and settings
  -> AVSpeechSynthesizer output
  -> Speech + AVAudioEngine input
  -> AVFoundation camera
  -> Vision / optional Core ML
  -> App Intents, URL routes, and Control Mesh guidance
```

The app runs in the normal iOS sandbox and uses public frameworks.

## Command Flow

1. The user taps the orb for push-to-talk or submits text.
2. The interface enters Listening or Processing.
3. `JarvisCommandRouter` normalizes the command and creates a local response or action.
4. In-app actions open native screens such as Inspection, Settings, Help, or Diagnostics.
5. Supported external routes use public URLs, App Intents, or Control Mesh guidance.
6. `JarvisSpeechService` speaks the response when speech output is enabled.
7. `JarvisMemoryStore` persists allowed notes, settings, and history locally.

## Vision Flow

1. AVFoundation provides the rear-camera preview and photo capture.
2. Apple Vision analyzes the captured image for text, barcodes, and image classification.
3. A compatible bundled Core ML model can add object detection.
4. Results are rendered and optionally spoken.

## Supporting Python Core

`core/`, `tests/`, and `tools/` contain tested registry, adapter, routing, device-profile, daemon-contract, asset, IPA-audit, and CI support code. These modules support validation and future integration; they are not a root daemon installed by the shipping iOS app.

## Legacy Prototypes

`native/` preserves Objective-C shell, daemon, and jailbreak-era contracts from earlier research. They are not included in the current app target and do not prove system hooks or jailbreak support.
