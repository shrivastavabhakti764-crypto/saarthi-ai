import pytest
from sqlalchemy import select

from app.llm import LlmResult
from app.models import SymptomLog
from tests.conftest import TestingSession
from tests.test_links import NOMINEE_PHONE, SENIOR_PHONE, auth, register

OTHER_SENIOR_PHONE = "9876543299"


def result(**fields):
    base = {"reply": "Namaste!", "language": "hinglish", "emotion": "happy"}
    base.update(fields)
    return LlmResult(**base)


class FakeLlm:
    def __init__(self):
        self.calls = []
        self.result = result()

    def __call__(self, history, message):
        self.calls.append((list(history), message))
        return self.result


@pytest.fixture
def fake_llm(monkeypatch):
    fake = FakeLlm()
    monkeypatch.setattr("app.routers.chat.generate_reply", fake)
    return fake


def senior_who_agreed(client, phone=SENIOR_PHONE):
    token = register(client, "senior", phone)
    assert client.post("/me/consent", headers=auth(token)).status_code == 200
    return token


def say(client, token, message="namaste"):
    return client.post("/chat", json={"message": message}, headers=auth(token))


def symptom_rows():
    with TestingSession() as db:
        return db.scalars(select(SymptomLog)).all()


def test_chat_requires_login(client, fake_llm):
    assert client.post("/chat", json={"message": "hi"}).status_code == 401


def test_a_nominee_cannot_chat(client, fake_llm):
    nominee = register(client, "nominee", NOMINEE_PHONE)
    assert say(client, nominee).status_code == 403


def test_a_senior_must_agree_to_the_consent_first(client, fake_llm):
    senior = register(client, "senior", SENIOR_PHONE)
    assert say(client, senior).status_code == 403
    assert fake_llm.calls == []


def test_a_message_gets_a_reply_and_both_are_saved(client, fake_llm):
    senior = senior_who_agreed(client)

    response = say(client, senior, "namaste Saarthi")

    assert response.status_code == 200
    assert response.json() == {
        "reply": "Namaste!",
        "language": "hinglish",
        "emotion": "happy",
        "symptom_detected": False,
        "asked_for_help": False,
    }
    saved = client.get("/chat/history", headers=auth(senior)).json()
    assert [(m["sender"], m["message_text"]) for m in saved] == [
        ("senior", "namaste Saarthi"),
        ("ai", "Namaste!"),
    ]
    assert symptom_rows() == []


def test_the_model_sees_the_earlier_conversation(client, fake_llm):
    senior = senior_who_agreed(client)

    say(client, senior, "pehla")
    say(client, senior, "doosra")

    history, message = fake_llm.calls[1]
    assert message == "doosra"
    assert history == [("senior", "pehla"), ("ai", "Namaste!")]


def test_history_is_private_and_can_be_limited(client, fake_llm):
    senior = senior_who_agreed(client)
    other = senior_who_agreed(client, OTHER_SENIOR_PHONE)
    say(client, senior, "ek")
    say(client, senior, "do")
    say(client, other, "mera alag")

    last_two = client.get("/chat/history?limit=2", headers=auth(senior)).json()
    others = client.get("/chat/history", headers=auth(other)).json()

    assert [m["message_text"] for m in last_two] == ["do", "Namaste!"]
    assert [m["message_text"] for m in others] == ["mera alag", "Namaste!"]


def test_a_health_complaint_is_logged(client, fake_llm):
    senior = senior_who_agreed(client)
    fake_llm.result = result(
        emotion="concerned",
        symptom_detected=True,
        symptom_text="sar dard ho raha hai",
        symptom_key="Head Ache!",
    )

    response = say(client, senior, "sar dard ho raha hai")

    assert response.json()["symptom_detected"] is True
    rows = symptom_rows()
    assert len(rows) == 1
    assert rows[0].symptom_key == "head_ache"
    assert rows[0].symptom_text == "sar dard ho raha hai"
    assert rows[0].flag == "noted"
    assert rows[0].asked_for_help is False
    assert rows[0].chat_message_id is not None


def test_asking_for_help_is_logged(client, fake_llm):
    senior = senior_who_agreed(client)
    fake_llm.result = result(asked_for_help=True)

    response = say(client, senior, "mujhe madad chahiye")

    assert response.json()["asked_for_help"] is True
    rows = symptom_rows()
    assert len(rows) == 1
    assert rows[0].symptom_key == "help_request"
    assert rows[0].flag == "help_requested"
    assert rows[0].asked_for_help is True


def test_an_empty_message_is_rejected(client, fake_llm):
    senior = senior_who_agreed(client)
    assert say(client, senior, "   ").status_code == 422
    assert fake_llm.calls == []