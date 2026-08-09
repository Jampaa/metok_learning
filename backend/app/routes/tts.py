"""POST /api/generate-tts

Generates Tibetan audio ONCE via Monlam and stores it in Firebase Storage,
returning a stable URL. Callers (the vocabulary/sentence content-authoring
flow) should save that URL back onto the vocabulary/sentence document so
the child's app only ever plays pre-generated audio — never call this on
every "Listen" tap (Section 14 of the spec).

TEMPORARY FALLBACK: until Firebase Storage is configured, this returns the
audio inline as a `data:audio/wav;base64,...` URI instead of a Storage URL,
so audio is still audible during setup. This is NOT the production path —
it re-calls Monlam on every request (cost + latency) instead of reusing a
stored file. Remove the fallback once FIREBASE_* env vars are set; the
route's response shape (`audioUrl: string`) doesn't change either way, so
nothing downstream needs to be touched.
"""

import base64
import logging
import re

from fastapi import APIRouter, HTTPException

from app.models.schemas import GenerateTtsRequest, GenerateTtsResponse
from app.services import firebase, monlam_tts

logger = logging.getLogger(__name__)
router = APIRouter()


def _slug(text: str) -> str:
    return re.sub(r"[^a-zA-Z0-9]+", "_", text).strip("_")[:60] or "audio"


@router.post("/generate-tts", response_model=GenerateTtsResponse)
async def generate_tts(payload: GenerateTtsRequest) -> GenerateTtsResponse:
    try:
        audio_bytes = await monlam_tts.generate_tibetan_audio(payload.text)
    except monlam_tts.MonlamTtsError as exc:
        logger.error("Monlam TTS failed: %s", exc)
        raise HTTPException(status_code=502, detail="Could not generate audio right now.") from exc

    path = f"audio/vocabulary/{_slug(payload.text)}.wav"
    url = firebase.upload_audio(path, audio_bytes, content_type="audio/wav")
    if url is None:
        logger.warning("Firebase Storage not configured — returning inline base64 audio (dev-only fallback).")
        encoded = base64.b64encode(audio_bytes).decode("ascii")
        url = f"data:audio/wav;base64,{encoded}"

    return GenerateTtsResponse(audioUrl=url)
