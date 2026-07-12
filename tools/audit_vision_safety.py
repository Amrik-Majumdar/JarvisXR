from __future__ import annotations

import argparse
import json
import re
from pathlib import Path

try:
    from .vision_model_contract import ROOT, write_json
except ImportError:  # Direct execution: python tools/audit_vision_safety.py
    from vision_model_contract import ROOT, write_json


DEFAULT_SOURCE_ROOT = ROOT / "ios" / "JarvisXR" / "JarvisXR"
PROHIBITED_CERTAINTY = (
    "the path is safe",
    "path is safe",
    "it is safe to cross",
    "safe to cross",
    "the road is clear",
    "road is clear",
    "the path is clear",
    "path is clear",
    "there are definitely no obstacles",
    "no obstacles are present",
    "you can proceed",
    "nothing is in front of you",
    "nothing is there",
)
PRECISE_DISTANCE_PATTERN = re.compile(
    r"\b(?:about\s+|approximately\s+|exactly\s+)?\d+(?:\.\d+)?\s*(?:feet|foot|ft|meters|metres|m|inches|inch)\b",
    re.IGNORECASE,
)


def normalized_text(text: str) -> str:
    return " ".join(text.lower().split())


def scan_safety(source_root: Path) -> dict:
    failures: list[str] = []
    passed: list[str] = []
    files = sorted(source_root.rglob("*.swift"))
    if not files:
        failures.append(f"no Swift production sources found under {source_root}")
    for path in files:
        text = path.read_text(encoding="utf-8")
        normalized = normalized_text(text)
        for phrase in PROHIBITED_CERTAINTY:
            if phrase in normalized:
                failures.append(f"{path.relative_to(source_root)} contains prohibited certainty: {phrase}")
        is_vision_source = "vision" in path.name.lower() or "camera" in path.name.lower() or "import Vision" in text
        if is_vision_source:
            for match in PRECISE_DISTANCE_PATTERN.finditer(text):
                failures.append(f"{path.relative_to(source_root)} contains unsupported precise visual distance: {match.group(0)}")
    if not failures:
        passed.append(f"{len(files)} production Swift files contain no prohibited certainty or precise visual-distance claims")
    return {
        "schema_version": 1,
        "status": "passed" if not failures else "failed",
        "source_root": str(source_root.resolve()),
        "files_scanned": len(files),
        "passed": passed,
        "failures": failures,
        "prohibited_phrases": list(PROHIBITED_CERTAINTY),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Fail on unsafe certainty in production JARVIS Vision wording.")
    parser.add_argument("--source-root", type=Path, default=DEFAULT_SOURCE_ROOT)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = scan_safety(args.source_root)
    if args.output:
        write_json(args.output, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
