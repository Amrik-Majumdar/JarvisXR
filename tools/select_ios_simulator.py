from __future__ import annotations

import json
import argparse
import subprocess
import sys


DEFAULT_NAMES = [
    "iPhone XR",
    "iPhone 11",
    "iPhone 11 Pro Max",
    "iPhone 14 Plus",
    "iPhone 15 Plus",
    "iPhone 16 Plus",
]

COMPACT_NAMES = [
    "iPhone 17e",
    "iPhone 16e",
    "iPhone SE (3rd generation)",
]

LARGE_NAMES = [
    "iPhone 17 Pro Max",
    "iPhone 16 Pro Max",
    "iPhone 16 Plus",
    "iPhone 15 Pro Max",
    "iPhone 15 Plus",
]


def main() -> int:
    parser = argparse.ArgumentParser(description="Select an iPhone Simulator for JARVIS CI.")
    parser.add_argument("--destination", action="store_true", help="Print xcodebuild destination string instead of raw UDID.")
    parser.add_argument("--details", action="store_true", help="Print JSON details for the selected simulator.")
    parser.add_argument("--profile", choices=("default", "compact", "large"), default="default")
    args = parser.parse_args()

    try:
        raw = subprocess.check_output(
            ["xcrun", "simctl", "list", "devices", "available", "-j"],
            text=True,
            stderr=subprocess.DEVNULL,
        )
        data = json.loads(raw)
    except Exception:
        return 1

    devices = []
    for runtime, runtime_devices in data.get("devices", {}).items():
        for device in runtime_devices:
            if device.get("isAvailable") and "iPhone" in device.get("name", ""):
                devices.append({**device, "runtime": runtime})
    preferred_names = {
        "default": DEFAULT_NAMES,
        "compact": COMPACT_NAMES,
        "large": LARGE_NAMES,
    }[args.profile]
    for preferred in preferred_names:
        for device in devices:
            if device.get("name") == preferred:
                print(format_output(device, args.destination, args.details))
                return 0
    if args.profile != "default":
        return 1
    if devices:
        print(format_output(devices[0], args.destination, args.details))
        return 0
    return 1


def format_output(device: dict, destination: bool, details: bool) -> str:
    udid = device.get("udid", "")
    if details:
        return json.dumps({
            "name": device.get("name", ""),
            "udid": udid,
            "runtime": device.get("runtime", ""),
            "state": device.get("state", ""),
        }, sort_keys=True)
    return f"id={udid}" if destination else udid


if __name__ == "__main__":
    sys.exit(main())
