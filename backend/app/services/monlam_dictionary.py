"""Monlam English→Tibetan dictionary lookup, with sense-disambiguation.

Confirmed against https://api-v1.monlamai.studio/docs with real calls.

WHY THIS IS MORE THAN "TAKE THE FIRST /search RESULT": testing showed
/dictionary/search's top-ranked result is wrong or garbled surprisingly
often on ordinary household nouns —

    pen      -> the animal-enclosure sense, not the writing instrument
    table    -> "spreadsheet/chart" sense, not the furniture
    notebook -> "laptop computer" sense, not a paper notebook
    mug, sofa -> a single dictionary entry mashing together multiple
                 numbered senses in one string ("n. 1. ... 2. ...")

...while also confirming that "multiple candidate entries" is NOT itself a
sign of a problem — "book" has 10 candidates that are almost all valid
synonyms (དཔེ་དེབ, དེབ, གླེགས་བམ, ...), and its first /search result was
already correct. So candidate *count* can't be used to decide when to
trust the top result; only an LLM judging actual meaning can. Hence: fetch
the small set of exact-word candidates, filter out syntactically-garbled
entries, and always confirm the pick with one Monlam chat call — but only
for a word the FIRST time it's ever seen (the caller caches the result).
"""

import asyncio
import logging
import re

import httpx

from app.config import get_settings
from app.services import monlam_chat

logger = logging.getLogger(__name__)

MAX_CANDIDATES = 8
_TIBETAN_RUN = re.compile(r"[ༀ-࿿][ༀ-࿿\s]*")
_MULTI_SENSE_MARKER = re.compile(r"\d\s*\.|^\s*(n|v|adj|adv|pl|v\.i|v\.t)\.\s", re.IGNORECASE)


class MonlamDictionaryError(RuntimeError):
    pass


def _extract_tibetan(explanation: str) -> str:
    """Explanations look like "<tibetan> <english gloss>" — pull out the
    first run of Tibetan-script text, wherever it appears in the string
    (garbled entries sometimes have Latin text before the Tibetan starts).
    """
    match = _TIBETAN_RUN.search(explanation)
    return match.group().strip() if match else ""


def _is_clean(explanation: str) -> bool:
    """Rejects entries that mash multiple numbered senses / part-of-speech
    definitions into one string — those need LLM cleanup, not display as-is.
    """
    return not _MULTI_SENSE_MARKER.search(explanation)


async def _fetch_candidates(client: httpx.AsyncClient, headers: dict, english: str) -> list[dict]:
    settings = get_settings()
    try:
        response = await client.get(
            f"{settings.monlam_dictionary_url.rsplit('/search', 1)[0]}/suggestions",
            headers=headers,
            params={"pair": "en-bo", "q": english},
        )
    except httpx.HTTPError as exc:
        raise MonlamDictionaryError(f"Could not reach Monlam dictionary: {exc}") from exc
    if response.status_code != 200:
        return []
    suggestions = response.json().get("data", {}).get("suggestions", [])
    exact_ids = [s["word_id"] for s in suggestions if s.get("word", "").lower() == english.lower()][:MAX_CANDIDATES]

    async def fetch_entry(word_id: int) -> dict | None:
        entry_url = f"{settings.monlam_dictionary_url.rsplit('/search', 1)[0]}/entry"
        try:
            r = await client.get(entry_url, headers=headers, params={"pair": "en-bo", "id": word_id})
        except httpx.HTTPError as exc:
            logger.warning("Entry fetch failed for word_id %s: %s", word_id, exc)
            return None
        if r.status_code != 200:
            return None
        return r.json().get("data")

    entries = await asyncio.gather(*(fetch_entry(wid) for wid in exact_ids))
    return [e for e in entries if e]


async def lookup_translation(english: str, category: str = "other") -> dict | None:
    """Returns {"tibetan": str, "wordId": int | None, "explanation": str}
    for the best-judged match, or None if the word isn't in Monlam's
    dictionary at all.
    """
    settings = get_settings()
    if not settings.monlam_configured:
        raise MonlamDictionaryError("MONLAM_API_KEY is not configured")

    headers = {"X-API-Key": settings.monlam_api_key}
    async with httpx.AsyncClient(timeout=30.0) as client:
        candidates = await _fetch_candidates(client, headers, english)

        if not candidates:
            # Fall back to plain /search in case /suggestions missed it.
            try:
                response = await client.get(settings.monlam_dictionary_url, headers=headers, params={"pair": "en-bo", "q": english})
            except httpx.HTTPError as exc:
                raise MonlamDictionaryError(f"Could not reach Monlam dictionary: {exc}") from exc
            if response.status_code != 200:
                raise MonlamDictionaryError(f"Monlam dictionary API returned {response.status_code}")
            results = response.json().get("data", {}).get("results", [])
            if not results:
                return None
            candidates = [results[0]["data"]]

    clean = [c for c in candidates if _is_clean(c.get("explanation", ""))]

    # Fast path: exactly one clean candidate, nothing to disambiguate.
    if len(clean) == 1 and len(candidates) == 1:
        tibetan = _extract_tibetan(clean[0]["explanation"])
        return {"tibetan": tibetan, "wordId": clean[0].get("word_id"), "explanation": clean[0]["explanation"]}

    # Otherwise, let the LLM pick/clean up using the object's category as context.
    pool = clean or candidates  # prefer clean entries, but give the LLM something even if all are messy
    picked = await monlam_chat.pick_best_translation(english, category, pool)
    if picked and _extract_tibetan(picked):
        return {"tibetan": _extract_tibetan(picked), "wordId": None, "explanation": f"LLM-disambiguated from {len(pool)} candidates"}

    # Last-resort fallback: the dictionary's own top-ranked result, even if unverified.
    fallback = candidates[0]
    return {"tibetan": _extract_tibetan(fallback["explanation"]), "wordId": fallback.get("word_id"), "explanation": fallback["explanation"]}
