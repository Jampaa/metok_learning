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

## Child privacy (legacy app)

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

## Yonten rebuild (Flutter + Firebase)

The app is moving to Flutter (`yonten/`) and Python Cloud Functions
(`functions/`). See `docs/yonten-phases.md`. The principle above doesn't
change (`DECISIONS.md` D2):

```
Flutter app (yonten/)
  -> Firebase Auth (anonymous first, linked by a parent later)
  -> Firestore (users/{uid}/**, read-only vocab + curriculum), offline persistence
  -> Hive (profile snapshot, settings, audio paths) for instant cold start
  -> callable identify_object (App Check)
       Gemini Flash   -> English name + confidence + kid_safe only
       vocab catalog  -> verified Tibetan, if we already have it
       Monlam dict    -> candidate Tibetan for new words (verified: false)
       get_word_audio -> Monlam TTS -> Storage audio/{wordId}.mp3
```

The legacy request flow above stays live until the Phase 10 cutover.

### Yonten: photos (DECISIONS.md D37)

At the owner's request, Yonten keeps every photo a child takes. Each one
is saved on the device, uploaded to `users/{uid}/photos/{photoId}.jpg`
(owner-only Storage rule, images up to 2 MB), and recorded in
`users/{uid}/photos/{photoId}`. A word's flash card shows only the
child's own photo of it. Gemini sees the photo only for the
`identify_object` call and the function never stores it. Before store
release (Phase 11b) the parent area needs a delete control, and the
privacy policy must disclose photo storage.
