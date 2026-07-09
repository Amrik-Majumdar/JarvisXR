from __future__ import annotations

import datetime as dt
import importlib.util
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "preview" / "windows_jarvis_preview" / "jarvis_preview.py"
OUT = ROOT / "dist" / "real_device_bugfix_visual_review"
BUNDLE_REPORT = ROOT / "dist" / "jarvis_local_approval_bundle" / "latest_visual_report.txt"


def load_preview_module():
    spec = importlib.util.spec_from_file_location("jarvis_preview", PREVIEW)
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load preview module.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    preview = load_preview_module()
    reports = preview.visual_state_reports()
    OUT.mkdir(parents=True, exist_ok=True)
    lines = [
        "JARVIS real-device bugfix visual review",
        f"timestamp: {dt.datetime.now().isoformat(timespec='seconds')}",
        f"states: {len(reports)}",
        "",
    ]
    for name, content in reports.items():
        path = OUT / f"{name}.txt"
        path.write_text(content, encoding="utf-8")
        lines.append(f"- {name}: {path}")
    BUNDLE_REPORT.parent.mkdir(parents=True, exist_ok=True)
    BUNDLE_REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print("\n".join(lines))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
