import json
import logging
import re
from typing import Literal

import httpx
from pydantic import BaseModel, Field, field_validator

from app.config import settings

# uvicorn already prints this logger's lines in the terminal.
log = logging.getLogger("uvicorn.error")

GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
CANNED_REPLY = "I'm having trouble right now, please try again in a moment."

SYSTEM_PROMPT = """You are Saarthi, a warm, patient companion for an elderly person who lives alone in India. You chat with them by voice or text.

Rules:
1. Reply in the same language and style the person used: Hindi (Devanagari), Hinglish (Hindi in English letters) or English. If they switch language, you switch too.
2. Be warm and short (1 to 3 sentences), use simple words, never sound alarming. No lists, no markdown.
3. Never diagnose, never prescribe, never give medical advice or name medicines or doses. Do not suggest remedies, rest or any treatment. When they mention a health problem, show that you care and gently suggest telling their family or a doctor.
4. If they seem lonely, sometimes (not in every message) suggest calling family, a short walk, a hobby, or offer a small story or quiz.
5. Fill the symptom fields only if, in THIS message, they mention a health complaint (pain, dizziness, fever, breathlessness and so on). symptom_text is what they said in their own words. symptom_key is one short normalised English word such as headache, chest_pain, dizziness, fever.
6. Set asked_for_help to true only if they clearly ask for help.

Return ONLY a JSON object with exactly these keys:
{"reply": string, "language": "hindi" or "hinglish" or "english", "emotion": "neutral" or "happy" or "concerned", "symptom_detected": true or false, "symptom_text": string, "symptom_key": string, "asked_for_help": true or false}
Use empty strings for symptom_text and symptom_key when there is no symptom."""


class LlmResult(BaseModel):
    reply: str = Field(min_length=1)
    language: Literal["hindi", "hinglish", "english"] = "hinglish"
    emotion: Literal["neutral", "happy", "concerned"] = "neutral"
    symptom_detected: bool = False
    symptom_text: str = ""
    symptom_key: str = ""
    asked_for_help: bool = False

    @field_validator("language", "emotion", mode="before")
    @classmethod
    def lowercase(cls, v):
        return v.strip().lower() if isinstance(v, str) else v


def _contents(history: list[tuple[str, str]], message: str) -> list[dict]:
    """Turns (sender, text) pairs into Gemini turns: same speaker twice in a
    row is merged, and the conversation must start with the person."""
    contents: list[dict] = []
    for sender, text in [*history, ("senior", message)]:
        role = "user" if sender == "senior" else "model"
        if contents and contents[-1]["role"] == role:
            contents[-1]["parts"][0]["text"] += "\n" + text
        else:
            contents.append({"role": role, "parts": [{"text": text}]})
    while contents and contents[0]["role"] == "model":
        contents.pop(0)
    return contents


def _call_gemini(model: str, contents: list[dict]) -> str:
    response = httpx.post(
        GEMINI_URL.format(model=model),
        headers={"x-goog-api-key": settings.gemini_api_key},
        json={
            "systemInstruction": {"parts": [{"text": SYSTEM_PROMPT}]},
            "contents": contents,
            "generationConfig": {
                "responseMimeType": "application/json",
                "temperature": 0.7,
                "maxOutputTokens": 1024,
            },
        },
        timeout=25.0,
    )
    response.raise_for_status()
    return response.json()["candidates"][0]["content"]["parts"][0]["text"]


def _parse(text: str) -> LlmResult:
    match = re.search(r"\{.*\}", text, re.DOTALL)
    if match is None:
        raise ValueError("no JSON object in the answer")
    return LlmResult.model_validate(json.loads(match.group(0)))


_SYMPTOM_WORDS = {
    "headache": ["headache", "head ache", "sar dard", "sir dard", "सिर दर्द", "सिरदर्द"],
    "chest_pain": ["chest pain", "seene mein dard", "seene me dard", "सीने"],
    "dizziness": ["dizzy", "dizziness", "chakkar", "चक्कर"],
    "fever": ["fever", "bukhar", "बुखार"],
    "breathlessness": ["breathless", "saans", "सांस", "साँस"],
    "stomach_pain": ["stomach", "pet dard", "पेट दर्द"],
    "weakness": ["weakness", "kamzori", "कमज़ोरी", "कमजोरी"],
}
_HELP_WORDS = ["help", "madad", "bachao", "मदद"]


def fallback_result(message: str) -> LlmResult:
    """Used when the AI cannot be reached: a friendly line plus a simple keyword check."""
    text = message.lower()
    key = next(
        (k for k, words in _SYMPTOM_WORDS.items() if any(w in text for w in words)),
        "",
    )
    return LlmResult(
        reply=CANNED_REPLY,
        language="hindi" if re.search("[\u0900-\u097f]", message) else "english",
        emotion="concerned" if key else "neutral",
        symptom_detected=bool(key),
        symptom_text=message if key else "",
        symptom_key=key,
        asked_for_help=any(w in text for w in _HELP_WORDS),
    )


def generate_reply(history: list[tuple[str, str]], message: str) -> LlmResult:
    """Asks Gemini. A bad answer is retried once; an outage or rate limit moves
    on to the second model; if everything fails the keyword fallback answers."""
    if not settings.gemini_api_key:
        return fallback_result(message)
    contents = _contents(history, message)
    for model in (settings.gemini_model, settings.gemini_fallback_model):
        for _attempt in range(2):
            try:
                return _parse(_call_gemini(model, contents))
            except (ValueError, KeyError, IndexError, TypeError) as e:
                log.warning("Bad answer from %s: %r", model, e)  # try the same model once more
            except httpx.HTTPError as e:
                log.warning("Could not reach %s: %r", model, e)
                break  # go to the next model
    return fallback_result(message)