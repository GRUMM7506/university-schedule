from typing import Any, Generic, TypeVar

from fastapi import HTTPException, status
from pydantic import BaseModel
from sqlalchemy import select
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

ModelT = TypeVar("ModelT")
CreateT = TypeVar("CreateT", bound=BaseModel)
UpdateT = TypeVar("UpdateT", bound=BaseModel)


class CRUDService(Generic[ModelT, CreateT, UpdateT]):
    def __init__(self, model: type[ModelT]):
        self.model = model

    def list(self, db: Session, skip: int = 0, limit: int = 100, search: str | None = None, sort: str | None = None) -> list[ModelT]:
        stmt = select(self.model)
        if search and hasattr(self.model, "name"):
            stmt = stmt.where(getattr(self.model, "name").ilike(f"%{search}%"))
        elif search and hasattr(self.model, "fio"):
            stmt = stmt.where(getattr(self.model, "fio").ilike(f"%{search}%"))
        if sort and hasattr(self.model, sort.lstrip("-")):
            column = getattr(self.model, sort.lstrip("-"))
            stmt = stmt.order_by(column.desc() if sort.startswith("-") else column.asc())
        else:
            stmt = stmt.order_by(getattr(self.model, "id").asc())
        return list(db.scalars(stmt.offset(skip).limit(limit)).all())

    def get(self, db: Session, item_id: int) -> ModelT:
        item = db.get(self.model, item_id)
        if item is None:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Object not found")
        return item

    def create(self, db: Session, obj_in: CreateT) -> ModelT:
        item = self.model(**obj_in.model_dump())
        db.add(item)
        return self._commit(db, item)

    def update(self, db: Session, item_id: int, obj_in: UpdateT) -> ModelT:
        item = self.get(db, item_id)
        for field, value in obj_in.model_dump(exclude_unset=True).items():
            setattr(item, field, value)
        return self._commit(db, item)

    def delete(self, db: Session, item_id: int) -> dict[str, bool]:
        item = self.get(db, item_id)
        db.delete(item)
        self._commit(db)
        return {"ok": True}

    @staticmethod
    def _commit(db: Session, item: Any | None = None):
        try:
            db.commit()
        except IntegrityError as exc:
            db.rollback()
            raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Constraint violation") from exc
        if item is not None:
            db.refresh(item)
        return item
