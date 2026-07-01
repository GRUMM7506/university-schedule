from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import api_router
from app.api.auth import router as auth_router
from app.api.users import router as users_router
from app.api.profile import router as profile_router
from app.api.permissions import router as permissions_router
from app.core.config import settings

app = FastAPI(title="University Process Management API", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.backend_cors_origins,
    allow_origin_regex=settings.backend_cors_origin_regex,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Domain-specific routers (extracted from the monolithic routes.py)
app.include_router(auth_router, prefix="/api")
app.include_router(users_router, prefix="/api")
app.include_router(profile_router, prefix="/api")
app.include_router(permissions_router, prefix="/api")

# Core CRUD + schedule/gradebook/dashboard router
app.include_router(api_router)


@app.get("/health")
def health():
    return {"status": "ok"}
