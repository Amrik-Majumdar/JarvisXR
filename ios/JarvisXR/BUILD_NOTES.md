# JarvisXR Build Notes

JarvisXR is a native Swift/UIKit iOS app. The Windows machine cannot run the iOS build locally because `xcodebuild` and `xcodegen` are macOS tools.

## Verification Path

GitHub Actions macOS is the build verifier for this repo.

Workflow name:
`Build JarvisXR iOS IPA`

Expected unsigned artifact:
`JarvisXR-unsigned-ipa`

Expected IPA inside the artifact:
`JarvisXR-unsigned.ipa`

## Reading Build Logs

Open the workflow run and inspect:

- `JarvisXR-build-output`
- `build.log`
- `schemes.log`
- `test.log` if simulator tests ran
- `BUILD_REAL_APP_STATUS.md`

The build step must produce:
`ios/JarvisXR/build/DerivedData/Build/Products/Release-iphoneos/JarvisXR.app`

The package step must produce a non-empty:
`ios/JarvisXR/build/JarvisXR-unsigned.ipa`

## Windows Install Input

Download the `JarvisXR-unsigned-ipa` artifact from GitHub Actions, extract it if needed, then select `JarvisXR-unsigned.ipa` in Sideloadly.

No jailbreak tooling is involved. Guided Access is the current lockdown layer after install.
