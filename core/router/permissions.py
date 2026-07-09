from __future__ import annotations


def requires_confirmation(capability: dict) -> bool:
    permission = capability.get("permission_required", "").lower()
    risk = capability.get("risk_level", "low")
    return risk in {"medium", "high"} or "confirm" in permission or "jailbreak" in permission


def permission_summary(capability: dict) -> str:
    if requires_confirmation(capability):
        return f"Confirmation required: {capability['permission_required']}"
    return f"No blocking confirmation: {capability['permission_required']}"
