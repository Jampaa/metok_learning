# Architecture

## Principle

```
AI DISCOVERS       -> Gemini Vision returns a plain English object name
                       + category only
MONLAM DICTIONARY  -> Monlam's real English-Tibetan dictionary supplies the
TEACHES               Tibetan word (with an LLM sense-check when the
                       dictionary itself is ambiguous — see below)
MONLAM SPEAKS       -> Audio is generated once via Monlam and stored in
                       Firebase Storage; the app only ever plays back that URL
CACHE REMEMBERS     -> Firestore caches each discovered word (text, audio,
                       photo, sentences) so it's never re-looked-up
GAME MOTIVATES      -> Stars / badges / missions drive repetition
```

Gemini is never the source of Tibetan vocabulary — it only classifies
photos. Monlam's dictionary is the authoritative source of the Tibetan
word itself; an LLM (also Monlam, model `melong`) is only used to pick
between the dictionary's own candidate entries when they conflict (see
`backend/app/services/monlam_dictionary.py`) — it never invents a
translation from nothing.

## Request flow

```
React (frontend/)
  -> Firebase client SDK directly for: auth, writing progress/learning_events
     (covered by firestore.rules)
  -> FastAPI (backend/) for anything that needs a secret key:
       POST /api/discover            -> the main pipeline (see docs/api.md):
                                         Gemini -> Monlam dictionary -> Monlam
                                         TTS -> Monlam chat -> Firestore cache
       POST /api/recognize-object    -> Gemini Vision only (standalone)
       POST /api/generate-sentences  -> Monlam chat (standalone)
       POST /api/generate-tts        -> Monlam TTS -> Firebase Storage (standalone)
       GET  /api/vocabulary/{id}     -> Firestore read-through
       POST /api/learning-event      -> Firestore (mainly for non-JS clients)
       POST /api/nfc-event           -> Firestore (ESP32 reporting a tap)
```

The frontend never holds a Gemini or Monlam key. `frontend/src/services/api.ts`
and `firebase/client.ts` both degrade gracefully to local-only mocks when
`VITE_API_URL` / Firebase env vars aren't set, so the app is demoable before
any backend is deployed.

## Offline-first demo mode

Every external dependency has a local fallback so the golden demo path
works with zero configuration:

| Dependency | Fallback |
|---|---|
| Backend / `/api/discover` | Random pick from local `frontend/src/data/vocabulary.ts` (`services/api.ts`'s `mockDiscover`) |
| Monlam audio | Browser `SpeechSynthesis` (best-effort; most browsers lack a Tibetan voice) |
| Dynamically discovered words | `progress.discoveredWords` (local cache, `hooks/useProgress.tsx`) — the offline vocabulary file only backs the mock, not real usage |
| Firebase Auth | Progress stored in `localStorage` instead of a signed-in user doc |
| Real NFC (Web NFC / ESP32) | "Simulate Tap" buttons in `features/nfc/NfcScreen.tsx` |

## Child privacy

Camera images are read into memory for the request and discarded by
default — **except** when a photo results in a genuinely new learned word
(a real, confident, dictionary-matched discovery). In that case the photo
is uploaded to Firebase Storage and shown in the app instead of a generic
emoji (`imageUrl` on the vocabulary record), same caching pattern as audio:
stored once per *word*, not per scan — a blurry shot, a low-confidence
guess, or an object outside Monlam's dictionary is never stored anywhere.
See `backend/app/routes/discovery.py`.

This is a deliberate, narrower version of Section 25's original "never
store camera images" rule — the image is tied to the discovered word, not
to the child, and only the single best photo of each word is ever kept
(re-scanning the same object doesn't add more copies).
