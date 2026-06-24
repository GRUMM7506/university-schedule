from fastapi import APIRouter, Depends, Query, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
from sqlalchemy.exc import IntegrityError

from app.api.deps import require_admin, require_staff
from app.db.session import get_db
from app.services.crud import CRUDService


def _integrity_error_detail(exc: IntegrityError) -> str:
    message = str(getattr(exc, "orig", exc))
    if "uq_schedule_group_slot" in message:
        return "У этой группы уже есть занятие в выбранный день и пару."
    if "uq_schedule_teacher_slot" in message:
        return "Преподаватель уже занят в выбранный день и пару."
    if "uq_schedule_classroom_slot" in message:
        return "Аудитория уже занята в выбранный день и пару."
    if "schedule.study_week_id" in message and "schedule.group_id" in message:
        return "У этой группы уже есть занятие в выбранный день и пару."
    if "schedule.study_week_id" in message and "schedule.teacher_id" in message:
        return "Преподаватель уже занят в выбранный день и пару."
    if "schedule.study_week_id" in message and "schedule.classroom_id" in message:
        return "Аудитория уже занята в выбранный день и пару."
    if "schedule" in message:
        return "Данное время уже занято в расписании."
    return "Конфликт данных. Запись уже существует или нарушено ограничение."


def build_crud_router(
    *,
    model,
    create_schema: type[BaseModel],
    update_schema: type[BaseModel],
    read_schema: type[BaseModel],
    staff_read: bool = False,
    any_read: bool = False,
) -> APIRouter:
    router = APIRouter()
    service = CRUDService(model)
    
    if any_read:
        from app.api.deps import require_any
        read_dep = require_any
    elif staff_read:
        read_dep = require_staff
    else:
        read_dep = require_admin

    @router.get("/list", response_model=list[read_schema], dependencies=[Depends(read_dep)])
    def list_items(
        skip: int = 0,
        limit: int = Query(default=100, le=500),
        search: str | None = None,
        sort: str | None = None,
        db: Session = Depends(get_db),
    ):
        return service.list(db, skip=skip, limit=limit, search=search, sort=sort)

    @router.get("/{item_id}", response_model=read_schema, dependencies=[Depends(read_dep)])
    def get_item(item_id: int, db: Session = Depends(get_db)):
        return service.get(db, item_id)

    @router.post("", response_model=read_schema, dependencies=[Depends(require_admin)])
    def create_item(payload: create_schema, db: Session = Depends(get_db)):  # type: ignore[valid-type]
        try:
            return service.create(db, payload)
        except IntegrityError as exc:
            db.rollback()
            raise HTTPException(status_code=400, detail=_integrity_error_detail(exc))

    @router.put("/{item_id}", response_model=read_schema, dependencies=[Depends(require_admin)])
    def update_item(item_id: int, payload: update_schema, db: Session = Depends(get_db)):  # type: ignore[valid-type]
        try:
            return service.update(db, item_id, payload)
        except IntegrityError as exc:
            db.rollback()
            raise HTTPException(status_code=400, detail=_integrity_error_detail(exc))

    @router.delete("/{item_id}", dependencies=[Depends(require_admin)])
    def delete_item(item_id: int, db: Session = Depends(get_db)):
        return service.delete(db, item_id)

    return router
