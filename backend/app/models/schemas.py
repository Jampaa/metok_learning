from typing import Literal

from pydantic import BaseModel, Field


VocabularyCategory = Literal["stationery", "kitchen", "house", "other"]


class RecognitionResponse(BaseModel):
    object: str
    category: VocabularyCategory
    confidence: float = Field(ge=0.0, le=1.0)


class SentenceDraft(BaseModel):
    english: str
    tibetan: str


class GenerateSentencesRequest(BaseModel):
    english: str
    tibetan: str
    level: Literal["beginner", "intermediate"] = "beginner"


class GenerateSentencesResponse(BaseModel):
    sentences: list[SentenceDraft]


class GenerateTtsRequest(BaseModel):
    text: str


class GenerateTtsResponse(BaseModel):
    audioUrl: str


LearningEventType = Literal[
    "object_identified",
    "word_viewed",
    "audio_played",
    "trace_started",
    "trace_completed",
    "sentence_viewed",
    "sentence_answered",
    "mission_started",
    "mission_completed",
    "nfc_detected",
    "nfc_audio_played",
]


class LearningEventRequest(BaseModel):
    userId: str | None = None
    vocabularyId: str
    eventType: LearningEventType
    source: Literal["web", "nfc"] = "web"
    timestamp: int
    meta: dict | None = None


class NfcEventRequest(BaseModel):
    tagUid: str
    deviceId: str | None = None
