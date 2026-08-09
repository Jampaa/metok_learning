"""Monlam chat/LLM integration (model "melong" by default).

Used for three things:
  1. Drafting simple sentences for a learned word (replaces the old
     gemini_llm.py — same function signature, drop-in swap).
  2. Disambiguating dictionary candidates when Monlam's dictionary search
     returns the wrong sense of a polysemous word (see monlam_dictionary.py).
  3. LAST-RESORT translation when the dictionary itself is unavailable
     (rate-limited, network error) or genuinely has no entry for a word —
     see translate_word(). This is deliberately the least-trusted path in
     the whole pipeline: the dictionary is real, human-compiled data;
     this is an LLM guessing. Callers must mark results from this path as
     unverified (see routes/discovery.py's `source` field) rather than
     treating them the same as a dictionary hit.

Confirmed live: POST /api/v1/ai/chat with {"messages": [...]} returns
{"response": "<string>", ...billing fields}. The "response" field is a
STRING that itself needs json.loads() when we ask for JSON — it is not
pre-parsed by the API.
"""

import json
import logging

import httpx

from app.config import get_settings

logger = logging.getLogger(__name__)


class MonlamChatError(RuntimeError):
    pass


async def _chat(prompt: str) -> str:
    settings = get_settings()
    if not settings.monlam_configured:
        raise MonlamChatError("MONLAM_API_KEY is not configured")

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            response = await client.post(
                settings.monlam_chat_url,
                headers={"X-API-Key": settings.monlam_api_key},
                json={
                    "model_name": settings.monlam_chat_model,
                    "messages": [{"role": "user", "content": prompt}],
                },
            )
    except httpx.HTTPError as exc:
        logger.error("Monlam chat network error: %s", exc)
        raise MonlamChatError(f"Could not reach Monlam chat: {exc}") from exc

    if response.status_code != 200:
        logger.error("Monlam chat request failed: %s %s", response.status_code, response.text[:500])
        raise MonlamChatError(f"Monlam chat API returned {response.status_code}")

    return response.json()["response"]


async def generate_draft_sentences(english: str, tibetan: str, level: str = "beginner") -> list[dict]:
    prompt = (
        f"Write 2 very simple {level}-level Tibetan sentences for a young child, "
        f"each using the word '{tibetan}' (English: '{english}'). "
        'Respond with ONLY a JSON object: {"sentences": [{"english": "...", "tibetan": "..."}, ...]}. '
        "Keep grammar and vocabulary extremely simple. No markdown."
    )
    try:
        raw = await _chat(prompt)
        data = json.loads(raw)
        return data["sentences"]
    except (MonlamChatError, KeyError, ValueError, TypeError, json.JSONDecodeError) as exc:
        logger.warning("Sentence generation failed for '%s': %s", english, exc)
        raise MonlamChatError(f"Could not generate sentences for '{english}'") from exc


async def pick_best_translation(english: str, category: str, candidates: list[dict]) -> str | None:
    """Given several raw dictionary entries for an English word, asks the LLM
    which one actually means the recognized object (not a homonym/other
    sense). Returns the chosen Tibetan text, or None if the LLM's answer
    doesn't look like valid Tibetan (caller should fall back).
    """
    numbered = "\n".join(f"{i+1}. {c['explanation']}" for i, c in enumerate(candidates))
    prompt = (
        f"A photo was identified as a '{english}' (category: {category}). "
        f"Here are Tibetan dictionary entries that matched the English word '{english}':\n{numbered}\n\n"
        f"Some of these may be unrelated meanings (e.g. a different sense of the English word) or "
        f"messy multi-definition entries. Pick or extract the single correct, clean Tibetan word or "
        f"short phrase for '{english}' as a {category} item. "
        'Respond with ONLY JSON: {"tibetan": "<Tibetan script only, no English>"}'
    )
    try:
        raw = await _chat(prompt)
        data = json.loads(raw)
        tibetan = str(data.get("tibetan", "")).strip()
        return tibetan or None
    except (MonlamChatError, ValueError, TypeError, json.JSONDecodeError) as exc:
        logger.warning("Disambiguation failed for '%s': %s", english, exc)
        return None


async def translate_word(english: str, category: str) -> str | None:
    """Asks the LLM directly for a Tibetan translation — used only when
    Monlam's dictionary itself couldn't answer (down, rate-limited, or no
    entry for this word at all). Returns None if the LLM doesn't have a
    confident answer either, rather than guessing.
    """
    prompt = (
        f"What is the standard, commonly used Tibetan word or short phrase "
        f"for the English word '{english}' (a {category} item)? "
        'Respond with ONLY JSON: {"tibetan": "<Tibetan script only, no English, no explanation>"}. '
        'If you are not confident of a correct Tibetan translation, respond with {"tibetan": null} instead of guessing.'
    )
    try:
        raw = await _chat(prompt)
        data = json.loads(raw)
        tibetan = data.get("tibetan")
        if not tibetan or not isinstance(tibetan, str):
            return None
        return tibetan.strip()
    except (MonlamChatError, ValueError, TypeError, json.JSONDecodeError) as exc:
        logger.warning("LLM translation fallback failed for '%s': %s", english, exc)
        return None
