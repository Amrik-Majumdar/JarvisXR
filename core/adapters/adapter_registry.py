from __future__ import annotations

from core.router.phone_state import MockPhoneState

from .battery_adapter import MockBatteryAdapter
from .camera_adapter import MockCameraAdapter
from .dock_adapter import MockDockAdapter
from .flashlight_adapter import MockFlashlightAdapter
from .location_adapter import MockLocationAdapter
from .microphone_adapter import MockMicrophoneAdapter
from .network_adapter import MockNetworkAdapter
from .ocr_adapter import MockOCRAdapter
from .sensor_adapter import MockSensorAdapter
from .speaker_adapter import MockSpeakerAdapter
from .storage_adapter import MockStorageAdapter
from .stt_adapter import MockSTTAdapter
from .tts_adapter import MockTTSAdapter
from .vision_adapter import MockVisionAdapter


class AdapterRegistry:
    def __init__(self, adapters: dict | None = None):
        self.adapters = adapters or {}

    @classmethod
    def mock_for_phone(cls, phone_state: dict) -> "AdapterRegistry":
        return cls(
            {
                "battery": MockBatteryAdapter(phone_state.get("battery", {}).get("level_percent", 72)),
                "camera": MockCameraAdapter(bool(phone_state.get("camera", {}).get("available", True))),
                "dock": MockDockAdapter(bool(phone_state.get("network", {}).get("dock", False))),
                "flashlight": MockFlashlightAdapter(),
                "location": MockLocationAdapter(bool(phone_state.get("sensors", {}).get("gps", {}).get("available", True))),
                "microphone": MockMicrophoneAdapter(bool(phone_state.get("microphone", {}).get("available", True))),
                "network": MockNetworkAdapter(bool(phone_state.get("network", {}).get("online", False)), bool(phone_state.get("privacy", {}).get("private_mode", False))),
                "ocr": MockOCRAdapter(),
                "sensor": MockSensorAdapter(bool(phone_state.get("sensors", {}).get("available", True))),
                "speaker": MockSpeakerAdapter(),
                "storage": MockStorageAdapter(float(phone_state.get("storage", {}).get("free_gb", 5.4))),
                "stt": MockSTTAdapter(),
                "tts": MockTTSAdapter(),
                "vision": MockVisionAdapter(),
            }
        )

    @classmethod
    def future_native_bridge(cls) -> "AdapterRegistry":
        return cls({})

    @classmethod
    def future_dock_bridge(cls) -> "AdapterRegistry":
        return cls({})

    def get(self, name: str):
        return self.adapters[name]

    def names(self) -> list[str]:
        return sorted(self.adapters)

    def refresh_from_phone(self, phone: MockPhoneState) -> None:
        self.adapters = self.mock_for_phone(phone.snapshot()).adapters
