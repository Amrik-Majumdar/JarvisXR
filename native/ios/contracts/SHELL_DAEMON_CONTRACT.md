# Shell to Daemon Contract

## Transport

Preferred transport is a local Unix domain socket or loopback HTTP service exposed only on device. The exact transport must be chosen after jailbreak tooling and sandbox behavior are known.

For v0.5 XR Device Mode, stock iOS should treat this as a service contract shape rather than a claim that `jarvisd` can run as a launchd daemon. A native app may use in-process service logic or a permitted local bridge until a jailbreak lane exists.

## Request: Route Command

```json
{
  "type": "route_command",
  "request_id": "uuid",
  "transcript": "scan this",
  "confirmed": false,
  "shell_state": {
    "screen": "home",
    "mode": "offline"
  }
}
```

## Response: Route Result

```json
{
  "type": "route_result",
  "request_id": "uuid",
  "status": "ok",
  "capability_id": "camera_inspection_001",
  "confidence": 0.94,
  "requires_confirmation": false,
  "unavailable_reason": null,
  "spoken_response": "Inspection frame ready.",
  "display_response": "Mock camera inspection prepared.",
  "data": {}
}
```

## Required Logs

- request id
- timestamp
- transcript
- selected capability id
- confidence
- mode
- risk
- confirmation state
- unavailable reason
- execution status

## Safety Rule

The shell must never silently execute high-risk commands. It must show confirmation before sending a confirmed request.

## v0.4 Adapter Data

Command responses may include adapter result dictionaries inside `data.handler_data`. The native shell should treat these as diagnostics and display inputs, not as proof that iPhone hardware is controlled.

## v0.5 Device And Ownership Requests

The shell should understand:

- `get_device_profile`
- `get_device_mode_strategy`
- `get_ownership_modes`
- `set_ownership_mode`
- `get_current_ownership_mode`
- `list_blocked_ownership_features`
- `get_spotify_strategy`
- `list_media_capabilities`

These return the normal Jarvis response envelope with spoken response, display response, data, unavailable reason, candidate capabilities, and logs.
