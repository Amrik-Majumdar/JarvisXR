from __future__ import annotations

import argparse
import json
import os
import tempfile
import urllib.request
from pathlib import Path

try:
    from .vision_model_contract import (
        DEFAULT_MANIFEST,
        DEFAULT_MODEL,
        load_json,
        sha256_file,
        validate_manifest,
        verify_artifact,
        write_json,
    )
except ImportError:  # Direct execution: python tools/fetch_vision_model.py
    from vision_model_contract import (
        DEFAULT_MANIFEST,
        DEFAULT_MODEL,
        load_json,
        sha256_file,
        validate_manifest,
        verify_artifact,
        write_json,
    )


def fetch_model(
    manifest_path: Path,
    output_path: Path,
    *,
    timeout: float = 120.0,
    force: bool = False,
    verify_only: bool = False,
) -> dict:
    manifest = load_json(manifest_path)
    manifest_failures = validate_manifest(manifest)
    if manifest_failures:
        raise RuntimeError("Invalid model manifest: " + "; ".join(manifest_failures))

    if output_path.exists() and not force:
        existing_failures = verify_artifact(output_path, manifest)
        if not existing_failures:
            return result_payload("already_verified", manifest_path, output_path, manifest)
        if verify_only:
            raise RuntimeError("; ".join(existing_failures))
    elif verify_only:
        raise RuntimeError(f"Model artifact is missing: {output_path}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    source = manifest["source"]
    request = urllib.request.Request(
        source["download_url"],
        headers={"User-Agent": "JarvisXR-model-fetch/1.0"},
    )
    temporary_path: Path | None = None
    try:
        with tempfile.NamedTemporaryFile(
            prefix=".JarvisObjectDetector-",
            suffix=".download",
            dir=output_path.parent,
            delete=False,
        ) as temporary:
            temporary_path = Path(temporary.name)
            with urllib.request.urlopen(request, timeout=timeout) as response:
                if getattr(response, "status", 200) != 200:
                    raise RuntimeError(f"Model download returned HTTP {response.status}")
                while True:
                    chunk = response.read(1024 * 1024)
                    if not chunk:
                        break
                    temporary.write(chunk)
            temporary.flush()
            os.fsync(temporary.fileno())

        downloaded_failures = verify_artifact(temporary_path, manifest)
        if downloaded_failures:
            raise RuntimeError("Downloaded model failed verification: " + "; ".join(downloaded_failures))

        os.replace(temporary_path, output_path)
        temporary_path = None
        return result_payload("downloaded_and_verified", manifest_path, output_path, manifest)
    finally:
        if temporary_path is not None:
            temporary_path.unlink(missing_ok=True)


def result_payload(status: str, manifest_path: Path, output_path: Path, manifest: dict) -> dict:
    return {
        "schema_version": 1,
        "status": status,
        "manifest": str(manifest_path.resolve()),
        "output": str(output_path.resolve()),
        "source_url": manifest["source"]["download_url"],
        "size_bytes": output_path.stat().st_size,
        "sha256": sha256_file(output_path),
        "verified": True,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Fetch and checksum-verify the pinned JARVIS Core ML detector.")
    parser.add_argument("--manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--output", type=Path, default=DEFAULT_MODEL)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--timeout", type=float, default=120.0)
    parser.add_argument("--force", action="store_true")
    parser.add_argument("--verify-only", action="store_true")
    args = parser.parse_args()

    try:
        result = fetch_model(
            args.manifest,
            args.output,
            timeout=args.timeout,
            force=args.force,
            verify_only=args.verify_only,
        )
    except Exception as exc:
        result = {
            "schema_version": 1,
            "status": "failed",
            "verified": False,
            "manifest": str(args.manifest.resolve()),
            "output": str(args.output.resolve()),
            "error": str(exc),
        }
        if args.report:
            write_json(args.report, result)
        print(json.dumps(result, indent=2, sort_keys=True))
        return 1

    if args.report:
        write_json(args.report, result)
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
