from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class DeviceProfile:
    model: str
    ios_version: str
    chip: str
    architecture: str
    screen_class: str
    primary_path: str
    jailbreak_status: str
    supervised_mode: str
    single_app_mode: str
    guided_access: str
    shortcuts_app_intents: str
    no_sim: bool
    cellular_dependence: str
    wifi_dependence: str
    offline_first: bool
    spotify_installed: bool
    browser_search_desired: bool
    springboard_hooks: str
    launchd_daemon: str
    system_wide_button_remap: str
    native_camera_mic_sensor_core_ml_path: str
    active_target: str = ""
    desired_identity: str = ""
    true_ownership: str = ""
    best_current_approximation: str = ""
    app_orchestration: str = ""
    spotify_web_search: str = ""
    next_decision: str = ""
    notes: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "model": self.model,
            "ios_version": self.ios_version,
            "chip": self.chip,
            "architecture": self.architecture,
            "screen_class": self.screen_class,
            "primary_path": self.primary_path,
            "jailbreak_status": self.jailbreak_status,
            "supervised_mode": self.supervised_mode,
            "single_app_mode": self.single_app_mode,
            "guided_access": self.guided_access,
            "shortcuts_app_intents": self.shortcuts_app_intents,
            "no_sim": self.no_sim,
            "cellular_dependence": self.cellular_dependence,
            "wifi_dependence": self.wifi_dependence,
            "offline_first": self.offline_first,
            "spotify_installed": self.spotify_installed,
            "browser_search_desired": self.browser_search_desired,
            "springboard_hooks": self.springboard_hooks,
            "launchd_daemon": self.launchd_daemon,
            "system_wide_button_remap": self.system_wide_button_remap,
            "native_camera_mic_sensor_core_ml_path": self.native_camera_mic_sensor_core_ml_path,
            "active_target": self.active_target,
            "desired_identity": self.desired_identity,
            "true_ownership": self.true_ownership,
            "best_current_approximation": self.best_current_approximation,
            "app_orchestration": self.app_orchestration,
            "spotify_web_search": self.spotify_web_search,
            "next_decision": self.next_decision,
            "notes": list(self.notes),
        }

    def validate(self) -> list[str]:
        errors: list[str] = []
        for key, value in self.to_dict().items():
            if key == "notes":
                if not isinstance(value, list):
                    errors.append("notes must be a list")
            elif key in {"active_target", "desired_identity", "true_ownership", "best_current_approximation", "app_orchestration", "spotify_web_search", "next_decision"} and value == "":
                continue
            elif isinstance(value, str) and not value:
                errors.append(f"{key} must not be empty")
        if not isinstance(self.no_sim, bool):
            errors.append("no_sim must be boolean")
        if not isinstance(self.offline_first, bool):
            errors.append("offline_first must be boolean")
        if not isinstance(self.spotify_installed, bool):
            errors.append("spotify_installed must be boolean")
        if not isinstance(self.browser_search_desired, bool):
            errors.append("browser_search_desired must be boolean")
        return errors


def compare_profiles(left: DeviceProfile, right: DeviceProfile) -> dict:
    left_data = left.to_dict()
    right_data = right.to_dict()
    differences = {}
    for key in sorted(set(left_data) | set(right_data)):
        if left_data.get(key) != right_data.get(key):
            differences[key] = {"active": left_data.get(key), "comparison": right_data.get(key)}
    return {
        "active_model": left.model,
        "comparison_model": right.model,
        "differences": differences,
        "summary": [
            "The active target is now iPhone XR.",
            "The iPhone 6 jailbreak lane is preserved but no longer primary.",
            "XR Device Mode uses native iOS ownership controls before jailbreak support.",
        ],
    }
