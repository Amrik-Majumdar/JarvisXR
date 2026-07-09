# Control Mesh

Control Mesh is the app's public-API coordination layer for actions outside the JARVIS process.

## Routes

| Request | Route |
|---|---|
| Open a supported app or URL | Public URL scheme or universal link |
| Run a JARVIS command from iOS | App Intent, Shortcut, or `jarvis://` deep link |
| Return to JARVIS | `jarvis://standby` or a user-created Shortcut |
| Tap visible system UI | Voice Control phrase such as `Show Grid`, then the target number |
| Scroll visible system UI | Voice Control phrase such as `Scroll Down` |
| Change brightness, appearance, or volume | User-created Shortcut or supported iOS control |
| Keep JARVIS foreground | Guided Access configured by the device owner |

## Boundary

Control Mesh does not inject events, read hidden content, bypass app sandboxes, or gain private system privileges. It coordinates mechanisms the user explicitly enables in iOS.

Availability depends on iOS version, language, installed apps, accessibility settings, and user-created Shortcuts.
