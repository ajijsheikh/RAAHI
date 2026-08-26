from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    DATABASE_URL: str = "postgresql+asyncpg://raahi:rahi@localhost:5432/raahi"
    GROQ_API_KEY: str = ""
    GROQ_MODEL: str = "llama-3.3-70b-versatile"
    GEMINI_API_KEY: str = ""
    GEMINI_MODEL: str = "gemini-2.0-flash"
    LLM_TIMEOUT_S: int = 8
    AUTH_MODE: str = "header"
    SUPABASE_URL: str = ""
    SUPABASE_ANON_KEY: str = ""
    SUPABASE_JWT_SECRET: str = ""
    TWILIO_ACCOUNT_SID: str = ""
    TWILIO_AUTH_TOKEN: str = ""
    TWILIO_FROM_NUMBER: str = ""
    TWILIO_TO_NUMBER_OVERRIDE: str = ""
    ALERTS_ENABLED: bool = True
    DELAY_THRESHOLD_MIN: int = 15
    MONITOR_POLL_INTERVAL_S: int = 5
    GEOFENCE_BUFFER_M: int = 50
    SAFETY_SCORE_FLOOR: float = 0.35
    IRCTC_ENABLED: bool = False
    IRCTC_API_KEY: str = ""
    IRCTC_API_HOST: str = ""

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()