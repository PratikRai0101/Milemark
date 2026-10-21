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
SCREEN_WIDTH = 234

# The demo is mostly still frames, so a low frame rate and a small palette
# hold the file down without the motion reading as choppy.
FPS = 8
COLOURS = 64


def frame_device(screen: Image.Image) -> Image.Image:
    """Puts a screen inside the drawn iPhone."""
    return device.draw_device(screen, background=device.GITHUB_DARK)


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

        for shot in shots:
            device = frame_device(Image.open(shot))
            device.save(shot)

        subprocess.run(
            [
                "ffmpeg", "-y", "-v", "error", "-framerate", str(FPS),
                "-i", str(frames / "%05d.png"),
                "-vf",
                f"split[a][b];[a]palettegen=max_colors={COLOURS}[p];[b][p]paletteuse=dither=bayer:bayer_scale=4",
                "-loop", "0", str(out),
            ],
            check=True,
        )

    print(f"  {out}  {out.stat().st_size // 1024} KB")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
