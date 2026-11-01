#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for FTF round 4, TIME CITY (demo/ftf/ftf_timecity): effect recipes, the
cue map and a 120 bpm industrial electro song with tape-warp character, for the
Godot Audio Kit. Needs the audio kit linked. Regenerate:
    python3 demo/ftf/ftf_timecity/audio/make.py

Sound sheet (a big hard room, metal and hydraulics run through a tape machine:
varispeed spin-ups and stops, reversed swells into every snap; music ducks 7 dB):
  tape.start   the tape spins up out of silence: low saw drone + hiss, varispeed 0.15 -> 1
  wave         the time wave crossing the city: a long filtered sweep that wows (varispeed 0.7 -> 1.2)
  block        metal latch clanks as the blocks rise, climbing, each bent up into pitch
  mh.rise      a reversed metal bell + hiss swelling into the snap (ends on frame 60)
  snap         the lockup snapping sharp: kick, metal bar, a tape click
  ripple       a ripple of time: a short wowed tone dipping in pitch (varispeed 1 -> 0.6)
  stamp        rubber stamp thud with a paper slap; stamp.small a smaller one
  sink         hydraulic hiss slowing down like a stopped tape (varispeed 1 -> 0.35)
  crane        the smeared crane: a long whoosh pulled from slow to fast (varispeed 0.55 -> 1.35)
  arrive       a dull boom as the camera lands
  drain        stepped descending ratchet
  ftf.rise     two seconds of reversed clang + noise + rising saw, ending on the drop
  drop         the big one: kick, sub boing, metal clang, noise slap
  fringe       a time-split blip: FM glitch, bent down fast
  tear         tape tear: crackle and a square zap, bitcrushed, slowing to a crawl
  pass         a band-passed whoosh scanning down
  streak       the tape stops: saw drone and hiss, varispeed 1 -> 0 over 1.4 s
  drain.out    a long low falling whoosh into the dark
  end          a last low thud, tape run-out
Music: 120 bpm, 4/4, first downbeat at 0.0 s (frame 0), a bar is 60 frames.
  spin   bar 0       kick and a filtered bass pulse opening up
  mh     bars 1-2    + clap, metal, sparse arp
  smear  bar 2-3     half-time kick, bass held, reversed swell into bar 3
  rise   bar 3-4     snare roll building, bass climbing
  drive  bars 4-6    full groove + reversed metal swells into every bar
  outro  bar 6-6.75  kick and bass thinning
  tail   6.75-7      silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_timecity/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
os.makedirs(MD, exist_ok=True)
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "tape_start": dict(voice="tone", params={"wave": "&saw", "freq_hz": 73.4, "attack_s": 0.05, "decay_s": 0.3, "sustain": 0.8, "gate_s": 0.9, "release_s": 0.08, "length_s": 1.0},
                       layers=[{"voice": "&whoosh", "params": {"length_s": 1.0, "low_hz": 200.0, "high_hz": 3000.0, "peak": 0.8, "noise": "&pink"}, "gain_db": -8.0}],
                       fx=[{"type": "lowpass", "cutoff_hz": 1400.0, "slope_db": 24.0}],
                       transforms=[{"type": "varispeed", "from": 0.15, "to": 1.0}, {"type": "fade", "out_s": 0.25}],
                       bind=level(-14.0, -7.0), send=0.25, seed=501),
    "wave": dict(voice="whoosh", params={"length_s": 1.3, "low_hz": 150.0, "high_hz": 4200.0, "peak": 0.7, "shape": 1.8, "q": 2.5, "noise": "&pink"},
                 layers=[{"voice": "&tone", "params": {"wave": "&triangle", "freq_hz": 220.0, "end_hz": 440.0, "glide_s": 0.6, "vibrato_hz": 3.0, "vibrato_semitones": 0.6, "attack_s": 0.4, "decay_s": 0.4, "sustain": 0.5, "gate_s": 1.0, "length_s": 1.3}, "gain_db": -12.0}],
                 transforms=[{"type": "varispeed", "from": 0.7, "to": 1.2}],
                 bind=level(-14.0, -6.0), send=0.3, seed=502),
    "block": dict(voice="mallet", params={"freq_hz": 330.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.12, "damping": 1.2},
                  layers=[{"voice": "&click", "params": {"freq_hz": 3200.0, "mode": "&band", "q": 6.0, "decay_s": 0.004, "body_hz": 110.0, "body": 0.6}, "gain_db": -4.0}],
                  transforms=[{"type": "varispeed", "from": 0.8, "to": 1.0}],
                  vary={"freq_hz": 0.03}, bind=pitched(-17.0, -8.0), send=0.2, seed=503),
    "mh_rise": dict(voice="fm", params={"freq_hz": 587.3, "ratio": 3.5, "index": 5.0, "index_end": 0.5, "index_decay_s": 0.4, "decay_s": 0.8, "gate_s": 0.05, "release_s": 0.3, "length_s": 0.86},
                    layers=[{"voice": "&whoosh", "params": {"length_s": 0.86, "low_hz": 400.0, "high_hz": 6000.0, "peak": 0.1, "shape": 2.0, "noise": "&pink"}, "gain_db": -6.0},
                            {"voice": "&mallet", "params": {"freq_hz": 146.8, "material": "&bar", "hardness": 1.0, "decay_s": 0.8}, "gain_db": -4.0}],
                    transforms=[{"type": "trim", "length_s": 0.86}, {"type": "reverse"}, {"type": "fade", "in_s": 0.05}],
                    bind=level(-12.0, -5.0), send=0.35, seed=504),
    "snap": dict(voice="kick", params={"tune_hz": 48.0, "punch": 4.5, "decay_s": 0.4, "click": 0.9, "drive": 0.45},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 140.0, "material": "&bar", "hardness": 1.0, "decay_s": 0.45}, "gain_db": -5.0},
                         {"voice": "&click", "params": {"freq_hz": 5200.0, "mode": "&band", "q": 2.0, "decay_s": 0.006}, "gain_db": -5.0},
                         {"voice": "&snare", "params": {"tone_hz": 160.0, "tone": 0.2, "noise": 1.0, "noise_hz": 3500.0, "noise_decay_s": 0.09}, "gain_db": -9.0}],
                 bind=level(-4.0, 0.0), send=0.35, seed=505),
    "ripple": dict(voice="tone", params={"wave": "&square", "width": 0.3, "freq_hz": 880.0, "vibrato_hz": 9.0, "vibrato_semitones": 0.8, "attack_s": 0.005, "decay_s": 0.2, "sustain": 0.2, "gate_s": 0.15, "release_s": 0.06, "length_s": 0.4},
                   layers=[{"voice": "&whoosh", "params": {"length_s": 0.4, "low_hz": 800.0, "high_hz": 5000.0, "peak": 0.3, "mode": "&band", "q": 2.0}, "gain_db": -8.0}],
                   fx=[{"type": "lowpass", "cutoff_hz": 3000.0}],
                   transforms=[{"type": "varispeed", "from": 1.0, "to": 0.6}],
                   bind=pitched(-18.0, -10.0), send=0.3, seed=506),
    "stamp": dict(voice="boing", params={"start_hz": 110.0, "end_hz": 60.0, "drop_s": 0.02, "decay_s": 0.09, "sub": 0.5, "click": 1.0, "click_hz": 2200.0},
                  layers=[{"voice": "&clap", "params": {"bursts": 1, "tail_decay_s": 0.05, "color_hz": 1600.0}, "gain_db": -6.0}],
                  bind=level(-7.0, -2.0), send=0.25, seed=507),
    "stamp_small": dict(voice="click", params={"freq_hz": 1800.0, "mode": "&band", "q": 2.0, "decay_s": 0.02, "body_hz": 180.0, "body": 0.8},
                        bind=level(-14.0, -6.0), send=0.2, seed=508),
    "sink": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 90.0, "high_hz": 1400.0, "peak": 0.25, "noise": "&brown"},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 160.0, "decay_s": 0.4, "sustain": 0.4, "gate_s": 0.4, "length_s": 0.5}, "gain_db": -12.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 2000.0}],
                 transforms=[{"type": "varispeed", "from": 1.0, "to": 0.35}, {"type": "fade", "out_s": 0.1}],
                 bind=level(-12.0, -5.0), send=0.3, seed=509),
    "crane": dict(voice="whoosh", params={"length_s": 0.8, "low_hz": 250.0, "high_hz": 7000.0, "peak": 0.6, "shape": 2.2, "noise": "&pink"},
                  layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 110.0, "end_hz": 165.0, "glide_s": 0.4, "attack_s": 0.3, "decay_s": 0.3, "sustain": 0.6, "gate_s": 0.7, "length_s": 0.8}, "gain_db": -14.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 4500.0}],
                  transforms=[{"type": "varispeed", "from": 0.55, "to": 1.35}],
                  bind=level(-11.0, -4.0), send=0.35, seed=510),
    "arrive": dict(voice="boing", params={"start_hz": 90.0, "end_hz": 38.0, "drop_s": 0.12, "decay_s": 0.5, "sub": 1.0, "click": 0.2},
                   bind=level(-9.0, -3.0), send=0.4, seed=511),
    "drain": dict(voice="ratchet", params={"length_s": 0.42, "start_rate_hz": 28.0, "end_rate_hz": 10.0, "click_hz": 1400.0, "q": 4.0, "fade": 0.5, "accent_every": 2.0},
                  layers=[{"voice": "&tone", "params": {"wave": "&triangle", "freq_hz": 300.0, "end_hz": 70.0, "glide_s": 0.15, "decay_s": 0.35, "gate_s": 0.35, "length_s": 0.42}, "gain_db": -10.0}],
                  bind=level(-13.0, -5.0), send=0.25, seed=512),
    "ftf_rise": dict(voice="mallet", params={"freq_hz": 98.0, "material": "&metal", "hardness": 1.0, "decay_s": 1.8},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 2.0, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.06, "shape": 1.4, "noise": "&pink"}, "gain_db": -4.0},
                             {"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 196.0, "end_hz": 49.0, "glide_s": 0.7, "decay_s": 1.6, "sustain": 0.0, "gate_s": 0.1, "length_s": 2.0}, "gain_db": -9.0},
                             {"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 40.0, "drop_s": 0.3, "decay_s": 1.2, "sub": 1.0, "click": 0.0}, "gain_db": -6.0}],
                     fx=[{"type": "drive", "amount": 0.25}, {"type": "lowpass", "cutoff_hz": 6000.0}],
                     transforms=[{"type": "trim", "length_s": 2.0}, {"type": "reverse"}, {"type": "fade", "in_s": 0.2}],
                     bind=level(-10.0, -3.0), send=0.3, seed=513),
    "drop": dict(voice="kick", params={"tune_hz": 42.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.55, "click": 0.8, "drive": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 120.0, "end_hz": 36.0, "drop_s": 0.12, "decay_s": 0.45, "sub": 1.0, "click": 0.0}, "gain_db": -5.0},
                         {"voice": "&mallet", "params": {"freq_hz": 196.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.7}, "gain_db": -5.0},
                         {"voice": "&snare", "params": {"tone_hz": 150.0, "tone": 0.3, "noise": 1.0, "noise_hz": 5000.0, "noise_decay_s": 0.16}, "gain_db": -6.0}],
                 bind=level(-3.0, 0.0), send=0.4, seed=514),
    "fringe": dict(voice="fm", params={"freq_hz": 293.7, "ratio": 2.76, "index": 9.0, "index_end": 0.0, "index_decay_s": 0.06, "decay_s": 0.14, "gate_s": 0.08, "release_s": 0.05},
                   layers=[{"voice": "&click", "params": {"freq_hz": 6000.0, "mode": "&band", "q": 3.0, "decay_s": 0.003}, "gain_db": -6.0}],
                   transforms=[{"type": "varispeed", "from": 1.0, "to": 0.5}],
                   bind=pitched(-15.0, -7.0), send=0.25, seed=515),
    "tear": dict(voice="static", params={"length_s": 0.3, "hiss": 0.9, "color_hz": 2600.0, "q": 0.7, "crackles_per_s": 1600.0, "crackle": 1.0, "flicker_hz": 30.0, "fade_s": 0.004},
                 layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 660.0, "end_hz": 110.0, "glide_s": 0.06, "decay_s": 0.2, "gate_s": 0.2, "length_s": 0.3}, "gain_db": -8.0}],
                 fx=[{"type": "bitcrush", "bits": 5.0, "hold": 3}],
                 transforms=[{"type": "varispeed", "from": 1.2, "to": 0.25}, {"type": "fade", "out_s": 0.08}],
                 bind=level(-10.0, -3.0), send=0.2, seed=516),
    "pass": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 600.0, "high_hz": 6000.0, "peak": 0.5, "mode": "&band", "q": 2.5},
                 bind=level(-17.0, -9.0), send=0.3, seed=517),
    "streak": dict(voice="tone", params={"wave": "&saw", "freq_hz": 146.8, "sustain": 1.0, "attack_s": 0.02, "gate_s": 1.3, "release_s": 0.05, "length_s": 1.4},
                   layers=[{"voice": "&whoosh", "params": {"length_s": 1.4, "low_hz": 200.0, "high_hz": 5000.0, "peak": 0.15, "noise": "&pink"}, "gain_db": -6.0},
                           {"voice": "&tone", "params": {"wave": "&square", "width": 0.25, "freq_hz": 293.7, "sustain": 1.0, "gate_s": 1.3, "length_s": 1.4}, "gain_db": -12.0}],
                   fx=[{"type": "lowpass", "cutoff_hz": 2200.0}],
                   transforms=[{"type": "varispeed", "from": 1.0, "to": 0.0}, {"type": "fade", "out_s": 0.25}],
                   bind=level(-11.0, -4.0), send=0.3, seed=518),
    "drain_out": dict(voice="whoosh", params={"length_s": 0.8, "low_hz": 60.0, "high_hz": 1200.0, "peak": 0.2, "shape": 1.6, "noise": "&brown"},
                      layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 140.0, "end_hz": 35.0, "glide_s": 0.3, "decay_s": 0.7, "gate_s": 0.7, "length_s": 0.8}, "gain_db": -5.0}],
                      bind=level(-12.0, -5.0), send=0.3, seed=519),
    "end": dict(voice="boing", params={"start_hz": 80.0, "end_hz": 40.0, "drop_s": 0.08, "decay_s": 0.25, "sub": 1.0, "click": 0.3},
                layers=[{"voice": "&mallet", "params": {"freq_hz": 110.0, "material": "&bar", "hardness": 0.8, "decay_s": 0.22}, "gain_db": -7.0}],
                transforms=[{"type": "varispeed", "from": 1.0, "to": 0.5}],
                bind=level(-9.0, -3.0), send=0.3, seed=520),
}

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

names = {"tape_start": "tape.start", "mh_rise": "mh.rise", "stamp_small": "stamp.small", "ftf_rise": "ftf.rise", "drain_out": "drain.out"}
cue_map(os.path.join(D, "timecity_map.tres"), {names.get(k, k): R + k + ".tres" for k in fx},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.55, "damp": 0.35, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.3)
with open(os.path.join(D, "timecity_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 7.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music (120 bpm, D minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=601,
       params={"tune_hz": 46.0, "punch": 4.0, "decay_s": 0.32, "click": 0.6, "drive": 0.5}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=602, send=0.35,
       params={"bursts": 4, "color_hz": 1400.0, "tail_decay_s": 0.14}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=603, send=0.25,
       params={"tone_hz": 220.0, "tone": 0.35, "noise": 0.9, "noise_hz": 6500.0, "noise_decay_s": 0.08},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=604, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.025, "tone_hz": 10000.0, "metal": 0.8}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "metal.tres"), voice="fm", seed=605, send=0.3,
       params={"freq_hz": 293.66, "ratio": 2.76, "index": 6.0, "index_end": 0.5, "index_decay_s": 0.05, "decay_s": 0.16, "gate_s": 0.02, "release_s": 0.08},
       transforms=[{"type": "varispeed", "from": 1.0, "to": 0.8}], bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=606,
       params={"position": 0.9, "sub": 0.5, "cutoff_hz": 380.0, "env_octaves": 2.0, "filter_decay_s": 0.09, "q": 2.5,
               "attack_s": 0.002, "decay_s": 0.1, "sustain": 0.5, "release_s": 0.03},
       bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "arp.tres"), voice="wavetable", seed=607, send=0.35,
       params={"position": 0.7, "cutoff_hz": 1500.0, "env_octaves": 1.6, "filter_decay_s": 0.06, "q": 3.0,
               "attack_s": 0.002, "decay_s": 0.08, "sustain": 0.0, "release_s": 0.04},
       transforms=[{"type": "varispeed", "from": 1.02, "to": 0.97}], bind=level(-10.0, 0.0))
# reversed metal swells: a decaying FM chime rendered 1.9 s and played backwards,
# so each one placed on a bar swells into the next downbeat
recipe(os.path.join(MD, "rev.tres"), voice="fm", seed=608, send=0.45,
       params={"freq_hz": 293.66, "ratio": 1.41, "index": 4.0, "index_end": 0.4, "index_decay_s": 0.6, "decay_s": 1.5, "sustain": 0.0,
               "release_s": 0.4, "length_s": 1.9},
       fx=[{"type": "lowpass", "cutoff_hz": 3500.0}],
       transforms=[{"type": "reverse"}, {"type": "fade", "in_s": 0.1, "out_s": 0.01}], bind=level(-10.0, 0.0))

BASS_NOTES = [38, 38, 50, 38, 41, 38, 48, 38]
ARP = ["D5", "A4", "F4", "A4", "D5", "C5", "A4", "F4", "D5", "A4", "F4", "A4", "E5", "C5", "A4", "G4"]
kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick_half = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.......x.......", "length": 16}
kick_light = {"name": "kick", "recipe": M + "kick.tres", "steps": "x.......x.......", "length": 16, "gain_db": -3.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -6.0}
hat = {"name": "hat", "recipe": M + "hat.tres", "steps": "o.x.o.x.o.x.o.xo", "length": 16, "gain_db": -13.0, "pan": 0.2}
metal = {"name": "metal", "recipe": M + "metal.tres", "steps": "..x..x....x..x.x", "length": 16, "gain_db": -12.0, "pan": -0.25}
tick = {"name": "metal", "recipe": M + "metal.tres", "steps": "..o...o...o...o.", "length": 16, "gain_db": -15.0, "pan": -0.25}
bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.x.x.x.x.x.x.x.", "length": 16, "notes": BASS_NOTES, "gate": 0.7, "gain_db": -4.0}
bass_held = {"name": "bass", "recipe": M + "bass.tres", "steps": "x-------x-------", "length": 16, "notes": [38, 36], "gate": 0.9, "gain_db": -5.0}
bass_climb = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.x.x.x.x.x.x.x.", "length": 16, "notes": [38, 38, 41, 41, 43, 43, 45, 48], "gate": 0.7, "gain_db": -4.0}
arp = {"name": "arp", "recipe": M + "arp.tres", "steps": "x" * 16, "length": 16, "notes": ARP, "gate": 0.6, "gain_db": -13.0, "pan": 0.15}
arp_sparse = dict(arp, steps="x.x.x.x.x.x.x.x.", gain_db=-15.0)
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "o...o...o.o.o.o.oooooooxxxxXXXX"[:16], "length": 16, "gain_db": -7.0}
roll2 = {"name": "snare", "recipe": M + "snare.tres", "steps": "o.o.o.o.xoxoxxXX", "length": 16, "gain_db": -6.0}
rev = {"name": "rev", "recipe": M + "rev.tres", "steps": "x...............", "length": 16, "notes": ["D4"], "gate": 15.0, "gain_db": -12.0, "pan": -0.1}

P = "AKPattern"
pat = lambda name, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                    {"steps": 16, "seed": len(name), "lanes": lanes}, typed={"lanes"})
pat("spin", [kick_light, tick, bass])
pat("mh", [kick, clap, metal, bass, arp_sparse])
pat("smear", [kick_half, tick, bass_held, rev])
pat("rise", [kick_light, roll, bass_climb])
pat("rise2", [kick, roll2, bass_climb, rev])
pat("drive", [kick, clap, hat, metal, bass, arp, rev])
pat("outro", [kick_light, hat, bass])
pat("silence", [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 120.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "spin", "bars": 1.0, "patterns": [M + "spin.tres"], "automation": {"bass.cutoff_hz": [[0.0, 160.0], [1.0, 420.0]]}},
        {"name": "mh", "bars": 1.0, "patterns": [M + "mh.tres"]},
        {"name": "smear", "bars": 1.0, "patterns": [M + "smear.tres"], "automation": {"bass.cutoff_hz": [[0.0, 300.0], [1.0, 200.0]]}},
        {"name": "rise", "bars": 0.5, "patterns": [M + "rise.tres"], "automation": {"bass.cutoff_hz": [[0.0, 220.0], [1.0, 400.0]]}},
        {"name": "rise2", "bars": 0.5, "patterns": [M + "rise2.tres"], "automation": {"bass.cutoff_hz": [[0.0, 400.0], [1.0, 700.0]]}},
        {"name": "drive", "bars": 2.0, "patterns": [M + "drive.tres"],
         "automation": {"arp.cutoff_hz": [[0.0, 900.0], [0.6, 2600.0], [1.0, 1800.0]], "bass.cutoff_hz": [[0.0, 380.0], [1.0, 620.0]]}},
        {"name": "outro", "bars": 0.75, "patterns": [M + "outro.tres"],
         "automation": {"bass.gain_db": [[0.0, 0.0], [1.0, -14.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -10.0]], "bass.cutoff_hz": [[0.0, 500.0], [1.0, 140.0]]}},
        {"name": "tail", "bars": 0.25, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, timecity_map.tres and the 120 bpm song" % len(fx))
