"""Gemini Flash object recognition (spec §8.1), ported from
backend/app/services/gemini_vision.py.

Gemini returns ONLY the English name, a category, its confidence and a
kid-safe flag. It is never asked for Tibetan (DECISIONS.md D2).
"""

from __future__ import annotations

import json

from google import genai
from google.genai import errors, types

from pipeline import Vision

CATEGORIES = ["kitchen", "house", "school", "toy", "food", "nature", "clothes", "other"]

SYSTEM = (
    "You help a young child (4-8 years old) learn words. Look at the photo and "
    "name the ONE main everyday object in it, using the simplest common English "
    "noun a child would know (1-2 words, lowercase, singular, e.g. 'apple', "
    "'cup', 'teddy bear'). Name the physical object, not what is inside or on "
    "it: a cup of tea is 'cup', a plate of rice is 'plate'. Never name a brand. "
    "Set kid_safe to false if the main subject is a person or face, a weapon, "
    "medicine or pills, alcohol, cigarettes, anything dangerous, or anything "
    "not suitable for a young child. "
    "confidence is how sure you are about the object name, from 0 to 1. If the "
    "photo is blurry, dark, or has no clear single object, give a low confidence."
)

SCHEMA = {
    "type": "object",
    "properties": {
        "english": {"type": "string"},
        "category": {"type": "string", "enum": CATEGORIES},
        "confidence": {"type": "number"},
        "kid_safe": {"type": "boolean"},
    },
    "required": ["english", "category", "confidence", "kid_safe"],
}


# Overloaded (503) or rate-limited (429): worth trying the fallback model.
_BUSY = {429, 503}


class GeminiVision:
    """Calls the configured model, and the fallback model only if the first
    one is busy, so a demand spike doesn't turn into "let's try again"."""

    def __init__(self, api_key: str, model: str, fallback: str | None = None):
        self._client = genai.Client(api_key=api_key)
        self._models = [m for m in (model, fallback) if m]

    def __call__(self, image: bytes) -> Vision:
        for i, model in enumerate(self._models):
            try:
                return self._ask(model, image)
            except errors.APIError as exc:
                if exc.code not in _BUSY or i == len(self._models) - 1:
                    raise
        raise RuntimeError("no Gemini model configured")

    def _ask(self, model: str, image: bytes) -> Vision:
        response = self._client.models.generate_content(
            model=model,
            contents=[
                types.Part.from_bytes(data=image, mime_type="image/jpeg"),
                "What is the main object in this photo?",
            ],
            config=types.GenerateContentConfig(
                system_instruction=SYSTEM,
                response_mime_type="application/json",
                response_schema=SCHEMA,
                temperature=0.2,
            ),
        )
        data = json.loads(response.text)
        category = str(data.get("category", "other")).lower()
        return Vision(
            english=str(data.get("english", "")).strip().lower(),
            category=category if category in CATEGORIES else "other",
            confidence=float(data.get("confidence", 0)),
            kid_safe=bool(data.get("kid_safe", False)),
        )
