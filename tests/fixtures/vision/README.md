# JARVIS Vision Fixtures

This directory is a legal, checksum-pinned test resource pack. Every binary
must have source, license, byte length, digest, and expected observations in
`fixtures.manifest.json`.

Validate the pack without claiming inference:

```bash
python tools/evaluate_vision_fixtures.py --metadata-only
```

Evaluate native observations produced by a Core ML test harness:

```bash
python tools/evaluate_vision_fixtures.py \
  --observations path/to/native-observations.json \
  --output path/to/vision-evaluation.json
```

Metadata-only validation proves fixture integrity and annotation consistency.
It does not prove that Core ML inference ran. The evaluator refuses to report
inference success unless an observations file is explicitly supplied.
