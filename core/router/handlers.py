from __future__ import annotations

from typing import Callable

from .permissions import requires_confirmation


def output(
    status: str,
    spoken: str,
    display: str,
    data: dict | None = None,
    requires: bool = False,
    unavailable: str | None = None,
    side_effects: list | None = None,
    memory_writes: list | None = None,
    logs: list | None = None,
    confirmation_token: str | None = None,
) -> dict:
    return {
        "status": status,
        "spoken_response": spoken,
        "display_response": display,
        "data": data or {},
        "side_effects": side_effects or [],
        "memory_writes": memory_writes or [],
        "logs": logs or [],
        "requires_confirmation": requires,
        "unavailable_reason": unavailable,
        "confirmation_token": confirmation_token,
    }


def camera_scan(ctx: dict) -> dict:
    result = ctx["adapters"].get("camera").capture_frame()
    if result.status != "ok":
        return output("unavailable", result.error or "Camera unavailable.", result.error or "Camera unavailable.", {"adapter": result.to_dict()}, unavailable=result.error)
    return output("ok", "Inspection frame ready.", "Mock camera inspection prepared.", {"mode": "inspection", "frame": result.data, "adapter": result.to_dict()})


def camera_freeze(ctx: dict) -> dict:
    return output("ok", "Frame frozen.", "Mock frame frozen for inspection.", {"frozen": True})


def flashlight(ctx: dict) -> dict:
    state = ctx["phone_state"]["camera"].get("flashlight", False)
    return output("ok", "Flashlight toggle prepared.", "Mock flashlight state would toggle.", {"previous": state, "next": not state})


def ocr_read(ctx: dict) -> dict:
    frame = ctx["adapters"].get("camera").capture_frame()
    if frame.status != "ok":
        return output("unavailable", frame.error or "Camera unavailable.", frame.error or "Camera unavailable.", {"adapter": frame.to_dict()}, unavailable=frame.error)
    result = ctx["adapters"].get("ocr").read_text(frame.data)
    return output("ok", "I can read the mock label text.", f"OCR mock result: {result.data.get('text')}.", {"text": result.data.get("text"), "confidence": result.data.get("confidence"), "adapter": result.to_dict(), "camera": frame.to_dict()})


def ocr_searchable(ctx: dict) -> dict:
    item = ctx["memory"].save_note("Searchable OCR text: SAMPLE LABEL 123", {"source": "ocr_mock"})
    return output("ok", "The text is saved and searchable.", "Saved OCR text to local memory.", {"memory_item": item}, memory_writes=[item])


def object_identify(ctx: dict) -> dict:
    frame = ctx["adapters"].get("camera").capture_frame()
    if frame.status != "ok":
        return output("unavailable", frame.error or "Camera unavailable.", frame.error or "Camera unavailable.", {"adapter": frame.to_dict()}, unavailable=frame.error)
    result = ctx["adapters"].get("vision").detect_objects(frame.data)
    return output("ok", "Mock object detection found a bottle and a label.", "Objects: bottle, label.", {"objects": result.data.get("objects", []), "adapter": result.to_dict(), "camera": frame.to_dict()})


def object_list(ctx: dict) -> dict:
    return output("ok", "Visible objects listed from mock detector.", "Mock visible objects: bottle, label, table.", {"objects": ["bottle", "label", "table"]})


def audio_push_to_talk(ctx: dict) -> dict:
    result = ctx["adapters"].get("microphone").start_push_to_talk()
    if result.status != "ok":
        return output("unavailable", result.error or "Microphone unavailable.", result.error or "Microphone unavailable.", {"adapter": result.to_dict()}, unavailable=result.error)
    return output("ok", "Push to talk is ready.", "Mock microphone is listening for a short command.", {"adapter": result.to_dict()})


def audio_speak(ctx: dict) -> dict:
    tts = ctx["adapters"].get("tts").synthesize("Repeating the last result.")
    speaker = ctx["adapters"].get("speaker").play_spoken_response("Repeating the last result.")
    return output("ok", "Repeating the last result.", "Mock spoken response emitted through local TTS path.", {"tts_adapter": tts.to_dict(), "speaker_adapter": speaker.to_dict()})


def sensor_check(ctx: dict) -> dict:
    result = ctx["adapters"].get("sensor").snapshot()
    if result.status != "ok":
        return output("unavailable", result.error or "Sensors unavailable.", result.error or "Sensors unavailable.", {"adapter": result.to_dict()}, unavailable=result.error)
    return output("ok", "Sensors report nominal mock state.", "Compass, motion, pressure, proximity, and GPS mock values are available.", {"adapter": result.to_dict()})


def sensor_angle(ctx: dict) -> dict:
    result = ctx["adapters"].get("sensor").measure_angle()
    if result.status != "ok":
        return output("unavailable", result.error or "Sensors unavailable.", result.error or "Sensors unavailable.", {"adapter": result.to_dict()}, unavailable=result.error)
    return output("ok", "The mock angle is zero degrees.", "Level angle: 0 degrees.", {"angle_degrees": result.data.get("angle_degrees"), "adapter": result.to_dict()})


def sensor_location(ctx: dict) -> dict:
    gps = ctx["phone_state"]["sensors"]["gps"]
    return output("ok", "Location saved from mock GPS.", "Saved mock GPS coordinate.", {"gps": gps})


def diagnostics_phone(ctx: dict) -> dict:
    state = ctx["phone_state"]
    return output("ok", "Phone diagnostics are ready.", "Mock diagnostics generated.", {"battery": state["battery"], "storage": state["storage"], "network": state["network"], "jailbreak": state["jailbreak"]})


def battery_diagnostics(ctx: dict) -> dict:
    result = ctx["adapters"].get("battery").status()
    spoken = "Battery is low. Offline and quiet behavior are preferred." if result.data.get("low_power_preferred") else "Battery diagnostics are ready."
    return output("ok", spoken, "Battery diagnostics generated.", {"adapter": result.to_dict()})


def storage_diagnostics(ctx: dict) -> dict:
    result = ctx["adapters"].get("storage").status()
    return output("ok", "Storage diagnostics are ready.", "Storage diagnostics generated.", {"adapter": result.to_dict()})


def network_status(ctx: dict) -> dict:
    result = ctx["adapters"].get("network").status()
    if result.status != "ok":
        return output("unavailable", result.error or "Network unavailable.", result.error or "Network unavailable.", {"adapter": result.to_dict()}, unavailable=result.error)
    return output("ok", "Network state is ready.", "Network state generated.", {"adapter": result.to_dict()})


def dock_sync(ctx: dict) -> dict:
    result = ctx["adapters"].get("dock").sync_logs()
    if result.status != "ok":
        return output("unavailable", result.error or "Dock unavailable.", result.error or "Dock unavailable.", {"adapter": result.to_dict()}, unavailable=result.error)
    return output("ok", "Dock log sync prepared.", "Mock Raspberry Pi log sync completed.", {"adapter": result.to_dict()}, side_effects=["dock_sync"])


def diagnostics_registry(ctx: dict) -> dict:
    return output("ok", "The registry contains four hundred capabilities.", "Capability registry count: 400.", {"capability_count": len(ctx["capabilities"])})


def utility_timer(ctx: dict) -> dict:
    return output("ok", "Timer prepared.", "Mock timer created for 60 seconds.", {"seconds": 60})


def utility_calculate(ctx: dict) -> dict:
    return output("ok", "Calculator prototype is ready.", "Calculator handler is available for simple expressions in a later pass.", {"implemented": "prototype"})


def memory_save_note(ctx: dict) -> dict:
    text = ctx.get("argument") or "Untitled Jarvis note"
    item = ctx["memory"].save_note(text, {"source": "handler"})
    return output("ok", "Note saved.", f"Saved note: {text}", {"memory_item": item}, memory_writes=[item])


def memory_observation(ctx: dict) -> dict:
    text = ctx.get("argument") or "Mock field observation"
    item = ctx["memory"].save_observation(text, {"source": "handler"})
    return output("ok", "Observation saved.", f"Saved observation: {text}", {"memory_item": item}, memory_writes=[item])


def memory_search(ctx: dict) -> dict:
    query = ctx.get("argument") or ctx["command"]
    results = ctx["memory"].search(query)
    return output("ok", f"I found {len(results)} memory item matches.", f"Memory search returned {len(results)} item(s).", {"results": results})


def memory_history(ctx: dict) -> dict:
    history = ctx["memory"].history()
    return output("ok", f"Showing {len(history)} recent memory items.", "Recent local memory loaded.", {"history": history})


def clear_test_data(ctx: dict) -> dict:
    confirmed = bool(ctx.get("confirmed"))
    result = ctx["memory"].clear_test_data(confirmed)
    status = "confirmation_required" if result["status"] == "confirmation_required" else result["status"]
    token = ctx.get("confirmation_token")
    return output(
        status,
        result.get("message", "Test memory cleared."),
        result.get("message", "Test memory cleared."),
        result,
        requires=not confirmed,
        side_effects=["memory_clear"] if confirmed else [],
        logs=["clear_test_data"],
        confirmation_token=token if not confirmed else None,
    )


def mode_change(ctx: dict) -> dict:
    capability = ctx["capability"]
    sensor = ctx["adapters"].get("sensor").snapshot()
    return output("ok", f"{capability['name']} is active in prototype mode.", f"Mode switch prepared: {capability['name']}.", {"mode": capability["id"], "adapter": sensor.to_dict()})


def privacy_mode(ctx: dict) -> dict:
    return output("ok", "Private mode is enabled in mock state.", "Private mode hides memory details in future UI surfaces.", {"private_mode": True}, side_effects=["privacy_mode_enabled"])


def diagnostics_unavailable(ctx: dict) -> dict:
    unavailable = ctx.get("unavailable_reason") or "Capability cannot run in the current mock state."
    return output("unavailable", unavailable, unavailable, unavailable=unavailable)


HANDLERS: dict[str, Callable[[dict], dict]] = {
    "camera_inspection_001": camera_scan,
    "camera_inspection_002": camera_scan,
    "camera_inspection_003": camera_freeze,
    "camera_inspection_005": flashlight,
    "ocr_text_001": ocr_read,
    "ocr_text_002": ocr_read,
    "ocr_text_014": ocr_searchable,
    "ocr_text_020": audio_speak,
    "object_detection_001": object_identify,
    "object_detection_020": object_list,
    "audio_voice_001": audio_push_to_talk,
    "audio_voice_002": audio_speak,
    "audio_voice_003": memory_save_note,
    "audio_voice_007": audio_speak,
    "sensor_tools_001": sensor_check,
    "sensor_tools_002": sensor_angle,
    "sensor_tools_003": sensor_check,
    "navigation_location_001": sensor_location,
    "navigation_location_002": sensor_check,
    "phone_control_002": battery_diagnostics,
    "phone_control_003": storage_diagnostics,
    "phone_control_005": network_status,
    "diagnostics_001": diagnostics_phone,
    "diagnostics_003": battery_diagnostics,
    "diagnostics_004": storage_diagnostics,
    "diagnostics_007": diagnostics_registry,
    "utilities_001": utility_timer,
    "utilities_007": utility_calculate,
    "files_memory_001": memory_save_note,
    "files_memory_002": memory_save_note,
    "files_memory_003": memory_search,
    "files_memory_004": memory_history,
    "files_memory_020": clear_test_data,
    "field_tools_002": memory_observation,
    "jarvis_modes_001": mode_change,
    "jarvis_modes_002": mode_change,
    "jarvis_modes_005": mode_change,
    "jarvis_modes_009": privacy_mode,
    "security_privacy_013": privacy_mode,
    "raspberry_pi_dock_001": dock_sync,
}


def execute_handler(ctx: dict) -> dict:
    capability = ctx["capability"]
    if requires_confirmation(capability) and not ctx.get("confirmed"):
        token = ctx.get("confirmation_token")
        return output(
            "confirmation_required",
            f"{capability['name']} requires confirmation.",
            f"Confirmation required before running {capability['name']}.",
            {"permission_required": capability["permission_required"], "risk_level": capability["risk_level"]},
            requires=True,
            logs=["confirmation_required"],
            confirmation_token=token,
        )
    handler = HANDLERS.get(capability["id"])
    if handler:
        return handler(ctx)
    return output(
        "ok",
        f"{capability['name']} is routed, but no prototype handler exists yet.",
        f"No v0.2 handler exists for {capability['id']}. The capability remains registered for future native or jailbreak implementation.",
        {"handler": "not_implemented"},
    )
