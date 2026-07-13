from __future__ import annotations

import json
import plistlib
import struct
import urllib.error
import zipfile
from pathlib import Path

import pytest

from tools.audit_vision_model import audit_model
from tools.audit_ipa import REQUIRED_HELP_STRINGS, REQUIRED_INTENT_STRINGS, audit_ipa, macho_architectures
from tools.audit_vision_privacy import scan_privacy
from tools.audit_vision_safety import scan_safety
from tools.evaluate_vision_fixtures import (
    DEFAULT_FIXTURE_MANIFEST,
    evaluate_observations,
    jpeg_dimensions,
    validate_fixture_pack,
)
from tools.fetch_vision_model import fetch_model
from tools.vision_model_contract import (
    DEFAULT_MANIFEST,
    DEFAULT_NOTICE,
    EXPECTED_CLASS_COUNT,
    load_json,
    validate_manifest,
    verify_artifact,
)


def test_model_manifest_contract_is_complete():
    manifest = load_json(DEFAULT_MANIFEST)
    assert validate_manifest(manifest) == []
    assert len(manifest["classes"]) == EXPECTED_CLASS_COUNT
    assert {"door", "stairs", "exit sign"}.issubset(manifest["known_unsupported_requested_targets"])


def test_model_audit_passes_without_uncommitted_binary():
    report = audit_model(DEFAULT_MANIFEST, DEFAULT_MANIFEST.parent / "not-present.mlmodel", DEFAULT_NOTICE, False)
    assert report["status"] == "passed"
    assert any("intentionally absent" in item for item in report["passed"])


def test_model_artifact_tampering_fails_closed(tmp_path):
    model = tmp_path / "JarvisObjectDetector.mlmodel"
    model.write_bytes(b"not the pinned model")
    failures = verify_artifact(model, load_json(DEFAULT_MANIFEST))
    assert any("size mismatch" in item for item in failures)
    assert any("SHA-256 mismatch" in item for item in failures)


def test_fetch_failure_never_installs_partial_model(tmp_path, monkeypatch):
    output = tmp_path / "JarvisObjectDetector.mlmodel"

    def fail_download(*_args, **_kwargs):
        raise urllib.error.URLError("offline test")

    monkeypatch.setattr("urllib.request.urlopen", fail_download)
    with pytest.raises(urllib.error.URLError):
        fetch_model(DEFAULT_MANIFEST, output, timeout=0.1)
    assert not output.exists()
    assert not list(tmp_path.glob("*.download"))


def test_public_domain_fixture_pack_and_jpeg_are_verified():
    report, annotations = validate_fixture_pack()
    assert report["status"] == "passed"
    assert report["inference_executed"] is False
    fixture = DEFAULT_FIXTURE_MANIFEST.parent / "images" / "Desk_chair.jpg"
    assert jpeg_dimensions(fixture) == (500, 750)
    assert annotations["desk-chair-public-domain"]["expected_objects"][0]["label"] == "chair"


def test_native_observation_evaluator_scores_expected_chair(tmp_path):
    base_report, expected = validate_fixture_pack()
    observations = tmp_path / "observations.json"
    observations.write_text(
        json.dumps(
            {
                "fixtures": [
                    {
                        "fixture_id": "desk-chair-public-domain",
                        "inference_completed": True,
                        "detections": [
                            {
                                "label": "chair",
                                "confidence": 0.82,
                                "spatial_region": "center",
                                "bounding_box": {"x": 0.18, "y": 0.04, "width": 0.81, "height": 0.94},
                            }
                        ],
                        "latency_ms": 120.0,
                        "narration": "Possible chair in the center.",
                        "policy_decision": "speak_confidence_qualified",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    report = evaluate_observations(base_report, expected, observations)
    assert report["status"] == "passed"
    assert report["inference_executed"] is True
    assert report["native_results"][0]["false_negatives"] == []
    assert report["native_results"][0]["accuracy_status"] == "fixture_expectations_met"


def test_native_observation_evaluator_records_accuracy_limitation_without_falsifying_smoke(tmp_path):
    base_report, expected = validate_fixture_pack()
    observations = tmp_path / "observations.json"
    observations.write_text(
        json.dumps(
            {
                "fixtures": [
                    {
                        "fixture_id": "desk-chair-public-domain",
                        "inference_completed": True,
                        "detections": [],
                        "latency_ms": 120.0,
                        "narration": "I do not have enough evidence to describe this image.",
                        "policy_decision": "uncertain_grounded_single_frame",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    report = evaluate_observations(base_report, expected, observations)
    assert report["status"] == "passed"
    assert report["native_results"][0]["passed"] is True
    assert report["native_results"][0]["semantic_expectations_met"] is False
    assert report["native_results"][0]["accuracy_status"] == "accuracy_limitation_observed"
    assert report["native_results"][0]["false_negatives"] == ["chair"]


def test_native_observation_evaluator_rejects_unsafe_narration(tmp_path):
    base_report, expected = validate_fixture_pack()
    observations = tmp_path / "observations.json"
    observations.write_text(
        json.dumps(
            {
                "fixtures": [
                    {
                        "fixture_id": "desk-chair-public-domain",
                        "inference_completed": True,
                        "detections": [
                            {
                                "label": "chair",
                                "confidence": 0.82,
                                "spatial_region": "center",
                                "bounding_box": {"x": 0.18, "y": 0.04, "width": 0.81, "height": 0.94},
                            }
                        ],
                        "narration": "The path is safe.",
                        "latency_ms": 120.0,
                    }
                ]
            }
        ),
        encoding="utf-8",
    )
    report = evaluate_observations(base_report, expected, observations)
    assert report["status"] == "failed"
    assert report["native_results"][0]["prohibited_narration"] == ["path is safe"]


def test_safety_audit_rejects_prohibited_certainty(tmp_path):
    source = tmp_path / "UnsafeVision.swift"
    source.write_text('let narration = "The path is safe."\n', encoding="utf-8")
    report = scan_safety(tmp_path)
    assert report["status"] == "failed"
    assert any("path is safe" in item for item in report["failures"])


def test_privacy_audit_rejects_network_and_image_save_paths(tmp_path):
    source = tmp_path / "UnsafeVision.swift"
    source.write_text(
        "import Vision\nlet session = URLSession.shared\nUIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)\n",
        encoding="utf-8",
    )
    report = scan_privacy(tmp_path, DEFAULT_MANIFEST)
    assert report["status"] == "failed"
    assert any("URLSession" in item for item in report["failures"])
    assert any("UIImageWriteToSavedPhotosAlbum" in item for item in report["failures"])


def test_macho_architecture_parser_recognizes_arm64_device_binary():
    binary = b"\xcf\xfa\xed\xfe" + struct.pack("<I", 0x0100000C) + b"\0" * 24
    assert macho_architectures(binary) == ["arm64"]


def test_ipa_audit_requires_model_permissions_unsigned_arm64_and_metadata(tmp_path):
    ipa = tmp_path / "JarvisXR-unsigned.ipa"
    make_synthetic_ipa(ipa)
    report = audit_ipa(ipa, inspect_compiled_assets=False)
    assert report["status"] == "passed", report["failures"]
    assert report["metadata"]["architectures"] == ["arm64"]
    assert report["metadata"]["source_model_sha256"] == load_json(DEFAULT_MANIFEST)["artifact"]["sha256"]
    assert report["metadata"]["unsigned_packaging_consistent"] is True


def test_ipa_audit_rejects_secret_file_and_code_signature(tmp_path):
    ipa = tmp_path / "JarvisXR-unsigned.ipa"
    make_synthetic_ipa(
        ipa,
        extras={
            "Payload/JarvisXR.app/.env": b"NOT_A_REAL_KEY=test",
            "Payload/JarvisXR.app/_CodeSignature/CodeResources": b"signature",
        },
    )
    report = audit_ipa(ipa, inspect_compiled_assets=False)
    assert report["status"] == "failed"
    assert any("credential filenames" in item for item in report["failures"])
    assert any("code-signature" in item for item in report["failures"])


def make_synthetic_ipa(path: Path, extras: dict[str, bytes] | None = None) -> None:
    root = "Payload/JarvisXR.app"
    info = {
        "CFBundleDisplayName": "JARVIS",
        "CFBundleExecutable": "JarvisXR",
        "CFBundleIdentifier": "com.amrik.jarvisxr",
        "CFBundleSupportedPlatforms": ["iPhoneOS"],
        "MinimumOSVersion": "18.0",
        "NSCameraUsageDescription": "Camera use.",
        "NSMicrophoneUsageDescription": "Microphone use.",
        "NSSpeechRecognitionUsageDescription": "Speech recognition use.",
        "UILaunchStoryboardName": "LaunchScreen",
    }
    executable = b"\xcf\xfa\xed\xfe" + struct.pack("<I", 0x0100000C) + b"\0" * 64
    evidence = "\n".join((*REQUIRED_INTENT_STRINGS, *REQUIRED_HELP_STRINGS)).encode()
    files = {
        f"{root}/Info.plist": plistlib.dumps(info),
        f"{root}/JarvisXR": executable,
        f"{root}/Assets.car": b"synthetic-assets",
        f"{root}/LaunchScreen.storyboardc/Info.plist": b"launch",
        f"{root}/ExtractedAppShortcutsMetadata.strings": evidence,
        f"{root}/JarvisObjectDetector.mlmodelc/model.espresso.net": b"compiled-model",
        f"{root}/JarvisObjectDetector.manifest.json": DEFAULT_MANIFEST.read_bytes(),
        f"{root}/JarvisObjectDetector.NOTICE.txt": DEFAULT_NOTICE.read_bytes(),
    }
    files.update(extras or {})
    with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        for name, content in files.items():
            archive.writestr(name, content)
