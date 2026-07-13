# Jarvis Vision Completion Ledger

This ledger separates implemented scope from release-run evidence and physical-device evidence. It must not be read as a claim that the current commit has passed CI or has been tested on an iPhone XR.

## Status Summary

| Evidence class | Status | Meaning |
|---|---|---|
| Implementation | Complete in source | The product, tests, tools, workflow, and documentation contain the listed Jarvis Vision behavior |
| Simulator and CI | Run-specific evidence pending | The workflow gates are implemented, but the final run URL, commit, outcomes, counts, and artifacts must be inserted below after the run completes |
| Physical iPhone XR | Pending | No physical-device success is claimed; complete and record every applicable item in the first-run checklist |

## Scope Map

| Area | Completed implementation | Simulator or CI gate | Physical-device work still required |
|---|---|---|---|
| Modes and camera | Describe, Live Guide, Find, Read Text, Barcode, Color, camera lifecycle, stop, pause, flashlight, and front or rear selection | Swift behavior tests, UI tests, deterministic state capture | Live camera permissions, focus, exposure, rotation, torch, interruptions, and foreground transitions |
| Messages | System contact picker, in-memory recipient and body draft, readback, explicit composer confirmation, standard MessageUI send or cancel result, and no message history | Command parser and draft-state tests plus iOS compilation | Real contact selection, dictation, VoiceOver flow, carrier behavior, and composer send or cancel on a physical phone |
| Detector | Model-agnostic interface plus checksum-pinned Apple `YOLOv3TinyInt8LUT`, 80-class catalog, schema validation, manifest, and notice | Model fetch and audit, compiled bundle check, real `Desk_chair.jpg` simulator execution, independent output-contract evaluation, and deterministic decoder semantics | Accuracy at practical distances and lighting, latency, memory pressure, and supported-target behavior; the first authoritative fixture run returned no detections |
| Understanding | OCR order, barcode deduplication, face and person counts, color naming, camera quality, tracking, and scene fusion | Analyzer, decoder, tracker, fusion, and fixture tests | Printed material, reflective barcodes, diverse lighting, motion, occlusion, and real-world false positives |
| Safety | Confidence and freshness policy, unsupported-target responses, qualified absence, no path-clear claims, and stale-result cancellation | Safety audit and narration-policy unit tests | Human review with realistic scenes while preserving normal mobility practices |
| Accessible output | Priority speech, session cancellation, reading controls, directional and status haptics, visible text, VoiceOver labels, Dynamic Type, contrast, and reduced motion | Speech and haptic policy tests, UI tests, and 28 screenshot proof states | VoiceOver focus and rotor, maximum text sizes, actual sound routes, interruption recovery, and haptic feel |
| Privacy | On-device vision, no normal frame or video storage, no OCR or barcode history, bounded session memory, and no vision network path | Privacy audit, preferences tests, IPA scan, and fixture provenance checks | Offline operation and post-session storage inspection on the installed app |
| Power and diagnostics | Dropped-frame and latency metrics, analyzer and model state, low-power profile, and thermal degradation | Coordinator and diagnostics tests plus report artifacts | Sustained Live Guide heat, battery use, responsiveness, and serious or critical thermal recovery |
| Packaging | XcodeGen project, unsigned arm64 build, compiled model resources, IPA audit, logs, reports, XCTest results, and proof artifacts | macOS workflow build, tests, audits, package inspection, and artifact uploads | Sign, sideload, launch, relaunch, and Guided Access exit on the target phone |

## Release-Run Evidence to Fill

- Commit: pending
- Workflow run URL: pending
- Workflow conclusion and completed jobs: pending
- Python test count: pending
- Swift unit test count: pending
- UI test count: pending
- Native `Desk_chair.jpg` inference result: pending
- Vision model, fixture, safety, and privacy audit results: pending
- Visual proof count: expected 28, run result pending
- Unsigned IPA size and SHA-256: pending
- IPA audit result: pending
- Artifact names and retention links: pending

## Physical-Device Handoff

The release remains physically unverified until a human completes [First-Run and Physical-Device Checklist](FIRST_RUN_CHECKLIST.md) on the target phone. Record device model, iOS version, signing path, app commit, accessibility settings, audio route, lighting, thermal conditions, and failures. Simulator evidence must remain labeled as simulator evidence.
