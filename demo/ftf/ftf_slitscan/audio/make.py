#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Slit-Scan take (demo/ftf/ftf_slitscan/ftf_slitscan.gd):
effect recipes, the cue map and a 180 bpm drum & bass bed, for the Godot Audio
Kit. Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_slitscan/audio/make.py

Sound sheet (shared reverb 0.4, music ducks 6 dB under the hits). The family:
thin glassy lines, scanner tones that trace the slit, metal and tape stops.
  slit       a glassy line opening: high glass ping over a falling sine
  rise       noise and saw swelling for 1.3 s into the MH snap
  snap       sharp hit: body thump, glass ping, noise crack
  whip       fast band whoosh as PRESENTS whips in
  type       fine ratchet under the katakana
  ripple     FM bell bending down: a time ripple, pitched per kick
  fold       a scanner tone diving 1400 -> 160 Hz with a dark whoosh
  glitch     crushed static burst as the colours flip
  tunnel     big driven impact with a sub drop and a long noise tail
  ring       short metal bars on every tunnel beat, climbing a minor pentatonic
  riser      1.4 s pink noise + saw climb into the scan, cut dead
  scan       a square-wave scanner whose pitch follows the slit (left, right, centre)
  snap.big   the drop: driven kick, sub, glass and a noise slap
  split      FM zap per accent (the RGB time split)
  pass       a band whoosh sweeping up as the scanner bump crosses the logo
  tear       bitcrushed stutter, tape-stopping
  stretch    tape stop: a saw falling away with a whoosh as the logo streaks off
  tail       a last glass ping over a soft sub
Music: 180 bpm, 4/4, first downbeat at 0.0 s; a bar is 40 frames.
  intro  bars 0-3     pad, sub on the bar, soft hats (Minimal Humans)
  tunnel bars 3-5     two-step break and reese bass
  scan   bar 5        drums out, reese and pad (the logo scan)
  drop   bars 6-8.5   full break, reese, metallic stabs
  outro  bar 8.5-9.5  kick and hats, reese closing
  tail   bar 9.5-10.5 silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_slitscan/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

# The scan tone traces the slit: 0.2 -> 0.8 -> 0.5 of the width over 13 + 13 frames.
SCAN_S = 26 / 30.0

fx = {
    "slit": dict(voice="mallet", params={"freq_hz": 2093.0, "material": "&glass", "hardness": 0.5, "decay_s": 0.45},
                 layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 3200.0, "end_hz": 900.0, "glide_s": 0.15, "decay_s": 0.3, "gate_s": 0.3, "length_s": 0.5}, "gain_db": -12.0}],
                 bind=level(-16.0, -8.0), send=0.5, seed=301),
    "rise": dict(voice="whoosh", params={"length_s": 1.3, "low_hz": 300.0, "high_hz": 11000.0, "peak": 0.97, "shape": 3.0, "noise": "&pink"},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 110.0, "end_hz": 880.0, "glide_s": 0.6, "attack_s": 1.0, "sustain": 1.0, "gate_s": 1.3, "release_s": 0.004, "length_s": 1.3}, "gain_db": -9.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 8000.0, "slope_db": 12.0}],
                 bind=level(-14.0, -6.0), send=0.2, offset_s=-1.3, seed=302),
    "snap": dict(voice="boing", params={"start_hz": 260.0, "end_hz": 60.0, "drop_s": 0.03, "decay_s": 0.18, "sub": 0.7, "click": 0.9, "click_hz": 9000.0},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 1568.0, "material": "&glass", "hardness": 0.8, "decay_s": 0.5}, "gain_db": -8.0},
                         {"voice": "&snare", "params": {"tone": 0.2, "noise": 1.0, "noise_hz": 8000.0, "noise_decay_s": 0.09}, "gain_db": -7.0}],
                 bind=level(-6.0, 0.0), send=0.35, seed=303),
    "whip": dict(voice="whoosh", params={"length_s": 0.18, "low_hz": 900.0, "high_hz": 9000.0, "peak": 0.8, "mode": "&band", "q": 1.4},
                 bind=level(-14.0, -6.0), send=0.2, seed=304),
    "type": dict(voice="ratchet", params={"length_s": 0.3, "start_rate_hz": 60.0, "end_rate_hz": 40.0, "click_hz": 7500.0, "q": 6.0, "fade": 0.4},
                 bind=level(-24.0, -14.0), seed=305),
    "ripple": dict(voice="fm", params={"freq_hz": 660.0, "ratio": 1.41, "index": 6.0, "index_end": 0.3, "index_decay_s": 0.25, "decay_s": 0.5, "gate_s": 0.25, "release_s": 0.2},
                   layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 660.0, "end_hz": 330.0, "glide_s": 0.15, "decay_s": 0.3, "gate_s": 0.3, "length_s": 0.45}, "gain_db": -6.0}],
                   bind=pitched(-14.0, -6.0), send=0.4, seed=306),
    "fold": dict(voice="follow", params={"wave": "&saw", "length_s": 0.7, "pitch": [[0.0, 1400.0], [0.7, 160.0]], "level": [[0.0, 0.0], [0.05, 1.0], [0.5, 0.6], [0.7, 0.0]], "glide": 0.3},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.7, "low_hz": 150.0, "high_hz": 2500.0, "peak": 0.25, "noise": "&brown"}, "gain_db": -4.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 4000.0}],
                 bind=level(-14.0, -6.0), send=0.3, seed=307),
    "glitch": dict(voice="static", params={"length_s": 0.14, "hiss": 0.8, "color_hz": 3600.0, "q": 0.9, "crackles_per_s": 1200.0, "crackle": 1.0, "flicker_hz": 60.0, "fade_s": 0.003},
                   fx=[{"type": "bitcrush", "bits": 5.0, "hold": 3}],
                   bind=level(-14.0, -5.0), seed=308),
    "tunnel": dict(voice="kick", params={"tune_hz": 42.0, "punch": 6.0, "drop_s": 0.05, "decay_s": 0.7, "click": 0.8, "drive": 0.6},
                   layers=[{"voice": "&boing", "params": {"start_hz": 120.0, "end_hz": 32.0, "drop_s": 0.25, "decay_s": 0.6, "sub": 1.0, "click": 0.0}, "gain_db": -5.0},
                           {"voice": "&whoosh", "params": {"length_s": 1.0, "low_hz": 2000.0, "high_hz": 12000.0, "peak": 0.03, "shape": 1.2, "mode": "&high"}, "gain_db": -10.0}],
                   bind=level(-4.0, 0.0), send=0.35, seed=309),
    "ring": dict(voice="mallet", params={"freq_hz": 659.25, "material": "&bar", "hardness": 0.85, "decay_s": 0.18},
                 bind=pitched(-18.0, -9.0), vary={"decay_s": 0.15}, send=0.3, seed=310),
    "riser": dict(voice="whoosh", params={"length_s": 1.4, "low_hz": 250.0, "high_hz": 12000.0, "peak": 0.98, "shape": 3.2, "noise": "&pink"},
                  layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 165.0, "end_hz": 1980.0, "glide_s": 0.7, "attack_s": 1.1, "sustain": 1.0, "gate_s": 1.4, "release_s": 0.004, "length_s": 1.4}, "gain_db": -6.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 9000.0, "slope_db": 12.0}],
                  bind=level(-12.0, -5.0), send=0.15, offset_s=-1.4, seed=311),
    "scan": dict(voice="follow", params={"wave": "&square", "length_s": 1.25,
                 "pitch": [[0.0, 300.0], [SCAN_S * 0.5, 1200.0], [SCAN_S, 600.0], [1.25, 600.0]],
                 "level": [[0.0, 0.0], [0.03, 1.0], [SCAN_S, 0.8], [1.25, 0.0]], "glide": 0.4},
                 layers=[{"voice": "&static", "params": {"length_s": 1.2, "hiss": 0.3, "color_hz": 6000.0, "crackles_per_s": 200.0, "crackle": 0.4, "fade_s": 0.05}, "gain_db": -14.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 3000.0}, {"type": "echo", "time_s": 1.0 / 6.0, "feedback": 0.35, "mix": 0.3}],
                 bind=level(-18.0, -9.0), send=0.25, seed=312),
    "snap_big": dict(voice="kick", params={"tune_hz": 46.0, "punch": 5.5, "drop_s": 0.04, "decay_s": 0.55, "click": 0.9, "drive": 0.55},
                     layers=[{"voice": "&boing", "params": {"start_hz": 150.0, "end_hz": 36.0, "drop_s": 0.14, "decay_s": 0.5, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                             {"voice": "&mallet", "params": {"freq_hz": 1318.5, "material": "&glass", "hardness": 0.9, "decay_s": 0.7}, "gain_db": -10.0},
                             {"voice": "&whoosh", "params": {"length_s": 0.4, "low_hz": 500.0, "high_hz": 10000.0, "peak": 0.03, "shape": 2.5}, "gain_db": -6.0}],
                     bind=level(-4.0, 0.0), send=0.35, seed=313),
    "split": dict(voice="fm", params={"freq_hz": 220.0, "ratio": 3.5, "index": 9.0, "index_end": 0.0, "index_decay_s": 0.06, "decay_s": 0.12, "gate_s": 0.08, "release_s": 0.05},
                  layers=[{"voice": "&click", "params": {"freq_hz": 6000.0, "mode": "&band", "q": 3.0, "decay_s": 0.003}, "gain_db": -6.0}],
                  bind=pitched(-14.0, -6.0), send=0.25, seed=314),
    "pass": dict(voice="whoosh", params={"length_s": 0.47, "low_hz": 700.0, "high_hz": 7000.0, "peak": 0.55, "mode": "&band", "q": 2.5},
                 layers=[{"voice": "&follow", "params": {"wave": "&triangle", "length_s": 0.47, "pitch": [[0.0, 500.0], [0.47, 1500.0]], "level": [[0.0, 0.0], [0.2, 1.0], [0.47, 0.0]]}, "gain_db": -12.0}],
                 bind=pitched(-16.0, -8.0), send=0.3, seed=315),
    "tear": dict(voice="static", params={"length_s": 0.22, "hiss": 0.9, "color_hz": 2600.0, "q": 0.7, "crackles_per_s": 1600.0, "crackle": 1.0, "flicker_hz": 36.0, "fade_s": 0.004},
                 layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 880.0, "end_hz": 110.0, "glide_s": 0.05, "decay_s": 0.15, "gate_s": 0.15, "length_s": 0.22}, "gain_db": -8.0}],
                 fx=[{"type": "bitcrush", "bits": 4.0, "hold": 4}],
                 transforms=[{"type": "varispeed", "from": 1.0, "to": 0.3}],
                 bind=level(-8.0, -2.0), seed=316),
    "stretch": dict(voice="tone", params={"wave": "&saw", "freq_hz": 440.0, "sustain": 1.0, "gate_s": 0.9, "release_s": 0.05, "length_s": 1.0},
                    layers=[{"voice": "&whoosh", "params": {"length_s": 0.9, "low_hz": 200.0, "high_hz": 6000.0, "peak": 0.15, "noise": "&pink"}, "gain_db": -6.0}],
                    fx=[{"type": "lowpass", "cutoff_hz": 2500.0}],
                    transforms=[{"type": "varispeed", "from": 1.0, "to": 0.0}, {"type": "fade", "out_s": 0.2}],
                    bind=level(-10.0, -3.0), send=0.3, seed=317),
    "tail": dict(voice="mallet", params={"freq_hz": 1760.0, "material": "&glass", "hardness": 0.5, "decay_s": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 48.0, "drop_s": 0.1, "decay_s": 0.25, "sub": 0.8, "click": 0.05}, "gain_db": -8.0}],
                 bind=level(-10.0, -3.0), send=0.5, seed=318),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

names = {k: k.replace("_", ".") if k == "snap_big" else k for k in fx}
cue_map(os.path.join(D, "ftf_slitscan_map.tres"), {names[k]: R + k + ".tres" for k in fx},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.45, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -2.0}, end_fade_s=0.4)
with open(os.path.join(D, "ftf_slitscan_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.22}\n')

# ------------------------------------------------------------------ music (180 bpm)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 52.0, "punch": 4.0, "drop_s": 0.025, "decay_s": 0.22, "click": 0.6, "drive": 0.3}, bind=level(-7.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=402, send=0.25,
       params={"tone_hz": 220.0, "tone": 0.45, "tone_decay_s": 0.05, "noise": 0.9, "noise_hz": 7000.0, "noise_decay_s": 0.12},
       vary={"noise_hz": 0.12}, vary_variants=4, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=403, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.022, "tone_hz": 10500.0, "metal": 0.5}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "ride.tres"), voice="hat", seed=404, params={"decay_s": 0.35, "tone_hz": 7000.0, "metal": 0.85, "tune": 1.3}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "reese.tres"), voice="wavetable", seed=405,
       params={"position": 0.68, "unison": 7, "detune_cents": 32.0, "sub": 0.55, "cutoff_hz": 520.0, "env_octaves": 1.2, "filter_decay_s": 0.35, "q": 1.4,
               "attack_s": 0.01, "decay_s": 0.4, "sustain": 0.8, "release_s": 0.08},
       fx=[{"type": "drive", "amount": 0.3}], bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "stab.tres"), voice="fm", seed=406, send=0.4,
       params={"ratio": 3.5, "index": 4.0, "index_end": 0.4, "index_decay_s": 0.12, "decay_s": 0.25, "gate_s": 0.12, "release_s": 0.12})
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=407, send=0.55,
       params={"position": 0.45, "unison": 5, "detune_cents": 14.0, "cutoff_hz": 1400.0, "env_octaves": 0.4, "filter_decay_s": 1.2,
               "q": 0.6, "attack_s": 0.5, "decay_s": 1.0, "sustain": 0.75, "release_s": 0.4})
recipe(os.path.join(MD, "sub.tres"), voice="tone", seed=408, params={"wave": "&sine", "freq_hz": 41.2, "attack_s": 0.01, "decay_s": 0.6, "sustain": 0.5, "gate_s": 0.8, "release_s": 0.2},
       bind=level(-6.0, 0.0))

kick2 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.........X.....X.........x...x.", "length": 32}
snare2 = {"name": "snare", "recipe": M + "snare.tres", "steps": "....X.......X.....o.X..o....X..o", "length": 32, "gain_db": -1.0}
hats = {"name": "hat", "recipe": M + "hat.tres", "steps": "x.o.x.oox.o.x.o.", "length": 16, "gain_db": -12.0, "pan": 0.2}
ride = {"name": "ride", "recipe": M + "ride.tres", "steps": "..x...x...x...x.", "length": 16, "gain_db": -18.0, "pan": -0.2}
reese = {"name": "reese", "recipe": M + "reese.tres", "steps": "X.......x.......", "length": 16, "notes": [40, 40, 43, 38], "gate": 7.6, "gain_db": -4.0}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "......x.....x...", "length": 16, "notes": ["E4", "G4"], "chord": [0, 3, 7, 10], "gate": 1.0, "gain_db": -12.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 31, "length": 32, "notes": ["E3", "C3"], "chord": [0, 7, 10, 14, 15], "gate": 31.0, "gain_db": -10.0}
sub = {"name": "sub", "recipe": M + "sub.tres", "steps": "x" + "." * 15, "length": 16, "notes": [28, 28, 24], "gate": 8.0, "gain_db": -6.0}
hat_soft = {"name": "hat", "recipe": M + "hat.tres", "steps": "..o...o...o..oo.", "length": 16, "gain_db": -16.0, "pan": 0.2}
kick_thin = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.......x.......", "length": 16}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name) + 7, "humanize_ms": 2.0, "lanes": lanes}, typed={"lanes"})
pat("intro", 32, [pad, sub, hat_soft])
pat("tunnel", 32, [kick2, snare2, hats, reese])
pat("scan", 16, [reese, pad])
pat("drop", 32, [kick2, snare2, hats, ride, reese, stab])
pat("outro", 16, [kick_thin, hats, reese])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 180.0, "beats_per_bar": 4, "offset_s": 0.0})
resource(os.path.join(MD, "song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 3.0, "patterns": [M + "intro.tres"]},
        {"name": "tunnel", "bars": 2.0, "patterns": [M + "tunnel.tres"],
         "automation": {"reese.cutoff_hz": [[0.0, 300.0], [1.0, 1100.0]]}},
        {"name": "scan", "bars": 1.0, "patterns": [M + "scan.tres"],
         "automation": {"reese.cutoff_hz": [[0.0, 1200.0], [1.0, 250.0]], "reese.gain_db": [[0.0, -2.0], [1.0, -10.0]]}},
        {"name": "drop", "bars": 2.5, "patterns": [M + "drop.tres"],
         "automation": {"reese.cutoff_hz": [[0.0, 600.0], [0.5, 1400.0], [1.0, 800.0]]}},
        {"name": "outro", "bars": 1.0, "patterns": [M + "outro.tres"],
         "automation": {"reese.cutoff_hz": [[0.0, 800.0], [1.0, 180.0]], "reese.gain_db": [[0.0, 0.0], [1.0, -14.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -10.0]]}},
        {"name": "tail", "bars": 1.0, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -5.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, the cue map and the 180 bpm song" % len(fx))
