# Public Release Handoff

## Current Product

The shipping source is the Swift and UIKit app under `ios/JarvisXR`. Jarvis Vision provides Describe, Live Guide, Find, Read Text, Barcode, and Color modes through a model-agnostic, on-device pipeline with tracking, scene fusion, safe narration, priority speech, haptics, diagnostics, privacy controls, and thermal degradation.

The build fetches Apple's `YOLOv3TinyInt8LUT` detector, verifies its pinned size and SHA-256, and bundles the compiled model, manifest, and notice. GitHub Actions is configured to generate the project, validate the repository, build the unsigned arm64 app, run simulator unit and UI tests, execute real fixture inference, capture 28 visual states, audit safety, privacy, model, and IPA surfaces, and upload evidence artifacts. Run-specific pass evidence for the current rewrite remains pending in [Jarvis Vision Completion Ledger](JARVIS_VISION_COMPLETION_LEDGER.md).

## Installation Path

1. Download the prerelease IPA or build from source.
2. Sign and sideload it with an authorized Apple ID.
3. Complete the first-run checklist.
4. Enable Guided Access only after testing the exit path.

Simulator and CI evidence does not replace physical-device checks for live camera accuracy, speech input, audio routes, haptic feel, signing, sustained heat, battery use, VoiceOver focus, or Guided Access. No physical iPhone XR success is claimed until the checklist is completed and recorded.

## Preserved Boundaries

The app uses public APIs and does not provide jailbreak hooks, root access, hidden screen reading, injected taps, a lock-screen replacement, or unrestricted system control.

## Source of Truth

- Product source: `ios/JarvisXR`
- Project configuration: `ios/JarvisXR/project.yml`
- CI: `.github/workflows/ios-build.yml`
- Public docs: `docs/README.md`
- Vision evidence status: `docs/JARVIS_VISION_COMPLETION_LEDGER.md`
- Detector decision and acceptance boundary: `docs/JARVIS_VISION_MODEL_DECISION.md`
- Release artifact: GitHub Releases
