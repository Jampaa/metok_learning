"""Monlam AI: dictionary, chat (sense-check / last-resort translation) and
text-to-speech. Ported from backend/app/services/monlam_*.py and made
synchronous for Cloud Functions. All endpoints use the `X-API-Key` header.

Why the dictionary needs a sense-check (from the legacy backend's testing):
the top /search result is often the wrong sense of a household noun (pen ->
animal enclosure, table -> spreadsheet, notebook -> laptop). So we fetch the
exact-word candidates, drop garbled multi-sense entries, and when there's
more than one, let Monlam's own LLM pick between the dictionary's entries.
The LLM never invents the word on this path.
"""

from __future__ import annotations

import io
import json
import logging
import re
import wave
from concurrent.futures import ThreadPoolExecutor
from typing import Protocol

import httpx

log = logging.getLogger(__name__)

BASE = "https://api-v1.monlamai.studio/api/v1"
DICT_URL = f"{BASE}/dictionary"
CHAT_URL = f"{BASE}/ai/chat"
TTS_URL = f"{BASE}/text-to-speech/stream"
CHAT_MODEL = "melong"
MAX_CANDIDATES = 8

_TIBETAN_RUN = re.compile(r"[ༀ-࿿][ༀ-࿿\s]*")
_MULTI_SENSE = re.compile(r"\d\s*\.|^\s*(n|v|adj|adv|pl|v\.i|v\.t)\.\s", re.IGNORECASE)


def extract_tibetan(text: str) -> str:
    m = _TIBETAN_RUN.search(text or "")
    return m.group().strip() if m else ""


def is_clean(explanation: str) -> bool:
    return not _MULTI_SENSE.search(explanation or "")


class MonlamClient:
    def __init__(self, api_key: str, timeout: float = 30.0):
        self._headers = {"X-API-Key": api_key}
        self._timeout = timeout

    # ---------- chat ----------

    def _chat(self, prompt: str) -> str:
        r = httpx.post(CHAT_URL, headers=self._headers, timeout=self._timeout, json={
            "model_name": CHAT_MODEL,
            "messages": [{"role": "user", "content": prompt}],
        })
        r.raise_for_status()
        # "response" is a string that itself holds the JSON we asked for.
        return r.json()["response"]

    def pick_best(self, english: str, category: str, candidates: list[dict]) -> str | None:
        numbered = "\n".join(f"{i + 1}. {c.get('explanation', '')}" for i, c in enumerate(candidates))
        prompt = (
            f"A photo was identified as a '{english}' (category: {category}). "
            f"Here are Tibetan dictionary entries that matched the English word '{english}':\n{numbered}\n\n"
            "Some may be unrelated meanings or messy multi-definition entries. Pick or extract "
            f"the single correct, clean Tibetan word for '{english}' as a {category} item. "
            'Respond with ONLY JSON: {"tibetan": "<Tibetan script only, no English>"}'
        )
        try:
            return extract_tibetan(str(json.loads(self._chat(prompt)).get("tibetan", ""))) or None
        except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
            log.warning("Monlam sense-check failed for %r: %s", english, exc)
            return None

    def translate(self, english: str, category: str) -> str | None:
        """Last resort when the dictionary has no entry. The result is stored
        unverified and never shown to a child until a teacher checks it."""
        prompt = (
            f"What is the standard, commonly used Tibetan word for the English word "
            f"'{english}' (a {category} item)? "
            'Respond with ONLY JSON: {"tibetan": "<Tibetan script only>"}. '
            'If you are not confident, respond with {"tibetan": null} instead of guessing.'
        )
        try:
            value = json.loads(self._chat(prompt)).get("tibetan")
            return extract_tibetan(value) if isinstance(value, str) else None
        except (httpx.HTTPError, ValueError, TypeError, KeyError) as exc:
            log.warning("Monlam translate failed for %r: %s", english, exc)
            return None

    # ---------- dictionary ----------

    def _candidates(self, client: httpx.Client, english: str) -> list[dict]:
        r = client.get(f"{DICT_URL}/suggestions", params={"pair": "en-bo", "q": english})
        if r.status_code != 200:
            return []
        suggestions = r.json().get("data", {}).get("suggestions", [])
        ids = [s["word_id"] for s in suggestions
               if s.get("word", "").lower() == english.lower()][:MAX_CANDIDATES]

        def entry(word_id: int) -> dict | None:
            e = client.get(f"{DICT_URL}/entry", params={"pair": "en-bo", "id": word_id})
            return e.json().get("data") if e.status_code == 200 else None

        with ThreadPoolExecutor(max_workers=4) as pool:
            return [e for e in pool.map(entry, ids) if e]

    def lookup(self, english: str, category: str) -> str | None:
        """Tibetan for `english` from Monlam's dictionary, or None if the
        dictionary has no entry. Raises httpx.HTTPError if it's unreachable."""
        with httpx.Client(headers=self._headers, timeout=self._timeout) as client:
            candidates = self._candidates(client, english)
            if not candidates:
                r = client.get(f"{DICT_URL}/search", params={"pair": "en-bo", "q": english})
                r.raise_for_status()
                results = r.json().get("data", {}).get("results", [])
                if not results:
                    return None
                candidates = [results[0]["data"]]

        clean = [c for c in candidates if is_clean(c.get("explanation", ""))]
        if len(clean) == 1 and len(candidates) == 1:
            return extract_tibetan(clean[0]["explanation"]) or None
        picked = self.pick_best(english, category, clean or candidates)
        if picked:
            return picked
        return extract_tibetan(candidates[0].get("explanation", "")) or None


# ---------- text-to-speech ----------

class TtsProvider(Protocol):
    """Swappable so the endpoint or vendor can change (spec §8.2)."""

    content_type: str
    extension: str

    def synthesize(self, tibetan: str) -> bytes: ...


class MonlamTts:
    content_type = "audio/wav"
    extension = "wav"

    def __init__(self, api_key: str, voice: str = "lhasa_female"):
        self._headers = {"X-API-Key": api_key}
        self._voice = voice

    def synthesize(self, tibetan: str) -> bytes:
        r = httpx.post(TTS_URL, headers=self._headers, timeout=45.0, json={
            "text": tibetan, "voice_name": self._voice, "is_async": False,
        })
        r.raise_for_status()
        if "audio" not in r.headers.get("content-type", ""):
            raise RuntimeError(f"Monlam TTS returned {r.headers.get('content-type')}")
        return r.content


class StubTts:
    """Placeholder clip (0.4 s of silence) for when no Monlam key is set,
    e.g. a fresh emulator. Lets the whole flow run end to end."""

    content_type = "audio/wav"
    extension = "wav"

    def synthesize(self, tibetan: str) -> bytes:
        buf = io.BytesIO()
        with wave.open(buf, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(16000)
            w.writeframes(b"\x00\x00" * 6400)
        return buf.getvalue()
