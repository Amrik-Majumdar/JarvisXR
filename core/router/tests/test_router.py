from __future__ import annotations

from pathlib import Path

from core.registry.validate_registry import load_registry, validate_registry
from core.router.command_router import CommandRouter
from core.router.handlers import HANDLERS
from core.router.local_memory import LocalMemory
from core.router.modes import Availability
from mock.cli_demo.jarvis_cli import render_result
from mock.phone_state import MockPhoneState, phone_state


ROOT = Path(__file__).resolve().parents[3]
REGISTRY = ROOT / "core" / "registry" / "capabilities.json"


def test_registry_validates():
    errors = validate_registry(load_registry(REGISTRY))
    assert errors == []


def test_scan_this_routes_offline():
    router = CommandRouter(REGISTRY)
    result = router.route("scan this")
    assert result["status"] == "ok"
    assert result["capability"]["mode"] in {"offline", "hybrid"}
    assert "camera" in result["required_hardware"]
    assert result["execution"]["status"] == "ok"
    assert result["execution"]["spoken_response"]


def test_online_capability_refuses_offline_mode():
    router = CommandRouter(REGISTRY, Availability())
    result = router.route("search current weather online")
    assert result["status"] == "unavailable"
    assert result["mode"] == "online"
    assert "online mode is not available" in result["unavailable_reason"].lower()


def test_dock_capability_allows_dock_mode():
    router = CommandRouter(REGISTRY, Availability.from_flags(dock=True))
    result = router.route("sync logs to raspberry pi")
    assert result["status"] == "ok"
    assert result["mode"] in {"dock", "hybrid"}


def test_offline_tools_summary():
    router = CommandRouter(REGISTRY)
    result = router.route("what can you do without internet")
    assert result["status"] == "ok"
    assert result["matches"]
    assert len(result["matches"]) <= 15


def test_mock_phone_state_shape():
    state = phone_state()
    assert state["camera"]["available"] is True
    assert "gps" in state["sensors"]
    assert state["network"]["mode"] == "offline"


def test_fuzzy_routing_handles_imperfect_phrase():
    router = CommandRouter(REGISTRY)
    result = router.route("scn this label")
    assert result["status"] in {"ok", "confirmation_required"}
    assert result["confidence"] > 0.2
    assert result["capability"]["family"] in {"Camera and Inspection", "OCR and Text"}


def test_camera_unavailable_refusal():
    phone = MockPhoneState("camera_unavailable")
    router = CommandRouter(REGISTRY, phone_state=phone)
    result = router.route("scan this")
    assert result["status"] == "unavailable"
    assert "camera" in result["unavailable_reason"].lower()


def test_dock_only_refuses_without_dock():
    router = CommandRouter(REGISTRY)
    result = router.route("sync logs to raspberry pi")
    assert result["status"] == "unavailable"
    assert "dock mode is not available" in result["unavailable_reason"].lower()


def test_high_risk_confirmation_behavior(tmp_path):
    memory = LocalMemory(tmp_path / "memory.sqlite")
    router = CommandRouter(REGISTRY, memory=memory)
    result = router.route("clear test data with confirmation")
    assert result["status"] == "confirmation_required"
    assert result["requires_confirmation"] is True
    confirmed = router.route("clear test data with confirmation", confirmed=True)
    assert confirmed["status"] == "ok"


def test_memory_save_and_search(tmp_path):
    memory = LocalMemory(tmp_path / "memory.sqlite")
    item = memory.save_note("Inspection note about a blue valve")
    assert item["id"]
    results = memory.search("blue valve")
    assert len(results) == 1
    assert results[0]["kind"] == "note"


def test_handler_output_format():
    router = CommandRouter(REGISTRY)
    result = router.route("read this label")
    execution = result["execution"]
    assert set(execution) == {
        "status",
        "spoken_response",
        "display_response",
        "data",
        "side_effects",
        "memory_writes",
        "logs",
        "requires_confirmation",
        "unavailable_reason",
        "confirmation_token",
    }
    assert execution["status"] == "ok"


def test_related_tools_query():
    router = CommandRouter(REGISTRY)
    result = router.route("show tools related to camera")
    assert result["status"] == "ok"
    assert result["matches"]
    assert any("Camera" in item["family"] for item in result["matches"])


def test_low_confidence_returns_candidates():
    router = CommandRouter(REGISTRY)
    result = router.route("do the thing with stuff")
    assert "low_confidence" in result
    if result["low_confidence"]:
        assert len(result["candidates"]) <= 3


def test_interactive_render_helper():
    router = CommandRouter(REGISTRY)
    result = router.route("check sensors")
    text = render_result(result)
    assert "spoken:" in text
    assert "capability:" in text


def test_at_least_25_handlers_registered():
    assert len(HANDLERS) >= 25
