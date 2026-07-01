"""Profile setup and update routes."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user, require_any
from app.api.auth import _student_for_user
from app.db.session import get_db
from app.models import Student, Teacher, User
from app.schemas.users import ProfileSetupPayload, ProfileUpdatePayload

router = APIRouter(prefix="/profile", tags=["profile"])


@router.post("/setup", dependencies=[Depends(require_any)])
def setup_profile(
    payload: ProfileSetupPayload,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.role == "Admin":
        raise HTTPException(status_code=400, detail="Администратору профиль не требуется")

    if user.role == "Student":
        if payload.group_id is None or payload.birth_date is None:
            raise HTTPException(status_code=400, detail="Укажите группу и дату рождения")
        email = f"{user.username}@msu.ru"
        existing = db.scalar(select(Student).where(Student.email == email))
        if existing:
            return {"linked_id": existing.id}
        # ── T3 FIX: pass user_id when creating Student ─────────────────────────
        entity = Student(
            fio=payload.fio,
            group_id=payload.group_id,
            email=email,
            birth_date=payload.birth_date,
            user_id=user.id,
        )
    elif user.role == "Teacher":
        if not payload.position:
            raise HTTPException(status_code=400, detail="Укажите должность")
        email = f"{user.username}@uni.uz"
        existing = db.scalar(select(Teacher).where(Teacher.email == email))
        if existing:
            return {"linked_id": existing.id}
        # ── T3 FIX: pass user_id when creating Teacher ─────────────────────────
        entity = Teacher(
            fio=payload.fio,
            position=payload.position,
            email=email,
            user_id=user.id,
        )
    else:
        raise HTTPException(status_code=400, detail="Неизвестная роль пользователя")

    db.add(entity)
    db.commit()
    db.refresh(entity)
    return {"linked_id": entity.id}


@router.put("/update", dependencies=[Depends(require_any)])
def update_profile(
    payload: ProfileUpdatePayload,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    """Update the current user's linked student or teacher profile."""
    if user.role == "Admin":
        raise HTTPException(status_code=400, detail="Администратору профиль не требуется")

    if user.role == "Student":
        entity = _student_for_user(db, user)
        if not entity:
            raise HTTPException(status_code=404, detail="Профиль студента не найден")
        if payload.fio is not None:
            entity.fio = payload.fio
        if payload.group_id is not None:
            entity.group_id = payload.group_id
        if payload.birth_date is not None:
            entity.birth_date = payload.birth_date
        if payload.phone is not None:
            entity.phone = payload.phone
        if payload.address is not None:
            entity.address = payload.address

    elif user.role == "Teacher":
        # ── T9 FIX: search by user_id instead of derived email ─────────────────
        entity = db.scalar(select(Teacher).where(Teacher.user_id == user.id))
        if not entity:
            raise HTTPException(status_code=404, detail="Профиль преподавателя не найден")
        if payload.fio is not None:
            entity.fio = payload.fio
        if payload.position is not None:
            entity.position = payload.position
        if payload.phone is not None:
            entity.phone = payload.phone
        if payload.address is not None:
            entity.address = payload.address
    else:
        raise HTTPException(status_code=400, detail="Неизвестная роль")

    db.commit()
    return {"ok": True}
