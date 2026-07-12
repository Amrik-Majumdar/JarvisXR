# First-Run and Physical-Device Checklist

Complete this on the actual target phone before enabling Guided Access or relying on Jarvis Vision. Simulator and CI results do not count as physical iPhone XR testing. Until a person completes and records this checklist on the device, every item in this document is pending.

## Installation and Recovery

- [ ] Record the app commit or version, iOS version, device model, signing method, and installation date
- [ ] App icon, launch screen, wordmark, orb, and safe-area layout appear correctly
- [ ] The unsigned build can be signed, installed, launched, terminated, and relaunched
- [ ] Guided Access can be entered and exited with the configured passcode or Face ID
- [ ] Camera, Microphone, and Speech denials each show a usable recovery path to Settings
- [ ] Backgrounding Vision stops camera analysis, speech, voice input, flashlight, and haptics

## Main Assistant

- [ ] Standby changes to Ready when the orb is tapped
- [ ] Ready changes to Listening when voice input starts
- [ ] Microphone and Speech permission prompts explain their use
- [ ] Spoken input reaches Processing and returns a response
- [ ] Long press returns the interface to Standby
- [ ] Typed commands submit with Send and the keyboard dismisses correctly
- [ ] `help`, `status`, `voice test`, and `about Jarvis` respond
- [ ] Clear Notes and Clear History require intentional confirmation
- [ ] Control Mesh presents a specific public-API route for system-level requests

## Six Vision Modes

- [ ] Describe identifies supported nearby objects and uses qualified, non-navigational language
- [ ] Live Guide announces stable meaningful changes, can pause and resume, and stops in the background
- [ ] Find provides distinct left, center, and right guidance for a supported class such as chair
- [ ] Find reports door, stairs, curb, step, and exit sign as unsupported instead of guessing
- [ ] Read Text reads a printed page in a useful order and supports pause, previous line, and next line
- [ ] Barcode reports a value once, deduplicates repeats, and does not open a detected link automatically
- [ ] Color reports an approximate common name and communicates uncertainty under poor lighting
- [ ] Camera-quality guidance distinguishes dark, blurry, moving, overexposed, and covered-camera conditions
- [ ] The red Stop control ends analysis, queued speech, voice input, and haptics immediately
- [ ] Repeat, More Detail, Less Detail, flashlight, and camera-switch controls behave as labeled

## Accessibility and Audio

- [ ] VoiceOver reaches every mode, result, control, recovery action, and adjustable setting in a logical order
- [ ] VoiceOver labels expose control purpose and current state without depending on color alone
- [ ] Extra Extra Large and accessibility Dynamic Type sizes remain usable without clipped primary controls
- [ ] Increase Contrast preserves readable boundaries and text
- [ ] Reduce Motion removes nonessential motion without hiding state changes
- [ ] Spoken warnings and target announcements preempt lower-priority scene chatter
- [ ] Pausing, stopping, or starting a new Vision session prevents stale narration from speaking later
- [ ] Direction, target-found, target-lost, warning, and completion haptic patterns feel distinguishable
- [ ] Disabling haptics preserves spoken direction guidance
- [ ] Speech remains intelligible through speaker, receiver behavior, wired audio if available, and the intended Bluetooth route
- [ ] Silent mode, volume changes, interruptions, and another app taking audio focus recover predictably

## Privacy, Diagnostics, and Performance

- [ ] Diagnostics shows detector identity and validation, camera state, analyzer availability, haptics backend, dropped frames, latency, thermal state, and current degradation profile
- [ ] Vision Settings persist only the documented preferences
- [ ] Stopping a session clears temporary scene memory
- [ ] Captured photos, video, recognized text, and barcode values do not appear in Photos, Files, notes, or command history unless a separate explicit action saves information
- [ ] Vision remains functional with Wi-Fi and cellular data disabled after installation
- [ ] Low Power Mode selects a reduced processing profile without presenting stale results
- [ ] Extended Live Guide use is observed for latency, frame drops, battery drain, temperature, and safe automatic thermal degradation
- [ ] Serious or critical thermal conditions reduce continuous processing and explain the change
- [ ] Front and rear camera choice, rotation, portrait framing, autofocus, exposure, and torch are checked on the target phone

## Reporting

Record the exact mode, target, lighting, distance, audio route, accessibility settings, thermal state, app version, iOS version, and device model for every failure. Include a privacy-safe screenshot or short description only when it does not expose recognized text, barcodes, faces, or private surroundings.

Passing this checklist still does not make Jarvis Vision a mobility aid or safety-certified navigation system. It can miss, misidentify, or mislocate objects. Never use a camera result as permission to cross, proceed, or ignore a cane, guide dog, human assistance, or established safe mobility practice.
