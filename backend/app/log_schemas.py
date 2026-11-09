from datetime import datetime
from typing import Literal

from pydantic import AwareDatetime, BaseModel


class LogRequest(BaseModel):
    scheduled_for: AwareDatetime
    status: Literal["taken", "skipped"]


class TodaySlotOut(BaseModel):
    reminder_id: int
    kind: str
    title: str
    dosage: str | None
    scheduled_for: datetime
    status: str
    responded_at: datetime | None