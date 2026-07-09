from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class STTAdapter(ABC):
    """Speech to text interface. Future iOS implementation may use local short-command recognition."""

    @abstractmethod
    def transcribe_last_clip(self) -> AdapterResult:
        raise NotImplementedError


class MockSTTAdapter(STTAdapter):
    source = "mock_stt"

    def transcribe_last_clip(self) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"transcript": "scan this", "confidence": 0.88}, start=start)
