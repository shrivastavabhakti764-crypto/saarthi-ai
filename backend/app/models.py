from datetime import datetime, time

from sqlalchemy import (
    BigInteger,
    Boolean,
    CheckConstraint,
    DateTime,
    ForeignKey,
    Identity,
    Index,
    SmallInteger,
    Text,
    Time,
    UniqueConstraint,
    func,
    text,
)
from sqlalchemy.dialects.postgresql import ARRAY
from sqlalchemy.orm import Mapped, mapped_column

from app.db import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint("role IN ('senior', 'nominee')", name="ck_users_role"),
        CheckConstraint(
            "preferred_language IN ('hindi', 'hinglish', 'english')",
            name="ck_users_preferred_language",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    name: Mapped[str] = mapped_column(Text)
    phone: Mapped[str] = mapped_column(Text, unique=True)
    pin_hash: Mapped[str] = mapped_column(Text)
    role: Mapped[str] = mapped_column(Text)
    preferred_language: Mapped[str] = mapped_column(Text, server_default="hinglish")
    fcm_token: Mapped[str | None] = mapped_column(Text)
    consent_accepted_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class LinkCode(Base):
    __tablename__ = "link_codes"

    code: Mapped[str] = mapped_column(Text, primary_key=True)
    senior_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    expires_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    used_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class NomineeLink(Base):
    __tablename__ = "nominee_links"
    __table_args__ = (
        UniqueConstraint("senior_id", "nominee_id", name="uq_nominee_links_pair"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    senior_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    nominee_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    relationship: Mapped[str] = mapped_column(Text)
    whatsapp_number: Mapped[str | None] = mapped_column(Text)
    whatsapp_opt_in: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Reminder(Base):
    __tablename__ = "reminders"
    __table_args__ = (
        CheckConstraint("kind IN ('medicine', 'appointment')", name="ck_reminders_kind"),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    senior_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    kind: Mapped[str] = mapped_column(Text, server_default="medicine")
    title: Mapped[str] = mapped_column(Text)
    dosage: Mapped[str | None] = mapped_column(Text)
    reminder_times: Mapped[list[time]] = mapped_column(
        ARRAY(Time), server_default=text("'{}'")
    )
    days_of_week: Mapped[list[int]] = mapped_column(
        ARRAY(SmallInteger), server_default=text("'{1,2,3,4,5,6,7}'")
    )
    one_off_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    is_active: Mapped[bool] = mapped_column(Boolean, server_default=text("true"))
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class ReminderLog(Base):
    __tablename__ = "reminder_logs"
    __table_args__ = (
        UniqueConstraint("reminder_id", "scheduled_for", name="uq_reminder_logs_slot"),
        CheckConstraint(
            "status IN ('pending', 'taken', 'skipped', 'missed')",
            name="ck_reminder_logs_status",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    reminder_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("reminders.id", ondelete="CASCADE")
    )
    scheduled_for: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    status: Mapped[str] = mapped_column(Text, server_default="pending")
    responded_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


class ChatMessage(Base):
    __tablename__ = "chat_messages"
    __table_args__ = (
        CheckConstraint("sender IN ('senior', 'ai')", name="ck_chat_messages_sender"),
        CheckConstraint(
            "emotion IN ('neutral', 'happy', 'concerned')",
            name="ck_chat_messages_emotion",
        ),
        CheckConstraint(
            "input_mode IN ('voice', 'text')", name="ck_chat_messages_input_mode"
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    senior_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    sender: Mapped[str] = mapped_column(Text)
    message_text: Mapped[str] = mapped_column(Text)
    language: Mapped[str | None] = mapped_column(Text)
    emotion: Mapped[str | None] = mapped_column(Text)
    input_mode: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class SymptomLog(Base):
    __tablename__ = "symptom_logs"
    __table_args__ = (
        CheckConstraint(
            "flag IN ('noted', 'repeated', 'help_requested')",
            name="ck_symptom_logs_flag",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    senior_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    chat_message_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("chat_messages.id", ondelete="SET NULL")
    )
    symptom_text: Mapped[str] = mapped_column(Text)
    symptom_key: Mapped[str] = mapped_column(Text)
    asked_for_help: Mapped[bool] = mapped_column(Boolean, server_default=text("false"))
    flag: Mapped[str] = mapped_column(Text, server_default="noted")
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )


class Escalation(Base):
    __tablename__ = "escalations"
    __table_args__ = (
        CheckConstraint(
            "reason IN ('repeated_symptom', 'symptom_and_missed_dose', 'help_requested')",
            name="ck_escalations_reason",
        ),
        CheckConstraint(
            "status IN ('awaiting_senior', 'resolved_ok', 'escalated')",
            name="ck_escalations_status",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    senior_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    symptom_log_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("symptom_logs.id", ondelete="SET NULL")
    )
    reason: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default="awaiting_senior")
    prompted_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    grace_deadline: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    resolved_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    summary_text: Mapped[str | None] = mapped_column(Text)


class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (
        CheckConstraint("channel IN ('push', 'whatsapp')", name="ck_notifications_channel"),
        CheckConstraint(
            "status IN ('queued', 'sent', 'delivered', 'failed')",
            name="ck_notifications_status",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, Identity(always=True), primary_key=True)
    escalation_id: Mapped[int | None] = mapped_column(
        BigInteger, ForeignKey("escalations.id", ondelete="SET NULL")
    )
    nominee_id: Mapped[int] = mapped_column(
        BigInteger, ForeignKey("users.id", ondelete="CASCADE")
    )
    channel: Mapped[str] = mapped_column(Text)
    summary_text: Mapped[str] = mapped_column(Text)
    status: Mapped[str] = mapped_column(Text, server_default="queued")
    provider_message_id: Mapped[str | None] = mapped_column(Text)
    error: Mapped[str | None] = mapped_column(Text)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), server_default=func.now()
    )
    sent_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))


# Indexes (defined after the classes so they can use DESC ordering and partial filters)
Index("idx_chat_senior_time", ChatMessage.senior_id, ChatMessage.created_at.desc())
Index(
    "idx_symptom_senior_key_time",
    SymptomLog.senior_id,
    SymptomLog.symptom_key,
    SymptomLog.created_at.desc(),
)
Index(
    "idx_escalations_due",
    Escalation.grace_deadline,
    postgresql_where=text("status = 'awaiting_senior'"),
)
Index(
    "idx_notifications_nominee_time",
    Notification.nominee_id,
    Notification.created_at.desc(),
)