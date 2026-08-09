"""Object identification via Gemini Vision.

This service ONLY returns a plain-English object name + a coarse category —
it is never the source of Tibetan vocabulary. The caller
(routes/discovery.py) looks the Tibetan word up via Monlam's dictionary;
Gemini never sees or invents Tibetan. See docs/architecture.md.

The category is used purely for Treasure Hunt matching (Section: "similar
items should count") — any recognized "stationery" item satisfies a
stationery mission, without needing an exact pre-known word.
"""

import json
import logging

from google import genai
from google.genai import types

from app.config import get_settings

logger = logging.getLogger(__name__)

CATEGORIES = ("stationery", "kitchen", "house", "other")

PROMPT = (
    "Identify the single main physical object in this photo. "
    "Respond with ONLY a JSON object of the exact shape "
    '{"object": "<short common everyday English noun, 1-2 words, lowercase>", '
    '"category": "<one of: stationery, kitchen, house, other>", '
    '"confidence": <number between 0 and 1>}. '
    'Example: {"object": "pen", "category": "stationery", "confidence": 0.92}. '
    "'stationery' = writing/school supplies, 'kitchen' = cookware/food/dining "
    "items, 'house' = furniture/general household items, 'other' = anything "
    "else. Do not add markdown, code fences, or any other text."
)

_client: genai.Client | None = None


def _get_client() -> genai.Client:
    global _client
    if _client is None:
        settings = get_settings()
        _client = genai.Client(api_key=settings.gemini_api_key)
    return _client


async def identify_object(image_bytes: bytes, mime_type: str = "image/jpeg") -> tuple[str, str, float]:
    """Returns (object_name, category, confidence). Raises on Gemini/network failure."""
    settings = get_settings()
    if not settings.gemini_configured:
        raise RuntimeError("GEMINI_API_KEY is not configured")

    client = _get_client()
    try:
        response = client.models.generate_content(
            model="gemini-flash-latest",
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime_type),
                PROMPT,
            ],
            config=types.GenerateContentConfig(response_mime_type="application/json"),
        )
    except genai.errors.APIError as exc:
        logger.error("Gemini API call failed: %s", exc)
        raise RuntimeError(f"Gemini API call failed: {exc}") from exc

    try:
        data = json.loads(response.text)
        category = str(data.get("category", "other")).lower().strip()
        if category not in CATEGORIES:
            category = "other"
        return str(data["object"]).lower().strip(), category, float(data["confidence"])
    except (KeyError, ValueError, TypeError, json.JSONDecodeError) as exc:
        logger.warning("Unexpected Gemini response, falling back: %s", response.text)
        raise RuntimeError("Gemini returned an unparseable response") from exc
