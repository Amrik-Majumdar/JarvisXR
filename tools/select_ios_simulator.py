from __future__ import annotations

import json
import argparse
import subprocess
import re
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Select an iPhone Simulator for JARVIS CI.")
    parser.add_argument("--destination", action="store_true", help="Print xcodebuild destination string instead of raw UDID.")
    parser.add_argument("--details", action="store_true", help="Print JSON details for the selected simulator.")
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
            device_type = str(device.get("deviceTypeIdentifier", ""))
            if device.get("isAvailable") and ".SimDeviceType.iPhone-" in device_type:
                devices.append({**device, "runtime": runtime})
    devices.sort(key=selection_key, reverse=True)
    if devices:
        print(format_output(devices[0], args.destination, args.details))
        return 0
    return 1


def selection_key(device: dict) -> tuple[int, tuple[int, ...], str]:
    runtime = str(device.get("runtime", ""))
    version_match = re.search(r"iOS-(\d+)(?:-(\d+))?(?:-(\d+))?", runtime)
    version = tuple(int(value or 0) for value in version_match.groups()) if version_match else (0, 0, 0)
    return (1 if device.get("state") == "Booted" else 0, version, str(device.get("udid", "")))


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
