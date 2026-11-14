from datetime import datetime

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import Escalation, NomineeLink, User

router = APIRouter(prefix="/alerts", tags=["alerts"])


class AlertOut(BaseModel):
    id: int
    senior_id: int
    senior_name: str
    reason: str
    summary: str
    created_at: datetime


@router.get("", response_model=list[AlertOut])
def list_alerts(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Updates about the seniors this nominee is linked to, newest first.
    Only the plain-language summary is shared, never the chat itself."""
    if current_user.role != "nominee":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only nominees can see alerts",
        )
    limit = max(1, min(limit, 200))
    rows = db.execute(
        select(Escalation, User.name)
        .join(NomineeLink, NomineeLink.senior_id == Escalation.senior_id)
        .join(User, User.id == Escalation.senior_id)
        .where(
            NomineeLink.nominee_id == current_user.id,
            Escalation.status == "escalated",
        )
        .order_by(Escalation.id.desc())
        .limit(limit)
    ).all()
    return [
        AlertOut(
            id=esc.id,
            senior_id=esc.senior_id,
            senior_name=name,
            reason=esc.reason,
            summary=esc.summary_text or "",
            created_at=esc.prompted_at,
        )
        for esc, name in rows
    ]