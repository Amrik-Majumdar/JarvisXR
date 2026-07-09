from __future__ import annotations

import json
from pathlib import Path

from core.registry.xr_capability_matrix import build_matrix, classify_capability, write_matrix


ROOT = Path(__file__).resolve().parents[3]


def _by_id(matrix: dict) -> dict:
    return {item["id"]: item for item in matrix["capabilities"]}


def test_xr_capability_matrix_generation_writes_json():
    matrix = write_matrix()
    path = ROOT / "core" / "registry" / "xr_capability_matrix.json"
    assert path.exists()
    saved = json.loads(path.read_text(encoding="utf-8"))
    assert saved["target_device"] == "iPhone XR"
    assert len(saved["capabilities"]) == 400


def test_camera_vision_ocr_capabilities_remain_native_possible():
    matrix = _by_id(build_matrix())
    assert "available_offline_native" in matrix["camera_inspection_001"]["xr_classifications"]
    assert "available_offline_native" in matrix["object_detection_001"]["xr_classifications"]
    assert "available_offline_native" in matrix["ocr_text_001"]["xr_classifications"]


def test_phone_control_capabilities_blocked_until_jailbreak():
    matrix = _by_id(build_matrix())
    assert "blocked_until_jailbreak" in matrix["phone_control_001"]["xr_classifications"]


def test_online_search_stays_online_only():
    capability = {
        "id": "online_enhancement_test",
        "family": "Online Enhancement",
        "name": "Search Current Weather Online",
        "mode": "online",
        "required_hardware": ["wifi"],
        "implementation_notes": "search the web",
        "example_voice_phrases": ["search current weather online"],
    }
    result = classify_capability(capability)
    assert "available_online_native" in result["xr_classifications"]
    assert "blocked_in_hard_lockdown" in result["xr_classifications"]
    assert "available_offline_native" not in result["xr_classifications"]


def test_spotify_capabilities_marked_uncertain_or_mode_dependent():
    capability = {
        "id": "spotify_test",
        "family": "Audio and Voice",
        "name": "Open Spotify Playlist",
        "mode": "hybrid",
        "required_hardware": ["speaker", "wifi"],
        "implementation_notes": "open Spotify link",
        "example_voice_phrases": ["play my playlist"],
    }
    result = classify_capability(capability)
    assert "available_soft_ownership" in result["xr_classifications"]
    assert "uncertain_needs_device_test" in result["xr_classifications"]


def test_dock_functions_stay_dock_only():
    matrix = _by_id(build_matrix())
    assert "available_dock" in matrix["raspberry_pi_dock_001"]["xr_classifications"]
    assert "available_dock" in matrix["windows_pc_dock_001"]["xr_classifications"]
