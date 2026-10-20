#!/usr/bin/env python3
"""Checks that every image and link in the readme points at something that
exists.

A readme that links to a file that was removed is worse than one that says
nothing, and the screenshots change often enough for it to happen.

Usage: python3 design/check-readme.py
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
README = ROOT / "README.md"

text = README.read_text()

# Images: both the html form and the markdown form.
images = re.findall(r'<img[^>]*\ssrc="([^"]+)"', text)
images += re.findall(r'!\[[^\]]*\]\(([^)\s]+)', text)

# Ordinary links, which are never a web address here.
links = [ref for _, ref in re.findall(r'\[([^\]]*)\]\(([^)]+)\)', text)]

missing = []
for ref in images + links:
    if ref.startswith(("http://", "https://", "#", "mailto:")):
        continue
    if not (ROOT / ref).exists():
        missing.append(ref)

if missing:
    print("The readme points at files that do not exist:", file=sys.stderr)
    for ref in sorted(set(missing)):
        print(f"  {ref}", file=sys.stderr)
    raise SystemExit(1)

print(f"The readme is sound: {len(images)} images and {len(links)} links all resolve.")
