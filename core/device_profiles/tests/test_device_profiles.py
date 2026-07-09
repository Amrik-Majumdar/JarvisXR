from __future__ import annotations

from core.device_profiles import compare_device_profiles, get_active_profile, get_device_mode_strategy
from core.device_profiles.iphone_xr import iphone_xr_profile


def test_active_device_profile_is_iphone_xr():
    profile = get_active_profile()
    assert profile["model"] == "iPhone XR"
    assert profile["ios_version"] == "18.7.9"
    assert profile["active_target"] == "iPhone XR"
    assert profile["desired_identity"] == "Jarvis is the phone"


def test_iphone_xr_profile_validates():
    profile = iphone_xr_profile()
    assert profile.validate() == []
    assert profile.no_sim is True
    assert profile.offline_first is True
    assert profile.spotify_installed is True


def test_compare_device_profiles_preserves_iphone_6_lane():
    comparison = compare_device_profiles()
    assert comparison["active_model"] == "iPhone XR"
    assert comparison["comparison_model"] == "iPhone 6"
    assert comparison["differences"]["primary_path"]["active"] == "Device Takeover Feasibility Gate"


def test_device_mode_strategy_marks_jailbreak_features_blocked():
    strategy = get_device_mode_strategy()
    blocked = set(strategy["blocked_future_path"])
    assert "SpringBoard hooks" in blocked
    assert "launchd daemon install" in blocked
    assert strategy["strategy"] == "Jarvis Device Mode"


def test_xr_profile_marks_app_orchestration_secondary():
    profile = get_active_profile()
    assert profile["true_ownership"] == "blocked without jailbreak"
    assert profile["best_current_approximation"] == "managed Jarvis appliance or supervised kiosk"
    assert profile["app_orchestration"] == "secondary utility, not core direction"
    assert profile["spotify_web_search"] == "optional modules, not identity"
