import re

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.chat_schemas import ChatMessageOut, ChatReply, ChatRequest
from app.db import get_db
from app.deps import get_current_user
from app.llm import generate_reply
from app.models import ChatMessage, SymptomLog, User

router = APIRouter(prefix="/chat", tags=["chat"])

HISTORY_FOR_MODEL = 8


def _require_senior_with_consent(user: User) -> None:
    if user.role != "senior":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only senior citizens can chat with Saarthi",
        )
    if user.consent_accepted_at is None:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Please accept the consent first",
        )


def _clean_key(key: str) -> str:
    cleaned = re.sub(r"[^a-z0-9]+", "_", key.lower()).strip("_")
    return cleaned[:50] or "unknown"


@router.post("", response_model=ChatReply)
def chat(
    body: ChatRequest,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    _require_senior_with_consent(current_user)
    senior_id = current_user.id

    recent = db.scalars(
        select(ChatMessage)
        .where(ChatMessage.senior_id == senior_id)
        .order_by(ChatMessage.id.desc())
        .limit(HISTORY_FOR_MODEL)
    ).all()
    history = [(m.sender, m.message_text) for m in reversed(recent)]

    result = generate_reply(history, body.message)

    senior_message = ChatMessage(
        senior_id=senior_id,
        sender="senior",
        message_text=body.message,
        input_mode=body.input_mode,
    )
    ai_message = ChatMessage(
        senior_id=senior_id,
        sender="ai",
        message_text=result.reply,
        language=result.language,
        emotion=result.emotion,
    )
    db.add_all([senior_message, ai_message])
    db.flush()  # gives the messages their ids

    has_symptom = result.symptom_detected and bool(result.symptom_key.strip())
    if has_symptom or result.asked_for_help:
        db.add(
            SymptomLog(
                senior_id=senior_id,
                chat_message_id=senior_message.id,
                symptom_text=result.symptom_text.strip() or body.message,
                symptom_key=_clean_key(result.symptom_key) if has_symptom else "help_request",
                asked_for_help=result.asked_for_help,
                flag="help_requested" if result.asked_for_help else "noted",
            )
        )
    db.commit()

    return ChatReply(
        reply=result.reply,
        language=result.language,
        emotion=result.emotion,
        symptom_detected=has_symptom,
        asked_for_help=result.asked_for_help,
    )


@router.get("/history", response_model=list[ChatMessageOut])
def history(
    limit: int = 50,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """The latest messages, oldest first."""
    _require_senior_with_consent(current_user)
    limit = max(1, min(limit, 200))
    rows = db.scalars(
        select(ChatMessage)
        .where(ChatMessage.senior_id == current_user.id)
        .order_by(ChatMessage.id.desc())
        .limit(limit)
    ).all()
    return list(reversed(rows))