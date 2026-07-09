from __future__ import annotations

from dataclasses import dataclass, field


@dataclass(frozen=True)
class OwnershipMode:
    mode_id: str
    name: str
    jarvis_controls: list[str]
    ios_still_controls: list[str]
    external_apps_can_open: bool
    spotify_can_open: bool
    browser_can_open: bool
    background_listening_possible: bool
    home_lock_system_buttons_controlled: bool
    offline_works: bool
    final_identity_status: str
    required_setup: list[str]
    blocked_reasons: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        return {
            "mode_id": self.mode_id,
            "name": self.name,
            "jarvis_controls": list(self.jarvis_controls),
            "ios_still_controls": list(self.ios_still_controls),
            "external_apps_can_open": self.external_apps_can_open,
            "spotify_can_open": self.spotify_can_open,
            "browser_can_open": self.browser_can_open,
            "background_listening_possible": self.background_listening_possible,
            "home_lock_system_buttons_controlled": self.home_lock_system_buttons_controlled,
            "offline_works": self.offline_works,
            "final_identity_status": self.final_identity_status,
            "required_setup": list(self.required_setup),
            "blocked_reasons": list(self.blocked_reasons),
        }


def _modes() -> dict[str, OwnershipMode]:
    return {
        "normal_app_mode": OwnershipMode(
            "normal_app_mode",
            "Normal App Mode",
            ["its own screen", "allowed permissions"],
            ["Home Screen", "lock screen", "system buttons", "app switching", "background policy"],
            True,
            True,
            True,
            False,
            False,
            True,
            "rejected as final identity",
            ["installable app"],
            ["Jarvis remains just an app"],
        ),
        "native_shell_mode": OwnershipMode(
            "native_shell_mode",
            "Native Jarvis Shell Mode",
            ["full-screen Jarvis interface", "offline tools", "camera and sensor panels", "local memory"],
            ["Home Screen", "lock screen", "system buttons", "foreground app limits"],
            True,
            True,
            True,
            False,
            False,
            True,
            "useful foundation but rejected as final identity",
            ["native iOS build path", "device permissions"],
        ),
        "restricted_device_mode": OwnershipMode(
            "restricted_device_mode",
            "Restricted Jarvis Device Mode",
            ["visible device purpose", "reduced clutter", "offline Jarvis tools"],
            ["Home Screen mechanics", "lock screen", "system buttons", "escape paths"],
            True,
            True,
            True,
            False,
            False,
            True,
            "partial approximation",
            ["delete apps", "Screen Time", "Focus", "Home Screen cleanup"],
        ),
        "supervised_kiosk_mode": OwnershipMode(
            "supervised_kiosk_mode",
            "Supervised Jarvis Kiosk Mode",
            ["foreground device experience", "single visible Jarvis surface", "offline Jarvis shell"],
            ["iOS kernel", "secure boot", "permission framework", "system internals"],
            False,
            False,
            False,
            False,
            False,
            True,
            "strongest non-jailbreak approximation",
            ["supervision or Guided Access", "native Jarvis shell", "recovery plan"],
            ["SpringBoard hooks remain unavailable", "lock screen hooks remain unavailable"],
        ),
        "managed_appliance_mode": OwnershipMode(
            "managed_appliance_mode",
            "Managed Jarvis Appliance Mode",
            ["dedicated appliance behavior", "app allow lists", "restrictions", "automatic relaunch where allowed", "offline tools"],
            ["SpringBoard internals", "lock screen internals", "secure boot", "stock iOS root restrictions"],
            False,
            False,
            False,
            False,
            False,
            True,
            "best current non-jailbreak target",
            ["supervision", "configuration profiles", "native Jarvis shell", "recovery profile"],
            ["no SpringBoard hooks", "no true root daemon", "no arbitrary app inspection"],
        ),
        "jailbroken_jarvisos_mode_blocked": OwnershipMode(
            "jailbroken_jarvisos_mode_blocked",
            "Jailbroken JarvisOS Mode Blocked",
            ["planned SpringBoard hooks", "planned daemon", "planned lock and button integration"],
            ["all system ownership surfaces remain stock until jailbreak is verified"],
            False,
            False,
            False,
            False,
            False,
            True,
            "true goal but blocked",
            ["verified jailbreak support for iPhone XR on iOS 18.7.9", "toolchain", "device tests", "safe rollback"],
            ["no verified XR iOS 18.7.9 jailbreak in this repo", "A12 is not checkm8", "system hooks are unproven"],
        ),
        "firmware_replacement_mode_impractical": OwnershipMode(
            "firmware_replacement_mode_impractical",
            "Firmware Replacement Mode Impractical",
            ["not practically available"],
            ["Apple secure boot", "firmware signing", "SEP", "hardware bring-up"],
            False,
            False,
            False,
            False,
            False,
            False,
            "impossible or not practical",
            ["custom signed firmware or broken secure boot chain"],
            ["Apple secure boot and signing make this effectively not practical"],
        ),
    }


ALIASES = {
    "native_app_mode": "native_shell_mode",
    "guided_access_mode": "supervised_kiosk_mode",
    "supervised_single_app_mode": "supervised_kiosk_mode",
    "soft_ownership_mode": "restricted_device_mode",
    "jailbreak_ownership_mode_blocked": "jailbroken_jarvisos_mode_blocked",
}


def get_ownership_modes() -> list[dict]:
    return [mode.to_dict() for mode in _modes().values()]


class OwnershipController:
    def __init__(self, current_mode: str = "restricted_device_mode"):
        self._modes = _modes()
        self.current_mode = self._normalize(current_mode)

    def _normalize(self, mode_id: str) -> str:
        normalized = ALIASES.get(mode_id, mode_id)
        return normalized if normalized in self._modes else "restricted_device_mode"

    def list_modes(self) -> list[dict]:
        return [mode.to_dict() for mode in self._modes.values()]

    def set_mode(self, mode_id: str) -> tuple[bool, str, dict]:
        normalized = self._normalize(mode_id)
        if normalized not in self._modes:
            return False, f"Unknown ownership mode: {mode_id}", self.get_current_mode()
        self.current_mode = normalized
        mode = self._modes[normalized].to_dict()
        if normalized in {"jailbroken_jarvisos_mode_blocked", "firmware_replacement_mode_impractical"}:
            return False, f"{mode['name']} is not currently buildable.", mode
        return True, f"Ownership mode set to {mode['name']}.", mode

    def get_current_mode(self) -> dict:
        return self._modes[self.current_mode].to_dict()

    def list_blocked_features(self) -> list[dict]:
        current = self._modes[self.current_mode]
        blocked = []
        checks = {
            "external_app_handoff": current.external_apps_can_open,
            "spotify_external_open": current.spotify_can_open,
            "browser_external_open": current.browser_can_open,
            "background_listening": current.background_listening_possible,
            "home_lock_system_button_control": current.home_lock_system_buttons_controlled,
        }
        for feature, allowed in checks.items():
            if not allowed:
                blocked.append({"feature": feature, "reason": "blocked by current ownership mode"})
        for reason in current.blocked_reasons:
            blocked.append({"feature": "setup_or_system_control", "reason": reason})
        return blocked
