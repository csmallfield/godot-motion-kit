#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Greebles take (demo/ftf/ftf_greebles): effect recipes, the cue
map and a 75 bpm half-time bed. Needs the audio kit linked (tools/link_audio_kit.sh).
Regenerate:  python3 demo/ftf/ftf_greebles/audio/make.py

Sound sheet (a vast open sky: long airy reverb, heavy stone and metal; music ducks 7 dB):
  air        a long wind swell as we pull back off the stone face
  clank      a heavy metal clunk with a sub, per layer sliding home (pitched)
  settle     a deep boom and brown-noise rumble: the lockup lands
  servo      hydraulic servo: ratchet + rising saw whine + band whoosh (hatch opens)
  lamp       two glass notes as PRESENTS lights
  riser      a 1.6 s noise-and-saw swell from the dive, cut dead on the drop
  alarm      soft two-tone square blips in the dark (blast doors)
  slam       the doors split: driven kick, sub drop, noise slap, door-metal ring
  cascade    a long fine ratchet: detail cascading over the structure
  hud        quick fine ticks as the HUD types
  drone      a passing craft: triangle doppler glide + band whoosh (pitch, pan)
  clamp      metal clang with a sub: the clamps bite
  steam      a hiss of steam
  pullout    a long airy whoosh as we pull out into the sky
  cut        power-down: sine dive, sub thud, a crackle
Music: 75 bpm, 4/4, first downbeat at 0.0 s; a bar is 96 frames (3.2 s). D minor.
  intro  bars 0-1.5     pad, sub, glass bells, a soft kick (the monument)
  dive   bars 1.5-2     snare roll and the pad opening (into the hatch)
  drop   bars 2-3.5     half-time break: kick, roomy snare on 3, shaker, sub, metal stabs
  thin   bars 3.5-4     pad, bells, soft kick (pull-out)
  tail   bars 4-4.375   silence; the cut rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_greebles/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "air": dict(voice="whoosh", params={"length_s": 2.6, "low_hz": 120.0, "high_hz": 1900.0, "peak": 0.45, "shape": 1.3, "noise": "&pink"},
                bind=level(-12.0, -4.0), send=0.45, seed=501),
    "clank": dict(voice="mallet", params={"freq_hz": 131.0, "material": "&metal", "hardness": 0.85, "decay_s": 0.55},
                  layers=[{"voice": "&boing", "params": {"start_hz": 150.0, "end_hz": 48.0, "drop_s": 0.06, "decay_s": 0.3, "sub": 0.9, "click": 0.6}, "gain_db": -3.0}],
                  bind=pitched(-8.0, -1.0), send=0.35, seed=502),
    "settle": dict(voice="boing", params={"start_hz": 95.0, "end_hz": 36.0, "drop_s": 0.2, "decay_s": 0.9, "sub": 1.0, "click": 0.3},
                   layers=[{"voice": "&whoosh", "params": {"length_s": 1.4, "low_hz": 60.0, "high_hz": 500.0, "peak": 0.1, "noise": "&brown"}, "gain_db": -4.0}],
                   bind=level(-6.0, 0.0), send=0.4, seed=503),
    "servo": dict(voice="ratchet", params={"length_s": 0.6, "start_rate_hz": 30.0, "end_rate_hz": 55.0, "click_hz": 2200.0, "q": 3.0, "fade": 0.2},
                  layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 170.0, "end_hz": 260.0, "glide_s": 0.3, "attack_s": 0.05, "decay_s": 0.4, "sustain": 0.6, "gate_s": 0.5, "length_s": 0.65}, "gain_db": -14.0},
                          {"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 500.0, "high_hz": 3000.0, "peak": 0.6, "mode": "&band", "q": 1.4}, "gain_db": -8.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 5000.0}], bind=level(-14.0, -6.0), send=0.25, seed=504),
    "lamp": dict(voice="mallet", params={"freq_hz": 880.0, "material": "&glass", "hardness": 0.45, "decay_s": 0.8},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 1318.5, "material": "&glass", "hardness": 0.4, "decay_s": 0.7}, "gain_db": -5.0, "offset_s": 0.08}],
                 bind=level(-14.0, -6.0), send=0.55, seed=505),
    "riser": dict(voice="tone", params={"wave": "&saw", "freq_hz": 90.0, "end_hz": 900.0, "glide_s": 0.9, "attack_s": 1.3, "decay_s": 0.3, "sustain": 1.0, "gate_s": 1.6, "release_s": 0.004, "length_s": 1.6},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 1.6, "low_hz": 200.0, "high_hz": 8000.0, "peak": 0.97, "shape": 3.0, "noise": "&pink"}, "gain_db": -1.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 6000.0, "slope_db": 12.0}], bind=level(-14.0, -5.0), send=0.2, offset_s=-1.6, seed=506),
    "alarm": dict(voice="tone", params={"wave": "&square", "freq_hz": 620.0, "decay_s": 0.2, "sustain": 0.5, "gate_s": 0.16, "release_s": 0.04, "length_s": 0.3},
                  fx=[{"type": "lowpass", "cutoff_hz": 2400.0}], bind=pitched(-20.0, -12.0), send=0.4, seed=507),
    "slam": dict(voice="kick", params={"tune_hz": 40.0, "punch": 6.0, "drop_s": 0.05, "decay_s": 0.7, "click": 0.8, "drive": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 170.0, "end_hz": 34.0, "drop_s": 0.18, "decay_s": 0.7, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.04, "shape": 2.5}, "gain_db": -5.0},
                         {"voice": "&mallet", "params": {"freq_hz": 73.0, "material": "&metal", "hardness": 1.0, "decay_s": 1.1}, "gain_db": -6.0}],
                 bind=level(-3.0, 0.0), send=0.45, seed=508),
    "cascade": dict(voice="ratchet", params={"length_s": 1.4, "start_rate_hz": 60.0, "end_rate_hz": 18.0, "click_hz": 5200.0, "q": 6.0, "fade": 0.7, "accent_every": 4.0},
                    bind=level(-22.0, -12.0), send=0.3, seed=509),
    "hud": dict(voice="ratchet", params={"length_s": 0.45, "start_rate_hz": 70.0, "end_rate_hz": 60.0, "click_hz": 7000.0, "q": 6.0, "fade": 0.5},
                bind=level(-26.0, -16.0), seed=510),
    "drone": dict(voice="tone", params={"wave": "&triangle", "freq_hz": 940.0, "end_hz": 560.0, "glide_s": 0.7, "attack_s": 0.4, "decay_s": 0.6, "sustain": 0.5, "gate_s": 1.2, "release_s": 0.3, "length_s": 1.9},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 1.8, "low_hz": 400.0, "high_hz": 3600.0, "peak": 0.5, "mode": "&band", "q": 1.0}, "gain_db": -4.0}],
                  bind={"intensity": {"gain_db": [-18.0, -9.0]}, "data.pitch": "pitch_scale", "data.pan": "pan"}, send=0.4, seed=511),
    "clamp": dict(voice="mallet", params={"freq_hz": 98.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.7},
                  layers=[{"voice": "&boing", "params": {"start_hz": 230.0, "end_hz": 55.0, "drop_s": 0.04, "decay_s": 0.3, "sub": 0.9, "click": 1.0, "click_hz": 8000.0}, "gain_db": -2.0}],
                  bind=level(-5.0, 0.0), send=0.4, seed=512),
    "steam": dict(voice="static", params={"length_s": 1.0, "hiss": 0.9, "color_hz": 4500.0, "q": 0.5, "crackles_per_s": 30.0, "crackle": 0.2, "fade_s": 0.3},
                  bind=level(-18.0, -9.0), send=0.3, seed=513),
    "pullout": dict(voice="whoosh", params={"length_s": 2.2, "low_hz": 100.0, "high_hz": 2600.0, "peak": 0.35, "shape": 1.5, "noise": "&pink"},
                    bind=level(-12.0, -4.0), send=0.5, seed=514),
    "cut": dict(voice="tone", params={"wave": "&sine", "freq_hz": 320.0, "end_hz": 40.0, "glide_s": 0.35, "decay_s": 1.0, "sustain": 0.0, "gate_s": 0.8, "length_s": 1.2},
                layers=[{"voice": "&boing", "params": {"start_hz": 80.0, "end_hz": 30.0, "drop_s": 0.2, "decay_s": 0.6, "sub": 1.0, "click": 0.2}, "gain_db": -2.0},
                        {"voice": "&static", "params": {"length_s": 0.3, "hiss": 0.5, "crackles_per_s": 400.0, "crackle": 0.8, "fade_s": 0.05}, "gain_db": -14.0}],
                bind=level(-6.0, 0.0), send=0.5, seed=515),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "greeble_map.tres"), {n: R + n + ".tres" for n in fx},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.78, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -4.0}, end_fade_s=0.4)
with open(os.path.join(D, "greeble_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 7.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.35}\n')

# ------------------------------------------------------------------ music (75 bpm, D minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=601,
       params={"tune_hz": 45.0, "punch": 4.0, "decay_s": 0.5, "click": 0.4, "drive": 0.35}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=602, send=0.45,
       params={"tone_hz": 175.0, "tone": 0.55, "noise": 0.9, "noise_hz": 4800.0, "noise_decay_s": 0.3},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "shaker.tres"), voice="hat", seed=603, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.028, "tone_hz": 10500.0, "metal": 0.15}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "sub.tres"), voice="wavetable", seed=604,
       params={"position": 0.15, "sub": 0.6, "cutoff_hz": 320.0, "env_octaves": 1.2, "filter_decay_s": 0.2, "q": 1.0,
               "attack_s": 0.005, "decay_s": 0.5, "sustain": 0.6, "release_s": 0.15}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "stab.tres"), voice="fm", seed=605, send=0.45,
       params={"ratio": 1.41, "index": 6.0, "index_end": 0.6, "index_decay_s": 0.08, "decay_s": 0.3, "sustain": 0.0, "gate_s": 0.15, "release_s": 0.1},
       bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bell.tres"), voice="fm", seed=606, send=0.6,
       params={"ratio": 3.5, "index": 3.5, "index_end": 0.3, "index_decay_s": 0.4, "decay_s": 1.4, "sustain": 0.0, "gate_s": 0.5, "release_s": 0.5},
       bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=607, send=0.6,
       params={"position": 0.45, "unison": 5, "detune_cents": 14.0, "cutoff_hz": 1100.0, "env_octaves": 0.4, "filter_decay_s": 1.0,
               "q": 0.7, "attack_s": 0.7, "decay_s": 1.0, "sustain": 0.75, "release_s": 0.8})

pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 15, "length": 16, "notes": ["D3", "D3", "A#2", "C3"], "chord": [0, 3, 7, 10], "gate": 15.5, "gain_db": -10.0}
sub = {"name": "sub", "recipe": M + "sub.tres", "steps": "X.......x.......", "length": 16, "notes": ["D1", "D1", "A#0", "C1"], "gate": 7.0, "gain_db": -4.0}
bell = {"name": "bell", "recipe": M + "bell.tres", "steps": "x.....x...x.....", "length": 16, "notes": ["D5", "A5", "F5", "C6", "A5", "E5"], "gain_db": -13.0, "pan": 0.25}
kick_soft = {"name": "kick", "recipe": M + "kick.tres", "steps": "o...............", "length": 16, "gain_db": -6.0}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "o.o.o.o.xoxoxXXX", "length": 16, "gain_db": -6.0}
kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.....x...x.....", "length": 16}
snare = {"name": "snare", "recipe": M + "snare.tres", "steps": "........X.......", "length": 16, "gain_db": -1.0}
shaker = {"name": "shaker", "recipe": M + "shaker.tres", "steps": "xoxoxoxoxoxoxoxo", "length": 16, "gain_db": -15.0, "pan": -0.2}
bass = {"name": "sub", "recipe": M + "sub.tres", "steps": "X.....x.X.....x.", "length": 16, "notes": [26, 26, 29, 24], "gate": 1.6, "gain_db": -3.0}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "..x...x...x...x.", "length": 16, "notes": ["D4", "F4", "A4", "C5"], "gain_db": -15.0, "pan": 0.2}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name), "lanes": lanes}, typed={"lanes"})
pat("intro", 16, [pad, sub, bell, kick_soft])
pat("dive", 16, [pad, sub, roll])
pat("drop", 16, [pad, kick, snare, shaker, bass, stab])
pat("thin", 16, [pad, bell, kick_soft])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 75.0, "beats_per_bar": 4, "offset_s": 0.0})
resource(os.path.join(MD, "greeble_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.5, "patterns": [M + "intro.tres"]},
        {"name": "dive", "bars": 0.5, "patterns": [M + "dive.tres"],
         "automation": {"pad.cutoff_hz": [[0.0, 1100.0], [1.0, 4500.0]], "snare.gain_db": [[0.0, -10.0], [1.0, 0.0]]}},
        {"name": "drop", "bars": 1.5, "patterns": [M + "drop.tres"]},
        {"name": "thin", "bars": 0.5, "patterns": [M + "thin.tres"],
         "automation": {"pad.gain_db": [[0.0, 0.0], [1.0, -6.0]]}},
        {"name": "tail", "bars": 0.375, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, greeble_map.tres and the 75 bpm song" % len(fx))
