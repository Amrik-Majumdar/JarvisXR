# Troubleshooting

## GitHub Actions Build Fails

1. Open the failed workflow step.
2. Download `JarvisXR-build-output`.
3. Check `xcodegen.log`, `schemes.log`, `xcodebuild-build.log`, unit-test logs, visual-proof logs, and `ipa-audit.log`.
4. Confirm the runner Xcode version includes the iOS 18 SDK.

## XcodeGen or Scheme Is Missing

Run:

```bash
python3 tools/fetch_vision_model.py
python3 tools/audit_vision_model.py --require-model
cd ios/JarvisXR
xcodegen generate
xcodebuild -list -project JarvisXR.xcodeproj
```

The scheme must be named `JarvisXR`.

## Object Model Is Missing or Invalid

Do not replace the model with a similarly named file. From the repository root, run the pinned fetch and audit commands above, then regenerate the Xcode project. In CI, inspect `model-fetch.json`, `vision-model-audit.json`, the unit-test result bundle, and `ipa-audit.json` in the uploaded artifacts. The exact expected digest and interface are recorded in `ios/JarvisXR/JarvisXR/Models/JarvisObjectDetector.manifest.json`.

Read Text, Barcode, and Color can remain available when object-model validation fails. Describe, Live Guide, and Find must report the failure rather than silently substitute unverified object results.

## IPA Is Missing

Confirm the device build produced:

```text
ios/JarvisXR/build/DerivedData/Build/Products/Release-iphoneos/JarvisXR.app
```

Then inspect `ipa-audit.log`. Do not sideload an artifact from a failed or cancelled run.

## Phone Is Not Detected

- Unlock the iPhone
- reconnect with a data-capable USB cable
- approve **Trust This Computer**
- install or repair Apple device drivers
- restart the sideloading tool

## App Cannot Run

- approve the developer profile if iOS requests it
- enable Developer Mode when required
- confirm the signing certificate has not expired
- reinstall or refresh the signed app

## Camera or Speech Is Unavailable

Open iOS Settings and review JARVIS permissions. Speech recognition availability can depend on language, device, network state, and Apple service availability.

## App Opens Then Closes

Reinstall an IPA from a successful workflow. Record the last screen and action. Do not post Apple ID details, provisioning data, device identifiers, or private note content.

## Guided Access Cannot Exit

Use the Guided Access passcode or configured Face ID exit. Test the exit path before dedicated use. If necessary, follow Apple's official Guided Access recovery instructions for the installed iOS version.
