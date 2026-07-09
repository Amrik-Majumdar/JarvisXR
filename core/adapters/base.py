from __future__ import annotations

import time
from dataclasses import dataclass, field
from typing import Protocol


@dataclass
class AdapterResult:
    status: str
    data: dict = field(default_factory=dict)
    error: str | None = None
    latency_ms: float = 0.0
    source: str = "mock"

    def to_dict(self) -> dict:
        return {
            "status": self.status,
            "data": self.data,
            "error": self.error,
            "latency_ms": self.latency_ms,
            "source": self.source,
        }


class Adapter(Protocol):
    source: str


def timed_result(source: str, status: str, data: dict | None = None, error: str | None = None, start: float | None = None) -> AdapterResult:
    started = start if start is not None else time.perf_counter()
    latency_ms = round((time.perf_counter() - started) * 1000, 3)
    return AdapterResult(status=status, data=data or {}, error=error, latency_ms=latency_ms, source=source)
