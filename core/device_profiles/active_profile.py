from __future__ import annotations

from .device_profile import compare_profiles
from .iphone_6 import iphone_6_profile
from .iphone_xr import iphone_xr_profile


ACTIVE_PROFILE = iphone_xr_profile()


def get_active_profile() -> dict:
    profile = ACTIVE_PROFILE.to_dict()
    profile["validation_errors"] = ACTIVE_PROFILE.validate()
    return profile


def compare_device_profiles() -> dict:
    return compare_profiles(ACTIVE_PROFILE, iphone_6_profile())


def get_device_mode_strategy() -> dict:
    return {
        "target": ACTIVE_PROFILE.model,
        "ios_version": ACTIVE_PROFILE.ios_version,
        "strategy": "Jarvis Device Mode",
        "primary_path": [
            "Build a native iOS Jarvis shell for iPhone XR.",
            "Strip the phone down so Jarvis is the visible purpose.",
            "Use supervised Single App Mode as the strongest non-jailbreak ownership path.",
            "Use Guided Access only as the immediate fallback.",
            "Treat Shortcuts, browser search, and Spotify as optional modules only.",
            "Do not grow app orchestration until takeover direction is chosen.",
        ],
        "blocked_future_path": [
            "SpringBoard hooks",
            "lock screen hooks",
            "launchd daemon install",
            "root file access",
            "system-wide button remaps",
        ],
        "dock_path": [
            "Windows PC remains development and test harness.",
            "Raspberry Pi remains sync, package, backup, recovery, and heavier-processing dock.",
        ],
        "honesty_boundary": "True phone ownership is blocked without jailbreak. Managed appliance mode is an approximation.",
    }
