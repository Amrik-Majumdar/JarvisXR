from __future__ import annotations

from .device_profile import DeviceProfile


def iphone_xr_profile() -> DeviceProfile:
    return DeviceProfile(
        model="iPhone XR",
        ios_version="18.7.9",
        chip="A12 Bionic",
        architecture="arm64e",
        screen_class="XR",
        primary_path="Device Takeover Feasibility Gate",
        jailbreak_status="blocked pending verified support",
        supervised_mode="best non-jailbreak ownership path",
        single_app_mode="kiosk lockdown path",
        guided_access="fallback lockdown path",
        shortcuts_app_intents="integration bridge",
        no_sim=True,
        cellular_dependence="none",
        wifi_dependence="optional online enhancement only",
        offline_first=True,
        spotify_installed=True,
        browser_search_desired=True,
        springboard_hooks="blocked until jailbreak",
        launchd_daemon="blocked until jailbreak",
        system_wide_button_remap="blocked until jailbreak",
        native_camera_mic_sensor_core_ml_path="available through public APIs where allowed",
        active_target="iPhone XR",
        desired_identity="Jarvis is the phone",
        true_ownership="blocked without jailbreak",
        best_current_approximation="managed Jarvis appliance or supervised kiosk",
        app_orchestration="secondary utility, not core direction",
        spotify_web_search="optional modules, not identity",
        next_decision="verify jailbreak feasibility or commit to appliance mode",
        notes=[
            "Jarvis should be the device identity, not merely an app.",
            "Normal app mode and native shell mode are rejected as final identity.",
            "Managed appliance mode is the best non-jailbreak approximation.",
            "Jailbroken JarvisOS remains the true goal but is blocked until verified.",
        ],
    )
