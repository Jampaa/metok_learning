# Design System

Centralized in `frontend/src/index.css` under the `@theme` block (Tailwind v4
tokens) — components must reference these tokens (`bg-primary`,
`text-adventure-dark`, `font-tibetan`, `tibetan` class) rather than
hardcoding hex values or font names.

## Palette

| Token | Hex | Use |
|---|---|---|
| `--color-primary` | `#4cad50` | Primary actions, headers |
| `--color-primary-dark` | `#388e3c` | Primary button active state |
| `--color-adventure` | `#ffb300` | Treasure Hunt, rewards, secondary CTA |
| `--color-adventure-dark` | `#e6a000` | Adventure button active state |
| `--color-sky` | `#2196f3` | Audio/listen actions |
| `--color-leaf` | `#8bc34a` | Accents |
| `--color-cream` | `#fff3d0` | App background |
| `--color-cream-dark` | `#ffe9a8` | Borders, progress track |
| `--color-sky-light` | `#e1f5fe` | Secondary background |
| `--color-ink` | `#263238` | Text |
| `--color-treasure` | `#d4a017` | Treasure chest / mission accents |
| `--color-correct` / `--color-incorrect` | `#43a047` / `#e5533d` | Quiz feedback (always paired with an icon/label, never color alone — Section 38) |

## Type

- `--font-display` (Baloo 2) — all UI chrome, buttons, headings. Rounded,
  playful, not a "SaaS dashboard" font.
- `--font-tibetan` (Noto Sans Tibetan) — applied via the `.tibetan` utility
  class whenever Uchen text is rendered. Uses `line-height: 2` because
  Tibetan stacked vowels/subscripts need more vertical room than Latin text.

## Rules

1. No new hex colors in components — add a token if you need a new color.
2. Rounded shapes (`rounded-[1.75rem]`+ blobs), not generic `rounded-md`
   rectangles everywhere.
3. Buttons always show a pressed state (`active:translate-y-0.5`) for
   tactile feedback on touch.
4. Loading states use rotating friendly copy (`LoadingAnimation.tsx`), never
   a bare spinner or the word "Loading...".
5. Tibetan text (`TibetanWord.tsx`) always checks `verified` — unverified
   seed words render as "translation pending review" instead of a
   `TODO_VERIFY` string, so this never accidentally reaches a child.

## Components (`frontend/src/components/`)

`Button`, `TibetanWord`, `AudioButton`, `ProgressBar`, `StarReward`,
`ObjectCard`, `WordCard`, `MissionCard`, `TreasureChest`, `Character`,
`BottomNavigation`, `Modal`, `LoadingAnimation`.

`Character` and `TreasureChest` currently render emoji placeholders — swap
for real illustrations from `assets/characters/` and `assets/icons/` without
changing their call sites.
