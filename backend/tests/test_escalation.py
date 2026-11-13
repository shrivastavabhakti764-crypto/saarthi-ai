from datetime import timedelta

from app.escalation import process_due
from app.models import Escalation
from app.schedule import utcnow
from tests.conftest import TestingSession
from tests.test_chat import fake_llm, result, say, senior_who_agreed  # noqa: F401
from tests.test_links import auth


def mention(fake_llm, key="headache", **extra):
    fake_llm.result = result(
        symptom_detected=True,
        symptom_text="mujhe dard hai",
        symptom_key=key,
        emotion="concerned",
        **extra,
    )


def open_check_in(client, fake_llm, token):
    """Two mentions of the same thing -> an 'Are you okay?' is waiting."""
    mention(fake_llm)
    say(client, token, "sir dard hai")
    return say(client, token, "phir dard hai").json()["escalation_id"]


def test_same_symptom_twice_asks_are_you_okay(client, fake_llm):
    token = senior_who_agreed(client)
    mention(fake_llm)
    assert say(client, token, "sir dard hai").json()["escalation_id"] is None

    second = say(client, token, "phir dard hai").json()
    assert second["escalation_id"] is not None

    active = client.get("/escalations/active", headers=auth(token)).json()
    assert active["id"] == second["escalation_id"]
    assert active["reason"] == "repeated_symptom"


def test_help_request_asks_first_and_second_ask_escalates_now(client, fake_llm):
    token = senior_who_agreed(client)
    fake_llm.result = result(asked_for_help=True, emotion="concerned")
    first = say(client, token, "madad karo").json()
    assert first["escalation_id"] is not None

    say(client, token, "madad karo jaldi")
    with TestingSession() as db:
        esc = db.get(Escalation, first["escalation_id"])
        assert esc.status == "escalated"
        assert "need help" in esc.summary_text or "asked for help" in esc.summary_text


def test_answers_ok_or_need_help(client, fake_llm):
    token = senior_who_agreed(client)
    esc_id = open_check_in(client, fake_llm, token)

    url = f"/escalations/{esc_id}/respond"
    done = client.post(url, json={"answer": "ok"}, headers=auth(token)).json()
    assert done["status"] == "resolved_ok"

    # A second answer changes nothing.
    again = client.post(url, json={"answer": "need_help"}, headers=auth(token)).json()
    assert again["status"] == "resolved_ok"

    # A new check-in answered with "need help" is escalated with a summary.
    mention(fake_llm)
    new_id = say(client, token, "dard ho raha hai").json()["escalation_id"]
    res = client.post(
        f"/escalations/{new_id}/respond",
        json={"answer": "need_help"},
        headers=auth(token),
    ).json()
    assert res["status"] == "escalated"
    with TestingSession() as db:
        assert db.get(Escalation, new_id).summary_text.startswith("Update about")


def test_no_answer_in_time_escalates(client, fake_llm):
    token = senior_who_agreed(client)
    esc_id = open_check_in(client, fake_llm, token)

    with TestingSession() as db:
        assert process_due(db, utcnow()) == 0  # still inside the grace window
        assert process_due(db, utcnow() + timedelta(hours=1)) == 1
        esc = db.get(Escalation, esc_id)
        assert esc.status == "escalated"
        assert "did not get a reply" in esc.summary_text