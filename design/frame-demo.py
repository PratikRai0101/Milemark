#!/usr/bin/env python3
"""Draws the demo video inside a device.

The simulator records the app's screen, not the phone around it, so the
device is drawn here: a metal edge, a black bezel, and the Dynamic Island
that the iPhone 17e has but the simulator never draws.

The proportions are the same as the still frames, so the demo and the
screens in the readme look like the same phone.

Usage: python3 design/frame-demo.py <video> <out.gif>
"""
import pathlib
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw

# The frame, in pixels at the size the gif is written.
FRAME_WIDTH = 250
# The demo is mostly still frames, so a low frame rate and a small palette
# hold the file down without the motion reading as choppy.
FPS = 8
COLOURS = 64
BEZEL = 8
EDGE = 2
SCREEN_WIDTH = FRAME_WIDTH - 2 * (BEZEL + EDGE)

# The device's own geometry, as fractions of the screen.
# The iPhone 17e's island is 125 pt wide on a 390 pt screen, 36.7 pt tall,
# and 11 pt from the top.
ISLAND_WIDTH = 0.320
ISLAND_HEIGHT = 0.0435
ISLAND_TOP = 0.013
SCREEN_RADIUS = 0.115

SURROUND = (255, 255, 255)
METAL = (214, 222, 226)
CHAMFER = (150, 166, 174)
BEZEL_COLOUR = (4, 6, 9)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return mask


def frame_device(screen: Image.Image) -> Image.Image:
    """Puts a screen inside a drawn phone."""
    width, height = screen.size
    radius = int(SCREEN_WIDTH * SCREEN_RADIUS)

    # The screen with its own corners.
    screen = screen.convert("RGB")
    # The screen's own corners are cut out of the black bezel.
    black = Image.new("RGB", screen.size, (0, 0, 0))
    screen = Image.composite(screen, black, rounded_mask(screen.size, radius))

    # The surround is opaque rather than transparent. A transparent surround
    # costs a great deal in a gif's file size, and the app is a light one, so
    # a light surround is also the one that belongs to it.
    canvas = Image.new(
        "RGB",
        (width + 2 * (BEZEL + EDGE), height + 2 * (BEZEL + EDGE)),
        SURROUND,
    )
    draw = ImageDraw.Draw(canvas)

    outer = (0, 0, canvas.width - 1, canvas.height - 1)
    corner = int(SCREEN_WIDTH * 0.105)
    draw.rounded_rectangle(outer, radius=corner + BEZEL + EDGE, fill=METAL)
    draw.rounded_rectangle(
        [EDGE, EDGE, canvas.width - 1 - EDGE, canvas.height - 1 - EDGE],
        radius=corner + BEZEL,
        fill=CHAMFER,
    )
    draw.rounded_rectangle(
        [EDGE + 1, EDGE + 1, canvas.width - 2 - EDGE, canvas.height - 2 - EDGE],
        radius=corner + BEZEL - 1,
        fill=BEZEL_COLOUR,
    )

    canvas.paste(screen, (EDGE + BEZEL, EDGE + BEZEL))

    # The Dynamic Island, which the simulator does not draw.
    island_w = int(SCREEN_WIDTH * ISLAND_WIDTH)
    island_h = int(height * ISLAND_HEIGHT)
    island_x = EDGE + BEZEL + (SCREEN_WIDTH - island_w) // 2
    island_y = EDGE + BEZEL + int(height * ISLAND_TOP)
    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        [island_x, island_y, island_x + island_w, island_y + island_h],
        radius=island_h // 2,
        fill=(0, 0, 0),
    )
    return canvas


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
