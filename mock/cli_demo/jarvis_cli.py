from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))

from core.router.command_router import CommandRouter
from core.router.local_memory import LocalMemory
from core.router.modes import Availability
from mock.phone_state import MockPhoneState, phone_state


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="JarvisOS iPhone 6 command router prototype")
    parser.add_argument("command", nargs="*", help="Typed command to route")
    parser.add_argument("--online", action="store_true", help="Simulate online mode")
    parser.add_argument("--dock", action="store_true", help="Simulate dock mode")
    parser.add_argument("--profile", default="offline", help="Mock phone profile")
    parser.add_argument("--state", action="store_true", help="Print mock phone state")
    parser.add_argument("--interactive", action="store_true", help="Start an interactive Jarvis prototype session")
    parser.add_argument("--confirm", action="store_true", help="Confirm a risky command in one-shot mode")
    parser.add_argument("--memory", default=str(ROOT / "work_memory.sqlite"), help="SQLite memory path")
    return parser


def render_result(result: dict, spoken: bool = True) -> str:
    lines = [
        f"status: {result.get('status')}",
        f"command: {result.get('command', '')}",
    ]
    capability = result.get("capability")
    if capability:
        lines.extend(
            [
                f"capability: {capability['id']} | {capability['name']}",
                f"mode: {result.get('mode')} | risk: {result.get('risk_level')} | confidence: {result.get('confidence')}",
            ]
        )
    if result.get("unavailable_reason"):
        lines.append(f"unavailable: {result['unavailable_reason']}")
    execution = result.get("execution")
    if execution:
        if spoken:
            lines.append(f"spoken: {execution['spoken_response']}")
        lines.append(f"display: {execution['display_response']}")
    elif result.get("message"):
        lines.append(result["message"])
    if result.get("low_confidence"):
        lines.append("candidates:")
        for candidate in result.get("candidates", []):
            lines.append(f"  {candidate['confidence']}: {candidate['id']} | {candidate['name']}")
    return "\n".join(lines)


def create_router(args: argparse.Namespace, state: MockPhoneState | None = None) -> CommandRouter:
    phone = state or MockPhoneState(args.profile)
    if args.online:
        phone.set_flag("online", True)
        phone.set_flag("wifi", True)
    if args.dock:
        phone.set_flag("dock", True)
        phone.set_flag("online", True)
        phone.set_flag("wifi", True)
    registry_path = ROOT / "core" / "registry" / "capabilities.json"
    memory = LocalMemory(args.memory)
    return CommandRouter(registry_path, Availability.from_phone_state(phone.snapshot()), phone, memory)


def interactive_session(args: argparse.Namespace) -> int:
    phone = MockPhoneState(args.profile)
    router = create_router(args, phone)
    print("Jarvis Core v0.2 interactive prototype. Type help for commands, exit to quit.")
    while True:
        try:
            raw = input("jarvis> ").strip()
        except EOFError:
            print()
            return 0
        if not raw:
            continue
        lowered = raw.lower()
        if lowered in {"exit", "quit"}:
            return 0
        if lowered == "help":
            print("Commands: mode, state, history, offline tools, profile <name>, set <flag> on|off, save note <text>, search memory <text>, confirm <command>")
            continue
        if lowered == "mode":
            print(json.dumps(phone.snapshot()["network"], indent=2))
            continue
        if lowered == "state":
            print(json.dumps(phone.snapshot(), indent=2))
            continue
        if lowered == "history":
            print(json.dumps(router.memory.history(), indent=2))
            continue
        if lowered == "offline tools":
            print(render_result(router.route("show offline tools"), spoken=False))
            continue
        if lowered.startswith("profile "):
            profile = raw.split(" ", 1)[1].strip()
            try:
                phone.apply_profile(profile)
                router.update_phone_state(phone.snapshot())
                print(f"profile: {profile}")
            except ValueError as exc:
                print(str(exc))
            continue
        if lowered.startswith("set "):
            parts = lowered.split()
            if len(parts) == 3 and parts[2] in {"on", "off"}:
                try:
                    phone.set_flag(parts[1], parts[2] == "on")
                    router.update_phone_state(phone.snapshot())
                    print(f"{parts[1]}: {parts[2]}")
                except ValueError as exc:
                    print(str(exc))
            else:
                print("Use: set <flag> on|off")
            continue
        confirmed = False
        command = raw
        if lowered.startswith("confirm "):
            confirmed = True
            command = raw.split(" ", 1)[1].strip()
        result = router.route(command, confirmed=confirmed)
        print(render_result(result))


def main() -> int:
    parser = build_parser()
    args = parser.parse_args()
    if args.interactive:
        return interactive_session(args)
    if args.state:
        print(json.dumps(phone_state(args.profile), indent=2))
        return 0

    command = " ".join(args.command).strip()
    if not command:
        parser.print_help()
        return 0

    router = create_router(args)
    result = router.route(command, confirmed=args.confirm)
    print(json.dumps(result, indent=2))
    return 0 if result["status"] in {"ok", "unavailable", "unmatched", "confirmation_required"} else 1


if __name__ == "__main__":
    raise SystemExit(main())
