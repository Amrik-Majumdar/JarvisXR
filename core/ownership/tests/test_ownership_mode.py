from __future__ import annotations

from core.ownership import (
    OwnershipController,
    explain_what_blocks_true_ownership,
    explain_why_not_just_an_app,
    get_recommended_takeover_path,
    get_takeover_levels,
    get_true_ownership_requirements,
    list_appliance_mode_steps,
    list_jailbreak_only_features,
    list_supervision_features,
)


def test_ownership_modes_list_contains_v06_modes():
    controller = OwnershipController()
    ids = {mode["mode_id"] for mode in controller.list_modes()}
    assert {
        "normal_app_mode",
        "native_shell_mode",
        "restricted_device_mode",
        "supervised_kiosk_mode",
        "managed_appliance_mode",
        "jailbroken_jarvisos_mode_blocked",
        "firmware_replacement_mode_impractical",
    }.issubset(ids)


def test_set_and_get_ownership_mode():
    controller = OwnershipController()
    ok, _, mode = controller.set_mode("managed_appliance_mode")
    assert ok is True
    assert mode["mode_id"] == "managed_appliance_mode"
    assert controller.get_current_mode()["mode_id"] == "managed_appliance_mode"


def test_hard_kiosk_blocks_external_app_handoff():
    controller = OwnershipController("supervised_kiosk_mode")
    mode = controller.get_current_mode()
    assert mode["external_apps_can_open"] is False
    assert mode["spotify_can_open"] is False
    assert mode["browser_can_open"] is False


def test_restricted_device_allows_secondary_external_utility():
    controller = OwnershipController("restricted_device_mode")
    mode = controller.get_current_mode()
    assert mode["external_apps_can_open"] is True
    assert mode["final_identity_status"] == "partial approximation"


def test_jailbroken_jarvisos_mode_reports_blocked():
    controller = OwnershipController()
    ok, message, mode = controller.set_mode("jailbroken_jarvisos_mode_blocked")
    assert ok is False
    assert "not currently buildable" in message
    assert mode["final_identity_status"] == "true goal but blocked"


def test_firmware_replacement_marked_impractical():
    controller = OwnershipController()
    ok, _, mode = controller.set_mode("firmware_replacement_mode_impractical")
    assert ok is False
    assert mode["final_identity_status"] == "impossible or not practical"


def test_blocked_features_reflect_current_mode():
    controller = OwnershipController("managed_appliance_mode")
    features = {item["feature"] for item in controller.list_blocked_features()}
    assert "external_app_handoff" in features
    assert "background_listening" in features


def test_takeover_levels_exist():
    levels = get_takeover_levels()
    assert len(levels) == 7
    assert levels[0]["id"] == "normal_app"
    assert levels[-1]["id"] == "firmware_replacement"


def test_takeover_normal_app_rejected_as_final_identity():
    normal = get_takeover_levels()[0]
    assert normal["final_identity"] == "rejected"
    assert normal["feels_like_jarvis_is_phone"] is False


def test_supervised_kiosk_buildable_if_setup_exists():
    kiosk = next(level for level in get_takeover_levels() if level["id"] == "supervised_jarvis_kiosk")
    assert "setup exists" in kiosk["can_be_built_now"]
    assert kiosk["recommendation"] == "Strongest non-jailbreak approximation."


def test_jailbroken_jarvisos_true_goal_but_blocked():
    jailbroken = next(level for level in get_takeover_levels() if level["id"] == "jailbroken_jarvisos")
    assert jailbroken["final_identity"] == "true goal"
    assert jailbroken["can_be_built_now"] is False
    assert "A12 is not checkm8" in jailbroken["blocked"]


def test_true_ownership_requirements_classify_system_features_jailbreak_only():
    requirements = {item["id"]: item for item in get_true_ownership_requirements()}
    assert requirements["springboard_hooks"]["classification"] == "possible through jailbreak only"
    assert requirements["global_button_remap"]["classification"] == "possible through jailbreak only"
    assert requirements["controls_lock_experience"]["classification"] == "possible through jailbreak only"


def test_native_hardware_requirements_possible_through_native_app():
    requirements = {item["id"]: item for item in get_true_ownership_requirements()}
    assert requirements["camera_mic_sensors_storage"]["classification"] == "possible through native app"
    assert requirements["voice_identity"]["classification"] == "possible through native app"


def test_appliance_mode_steps_exist():
    steps = list_appliance_mode_steps()
    assert len(steps) >= 10
    assert any("Single App Mode" in step for step in steps)


def test_app_orchestration_marked_secondary():
    explanation = explain_why_not_just_an_app()
    assert explanation["app_orchestration"] == "secondary utility only"
    assert explanation["spotify_search"] == "optional modules only"


def test_recommended_path_prefers_appliance_not_app_control():
    path = get_recommended_takeover_path()
    assert path["current_xr_can_meet_true_ownership_now"] is False
    assert path["best_non_jailbreak_approximation"] == "managed_jarvis_appliance"
    assert "Do not build more app-control features" in path["stop_rule"]


def test_true_ownership_blockers_include_stock_ios_and_no_jailbreak():
    blockers = explain_what_blocks_true_ownership()
    assert "stock iOS sandbox" in blockers["blocked_by"]
    assert "no verified XR iOS 18.7.9 jailbreak in this repo" in blockers["blocked_by"]


def test_jailbreak_only_features_list():
    features = {item["feature"] for item in list_jailbreak_only_features()}
    assert "SpringBoard hooks" in features
    assert "global button remap" in features


def test_supervision_features_list():
    features = {item["feature"] for item in list_supervision_features()}
    assert "Single App Mode" in features
    assert "app allow lists" in features
