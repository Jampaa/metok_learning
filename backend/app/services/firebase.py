"""Firebase Admin SDK integration (Firestore + Storage).

Only initialized when FIREBASE_* env vars are present, so the backend can
run (recognition/sentence endpoints still work) even before Firebase is
wired up. Vocabulary/sentence data itself is expected to live in Firestore
in production — see docs/database.md — with the frontend's local
src/data/vocabulary.ts as the offline-demo fallback.
"""

import logging

import firebase_admin
from firebase_admin import auth as firebase_auth
from firebase_admin import credentials, firestore, storage

from app.config import get_settings

logger = logging.getLogger(__name__)

_app: firebase_admin.App | None = None


def _get_app() -> firebase_admin.App | None:
    global _app
    settings = get_settings()
    if not settings.firebase_configured:
        return None
    if _app is None:
        cred = credentials.Certificate(
            {
                "type": "service_account",
                "project_id": settings.firebase_project_id,
                "client_email": settings.firebase_client_email,
                # Private keys in .env often have literal "\n" — convert back to real newlines.
                "private_key": settings.firebase_private_key.replace("\\n", "\n"),
                "token_uri": "https://oauth2.googleapis.com/token",
            }
        )
        _app = firebase_admin.initialize_app(
            cred, {"storageBucket": settings.firebase_storage_bucket}
        )
    return _app


def get_firestore_client():
    app = _get_app()
    if app is None:
        return None
    return firestore.client(app)


def _upload_bytes(path: str, data: bytes, content_type: str) -> str | None:
    app = _get_app()
    if app is None:
        logger.warning("Firebase not configured — skipping upload for %s", path)
        return None
    bucket = storage.bucket(app=app)
    blob = bucket.blob(path)
    blob.upload_from_string(data, content_type=content_type)
    blob.make_public()
    return blob.public_url


def upload_audio(path: str, audio_bytes: bytes, content_type: str = "audio/mpeg") -> str | None:
    """Uploads generated TTS audio to Firebase Storage and returns a public URL."""
    return _upload_bytes(path, audio_bytes, content_type)


def upload_image(path: str, image_bytes: bytes, content_type: str = "image/jpeg") -> str | None:
    """Uploads a discovery photo to Firebase Storage and returns a public URL."""
    return _upload_bytes(path, image_bytes, content_type)


def verify_id_token(token: str) -> str | None:
    """Verifies a Firebase Auth ID token and returns the uid, or None if
    invalid/expired/Firebase isn't configured. Never raises — callers treat
    None as "no verified identity" and decide what that means for the route.
    """
    app = _get_app()
    if app is None:
        return None
    try:
        decoded = firebase_auth.verify_id_token(token, app=app)
        return decoded["uid"]
    except Exception as exc:  # noqa: BLE001 — firebase_admin raises several distinct exception types for a bad token; all mean "not verified"
        logger.warning("ID token verification failed: %s", exc)
        return None
