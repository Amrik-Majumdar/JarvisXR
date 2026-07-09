from __future__ import annotations

import importlib.util
import sys
from pathlib import Path
import json


ROOT = Path(__file__).resolve().parents[1]
PREVIEW = ROOT / "preview" / "windows_jarvis_preview" / "jarvis_preview.py"
IOS_ROOT = ROOT / "ios" / "JarvisXR" / "JarvisXR"


def load_preview_module():
    spec = importlib.util.spec_from_file_location("jarvis_preview", PREVIEW)
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load preview module.")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def read(path: Path) -> str:
    return path.read_text(encoding="utf-8")


def main() -> int:
    preview = load_preview_module()
    root = read(IOS_ROOT / "JarvisRootViewController.swift")
    help_swift = read(IOS_ROOT / "JarvisHelpViewController.swift")
    router = read(IOS_ROOT / "JarvisCommandRouter.swift")
    planner = read(IOS_ROOT / "JarvisCommandPlan.swift")
    mesh = read(IOS_ROOT / "JarvisControlMeshPlanner.swift")
    mesh_view = read(IOS_ROOT / "JarvisControlMeshViewController.swift")
    camera = read(IOS_ROOT / "JarvisCameraViewController.swift")
    vision = read(IOS_ROOT / "JarvisVisionInterfaces.swift")
    app_intents = read(IOS_ROOT / "JarvisAppIntents.swift")
    preview_text = read(PREVIEW)
    voice = read(IOS_ROOT / "JarvisVoiceInputService.swift")
    state = read(IOS_ROOT / "JarvisInteractionState.swift")
    theme = read(IOS_ROOT / "JarvisTheme.swift")
    info_plist = read(IOS_ROOT / "Info.plist")
    project_yml = read(ROOT / "ios" / "JarvisXR" / "project.yml")
    workflow_yml = read(ROOT / ".github" / "workflows" / "ios-build.yml")
    ui_test = read(ROOT / "ios" / "JarvisXR" / "JarvisXRUITests" / "JarvisXRVisualProofTests.swift")
    run_tests_bat = read(ROOT / "dist" / "jarvis_local_approval_bundle" / "run_tests.bat")
    launch_screen = read(IOS_ROOT / "LaunchScreen.storyboard")
    orb_imageset = IOS_ROOT / "Assets.xcassets" / "JarvisOrb.imageset"
    app_icon_set = IOS_ROOT / "Assets.xcassets" / "AppIcon.appiconset"

    failures: list[str] = []

    def check(name: str, condition: bool) -> None:
        if not condition:
            failures.append(name)

    model = preview.InteractionModel()
    initial_surface = "\n".join(model.product_surface_texts())
    model.open_help()
    help_surface = "\n".join(model.product_surface_texts())
    model.close_help()
    model.open_mesh()
    mesh_surface = "\n".join(model.product_surface_texts())

    check("Swift help button exists", 'setTitle("?",' in root)
    check("Swift Mesh button exists", 'setTitle("Mesh"' in root)
    check("Preview exposes product-only mode", "--product-only" in preview_text and "Product-only view" in preview_text)
    check("Preview has Mesh sheet", "Control Mesh" in mesh_surface and "Voice Control" in mesh_surface)
    check("Help includes scan read detect Mesh", all(term in help_swift for term in ["scan this", "read this", "detect objects", "Control Mesh"]))
    check("Help avoids forbidden words", all(term not in help_swift.lower() for term in ["json", "debug", "approval gate", "test step"]))
    check("Phone surface avoids JSON", "JSON" not in initial_surface and "json" not in initial_surface.lower())
    check("Phone surface avoids guide/checklist text", all(term not in initial_surface.lower() for term in ["checklist", "approval", "should say ready"]))
    check("Keyboard keeps required controls", _keyboard_ok(preview))
    check("Orb flow works", _orb_flow_ok(preview))
    check("Speaking tap stops", _speaking_stop_ok(preview))
    check("Permission denied state exists", _state_contains(preview, "permission_denied", "permission"))
    check("No speech state exists", _state_contains(preview, "no_speech", "No speech heard"))
    check("Scan routes to inspection", preview.InteractionModel().process("scan this").state == "Inspection")
    check("Read routes to OCR", preview.InteractionModel().process("read this").action == "ocr")
    detect = preview.InteractionModel().process("detect objects")
    check("Detect objects routes to visual classification", detect.state == "Inspection" and "classification" in detect.display.lower())
    check("Go home routes to Control Mesh", preview.InteractionModel().process("go home").action == "control_mesh")
    check("Tap routes to grid", "show grid" in preview.InteractionModel().process("tap that").display.lower())
    check("Return route exists", "jarvis://standby" in mesh and "return to jarvis" in mesh.lower())
    check("Vision fallback is real and not model-dead-ended", "VNClassifyImageRequest" in camera and "Visual scan ready" in vision and "Object model not installed" not in vision + router + camera)
    check("Inspection speaks scan results when enabled", "speakInspectionSummary" in camera and "JarvisSpeechService.shared.isEnabled" in camera and "JarvisSpeechService.shared.speak" in camera)
    settings = read(IOS_ROOT / "JarvisSettingsViewController.swift")
    speech = read(IOS_ROOT / "JarvisSpeechService.swift")
    check("Settings buttons route to real actions", all(term in settings for term in [
        "clearNotesButton.addTarget",
        "clearHistoryButton.addTarget",
        "voiceTestButton.addTarget",
        "profilePreviewButton.addTarget",
        "personalVoiceButton.addTarget",
        "aboutButton.addTarget",
    ]))
    check("Control Mesh buttons route through real deep links", all(term in mesh_view for term in [
        "inspectButton.addTarget",
        "quietButton.addTarget",
        "voiceButton.addTarget",
        "JarvisDeepLinkRouter.post(.inspect)",
        "JarvisDeepLinkRouter.post(.command(\"quiet mode\"))",
        "JarvisDeepLinkRouter.post(.command(\"voice test\"))",
    ]))
    check("Voice profiles persist and affect speech parameters", all(term in speech for term in [
        "profileKey",
        "UserDefaults.standard.set(newValue.rawValue",
        "utterance.rate = speechRate(for:",
        "utterance.pitchMultiplier = pitch(for:",
        "utterance.volume = volume(for:",
    ]))
    check("No Recent Activity in product sources", "Recent Activity" not in root)
    check("No response panel label", "JARVIS RESPONSE" not in root)
    check("No debug chips", all(term not in root for term in ["Wi-Fi path available", "offline tools remain", "guided ready"]))
    check("No product-facing XR in root", "XR" not in root.replace("JarvisXRLayoutModel", "").replace("iPhone XR keyboard", ""))
    check("No WebView stack", all(term not in root + help_swift + router + camera for term in ["WebView", "WKWebView"]))
    check("No private implementation strings", all(term not in root + router + camera for term in ["UIApplication.shared.perform", "LSApplicationWorkspace", "SpringBoardServices"]))
    check("JarvisOrb imageset exists", orb_imageset.exists())
    check("JarvisOrb contents references real files", _imageset_has_real_files(orb_imageset))
    check("Root orb uses bundled asset with fallback", 'UIImage(named: "JarvisOrb")' in theme and "JarvisOrbView" in root + theme)
    check("LaunchScreen storyboard source exists", 'launchScreen="YES"' in launch_screen and "JARVIS" in launch_screen)
    check("AppIcon assets exist", app_icon_set.exists() and _imageset_has_real_files(app_icon_set))
    check("Product source does not expose Blocked label", '"Blocked"' not in root + theme + state + preview_text)
    check("Product Swift does not keep blocked state case", "case blocked" not in root + state + planner)
    check("Tap and long press are separate recognizers", "UITapGestureRecognizer" in root and "UILongPressGestureRecognizer" in root and "tap.require(toFail: longPress)" in root)
    check("Long press returns standby", "enterStandbyFromLongPress" in root and "voiceInput.stopListening(process: false)" in root)
    check("Manual listening stop processes transcript", "voiceInput.stopListening(process: true)" in root and "onFinalTranscript" in voice)
    check("No speech returns ready", "case .noSpeech:" in root and "setInterfaceState(.ready, hint: \"No speech heard.\")" in root)
    check("Ready state label matches UI proof", 'case ready = "Ready"' in state and 'waitForState("Ready")' in ui_test)
    check("Real UIKit layout uses keyboardLayoutGuide", "keyboardLayoutGuide.topAnchor" in root and "keyboardWillChangeFrameNotification" not in root)
    check("Real UIKit source avoids copied preview layout model", "JarvisXRLayoutModel" not in root + state)
    check("Launch screen configured", "UILaunchStoryboardName" in info_plist and "LaunchScreen" in info_plist and "path: JarvisXR" in project_yml and "LaunchScreen.storyboard" not in project_yml)
    check("Markdown model notes excluded from app bundle", "Models/README.md" in project_yml)
    check("No primary Spotify music example", "Try: open Spotify" not in root + help_swift + preview_text and "play music" not in help_swift)
    check("Required App Intents source strings exist", all(text in app_intents for text in [
        "Start JARVIS Inspection",
        "Open JARVIS Control Mesh",
        "Return to JARVIS",
        "Run JARVIS Command",
        "Set JARVIS Quiet Mode",
        "Set JARVIS Normal Mode",
    ]))
    check("UI test target configured", "JarvisXRUITests" in project_yml and "bundle.ui-testing" in project_yml)
    check("UI test target has TEST_TARGET_NAME", "TEST_TARGET_NAME: JarvisXR" in project_yml)
    check("UI test launch args are handled by app and camera", "--jarvis-ui-test" in ui_test and "--jarvis-ui-test" in root and "--jarvis-ui-test" in camera)
    check("UI screenshot test reads VISUAL_PROOF_DIR", "VISUAL_PROOF_DIR" in ui_test and "pngRepresentation.write" in ui_test)
    check("UI screenshot test asserts file size", "attributesOfItem" in ui_test and "XCTAssertGreaterThan" in ui_test)
    check("UI screenshot test cannot silently skip output", "else { return }" not in ui_test and "XCTSkip" not in ui_test)
    check("UI screenshot test debugs failures", "failure-current-screen" in ui_test and "app.debugDescription" in ui_test)
    check("UI screenshot test has exact required screenshot names", all(f'"{name}"' in ui_test for name in [
        "standby",
        "ready",
        "listening",
        "processing",
        "no-speech",
        "long-hold-standby",
        "keyboard",
        "help",
        "mesh",
        "inspection",
        "object-model-missing",
        "settings",
        "diagnostics",
    ]))
    check("Workflow captures required iOS screenshots", "Capture required iOS screenshots" in workflow_yml and "VISUAL_PROOF_DIR" in workflow_yml and "verify_visual_proof.py" in workflow_yml)
    check("Workflow uploads screenshot artifact", "JarvisXR-ios-screenshot-proof" in workflow_yml and "if-no-files-found: error" in workflow_yml)
    check("Workflow fails if simulator is missing", "Screenshot proof cannot be generated" in workflow_yml and "exit 1" in workflow_yml)
    check("Workflow uploads debug artifacts on failure", "if: always()" in workflow_yml and "JarvisXR-build-output" in workflow_yml and "visual-proof-filesystem-debug.log" in workflow_yml)
    check("Workflow preserves xcresult bundles", ".xcresult" in workflow_yml and "xcodebuild-visual-proof.log" in workflow_yml)
    check("Workflow prints selected destination", "Using xcodebuild destination" in workflow_yml and "--destination" in workflow_yml)
    check("Workflow runs IPA audit against produced IPA", "tools/audit_ipa.py ios/JarvisXR/build/JarvisXR-unsigned.ipa" in workflow_yml)
    check("Workflow saves required named logs", all(name in workflow_yml for name in [
        "environment.txt",
        "xcode-version.txt",
        "simulator-list-before.txt",
        "simulator-list-after-boot.txt",
        "selected-simulator.txt",
        "xcodegen.log",
        "xcodebuild-build.log",
        "xcodebuild-unit-test.log",
        "xcodebuild-visual-proof.log",
        "visual-proof-filesystem-debug.log",
        "ipa-audit.log",
        "artifact-tree.txt",
    ]))
    check("Local run_tests compiles helper scripts", "python -m py_compile" in run_tests_bat and "tools\\audit_ipa.py" in run_tests_bat and "tools\\verify_visual_proof.py" in run_tests_bat)

    if failures:
        print("JARVIS product surface test failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print("JARVIS product surface test passed:")
    print("- Swift help and Mesh controls exist")
    print("- Help, Mesh, preview, planner, vision, and routing checks passed")
    print("- Product surface avoids forbidden debug/report UI")
    return 0


def _keyboard_ok(preview) -> bool:
    model = preview.InteractionModel()
    model.toggle_keyboard()
    layout = model.layout()
    return (
        layout.compact
        and layout.input_top + preview.INPUT_HEIGHT < preview.PHONE_HEIGHT - preview.SAFE_BOTTOM - preview.KEYBOARD_HEIGHT
        and layout.help_bounds[1] >= preview.SAFE_TOP
        and layout.menu_bounds[1] >= preview.SAFE_TOP
    )


def _orb_flow_ok(preview) -> bool:
    model = preview.InteractionModel()
    return model.orb_tap() == "JARVIS ready" and model.orb_tap() == "Listening" and model.orb_tap() in {"Inspection", "Done", "JARVIS ready"}


def _speaking_stop_ok(preview) -> bool:
    model = preview.InteractionModel()
    model.speaking()
    return model.orb_tap() == "JARVIS ready"


def _state_contains(preview, method_name: str, expected: str) -> bool:
    model = preview.InteractionModel()
    getattr(model, method_name)()
    return expected.lower() in "\n".join(model.product_surface_texts()).lower()


def _imageset_has_real_files(path: Path) -> bool:
    contents = path / "Contents.json"
    if not contents.exists():
        return False
    try:
        data = json.loads(contents.read_text(encoding="utf-8"))
    except Exception:
        return False
    filenames = [item.get("filename") for item in data.get("images", []) if item.get("filename")]
    return bool(filenames) and all((path / name).exists() and (path / name).stat().st_size > 0 for name in filenames)


if __name__ == "__main__":
    raise SystemExit(main())
