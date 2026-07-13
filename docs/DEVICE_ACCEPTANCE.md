# Device Acceptance Mode

Device Acceptance Mode documents what the installed build can demonstrate on a real iPhone without overstating simulator or static evidence.

## Start and operate

Start it by saying “run the complete device test,” using the matching App Shortcut, or selecting **Complete Device Test** in Diagnostics. Jarvis speaks each step and accepts **Yes**, **No**, **Different**, **Repeat**, **Continue**, **Skip**, and **Stop**. The visible Skip and Stop controls remain available throughout.

The automatic portion records app and iOS version, the preserved iOS 18 deployment baseline, privacy-description presence, speech and microphone authorization/configuration, accessibility settings, haptic backend availability, local model checksum/load/inference, OCR, barcode support, and live rear-camera/vision-pipeline evidence when the phone permits them. It then asks the user to confirm flashlight on and off, haptics, two distinct speech profiles, rear-camera cover/recovery, and the observed live result.

## Evidence and limits

Each check remains explicitly marked as automated, user-confirmed, unavailable, skipped, or attention required. A physical check cannot pass unless the user confirms it, and unavailable hardware or permissions are recorded rather than hidden. The flow does not prove real-world vision accuracy, safe navigation, battery life, thermal behavior, audio routing, signing, or App Store readiness.

## Local export

Finishing or stopping writes a versioned JSON report to the app's Application Support container under `JarvisXR/DeviceAcceptanceReports`. Nothing is uploaded. The report contains check names, statuses, methods, notes, build and capability metadata, and stated limitations; it does not contain camera images or frames, OCR text, barcode values, audio, telemetry, or network data.

Use the enabled **Share Report** button to choose a destination through the system share sheet. The user controls whether and where the report leaves the device.
