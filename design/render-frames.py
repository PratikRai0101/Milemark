#!/usr/bin/env python3
"""Renders the app's screenshots inside a device frame, for the readme.

The frame is the iPhone drawn in `design/device.py`: a metal edge, a black
bezel, the Dynamic Island and the home indicator. There is no caption in the
image — the readme writes the caption underneath it, and having both means
saying the same thing twice.

Usage: python3 design/render-frames.py
"""
import pathlib
import subprocess
import sys

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import device  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / ".captures"
OUT = ROOT / "Screenshots" / "frames"

FRAMES = [
    "01-archive.png",
    "02-receipt-route.png",
    "03-receipt-ascii.png",
    "04-receipt-pace.png",
    "08-photo.png",
    "05-share.png",
    "07-tracking.png",
    "06-kept.png",
    "09-receipt-large-text.png",
    "10-settings.png",
    "11-import.png",
]


def main() -> int:
    missing = [name for name in FRAMES if not (SHOTS / name).exists()]
    if missing:
        print("These captures are missing, so the frames would be broken:", file=sys.stderr)
        for name in missing:
            print("  " + name, file=sys.stderr)
        print("Run design/capture-screenshots.sh first.", file=sys.stderr)
        return 1

    OUT.mkdir(parents=True, exist_ok=True)
    for name in FRAMES:
        screen = Image.open(SHOTS / name)
        # A transparent surround, so the frame sits on whatever the readme's
        # own background is.
        device.draw_device(screen).save(OUT / name)
        print("  " + name)

    print("  shrinking the frames")
    subprocess.run(
        [sys.executable, str(ROOT / "design" / "optimise-frames.py")], check=True
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
