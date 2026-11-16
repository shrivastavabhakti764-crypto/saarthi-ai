"""Escalation rules (TRD 2.6).

The rules count mentions, missed doses and explicit help requests. They never
judge how serious something is medically.
"""
import logging
from collections import Counter
from datetime import datetime, timedelta

from sqlalchemy import func, select, update
from sqlalchemy.orm import Session

from app.config import settings
from app.models import (
    Escalation,
    NomineeLink,
    Notification,
    Reminder,
    ReminderLog,
    SymptomLog,
    User,
)
from app.push import send_push

log = logging.getLogger("uvicorn.error")

WINDOW = timedelta(hours=24)
HELP_KEY = "help_request"


def get_active(db: Session, senior_id: int) -> Escalation | None:
    """The "Are you okay?" that is still waiting for an answer, if any."""
    return db.scalars(
        select(Escalation)
        .where(Escalation.senior_id == senior_id, Escalation.status == "awaiting_senior")
        .order_by(Escalation.id.desc())
    ).first()


def _same_symptom_count(db: Session, senior_id: int, key: str, now: datetime) -> int:
    return (
        db.scalar(
            select(func.count(SymptomLog.id)).where(
                SymptomLog.senior_id == senior_id,
                SymptomLog.symptom_key == key,
                SymptomLog.created_at > now - WINDOW,
            )
        )
        or 0
    )


def _missed_doses(db: Session, senior_id: int, now: datetime) -> int:
    return (
        db.scalar(
            select(func.count(ReminderLog.id))
            .select_from(ReminderLog)
            .join(Reminder, Reminder.id == ReminderLog.reminder_id)
            .where(
                Reminder.senior_id == senior_id,
                ReminderLog.status == "missed",
                ReminderLog.scheduled_for > now - WINDOW,
                ReminderLog.scheduled_for <= now,
            )
        )
        or 0
    )


def decide_reason(db: Session, symptom: SymptomLog, now: datetime) -> str | None:
    """Which of the three rules (if any) this new symptom log triggers."""
    if symptom.asked_for_help:
        return "help_requested"
    if symptom.symptom_key == HELP_KEY:
        return None
    if _same_symptom_count(db, symptom.senior_id, symptom.symptom_key, now) >= 2:
        return "repeated_symptom"
    if _missed_doses(db, symptom.senior_id, now) >= 1:
        return "symptom_and_missed_dose"
    return None


def build_summary(db: Session, esc: Escalation, now: datetime, by_senior: bool) -> str:
    """Plain-language update for the family. No advice, no diagnosis."""
    senior = db.get(User, esc.senior_id)
    name = senior.name if senior else "your family member"

    keys = db.scalars(
        select(SymptomLog.symptom_key).where(
            SymptomLog.senior_id == esc.senior_id,
            SymptomLog.symptom_key != HELP_KEY,
            SymptomLog.created_at > now - WINDOW,
        )
    ).all()
    counts = Counter(k.replace("_", " ") for k in keys)
    asked_help = bool(
        db.scalar(
            select(func.count(SymptomLog.id)).where(
                SymptomLog.senior_id == esc.senior_id,
                SymptomLog.asked_for_help.is_(True),
                SymptomLog.created_at > now - WINDOW,
            )
        )
    )
    missed = _missed_doses(db, esc.senior_id, now)

    parts = []
    if counts:
        listed = ", ".join(f"{k} ({n} times)" if n > 1 else k for k, n in counts.items())
        parts.append(f"mentioned {listed}")
    if asked_help:
        parts.append("asked for help in the chat")
    if missed:
        parts.append(f"missed {missed} medicine reminder{'s' if missed != 1 else ''}")
    what = "; ".join(parts) if parts else "may need a call"

    if by_senior:
        outcome = f"{name} said they need help."
    else:
        outcome = f"Saarthi asked if {name} was okay and did not get a reply."
    return (
        f"Update about {name}: in the last 24 hours, {name} {what}. "
        f"{outcome} You may want to call {name}."
    )


def maybe_start(db: Session, symptom: SymptomLog, now: datetime) -> Escalation | None:
    """Call right after a symptom log was saved (flushed).

    Returns the escalation that is waiting for the senior's answer (new or
    already open), or None when there is nothing to ask.
    """
    existing = get_active(db, symptom.senior_id)
    if existing is not None:
        if symptom.asked_for_help:
            # Asking for help while "Are you okay?" is pending: no more waiting.
            escalate(db, existing, now, by_senior=True)
            return None
        return existing

    reason = decide_reason(db, symptom, now)
    if reason is None:
        return None
    if reason == "repeated_symptom":
        symptom.flag = "repeated"

    esc = Escalation(
        senior_id=symptom.senior_id,
        symptom_log_id=symptom.id,
        reason=reason,
        status="awaiting_senior",
        prompted_at=now,
        grace_deadline=now + timedelta(minutes=settings.escalation_grace_minutes),
    )
    db.add(esc)
    db.flush()
    return esc


def resolve_ok(db: Session, esc: Escalation, now: datetime) -> bool:
    """Senior said "I'm okay". Nobody is notified."""
    row = db.execute(
        update(Escalation)
        .where(Escalation.id == esc.id, Escalation.status == "awaiting_senior")
        .values(status="resolved_ok", resolved_at=now)
        .returning(Escalation.id)
    ).first()
    return row is not None


def notify_nominees(
    db: Session, esc: Escalation, summary: str, now: datetime
) -> None:
    """Pushes the summary to every nominee linked to this senior and records
    one row per nominee in `notifications`. Never raises: a push problem must
    not stop the escalation itself."""
    try:
        senior = db.get(User, esc.senior_id)
        senior_name = senior.name if senior else "your family member"
        nominees = db.scalars(
            select(User)
            .join(NomineeLink, NomineeLink.nominee_id == User.id)
            .where(NomineeLink.senior_id == esc.senior_id)
        ).all()
        for nominee in nominees:
            if not nominee.fcm_token:
                sent, error = False, "no push token"
            else:
                sent, error = send_push(
                    nominee.fcm_token, f"Alert about {senior_name}", summary
                )
            db.add(
                Notification(
                    escalation_id=esc.id,
                    nominee_id=nominee.id,
                    channel="push",
                    summary_text=summary,
                    status="sent" if sent else "failed",
                    error=error,
                    sent_at=now if sent else None,
                )
            )
    except Exception:
        log.exception("Could not notify nominees for escalation %s", esc.id)


def escalate(db: Session, esc: Escalation, now: datetime, *, by_senior: bool) -> bool:
    """Moves to 'escalated', stores the summary and pushes it to the family."""
    summary = build_summary(db, esc, now, by_senior)
    row = db.execute(
        update(Escalation)
        .where(Escalation.id == esc.id, Escalation.status == "awaiting_senior")
        .values(status="escalated", summary_text=summary)
        .returning(Escalation.id)
    ).first()
    if row is None:
        return False
    notify_nominees(db, esc, summary, now)
    return True


def process_due(db: Session, now: datetime) -> int:
    """Escalates every check-in whose grace deadline has passed."""
    due = db.scalars(
        select(Escalation).where(
            Escalation.status == "awaiting_senior",
            Escalation.grace_deadline <= now,
        )
    ).all()
    count = 0
    for esc in due:
        if escalate(db, esc, now, by_senior=False):
            count += 1
    db.commit()
    return count