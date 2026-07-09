from __future__ import annotations

import time
import uuid
from dataclasses import dataclass, field

from core.router.phone_state import MockPhoneState


MODES = {"offline", "online", "dock", "inspection", "field", "sensor", "quiet", "privacy", "diagnostics", "recovery"}


@dataclass
class ConfirmationStore:
    ttl_seconds: int = 120
    tokens: dict[str, dict] = field(default_factory=dict)

    def create(self, request: dict, risk_level: str) -> dict:
        now = time.time()
        token = uuid.uuid4().hex
        record = {
            "token": token,
            "request": request,
            "created_at": now,
            "expires_at": now + self.ttl_seconds,
            "risk_level": risk_level,
            "used": False,
        }
        self.tokens[token] = record
        return record

    def consume(self, token: str) -> tuple[bool, dict | None, str | None]:
        record = self.tokens.get(token)
        if not record:
            return False, None, "confirmation token is unknown"
        if record["used"]:
            return False, record, "confirmation token was already used"
        if time.time() > record["expires_at"]:
            return False, record, "confirmation token is expired"
        record["used"] = True
        return True, record, None


class ModeEngine:
    def __init__(self, phone: MockPhoneState):
        self.phone = phone
        self.mode = "offline"

    def set_mode(self, mode: str, override: bool = False) -> tuple[bool, str]:
        if mode not in MODES:
            return False, f"unknown mode: {mode}"
        state = self.phone.snapshot()
        if state["battery"].get("level_percent", 100) <= 10 and mode not in {"offline", "quiet", "diagnostics", "recovery"}:
            return False, "low battery prefers offline, quiet, diagnostics, or recovery mode"
        if mode == "online" and not state["network"].get("online"):
            return False, "online mode requires online state"
        if mode == "dock" and not state["network"].get("dock"):
            return False, "dock mode requires dock state"
        if mode == "inspection" and not state["camera"].get("available"):
            return False, "inspection mode requires available camera"
        if mode == "sensor" and not state["sensors"].get("available"):
            return False, "sensor mode requires available sensors"
        if mode == "online" and state["privacy"].get("private_mode") and not override:
            return False, "privacy mode blocks online enhancement unless overridden"
        if mode == "privacy":
            self.phone.set_flag("private", True)
        self.mode = mode
        return True, f"mode set to {mode}"


class ServiceState:
    def __init__(self, phone: MockPhoneState | None = None):
        self.phone = phone or MockPhoneState()
        self.confirmations = ConfirmationStore()
        self.mode_engine = ModeEngine(self.phone)

    @property
    def mode(self) -> str:
        return self.mode_engine.mode

    def set_profile(self, profile: str) -> dict:
        state = self.phone.apply_profile(profile)
        return state
