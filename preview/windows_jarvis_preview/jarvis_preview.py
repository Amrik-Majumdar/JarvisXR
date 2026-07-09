"""Windows product preview for the native JARVIS iPhone app.

The phone canvas models the final product surface. The controls beside it are
an external harness for local review before the next iPhone build.
"""

from __future__ import annotations

import argparse
import datetime as dt
import math
from dataclasses import dataclass
from pathlib import Path
from typing import Callable


APP_DIR = Path(__file__).resolve().parent
ROOT_DIR = APP_DIR.parents[1]
BUNDLE_DIR = ROOT_DIR / "dist" / "jarvis_local_approval_bundle"
DEVELOPER_REPORT = BUNDLE_DIR / "preview_developer_report.txt"
VISUAL_REVIEW_DIR = ROOT_DIR / "dist" / "production_visual_review"
ORB_ASSET = APP_DIR / "assets" / "jarvis_orb_reference.png"
LONG_HOLD_SECONDS = 0.72

PHONE_WIDTH = 414
PHONE_HEIGHT = 896
SAFE_TOP = 47
SAFE_BOTTOM = 34
KEYBOARD_HEIGHT = 336
INPUT_HEIGHT = 58

COLORS = {
    "page": "#010304",
    "phone": "#030608",
    "panel": "#091014",
    "panel2": "#111a20",
    "line": "#273a44",
    "text": "#e9f3f5",
    "muted": "#8d9ba1",
    "cyan": "#48e8ff",
    "green": "#77f0c5",
    "amber": "#e5b761",
    "red": "#d66d68",
    "keyboard": "#171b20",
}

HELP_SECTIONS = (
    ("Start", ("Tap once from standby to wake JARVIS.", "Tap again to listen.", "Tap while listening to process the command.", "Long hold the orb to return to standby.")),
    ("Voice", ("JARVIS listens while this app is open.", "A short pause ends the command.", "Background wake word is not available in this build.")),
    ("Typing", ("Use the command bar when voice is not ideal.", "Return or Send routes the command.")),
    ("Vision", ("Try: scan this, read this, look at this, detect objects.", "OCR, barcode scan, and image classification run after capture.", "A custom Core ML detector can be bundled later.")),
    ("Control Mesh", ("Use Mesh for phone-level actions.", "Voice Control handles Show Grid, Tap, Scroll, Go Home, and screenshots.", "Shortcuts and jarvis:// links return actions back to JARVIS.")),
    ("States", ("Ready means JARVIS is awake.", "Listening means it is hearing you.", "Processing means it is routing the command.", "Speaking means it is responding.")),
    ("Limits", ("No hidden phone takeover without jailbreak.", "Phone-level actions use Control Mesh, Voice Control, or Shortcuts.", "Full phone takeover needs system access not available in this build.")),
)


@dataclass
class LayoutResult:
    compact: bool
    input_top: int
    orb_size: int
    orb_center_y: int
    state_y: int
    title_y: int
    help_bounds: tuple[int, int, int, int]
    menu_bounds: tuple[int, int, int, int]


def compute_layout(keyboard_visible: bool) -> LayoutResult:
    if keyboard_visible:
        input_top = PHONE_HEIGHT - SAFE_BOTTOM - KEYBOARD_HEIGHT - INPUT_HEIGHT - 10
        return LayoutResult(
            compact=True,
            input_top=input_top,
            orb_size=154,
            orb_center_y=SAFE_TOP + 176,
            state_y=SAFE_TOP + 278,
            title_y=SAFE_TOP + 18,
            help_bounds=(PHONE_WIDTH - 56, SAFE_TOP + 12, PHONE_WIDTH - 20, SAFE_TOP + 48),
            menu_bounds=(18, SAFE_TOP + 14, 58, SAFE_TOP + 46),
        )
    return LayoutResult(
        compact=False,
        input_top=PHONE_HEIGHT - SAFE_BOTTOM - INPUT_HEIGHT - 14,
        orb_size=292,
        orb_center_y=SAFE_TOP + 336,
        state_y=SAFE_TOP + 508,
        title_y=SAFE_TOP + 24,
        help_bounds=(PHONE_WIDTH - 56, SAFE_TOP + 12, PHONE_WIDTH - 20, SAFE_TOP + 48),
        menu_bounds=(18, SAFE_TOP + 14, 58, SAFE_TOP + 46),
    )


@dataclass
class PreviewResponse:
    status: str
    spoken: str
    display: str
    state: str = "Done"
    action: str = ""


class PreviewAssistantCore:
    def __init__(self) -> None:
        self.notes: list[str] = []

    def normalize(self, raw: str) -> str:
        text = raw.strip().lower().replace("what's", "what is").replace("whats", "what is")
        for char in ",.?;!\"":
            text = text.replace(char, " ")
        for prefix in ("hey jarvis ", "okay jarvis ", "ok jarvis ", "jarvis "):
            if text.startswith(prefix):
                text = text[len(prefix):]
                break
        return " ".join(text.split())

    def route(self, raw: str) -> PreviewResponse:
        command = self.normalize(raw)
        if not command:
            return PreviewResponse("ok", "JARVIS ready.", "Ready when you are.", "JARVIS ready")
        if command in {"help", "what can you do", "tools"}:
            return PreviewResponse(
                "ok",
                "Inspection tools are ready.",
                "Vision: scan this, look at this, read this, detect objects. Control: show grid, tap, scroll down.",
            )
        if command in {"settings", "open settings"}:
            return PreviewResponse("ok", "Opening settings.", "Opening JARVIS settings.", "Done", "settings")
        if command in {"diagnostics"}:
            return PreviewResponse("ok", "Diagnostics ready.", "Diagnostics ready.", "Done", "diagnostics")
        if command in {"control mesh", "mesh", "open mesh", "open control mesh"}:
            return PreviewResponse("ok", "Control Mesh ready.", "Control Mesh ready.", "Done", "control_mesh")
        if command in {"jarvis ready", "ready"}:
            return PreviewResponse("ok", "JARVIS ready.", "Ready when you are.", "JARVIS ready")
        if command in {"scan this", "scan this paper", "take photo", "take a picture for analysis"}:
            return PreviewResponse("ok", "Opening inspection.", "Opening inspection.", "Inspection", "inspect")
        if command in {"look at this", "what am i looking at", "what am i pointing at", "inspect this", "analyze this"}:
            return PreviewResponse(
                "ok",
                "Opening inspection.",
                "Opening inspection. OCR and codes run after capture.",
                "Inspection",
                "inspect",
            )
        if command in {"read this", "read this label", "read what is on screen"}:
            return PreviewResponse("ok", "Opening text scan.", "Opening text scan.", "Inspection", "ocr")
        if command in {"detect objects", "identify this object"}:
            return PreviewResponse(
                "ok",
                "Opening visual scan.",
                "Visual scan ready: text, codes, and image classification are active.",
                "Inspection",
                "visual_classification",
            )
        if command in {"flashlight on", "light on"}:
            return PreviewResponse("ok", "Opening inspection.", "Open inspection, then enable Light.", "Inspection", "inspect")
        if command in {"flashlight off", "light off"}:
            return PreviewResponse("ok", "Light control is in inspection.", "Use Light in inspection.", "Inspection", "inspect")
        if command.startswith("remember this"):
            note = raw.lower().split("remember this", 1)[-1].strip(" :")
            if not note:
                return PreviewResponse("refused", "Tell me what to remember.", "Tell me what to remember.", "Done")
            self.notes.insert(0, note)
            return PreviewResponse("ok", "Remembered.", "Remembered.", "Done")
        if command in {"show notes", "memory"}:
            display = "No notes." if not self.notes else self.notes[0]
            return PreviewResponse("ok", "Memory ready.", display, "Done")
        if command in {"show grid", "tap", "scroll down", "go home"}:
            phrases = {
                "show grid": "Say: Show Grid.",
                "tap": "Say: Show Grid, then Tap the target number.",
                "scroll down": "Say: Scroll Down.",
                "go home": "Say: Go Home.",
            }
            return PreviewResponse("ok", "Use Control Mesh.", phrases[command], "Done", "control_mesh")
        if command in {"take screenshot", "take a screenshot"}:
            return PreviewResponse("ok", "Use Voice Control.", "Say: Take Screenshot.", "Done", "control_mesh")
        if command in {"return to jarvis", "come back to jarvis", "go back to jarvis"}:
            return PreviewResponse("ok", "Return to JARVIS.", "Use the JARVIS Return Shortcut or jarvis://standby.", "Done", "control_mesh")
        if command in {"stop listening", "cancel listening"}:
            return PreviewResponse("ok", "Listening stopped.", "Listening stopped.", "Done")
        if command in {"stop speaking", "quiet mode", "be quiet"}:
            return PreviewResponse("ok", "Speech stopped.", "Quiet mode.", "Done")
        if command in {"status", "battery", "device status"}:
            return PreviewResponse("ok", "Device status ready.", "Device status ready.", "Done")
        return PreviewResponse(
            "refused",
            "Command not recognized.",
            "Try: scan this, read this, detect objects, show grid.",
            "Done",
        )


class InteractionModel:
    def __init__(self) -> None:
        self.core = PreviewAssistantCore()
        self.state = "Standby"
        self.keyboard_visible = False
        self.help_visible = False
        self.mesh_visible = False
        self.partial_transcript = ""
        self.last_response = "Ready when you are."
        self.history: list[str] = []
        self.pointer_is_down = False
        self.long_hold_consumed = False

    def orb_tap(self) -> str:
        return self.pointer_up(after_seconds=0.12)

    def pointer_down(self) -> None:
        self.pointer_is_down = True
        self.long_hold_consumed = False

    def pointer_up(self, after_seconds: float) -> str:
        if not self.pointer_is_down:
            self.pointer_down()
        self.pointer_is_down = False
        if after_seconds >= LONG_HOLD_SECONDS:
            self.long_hold_consumed = True
            return self.long_press()
        if self.long_hold_consumed:
            self.long_hold_consumed = False
            return self.state
        return self._short_tap()

    def _short_tap(self) -> str:
        self._close_sheets()
        if self.state == "Standby":
            self.state = "JARVIS ready"
            self.last_response = "Ready when you are."
        elif self.state in {"JARVIS ready", "Done", "Attention"}:
            self.state = "Listening"
            self.partial_transcript = ""
            self.last_response = "Listening."
        elif self.state == "Listening":
            self.endpoint()
        elif self.state == "Speaking":
            self.state = "JARVIS ready"
            self.last_response = "Speech stopped."
        elif self.state == "Processing":
            self.last_response = "Processing."
        else:
            self.state = "JARVIS ready"
            self.last_response = "Ready when you are."
        return self.state

    def long_press(self) -> str:
        self._close_sheets()
        self.state = "Standby"
        self.partial_transcript = ""
        self.last_response = "Standby."
        return self.state

    def open_help(self) -> None:
        self.mesh_visible = False
        self.help_visible = True

    def close_help(self) -> None:
        self.help_visible = False

    def open_mesh(self) -> None:
        self.help_visible = False
        self.mesh_visible = True

    def close_mesh(self) -> None:
        self.mesh_visible = False

    def _close_sheets(self) -> None:
        self.help_visible = False
        self.mesh_visible = False

    def permission_denied(self) -> None:
        self._close_sheets()
        self.state = "Attention"
        self.last_response = "Microphone permission is needed for in-app voice."

    def no_speech(self) -> None:
        self._close_sheets()
        self.state = "JARVIS ready"
        self.last_response = "No speech heard."

    def speaking(self) -> None:
        self._close_sheets()
        self.state = "Speaking"
        self.last_response = "Speaking."

    def inspection(self) -> None:
        self._close_sheets()
        self.state = "Inspection"
        self.last_response = "Opening inspection."

    def reset(self) -> None:
        self._close_sheets()
        self.keyboard_visible = False
        self.partial_transcript = ""
        self.state = "Standby"
        self.last_response = "Ready when you are."

    def simulate_partial(self, text: str) -> None:
        self._close_sheets()
        self.partial_transcript = text
        self.state = "Listening"
        self.last_response = text

    def endpoint(self) -> PreviewResponse:
        transcript = self.partial_transcript.strip()
        self.state = "Heard you" if transcript else "JARVIS ready"
        if not transcript:
            self.last_response = "No speech heard."
            return PreviewResponse("refused", "No speech heard.", "No speech heard.", "JARVIS ready")
        response = self.process(transcript, source="voice")
        return response

    def process(self, command: str, source: str = "typed") -> PreviewResponse:
        self._close_sheets()
        self.state = "Processing"
        response = self.core.route(command)
        self.state = response.state
        self.last_response = response.display
        self.history.insert(0, f"{source}: {command} -> {response.display}")
        self.history = self.history[:8]
        self.partial_transcript = ""
        return response

    def toggle_keyboard(self) -> None:
        self.keyboard_visible = not self.keyboard_visible

    def layout(self) -> LayoutResult:
        return compute_layout(self.keyboard_visible)

    def product_surface_texts(self) -> list[str]:
        texts = ["JARVIS", "Mesh", "?", self.state, self.partial_transcript or self.last_response, "Command JARVIS", "Send"]
        if self.help_visible:
            texts.extend(["Operate JARVIS"])
            for title, rows in HELP_SECTIONS:
                texts.append(title)
                texts.extend(rows)
        if self.mesh_visible:
            texts.extend([
                "Control Mesh",
                "JARVIS coordinates phone-level actions through public iOS routes.",
                "Voice Control: Show Grid, Tap, Scroll, Go Home, Take Screenshot.",
                "Shortcuts: return to JARVIS and route system preferences.",
                "Guided Access: appliance mode after testing."
            ])
        return texts

    def report(self) -> str:
        layout = self.layout()
        lines = [
            f"timestamp: {dt.datetime.now().isoformat(timespec='seconds')}",
            f"state: {self.state}",
            f"keyboard_visible: {self.keyboard_visible}",
            f"help_visible: {self.help_visible}",
            f"mesh_visible: {self.mesh_visible}",
            f"input_top: {layout.input_top}",
            f"orb_size: {layout.orb_size}",
            f"orb_center_y: {layout.orb_center_y}",
            f"last_response: {self.last_response}",
            "history:",
        ]
        lines.extend(f"- {item}" for item in self.history[:8])
        return "\n".join(lines) + "\n"


def run_self_test() -> int:
    model = InteractionModel()
    closed = model.layout()
    model.toggle_keyboard()
    open_layout = model.layout()
    model.open_help()
    product_text = "\n".join(model.product_surface_texts()).lower()
    checks: list[tuple[str, Callable[[], bool]]] = [
        ("closed input above home", lambda: closed.input_top + INPUT_HEIGHT <= PHONE_HEIGHT - SAFE_BOTTOM),
        ("preview orb asset exists", lambda: ORB_ASSET.exists() and ORB_ASSET.stat().st_size > 0),
        ("keyboard input above keyboard", lambda: open_layout.input_top + INPUT_HEIGHT < PHONE_HEIGHT - SAFE_BOTTOM - KEYBOARD_HEIGHT),
        ("keyboard compact", lambda: open_layout.compact and open_layout.orb_size < closed.orb_size),
        ("help opens", lambda: model.help_visible and "operate jarvis" in product_text),
        ("mesh opens", lambda: _mesh_flow(model)),
        ("no guide text", lambda: "should " + "say ready" not in product_text and "approval" not in product_text),
        ("no product data dump", lambda: "export" not in product_text and "debug" not in product_text),
        ("orb ready", lambda: _ready_flow(model)),
        ("silence endpoint processing", lambda: _endpoint_scan(model)),
        ("scan inspection", lambda: model.process("scan this").state == "Inspection"),
        ("read maps ocr", lambda: model.process("read this").action == "ocr"),
        ("detect visual classification", lambda: "classification" in model.process("detect objects").display.lower()),
        ("go home uses mesh", lambda: model.process("go home").action == "control_mesh"),
        ("tap uses mesh", lambda: model.process("tap").action == "control_mesh"),
    ]
    failed = [name for name, check in checks if not check()]
    if failed:
        print("Preview self-test failed: " + ", ".join(failed))
        return 1
    print(f"Preview self-test passed: {len(checks)} checks")
    return 0


def _ready_flow(model: InteractionModel) -> bool:
    model.close_help()
    return model.orb_tap() == "JARVIS ready" and model.orb_tap() == "Listening"


def _endpoint_scan(model: InteractionModel) -> bool:
    model.simulate_partial("scan this")
    response = model.endpoint()
    return response.action == "inspect" and model.state == "Inspection"


def _mesh_flow(model: InteractionModel) -> bool:
    model.open_mesh()
    text = "\n".join(model.product_surface_texts()).lower()
    return model.mesh_visible and "control mesh" in text and "voice control" in text


class JarvisPreviewApp:
    def __init__(self, product_only: bool = False) -> None:
        import tkinter as tk

        self.tk = tk
        self.model = InteractionModel()
        self.phase = 0.0
        self.product_only = product_only

        self.root = tk.Tk()
        self.root.title("JARVIS Product Preview")
        self.root.geometry("980x960")
        self.root.configure(bg=COLORS["page"])

        self.canvas = tk.Canvas(self.root, width=PHONE_WIDTH, height=PHONE_HEIGHT, bg=COLORS["phone"], highlightthickness=0)
        self.canvas.pack(side="left", padx=28, pady=28)
        self.canvas.bind("<Button-1>", self._phone_click)

        self.panel = tk.Frame(self.root, bg=COLORS["page"])
        panel = self.panel
        if not self.product_only:
            panel.pack(side="left", fill="both", expand=True, padx=(0, 28), pady=28)

        tk.Label(panel, text="Preview controls", fg=COLORS["text"], bg=COLORS["page"], font=("Segoe UI", 18, "bold")).pack(anchor="w")
        tk.Label(panel, text="External review harness. Not part of the phone app.", fg=COLORS["muted"], bg=COLORS["page"], font=("Segoe UI", 10)).pack(anchor="w", pady=(2, 18))

        self.command_var = tk.StringVar()
        entry = tk.Entry(panel, textvariable=self.command_var, bg=COLORS["panel"], fg=COLORS["text"], insertbackground=COLORS["cyan"], font=("Segoe UI", 13), relief="solid", bd=1)
        entry.pack(fill="x", ipady=10)
        entry.bind("<Return>", lambda _event: self.run_command())

        self._button(panel, "Send typed command", self.run_command)
        self._button(panel, "Orb Tap", self.tap_orb)
        self._button(panel, "Hold Orb", self.long_press)
        self._button(panel, "Keyboard", self.toggle_keyboard)
        self._button(panel, "Help", self.open_help)
        self._button(panel, "Mesh", self.open_mesh)
        self._button(panel, "Product-only view", self.toggle_product_only)

        tk.Label(panel, text="Voice samples", fg=COLORS["muted"], bg=COLORS["page"], font=("Segoe UI", 10, "bold")).pack(anchor="w", pady=(18, 6))
        self._button(panel, "Speak: scan this", lambda: self.speak_command("scan this"))
        self._button(panel, "Speak: read this", lambda: self.speak_command("read this"))
        self._button(panel, "Speak: detect objects", lambda: self.speak_command("detect objects"))
        self._button(panel, "Permission denied", self.permission_denied)
        self._button(panel, "No speech", self.no_speech)
        self._button(panel, "Speaking", self.speaking)
        self._button(panel, "Inspection", self.inspection)
        self._button(panel, "Reset", self.reset)

        tk.Label(panel, text="Priority commands", fg=COLORS["muted"], bg=COLORS["page"], font=("Segoe UI", 10, "bold")).pack(anchor="w", pady=(18, 6))
        for label, command in (
            ("Look at this", "look at this"),
            ("Scan this", "scan this"),
            ("Read this", "read this"),
            ("Detect objects", "detect objects"),
            ("Stop listening", "stop listening"),
        ):
            self._button(panel, label, lambda cmd=command: self.execute(cmd))

        self.status_label = tk.Label(panel, text="", fg=COLORS["text"], bg=COLORS["panel"], font=("Segoe UI", 11), justify="left", anchor="nw", relief="solid", bd=1, padx=12, pady=12)
        self.status_label.pack(fill="both", expand=True, pady=(18, 8))
        self._button(panel, "Developer report", self.write_developer_report)

        self.root.after(30, self.animate)
        self.redraw()

    def _button(self, parent, text: str, command: Callable[[], None]) -> None:
        button = self.tk.Button(parent, text=text, command=command, bg=COLORS["panel2"], fg=COLORS["text"], activebackground="#16252c", activeforeground=COLORS["cyan"], relief="solid", bd=1, font=("Segoe UI", 10), padx=10, pady=9)
        button.pack(fill="x", pady=3)

    def run_command(self) -> None:
        command = self.command_var.get()
        self.command_var.set("")
        self.execute(command)

    def execute(self, command: str) -> None:
        self.model.process(command)
        self.redraw()

    def tap_orb(self) -> None:
        self.model.orb_tap()
        self.redraw()

    def long_press(self) -> None:
        self.model.long_press()
        self.redraw()

    def open_help(self) -> None:
        self.model.open_help()
        self.redraw()

    def open_mesh(self) -> None:
        self.model.open_mesh()
        self.redraw()

    def toggle_product_only(self) -> None:
        self.product_only = not self.product_only
        if self.product_only:
            self.panel.pack_forget()
            self.root.geometry("470x960")
        else:
            self.panel.pack(side="left", fill="both", expand=True, padx=(0, 28), pady=28)
            self.root.geometry("980x960")
        self.redraw()

    def speak_command(self, text: str) -> None:
        self.model.simulate_partial(text)
        self.redraw()
        self.root.after(950, self._finish_voice)

    def _finish_voice(self) -> None:
        self.model.endpoint()
        self.redraw()

    def permission_denied(self) -> None:
        self.model.permission_denied()
        self.redraw()

    def no_speech(self) -> None:
        self.model.no_speech()
        self.redraw()

    def speaking(self) -> None:
        self.model.speaking()
        self.redraw()

    def inspection(self) -> None:
        self.model.inspection()
        self.redraw()

    def reset(self) -> None:
        self.model.reset()
        self.redraw()

    def toggle_keyboard(self) -> None:
        self.model.toggle_keyboard()
        self.redraw()

    def write_developer_report(self) -> None:
        BUNDLE_DIR.mkdir(parents=True, exist_ok=True)
        DEVELOPER_REPORT.write_text(self.model.report(), encoding="utf-8")
        self.model.last_response = f"Developer report written to {DEVELOPER_REPORT.name}."
        self.redraw()

    def animate(self) -> None:
        self.phase += 0.08
        self.redraw()
        self.root.after(33, self.animate)

    def _phone_click(self, event) -> None:
        layout = self.model.layout()
        x1, y1, x2, y2 = layout.help_bounds
        if x1 <= event.x <= x2 and y1 <= event.y <= y2:
            self.open_help()
            return
        if self.model.help_visible:
            self.model.close_help()
            self.redraw()
        elif self.model.mesh_visible:
            self.model.close_mesh()
            self.redraw()

    def redraw(self) -> None:
        c = self.canvas
        c.delete("all")
        layout = self.model.layout()
        c.create_rectangle(0, 0, PHONE_WIDTH, PHONE_HEIGHT, fill=COLORS["phone"], outline="")
        c.create_rectangle(0, 0, PHONE_WIDTH, SAFE_TOP, fill="#05090d", outline="")
        c.create_rectangle(0, PHONE_HEIGHT - SAFE_BOTTOM, PHONE_WIDTH, PHONE_HEIGHT, fill="#05090d", outline="")
        c.create_text(PHONE_WIDTH / 2, layout.title_y, text="JARVIS", fill=COLORS["text"], font=("Segoe UI", 27, "bold"))
        self._draw_top_controls(layout)

        self._draw_orb(PHONE_WIDTH // 2, layout.orb_center_y, layout.orb_size)
        c.create_text(PHONE_WIDTH / 2, layout.state_y, text=self.model.state, fill=self._state_color(), font=("Segoe UI", 22, "bold"))

        hint = self.model.partial_transcript or self.model.last_response
        c.create_text(PHONE_WIDTH / 2, layout.state_y + 38, text=self._compact(hint, 80), fill=COLORS["muted"], font=("Segoe UI", 12), width=PHONE_WIDTH - 56)

        self._draw_input(layout)

        if self.model.keyboard_visible:
            self._draw_keyboard()

        if self.model.help_visible:
            self._draw_help_sheet()
        if self.model.mesh_visible:
            self._draw_mesh_sheet()

        if not self.product_only:
            self.status_label.configure(text=self._external_status())

    def _draw_top_controls(self, layout: LayoutResult) -> None:
        c = self.canvas
        mx1, my1, mx2, my2 = layout.menu_bounds
        hx1, hy1, hx2, hy2 = layout.help_bounds
        c.create_rectangle(mx1, my1, mx2 + 10, my2, fill="#071116", outline="#20343c", width=1)
        c.create_text((mx1 + mx2) / 2 + 5, (my1 + my2) / 2, text="Mesh", fill=COLORS["muted"], font=("Segoe UI", 10, "bold"))
        c.create_oval(hx1, hy1, hx2, hy2, fill="#071116", outline=COLORS["cyan"], width=1)
        c.create_text((hx1 + hx2) / 2, (hy1 + hy2) / 2, text="?", fill=COLORS["cyan"], font=("Segoe UI", 16, "bold"))

    def _draw_input(self, layout: LayoutResult) -> None:
        c = self.canvas
        c.create_rectangle(16, layout.input_top, PHONE_WIDTH - 16, layout.input_top + INPUT_HEIGHT, fill=COLORS["panel"], outline=COLORS["line"], width=1)
        c.create_text(32, layout.input_top + INPUT_HEIGHT / 2, text="Command JARVIS", anchor="w", fill=COLORS["muted"], font=("Segoe UI", 13))
        c.create_rectangle(PHONE_WIDTH - 94, layout.input_top + 8, PHONE_WIDTH - 26, layout.input_top + INPUT_HEIGHT - 8, fill=COLORS["cyan"], outline="")
        c.create_text(PHONE_WIDTH - 60, layout.input_top + INPUT_HEIGHT / 2, text="Send", fill="#001014", font=("Segoe UI", 12, "bold"))

    def _draw_keyboard(self) -> None:
        c = self.canvas
        top = PHONE_HEIGHT - SAFE_BOTTOM - KEYBOARD_HEIGHT
        c.create_rectangle(0, top, PHONE_WIDTH, PHONE_HEIGHT - SAFE_BOTTOM, fill=COLORS["keyboard"], outline=COLORS["line"])
        for row in range(4):
            y = top + 44 + row * 56
            for col in range(10):
                x = 18 + col * 38
                c.create_rectangle(x, y, x + 28, y + 36, fill="#252b31", outline="#343b42")

    def _draw_help_sheet(self) -> None:
        c = self.canvas
        x1, y1, x2, y2 = 22, SAFE_TOP + 72, PHONE_WIDTH - 22, PHONE_HEIGHT - SAFE_BOTTOM - 96
        c.create_rectangle(x1, y1, x2, y2, fill="#071016", outline="#2a4e58", width=2)
        c.create_text(x1 + 18, y1 + 28, anchor="w", text="Operate JARVIS", fill=COLORS["text"], font=("Segoe UI", 19, "bold"))
        y = y1 + 58
        for title, rows in HELP_SECTIONS:
            c.create_text(x1 + 18, y, anchor="w", text=title, fill=COLORS["cyan"], font=("Segoe UI", 12, "bold"))
            y += 20
            for row in rows:
                c.create_text(x1 + 20, y, anchor="w", text=row, fill=COLORS["text"], font=("Segoe UI", 9), width=x2 - x1 - 40)
                y += 17
            y += 6
            if y > y2 - 36:
                break
        c.create_text(PHONE_WIDTH / 2, y2 - 22, text="Tap outside this panel to close.", fill=COLORS["muted"], font=("Segoe UI", 10))

    def _draw_mesh_sheet(self) -> None:
        c = self.canvas
        x1, y1, x2, y2 = 22, SAFE_TOP + 92, PHONE_WIDTH - 22, PHONE_HEIGHT - SAFE_BOTTOM - 120
        c.create_rectangle(x1, y1, x2, y2, fill="#071016", outline=COLORS["cyan"], width=2)
        c.create_text(x1 + 18, y1 + 30, anchor="w", text="Control Mesh", fill=COLORS["text"], font=("Segoe UI", 20, "bold"))
        rows = [
            ("Apps", "Open supported apps through public links or Shortcuts."),
            ("Tap", "Use Voice Control: Show Grid, then Tap the target."),
            ("Scroll", "Use Voice Control: Scroll Down or Scroll Up."),
            ("Return", "Use the Return to JARVIS Shortcut or jarvis://standby."),
            ("Lockdown", "Guided Access keeps JARVIS foreground after testing."),
            ("Boundary", "System takeover is outside public iOS access."),
        ]
        y = y1 + 74
        for title, body in rows:
            c.create_text(x1 + 20, y, anchor="w", text=title, fill=COLORS["cyan"], font=("Segoe UI", 12, "bold"))
            y += 20
            c.create_text(x1 + 20, y, anchor="w", text=body, fill=COLORS["text"], font=("Segoe UI", 10), width=x2 - x1 - 40)
            y += 38
        c.create_text(PHONE_WIDTH / 2, y2 - 22, text="Tap outside this panel to close.", fill=COLORS["muted"], font=("Segoe UI", 10))

    def _draw_orb(self, cx: int, cy: int, size: int) -> None:
        c = self.canvas
        radius = size / 2
        pulse = 1 + math.sin(self.phase) * 0.025
        primary = self._state_color()
        c.create_oval(cx - radius, cy - radius, cx + radius, cy + radius, fill="#061016", outline="#172830", width=4)
        for layer in range(5, 0, -1):
            glow = radius * (0.54 + layer * 0.095)
            color = "#06232b" if layer > 2 else "#0a3440"
            c.create_oval(cx - glow, cy - glow, cx + glow, cy + glow, outline=color, width=layer)
        c.create_oval(cx - radius * 0.82, cy - radius * 0.82, cx + radius * 0.82, cy + radius * 0.82, outline=primary, width=3)
        for index in range(72):
            angle = (index * 360 / 72 + self.phase * 22) * math.pi / 180
            r1 = radius * 0.52
            r2 = radius * (0.70 if index % 6 == 0 else 0.64)
            c.create_line(cx + math.cos(angle) * r1, cy + math.sin(angle) * r1, cx + math.cos(angle) * r2, cy + math.sin(angle) * r2, fill=primary if index % 3 == 0 else "#1e4d58")
        c.create_arc(cx - radius * 0.94, cy - radius * 0.94, cx + radius * 0.94, cy + radius * 0.94, start=(self.phase * 80) % 360, extent=52, style=self.tk.ARC, outline=primary, width=4)
        core = radius * 0.22 * pulse
        c.create_oval(cx - core * 2.1, cy - core * 2.1, cx + core * 2.1, cy + core * 2.1, fill="#0b242b", outline=primary, width=2)
        c.create_oval(cx - core, cy - core, cx + core, cy + core, fill=primary, outline="")

    def _state_color(self) -> str:
        return {
            "Standby": COLORS["muted"],
            "JARVIS ready": COLORS["cyan"],
            "Listening": COLORS["cyan"],
            "Heard you": COLORS["green"],
            "Processing": "#a7dfff",
            "Speaking": COLORS["green"],
            "Done": COLORS["cyan"],
            "Inspection": "#b6c0ff",
            "Attention": COLORS["amber"],
        }.get(self.model.state, COLORS["amber"])

    def _compact(self, text: str, limit: int) -> str:
        return text if len(text) <= limit else text[: limit - 3] + "..."

    def _external_status(self) -> str:
        layout = self.model.layout()
        return "\n".join([
            "Preview status",
            f"State: {self.model.state}",
            f"Keyboard: {'open' if self.model.keyboard_visible else 'closed'}",
            f"Help: {'open' if self.model.help_visible else 'closed'}",
            f"Orb size: {layout.orb_size}",
            f"Input top: {layout.input_top}",
            "",
            "Keep the phone frame clean.",
            "Use these controls only to review states.",
        ])

    def run(self) -> None:
        self.root.mainloop()


def run_gui(product_only: bool = False) -> None:
    JarvisPreviewApp(product_only=product_only).run()


def visual_state_reports() -> dict[str, str]:
    states: dict[str, InteractionModel] = {}

    standby = InteractionModel()
    states["standby_state"] = standby

    ready = InteractionModel()
    ready.orb_tap()
    states["ready_state"] = ready

    listening = InteractionModel()
    listening.orb_tap()
    listening.orb_tap()
    states["listening_state"] = listening

    listening_with_transcript = InteractionModel()
    listening_with_transcript.orb_tap()
    listening_with_transcript.orb_tap()
    listening_with_transcript.simulate_partial("scan this")
    states["listening_with_transcript_state"] = listening_with_transcript

    manual_endpoint = InteractionModel()
    manual_endpoint.orb_tap()
    manual_endpoint.orb_tap()
    manual_endpoint.simulate_partial("scan this")
    manual_endpoint.orb_tap()
    states["manual_endpoint_processed_state"] = manual_endpoint

    long_hold = InteractionModel()
    long_hold.orb_tap()
    long_hold.pointer_down()
    long_hold.pointer_up(after_seconds=LONG_HOLD_SECONDS)
    states["long_hold_standby_state"] = long_hold

    speaking = InteractionModel()
    speaking.speaking()
    states["speaking_state"] = speaking

    keyboard = InteractionModel()
    keyboard.orb_tap()
    keyboard.toggle_keyboard()
    states["keyboard_state"] = keyboard

    help_state = InteractionModel()
    help_state.open_help()
    states["help_sheet_state"] = help_state

    mesh_state = InteractionModel()
    mesh_state.open_mesh()
    states["mesh_sheet_state"] = mesh_state

    inspection = InteractionModel()
    inspection.process("scan this")
    states["inspection_state"] = inspection

    denied = InteractionModel()
    denied.permission_denied()
    states["permission_denied_state"] = denied

    model_missing = InteractionModel()
    model_missing.process("detect objects")
    states["object_model_missing_state"] = model_missing

    reports: dict[str, str] = {}
    for name, model in states.items():
        layout = model.layout()
        reports[name] = "\n".join([
            f"state_name: {name}",
            f"phone_size: {PHONE_WIDTH}x{PHONE_HEIGHT}",
            f"state: {model.state}",
            f"keyboard_visible: {model.keyboard_visible}",
            f"help_visible: {model.help_visible}",
            f"mesh_visible: {model.mesh_visible}",
            f"orb_size: {layout.orb_size}",
            f"input_top: {layout.input_top}",
            "surface_text:",
            *[f"- {line}" for line in model.product_surface_texts()],
        ]) + "\n"
    return reports


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--product-only", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        return run_self_test()
    run_gui(product_only=args.product_only)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
