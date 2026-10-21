#!/usr/bin/env python3
"""Draws the demo video inside a device.

The simulator records the app's screen, not the phone around it, so the
device is drawn: the same iPhone the still frames use, on GitHub's dark
canvas so that it sits on the page rather than on a white card.

Usage: python3 design/frame-demo.py <video> <out.gif>
"""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
import device  # noqa: E402

# The screen, in pixels at the size the gif is written.
# Sized for the README's 260 px preview; the full-resolution MP4 remains
# available for inspecting details without downloading an oversized GIF.
SCREEN_WIDTH = 260

# GIF delays are measured in hundredths of a second: 25 fps gives an exact
# 40 ms cadence, unlike a 30 fps export that alternates 30/40 ms delays.
# Keep native transitions rather than dropping them to the old 8 fps.
FPS = 25
COLOURS = 128


def make_framer():
    """Builds the device once, and returns something that fills it."""
    state = {}

    def frame_device(screen: Image.Image) -> Image.Image:
        width, height = screen.size
        if "frame" not in state:
            frame, mask, off = device.frame_parts(width, height)
            state["frame"] = frame
            state["mask"] = mask
            state["off"] = off
        composed = state["frame"].copy()
        composed.paste(screen.convert("RGB"), state["off"], state["mask"])
        device.draw_island(composed, (width, height), state["off"])
        return composed

    return frame_device


def main() -> int:
    if len(sys.argv) != 3:
        print(__doc__, file=sys.stderr)
        return 2
    video = pathlib.Path(sys.argv[1])
    out = pathlib.Path(sys.argv[2])
    if not video.exists():
        print(f"There is no video at {video}.", file=sys.stderr)
        return 1

    with tempfile.TemporaryDirectory() as work:
        frames = pathlib.Path(work)
        subprocess.run(
            [
                "ffmpeg", "-y", "-v", "error", "-i", str(video),
                "-vf", f"fps={FPS},scale={SCREEN_WIDTH}:-2",
                str(frames / "%05d.png"),
            ],
            check=True,
        )

        shots = sorted(frames.glob("*.png"))
        if not shots:
            print("The video had no frames in it.", file=sys.stderr)
            return 1

        frame_device = make_framer()
        for shot in shots:
            frame_device(Image.open(shot)).save(shot)

        subprocess.run(
            [
                "ffmpeg", "-y", "-v", "error", "-framerate", str(FPS),
                "-i", str(frames / "%05d.png"),
                "-vf",
                f"split[a][b];[a]palettegen=max_colors={COLOURS}:reserve_transparent=0[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle",
                "-loop", "0", str(out),
            ],
            check=True,
        )

    print(f"  {out}  {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
