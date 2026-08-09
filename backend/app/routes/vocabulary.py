"""GET /api/vocabulary/{id}

Thin passthrough to Firestore for cases where a non-browser client (e.g. the
ESP32, or a future admin tool) needs vocabulary without the Firebase SDK.
The React app should keep reading Firestore directly via the client SDK
(Section 30) — this route is not the primary path for the web app.
"""

from fastapi import APIRouter, HTTPException

from app.services import firebase

router = APIRouter()


@router.get("/vocabulary/{vocabulary_id}")
async def get_vocabulary(vocabulary_id: str) -> dict:
    db = firebase.get_firestore_client()
    if db is None:
        raise HTTPException(status_code=503, detail="Firestore is not configured on this backend.")

    doc = db.collection("vocabulary").document(vocabulary_id).get()
    if not doc.exists:
        raise HTTPException(status_code=404, detail="Vocabulary word not found.")
    return doc.to_dict()
