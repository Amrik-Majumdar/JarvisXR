# Features and Limits

## Implemented

- Native Swift and UIKit interface
- Typed local commands
- In-app push-to-talk through Speech and AVAudioEngine
- Local speech output through AVSpeechSynthesizer
- Persistent voice profile, speech toggle, notes, and history
- Rear-camera preview, capture, torch, autofocus, and exposure configuration
- Vision text recognition, barcode and QR detection, and image classification
- Optional Core ML model discovery
- App Intents and `jarvis://` deep links
- Control Mesh guidance for public accessibility and automation routes
- Guided Access setup guidance

## Device or Configuration Dependent

- Speech recognition quality and whether Apple can process it fully on-device
- Installed speech voices
- Camera and torch availability
- External app URL schemes
- Shortcuts, Vocal Shortcuts, Voice Control, and Guided Access configuration
- Compatible Core ML object detection model
- Sideload signing duration and refresh behavior

## Not Implemented

- Background wake word
- Arbitrary global floating assistant overlay
- Hidden reading of other apps
- Injected taps or scrolling in other apps
- Lock-screen replacement
- SpringBoard hooks
- Root or launchd daemon
- Global hardware-button remapping
- Firmware replacement
- Guaranteed offline general-purpose language-model reasoning

These limits follow stock iOS security and public API boundaries.
