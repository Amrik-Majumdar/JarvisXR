from __future__ import annotations

import json
from collections import Counter
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
REGISTRY_PATH = ROOT / "core" / "registry" / "capabilities.json"
OUTPUT_PATH = ROOT / "core" / "registry" / "xr_capability_matrix.json"

OFFLINE_NATIVE_FAMILIES = {
    "Camera and Inspection",
    "OCR and Text",
    "Object Detection",
    "Audio and Voice",
    "Field Tools",
    "Navigation and Location",
    "Sensor Tools",
    "Files and Memory",
    "Utilities",
    "Diagnostics",
    "Security and Privacy",
    "Offline Knowledge",
    "Jarvis Modes",
    "QR and Barcode",
}
DOCK_FAMILIES = {"Raspberry Pi Dock", "Windows PC Dock", "Developer Tools"}
BLOCKED_JAILBREAK_FAMILIES = {"Phone Control"}
SPRINGBOARD_TERMS = ("springboard", "launchd", "root", "lock screen", "button remap", "home button", "system-wide")
SPOTIFY_TERMS = ("spotify", "music", "media", "playback")
BROWSER_SEARCH_TERMS = ("browser", "safari", "search", "web")


def _text_blob(capability: dict) -> str:
    values = [
        capability.get("id", ""),
        capability.get("family", ""),
        capability.get("name", ""),
        capability.get("implementation_notes", ""),
        " ".join(capability.get("example_voice_phrases", [])),
        " ".join(capability.get("required_hardware", [])),
    ]
    return " ".join(values).lower()


def classify_capability(capability: dict) -> dict:
    family = capability.get("family", "")
    mode = capability.get("mode", "")
    text = _text_blob(capability)
    classifications: list[str] = []
    notes: list[str] = []

    if family in BLOCKED_JAILBREAK_FAMILIES or any(term in text for term in SPRINGBOARD_TERMS):
        classifications.append("blocked_until_jailbreak")
        notes.append("System-wide control, SpringBoard behavior, launchd, root, or button remap work is blocked until a verified XR iOS 18.7.9 jailbreak lane exists.")

    if family in DOCK_FAMILIES or mode == "dock":
        classifications.append("available_dock")
        notes.append("Dock behavior remains Raspberry Pi or Windows PC enhanced and is not the product identity.")

    if family == "Online Enhancement" or mode == "online" or any(term in text for term in BROWSER_SEARCH_TERMS):
        classifications.append("available_online_native")
        notes.append("Online behavior requires Wi-Fi and must stay behind controlled Jarvis flows.")

    if any(term in text for term in SPOTIFY_TERMS):
        classifications.append("available_soft_ownership")
        classifications.append("uncertain_needs_device_test")
        notes.append("Spotify is installed, but playback and handoff control remain mode-dependent until tested.")

    if family in OFFLINE_NATIVE_FAMILIES and mode in {"offline", "hybrid"} and "blocked_until_jailbreak" not in classifications:
        classifications.append("available_offline_native")
        notes.append("Native XR public APIs or local storage can plausibly support this family, subject to device permissions and tests.")

    if mode == "hybrid" and "available_online_native" not in classifications:
        classifications.append("available_online_native")
        notes.append("Hybrid behavior can improve when Wi-Fi is available.")

    if family in {"Online Enhancement"} or any(term in text for term in BROWSER_SEARCH_TERMS + SPOTIFY_TERMS):
        classifications.append("blocked_in_hard_lockdown")
        notes.append("External handoff is blocked in supervised hard lockdown unless an in-app or allowed integration is proven.")

    if not classifications:
        classifications.append("uncertain_needs_device_test")
        notes.append("XR behavior needs native device testing before availability is claimed.")

    classifications = sorted(set(classifications))
    return {
        "id": capability["id"],
        "family": family,
        "name": capability["name"],
        "registry_mode": mode,
        "required_hardware": capability.get("required_hardware", []),
        "xr_classifications": classifications,
        "notes": notes,
    }


def build_matrix() -> dict:
    registry = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    capabilities = [classify_capability(capability) for capability in registry["capabilities"]]
    counter: Counter[str] = Counter()
    for item in capabilities:
        counter.update(item["xr_classifications"])
    return {
        "version": "0.5",
        "target_device": "iPhone XR",
        "ios_version": "18.7.9",
        "strategy": "Jarvis Device Mode",
        "classification_labels": [
            "available_offline_native",
            "available_online_native",
            "available_dock",
            "available_soft_ownership",
            "blocked_in_hard_lockdown",
            "blocked_until_jailbreak",
            "uncertain_needs_device_test",
        ],
        "summary_counts": dict(sorted(counter.items())),
        "capabilities": capabilities,
    }


def write_matrix() -> dict:
    matrix = build_matrix()
    OUTPUT_PATH.write_text(json.dumps(matrix, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    return matrix


def main() -> int:
    matrix = write_matrix()
    print(f"Generated XR capability matrix for {len(matrix['capabilities'])} capabilities at {OUTPUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
