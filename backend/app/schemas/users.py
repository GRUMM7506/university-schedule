"""User-related Pydantic schemas (moved from api/routes.py)."""
from datetime import date

from pydantic import BaseModel, ConfigDict, Field


class UserRead(BaseModel):
    id: int
    username: str
    role: str

    model_config = ConfigDict(from_attributes=True)


class UserCreate(BaseModel):
    username: str = Field(min_length=3, max_length=80)
    password: str = Field(min_length=6)
    role: str


class UserUpdate(BaseModel):
    password: str | None = Field(default=None, min_length=6)
    role: str | None = None


class ProfileSetupPayload(BaseModel):
    fio: str = Field(min_length=2, max_length=180)
    group_id: int | None = None
    birth_date: date | None = None
    position: str | None = None


class ProfileUpdatePayload(BaseModel):
    fio: str | None = Field(default=None, min_length=2, max_length=180)
    position: str | None = None
    group_id: int | None = None
    birth_date: date | None = None
    phone: str | None = None
    address: str | None = None
