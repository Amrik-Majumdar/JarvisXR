from __future__ import annotations

import time
from abc import ABC, abstractmethod

from .base import AdapterResult, timed_result


class NetworkAdapter(ABC):
    """Network state interface. Future iOS implementation should expose Wi-Fi and online state without making cloud core."""

    @abstractmethod
    def status(self) -> AdapterResult:
        raise NotImplementedError


class MockNetworkAdapter(NetworkAdapter):
    source = "mock_network"

    def __init__(self, online: bool = False, private_mode: bool = False):
        self.online = online
        self.private_mode = private_mode

    def status(self) -> AdapterResult:
        start = time.perf_counter()
        if self.private_mode:
            return timed_result(self.source, "refused", {"online": self.online, "private_mode": True}, "privacy mode blocks online adapter usage", start=start)
        return timed_result(self.source, "ok", {"online": self.online, "wifi": self.online}, start=start)
