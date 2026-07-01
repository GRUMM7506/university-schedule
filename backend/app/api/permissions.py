"""Permissions management routes."""
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import Session

from app.api.deps import get_current_user
from app.db.session import get_db
from app.models import User, UserPermission
from app.models.permissions import ALL_PERMISSIONS, DEFAULT_ROLE_PERMISSIONS, PERMISSION_LABELS

router = APIRouter(prefix="/permissions", tags=["permissions"])


@router.get("/me")
def get_my_permissions(user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    """Flat list of permissions effectively granted to the current user
    (role defaults with individual overrides applied). Admin always gets
    everything. Used by the Flutter app to drive menu/UI visibility."""
    if user.role == "Admin":
        return {"permissions": list(ALL_PERMISSIONS)}

    role_defaults = DEFAULT_ROLE_PERMISSIONS.get(user.role, set())
    overrides = {
        p.permission: p.is_granted
        for p in db.scalars(select(UserPermission).where(UserPermission.user_id == user.id)).all()
    }
    effective = {
        perm for perm in ALL_PERMISSIONS
        if overrides.get(perm, perm in role_defaults)
    }
    return {"permissions": sorted(effective)}


@router.get("/user/{user_id}")
def get_user_permissions(
    user_id: int,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.role != "Admin" and user.id != user_id:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    target = db.scalar(select(User).where(User.id == user_id))
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")

    overrides = {
        p.permission: p.is_granted
        for p in db.scalars(select(UserPermission).where(UserPermission.user_id == user_id)).all()
    }
    role_defaults = DEFAULT_ROLE_PERMISSIONS.get(target.role, set())

    permissions = [
        {
            "permission": perm,
            "label": PERMISSION_LABELS.get(perm, perm),
            "default_granted": perm in role_defaults,
            "override": overrides.get(perm),
        }
        for perm in ALL_PERMISSIONS
    ]
    return {"permissions": permissions}


@router.put("/{user_id}")
def update_user_permission(
    user_id: int,
    payload: dict,
    user: User = Depends(get_current_user),
    db: Session = Depends(get_db),
):
    if user.role != "Admin":
        raise HTTPException(status_code=403, detail="Only administrators can manage permissions")

    permission = payload.get("permission")
    is_granted = payload.get("is_granted")

    if not permission:
        raise HTTPException(status_code=400, detail="permission is required")
    if permission not in ALL_PERMISSIONS:
        raise HTTPException(status_code=400, detail="Unknown permission")

    target = db.scalar(select(User).where(User.id == user_id))
    if target is None:
        raise HTTPException(status_code=404, detail="User not found")

    perm = db.scalar(select(UserPermission).where(
        UserPermission.user_id == user_id,
        UserPermission.permission == permission,
    ))

    if is_granted is None:
        if perm:
            db.delete(perm)
    elif perm:
        perm.is_granted = is_granted
    else:
        perm = UserPermission(user_id=user_id, permission=permission, is_granted=is_granted)
        db.add(perm)

    db.commit()
    return {"ok": True}
