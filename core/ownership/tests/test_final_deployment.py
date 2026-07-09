from __future__ import annotations

from pathlib import Path

from core.ownership.final_deployment import (
    get_appliance_mode_plan,
    get_do_not_jailbreak_warning,
    get_final_recommendation,
    get_native_build_decision_tree,
    get_xr_setup_steps,
)


ROOT = Path(__file__).resolve().parents[3]


def test_final_recommendation_says_do_not_jailbreak():
    recommendation = get_final_recommendation()
    assert recommendation["final_current_recommendation"] == "do not jailbreak this XR right now"


def test_final_recommendation_says_appliance_mode_chosen():
    recommendation = get_final_recommendation()
    assert recommendation["chosen_path"] == "Managed Jarvis Appliance Mode"
    assert recommendation["immediate_fallback"] == "Guided Access"


def test_xr_setup_steps_are_non_empty():
    steps = get_xr_setup_steps()
    assert steps
    assert all(items for items in steps.values())


def test_do_not_jailbreak_warning_contains_required_facts():
    warning = get_do_not_jailbreak_warning()
    assert warning["chip"] == "A12"
    assert warning["ios_version"] == "18.7.9"
    assert "unverified" in warning["unverified_tool_warning"].lower()


def test_appliance_mode_plan_exists():
    plan = get_appliance_mode_plan()
    assert "native Jarvis shell" in plan["required_before_real_use"]
    assert any("does not currently produce" in item for item in plan["limits"])


def test_native_build_decision_tree_includes_required_paths():
    tree = get_native_build_decision_tree()
    assert "mac_xcode_available" in tree
    assert "apple_configurator_available" in tree
    assert "only_windows_and_raspberry_pi_available" in tree


def test_release_freeze_file_exists():
    assert (ROOT / "RELEASE_FREEZE.md").exists()


def test_final_handoff_file_exists():
    assert (ROOT / "docs" / "FINAL_HANDOFF.md").exists()


def test_physical_setup_checklist_exists():
    assert (ROOT / "docs" / "XR_PHYSICAL_SETUP_CHECKLIST.md").exists()


def test_jarvis_identity_spec_exists():
    assert (ROOT / "docs" / "JARVIS_IDENTITY_SPEC.md").exists()
