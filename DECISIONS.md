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

## Phase 1

**D13. Avatar crop.** The spec's avatar crop `(152, 140, 872, 860)` cuts
off the top of Yonten's hair tuft, whose top edge is at y 133. We use
`(152, 126, 872, 846)`: the same 720 px square, moved up 14 px.

**D14. Placeholder art colors.** The palette has no green, so the
`obj-apple` leaf uses yellowDark `#D1A507`. The `obj-door` frame uses
mutedStrong `#3D4357`, standing in for the black trapezoid frame of a
Tibetan doorway. All drawn glyphs are named after the file the brief
expects (`icon-book`, `obj-apple`, ...), so real art can replace them one
by one.

**D15. Progress ticks.** `SegmentedProgress` draws one tick per step up to
10 steps. Larger targets, such as 30 XP, get 10 evenly spaced ticks so the
bar stays readable.

**D16. Gallery as home screen.** Until Phase 2 adds routing, the app opens
on the developer gallery. In Phase 2 it moves to a hidden `/gallery`
route.

**D17. Lamp flame extraction.** Pillow 12's `ImageDraw.floodfill` did
nothing on the single-channel alpha mask, so `prep_images.py` finds the
flame by growing a region with numpy instead (repeated 4-neighbor
dilation, limited to y < 362). The result is the same as the spec's flood
fill: flame and wick only, no sparkles.

## Phase 2

**D18. Active tab label contrast.** The spec sets the active tab label to
#1A8AC1, which is only about 3.9:1 on white, below the spec's own 4.5:1
rule. For now we follow the visual spec. The active state is also shown
by the blue tile, so color isn't the only cue. Phase 9's accessibility
audit decides whether to darken it.

**D19. Reduced motion lives in one place.** `ReducedMotionScope` at the
app root combines `MediaQuery.disableAnimations` with a debug override
(the gallery toggle). Every looping animation goes through `LoopBuilder`,
and the blink clock and nav hop check the same scope, so one switch stops
all motion. Under reduced motion, frame sequences jump straight to their
end state.

**D20. Pose motion pivots.** Explore sways around (50%, 95%), as in the
spec. Think tilts around (50%, 60%), roughly Yonten's neck, so it reads
as a head tilt rather than a whole-body sway.

**D21. Scanner and gallery are full-screen routes** outside the tab
shell, so the nav is hidden there. Close pops back to the tab you came
from. The gallery is reachable only by URL: `/#/gallery`.

**D22. Placeholder numbers.** Until Phase 4 the pills show 3-day streak
and 4 words (`headerStatsProvider`), and the Me tab shows "Explorer" as
the name.

**D23. UI Tibetan strings.** Screen titles (རྒྱབ་ཁུར།, ཉིན་རེའི་ལས་འགན།,
མིག་འཕྲུལ།) are copied verbatim from the spec. They're UI labels, not
vocabulary, but they still go on the fluent-speaker check list with the
seed words (D4).

## Phase 3

**D24. "Start!" instead of "START".** Spec §4 bans uppercase labels and
asks for sentence case, so the bubble says "Start!". It's short enough to
fit at the spec's position (304, 368) without running off the 400 px
frame.

**D25. Chest placement is data, with a config for new chapters.** Chapter
1 is hand-placed exactly as in spec §7 (ཀ ཁ ག ང, chest, ཅ ཆ ཇ ཉ ཏ). A
strict "every 5 nodes" rule would also put a chest at node 10 and push ཏ
to node 11. `CurriculumConfig.chestInterval` (5) and `lettersWithChests()`
are for authoring later chapters. The map draws whatever the data says.

**D26. Map behavior details.**
- Tapping a chest early (demo) completes the chest without moving the
  current lesson, so ང stays active and the chest is skipped later.
  Reaching an unopened chest opens it automatically.
- The map scrolls on open just far enough to show the active node, and
  keeps the sky band in view.
- Later chapters start after a 320 px gap holding a 140 px chapter
  thangka on the side away from the path. The node pattern continues.
- Yonten and the bubble mirror to the other side of the active node when
  it's near the edge.
- "Map opens" replays (Yonten waves, thangka swings) every time the child
  switches back to the Map tab.
- The guidebook button shows which workbook pages the unit matches.
- Opening a chest plays crouch → cheer-jump → cheer-land. Phase 5 adds
  the full celebrate motion.

**D27. Workbook pages are placeholders.** Chapter 1 says workbook chapter
1, pages 1–6. The real chapter and page numbers need to come from the
author's mother's workbook.

**D28. Map progress is in memory for now.** Progress and stickers reset
when the app reloads until Phase 4 stores them in Firestore and Hive. The
gallery has debug buttons to complete the current lesson and to reset
the demo.

## Phase 4

**D29. New children start at ཀ.** A fresh account has nothing done and ཀ
active. The spec's demo state (ཀ ཁ ག done, ང active, four Backpack words)
is one tap away in the gallery ("Load demo") rather than being every
child's starting point.

**D30. One source for seed data.** `yonten/assets/data/curriculum.json`
and `vocab_seed.json` are bundled into the app (offline fallback) and
uploaded by the seed scripts, so Firestore and the app can't drift. The
seed vocab is `verified: false` with empty phonetics, which must come from
a speaker. `vocab` docs may say `verified` or the spec's `reviewed`; the
app accepts both.

**D31. Transactions with an offline fallback.** Lesson and scan updates
run in a Firestore transaction (spec §7). Transactions need the server,
so if one fails or takes more than 3 s, the same change is written as a
merge built from the cached profile. That write applies locally at once
and syncs later. It stays forward-only because completed lessons are
added with arrayUnion. Testing note: in the web SDK, `disableNetwork()`
doesn't block transactions, so the smoke check simulates offline with an
instance pointed at a dead port.

**D32. Rules.** `users/{uid}` is owner-only, and on update
`progress.completedLessonIds` must be a superset of the stored list, so
the server rejects any rewind. Delete is allowed (debug reset, and later
"delete my data"). Yonten's subcollections (`words`, `stickers`,
`quests`) get explicit owner rules instead of a recursive wildcard, so
the legacy `discoveries` subcollection stays admin-only. `curriculum` and
`vocab` are read-only for signed-in users. All legacy rules are kept
until the Phase 10 cutover. Storage: `audio/**` is public to read and
never client-writable; `users/{uid}/**` takes owner-only images up to
2 MB.

**D33. Local mode is per device.** If Firebase or anonymous sign-in
fails at startup (e.g. the very first launch with no connection), the
child plays in local mode and data is saved in Hive (`local.*`). Those
local records aren't merged into a Firestore account later. Phase 9 adds
a retry and a one-time merge.

**D34. Hive stores JSON strings** in one box (`yonten`), so no type
adapters are needed. `cache.profile` mirrors the Firestore profile for an
instant cold start; `cache.audioPaths` is for Phase 6.

**D35. Tooling.** The emulators need Java 21 (Homebrew `openjdk@21`). The
Firestore emulator runs on port 8085 because Flutter web uses 8080. The
rules tests live in `firebase/tests` and use Node's test runner with
`@firebase/rules-unit-testing`. Commands are in `docs/yonten-dev.md`.

## Phases 5 and 6

**D36. Which Tibetan a child may see (revises D3 and D4).** A strict "a
person must check every word" rule would mean a real scan never shows
Tibetan. We follow the legacy backend instead (`backend/app/routes/discovery.py`)
and `docs/architecture.md`, where Monlam's dictionary is the authoritative
source:
- A Monlam dictionary match is `verified: true` (`source: monlam_dictionary`).
- A Monlam LLM guess is stored `verified: false` (`source: monlam_llm`)
  and is never sent to the app: the function blanks unverified Tibetan on
  the server, and the app blanks it again.
- Alphabet letters are `verified: true` (`source: alphabet`); a letter
  isn't a translation.
- The four spec seed words are verified only if Monlam's dictionary agrees
  with the spec's spelling. Otherwise the dictionary's answer is saved as
  `dictionaryTibetan` for a teacher.
- An unverified find still counts (XP, streak, Backpack) and shows English
  plus "We'll learn this one in Tibetan soon!".

**D37. Every photo is kept; cards show only the child's photo (owner's
request, overrides spec §8.1).** Every shutter press, whatever the result,
is saved:
- on the device (Hive, newest 80 kept once uploaded);
- in Storage at `users/{uid}/photos/{photoId}.jpg` (at most 1024 px, JPEG
  quality 82, under the 2 MB rule);
- as a record in `users/{uid}/photos/{photoId}` with status found / retry
  / queued.

A word's card (scanner result card, Backpack in Phase 7) shows the child's
newest photo of that word and nothing else: `WordPhoto` uses the device
copy, then the uploaded copy, then a plain paper tile. Never drawn art.
Older photos of the same word stay in `photos`. The `keepPhotos` parent
setting is removed. Privacy follow-up for Phase 11b: these are photos
taken in a child's home, so the parent area needs a "delete my child's
photos" control, and the privacy policy and store forms must say photos
are stored.

**D38. Photos go to Storage from the app, not through the function.** The
app uploads the photo itself and sends the same JPEG (base64) to
`identify_object`, which never stores it. Uploads that fail wait in a
queue and retry.

**D39. A scan from the map completes the lesson.** The active node opens
the scanner with `?lesson=<id>`. A find (not a retry) completes that
lesson, forward only. The spec has no separate letter-lesson screen; one
can come later (Phase 12).

**D40. Offline and failure behavior.**
- No connection, or the function isn't reachable: the scan is queued
  ("Yonten will check this when we're back online") and retried at startup
  and every 90 s, along with queued photo uploads.
- Low confidence, not kid-safe (people, weapons, medicine, etc.) or any
  server error: "Hmm, let's try again!". The child never sees an error.
- The mock vision service (cycles through starter words) runs only with
  `--dart-define=VISION_MOCK=true` or in tests. It is never a silent
  fallback, because naming the wrong object teaches the wrong word.

**D41. Gemini.** `gemini-3.8-flash` (it's on the key's model list as of
2026-10-09), with `gemini-3.6-flash` as a fallback used only when the
main model answers 503 (busy) or 429. Both are params in `functions/.env`.
Gemini returns only `{english, category, confidence, kid_safe}`, never
Tibetan (D2). The prompt asks for the container, not its contents ("a cup
of tea is 'cup'").

**D42. Audio is WAV, not MP3.** Monlam's TTS only returns `audio/wav`
(checked in its OpenAPI spec), and Cloud Functions has no encoder. A
one-word WAV is small. Files live at `audio/{wordId}.wav` with a one-year
cache header. Only verified words get audio. `TtsProvider` has Monlam and
a stub (silent clip) for when no key is set.

**D43. App Check is not enforced yet.** `ENFORCE_APP_CHECK = False` in
`functions/main.py`. Enforcing it before the web app registers a reCAPTCHA
Enterprise key would block every call. Phase 9 turns it on.

**D44. Functions toolchain.** Python 3.13 venv at `functions/venv` (the
CLI requires that path and the runtime version), runtime `python313`.
Non-secret params are in `functions/.env`; secrets go in Secret Manager in
production, or `functions/.secret.local` (git-ignored) for the emulator.
On macOS the Functions emulator needs `OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES`
and `no_proxy='*'`, or forked workers crash. Production (Linux) is not
affected.

**D45. Monlam quota (blocking).** As of 2026-10-09 every Monlam endpoint
(dictionary, chat, TTS) returns 402 "Project quota has expired". Until
the owner renews it, scans still find objects in English, but no new word
can be verified and no audio can be generated. Everything retries
automatically once the quota is back. After that, rerun
`seed_vocab.py`.

## Phases 7 and 8

**D46. Quest progress is written with each scan.** The scan transaction
(or its offline fallback) also updates `quests/{today}`, so quests count
the same online, offline and when queued scans catch up:
- Find N things: +1 per find. Any find counts; the app can't tell what
  room the child is in. N = the parent's daily goal (default 3).
- Learn 2 new words: +1 the first time a word is found.
- Earn 30 XP: +10 per find.

Claiming gives +10 XP, which doesn't count toward the XP quest. Quests
reset per local day; the app re-checks the date every 90 s.

**D47. Active days for the butter lamps.** `users/{uid}.activeDates`
keeps the last 14 local dates with a scan or finished lesson, updated
with the streak. The "This week" card lights those days, Monday to
Sunday.

**D48. Transactions don't race a timer (fixes D31).** The offline
fallback runs only after a transaction has failed. With a 3 s timer, a
slow transaction that later committed was counted twice; the emulator
check found it (4 hunts for 2 scans). Offline, a transaction fails fast,
so the fallback still applies at once.

**D49. Parent area.**
- Hold-to-unlock uses raw pointer events. A gesture recognizer handed a
  long hold to its long-press recognizer at 0.5 s and cancelled the
  unlock. Moving the finger (scrolling) also cancels it. Screen readers
  get a long-press action instead of a timed hold.
- Settings: child's name (not in the spec, but the Me tab shows a name),
  account linking (Google and Apple by popup on web, email with
  `linkWithCredential`; same uid, so everything is kept), daily goal 1–10
  (sets the find quest's target from the next new day), and sound on/off
  (the audio service checks it).
- Linking needs the Google, Apple and Email providers switched on in the
  Firebase console, plus Apple's service setup. Until then the parent sees
  "This sign-in method isn't switched on yet".

**D50. Each tappable is its own accessibility node.** `ToyButton`,
`Squishable`, the stat tiles, sticker slots, word cards and lamp days use
`Semantics(container: true)`. Without it, screen readers merged
neighbouring labels into one (found by the widget tests).

**D51. Backpack details.** Unverified words show English only, and
tapping them wiggles the card without playing audio. With no words yet,
a friendly line invites the child to go find something. Sticker slots
are fixed at 3 (`StickerCatalog`); the chorten is the first chest's
sticker.
