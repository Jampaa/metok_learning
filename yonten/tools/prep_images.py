"""Image pipeline for Yonten (spec section 3).

Reads the 1024x1024 transparent PNG pack from assets/raw/Yonten-App-Images/
and writes 2x-resolution WebP files (quality 88) to assets/images/.

Usage (from yonten/):
    tools/.venv/bin/python tools/prep_images.py [--src DIR] [--out DIR]
"""

from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
DEFAULT_SRC = ROOT / "assets" / "raw" / "Yonten-App-Images"
DEFAULT_OUT = ROOT / "assets" / "images"
WEBP_QUALITY = 88

# 1. Full-body poses share one crop so frames swap in place without jumping.
POSE_CROP = (88, 88, 936, 936)
POSE_SIZE = 280
POSES = [
    "idle", "blink", "wave-a", "wave-b", "explore", "explore-blink",
    "crouch", "cheer-jump", "cheer-land", "think",
]

# 2. Avatar head-and-shoulders.
# Spec says (152, 140, 872, 860); shifted up 14 px so the hair tuft
# (top at y 133) isn't clipped. Same 720 px square. DECISIONS.md D13.
AVATAR_CROP = (152, 126, 872, 846)
AVATAR_SIZE = 260

# 3. Peek: the cut edge lands exactly on the right side.
PEEK_CROP = (380, 110, 817, 910)
PEEK_HEIGHT = 300

# 4. Scene images: alpha bounding box, then resize to a width (or height).
SCENE_WIDTHS = {
    "map-mountains": 800,
    "map-hills": 800,
    "cloud-1": 260,
    "cloud-2": 180,
    "prayer-flags": 480,
    "thangka-frame": 420,
    "chest-closed": 200,
    "chest-open": 220,
}
SCENE_HEIGHTS = {"chorten": 260}

# 5. Lamp split. Flame base sits at (50%, 32%) of the shared frame.
LAMP_SPLIT_Y = 362
LAMP_FLAME_SEED = (512, 300)
LAMP_CROP = (278, 99, 746, 923)
LAMP_WIDTH = 96

# 6. Icons.
ICONS = [
    "nav-map", "nav-backpack", "nav-quests", "nav-me", "nav-camera",
    "icon-flame", "icon-flash",
]
ICON_SIZE = 96

# 7. Paper grain tile.
GRAIN_SIZE = 256


def save(img: Image.Image, out: Path, name: str) -> None:
    path = out / f"{name}.webp"
    img.save(path, "WEBP", quality=WEBP_QUALITY, method=6)
    print(f"  {path.name:28s} {img.width}x{img.height}")


def load(src: Path, folder: str, name: str) -> Image.Image:
    return Image.open(src / folder / f"{name}.png").convert("RGBA")


def alpha_bbox(img: Image.Image) -> tuple[int, int, int, int]:
    bbox = img.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("image is fully transparent")
    return bbox


def resize_width(img: Image.Image, width: int) -> Image.Image:
    height = round(img.height * width / img.width)
    return img.resize((width, height), Image.LANCZOS)


def resize_height(img: Image.Image, height: int) -> Image.Image:
    width = round(img.width * height / img.height)
    return img.resize((width, height), Image.LANCZOS)


def prep_poses(src: Path, out: Path) -> None:
    for pose in POSES:
        img = load(src, "1-yonten-poses", f"yonten-{pose}").crop(POSE_CROP)
        save(img.resize((POSE_SIZE, POSE_SIZE), Image.LANCZOS), out, f"yonten-{pose}")
    for pose in ("avatar", "avatar-blink"):
        img = load(src, "1-yonten-poses", f"yonten-{pose}").crop(AVATAR_CROP)
        save(img.resize((AVATAR_SIZE, AVATAR_SIZE), Image.LANCZOS), out, f"yonten-{pose}")
    peek = load(src, "1-yonten-poses", "yonten-peek").crop(PEEK_CROP)
    save(resize_height(peek, PEEK_HEIGHT), out, "yonten-peek")


def prep_scene(src: Path, out: Path) -> None:
    for name, width in SCENE_WIDTHS.items():
        img = load(src, "2-map-scene", name)
        save(resize_width(img.crop(alpha_bbox(img)), width), out, name)
    for name, height in SCENE_HEIGHTS.items():
        img = load(src, "2-map-scene", name)
        save(resize_height(img.crop(alpha_bbox(img)), height), out, name)


def flood_region(mask: np.ndarray, seed: tuple[int, int]) -> np.ndarray:
    """4-connected region of `mask` containing `seed` (x, y), grown by
    repeated dilation until it stops changing."""
    x, y = seed
    if not mask[y, x]:
        raise ValueError(f"seed {seed} is not inside the mask")
    region = np.zeros_like(mask)
    region[y, x] = True
    while True:
        grown = region.copy()
        grown[1:, :] |= region[:-1, :]
        grown[:-1, :] |= region[1:, :]
        grown[:, 1:] |= region[:, :-1]
        grown[:, :-1] |= region[:, 1:]
        grown &= mask
        if np.array_equal(grown, region):
            return region
        region = grown


def prep_lamp(src: Path, out: Path) -> None:
    lit = load(src, "3-streak-and-rewards", "lamp-lit-tibetan-style")
    rgba = np.array(lit)

    # Base: everything at or below the split line.
    base = rgba.copy()
    base[:LAMP_SPLIT_Y, :, 3] = 0

    # Flame: only the opaque region connected to the seed, above the split.
    # This keeps flame + wick and drops the free-floating sparkles.
    opaque = rgba[:, :, 3] > 16
    opaque[LAMP_SPLIT_Y:, :] = False
    connected = flood_region(opaque, LAMP_FLAME_SEED)
    flame = rgba.copy()
    flame[~connected, 3] = 0

    for name, arr in (("lamp-base", base), ("lamp-flame", flame)):
        img = Image.fromarray(arr, "RGBA").crop(LAMP_CROP)
        save(resize_width(img, LAMP_WIDTH), out, name)


def prep_icons(src: Path, out: Path) -> None:
    for name in ICONS:
        img = load(src, "4-icons", name)
        img = img.crop(alpha_bbox(img))
        side = max(img.width, img.height)
        square = Image.new("RGBA", (side, side), (0, 0, 0, 0))
        square.paste(img, ((side - img.width) // 2, (side - img.height) // 2))
        save(square.resize((ICON_SIZE, ICON_SIZE), Image.LANCZOS), out, name)


def prep_paper_grain(out: Path) -> None:
    """Tileable gray fractal noise: 1/f spectrum with random phases.

    Building it in the frequency domain makes it wrap seamlessly.
    """
    rng = np.random.default_rng(seed=7)
    fy = np.fft.fftfreq(GRAIN_SIZE)[:, None]
    fx = np.fft.fftfreq(GRAIN_SIZE)[None, :]
    freq = np.sqrt(fx * fx + fy * fy)
    freq[0, 0] = 1.0
    amplitude = 1.0 / freq**0.9
    amplitude[0, 0] = 0.0
    phase = np.exp(2j * np.pi * rng.random((GRAIN_SIZE, GRAIN_SIZE)))
    noise = np.real(np.fft.ifft2(amplitude * phase))
    noise = (noise - noise.mean()) / noise.std()
    gray = np.clip(170 + noise * 42, 0, 255).astype(np.uint8)
    Image.fromarray(gray, "L").save(out / "paper-grain.png", optimize=True)
    print(f"  {'paper-grain.png':28s} {GRAIN_SIZE}x{GRAIN_SIZE}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--src", type=Path, default=DEFAULT_SRC)
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    print("Poses");   prep_poses(args.src, args.out)
    print("Scene");   prep_scene(args.src, args.out)
    print("Lamp");    prep_lamp(args.src, args.out)
    print("Icons");   prep_icons(args.src, args.out)
    print("Texture"); prep_paper_grain(args.out)


if __name__ == "__main__":
    main()
