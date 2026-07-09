from __future__ import annotations


FINAL_RECOMMENDATION = {
    "release_name": "v0.7 Final XR Appliance Deployment Kit",
    "target": "iPhone XR on iOS 18.7.9",
    "final_current_recommendation": "do not jailbreak this XR right now",
    "chosen_path": "Managed Jarvis Appliance Mode",
    "strongest_path_if_mac_exists": "supervised Single App Mode with Apple Configurator or MDM-style setup",
    "immediate_fallback": "Guided Access",
    "feature_freeze": "No more feature-building prompts until physical setup is attempted.",
    "true_ownership_status": "blocked without a verified jailbreak",
    "what_remains_impossible_without_jailbreak": [
        "SpringBoard hooks",
        "lock screen hooks",
        "launchd daemon install",
        "root access",
        "global button remap",
        "arbitrary app control",
        "true OS ownership",
    ],
}


XR_SETUP_STEPS = {
    "before_touching_phone": [
        "Confirm the device is iPhone XR.",
        "Confirm iOS version is 18.7.9.",
        "Do not update iOS.",
        "Do not attempt random jailbreak tools.",
        "Decide whether to erase/reset or keep existing data.",
        "Note whether a Mac is available.",
    ],
    "strip_down": [
        "Remove SIM if present.",
        "Delete unnecessary apps.",
        "Remove Home Screen clutter.",
        "Disable unnecessary notifications.",
        "Disable background distractions.",
        "Configure Focus.",
        "Configure Screen Time restrictions.",
        "Lock or hide unnecessary apps where iOS allows.",
        "Leave only what supports Jarvis setup.",
    ],
    "identity_layer": [
        "Set phone name toward Jarvis identity.",
        "Use restrained Jarvis wallpaper direction.",
        "Use app layout that makes Jarvis the visible purpose.",
        "Use icon and naming direction that feels like an instrument, not a toy.",
        "Make lock screen visual direction match Jarvis identity without claiming lock-screen control.",
    ],
    "guided_access": [
        "Enable Guided Access.",
        "Set passcode or Face ID exit.",
        "Open Jarvis shell when available.",
        "Triple-click side button to lock into Jarvis.",
        "Remember Guided Access cannot provide SpringBoard hooks, root access, or true OS ownership.",
    ],
    "supervised_single_app_mode": [
        "Requires Mac and Apple Configurator or MDM-style setup.",
        "Supervised mode is stronger than Guided Access.",
        "Selected Jarvis app becomes the visible device experience.",
        "This cannot be done from Windows alone.",
        "Use checklist and recovery plan, not fake commands.",
    ],
    "restricted_home_screen_fallback": [
        "Use when there is no Mac and no jailbreak.",
        "Keep the XR Jarvis-first through restrictions and layout.",
        "Do not treat external apps as identity.",
    ],
    "recovery": [
        "Write down Guided Access passcode before setup.",
        "Confirm Face ID exit if used.",
        "Do not lock yourself out.",
        "Test exit procedure before relying on lockdown.",
        "Stop if the exit path is unclear.",
    ],
}


DO_NOT_JAILBREAK_WARNING = {
    "warning": "Do not jailbreak this XR on iOS 18.7.9 right now.",
    "device": "iPhone XR",
    "chip": "A12",
    "architecture": "arm64e",
    "ios_version": "18.7.9",
    "unverified_tool_warning": "Unverified tools must not be used because no verified XR iOS 18.7.9 jailbreak is present in the checked sources.",
    "does_not_apply": ["checkm8", "palera1n-style A8 to A11 routes"],
    "avoid": [
        "YouTube jailbreaks",
        "paid unlockers",
        "survey jailbreaks",
        "browser jailbreaks",
        "fake Cydia installers",
        "one click jailbreak claims",
    ],
    "trusted_sources_required": [
        "official jailbreak project site",
        "respected jailbreak wiki",
        "reproducible GitHub release",
        "known developer announcement",
        "broad community validation",
    ],
    "future_rule": "If a jailbreak appears later, create a new feasibility pass before installing anything.",
}


APPLIANCE_MODE_PLAN = {
    "status": "final practical path for this XR now",
    "required_before_real_use": [
        "native Jarvis shell",
        "camera inspection",
        "voice command interface",
        "local memory",
        "offline utilities",
        "sensor tools",
        "local TTS",
        "local or limited STT",
        "Core ML and Vision modules later",
        "Guided Access setup",
        "Single App Mode setup if Mac exists",
    ],
    "limits": [
        "This repo does not currently produce an installable iOS app.",
        "Building and installing the native shell requires a real iOS build path.",
        "Likely options are Mac/Xcode with free signing or another legitimate signing path.",
        "Windows alone cannot fully build and install a native iOS app.",
    ],
}


NATIVE_BUILD_DECISION_TREE = {
    "mac_xcode_available": {
        "can_do": ["build native iOS shell", "use free signing for development install", "test on XR"],
        "cannot_do": ["claim jailbreak hooks", "install launchd daemon on stock iOS"],
        "guided_access": True,
        "single_app_mode": "possible if Apple Configurator or supervision path is also available",
        "native_app_install_realistic": True,
        "pause": False,
    },
    "mac_xcode_not_available": {
        "can_do": ["prepare docs", "run Python harness", "prepare design and contracts"],
        "cannot_do": ["fully build and install native iOS app from Windows alone"],
        "guided_access": "available once an app exists on the phone",
        "single_app_mode": False,
        "native_app_install_realistic": False,
        "pause": True,
    },
    "apple_configurator_available": {
        "can_do": ["supervise device", "prepare Single App Mode route", "make stronger appliance behavior"],
        "cannot_do": ["replace iOS", "create SpringBoard hooks"],
        "guided_access": True,
        "single_app_mode": True,
        "native_app_install_realistic": "requires app build/signing path too",
        "pause": False,
    },
    "only_windows_and_raspberry_pi_available": {
        "can_do": ["run Jarvis Core tests", "maintain repo", "prepare assets", "use restricted Home Screen fallback"],
        "cannot_do": ["fully build and install native iOS app", "supervise via Apple Configurator from Windows alone"],
        "guided_access": "only useful once Jarvis shell is installed",
        "single_app_mode": False,
        "native_app_install_realistic": False,
        "pause": True,
    },
}


def get_final_recommendation() -> dict:
    return dict(FINAL_RECOMMENDATION)


def get_xr_setup_steps() -> dict:
    return {key: list(value) for key, value in XR_SETUP_STEPS.items()}


def get_do_not_jailbreak_warning() -> dict:
    return {key: list(value) if isinstance(value, list) else value for key, value in DO_NOT_JAILBREAK_WARNING.items()}


def get_appliance_mode_plan() -> dict:
    return {key: list(value) if isinstance(value, list) else value for key, value in APPLIANCE_MODE_PLAN.items()}


def get_native_build_decision_tree() -> dict:
    return {key: dict(value) for key, value in NATIVE_BUILD_DECISION_TREE.items()}
