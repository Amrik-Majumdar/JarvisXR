# Vision Pipeline

## Current Pipeline

The inspection screen uses:

- AVFoundation rear-camera preview
- photo capture
- torch control when available
- continuous autofocus and auto exposure when supported
- Vision text recognition
- Vision QR and barcode detection
- Vision image classification
- capture dimensions and byte-count metadata

Analysis starts after capture. Results are displayed and can be spoken when speech output is enabled.

## Object Detection

The app checks for a compatible compiled Core ML model in the app bundle. Expected model names include:

- `JarvisObjectDetector.mlmodelc`
- `YOLO.mlmodelc`
- `YOLOv8n.mlmodelc`
- `ObjectDetector.mlmodelc`

No external object-detection model is bundled in the public release candidate. Apple Vision image classification remains available as the built-in fallback.

To add a model:

1. Confirm the model license permits redistribution.
2. Add the model source or compiled artifact under `ios/JarvisXR/JarvisXR/Models`.
3. Include it in the XcodeGen target.
4. Rebuild and audit the IPA.
5. Test model loading, latency, memory, thermal behavior, and output on a physical device.

Do not describe object detection as active until the bundled model is loaded and tested.
