from __future__ import annotations

import argparse
from pathlib import Path


REQUIRED_SCREENSHOTS = [
    "standby.png",
    "ready.png",
    "listening.png",
    "processing.png",
    "no-speech.png",
    "long-hold-standby.png",
    "keyboard.png",
    "help.png",
    "mesh.png",
    "inspection.png",
    "object-model-missing.png",
    "settings.png",
    "diagnostics.png",
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Verify JARVIS iOS visual proof screenshots.")
    parser.add_argument("directory", help="Directory containing PNG screenshots from XCUITest.")
    args = parser.parse_args()

    root = Path(args.directory)
    failures: list[str] = []
    for filename in REQUIRED_SCREENSHOTS:
        path = root / filename
        if not path.exists():
            failures.append(f"missing: {filename}")
        elif path.stat().st_size <= 0:
            failures.append(f"empty: {filename}")

    if failures:
        print("JARVIS visual proof verification failed")
        for failure in failures:
            print(f"FAIL: {failure}")
        return 1

    print(f"JARVIS visual proof verification passed: {len(REQUIRED_SCREENSHOTS)} screenshots")
    for filename in REQUIRED_SCREENSHOTS:
        print(f"PASS: {filename}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
