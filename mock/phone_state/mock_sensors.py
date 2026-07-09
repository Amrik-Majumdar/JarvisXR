from __future__ import annotations


def sensor_state() -> dict:
    return {
        "gps": {"available": True, "lat": 0.0, "lon": 0.0, "accuracy_m": 50},
        "compass": {"available": True, "heading_deg": 180},
        "accelerometer": {"available": True, "x": 0.0, "y": 0.0, "z": 1.0},
        "gyroscope": {"available": True, "pitch": 0.0, "roll": 0.0, "yaw": 0.0},
        "barometer": {"available": True, "pressure_hpa": 1013.25},
        "ambient_light": {"available": "uncertain on public APIs", "lux": None},
        "proximity": {"available": True, "near": False},
    }
