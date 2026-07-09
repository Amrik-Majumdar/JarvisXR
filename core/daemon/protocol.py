from __future__ import annotations

import json
from pathlib import Path


VALID_REQUEST_TYPES = {
    "health_check",
    "route_command",
    "execute_command",
    "list_capabilities",
    "list_offline_capabilities",
    "list_related_capabilities",
    "get_phone_state",
    "update_mock_phone_state",
    "save_note",
    "search_memory",
    "export_memory_summary",
    "request_confirmation",
    "confirm_and_execute",
    "set_mode",
    "get_mode",
    "get_recent_history",
    "get_device_profile",
    "compare_device_profiles",
    "get_device_mode_strategy",
    "get_spotify_strategy",
    "list_media_capabilities",
    "get_ownership_modes",
    "set_ownership_mode",
    "get_current_ownership_mode",
    "list_blocked_ownership_features",
    "get_takeover_levels",
    "get_true_ownership_requirements",
    "get_recommended_takeover_path",
    "explain_why_not_just_an_app",
    "explain_what_blocks_true_ownership",
    "list_jailbreak_only_features",
    "list_supervision_features",
    "list_appliance_mode_steps",
    "get_final_recommendation",
    "get_xr_setup_steps",
    "get_do_not_jailbreak_warning",
    "get_appliance_mode_plan",
    "get_native_build_decision_tree",
}

RESPONSE_STATUSES = {"ok", "refused", "confirmation_required", "error", "unavailable"}
HANDLER_STATUSES = RESPONSE_STATUSES


def load_schema(name: str) -> dict:
    path = Path(__file__).with_name("schemas") / name
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_request(request: dict) -> list[str]:
    errors: list[str] = []
    if not isinstance(request, dict):
        return ["request must be an object"]
    if request.get("type") not in VALID_REQUEST_TYPES:
        errors.append("type must be a supported request type")
    if not isinstance(request.get("request_id"), str) or not request.get("request_id"):
        errors.append("request_id must be a non-empty string")
    allowed = {"type", "request_id", "command", "query", "text", "topic", "mode", "profile", "confirmation_token", "confirmed", "payload"}
    extra = set(request) - allowed
    if extra:
        errors.append(f"unexpected request fields: {sorted(extra)}")
    return errors


def validate_handler_result(result: dict) -> list[str]:
    required = {
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
    errors: list[str] = []
    missing = required - set(result)
    if missing:
        errors.append(f"handler result missing fields: {sorted(missing)}")
    if result.get("status") not in HANDLER_STATUSES:
        errors.append("handler status is invalid")
    for field in ["spoken_response", "display_response"]:
        if not isinstance(result.get(field), str):
            errors.append(f"{field} must be a string")
    if not isinstance(result.get("data"), dict):
        errors.append("data must be an object")
    for field in ["side_effects", "memory_writes", "logs"]:
        if not isinstance(result.get(field), list):
            errors.append(f"{field} must be a list")
    if not isinstance(result.get("requires_confirmation"), bool):
        errors.append("requires_confirmation must be a boolean")
    if result.get("unavailable_reason") is not None and not isinstance(result.get("unavailable_reason"), str):
        errors.append("unavailable_reason must be string or null")
    if result.get("confirmation_token") is not None and not isinstance(result.get("confirmation_token"), str):
        errors.append("confirmation_token must be string or null")
    return errors


def make_response(
    request_id: str,
    status: str,
    mode: str,
    spoken_response: str,
    display_response: str,
    data: dict | None = None,
    risk_level: str = "low",
    requires_confirmation: bool = False,
    unavailable_reason: str | None = None,
    candidate_capabilities: list | None = None,
    logs_written: list[str] | None = None,
) -> dict:
    return {
        "request_id": request_id,
        "status": status,
        "mode": mode,
        "spoken_response": spoken_response,
        "display_response": display_response,
        "data": data or {},
        "risk_level": risk_level,
        "requires_confirmation": requires_confirmation,
        "unavailable_reason": unavailable_reason,
        "candidate_capabilities": candidate_capabilities or [],
        "logs_written": logs_written or [],
    }


def validate_response(response: dict) -> list[str]:
    required = {
        "request_id",
        "status",
        "mode",
        "spoken_response",
        "display_response",
        "data",
        "risk_level",
        "requires_confirmation",
        "unavailable_reason",
        "candidate_capabilities",
        "logs_written",
    }
    errors: list[str] = []
    missing = required - set(response)
    if missing:
        errors.append(f"response missing fields: {sorted(missing)}")
    if response.get("status") not in RESPONSE_STATUSES:
        errors.append("response status is invalid")
    if not isinstance(response.get("data"), dict):
        errors.append("response data must be an object")
    if not isinstance(response.get("candidate_capabilities"), list):
        errors.append("candidate_capabilities must be a list")
    if not isinstance(response.get("logs_written"), list):
        errors.append("logs_written must be a list")
    return errors
