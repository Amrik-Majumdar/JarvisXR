# Permissions and Confirmations

## Confirmation Required

- Any high-risk capability.
- Destructive memory actions.
- Package install or restore.
- Online send or cloud sync.
- Jailbreak control actions.

## Permission State

The shell and daemon should expose camera, microphone, location, storage, dock, online, private mode, and jailbreak state.

## Refusal Format

```json
{
  "status": "unavailable",
  "unavailable_reason": "camera is unavailable in the current device state",
  "capability_id": "camera_inspection_001"
}
```

## Safety Logging

Every refusal and every confirmed action must be logged locally. Dock export may copy logs later, but local logging is the source of truth.

## v0.4 Confirmation Flow

The shell receives `confirmation_required` plus a token, shows `JVSConfirmationView`, then sends `confirm_and_execute` with that token. Missing, expired, or unknown tokens must render as refused.

Hardware unavailable reporting should preserve the daemon `unavailable_reason` and any adapter error data.

## v0.5 Ownership Permission Boundary

Supervised Single App Mode and Guided Access are setup states, not jailbreak proof. The shell must show when external app handoff, Spotify open, browser open, background listening, or system button control is blocked by the current ownership mode.
