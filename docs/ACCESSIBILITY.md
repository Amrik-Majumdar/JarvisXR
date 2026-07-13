# Accessibility

Jarvis is voice-first, with a visual and touch fallback that remains useful for low-vision users, assistants, and demonstrations.

## Primary interaction

- The root experience becomes ready to listen after launch when permissions and onboarding allow it.
- Natural language selects Describe, Live Guide, Find, Read Text, Scan Barcode, flashlight, messaging, and speech actions.
- The Vision screen keeps an accessible Voice control and an emergency Stop control visible at the bottom. Stop cancels camera analysis, speech, haptics, and voice input immediately.
- The visual task picker is a single accessible menu rather than a row of competing mode cards.
- Device Acceptance Mode is voice-led, always exposes Skip and Stop touch fallbacks, repeats its current question on request, and keeps a visible status for every automatic and physical check.

## Structural support

- Important state is exposed through speech, VoiceOver labels, visible text, and optional haptics; color or animation is never the only status signal.
- UIKit labels and controls use Dynamic Type and explicit accessibility labels, values, hints, identifiers, and touch targets.
- The central orb has a text-equivalent accessibility label. Decorative state imagery is hidden from VoiceOver when the adjacent state text already provides the same information.
- Reduce Motion suppresses navigation animation where implemented. Haptic unavailability has a speech fallback. Voice output adopts assistive-technology settings when VoiceOver is active.

## What still needs an iPhone

Automated UI tests cover accessibility metadata, target sizes, large Dynamic Type, persistent Stop visibility, and fixture states. A person must still validate VoiceOver focus order, rotor behavior, Bluetooth routing, haptic feel, Switch Control, and real camera guidance on each representative physical iPhone configuration.

Use [Device Acceptance Mode](DEVICE_ACCEPTANCE.md) after installing a build to record those physical checks without treating simulator or static evidence as device confirmation.
