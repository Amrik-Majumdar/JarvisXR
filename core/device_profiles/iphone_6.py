from __future__ import annotations

from .device_profile import DeviceProfile


def iphone_6_profile() -> DeviceProfile:
    return DeviceProfile(
        model="iPhone 6",
        ios_version="unknown",
        chip="A8",
        architecture="arm64",
        screen_class="iPhone 6",
        primary_path="jailbreak-first Jarvis shell lane",
        jailbreak_status="blocked until exact iOS version and jailbreak path are known",
        supervised_mode="not primary in v0.1 to v0.4 plan",
        single_app_mode="not primary in v0.1 to v0.4 plan",
        guided_access="fallback only",
        shortcuts_app_intents="limited by old iOS target",
        no_sim=True,
        cellular_dependence="none",
        wifi_dependence="optional online enhancement only",
        offline_first=True,
        spotify_installed=False,
        browser_search_desired=False,
        springboard_hooks="planned only after jailbreak",
        launchd_daemon="planned only after jailbreak",
        system_wide_button_remap="planned only after jailbreak and device tests",
        native_camera_mic_sensor_core_ml_path="possible but constrained by older hardware and iOS target",
        notes=[
            "This profile is preserved for the future jailbreak lane.",
            "It is no longer the active product target.",
        ],
    )
