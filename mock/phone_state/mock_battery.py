from __future__ import annotations


def battery_state() -> dict:
    return {
        "level_percent": 72,
        "charging": False,
        "low_power_mode": False,
        "health_source": "mock only until device diagnostics are available",
    }
