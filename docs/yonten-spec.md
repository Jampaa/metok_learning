# Prompt: build the Yonten Tibetan learning app (Flutter + Firebase MVP)

How to use it:

1. Open Cursor (or Claude Code) in an empty folder.
2. Unzip `Yonten-App-Images-Transparent.zip` into `assets/raw/` inside that folder.
3. Paste everything below the line into the AI chat.

---

You are a senior Flutter engineer and UI/UX designer. Build the MVP of **Yonten**, a Tibetan-language learning app for children aged 4–8, in 10 days. Use the exact tech stack, visual spec and animation spec below, in this repo. Work in small, runnable steps, commit after each day's milestone, and don't ask me questions. If something is unclear, make the sensible choice and add it to `DECISIONS.md`.

## 1. Tech stack (locked in)

This is a locked-in, high-performance, 10-day MVP tech stack. It is 100% serverless, needs no maintenance, and is optimized for speed.

### 1. Frontend (the apps)

- **Framework: Flutter (Dart).** You write the UI once. It compiles into a fast web PWA now, and later compiles natively into iOS and Android apps with a single command.
- **Design:** custom-coded widgets in the "Himalayan" palette, with the tactile toy look (thick 4px bottom border).
- **State management and local storage: Provider / Riverpod + Hive (or SharedPreferences).** This keeps the app fast locally, even if the child's internet connection drops.
  - Use Riverpod.
  - For Hive, use `hive_ce`, the maintained fork.

### 2. Backend and database (serverless Firebase)

- **Hosting and PWA deployment: Firebase Hosting.** Free global CDN, handles SSL certificates, and serves the web app instantly.
- **Database: Cloud Firestore.** A real-time NoSQL database. It caches user progress offline, tracks streaks, and syncs parent metrics without anyone managing database servers.
- **Authentication: Firebase Auth.** A secure, built-in login system that supports Google, Apple, and simple anonymous or email logins for kids and parents.
- **Storage: Firebase Cloud Storage.** Holds the compressed Monlam TTS audio files (MP3s) and the scanned flashcard images.

### 3. AI and audio processing (the brains)

- **Computer vision (object recognition): Google Gemini Flash, via Python Cloud Functions.** Fast multimodal vision. When a child takes a photo, Gemini identifies the object and returns the Tibetan and English translation data.
  - Use the current Flash model: `gemini-3.8-flash` as of October 2026, with `gemini-3.6-flash` as Google's recommended stable replacement for older Flash models.
  - Gemini 1.5 Flash has been retired, so don't use it.
  - Keep the model name in one config value so it can be upgraded.
- **Backend logic layer: Firebase Cloud Functions (Python runtime).** No separate FastAPI server is needed. Python Cloud Functions run securely on Google's servers, keep the API keys hidden, and make the Gemini and Monlam requests when the app triggers them.
- **Voice/TTS: Monlam AI Text-to-Speech API.** Authentic, high-quality Tibetan pronunciation for every word scanned.

### Why this wins the 10 days

- **No servers to manage:** everything is serverless.
- **One codebase:** the same Flutter code goes from web to mobile.
- **Near-zero cost at MVP scale:**
  - Cloud Functions and the default Cloud Storage bucket require the **Blaze (pay-as-you-go) plan**, which means a billing account must be attached.
  - Blaze includes monthly no-cost quotas: 2M function calls, Firestore's free daily reads and writes, 5 GB of Storage, and 10 GB of Hosting.
  - A small MVP should stay inside those quotas. Set a budget alert at $5.

This is the exact stack to scaffold.

## 2. Repo structure

```
yonten/
  pubspec.yaml
  DECISIONS.md
  tools/prep_images.py          # image pipeline (section 3)
  assets/raw/                   # the unzipped image pack (input only, not bundled)
  assets/images/                # processed .webp output (bundled)
  assets/fonts/                 # Grandstander, Andika, Jomolhari (OFL, bundled for offline)
  lib/
    main.dart
    app/router.dart  app/app.dart
    theme/colors.dart  theme/text.dart  theme/motion.dart
    widgets/          # ToyButton, ToyCard, LevelNode, StickerChip, SegmentedProgress,
                      # YontenSprite, PaperGrain, InkIcons (CustomPainter/SVG for missing icons)
    features/map/  features/scanner/  features/backpack/  features/quests/  features/profile/
    data/models/  data/repositories/   # Firestore + Hive
    services/auth_service.dart  vision_service.dart  audio_service.dart
  functions/                    # Python Cloud Functions
    main.py  requirements.txt
  firestore.rules  storage.rules  firebase.json
  web/manifest.json             # PWA name, icons, theme color #2AB0EE
```

Packages:

| Purpose | Packages |
|---|---|
| State | flutter_riverpod |
| Local storage | hive_ce, hive_ce_flutter (or shared_preferences) |
| Firebase | firebase_core, firebase_auth, cloud_firestore, firebase_storage, cloud_functions, firebase_app_check |
| Camera | camera (live viewfinder), with image_picker as a fallback |
| Audio | just_audio |
| SVG icons | flutter_svg |
| Routing | go_router |

## 3. Image pack and pipeline

`assets/raw/Yonten-App-Images/` holds 1024 × 1024 transparent PNGs:

- `1-yonten-poses/`: idle, blink, wave-a, wave-b, explore, explore-blink, crouch, cheer-jump, cheer-land, peek, think, avatar, avatar-blink.
- `2-map-scene/`: map-mountains, map-hills, cloud-1, cloud-2, prayer-flags, chorten, thangka-frame, chest-closed, chest-open.
- `3-streak-and-rewards/`: lamp-base and lamp-lit-tibetan-style. The lit lamp has the flame baked in.
- `4-icons/`: nav-map, nav-backpack, nav-quests, nav-me, nav-camera, icon-flame, icon-flash.
- Ignore `5-alternates/`.

Write `tools/prep_images.py` (Pillow + numpy, WebP quality 88) that writes to `assets/images/`. Output sizes are 2× the on-screen size.

1. **Full-body Yonten poses** (idle, blink, wave-a, wave-b, explore, explore-blink, crouch, cheer-jump, cheer-land, think): crop all with the same box `(88, 88, 936, 936)` and resize to 280 × 280. The shared crop is what lets poses swap in place without jumping.
2. **avatar and avatar-blink:** crop `(152, 140, 872, 860)` and resize to 260 × 260.
3. **peek:** crop `(380, 110, 817, 910)` so the cut edge lands exactly on the right side, then resize to height 300.
4. **Scene images:** crop each to its alpha bounding box, then resize to these widths:

   | Image | Width |
   |---|---|
   | mountains | 800 |
   | hills | 800 |
   | cloud-1 | 260 |
   | cloud-2 | 180 |
   | prayer-flags | 480 |
   | thangka-frame | 420 |
   | chest-closed | 200 |
   | chest-open | 220 |

   The chorten is resized to height 260 instead.
5. **Lamp:** split `lamp-lit-tibetan-style` into two images that share one frame, so they stack exactly.
   - **lamp-base:** clear every pixel above y = 362.
   - **lamp-flame:** flood-fill the alpha from (x 512, y 300), limited to y < 362. This keeps only the flame and wick and drops the sparkles.
   - Crop both to `(278, 99, 746, 923)` and resize to width 96. In that frame the flame's base sits at 50% across and 32% down; use that point as the flame's transform origin.
6. **Icons:** crop to the bounding box, pad to a square and resize to 96 × 96.
7. **paper-grain.png:** a 256 × 256 tile of gray fractal noise, used for the paper texture.

Run `precacheImage` for every Yonten frame at startup, so pose swaps never flash.

### Missing images

Draw these in code (flutter_svg or CustomPainter) in the same style: a 2–2.5 px #2D3142 outline, flat fills, palette colors only. When the real art arrives, swap them for image files with the same names.

- **Word pictures:** apple, Tibetan door, water drop, sun.
- **Small icons:** book, guidebook (book with a maroon right page), magnifier, pecha, star, lock, speaker, close ×, switch camera, white check mark.
- **+10 XP seal:** a yellow circle with the text set in code.

## 4. Design system ("ink-and-sticker storybook")

Put these in `theme/`.

**Colors:**

| Role | Color | Notes |
|---|---|---|
| Sky blue (primary, active) | #2AB0EE | darker #1A8AC1 |
| Monastery maroon | #C03221 | darker #9A2517 |
| Butter-tea yellow (rewards, done) | #F9C80E | darker #D1A507 |
| Background | #F7F9FA | |
| Ink (text and all outlines) | #2D3142 | |

- **Supporting colors:**
  - Muted text: #5C6378 and #3D4357.
  - Disabled: fill #EEF2F5, border #B8C3CC, text #7D8995.
  - Inactive labels: #6B7685.
- **Tints:**
  - Sky: #DDF1FB.
  - Yellow: #FEF1C2, plus #FFF6D6 for a completed card.
  - Maroon: #F8DEDA.
  - Slate: #E9EDF1.

**Type** (bundled font files, not fetched at runtime, so text works offline):

- **Grandstander** 700/800 for headings, numbers and button labels.
- **Andika** 400/700 for body text and labels. It was designed for early readers.
- **Jomolhari** for all Tibetan text. It has one weight only, so never set it bold.

**ToyButton / ToyCard widget:**

- 2 px ink border all round, plus a 4 px ink bottom edge.
- Corner radius 16.
- Pressed state: on tap-down, the content moves down 2 px and the bottom edge shrinks to 2 px. The total height stays constant (pad the top), so nothing around it moves. Animate it over 70 ms.
- Level nodes, the shutter and avatars are circles.
- Illustration buttons (Yonten, the chest, nav items) squish to 0.94 scale when pressed instead.

**PaperGrain:** an 8% multiply overlay of the tiled `paper-grain.png` over the whole app, ignoring pointer input. Add a debug setting to turn it off.

**Rules:**

- **Banned:**
  - Gradients, glows, frosted glass and soft shadows.
  - Emoji.
  - Uppercase letter-spaced labels.
  - Material default icons.
- **Use instead:**
  - Sentence-case labels ("Start here!", "Claim", "Play audio").
  - Slight hand-placed rotations (−3° to +2°) on stickers and cards.
- **Feedback:** positive reinforcement only — no hearts, lives or energy.
- **Accessibility:**
  - Every tappable element has a Semantics label and a tap target of at least 44 px.
  - Text contrast is at least 4.5:1, so text on blue is ink-colored, not white.
  - When `MediaQuery.disableAnimations` is true, every looping animation stops.

**Layout:** the reference frame is 400 × 800 logical px. On web, center the app in a 430 px-wide column. Positions below are in reference px; scale them with the screen width on phones.

## 5. Screens

- **Shell:** the screen area sits above an 88 px bottom nav.
- **Streak and words pills:** two white sticker chips at the top-right (top 12, right 14) on the Map and Backpack screens only: icon-flame + streak count, and a book icon + words learned.
- **Bottom nav:**
  - White, with a 2 px ink top border and five columns: Map, Backpack, [gap], Quests, Me.
  - Each tab shows a 52 × 38 tile holding a 32 px icon, with a label underneath (Andika 12.5 / 700).
  - Active tab: the tile is sky blue with an ink outline and 4 px ink bottom, and the label turns #1A8AC1.
  - Center Scan button: an 84 px white circle with an ink outline sits 34 px above the bar. Inside it is a sky-blue round button (62 × 58, 2.5 px ink outline, 4 px bottom) holding the nav-camera image at 40 px. A "Scan" label sits underneath.

### Map (scrolls): the Treasure Hunt Map

**What it is.** The Map is the center of the app, the screen the child sees every day.

- It is not a menu or a grid of levels. It is a vertically scrolling, winding illustration, like a vintage treasure map or a board-game path.
- As the child scrolls up, a colorful dirt path curves back and forth.
- Chunky, tactile stepping stones sit along the path: the lesson nodes.
- Each node is one step in the author's mother's Tibetan primary curriculum, starting with the alphabet (ཀ་ ཁ་ ག་ ང་).

**Gameplay loop:**

| Node | Look | On tap |
|---|---|---|
| Active ("now") | Glowing sky blue (#2AB0EE), gentle pulsing ring, a floating "START" speech bubble | Launches that lesson or camera scanner challenge |
| Completed ("past") | Butter-tea yellow (#F9C80E) with a small check or star badge | Replays the word for extra practice |
| Locked ("future") | Grayed out, further along the path | Nothing is blocked or punished. A gentle message says it opens soon; nodes unlock naturally as the child progresses |
| Milestone chest | A chunky treasure chest in place of a circle, every 5 nodes (make the interval a config value, 5 or 10) | When reached: a mini-celebration (chest opens, confetti, Yonten cheers) and a special reward, such as a new sticker added to the Backpack |

**Rules:**

- **No health barriers, energy meters or "Game Over" screens.**
- **The map only moves forward.** Failing a scanner check never moves the child backward.
- **Clusters follow the workbook.** Each cluster of nodes mirrors one chapter or page sequence of the mother's Tibetan workbook, so finishing a cluster on screen matches the lessons the child is coloring in the physical book.
  - Show a hanging thangka banner at the start of each cluster, with the chapter name and its letters.
  - Store the chapter and page numbers on each lesson (section 7).

**Why it works:** children understand physical geography far better than abstract lists, so an upward winding path gives an intuitive sense of a journey. There is zero anxiety, because progress is safe and always positive.

**Sky band**, 340 px tall, background #DDF1FB, layered back to front:

1. cloud-2: 90 × 56 at (236, 124).
2. map-mountains: 400 × 135, bottom 46.
3. map-hills: 400 × 67, bottom 0.
4. cloud-1: 130 × 78 at top-right (right 16, top 62).
5. thangka-frame: 200 × 300 at (16, 12). Overlay live text on its empty panel, which sits at left 39, top 55, 122 × 180: "Unit 1" (Andika 13, #FBD9D3), "The Alphabet" (Grandstander 23, white) and "ཀ་ཁ་ག་ང།" (Jomolhari 21, yellow).
6. A guidebook button at right 18, top 232.

**Trail**, 1090 px tall:

- **Dirt path:** drawn with a CustomPainter along this SVG path, which starts at the hills (y 0):
  `M200 0 L200 76 C200 128 256 128 256 180 C256 232 284 232 284 284 C284 336 256 336 256 388 C256 440 200 440 200 492 C200 544 144 544 144 596 C144 648 116 648 116 700 C116 752 144 752 144 804 C144 856 200 856 200 908 C200 960 256 960 256 1012 L256 1090`
  - Draw it twice with round caps: first a 40 px ink stroke, then a 35 px cream (#F2E2C4) stroke on top, which leaves a thin ink edge on both sides.
  - On the part already walked, up to (256, 388), add golden footsteps: #D1A507 dots, 9 px wide, every 19 px.
- **Nodes:** 64 × 60 circles, centered on the path points in order:

  | Lessons | Letters | Style |
  |---|---|---|
  | 1–3 | ཀ ཁ ག | Completed: yellow, ink letter, small maroon check badge at the top-right |
  | 4 | ང | Active: sky blue, 76 × 72, on a 100 px #DDF1FB disc, with a 4 px sky-blue ring pulsing outward. A "START" bubble floats to its right at (304, 368), with a tail pointing at the node |
  | 5 | — | Milestone chest instead of a node |
  | 6–10 | ཅ ཆ ཇ ཉ ཏ | Locked: disabled colors |

- **Tap behavior:**
  - Active node: opens the Scanner (or that lesson).
  - Completed node: a message slides up from the bottom, "Let's practice ཀ again!", and the word's audio plays.
  - Locked node: the message "Keep going! This one opens after ང.".
  - Chest: opens it (described below).
  - Messages are white sticker toasts that hide after 2.8 s.
- **Yonten:** 124 px, beside the active node at (86, 326). He waves when the map opens or when tapped.
- **Prayer flags:** 230 × 54 at (190, 548).
- **Chorten:** 72 × 128 at (302, 672).
- **Chest:** closed image 86 × 71 that wiggles, and an open image 98 × 110, both bottom-aligned in a 96 × 84 tap area at (152, 446).
  - When the child reaches it, or taps it in the demo: swap to the open chest with a pop, burst confetti and show "Chest opened! A new sticker is in your Backpack."
  - Add the sticker to the Backpack's Stickers row.
  - Once opened, it stays open.
- **Data:** build the map from the `curriculum` collection and `users/{uid}.progress` (section 7). The node positions repeat the same winding pattern per cluster, with a chapter thangka at the start of each cluster.

### Scanner (Magic Eye)

- **Header:** a close × button, "Magic Eye" with "མིག་འཕྲུལ།" underneath in maroon, and a flash toggle (icon-flash).
- **Viewfinder:** 400 px tall, #2D3142, radius 24, showing the live `camera` preview. Four 46 px sky-blue corner brackets (7 px thick, radius 18) sit on top.
  - **Before a scan:** a tilted white sticker reads "What's in your kitchen?" and a sky-blue scan line sweeps up and down.
  - **After a scan:** a white result card slides up, tilted −1.5°. It shows the word picture (the captured image's crop if there's no art), the Tibetan word (Jomolhari 46, maroon), the English word (Grandstander 22) and the phonetic spelling (muted). It also has a sky-blue "Play audio" button, and a yellow "+10 XP" seal overlapping the top-right corner.
- **Controls row** (3 columns):
  - Left: Yonten (112 px) under a speech sticker.
  - Center: the shutter, a white circle 76 × 72 with a 3 px ink outline and a 52 px sky-blue inner disc.
  - Right: a switch-camera button.
- **States:**
  - `looking`: "Let's look!", explore pose.
  - `thinking`: while the function call runs, explore pose with the scan line speeding up.
  - `found`: "ཡག་པོ་རེད། / Great find!", celebrate sequence.
  - `retry`: the think pose and "Hmm, let's try again!", returning to `looking` after 2 s. Never show an error-red state to a child.

### Backpack

- **Title:** "My Backpack" with "རྒྱབ་ཁུར།" underneath, then the line "Words you've found".
- **Word cards:** a 2-column grid of white cards, 178 px tall, each slightly rotated (−1.5°, 1.2°, 1°, −1.8° repeating). Each card shows its picture, the Tibetan word (Jomolhari 30, maroon) and the English word. Tapping a card plays its audio and wiggles it.
- **Data:** the cards come from `users/{uid}/words`, newest first. Seed four words for the demo:

  | Tibetan | English |
  |---|---|
  | ཀུ་ཤུ | apple |
  | སྒོ | door |
  | ཆུ | water |
  | ཉི་མ | sun |

- **Stickers:** a heading "Stickers" with "N of 3 · from map chests" on the right, then a row of 72 px round slots.
  - An earned sticker shows as a white circle with an ink outline, tilted −6°, holding the reward image (the chorten for the first chest). It pops in.
  - Empty slots are dashed #B8C3CC circles.
- **Bottom button:** a full-width sky-blue "Find more words" button that opens the Scanner.

### Quests

- **Title:** "Daily Quests" (Grandstander 34) with "ཉིན་རེའི་ལས་འགན།" underneath.
- **Peeking Yonten:** yonten-peek at 82 × 150, flush with the screen's right edge, sitting behind the first card.
- **Quest cards:** three cards, each with a round icon sticker, the goal text, a segmented progress bar (18 px tall, ink outline, sky-blue fill, tick marks at each step) with a count, and a Claim button:

  | Quest | Icon | Example progress |
  |---|---|---|
  | Find 3 things in the kitchen | nav-camera | 1/3 |
  | Learn 2 new words | book | 2/2 |
  | Earn 30 XP to open a chest | nav-quests | 10/30 |

- **Claim button:**
  - While a quest is unfinished, it's gray and disabled.
  - When the quest is complete, it turns yellow and breathes, and the card background becomes #FFF6D6.
  - Tapping it pops a maroon "Got it!" stamp and adds XP.
- **Data:** quests reset daily, stored in `users/{uid}/quests/{yyyy-mm-dd}`.

### Me (Profile)

- **Avatar:** a 132 px yellow ring with a sky-tint inner circle holding yonten-avatar.
- **Name and level:** the child's name (Grandstander 32), then a notched maroon ribbon reading "Level N Explorer" with a yellow star.
- **Stats:** a 2 × 2 grid of tinted tiles, 112 px tall, each with an icon, a big number and a label:

  | Stat | Tile color | Icon |
  |---|---|---|
  | Total Words | Sky tint | Book |
  | Current Streak (days) | Yellow tint | icon-flame |
  | Scavenger Hunts | Maroon tint | Magnifier |
  | Lessons Done | Slate tint | Pecha |

- **"This week" card:** shows "N-day streak!" in maroon and seven butter lamps (34 × 60) for Mon–Sun.
  - Active days: the lamp base with a flickering flame.
  - Today, once active: the flame lights up with a pop, and the day letter is maroon.
  - Future or missed days: the base only, grayscale at 35% opacity.
- **Parent Settings (Hold to unlock):** a gray button. While held, a gray fill grows across it over 1.5 s; when it finishes, the parent area opens: link account, daily goal, sound on/off. Letting go early cancels it.

## 6. Animation spec

Implement with AnimationControllers and implicit animations; `flutter_animate` is allowed. All motion lives in `theme/motion.dart`. Swap poses with a `YontenSprite` widget that stacks every frame of an instance and shows one, so frames are preloaded and never flicker. Cancel timers and controllers when a screen is disposed.

| Element | When | Motion | Timing |
|---|---|---|---|
| Yonten blink (all screens) | Always | Swap to the blink frame | Every 3.5–6 s at random, for 140 ms |
| Yonten breathing | Idle on the map | scaleY 1 → 1.025, anchored at the bottom | 3 s loop |
| Yonten wave | Map opens, or Yonten is tapped | Frames a, b, a, b, a, then idle | Starts after 250 ms, 190 ms per frame |
| Yonten explore | Scanner `looking` | Whole image rotates ±3° around (50%, 95%) | 2.6 s loop |
| Yonten celebrate | Scanner `found` | crouch (scale 1.06, .9) → cheer-jump (up 30 px, scale .96, 1.06) with confetti → cheer-land (scale 1.08, .92) → rest on cheer-land | Starts at 0 / 150 / 520 / 700 ms, 140 ms transitions. Confetti: 7 outlined paper bits that fall 130 px and spin, about 1.4 s |
| Yonten think | Scanner `retry` | Think pose, head tilts ±3° | 2 s loop |
| Yonten peek | Quests opens | Slides in from fully off-screen right | 450 ms, after a 150 ms delay |
| Profile avatar | Always | Swaps to avatar-blink in step with the global blink | — |
| Clouds | Map | Drift 20 px sideways and back | 12 s and 15 s loops, opposite directions |
| Mountains | Map scroll | Parallax: offset = scrollOffset × 0.35, capped at 340 | Follows the scroll |
| Thangka | Map opens | Swings in like hanging cloth: −12° → 6° → −3.5° → 1° → −1.5°, pivoting at the top center | 900 ms |
| Prayer flags | Map | Skew 0 → −4°, anchored at the top | 3 s loop |
| Chest | Map | Wiggles ±5° in the last 14% of each loop. When opened, swaps to the open chest with a pop (scale .6 → 1.12 → 1) and 7 confetti bits | 5 s loop; confetti about 1.4 s |
| Active node ring | Map | A 4 px sky-blue ring grows from scale .85 to 1.3 while fading out | 2 s loop |
| START bubble | Map | Floats 4 px up and down | 2.4 s loop |
| Map message toast | Tapping a node or the chest | Slides up from the bottom, hides after 2.8 s | 440 ms |
| New sticker | Backpack, after a chest | Pops in | 380 ms |
| Scan line | Scanner `looking` / `thinking` | Sweeps 260 px | 2.8 s loop, 1.2 s while thinking |
| Result card | Scanner `found` | Slides up from 115% with a small overshoot. The word picture pops in at 200 ms; the XP seal stamps in from scale 1.8 and 30° to 1 and 12°, starting at 250 ms | 440 ms |
| Word cards | Backpack opens | Pop in one after another | 70 ms apart |
| Butter lamp flames | Profile | Flicker: scale and rotate around (50%, 32%), each lamp starting at a different point in the loop | 1.5 s loop |
| Today's lamp | Profile opens, if today is active | Lights up: scale 0 → 1.25 → 1 | 520 ms, after 450 ms |
| Nav icon | Tab selected | Hops 7 px once | 260 ms |
| Claim button | While claimable | Breathes: scale 1 → 1.06 | 2.4 s loop |

## 7. Data, auth and offline

- **Auth:**
  - Sign the child in anonymously on first launch, so they can play immediately.
  - In Parent Settings, the parent links Google, Apple or email with `linkWithCredential`, which keeps all progress.
- **Firestore:**
  - `users/{uid}`: `displayName`, `level`, `xp`, `streak{count, lastActiveDate}`, `stats{words, hunts, lessons}`, `progress{unit1: currentLesson}`, `settings{sound, dailyGoal}`.
  - `users/{uid}/words/{wordId}`: `tibetan`, `english`, `phonetic`, `imageUrl?`, `audioUrl`, `foundAt`.
  - `users/{uid}/quests/{date}`: an array of `{id, goal, progress, target, claimed}`.
  - `vocab/{wordId}` (global catalog, read-only for clients): `tibetan`, `english`, `phonetic`, `audioUrl`, `reviewed: bool`.
  - `curriculum/{chapterId}` (global, read-only for clients): `order`, `title`, `titleTibetan`, `workbookChapter`, `workbookPages`, and `lessons[]`. Each lesson has `{id, order, type: letter|word|scan|chest, label, wordId?, rewardStickerId?}`. Seed chapter 1 with ཀ ཁ ག ང, a chest, then ཅ ཆ ཇ ཉ ཏ.
  - `users/{uid}.progress`: `{currentLessonId, completedLessonIds[]}`. It only ever moves forward: a failed scan never removes progress.
  - `users/{uid}/stickers/{stickerId}`: `{earnedAt, fromLessonId}`.
- **Streak rule:** a day counts as active after one scan or one finished lesson. Update it in a Firestore transaction, comparing dates in the child's local time zone.
- **Offline:**
  - Turn Firestore persistence on (including on web).
  - Hive caches the profile snapshot, settings and audio file paths, so the app opens instantly with no connection.
  - Queue scans while offline and show "Yonten will check this when we're back online".
- **Security rules:**
  - Users read and write only `users/{their uid}/**`.
  - `vocab` is read-only for clients.
  - In Storage, `audio/**` is publicly readable but writable only by functions. User uploads go to `users/{uid}/**`, are limited to 2 MB, and accept images only.
  - Turn on **App Check** for the callable functions.

## 8. Cloud Functions (Python, 2nd gen, region us-central1)

1. **`identify_object` (callable):**
   - **Input:** a JPEG the app has resized to at most 1024 px.
   - **Gemini call:** use the model from the config value, with structured JSON output: `{english, tibetan, phonetic, confidence, kid_safe}`. The system prompt asks for one everyday object, in simple words for a child.
   - **Matching:** match the English word against the `vocab` catalog first. If it's found, return the catalog entry, because its Tibetan has been checked. If it isn't found, create a `vocab` doc with `reviewed: false` so a Tibetan teacher can check it later.
   - **Retry cases:** return `retry` when confidence is below 0.6 or `kid_safe` is false.
   - **Photos:** don't keep the raw photo. Only save a small cropped thumbnail, and only if the parent has allowed it in settings.
2. **`get_word_audio`** (called from `identify_object`, and on its own for seeding):
   - If `vocab/{id}.audioUrl` exists, return it.
   - Otherwise call the Monlam TTS API with the Tibetan text, save the MP3 to `audio/{wordId}.mp3` in Storage, store the URL and return it.
   - Put Monlam behind a small `TtsProvider` interface so the endpoint can change.
   - Before coding against it, confirm Monlam's TTS API access, endpoint and key with Monlam AI; their public site lists TTS but no developer docs. Until a key exists, use a stub that returns a placeholder clip.
3. **Secrets:** use `firebase functions:secrets:set GEMINI_API_KEY` and `MONLAM_API_KEY`, and never put keys in the Flutter app.
4. **Seed script:** write `functions/seed_vocab.py`, which loads a starter list (the four demo words plus the Unit 1 letters) and pre-generates their audio.

## 9. 10-day plan

| Day | Milestone |
|---|---|
| 1 | Flutter project, Firebase project on Blaze with a budget alert, image pipeline, fonts, theme, ToyButton/ToyCard, PaperGrain |
| 2 | Bottom nav, routing, pills, YontenSprite with the blink loop |
| 3 | Treasure Hunt Map: sky layers, dirt-path painter, nodes built from the curriculum data, tap behaviors, milestone chest, all map animations |
| 4 | Scanner UI: camera preview, states, result card, celebrate sequence |
| 5 | `identify_object` function wired to the scanner, with the retry path |
| 6 | `get_word_audio` with Monlam (or the stub), just_audio playback, seed script |
| 7 | Backpack from Firestore and the Quests logic with daily reset and claim |
| 8 | Profile: stats, butter-lamp streak, hold-to-unlock Parent Settings, account linking |
| 9 | Offline (persistence, Hive, scan queue), security rules, App Check, reduced motion |
| 10 | PWA manifest and icons, performance pass, deploy to Firebase Hosting, write the README |

## 10. Done when

- The web PWA deploys to Firebase Hosting and installs on a phone home screen.
- All five tabs work. A real scan returns a Tibetan word with audio, adds it to the Backpack, gives XP, and updates the streak and quests.
- The Treasure Hunt Map follows its rules:
  - It is built from the curriculum data.
  - Active, completed and locked nodes behave as in the gameplay table.
  - Milestone chests give a Backpack sticker.
  - Progress never goes backward.
- Yonten blinks, waves, explores, celebrates, thinks and peeks as specified, with no visible jump between frames.
- The app opens and shows progress with no network connection.
- No API keys exist in client code, and the security rules block cross-user access.
- Nothing breaks the banned list in section 4, and reduced motion stops all loops.
- `DECISIONS.md` lists every assumption you made.
