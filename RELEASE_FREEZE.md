# Release Candidate Freeze

`v0.1.0-rc1` identifies the first publicly packaged JARVIS XR release candidate.

The tag remains fixed to the audited application build. Documentation, repository presentation, contribution guidance, and CI validation may continue on `main` without changing that release artifact.

A new app release must use a new version and tag after:

- Swift unit tests pass
- Python validation passes
- visual proof passes
- IPA audit passes
- real-device regression testing is completed

Do not move or overwrite the existing release tag.
