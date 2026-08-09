"""POST /api/discover

One-call orchestration: photo -> Gemini (object + category + confidence) ->
shared word lookup -> per-user discovery record -> a VocabularyItem-shaped
result.

Two separate Firestore layers, deliberately not merged into one doc:

  vocabulary/{word}              SHARED, global. Tibetan translation, the
                                  word's own pronunciation audio, sentences,
                                  category. A pen's Tibetan name is the same
                                  fact for every user — no reason to look it
                                  up or pay for TTS/LLM calls more than once,
                                  ever, for the whole app.

  users/{uid}/discoveries/{word} PER-USER, exclusive. Just this user's own
                                  photo of the object and when they found
                                  it. Two different users scanning their own
                                  pens each get their own photo here — never
                                  each other's. This is what "have I found
                                  this word" and Treasure Hunt progress are
                                  based on, not the shared vocabulary cache.

Auth: when Firebase is configured, a valid Firebase ID token is REQUIRED
(`Authorization: Bearer <token>`) — per-user data has nowhere to go without
knowing who "user" is. When Firebase isn't configured at all (local/offline
dev), auth is skipped entirely and this endpoint behaves as pure passthrough
with no caching of any kind, same as before this split existed.

Response is one of three shapes (no single response_model — they're
genuinely different, all returned as 200s since they're expected outcomes,
not failures):
  {"status": "low_confidence", "object", "category", "confidence"}
  {"status": "not_in_dictionary", "object", "category", "confidence"}
  {"status": "ok", ...full vocabulary item, imageUrl = THIS user's photo}

Per Section 25 (child privacy): a photo is only ever stored the first time
its owner discovers that specific word — never for a low-confidence/unknown
shot, and never a second copy for a word that same user already found.
"""

import base64
import logging
import re

from fastapi import APIRouter, Depends, File, Header, HTTPException, UploadFile
from google.cloud.firestore_v1 import SERVER_TIMESTAMP

from app.config import get_settings
from app.services import firebase, gemini_vision, monlam_chat, monlam_dictionary, monlam_tts

logger = logging.getLogger(__name__)
router = APIRouter()

MAX_IMAGE_BYTES = 8 * 1024 * 1024

CATEGORY_EMOJI = {"stationery": "✏️", "kitchen": "🍽️", "house": "🛋️", "other": "📦"}

EXTENSION_FOR_CONTENT_TYPE = {"image/jpeg": "jpg", "image/png": "png", "image/webp": "webp"}


def _normalize_key(english: str) -> str:
    return re.sub(r"\s+", " ", english.strip().lower())


async def get_current_uid(authorization: str | None = Header(default=None)) -> str | None:
    """FastAPI dependency: resolves the caller's uid from a Bearer ID token.

    Returns None (no auth required) when Firebase isn't configured on this
    backend at all — that's the offline/local-dev case, where there's no
    per-user data to protect in the first place. Once Firebase IS
    configured, a valid token is mandatory: without a uid there's no place
    to put a per-user discovery record, so we can't proceed.
    """
    settings = get_settings()
    if not settings.firebase_configured:
        return None

    if not authorization or not authorization.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Please sign in to start discovering words.")

    token = authorization.removeprefix("Bearer ").strip()
    uid = firebase.verify_id_token(token)
    if uid is None:
        raise HTTPException(status_code=401, detail="Your sign-in has expired — please sign in again.")
    return uid


async def _get_shared_word(db, key: str) -> dict | None:
    if db is None:
        return None
    try:
        doc = db.collection("vocabulary").document(key).get()
        return doc.to_dict() if doc.exists else None
    except Exception as exc:  # noqa: BLE001 — a read hiccup should degrade to "treat as uncached", not crash the request
        logger.warning("Firestore shared-word read failed for '%s' (treating as cache miss): %s", key, exc)
        return None


async def _build_shared_word(key: str, category: str) -> dict | None:
    """Runs the Monlam pipeline for a word nobody has ever looked up before.
    Returns None only if NEITHER the dictionary NOR the LLM fallback can
    produce a translation.

    The dictionary is tried first — it's real, human-compiled data, so it's
    trusted (`verified: True`) once Monlam's own sense-check confirms it
    (see monlam_dictionary.py). If the dictionary is down (rate-limited,
    network error) or genuinely has no entry, we fall back to asking
    Monlam's LLM directly instead of failing outright — clearly marked
    `verified: False` / `source: "monlam_llm_fallback"` since an LLM guess
    is a materially different trust level than a dictionary hit.
    """
    translation = None
    try:
        translation = await monlam_dictionary.lookup_translation(key, category)
    except monlam_dictionary.MonlamDictionaryError as exc:
        logger.warning("Dictionary lookup failed for '%s', falling back to LLM translation: %s", key, exc)

    source = "monlam_dictionary"
    if translation is None:
        llm_tibetan = await monlam_chat.translate_word(key, category)
        if llm_tibetan is None:
            return None
        translation = {"tibetan": llm_tibetan}
        source = "monlam_llm_fallback"

    tibetan = translation["tibetan"]

    audio_url = None
    try:
        audio_bytes = await monlam_tts.generate_tibetan_audio(tibetan)
        audio_url = firebase.upload_audio(
            f"audio/vocabulary/{key.replace(' ', '_')}.wav", audio_bytes, content_type="audio/wav"
        )
        if audio_url is None:
            audio_url = f"data:audio/wav;base64,{base64.b64encode(audio_bytes).decode('ascii')}"
    except monlam_tts.MonlamTtsError as exc:
        logger.warning("TTS generation failed for '%s' (non-fatal): %s", tibetan, exc)
    except Exception as exc:  # noqa: BLE001 — a Storage upload hiccup shouldn't block showing the word, just its audio
        logger.warning("Audio upload failed for '%s' (non-fatal): %s", tibetan, exc)

    try:
        sentences = await monlam_chat.generate_draft_sentences(key, tibetan)
    except monlam_chat.MonlamChatError as exc:
        logger.warning("Sentence generation failed for '%s' (non-fatal): %s", key, exc)
        sentences = []

    return {
        "id": key,
        "english": key,
        "tibetan": tibetan,
        "verified": source == "monlam_dictionary",
        "category": category,
        "difficulty": 1,
        "emoji": CATEGORY_EMOJI.get(category, "📦"),
        "audioUrl": audio_url,
        "sentences": sentences,
        "source": source,
    }


async def _get_or_create_user_photo(db, uid: str, key: str, image_bytes: bytes, content_type: str) -> str | None:
    """Returns this user's own photo URL for this word — reusing it if
    they've found this word before, uploading a fresh one (to a per-user
    Storage path) if this is their first time.
    """
    doc_ref = db.collection("users").document(uid).collection("discoveries").document(key)
    try:
        doc = doc_ref.get()
        if doc.exists:
            return doc.to_dict().get("imageUrl")
    except Exception as exc:  # noqa: BLE001 — a read hiccup shouldn't block returning the word, just re-uploads a photo unnecessarily this once
        logger.warning("Per-user discovery read failed for uid=%s word=%s: %s", uid, key, exc)

    extension = EXTENSION_FOR_CONTENT_TYPE.get(content_type, "jpg")
    image_url = None
    try:
        image_url = firebase.upload_image(
            f"images/users/{uid}/{key.replace(' ', '_')}.{extension}", image_bytes, content_type=content_type
        )
    except Exception as exc:  # noqa: BLE001 — a Storage hiccup shouldn't block showing the word, just its photo
        logger.warning("Image upload failed for uid=%s word=%s (non-fatal): %s", uid, key, exc)

    try:
        doc_ref.set({"imageUrl": image_url, "discoveredAt": SERVER_TIMESTAMP})
    except Exception as exc:  # noqa: BLE001 — a failed write shouldn't stop us returning the word/photo we already have
        logger.warning("Per-user discovery write failed for uid=%s word=%s: %s", uid, key, exc)

    return image_url


@router.post("/discover")
async def discover(image: UploadFile = File(...), uid: str | None = Depends(get_current_uid)) -> dict:
    image_bytes = await image.read()
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image too large")
    if not image_bytes:
        raise HTTPException(status_code=400, detail="No image received")

    settings = get_settings()
    try:
        object_name, category, confidence = await gemini_vision.identify_object(
            image_bytes, mime_type=image.content_type or "image/jpeg"
        )
    except RuntimeError as exc:
        logger.error("Discovery recognition failed: %s", exc)
        raise HTTPException(status_code=502, detail="We couldn't identify that object. Try another picture!") from exc

    if confidence < settings.recognition_confidence_threshold:
        return {"status": "low_confidence", "object": object_name, "category": category, "confidence": confidence}

    key = _normalize_key(object_name)
    db = firebase.get_firestore_client()

    shared_word = await _get_shared_word(db, key)
    if shared_word is None:
        shared_word = await _build_shared_word(key, category)
        if shared_word is None:
            return {"status": "not_in_dictionary", "object": object_name, "category": category, "confidence": confidence}
        if db is not None:
            try:
                db.collection("vocabulary").document(key).set(shared_word)
            except Exception as exc:  # noqa: BLE001 — a failed cache write shouldn't stop us from returning the word we already have
                logger.warning("Shared-word cache write failed for '%s': %s", key, exc)

    image_url = None
    if db is not None and uid is not None:
        image_url = await _get_or_create_user_photo(
            db, uid, key, image_bytes, image.content_type or "image/jpeg"
        )

    return {"status": "ok", **shared_word, "imageUrl": image_url}
