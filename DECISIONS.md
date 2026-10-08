# Decisions

Assumptions and choices made while building Yonten (`docs/yonten-spec.md`,
phases in `docs/yonten-phases.md`). Add new entries at the bottom, and say
which phase each one came from.

## Phase 0

**D1. Layout.** The Flutter app lives in `yonten/` and the Python Cloud
Functions in `functions/`. `firebase.json` stays at the repo root. The legacy
React app (`frontend/`) and FastAPI server (`backend/`) stay as they are until
the Phase 10 cutover, then move to `legacy/`. Until then, Hosting keeps
serving `frontend/dist`.

**D2. Source of Tibetan words.** Spec §8.1 asks Gemini to return Tibetan; we
don't do that. Gemini returns only `{english, confidence, kid_safe}`. The
Tibetan word comes from the `vocab` catalog first, then from the Monlam
dictionary (ported from `backend/app/services/monlam_dictionary.py`). This
keeps the existing rule in `docs/architecture.md`: AI discovers, the
dictionary teaches, Monlam speaks.

**D3. Verified flag.** The `vocab` docs use the existing `verified: bool`
field, not the spec's `reviewed`. A child only sees Tibetan from a
`verified: true` entry. An unverified find shows the English word and
Yonten's line "Let's learn this one soon!", and the entry waits for a
teacher to check it.

**D4. Seed words.** ཀུ་ཤུ (apple), སྒོ (door), ཆུ (water), ཉི་མ (sun) and the
Unit 1 letters are seeded as `verified: false`. They switch to
`verified: true` only after a fluent speaker confirms them (Phase 6).

**D5. Firebase project.** Reuse `tashi-learn`. It needs the Blaze plan for
Cloud Functions and the default Storage bucket, with a $5 budget alert. The
owner does the upgrade in the console.

**D6. TTS.** Port the working `backend/app/services/monlam_tts.py` behind a
`TtsProvider` interface, with a stub provider for local and emulator runs.

**D7. Gemini model.** The model name is one config value (`GEMINI_MODEL`).
Check the current Flash model ID on Google's model list before Phase 6 sets
it.

**D8. Out of MVP scope.** Letter tracing, the sentence quiz and the NFC toy
aren't in the spec. They're parked in Phase 12.

**D9. App identity.** The Flutter package name is `yonten`. The org /
bundle prefix is `org.gtpn` (bundle id `org.gtpn.yonten`), which can be
changed before the first store upload (Phase 11).

**D10. Platforms.** `flutter create` targets web, iOS and Android only. No
desktop targets.

**D11. iOS Firebase config deferred.** `flutterfire configure` registered
the web and Android apps only. The iOS step needs the `xcodeproj` Ruby gem,
which isn't installed. Run `flutterfire configure` again with `ios` in
Phase 11 (bundle id `org.gtpn.yonten`).

**D12. Material widgets, no Material icons.** `MaterialApp` and the layout
widgets are fine to use. `cupertino_icons` is removed, and no `Icons.*`
glyphs are used (spec §4 bans default icon sets). Icons come from
`InkIcons` and the image pack.
