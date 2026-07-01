"""Authentication routes: login, refresh, guest, logout, change-password."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_any
from app.core.security import (
    create_access_token,
    create_refresh_token,
    get_password_hash,
    verify_password,
)
from app.db.session import get_db
from app.models import Student, Teacher, User
from app.schemas import Token
from app.schemas.entities import LoginRequest

router = APIRouter(prefix="/auth", tags=["auth"])


def _student_for_user(db: Session, user: User) -> Student | None:
    """Find the Student record linked to a User, by user_id first, then email fallback."""
    student = db.scalar(select(Student).where(Student.user_id == user.id))
    if student:
        return student
    email_candidates = [f"{user.username}@msu.ru", f"{user.username}@student.uz"]
    if "@" in user.username:
        email_candidates.append(user.username)
    return db.scalar(select(Student).where(Student.email.in_(email_candidates)))


def _build_token_response(db: Session, user: User) -> Token:
    """Build a Token response, attaching student_id when the user is a Student."""
    student_id = None
    if user.role == "Student":
        student = _student_for_user(db, user)
        if student:
            student_id = student.id

    refresh = create_refresh_token(user.username)
    user.refresh_token = refresh
    db.commit()

    return Token(
        access_token=create_access_token(user.username, user.role),
        refresh_token=refresh,
        role=user.role,
        username=user.username,
        student_id=student_id,
    )


@router.post("/login", response_model=Token)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.username == payload.username))
    if user is None or not verify_password(payload.password, user.hashed_password):
        raise HTTPException(status_code=401, detail="Invalid username or password")
    return _build_token_response(db, user)


@router.post("/refresh", response_model=Token)
def refresh_token_endpoint(payload: dict, db: Session = Depends(get_db)):
    from jose import jwt
    from app.core.config import settings

    incoming = payload.get("refresh_token")
    if not incoming:
        raise HTTPException(status_code=400, detail="Refresh token is missing")

    try:
        data = jwt.decode(incoming, settings.secret_key, algorithms=[settings.algorithm])
        username = data.get("sub")
    except Exception:
        raise HTTPException(status_code=401, detail="Invalid refresh token")

    user = db.scalar(select(User).where(User.username == username))
    if user is None:
        raise HTTPException(status_code=401, detail="User not found")

    # ── T2 FIX: validate the incoming token against the stored one ─────────────
    if user.refresh_token != incoming:
        raise HTTPException(status_code=401, detail="Refresh token has been revoked")

    return _build_token_response(db, user)


@router.post("/guest", response_model=Token)
def guest_login(db: Session = Depends(get_db)):
    guest = db.scalar(select(User).where(User.username == "guest"))
    if guest is None:
        guest = User(
            username="guest",
            hashed_password=get_password_hash("guest"),
            role="Guest",
        )
        db.add(guest)
        db.commit()
        db.refresh(guest)

    refresh = create_refresh_token(guest.username)
    guest.refresh_token = refresh
    db.commit()

    return Token(
        access_token=create_access_token(guest.username, guest.role),
        refresh_token=refresh,
        role=guest.role,
        username=guest.username,
        student_id=None,
    )


@router.post("/change-password", dependencies=[Depends(require_any)])
def change_password(
    payload: dict,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    old_password = payload.get("old_password")
    new_password = payload.get("new_password")
    if not old_password or not new_password:
        raise HTTPException(status_code=400, detail="Both old and new passwords are required")

    # ── T12 FIX: enforce minimum password length ───────────────────────────────
    if len(new_password) < 6:
        raise HTTPException(status_code=400, detail="New password must be at least 6 characters")

    if not verify_password(old_password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Old password is incorrect")

    user.hashed_password = get_password_hash(new_password)
    db.commit()
    return {"ok": True}
