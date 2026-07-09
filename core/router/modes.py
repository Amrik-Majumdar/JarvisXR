from __future__ import annotations

from dataclasses import dataclass


VALID_MODES = {"offline", "online", "dock", "hybrid"}


@dataclass(frozen=True)
class Availability:
    offline: bool = True
    online: bool = False
    dock: bool = False

    def allows(self, capability_mode: str) -> bool:
        if capability_mode == "offline":
            return self.offline
        if capability_mode == "online":
            return self.online
        if capability_mode == "dock":
            return self.dock
        if capability_mode == "hybrid":
            return self.offline or self.online or self.dock
        return False

    @classmethod
    def from_flags(cls, online: bool = False, dock: bool = False) -> "Availability":
        return cls(offline=True, online=online, dock=dock)

    @classmethod
    def from_phone_state(cls, state: dict) -> "Availability":
        network = state.get("network", {})
        return cls(
            offline=True,
            online=bool(network.get("wifi") or network.get("online")),
            dock=bool(network.get("dock")),
        )
