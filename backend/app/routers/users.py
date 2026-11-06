from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import UserOut

router = APIRouter(tags=["users"])


@router.get("/me", response_model=UserOut)
def read_me(current_user: User = Depends(get_current_user)):
    return current_user


@router.post("/me/consent", response_model=UserOut)
def accept_consent(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """A senior agrees that health mentions may be shared with their nominees."""
    if current_user.role != "senior":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only senior citizens give consent",
        )
    # Record the first agreement only; repeating the call changes nothing.
    if current_user.consent_accepted_at is None:
        current_user.consent_accepted_at = datetime.now(timezone.utc)
        db.commit()
        db.refresh(current_user)
    return current_user