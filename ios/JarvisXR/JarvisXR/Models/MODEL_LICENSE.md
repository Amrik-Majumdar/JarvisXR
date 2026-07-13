# Object Detector Provenance and License

JARVIS XR fetches the `YOLOv3TinyInt8LUT.mlmodel` artifact published in
Apple's Core ML model gallery and renames the verified source artifact to
`JarvisObjectDetector.mlmodel` for compilation by Xcode.

- Catalog: <https://developer.apple.com/machine-learning/models/>
- Artifact: <https://ml-assets.apple.com/coreml/models/Image/ObjectDetection/YOLOv3Tiny/YOLOv3TinyInt8LUT.mlmodel>
- Upstream source: <https://github.com/pjreddie/darknet>
- Upstream license: <https://github.com/pjreddie/darknet/blob/master/LICENSE>
- Recorded authors: Joseph Redmon and Ali Farhadi
- Pinned size: 8,913,366 bytes
- Pinned SHA-256: `cde8af2528d6eca1d1580fdd0f0147cb6613d40ba962656b5f683c65f571870e`

The downloaded model's embedded metadata identifies the license as the “YOLO
License” and links to the Darknet license above. That license states that
Darknet is public domain and permits use for any purpose. The build retains a
human-readable notice in `JarvisObjectDetector.NOTICE.txt` and a complete
machine-readable record in `JarvisObjectDetector.manifest.json`.

The model recognizes the 80 classes listed in the manifest. It does not include
doors, stairs, curbs, steps, or exit signs. Those targets must be reported as
unsupported unless a separate verified analyzer supplies evidence.

This third-party notice does not change JARVIS XR's GPL-3.0-or-later software
license or the CC BY-NC-SA 4.0 terms covering the project's original visual
identity assets.
