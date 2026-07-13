# Compatible iPhone Setup Checklist (XR Capability Baseline)

Use this only on a device you own or are authorized to configure.

## Before Installation

- [ ] Back up important data
- [ ] Confirm the device and iOS version
- [ ] Confirm the Apple ID and sideloading method
- [ ] Keep signing credentials private
- [ ] Download the IPA from the official repository release

## After Installation

- [ ] Record that this is a physical-device check, including commit, iOS version, and device model
- [ ] Confirm the app icon and launch screen
- [ ] Test typed commands
- [ ] Test microphone and Speech permissions
- [ ] Test camera permission and all six Jarvis Vision modes
- [ ] Test speech output and voice profiles
- [ ] Test VoiceOver, Dynamic Type, audio routes, haptics, and thermal degradation
- [ ] Test Settings persistence
- [ ] Confirm the app can be removed or refreshed

Use the complete [First-Run and Physical-Device Checklist](FIRST_RUN_CHECKLIST.md). Simulator and CI evidence is not physical-device evidence.

## Dedicated Device Setup

- [ ] Disable unnecessary notifications
- [ ] Configure Focus and Screen Time as desired
- [ ] Enable Guided Access
- [ ] Set a Guided Access passcode or Face ID exit
- [ ] Test entry and exit before relying on lockdown

Guided Access restricts app switching. It does not grant JARVIS root access or control of iOS.
