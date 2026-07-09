from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class LocationAdapter(ABC):
    """Location interface. Future iOS implementation should use CLLocationManager with explicit permission state."""

    @abstractmethod
    def current_location(self) -> AdapterResult:
        raise NotImplementedError


class MockLocationAdapter(LocationAdapter):
    source = "mock_location"

    def __init__(self, available: bool = True):
        self.available = available

    def current_location(self) -> AdapterResult:
        start = time.perf_counter()
        if not self.available:
            return timed_result(self.source, "unavailable", error="location adapter unavailable", start=start)
        return timed_result(self.source, "ok", {"lat": 0.0, "lon": 0.0, "accuracy_m": 50}, start=start)
