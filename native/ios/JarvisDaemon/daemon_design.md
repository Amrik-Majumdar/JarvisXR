# Daemon Design

## Responsibilities

- Load and validate capability registry.
- Expose local command routing service to shell.
- Keep local memory and command logs.
- Track sensor and hardware availability.
- Gate online and dock functions.
- Write diagnostic logs for recovery.

## Boundaries

The daemon must not assume SpringBoard hook success. It should be useful to the shell even if the tweak is disabled.

## Device Test Requirements

- launchd loads the service.
- service logs startup.
- service restarts cleanly.
- shell can query daemon status.
- uninstall path works.
