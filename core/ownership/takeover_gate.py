from __future__ import annotations


TAKEOVER_LEVELS = [
    {
        "level": 0,
        "id": "normal_app",
        "name": "Normal App",
        "final_identity": "rejected",
        "jarvis_controls": ["its own app process", "its own UI", "allowed app permissions"],
        "ios_still_controls": ["Home Screen", "lock screen", "app switching", "system buttons", "background policy"],
        "feels_like_jarvis_is_phone": False,
        "offline_viability": "good inside the app only",
        "spotify_browser": "external apps can exist, but this drifts into app orchestration",
        "requirements": ["installable native app"],
        "can_be_built_now": True,
        "blocked": ["device identity", "system ownership", "cannot prevent casual exit"],
        "recommendation": "Rejected as the main project. Useful only as a test harness.",
    },
    {
        "level": 1,
        "id": "native_jarvis_shell",
        "name": "Native Jarvis Shell",
        "final_identity": "rejected",
        "jarvis_controls": ["full-screen Jarvis interface", "camera tools", "voice tools", "local memory", "sensor panels"],
        "ios_still_controls": ["Home Screen", "lock screen", "app switching", "system buttons", "permissions"],
        "feels_like_jarvis_is_phone": "partial while foreground",
        "offline_viability": "strong for local tools while foreground",
        "spotify_browser": "optional modules only",
        "requirements": ["native iOS build path", "device permissions"],
        "can_be_built_now": "buildable after native toolchain decision",
        "blocked": ["true home ownership", "lock ownership", "background identity"],
        "recommendation": "Useful foundation, but rejected as final identity because it remains an app.",
    },
    {
        "level": 2,
        "id": "restricted_jarvis_device",
        "name": "Restricted Jarvis Device",
        "final_identity": "approximation",
        "jarvis_controls": ["visible device purpose", "reduced clutter", "offline Jarvis tools"],
        "ios_still_controls": ["Home Screen mechanics", "lock screen", "system buttons", "app escape paths"],
        "feels_like_jarvis_is_phone": "moderate if disciplined",
        "offline_viability": "strong",
        "spotify_browser": "allowed as optional modules, not identity",
        "requirements": ["delete apps", "Screen Time", "Focus", "Home Screen cleanup", "no SIM"],
        "can_be_built_now": True,
        "blocked": ["cannot enforce single purpose against a user who exits"],
        "recommendation": "Good immediate preparation, not enough for true takeover.",
    },
    {
        "level": 3,
        "id": "supervised_jarvis_kiosk",
        "name": "Supervised Jarvis Kiosk",
        "final_identity": "best non-jailbreak hard lock",
        "jarvis_controls": ["foreground device experience", "offline Jarvis shell", "single visible app surface"],
        "ios_still_controls": ["kernel", "secure boot", "system UI under the lock", "permission framework"],
        "feels_like_jarvis_is_phone": "strong while locked",
        "offline_viability": "strong",
        "spotify_browser": "constrained because external app escape conflicts with kiosk mode",
        "requirements": ["supervision or Guided Access", "native Jarvis shell", "setup and recovery plan"],
        "can_be_built_now": "yes if supervision or Guided Access setup exists",
        "blocked": ["SpringBoard hooks", "lock screen hooks", "global button remaps"],
        "recommendation": "Strongest non-jailbreak approximation.",
    },
    {
        "level": 4,
        "id": "managed_jarvis_appliance",
        "name": "Managed Jarvis Appliance",
        "final_identity": "best current non-jailbreak target",
        "jarvis_controls": ["dedicated appliance behavior", "app allow list", "restrictions", "automatic relaunch where allowed", "offline tools"],
        "ios_still_controls": ["SpringBoard internals", "lock screen internals", "secure boot", "rootless stock system"],
        "feels_like_jarvis_is_phone": "very close for practical use",
        "offline_viability": "strong",
        "spotify_browser": "optional and restricted, not the identity",
        "requirements": ["supervision", "configuration profiles or MDM-style controls", "native Jarvis shell", "recovery profile"],
        "can_be_built_now": "yes only if supervision tooling exists",
        "blocked": ["SpringBoard hooks", "true daemon", "arbitrary app inspection"],
        "recommendation": "Recommended non-jailbreak path if the user chooses not to wait.",
    },
    {
        "level": 5,
        "id": "jailbroken_jarvisos",
        "name": "Jailbroken JarvisOS",
        "final_identity": "true goal",
        "jarvis_controls": ["SpringBoard hooks", "lock screen hooks", "daemon", "button remaps where possible", "system UI control where tested"],
        "ios_still_controls": ["secure boot chain", "hardware firmware", "SEP", "baseband absence because no SIM"],
        "feels_like_jarvis_is_phone": True,
        "offline_viability": "strongest",
        "spotify_browser": "can be integrated as secondary flows if hooks and policies allow",
        "requirements": ["verified XR iOS 18.7.9 jailbreak", "Theos or equivalent toolchain", "device tests", "safe rollback"],
        "can_be_built_now": False,
        "blocked": ["no verified jailbreak route in this repo", "A12 is not checkm8", "iOS 18.7.9 iPhone jailbreak not verified"],
        "recommendation": "Preserve lane. Do not build as claimed capability until verified.",
    },
    {
        "level": 6,
        "id": "firmware_replacement",
        "name": "Firmware Or Custom OS Replacement",
        "final_identity": "impractical",
        "jarvis_controls": ["not practically available"],
        "ios_still_controls": ["Apple secure boot", "signing chain", "hardware bring-up", "SEP"],
        "feels_like_jarvis_is_phone": "theoretical only",
        "offline_viability": "not relevant",
        "spotify_browser": "not relevant",
        "requirements": ["custom signed firmware or broken secure boot chain"],
        "can_be_built_now": False,
        "blocked": ["Apple secure boot and firmware signing make this effectively not practical"],
        "recommendation": "Do not pursue for iPhone XR.",
    },
]


TRUE_OWNERSHIP_REQUIREMENTS = [
    ("starts_automatically", "Starts automatically", "possible through supervision"),
    ("cannot_be_casually_exited", "Cannot be casually exited", "possible through supervision"),
    ("controls_home_experience", "Controls home experience", "possible through supervision"),
    ("controls_lock_experience", "Controls lock experience", "possible through jailbreak only"),
    ("camera_mic_sensors_storage", "Handles camera, mic, sensors, storage, and memory", "possible through native app"),
    ("voice_identity", "Has voice identity", "possible through native app"),
    ("local_tools", "Has local tools", "possible now"),
    ("offline_brain", "Has offline brain", "possible now"),
    ("open_or_replace_core_flows", "Can open or replace core flows", "possible through supervision"),
    ("survive_reboot_or_relaunch", "Can survive reboot or relaunch", "possible through supervision"),
    ("recover_safely", "Can recover safely", "possible through supervision"),
    ("uninstall_recovery_path", "Has uninstall and recovery path", "possible through supervision"),
    ("permission_safety_policy", "Has permission and safety policy", "possible now"),
    ("optional_other_app_control", "Optionally controls other apps", "possible through jailbreak only"),
    ("springboard_hooks", "Controls SpringBoard hooks", "possible through jailbreak only"),
    ("global_button_remap", "Controls global button remaps", "possible through jailbreak only"),
    ("firmware_replacement", "Replaces Apple firmware", "impossible or not practical"),
]


APPLIANCE_MODE_STEPS = [
    "Decide whether the device can be erased.",
    "Keep no SIM and no cellular dependence.",
    "Remove unnecessary apps.",
    "Disable unnecessary notifications.",
    "Configure Focus for Jarvis use.",
    "Configure Screen Time restrictions.",
    "Reduce Home Screen to Jarvis purpose only.",
    "Prepare the native Jarvis shell as the only visible experience.",
    "Use supervised Single App Mode if Apple Configurator or MDM-style setup is available.",
    "Use Guided Access as fallback if supervision is unavailable.",
    "Keep offline voice, camera, sensor, memory, and utility tools central.",
    "Keep Spotify and search as optional modules, not identity.",
    "Document recovery and exit procedure before locking down.",
]


def get_takeover_levels() -> list[dict]:
    return [dict(level) for level in TAKEOVER_LEVELS]


def get_true_ownership_requirements() -> list[dict]:
    return [{"id": item[0], "requirement": item[1], "classification": item[2]} for item in TRUE_OWNERSHIP_REQUIREMENTS]


def get_recommended_takeover_path() -> dict:
    return {
        "current_xr_can_meet_true_ownership_now": False,
        "best_non_jailbreak_approximation": "managed_jarvis_appliance",
        "true_goal": "jailbroken_jarvisos",
        "decision": "Choose managed appliance mode now, wait for a verified jailbreak, or change hardware/iOS target.",
        "stop_rule": "Do not build more app-control features until this decision is made.",
    }


def explain_why_not_just_an_app() -> dict:
    return {
        "reason": "A normal app cannot own the Home Screen, lock screen, system buttons, reboot behavior, SpringBoard, or background identity.",
        "project_position": "Normal app and native shell are useful foundations but rejected as final identity.",
        "app_orchestration": "secondary utility only",
        "spotify_search": "optional modules only",
    }


def explain_what_blocks_true_ownership() -> dict:
    return {
        "blocked_by": [
            "stock iOS sandbox",
            "SpringBoard ownership",
            "lock screen ownership",
            "background execution limits",
            "secure boot and firmware signing",
            "no verified XR iOS 18.7.9 jailbreak in this repo",
        ],
        "jailbreak_reality": "A12 iPhone XR is not supported by checkm8 class routes.",
    }


def list_jailbreak_only_features() -> list[dict]:
    features = ["SpringBoard hooks", "lock screen hooks", "root daemon", "global button remap", "system UI control", "arbitrary app inspection where possible"]
    return [{"feature": feature, "classification": "possible through jailbreak only"} for feature in features]


def list_supervision_features() -> list[dict]:
    features = ["Single App Mode", "configuration profiles", "app allow lists", "restrictions", "automatic relaunch where possible", "cannot be casually exited"]
    return [{"feature": feature, "classification": "possible through supervision"} for feature in features]


def list_appliance_mode_steps() -> list[str]:
    return list(APPLIANCE_MODE_STEPS)
