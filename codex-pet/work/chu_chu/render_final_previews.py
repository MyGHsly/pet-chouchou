"""Render supplementary previews from the exact, validated pet atlas bytes."""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

CELL = (192, 208)
STANDARD = [
    ("idle", 6, [280, 110, 110, 140, 140, 320]),
    ("running-right", 8, [120] * 7 + [220]),
    ("running-left", 8, [120] * 7 + [220]),
    ("waving", 4, [140] * 3 + [280]),
    ("jumping", 5, [140] * 4 + [280]),
    ("failed", 8, [140] * 7 + [240]),
    ("waiting", 6, [150] * 5 + [260]),
    ("running", 6, [120] * 5 + [220]),
    ("review", 6, [150] * 5 + [280]),
]


def get_cell(atlas: Image.Image, row: int, col: int) -> Image.Image:
    w, h = CELL
    return atlas.crop((col * w, row * h, (col + 1) * w, (row + 1) * h))


def display(cell: Image.Image, label: str) -> Image.Image:
    bg = Image.new("RGBA", (384, 448), (245, 245, 240, 255))
    sprite = cell.resize((384, 416), Image.Resampling.LANCZOS)
    bg.alpha_composite(sprite, (0, 32))
    d = ImageDraw.Draw(bg)
    d.rectangle((0, 0, 383, 31), fill=(31, 36, 42, 255))
    d.text((10, 8), label, font=ImageFont.load_default(), fill=(255, 255, 255, 255))
    return bg.convert("RGB")


def gif(frames: list[Image.Image], durations: list[int], path: Path) -> None:
    frames[0].save(
        path, save_all=True, append_images=frames[1:], duration=durations,
        loop=0, disposal=2, optimize=True,
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("atlas")
    parser.add_argument("--output-dir", required=True)
    parser.add_argument("--frames-root", required=True)
    args = parser.parse_args()
    out = Path(args.output_dir)
    frames_root = Path(args.frames_root)
    out.mkdir(parents=True, exist_ok=True)
    frames_root.mkdir(parents=True, exist_ok=True)
    atlas = Image.open(args.atlas).convert("RGBA")
    if atlas.size != (1536, 2288):
        raise SystemExit(f"expected v2 atlas, found {atlas.size}")

    all_frames, all_durations = [], []
    cells = {}
    for row, (name, count, durations) in enumerate(STANDARD):
        state_dir = frames_root / name
        state_dir.mkdir(parents=True, exist_ok=True)
        state_frames = []
        for col in range(count):
            cell = get_cell(atlas, row, col)
            cell.save(state_dir / f"{col:02d}.png")
            state_frames.append(display(cell, name))
        cells[name] = state_frames
        all_frames += state_frames
        all_durations += durations
    gif(all_frames, all_durations, out / "all-states.gif")

    transition = cells["idle"][:3] + cells["jumping"] + cells["idle"][3:]
    gif(transition, [180] * len(transition), out / "idle-jump-idle.gif")

    look_cells = [get_cell(atlas, 9 + i // 8, i % 8) for i in range(16)]
    look_frames = [display(cell, f"look {i + 1:02d}/16") for i, cell in enumerate(look_cells)]
    gif(look_frames, [220] * 16, out / "look-loop.gif")

    for name, index in [("idle", 0), ("running-right", 3), ("jumping", 2), ("waiting", 3)]:
        cells[name][index].save(out / f"still-{name}.png")
    print(f"wrote final previews to {out}")


if __name__ == "__main__":
    main()
