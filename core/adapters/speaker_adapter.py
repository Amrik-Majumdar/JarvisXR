from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class SpeakerAdapter(ABC):
    """Speaker output interface. Future iOS implementation should use AVAudioSession."""

    @abstractmethod
    def play_spoken_response(self, text: str) -> AdapterResult:
        raise NotImplementedError


class MockSpeakerAdapter(SpeakerAdapter):
    source = "mock_speaker"

    def play_spoken_response(self, text: str) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"spoken_text": text, "played": True}, start=start)
