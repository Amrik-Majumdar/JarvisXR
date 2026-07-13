from __future__ import annotations

import argparse
import hashlib
import json
import plistlib
import re
import struct
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any

try:
    from .vision_model_contract import EXPECTED_SHA256, ROOT, validate_manifest, write_json
except ImportError:  # Direct execution: python tools/audit_ipa.py
    from vision_model_contract import EXPECTED_SHA256, ROOT, validate_manifest, write_json


EXPECTED_BUNDLE_ID = "com.amrik.jarvisxr"
EXPECTED_DISPLAY_NAME = "JARVIS"
EXPECTED_MINIMUM_OS_VERSION = "18.0"
EXPECTED_MODEL = "JarvisObjectDetector.mlmodelc"
EXPECTED_MODEL_MANIFEST = "JarvisObjectDetector.manifest.json"
EXPECTED_MODEL_NOTICE = "JarvisObjectDetector.NOTICE.txt"
REQUIRED_PERMISSIONS = (
    "NSCameraUsageDescription",
    "NSMicrophoneUsageDescription",
    "NSSpeechRecognitionUsageDescription",
)
REQUIRED_INTENT_STRINGS = (
    "Start JARVIS Inspection",
    "Open JARVIS Control Mesh",
    "Return to JARVIS",
    "Run JARVIS Command",
    "Set JARVIS Quiet Mode",
    "Set JARVIS Normal Mode",
)
FORBIDDEN_PRODUCT_STRINGS = (
    "Recent Activity",
    "JARVIS RESPONSE",
    "Next test steps ready",
    "Try: open Spotify",
    "raw JSON",
    "debug label",
    "Wi-Fi path available",
    "offline tools remain",
    "guided ready",
)
REQUIRED_HELP_STRINGS = (
    "Tap once from standby",
    "Tap again to listen",
    "Tap while listening",
    "Long hold",
)
SECRET_CONTENT_PATTERNS = (
    re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    re.compile(rb"\bsk-[A-Za-z0-9_-]{20,}\b"),
    re.compile(rb"\bgh[pousr]_[A-Za-z0-9]{30,}\b"),
    re.compile(rb"\bAIza[0-9A-Za-z_-]{30,}\b"),
    re.compile(rb"(?:OPENAI_API_KEY|APPLE_PASSWORD|AWS_SECRET_ACCESS_KEY)\s*[:=]\s*[^\s\x00]+", re.IGNORECASE),
)
SECRET_FILE_SUFFIXES = (".p12", ".cer", ".mobileprovision", ".env", ".pem", ".key")
FORBIDDEN_APP_DOC_SUFFIXES = (".md", ".markdown", ".rst")
FORBIDDEN_FIXTURE_BASENAMES = {"desk_chair.jpg"}

CPU_TYPES = {
    7: "x86",
    0x01000007: "x86_64",
    12: "arm",
    0x0100000C: "arm64",
    0x0200000C: "arm64_32",
}


class AuditReport:
    def __init__(self, ipa: Path):
        self.ipa = ipa
        self.passed: list[str] = []
        self.warnings: list[str] = []
        self.failures: list[str] = []
        self.metadata: dict[str, Any] = {}

    def check(self, condition: bool, passed: str, failed: str) -> None:
        (self.passed if condition else self.failures).append(passed if condition else failed)

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": 1,
            "status": "passed" if not self.failures else "failed",
            "ipa": str(self.ipa.resolve()),
            "passed": self.passed,
            "warnings": self.warnings,
            "failures": self.failures,
            "metadata": self.metadata,
        }


def audit_ipa(ipa_path: Path, *, inspect_compiled_assets: bool = True) -> dict[str, Any]:
    report = AuditReport(ipa_path)
    check_source_evidence(report)
    if not ipa_path.is_file() or ipa_path.stat().st_size <= 0:
        report.failures.append(f"IPA is missing or empty: {ipa_path}")
        return report.to_dict()
    report.metadata["ipa_size_bytes"] = ipa_path.stat().st_size
    report.metadata["ipa_sha256"] = sha256_bytes(ipa_path.read_bytes())

    try:
        archive = zipfile.ZipFile(ipa_path)
    except Exception as exc:
        report.failures.append(f"could not open IPA zip: {exc}")
        return report.to_dict()

    with archive:
        names = archive.namelist()
        unsafe_paths = [name for name in names if is_unsafe_archive_path(name)]
        report.check(not unsafe_paths, "archive contains no unsafe paths", "archive contains unsafe paths: " + ", ".join(unsafe_paths[:8]))
        app_roots = sorted({name.split(".app/", 1)[0] + ".app" for name in names if name.startswith("Payload/") and ".app/" in name})
        report.check(len(app_roots) == 1, f"one application bundle found: {app_roots[0] if app_roots else 'none'}", f"expected exactly one Payload/*.app, found {len(app_roots)}")
        if not app_roots:
            return report.to_dict()
        app_root = app_roots[0]
        report.metadata["app_root"] = app_root

        info = read_info_plist(archive, names, app_root, report)
        if info:
            audit_info_plist(info, report)
            audit_executable(archive, names, app_root, info, report)

        audit_unsigned_state(names, app_root, report)
        audit_model_bundle(archive, names, app_root, report)
        audit_bundle_resources(archive, names, app_root, report, inspect_compiled_assets)
        audit_secrets_and_private_fixtures(archive, names, app_root, report)

    return report.to_dict()


def check_source_evidence(report: AuditReport) -> None:
    orb = ROOT / "ios" / "JarvisXR" / "JarvisXR" / "Assets.xcassets" / "JarvisOrb.imageset" / "jarvis-orb.png"
    app_icon = ROOT / "ios" / "JarvisXR" / "JarvisXR" / "Assets.xcassets" / "AppIcon.appiconset"
    launch = ROOT / "ios" / "JarvisXR" / "JarvisXR" / "LaunchScreen.storyboard"
    intents = ROOT / "ios" / "JarvisXR" / "JarvisXR" / "JarvisAppIntents.swift"
    report.check(orb.is_file() and orb.stat().st_size > 0, "expected orb source asset exists", f"expected orb source asset is missing: {orb}")
    report.check(source_asset_set_has_files(app_icon), "AppIcon source asset set has nonempty PNG files", f"AppIcon source asset set is missing or empty: {app_icon}")
    report.check(launch.is_file() and launch.stat().st_size > 0, "LaunchScreen source exists", f"LaunchScreen source is missing: {launch}")
    if intents.is_file():
        source_text = intents.read_text(encoding="utf-8")
        for text in REQUIRED_INTENT_STRINGS:
            report.check(text in source_text, f"App Intent source string present: {text}", f"App Intent source string missing: {text}")
    else:
        report.failures.append(f"App Intents source is missing: {intents}")


def read_info_plist(archive: zipfile.ZipFile, names: list[str], app_root: str, report: AuditReport) -> dict[str, Any]:
    path = f"{app_root}/Info.plist"
    if path not in names:
        report.failures.append("Info.plist is missing from the app bundle")
        return {}
    try:
        info = plistlib.loads(archive.read(path))
    except Exception as exc:
        report.failures.append(f"Info.plist could not parse: {exc}")
        return {}
    report.passed.append("Info.plist exists and parses")
    return info


def audit_info_plist(info: dict[str, Any], report: AuditReport) -> None:
    display_name = info.get("CFBundleDisplayName")
    report.check(display_name == EXPECTED_DISPLAY_NAME, f"CFBundleDisplayName is {EXPECTED_DISPLAY_NAME}", f"unexpected CFBundleDisplayName: {display_name}")
    bundle_id = str(info.get("CFBundleIdentifier", ""))
    report.check(bundle_id == EXPECTED_BUNDLE_ID, f"bundle identifier is {EXPECTED_BUNDLE_ID}", f"unexpected bundle identifier: {bundle_id}")
    minimum_os = str(info.get("MinimumOSVersion", ""))
    report.check(minimum_os == EXPECTED_MINIMUM_OS_VERSION, f"MinimumOSVersion is {EXPECTED_MINIMUM_OS_VERSION}", f"MinimumOSVersion expected {EXPECTED_MINIMUM_OS_VERSION}, got {minimum_os or 'missing'}")
    report.check(info.get("UILaunchStoryboardName") == "LaunchScreen", "LaunchScreen is configured", "UILaunchStoryboardName is not LaunchScreen")
    for key in REQUIRED_PERMISSIONS:
        value = info.get(key)
        report.check(isinstance(value, str) and bool(value.strip()), f"{key} is present and nonempty", f"{key} is missing or empty")
    platforms = info.get("CFBundleSupportedPlatforms", [])
    report.check("iPhoneOS" in platforms, "bundle declares iPhoneOS platform", f"bundle is not an iPhoneOS device build: {platforms}")
    report.metadata.update(
        {
            "bundle_identifier": bundle_id,
            "minimum_os_version": minimum_os,
            "supported_platforms": platforms,
        }
    )


def audit_executable(archive: zipfile.ZipFile, names: list[str], app_root: str, info: dict[str, Any], report: AuditReport) -> None:
    executable_name = str(info.get("CFBundleExecutable", ""))
    executable_path = f"{app_root}/{executable_name}" if executable_name else ""
    if not executable_name or executable_path not in names:
        report.failures.append(f"application executable is missing: {executable_path or 'CFBundleExecutable not set'}")
        return
    executable = archive.read(executable_path)
    report.check(bool(executable), "application executable is nonempty", "application executable is empty")
    architectures = macho_architectures(executable)
    report.check("arm64" in architectures, "application executable contains arm64", f"application executable lacks arm64: {architectures}")
    report.check(not ({"x86", "x86_64"} & set(architectures)), "application executable contains no simulator architecture", f"simulator architecture found in device executable: {architectures}")
    report.metadata.update(
        {
            "executable": executable_name,
            "executable_size_bytes": len(executable),
            "executable_sha256": sha256_bytes(executable),
            "architectures": architectures,
        }
    )


def audit_unsigned_state(names: list[str], app_root: str, report: AuditReport) -> None:
    signature_entries = [name for name in names if name.startswith(f"{app_root}/_CodeSignature/")]
    provisioning = [name for name in names if name == f"{app_root}/embedded.mobileprovision"]
    report.check(not signature_entries, "no _CodeSignature is present, consistent with unsigned packaging", "unexpected code-signature resources are present")
    report.check(not provisioning, "no embedded provisioning profile is present", "unexpected embedded.mobileprovision is present")
    report.metadata["unsigned_packaging_consistent"] = not signature_entries and not provisioning


def audit_model_bundle(archive: zipfile.ZipFile, names: list[str], app_root: str, report: AuditReport) -> None:
    model_prefixes = sorted({name[: name.index(".mlmodelc/") + len(".mlmodelc")] for name in names if name.startswith(app_root + "/") and ".mlmodelc/" in name})
    expected_prefixes = [prefix for prefix in model_prefixes if PurePosixPath(prefix).name == EXPECTED_MODEL]
    report.check(len(expected_prefixes) == 1, f"compiled model resource present: {EXPECTED_MODEL}", f"expected exactly one {EXPECTED_MODEL}, found {len(expected_prefixes)}")
    raw_models = [name for name in names if name.startswith(app_root + "/") and name.endswith(".mlmodel")]
    report.check(not raw_models, "raw .mlmodel source is not packaged", "raw .mlmodel source was packaged instead of only compiled output")
    if expected_prefixes:
        prefix = expected_prefixes[0] + "/"
        files = sorted(name for name in names if name.startswith(prefix) and not name.endswith("/"))
        nonempty = [name for name in files if archive.getinfo(name).file_size > 0]
        report.check(bool(nonempty), "compiled model directory contains nonempty artifacts", "compiled model directory is empty")
        report.metadata["compiled_model_tree_sha256"] = archive_tree_sha256(archive, nonempty)
        report.metadata["compiled_model_file_count"] = len(nonempty)

    manifest_name = find_app_resource(names, app_root, EXPECTED_MODEL_MANIFEST)
    if not manifest_name:
        report.failures.append(f"model manifest is missing from app bundle: {EXPECTED_MODEL_MANIFEST}")
    else:
        try:
            manifest = json.loads(archive.read(manifest_name))
            manifest_failures = validate_manifest(manifest)
            report.failures.extend(f"bundled model manifest: {item}" for item in manifest_failures)
            if not manifest_failures:
                report.passed.append("bundled model manifest contract is valid")
            report.check(manifest.get("artifact", {}).get("sha256") == EXPECTED_SHA256, "bundled manifest contains pinned source SHA-256", "bundled manifest source SHA-256 is missing or unexpected")
            report.check(manifest.get("compiled_resource_name") == EXPECTED_MODEL, "bundled manifest names the compiled model resource", "bundled manifest compiled resource name is unexpected")
            report.metadata["source_model_sha256"] = manifest.get("artifact", {}).get("sha256")
            report.metadata["model_class_count"] = len(manifest.get("classes", []))
            report.metadata["model_license"] = manifest.get("license", {}).get("spdx_expression")
        except Exception as exc:
            report.failures.append(f"bundled model manifest could not parse: {exc}")

    notice_name = find_app_resource(names, app_root, EXPECTED_MODEL_NOTICE)
    report.check(bool(notice_name) and archive.getinfo(notice_name).file_size > 0, "model provenance notice is bundled", f"model provenance notice is missing or empty: {EXPECTED_MODEL_NOTICE}")


def audit_bundle_resources(
    archive: zipfile.ZipFile,
    names: list[str],
    app_root: str,
    report: AuditReport,
    inspect_compiled_assets: bool,
) -> None:
    launch = [name for name in names if name.startswith(app_root + "/") and "LaunchScreen" in name]
    report.check(bool(launch), "compiled LaunchScreen resource is present", "compiled LaunchScreen resource is missing")
    assets_name = f"{app_root}/Assets.car"
    report.check(assets_name in names and archive.getinfo(assets_name).file_size > 0, "Assets.car is present and nonempty", "Assets.car is missing or empty")
    if inspect_compiled_assets and assets_name in names:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "Assets.car"
            path.write_bytes(archive.read(assets_name))
            names_in_catalog = asset_catalog_names(path, report.warnings)
            if names_in_catalog:
                report.check("JarvisOrb" in names_in_catalog, "JarvisOrb is present in Assets.car", "JarvisOrb is missing from Assets.car")
                report.check(any("AppIcon" in name for name in names_in_catalog), "AppIcon is present in Assets.car", "AppIcon is missing from Assets.car")
            elif sys.platform == "darwin":
                report.failures.append("assetutil could not prove JarvisOrb and AppIcon in Assets.car")
            else:
                report.warnings.append("assetutil is unavailable; source asset evidence was used")

    bundled_docs = [name for name in names if name.startswith(app_root + "/") and PurePosixPath(name).suffix.lower() in FORBIDDEN_APP_DOC_SUFFIXES]
    report.check(not bundled_docs, "no Markdown or documentation source is bundled", "documentation source was copied into app bundle: " + ", ".join(bundled_docs[:8]))
    combined = read_text_payload(archive, names, app_root)
    intent_metadata = [name for name in names if name.startswith(app_root + "/") and any(token in name for token in ("AppIntents", "AppShortcuts", "ExtractedAppShortcutsMetadata"))]
    intents_seen = any(text in combined for text in REQUIRED_INTENT_STRINGS)
    report.check(bool(intent_metadata) or intents_seen, "App Intents metadata or readable strings are present", "App Intents metadata and readable strings are missing")
    if intents_seen:
        for text in REQUIRED_INTENT_STRINGS:
            report.check(text in combined, f"intent string present: {text}", f"intent string missing: {text}")
    for text in FORBIDDEN_PRODUCT_STRINGS:
        report.check(text not in combined, f"forbidden product string absent: {text}", f"forbidden product string found: {text}")
    for text in REQUIRED_HELP_STRINGS:
        report.check(text in combined, f"help wording present: {text}", f"required help wording missing: {text}")


def audit_secrets_and_private_fixtures(archive: zipfile.ZipFile, names: list[str], app_root: str, report: AuditReport) -> None:
    app_files = [name for name in names if name.startswith(app_root + "/") and not name.endswith("/")]
    suspicious_names = []
    private_fixtures = []
    content_hits = []
    for name in app_files:
        lowered = name.lower()
        base = PurePosixPath(lowered).name
        if base.startswith(".env") or base.endswith(SECRET_FILE_SUFFIXES) or "secret" in base:
            suspicious_names.append(name)
        if base in FORBIDDEN_FIXTURE_BASENAMES:
            private_fixtures.append(name)
        data = archive.read(name)
        if len(data) <= 20 * 1024 * 1024:
            for pattern in SECRET_CONTENT_PATTERNS:
                if pattern.search(data):
                    content_hits.append(f"{name}: {pattern.pattern.decode('ascii', errors='ignore')}")
    report.check(not suspicious_names, "no secret or credential filenames are bundled", "secret or credential filenames found: " + ", ".join(suspicious_names[:8]))
    report.check(not content_hits, "no recognizable API keys or private keys are bundled", "possible secret content found: " + ", ".join(content_hits[:8]))
    report.check(not private_fixtures, "test fixtures are absent from the shipping app bundle", "test fixtures were copied into the shipping app: " + ", ".join(private_fixtures))


def find_app_resource(names: list[str], app_root: str, basename: str) -> str | None:
    matches = [name for name in names if name.startswith(app_root + "/") and PurePosixPath(name).name == basename]
    return matches[0] if len(matches) == 1 else None


def read_text_payload(archive: zipfile.ZipFile, names: list[str], app_root: str) -> str:
    chunks: list[str] = []
    for name in names:
        if not name.startswith(app_root + "/") or name.endswith("/") or ".mlmodelc/" in name:
            continue
        data = archive.read(name)
        chunks.append(data.decode("utf-8", errors="ignore"))
    return "\n".join(chunks)


def is_unsafe_archive_path(name: str) -> bool:
    path = PurePosixPath(name)
    return path.is_absolute() or ".." in path.parts or "\\" in name


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def archive_tree_sha256(archive: zipfile.ZipFile, names: list[str]) -> str:
    digest = hashlib.sha256()
    for name in sorted(names):
        digest.update(name.encode("utf-8"))
        digest.update(b"\0")
        digest.update(archive.read(name))
        digest.update(b"\0")
    return digest.hexdigest()


def macho_architectures(data: bytes) -> list[str]:
    if len(data) < 8:
        return []
    magic = data[:4]
    thin_formats = {
        b"\xfe\xed\xfa\xce": ">",
        b"\xce\xfa\xed\xfe": "<",
        b"\xfe\xed\xfa\xcf": ">",
        b"\xcf\xfa\xed\xfe": "<",
    }
    if magic in thin_formats:
        cpu_type = struct.unpack(f"{thin_formats[magic]}I", data[4:8])[0]
        return [CPU_TYPES.get(cpu_type, f"cpu-{cpu_type:#x}")]
    fat_formats = {
        b"\xca\xfe\xba\xbe": (">", 20),
        b"\xbe\xba\xfe\xca": ("<", 20),
        b"\xca\xfe\xba\xbf": (">", 32),
        b"\xbf\xba\xfe\xca": ("<", 32),
    }
    if magic not in fat_formats:
        return []
    endian, entry_size = fat_formats[magic]
    count = struct.unpack(f"{endian}I", data[4:8])[0]
    if count > 32 or len(data) < 8 + count * entry_size:
        return []
    result = []
    for index in range(count):
        offset = 8 + index * entry_size
        cpu_type = struct.unpack(f"{endian}I", data[offset : offset + 4])[0]
        result.append(CPU_TYPES.get(cpu_type, f"cpu-{cpu_type:#x}"))
    return sorted(set(result))


def source_asset_set_has_files(path: Path) -> bool:
    contents = path / "Contents.json"
    if not contents.is_file():
        return False
    try:
        data = json.loads(contents.read_text(encoding="utf-8"))
    except Exception:
        return False
    filenames = [item.get("filename") for item in data.get("images", []) if item.get("filename")]
    return bool(filenames) and all((path / name).is_file() and (path / name).stat().st_size > 0 for name in filenames)


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
    return {str(item.get("Name") or item.get("AssetName")) for item in payload if item.get("Name") or item.get("AssetName")}


def main() -> int:
    parser = argparse.ArgumentParser(description="Audit a JARVIS unsigned device IPA and emit human and JSON evidence.")
    parser.add_argument("ipa", type=Path, help="Path to JarvisXR-unsigned.ipa")
    parser.add_argument("--json-output", type=Path, help="Write the complete machine-readable audit report")
    args = parser.parse_args()
    result = audit_ipa(args.ipa)
    if args.json_output:
        write_json(args.json_output, result)
    print("JARVIS IPA audit")
    for item in result["passed"]:
        print(f"PASS: {item}")
    for item in result["warnings"]:
        print(f"WARN: {item}")
    for item in result["failures"]:
        print(f"FAIL: {item}")
    print("JSON: " + json.dumps(result, sort_keys=True))
    return 0 if result["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
