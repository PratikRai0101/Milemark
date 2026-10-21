#!/usr/bin/env python3
"""Shrinks the framed screenshots.

The frames are mostly flat greys with one accent colour, so a 128-colour
palette is indistinguishable from the original at a third of the size. The
readme shows these at 300 px wide, and there are eleven of them, so the
difference is worth a megabyte of the page weight.

Usage: python3 design/optimise-frames.py
"""
import pathlib
import sys

from PIL import Image

COLOURS = 128
ROOT = pathlib.Path(__file__).resolve().parent.parent
FRAMES = ROOT / "Screenshots" / "frames"


def main() -> int:
    if not FRAMES.is_dir():
        print("There are no frames to shrink.", file=sys.stderr)
        return 1

    before = after = 0
    for path in sorted(FRAMES.glob("*.png")):
        size = path.stat().st_size
        before += size
        image = Image.open(path).convert("RGB")
        image.quantize(
            colors=COLOURS, method=Image.MEDIANCUT, dither=Image.Dither.NONE
        ).save(path, optimize=True)
        new = path.stat().st_size
        after += new
        print(f"  {path.name}  {size // 1024} KB → {new // 1024} KB")

    print(f"  {before // 1024} KB → {after // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
