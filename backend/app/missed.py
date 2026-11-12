from datetime import datetime, time, timedelta, timezone

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.orm import Session

from app.models import Reminder, ReminderLog
from app.schedule import IST, MISSED_AFTER, slots_for_day

# Also look at yesterday, in case the server was switched off overnight.
CATCH_UP_DAYS = 1


def mark_missed(db: Session, now: datetime) -> int:
    """Writes a 'missed' log for every slot that got no answer and is more than
    60 minutes old. Slots from before the reminder existed are ignored.
    Returns how many rows were written."""
    today = now.astimezone(IST).date()
    days = [today - timedelta(days=d) for d in range(CATCH_UP_DAYS, -1, -1)]
    window_start = datetime.combine(days[0], time.min, tzinfo=IST)

    reminders = db.scalars(
        select(Reminder).where(Reminder.is_active.is_(True))
    ).all()
    if not reminders:
        return 0

    answered = {
        (log.reminder_id, log.scheduled_for.astimezone(timezone.utc))
        for log in db.scalars(
            select(ReminderLog).where(
                ReminderLog.reminder_id.in_([r.id for r in reminders]),
                ReminderLog.scheduled_for >= window_start,
            )
        )
    }

    written = 0
    for reminder in reminders:
        for day in days:
            for slot in slots_for_day(reminder, day):
                if slot + MISSED_AFTER > now:
                    continue  # not missed yet
                if slot < reminder.created_at:
                    continue  # the reminder did not exist then
                if (reminder.id, slot.astimezone(timezone.utc)) in answered:
                    continue
                # RETURNING gives a row only when something was really inserted
                # (rowcount is -1 with this driver, so it cannot be trusted).
                inserted = db.execute(
                    insert(ReminderLog)
                    .values(reminder_id=reminder.id, scheduled_for=slot, status="missed")
                    .on_conflict_do_nothing(
                        index_elements=["reminder_id", "scheduled_for"]
                    )
                    .returning(ReminderLog.id)
                ).first()
                if inserted is not None:
                    written += 1
    db.commit()
    return written