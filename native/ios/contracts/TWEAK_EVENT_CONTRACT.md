# SpringBoard Tweak Event Contract

The tweak should emit events to `jarvisd` or the shell. It must not perform complex command execution itself.

## Event Types

- `springboard_started`
- `device_unlocked`
- `home_requested`
- `jarvis_activation_requested`
- `safe_mode_detected`
- `tweak_disabled`

## Event Shape

```json
{
  "type": "jarvis_activation_requested",
  "event_id": "uuid",
  "timestamp": "iso8601",
  "source": "springboard_tweak",
  "payload": {
    "trigger": "tested_button_or_gesture"
  }
}
```

## Required Logs

- event id
- timestamp
- source
- hook name
- device state if available
- action requested
- action accepted or refused
- safe mode and rollback status

## Safety Rule

Every hook must have a disable path. The tweak must fail safely back to normal SpringBoard or safe mode.

## v0.4 Boundary

SpringBoard tweak events may request activation or mode changes later. They must not bypass the daemon confirmation flow, adapter availability checks, or local safety logs.

## v0.5 XR Boundary

On iPhone XR iOS 18.7.9 this contract is a waiting-lane document. No SpringBoard event behavior is claimed until a verified jailbreak path exists and the hooks are tested on the device.
