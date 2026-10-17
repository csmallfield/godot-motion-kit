#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Compare a Godot Movie Maker render with a Remotion render, frame by frame.

  python3 compare.py <remotion_dir> <godot_dir> <out_dir> [--frames 20,60,120] [--label E1]

remotion_dir holds element-000.png ... (Remotion renderFrames); godot_dir holds
f00000000.png ... (Godot --write-movie). Writes to out_dir:
  ssim.csv            per-frame SSIM (luma, 1/2 scale) and mean absolute error
  ssim.png            SSIM across the piece
  sheet.png           contact sheet: Remotion | Godot | difference, at the key frames
  side_by_side.mp4    both renders next to each other (needs ffmpeg)
"""
import argparse, csv, os, subprocess, sys
import numpy as np
from PIL import Image, ImageDraw, ImageFont
from skimage.metrics import structural_similarity

ap = argparse.ArgumentParser()
ap.add_argument("remotion"); ap.add_argument("godot"); ap.add_argument("out")
ap.add_argument("--frames", default="")
ap.add_argument("--label", default="")
ap.add_argument("--fps", type=int, default=30)
ap.add_argument("--no-video", action="store_true")
a = ap.parse_args()
os.makedirs(a.out, exist_ok=True)

rem = sorted(f for f in os.listdir(a.remotion) if f.endswith(".png"))
god = sorted(f for f in os.listdir(a.godot) if f.endswith(".png"))
n = min(len(rem), len(god))
print(f"{a.label}: {len(rem)} Remotion frames, {len(god)} Godot frames, comparing {n}")

def load(path, scale=0.5):
    im = Image.open(path).convert("RGB")
    if scale != 1:
        im = im.resize((int(im.width * scale), int(im.height * scale)), Image.BILINEAR)
    return np.asarray(im, dtype=np.float32) / 255.0

rows = []
for i in range(n):
    r = load(os.path.join(a.remotion, rem[i])); g = load(os.path.join(a.godot, god[i]))
    lr = r @ [0.299, 0.587, 0.114]; lg = g @ [0.299, 0.587, 0.114]
    s = structural_similarity(lr, lg, data_range=1.0)
    mae = float(np.abs(r - g).mean())
    rows.append((i, s, mae))
with open(os.path.join(a.out, "ssim.csv"), "w", newline="") as fh:
    w = csv.writer(fh); w.writerow(["frame", "ssim", "mae"]); w.writerows(rows)
ss = np.array([r[1] for r in rows]); ma = np.array([r[2] for r in rows])
print(f"SSIM mean {ss.mean():.4f}  median {np.median(ss):.4f}  min {ss.min():.4f} at frame {int(ss.argmin())}")
print(f"frames with SSIM < 0.95: {int((ss < 0.95).sum())}   < 0.90: {int((ss < 0.90).sum())}")

# SSIM plot (drawn with PIL to avoid a matplotlib dependency)
W, H, L, B = 1600, 420, 70, 50
im = Image.new("RGB", (W, H), "white"); d = ImageDraw.Draw(im)
lo = 0.8
def Y(v): return H - B - (max(v, lo) - lo) / (1 - lo) * (H - B - 30)
def X(i): return L + i / max(1, n - 1) * (W - L - 30)
for v in (0.8, 0.85, 0.9, 0.95, 1.0):
    d.line([(L, Y(v)), (W - 30, Y(v))], fill=(225, 225, 225)); d.text((10, Y(v) - 7), f"{v:.2f}", fill=(90, 90, 90))
for sec in range(0, n // a.fps + 1):
    x = X(sec * a.fps); d.line([(x, H - B), (x, H - B + 6)], fill=(90, 90, 90)); d.text((x - 6, H - B + 10), f"{sec}s", fill=(90, 90, 90))
d.line([(X(i), Y(v)) for i, v in enumerate(ss)], fill=(27, 99, 147), width=2)
d.text((L, 8), f"{a.label} SSIM per frame, Remotion vs Godot (mean {ss.mean():.3f}, min {ss.min():.3f})", fill=(0, 0, 0))
im.save(os.path.join(a.out, "ssim.png"))

# Contact sheet
frames = [int(x) for x in a.frames.split(",") if x] or list(np.linspace(0, n - 1, 8).astype(int))
tw, th = 480, 270
sheet = Image.new("RGB", (tw * 3 + 40, (th + 30) * len(frames) + 40), (30, 30, 30)); sd = ImageDraw.Draw(sheet)
sd.text((10, 10), f"{a.label}   Remotion | Godot | difference x4", fill=(240, 240, 240))
for k, fr in enumerate(frames):
    fr = min(fr, n - 1)
    r = Image.open(os.path.join(a.remotion, rem[fr])).convert("RGB").resize((tw, th), Image.BILINEAR)
    g = Image.open(os.path.join(a.godot, god[fr])).convert("RGB").resize((tw, th), Image.BILINEAR)
    diff = np.clip(np.abs(np.asarray(r, np.int16) - np.asarray(g, np.int16)) * 4, 0, 255).astype(np.uint8)
    y = 40 + k * (th + 30)
    sheet.paste(r, (10, y)); sheet.paste(g, (20 + tw, y)); sheet.paste(Image.fromarray(diff), (30 + 2 * tw, y))
    sd.text((10, y + th + 4), f"frame {fr}   SSIM {ss[fr]:.3f}", fill=(220, 220, 220))
sheet.save(os.path.join(a.out, "sheet.png"))

if not a.no_video:
    out = os.path.join(a.out, "side_by_side.mp4")
    wav = os.path.join(a.godot, "f.wav")
    cmd = ["ffmpeg", "-y", "-loglevel", "error", "-framerate", str(a.fps), "-i", os.path.join(a.remotion, "element-%03d.png"),
           "-framerate", str(a.fps), "-i", os.path.join(a.godot, "f%08d.png")]
    if os.path.exists(wav): cmd += ["-i", wav]
    cmd += ["-filter_complex",
            "[0:v]scale=960:540,drawtext=text='Remotion':x=20:y=20:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.5[a];"
            "[1:v]scale=960:540,drawtext=text='Godot Motion Kit':x=20:y=20:fontsize=28:fontcolor=white:box=1:boxcolor=black@0.5[b];"
            "[a][b]hstack[v]", "-map", "[v]"]
    if os.path.exists(wav): cmd += ["-map", "2:a", "-c:a", "aac", "-b:a", "192k", "-shortest"]
    cmd += ["-c:v", "libx264", "-crf", "18", "-pix_fmt", "yuv420p", out]
    subprocess.run(cmd, check=True)
    print("wrote", out)
