# Jarvis Shell Implementation Plan v0.3

Jarvis Core v0.3 adds a native shell preparation layer that can eventually talk to `jarvisd`.

## New Pieces

- Objective-C generated model skeletons in `generated`.
- Objective-C UIKit shell skeletons in `JarvisShellNative`.
- `JVSCommandClient` as the native command boundary.
- `JVSLocalDaemonTransport` as the future local daemon transport placeholder.
- `JVSDesignTokens` for restrained iPhone 6 UI rules.

## Screen Responsibilities

- Home: mode, status orb, offline, online, dock, battery, and daemon state.
- Command: transcript, routed capability, risk, confidence, confirmation, response.
- Camera inspection: preview, freeze, OCR, object detect, flashlight, save observation.
- Sensor: compass, level, movement, pressure, GPS, availability.
- Capability browser: registry search and grouped tool list.
- Memory: notes, observations, command history, search, export.
- Dock: Pi or PC availability, sync, backup, package and model state.
- Safety: permissions, risky actions, jailbreak state, refusal reasons, recovery notes.

## What Can Be Built Before Jailbreak

Screen structure, generated models, bundled registry browsing, mock daemon transport, local app storage experiments, and public camera or sensor API experiments if a compatible build path exists.

## What Requires Device Testing

Real daemon transport, launchd startup, SpringBoard events, button or gesture activation, file paths outside the app sandbox, package installation, safe mode recovery, and any claim that Jarvis dominates the phone.
