"""The iPhone the screens are shown in.

The simulator records the app's screen and not the phone around it, so the
device is drawn here: a titanium band, the black glass behind the display,
and the screen with the corners a real display curves into the body.

The measurements are the iPhone 17 Pro's, in points:

    5 pt   the titanium band
   12 pt   the black glass
   66 pt   the device's own corner radius
   55 pt   the screen's corner radius

The band is not a flat grey. It is a gradient with a bright sheen across the
upper left, the way a milled titanium edge catches the light, and the whole
thing is a single static frame that is composited under every frame of the
demo, so the device cannot wobble between one moment and the next.

One drawing, used by both the still frames and the demo, so the two always
look like the same phone.
"""

import math

from PIL import Image, ImageDraw

GLASS_PT = 12.0
BAND_PT = 5.0
DEVICE_RADIUS_PT = 66.0
SCREEN_RADIUS_PT = 55.0

# The width of the phone the capture came from, in points. The iPhone 17e.
LOGICAL_W = 390

# The Dynamic Island, as fractions of the screen. On the iPhone 17e it is
# 125 pt wide on a 390 pt screen, 36.7 pt tall, and 11 pt from the top.
ISLAND_WIDTH_PT = 125.0
ISLAND_HEIGHT_PT = 36.7
ISLAND_TOP_PT = 11.0

# The home indicator.
INDICATOR_WIDTH_PT = 140.0
INDICATOR_HEIGHT_PT = 5.0
INDICATOR_BOTTOM_PT = 8.0

GLASS = (8, 9, 10)
OUTLINE = (232, 232, 236)
INDICATOR = (150, 150, 150)

# GitHub's canvas in dark mode, #0D1116. The demo is drawn on it so that the
# device sits on the page rather than on a white card.
GITHUB_DARK = (13, 17, 22)


def band_gradient(w, h):
    """Titanium: a soft vertical gradient with a bright upper-left sheen."""
    base = Image.new("RGB", (w, h), (0, 0, 0))
    px = base.load()
    for y in range(h):
        t = y / max(1, h - 1)
        v = int(196 - 74 * t + 26 * math.sin(t * math.pi))
        for x in range(w):
            u = x / max(1, w - 1)
            sheen = int(16 * (1 - u) * math.sin(t * math.pi * 0.8))
            c = max(0, min(255, v + sheen))
            px[x, y] = (c, c - 2, c - 6)
    return base


def frame_parts(screen_w, screen_h, logical_width=LOGICAL_W):
    """The device, the screen's mask, and where the screen goes in it."""
    scale = screen_w / logical_width
    glass = int(round(GLASS_PT * scale))
    band = int(round(BAND_PT * scale))
    w = screen_w + 2 * (glass + band)
    h = screen_h + 2 * (glass + band)
    r_device = int(round(DEVICE_RADIUS_PT * scale))
    r_glass = int(round((DEVICE_RADIUS_PT - BAND_PT) * scale))
    r_screen = int(round(SCREEN_RADIUS_PT * scale))
    off = (band + glass, band + glass)

    canvas = Image.new("RGB", (w, h), (14, 16, 18))
    mask = Image.new("L", (w, h), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, w - 1, h - 1), radius=r_device, fill=255)
    canvas.paste(band_gradient(w, h), (0, 0), mask)

    draw = ImageDraw.Draw(canvas)
    draw.rounded_rectangle(
        (0, 0, w - 1, h - 1),
        radius=r_device,
        outline=OUTLINE,
        width=max(1, int(round(scale * 0.8))),
    )
    draw.rounded_rectangle(
        (band, band, w - band - 1, h - band - 1), radius=r_glass, fill=GLASS
    )

    screen_mask = Image.new("L", (screen_w, screen_h), 0)
    ImageDraw.Draw(screen_mask).rounded_rectangle(
        (0, 0, screen_w - 1, screen_h - 1), radius=r_screen, fill=255
    )
    return canvas, screen_mask, off


def draw_island(device, screen_size, offset, logical_width=LOGICAL_W):
    """Draws the Dynamic Island over a screen.

    The simulator never draws it, so the app has to. It is drawn after the
    screen is composited, because it sits on top of the app's own pixels.
    """
    width, height = screen_size
    scale = width / logical_width
    island_w = int(round(ISLAND_WIDTH_PT * scale))
    island_h = int(round(ISLAND_HEIGHT_PT * scale))
    island_x = offset[0] + (width - island_w) // 2
    island_y = offset[1] + int(round(ISLAND_TOP_PT * scale))
    ImageDraw.Draw(device).rounded_rectangle(
        (island_x, island_y, island_x + island_w, island_y + island_h),
        radius=island_h // 2,
        fill=(0, 0, 0),
    )
    return device


def draw_device(screen, background=None, logical_width=LOGICAL_W, island=False):
    """Puts a screen inside a drawn iPhone.

    The background is what shows around the device. It is `None` for a
    transparent surround, and a colour for an opaque one.
    """
    screen = screen.convert("RGB")
    width, height = screen.size
    frame, mask, off = frame_parts(width, height, logical_width)

    if background is None:
        device = frame.convert("RGBA")
        flat = Image.new("RGB", (width, height), (0, 0, 0))
        flat.paste(screen, (0, 0), mask)
        device.paste(flat, off)
    else:
        device = frame
        device.paste(screen, off, mask)

    if island:
        draw_island(device, (width, height), off, logical_width)
    return device
