# Backend API

FastAPI app at `backend/app/main.py`. Base URL: `VITE_API_URL` (frontend) /
`http://localhost:8000` (local dev). Interactive docs at `/docs` once the
server is running — that page lets you call every endpoint by hand and see
real request/response shapes.

Every route degrades to a clear error rather than a crash when its
dependency isn't configured — see `app/config.py`'s `*_configured`
properties, checked at `GET /api/health`.

---

## Endpoints

### `GET /api/health`
No dependencies. Returns which external services currently have valid
config: `{"status": "ok", "gemini_configured": bool, "monlam_configured": bool, "firebase_configured": bool}`.
Doesn't verify the keys actually work (that only happens when you use
them) — it just checks the env vars are present. Use this first whenever
something else is misbehaving, to rule out a missing/wrong `.env` value.

### `POST /api/discover` — the main endpoint the app actually uses
**File**: `routes/discovery.py`. **Needs**: `GEMINI_API_KEY` always;
`MONLAM_API_KEY` and Firebase for anything beyond a low-confidence result.

Takes one `multipart/form-data` image and does the *entire* golden-demo
pipeline in one call:

1. Sends the image to **Gemini Vision** (`services/gemini_vision.py`) and
   gets back an English object name, a category (`stationery` / `kitchen`
   / `house` / `other`), and a confidence score.
2. If confidence is below the threshold (`RECOGNITION_CONFIDENCE_THRESHOLD`,
   default `0.70`), stops immediately and returns
   `{"status": "low_confidence", ...}` — no Monlam calls spent on a bad photo.
3. Otherwise, checks Firestore's `vocabulary` collection for a doc with
   that word as its ID. If it's already there (either pre-seeded or
   discovered by an earlier scan by anyone), returns it straight away —
   this is why the *second* time anyone scans the same word is instant.
4. If it's genuinely new, calls **Monlam's dictionary** (see
   `services/monlam_dictionary.py` below) to get the correct Tibetan word.
   If Monlam's dictionary has no entry at all, returns
   `{"status": "not_in_dictionary", ...}`.
5. Calls **Monlam TTS** to generate audio for that word, uploads it to
   Firebase Storage (or falls back to an inline base64 audio URI if
   Storage isn't configured — see the TTS section below).
6. Calls **Monlam chat** to draft 1-2 simple example sentences for the word.
7. Writes the finished word (Tibetan text, audio URL, sentences, category)
   into Firestore as the new cache entry, and returns it as
   `{"status": "ok", ...fullWordData}`.

Steps 4-6 are the only "slow" part (~1.5-2s, mostly the LLM sense-check
call) and only ever happen once per word, ever — after that it's just a
Firestore read (step 3), which is fast.

### `POST /api/recognize-object`
**File**: `routes/recognition.py`. **Needs**: `GEMINI_API_KEY`.

The raw Gemini-only half of step 1 above, exposed on its own:
image in, `{"object": "...", "category": "...", "confidence": 0.0-1.0}`
out. It deliberately knows nothing about Tibetan or Firestore — it exists
for any caller that only wants the vision classification (mainly kept
around from before `/api/discover` existed; the frontend now calls
`/api/discover` instead).

### `GET /api/vocabulary/{id}`
**File**: `routes/vocabulary.py`. **Needs**: Firebase.

Plain Firestore read-through: fetches `vocabulary/{id}` and returns it, or
404 if that word hasn't been discovered/seeded yet, or 503 if Firebase
isn't configured on this backend. This is how you can check "did scanning
a pen actually get cached?" from a terminal — see the curl examples in the
root README. The React app doesn't call this itself (it uses the Firebase
JS SDK directly for reads), so this route is really for scripts, `curl`,
or a future admin tool.

### `POST /api/generate-sentences`
**File**: `routes/sentences.py`. **Needs**: `MONLAM_API_KEY`.

Manual/on-demand version of step 6 above: `{english, tibetan, level}` in,
`{"sentences": [{"english", "tibetan"}, ...]}` out, via Monlam chat. You'd
use this to regenerate sentences for a specific word without re-running
the whole discovery pipeline (e.g. if the first batch came out too
complex). `/api/discover` already calls the same underlying service
automatically for every new word — this route doesn't need to be called
as part of the normal app flow.

### `POST /api/generate-tts`
**File**: `routes/tts.py`. **Needs**: `MONLAM_API_KEY` (Firebase optional).

Manual/on-demand version of step 5: `{"text": "<tibetan>"}` in, `{"audioUrl": "..."}`
out. Calls Monlam, then uploads the resulting audio to Firebase Storage
and returns that permanent URL. **If Firebase Storage isn't configured**,
it instead returns the audio inline as a `data:audio/wav;base64,...` URI —
clearly marked in the code as a dev-only shortcut, because it means the
audio gets regenerated (and re-billed) every single call instead of being
saved once. Like `/api/generate-sentences`, `/api/discover` already
handles this automatically for new words — you'd only call this route
directly to regenerate audio for one specific word.

### `POST /api/learning-event`
**File**: `routes/learning.py`. **Needs**: Firebase (optional — logs to
console instead if not configured).

`{userId, vocabularyId, eventType, source, timestamp, meta}` in, written
as a new doc in Firestore's `learning_events` collection. The frontend
mostly writes these straight to Firestore itself via the client SDK; this
route exists for any client that can't do that (see NFC event below).

### `POST /api/nfc-event`
**File**: `routes/learning.py`. **Needs**: Firebase (optional).

For the physical ESP32 toy, which has no JavaScript/Firebase SDK available.
`{tagUid, deviceId}` in — looks up `nfc_tags/{tagUid}` in Firestore to find
which vocabulary word that physical sticker maps to, logs an
`nfc_detected` learning event, and returns `{"vocabularyId": "..."}` so the
device (or whatever's polling on its behalf) knows what was tapped.

---

## Services (`app/services/`) — the actual integration code

Routes are thin; almost all real logic lives here.

- **`gemini_vision.py`** — the only thing that talks to Gemini for images.
  One function, `identify_object()`: sends the photo + a prompt asking for
  a short English noun, a category, and a confidence number, all as JSON.
  Never touches Tibetan.

- **`monlam_dictionary.py`** — the English→Tibetan lookup, and the most
  involved piece of logic in the backend. Naively trusting Monlam's
  `/dictionary/search` top result turned out to be wrong surprisingly
  often (a "pen" search returns the animal-enclosure sense, not the
  writing instrument — verified against the live API). So instead:
  fetches every dictionary entry that exactly matches the English word,
  filters out entries that look like garbled multi-definition dumps, and
  sends whatever's left to Monlam chat to pick the one that actually
  matches the recognized object's category. Only runs for a word the
  first time it's ever seen (`/api/discover` caches the result after).

- **`monlam_chat.py`** — wraps Monlam's `/ai/chat` endpoint (model
  `melong`). Two jobs: drafting simple example sentences for a word, and
  the sense-disambiguation call `monlam_dictionary.py` uses above.

- **`monlam_tts.py`** — text-to-speech. Sends Tibetan text to Monlam's
  streaming TTS endpoint and gets back raw WAV audio bytes.

- **`firebase.py`** — Firebase Admin SDK wrapper: a Firestore client
  getter, and `upload_audio()` which pushes bytes to Storage and returns a
  public URL. Every function here returns `None`/no-ops gracefully if
  `FIREBASE_*` env vars aren't set, rather than throwing.

---

## `backend/scripts/seed_firestore.py` — not an endpoint, but worth knowing about

A one-off script (`python -m scripts.seed_firestore`), not part of the
running API. Pre-writes 4 manually-verified words (pen, book, paper,
table) into Firestore so they resolve instantly and correctly even before
anyone scans them live, and deletes old placeholder docs from an earlier
version of this project that hand-curated a vocabulary list — those would
otherwise sit in Firestore's cache and permanently block real dynamic
lookups for those specific words. Also writes the 3 developer-defined hunt
missions (stationery/kitchen/house) into Firestore for consistency, though
the frontend currently reads mission definitions from its own
`frontend/src/data/missions.ts`, not Firestore.
