from datetime import datetime
from zoneinfo import ZoneInfo

import pytest

from tests.test_links import NOMINEE_PHONE, OTHER_NOMINEE_PHONE, SENIOR_PHONE, auth, register
from tests.test_reminders import (
    OTHER_SENIOR_PHONE,
    appointment,
    create,
    link,
    medicine,
)

IST = ZoneInfo("Asia/Kolkata")
NOW = datetime(2026, 11, 9, 10, 0, tzinfo=IST)  # a Monday, 10:00 in the morning


@pytest.fixture(autouse=True)
def fixed_now(monkeypatch):
    monkeypatch.setattr("app.routers.schedule.utcnow", lambda: NOW)


def today(client, token):
    return client.get("/reminders/today", headers=auth(token))


def log(client, token, reminder_id, scheduled_for, status):
    return client.post(
        f"/reminders/{reminder_id}/log",
        json={"scheduled_for": scheduled_for, "status": status},
        headers=auth(token),
    )


def test_today_requires_login(client):
    assert client.get("/reminders/today").status_code == 401


def test_a_nominee_cannot_use_the_senior_schedule(client):
    senior = register(client, "senior", SENIOR_PHONE)
    nominee = register(client, "nominee", NOMINEE_PHONE)
    link(client, senior, nominee)
    reminder_id = create(client, senior, medicine()).json()["id"]

    assert today(client, nominee).status_code == 403
    assert log(client, nominee, reminder_id, "2026-11-09T08:00:00+05:30", "taken").status_code == 403


def test_today_lists_every_slot_with_its_status(client):
    senior = register(client, "senior", SENIOR_PHONE)
    create(client, senior, medicine(title="BP", reminder_times=["10:30", "08:00", "09:30"]))

    response = today(client, senior)

    assert response.status_code == 200
    slots = response.json()
    assert [s["scheduled_for"][11:16] for s in slots] == ["08:00", "09:30", "10:30"]
    # 08:00 is 2 hours ago (missed); 09:30 is 30 minutes ago (still waiting); 10:30 is ahead.
    assert [s["status"] for s in slots] == ["missed", "pending", "pending"]
    assert slots[0]["title"] == "BP"
    assert slots[0]["responded_at"] is None


def test_today_skips_other_days_and_paused_reminders(client):
    senior = register(client, "senior", SENIOR_PHONE)
    create(client, senior, medicine(title="Tuesday only", days_of_week=[2]))
    create(client, senior, medicine(title="Paused", is_active=False))
    create(client, senior, medicine(title="Monday", days_of_week=[1], reminder_times=["11:00"]))

    titles = [s["title"] for s in today(client, senior).json()]

    assert titles == ["Monday"]


def test_an_appointment_shows_only_on_its_day(client):
    senior = register(client, "senior", SENIOR_PHONE)
    create(client, senior, appointment(title="Today visit", one_off_at="2026-11-09T15:00:00+05:30"))
    create(client, senior, appointment(title="Tomorrow visit", one_off_at="2026-11-10T15:00:00+05:30"))

    slots = today(client, senior).json()

    assert [s["title"] for s in slots] == ["Today visit"]
    assert slots[0]["kind"] == "appointment"
    assert slots[0]["status"] == "pending"


def test_marking_a_dose_as_taken(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["08:00", "09:30"])).json()["id"]

    response = log(client, senior, reminder_id, "2026-11-09T08:00:00+05:30", "taken")

    assert response.status_code == 200
    assert response.json()["status"] == "taken"
    assert response.json()["responded_at"] is not None
    assert [s["status"] for s in today(client, senior).json()] == ["taken", "pending"]


def test_a_slot_can_be_changed_after_marking(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["09:30"])).json()["id"]

    assert log(client, senior, reminder_id, "2026-11-09T09:30:00+05:30", "skipped").status_code == 200
    assert log(client, senior, reminder_id, "2026-11-09T09:30:00+05:30", "taken").status_code == 200

    slots = today(client, senior).json()
    assert len(slots) == 1
    assert slots[0]["status"] == "taken"


def test_the_time_may_be_sent_in_any_time_zone(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["08:00"])).json()["id"]

    # 02:30 UTC is the same moment as 08:00 in India
    response = log(client, senior, reminder_id, "2026-11-09T02:30:00+00:00", "taken")

    assert response.status_code == 200
    assert today(client, senior).json()[0]["status"] == "taken"


def test_logging_needs_a_real_scheduled_time(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(
        client, senior, medicine(reminder_times=["08:00"], days_of_week=[1])
    ).json()["id"]

    wrong_time = log(client, senior, reminder_id, "2026-11-09T08:15:00+05:30", "taken")
    wrong_day = log(client, senior, reminder_id, "2026-11-10T08:00:00+05:30", "taken")

    assert wrong_time.status_code == 400
    assert wrong_day.status_code == 400


def test_another_seniors_reminder_is_not_found(client):
    senior = register(client, "senior", SENIOR_PHONE)
    other = register(client, "senior", OTHER_SENIOR_PHONE)
    reminder_id = create(client, other, medicine(reminder_times=["08:00"])).json()["id"]

    response = log(client, senior, reminder_id, "2026-11-09T08:00:00+05:30", "taken")

    assert response.status_code == 404
    assert today(client, senior).json() == []


def test_log_needs_taken_or_skipped(client):
    senior = register(client, "senior", SENIOR_PHONE)
    reminder_id = create(client, senior, medicine(reminder_times=["08:00"])).json()["id"]
    assert log(client, senior, reminder_id, "2026-11-09T08:00:00+05:30", "missed").status_code == 422


def test_log_requires_login(client):
    response = client.post(
        "/reminders/1/log",
        json={"scheduled_for": "2026-11-09T08:00:00+05:30", "status": "taken"},
    )
    assert response.status_code == 401