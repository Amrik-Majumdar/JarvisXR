# Voice Commands

Jarvis is designed to accept the intent of a request instead of requiring a manually selected Vision mode. Commands are processed while the app is active; App Intents can open supported tasks, but availability through Siri and Shortcuts depends on iOS configuration.

## Scene and Live Guide

- “What is in front of me?” / “Describe this room” / “What is on my left?”
- “Tell me more” / “Be more concise” / “What changed?” / “Repeat that”
- “Start Live Guide” / “Start guiding me” / “Only tell me important changes”
- “Pause” / “Continue” / “Stop”

Live Guide is informational only. It can describe confirmed changes and possible obstructions, but it never verifies a clear path or permission to proceed.

## Find, Read, and Scan

- “Find a chair” / “Where is the chair?” / “Help me locate a table”
- “Is it on my left?” / “Center the object” / “Where did it go?”
- “Read this” / “Read the sign in front of me” / “Read the largest text”
- “Start from the top” / “Next line” / “Previous line” / “Spell that” / “Stop reading”
- “Scan this barcode” / “What is this code?” / “Read the numbers one at a time”

Find only reports the installed detector's supported classes. Read and Scan work from continuous camera frames while the task is active; the user does not need to take a photo manually.

## Speech, Flashlight, and Messages

- “Speak faster” / “Speak slower” / “Use another voice” / “Stop speaking”
- “Turn on the flashlight” / “Turn off the flashlight” / “Is the flashlight on?”
- “Text Mom that I will be home soon” / “Message Alex”
- “Read it back” / “Change it to I am waiting outside” / “Change the recipient” / “Cancel the message” / “Open Messages”

Messages stay in an in-memory draft until the user explicitly asks to open Apple's composer. Jarvis does not send a message silently.

## Context and Recovery

Follow-ups are temporary and task-scoped. Saying Stop clears active Vision work, Vision speech, haptics, camera analysis, and task context. If a camera frame is dark, invalid, or unavailable, Jarvis reports the condition distinctly and keeps trying when recovery is possible.

## Device Acceptance

- “Run the complete device test” / “Run device test”
- “Continue”, “Repeat”, “Skip”, “Stop”, “Yes”, “No”, or “Different” while the test asks a physical confirmation question

This mode is a local, voice-driven acceptance check for the installed build. It keeps automatic results separate from user-confirmed checks and offers an explicit local-only report export. See [Device Acceptance Mode](DEVICE_ACCEPTANCE.md).
