from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class VisionAdapter(ABC):
    """Object detection interface. Future iOS implementation should use small Core ML models after testing."""

    @abstractmethod
    def detect_objects(self, frame: dict | None = None) -> AdapterResult:
        raise NotImplementedError


class MockVisionAdapter(VisionAdapter):
    source = "mock_vision"

    def detect_objects(self, frame: dict | None = None) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"objects": [{"label": "bottle", "confidence": 0.78}, {"label": "label", "confidence": 0.74}], "frame": frame}, start=start)
