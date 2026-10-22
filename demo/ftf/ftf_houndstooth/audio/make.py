#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Houndstooth take (demo/ftf/ftf_houndstooth/): effect recipes,
the cue map and a 120 bpm runway-house bed, for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_houndstooth/audio/make.py

Sound sheet (shared reverb 0.4, a dry-ish catwalk room; music ducks 6 dB):
  open      a bolt of cloth unrolling: low brown-noise swish and a soft thump
  weave     a sewing machine: a fast needle ratchet over a motor hum (pitch in data)
  turn      a short dial ratchet and a wooden tick: tiles turning 45 degrees
  colour    a soft A-minor electric-piano chord as the colours run in
  part      tailor's scissors: two blade clicks, a metal shing and a soft boom
  label     a woven label slid out: a short band swish and a tick
  bulge     a slow rubbery whomp as the cloth swells
  pull      cloth yanked away: a big rising pink-noise swish
  sweep     a fabric swish with a pitched wooden tick: colourway changes
  tighten   a zip pulled tight
  riser     saw glide and noise swelling for 1.6 s, peaking on the drop
  snip      scissors: two blade clicks and a glass ping
  drop      the runway drop: driven kick, sub, a minor-seventh stab and a crack
  tag       a swing tag dropping: wooden knock and a tiny click (pitched)
  ripple    a glassy shimmer as a ripple runs out through the cloth
  zip       a zipper as the labels leave
  collapse  a long sine dive with a dark swish as the tiles shrink away
  blip      the last tile: a glass ping over a soft sub
Music: 120 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 60 frames.
  intro   bar 0        pad, shaker, a soft kick on the one
  mh      bar 1        four-on-the-floor kick, organ bass, pad, shaker
  build   bars 2-3.75  + clap, open hats; the bass filter opens
  break   last beat    a snare roll into the drop
  drop    bars 4-5.6   everything + minor-seventh stabs on the offbeats
  outro   0.8 bar      kick and bass closing down
  tail    0.6 bar      silence; the blip rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_houndstooth/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

blade = lambda off: {"voice": "&click", "params": {"freq_hz": 5200.0, "mode": "&band", "q": 7.0, "decay_s": 0.004}, "gain_db": -2.0, "offset_s": off}

fx = {
    "open": dict(voice="whoosh", params={"length_s": 0.55, "low_hz": 120.0, "high_hz": 2600.0, "peak": 0.55, "shape": 1.6, "noise": "&brown"},
                 layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 48.0, "drop_s": 0.08, "decay_s": 0.25, "sub": 0.6, "click": 0.1}, "gain_db": -6.0, "offset_s": 0.25}],
                 bind=level(-10.0, -3.0), send=0.25, seed=801),
    "weave": dict(voice="ratchet", params={"length_s": 0.55, "start_rate_hz": 30.0, "end_rate_hz": 34.0, "click_hz": 2300.0, "q": 3.5, "click_decay_s": 0.006,
                  "jitter": 0.04, "accent_every": 2.0, "fade": 0.2},
                  layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 96.0, "attack_s": 0.02, "decay_s": 0.3, "sustain": 0.6, "gate_s": 0.5, "release_s": 0.05, "length_s": 0.6}, "gain_db": -14.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 5000.0}],
                  bind=pitched(-14.0, -5.0), send=0.15, seed=802),
    "turn": dict(voice="ratchet", params={"length_s": 0.16, "start_rate_hz": 70.0, "end_rate_hz": 50.0, "click_hz": 4200.0, "q": 4.0, "fade": 0.5},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 880.0, "material": "&wood", "hardness": 0.6, "decay_s": 0.12}, "gain_db": -6.0, "offset_s": 0.12}],
                 bind=pitched(-16.0, -7.0), send=0.2, seed=803),
    "colour": dict(voice="fm", params={"freq_hz": 440.0, "ratio": 1.0, "index": 2.2, "index_end": 0.4, "index_decay_s": 0.3, "decay_s": 0.9, "sustain": 0.0, "gate_s": 0.6, "release_s": 0.3},
                   layers=[{"voice": "&fm", "params": {"freq_hz": 523.25, "ratio": 1.0, "index": 2.0, "index_end": 0.4, "index_decay_s": 0.3, "decay_s": 0.9, "gate_s": 0.6, "release_s": 0.3}, "gain_db": -2.0},
                           {"voice": "&fm", "params": {"freq_hz": 659.25, "ratio": 1.0, "index": 1.8, "index_end": 0.4, "index_decay_s": 0.3, "decay_s": 0.9, "gate_s": 0.6, "release_s": 0.3}, "gain_db": -3.0}],
                   bind=level(-14.0, -6.0), send=0.45, seed=804),
    "part": dict(voice="boing", params={"start_hz": 130.0, "end_hz": 52.0, "drop_s": 0.08, "decay_s": 0.3, "sub": 0.7, "click": 0.0},
                 layers=[blade(0.0), blade(0.07),
                         {"voice": "&mallet", "params": {"freq_hz": 2637.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.35}, "gain_db": -12.0, "offset_s": 0.07}],
                 bind=level(-6.0, -1.0), send=0.3, seed=805),
    "label": dict(voice="whoosh", params={"length_s": 0.2, "low_hz": 700.0, "high_hz": 5500.0, "peak": 0.6, "mode": "&band", "q": 1.0},
                  layers=[{"voice": "&click", "params": {"freq_hz": 3000.0, "mode": "&band", "q": 3.0, "decay_s": 0.004}, "gain_db": -8.0, "offset_s": 0.17}],
                  bind=level(-16.0, -8.0), send=0.2, seed=806),
    "bulge": dict(voice="boing", params={"start_hz": 95.0, "end_hz": 55.0, "drop_s": 0.22, "decay_s": 0.45, "wobble_hz": 3.5, "wobble_semitones": 3.0, "sub": 0.5, "click": 0.0},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 0.5, "low_hz": 150.0, "high_hz": 1200.0, "peak": 0.4, "noise": "&brown"}, "gain_db": -8.0}],
                  bind=level(-12.0, -4.0), send=0.3, seed=807),
    "pull": dict(voice="whoosh", params={"length_s": 0.4, "low_hz": 300.0, "high_hz": 7000.0, "peak": 0.75, "shape": 2.0, "noise": "&pink"},
                 bind=level(-10.0, -2.0), send=0.25, offset_s=-0.1, seed=808),
    "sweep": dict(voice="whoosh", params={"length_s": 0.32, "low_hz": 800.0, "high_hz": 6500.0, "peak": 0.5, "mode": "&band", "q": 0.9, "noise": "&pink"},
                  layers=[{"voice": "&mallet", "params": {"freq_hz": 659.25, "material": "&wood", "hardness": 0.7, "decay_s": 0.14}, "gain_db": -5.0}],
                  bind=pitched(-14.0, -6.0), vary={"high_hz": 0.15}, send=0.25, seed=809),
    "tighten": dict(voice="ratchet", params={"length_s": 0.38, "start_rate_hz": 22.0, "end_rate_hz": 95.0, "click_hz": 5200.0, "q": 5.0, "fade": 0.1},
                    bind=level(-14.0, -6.0), seed=810),
    "riser": dict(voice="tone", params={"wave": "&saw", "freq_hz": 180.0, "end_hz": 1500.0, "glide_s": 0.8, "attack_s": 1.3, "decay_s": 0.3, "sustain": 1.0, "gate_s": 1.6, "release_s": 0.004, "length_s": 1.6},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 1.6, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.97, "shape": 3.0, "noise": "&pink"}, "gain_db": -2.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 6500.0, "slope_db": 12.0}],
                  bind=level(-14.0, -6.0), send=0.15, offset_s=-1.6, seed=811),
    "snip": dict(voice="click", params={"freq_hz": 5200.0, "mode": "&band", "q": 7.0, "decay_s": 0.004},
                 layers=[blade(0.06), {"voice": "&mallet", "params": {"freq_hz": 1975.5, "material": "&glass", "hardness": 0.7, "decay_s": 0.3}, "gain_db": -9.0, "offset_s": 0.06}],
                 bind=pitched(-10.0, -3.0), send=0.3, seed=812),
    "drop": dict(voice="kick", params={"tune_hz": 46.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.55, "click": 0.7, "drive": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 150.0, "end_hz": 40.0, "drop_s": 0.14, "decay_s": 0.5, "sub": 1.0, "click": 0.0}, "gain_db": -5.0},
                         {"voice": "&fm", "params": {"freq_hz": 220.0, "ratio": 1.0, "index": 3.0, "index_end": 0.5, "index_decay_s": 0.2, "decay_s": 0.5, "gate_s": 0.3, "release_s": 0.2}, "gain_db": -8.0},
                         {"voice": "&fm", "params": {"freq_hz": 261.63, "ratio": 1.0, "index": 3.0, "index_end": 0.5, "index_decay_s": 0.2, "decay_s": 0.5, "gate_s": 0.3, "release_s": 0.2}, "gain_db": -9.0},
                         {"voice": "&fm", "params": {"freq_hz": 392.0, "ratio": 1.0, "index": 3.0, "index_end": 0.5, "index_decay_s": 0.2, "decay_s": 0.5, "gate_s": 0.3, "release_s": 0.2}, "gain_db": -10.0},
                         {"voice": "&snare", "params": {"tone_hz": 200.0, "tone": 0.4, "noise": 0.9, "noise_hz": 6500.0, "noise_decay_s": 0.16}, "gain_db": -6.0}],
                 bind=level(-4.0, 0.0), send=0.35, seed=813),
    "tag": dict(voice="mallet", params={"freq_hz": 523.25, "material": "&wood", "hardness": 0.8, "decay_s": 0.16},
                layers=[{"voice": "&click", "params": {"freq_hz": 6000.0, "mode": "&high", "decay_s": 0.003}, "gain_db": -10.0}],
                bind=pitched(-14.0, -6.0), send=0.25, seed=814),
    "ripple": dict(voice="mallet", params={"freq_hz": 1318.5, "material": "&glass", "hardness": 0.35, "decay_s": 0.45},
                   layers=[{"voice": "&mallet", "params": {"freq_hz": 1975.5, "material": "&glass", "hardness": 0.3, "decay_s": 0.4}, "gain_db": -5.0, "offset_s": 0.05},
                           {"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 1500.0, "high_hz": 9000.0, "peak": 0.3, "mode": "&high"}, "gain_db": -16.0}],
                   bind=level(-18.0, -10.0), send=0.5, seed=815),
    "zip": dict(voice="ratchet", params={"length_s": 0.42, "start_rate_hz": 40.0, "end_rate_hz": 75.0, "click_hz": 6200.0, "q": 5.0, "fade": 0.3},
                bind=level(-16.0, -8.0), seed=816),
    "collapse": dict(voice="tone", params={"wave": "&sine", "freq_hz": 620.0, "end_hz": 55.0, "glide_s": 0.3, "decay_s": 0.9, "sustain": 0.2, "gate_s": 0.9, "release_s": 0.2, "length_s": 1.2},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 1.0, "low_hz": 120.0, "high_hz": 2000.0, "peak": 0.25, "noise": "&brown"}, "gain_db": -6.0}],
                     bind=level(-12.0, -4.0), send=0.3, seed=817),
    "blip": dict(voice="mallet", params={"freq_hz": 1760.0, "material": "&glass", "hardness": 0.6, "decay_s": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 50.0, "drop_s": 0.08, "decay_s": 0.25, "sub": 0.8, "click": 0.1}, "gain_db": -8.0}],
                 bind=level(-8.0, -2.0), send=0.5, seed=818),
}

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "ht_map.tres"), {name: R + name + ".tres" for name in fx},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.4, "damp": 0.5, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.4)
with open(os.path.join(D, "ht_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.25}\n')

# ------------------------------------------------------------------ music (120 bpm, A minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=901,
       params={"tune_hz": 52.0, "punch": 3.2, "decay_s": 0.32, "click": 0.4, "drive": 0.25}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=902, send=0.3,
       params={"color_hz": 1250.0, "tail_decay_s": 0.14}, vary={"color_hz": 0.08}, vary_variants=4, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=903, send=0.2,
       params={"tone_hz": 210.0, "tone": 0.4, "noise": 0.85, "noise_hz": 6000.0, "noise_decay_s": 0.09}, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "ohat.tres"), voice="hat", seed=904, params={"decay_s": 0.2, "tone_hz": 8800.0, "metal": 0.65}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "shaker.tres"), voice="hat", seed=905, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.025, "tone_hz": 11000.0, "metal": 0.15}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "organ.tres"), voice="wavetable", seed=906,
       params={"position": 0.9, "sub": 0.45, "cutoff_hz": 700.0, "env_octaves": 2.2, "filter_decay_s": 0.09, "q": 1.6,
               "attack_s": 0.003, "decay_s": 0.14, "sustain": 0.25, "release_s": 0.04}, bind=level(-9.0, 0.0))
recipe(os.path.join(MD, "stab.tres"), voice="fm", seed=907, send=0.4,
       params={"freq_hz": 220.0, "ratio": 1.0, "index": 2.6, "index_end": 0.5, "index_decay_s": 0.12, "decay_s": 0.22, "sustain": 0.0, "gate_s": 0.15, "release_s": 0.1})
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=908, send=0.5,
       params={"position": 0.45, "unison": 5, "detune_cents": 15.0, "cutoff_hz": 1200.0, "env_octaves": 0.5, "filter_decay_s": 1.0,
               "q": 0.7, "attack_s": 0.4, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.35})

BASS_STEPS = "X..x..x.X..x.x.."
BASS_NOTES = [33, 45, 33, 36, 33, 45, 31]
kick4 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick1 = {"name": "kick", "recipe": M + "kick.tres", "steps": "o...............", "length": 16, "gain_db": -4.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -4.0}
ohat = {"name": "ohat", "recipe": M + "ohat.tres", "steps": "..x...x...x...x.", "length": 16, "gain_db": -12.0, "pan": -0.15}
shaker = {"name": "shaker", "recipe": M + "shaker.tres", "steps": "xoxoxoxoxoxoxoxo", "length": 16, "gain_db": -15.0, "pan": 0.2}
organ = {"name": "organ", "recipe": M + "organ.tres", "steps": BASS_STEPS, "length": 16, "notes": BASS_NOTES, "gate": 0.8, "gain_db": -2.0}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "..x...x...x..x..", "length": 16, "notes": ["A3", "A3", "A3", "G3"], "chord": [0, 3, 7, 10], "gate": 1.0, "gain_db": -9.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 15, "length": 16, "notes": ["A3"], "chord": [0, 3, 7, 12], "gate": 15.0, "gain_db": -11.0}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "3456789X", "length": 8, "gain_db": -3.0}

P = "AKPattern"
pat = lambda name, steps, lanes, swing=0.5: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                                     {"steps": steps, "seed": len(name) + 3, "swing": swing, "lanes": lanes}, typed={"lanes"})
pat("intro", 16, [pad, kick1, shaker], 0.56)
pat("mh", 16, [kick4, organ, pad, shaker], 0.56)
pat("build", 16, [kick4, clap, ohat, shaker, organ], 0.56)
pat("break", 4, [roll])
pat("drop", 16, [kick4, clap, ohat, shaker, organ, stab], 0.56)
pat("outro", 16, [kick4, organ], 0.56)
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 120.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "ht_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"]},
        {"name": "mh", "bars": 1.0, "patterns": [M + "mh.tres"], "automation": {"organ.cutoff_hz": [[0.0, 400.0], [1.0, 650.0]]}},
        {"name": "build", "bars": 1.75, "patterns": [M + "build.tres"],
         "automation": {"organ.cutoff_hz": [[0.0, 500.0], [1.0, 1800.0]], "organ.q": [[0.0, 1.5], [1.0, 4.0]]}},
        {"name": "break", "bars": 0.25, "patterns": [M + "break.tres"]},
        {"name": "drop", "bars": 1.6, "patterns": [M + "drop.tres"],
         "automation": {"organ.cutoff_hz": [[0.0, 1100.0], [0.5, 1600.0], [1.0, 1000.0]]}},
        {"name": "outro", "bars": 0.8, "patterns": [M + "outro.tres"],
         "automation": {"organ.cutoff_hz": [[0.0, 900.0], [1.0, 200.0]], "organ.gain_db": [[0.0, 0.0], [1.0, -12.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -8.0]]}},
        {"name": "tail", "bars": 0.6, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, ht_map.tres and the 120 bpm song" % len(fx))
