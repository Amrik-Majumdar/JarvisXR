from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from .vision_model_contract import DEFAULT_MANIFEST, ROOT, load_json, write_json
except ImportError:  # Direct execution: python tools/audit_vision_privacy.py
    from vision_model_contract import DEFAULT_MANIFEST, ROOT, load_json, write_json


DEFAULT_SOURCE_ROOT = ROOT / "ios" / "JarvisXR" / "JarvisXR"
NETWORK_TOKENS = (
    "URLSession",
    "URLRequest",
    "NWConnection",
    "Alamofire",
    ".dataTask(",
    ".uploadTask(",
    "WebSocketTask",
)
TELEMETRY_TOKENS = (
    "FirebaseAnalytics",
    "import Sentry",
    "import Amplitude",
    "Mixpanel",
)
IMAGE_PERSISTENCE_TOKENS = (
    "UIImageWriteToSavedPhotosAlbum",
    "PHPhotoLibrary",
    "creationRequestForAsset",
    "CGImageDestinationFinalize",
)
VISION_LOGGING_TOKENS = (
    "print(",
    "NSLog(",
    "os_log(",
    "Logger(",
)


def scan_privacy(source_root: Path, model_manifest_path: Path = DEFAULT_MANIFEST) -> dict:
    failures: list[str] = []
    passed: list[str] = []
    files = sorted(source_root.rglob("*.swift"))
    if not files:
        failures.append(f"no Swift production sources found under {source_root}")
    for path in files:
        text = path.read_text(encoding="utf-8")
        relative = path.relative_to(source_root)
        for token in NETWORK_TOKENS:
            if token in text:
                failures.append(f"{relative} contains production network API token: {token}")
        for token in TELEMETRY_TOKENS:
            if token in text:
                failures.append(f"{relative} contains telemetry SDK token: {token}")
        is_vision_source = "vision" in path.name.lower() or "camera" in path.name.lower() or "import Vision" in text
        if is_vision_source:
            for token in IMAGE_PERSISTENCE_TOKENS:
                if token in text:
                    failures.append(f"{relative} contains automatic image-persistence API: {token}")
            if "payloadStringValue" in text and "UIApplication.shared.open" in text:
                failures.append(f"{relative} may automatically open a recognized barcode URL")
            if any(token in text for token in VISION_LOGGING_TOKENS) and any(token in text for token in ("recognizedText", "payloadStringValue", "VNRecognizeTextRequest")):
                failures.append(f"{relative} may log recognized private text or barcode content")

    try:
        manifest = load_json(model_manifest_path)
        if manifest.get("compatibility", {}).get("network_required_at_runtime") is False:
            passed.append("model manifest declares no runtime network requirement")
        else:
            failures.append("model manifest must declare runtime network requirement false")
    except Exception as exc:
        failures.append(f"could not inspect model privacy metadata: {exc}")

    if not failures:
        passed.append(f"{len(files)} production Swift files contain no network, telemetry, automatic image-save, barcode-open, or private Vision logging paths")
    return {
        "schema_version": 1,
        "status": "passed" if not failures else "failed",
        "source_root": str(source_root.resolve()),
        "files_scanned": len(files),
        "passed": passed,
        "failures": failures,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit production JARVIS Vision sources for offline privacy invariants.")
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--model-manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = scan_privacy(args.source_root, args.model_manifest)
    if args.output:
        write_json(args.output, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
