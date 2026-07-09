from __future__ import annotations

import re
from difflib import SequenceMatcher


TOKEN_RE = re.compile(r"[a-z0-9]+")
STOP_WORDS = {"jarvis", "please", "the", "a", "an", "my", "me", "can", "you"}
FAMILY_TERMS = {
    "camera": {"camera", "scan", "photo", "image", "inspection", "flashlight", "visual"},
    "sensor": {"sensor", "sensors", "gps", "compass", "level", "angle", "motion", "barometer"},
    "voice": {"voice", "audio", "microphone", "speaker", "speak", "read", "sound"},
    "security": {"security", "privacy", "permission", "private", "confirm", "risky"},
    "memory": {"memory", "note", "notes", "observation", "history", "search", "save"},
    "dock": {"dock", "pi", "raspberry", "windows", "pc", "sync", "backup"},
}


def normalize(text: str) -> str:
    return " ".join(TOKEN_RE.findall(text.lower()))


def tokenize(text: str) -> set[str]:
    return {token for token in normalize(text).split() if token not in STOP_WORDS}


def family_tokens(capability: dict) -> set[str]:
    family = tokenize(capability.get("family", ""))
    expanded = set(family)
    for key, terms in FAMILY_TERMS.items():
        if key in family:
            expanded |= terms
    return expanded


def score_command(command: str, capability: dict) -> float:
    normalized_command = normalize(command)
    command_tokens = tokenize(command)
    candidates = [capability["name"], capability["family"], *capability["example_voice_phrases"]]
    best = 0.0
    for candidate in candidates:
        normalized_candidate = normalize(candidate)
        candidate_tokens = tokenize(candidate)
        overlap = len(command_tokens & candidate_tokens) / max(1, len(command_tokens | candidate_tokens))
        phrase_score = SequenceMatcher(None, normalized_command, normalized_candidate).ratio()
        if normalized_candidate in normalized_command or normalized_command in normalized_candidate:
            phrase_score = max(phrase_score, 0.95)
        family_overlap = len(command_tokens & family_tokens(capability)) / max(1, len(command_tokens))
        mode_bonus = 0.04 if capability.get("mode") in command_tokens else 0.0
        best = max(best, (overlap * 0.55) + (phrase_score * 0.30) + (family_overlap * 0.15) + mode_bonus)
    return best


def find_matches(
    command: str,
    capabilities: list[dict],
    limit: int = 5,
    preferred_modes: set[str] | None = None,
) -> list[tuple[float, dict]]:
    scored = [(score_command(command, capability), capability) for capability in capabilities]
    if preferred_modes:
        scored = [
            (score + (0.05 if capability.get("mode") in preferred_modes else 0.0), capability)
            for score, capability in scored
        ]
    scored.sort(key=lambda item: item[0], reverse=True)
    return [item for item in scored[:limit] if item[0] >= 0.16]


def related_to(topic: str, capability: dict) -> bool:
    topic_tokens = tokenize(topic)
    searchable = (
        tokenize(capability.get("family", ""))
        | tokenize(capability.get("name", ""))
        | set().union(*(tokenize(phrase) for phrase in capability.get("example_voice_phrases", [])))
        | set(capability.get("required_hardware", []))
        | family_tokens(capability)
    )
    return bool(topic_tokens & {normalize(item) for item in searchable}) or bool(topic_tokens & searchable)
