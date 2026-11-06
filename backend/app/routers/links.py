import math
import secrets
from datetime import datetime, timedelta, timezone

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import delete, select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import rate_limit
from app.db import get_db
from app.deps import get_current_user
from app.models import LinkCode, NomineeLink, User
from app.schemas import LinkCodeOut, LinkOut, RedeemRequest

router = APIRouter(prefix="/links", tags=["links"])

CODE_LIFETIME = timedelta(minutes=15)


def link_out(db: Session, link: NomineeLink) -> LinkOut:
    senior = db.get(User, link.senior_id)
    nominee = db.get(User, link.nominee_id)
    return LinkOut(
        id=link.id,
        senior_id=link.senior_id,
        senior_name=senior.name,
        nominee_id=link.nominee_id,
        nominee_name=nominee.name,
        relationship=link.relationship,
        whatsapp_number=link.whatsapp_number,
        whatsapp_opt_in=link.whatsapp_opt_in,
        created_at=link.created_at,
    )


@router.post("/code", response_model=LinkCodeOut, status_code=status.HTTP_201_CREATED)
def create_link_code(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """A senior creates a 6-digit code (valid 15 minutes) to give to a family member."""
    if current_user.role != "senior":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only senior citizens can create a link code",
        )
    senior_id = current_user.id
    expires_at = datetime.now(timezone.utc) + CODE_LIFETIME

    for _ in range(10):
        # Only one unused code per senior at a time: a new code replaces the old one.
        db.execute(
            delete(LinkCode).where(
                LinkCode.senior_id == senior_id, LinkCode.used_at.is_(None)
            )
        )
        code = f"{secrets.randbelow(1_000_000):06d}"
        db.add(LinkCode(code=code, senior_id=senior_id, expires_at=expires_at))
        try:
            db.commit()
            return LinkCodeOut(code=code, expires_at=expires_at)
        except IntegrityError:
            db.rollback()  # the code already exists for someone else: try another

    raise HTTPException(
        status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
        detail="Could not create a code. Please try again.",
    )


@router.post("/redeem", response_model=LinkOut, status_code=status.HTTP_201_CREATED)
def redeem_link_code(
    body: RedeemRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """A nominee enters a senior's code to link the two accounts."""
    if current_user.role != "nominee":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only family members (nominees) can use a link code",
        )
    nominee_id = current_user.id
    key = f"redeem:{nominee_id}"

    wait = rate_limit.seconds_locked(key)
    if wait > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many wrong codes. Try again in {math.ceil(wait / 60)} minute(s).",
            headers={"Retry-After": str(wait)},
        )

    now = datetime.now(timezone.utc)
    link_code = db.scalar(
        select(LinkCode).where(LinkCode.code == body.code).with_for_update()
    )
    if link_code is None or link_code.used_at is not None or link_code.expires_at <= now:
        rate_limit.record_failure(key)
        # Same message for wrong, used and expired codes.
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="This code is not valid or has expired",
        )

    link = NomineeLink(
        senior_id=link_code.senior_id,
        nominee_id=nominee_id,
        relationship=body.relationship,
        whatsapp_number=body.whatsapp_number,
        whatsapp_opt_in=body.whatsapp_opt_in,
    )
    link_code.used_at = now
    db.add(link)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()  # also undoes used_at, so the code stays usable
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="You are already linked to this person",
        )

    rate_limit.reset(key)
    db.refresh(link)
    return link_out(db, link)