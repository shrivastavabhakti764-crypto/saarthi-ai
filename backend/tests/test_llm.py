import httpx
import pytest

from app import llm
from app.config import settings

GOOD = (
    '{"reply": "Namaste! Main theek hoon.", "language": "hinglish", "emotion": "happy", '
    '"symptom_detected": false, "symptom_text": "", "symptom_key": "", "asked_for_help": false}'
)


@pytest.fixture(autouse=True)
def api_key(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "test-key")


def test_an_answer_inside_a_code_fence_is_read(monkeypatch):
    monkeypatch.setattr(llm, "_call_gemini", lambda model, contents: "```json\n" + GOOD + "\n```")

    result = llm.generate_reply([], "namaste")

    assert result.reply == "Namaste! Main theek hoon."
    assert result.emotion == "happy"


def test_bad_json_is_retried_once_on_the_same_model(monkeypatch):
    answers = iter(["not json at all", GOOD])
    calls = []

    def fake(model, contents):
        calls.append(model)
        return next(answers)

    monkeypatch.setattr(llm, "_call_gemini", fake)

    result = llm.generate_reply([], "namaste")

    assert result.reply == "Namaste! Main theek hoon."
    assert calls == [settings.gemini_model, settings.gemini_model]


def test_an_outage_moves_on_to_the_second_model(monkeypatch):
    calls = []

    def fake(model, contents):
        calls.append(model)
        if model == settings.gemini_model:
            raise httpx.ConnectError("down")
        return GOOD

    monkeypatch.setattr(llm, "_call_gemini", fake)

    result = llm.generate_reply([], "namaste")

    assert result.reply == "Namaste! Main theek hoon."
    assert calls == [settings.gemini_model, settings.gemini_fallback_model]


def test_when_everything_fails_a_friendly_reply_and_keyword_check_are_used(monkeypatch):
    def fake(model, contents):
        raise httpx.ConnectError("down")

    monkeypatch.setattr(llm, "_call_gemini", fake)

    result = llm.generate_reply([], "mujhe bahut sar dard ho raha hai")

    assert "trouble" in result.reply
    assert result.symptom_detected is True
    assert result.symptom_key == "headache"


def test_without_a_key_the_ai_is_not_called(monkeypatch):
    monkeypatch.setattr(settings, "gemini_api_key", "")

    def fake(model, contents):
        raise AssertionError("must not be called")

    monkeypatch.setattr(llm, "_call_gemini", fake)

    assert llm.generate_reply([], "I feel dizzy").symptom_key == "dizziness"
    assert llm.generate_reply([], "please help me").asked_for_help is True


def test_turns_of_the_same_speaker_are_merged():
    contents = llm._contents(
        [("senior", "hi"), ("senior", "hello"), ("ai", "namaste")], "kaise ho"
    )

    assert [c["role"] for c in contents] == ["user", "model", "user"]
    assert contents[0]["parts"][0]["text"] == "hi\nhello"