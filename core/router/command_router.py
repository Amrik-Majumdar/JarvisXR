from __future__ import annotations

import json
from pathlib import Path

try:
    from core.adapters import AdapterRegistry
    from .handlers import execute_handler
    from .intent_matcher import find_matches, normalize, related_to, tokenize
    from .local_memory import LocalMemory
    from .modes import Availability
    from .permissions import permission_summary
    from .phone_state import MockPhoneState
except ImportError:
    from core.adapters import AdapterRegistry
    from handlers import execute_handler
    from intent_matcher import find_matches, normalize, related_to, tokenize
    from local_memory import LocalMemory
    from modes import Availability
    from permissions import permission_summary
    from phone_state import MockPhoneState


LOW_CONFIDENCE = 0.42

HARDWARE_KEYS = {
    "camera": ("camera", "available"),
    "microphone": ("microphone", "available"),
    "speaker": ("speaker", "available"),
    "gps": ("sensors", "gps", "available"),
    "compass": ("sensors", "compass", "available"),
    "accelerometer": ("sensors", "accelerometer", "available"),
    "gyroscope": ("sensors", "gyroscope", "available"),
    "barometer": ("sensors", "barometer", "available"),
    "sensors": ("sensors", "available"),
    "wifi": ("network", "wifi"),
    "raspberry pi": ("network", "dock"),
    "windows pc": ("network", "dock"),
    "local storage": ("storage", "free_gb"),
    "battery": ("battery", "level_percent"),
}


class CommandRouter:
    def __init__(
        self,
        registry_path: Path | str,
        availability: Availability | None = None,
        phone_state: dict | MockPhoneState | None = None,
        memory: LocalMemory | None = None,
        adapters: AdapterRegistry | None = None,
    ):
        self.registry_path = Path(registry_path)
        if isinstance(phone_state, MockPhoneState):
            self.phone = phone_state
            self.phone_state = phone_state.snapshot()
        else:
            self.phone = None
            self.phone_state = phone_state or MockPhoneState().snapshot()
        self.availability = availability or Availability.from_phone_state(self.phone_state)
        if availability and not phone_state:
            self.phone_state["network"]["wifi"] = availability.online or availability.dock
            self.phone_state["network"]["online"] = availability.online or availability.dock
            self.phone_state["network"]["dock"] = availability.dock
            self.phone_state["network"]["mode"] = "dock" if availability.dock else ("online" if availability.online else "offline")
        self.memory = memory or LocalMemory()
        self.adapters = adapters or AdapterRegistry.mock_for_phone(self.phone_state)
        with self.registry_path.open("r", encoding="utf-8") as handle:
            self.registry = json.load(handle)
        self.capabilities = self.registry["capabilities"]

    def update_phone_state(self, state: dict) -> None:
        self.phone_state = state
        self.availability = Availability.from_phone_state(state)
        self.adapters = AdapterRegistry.mock_for_phone(state)

    def route(self, command: str, confirmed: bool = False) -> dict:
        command = command.strip()
        if not command:
            return {"status": "error", "message": "No command provided."}

        special = self._special_query(command)
        if special:
            return special

        preferred_modes = self._preferred_modes(command)
        matches = find_matches(command, self.capabilities, preferred_modes=preferred_modes)
        if not matches:
            return {
                "status": "unmatched",
                "message": "I could not map that to a registered Jarvis capability.",
                "matches": [],
            }

        score, capability = matches[0]
        mode_allowed = self.availability.allows(capability["mode"])
        hardware_errors = self._hardware_errors(capability)
        unavailable_reason = self._unavailable_reason(capability, mode_allowed, hardware_errors)
        allowed = mode_allowed and not hardware_errors
        ctx = {
            "command": command,
            "argument": self._extract_argument(command),
            "capability": capability,
            "capabilities": self.capabilities,
            "phone_state": self.phone_state,
            "memory": self.memory,
            "adapters": self.adapters,
            "confirmed": confirmed,
            "unavailable_reason": unavailable_reason,
        }
        execution = execute_handler(ctx) if allowed else {
            "status": "unavailable",
            "spoken_response": unavailable_reason,
            "display_response": unavailable_reason,
            "data": {"hardware_errors": hardware_errors, "mode": capability["mode"]},
            "requires_confirmation": False,
            "unavailable_reason": unavailable_reason,
        }
        status = execution["status"] if allowed else "unavailable"
        if status == "ok":
            self.memory.save_command(command, {"status": status, "capability": capability})
        response = {
            "status": status,
            "command": command,
            "confidence": round(score, 3),
            "capability": capability,
            "mode": capability["mode"],
            "required_hardware": capability["required_hardware"],
            "risk_level": capability["risk_level"],
            "permission": permission_summary(capability),
            "requires_confirmation": execution["requires_confirmation"],
            "unavailable_reason": execution["unavailable_reason"],
            "execution": execution,
            "simulated_response": execution["spoken_response"],
            "alternates": [self._candidate(item) for item in matches[1:4]],
            "low_confidence": score < LOW_CONFIDENCE,
        }
        if score < LOW_CONFIDENCE:
            response["message"] = "I found several possible tools. Confirm before executing on device hardware."
            response["candidates"] = [self._candidate(item) for item in matches[:3]]
        return response

    def _special_query(self, command: str) -> dict | None:
        normalized = normalize(command)
        tokens = tokenize(command)
        if {"offline", "internet"} & tokens and {"do", "tools", "without", "available"} & tokens:
            offline = [cap for cap in self.capabilities if cap["mode"] in {"offline", "hybrid"}]
            return {
                "status": "ok",
                "message": f"{len(offline)} capabilities are available without internet or can begin offline.",
                "matches": offline[:15],
            }
        if normalized.startswith("show tools related to") or normalized.startswith("tools related to"):
            lower = command.lower()
            prefix = "show tools related to" if lower.startswith("show tools related to") else "tools related to"
            topic = command[len(prefix):].strip()
            matches = [cap for cap in self.capabilities if related_to(topic, cap)]
            return {
                "status": "ok",
                "message": f"{len(matches)} capabilities relate to {topic}.",
                "matches": matches[:20],
            }
        if normalized.startswith("show tools for") or (normalized.startswith("show") and "tools" in tokens):
            topic = command.replace("show tools for", "").replace("show", "").replace("tools", "").strip()
            if topic:
                matches = [cap for cap in self.capabilities if related_to(topic, cap)]
                return {
                    "status": "ok",
                    "message": f"{len(matches)} capabilities relate to {topic}.",
                    "matches": matches[:20],
                }
        return None

    def _preferred_modes(self, command: str) -> set[str]:
        tokens = tokenize(command)
        modes: set[str] = set()
        if "offline" in tokens:
            modes |= {"offline", "hybrid"}
        if "online" in tokens:
            modes.add("online")
        if "dock" in tokens or "pi" in tokens or "pc" in tokens:
            modes.add("dock")
        return modes

    def _hardware_errors(self, capability: dict) -> list[str]:
        errors: list[str] = []
        if self.phone_state.get("privacy", {}).get("private_mode") and capability["mode"] == "online":
            errors.append("private mode blocks online capabilities")
        for item in capability.get("required_hardware", []):
            key = item.lower()
            matched = False
            for hardware, path in HARDWARE_KEYS.items():
                if hardware in key:
                    matched = True
                    value = self._get_path(path)
                    if value is False or value is None:
                        errors.append(f"{item} is unavailable in the current mock phone state")
                    if hardware == "local storage" and isinstance(value, (int, float)) and value < 0.5:
                        errors.append("local storage is nearly full")
            if not matched and "jailbreak" in key and "optional" not in key:
                if not self.phone_state.get("jailbreak", {}).get("active"):
                    errors.append("jailbreak is inactive")
        if capability["family"] == "Sensor Tools" and self.phone_state.get("sensors", {}).get("available") is False:
            errors.append("sensors are unavailable in the current mock phone state")
        return errors

    def _get_path(self, path: tuple[str, ...] | tuple[str, str] | tuple[str, str, str]):
        value = self.phone_state
        for part in path:
            if not isinstance(value, dict):
                return None
            value = value.get(part)
        return value

    @staticmethod
    def _unavailable_reason(capability: dict, mode_allowed: bool, hardware_errors: list[str]) -> str | None:
        reasons: list[str] = []
        if not mode_allowed:
            mode = capability["mode"]
            if mode == "online":
                reasons.append("Wi-Fi or online mode is not available")
            elif mode == "dock":
                reasons.append("dock mode is not available")
            else:
                reasons.append(f"{mode} mode is not available")
        reasons.extend(hardware_errors)
        return "; ".join(reasons) if reasons else None

    @staticmethod
    def _candidate(match: tuple[float, dict]) -> dict:
        score, capability = match
        return {
            "confidence": round(score, 3),
            "id": capability["id"],
            "name": capability["name"],
            "family": capability["family"],
            "mode": capability["mode"],
            "risk_level": capability["risk_level"],
        }

    @staticmethod
    def _extract_argument(command: str) -> str:
        lowered = command.lower()
        for marker in ["note:", "observation:", "search memory for", "save note", "save this observation"]:
            if marker in lowered:
                return command[lowered.find(marker) + len(marker):].strip(" :")
        return ""
