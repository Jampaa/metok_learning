"""Monlam Tibetan TTS integration.

Confirmed against https://api-v1.monlamai.studio/docs (OpenAPI spec) on
2026-08-08. Uses the synchronous streaming endpoint
(POST /api/v1/text-to-speech/stream), which returns raw `audio/wav` bytes
directly — no async job/polling needed for our use case.

Auth: `X-API-Key` header (not Bearer).
Voices: lhasa_female, lhasa_male, amdo_female, amdo_male, kham_female,
kham_male — see MONLAM_VOICE_NAME in .env.
"""

import logging

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)


class MonlamTtsError(RuntimeError):
    pass


async def generate_tibetan_audio(text: str) -> bytes:
    """Returns raw WAV audio bytes for the given Tibetan text.

    Callers are expected to upload the result to Firebase Storage themselves
    (see routes/tts.py) and persist the resulting URL — never regenerate
    audio on every playback (Section 14 of the spec).
    """
    settings = get_settings()
    if not settings.monlam_configured:
        raise MonlamTtsError("MONLAM_API_KEY is not configured")

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                settings.monlam_api_url,
                headers={"X-API-Key": settings.monlam_api_key},
                json={
                    "text": text,
                    "voice_name": settings.monlam_voice_name,
                    "is_async": False,
                },
            )
    except httpx.HTTPError as exc:
        logger.error("Monlam TTS network error: %s", exc)
        raise MonlamTtsError(f"Could not reach Monlam TTS: {exc}") from exc

    if response.status_code != 200:
        logger.error("Monlam TTS request failed: %s %s", response.status_code, response.text[:500])
        raise MonlamTtsError(f"Monlam API returned {response.status_code}: {response.text[:200]}")

    content_type = response.headers.get("content-type", "")
    if "audio" not in content_type:
        raise MonlamTtsError(f"Expected audio, got content-type '{content_type}': {response.text[:200]}")

    return response.content
