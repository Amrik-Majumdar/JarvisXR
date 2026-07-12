from __future__ import annotations

import argparse
import json
import struct
from pathlib import Path
from typing import Any

try:
    from .vision_model_contract import DEFAULT_MANIFEST, ROOT, load_json, sha256_file, validate_manifest, write_json
except ImportError:  # Direct execution: python tools/evaluate_vision_fixtures.py
    from vision_model_contract import DEFAULT_MANIFEST, ROOT, load_json, sha256_file, validate_manifest, write_json


DEFAULT_FIXTURE_ROOT = ROOT / "tests" / "fixtures" / "vision"
DEFAULT_FIXTURE_MANIFEST = DEFAULT_FIXTURE_ROOT / "fixtures.manifest.json"
SPATIAL_REGIONS = {"left", "center", "right"}
VERTICAL_REGIONS = {"high", "middle", "low"}
FORBIDDEN_NARRATION = (
    "path is safe",
    "safe to cross",
    "road is clear",
    "path is clear",
    "nothing is there",
    "no obstacles",
    "you can proceed",
)


def jpeg_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        if handle.read(2) != b"\xff\xd8":
            raise ValueError(f"Not a JPEG file: {path}")
        while True:
            marker_start = handle.read(1)
            if not marker_start:
                break
            if marker_start != b"\xff":
                continue
            marker = handle.read(1)
            while marker == b"\xff":
                marker = handle.read(1)
            if not marker or marker in {b"\xd8", b"\xd9"}:
                continue
            length_bytes = handle.read(2)
            if len(length_bytes) != 2:
                break
            segment_length = struct.unpack(">H", length_bytes)[0]
            if segment_length < 2:
                raise ValueError(f"Invalid JPEG segment in {path}")
            if marker[0] in {0xC0, 0xC1, 0xC2, 0xC3, 0xC5, 0xC6, 0xC7, 0xC9, 0xCA, 0xCB, 0xCD, 0xCE, 0xCF}:
                segment = handle.read(segment_length - 2)
                if len(segment) < 5:
                    break
                height, width = struct.unpack(">HH", segment[1:5])
                return width, height
            handle.seek(segment_length - 2, 1)
    raise ValueError(f"JPEG dimensions were not found: {path}")


def validate_fixture_pack(
    fixture_manifest_path: Path = DEFAULT_FIXTURE_MANIFEST,
    model_manifest_path: Path = DEFAULT_MANIFEST,
) -> tuple[dict[str, Any], dict[str, dict[str, Any]]]:
    failures: list[str] = []
    passed: list[str] = []
    fixture_reports: dict[str, dict[str, Any]] = {}
    fixture_manifest = load_json(fixture_manifest_path)
    model_manifest = load_json(model_manifest_path)
    failures.extend(f"model manifest: {item}" for item in validate_manifest(model_manifest))
    classes = set(model_manifest.get("classes", []))
    root = fixture_manifest_path.parent

    if fixture_manifest.get("schema_version") != 1:
        failures.append("fixture manifest has an unexpected schema version")
    fixtures = fixture_manifest.get("fixtures")
    if not isinstance(fixtures, list) or not fixtures:
        failures.append("fixture manifest must contain at least one fixture")
        fixtures = []

    seen_ids: set[str] = set()
    for item in fixtures:
        if not isinstance(item, dict):
            failures.append("fixture entry must be an object")
            continue
        fixture_id = str(item.get("id", ""))
        item_failures: list[str] = []
        if not fixture_id or fixture_id in seen_ids:
            item_failures.append("fixture id is missing or duplicated")
        seen_ids.add(fixture_id)
        image_path = root / str(item.get("file", ""))
        annotation_path = root / str(item.get("expected_annotation", ""))
        if not image_path.is_file():
            item_failures.append(f"image is missing: {image_path}")
        else:
            if image_path.stat().st_size != item.get("size_bytes"):
                item_failures.append("image size does not match manifest")
            if sha256_file(image_path) != str(item.get("sha256", "")).lower():
                item_failures.append("image SHA-256 does not match manifest")
            try:
                dimensions = jpeg_dimensions(image_path)
                if dimensions != (item.get("width"), item.get("height")):
                    item_failures.append(f"image dimensions do not match manifest: {dimensions}")
            except Exception as exc:
                item_failures.append(str(exc))

        license_info = item.get("license")
        if not isinstance(license_info, dict) or license_info.get("spdx_expression") != "LicenseRef-Public-Domain":
            item_failures.append("fixture must have an explicit public-domain license record")
        if not str(item.get("source_page", "")).startswith("https://commons.wikimedia.org/"):
            item_failures.append("fixture source page must use Wikimedia Commons HTTPS")

        annotation: dict[str, Any] = {}
        if not annotation_path.is_file():
            item_failures.append(f"expected annotation is missing: {annotation_path}")
        else:
            try:
                annotation = load_json(annotation_path)
            except Exception as exc:
                item_failures.append(f"could not load annotation: {exc}")
        if annotation:
            if annotation.get("fixture_id") != fixture_id:
                item_failures.append("annotation fixture_id does not match")
            for expected in annotation.get("expected_objects", []):
                if not isinstance(expected, dict):
                    item_failures.append("expected object must be an object")
                    continue
                label = expected.get("label")
                if label not in classes:
                    item_failures.append(f"expected label is not supported by the model: {label}")
                if expected.get("spatial_region") not in SPATIAL_REGIONS:
                    item_failures.append(f"invalid spatial region for {label}")
                if expected.get("vertical_region") not in VERTICAL_REGIONS:
                    item_failures.append(f"invalid vertical region for {label}")
                box = expected.get("approximate_bounding_box")
                if not valid_box(box):
                    item_failures.append(f"invalid normalized bounding box for {label}")

        fixture_reports[fixture_id] = {
            "image": str(image_path.resolve()),
            "annotation": str(annotation_path.resolve()),
            "failures": item_failures,
        }
        failures.extend(f"{fixture_id}: {failure}" for failure in item_failures)
        if not item_failures:
            passed.append(f"{fixture_id}: binary, license, and annotation verified")

    report = {
        "schema_version": 1,
        "status": "passed" if not failures else "failed",
        "scope": "fixture_integrity_and_expectation_validation",
        "inference_executed": False,
        "passed": passed,
        "failures": failures,
        "fixtures": fixture_reports,
    }
    return report, {str(item.get("id")): load_json(root / str(item.get("expected_annotation"))) for item in fixtures if isinstance(item, dict) and (root / str(item.get("expected_annotation", ""))).is_file()}


def valid_box(box: Any) -> bool:
    if not isinstance(box, dict):
        return False
    try:
        x, y, width, height = (float(box[key]) for key in ("x", "y", "width", "height"))
    except (KeyError, TypeError, ValueError):
        return False
    return 0 <= x <= 1 and 0 <= y <= 1 and 0 < width <= 1 and 0 < height <= 1 and x + width <= 1.01 and y + height <= 1.01


def box_iou(left: dict[str, Any], right: dict[str, Any]) -> float:
    lx1, ly1 = float(left["x"]), float(left["y"])
    lx2, ly2 = lx1 + float(left["width"]), ly1 + float(left["height"])
    rx1, ry1 = float(right["x"]), float(right["y"])
    rx2, ry2 = rx1 + float(right["width"]), ry1 + float(right["height"])
    intersection = max(0.0, min(lx2, rx2) - max(lx1, rx1)) * max(0.0, min(ly2, ry2) - max(ly1, ry1))
    union = (lx2 - lx1) * (ly2 - ly1) + (rx2 - rx1) * (ry2 - ry1) - intersection
    return intersection / union if union > 0 else 0.0


def evaluate_observations(base_report: dict[str, Any], expected_by_id: dict[str, dict[str, Any]], observations_path: Path) -> dict[str, Any]:
    payload = load_json(observations_path)
    observations = payload.get("fixtures")
    if not isinstance(observations, list):
        raise ValueError("observations JSON must contain a fixtures array")
    by_id = {str(item.get("fixture_id")): item for item in observations if isinstance(item, dict)}
    failures = list(base_report["failures"])
    results: list[dict[str, Any]] = []
    for fixture_id, expected in expected_by_id.items():
        actual = by_id.get(fixture_id)
        if actual is None:
            failures.append(f"{fixture_id}: native observations are missing")
            continue
        detections = [item for item in actual.get("detections", []) if isinstance(item, dict)]
        expected_objects = [item for item in expected.get("expected_objects", []) if isinstance(item, dict)]
        false_negatives: list[str] = []
        matched_indices: set[int] = set()
        for target in expected_objects:
            candidates: list[tuple[int, dict[str, Any], float]] = []
            for index, detection in enumerate(detections):
                if detection.get("label") != target.get("label"):
                    continue
                confidence = float(detection.get("confidence", 0.0))
                if confidence < float(target.get("minimum_confidence_for_fixture_evaluation", 0.0)):
                    continue
                iou = 1.0
                if valid_box(detection.get("bounding_box")):
                    iou = box_iou(target["approximate_bounding_box"], detection["bounding_box"])
                elif detection.get("spatial_region") != target.get("spatial_region"):
                    continue
                candidates.append((index, detection, iou))
            candidates.sort(key=lambda entry: (entry[2], float(entry[1].get("confidence", 0.0))), reverse=True)
            if not candidates or candidates[0][2] < float(target.get("minimum_iou_for_fixture_evaluation", 0.0)):
                if target.get("required", True):
                    false_negatives.append(str(target.get("label")))
            else:
                matched_indices.add(candidates[0][0])
        allowed = set(expected.get("allowed_additional_labels", []))
        false_positives = [
            str(detection.get("label"))
            for index, detection in enumerate(detections)
            if index not in matched_indices and detection.get("label") not in allowed and float(detection.get("confidence", 0.0)) >= 0.2
        ]
        narration = str(actual.get("narration", ""))
        prohibited = [phrase for phrase in FORBIDDEN_NARRATION if phrase in narration.lower()]
        fixture_passed = (
            not false_negatives
            and len(false_positives) <= int(expected.get("maximum_false_positives", 0))
            and not prohibited
        )
        if not fixture_passed:
            failures.append(f"{fixture_id}: native evaluation failed")
        results.append(
            {
                "fixture_id": fixture_id,
                "passed": fixture_passed,
                "false_negatives": false_negatives,
                "false_positives": false_positives,
                "prohibited_narration": prohibited,
                "latency_ms": actual.get("latency_ms"),
                "policy_decision": actual.get("policy_decision"),
            }
        )
    return {
        **base_report,
        "status": "passed" if not failures else "failed",
        "scope": "native_fixture_observation_evaluation",
        "inference_executed": True,
        "observation_source": str(observations_path.resolve()),
        "failures": failures,
        "native_results": results,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Validate legal vision fixtures and optionally score native detector observations.")
    parser.add_argument("--fixtures", type=Path, default=DEFAULT_FIXTURE_MANIFEST)
    parser.add_argument("--model-manifest", type=Path, default=DEFAULT_MANIFEST)
    parser.add_argument("--metadata-only", action="store_true")
    parser.add_argument("--observations", type=Path)
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    if args.metadata_only == bool(args.observations):
        parser.error("choose exactly one of --metadata-only or --observations")
    try:
        report, expected = validate_fixture_pack(args.fixtures, args.model_manifest)
        if args.observations:
            report = evaluate_observations(report, expected, args.observations)
    except Exception as exc:
        report = {
            "schema_version": 1,
            "status": "failed",
            "scope": "fixture_evaluation",
            "inference_executed": False,
            "passed": [],
            "failures": [str(exc)],
        }
    if args.output:
        write_json(args.output, report)
    print(json.dumps(report, indent=2, sort_keys=True))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
