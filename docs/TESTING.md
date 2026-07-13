# Testing

## Python Validation

Install Python 3.11 or newer and pytest:

```bash
python -m pip install pytest
python tests/run_all_tests.py
```

The runner validates legacy registry and router contracts plus the Jarvis Vision model manifest, checksum contract, fixture provenance, expected annotations, safety language, privacy invariants, IPA audit behavior, generated project surface, and required screenshot inventory. A metadata-only fixture check never counts as inference.

## Windows Preview

```powershell
python preview/windows_jarvis_preview/jarvis_preview.py --self-test
python preview/windows_jarvis_preview/jarvis_preview.py
```

The preview is an interaction check, not proof of UIKit, Core ML, AVFoundation, VoiceOver, speech, or haptic behavior.

## Camera-quality Replay on Windows

The portable replay executes the same `CameraQualityMetricsEngine` used by the production analyzer. It validates the false-covered regression boundary: an initial black frame is not treated as a covered lens, a valid blank/blurred frame remains eligible for inference, and only sustained dark uniform evidence becomes obstruction.

```powershell
swiftc ios/JarvisXR/JarvisXR/CameraQualityMetricsEngine.swift `
  tools/vision-replay/CameraQualityReplayCLI.swift `
  -o ios/JarvisXR/build/local-replay/camera-quality-replay.exe
ios/JarvisXR/build/local-replay/camera-quality-replay.exe
```

This portable check does not replace iOS XCTest, AVFoundation capture, Vision/Core ML inference, VoiceOver, speech, haptics, or an iPhone camera test. Debug builds additionally contain the in-app 17-scenario Replay Lab, which must be run on an Apple-platform build.

## Swift Unit Tests

Fetch the pinned model and generate the project as described in [Building](BUILDING.md). Run the unit target on an available iPhone simulator with an observations output path:

```bash
cd ios/JarvisXR
mkdir -p build/reports
VISION_EVALUATION_OUTPUT="$PWD/build/reports/native-vision-observations.json" \
xcodebuild \
  -project JarvisXR.xcodeproj \
  -scheme JarvisXR \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath build/TestDerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -only-testing:JarvisXRTests \
  test
```

The tests cover detector schema decoding and error cases, real model inference, OCR order, temporal camera quality, color classification, barcode deduplication, person fusion, tracking, scene fusion, safe narration, distinct speech profiles and cancellation, quiet-guide status behavior, haptic patterns, replay-scenario inventory, preferences, and session-memory privacy.

## Real Simulator Inference

The `VisionAnalyzerPipelineTests` target loads the bundled compiled Core ML model and analyzes the public-domain `Desk_chair.jpg` fixture. It writes the execution result, labels, confidence, normalized boxes, narration, latency, and policy decision to `native-vision-observations.json`. From the repository root, evaluate that native output:

```bash
python3 tools/evaluate_vision_fixtures.py \
  --observations ios/JarvisXR/build/reports/native-vision-observations.json \
  --output ios/JarvisXR/build/reports/vision-fixture-native.json
```

The release gate requires successful real model execution, a finite latency, structurally valid finite observations when any are returned, and safe narration. It also records chair recall, localization overlap, and false positives as fixture accuracy evidence without treating one image as a release-wide accuracy threshold. The pinned model returned no detections for this fixture in the first authoritative simulator run, so that limitation remains explicit rather than being hidden through threshold tuning. A missing observations file, model error, malformed output, or unsafe narration still fails the workflow.

## UI and Visual Proof

`JarvisXRUITests` exercises accessible navigation and deterministic states on dynamically measured compact and large available iPhone simulators. The workflow captures 29 screenshots and `tools/verify_visual_proof.py` rejects missing or empty files. The states cover the main assistant, all Vision modes, target guidance, reading, barcode results, permission denial, model unavailability, settings, help, diagnostics, self-test, Device Acceptance Mode, and onboarding.

Visual proof confirms rendered simulator states. It does not confirm live camera analysis, audible output, haptic feel, or physical-device accessibility.

## Device Acceptance Mode

Say “run the complete device test,” invoke the matching Shortcut, or select **Complete Device Test** in Diagnostics. Jarvis runs available automatic checks, then asks for physical confirmation of flashlight, haptics, speech profiles, rear-camera cover/recovery, and live camera/vision evidence. Every result is labeled automated, user-confirmed, unavailable, skipped, or attention required; it never converts a skipped or unavailable physical check into a pass.

The completed or stopped report is written only to the app's local Application Support container and may be shared explicitly with the system share sheet. It contains no camera frame, image, OCR text, barcode value, audio recording, network upload, or telemetry. See [Device Acceptance Mode](DEVICE_ACCEPTANCE.md) for the exact procedure and evidence boundary.

## Model, Safety, and Privacy Audits

```bash
python3 tools/audit_vision_model.py --require-model
python3 tools/audit_vision_safety.py
python3 tools/audit_vision_privacy.py
```

The model audit checks bytes, digest, schema metadata, classes, source, and notices. The safety audit rejects prohibited path-clear language and unsupported-target overclaims. The privacy audit checks that vision frames, OCR, barcodes, and temporary scene observations do not gain an unintended persistence or network path.

## IPA Audit

```bash
python tools/audit_ipa.py path/to/JarvisXR-unsigned.ipa \
  --json-output ios/JarvisXR/build/reports/ipa-audit.json
```

The audit checks package structure, executable and arm64 evidence, property list and privacy descriptions, compiled assets, launch resources, app icon evidence, App Intents metadata, compiled object model, detector manifest and notice, unsigned state, and common secret patterns.

## Evidence Boundary

The workflow is configured to retain XCTest result bundles, native vision reports, 29 PNG proof states, build logs, the audited unsigned IPA, IPA evidence, and Windows validation reports. Run-specific CI results for this rewrite remain pending until recorded in [Vision Completion Ledger](JARVIS_VISION_COMPLETION_LEDGER.md).

Simulator and static-audit success do not prove microphone, live camera accuracy, permissions on a previously used phone, audio routing, haptic feel, signing, Guided Access, sustained performance, heat, or battery behavior. Use [First-Run and Physical-Device Checklist](FIRST_RUN_CHECKLIST.md) after every reinstall and report that evidence separately.
