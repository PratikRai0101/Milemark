#!/usr/bin/env python3
"""Captures a close-up of the receipt's action bar, so the Liquid Glass can be
seen rather than taken on trust.

The bar is found by looking for the row with the most ink in it, so the crop
lands on the buttons however the receipt is laid out.

Usage: python3 design/capture-glass.py [device name]
"""
import pathlib
import sys

from PIL import Image, ImageDraw, ImageFont

ROOT = pathlib.Path(__file__).resolve().parent.parent
SHOTS = ROOT / ".captures"
OUT = ROOT / "Screenshots"

source = SHOTS / "02-receipt-route.png"
if not source.exists():
    sys.exit("Run design/capture-screenshots.sh first.")

device = sys.argv[1] if len(sys.argv) > 1 else "iPhone 17 Pro"

image = Image.open(source).convert("RGB")
width, height = image.size

# The Save button is solid ink, so the row with the most ink is the bar.
best_row, best_ink = 0, 0
for y in range(0, height, 4):
    ink = sum(1 for x in range(0, width, 6) if sum(image.getpixel((x, y))) < 180)
    if ink > best_ink:
        best_ink, best_row = ink, y

crop_height = 250
top = max(0, best_row - 165)
crop = image.crop((0, top, width, min(height, top + crop_height)))

# The plate the close-up sits on.
padding = 44
caption_height = 62
plate = Image.new("RGB", (width + padding * 2, crop.height + caption_height + padding), (233, 233, 230))
plate.paste(crop, (padding, padding))
draw = ImageDraw.Draw(plate)

font_path = "/System/Library/Fonts/SFNS.ttf"
try:
    font = ImageFont.truetype(font_path, 15)
except OSError:
    font = ImageFont.load_default()

caption = "THE ACTION BAR — LIQUID GLASS, WHERE THE SYSTEM PROVIDES IT"
text_y = padding + crop.height + 20
draw.text((padding, text_y), caption, font=font, fill=(110, 113, 107))

OUT.mkdir(parents=True, exist_ok=True)
target = OUT / "glass-action-bar.png"
plate.save(target)
print(f"  {target}")
print(f"  captured on {device}")
