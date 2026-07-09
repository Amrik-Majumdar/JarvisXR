from __future__ import annotations

import argparse
import json
import plistlib
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path
from pathlib import PurePosixPath


EXPECTED_BUNDLE_ID = "com.amrik.jarvisxr"
EXPECTED_DISPLAY_NAME = "JARVIS"
REQUIRED_INTENT_STRINGS = [
    "Start JARVIS Inspection",
    "Open JARVIS Control Mesh",
    "Return to JARVIS",
    "Run JARVIS Command",
    "Set JARVIS Quiet Mode",
    "Set JARVIS Normal Mode",
]
FORBIDDEN_STRINGS = [
    "Recent Activity",
    "JARVIS RESPONSE",
    "Next test steps ready",
    "Try: open Spotify",
    "play music",
    "raw JSON",
    "debug label",
    "Wi-Fi path available",
    "offline tools remain",
    "guided ready",
    "Blocked",
    "blocked",
]
REQUIRED_HELP_STRINGS = [
    "Tap once from standby",
    "Tap again to listen",
    "Tap while listening",
    "Long hold",
]
FORBIDDEN_APP_DOC_SUFFIXES = (".md", ".markdown", ".rst")


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit a JARVIS unsigned IPA on Windows.")
    parser.add_argument("ipa", help="Path to JarvisXR-unsigned.ipa")
    args = parser.parse_args()

    failures: list[str] = []
    warnings: list[str] = []
    passed: list[str] = []
    repo_orb = Path("ios") / "JarvisXR" / "JarvisXR" / "Assets.xcassets" / "JarvisOrb.imageset" / "jarvis-orb.png"
    repo_app_icon = Path("ios") / "JarvisXR" / "JarvisXR" / "Assets.xcassets" / "AppIcon.appiconset"
    repo_launch = Path("ios") / "JarvisXR" / "JarvisXR" / "LaunchScreen.storyboard"
    if repo_orb.exists() and repo_orb.stat().st_size > 0:
        passed.append("Expected iOS orb source asset exists before build")
    else:
        failures.append(f"Expected iOS orb source asset is missing before build: {repo_orb}")
    if source_asset_set_has_files(repo_app_icon):
        passed.append("Expected AppIcon source asset set has real PNG files")
    else:
        failures.append(f"Expected AppIcon source asset set is missing or empty: {repo_app_icon}")
    if repo_launch.exists() and repo_launch.stat().st_size > 0:
        passed.append("LaunchScreen storyboard source exists before build")
    else:
        failures.append(f"LaunchScreen storyboard source missing before build: {repo_launch}")

    intents_source = Path("ios") / "JarvisXR" / "JarvisXR" / "JarvisAppIntents.swift"
    if intents_source.exists():
        source_text = intents_source.read_text(encoding="utf-8")
        for text in REQUIRED_INTENT_STRINGS:
            if text in source_text:
                passed.append(f"App Intent source string present: {text}")
            else:
                failures.append(f"Expected App Intent source string missing: {text}")
    else:
        failures.append(f"App Intents source file missing: {intents_source}")

    try:
        archive = zipfile.ZipFile(args.ipa)
    except Exception as exc:
        print(f"IPA audit failed: could not open zip: {exc}")
        return 1

    with archive:
        names = archive.namelist()
        app_roots = sorted({name.split(".app/", 1)[0] + ".app" for name in names if name.startswith("Payload/") and ".app/" in name})
        if len(app_roots) != 1:
            failures.append(f"Expected one Payload/*.app, found {len(app_roots)}")
            app_root = app_roots[0] if app_roots else ""
        else:
            app_root = app_roots[0]
            passed.append(f"App bundle found: {app_root}")

        info_path = f"{app_root}/Info.plist" if app_root else ""
        info = {}
        if info_path and info_path in names:
            try:
                info = plistlib.loads(archive.read(info_path))
                passed.append("Info.plist exists and parses")
            except Exception as exc:
                failures.append(f"Info.plist could not parse: {exc}")
        else:
            failures.append("Info.plist missing from app bundle")

        if info:
            check_equal(passed, failures, "CFBundleDisplayName", info.get("CFBundleDisplayName"), EXPECTED_DISPLAY_NAME)
            bundle_id = info.get("CFBundleIdentifier", "")
            if bundle_id == EXPECTED_BUNDLE_ID or bundle_id.endswith(".jarvisxr"):
                passed.append(f"Bundle identifier acceptable: {bundle_id}")
            else:
                failures.append(f"Unexpected bundle identifier: {bundle_id}")
            if info.get("MinimumOSVersion"):
                passed.append(f"MinimumOSVersion present: {info.get('MinimumOSVersion')}")
            else:
                failures.append("MinimumOSVersion missing")
            if info.get("UILaunchStoryboardName") == "LaunchScreen":
                passed.append("LaunchScreen configured in Info.plist")
            else:
                failures.append("UILaunchStoryboardName is not LaunchScreen")

        launch_candidates = [name for name in names if name.startswith(app_root + "/") and "LaunchScreen" in name]
        if launch_candidates:
            passed.append("LaunchScreen resource present")
        else:
            failures.append("LaunchScreen resource not found in app bundle")

        assets_car_name = f"{app_root}/Assets.car"
        if assets_car_name in names:
            passed.append("Assets.car present")
            with tempfile.TemporaryDirectory() as tmp:
                assets_path = Path(tmp) / "Assets.car"
                assets_path.write_bytes(archive.read(assets_car_name))
                asset_names = asset_catalog_names(assets_path, warnings)
                if asset_names:
                    if "JarvisOrb" in asset_names:
                        passed.append("JarvisOrb present in compiled Assets.car")
                    else:
                        failures.append("JarvisOrb missing from compiled Assets.car")
                    if any(name == "AppIcon" or name.startswith("AppIcon") or "AppIcon" in name for name in asset_names):
                        passed.append("AppIcon present in compiled Assets.car")
                    else:
                        failures.append("AppIcon missing from compiled Assets.car")
                elif sys.platform == "darwin":
                    failures.append("assetutil could not prove JarvisOrb and AppIcon in Assets.car")
                else:
                    warnings.append("assetutil unavailable, using source asset catalog evidence for AppIcon and JarvisOrb")
        else:
            failures.append("Assets.car missing, asset catalog may not be bundled")

        app_intents_metadata = [
            name for name in names
            if name.startswith(app_root + "/")
            and (
                "AppIntents" in name
                or "AppShortcuts" in name
                or "ExtractedAppShortcutsMetadata" in name
            )
        ]

        bundled_docs = [
            name for name in names
            if name.startswith(app_root + "/")
            and PurePosixPath(name).suffix.lower() in FORBIDDEN_APP_DOC_SUFFIXES
        ]
        if bundled_docs:
            failures.append("Markdown or documentation files were copied into the app bundle: " + ", ".join(bundled_docs[:8]))
        else:
            passed.append("No markdown/docs in app bundle")

        combined = read_text_payload(archive, names, app_root)
        intents_seen = any(text in combined for text in REQUIRED_INTENT_STRINGS)
        if app_intents_metadata:
            passed.append("App Intents metadata resource present: " + ", ".join(app_intents_metadata[:4]))
        if intents_seen:
            for text in REQUIRED_INTENT_STRINGS:
                if text in combined:
                    passed.append(f"Intent string present: {text}")
                else:
                    failures.append(f"Expected App Intent string missing from readable bundle payload: {text}")
        elif app_intents_metadata:
            warnings.append("App Intent strings were not readable, but App Intents metadata resources were found")
        else:
            failures.append("App Intents metadata or readable intent strings were not found in the app bundle")

        if ".mlmodelc/" not in "\n".join(names):
            vision_source = Path("ios") / "JarvisXR" / "JarvisXR" / "JarvisCameraViewController.swift"
            vision_text = vision_source.read_text(encoding="utf-8") if vision_source.exists() else ""
            if "VNClassifyImageRequest" in vision_text and "Visual scan ready" in vision_text + combined:
                passed.append("No .mlmodelc found and built-in Vision classification fallback is active")
            else:
                failures.append("No .mlmodelc found and built-in Vision classification fallback was not proven")
        else:
            passed.append("Compiled Core ML model resource present")

        for text in FORBIDDEN_STRINGS:
            if text in combined:
                failures.append(f"Forbidden product string found: {text}")
            else:
                passed.append(f"Forbidden product string absent: {text}")

        for text in REQUIRED_HELP_STRINGS:
            if text in combined:
                passed.append(f"Help wording present: {text}")
            else:
                failures.append(f"Required tap/hold help wording missing: {text}")

        if "LaunchScreen.storyboardc/" in "\n".join(names) or any(name.endswith("LaunchScreen.storyboardc") for name in names):
            passed.append("Compiled LaunchScreen storyboard present")
        elif any("LaunchScreen" in name for name in names):
            passed.append("LaunchScreen resource present by name")
        else:
            failures.append("No LaunchScreen resource name found")

        if not has_otool():
            warnings.append("otool unavailable on this machine, framework binary inspection skipped")

    print("JARVIS IPA audit")
    for item in passed:
        print(f"PASS: {item}")
    for item in warnings:
        print(f"WARN: {item}")
    for item in failures:
        print(f"FAIL: {item}")
    return 1 if failures else 0


def check_equal(passed: list[str], failures: list[str], label: str, actual: object, expected: object) -> None:
    if actual == expected:
        passed.append(f"{label} == {expected}")
    else:
        failures.append(f"{label} expected {expected}, got {actual}")


def read_text_payload(archive: zipfile.ZipFile, names: list[str], app_root: str) -> str:
    chunks: list[str] = []
    for name in names:
        if not name.startswith(app_root + "/") or name.endswith("/"):
            continue
        try:
            data = archive.read(name)
        except Exception:
            continue
        if b"\x00" in data[:4096] and not name.endswith((".plist", ".strings", ".json")):
            try:
                chunks.append(data.decode("utf-8", errors="ignore"))
            except Exception:
                pass
            continue
        try:
            chunks.append(data.decode("utf-8", errors="ignore"))
        except Exception:
            continue
    return "\n".join(chunks)


def source_asset_set_has_files(path: Path) -> bool:
    contents = path / "Contents.json"
    if not contents.exists():
        return False
    try:
        data = json.loads(contents.read_text(encoding="utf-8"))
    except Exception:
        return False
    filenames = [item.get("filename") for item in data.get("images", []) if item.get("filename")]
    return bool(filenames) and all((path / name).exists() and (path / name).stat().st_size > 0 for name in filenames)


def asset_catalog_names(assets_car: Path, warnings: list[str]) -> set[str]:
    if sys.platform != "darwin":
        return set()
    try:
        result = subprocess.run(
            ["xcrun", "assetutil", "--info", str(assets_car)],
            check=True,
            capture_output=True,
            text=True,
        )
        payload = json.loads(result.stdout)
    except Exception as exc:
        warnings.append(f"assetutil inspection failed: {exc}")
        return set()
    names: set[str] = set()
    for item in payload:
        name = item.get("Name") or item.get("AssetName")
        if name:
            names.add(str(name))
    return names


def has_otool() -> bool:
    return sys.platform == "darwin"


if __name__ == "__main__":
    raise SystemExit(main())
