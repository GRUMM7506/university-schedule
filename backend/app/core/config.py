from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    database_url: str = "postgresql+psycopg://postgres:postgres@localhost:5432/university"
    secret_key: str = "change-me-in-production"
    algorithm: str = "HS256"
    access_token_expire_minutes: int = 1440
    backend_cors_origins: list[str] = ["http://localhost:3000", "http://localhost:8080"]

    model_config = SettingsConfigDict(env_file=".env", case_sensitive=False)


settings = Settings()
