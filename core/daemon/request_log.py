from __future__ import annotations

import json
from datetime import datetime, timezone
from pathlib import Path


class RequestLog:
    def __init__(self, path: Path | str | None = None):
        self.path = Path(path) if path else None
        self.entries: list[dict] = []

    def write(self, request_id: str, event: str, payload: dict) -> str:
        entry = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "request_id": request_id,
            "event": event,
            "payload": payload,
        }
        self.entries.append(entry)
        if self.path:
            self.path.parent.mkdir(parents=True, exist_ok=True)
            with self.path.open("a", encoding="utf-8") as handle:
                handle.write(json.dumps(entry, sort_keys=True) + "\n")
        return f"{request_id}:{event}"

    def recent(self, limit: int = 10) -> list[dict]:
        return self.entries[-limit:]
