from datetime import datetime, time, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.log_schemas import LogRequest, TodaySlotOut
from app.models import Reminder, ReminderLog, User
from app.schedule import IST, slot_status, slots_for_day, utcnow

router = APIRouter(prefix="/reminders", tags=["schedule"])


def _require_senior(user: User) -> None:
    if user.role != "senior":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only senior citizens use the daily schedule",
        )


def _slot_out(
    reminder: Reminder, slot: datetime, log: ReminderLog | None, now: datetime
) -> TodaySlotOut:
    return TodaySlotOut(
        reminder_id=reminder.id,
        kind=reminder.kind,
        title=reminder.title,
        dosage=reminder.dosage,
        scheduled_for=slot,
        status=slot_status(log.status if log else None, slot, now),
        responded_at=log.responded_at if log else None,
    )


@router.get("/today", response_model=list[TodaySlotOut])
def today(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Today's slots for the senior, in time order, each with its status."""
    _require_senior(current_user)
    now = utcnow()
    day = now.astimezone(IST).date()
    day_start = datetime.combine(day, time.min, tzinfo=IST)
    day_end = day_start + timedelta(days=1)

    reminders = db.scalars(
        select(Reminder).where(
            Reminder.senior_id == current_user.id, Reminder.is_active.is_(True)
        )
    ).all()
    if not reminders:
        return []

    logs = {
        (log.reminder_id, log.scheduled_for.astimezone(timezone.utc)): log
        for log in db.scalars(
            select(ReminderLog).where(
                ReminderLog.reminder_id.in_([r.id for r in reminders]),
                ReminderLog.scheduled_for >= day_start,
                ReminderLog.scheduled_for < day_end,
            )
        )
    }

    slots = [(r, s) for r in reminders for s in slots_for_day(r, day)]
    slots.sort(key=lambda pair: (pair[1], pair[0].id))
    return [
        _slot_out(r, s, logs.get((r.id, s.astimezone(timezone.utc))), now)
        for r, s in slots
    ]


@router.post("/{reminder_id}/log", response_model=TodaySlotOut)
def log_slot(
    reminder_id: int,
    body: LogRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The senior marks one slot as taken or skipped (can be changed later)."""
    _require_senior(current_user)
    reminder = db.get(Reminder, reminder_id)
    if reminder is None or reminder.senior_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found"
        )

    wanted = body.scheduled_for.astimezone(timezone.utc)
    day = body.scheduled_for.astimezone(IST).date()
    slot = next(
        (s for s in slots_for_day(reminder, day) if s.astimezone(timezone.utc) == wanted),
        None,
    )
    if slot is None:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="That is not a scheduled time for this reminder",
        )

    now = utcnow()

    def find_log() -> ReminderLog | None:
        return db.scalar(
            select(ReminderLog).where(
                ReminderLog.reminder_id == reminder.id,
                ReminderLog.scheduled_for == slot,
            )
        )

    log = find_log()
    if log is None:
        log = ReminderLog(reminder_id=reminder.id, scheduled_for=slot)
        db.add(log)
    log.status = body.status
    log.responded_at = now
    try:
        db.commit()
    except IntegrityError:
        # Two taps at the same moment: the other request made the row first.
        db.rollback()
        log = find_log()
        log.status = body.status
        log.responded_at = now
        db.commit()

    db.refresh(log)
    return _slot_out(reminder, slot, log, now)