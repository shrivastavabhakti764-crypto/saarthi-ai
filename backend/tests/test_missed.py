from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

from sqlalchemy import select, update

from app.missed import mark_missed
from app.models import Reminder, ReminderLog
from tests.conftest import TestingSession
from tests.test_links import SENIOR_PHONE, register
from tests.test_reminders import appointment, create, medicine

IST = ZoneInfo("Asia/Kolkata")
NOW = datetime(2026, 11, 9, 10, 0, tzinfo=IST)  # Monday, 10:00 in the morning


def at(day: int, hour: int, minute: int = 0) -> datetime:
    return datetime(2026, 11, day, hour, minute, tzinfo=IST)


def existed_since(db, moment: datetime) -> None:
    """Pretend every reminder was created at [moment] (the API stamps real time)."""
    db.execute(update(Reminder).values(created_at=moment))
    db.commit()


def all_logs(db):
    return db.scalars(select(ReminderLog).order_by(ReminderLog.scheduled_for)).all()


def senior_with(client, body):
    senior = register(client, "senior", SENIOR_PHONE)
    return create(client, senior, body).json()["id"]


def test_an_unanswered_slot_older_than_an_hour_is_marked_missed(client):
    senior_with(
        client,
        medicine(reminder_times=["08:00", "09:30", "10:30"], days_of_week=[1]),
    )
    with TestingSession() as db:
        existed_since(db, NOW - timedelta(days=10))

        written = mark_missed(db, NOW)

        assert written == 1  # 09:30 is only 30 minutes old, 10:30 is ahead
        logs = all_logs(db)
        assert len(logs) == 1
        assert logs[0].scheduled_for == at(9, 8)
        assert logs[0].status == "missed"
        assert logs[0].responded_at is None


def test_running_twice_does_not_write_twice(client):
    senior_with(client, medicine(reminder_times=["08:00"], days_of_week=[1]))
    with TestingSession() as db:
        existed_since(db, NOW - timedelta(days=10))

        assert mark_missed(db, NOW) == 1
        assert mark_missed(db, NOW) == 0
        assert len(all_logs(db)) == 1


def test_an_answered_slot_is_left_alone(client):
    reminder_id = senior_with(client, medicine(reminder_times=["08:00"], days_of_week=[1]))
    with TestingSession() as db:
        existed_since(db, NOW - timedelta(days=10))
        db.add(ReminderLog(reminder_id=reminder_id, scheduled_for=at(9, 8), status="taken"))
        db.commit()

        assert mark_missed(db, NOW) == 0
        assert [log.status for log in all_logs(db)] == ["taken"]


def test_yesterdays_unanswered_slots_are_caught_up(client):
    senior_with(client, medicine(reminder_times=["08:00"]))  # every day
    with TestingSession() as db:
        existed_since(db, NOW - timedelta(days=10))

        assert mark_missed(db, NOW) == 2

        assert [log.scheduled_for for log in all_logs(db)] == [at(8, 8), at(9, 8)]


def test_a_paused_reminder_is_ignored(client):
    senior_with(client, medicine(reminder_times=["08:00"], is_active=False))
    with TestingSession() as db:
        existed_since(db, NOW - timedelta(days=10))

        assert mark_missed(db, NOW) == 0


def test_slots_from_before_the_reminder_existed_are_ignored(client):
    senior_with(
        client,
        medicine(reminder_times=["08:00", "08:45"], days_of_week=[1]),
    )
    with TestingSession() as db:
        existed_since(db, at(9, 8, 30))  # created at 08:30

        assert mark_missed(db, NOW) == 1

        assert [log.scheduled_for for log in all_logs(db)] == [at(9, 8, 45)]


def test_an_appointment_that_passed_without_an_answer_is_missed(client):
    senior_with(client, appointment(one_off_at="2026-11-09T07:00:00+05:30"))
    with TestingSession() as db:
        existed_since(db, NOW - timedelta(days=10))

        assert mark_missed(db, NOW) == 1

        assert all_logs(db)[0].scheduled_for == at(9, 7)


def test_an_appointment_tomorrow_is_not_missed(client):
    senior_with(client, appointment(one_off_at="2026-11-10T07:00:00+05:30"))
    with TestingSession() as db:
        existed_since(db, NOW - timedelta(days=10))

        assert mark_missed(db, NOW) == 0