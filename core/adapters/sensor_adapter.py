from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class SensorAdapter(ABC):
    """Sensor interface. Future iOS implementation should wrap CoreMotion, compass, pressure, and proximity APIs."""

    @abstractmethod
    def snapshot(self) -> AdapterResult:
        raise NotImplementedError

    @abstractmethod
    def measure_angle(self) -> AdapterResult:
        raise NotImplementedError


class MockSensorAdapter(SensorAdapter):
    source = "mock_sensor"

    def __init__(self, available: bool = True):
        self.available = available

    def snapshot(self) -> AdapterResult:
        start = time.perf_counter()
        if not self.available:
            return timed_result(self.source, "unavailable", error="sensor adapter unavailable", start=start)
        return timed_result(self.source, "ok", {"compass_heading": 180, "pressure_hpa": 1013.25, "motion": {"x": 0, "y": 0, "z": 1}}, start=start)

    def measure_angle(self) -> AdapterResult:
        start = time.perf_counter()
        if not self.available:
            return timed_result(self.source, "unavailable", error="sensor adapter unavailable", start=start)
        return timed_result(self.source, "ok", {"angle_degrees": 0}, start=start)
