from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parents[1]
DEFAULT_MANIFEST = ROOT / "ios" / "JarvisXR" / "JarvisXR" / "Models" / "JarvisObjectDetector.manifest.json"
DEFAULT_MODEL = ROOT / "ios" / "JarvisXR" / "JarvisXR" / "Models" / "JarvisObjectDetector.mlmodel"
DEFAULT_NOTICE = ROOT / "ios" / "JarvisXR" / "JarvisXR" / "Models" / "JarvisObjectDetector.NOTICE.txt"

EXPECTED_SCHEMA_VERSION = 1
EXPECTED_BUNDLE_NAME = "JarvisObjectDetector"
EXPECTED_SHA256 = "cde8af2528d6eca1d1580fdd0f0147cb6613d40ba962656b5f683c65f571870e"
EXPECTED_SIZE = 8_913_366
EXPECTED_CLASS_COUNT = 80
EXPECTED_INPUT_SIZE = (416, 416)


def load_json(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as handle:
        payload = json.load(handle)
    if not isinstance(payload, dict):
        raise ValueError(f"Expected a JSON object at {path}")
    return payload


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_manifest(manifest: dict[str, Any]) -> list[str]:
    failures: list[str] = []

    def require(condition: bool, message: str) -> None:
        if not condition:
            failures.append(message)

    require(manifest.get("schema_version") == EXPECTED_SCHEMA_VERSION, "unexpected schema_version")
    require(manifest.get("bundle_resource_name") == EXPECTED_BUNDLE_NAME, "unexpected bundle_resource_name")
    require(manifest.get("source_artifact_filename") == f"{EXPECTED_BUNDLE_NAME}.mlmodel", "unexpected source artifact filename")
    require(manifest.get("compiled_resource_name") == f"{EXPECTED_BUNDLE_NAME}.mlmodelc", "unexpected compiled resource name")

    source = manifest.get("source")
    require(isinstance(source, dict), "source must be an object")
    if isinstance(source, dict):
        download_url = source.get("download_url")
        require(isinstance(download_url, str) and download_url.startswith("https://ml-assets.apple.com/"), "download_url must use the pinned Apple HTTPS host")
        require(source.get("upstream_filename") == "YOLOv3TinyInt8LUT.mlmodel", "unexpected upstream filename")

    artifact = manifest.get("artifact")
    require(isinstance(artifact, dict), "artifact must be an object")
    if isinstance(artifact, dict):
        require(artifact.get("size_bytes") == EXPECTED_SIZE, "unexpected artifact size")
        require(str(artifact.get("sha256", "")).lower() == EXPECTED_SHA256, "unexpected artifact SHA-256")
        require(artifact.get("coreml_specification_version") == 3, "unexpected Core ML specification version")

    interface = manifest.get("interface")
    require(isinstance(interface, dict), "interface must be an object")
    if isinstance(interface, dict):
        primary_input = interface.get("primary_input")
        require(isinstance(primary_input, dict), "primary_input must be an object")
        if isinstance(primary_input, dict):
            require((primary_input.get("width"), primary_input.get("height")) == EXPECTED_INPUT_SIZE, "unexpected primary input dimensions")
            require(primary_input.get("color_space") == "RGB", "unexpected primary input color space")
        threshold_names = {
            item.get("name")
            for item in interface.get("threshold_inputs", [])
            if isinstance(item, dict)
        }
        require(threshold_names == {"iouThreshold", "confidenceThreshold"}, "threshold inputs are incomplete")
        output_names = {
            item.get("name")
            for item in interface.get("outputs", [])
            if isinstance(item, dict)
        }
        require(output_names == {"confidence", "coordinates"}, "model outputs are incomplete")
        require(interface.get("non_maximum_suppression") is True, "NMS metadata must be true")
        require(interface.get("class_count") == EXPECTED_CLASS_COUNT, "unexpected interface class count")

    classes = manifest.get("classes")
    require(isinstance(classes, list), "classes must be an array")
    if isinstance(classes, list):
        require(len(classes) == EXPECTED_CLASS_COUNT, f"expected {EXPECTED_CLASS_COUNT} classes")
        require(len(set(classes)) == len(classes), "classes must be unique")
        require(all(isinstance(item, str) and item.strip() for item in classes), "classes must be nonempty strings")
        require("chair" in classes and "person" in classes, "required baseline classes are missing")

    unsupported = manifest.get("known_unsupported_requested_targets")
    require(isinstance(unsupported, list) and {"door", "stairs", "exit sign"}.issubset(set(unsupported)), "known unsupported targets are incomplete")

    license_info = manifest.get("license")
    require(isinstance(license_info, dict), "license must be an object")
    if isinstance(license_info, dict):
        require(license_info.get("name") == "YOLO License", "unexpected model license name")
        require(license_info.get("spdx_expression") == "LicenseRef-YOLO-Public-Domain", "unexpected model license expression")
        require(str(license_info.get("license_url", "")).startswith("https://github.com/pjreddie/darknet/"), "model license URL is not authoritative")
        require(license_info.get("notice_resource") == "JarvisObjectDetector.NOTICE.txt", "model notice resource is missing")

    compatibility = manifest.get("compatibility")
    require(isinstance(compatibility, dict), "compatibility must be an object")
    if isinstance(compatibility, dict):
        require(compatibility.get("target_device") == "iPhone XR", "unexpected target device")
        require(compatibility.get("network_required_at_runtime") is False, "runtime network requirement must be false")
        require(compatibility.get("physical_device_validation_required") is True, "physical-device validation must remain required")

    return failures


def verify_artifact(path: Path, manifest: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    if not path.is_file():
        return [f"model artifact is missing: {path}"]
    artifact = manifest.get("artifact", {})
    expected_size = artifact.get("size_bytes")
    expected_sha = str(artifact.get("sha256", "")).lower()
    actual_size = path.stat().st_size
    if actual_size != expected_size:
        failures.append(f"model size mismatch: expected {expected_size}, got {actual_size}")
    actual_sha = sha256_file(path)
    if actual_sha != expected_sha:
        failures.append(f"model SHA-256 mismatch: expected {expected_sha}, got {actual_sha}")
    return failures


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(payload, indent=2, sort_keys=True) + "\n", encoding="utf-8")
