from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class BatteryAdapter(ABC):
    """Battery diagnostics interface. Future iOS implementation should use UIDevice and jailbreak diagnostics where safe."""

    @abstractmethod
    def status(self) -> AdapterResult:
        raise NotImplementedError


class MockBatteryAdapter(BatteryAdapter):
    source = "mock_battery"

    def __init__(self, level_percent: int = 72):
        self.level_percent = level_percent

    def status(self) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"level_percent": self.level_percent, "low_power_preferred": self.level_percent <= 10}, start=start)
