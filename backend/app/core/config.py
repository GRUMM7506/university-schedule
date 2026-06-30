from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://postgres:7894@localhost:7894/SCHEDULE DATABASE"
    secret_key: str = "change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440
    refresh_token_expire_days: int = 30
    backend_cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]
    backend_cors_origin_regex: str | None = r"https?://(localhost|127\.0\.0\.1)(:\d+)?"

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False)


settings = Settings()