"""Yonten Cloud Functions (Python, 2nd gen, us-central1). Spec §8.

identify_object  callable: photo -> a word (see pipeline.py)
get_word_audio   callable: wordId -> URL of its Monlam audio in Storage

Secrets (never in the app):
    firebase functions:secrets:set GEMINI_API_KEY
    firebase functions:secrets:set MONLAM_API_KEY
For the emulator, put them in functions/.secret.local (git-ignored).
"""

from __future__ import annotations

import base64
import binascii
import logging

from firebase_admin import firestore, initialize_app, storage
from firebase_functions import https_fn, options, params

import pipeline
from audio_store import ensure_audio as _store_audio
from gemini_vision import GeminiVision
from monlam import MonlamClient, MonlamTts, StubTts, TtsProvider

initialize_app()
log = logging.getLogger("yonten")

GEMINI_API_KEY = params.SecretParam("GEMINI_API_KEY")
MONLAM_API_KEY = params.SecretParam("MONLAM_API_KEY")
# One place to upgrade the model (spec §1). Checked against Google's model
# list on 2026-10-09: gemini-3.8-flash is available.
GEMINI_MODEL = params.StringParam("GEMINI_MODEL", default="gemini-3.8-flash")
# Used only when the main model is overloaded (spec §1's stable replacement).
GEMINI_FALLBACK_MODEL = params.StringParam("GEMINI_FALLBACK_MODEL", default="gemini-3.6-flash")
MONLAM_VOICE = params.StringParam("MONLAM_VOICE", default="lhasa_female")

# App Check is switched on in Phase 9, once the web app registers a
# reCAPTCHA Enterprise key. Turning it on before that would block every call.
ENFORCE_APP_CHECK = False

MAX_IMAGE_BYTES = 2 * 1024 * 1024

options.set_global_options(region="us-central1", max_instances=10)


def _db():
    return firestore.client()


def _tts() -> TtsProvider:
    key = MONLAM_API_KEY.value
    return MonlamTts(key, MONLAM_VOICE.value) if key else StubTts()


def ensure_audio(word_id: str, tibetan: str) -> str:
    """Generates the word's audio once and records its URL on the vocab doc.
    Never regenerated per playback."""
    return _store_audio(_db(), storage.bucket(), word_id, tibetan, _tts())


class _LiveDeps:
    """Real services for pipeline.identify."""

    def __init__(self):
        self._vision = GeminiVision(GEMINI_API_KEY.value, GEMINI_MODEL.value,
                                    GEMINI_FALLBACK_MODEL.value)
        self._monlam = MonlamClient(MONLAM_API_KEY.value) if MONLAM_API_KEY.value else None

    def vision(self, image):
        return self._vision(image)

    def get_vocab(self, word_id):
        snap = _db().collection("vocab").document(word_id).get()
        return snap.to_dict() if snap.exists else None

    def save_vocab(self, word_id, doc):
        _db().collection("vocab").document(word_id).set(doc, merge=True)

    def dictionary(self, english, category):
        return self._monlam.lookup(english, category) if self._monlam else None

    def llm_translate(self, english, category):
        return self._monlam.translate(english, category) if self._monlam else None

    def audio_for(self, word_id, tibetan):
        return ensure_audio(word_id, tibetan)


def _require_auth(req: https_fn.CallableRequest) -> str:
    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED,
                                  "Please sign in first.")
    return req.auth.uid


@https_fn.on_call(
    secrets=[GEMINI_API_KEY, MONLAM_API_KEY],
    memory=options.MemoryOption.MB_512,
    timeout_sec=60,
    enforce_app_check=ENFORCE_APP_CHECK,
)
def identify_object(req: https_fn.CallableRequest) -> dict:
    """Input: {"image": base64 JPEG, at most 1024 px on its long side}.
    Output: {"status": "found", "word": {...}} or {"status": "retry", "reason"}.

    The photo isn't stored here. The app keeps the child's photos itself
    (DECISIONS.md D37).
    """
    _require_auth(req)
    data = req.data if isinstance(req.data, dict) else {}
    try:
        image = base64.b64decode(data.get("image", ""), validate=True)
    except (binascii.Error, ValueError):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "Bad image.")
    if not image or len(image) > MAX_IMAGE_BYTES:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT,
                                  "Image missing or too large.")
    try:
        return pipeline.identify(image, _LiveDeps(), now=lambda: firestore.SERVER_TIMESTAMP)
    except Exception:  # noqa: BLE001 - never show a child an error; the app says "let's try again"
        log.exception("identify_object failed")
        return {"status": "retry", "reason": "error"}


@https_fn.on_call(
    secrets=[MONLAM_API_KEY],
    timeout_sec=60,
    enforce_app_check=ENFORCE_APP_CHECK,
)
def get_word_audio(req: https_fn.CallableRequest) -> dict:
    """Input {"wordId"}. Output {"audioUrl"} for a verified word, generating
    and caching it on first request."""
    _require_auth(req)
    word_id = str((req.data or {}).get("wordId", "")).strip()
    if not word_id:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "wordId is required.")
    snap = _db().collection("vocab").document(word_id).get()
    if not snap.exists:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.NOT_FOUND, "Unknown word.")
    doc = snap.to_dict()
    if doc.get("audioUrl"):
        return {"audioUrl": doc["audioUrl"]}
    if not pipeline.is_verified(doc) or not doc.get("tibetan"):
        # Never speak an unverified word.
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.FAILED_PRECONDITION,
                                  "This word hasn't been checked yet.")
    try:
        return {"audioUrl": ensure_audio(word_id, doc["tibetan"])}
    except Exception:  # noqa: BLE001 - e.g. Monlam quota expired; try again later
        log.exception("get_word_audio failed for %s", word_id)
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAVAILABLE,
                                  "Audio isn't ready yet.")
