# Jarvis Shell Implementation Plan v0.5 XR Device Mode

## Active Decision

The repo should stop treating iPhone 6 as the main target. The old Objective-C/UIKit skeletons remain useful for future jailbreak work, but the immediate native XR app likely benefits from Swift/UIKit or SwiftUI, pending build environment decision.

## Lane A: Native XR App, Primary Now

- Swift/UIKit or SwiftUI decision pending.
- AVFoundation camera and microphone.
- Vision and Core ML for still-image detection first.
- Speech or local STT investigation.
- AVSpeechSynthesizer or local TTS investigation.
- CoreLocation.
- CoreMotion.
- Local storage.
- App Intents.
- Shortcuts.
- `SFSafariViewController` or controlled browser/search flow.
- Spotify integration investigation.
- Designed for Single App Mode compatibility.

This lane is a native iOS app lane, not a website and not a web shell.

## Lane B: Objective-C/UIKit Jailbreak Lane, Preserved

- SpringBoard tweak.
- `jarvisd`.
- Theos.
- Rootless or rootful approach depending on a future verified jailbreak.
- Lock screen hooks.
- Auto-launch after respring.
- Button remaps.

This lane is blocked for iPhone XR iOS 18.7.9 until verified support exists.

## Immediate Native Questions For v0.6

- Does the user have a Mac with Xcode?
- Is Apple Developer free signing available?
- Is Apple Configurator available for supervised Single App Mode?
- Is the build path Swift/UIKit, SwiftUI, or Objective-C/UIKit shared with the jailbreak lane?
