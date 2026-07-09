from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class StorageAdapter(ABC):
    """Storage diagnostics interface. Future iOS implementation should report local Jarvis storage and device free space."""

    @abstractmethod
    def status(self) -> AdapterResult:
        raise NotImplementedError


class MockStorageAdapter(StorageAdapter):
    source = "mock_storage"

    def __init__(self, free_gb: float = 5.4):
        self.free_gb = free_gb

    def status(self) -> AdapterResult:
        start = time.perf_counter()
        return timed_result(self.source, "ok", {"total_gb": 16, "free_gb": self.free_gb, "nearly_full": self.free_gb < 0.5}, start=start)
