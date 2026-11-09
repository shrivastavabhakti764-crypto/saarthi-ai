from datetime import datetime, time
from typing import Literal

from pydantic import (
    AwareDatetime,
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)

ALL_DAYS = [1, 2, 3, 4, 5, 6, 7]  # 1 = Monday ... 7 = Sunday


class ReminderBody(BaseModel):
    kind: Literal["medicine", "appointment"] = "medicine"
    title: str = Field(min_length=1, max_length=100)
    dosage: str | None = Field(default=None, max_length=100)
    reminder_times: list[time] = Field(default_factory=list, max_length=10)
    days_of_week: list[int] = Field(default_factory=lambda: list(ALL_DAYS))
    one_off_at: AwareDatetime | None = None
    is_active: bool = True

    @field_validator("title")
    @classmethod
    def clean_title(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("title cannot be empty")
        return v

    @field_validator("dosage")
    @classmethod
    def clean_dosage(cls, v: str | None) -> str | None:
        if v is None:
            return None
        return v.strip() or None

    @field_validator("reminder_times")
    @classmethod
    def clean_times(cls, v: list[time]) -> list[time]:
        if any(t.tzinfo is not None for t in v):
            raise ValueError("times must not include a time zone")
        # whole minutes only, no duplicates, in order
        return sorted({t.replace(second=0, microsecond=0) for t in v})

    @field_validator("days_of_week")
    @classmethod
    def clean_days(cls, v: list[int]) -> list[int]:
        if not v or any(d < 1 or d > 7 for d in v):
            raise ValueError("days_of_week needs numbers from 1 (Monday) to 7 (Sunday)")
        return sorted(set(v))

    @model_validator(mode="after")
    def check_kind(self):
        if self.kind == "medicine":
            if not self.reminder_times:
                raise ValueError("a medicine reminder needs at least one time")
            if self.one_off_at is not None:
                raise ValueError("one_off_at is only for appointments")
        else:
            if self.one_off_at is None:
                raise ValueError("an appointment needs one_off_at")
            if self.reminder_times:
                raise ValueError("an appointment has one date and time, not daily times")
        return self


class ReminderCreate(ReminderBody):
    # Only a family member (nominee) sends this: which senior the reminder is for.
    senior_id: int | None = None


class ReminderOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    senior_id: int
    kind: str
    title: str
    dosage: str | None
    reminder_times: list[time]
    days_of_week: list[int]
    one_off_at: datetime | None
    is_active: bool
    created_at: datetime