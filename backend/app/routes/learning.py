"""POST /api/learning-event, POST /api/nfc-event

Writes learning events to Firestore when configured; otherwise just logs,
so local dev without Firebase never breaks. The frontend already writes
most events straight to Firestore via the client SDK — these routes exist
mainly for the ESP32 (which can't use the JS SDK) to report NFC taps.
"""

import logging

from fastapi import APIRouter

from app.models.schemas import LearningEventRequest, NfcEventRequest
from app.services import firebase

logger = logging.getLogger(__name__)
router = APIRouter()


@router.post("/learning-event")
async def learning_event(payload: LearningEventRequest) -> dict:
    db = firebase.get_firestore_client()
    if db is None:
        logger.info("[learning-event] %s", payload.model_dump())
        return {"stored": False}

    db.collection("learning_events").add(payload.model_dump())
    return {"stored": True}


@router.post("/nfc-event")
async def nfc_event(payload: NfcEventRequest) -> dict:
    db = firebase.get_firestore_client()
    if db is None:
        logger.info("[nfc-event] %s", payload.model_dump())
        return {"stored": False, "vocabularyId": None}

    tag_doc = db.collection("nfc_tags").document(payload.tagUid).get()
    vocabulary_id = tag_doc.to_dict().get("vocabularyId") if tag_doc.exists else None
    db.collection("learning_events").add(
        {
            "vocabularyId": vocabulary_id,
            "eventType": "nfc_detected",
            "source": "nfc",
            "deviceId": payload.deviceId,
        }
    )
    return {"stored": True, "vocabularyId": vocabulary_id}
