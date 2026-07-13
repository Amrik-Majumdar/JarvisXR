from __future__ import annotations

import argparse
import json
from pathlib import Path

try:
    from .vision_model_contract import (
        DEFAULT_MANIFEST,
        DEFAULT_MODEL,
        DEFAULT_NOTICE,
        load_json,
        validate_manifest,
        verify_artifact,
        write_json,
    )
except ImportError:  # Direct execution: python tools/audit_vision_model.py
    from vision_model_contract import (
        DEFAULT_MANIFEST,
        DEFAULT_MODEL,
        DEFAULT_NOTICE,
        load_json,
        validate_manifest,
        verify_artifact,
        write_json,
    )


def audit_model(manifest_path: Path, model_path: Path, notice_path: Path, require_model: bool) -> dict:
    failures: list[str] = []
    passed: list[str] = []
    metadata: dict = {}

    try:
        manifest = load_json(manifest_path)
    except Exception as exc:
        return {
            "schema_version": 1,
            "status": "failed",
            "passed": passed,
            "failures": [f"could not load model manifest: {exc}"],
            "metadata": metadata,
        }

    failures.extend(validate_manifest(manifest))
    if not failures:
        passed.append("model manifest contract is valid")

    if notice_path.is_file() and notice_path.stat().st_size > 0:
        notice = notice_path.read_text(encoding="utf-8")
        expected_digest = manifest.get("artifact", {}).get("sha256", "")
        expected_license_url = manifest.get("license", {}).get("license_url", "")
        if expected_digest in notice and expected_license_url in notice:
            passed.append("model notice preserves checksum and authoritative license URL")
        else:
            failures.append("model notice is missing checksum or authoritative license URL")
    else:
        failures.append(f"model notice is missing: {notice_path}")

    if model_path.exists():
        artifact_failures = verify_artifact(model_path, manifest)
        failures.extend(artifact_failures)
        if not artifact_failures:
            passed.append("model artifact size and SHA-256 are verified")
            metadata["artifact_size_bytes"] = model_path.stat().st_size
            metadata["artifact_sha256"] = manifest["artifact"]["sha256"]
    elif require_model:
        failures.append(f"model artifact is required but missing: {model_path}")
    else:
        passed.append("model artifact intentionally absent from source checkout")

    metadata.update(
        {
            "manifest": str(manifest_path.resolve()),
            "model": str(model_path.resolve()),
            "notice": str(notice_path.resolve()),
            "bundle_resource_name": manifest.get("bundle_resource_name"),
            "class_count": len(manifest.get("classes", [])),
            "runtime_network_required": manifest.get("compatibility", {}).get("network_required_at_runtime"),
        }
    )
    return {
        "schema_version": 1,
        "status": "passed" if not failures else "failed",
        "passed": passed,
        "failures": failures,
        "metadata": metadata,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit the JARVIS object-detector manifest and optional source artifact.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--model", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--notice", type=Path, default=DEFAULT_NOTICE)
    parser.add_argument("--require-model", action="store_true")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    report = audit_model(args.manifest, args.model, args.notice, args.require_model)
    if args.output:
        write_json(args.output, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
