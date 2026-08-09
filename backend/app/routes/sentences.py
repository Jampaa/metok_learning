"""POST /api/generate-sentences

Manual/standalone sentence (re)generation via Monlam chat — see
services/monlam_chat.py. The main discovery flow (routes/discovery.py)
already generates and caches sentences automatically for each new word;
this route exists for regenerating a specific word's sentences on demand.
"""

import logging

from fastapi import APIRouter, HTTPException

from app.models.schemas import GenerateSentencesRequest, GenerateSentencesResponse
from app.services import monlam_chat

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/generate-sentences", response_model=GenerateSentencesResponse)
async def generate_sentences(payload: GenerateSentencesRequest) -> GenerateSentencesResponse:
    try:
        sentences = await monlam_chat.generate_draft_sentences(
            payload.english, payload.tibetan, payload.level
        )
    except monlam_chat.MonlamChatError as exc:
        logger.error("Sentence generation failed: %s", exc)
        raise HTTPException(status_code=502, detail="Could not generate sentences right now.") from exc

    return GenerateSentencesResponse(sentences=sentences)
