# Building JARVIS XR

## Requirements

- macOS capable of running a current Xcode release with the iOS 18 SDK
- Xcode command line tools
- Homebrew
- XcodeGen
- Python 3.11 or newer
- Git

Windows and Linux cannot compile the native iOS target locally. They can run the Python validation suite and can use GitHub Actions for the macOS build.

## Clean Checkout

```bash
git clone https://github.com/Amrik-Majumdar/JarvisXR.git
cd JarvisXR
brew install xcodegen
xcodegen --version
xcodebuild -version
```

## Fetch and Verify the Detector

The detector is intentionally not committed as a large binary. From the repository root, fetch the exact Apple-hosted artifact and verify it before generating the Xcode project:

```bash
python3 tools/fetch_vision_model.py \
  --report ios/JarvisXR/build/reports/model-fetch.json
python3 tools/audit_vision_model.py \
  --require-model \
  --output ios/JarvisXR/build/reports/vision-model-audit.json
```

The fetch is atomic and fails if the artifact is not exactly 8,913,366 bytes with SHA-256 `cde8af2528d6eca1d1580fdd0f0147cb6613d40ba962656b5f683c65f571870e`. Xcode compiles the verified `JarvisObjectDetector.mlmodel` into the app. The machine-readable manifest, human-readable notice, class list, schema, source URL, and license record are tracked under `ios/JarvisXR/JarvisXR/Models`.

Do not substitute or redistribute a different model under the same name. Review [Model Decision](JARVIS_VISION_MODEL_DECISION.md) and the model directory's `MODEL_LICENSE.md` before changing the detector.

## Generate the Project

```bash
cd ios/JarvisXR
xcodegen generate
xcodebuild -list -project JarvisXR.xcodeproj
```

`JarvisXR.xcodeproj` is generated and is intentionally not the source of truth. Edit `project.yml` when project configuration changes.

## Simulator Unit Tests and Native Fixture Evaluation

```bash
mkdir -p build/reports
VISION_EVALUATION_OUTPUT="$PWD/build/reports/native-vision-observations.json" \
xcodebuild \
  -project JarvisXR.xcodeproj \
  -scheme JarvisXR \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  -only-testing:JarvisXRTests \
  test
```

Simulator device names vary by installed Xcode. Run `xcrun simctl list devices available` and choose an available iPhone when needed.

The unit target covers detector output decoding, tracking, scene fusion, reading order, camera quality, barcode deduplication, safe narration, session-scoped speech, haptic vocabulary, and privacy invariants. It also loads the bundled model and performs real inference against the public-domain `Desk_chair.jpg` fixture. Validate the native execution and observation contract from the repository root:

```bash
cd ../..
python3 tools/evaluate_vision_fixtures.py \
  --observations ios/JarvisXR/build/reports/native-vision-observations.json \
  --output ios/JarvisXR/build/reports/vision-fixture-native.json
python3 tools/audit_vision_safety.py \
  --output ios/JarvisXR/build/reports/vision-safety-audit.json
python3 tools/audit_vision_privacy.py \
  --output ios/JarvisXR/build/reports/vision-privacy-audit.json
```

These are simulator and static-policy checks. They do not measure physical iPhone XR latency, sustained temperature, battery use, camera accuracy, audio routing, or haptic feel.

## UI Tests and Visual Proof

The `JarvisXRUITests` target verifies accessible navigation and deterministic fixture states. The workflow also captures and validates 28 PNG states covering the main assistant, all six Vision modes, permissions, model failure, settings, help, diagnostics, self-test, and onboarding.

## Unsigned Device Build

```bash
xcodebuild \
  -project JarvisXR.xcodeproj \
  -scheme JarvisXR \
  -configuration Release \
  -sdk iphoneos \
  -destination 'generic/platform=iOS' \
  -derivedDataPath build/DerivedData \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  clean build
```

The unsigned `.app` appears under:

```text
ios/JarvisXR/build/DerivedData/Build/Products/Release-iphoneos/JarvisXR.app
```

The GitHub Actions workflow packages it as `Payload/JarvisXR.app` inside `JarvisXR-unsigned.ipa`, then audits the bundle structure, executable, arm64 slice, privacy usage descriptions, compiled model, manifest, notice, signing state, and common secret patterns.

## GitHub Actions

1. Fork the repository.
2. Enable Actions for the fork.
3. Open **Actions > Build JarvisXR iOS IPA**.
4. Choose **Run workflow**.
5. Download the relevant artifacts:

   - `JarvisXR-unsigned-ipa`
   - `JarvisXR-ios-screenshot-proof`
   - `JarvisXR-vision-evaluation`
   - `JarvisXR-xcresults`
   - `JarvisXR-build-output`
   - `JarvisXR-windows-validation-reports`

Artifacts expire according to GitHub retention policy. Release assets remain available until removed.

The workflow is configured to fetch and verify the detector, run the Python gates, build an unsigned arm64 app, run Swift unit and UI tests, execute the real simulator fixture, evaluate safety and privacy policy, capture 28 visual states, audit the IPA, and upload logs and reports even when diagnostic steps fail. Run-specific pass evidence for the current rewrite remains pending in [Vision Completion Ledger](JARVIS_VISION_COMPLETION_LEDGER.md) until the release run is recorded.

## Reproducibility Scope

The repository contains the source, pinned model contract, checksums, fixture provenance, and configuration needed to regenerate the Xcode project and run the build workflow. Builds are not claimed to be bit-for-bit identical because GitHub runner images, Xcode, SDKs, Homebrew packages, and Apple tooling can change.

The current workflow pins the hosted macOS 26 runner label and Xcode 26.5 path configured for the release build. GitHub may eventually retire hosted images or action versions; future updates must be validated by a complete workflow run before merge.
