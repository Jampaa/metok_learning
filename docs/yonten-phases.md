# Yonten rebuild: phase plan

The full spec is in [`yonten-spec.md`](yonten-spec.md). Section numbers below
(§4, §6, ...) refer to that file. This document splits the spec into phases you
can run one at a time, then extends it with a runway for the native iOS and
Android apps.

## How to run a phase

- Do one phase per session or branch. Start with: "Execute Phase N of
  `docs/yonten-phases.md`."
- Every phase ends in a working app. `flutter build web` and
  `flutter analyze` pass, and the functions import cleanly.
- Every phase ends with a commit and the phase's checkbox ticked here.
- Anything that depends on a service you haven't configured yet must fall
  back to local data and never break the screen (same rule as `AGENTS.md`).
- New assumptions go in `DECISIONS.md` in the same commit.

## Decisions made up front

These settle the places where the spec and this repo's existing rules
disagree. Each one gets logged in `DECISIONS.md` in Phase 0.

| # | Topic | Decision | Why |
|---|---|---|---|
| D1 | Where the app lives | New Flutter app in `yonten/`, Python Cloud Functions in `functions/`, `firebase.json` at the repo root. Legacy `frontend/` and `backend/` stay in place until the Phase 10 cutover, then move to `legacy/`. | The live demo keeps working while the rebuild happens. |
| D2 | Source of Tibetan words | **Keep the repo rule.** Gemini returns only the English name, confidence and kid-safe flag. Tibetan comes from the `vocab` catalog, then the Monlam dictionary (port `backend/app/services/monlam_dictionary.py`). §8.1 asks Gemini for Tibetan; we won't do that. | `docs/architecture.md` and `AGENTS.md`: Gemini never invents Tibetan. |
| D3 | Verified flag | Use the existing `verified: bool` (not `reviewed`). Only `verified: true` Tibetan is shown to a child. Unverified finds show the English word, Yonten says "Let's learn this one soon!", and the find is queued for a teacher to check. | Non-negotiable in `AGENTS.md`. |
| D4 | Seed words | ཀུ་ཤུ, སྒོ, ཆུ, ཉི་མ and the Unit 1 letters are seeded with `verified: false` until a fluent speaker (the author's mother) signs them off in Phase 6. | Same rule. |
| D5 | Firebase project | Reuse `tashi-learn` and upgrade it to Blaze with a $5 budget alert. | We already have Hosting, rules and Monlam audio there. |
| D6 | Monlam TTS | Port the working `backend/app/services/monlam_tts.py` behind a `TtsProvider` interface. Keep a stub provider for local and emulator runs. | We already have Monlam access, so no stub-only phase is needed. |
| D7 | Gemini model | Read the model name from one config value (`GEMINI_MODEL`). Check the current Flash model ID on Google's model list in Phase 6 before setting it. | The model ID in §1 can't be confirmed from here. |
| D8 | Legacy features | Tracing, sentence quiz and NFC/hardware aren't in the MVP. They move to Phase 12. | Keeps the 10-day scope. |

---

## Phase 0: Foundations (half a day)

**Goal:** a clean starting point for the rebuild.

- [ ] **(Owner)** Commit or stash the current uncommitted changes (`firebase.json` move, `client.ts`, `Welcome.tsx`).
- [x] Install Flutter stable (it isn't on this machine yet), run `flutter doctor`, and install the FlutterFire CLI.
- [ ] **(Owner: needs the Firebase console)** Upgrade `tashi-learn` to Blaze, set the $5 budget alert, and turn on Auth (Anonymous, Google, Apple, Email), Firestore, Storage and App Check.
- [x] Run `flutter create yonten` (web, iOS and Android platforms; org id decided and logged), then `flutterfire configure`.
- [x] Add the packages from §2.
- [x] Create `DECISIONS.md` with D1–D8.
- [x] Update `AGENTS.md` and `docs/architecture.md` to describe the new layout. Keep the old rules.

**Done when:** the Flutter counter app builds for web and connects to Firebase (anonymous sign-in works). The legacy app still builds.

## Phase 1: Assets and design system (§3, §4) — spec day 1

**Goal:** every visual building block exists before any screen does.

- [x] Copy the image pack into `yonten/assets/raw/` (input only, git-ignored or LFS).
- [x] Write `tools/prep_images.py` (§3, steps 1–7): shared pose crop, avatar crop, peek crop, scene bounding-box crops, lamp split with the flame flood-fill, icons, and the paper-grain tile. Output goes to `assets/images/*.webp`.
- [x] Bundle the Grandstander, Andika and Jomolhari fonts (OFL).
- [x] Create `theme/colors.dart` and `theme/text.dart` with exactly the §4 tokens. Create `theme/motion.dart` as an empty home for durations and curves.
- [x] Build the widgets `ToyButton`, `ToyCard` (70 ms pressed state, constant height), `StickerChip`, `SegmentedProgress` and `PaperGrain` (with the debug toggle).
- [x] Draw the missing art in `InkIcons` (§3 "Missing images"), named so it can be swapped for real files later.
- [x] Build a hidden `/gallery` route that shows every widget and icon.

**Done when:** the gallery renders every token, widget and processed image, and pose frames overlay with no visible jump.

## Phase 2: App shell and Yonten (§5 shell, §6 Yonten rows) — day 2

- [x] `go_router` with the five tabs and the 88 px bottom nav. Center Scan button, active-tile style, 7 px icon hop.
- [x] Streak and words pills on the Map and Backpack screens (static values for now).
- [x] The web layout: a centered 430 px column, reference-px scaling on phones.
- [x] `YontenSprite`: stacks every frame, `precacheImage` at startup, the global blink clock (3.5–6 s), breathing, and the wave sequence.
- [x] Reduced motion: one provider reads `MediaQuery.disableAnimations` and every looping animation listens to it.

**Done when:** all five tabs navigate, Yonten blinks and waves with no flicker, and reduced motion stops every loop.

## Phase 3: Treasure Hunt Map, local data (§5 Map, §6 map rows) — day 3

**Goal:** the hero screen, fully animated, driven by a local curriculum.

- [x] Data models `Chapter`, `Lesson` and `Progress` (§7 shapes), with a `CurriculumRepository` interface and a local implementation seeded with chapter 1.
- [x] Sky band layers, mountain parallax, cloud drift, and the thangka swing with its live text overlay.
- [x] The dirt-path `CustomPainter` (ink stroke, then cream stroke, then golden footsteps).
- [x] Node layout generated per cluster (the winding pattern repeats), with a thangka at the start of each cluster.
- [x] Node states: completed, active (pulse ring and START bubble), locked, and the chest every `chestInterval` nodes (config value).
- [x] Tap behaviors and the 2.8 s sticker toast. The chest opens with confetti, stays open, and grants a sticker (local).
- [x] Prayer flags, chorten, and Yonten beside the active node.

**Done when:** the map matches the design artifact, works offline, and progress can only move forward.

## Phase 4: Auth and data layer (§7) — moved earlier than the spec's plan

**Goal:** real persistence before more screens are built on top of it.

- [x] `AuthService`: anonymous sign-in on first launch.
- [x] Firestore repositories for `users/{uid}`, `words`, `stickers`, `quests` and `curriculum`, plus `vocab` (read-only).
- [x] Firestore persistence on, including web.
- [x] A Hive cache for the profile snapshot, settings and audio paths, so the app opens instantly.
- [x] Riverpod providers switch between the Firestore and local implementations when Firebase isn't configured.
- [x] A forward-only progress transaction (`completeLesson`), and the streak transaction using the child's local date.
- [x] A curriculum seed script for chapter 1, with `workbookChapter` and `workbookPages`.
- [x] First draft of `firestore.rules` and `storage.rules` (§7), tested in the emulator.

- [ ] **(Owner)** Deploy the new rules and seed production: `firebase deploy --only firestore:rules,storage`, then run `seed_curriculum.py` with Admin credentials (`docs/yonten-dev.md`).

**Done when:** the map renders from Firestore, survives a reload, and still renders in airplane mode.

## Phase 5: Scanner UI with a mock vision service (§5 Scanner) — day 4

- [x] Live `camera` preview, falling back to `image_picker`, and to a still image on web without a camera.
- [x] Header, corner brackets, scan line, and the "What's in your kitchen?" sticker.
- [x] The state machine `looking` → `thinking` → `found` | `retry`, with the Yonten pose for each state. No red error states.
- [x] The result card animation, the XP seal stamp, and the celebrate sequence with confetti.
- [x] A `VisionService` interface with a `MockVisionService` that returns seeded vocab.
- [x] Resize the JPEG on the device to at most 1024 px.
- [x] Hook the result into adding the word, XP, streak and quest progress (Phase 4 repos).

**Done when:** a mock scan adds a word to Firestore and the full animation sequence plays.

## Phase 6: Cloud Functions (§8) — days 5–6

**Goal:** real scans with real Tibetan audio. Port from `backend/app/services/`; don't rewrite.

- [x] `functions/` Python 2nd gen, us-central1. Secrets `GEMINI_API_KEY` and `MONLAM_API_KEY` (plus the dictionary key if it's separate). A `GEMINI_MODEL` config value (D7).
- [x] `identify_object` callable with App Check enforced:
  - Gemini returns structured English + confidence + kid_safe.
  - The result is looked up in the `vocab` catalog, then the Monlam dictionary (D2).
  - Return `retry` when confidence is below 0.6 or the object isn't kid-safe.
  - Keep a thumbnail only if the parent allows it.
- [x] `get_word_audio` behind `TtsProvider` (Monlam, plus a stub). Cache the MP3 at `audio/{wordId}.mp3`.
- [x] `functions/seed_vocab.py`: the demo words and Unit 1 letters, generating their audio.
- [ ] **Human step:** the fluent speaker verifies the seed list, then the seed sets `verified: true` (D4).
- [x] `FunctionsVisionService` replaces the mock when configured. `just_audio` playback with offline caching of audio paths.
- [x] Offline scan queue with the message "Yonten will check this when we're back online".

- [x] Every photo kept and shown on the word's card (owner request, D37).
- [ ] **(Owner)** Renew the Monlam quota (D45), upgrade to Blaze, set the two secrets, deploy functions and rules, then run `seed_vocab.py` (`docs/yonten-dev.md`).
- [ ] App Check enforcement moves to Phase 9 (D43).

**Done when:** a real photo of an apple returns ཀུ་ཤུ with Monlam audio on a phone browser, and no keys appear in `yonten/`.

## Phase 7: Backpack and Quests (§5) — day 7

- [x] Backpack: each card shows only the child's own photo via `WordPhoto` (D37).
- [x] Backpack: the word grid from `users/{uid}/words` (newest first), rotations, staggered pop-in, tap to play audio with a wiggle, and the "Find more words" button.
- [x] Stickers row: earned stickers from map chests, plus dashed empty slots.
- [x] Quests: a daily document at `quests/{yyyy-mm-dd}` created on first open. Quest progress hooks from scans, lessons and XP.
- [x] Claim button behavior (breathing, the "Got it!" stamp, XP). Yonten peeks in.

**Done when:** a scan shows up in the Backpack, moves its quests forward, and a claim adds XP. The next day's quests reset.

## Phase 8: Profile and parent area (§5 Me) — day 8

- [x] Avatar ring, name, level ribbon, and the 2 × 2 stats grid.
- [x] "This week" butter lamps: flickering flames, today's lamp lighting up, missed days dimmed.
- [x] The 1.5 s hold-to-unlock parent gate.
- [x] Parent settings: link Google, Apple or email (`linkWithCredential`), daily goal, sound on/off, and the photo-keeping permission (used by Phase 6).

- [ ] **(Owner)** Turn on the Google, Apple and Email sign-in providers in the Firebase console (Apple also needs its service ID and key) so linking works (D49).

**Done when:** linking an account keeps all progress, and the lamps match the real streak.

## Phase 9: Hardening (§4 rules, §7) — day 9

- [ ] Final security rules, with emulator tests proving one user can't read or write another user's data.
- [ ] App Check enforced in production.
- [ ] Local-mode recovery (D33): retry sign-in later and merge `local.*` data into the account once.
- [ ] Offline pass: cold start in airplane mode, then the queued scan syncs.
- [ ] Accessibility pass: Semantics labels, tap targets of at least 44 px, contrast of at least 4.5:1, reduced motion.
- [ ] Banned-list audit: no gradients, emoji, Material icons or uppercase labels.
- [ ] Performance: image sizes, startup time, and frame rate during map scrolling on a mid-range Android phone.

## Phase 10: PWA launch and cutover — day 10

- [ ] `web/manifest.json` (theme #2AB0EE) and the icons. Check that the PWA installs on iOS Safari and Android Chrome.
- [ ] Point Hosting `public` at `yonten/build/web`. Move `frontend/` and `backend/` to `legacy/`. Update `README.md` and `docs/`.
- [ ] Deploy Hosting, Functions and rules. Run the §10 "Done when" checklist end to end.

**MVP is done here.**

---

## Phase 11: Mobile app runway (iOS and Android)

The same Flutter code base, so this phase is configuration, compliance and store work rather than a rewrite. Start it once Phase 10 has shipped.

**11a. Native builds**
- [ ] Add the native Firebase config (`flutterfire configure` for iOS and Android). Set the bundle and package ids.
- [ ] Camera permission strings (iOS `NSCameraUsageDescription`, Android manifest), and the native camera path with `ResolutionPreset` tuning.
- [ ] App Check providers: App Attest/DeviceCheck on iOS, Play Integrity on Android.
- [ ] Sign in with Apple (required on iOS once Google sign-in is offered).
- [ ] App icon, splash screen, and locking to portrait.
- [ ] Bundle the Unit 1 audio in the app so the first lessons work with no network.

**11b. Kids-app compliance**
- [ ] Apple Kids Category and Google Play Families policy: no third-party analytics or ads, and a parental gate before any external link, purchase or account linking (the hold-to-unlock may need a stronger gate, such as a simple math question; check the current guidelines).
- [ ] Photos are kept (D37): parental consent, a "delete my child's photos" control, and disclosure in the privacy policy and store forms.
- [ ] COPPA and GDPR-K privacy policy, a data-deletion flow in Parent Settings, and a minimal data inventory.
- [ ] Privacy nutrition labels and the Data safety form.

**11c. Release**
- [ ] Internal testing: TestFlight and a Play internal track, with 3–5 families.
- [ ] CI: GitHub Actions or Codemagic building web, iOS and Android on every tag.
- [ ] Store listings, screenshots in English and Tibetan, then staged rollout.

## Phase 12: After the MVP

- Real art for every `InkIcons` placeholder, and word pictures for each new vocab item.
- More curriculum chapters, following the workbook. Add a teacher review screen for unverified vocab (D3).
- Bring back the legacy features: letter tracing, the sentence quiz (only `approved: true` sentences) and the NFC toy.
- A parent metrics dashboard.

## Order and parallel work

```
0 → 1 → 2 → 3 → 4 → 5 → 7 → 8 → 9 → 10 → 11
                     ↘ 6 (functions) ↗
```

Phase 6 only depends on Phase 0, so someone else can build it alongside Phases 1–5.
