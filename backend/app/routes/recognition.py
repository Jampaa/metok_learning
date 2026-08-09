"""POST /api/recognize-object

Camera image in -> Gemini identifies the object -> plain object name out.
The frontend, not this route, looks the name up in the curated vocabulary —
this route deliberately knows nothing about Tibetan vocabulary (Section 2 of
the spec: AI discovers, database teaches).

Per Section 25 (child privacy): the uploaded image is only held in memory
for the duration of this request and is never written to disk or storage.
"""

import logging

from fastapi import APIRouter, File, HTTPException, UploadFile

from app.models.schemas import RecognitionResponse
from app.services import gemini_vision

logger = logging.getLogger(__name__)
router = APIRouter()

MAX_IMAGE_BYTES = 8 * 1024 * 1024


@router.post("/recognize-object", response_model=RecognitionResponse)
async def recognize_object(image: UploadFile = File(...)) -> RecognitionResponse:
    image_bytes = await image.read()
    if len(image_bytes) > MAX_IMAGE_BYTES:
        raise HTTPException(status_code=413, detail="Image too large")
    if not image_bytes:
        raise HTTPException(status_code=400, detail="No image received")

    try:
        object_name, category, confidence = await gemini_vision.identify_object(
            image_bytes, mime_type=image.content_type or "image/jpeg"
        )
    except RuntimeError as exc:
        logger.error("Recognition failed: %s", exc)
        raise HTTPException(
            status_code=502, detail="We couldn't identify that object. Try another picture!"
        ) from exc

    return RecognitionResponse(object=object_name, category=category, confidence=confidence)
