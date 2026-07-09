# Public Release Handoff

## Current Product

The shipping source is the Swift and UIKit app under `ios/JarvisXR`. GitHub Actions generates the Xcode project, validates the repository, builds the app, runs simulator tests, captures visual proof, audits the package, and uploads an unsigned IPA.

## Installation Path

1. Download the prerelease IPA or build from source.
2. Sign and sideload it with an authorized Apple ID.
3. Complete the first-run checklist.
4. Enable Guided Access only after testing the exit path.

## Preserved Boundaries

The app uses public APIs and does not provide jailbreak hooks, root access, hidden screen reading, injected taps, a lock-screen replacement, or unrestricted system control.

## Source of Truth

- Product source: `ios/JarvisXR`
- Project configuration: `ios/JarvisXR/project.yml`
- CI: `.github/workflows/ios-build.yml`
- Public docs: `docs/README.md`
- Release artifact: GitHub Releases
