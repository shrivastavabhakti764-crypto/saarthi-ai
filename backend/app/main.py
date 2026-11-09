from fastapi import Depends, FastAPI, HTTPException
from sqlalchemy import text
from sqlalchemy.orm import Session

from app.db import get_db
from app.routers import auth, links, reminders, users

app = FastAPI(title="Saarthi.AI API", version="0.1.0")

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(links.router)
app.include_router(reminders.router)


@app.get("/health")
def health(db: Session = Depends(get_db)):
    """Returns ok only if the API is up AND the database answers."""
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        raise HTTPException(status_code=503, detail="database unavailable")
    return {"status": "ok", "database": "connected"}