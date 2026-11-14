from app.models import NomineeLink
from tests.conftest import TestingSession
from tests.test_chat import fake_llm, say, senior_who_agreed  # noqa: F401
from tests.test_escalation import open_check_in
from tests.test_links import NOMINEE_PHONE, auth, register


def escalate_by_help(client, senior, esc_id):
    return client.post(
        f"/escalations/{esc_id}/respond",
        json={"answer": "need_help"},
        headers=auth(senior),
    )


def test_nominee_sees_the_alert_of_a_linked_senior(client, fake_llm):
    senior = senior_who_agreed(client)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    senior_id = client.get("/me", headers=auth(senior)).json()["id"]
    nominee_id = client.get("/me", headers=auth(nominee)).json()["id"]
    with TestingSession() as db:
        db.add(NomineeLink(senior_id=senior_id, nominee_id=nominee_id, relationship="Son"))
        db.commit()

    esc_id = open_check_in(client, fake_llm, senior)
    # Still waiting for the senior: the family is not told yet.
    assert client.get("/alerts", headers=auth(nominee)).json() == []

    escalate_by_help(client, senior, esc_id)
    alerts = client.get("/alerts", headers=auth(nominee)).json()
    assert len(alerts) == 1
    assert alerts[0]["summary"].startswith("Update about")
    assert "message_text" not in alerts[0]


def test_unlinked_nominee_sees_nothing_and_senior_is_refused(client, fake_llm):
    senior = senior_who_agreed(client)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    esc_id = open_check_in(client, fake_llm, senior)
    escalate_by_help(client, senior, esc_id)

    assert client.get("/alerts", headers=auth(nominee)).json() == []
    assert client.get("/alerts", headers=auth(senior)).status_code == 403