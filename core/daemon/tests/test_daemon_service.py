from __future__ import annotations

import time
from pathlib import Path

from core.daemon.jarvis_service import JarvisService
from core.daemon.protocol import load_schema, validate_handler_result, validate_request, validate_response
from core.router.handlers import HANDLERS
from core.router.local_memory import LocalMemory
from core.router.phone_state import MockPhoneState


ROOT = Path(__file__).resolve().parents[3]


def service(tmp_path) -> JarvisService:
    return JarvisService(memory_path=tmp_path / "memory.sqlite")


def request(kind: str, request_id: str = "r1", **extra) -> dict:
    payload = {"type": kind, "request_id": request_id}
    payload.update(extra)
    return payload


def test_request_schemas_load():
    assert load_schema("jarvis_request.schema.json")["title"] == "Jarvis Daemon Request"
    assert load_schema("jarvis_response.schema.json")["title"] == "Jarvis Daemon Response"


def test_request_validation_accepts_health_check():
    assert validate_request(request("health_check")) == []


def test_request_validation_rejects_unknown_type():
    assert validate_request(request("bad_type")) != []


def test_response_validation_accepts_health_check(tmp_path):
    response = service(tmp_path).handle(request("health_check"))
    assert validate_response(response) == []


def test_daemon_health_check(tmp_path):
    response = service(tmp_path).handle(request("health_check"))
    assert response["status"] == "ok"
    assert response["request_id"] == "r1"


def test_route_command(tmp_path):
    response = service(tmp_path).handle(request("route_command", command="scan this"))
    assert response["status"] == "ok"
    assert response["data"]["route"]["capability"]["id"] == "camera_inspection_001"


def test_execute_command(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="scan this"))
    assert response["status"] == "ok"
    assert response["spoken_response"] == "Inspection frame ready."


def test_list_offline_capabilities(tmp_path):
    response = service(tmp_path).handle(request("list_offline_capabilities"))
    assert response["status"] == "ok"
    assert len(response["data"]["capabilities"]) >= 300


def test_related_capabilities(tmp_path):
    response = service(tmp_path).handle(request("list_related_capabilities", topic="camera"))
    assert response["status"] == "ok"
    assert response["data"]["capabilities"]


def test_mock_state_update(tmp_path):
    svc = service(tmp_path)
    response = svc.handle(request("update_mock_phone_state", profile="camera_unavailable"))
    assert response["status"] == "ok"
    assert response["data"]["phone_state"]["camera"]["available"] is False


def test_hardware_refusal(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="camera_unavailable"))
    response = svc.handle(request("execute_command", command="scan this"))
    assert response["status"] == "unavailable"
    assert "camera" in response["unavailable_reason"]


def test_online_refusal(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="search current weather online"))
    assert response["status"] == "unavailable"
    assert "online" in response["unavailable_reason"].lower()


def test_dock_refusal(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="sync logs to raspberry pi"))
    assert response["status"] == "unavailable"
    assert "dock" in response["unavailable_reason"].lower()


def test_privacy_mode_blocks_online(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="online"))
    svc.state.phone.set_flag("private", True)
    svc.router.update_phone_state(svc.state.phone.snapshot())
    response = svc.handle(request("execute_command", command="search current weather online"))
    assert response["status"] == "unavailable"
    assert "private mode" in response["unavailable_reason"]


def test_confirmation_token_creation(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="clear test data with confirmation"))
    assert response["status"] == "confirmation_required"
    assert response["data"]["handler_data"]["confirmation_token"]


def test_confirmation_token_execution(tmp_path):
    svc = service(tmp_path)
    first = svc.handle(request("execute_command", "c1", command="clear test data with confirmation"))
    token = first["data"]["handler_data"]["confirmation_token"]
    second = svc.handle(request("confirm_and_execute", "c2", confirmation_token=token))
    assert second["status"] == "ok"


def test_missing_confirmation_token_refused(tmp_path):
    response = service(tmp_path).handle(request("confirm_and_execute", confirmation_token=""))
    assert response["status"] == "refused"


def test_invalid_confirmation_token_refused(tmp_path):
    response = service(tmp_path).handle(request("confirm_and_execute", confirmation_token="not-real"))
    assert response["status"] == "refused"


def test_stale_confirmation_token_refused(tmp_path):
    svc = service(tmp_path)
    first = svc.handle(request("execute_command", "c1", command="clear test data with confirmation"))
    token = first["data"]["handler_data"]["confirmation_token"]
    svc.state.confirmations.tokens[token]["expires_at"] = time.time() - 1
    second = svc.handle(request("confirm_and_execute", "c2", confirmation_token=token))
    assert second["status"] == "refused"


def test_dock_restore_style_confirmation(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="dock"))
    first = svc.handle(request("execute_command", command="restore from pi"))
    assert first["status"] == "confirmation_required"
    assert first["data"]["handler_data"]["confirmation_token"]


def test_set_mode_online_requires_online(tmp_path):
    response = service(tmp_path).handle(request("set_mode", mode="online"))
    assert response["status"] == "refused"


def test_set_mode_online_when_online(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="online"))
    response = svc.handle(request("set_mode", mode="online"))
    assert response["status"] == "ok"


def test_set_mode_dock_requires_dock(tmp_path):
    response = service(tmp_path).handle(request("set_mode", mode="dock"))
    assert response["status"] == "refused"


def test_set_mode_dock_when_docked(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="dock"))
    response = svc.handle(request("set_mode", mode="dock"))
    assert response["status"] == "ok"


def test_set_mode_inspection_camera_unavailable(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="camera_unavailable"))
    response = svc.handle(request("set_mode", mode="inspection"))
    assert response["status"] == "refused"


def test_set_mode_sensor_unavailable(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="sensors_unavailable"))
    response = svc.handle(request("set_mode", mode="sensor"))
    assert response["status"] == "refused"


def test_low_battery_prefers_safe_modes(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="low_battery"))
    response = svc.handle(request("set_mode", mode="field"))
    assert response["status"] == "refused"


def test_save_and_search_memory(tmp_path):
    svc = service(tmp_path)
    save = svc.handle(request("save_note", text="blue valve by pump"))
    assert save["status"] == "ok"
    search = svc.handle(request("search_memory", query="blue valve"))
    assert len(search["data"]["results"]) == 1


def test_export_memory_summary(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("save_note", text="summary note"))
    response = svc.handle(request("export_memory_summary"))
    assert response["data"]["summary"]["counts"]["note"] == 1


def test_recent_history(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("save_note", text="history note"))
    response = svc.handle(request("get_recent_history"))
    assert response["data"]["history"]


def test_all_registered_handlers_return_valid_shape(tmp_path):
    memory = LocalMemory(tmp_path / "memory.sqlite")
    phone = MockPhoneState("dock")
    capabilities = []
    import json

    with (ROOT / "core" / "registry" / "capabilities.json").open("r", encoding="utf-8") as handle:
        capabilities = json.load(handle)["capabilities"]
    by_id = {cap["id"]: cap for cap in capabilities}
    from core.router.handlers import execute_handler
    from core.adapters import AdapterRegistry

    for cap_id in HANDLERS:
        cap = by_id[cap_id]
        snapshot = phone.snapshot()
        result = execute_handler(
            {
                "command": cap["example_voice_phrases"][0],
                "argument": "handler shape test",
                "capability": cap,
                "capabilities": capabilities,
                "phone_state": snapshot,
                "memory": memory,
                "adapters": AdapterRegistry.mock_for_phone(snapshot),
                "confirmed": True,
                "confirmation_token": None,
            }
        )
        assert validate_handler_result(result) == []


def test_generated_model_files_exist():
    generated = ROOT / "native" / "ios" / "JarvisShell" / "generated"
    expected = [
        "JVSCapability.h",
        "JVSCapability.m",
        "JVSCommandRequest.h",
        "JVSCommandRequest.m",
        "JVSCommandResponse.h",
        "JVSCommandResponse.m",
        "JVSPhoneState.h",
        "JVSPhoneState.m",
        "JVSMode.h",
        "JVSMode.m",
        "JVSConfirmation.h",
        "JVSConfirmation.m",
    ]
    # The generation command in run_all_tests creates these before pytest.
    for name in expected:
        assert (generated / name).exists()


def test_scan_command_uses_camera_adapter(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="scan this"))
    adapter = response["data"]["handler_data"]["adapter"]
    assert adapter["source"] == "mock_camera"
    assert adapter["latency_ms"] >= 0


def test_ocr_command_uses_ocr_adapter(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="read this label"))
    assert response["data"]["handler_data"]["adapter"]["source"] == "mock_ocr"


def test_object_detection_uses_vision_adapter(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="identify this object"))
    assert response["data"]["handler_data"]["adapter"]["source"] == "mock_vision"


def test_tts_command_uses_tts_and_speaker_adapters(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="read this back to me"))
    data = response["data"]["handler_data"]
    assert data["tts_adapter"]["source"] == "mock_tts"
    assert data["speaker_adapter"]["source"] == "mock_speaker"


def test_sensor_command_uses_sensor_adapter(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="measure this angle"))
    assert response["data"]["handler_data"]["adapter"]["source"] == "mock_sensor"


def test_battery_diagnostics_uses_battery_adapter(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="show battery diagnostics"))
    assert response["data"]["handler_data"]["adapter"]["source"] == "mock_battery"


def test_storage_diagnostics_uses_storage_adapter(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="show storage"))
    assert response["data"]["handler_data"]["adapter"]["source"] == "mock_storage"


def test_dock_command_uses_dock_adapter(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="dock"))
    response = svc.handle(request("execute_command", command="sync logs to raspberry pi"))
    assert response["data"]["handler_data"]["adapter"]["source"] == "mock_dock"


def test_start_privacy_blocks_online_afterward(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="online"))
    privacy = svc.handle(request("execute_command", command="start privacy mode"))
    assert privacy["status"] == "ok"
    online = svc.handle(request("execute_command", command="search current weather online"))
    assert online["status"] == "unavailable"
    assert "private mode" in online["unavailable_reason"]


def test_low_battery_profile_changes_battery_response(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="low_battery"))
    response = svc.handle(request("execute_command", command="show battery diagnostics"))
    assert "low" in response["spoken_response"].lower()


def test_camera_unavailable_profile_refuses_adapter_scan(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="camera_unavailable"))
    response = svc.handle(request("execute_command", command="scan this"))
    assert response["status"] == "unavailable"
    assert "camera" in response["unavailable_reason"]


def test_microphone_unavailable_profile_refuses_push_to_talk(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("update_mock_phone_state", profile="microphone_unavailable"))
    response = svc.handle(request("execute_command", command="start push to talk"))
    assert response["status"] == "unavailable"
    assert "microphone" in response["unavailable_reason"].lower()


def test_daemon_response_schema_after_adapter_execution(tmp_path):
    response = service(tmp_path).handle(request("execute_command", command="read this label"))
    assert validate_response(response) == []


def test_get_device_profile_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_device_profile"))
    assert response["status"] == "ok"
    assert response["data"]["device_profile"]["model"] == "iPhone XR"
    assert validate_response(response) == []


def test_compare_device_profiles_service_request(tmp_path):
    response = service(tmp_path).handle(request("compare_device_profiles"))
    assert response["status"] == "ok"
    assert response["data"]["comparison"]["active_model"] == "iPhone XR"
    assert response["data"]["comparison"]["comparison_model"] == "iPhone 6"


def test_get_device_mode_strategy_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_device_mode_strategy"))
    assert response["status"] == "ok"
    assert response["data"]["strategy"]["strategy"] == "Jarvis Device Mode"


def test_get_ownership_modes_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_ownership_modes"))
    ids = {mode["mode_id"] for mode in response["data"]["ownership_modes"]}
    assert "supervised_kiosk_mode" in ids
    assert "jailbroken_jarvisos_mode_blocked" in ids


def test_set_and_get_ownership_mode_service_request(tmp_path):
    svc = service(tmp_path)
    set_response = svc.handle(request("set_ownership_mode", mode="managed_appliance_mode"))
    assert set_response["status"] == "ok"
    get_response = svc.handle(request("get_current_ownership_mode"))
    assert get_response["data"]["ownership_mode"]["mode_id"] == "managed_appliance_mode"


def test_jailbreak_ownership_service_request_refuses(tmp_path):
    response = service(tmp_path).handle(request("set_ownership_mode", mode="jailbroken_jarvisos_mode_blocked"))
    assert response["status"] == "refused"
    assert response["data"]["ownership_mode"]["blocked_reasons"]


def test_blocked_ownership_features_service_request(tmp_path):
    svc = service(tmp_path)
    svc.handle(request("set_ownership_mode", mode="supervised_kiosk_mode"))
    response = svc.handle(request("list_blocked_ownership_features"))
    features = {item["feature"] for item in response["data"]["blocked_features"]}
    assert "external_app_handoff" in features


def test_spotify_strategy_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_spotify_strategy"))
    strategy = response["data"]["spotify_strategy"]
    assert strategy["installed"] is True
    assert strategy["hard_ownership_mode"]["external_spotify_open_allowed"] is False
    assert "unverified" in strategy["honesty_boundary"].lower()


def test_list_media_capabilities_service_request(tmp_path):
    response = service(tmp_path).handle(request("list_media_capabilities"))
    ids = {item["id"] for item in response["data"]["media_capabilities"]}
    assert "media_spotify_handoff" in ids
    assert "media_browser_search" in ids


def test_get_takeover_levels_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_takeover_levels"))
    assert response["status"] == "ok"
    assert len(response["data"]["takeover_levels"]) == 7


def test_get_true_ownership_requirements_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_true_ownership_requirements"))
    requirements = {item["id"]: item for item in response["data"]["requirements"]}
    assert requirements["springboard_hooks"]["classification"] == "possible through jailbreak only"


def test_get_recommended_takeover_path_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_recommended_takeover_path"))
    assert response["data"]["recommended_path"]["best_non_jailbreak_approximation"] == "managed_jarvis_appliance"


def test_explain_why_not_just_an_app_service_request(tmp_path):
    response = service(tmp_path).handle(request("explain_why_not_just_an_app"))
    assert response["data"]["explanation"]["app_orchestration"] == "secondary utility only"


def test_explain_what_blocks_true_ownership_service_request(tmp_path):
    response = service(tmp_path).handle(request("explain_what_blocks_true_ownership"))
    assert "no verified XR iOS 18.7.9 jailbreak in this repo" in response["data"]["blockers"]["blocked_by"]


def test_list_jailbreak_only_features_service_request(tmp_path):
    response = service(tmp_path).handle(request("list_jailbreak_only_features"))
    features = {item["feature"] for item in response["data"]["features"]}
    assert "lock screen hooks" in features


def test_list_supervision_features_service_request(tmp_path):
    response = service(tmp_path).handle(request("list_supervision_features"))
    features = {item["feature"] for item in response["data"]["features"]}
    assert "Single App Mode" in features


def test_list_appliance_mode_steps_service_request(tmp_path):
    response = service(tmp_path).handle(request("list_appliance_mode_steps"))
    assert response["status"] == "ok"
    assert any("Spotify and search" in step for step in response["data"]["steps"])


def test_get_final_recommendation_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_final_recommendation"))
    recommendation = response["data"]["final_recommendation"]
    assert recommendation["final_current_recommendation"] == "do not jailbreak this XR right now"
    assert recommendation["chosen_path"] == "Managed Jarvis Appliance Mode"


def test_get_xr_setup_steps_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_xr_setup_steps"))
    assert response["status"] == "ok"
    assert response["data"]["setup_steps"]["before_touching_phone"]


def test_get_do_not_jailbreak_warning_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_do_not_jailbreak_warning"))
    warning = response["data"]["warning"]
    assert warning["chip"] == "A12"
    assert warning["ios_version"] == "18.7.9"
    assert "unverified" in warning["unverified_tool_warning"].lower()


def test_get_appliance_mode_plan_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_appliance_mode_plan"))
    plan = response["data"]["appliance_mode_plan"]
    assert "native Jarvis shell" in plan["required_before_real_use"]


def test_get_native_build_decision_tree_service_request(tmp_path):
    response = service(tmp_path).handle(request("get_native_build_decision_tree"))
    tree = response["data"]["native_build_decision_tree"]
    assert "mac_xcode_available" in tree
    assert "apple_configurator_available" in tree
    assert "only_windows_and_raspberry_pi_available" in tree
