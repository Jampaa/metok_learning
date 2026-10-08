"""The scan pipeline (spec §8.1), with every outside service injected.

    photo -> Gemini (English name, confidence, kid_safe ONLY)
          -> vocab catalog (a word we already know)
          -> Monlam dictionary (authoritative Tibetan, verified)
          -> Monlam LLM (last resort, unverified, never shown to a child)
          -> Monlam TTS audio, for verified words only

Gemini is never asked for Tibetan (DECISIONS.md D2), and Tibetan from an
unverified entry never leaves the server (D36).
"""

from __future__ import annotations

import re
from dataclasses import dataclass
from typing import Callable, Protocol

MIN_CONFIDENCE = 0.6


@dataclass(frozen=True)
class Vision:
    english: str
    category: str
    confidence: float
    kid_safe: bool


class Deps(Protocol):
    def vision(self, image: bytes) -> Vision: ...
    def get_vocab(self, word_id: str) -> dict | None: ...
    def save_vocab(self, word_id: str, doc: dict) -> None: ...
    def dictionary(self, english: str, category: str) -> str | None: ...
    def llm_translate(self, english: str, category: str) -> str | None: ...
    def audio_for(self, word_id: str, tibetan: str) -> str | None: ...


def normalize_key(english: str) -> str:
    """'Teddy  Bear' -> 'teddy-bear'. Safe as a Firestore doc id."""
    key = re.sub(r"[^a-z0-9]+", "-", english.strip().lower()).strip("-")
    return key[:60] or "thing"


def is_verified(doc: dict) -> bool:
    # Spec §7 calls the flag `reviewed`; this project uses `verified` (D3).
    return bool(doc.get("verified") or doc.get("reviewed"))


def public_word(word_id: str, doc: dict, audio_url: str | None) -> dict:
    """What the app receives. Unverified Tibetan is withheld here, on the
    server, so no client bug can ever show it to a child."""
    verified = is_verified(doc) and bool(doc.get("tibetan"))
    return {
        "id": word_id,
        "english": doc.get("english", word_id),
        "tibetan": doc.get("tibetan", "") if verified else "",
        "phonetic": doc.get("phonetic", "") if verified else "",
        "verified": verified,
        "audioUrl": audio_url if verified else None,
        "category": doc.get("category", "other"),
    }


def identify(image: bytes, deps: Deps, *, now: Callable[[], object],
             min_confidence: float = MIN_CONFIDENCE) -> dict:
    v = deps.vision(image)
    if not v.kid_safe:
        return {"status": "retry", "reason": "not_kid_safe"}
    if v.confidence < min_confidence or not v.english.strip():
        return {"status": "retry", "reason": "low_confidence"}

    word_id = normalize_key(v.english)
    doc = deps.get_vocab(word_id)
    if doc is None:
        doc = build_entry(v, deps, now=now)
        deps.save_vocab(word_id, doc)

    audio = doc.get("audioUrl")
    if is_verified(doc) and doc.get("tibetan") and not audio:
        try:
            audio = deps.audio_for(word_id, doc["tibetan"])
        except Exception:  # noqa: BLE001 - audio is optional; the word still counts
            audio = None
    return {"status": "found", "word": public_word(word_id, doc, audio)}


def build_entry(v: Vision, deps: Deps, *, now: Callable[[], object]) -> dict:
    """A new `vocab` doc for a word nobody has scanned before."""
    english = v.english.strip().lower()
    tibetan, source = None, None
    try:
        tibetan = deps.dictionary(english, v.category)
        source = "monlam_dictionary" if tibetan else None
    except Exception:  # noqa: BLE001 - dictionary down: fall through to the LLM
        tibetan = None
    if not tibetan:
        try:
            tibetan = deps.llm_translate(english, v.category)
            source = "monlam_llm" if tibetan else None
        except Exception:  # noqa: BLE001
            tibetan = None
    return {
        "english": english,
        "tibetan": tibetan or "",
        "phonetic": "",
        # Monlam's dictionary is the authoritative source (docs/architecture.md);
        # an LLM guess waits for a teacher.
        "verified": source == "monlam_dictionary",
        "source": source or "none",
        "category": v.category,
        "createdAt": now(),
    }
