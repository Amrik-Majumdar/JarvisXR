# Jarvis Shell Implementation Plan v0.2

This is a native iOS preparation plan. It is not a compiled app claim.

## View Controller Structure

- `JarvisRootController`: owns portrait lock, shell navigation, daemon status, and global mode state.
- `JarvisHomeViewController`: central orb, mode strip, system state, and primary command button.
- `JarvisCommandViewController`: transcript, routed capability, confidence, candidates, confirmation, and execution output.
- `JarvisInspectionViewController`: native camera preview, freeze frame, OCR action, object action, flashlight, save observation.
- `JarvisSensorViewController`: compass, level, motion, barometer, GPS, proximity, and availability states.
- `JarvisCapabilityBrowserViewController`: searchable table grouped by mode, family, hardware, and risk.
- `JarvisMemoryViewController`: local notes, observations, command history, search, export, and private mode state.
- `JarvisDockViewController`: dock availability, backup status, package version, model version, and sync actions.
- `JarvisSafetyViewController`: permissions, confirmations, unavailable capabilities, jailbreak state, and recovery notes.

## Native Components

- `UITableView` or `UICollectionView` for capability and memory lists.
- `AVCaptureSession` for camera preview when available.
- `CoreMotion` wrappers for level and movement.
- `CLLocationManager` for GPS and compass where permission allows.
- `AVSpeechSynthesizer` for local spoken output if available.
- `URLSession` or local socket client only for daemon bridge or dock bridge.

## Command State Model

```swift
struct JarvisCommandState {
    let transcript: String
    let capabilityId: String?
    let confidence: Double
    let mode: String
    let riskLevel: String
    let requiresConfirmation: Bool
    let unavailableReason: String?
}
```

## Camera Mode Model

Tracks camera permission, preview state, flashlight state, frozen frame, OCR result, object result, saved observation ID, and thermal or battery warning.

## Sensor Mode Model

Tracks availability and last values for GPS, compass, accelerometer, gyroscope, barometer, proximity, and ambient light where accessible.

## Memory and Log Model

Tracks notes, observations, command history, search results, private mode, export status, and clear-test-data confirmation.

## Shell to Daemon Bridge

Before jailbreak, the shell can use bundled registry data and local app storage. After jailbreak, it should talk to `jarvisd` through the contract in `native/ios/contracts/SHELL_DAEMON_CONTRACT.md`.

## Buildable Before Jailbreak

- Screen structure.
- Bundled capability browser.
- Local command display.
- Mock or app-local memory.
- Camera and sensor flows available through public APIs.

## Requires Device Testing

- launchd daemon connection.
- SpringBoard return-to-Jarvis behavior.
- Button or gesture activation.
- File paths outside app sandbox.
- Any jailbreak-only capability.
