from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class OCRAdapter(ABC):
    """OCR interface. Future iOS implementation depends on exact iOS version and available local OCR libraries."""

    @abstractmethod
    def read_text(self, frame: dict | None = None) -> AdapterResult:
        raise NotImplementedError


class MockOCRAdapter(OCRAdapter):
    source = "mock_ocr"

    def read_text(self, frame: dict | None = None) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"text": "SAMPLE LABEL 123", "confidence": 0.91, "frame": frame}, start=start)
