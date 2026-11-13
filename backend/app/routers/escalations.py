from datetime import datetime
from typing import Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel, ConfigDict
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.escalation import escalate, get_active, resolve_ok
from app.models import Escalation, User
from app.schedule import utcnow

router = APIRouter(prefix="/escalations", tags=["escalations"])


class EscalationOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    reason: str
    status: str
    grace_deadline: datetime


class RespondBody(BaseModel):
    answer: Literal["ok", "need_help"]


def _require_senior(user: User) -> None:
    if user.role != "senior":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only senior citizens can answer this",
        )


@router.get("/active", response_model=EscalationOut | None)
def active(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The "Are you okay?" waiting for an answer, or null."""
    _require_senior(current_user)
    return get_active(db, current_user.id)


@router.post("/{escalation_id}/respond", response_model=EscalationOut)
def respond(
    escalation_id: int,
    body: RespondBody,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_senior(current_user)
    esc = db.get(Escalation, escalation_id)
    if esc is None or esc.senior_id != current_user.id:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Not found")

    # Already answered or escalated by the timer: just report where it stands.
    if esc.status == "awaiting_senior":
        now = utcnow()
        if body.answer == "ok":
            resolve_ok(db, esc, now)
        else:
            escalate(db, esc, now, by_senior=True)
        db.commit()
        db.refresh(esc)
    return esc