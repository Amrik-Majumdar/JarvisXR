from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class MicrophoneAdapter(ABC):
    """Microphone interface. Future iOS implementation should use AVAudioRecorder or Audio Queue."""

    @abstractmethod
    def start_push_to_talk(self) -> AdapterResult:
        raise NotImplementedError


class MockMicrophoneAdapter(MicrophoneAdapter):
    source = "mock_microphone"

    def __init__(self, available: bool = True):
        self.available = available

    def start_push_to_talk(self) -> AdapterResult:
        start = time.perf_counter()
        if not self.available:
            return timed_result(self.source, "unavailable", error="microphone adapter unavailable", start=start)
        return timed_result(self.source, "ok", {"input_level_db": -42, "session": "push_to_talk"}, start=start)
