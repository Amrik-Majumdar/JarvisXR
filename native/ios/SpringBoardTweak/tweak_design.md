# Tweak Design

## Goal

Make Jarvis feel like the phone itself by reducing normal SpringBoard exposure and returning the user to Jarvis wherever technically safe.

## Planned Behaviors

- Auto-launch Jarvis after unlock or respring.
- Redirect home behavior to Jarvis shell when possible.
- Provide gesture or button activation if available.
- Hide clutter only where reversible and stable.
- Fail safely into normal SpringBoard or safe mode.

## Safety

Every hook must have a rollback path and must be tested independently.
