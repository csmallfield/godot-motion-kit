#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for FTF take 3, RISO (demo/ftf/ftf_riso/ftf_riso.gd): press effects,
the cue map and a 100 bpm dub groove, for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_riso/audio/make.py

Sound sheet (a print shop: dry, mechanical, a small room; music ducks under the press):
  feed      paper feeding into the press: a fast rattle and a papery swish
  print     one plate printing: a low plate thunk, the roller's ratcheting rumble
            and a brown-noise roll (pitch per plate, from cue data)
  slam      the pink plate slamming in far off register: a heavier thunk and slap
  register  every plate clamping home: a hard wood clack, a metal bar ring, a sub
  sheet     the sheet pulled out and a new one fed in: a long swish with paper flutter
  slur      the lime plate's second impression: a soft double tap
  stamp     the approval stamp: a dead, heavy thump with a papery slap
  flood     the black flood roller: a rumbling roll building over two beats
  end       the last hit on black: a deep thud with a low bell that rings out
Music: 100 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 72 frames.
  intro  bar 0          the press ticking, one bass note and an electric-piano chord
  groove bars 1-1.75    boom-bap kick and snare (snare echoes), swung hats, dub bass
  break  bar 1.75-2     press and a chord only (the sheet change)
  build  bars 2-3       kick, hats, press; the bass filter opens
  full   bars 3-4.5     everything, plus a metal bell line (the FTF hold)
  flood  bars 4.5-5     kick and bass closing down under the flood
  tail   bars 5-5.83    silence; the end hit rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_riso/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "feed": dict(voice="ratchet", params={"length_s": 0.42, "start_rate_hz": 70.0, "end_rate_hz": 34.0, "click_hz": 2400.0, "q": 2.5, "jitter": 0.25, "fade": 0.5},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.45, "low_hz": 600.0, "high_hz": 5500.0, "peak": 0.45, "noise": "&pink"}, "gain_db": -5.0}],
                 bind=level(-16.0, -7.0), send=0.12, seed=301),
    "print": dict(voice="boing", params={"start_hz": 150.0, "end_hz": 58.0, "drop_s": 0.05, "decay_s": 0.14, "sub": 0.4, "click": 0.55, "click_hz": 3500.0},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 0.34, "start_rate_hz": 95.0, "end_rate_hz": 60.0, "click_hz": 1700.0, "q": 2.0, "jitter": 0.15, "fade": 0.4}, "gain_db": -7.0, "offset_s": 0.01},
                          {"voice": "&whoosh", "params": {"length_s": 0.34, "low_hz": 120.0, "high_hz": 1400.0, "peak": 0.4, "noise": "&brown"}, "gain_db": -6.0}],
                  bind=pitched(-11.0, -3.0), vary={"decay_s": 0.1}, send=0.1, seed=302),
    "slam": dict(voice="boing", params={"start_hz": 200.0, "end_hz": 48.0, "drop_s": 0.04, "decay_s": 0.22, "sub": 0.8, "click": 0.9, "click_hz": 5000.0},
                 layers=[{"voice": "&snare", "params": {"tone_hz": 160.0, "tone": 0.3, "noise": 1.0, "noise_hz": 3500.0, "noise_decay_s": 0.09}, "gain_db": -5.0}],
                 bind=level(-6.0, 0.0), send=0.12, seed=303),
    "register": dict(voice="click", params={"freq_hz": 1900.0, "mode": "&band", "q": 14.0, "decay_s": 0.02, "body_hz": 110.0, "body": 0.9},
                     layers=[{"voice": "&mallet", "params": {"freq_hz": 233.0, "material": "&bar", "hardness": 0.9, "decay_s": 0.35}, "gain_db": -6.0},
                             {"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 45.0, "drop_s": 0.06, "decay_s": 0.25, "sub": 1.0, "click": 0.0}, "gain_db": -5.0}],
                     bind=pitched(-6.0, 0.0), send=0.15, seed=304),
    "sheet": dict(voice="whoosh", params={"length_s": 0.75, "low_hz": 400.0, "high_hz": 6500.0, "peak": 0.35, "shape": 1.6, "noise": "&pink"},
                  layers=[{"voice": "&static", "params": {"length_s": 0.6, "hiss": 0.25, "color_hz": 3000.0, "crackles_per_s": 120.0, "crackle": 0.7, "flicker_hz": 22.0, "flicker_depth": 0.8, "fade_s": 0.05}, "gain_db": -9.0},
                          {"voice": "&ratchet", "params": {"length_s": 0.5, "start_rate_hz": 30.0, "end_rate_hz": 80.0, "click_hz": 2600.0, "q": 3.0, "fade": 0.2}, "gain_db": -10.0, "offset_s": 0.25}],
                  bind=level(-12.0, -3.0), send=0.15, seed=305),
    "slur": dict(voice="click", params={"freq_hz": 1200.0, "mode": "&band", "q": 6.0, "decay_s": 0.012, "body_hz": 90.0, "body": 0.6},
                 fx=[{"type": "echo", "time_s": 0.06, "feedback": 0.2, "mix": 0.5, "tail_s": 0.2}],
                 bind=level(-16.0, -8.0), seed=306),
    "stamp": dict(voice="boing", params={"start_hz": 95.0, "end_hz": 42.0, "drop_s": 0.03, "decay_s": 0.12, "sub": 0.9, "click": 1.0, "click_hz": 2200.0},
                  layers=[{"voice": "&snare", "params": {"tone_hz": 140.0, "tone": 0.6, "noise": 0.7, "noise_hz": 2500.0, "noise_decay_s": 0.06}, "gain_db": -6.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 4500.0}],
                  bind=level(-5.0, 0.0), send=0.1, seed=307),
    "flood": dict(voice="whoosh", params={"length_s": 1.25, "low_hz": 80.0, "high_hz": 1800.0, "peak": 0.85, "shape": 1.2, "noise": "&brown"},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 1.2, "start_rate_hz": 30.0, "end_rate_hz": 110.0, "click_hz": 1400.0, "q": 2.0, "jitter": 0.2, "fade": 0.0}, "gain_db": -8.0}],
                  bind=level(-10.0, -2.0), send=0.12, seed=308),
    "end": dict(voice="kick", params={"tune_hz": 42.0, "punch": 4.0, "drop_s": 0.05, "decay_s": 0.7, "click": 0.6, "drive": 0.4},
                layers=[{"voice": "&mallet", "params": {"freq_hz": 146.83, "material": "&bar", "hardness": 0.5, "decay_s": 1.1}, "gain_db": -6.0},
                        {"voice": "&boing", "params": {"start_hz": 90.0, "end_hz": 36.0, "drop_s": 0.2, "decay_s": 0.6, "sub": 1.0, "click": 0.0}, "gain_db": -6.0}],
                bind=level(-3.0, 0.0), send=0.3, seed=309),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "riso_map.tres"), {name: R + name + ".tres" for name in fx},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.22, "damp": 0.65, "width": 0.8, "quality": "&full", "return_db": -4.0}, end_fade_s=0.4)
with open(os.path.join(D, "riso_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music: 100 bpm dub
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 52.0, "punch": 3.0, "decay_s": 0.34, "click": 0.35, "drive": 0.3}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=402, send=0.2,
       params={"tone_hz": 180.0, "tone": 0.55, "noise": 0.8, "noise_hz": 4200.0, "noise_decay_s": 0.18},
       fx=[{"type": "echo", "time_s": 0.45, "feedback": 0.38, "mix": 0.3, "tail_s": 1.2}],
       bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=403, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.035, "tone_hz": 8000.0, "metal": 0.45}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "press.tres"), voice="click", seed=404, vary={"freq_hz": 0.08}, vary_variants=4,
       params={"freq_hz": 2800.0, "mode": "&band", "q": 7.0, "decay_s": 0.01, "body_hz": 180.0, "body": 0.4}, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=405,
       params={"position": 0.22, "sub": 0.55, "cutoff_hz": 520.0, "env_octaves": 1.4, "filter_decay_s": 0.2, "q": 1.4,
               "attack_s": 0.004, "decay_s": 0.3, "sustain": 0.55, "release_s": 0.06}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "ep.tres"), voice="fm", seed=406, send=0.3,
       params={"ratio": 1.0, "index": 2.6, "index_end": 0.25, "index_decay_s": 0.25, "attack_s": 0.003, "decay_s": 0.5, "sustain": 0.0, "release_s": 0.2},
       fx=[{"type": "echo", "time_s": 0.45, "feedback": 0.3, "mix": 0.25, "tail_s": 1.0}])
recipe(os.path.join(MD, "bell.tres"), voice="mallet", seed=407, send=0.25,
       params={"material": "&metal", "hardness": 0.55, "decay_s": 0.5}, bind=level(-10.0, 0.0))

kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X......x..X.....", "length": 16}
snare = {"name": "snare", "recipe": M + "snare.tres", "steps": "....X.......X..o", "length": 16, "gain_db": -2.0}
hat = {"name": "hat", "recipe": M + "hat.tres", "steps": ".o.x.o.x.o.x.oox", "length": 16, "gain_db": -12.0, "pan": 0.2}
press = {"name": "press", "recipe": M + "press.tres", "steps": "X.o.x.o.X.o.x.oo", "length": 16, "gain_db": -16.0, "pan": -0.25}
bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "X.....x...X..x..X.....x...X.....", "length": 32,
        "notes": [38, 38, 41, 36, 34, 34, 36, 33], "gate": 0.9, "gain_db": -2.0}
ep = {"name": "ep", "recipe": M + "ep.tres", "steps": "......x.......x.......x.......x.", "length": 32,
      "notes": ["D4", "D4", "A#3", "A#3"], "chord": [0, 7, 10, 15], "gate": 1.5, "gain_db": -12.0}
bell = {"name": "bell", "recipe": M + "bell.tres", "steps": "x..x..x...x.x...x..x....x.x.x...", "length": 32,
        "notes": ["A5", "F5", "D5", "C5", "D5", "A4", "C5", "D5", "F5", "G5"], "gain_db": -15.0, "pan": 0.3}
bass_hit = {"name": "bass", "recipe": M + "bass.tres", "steps": "X...............", "length": 16, "notes": [38], "gate": 3.0, "gain_db": -3.0}
ep_hit = {"name": "ep", "recipe": M + "ep.tres", "steps": "x...............", "length": 16, "notes": ["D4"], "chord": [0, 7, 10, 15], "gate": 2.0, "gain_db": -12.0}
kick_build = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.......X.......", "length": 16}

P = "AKPattern"
pat = lambda name, steps, lanes, swing=0.58: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                                      {"steps": steps, "seed": len(name) + 40, "swing": swing, "lanes": lanes}, typed={"lanes"})
pat("intro", 16, [press, bass_hit, ep_hit])
pat("groove", 32, [kick, snare, hat, press, bass])
pat("brk", 16, [press, ep_hit])
pat("build", 32, [kick_build, hat, press, bass])
pat("full", 32, [kick, snare, hat, press, bass, ep, bell])
pat("flood", 16, [kick_build, bass])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 100.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "riso_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"]},
        {"name": "groove", "bars": 0.75, "patterns": [M + "groove.tres"]},
        {"name": "break", "bars": 0.25, "patterns": [M + "brk.tres"]},
        {"name": "build", "bars": 1.0, "patterns": [M + "build.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 300.0], [1.0, 900.0]]}},
        {"name": "full", "bars": 1.5, "patterns": [M + "full.tres"]},
        {"name": "flood", "bars": 0.5, "patterns": [M + "flood.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 600.0], [1.0, 150.0]], "bass.gain_db": [[0.0, 0.0], [1.0, -10.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -8.0]]}},
        {"name": "tail", "bars": 0.8334, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, riso_map.tres and the 100 bpm song" % len(fx))
