# Agent Notes

This repo implements `PROJECT_SPEC.md`-equivalent rules baked into
`docs/`. Before changing anything, read:

- `docs/architecture.md` — the AI-discovers/database-teaches/Monlam-speaks
  principle. Never wire Gemini directly to a "speak this word" action, and
  never let a component invent a Tibetan translation.
- `docs/database.md` — Firestore shape. `frontend/src/data/vocabulary.ts` is
  the offline mirror; keep both in sync if you change one.
- `docs/api.md` — backend contract.
- `docs/design-system.md` — design tokens live in `frontend/src/index.css`
  only. Don't hardcode colors/fonts in components.

## Non-negotiables

- Only `verified: true` vocabulary items may show a Tibetan string to a
  user. Everything else must stay `tibetan: "TODO_VERIFY"` until a fluent
  speaker confirms it — don't "fill in" translations yourself.
- Gemini-drafted sentences are never shown to a child until a human sets
  `approved: true` in Firestore.
- No Gemini/Monlam/Firebase Admin secret ever goes in `frontend/`. Backend
  env vars only.
- Every feature that depends on an unconfigured external service
  (Firebase, backend, Monlam, real NFC) must degrade to a working local
  fallback rather than break the screen — see the fallback table in
  `docs/architecture.md`.
- Small, incremental changes. This app must always build
  (`npm run build` in `frontend/`, `python -c "from app.main import app"`
  in `backend/` with its venv active) before you consider a change done.
