import logging

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.config import get_settings
from app.routes import discovery, learning, recognition, sentences, tts, vocabulary

logging.basicConfig(level=logging.INFO)

settings = get_settings()

app = FastAPI(title="Tibetan Word Adventure API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origin_list,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(recognition.router, prefix="/api")
app.include_router(discovery.router, prefix="/api")
app.include_router(vocabulary.router, prefix="/api")
app.include_router(sentences.router, prefix="/api")
app.include_router(tts.router, prefix="/api")
app.include_router(learning.router, prefix="/api")


@app.get("/api/health")
async def health() -> dict:
    return {
        "status": "ok",
        "gemini_configured": settings.gemini_configured,
        "monlam_configured": settings.monlam_configured,
        "firebase_configured": settings.firebase_configured,
    }
