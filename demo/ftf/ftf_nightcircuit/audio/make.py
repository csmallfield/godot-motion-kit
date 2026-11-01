#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the Night Circuit take (demo/ftf/ftf_nightcircuit/ftf_nightcircuit.gd):
effect recipes, cue map and a dark, rolling 150 bpm synthwave bed for the Godot
Audio Kit. Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_nightcircuit/audio/make.py

Sound sheet (shared reverb 0.6, a wide dusk space; music ducks 6 dB under hits):
  engine      the ship under us for the whole piece: two `follow` oscillators
              (saw + square an octave-ish apart via pitch_scale) whose pitch and
              level curves come from the camera's speed profile in the cue data;
              driven, low-passed, a growl not a whine
  power       heavy relay clunk, a low filtered saw swelling under it, climbing per step
  hud.type    fine dry ratchet: the HUD writing itself
  neon        fluorescent strike on the MH sign: crackling static and a mains buzz
  presents    short ratchet run and a cold glass ping
  overtake    a rival streaking past: band whoosh with a falling saw (doppler)
  spool       engine spool-up: saw glide and rising noise, peaking on the launch
  launch      driven boom + wide whoosh on the bar
  pass        big pass-by whoosh under the MH gantry, sub thump
  gate        overhead whoosh + metal thunk, one per checkered gantry
  rise        the board cracking: low grinding ratchet and a brown-noise swell into the drop
  drop        the reveal: driven kick, long sub drop, noise slap, a dark FM minor chord
  ring        a shockwave through the board: soft sub thump and air
  callout     two small triangle blips
  ship        doppler fly-by under the sign
  sink        the sun going down: a long falling filtered saw
  cut         relay clunk with a falling tone, deeper each step
  sign.cut    power-down: tape-stopped tone, static burst and sub thump
Music: C minor, 150 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 48 frames.
  power   bars 0-1      open-fifth drone opening up, ticking hats
  grid    bars 1-2      half-time kick, rolling octave bass under a closed filter, pad
  run     bars 2-3.75   four on the floor, rolling bass opening, gated snare, 16th hats
  roll    bars 3.75-4   snare roll into the drop
  drop    bars 4-7      full: Cm / Ab / Eb, bass, gated snare, arp, pad with thirds
  outro   bars 7-8      bass closing down, pad, single kicks
  tail    bars 8-8.75   silence; the power-down rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_nightcircuit/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
os.makedirs(MD, exist_ok=True)
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

FLAT = [[0.0, 40.0], [14.0, 40.0]]      # placeholders: the cue's data replaces them
ONE = [[0.0, 1.0], [14.0, 1.0]]

fx = {
    "engine": dict(voice="follow", params={"wave": "&saw", "length_s": 14.0, "pitch": FLAT, "level": ONE, "glide": 0.3, "fade_s": 0.3},
                   layers=[{"voice": "&follow", "params": {"wave": "&square", "length_s": 14.0, "pitch": FLAT, "level": ONE, "glide": 0.3, "fade_s": 0.3}, "gain_db": -9.0},
                           {"voice": "&follow", "params": {"wave": "&triangle", "length_s": 14.0, "pitch": FLAT, "level": ONE, "glide": 0.3, "fade_s": 0.3}, "gain_db": -4.0}],
                   fx=[{"type": "drive", "amount": 0.55}, {"type": "lowpass", "cutoff_hz": 700.0, "slope_db": 24.0}, {"type": "highpass", "cutoff_hz": 30.0}],
                   bind={"intensity": {"gain_db": [-24.0, -15.0]}, "data.pitch": "pitch", "data.level": "level"}, send=0.15, seed=601),
    "power": dict(voice="click", params={"freq_hz": 1500.0, "mode": "&band", "q": 2.0, "decay_s": 0.025, "body_hz": 60.0, "body": 1.0},
                  layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 65.41, "attack_s": 0.06, "decay_s": 0.3, "sustain": 0.4, "gate_s": 0.35, "release_s": 0.12}, "gain_db": -11.0},
                          {"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 40.0, "drop_s": 0.07, "decay_s": 0.22, "sub": 0.9, "click": 0.2}, "gain_db": -4.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 2000.0}], bind=pitched(-9.0, -2.0), send=0.4, seed=602),
    "hud_type": dict(voice="ratchet", params={"length_s": 0.75, "start_rate_hz": 58.0, "end_rate_hz": 42.0, "click_hz": 6200.0, "q": 5.0, "fade": 0.4},
                     bind=level(-25.0, -16.0), seed=603),
    "neon": dict(voice="static", params={"length_s": 0.3, "hiss": 0.5, "color_hz": 4000.0, "q": 0.9, "crackles_per_s": 220.0, "crackle": 1.0, "flicker_hz": 28.0, "flicker_depth": 0.9, "fade_s": 0.01},
                 layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 100.0, "attack_s": 0.002, "decay_s": 0.2, "sustain": 0.5, "gate_s": 0.25, "release_s": 0.05, "length_s": 0.32}, "gain_db": -12.0}],
                 fx=[{"type": "highpass", "cutoff_hz": 90.0}], bind=level(-14.0, -5.0), send=0.3, seed=604),
    "presents": dict(voice="ratchet", params={"length_s": 0.34, "start_rate_hz": 34.0, "end_rate_hz": 30.0, "click_hz": 3400.0, "q": 5.0, "fade": 0.2},
                     layers=[{"voice": "&mallet", "params": {"freq_hz": 1046.5, "material": "&glass", "hardness": 0.5, "decay_s": 0.7}, "gain_db": -6.0, "offset_s": 0.34}],
                     bind=level(-16.0, -7.0), send=0.5, seed=605),
    "overtake": dict(voice="whoosh", params={"length_s": 0.6, "low_hz": 350.0, "high_hz": 6500.0, "peak": 0.4, "shape": 2.0, "mode": "&band", "q": 1.2},
                     layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 640.0, "end_hz": 260.0, "glide_s": 0.2, "attack_s": 0.2, "decay_s": 0.3, "sustain": 0.0, "gate_s": 0.35, "length_s": 0.6}, "gain_db": -15.0}],
                     fx=[{"type": "lowpass", "cutoff_hz": 5500.0}], bind=pitched(-14.0, -6.0), vary={"high_hz": 0.12}, send=0.35, seed=606),
    "spool": dict(voice="tone", params={"wave": "&saw", "freq_hz": 55.0, "end_hz": 196.0, "glide_s": 0.38, "attack_s": 0.25, "decay_s": 0.2, "sustain": 0.8, "gate_s": 0.38, "release_s": 0.03, "length_s": 0.42},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 0.42, "low_hz": 150.0, "high_hz": 4000.0, "peak": 0.95, "shape": 1.4, "noise": "&pink"}, "gain_db": -5.0}],
                  fx=[{"type": "drive", "amount": 0.4}, {"type": "lowpass", "cutoff_hz": 3000.0}], bind=level(-12.0, -4.0), send=0.25, seed=607),
    "launch": dict(voice="boing", params={"start_hz": 120.0, "end_hz": 38.0, "drop_s": 0.12, "decay_s": 0.5, "sub": 1.0, "click": 0.5},
                   layers=[{"voice": "&whoosh", "params": {"length_s": 0.7, "low_hz": 200.0, "high_hz": 6000.0, "peak": 0.1, "shape": 1.8, "noise": "&pink"}, "gain_db": -4.0}],
                   fx=[{"type": "drive", "amount": 0.3}], bind=level(-7.0, -1.0), send=0.35, seed=608),
    "pass": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 150.0, "high_hz": 6000.0, "peak": 0.45, "shape": 2.0, "noise": "&pink"},
                 layers=[{"voice": "&boing", "params": {"start_hz": 130.0, "end_hz": 48.0, "drop_s": 0.08, "decay_s": 0.22, "sub": 0.7, "click": 0.1}, "gain_db": -8.0, "offset_s": 0.2}],
                 bind=level(-10.0, -3.0), send=0.3, seed=609),
    "gate": dict(voice="whoosh", params={"length_s": 0.3, "low_hz": 300.0, "high_hz": 5200.0, "peak": 0.45, "shape": 2.2, "noise": "&pink"},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 130.0, "material": "&metal", "hardness": 0.8, "decay_s": 0.25}, "gain_db": -9.0, "offset_s": 0.13}],
                 bind=pitched(-12.0, -5.0), vary={"high_hz": 0.15}, send=0.3, seed=610),
    "rise": dict(voice="ratchet", params={"length_s": 0.53, "start_rate_hz": 18.0, "end_rate_hz": 70.0, "click_hz": 900.0, "q": 2.5, "fade": 0.1},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.53, "low_hz": 60.0, "high_hz": 1800.0, "peak": 0.95, "shape": 1.3, "noise": "&brown", "q": 1.5}, "gain_db": -2.0},
                         {"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 41.2, "end_hz": 82.4, "glide_s": 0.5, "attack_s": 0.3, "decay_s": 0.2, "sustain": 0.9, "gate_s": 0.5, "release_s": 0.02, "length_s": 0.53}, "gain_db": -8.0}],
                 fx=[{"type": "drive", "amount": 0.5}, {"type": "lowpass", "cutoff_hz": 2600.0}], bind=level(-9.0, -2.0), send=0.4, seed=611),
    "drop": dict(voice="kick", params={"tune_hz": 41.0, "punch": 5.0, "drop_s": 0.05, "decay_s": 0.75, "click": 0.8, "drive": 0.6},
                 layers=[{"voice": "&boing", "params": {"start_hz": 130.0, "end_hz": 30.0, "drop_s": 0.25, "decay_s": 0.7, "sub": 1.0, "click": 0.0}, "gain_db": -3.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.5, "low_hz": 400.0, "high_hz": 9000.0, "peak": 0.03, "shape": 2.5}, "gain_db": -6.0},
                         {"voice": "&fm", "params": {"freq_hz": 130.81, "ratio": 2.0, "index": 5.0, "index_end": 0.6, "index_decay_s": 0.5, "decay_s": 1.1, "gate_s": 0.9, "release_s": 0.4}, "gain_db": -11.0},
                         {"voice": "&fm", "params": {"freq_hz": 155.56, "ratio": 2.0, "index": 5.0, "index_end": 0.6, "index_decay_s": 0.5, "decay_s": 1.1, "gate_s": 0.9, "release_s": 0.4}, "gain_db": -13.0},
                         {"voice": "&fm", "params": {"freq_hz": 196.0, "ratio": 2.0, "index": 5.0, "index_end": 0.6, "index_decay_s": 0.5, "decay_s": 1.1, "gate_s": 0.9, "release_s": 0.4}, "gain_db": -13.0}],
                 bind=level(-4.0, 0.0), send=0.45, seed=612),
    "ring": dict(voice="boing", params={"start_hz": 90.0, "end_hz": 36.0, "drop_s": 0.15, "decay_s": 0.4, "sub": 1.0, "click": 0.05},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.9, "low_hz": 500.0, "high_hz": 3500.0, "peak": 0.08, "shape": 2.0, "noise": "&pink"}, "gain_db": -10.0}],
                 bind=level(-12.0, -5.0), send=0.5, seed=613),
    "callout": dict(voice="tone", params={"wave": "&triangle", "freq_hz": 1568.0, "end_hz": 2093.0, "glide_s": 0.02, "decay_s": 0.06, "gate_s": 0.06, "length_s": 0.12},
                    bind=pitched(-21.0, -13.0), send=0.3, seed=614),
    "ship": dict(voice="whoosh", params={"length_s": 0.7, "low_hz": 400.0, "high_hz": 7000.0, "peak": 0.55, "shape": 2.0, "mode": "&band", "q": 1.1},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 780.0, "end_hz": 310.0, "glide_s": 0.18, "attack_s": 0.25, "decay_s": 0.3, "sustain": 0.0, "gate_s": 0.4, "length_s": 0.7}, "gain_db": -14.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 6000.0}], bind=pitched(-13.0, -5.0), send=0.35, seed=615),
    "sink": dict(voice="tone", params={"wave": "&saw", "freq_hz": 196.0, "end_hz": 49.0, "glide_s": 1.4, "attack_s": 0.3, "decay_s": 0.8, "sustain": 0.6, "gate_s": 1.3, "release_s": 0.3, "length_s": 1.8},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 293.66, "end_hz": 73.4, "glide_s": 1.4, "attack_s": 0.3, "decay_s": 0.8, "sustain": 0.6, "gate_s": 1.3, "release_s": 0.3, "length_s": 1.8}, "gain_db": -5.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 900.0}], bind=level(-16.0, -9.0), send=0.55, seed=616),
    "cut": dict(voice="click", params={"freq_hz": 1100.0, "mode": "&band", "q": 2.5, "decay_s": 0.03, "body_hz": 55.0, "body": 1.0},
                layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 196.0, "end_hz": 82.0, "glide_s": 0.08, "decay_s": 0.15, "gate_s": 0.15, "length_s": 0.3}, "gain_db": -12.0}],
                fx=[{"type": "lowpass", "cutoff_hz": 2800.0}], bind=pitched(-8.0, -2.0), send=0.45, seed=617),
    "sign_cut": dict(voice="tone", params={"wave": "&saw", "freq_hz": 261.63, "attack_s": 0.002, "decay_s": 0.5, "sustain": 0.7, "gate_s": 0.6, "release_s": 0.2, "length_s": 0.9},
                     layers=[{"voice": "&static", "params": {"length_s": 0.25, "hiss": 0.8, "color_hz": 3000.0, "crackles_per_s": 800.0, "crackle": 1.0, "flicker_hz": 40.0}, "gain_db": -7.0},
                             {"voice": "&boing", "params": {"start_hz": 85.0, "end_hz": 28.0, "drop_s": 0.15, "decay_s": 0.5, "sub": 1.0, "click": 0.3}, "gain_db": 0.0}],
                     fx=[{"type": "lowpass", "cutoff_hz": 2400.0}], transforms=[{"type": "varispeed", "from": 1.0, "to": 0.2}],
                     bind=level(-6.0, 0.0), send=0.5, seed=618),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "nc_map.tres"), {
    "engine": R + "engine.tres", "power": R + "power.tres", "hud.type": R + "hud_type.tres", "neon": R + "neon.tres",
    "presents": R + "presents.tres", "overtake": R + "overtake.tres", "spool": R + "spool.tres", "launch": R + "launch.tres",
    "pass": R + "pass.tres", "gate": R + "gate.tres", "rise": R + "rise.tres", "drop": R + "drop.tres", "ring": R + "ring.tres",
    "callout": R + "callout.tres", "ship": R + "ship.tres", "sink": R + "sink.tres", "cut": R + "cut.tres", "sign.cut": R + "sign_cut.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.65, "damp": 0.55, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.4)
with open(os.path.join(D, "nc_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -14.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music: C minor, 150 bpm
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=701,
       params={"tune_hz": 47.0, "punch": 4.5, "decay_s": 0.34, "click": 0.3, "drive": 0.5}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=702, send=0.55,
       params={"tone_hz": 190.0, "tone": 0.4, "noise": 0.9, "noise_hz": 4000.0, "noise_decay_s": 0.22},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-18.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=703, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.03, "tone_hz": 8500.0, "metal": 0.6}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=704,
       params={"position": 0.68, "sub": 0.5, "cutoff_hz": 300.0, "env_octaves": 2.6, "filter_decay_s": 0.07, "q": 3.0,
               "attack_s": 0.002, "decay_s": 0.09, "sustain": 0.35, "release_s": 0.03},
       fx=[{"type": "drive", "amount": 0.35}], bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "drone.tres"), voice="wavetable", seed=705, send=0.45,
       params={"position": 0.7, "unison": 5, "detune_cents": 16.0, "sub": 0.5, "cutoff_hz": 240.0, "env_octaves": 0.4, "filter_decay_s": 2.0,
               "q": 1.4, "attack_s": 0.6, "decay_s": 1.0, "sustain": 0.8, "release_s": 0.4})
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=706, send=0.6,
       params={"position": 0.5, "unison": 5, "detune_cents": 20.0, "cutoff_hz": 850.0, "env_octaves": 0.5, "filter_decay_s": 1.0,
               "q": 0.8, "attack_s": 0.35, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.35})
recipe(os.path.join(MD, "arp.tres"), voice="wavetable", seed=707, send=0.45,
       params={"position": 0.62, "unison": 3, "detune_cents": 10.0, "cutoff_hz": 1100.0, "env_octaves": 2.0, "filter_decay_s": 0.06,
               "q": 2.0, "attack_s": 0.002, "decay_s": 0.1, "sustain": 0.0, "release_s": 0.05},
       fx=[{"type": "echo", "time_s": 0.3, "feedback": 0.3, "mix": 0.25}], bind=level(-12.0, 0.0))

# chords per bar: Cm, Ab, Eb, Bb (roots; bass in octave 1, pad fifths + a third lane)
ROOTS = [24, 20, 27, 22]          # C1, Ab0, Eb1, Bb0
THIRDS = ["D#4", "C4", "G3", "D4"]
TONES = [[60, 63, 67, 72], [56, 60, 63, 68], [63, 67, 70, 75], [58, 62, 65, 70]]


def rolling(bars):
    notes = []
    for b in range(bars):
        r = ROOTS[b % 4]
        notes += [r, r + 12] * 8
    return notes


def arp_notes(bars):
    seq = [0, 1, 2, 3, 2, 1, 2, 3]
    notes = []
    for b in range(bars):
        t = TONES[b % 4]
        notes += [t[i] for i in seq] * 2
    return notes


kick4 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick_half = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.......x.......", "length": 16, "gain_db": -2.0}
kick1 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...............", "length": 16, "gain_db": -2.0}
snare = {"name": "snare", "recipe": M + "snare.tres", "steps": "....X.......X...", "length": 16, "gain_db": 7.0}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "1234567891234589", "length": 16, "gain_db": 3.0}
hat_tick = {"name": "hat", "recipe": M + "hat.tres", "steps": "..o...o...o...o.", "length": 16, "gain_db": -6.0, "pan": 0.2}
hat16 = {"name": "hat", "recipe": M + "hat.tres", "steps": "oxoXoxoXoxoXoxoX", "length": 16, "gain_db": -3.0, "pan": 0.2}
bass_grid = {"name": "bass", "recipe": M + "bass.tres", "steps": "Xooo" * 4, "length": 16, "notes": rolling(1), "gate": 0.55, "gain_db": -3.0}
bass_run = {"name": "bass", "recipe": M + "bass.tres", "steps": "Xxox" * 8, "length": 32, "notes": rolling(2), "gate": 0.55, "gain_db": -2.0}
bass_drop = {"name": "bass", "recipe": M + "bass.tres", "steps": "Xxox" * 16, "length": 64, "notes": rolling(4), "gate": 0.55, "gain_db": -1.0}
drone = {"name": "drone", "recipe": M + "drone.tres", "steps": "x" + "." * 47, "length": 48, "notes": ["C2"], "chord": [0, 7, 12], "gate": 47.0, "gain_db": -8.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": ("x" + "." * 15) * 4, "length": 64, "notes": [48, 44, 51, 46], "chord": [0, 7, 12], "gate": 15.0, "gain_db": -3.0}
third = {"name": "third", "recipe": M + "pad.tres", "steps": ("x" + "." * 15) * 4, "length": 64, "notes": THIRDS, "gate": 15.0, "gain_db": -5.0}
pad_c = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 15, "length": 16, "notes": [48], "chord": [0, 7, 12], "gate": 15.0, "gain_db": -3.0}
arp = {"name": "arp", "recipe": M + "arp.tres", "steps": "xoxo" * 16, "length": 64, "notes": arp_notes(4), "gate": 0.5, "gain_db": 3.0, "pan": -0.15}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name) + 11, "lanes": lanes}, typed={"lanes"})
pat("power", 48, [drone, hat_tick])
pat("grid", 16, [kick_half, bass_grid, hat_tick, pad_c])
pat("run", 32, [kick4, snare, bass_run, hat16])
pat("roll", 16, [roll, bass_run, hat16])
pat("drop", 64, [kick4, snare, bass_drop, hat16, pad, third, arp])
pat("outro", 16, [kick1, bass_grid, pad_c])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 150.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "nc_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "power", "bars": 1.0, "patterns": [M + "power.tres"], "automation": {"drone.cutoff_hz": [[0.0, 110.0], [1.0, 520.0]]}},
        {"name": "grid", "bars": 1.0, "patterns": [M + "grid.tres"], "automation": {"bass.cutoff_hz": [[0.0, 160.0], [1.0, 320.0]]}},
        {"name": "run", "bars": 1.75, "patterns": [M + "run.tres"], "automation": {"bass.cutoff_hz": [[0.0, 300.0], [1.0, 1000.0]]}},
        {"name": "roll", "bars": 0.25, "patterns": [M + "roll.tres"], "automation": {"bass.cutoff_hz": [[0.0, 1000.0], [1.0, 1700.0]]}},
        {"name": "drop", "bars": 3.0, "patterns": [M + "drop.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 700.0], [0.5, 1200.0], [1.0, 800.0]], "arp.cutoff_hz": [[0.0, 700.0], [1.0, 2200.0]]}},
        {"name": "outro", "bars": 1.0, "patterns": [M + "outro.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 500.0], [1.0, 120.0]], "bass.gain_db": [[0.0, 0.0], [1.0, -12.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -6.0]]}},
        {"name": "tail", "bars": 0.75, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, nc_map.tres and the 150 bpm song" % len(fx))
