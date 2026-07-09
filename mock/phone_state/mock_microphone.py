from __future__ import annotations


def microphone_state() -> dict:
    return {
        "available": True,
        "mode": "mock",
        "input_level_db": -42,
        "supported_actions": ["push_to_talk_record", "sound_level_estimate", "mock_command_transcript"],
    }
