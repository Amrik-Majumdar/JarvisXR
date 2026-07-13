# JARVIS Core ML Model Supply Chain

The object detector is an externally fetched, checksum-pinned build input. The
8.9 MB binary is deliberately not stored in Git.

From the repository root, fetch and verify it with:

```bash
python tools/fetch_vision_model.py
```

The command downloads Apple's `YOLOv3TinyInt8LUT.mlmodel`, verifies its exact
byte count and SHA-256 from `JarvisObjectDetector.manifest.json`, and only then
atomically installs it here as `JarvisObjectDetector.mlmodel`. Xcode compiles
that source artifact into `JarvisObjectDetector.mlmodelc` for the application
bundle.

Files committed in this directory:

- `JarvisObjectDetector.manifest.json`: machine-readable provenance, model
  interface, supported classes, checksum, and license metadata.
- `JarvisObjectDetector.NOTICE.txt`: redistributable notice copied into the app.
- `MODEL_LICENSE.md`: human-readable provenance and licensing notes.

The fetcher fails closed on a download, size, or digest mismatch. Do not replace
the model without updating the manifest, legal documentation, fixtures, and
device evaluation together.
