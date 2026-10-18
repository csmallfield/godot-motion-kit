#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Contact sheet of a rendered composition, for reviewing a piece without a reference.

    python3 tools/sheet/sheet.py out/race out/race-sheet.png --every 10
    python3 tools/sheet/sheet.py out/race out/race-beats.png --frames 0,24,48,90,150

Tiles the chosen frames (Movie Maker's f00000000.png ...) with their frame numbers,
and with --motion prints how much each frame differs from the one before: a spike is
a cut or a jump, a run of zeros a hold (or something that forgot to move).
Needs Pillow; --motion also needs numpy.
"""
import argparse, glob, os, re
from PIL import Image, ImageDraw

ap = argparse.ArgumentParser()
ap.add_argument("frames_dir")
ap.add_argument("out")
ap.add_argument("--every", type=int, default=15, help="take every Nth frame")
ap.add_argument("--frames", help="comma-separated frame numbers instead of --every")
ap.add_argument("--cols", type=int, default=5)
ap.add_argument("--width", type=int, default=384, help="tile width in pixels")
ap.add_argument("--motion", action="store_true", help="print per-frame change")
a = ap.parse_args()

files = sorted(glob.glob(os.path.join(a.frames_dir, "f*.png")))
num = lambda p: int(re.search(r"(\d+)\.png$", p).group(1))
by_n = {num(p): p for p in files}
if not by_n:
    raise SystemExit(f"no f*.png frames in {a.frames_dir}")
pick = [int(x) for x in a.frames.split(",")] if a.frames else sorted(by_n)[:: a.every]
pick = [n for n in pick if n in by_n]

first = Image.open(by_n[pick[0]])
tw = a.width; th = round(first.height * tw / first.width)
rows = (len(pick) + a.cols - 1) // a.cols
sheet = Image.new("RGB", (a.cols * (tw + 8) + 8, rows * (th + 26) + 8), (24, 24, 24))
d = ImageDraw.Draw(sheet)
for k, n in enumerate(pick):
    x = 8 + (k % a.cols) * (tw + 8); y = 8 + (k // a.cols) * (th + 26)
    sheet.paste(Image.open(by_n[n]).convert("RGB").resize((tw, th), Image.BILINEAR), (x, y))
    d.text((x, y + th + 4), f"frame {n}  ({n / 30:.2f} s at 30 fps)", fill=(220, 220, 220))
sheet.save(a.out)
print(f"wrote {a.out}: {len(pick)} frames")

if a.motion:
    import numpy as np
    prev = None
    for n in sorted(by_n):
        im = np.asarray(Image.open(by_n[n]).convert("L").resize((480, 270)), dtype=np.float32)
        if prev is not None:
            print(f"{n:5d} {abs(im - prev).mean():7.2f}")
        prev = im
