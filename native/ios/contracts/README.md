# JarvisOS iOS Contracts

These contracts define the message boundary between the native shell, `jarvisd`, and the SpringBoard tweak. They are design contracts for future jailbroken-device implementation. They are not proof that the behavior works on an iPhone 6.

v0.4 adds adapter status reporting expectations so the native shell can display whether a result came from a mock, future native bridge, or future dock bridge.

## v0.5 XR Device Mode

The active device is now iPhone XR on iOS 18.7.9. These contracts now serve two lanes:

- Native XR app lane for Jarvis Device Mode.
- Preserved jailbreak lane for future verified support.

SpringBoard hooks, launchd daemon install, root access, and system-wide button remaps are blocked on XR until verified and device-tested.
