from __future__ import annotations

from core.adapters.adapter_registry import AdapterRegistry
from core.router.phone_state import MockPhoneState


def assert_result_shape(result):
    payload = result.to_dict()
    assert set(payload) == {"status", "data", "error", "latency_ms", "source"}
    assert isinstance(payload["data"], dict)
    assert isinstance(payload["latency_ms"], float)
    assert payload["source"]


def test_adapter_registry_initializes_all_mocks():
    registry = AdapterRegistry.mock_for_phone(MockPhoneState().snapshot())
    assert registry.names() == [
        "battery",
        "camera",
        "dock",
        "flashlight",
        "location",
        "microphone",
        "network",
        "ocr",
        "sensor",
        "speaker",
        "storage",
        "stt",
        "tts",
        "vision",
    ]


def test_camera_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("camera").capture_frame())


def test_microphone_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("microphone").start_push_to_talk())


def test_speaker_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("speaker").play_spoken_response("test"))


def test_tts_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("tts").synthesize("test"))


def test_stt_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("stt").transcribe_last_clip())


def test_vision_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("vision").detect_objects())


def test_ocr_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("ocr").read_text())


def test_sensor_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("sensor").snapshot())


def test_location_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("location").current_location())


def test_flashlight_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("flashlight").set_enabled(True))


def test_storage_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("storage").status())


def test_battery_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState().snapshot()).get("battery").status())


def test_network_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState("online").snapshot()).get("network").status())


def test_dock_adapter_result_shape():
    assert_result_shape(AdapterRegistry.mock_for_phone(MockPhoneState("dock").snapshot()).get("dock").sync_logs())


def test_unavailable_camera_adapter():
    result = AdapterRegistry.mock_for_phone(MockPhoneState("camera_unavailable").snapshot()).get("camera").capture_frame()
    assert result.status == "unavailable"
    assert result.error


def test_unavailable_microphone_adapter():
    result = AdapterRegistry.mock_for_phone(MockPhoneState("microphone_unavailable").snapshot()).get("microphone").start_push_to_talk()
    assert result.status == "unavailable"
    assert result.error


def test_private_network_adapter_refuses():
    result = AdapterRegistry.mock_for_phone(MockPhoneState("private").snapshot()).get("network").status()
    assert result.status == "refused"
    assert "privacy" in result.error
