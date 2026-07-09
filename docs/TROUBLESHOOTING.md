# Troubleshooting

## GitHub Actions Build Fails

1. Open the failed workflow step.
2. Download `JarvisXR-build-output`.
3. Check `xcodegen.log`, `schemes.log`, `xcodebuild-build.log`, unit-test logs, visual-proof logs, and `ipa-audit.log`.
4. Confirm the runner Xcode version includes the iOS 18 SDK.

## XcodeGen or Scheme Is Missing

Run:

```bash
cd ios/JarvisXR
xcodegen generate
xcodebuild -list -project JarvisXR.xcodeproj
```

The scheme must be named `JarvisXR`.

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
