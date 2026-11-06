import re
from datetime import datetime
from typing import Literal

from pydantic import (
    BaseModel,
    ConfigDict,
    Field,
    field_validator,
    model_validator,
)


def normalise_indian_phone(v: str) -> str:
    digits = re.sub(r"\D", "", v)  # keep digits only
    if len(digits) == 12 and digits.startswith("91"):
        digits = digits[2:]
    if len(digits) == 10 and digits[0] in "6789":
        return "+91" + digits
    raise ValueError("enter a valid 10-digit Indian mobile number")


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
        return normalise_indian_phone(v)


class LoginRequest(BaseModel):
    phone: str
    pin: str = Field(pattern=r"^\d{4,6}$")

    @field_validator("phone")
    @classmethod
    def normalise_phone(cls, v: str) -> str:
        return normalise_indian_phone(v)


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


class LinkCodeOut(BaseModel):
    code: str
    expires_at: datetime


class RedeemRequest(BaseModel):
    code: str = Field(pattern=r"^\d{6}$")
    relationship: str = Field(min_length=1, max_length=50)
    whatsapp_number: str | None = None
    whatsapp_opt_in: bool = False

    @field_validator("relationship")
    @classmethod
    def clean_relationship(cls, v: str) -> str:
        v = v.strip()
        if not v:
            raise ValueError("relationship cannot be empty")
        return v

    @field_validator("whatsapp_number")
    @classmethod
    def normalise_whatsapp(cls, v: str | None) -> str | None:
        if v is None or not v.strip():
            return None
        return normalise_indian_phone(v)

    @model_validator(mode="after")
    def opt_in_needs_a_number(self):
        if self.whatsapp_opt_in and self.whatsapp_number is None:
            raise ValueError("a WhatsApp number is needed to opt in")
        return self


class LinkOut(BaseModel):
    id: int
    senior_id: int
    senior_name: str
    nominee_id: int
    nominee_name: str
    relationship: str
    whatsapp_number: str | None
    whatsapp_opt_in: bool
    created_at: datetime