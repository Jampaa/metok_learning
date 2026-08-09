from functools import lru_cache

from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(env_file=".env", extra="ignore")

    gemini_api_key: str = ""
    monlam_api_key: str = ""
    # https://api-v1.monlamai.studio/docs — all auth via X-API-Key header.
    monlam_api_url: str = "https://api-v1.monlamai.studio/api/v1/text-to-speech/stream"
    monlam_voice_name: str = "lhasa_female"
    monlam_dictionary_url: str = "https://api-v1.monlamai.studio/api/v1/dictionary/search"
    monlam_chat_url: str = "https://api-v1.monlamai.studio/api/v1/ai/chat"
    monlam_chat_model: str = "melong"

    firebase_project_id: str = ""
    firebase_client_email: str = ""
    firebase_private_key: str = ""
    firebase_storage_bucket: str = ""

    cors_origins: str = "http://localhost:5173"

    # Below this, recognition is rejected as "not sure" rather than guessed.
    recognition_confidence_threshold: float = 0.70

    @property
    def cors_origin_list(self) -> list[str]:
        return [origin.strip() for origin in self.cors_origins.split(",") if origin.strip()]

    @property
    def gemini_configured(self) -> bool:
        return bool(self.gemini_api_key)

    @property
    def monlam_configured(self) -> bool:
        return bool(self.monlam_api_key and self.monlam_api_url)

    @property
    def firebase_configured(self) -> bool:
        return bool(self.firebase_project_id and self.firebase_client_email and self.firebase_private_key)


@lru_cache
def get_settings() -> Settings:
    return Settings()
