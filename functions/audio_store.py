"""Word audio in Cloud Storage, generated once per word (spec §8.2).

Shared by main.py (on demand) and seed_vocab.py (pre-generation).
"""

from __future__ import annotations

import os
from urllib.parse import quote

from monlam import TtsProvider


def public_url(bucket_name: str, path: str) -> str:
    """Download URL. `audio/**` is publicly readable in storage.rules, so no
    token is needed. Points at the Storage emulator when it's running."""
    host = os.environ.get("FIREBASE_STORAGE_EMULATOR_HOST")
    base = f"http://{host}" if host else "https://firebasestorage.googleapis.com"
    return f"{base}/v0/b/{bucket_name}/o/{quote(path, safe='')}?alt=media"


def ensure_audio(db, bucket, word_id: str, tibetan: str, tts: TtsProvider) -> str:
    """Synthesizes `tibetan`, stores it at audio/{wordId}.{ext}, records the
    URL on vocab/{wordId} and returns it."""
    path = f"audio/{word_id}.{tts.extension}"
    blob = bucket.blob(path)
    blob.cache_control = "public, max-age=31536000"
    blob.upload_from_string(tts.synthesize(tibetan), content_type=tts.content_type)
    url = public_url(bucket.name, path)
    db.collection("vocab").document(word_id).set({"audioUrl": url}, merge=True)
    return url
