import re
from datetime import datetime
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field, field_validator


class RegisterRequest(BaseModel):
    name: str = Field(min_length=1, max_length=100)
    phone: str
    pin: str = Field(pattern=r"^\d{4,6}$")
    role: Literal["senior", "nominee"]

    @field_validator("name")
    @classmethod
    def clean_name(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("name cannot be empty")
        return v

    @field_validator("phone")
    @classmethod
    def normalise_phone(cls, v: str) -> str:
        digits = re.sub(r"\D", "", v)  # keep digits only
        if len(digits) == 12 and digits.startswith("91"):
            digits = digits[2:]
        if len(digits) == 10 and digits[0] in "6789":
            return "+91" + digits
        raise ValueError("enter a valid 10-digit Indian mobile number")


class UserOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    phone: str
    role: str
    consent_accepted_at: datetime | None
    created_at: datetime


class AuthResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user: UserOut