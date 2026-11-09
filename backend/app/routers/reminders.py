from fastapi import APIRouter, Depends, HTTPException, Response, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.access import can_access_senior, linked_senior_ids
from app.db import get_db
from app.deps import get_current_user
from app.models import Reminder, User
from app.reminder_schemas import ReminderBody, ReminderCreate, ReminderOut

router = APIRouter(prefix="/reminders", tags=["reminders"])


def _reminder_or_404(db: Session, user: User, reminder_id: int) -> Reminder:
    reminder = db.get(Reminder, reminder_id)
    if reminder is None or not can_access_senior(db, user, reminder.senior_id):
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="Reminder not found"
        )
    return reminder


def _apply(reminder: Reminder, body: ReminderBody) -> None:
    reminder.kind = body.kind
    reminder.title = body.title
    reminder.dosage = body.dosage
    reminder.reminder_times = body.reminder_times
    reminder.days_of_week = body.days_of_week
    reminder.one_off_at = body.one_off_at
    reminder.is_active = body.is_active


@router.post("", response_model=ReminderOut, status_code=status.HTTP_201_CREATED)
def create_reminder(
    body: ReminderCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role == "senior":
        if body.senior_id not in (None, current_user.id):
            raise HTTPException(
                status_code=status.HTTP_403_FORBIDDEN,
                detail="A senior can only add reminders for themselves",
            )
        senior_id = current_user.id
    else:
        if body.senior_id is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Say which senior this reminder is for (senior_id)",
            )
        if not can_access_senior(db, current_user, body.senior_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Senior not found"
            )
        senior_id = body.senior_id

    reminder = Reminder(senior_id=senior_id)
    _apply(reminder, body)
    db.add(reminder)
    db.commit()
    db.refresh(reminder)
    return reminder


@router.get("", response_model=list[ReminderOut])
def list_reminders(
    senior_id: int | None = None,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """A senior sees their own. A nominee sees every linked senior's, or one senior's."""
    if current_user.role == "senior":
        if senior_id not in (None, current_user.id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Senior not found"
            )
        condition = Reminder.senior_id == current_user.id
    elif senior_id is not None:
        if not can_access_senior(db, current_user, senior_id):
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail="Senior not found"
            )
        condition = Reminder.senior_id == senior_id
    else:
        condition = Reminder.senior_id.in_(linked_senior_ids(current_user.id))

    return db.scalars(
        select(Reminder).where(condition).order_by(Reminder.created_at, Reminder.id)
    ).all()


@router.put("/{reminder_id}", response_model=ReminderOut)
def update_reminder(
    reminder_id: int,
    body: ReminderBody,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reminder = _reminder_or_404(db, current_user, reminder_id)
    _apply(reminder, body)
    db.commit()
    db.refresh(reminder)
    return reminder


@router.delete("/{reminder_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_reminder(
    reminder_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    reminder = _reminder_or_404(db, current_user, reminder_id)
    db.delete(reminder)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)