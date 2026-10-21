"""The phone the screens are shown in.

The simulator records the app's screen and not the phone around it, so the
device is drawn here: a metal edge, the chamfer where the metal turns over,
the black bezel, the screen with the iPhone's own corner radius, the Dynamic
Island, and the home indicator.

One drawing, used by both the still frames and the demo, so the two always
look like the same phone.

Every measurement is a fraction of the screen's width, so the device is the
same shape at any size.
"""

from PIL import Image, ImageDraw

# The rings around the screen, as fractions of the screen's width.
EDGE = 0.0017
CHAMFER = 0.0108
BEZEL = 0.0299

# The screen's own corners, and the device's.
SCREEN_RADIUS = 0.115
OUTER_RADIUS = 0.135

# The Dynamic Island, as fractions of the screen. On the iPhone 17e it is
# 125 pt wide on a 390 pt screen, 36.7 pt tall, and 11 pt from the top.
ISLAND_WIDTH = 0.320
ISLAND_HEIGHT = 0.0435
ISLAND_TOP = 0.013

# The home indicator.
INDICATOR_WIDTH = 0.360
INDICATOR_HEIGHT = 0.0052
INDICATOR_BOTTOM = 0.0075

METAL = (214, 222, 226)
CHAMFER_TOP = (182, 178, 174)
CHAMFER_BOTTOM = (126, 124, 120)
BEZEL_COLOUR = (8, 9, 10)
INDICATOR_COLOUR = (150, 150, 150)

# GitHub's canvas in dark mode, #0D1116. The demo is drawn on it so that the
# device sits on the page rather than on a white card.
GITHUB_DARK = (13, 17, 22)


def rounded_mask(size, radius):
    mask = Image.new("L", size, 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255
    )
    return mask


def draw_device(screen, background=None):
    """Puts a screen inside a drawn iPhone.

    The background is what shows around the device. It is `None` for a
    transparent surround, and a colour for an opaque one.
    """
    screen = screen.convert("RGB")
    width, height = screen.size
    edge = max(1, int(width * EDGE))
    chamfer = max(1, int(width * CHAMFER))
    bezel = max(2, int(width * BEZEL))
    radius = int(width * SCREEN_RADIUS)
    mask = rounded_mask(screen.size, radius)

    total = (
        width + 2 * (edge + chamfer + bezel),
        height + 2 * (edge + chamfer + bezel),
    )
    transparent = background is None
    if transparent:
        canvas = Image.new("RGBA", total, (0, 0, 0, 0))
        fill = lambda colour: colour + (255,)
    else:
        canvas = Image.new("RGB", total, background)
        fill = lambda colour: colour

    draw = ImageDraw.Draw(canvas)
    outer = int(width * OUTER_RADIUS)
    draw.rounded_rectangle(
        [0, 0, total[0] - 1, total[1] - 1],
        radius=outer + bezel + chamfer,
        fill=fill(METAL),
    )
    draw.rounded_rectangle(
        [edge, edge, total[0] - 1 - edge, total[1] - 1 - edge],
        radius=outer + bezel,
        fill=fill(CHAMFER_TOP),
    )
    # The chamfer is darker at the bottom, the way metal turns away from the
    # light.
    draw.rounded_rectangle(
        [edge + 1, edge + 1, total[0] - 2 - edge, total[1] - 2 - edge],
        radius=outer + bezel - 1,
        fill=fill(CHAMFER_BOTTOM),
    )
    draw.rounded_rectangle(
        [
            edge + chamfer,
            edge + chamfer,
            total[0] - 1 - edge - chamfer,
            total[1] - 1 - edge - chamfer,
        ],
        radius=int(width * SCREEN_RADIUS),
        fill=fill(BEZEL_COLOUR),
    )

    origin = (edge + chamfer + bezel, edge + chamfer + bezel)
    if transparent:
        screen_rgba = screen.convert("RGBA")
        screen_rgba.putalpha(mask)
        canvas.alpha_composite(screen_rgba, origin)
    else:
        flat = Image.new("RGB", screen.size, (0, 0, 0))
        flat.paste(screen, (0, 0), mask)
        canvas.paste(flat, origin)

    draw = ImageDraw.Draw(canvas)

    # The Dynamic Island, which the simulator does not draw.
    island_w = int(width * ISLAND_WIDTH)
    island_h = max(3, int(height * ISLAND_HEIGHT))
    island_x = origin[0] + (width - island_w) // 2
    island_y = origin[1] + int(height * ISLAND_TOP)
    draw.rounded_rectangle(
        [island_x, island_y, island_x + island_w, island_y + island_h],
        radius=island_h // 2,
        fill=fill((0, 0, 0)),
    )

    # The home indicator, which the simulator does not draw either.
    bar_w = int(width * INDICATOR_WIDTH)
    bar_h = max(2, int(height * INDICATOR_HEIGHT))
    bar_x = origin[0] + (width - bar_w) // 2
    bar_y = origin[1] + height - int(height * INDICATOR_BOTTOM) - bar_h
    draw.rounded_rectangle(
        [bar_x, bar_y, bar_x + bar_w, bar_y + bar_h],
        radius=bar_h // 2,
        fill=fill(INDICATOR_COLOUR),
    )
    return canvas
