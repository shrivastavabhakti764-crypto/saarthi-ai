from datetime import datetime, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.db import get_db
from app.deps import get_current_user
from app.models import User
from app.schemas import FcmTokenIn, UserOut

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


@router.put("/me/fcm-token", status_code=status.HTTP_204_NO_CONTENT)
def save_fcm_token(
    body: FcmTokenIn,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
) -> None:
    """Remember this phone's push token for the logged-in user."""
    # A phone belongs to one account at a time: take the token away from
    # anyone else who had it (for example the previous user of this phone).
    db.query(User).filter(
        User.fcm_token == body.token, User.id != current_user.id
    ).update({User.fcm_token: None})
    current_user.fcm_token = body.token
    db.commit()