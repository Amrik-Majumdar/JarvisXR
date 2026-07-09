from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class DockAdapter(ABC):
    """Dock interface. Future implementations may target Raspberry Pi or Windows PC sync services."""

    @abstractmethod
    def sync_logs(self) -> AdapterResult:
        raise NotImplementedError


class MockDockAdapter(DockAdapter):
    source = "mock_dock"

    def __init__(self, available: bool = False):
        self.available = available

    def sync_logs(self) -> AdapterResult:
        start = time.perf_counter()
        if not self.available:
            return timed_result(self.source, "unavailable", error="dock adapter unavailable", start=start)
        return timed_result(self.source, "ok", {"target": "raspberry_pi", "synced_logs": 3}, start=start)
