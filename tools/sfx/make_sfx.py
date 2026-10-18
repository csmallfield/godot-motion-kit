#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Synthesise the demo's cue sounds (no samples, no licences): whoosh, blip, hit, pop, tick.

    python3 tools/sfx/make_sfx.py demo/assets/audio/sfx

Each sound starts at sample 0 (no lead-in), so a cue's frame is where you hear it.
Needs numpy.
"""
import sys, os, wave
import numpy as np

SR = 44100
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def env(n, attack, decay):
    """Linear attack then exponential decay, over n samples."""
    e = np.exp(-np.arange(n) / (decay * SR))
    a = max(1, int(attack * SR))
    e[:a] *= np.linspace(0.0, 1.0, a)
    return e


def lowpass(x, cutoff):
    """One-pole low-pass with a per-sample cutoff in Hz."""
    y = np.zeros_like(x)
    c = np.broadcast_to(cutoff, x.shape)
    acc = 0.0
    for i in range(len(x)):
        a = 1.0 - np.exp(-2 * np.pi * c[i] / SR)
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def whoosh():
    tt = t(0.55)
    n = rng.standard_normal(len(tt))
    sweep = 300 + 5000 * np.sin(np.pi * tt / tt[-1]) ** 2
    shape = np.sin(np.pi * np.clip(tt / 0.55, 0, 1)) ** 1.5
    return lowpass(n, sweep) * shape * 0.9


def blip():
    tt = t(0.18)
    tone = np.sign(np.sin(2 * np.pi * 880 * tt)) * 0.35 + np.sin(2 * np.pi * 1760 * tt) * 0.25
    return tone * env(len(tt), 0.002, 0.05)


def hit():
    tt = t(0.9)
    f = 180 * np.exp(-tt * 9) + 45
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.001, 0.28)
    crack = lowpass(rng.standard_normal(len(tt)), 6000) * env(len(tt), 0.0005, 0.03)
    return body * 0.9 + crack * 0.5


def pop():
    tt = t(0.14)
    f = 500 + 1400 * (tt / tt[-1])
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * env(len(tt), 0.001, 0.04) * 0.7


def tick():
    tt = t(0.05)
    return lowpass(rng.standard_normal(len(tt)), 9000) * env(len(tt), 0.0003, 0.008) * 0.6


def write(path, x):
    x = np.clip(x / max(1e-9, np.abs(x).max()) * 0.89, -1, 1)
    with wave.open(path, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR)
        w.writeframes((x * 32767).astype("<i2").tobytes())


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "."
    os.makedirs(out, exist_ok=True)
    for name, fn in [("whoosh", whoosh), ("blip", blip), ("hit", hit), ("pop", pop), ("tick", tick)]:
        write(os.path.join(out, name + ".wav"), fn())
        print("wrote", os.path.join(out, name + ".wav"))
