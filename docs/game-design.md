# Game Design

## Core loop

```
SEE -> IDENTIFY -> LEARN WORD -> HEAR -> TRACE -> SENTENCE -> PLAY -> REPEAT
```

## Modes

- **Explorer** (`features/explorer/`): free discovery — tap an illustrated
  object or take a picture. No goal, no time pressure.
- **Treasure Hunt** (`features/treasure-hunt/`): the app gives a mission
  ("find 3 writing tools"); finding all required objects opens a treasure
  chest, awards a badge, and unlocks the next area.

Both modes read the same `vocabulary`/`missions` data — never duplicate
word definitions between them.

## Rewards

- +10 ⭐ per first listen / correct quiz answer / trace ≥ 50%
- +5 ⭐ per NFC tap
- Mission completion: mission's `reward` (40-50 ⭐) + a named badge
- Area unlocks: 50 ⭐ -> Garden, 100 ⭐ -> Market (`hooks/useProgress.tsx`)

## Tracing score

Not handwriting recognition — a coarse heuristic (`TracingScreen.tsx`):
70% weight on "did strokes land inside the target's bounding box", 30% on
"how much of a 16x16 grid over that box got covered". Good enough to feel
like a mini-game, explicitly not a claim about handwriting quality.

## Sentence quiz

Fill-in-the-blank, multiple choice, per Section 17 — e.g.
`སྨྱུ་གུ ______ ཡིན།` with one correct option and two distractors. Wrong
answers can be retried; right answers lock in and reward stars.
