from __future__ import annotations

import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


def run(command: list[str]) -> int:
    print(f"$ {' '.join(command)}")
    completed = subprocess.run(command, cwd=ROOT)
    return completed.returncode


def main() -> int:
    checks = [
        [sys.executable, "core/registry/validate_registry.py"],
        [sys.executable, "core/registry/xr_capability_matrix.py"],
        [sys.executable, "native/ios/JarvisShell/scripts/generate_models.py"],
        [sys.executable, "-m", "pytest", "core/device_profiles/tests"],
        [sys.executable, "-m", "pytest", "core/ownership/tests"],
        [sys.executable, "-m", "pytest", "core/registry/tests"],
        [sys.executable, "-m", "pytest", "core/adapters/tests"],
        [sys.executable, "-m", "pytest", "core/router/tests"],
        [sys.executable, "-m", "pytest", "core/daemon/tests"],
    ]
    for command in checks:
        code = run(command)
        if code != 0:
            return code
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
