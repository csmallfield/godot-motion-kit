#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Checkerboard City take: effect recipes, the cue map and a
112.5 bpm synthwave / demoscene bed. Needs the audio kit linked
(tools/link_audio_kit.sh). Regenerate: python3 demo/ftf/ftf_checkercity/audio/make.py

Sound sheet (shared reverb 0.5, big and 80s; music ducks 6 dB under the hits):
  dive       long pink whoosh falling into the board
  sprout     rising square blips as the city sprouts
  mh.rise    a slow saw swell with a sub, the monument rising like a sunrise
  mh.land    a deep gated tom boom with a glass ping
  presents   two bright FM bell notes
  pulse      short tom hits on the beat while the board pulses
  mh.sink    a reversed swell
  tube.in    a filtered noise zap into the tube
  flip       chip blips, one per colour flip, climbing
  tube.out   a downward whoosh
  rise       a riser swelling into the drop
  drop       driven kick, sub boom, gated noise: the logo out of the floor
  ring       a sine sweep down with a soft thump: the shockwave rings
  halve      a ratchet tick run as the board halves
  swerve     a pink whoosh on the road's swerves
  sink       a reversed tom swell as the logo sinks
  fold       a long rumbling sweep as the ground folds into a wall
  close      a dark boom with a long tail: the wall closes
Music: 112.5 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 64 frames.
  intro  bar 0          pad and a soft arp (the dive)
  mh     bar 1          kick, octave bass, arp, pad (Minimal Humans)
  tube   bars 2-2.75    full, the arp doubles up (the tube)
  build  bar 2.75-3     snare roll
  drop   bars 3-5       full: gated snare, octave bass, arp, stabs (logo hold)
  outro  bar 5          kick and bass, filter closing (the fold)
  tail   bar 6-6.5625   silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_checkercity/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "dive": dict(voice="whoosh", params={"length_s": 1.1, "low_hz": 180.0, "high_hz": 6000.0, "peak": 0.25, "shape": 1.6, "noise": "&pink"},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 900.0, "end_hz": 110.0, "glide_s": 0.35, "decay_s": 0.8, "gate_s": 0.8, "length_s": 1.0}, "gain_db": -16.0}],
                 bind=level(-12.0, -4.0), send=0.3, seed=301),
    "sprout": dict(voice="tone", params={"wave": "&square", "freq_hz": 440.0, "end_hz": 1760.0, "glide_s": 0.25, "decay_s": 0.3, "gate_s": 0.35, "length_s": 0.5},
                   fx=[{"type": "lowpass", "cutoff_hz": 4000.0}], bind=level(-20.0, -12.0), send=0.3, seed=302),
    "mh_rise": dict(voice="tone", params={"wave": "&saw", "freq_hz": 110.0, "end_hz": 220.0, "glide_s": 0.5, "attack_s": 0.6, "decay_s": 0.2, "sustain": 1.0, "gate_s": 0.75, "release_s": 0.05, "length_s": 0.8},
                    layers=[{"voice": "&whoosh", "params": {"length_s": 0.8, "low_hz": 150.0, "high_hz": 2500.0, "peak": 0.95, "shape": 2.5, "noise": "&brown"}, "gain_db": -6.0}],
                    fx=[{"type": "lowpass", "cutoff_hz": 2200.0, "slope_db": 12.0}], bind=level(-14.0, -6.0), send=0.4, seed=303),
    "mh_land": dict(voice="boing", params={"start_hz": 150.0, "end_hz": 48.0, "drop_s": 0.08, "decay_s": 0.4, "sub": 0.9, "click": 0.5},
                    layers=[{"voice": "&mallet", "params": {"freq_hz": 1318.5, "material": "&glass", "hardness": 0.5, "decay_s": 0.6}, "gain_db": -10.0}],
                    transforms=[{"type": "trim", "length_s": 0.62}, {"type": "fade", "out_s": 0.12}],
                    bind=level(-4.0, 0.0), send=0.5, seed=304),
    "presents": dict(voice="fm", params={"freq_hz": 880.0, "ratio": 3.5, "index": 4.0, "index_end": 0.5, "index_decay_s": 0.15, "decay_s": 0.6, "gate_s": 0.1},
                     layers=[{"voice": "&fm", "params": {"freq_hz": 1318.5, "ratio": 3.5, "index": 3.0, "index_end": 0.4, "index_decay_s": 0.15, "decay_s": 0.6, "gate_s": 0.1}, "gain_db": -3.0, "offset_s": 0.13}],
                     bind=level(-12.0, -5.0), send=0.5, seed=305),
    "pulse": dict(voice="boing", params={"start_hz": 240.0, "end_hz": 120.0, "drop_s": 0.05, "decay_s": 0.16, "sub": 0.3, "click": 0.4},
                  bind=pitched(-14.0, -7.0), send=0.4, seed=306),
    "mh_sink": dict(voice="whoosh", params={"length_s": 0.45, "low_hz": 200.0, "high_hz": 3000.0, "peak": 0.9, "shape": 2.0, "noise": "&brown"},
                    bind=level(-16.0, -8.0), send=0.3, seed=307),
    "tube_in": dict(voice="whoosh", params={"length_s": 0.42, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.95, "shape": 2.6, "mode": "&band", "q": 2.0},
                    layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 200.0, "end_hz": 1600.0, "glide_s": 0.15, "decay_s": 0.3, "gate_s": 0.4, "length_s": 0.42}, "gain_db": -12.0}],
                    bind=level(-12.0, -4.0), send=0.3, seed=308),
    "flip": dict(voice="tone", params={"wave": "&square", "freq_hz": 659.25, "decay_s": 0.07, "gate_s": 0.06, "length_s": 0.14},
                 layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 1318.5, "decay_s": 0.05, "gate_s": 0.04, "length_s": 0.1}, "gain_db": -6.0, "offset_s": 0.06}],
                 fx=[{"type": "lowpass", "cutoff_hz": 5000.0}], bind=pitched(-18.0, -9.0), send=0.3, seed=309),
    "tube_out": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 200.0, "high_hz": 5000.0, "peak": 0.3, "shape": 1.8, "noise": "&pink"},
                     bind=level(-14.0, -6.0), send=0.3, seed=310),
    "rise": dict(voice="tone", params={"wave": "&saw", "freq_hz": 110.0, "end_hz": 1760.0, "glide_s": 0.25, "attack_s": 0.4, "decay_s": 0.1, "sustain": 1.0, "gate_s": 0.53, "release_s": 0.004, "length_s": 0.53},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.53, "low_hz": 300.0, "high_hz": 10000.0, "peak": 0.97, "shape": 3.0, "noise": "&pink"}, "gain_db": -3.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 7000.0, "slope_db": 12.0}], bind=level(-14.0, -6.0), send=0.15, seed=311),
    "drop": dict(voice="kick", params={"tune_hz": 46.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.55, "click": 0.7, "drive": 0.45},
                 layers=[{"voice": "&boing", "params": {"start_hz": 130.0, "end_hz": 36.0, "drop_s": 0.14, "decay_s": 0.5, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&snare", "params": {"tone_hz": 180.0, "tone": 0.4, "noise": 1.0, "noise_hz": 7000.0, "noise_decay_s": 0.3}, "gain_db": -5.0}],
                 transforms=[{"type": "trim", "length_s": 0.65}, {"type": "fade", "out_s": 0.1}],
                 bind=level(-4.0, 0.0), send=0.4, seed=312),
    "ring": dict(voice="tone", params={"wave": "&sine", "freq_hz": 1400.0, "end_hz": 140.0, "glide_s": 0.18, "decay_s": 0.5, "gate_s": 0.5, "length_s": 0.7},
                 layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 50.0, "drop_s": 0.06, "decay_s": 0.2, "sub": 0.6, "click": 0.2}, "gain_db": -6.0}],
                 bind=level(-14.0, -6.0), send=0.4, seed=313),
    "halve": dict(voice="ratchet", params={"length_s": 0.35, "start_rate_hz": 60.0, "end_rate_hz": 30.0, "click_hz": 5000.0, "q": 5.0, "fade": 0.5},
                  bind=level(-18.0, -9.0), seed=314),
    "swerve": dict(voice="whoosh", params={"length_s": 0.6, "low_hz": 250.0, "high_hz": 6000.0, "peak": 0.5, "shape": 1.6, "noise": "&pink"},
                   bind=level(-16.0, -8.0), send=0.3, seed=315),
    "sink": dict(voice="boing", params={"start_hz": 200.0, "end_hz": 60.0, "drop_s": 0.08, "decay_s": 0.3, "sub": 0.6, "click": 0.3},
                 transforms=[{"type": "reverse"}], offset_s=-0.4, bind=level(-12.0, -5.0), send=0.3, seed=316),
    "fold": dict(voice="whoosh", params={"length_s": 1.7, "low_hz": 80.0, "high_hz": 2200.0, "peak": 0.8, "shape": 1.8, "noise": "&brown"},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 55.0, "end_hz": 110.0, "glide_s": 0.8, "attack_s": 0.6, "decay_s": 0.4, "sustain": 0.8, "gate_s": 1.5, "length_s": 1.7}, "gain_db": -10.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 1800.0, "slope_db": 24.0}], bind=level(-12.0, -4.0), send=0.3, seed=317),
    "close": dict(voice="kick", params={"tune_hz": 40.0, "punch": 4.0, "drop_s": 0.05, "decay_s": 0.7, "click": 0.5, "drive": 0.4},
                  layers=[{"voice": "&boing", "params": {"start_hz": 90.0, "end_hz": 32.0, "drop_s": 0.2, "decay_s": 0.6, "sub": 1.0, "click": 0.0}, "gain_db": -4.0}],
                  bind=level(-4.0, 0.0), send=0.5, seed=318),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "cc_map.tres"), {
    "dive": R + "dive.tres", "sprout": R + "sprout.tres", "mh.rise": R + "mh_rise.tres", "mh.land": R + "mh_land.tres",
    "presents": R + "presents.tres", "pulse": R + "pulse.tres", "mh.sink": R + "mh_sink.tres", "tube.in": R + "tube_in.tres",
    "flip": R + "flip.tres", "tube.out": R + "tube_out.tres", "rise": R + "rise.tres", "drop": R + "drop.tres",
    "ring": R + "ring.tres", "halve": R + "halve.tres", "swerve": R + "swerve.tres", "sink": R + "sink.tres",
    "fold": R + "fold.tres", "close": R + "close.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.5, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -2.0}, end_fade_s=0.9)
with open(os.path.join(D, "cc_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.25}\n')

# ------------------------------------------------------------------ music (112.5 bpm, A minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 52.0, "punch": 3.0, "decay_s": 0.3, "click": 0.35, "drive": 0.25}, bind=level(-7.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=402, send=0.35,
       params={"tone_hz": 200.0, "tone": 0.5, "noise": 0.85, "noise_hz": 5000.0, "noise_decay_s": 0.18},
       transforms=[{"type": "trim", "length_s": 0.2}, {"type": "fade", "out_s": 0.04}], vary={"noise_hz": 0.08}, vary_variants=4, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=403, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.03, "tone_hz": 9000.0, "metal": 0.5}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=404,
       params={"position": 0.66, "sub": 0.3, "cutoff_hz": 700.0, "env_octaves": 2.0, "filter_decay_s": 0.1, "q": 1.5,
               "attack_s": 0.002, "decay_s": 0.1, "sustain": 0.4, "release_s": 0.03}, bind=level(-9.0, 0.0))
recipe(os.path.join(MD, "arp.tres"), voice="tone", seed=405, send=0.35,
       params={"wave": "&square", "freq_hz": 440.0, "decay_s": 0.09, "gate_s": 0.07, "length_s": 0.14},
       fx=[{"type": "lowpass", "cutoff_hz": 3500.0}], bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=406, send=0.55,
       params={"position": 0.62, "unison": 5, "detune_cents": 18.0, "cutoff_hz": 1300.0, "env_octaves": 0.6, "filter_decay_s": 1.2,
               "q": 0.7, "attack_s": 0.4, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.4})
recipe(os.path.join(MD, "stab.tres"), voice="wavetable", seed=407, send=0.45,
       params={"position": 0.7, "unison": 5, "detune_cents": 20.0, "cutoff_hz": 2200.0, "env_octaves": 1.5, "filter_decay_s": 0.08,
               "q": 1.0, "attack_s": 0.002, "decay_s": 0.16, "sustain": 0.0, "release_s": 0.08})

# A minor: Am - F - C - G, one chord a bar (the take is short, so the loop turns each bar)
ROOTS = [45, 41, 48, 43]
bass_notes = [r - 12 + (12 if s % 2 else 0) for r in ROOTS for s in range(16)]   # octave bass on eighths
ARP = [0, 7, 12, 15, 12, 7, 19, 12]
arp_notes = [57 + a for a in ARP] * 8
pad_notes = [r + 12 for r in ROOTS]

bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.x.x.x.x.x.x.x." * 4, "notes": bass_notes[::2], "gate": 0.8, "gain_db": -2.0}
arp = {"name": "arp", "recipe": M + "arp.tres", "steps": "x.x.x.x.x.x.x.x.", "length": 16, "notes": arp_notes, "gate": 0.7, "gain_db": -9.0, "pan": 0.2}
arp16 = dict(arp, steps="xxxxxxxxxxxxxxxx", gain_db=-11.0)
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 15, "length": 16, "notes": pad_notes, "chord": [0, 3, 7, 12], "gate": 15.0, "gain_db": -9.0}
kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick_soft = {"name": "kick", "recipe": M + "kick.tres", "steps": "o.......o.......", "length": 16, "gain_db": -6.0}
snare = {"name": "snare", "recipe": M + "snare.tres", "steps": "....X.......X...", "length": 16, "gain_db": -3.0}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "o.o.x.x.xxxxXXXX", "length": 16, "gain_db": -6.0}
hat = {"name": "hat", "recipe": M + "hat.tres", "steps": "..x...x...x...x.", "length": 16, "gain_db": -12.0, "pan": -0.15}
hat16 = {"name": "hat", "recipe": M + "hat.tres", "steps": "oxoxoxoxoxoxoxox", "length": 16, "gain_db": -13.0, "pan": -0.15}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "......x.......x.", "length": 16, "notes": pad_notes, "chord": [0, 3, 7], "gate": 1.0, "gain_db": -11.0}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name), "lanes": lanes}, typed={"lanes"})
pat("intro", 64, [pad, arp, kick_soft])
pat("mh", 64, [pad, arp, kick, bass, hat])
pat("tube", 64, [pad, arp16, kick, snare, bass, hat16])
pat("build", 16, [roll, bass, arp16])
pat("drop", 64, [arp, kick, snare, bass, hat16, stab, pad])
pat("outro", 64, [kick, bass, hat])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 112.5, "beats_per_bar": 4, "offset_s": 0.0})
resource(os.path.join(MD, "cc_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"]},
        {"name": "mh", "bars": 1.0, "patterns": [M + "mh.tres"], "automation": {"bass.cutoff_hz": [[0.0, 400.0], [1.0, 800.0]]}},
        {"name": "tube", "bars": 0.75, "patterns": [M + "tube.tres"], "automation": {"bass.cutoff_hz": [[0.0, 900.0], [1.0, 1600.0]]}},
        {"name": "build", "bars": 0.25, "patterns": [M + "build.tres"]},
        {"name": "drop", "bars": 2.0, "patterns": [M + "drop.tres"], "automation": {"bass.cutoff_hz": [[0.0, 1200.0], [0.5, 1800.0], [1.0, 1000.0]]}},
        {"name": "outro", "bars": 1.0, "patterns": [M + "outro.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 900.0], [1.0, 180.0]], "bass.gain_db": [[0.0, 0.0], [1.0, -12.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -8.0]]}},
        {"name": "tail", "bars": 0.5625, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, cc_map.tres and the 112.5 bpm song" % len(fx))
