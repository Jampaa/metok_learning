"""Seeds a handful of pre-verified words + removes stale placeholder docs.

Vocabulary is no longer curated ahead of time — see routes/discovery.py,
which discovers + caches words dynamically via Monlam's dictionary the
first time each one is scanned. This script only pre-warms the 4 words
that were manually verified before the pivot (guarantees the golden-demo
word "pen" always resolves instantly and correctly), and deletes the old
TODO_VERIFY placeholder docs from the previous curated-vocabulary phase —
those would otherwise be served as false cache hits, permanently blocking
real dynamic lookups for pencil/notebook/ruler/eraser/bag/chair.

Missions stay developer-authored (see frontend/src/data/missions.ts, the
actual source of truth the app reads) — mirrored here only for admin-tool
consistency, not currently read by the frontend.

Safe to re-run.

Usage:
    cd backend && source .venv/bin/activate
    python -m scripts.seed_firestore
"""

import asyncio
import logging

from app.services import firebase, monlam_chat

logger = logging.getLogger(__name__)

VOCABULARY = [
    {"id": "pen", "english": "pen", "tibetan": "སྨྱུ་གུ", "verified": True, "category": "stationery", "difficulty": 1, "emoji": "✏️"},
    {"id": "book", "english": "book", "tibetan": "དེབ", "verified": True, "category": "stationery", "difficulty": 1, "emoji": "✏️"},
    {"id": "paper", "english": "paper", "tibetan": "ཤོག་བུ", "verified": True, "category": "stationery", "difficulty": 1, "emoji": "✏️"},
    {"id": "table", "english": "table", "tibetan": "ཅོག་ཙེ", "verified": True, "category": "house", "difficulty": 2, "emoji": "🛋️"},
]

# From the old curated-vocabulary phase — placeholder docs that must not
# shadow real dynamic lookups now that discovery.py trusts any cache hit.
STALE_PLACEHOLDER_IDS = ["pencil", "notebook", "ruler", "eraser", "bag", "chair"]

MISSIONS = [
    {
        "id": "stationery-hunt",
        "title": "Find 3 Stationery Items",
        "description": "Pens, books, paper — school supplies of any kind!",
        "targetCategory": "stationery",
        "requiredCount": 3,
        "reward": 50,
        "badge": "Scribe Badge",
    },
    {
        "id": "kitchen-hunt",
        "title": "Find 3 Kitchen Items",
        "description": "Anything you'd find in the kitchen!",
        "targetCategory": "kitchen",
        "requiredCount": 3,
        "reward": 50,
        "badge": "Kitchen Badge",
    },
    {
        "id": "house-hunt",
        "title": "Find 3 House Items",
        "description": "Furniture and things around the house!",
        "targetCategory": "house",
        "requiredCount": 3,
        "reward": 40,
        "badge": "House Badge",
    },
]


async def _sentences_for(item: dict) -> list[dict]:
    try:
        return await monlam_chat.generate_draft_sentences(item["english"], item["tibetan"])
    except monlam_chat.MonlamChatError as exc:
        logger.warning("Sentence generation failed for '%s': %s", item["english"], exc)
        return []


def main() -> None:
    db = firebase.get_firestore_client()
    if db is None:
        raise SystemExit("Firestore isn't configured — check FIREBASE_* in backend/.env")

    for item in VOCABULARY:
        doc_id = item["id"]
        sentences = asyncio.run(_sentences_for(item))
        db.collection("vocabulary").document(doc_id).set({**item, "sentences": sentences, "source": "manual_seed"})
        print(f"vocabulary/{doc_id}: {item['tibetan']} ({len(sentences)} sentences)")

    for doc_id in STALE_PLACEHOLDER_IDS:
        db.collection("vocabulary").document(doc_id).delete()
        print(f"vocabulary/{doc_id}: deleted (stale placeholder)")

    for mission in MISSIONS:
        doc_id = mission["id"]
        db.collection("missions").document(doc_id).set(mission)
        print(f"missions/{doc_id}: {mission['title']}")

    print(f"\nSeeded {len(VOCABULARY)} words, removed {len(STALE_PLACEHOLDER_IDS)} placeholders, wrote {len(MISSIONS)} missions.")


if __name__ == "__main__":
    main()
