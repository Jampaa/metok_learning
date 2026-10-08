"""Upload the map curriculum to Firestore `curriculum/{chapterId}` (spec §7).

The source of truth is yonten/assets/data/curriculum.json, the same file the
app bundles as its offline fallback, so the two never drift apart.

Usage (from the repo root):

  # Local emulator (start it with `firebase emulators:start`):
  functions/venv/bin/python -I functions/seed_curriculum.py --emulator

  # Production. Needs Admin credentials, e.g. a service-account key:
  GOOGLE_APPLICATION_CREDENTIALS=/path/key.json \
      functions/venv/bin/python -I functions/seed_curriculum.py --project tashi-learn

Re-running is safe: each chapter doc is overwritten with the file's content.
Chapters that are no longer in the file are left alone (use --prune to
delete them).
"""

from __future__ import annotations

import argparse
import json
import os
from pathlib import Path

import firebase_admin
import google.auth.credentials
from firebase_admin import credentials, firestore

REPO = Path(__file__).resolve().parent.parent
CURRICULUM_JSON = REPO / "yonten" / "assets" / "data" / "curriculum.json"
EMULATOR_HOST = "127.0.0.1:8085"
LESSON_TYPES = {"letter", "word", "scan", "chest"}


def load_chapters(path: Path) -> list[dict]:
    data = json.loads(path.read_text(encoding="utf-8"))
    chapters = data["chapters"]
    for c in chapters:
        validate(c)
    return chapters


def validate(chapter: dict) -> None:
    cid = chapter["id"]
    for key in ("order", "title", "titleTibetan", "workbookChapter", "workbookPages", "lessons"):
        if key not in chapter:
            raise ValueError(f"{cid}: missing {key}")
    ids = set()
    for i, lesson in enumerate(chapter["lessons"], start=1):
        if lesson["type"] not in LESSON_TYPES:
            raise ValueError(f"{cid}/{lesson['id']}: bad type {lesson['type']}")
        if lesson["order"] != i:
            raise ValueError(f"{cid}/{lesson['id']}: order {lesson['order']} should be {i}")
        if lesson["id"] in ids:
            raise ValueError(f"{cid}: duplicate lesson id {lesson['id']}")
        if lesson["type"] == "chest" and not lesson.get("rewardStickerId"):
            raise ValueError(f"{cid}/{lesson['id']}: chest needs rewardStickerId")
        ids.add(lesson["id"])


class EmulatorCredential(credentials.Base):
    """No-auth credential; the emulator accepts anything."""

    def get_credential(self):
        return google.auth.credentials.AnonymousCredentials()


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", default="tashi-learn")
    parser.add_argument("--emulator", action="store_true",
                        help=f"write to the Firestore emulator at {EMULATOR_HOST}")
    parser.add_argument("--prune", action="store_true",
                        help="delete chapters that are not in the file")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    chapters = load_chapters(CURRICULUM_JSON)
    print(f"{len(chapters)} chapter(s) in {CURRICULUM_JSON.relative_to(REPO)}")
    if args.dry_run:
        for c in chapters:
            print(f"  {c['id']}: {c['title']} ({len(c['lessons'])} lessons)")
        return

    if args.emulator:
        os.environ["FIRESTORE_EMULATOR_HOST"] = EMULATOR_HOST
        app = firebase_admin.initialize_app(
            EmulatorCredential(), {"projectId": args.project})
    else:
        app = firebase_admin.initialize_app(options={"projectId": args.project})
    db = firestore.client(app)

    target = "emulator" if args.emulator else f"project {args.project}"
    col = db.collection("curriculum")
    for c in chapters:
        doc = {k: v for k, v in c.items() if k != "id"}
        col.document(c["id"]).set(doc)
        print(f"  wrote curriculum/{c['id']} to {target}")

    if args.prune:
        keep = {c["id"] for c in chapters}
        for snap in col.stream():
            if snap.id not in keep:
                snap.reference.delete()
                print(f"  pruned curriculum/{snap.id}")


if __name__ == "__main__":
    main()
