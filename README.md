# Tashi's Tibetan Adventure

A mobile-first PWA that teaches kids Tibetan vocabulary through camera-based
object discovery, Tibetan audio, Uchen tracing, simple sentences, and
game-like exploration (Explorer mode, Treasure Hunt, NFC physical toys).

Core loop: **SEE → IDENTIFY → LEARN THE WORD → HEAR IT → TRACE IT → USE IT
IN A SENTENCE → PLAY → REPEAT**.

Architecture principle (see `docs/architecture.md`): **AI discovers,
database teaches, Monlam speaks, game motivates.** Gemini only classifies
photos and drafts sentences for review — it is never the source of truth
for Tibetan vocabulary, and it never generates audio.

## Status

Phase 1-11 MVP shell is built and running:

- Mobile-first React/TS/Vite/Tailwind PWA with the full golden-demo flow:
  Explorer → camera recognition (mocked until Gemini is wired) → word card
  → audio (mocked until Monlam is wired) → Uchen tracing → sentence quiz →
  Treasure Hunt → rewards → NFC (with a "Simulate Tap" web fallback) →
  Profile/progress.
- FastAPI backend scaffolded with real Gemini Vision / Gemini LLM
  integration code and a Monlam TTS service interface — both need real API
  keys to actually call out (see below).
- Firestore/Storage security rules drafted.
- ESP32 NFC toy reference firmware (untested on real hardware — see
  `docs/hardware.md`).

**Important — vocabulary honesty:** only `pen` (`སྨྱུ་གུ`), `book` (`དེབ`),
`paper` (`ཤོག་བུ`), and `table` (`ཅོག་ཙེ`) have translations in this repo.
Everything else in `frontend/src/data/vocabulary.ts` is marked
`tibetan: "TODO_VERIFY"` and renders as "translation pending review" in the
UI rather than a fabricated word. Get the rest verified by a fluent speaker
or the Monlam dictionary before expanding the vocabulary set — this project
explicitly refuses to auto-translate or invent Tibetan (Section 44 rule).

## Repo layout

```
frontend/   React + TypeScript + Vite + Tailwind PWA
backend/    FastAPI (Gemini, Monlam, Firebase Admin)
firebase/   firestore.rules, storage.rules, firebase.json
hardware/   ESP32 + PN532 NFC toy firmware
assets/     characters, objects, backgrounds, stickers, icons, audio (placeholders)
docs/       architecture, database, api, design-system, game-design, hardware
```

## Run it right now (zero config)

The app runs fully standalone with mocked recognition/audio/progress —
useful for iterating on UI/game design before any keys exist.

```bash
cd frontend
npm install
npm run dev
```

Open the printed localhost URL on your phone (same Wi-Fi) or in a mobile
device emulation in your browser's dev tools — this app is mobile-first.

To also run the backend locally (still works with zero keys — recognition
just returns `RuntimeError`s until `GEMINI_API_KEY` is set):

```bash
cd backend
python3.12 -m venv .venv   # 3.12/3.13 — pydantic-core has no 3.14 wheels yet
source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
uvicorn app.main:app --reload
```

Then point the frontend at it: `frontend/.env` with
`VITE_API_URL=http://localhost:8000`.

## Getting each API key

### Gemini (image recognition + sentence drafts)

1. Go to **https://aistudio.google.com/apikey** and sign in with a Google
   account.
2. Click **Create API key** (a free tier with rate limits is enough for a
   hackathon demo).
3. Put it in `backend/.env` as `GEMINI_API_KEY=...`.

No approval process — this is the one key you can get in under a minute.

### Firebase (auth, Firestore, Storage, Hosting)

1. Go to **https://console.firebase.google.com**, create a project.
2. **Build → Authentication → Get started → Sign-in method → Anonymous →
   Enable.**
3. **Build → Firestore Database → Create database** (production mode —
   the rules in `firebase/firestore.rules` lock it down).
4. **Build → Storage → Get started.**
5. **Project settings → General → Your apps → Add app → Web** — copy the
   resulting config object's values into `frontend/.env` as the
   `VITE_FIREBASE_*` vars.
6. **Project settings → Service accounts → Generate new private key** —
   downloads a JSON file. Map its fields into `backend/.env`:
   `FIREBASE_PROJECT_ID` = `project_id`, `FIREBASE_CLIENT_EMAIL` =
   `client_email`, `FIREBASE_PRIVATE_KEY` = `private_key` (keep the `\n`
   escapes literal, the backend un-escapes them).
7. Deploy rules once the Firebase CLI is set up:
   `cd firebase && firebase deploy --only firestore:rules,storage`.

### Monlam TTS (Tibetan audio)

Confirmed against **https://api-v1.monlamai.studio/docs**. Auth is an
`X-API-Key` header (not Bearer). Put your key in `backend/.env` as
`MONLAM_API_KEY=...` — `MONLAM_API_URL` and `MONLAM_VOICE_NAME` already
default to the right values (the streaming endpoint, `lhasa_female` voice;
other options are `lhasa_male`, `amdo_female`, `amdo_male`, `kham_female`,
`kham_male`).

**Audio storage**: the intended path (Section 14) is generate once via
Monlam → upload to Firebase Storage → save the URL → the app only ever
plays that stored file afterward, never re-calling Monlam per "Listen" tap.
That upload step needs Firebase Storage configured (see above). **Until
then**, `POST /api/generate-tts` falls back to returning the audio inline
as a `data:audio/wav;base64,...` URI so you can hear it immediately — this
is clearly marked as a dev-only shortcut in `routes/tts.py` because it
re-calls Monlam on every request instead of reusing a stored file. Set up
Firebase Storage before relying on this for real usage.

## Deployment

- **Frontend** → Firebase Hosting: `cd frontend && npm run build && cd
  ../firebase && firebase deploy --only hosting`.
- **Backend** → Render or Google Cloud Run, using `backend/Dockerfile`. Set
  the same env vars as `backend/.env` in the platform's secret manager —
  never commit a real `.env`.

## Hackathon priorities (see project spec)

Golden demo path: Camera → Gemini → object name → Firestore lookup →
Tibetan word → audio → tracing → sentence → Treasure Hunt reward → NFC tap
→ ESP32 speaker → learning event logged. Build/verify that path before
adding anything else. See `docs/game-design.md` for mode design and
`docs/hardware.md` for why the NFC/ESP32 step should always have the web
"Simulate Tap" fallback ready on demo day.
