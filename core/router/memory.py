from __future__ import annotations

from dataclasses import dataclass, field
from datetime import datetime, timezone


@dataclass
class MemoryLog:
    entries: list[dict] = field(default_factory=list)

    def add(self, kind: str, payload: dict) -> dict:
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "kind": kind,
            "payload": payload,
        }
        self.entries.append(entry)
        return entry

    def recent(self, limit: int = 10) -> list[dict]:
        return self.entries[-limit:]
