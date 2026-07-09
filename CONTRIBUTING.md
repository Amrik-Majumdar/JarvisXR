# Contributing

Contributions that improve reliability, accessibility, privacy, documentation, tests, and public-API iOS behavior are welcome.

## Development Rules

- Keep the shipping app native Swift and UIKit.
- Use public Apple APIs only.
- Do not add paid APIs, required cloud services, private frameworks, jailbreak claims, or hidden automation.
- Do not commit IPA files, signing material, build output, logs, personal data, or secrets.
- Keep permissions aligned with features that are actually implemented.
- Describe device-only behavior as unverified until it has been tested on hardware.

## Workflow

1. Fork the repository and create a focused branch.
2. Make the smallest coherent change.
3. Run the Python validation suite.
4. Generate the Xcode project and run Swift tests on macOS when applicable.
5. Update tests and public documentation.
6. Open a pull request using the provided template.

See [Building](docs/BUILDING.md) and [Testing](docs/TESTING.md).
