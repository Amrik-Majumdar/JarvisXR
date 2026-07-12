from __future__ import annotations

import os
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
REPORTS = ROOT / "ios" / "JarvisXR" / "build" / "reports"
PYTEST_TEMP_ROOT = ROOT / "ios" / "JarvisXR" / "build" / "pytest-temp" / str(os.getpid())


def run(command: list[str]) -> int:
    print(f"$ {' '.join(command)}")
    completed = subprocess.run(command, cwd=ROOT)
    return completed.returncode


def pytest(path: str, name: str) -> list[str]:
    """Keep pytest deterministic when the host's global temp/cache is restricted."""
    return [
        sys.executable,
        "-m",
        "pytest",
        path,
        "--basetemp",
        str(PYTEST_TEMP_ROOT / name),
        "-p",
        "no:cacheprovider",
    ]


def main() -> int:
    REPORTS.mkdir(parents=True, exist_ok=True)
    PYTEST_TEMP_ROOT.mkdir(parents=True, exist_ok=True)
    checks = [
        [sys.executable, "core/registry/validate_registry.py"],
        [sys.executable, "core/registry/xr_capability_matrix.py"],
        [sys.executable, "native/ios/JarvisShell/scripts/generate_models.py"],
        [sys.executable, "tools/audit_vision_model.py", "--output", str(REPORTS / "vision-model-audit.json")],
        [sys.executable, "tools/evaluate_vision_fixtures.py", "--metadata-only", "--output", str(REPORTS / "vision-fixture-metadata.json")],
        [sys.executable, "tools/audit_vision_safety.py", "--output", str(REPORTS / "vision-safety-audit.json")],
        [sys.executable, "tools/audit_vision_privacy.py", "--output", str(REPORTS / "vision-privacy-audit.json")],
        pytest("tests/vision", "vision"),
        [sys.executable, "tools/jarvis_product_surface_test.py"],
        pytest("core/device_profiles/tests", "device-profiles"),
        pytest("core/ownership/tests", "ownership"),
        pytest("core/registry/tests", "registry"),
        pytest("core/adapters/tests", "adapters"),
        pytest("core/router/tests", "router"),
        pytest("core/daemon/tests", "daemon"),
    ]
    for command in checks:
        code = run(command)
        if code != 0:
            return code
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
