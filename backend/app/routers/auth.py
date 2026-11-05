import math

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from app import rate_limit
from app.db import get_db
from app.models import User
from app.schemas import AuthResponse, LoginRequest, RegisterRequest, UserOut
from app.security import create_access_token, hash_pin, verify_pin

router = APIRouter(prefix="/auth", tags=["auth"])


@router.post("/register", response_model=AuthResponse, status_code=status.HTTP_201_CREATED)
def register(body: RegisterRequest, db: Session = Depends(get_db)):
    user = User(
        name=body.name,
        phone=body.phone,
        pin_hash=hash_pin(body.pin),
        role=body.role,
    )
    db.add(user)
    try:
        db.commit()
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="This phone number is already registered",
        )
    db.refresh(user)
    return AuthResponse(
        access_token=create_access_token(user.id),
        user=UserOut.model_validate(user),
    )


@router.post("/login", response_model=AuthResponse)
def login(body: LoginRequest, db: Session = Depends(get_db)):
    wait = rate_limit.seconds_locked(body.phone)
    if wait > 0:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail=f"Too many wrong attempts. Try again in {math.ceil(wait / 60)} minute(s).",
            headers={"Retry-After": str(wait)},
        )

    user = db.scalar(select(User).where(User.phone == body.phone))
    if user is None or not verify_pin(body.pin, user.pin_hash):
        rate_limit.record_failure(body.phone)
        # Same message for "no such user" and "wrong PIN" so nobody can probe which phones exist
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect phone number or PIN",
        )

    rate_limit.reset(body.phone)
    return AuthResponse(
        access_token=create_access_token(user.id),
        user=UserOut.model_validate(user),
    )