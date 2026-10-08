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
