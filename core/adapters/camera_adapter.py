from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class CameraAdapter(ABC):
    """Camera capture interface. Future iOS implementation should wrap AVCaptureSession."""

    @abstractmethod
    def capture_frame(self) -> AdapterResult:
        raise NotImplementedError


class MockCameraAdapter(CameraAdapter):
    source = "mock_camera"

    def __init__(self, available: bool = True):
        self.available = available

    def capture_frame(self) -> AdapterResult:
        start = time.perf_counter()
        if not self.available:
            return timed_result(self.source, "unavailable", error="camera adapter unavailable", start=start)
        return timed_result(self.source, "ok", {"frame_id": "mock-frame-001", "resolution": "640x480"}, start=start)
