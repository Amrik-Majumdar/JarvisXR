from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from core.daemon.protocol import make_response, validate_request, validate_response
from core.daemon.request_log import RequestLog
from core.daemon.service_state import ServiceState
from core.adapters import AdapterRegistry
from core.device_profiles import compare_device_profiles, get_active_profile, get_device_mode_strategy
from core.ownership import (
    OwnershipController,
    explain_what_blocks_true_ownership,
    explain_why_not_just_an_app,
    get_recommended_takeover_path,
    get_takeover_levels,
    get_true_ownership_requirements,
    get_appliance_mode_plan,
    get_do_not_jailbreak_warning,
    get_final_recommendation,
    get_native_build_decision_tree,
    get_xr_setup_steps,
    list_appliance_mode_steps,
    list_jailbreak_only_features,
    list_supervision_features,
)
from core.router.command_router import CommandRouter
from core.router.intent_matcher import related_to
from core.router.local_memory import LocalMemory
from core.router.modes import Availability


class JarvisService:
    def __init__(
        self,
        registry_path: Path | str | None = None,
        memory_path: Path | str | None = None,
        log_path: Path | str | None = None,
        state: ServiceState | None = None,
    ):
        self.registry_path = Path(registry_path) if registry_path else ROOT / "core" / "registry" / "capabilities.json"
        self.memory = LocalMemory(memory_path)
        self.state = state or ServiceState()
        self.log = RequestLog(log_path)
        self.adapters = AdapterRegistry.mock_for_phone(self.state.phone.snapshot())
        self.ownership = OwnershipController()
        self.router = self._make_router()

    def _make_router(self) -> CommandRouter:
        return CommandRouter(
            self.registry_path,
            Availability.from_phone_state(self.state.phone.snapshot()),
            self.state.phone,
            self.memory,
            self.adapters,
        )

    def handle(self, request: dict) -> dict:
        errors = validate_request(request)
        if errors:
            return make_response(
                str(request.get("request_id", "invalid")),
                "error",
                self.state.mode,
                "Request rejected.",
                "Invalid request shape.",
                {"errors": errors},
                unavailable_reason="invalid request",
            )
        request_id = request["request_id"]
        logs = [self.log.write(request_id, "request_received", {"type": request["type"]})]
        try:
            response = self._dispatch(request, logs)
        except Exception as exc:
            logs.append(self.log.write(request_id, "request_error", {"error": str(exc)}))
            response = make_response(
                request_id,
                "error",
                self.state.mode,
                "Jarvis service error.",
                str(exc),
                {"error": str(exc)},
                unavailable_reason=str(exc),
                logs_written=logs,
            )
        response_errors = validate_response(response)
        if response_errors:
            return make_response(
                request_id,
                "error",
                self.state.mode,
                "Jarvis produced an invalid response.",
                "Response schema validation failed.",
                {"errors": response_errors, "response": response},
                unavailable_reason="invalid response",
                logs_written=logs,
            )
        return response

    def _dispatch(self, request: dict, logs: list[str]) -> dict:
        request_type = request["type"]
        request_id = request["request_id"]
        if request_type == "health_check":
            return self._response(request_id, "ok", "Jarvis daemon harness is alive.", "Jarvis service healthy.", {"service": "jarvis_core_v0_3"}, logs)
        if request_type == "route_command":
            return self._route(request, logs, execute=False)
        if request_type == "execute_command":
            return self._execute(request, logs, confirmed=bool(request.get("confirmed")))
        if request_type == "list_capabilities":
            return self._response(request_id, "ok", "Capability registry loaded.", "All capabilities returned.", {"capabilities": self.router.capabilities}, logs)
        if request_type == "list_offline_capabilities":
            caps = [cap for cap in self.router.capabilities if cap["mode"] in {"offline", "hybrid"}]
            return self._response(request_id, "ok", f"{len(caps)} offline-capable tools available.", "Offline capabilities returned.", {"capabilities": caps}, logs)
        if request_type == "list_related_capabilities":
            topic = request.get("topic") or request.get("query") or ""
            caps = [cap for cap in self.router.capabilities if related_to(topic, cap)]
            return self._response(request_id, "ok", f"{len(caps)} related tools found.", f"Related capabilities for {topic}.", {"capabilities": caps[:50]}, logs)
        if request_type == "get_phone_state":
            return self._response(request_id, "ok", "Phone state loaded.", "Mock phone state returned.", {"phone_state": self.state.phone.snapshot()}, logs)
        if request_type == "update_mock_phone_state":
            state = self.state.set_profile(request.get("profile", "offline"))
            self.adapters.refresh_from_phone(self.state.phone)
            self.router.update_phone_state(state)
            self.router.adapters = self.adapters
            return self._response(request_id, "ok", f"Mock profile set to {request.get('profile')}.", "Mock phone state updated.", {"phone_state": state}, logs)
        if request_type == "save_note":
            item = self.memory.save_note(request.get("text", ""), {"source": "daemon_request"})
            return self._response(request_id, "ok", "Note saved.", "Local memory note saved.", {"memory_item": item}, logs)
        if request_type == "search_memory":
            results = self.memory.search(request.get("query", ""))
            return self._response(request_id, "ok", f"I found {len(results)} memory matches.", "Memory search completed.", {"results": results}, logs)
        if request_type == "export_memory_summary":
            return self._response(request_id, "ok", "Memory summary ready.", "Memory summary exported.", {"summary": self.memory.summary()}, logs)
        if request_type == "request_confirmation":
            return self._request_confirmation(request, logs)
        if request_type == "confirm_and_execute":
            return self._confirm_and_execute(request, logs)
        if request_type == "set_mode":
            return self._set_mode(request, logs)
        if request_type == "get_mode":
            return self._response(request_id, "ok", f"Current mode is {self.state.mode}.", "Mode returned.", {"mode": self.state.mode}, logs)
        if request_type == "get_recent_history":
            return self._response(request_id, "ok", "Recent history loaded.", "Recent memory history returned.", {"history": self.memory.history()}, logs)
        if request_type == "get_device_profile":
            return self._response(request_id, "ok", "Active device profile loaded.", "Active device profile returned.", {"device_profile": get_active_profile()}, logs)
        if request_type == "compare_device_profiles":
            return self._response(request_id, "ok", "Device profile comparison ready.", "Compared active XR profile with preserved iPhone 6 lane.", {"comparison": compare_device_profiles()}, logs)
        if request_type == "get_device_mode_strategy":
            return self._response(request_id, "ok", "Jarvis Device Mode strategy loaded.", "Device Mode strategy returned.", {"strategy": get_device_mode_strategy()}, logs)
        if request_type == "get_spotify_strategy":
            return self._response(request_id, "ok", "Spotify strategy loaded.", "Spotify strategy returned.", {"spotify_strategy": self._spotify_strategy()}, logs)
        if request_type == "list_media_capabilities":
            return self._response(request_id, "ok", "Media capabilities listed.", "Media capabilities returned.", {"media_capabilities": self._media_capabilities()}, logs)
        if request_type == "get_ownership_modes":
            return self._response(request_id, "ok", "Ownership modes loaded.", "Ownership modes returned.", {"ownership_modes": self.ownership.list_modes()}, logs)
        if request_type == "set_ownership_mode":
            ok, message, mode = self.ownership.set_mode(request.get("mode", ""))
            status = "ok" if ok else "refused"
            return self._response(request_id, status, message, message, {"ownership_mode": mode}, logs, unavailable_reason=None if ok else message)
        if request_type == "get_current_ownership_mode":
            return self._response(request_id, "ok", "Current ownership mode loaded.", "Current ownership mode returned.", {"ownership_mode": self.ownership.get_current_mode()}, logs)
        if request_type == "list_blocked_ownership_features":
            blocked = self.ownership.list_blocked_features()
            return self._response(request_id, "ok", f"{len(blocked)} ownership features are blocked in the current mode.", "Blocked ownership features returned.", {"blocked_features": blocked, "ownership_mode": self.ownership.get_current_mode()}, logs)
        if request_type == "get_takeover_levels":
            return self._response(request_id, "ok", "Device takeover levels loaded.", "Device takeover feasibility levels returned.", {"takeover_levels": get_takeover_levels()}, logs)
        if request_type == "get_true_ownership_requirements":
            return self._response(request_id, "ok", "True ownership requirements loaded.", "True ownership requirements returned.", {"requirements": get_true_ownership_requirements()}, logs)
        if request_type == "get_recommended_takeover_path":
            return self._response(request_id, "ok", "Recommended takeover path loaded.", "Recommended takeover path returned.", {"recommended_path": get_recommended_takeover_path()}, logs)
        if request_type == "explain_why_not_just_an_app":
            return self._response(request_id, "ok", "A normal app is not enough.", "Normal app limitation explanation returned.", {"explanation": explain_why_not_just_an_app()}, logs)
        if request_type == "explain_what_blocks_true_ownership":
            return self._response(request_id, "ok", "True ownership blockers loaded.", "True ownership blockers returned.", {"blockers": explain_what_blocks_true_ownership()}, logs)
        if request_type == "list_jailbreak_only_features":
            return self._response(request_id, "ok", "Jailbreak-only features listed.", "Jailbreak-only features returned.", {"features": list_jailbreak_only_features()}, logs)
        if request_type == "list_supervision_features":
            return self._response(request_id, "ok", "Supervision features listed.", "Supervision features returned.", {"features": list_supervision_features()}, logs)
        if request_type == "list_appliance_mode_steps":
            return self._response(request_id, "ok", "Appliance mode steps listed.", "Appliance mode steps returned.", {"steps": list_appliance_mode_steps()}, logs)
        if request_type == "get_final_recommendation":
            return self._response(request_id, "ok", "Final XR recommendation loaded.", "Final XR recommendation returned.", {"final_recommendation": get_final_recommendation()}, logs)
        if request_type == "get_xr_setup_steps":
            return self._response(request_id, "ok", "XR setup steps loaded.", "XR setup steps returned.", {"setup_steps": get_xr_setup_steps()}, logs)
        if request_type == "get_do_not_jailbreak_warning":
            return self._response(request_id, "ok", "Do not jailbreak warning loaded.", "Do not jailbreak warning returned.", {"warning": get_do_not_jailbreak_warning()}, logs)
        if request_type == "get_appliance_mode_plan":
            return self._response(request_id, "ok", "Appliance mode plan loaded.", "Appliance mode plan returned.", {"appliance_mode_plan": get_appliance_mode_plan()}, logs)
        if request_type == "get_native_build_decision_tree":
            return self._response(request_id, "ok", "Native build decision tree loaded.", "Native build decision tree returned.", {"native_build_decision_tree": get_native_build_decision_tree()}, logs)
        return self._response(request_id, "error", "Unknown request.", "Unknown request type.", {}, logs, unavailable_reason="unknown request")

    def _spotify_strategy(self) -> dict:
        mode = self.ownership.get_current_mode()
        return {
            "installed": True,
            "offline_behavior": "Only Spotify content already downloaded inside Spotify can work without Wi-Fi.",
            "online_behavior": "Wi-Fi enables search, streaming, links, and richer Spotify handoff investigation.",
            "hard_ownership_mode": {
                "mode": "supervised_kiosk_mode",
                "external_spotify_open_allowed": False,
                "status": "optional module only, limited or unavailable in hard takeover modes",
            },
            "soft_ownership_mode": {
                "external_spotify_open_allowed": True,
                "status": "secondary utility only, not device identity",
            },
            "current_ownership_mode": mode,
            "control_options": [
                "open Spotify content links from Jarvis",
                "investigate Spotify iOS SDK or App Remote",
                "investigate Shortcuts or Siri bridge as a convenience only",
                "use external app handoff only as a secondary utility",
            ],
            "honesty_boundary": "Spotify playback control remains unverified and is not claimed until tested on the XR.",
        }

    def _media_capabilities(self) -> list[dict]:
        mode = self.ownership.get_current_mode()
        return [
            {
                "id": "media_spotify_handoff",
                "name": "Open Spotify through Jarvis",
                "availability": "mode_dependent",
                "spotify_can_open_now": bool(mode.get("spotify_can_open")),
                "requires_wifi": "for non-downloaded content",
                "requires_device_test": True,
            },
            {
                "id": "media_spotify_downloaded_content",
                "name": "Use downloaded Spotify content",
                "availability": "uncertain_needs_device_test",
                "spotify_can_open_now": bool(mode.get("spotify_can_open")),
                "requires_wifi": False,
                "requires_device_test": True,
            },
            {
                "id": "media_browser_search",
                "name": "Controlled browser or search flow",
                "availability": "online_native",
                "browser_can_open_now": bool(mode.get("browser_can_open")),
                "requires_wifi": True,
                "requires_device_test": True,
            },
        ]

    def _route(self, request: dict, logs: list[str], execute: bool) -> dict:
        command = request.get("command", "")
        result = self.router.route(command, confirmed=False)
        logs.append(self.log.write(request["request_id"], "command_routed", {"status": result.get("status")}))
        return self._router_response(request["request_id"], result, logs, execute=execute)

    def _execute(self, request: dict, logs: list[str], confirmed: bool = False) -> dict:
        command = request.get("command", "")
        preliminary = self.router.route(command, confirmed=False)
        risk = preliminary.get("risk_level", "low")
        if preliminary.get("requires_confirmation") and not confirmed:
            token = self.state.confirmations.create(request, risk)
            preliminary["execution"]["confirmation_token"] = token["token"]
            preliminary["execution"]["data"]["confirmation_token"] = token["token"]
            logs.append(self.log.write(request["request_id"], "confirmation_token_created", {"token": token["token"]}))
            return self._router_response(request["request_id"], preliminary, logs, execute=True)
        result = self.router.route(command, confirmed=confirmed)
        self._apply_execution_side_effects(result)
        logs.append(self.log.write(request["request_id"], "command_executed", {"status": result.get("status")}))
        return self._router_response(request["request_id"], result, logs, execute=True)

    def _request_confirmation(self, request: dict, logs: list[str]) -> dict:
        command = request.get("command", "")
        result = self.router.route(command, confirmed=False)
        token = self.state.confirmations.create({"type": "execute_command", "request_id": request["request_id"], "command": command, "confirmed": True}, result.get("risk_level", "medium"))
        logs.append(self.log.write(request["request_id"], "confirmation_token_created", {"token": token["token"]}))
        return self._response(
            request["request_id"],
            "confirmation_required",
            "Confirmation token created.",
            "Confirmation required before execution.",
            {"confirmation_token": token["token"], "route": result},
            logs,
            risk_level=result.get("risk_level", "medium"),
            requires_confirmation=True,
            candidate_capabilities=result.get("alternates", []),
        )

    def _confirm_and_execute(self, request: dict, logs: list[str]) -> dict:
        token = request.get("confirmation_token", "")
        ok, record, reason = self.state.confirmations.consume(token)
        if not ok:
            logs.append(self.log.write(request["request_id"], "confirmation_refused", {"reason": reason}))
            return self._response(request["request_id"], "refused", reason or "Confirmation refused.", reason or "Confirmation refused.", {"token": token}, logs, unavailable_reason=reason)
        stored_request = dict(record["request"])
        stored_request["request_id"] = request["request_id"]
        stored_request["confirmed"] = True
        logs.append(self.log.write(request["request_id"], "confirmation_accepted", {"token": token}))
        return self._execute(stored_request, logs, confirmed=True)

    def _apply_execution_side_effects(self, result: dict) -> None:
        capability = result.get("capability") or {}
        execution = result.get("execution") or {}
        data = execution.get("data") or {}
        if result.get("status") == "ok" and (data.get("private_mode") or capability.get("id") in {"jarvis_modes_009", "security_privacy_013"}):
            self.state.phone.set_flag("private", True)
            self.adapters.refresh_from_phone(self.state.phone)
            self.router.update_phone_state(self.state.phone.snapshot())
            self.router.adapters = self.adapters

    def _set_mode(self, request: dict, logs: list[str]) -> dict:
        ok, message = self.state.mode_engine.set_mode(request.get("mode", ""), override=bool(request.get("payload", {}).get("override")))
        status = "ok" if ok else "refused"
        logs.append(self.log.write(request["request_id"], "mode_transition", {"status": status, "mode": request.get("mode")}))
        return self._response(request["request_id"], status, message, message, {"mode": self.state.mode}, logs, unavailable_reason=None if ok else message)

    def _router_response(self, request_id: str, result: dict, logs: list[str], execute: bool) -> dict:
        capability = result.get("capability") or {}
        execution = result.get("execution") or {}
        status = result.get("status", "error")
        if status == "unmatched":
            status = "refused"
        return make_response(
            request_id,
            status,
            self.state.mode,
            execution.get("spoken_response") or result.get("message", ""),
            execution.get("display_response") or result.get("message", ""),
            {"route": result, "executed": execute, "handler_data": execution.get("data", {})},
            risk_level=result.get("risk_level", capability.get("risk_level", "low")),
            requires_confirmation=bool(result.get("requires_confirmation")),
            unavailable_reason=result.get("unavailable_reason"),
            candidate_capabilities=result.get("candidates") or result.get("alternates") or [],
            logs_written=logs + execution.get("logs", []),
        )

    def _response(
        self,
        request_id: str,
        status: str,
        spoken: str,
        display: str,
        data: dict,
        logs: list[str],
        risk_level: str = "low",
        requires_confirmation: bool = False,
        unavailable_reason: str | None = None,
        candidate_capabilities: list | None = None,
    ) -> dict:
        return make_response(
            request_id,
            status,
            self.state.mode,
            spoken,
            display,
            data,
            risk_level=risk_level,
            requires_confirmation=requires_confirmation,
            unavailable_reason=unavailable_reason,
            candidate_capabilities=candidate_capabilities or [],
            logs_written=logs,
        )


def stdio_loop(service: JarvisService) -> int:
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue
        try:
            request = json.loads(line)
            response = service.handle(request)
        except json.JSONDecodeError as exc:
            response = make_response("invalid-json", "error", service.state.mode, "Invalid JSON.", str(exc), {"error": str(exc)}, unavailable_reason="invalid json")
        print(json.dumps(response, sort_keys=True), flush=True)
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Jarvis Core v0.3 daemon service harness")
    parser.add_argument("--stdio", action="store_true", help="Read JSON requests from stdin and write JSON responses to stdout")
    parser.add_argument("--memory", default=None, help="SQLite memory path")
    parser.add_argument("--log", default=None, help="JSONL request log path")
    return parser


def main() -> int:
    args = build_parser().parse_args()
    service = JarvisService(memory_path=args.memory, log_path=args.log)
    if args.stdio:
        return stdio_loop(service)
    print(json.dumps(service.handle({"type": "health_check", "request_id": "manual-health"}), indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
