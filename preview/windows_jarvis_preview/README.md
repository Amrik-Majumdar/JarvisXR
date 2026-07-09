# JARVIS Windows Preview

This is a Windows-runnable preview of the JARVIS appliance shell. It is not the iPhone app and it is not a website.

Run:

```powershell
python preview/windows_jarvis_preview/jarvis_preview.py
```

Self-test:

```powershell
python preview/windows_jarvis_preview/jarvis_preview.py --self-test
```

The preview uses Python standard library tkinter for the UI. If `pyttsx3` happens to be installed, it can speak responses locally. If it is not installed, the preview still works without speech.

It proves:

- The visual direction is Jarvis-first, dark, restrained, and command-focused.
- The offline command behavior feels coherent before sideloading.
- Notes, history, confirmation, and utility commands work in the preview harness.

It does not prove:

- The Swift/UIKit app compiles.
- The iPhone camera permission flow works.
- AVSpeechSynthesizer voice availability.
- Sideloadly installation.
- Guided Access behavior.
- Any jailbreak or OS-level control.
