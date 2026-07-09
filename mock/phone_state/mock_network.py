from __future__ import annotations


def network_state() -> dict:
    return {
        "wifi": False,
        "bluetooth": False,
        "cellular": False,
        "dock": False,
        "mode": "offline",
    }
