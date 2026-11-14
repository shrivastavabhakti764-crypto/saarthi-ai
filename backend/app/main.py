from contextlib import asynccontextmanager

from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.config import settings
from app.db import get_db
from app.routers import alerts, auth, chat, escalations, links, reminders, schedule, users
from app.scheduler import start_scheduler


@asynccontextmanager
async def lifespan(app: FastAPI):
    scheduler = start_scheduler() if settings.scheduler_enabled else None
    try:
        yield
    finally:
        if scheduler is not None:
            scheduler.shutdown(wait=False)


app = FastAPI(title="Saarthi.AI API", version="0.1.0", lifespan=lifespan)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(links.router)
app.include_router(reminders.router)
app.include_router(schedule.router)
app.include_router(chat.router)
app.include_router(escalations.router)
app.include_router(alerts.router)


@app.get("/health")
def health(db: Session = Depends(get_db)):
    """Returns ok only if the API is up AND the database answers."""
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ok", "database": "connected"}