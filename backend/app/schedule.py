from datetime import date, datetime, timedelta, timezone
from zoneinfo import ZoneInfo

IST = ZoneInfo("Asia/Kolkata")
MISSED_AFTER = timedelta(minutes=60)


def utcnow() -> datetime:
    return datetime.now(timezone.utc)


def slots_for_day(reminder, day: date) -> list[datetime]:
    """Every moment this reminder should fire on the given (Indian) calendar day."""
    if not reminder.is_active:
        return []
    if reminder.kind == "medicine":
        if day.isoweekday() not in reminder.days_of_week:
            return []
        return [
            datetime.combine(day, t, tzinfo=IST) for t in reminder.reminder_times
        ]
    # appointment: one date and time
    one_off = reminder.one_off_at
    if one_off is not None and one_off.astimezone(IST).date() == day:
        return [one_off.astimezone(IST)]
    return []


def slot_status(logged: str | None, scheduled_for: datetime, now: datetime) -> str:
    """Answered slots keep their answer; silent ones become 'missed' after 60 minutes."""
    if logged is not None:
        return logged
    if scheduled_for + MISSED_AFTER <= now:
        return "missed"
    return "pending"