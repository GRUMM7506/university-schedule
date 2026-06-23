from fastapi import APIRouter, Depends, Query
from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.api.deps import require_admin, require_staff
from app.db.session import get_db
from app.services.crud import CRUDService


def build_crud_router(
    *,
    model,
    create_schema: type[BaseModel],
    update_schema: type[BaseModel],
    read_schema: type[BaseModel],
    staff_read: bool = False,
) -> APIRouter:
    router = APIRouter()
    service = CRUDService(model)
    read_dep = require_staff if staff_read else require_admin

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
        return service.create(db, payload)

    @router.put("/{item_id}", response_model=read_schema, dependencies=[Depends(require_admin)])
    def update_item(item_id: int, payload: update_schema, db: Session = Depends(get_db)):  # type: ignore[valid-type]
        return service.update(db, item_id, payload)

    @router.delete("/{item_id}", dependencies=[Depends(require_admin)])
    def delete_item(item_id: int, db: Session = Depends(get_db)):
        return service.delete(db, item_id)

    return router
