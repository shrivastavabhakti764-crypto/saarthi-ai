from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=1000)
    input_mode: Literal["voice", "text"] = "text"

    @field_validator("message")
    @classmethod
    def clean_message(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("message cannot be empty")
        return v


class ChatReply(BaseModel):
    reply: str
    language: str
    emotion: str
    symptom_detected: bool
    asked_for_help: bool


class ChatMessageOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    sender: str
    message_text: str
    language: str | None
    emotion: str | None
    created_at: datetime