# Testing

## Python Validation

Install Python 3.11 or newer and pytest:

```bash
python -m pip install pytest
python tests/run_all_tests.py
```

The runner validates:

- capability registry and XR matrix
- generated native contracts
- device profiles and ownership rules
- adapter result contracts
- router and daemon behavior
- confirmation and mode transitions

## Windows Preview

```powershell
python preview/windows_jarvis_preview/jarvis_preview.py --self-test
python preview/windows_jarvis_preview/jarvis_preview.py
```

The preview is an interaction check, not proof of UIKit behavior.

## Swift Tests

Generate the Xcode project, then run the `JarvisXR` scheme tests on an available iPhone simulator. CI performs Swift unit tests and automated visual-state capture.

## IPA Audit

```bash
python tools/audit_ipa.py path/to/JarvisXR-unsigned.ipa
```

The audit checks the package structure, executable, property list, compiled assets, launch storyboard, app icon evidence, and App Intents metadata.

## Real-Device Testing

Simulator success does not prove microphone, camera, speech, permissions, audio routing, signing, Guided Access, or performance on a physical phone. Use [First Run Checklist](FIRST_RUN_CHECKLIST.md) after every reinstall.
