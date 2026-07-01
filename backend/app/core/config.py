import os

from pydantic_settings import BaseSettings, SettingsConfigDict

_DEFAULT_SECRET = "change-me-in-production"


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://postgres:7894@localhost:7894/SCHEDULE DATABASE"
    secret_key: str = _DEFAULT_SECRET
    algorithm: str = "HS256"
    debug: bool = False
    # Access tokens are short-lived; refresh tokens handle session persistence.
    access_token_expire_minutes: int = 30
    refresh_token_expire_days: int = 30
    backend_cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]
    backend_cors_origin_regex: str | None = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False)


settings = Settings()

# Guard against running with the default secret in production.
_is_debug = os.getenv("DEBUG", "false").lower() in {"1", "true", "yes"}
if settings.secret_key == _DEFAULT_SECRET and not _is_debug:
    raise RuntimeError(
        "SECRET_KEY is set to the default value. "
        "Set a strong SECRET_KEY in your .env file before running in production."
    )