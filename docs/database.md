# Firestore Schema

Mirrors `frontend/src/types/index.ts`. The frontend's local
`src/data/vocabulary.ts` / `missions.ts` are the offline-demo stand-ins for
`vocabulary/` and `missions/` below — keep their shape in sync.

## `vocabulary/{id}`

```json
{
  "english": "pen",
  "tibetan": "སྨྱུ་གུ",
  "verified": true,
  "category": "stationery",
  "difficulty": 1,
  "imageUrl": "",
  "audioUrl": "",
  "uchenDataUrl": "",
  "sentences": ["pen_01"]
}
```

`verified: false` + `tibetan: "TODO_VERIFY"` for anything not yet confirmed
by a fluent speaker — **never** flip this without doing that (Section 44).
Read-only for clients; written only via the Admin SDK.

## `sentences/{id}`

```json
{ "vocabularyId": "pen", "english": "...", "tibetan": "...", "difficulty": 1, "approved": false, "audioUrl": "" }
```

`approved` gates whether a sentence is ever shown to a child — Gemini
drafts, a human flips this to `true`.

## `missions/{id}`

```json
{ "title": "Find the Writing Tools", "description": "...", "requiredVocabulary": ["pen","pencil","notebook"], "reward": 50 }
```

## `nfc_tags/{tagUid}`

Keyed by the **physical tag's UID**, not the user:

```json
{ "vocabularyId": "pen", "deviceId": "toy01" }
```

## `users/{uid}`, `progress/{uid}`

```json
{ "displayName": "", "createdAt": "", "stars": 120, "level": 2, "badges": [], "unlockedAreas": ["school"] }
```

## `learning_events/{id}`

```json
{ "userId": "...", "vocabularyId": "pen", "eventType": "audio_played", "source": "web", "timestamp": 0 }
```

`eventType` ∈ `object_identified | word_viewed | audio_played |
trace_started | trace_completed | sentence_viewed | sentence_answered |
mission_started | mission_completed | nfc_detected | nfc_audio_played`.

Engagement counters only (heard/traced/found/nfc/quiz) — this is **not** a
language-proficiency assessment (Section 23).
