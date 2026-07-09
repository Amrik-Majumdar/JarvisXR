from __future__ import annotations

from copy import deepcopy


DEFAULT_STATE = {
    "profile": "offline",
    "network": {"wifi": False, "online": False, "bluetooth": False, "cellular": False, "dock": False, "mode": "offline"},
    "battery": {"level_percent": 72, "charging": False, "low_power_mode": False},
    "storage": {"total_gb": 16, "free_gb": 5.4, "jarvis_memory_mb": 128, "nearly_full": False},
    "camera": {"available": True, "flashlight": False},
    "microphone": {"available": True, "input_level_db": -42},
    "speaker": {"available": True},
    "sensors": {
        "available": True,
        "gps": {"available": True, "lat": 0.0, "lon": 0.0, "accuracy_m": 50},
        "compass": {"available": True, "heading_deg": 180},
        "accelerometer": {"available": True, "x": 0.0, "y": 0.0, "z": 1.0},
        "gyroscope": {"available": True, "pitch": 0.0, "roll": 0.0, "yaw": 0.0},
        "barometer": {"available": True, "pressure_hpa": 1013.25},
        "ambient_light": {"available": "uncertain on public APIs", "lux": None},
        "proximity": {"available": True, "near": False},
    },
    "privacy": {"private_mode": False},
    "jailbreak": {"active": False, "ios_version": None},
}


PROFILE_PATCHES = {
    "offline": {},
    "online": {"network": {"wifi": True, "online": True, "mode": "online"}},
    "dock": {"network": {"wifi": True, "online": True, "dock": True, "mode": "dock"}},
    "low_battery": {"battery": {"level_percent": 8, "low_power_mode": True}},
    "storage_full": {"storage": {"free_gb": 0.2, "nearly_full": True}},
    "camera_unavailable": {"camera": {"available": False}},
    "microphone_unavailable": {"microphone": {"available": False}},
    "gps_unavailable": {"sensors": {"gps": {"available": False}}},
    "sensors_unavailable": {"sensors": {"available": False}},
    "private": {"privacy": {"private_mode": True}},
    "jailbreak_active": {"jailbreak": {"active": True}},
}


def deep_update(base: dict, patch: dict) -> dict:
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_update(base[key], value)
        else:
            base[key] = value
    return base


class MockPhoneState:
    def __init__(self, profile: str = "offline"):
        self.state = deepcopy(DEFAULT_STATE)
        self.apply_profile(profile)

    def apply_profile(self, profile: str) -> dict:
        if profile not in PROFILE_PATCHES:
            raise ValueError(f"Unknown mock phone state profile: {profile}")
        self.state["profile"] = profile
        deep_update(self.state, deepcopy(PROFILE_PATCHES[profile]))
        return self.snapshot()

    def set_flag(self, name: str, enabled: bool = True) -> dict:
        mapping = {
            "online": ("network", "online"),
            "wifi": ("network", "wifi"),
            "dock": ("network", "dock"),
            "private": ("privacy", "private_mode"),
            "jailbreak": ("jailbreak", "active"),
            "camera": ("camera", "available"),
            "microphone": ("microphone", "available"),
            "sensors": ("sensors", "available"),
        }
        if name not in mapping:
            raise ValueError(f"Unknown state flag: {name}")
        section, key = mapping[name]
        self.state[section][key] = enabled
        if name in {"online", "wifi"}:
            self.state["network"]["mode"] = "online" if enabled else "offline"
        if name == "dock":
            self.state["network"]["mode"] = "dock" if enabled else self.state["network"].get("mode", "offline")
        return self.snapshot()

    def snapshot(self) -> dict:
        return deepcopy(self.state)


def phone_state(profile: str = "offline") -> dict:
    return MockPhoneState(profile).snapshot()
