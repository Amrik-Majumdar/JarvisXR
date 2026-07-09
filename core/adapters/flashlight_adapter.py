from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class FlashlightAdapter(ABC):
    """Flashlight interface. Future iOS implementation should route through AVCaptureDevice torch APIs."""

    @abstractmethod
    def set_enabled(self, enabled: bool) -> AdapterResult:
        raise NotImplementedError


class MockFlashlightAdapter(FlashlightAdapter):
    source = "mock_flashlight"

    def set_enabled(self, enabled: bool) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"enabled": enabled}, start=start)
