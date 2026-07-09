# UI Spec Implementation Notes

## Native Route

Use UIKit view controllers or Swift equivalents. Keep the first implementation simple: tab or rail navigation, fixed portrait orientation, native camera view, and table views for capabilities and logs.

## iPhone 6 Constraints

- 375 by 667 point target.
- Avoid heavy blur.
- Avoid continuous expensive animations.
- Cache registry summaries.
- Keep camera and model work interruptible.

## State Contracts

The shell should read capability metadata from a bundled registry copy. Later it can query the daemon for live registry and hardware availability.

## Unimplemented Until Device Phase

- Launch as dominant shell.
- Home gesture interception.
- Button activation.
- Background daemon connection.
- Any SpringBoard behavior.
