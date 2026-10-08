"""Seed the `vocab` catalog and pre-generate audio (spec §8.4).

Source: yonten/assets/data/vocab_seed.json (the starter words from the spec
plus the Unit 1 letters). The same file is the app's offline fallback.

Verification (DECISIONS.md D36):
  - Letters are the alphabet itself, not translations, so they're verified.
  - A word is verified only if Monlam's dictionary gives the same Tibetan as
    the seed file. Otherwise it stays unverified, with the dictionary's
    answer saved as `dictionaryTibetan` for a teacher to compare.
  - Audio is generated for verified entries only.

Usage (from the repo root):
  functions/venv/bin/python -I functions/seed_vocab.py --emulator
  GOOGLE_APPLICATION_CREDENTIALS=key.json \
      functions/venv/bin/python -I functions/seed_vocab.py --project tashi-learn

MONLAM_API_KEY is read from the environment, or from functions/.secret.local.
Without it, entries are written and nothing is verified against the dictionary.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path

import firebase_admin
import google.auth.credentials
from firebase_admin import credentials, firestore, storage

sys.path.insert(0, str(Path(__file__).resolve().parent))
from audio_store import ensure_audio  # noqa: E402
from monlam import MonlamClient, MonlamTts, StubTts  # noqa: E402

REPO = Path(__file__).resolve().parent.parent
SEED = REPO / "yonten" / "assets" / "data" / "vocab_seed.json"
SECRETS = Path(__file__).resolve().parent / ".secret.local"


class EmulatorCredential(credentials.Base):
    def get_credential(self):
        return google.auth.credentials.AnonymousCredentials()


def monlam_key() -> str:
    key = os.environ.get("MONLAM_API_KEY", "")
    if not key and SECRETS.exists():
        for line in SECRETS.read_text().splitlines():
            if line.startswith("MONLAM_API_KEY="):
                key = line.split("=", 1)[1].strip().strip('"')
    return key


def same_word(a: str, b: str) -> bool:
    strip = lambda s: (s or "").strip().rstrip("་།").strip()  # noqa: E731
    return bool(a) and strip(a) == strip(b)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--project", default="tashi-learn")
    parser.add_argument("--bucket", default="tashi-learn.firebasestorage.app")
    parser.add_argument("--emulator", action="store_true")
    parser.add_argument("--no-audio", action="store_true")
    args = parser.parse_args()

    if args.emulator:
        os.environ["FIRESTORE_EMULATOR_HOST"] = "127.0.0.1:8085"
        os.environ["FIREBASE_STORAGE_EMULATOR_HOST"] = "127.0.0.1:9199"
        os.environ["STORAGE_EMULATOR_HOST"] = "http://127.0.0.1:9199"
        cred = EmulatorCredential()
    else:
        cred = None
    app = firebase_admin.initialize_app(cred, {"projectId": args.project, "storageBucket": args.bucket})
    db = firestore.client(app)
    bucket = storage.bucket(app=app)

    key = monlam_key()
    monlam = MonlamClient(key) if key else None
    tts = MonlamTts(key) if key else StubTts()
    print(f"Monlam: {'on' if monlam else 'off (no key, stub audio)'}")

    entries = json.loads(SEED.read_text(encoding="utf-8"))["vocab"]
    for e in entries:
        wid = e["id"]
        doc = {k: v for k, v in e.items() if k not in ("id", "verified")}
        if wid.startswith("letter-"):
            doc.update(verified=True, source="alphabet")
        elif monlam:
            try:
                found = monlam.lookup(e["english"], "other")
            except Exception as exc:  # noqa: BLE001 - e.g. Monlam quota expired
                print(f"  {wid}: dictionary unavailable ({exc}); left unverified")
                found = None
            if found is not None:
                doc["dictionaryTibetan"] = found
            agrees = same_word(found or "", e["tibetan"])
            doc.update(verified=agrees, source="monlam_dictionary" if agrees else "seed")
        else:
            doc.update(verified=False, source="seed")
        db.collection("vocab").document(wid).set(doc, merge=True)
        note = ""
        if doc["verified"] and doc.get("tibetan") and not args.no_audio:
            try:
                ensure_audio(db, bucket, wid, doc["tibetan"], tts)
                note = " + audio"
            except Exception as exc:  # noqa: BLE001 - audio can be generated later
                note = f" (no audio yet: {str(exc)[:60]})"
        mismatch = ""
        if "dictionaryTibetan" in doc and not doc["verified"]:
            mismatch = f"  (dictionary says {doc['dictionaryTibetan'] or 'nothing'})"
        print(f"  {wid:12s} {doc['tibetan']:8s} verified={doc['verified']}{note}{mismatch}")


if __name__ == "__main__":
    main()
