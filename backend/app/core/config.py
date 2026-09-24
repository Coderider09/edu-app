from typing import List

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    DATABASE_URL: str = "postgresql://eduapp:eduapp_password@localhost:5432/eduapp"
    REDIS_URL: str = "redis://localhost:6379/0"
    SECRET_KEY: str = "change-me-in-production"
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    REFRESH_TOKEN_EXPIRE_DAYS: int = 30
    ENVIRONMENT: str = "development"
    CORS_ORIGINS: List[str] = ["*"]

    # Google OAuth: client IDs (Android/iOS/Web) accepted as the token audience
    GOOGLE_CLIENT_IDS: List[str] = []

    # Brute-force protection for /auth/login
    LOGIN_RATE_LIMIT: int = 10
    LOGIN_RATE_WINDOW_SECONDS: int = 300

    # Local timezone used for daily streaks (Tajikistan, UTC+5)
    TIMEZONE: str = "Asia/Dushanbe"

    LEADERBOARD_CACHE_SECONDS: int = 60

    # First superadmin, created by `python -m app.seed` when both are set
    FIRST_SUPERADMIN_EMAIL: str = ""
    FIRST_SUPERADMIN_PASSWORD: str = ""


settings = Settings()

if settings.ENVIRONMENT == "production" and (
    settings.SECRET_KEY == "change-me-in-production" or len(settings.SECRET_KEY) < 32
):
    raise RuntimeError("Set a random SECRET_KEY of at least 32 characters in production")
