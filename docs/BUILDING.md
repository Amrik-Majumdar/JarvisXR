# Building JARVIS XR

## Requirements

- macOS capable of running a current Xcode release with the iOS 18 SDK
- Xcode command line tools
- Homebrew
- XcodeGen
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

## Generate the Project

```bash
cd ios/JarvisXR
xcodegen generate
xcodebuild -list -project JarvisXR.xcodeproj
```

`JarvisXR.xcodeproj` is generated and is intentionally not the source of truth. Edit `project.yml` when project configuration changes.

## Simulator Tests

```bash
xcodebuild \
  -project JarvisXR.xcodeproj \
  -scheme JarvisXR \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  test
```

Simulator device names vary by installed Xcode. Run `xcrun simctl list devices available` and choose an available iPhone when needed.

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

The GitHub Actions workflow packages it as `Payload/JarvisXR.app` inside `JarvisXR-unsigned.ipa`.

## GitHub Actions

1. Fork the repository.
2. Enable Actions for the fork.
3. Open **Actions > Build JarvisXR iOS IPA**.
4. Choose **Run workflow**.
5. Download the unsigned IPA, screenshot proof, and build-output artifacts.

Artifacts expire according to GitHub retention policy. Release assets remain available until removed.

## Reproducibility Scope

The repository contains the complete source and configuration needed to regenerate the Xcode project and run the build workflow. Builds are not claimed to be bit-for-bit identical because GitHub runner images, Xcode, SDKs, Homebrew packages, and Apple tooling can change.
