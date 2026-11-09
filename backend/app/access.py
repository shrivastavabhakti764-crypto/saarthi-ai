from sqlalchemy import select
from sqlalchemy.orm import Session

from app.models import NomineeLink, User


def linked_senior_ids(nominee_id: int):
    """A subquery with the ids of every senior this nominee is linked to."""
    return select(NomineeLink.senior_id).where(NomineeLink.nominee_id == nominee_id)


def can_access_senior(db: Session, user: User, senior_id: int) -> bool:
    """A senior reaches only their own data; a nominee only linked seniors' data."""
    if user.role == "senior":
        return user.id == senior_id
    link_id = db.scalar(
        select(NomineeLink.id).where(
            NomineeLink.senior_id == senior_id,
            NomineeLink.nominee_id == user.id,
        )
    )
    return link_id is not None