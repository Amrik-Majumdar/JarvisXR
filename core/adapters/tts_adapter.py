from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class TTSAdapter(ABC):
    """Text to speech interface. Future iOS implementation should use local AVSpeechSynthesizer."""

    @abstractmethod
    def synthesize(self, text: str) -> AdapterResult:
        raise NotImplementedError


class MockTTSAdapter(TTSAdapter):
    source = "mock_tts"

    def synthesize(self, text: str) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"text": text, "voice": "local-british-style-placeholder"}, start=start)
