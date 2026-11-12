import pytest

from tests.test_links import SENIOR_PHONE, register
from tests.test_reminders import appointment, create, medicine
from tests.test_schedule import NOW, log, today


@pytest.fixture(autouse=True)
def fixed_now(monkeypatch):
    # Monday 9 November 2026, 10:00 in the morning in India
    monkeypatch.setattr("app.routers.schedule.utcnow", lambda: NOW)


def test_a_slot_more_than_an_hour_away_cannot_be_answered_yet(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["11:01"])).json()["id"]

    response = log(client, senior, reminder_id, "2026-11-09T11:01:00+05:30", "taken")

    assert response.status_code == 400
    assert response.json()["detail"] == "It is too early to answer this reminder"
    assert today(client, senior).json()[0]["status"] == "pending"


def test_a_slot_exactly_an_hour_away_can_be_answered(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["11:00"])).json()["id"]

    response = log(client, senior, reminder_id, "2026-11-09T11:00:00+05:30", "taken")

    assert response.status_code == 200
    assert response.json()["status"] == "taken"


def test_a_slot_coming_soon_can_be_answered(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["10:30"])).json()["id"]

    assert log(client, senior, reminder_id, "2026-11-09T10:30:00+05:30", "skipped").status_code == 200


def test_a_slot_that_already_passed_can_still_be_answered(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["08:00"])).json()["id"]

    # it shows as missed, but a late answer (like one kept while offline) is accepted
    assert today(client, senior).json()[0]["status"] == "missed"
    response = log(client, senior, reminder_id, "2026-11-09T08:00:00+05:30", "taken")

    assert response.status_code == 200
    assert today(client, senior).json()[0]["status"] == "taken"


def test_an_appointment_hours_away_cannot_be_answered_yet(client):
    senior = register(client, "senior", SENIOR_PHONE)
    when = "2026-11-09T18:00:00+05:30"
    reminder_id = create(client, senior, appointment(one_off_at=when)).json()["id"]

    response = log(client, senior, reminder_id, when, "taken")

    assert response.status_code == 400
    assert response.json()["detail"] == "It is too early to answer this reminder"