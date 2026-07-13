from __future__ import annotations

import json
import argparse
from pathlib import Path
import subprocess
import re
import sys


def main() -> int:
    parser = argparse.ArgumentParser(description="Select an iPhone Simulator for JARVIS CI.")
    parser.add_argument("--destination", action="store_true", help="Print xcodebuild destination string instead of raw UDID.")
    parser.add_argument("--details", action="store_true", help="Print JSON details for the selected simulator.")
    parser.add_argument("--all", action="store_true", help="Print every dynamically discovered available iPhone simulator.")
    parser.add_argument("--discover-layouts", metavar="PATH", help="Boot discovered iPhones, measure screenshot dimensions, and write JSON evidence.")
    parser.add_argument("--layout-report", metavar="PATH", help="Read a JSON layout discovery report.")
    parser.add_argument("--layout", choices=("compact", "large"), help="Select the measured smallest or largest iPhone layout.")
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
    if args.discover_layouts:
        return discover_layouts(devices, Path(args.discover_layouts))
    if args.layout:
        if not args.layout_report:
            return 1
        return select_measured_layout(Path(args.layout_report), args.layout, args.destination, args.details)
    if args.all:
        for device in devices:
            print(format_output(device, args.destination, args.details))
        return 0 if devices else 1
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


def discover_layouts(devices: list[dict], output: Path) -> int:
    layouts: list[dict] = []
    for device in devices:
        udid = str(device.get("udid", ""))
        if not udid:
            continue
        was_booted = device.get("state") == "Booted"
        screenshot = Path("/tmp") / f"jarvisxr-simulator-{udid}.png"
        try:
            subprocess.run(["xcrun", "simctl", "boot", udid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", str(screenshot)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            width, height = png_dimensions(screenshot)
            layouts.append({
                "name": device.get("name", ""),
                "udid": udid,
                "runtime": device.get("runtime", ""),
                "width": width,
                "height": height,
                "pixels": width * height,
            })
        except Exception:
            continue
        finally:
            screenshot.unlink(missing_ok=True)
            if not was_booted:
                subprocess.run(["xcrun", "simctl", "shutdown", udid], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if not layouts:
        return 1
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps({"layouts": layouts}, indent=2, sort_keys=True), encoding="utf-8")
    print(json.dumps({"layouts": layouts}, sort_keys=True))
    return 0


def select_measured_layout(report: Path, layout: str, destination: bool, details: bool) -> int:
    try:
        entries = json.loads(report.read_text(encoding="utf-8")).get("layouts", [])
        if not isinstance(entries, list) or not entries:
            return 1
        selected = min(entries, key=lambda item: int(item["pixels"])) if layout == "compact" else max(entries, key=lambda item: int(item["pixels"]))
        return print_selected_layout(selected, destination, details)
    except Exception:
        return 1


def print_selected_layout(device: dict, destination: bool, details: bool) -> int:
    if details:
        print(json.dumps(device, sort_keys=True))
    else:
        udid = str(device.get("udid", ""))
        print(f"id={udid}" if destination else udid)
    return 0


def png_dimensions(path: Path) -> tuple[int, int]:
    raw = path.read_bytes()
    if raw[:8] != b"\x89PNG\r\n\x1a\n" or raw[12:16] != b"IHDR":
        raise ValueError("not a PNG")
    return int.from_bytes(raw[16:20], "big"), int.from_bytes(raw[20:24], "big")


if __name__ == "__main__":
    sys.exit(main())
