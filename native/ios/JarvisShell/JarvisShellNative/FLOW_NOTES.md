# Native Flow Notes v0.4

These are native UIKit flow notes for the future iPhone 6 shell. They are not device-tested behavior.

## Boot Into Jarvis Home

- Starting screen: `JVSRootViewController`.
- User action: app launch, jailbreak auto-launch later.
- Daemon request: `health_check`, then `get_phone_state`.
- Expected daemon response: service status and phone state.
- UI state transition: root embeds home, status header updates.
- Spoken response behavior: silent unless recovery state is detected.
- Failure state: show offline banner and daemon unavailable message.

## Wake Or Button-Triggered Command

- Starting screen: any shell screen.
- User action: future tested button or gesture event.
- Daemon request: none until transcript exists.
- Expected daemon response: not applicable.
- UI state transition: command screen opens with listening state.
- Spoken response behavior: short local ready tone later.
- Failure state: remain on current screen if activation hook is unavailable.

## Push-To-Talk Command

- Starting screen: home or command screen.
- User action: hold command control.
- Daemon request: `execute_command` after transcript is available.
- Expected daemon response: route result or refusal.
- UI state transition: orb listening, then routing, then result.
- Spoken response behavior: speak `spoken_response` through local TTS path later.
- Failure state: microphone unavailable refusal.

## Command Routed To Daemon

- Starting screen: command screen.
- User action: submit transcript.
- Daemon request: `execute_command`.
- Expected daemon response: stable jarvis response shape.
- UI state transition: render capability, risk, mode, candidates, and output.
- Spoken response behavior: hand off response text to TTS adapter.
- Failure state: show unavailable reason and candidate capabilities.

## Confirmation Required

- Starting screen: command screen.
- User action: risky command.
- Daemon request: `execute_command`.
- Expected daemon response: `confirmation_required` with token.
- UI state transition: show `JVSConfirmationView`.
- Spoken response behavior: state confirmation requirement.
- Failure state: invalid or expired token refusal.

## Camera Inspection

- Starting screen: home or command screen.
- User action: scan this or inspection mode.
- Daemon request: `execute_command` with `scan this`.
- Expected daemon response: camera adapter result.
- UI state transition: camera inspection screen shows overlay.
- Spoken response behavior: concise inspection status.
- Failure state: camera unavailable refusal.

## OCR Scan

- Starting screen: camera inspection screen.
- User action: OCR control or read this label.
- Daemon request: `execute_command`.
- Expected daemon response: OCR adapter result.
- UI state transition: text result panel opens.
- Spoken response behavior: read extracted text only when requested.
- Failure state: camera or OCR unavailable.

## Object Detection Scan

- Starting screen: camera inspection screen.
- User action: object scan control.
- Daemon request: `execute_command`.
- Expected daemon response: vision adapter result.
- UI state transition: object list overlay updates.
- Spoken response behavior: summarize top detections.
- Failure state: camera or vision unavailable.

## Sensor Mode

- Starting screen: home.
- User action: sensor mode.
- Daemon request: `set_mode` then sensor command.
- Expected daemon response: mode accepted and sensor adapter data.
- UI state transition: sensor tiles update.
- Spoken response behavior: only for explicit readback.
- Failure state: sensors unavailable.

## Field Mode

- Starting screen: home.
- User action: start field mode.
- Daemon request: `set_mode` or `execute_command`.
- Expected daemon response: field mode accepted if safe.
- UI state transition: field controls and memory logging become prominent.
- Spoken response behavior: concise mode confirmation.
- Failure state: low battery may prefer quiet or offline mode.

## Offline Mode

- Starting screen: any.
- User action: start offline mode.
- Daemon request: `set_mode`.
- Expected daemon response: ok.
- UI state transition: offline banner visible.
- Spoken response behavior: optional confirmation.
- Failure state: none expected.

## Online Mode

- Starting screen: home or settings.
- User action: start online mode.
- Daemon request: `set_mode`.
- Expected daemon response: ok only if online state exists.
- UI state transition: online indicator appears.
- Spoken response behavior: announce online enhancement availability.
- Failure state: online unavailable or privacy mode blocks online.

## Dock Mode

- Starting screen: dock screen.
- User action: start dock mode or sync logs.
- Daemon request: `set_mode` or dock command.
- Expected daemon response: ok only if dock is available.
- UI state transition: dock status view shows target and sync result.
- Spoken response behavior: short sync status.
- Failure state: no dock refusal.

## Privacy Mode

- Starting screen: settings or home.
- User action: start privacy mode.
- Daemon request: `execute_command` or `set_mode`.
- Expected daemon response: private mode enabled.
- UI state transition: private state visible, online enhancements blocked.
- Spoken response behavior: confirm privacy mode.
- Failure state: none expected.

## Diagnostics Mode

- Starting screen: settings or home.
- User action: diagnostics mode.
- Daemon request: `set_mode`, then diagnostics command.
- Expected daemon response: adapter diagnostics.
- UI state transition: diagnostics tiles update.
- Spoken response behavior: speak critical warnings only.
- Failure state: adapter unavailable state shown per tile.

## Recovery Mode

- Starting screen: settings or failure screen.
- User action: recovery mode.
- Daemon request: `set_mode`.
- Expected daemon response: ok.
- UI state transition: recovery options and logs visible.
- Spoken response behavior: minimal.
- Failure state: daemon unavailable, show local recovery notes.
