from __future__ import annotations


def camera_state() -> dict:
    return {
        "available": True,
        "mode": "mock",
        "flashlight": False,
        "last_frame": None,
        "supported_actions": ["capture_still", "freeze_frame", "scan_qr", "mock_ocr", "mock_object_detect"],
    }
