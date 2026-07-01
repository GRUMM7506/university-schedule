"""User management routes (Admin only)."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import require_permission
from app.core.security import get_password_hash
from app.db.session import get_db
from app.models import User
from app.schemas.users import UserCreate, UserRead, UserUpdate

router = APIRouter(prefix="/users", tags=["users"])

_manage_dep = Depends(require_permission("users.manage"))


@router.get("", response_model=list[UserRead], dependencies=[_manage_dep])
def list_users(db: Session = Depends(get_db)):
    return db.scalars(select(User).order_by(User.id)).all()


@router.post("", response_model=UserRead, dependencies=[_manage_dep])
def create_user(payload: UserCreate, db: Session = Depends(get_db)):
    existing = db.scalar(select(User).where(User.username == payload.username))
    if existing:
        raise HTTPException(status_code=400, detail="Username already exists")
    user = User(
        username=payload.username,
        hashed_password=get_password_hash(payload.password),
        role=payload.role,
    )
    db.add(user)
    db.commit()
    db.refresh(user)
    return user


@router.put("/{user_id}", response_model=UserRead, dependencies=[_manage_dep])
def update_user(user_id: int, payload: UserUpdate, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if payload.password:
        user.hashed_password = get_password_hash(payload.password)
    if payload.role:
        user.role = payload.role
    db.commit()
    db.refresh(user)
    return user


@router.delete("/{user_id}", dependencies=[_manage_dep])
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.scalar(select(User).where(User.id == user_id))
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    db.delete(user)
    db.commit()
    return {"ok": True}
