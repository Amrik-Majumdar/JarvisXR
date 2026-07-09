# Security Policy

## Supported Version

Security fixes are applied to the latest commit on `main` and, when practical, the newest prerelease.

| Version | Supported |
|---|---|
| Latest `main` | Yes |
| Latest prerelease | Best effort |
| Older commits or artifacts | No |

## Report a Vulnerability

Use GitHub private vulnerability reporting for this repository when available. Do not place exploit details, credentials, signing files, private device data, or personal information in a public issue.

Include:

- affected commit or release
- affected iOS and device version
- clear reproduction steps
- expected and observed behavior
- impact assessment
- minimal logs with personal data removed

Allow reasonable time for triage before public disclosure.

## Security Boundaries

JARVIS XR:

- uses public iOS APIs
- runs inside the normal iOS application sandbox
- does not require root access or a jailbreak
- does not include a developer-operated cloud backend
- does not need API keys or signing secrets in the repository

Users remain responsible for Apple ID security, local signing credentials, device passcodes, backups, and third-party sideloading tools.

## Out of Scope

- vulnerabilities in unmodified Apple, GitHub, AltServer, Sideloadly, Spotify, or YouTube products
- social engineering without a software flaw
- reports based only on unsupported jailbreak modifications
- availability issues caused solely by expired sideload signatures
