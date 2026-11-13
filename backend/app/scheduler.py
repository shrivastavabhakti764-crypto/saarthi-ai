import logging
from datetime import datetime, timezone

from apscheduler.schedulers.background import BackgroundScheduler

from app.db import SessionLocal
from app.escalation import process_due
from app.missed import mark_missed
from app.schedule import utcnow

# uvicorn already prints this logger's INFO lines in the terminal.
log = logging.getLogger("uvicorn.error")


def run_missed_job() -> None:
    db = SessionLocal()
    try:
        count = mark_missed(db, utcnow())
        if count:
            log.info("Marked %s slot(s) as missed", count)
    except Exception:
        db.rollback()
        log.exception("The missed-dose job failed")
    finally:
        db.close()


def run_escalation_job() -> None:
    db = SessionLocal()
    try:
        count = process_due(db, utcnow())
        if count:
            log.info("Escalated %s overdue check-in(s)", count)
    except Exception:
        db.rollback()
        log.exception("The escalation job failed")
    finally:
        db.close()


def start_scheduler() -> BackgroundScheduler:
    """Runs both jobs now, and then every minute."""
    scheduler = BackgroundScheduler(timezone="UTC")
    for func, job_id in (
        (run_missed_job, "mark_missed"),
        (run_escalation_job, "process_escalations"),
    ):
        scheduler.add_job(
            func,
            "interval",
            minutes=1,
            id=job_id,
            max_instances=1,
            coalesce=True,
            next_run_time=datetime.now(timezone.utc),
        )
    scheduler.start()
    return scheduler