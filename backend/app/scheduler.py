import logging
from datetime import datetime, timezone

from apscheduler.schedulers.background import BackgroundScheduler

from app.db import SessionLocal
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


def start_scheduler() -> BackgroundScheduler:
    """Runs the missed-dose job now, and then every minute."""
    scheduler = BackgroundScheduler(timezone="UTC")
    scheduler.add_job(
        run_missed_job,
        "interval",
        minutes=1,
        id="mark_missed",
        max_instances=1,
        coalesce=True,
        next_run_time=datetime.now(timezone.utc),
    )
    scheduler.start()
    return scheduler