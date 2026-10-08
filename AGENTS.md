# Agent Notes

This repo is being rebuilt as **Yonten**, a Flutter + Firebase app. The spec
is in `docs/yonten-spec.md`, and the work is split into phases in
`docs/yonten-phases.md`. `DECISIONS.md` records every place where we
deliberately depart from the spec. During the rebuild, two apps live side by
side:

| Path | What | Status |
|---|---|---|
| `yonten/` | Flutter app (web PWA now, iOS/Android later) | Active |
| `functions/` | Python Cloud Functions (Gemini, Monlam) | Active, from Phase 6 |
| `frontend/`, `backend/` | Legacy React + FastAPI app | Frozen; moves to `legacy/` in Phase 10 |

Before changing anything, read:

- `docs/architecture.md`: the AI-discovers / dictionary-teaches /
  Monlam-speaks principle. Never wire Gemini directly to a "speak this
  word" action, and never let a component invent a Tibetan translation.
- `docs/database.md`: the legacy Firestore shape. Yonten's shape is in
  spec §7, as amended by `DECISIONS.md`.
- `docs/yonten-spec.md` §4: Yonten's design tokens live only in
  `yonten/lib/theme/`. Don't hardcode colors or fonts in widgets.

## Workflow

- Work one phase at a time. Tick the phase's checkboxes in
  `docs/yonten-phases.md` when it's done.
- The repo owner makes all git commits. Agents don't commit.

## Non-negotiables

- Only `verified: true` vocabulary items may show a Tibetan string to a
  user. Verified means a Monlam dictionary match, an alphabet letter, or a
  fluent speaker's confirmation (DECISIONS.md D36). Don't "fill in"
  translations yourself.
- Gemini only identifies objects (English name, confidence, kid_safe).
  Tibetan comes from the vocab catalog or Monlam's dictionary, and
  unverified Tibetan never leaves the server (DECISIONS.md D36).
- Every photo the child takes is kept, and a word's flash card shows only
  the child's own photo of it, never drawn art (D37).
- Gemini-drafted sentences are never shown to a child until a human sets
  `approved: true` in Firestore.
- No Gemini, Monlam or Firebase Admin secret ever goes in `yonten/` or
  `frontend/`. Secrets live only in Cloud Functions secrets or backend env
  vars.
- Every feature that depends on an unconfigured external service
  (Firebase, Functions, Monlam, camera) must degrade to a working local
  fallback rather than break the screen.
- Small, incremental changes. The app must always build before a change
  counts as done:
  - `flutter analyze && flutter test && flutter build web` in `yonten/`
  - `venv/bin/python -m pytest -q tests` in `functions/`
  - `npm run build` in `frontend/`, until the cutover
