<div align="center">
  <img src="assets/visual_reference/jarvis_orb_clean_icon_reference.png" width="132" alt="JARVIS orb logo">

  # JARVIS XR

  **A native, offline-first assistant interface for iPhone XR**

  Voice and typed commands, visual inspection, local memory, configurable speech,
  and public-API iOS automation guidance in one focused UIKit experience.

  [![iOS 18+](https://img.shields.io/badge/iOS-18%2B-111827?style=for-the-badge&logo=apple)](ios/JarvisXR/project.yml)
  [![Swift 5.9](https://img.shields.io/badge/Swift-5.9-F05138?style=for-the-badge&logo=swift&logoColor=white)](ios/JarvisXR/JarvisXR)
  [![Build](https://img.shields.io/github/actions/workflow/status/Amrik-Majumdar/JarvisXR/ios-build.yml?branch=main&style=for-the-badge&label=Build)](https://github.com/Amrik-Majumdar/JarvisXR/actions/workflows/ios-build.yml)
  [![Release](https://img.shields.io/github/v/release/Amrik-Majumdar/JarvisXR?include_prereleases&style=for-the-badge&label=RC)](https://github.com/Amrik-Majumdar/JarvisXR/releases)
  [![License: GPLv3+](https://img.shields.io/badge/License-GPLv3%2B-2C8EBB?style=for-the-badge&logo=gnu)](LICENSE)

  [Download RC](https://github.com/Amrik-Majumdar/JarvisXR/releases) |
  [Install Guide](docs/INSTALLING_ON_IPHONE.md) |
  [Build From Source](docs/BUILDING.md) |
  [Documentation](docs/README.md)
</div>

> [!IMPORTANT]
> JARVIS XR is a native iOS prototype built exclusively with public APIs. It is not a jailbreak, firmware replacement, hidden system service, or unrestricted phone-control layer.

## Product Overview

JARVIS XR turns a dedicated iPhone into a focused assistant surface without relying on a browser UI or paid cloud APIs. The app centers interaction on a reactive orb, push-to-talk speech recognition, typed commands, local speech output, and camera-based visual inspection.

| Native interaction | Local intelligence | Device integration |
|---|---|---|
| Distinct standby, listening, processing, speaking, and inspection states | Local command routing, notes, history, and configurable responses | Camera, microphone, speech, Vision, App Intents, deep links, and Guided Access guidance |
| Voice-first interface with dependable typed fallback | OCR, barcode recognition, and built-in Vision image classification | Control Mesh routes supported actions through public iOS mechanisms |

## Interface

<table>
  <tr>
    <td align="center" width="50%"><a href="assets/screenshots/ready.png"><img src="assets/screenshots/ready.png" width="300" alt="JARVIS ready state"></a><br><sub><b>Ready</b></sub></td>
    <td align="center" width="50%"><a href="assets/screenshots/listening.png"><img src="assets/screenshots/listening.png" width="300" alt="JARVIS listening state"></a><br><sub><b>Listening</b></sub></td>
  </tr>
  <tr>
    <td align="center" width="50%"><a href="assets/screenshots/inspection.png"><img src="assets/screenshots/inspection.png" width="300" alt="JARVIS inspection mode"></a><br><sub><b>Inspection</b></sub></td>
    <td align="center" width="50%"><a href="assets/screenshots/control-mesh.png"><img src="assets/screenshots/control-mesh.png" width="300" alt="JARVIS Control Mesh"></a><br><sub><b>Control Mesh</b></sub></td>
  </tr>
  <tr>
    <td align="center" colspan="2"><a href="assets/screenshots/settings.png"><img src="assets/screenshots/settings.png" width="300" alt="JARVIS settings"></a><br><sub><b>Settings</b></sub></td>
  </tr>
</table>

<p align="center"><sub>Each screen uses the same display scale. Select any image to open the full-resolution proof.</sub></p>

Portrait-first UIKit layout, full-screen dark interface, accessible labels, local settings, and a restrained visual system built around one central control surface.

## Capabilities

| Area | Current implementation | Boundary |
|---|---|---|
| Voice input | In-app push-to-talk using Apple's Speech framework | Recognition availability and on-device processing vary by device, language, and Apple service state |
| Voice output | `AVSpeechSynthesizer` with persistent voice profiles | Installed system voices determine final sound |
| Visual inspection | AVFoundation capture, Vision OCR, QR/barcode recognition, and image classification | External object detection requires a compatible bundled Core ML model |
| Memory | Local notes, command history, search, and clear controls | Stored in the app container; removing the app can remove local data |
| Control Mesh | Deep links, App Intents, Shortcuts guidance, Voice Control phrases, and public app URL routes | No injected taps, hidden screen reading, global overlay, or private system hooks |
| Appliance use | Guided Access setup and dedicated-device workflow | iOS remains the operating system and security authority |

## Start Here

### Install the release candidate

1. Read the [iPhone installation guide](docs/INSTALLING_ON_IPHONE.md).
2. Download `JarvisXR-unsigned.ipa` from the [latest prerelease](https://github.com/Amrik-Majumdar/JarvisXR/releases).
3. Sign and sideload it with AltServer, Sideloadly, or another tool you trust.
4. Complete the [first-run checklist](docs/FIRST_RUN_CHECKLIST.md) before enabling Guided Access.

### Build it yourself

```bash
git clone https://github.com/Amrik-Majumdar/JarvisXR.git
cd JarvisXR/ios/JarvisXR
brew install xcodegen
xcodegen generate
xcodebuild -project JarvisXR.xcodeproj \
  -scheme JarvisXR \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  CODE_SIGNING_ALLOWED=NO test
```

Native builds require macOS and Xcode. Windows and Linux can run the Python validation suite, while the included GitHub Actions workflow performs the macOS build, simulator tests, visual proof capture, IPA audit, and unsigned IPA packaging.

See [Building](docs/BUILDING.md) for the complete reproducible path.

## Verification

Every app-affecting push runs the following gates:

```text
Registry validation -> Python tests -> XcodeGen -> iPhoneOS build
-> Swift unit tests -> simulator visual proof -> IPA audit -> artifacts
```

The workflow uploads:

- `JarvisXR-unsigned-ipa`
- `JarvisXR-ios-screenshot-proof`
- `JarvisXR-build-output`

The build is reproducible from source through a documented CI process. It is not claimed to be bit-for-bit deterministic across changing Xcode or macOS toolchains.

## Privacy and Safety

JARVIS XR has no developer-operated analytics, advertising, account, or cloud backend. Notes and command history remain in the app container. Camera analysis runs through Apple frameworks in the app. Speech recognition may be processed on-device or by Apple depending on device and language support.

Read the full [Privacy Policy](PRIVACY.md), [Terms](TERMS.md), [Security Policy](SECURITY.md), and [Disclaimer](DISCLAIMER.md) before installation.

## Public API Limits

Stock iOS does not permit this app to:

- replace SpringBoard or the lock screen
- install a root or launchd daemon
- read arbitrary content from other apps
- inject taps into other apps
- remap system buttons globally
- display arbitrary floating UI over other apps
- provide unrestricted background listening

JARVIS coordinates supported actions through public APIs and accessibility features. See [Features and Limits](docs/FEATURES_AND_LIMITS.md).

## Repository Map

```text
ios/JarvisXR/       Shipping Swift and UIKit app
core/               Tested command, registry, adapter, and device contracts
mock/               Mock phone state and CLI helpers required by router tests
native/             Preserved legacy native and jailbreak-era prototypes
preview/            Optional Windows interaction preview
tests/              Python validation entry point
tools/              Build, asset, IPA, and visual-proof utilities
assets/             Logo references and curated screenshots
docs/               Public build, install, architecture, and usage guides
.github/             CI workflow and contribution templates
```

The app under `ios/JarvisXR` is the current product. Files under `native/` are preserved prototypes and are not part of the shipping iOS target.

## Project Documents

| Build and install | Product and internals | Trust and support |
|---|---|---|
| [Building](docs/BUILDING.md) | [Architecture](docs/ARCHITECTURE.md) | [Privacy](PRIVACY.md) |
| [Install on iPhone](docs/INSTALLING_ON_IPHONE.md) | [Features and limits](docs/FEATURES_AND_LIMITS.md) | [Security](SECURITY.md) |
| [First run](docs/FIRST_RUN_CHECKLIST.md) | [Vision pipeline](docs/VISION.md) | [Support](SUPPORT.md) |
| [Troubleshooting](docs/TROUBLESHOOTING.md) | [Control Mesh](docs/CONTROL_MESH.md) | [Contributing](CONTRIBUTING.md) |

## License

Current software is licensed under [GNU GPLv3 or later](LICENSE), with permitted attribution and origin terms under [GPLv3 section 7](ADDITIONAL_TERMS.md). Distributed modifications must remain under the GPL, preserve copyright and legal notices, identify changes, and provide corresponding source as the license requires.

Original branding, logo artwork, screenshots, and visual reference assets use separate [CC BY-NC-SA 4.0 terms](ASSET_LICENSE.md). Commercial use of those assets requires written permission. See [Attribution](ATTRIBUTION.md) and [CITATION.cff](CITATION.cff).

Apple, iPhone, iOS, Siri, Speech, Vision, Core ML, Xcode, and related marks belong to Apple Inc. JARVIS XR is an independent project and is not affiliated with or endorsed by Apple.
