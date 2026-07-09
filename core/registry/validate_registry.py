from __future__ import annotations

import json
import sys
from pathlib import Path


REQUIRED_FIELDS = {
    "id",
    "family",
    "name",
    "example_voice_phrases",
    "mode",
    "required_hardware",
    "risk_level",
    "permission_required",
    "implementation_notes",
    "test_idea",
}

VALID_MODES = {"offline", "online", "dock", "hybrid"}
VALID_RISKS = {"low", "medium", "high"}


def load_registry(path: Path) -> dict:
    with path.open("r", encoding="utf-8") as handle:
        return json.load(handle)


def validate_registry(registry: dict) -> list[str]:
    errors: list[str] = []
    capabilities = registry.get("capabilities")
    if not isinstance(capabilities, list):
        return ["capabilities must be a list"]
    if len(capabilities) < 400:
        errors.append(f"registry must include at least 400 capabilities, found {len(capabilities)}")

    seen_ids: set[str] = set()
    for index, capability in enumerate(capabilities):
        prefix = f"capabilities[{index}]"
        if not isinstance(capability, dict):
            errors.append(f"{prefix} must be an object")
            continue
        missing = REQUIRED_FIELDS - set(capability)
        if missing:
            errors.append(f"{prefix} missing fields: {sorted(missing)}")
        extra = set(capability) - REQUIRED_FIELDS
        if extra:
            errors.append(f"{prefix} has unexpected fields: {sorted(extra)}")
        cap_id = capability.get("id")
        if not isinstance(cap_id, str) or not cap_id:
            errors.append(f"{prefix}.id must be a non-empty string")
        elif cap_id in seen_ids:
            errors.append(f"duplicate capability id: {cap_id}")
        else:
            seen_ids.add(cap_id)
        if capability.get("mode") not in VALID_MODES:
            errors.append(f"{prefix}.mode must be one of {sorted(VALID_MODES)}")
        if capability.get("risk_level") not in VALID_RISKS:
            errors.append(f"{prefix}.risk_level must be one of {sorted(VALID_RISKS)}")
        phrases = capability.get("example_voice_phrases")
        if not isinstance(phrases, list) or len(phrases) < 2 or not all(isinstance(item, str) for item in phrases):
            errors.append(f"{prefix}.example_voice_phrases must contain at least two strings")
        hardware = capability.get("required_hardware")
        if not isinstance(hardware, list) or not all(isinstance(item, str) for item in hardware):
            errors.append(f"{prefix}.required_hardware must be a list of strings")
    return errors


def main() -> int:
    registry_path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).with_name("capabilities.json")
    registry = load_registry(registry_path)
    errors = validate_registry(registry)
    if errors:
        for error in errors:
            print(f"ERROR: {error}")
        return 1
    print(f"OK: {len(registry['capabilities'])} capabilities validated")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
