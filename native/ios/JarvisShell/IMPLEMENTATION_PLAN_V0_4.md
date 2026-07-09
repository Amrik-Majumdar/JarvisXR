# Jarvis Shell Implementation Plan v0.4

Jarvis Core v0.4 makes the native UIKit skeleton more concrete while keeping it clearly uncompiled and untested on iPhone.

## Native Architecture Package

New shell classes:

- `JVSAppState`
- `JVSModeController`
- `JVSCommandSession`
- `JVSResponseRenderer`
- `JVSVoiceOrbView`
- `JVSStatusHeaderView`
- `JVSCapabilityListView`
- `JVSConfirmationView`
- `JVSSensorTileView`
- `JVSMemoryLogCell`
- `JVSCameraOverlayView`
- `JVSOfflineBannerView`
- `JVSDockStatusView`

## Daemon Handoff

`JVSCommandClient` remains the shell boundary. `JVSLocalDaemonTransport` remains a placeholder until a jailbreak-safe local IPC path is chosen and tested.

## Screen Behavior

The shell should render daemon mode, spoken response, display response, confirmation requirement, unavailable reason, candidate capabilities, and adapter status.

## Still Mocked

Camera preview, microphone capture, TTS, STT, OCR, object detection, GPS, sensors, dock sync, and jailbreak hooks are not proven by these files.

## Device Gate

Actual deployment waits for the iPhone 6 exact iOS version, jailbreak selection, build toolchain, package workflow, and first-device tests.
