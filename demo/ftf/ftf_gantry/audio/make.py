#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the Gantry take (demo/ftf/ftf_gantry/ftf_gantry.gd): effect
recipes, cue map and a dark, rolling 150 bpm bed for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_gantry/audio/make.py

Sound sheet (shared reverb 0.5, a big dark space; music ducks 8 dB):
  power       heavy relay clunk with a low hum swelling under it, climbing per step
  hud.type    fine dry ratchet: the HUD writing itself
  launch      engine spool: saw glide up with a pink whoosh, peaking on the bar
  neon        fluorescent strike: crackling static and a 100 Hz mains buzz
  presents    a short ratchet run and a cold glass ping
  pass        big pass-by whoosh peaking under the MH gantry
  gate        overhead whoosh + metal thunk, one per sponsor gantry
  tunnel      low brown-noise roar opening up as the tunnel swallows us
  drop        the reveal: driven kick, sub drop, noise slap and a cold FM chord
  brake       air brake: bright hiss with a falling tone
  settle      crane landing: slow ratchet into a soft sub thump
  callout     two small triangle blips
  ship        doppler fly-by: falling saw tone inside a band whoosh
  crane       low rising hum as the camera lifts away
  cut         relay clunk with a falling tone, deeper each step
  sign.cut    power-down: tape-stopped tone, static burst and sub thump
Music: 150 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 48 frames.
  power   bars 0-1      a low drone opening up, ticking hats
  run     bars 1-3.75   rolling 16th bass, four-on-the-floor, rims
  roll    bars 3.75-4   a snare roll into the drop
  drop    bars 4-7      full: kick, snare, rolling bass, minor stabs, ride
  outro   bars 7-8      bass closing down, pad, single kicks
  tail    bars 8-8.75   silence; the power-down rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_gantry/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "power": dict(voice="click", params={"freq_hz": 1800.0, "mode": "&band", "q": 2.0, "decay_s": 0.02, "body_hz": 70.0, "body": 1.0},
                  layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 55.0, "attack_s": 0.05, "decay_s": 0.3, "sustain": 0.4, "gate_s": 0.35, "release_s": 0.1}, "gain_db": -10.0},
                          {"voice": "&boing", "params": {"start_hz": 120.0, "end_hz": 45.0, "drop_s": 0.06, "decay_s": 0.2, "sub": 0.8, "click": 0.2}, "gain_db": -4.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 2400.0}], bind=pitched(-8.0, -1.0), send=0.4, seed=401),
    "hud_type": dict(voice="ratchet", params={"length_s": 0.7, "start_rate_hz": 60.0, "end_rate_hz": 40.0, "click_hz": 6500.0, "q": 5.0, "fade": 0.4},
                     bind=level(-24.0, -15.0), seed=402),
    "launch": dict(voice="tone", params={"wave": "&saw", "freq_hz": 55.0, "end_hz": 220.0, "glide_s": 0.25, "attack_s": 0.2, "decay_s": 0.4, "sustain": 0.6, "gate_s": 0.6, "release_s": 0.15, "length_s": 0.9},
                   layers=[{"voice": "&whoosh", "params": {"length_s": 0.8, "low_hz": 200.0, "high_hz": 5000.0, "peak": 0.45, "shape": 1.6, "noise": "&pink"}, "gain_db": -3.0}],
                   fx=[{"type": "lowpass", "cutoff_hz": 3500.0}, {"type": "drive", "amount": 0.3}], bind=level(-8.0, -1.0), send=0.3, seed=403),
    "neon": dict(voice="static", params={"length_s": 0.3, "hiss": 0.5, "color_hz": 4200.0, "q": 0.9, "crackles_per_s": 200.0, "crackle": 1.0, "flicker_hz": 30.0, "flicker_depth": 0.9, "fade_s": 0.01},
                 layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 100.0, "attack_s": 0.002, "decay_s": 0.2, "sustain": 0.5, "gate_s": 0.25, "release_s": 0.05, "length_s": 0.32}, "gain_db": -12.0}],
                 fx=[{"type": "highpass", "cutoff_hz": 80.0}], bind=level(-14.0, -5.0), send=0.3, seed=404),
    "presents": dict(voice="ratchet", params={"length_s": 0.34, "start_rate_hz": 34.0, "end_rate_hz": 30.0, "click_hz": 3600.0, "q": 5.0, "fade": 0.2},
                     layers=[{"voice": "&mallet", "params": {"freq_hz": 1174.7, "material": "&glass", "hardness": 0.5, "decay_s": 0.6}, "gain_db": -6.0, "offset_s": 0.34}],
                     bind=level(-16.0, -7.0), send=0.45, seed=405),
    "pass": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 150.0, "high_hz": 6000.0, "peak": 0.45, "shape": 2.0, "noise": "&pink"},
                 layers=[{"voice": "&boing", "params": {"start_hz": 140.0, "end_hz": 50.0, "drop_s": 0.08, "decay_s": 0.2, "sub": 0.6, "click": 0.1}, "gain_db": -8.0, "offset_s": 0.2}],
                 bind=level(-10.0, -2.0), send=0.3, seed=406),
    "gate": dict(voice="whoosh", params={"length_s": 0.3, "low_hz": 300.0, "high_hz": 5000.0, "peak": 0.45, "shape": 2.2, "noise": "&pink"},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 140.0, "material": "&metal", "hardness": 0.8, "decay_s": 0.25}, "gain_db": -9.0, "offset_s": 0.13}],
                 bind=pitched(-12.0, -4.0), vary={"high_hz": 0.15}, send=0.3, seed=407),
    "tunnel": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 80.0, "high_hz": 1400.0, "peak": 0.3, "shape": 1.4, "noise": "&brown", "q": 2.0},
                   bind=level(-8.0, -1.0), send=0.5, seed=408),
    "drop": dict(voice="kick", params={"tune_hz": 42.0, "punch": 5.0, "drop_s": 0.05, "decay_s": 0.7, "click": 0.8, "drive": 0.6},
                 layers=[{"voice": "&boing", "params": {"start_hz": 140.0, "end_hz": 32.0, "drop_s": 0.2, "decay_s": 0.6, "sub": 1.0, "click": 0.0}, "gain_db": -3.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.5, "low_hz": 400.0, "high_hz": 9000.0, "peak": 0.03, "shape": 2.5}, "gain_db": -6.0},
                         {"voice": "&fm", "params": {"freq_hz": 146.83, "ratio": 3.5, "index": 6.0, "index_end": 0.8, "index_decay_s": 0.4, "decay_s": 1.0, "gate_s": 0.8, "release_s": 0.4}, "gain_db": -10.0},
                         {"voice": "&fm", "params": {"freq_hz": 220.0, "ratio": 3.5, "index": 6.0, "index_end": 0.8, "index_decay_s": 0.4, "decay_s": 1.0, "gate_s": 0.8, "release_s": 0.4}, "gain_db": -12.0}],
                 bind=level(-4.0, 0.0), send=0.4, seed=409),
    "brake": dict(voice="whoosh", params={"length_s": 0.6, "low_hz": 2500.0, "high_hz": 11000.0, "peak": 0.08, "shape": 1.2, "mode": "&high"},
                  layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 260.0, "end_hz": 70.0, "glide_s": 0.25, "decay_s": 0.4, "gate_s": 0.4, "length_s": 0.6}, "gain_db": -12.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 9000.0}], bind=level(-12.0, -4.0), send=0.3, seed=410),
    "settle": dict(voice="ratchet", params={"length_s": 0.2, "start_rate_hz": 24.0, "end_rate_hz": 12.0, "click_hz": 1500.0, "q": 3.0, "fade": 0.3},
                   layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 45.0, "drop_s": 0.07, "decay_s": 0.3, "sub": 0.9, "click": 0.2}, "gain_db": -2.0, "offset_s": 0.2}],
                   bind=level(-12.0, -4.0), send=0.35, seed=411),
    "callout": dict(voice="tone", params={"wave": "&triangle", "freq_hz": 1760.0, "end_hz": 2349.3, "glide_s": 0.02, "decay_s": 0.06, "gate_s": 0.06, "length_s": 0.12},
                    bind=pitched(-20.0, -12.0), send=0.3, seed=412),
    "ship": dict(voice="whoosh", params={"length_s": 0.7, "low_hz": 400.0, "high_hz": 7000.0, "peak": 0.55, "shape": 2.0, "mode": "&band", "q": 1.1},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 820.0, "end_hz": 330.0, "glide_s": 0.18, "attack_s": 0.25, "decay_s": 0.3, "sustain": 0.0, "gate_s": 0.4, "length_s": 0.7}, "gain_db": -14.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 6000.0}], bind=pitched(-12.0, -4.0), send=0.35, seed=413),
    "crane": dict(voice="tone", params={"wave": "&saw", "freq_hz": 50.0, "end_hz": 75.0, "glide_s": 0.6, "attack_s": 0.4, "decay_s": 0.6, "sustain": 0.5, "gate_s": 1.0, "release_s": 0.3, "length_s": 1.4},
                  fx=[{"type": "lowpass", "cutoff_hz": 700.0}], bind=level(-14.0, -7.0), send=0.4, seed=414),
    "cut": dict(voice="click", params={"freq_hz": 1200.0, "mode": "&band", "q": 2.5, "decay_s": 0.03, "body_hz": 60.0, "body": 1.0},
                layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 220.0, "end_hz": 90.0, "glide_s": 0.08, "decay_s": 0.15, "gate_s": 0.15, "length_s": 0.3}, "gain_db": -12.0}],
                fx=[{"type": "lowpass", "cutoff_hz": 3000.0}], bind=pitched(-8.0, -2.0), send=0.45, seed=415),
    "sign_cut": dict(voice="tone", params={"wave": "&saw", "freq_hz": 330.0, "attack_s": 0.002, "decay_s": 0.5, "sustain": 0.7, "gate_s": 0.6, "release_s": 0.2, "length_s": 0.9},
                     layers=[{"voice": "&static", "params": {"length_s": 0.25, "hiss": 0.8, "color_hz": 3000.0, "crackles_per_s": 800.0, "crackle": 1.0, "flicker_hz": 40.0}, "gain_db": -6.0},
                             {"voice": "&boing", "params": {"start_hz": 90.0, "end_hz": 30.0, "drop_s": 0.15, "decay_s": 0.5, "sub": 1.0, "click": 0.3}, "gain_db": 0.0}],
                     fx=[{"type": "lowpass", "cutoff_hz": 2500.0}], transforms=[{"type": "varispeed", "from": 1.0, "to": 0.2}],
                     bind=level(-6.0, 0.0), send=0.5, seed=416),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "gantry_map.tres"), {
    "power": R + "power.tres", "hud.type": R + "hud_type.tres", "launch": R + "launch.tres", "neon": R + "neon.tres",
    "presents": R + "presents.tres", "pass": R + "pass.tres", "gate": R + "gate.tres", "tunnel": R + "tunnel.tres",
    "drop": R + "drop.tres", "brake": R + "brake.tres", "settle": R + "settle.tres", "callout": R + "callout.tres",
    "ship": R + "ship.tres", "crane": R + "crane.tres", "cut": R + "cut.tres", "sign.cut": R + "sign_cut.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.6, "damp": 0.6, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.4)
with open(os.path.join(D, "gantry_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 8.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music: D minor, 150 bpm
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=501,
       params={"tune_hz": 46.0, "punch": 4.0, "decay_s": 0.32, "click": 0.35, "drive": 0.45}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=502, send=0.35,
       params={"tone_hz": 180.0, "tone": 0.45, "noise": 0.9, "noise_hz": 4500.0, "noise_decay_s": 0.18},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-18.0, 0.0))
recipe(os.path.join(MD, "rim.tres"), voice="click", seed=503, params={"freq_hz": 2200.0, "mode": "&band", "q": 6.0, "decay_s": 0.02, "body_hz": 400.0, "body": 0.4},
       bind=level(-12.0, 0.0), send=0.3)
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=504, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.025, "tone_hz": 9000.0, "metal": 0.7}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "ride.tres"), voice="hat", seed=505, params={"decay_s": 0.35, "tone_hz": 7000.0, "metal": 0.85, "tune": 0.8}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=506,
       params={"position": 0.72, "sub": 0.45, "cutoff_hz": 320.0, "env_octaves": 2.4, "filter_decay_s": 0.08, "q": 2.5,
               "attack_s": 0.002, "decay_s": 0.1, "sustain": 0.3, "release_s": 0.03},
       fx=[{"type": "drive", "amount": 0.4}], bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "drone.tres"), voice="wavetable", seed=507, send=0.4,
       params={"position": 0.7, "unison": 5, "detune_cents": 14.0, "sub": 0.5, "cutoff_hz": 260.0, "env_octaves": 0.4, "filter_decay_s": 2.0,
               "q": 1.5, "attack_s": 0.6, "decay_s": 1.0, "sustain": 0.8, "release_s": 0.4})
recipe(os.path.join(MD, "stab.tres"), voice="wavetable", seed=508, send=0.5,
       params={"position": 0.66, "unison": 5, "detune_cents": 20.0, "cutoff_hz": 1300.0, "env_octaves": 1.6, "filter_decay_s": 0.08,
               "q": 1.4, "attack_s": 0.002, "decay_s": 0.16, "sustain": 0.0, "release_s": 0.08})
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=509, send=0.6,
       params={"position": 0.45, "unison": 5, "detune_cents": 18.0, "cutoff_hz": 900.0, "env_octaves": 0.4, "filter_decay_s": 1.0,
               "q": 0.7, "attack_s": 0.5, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.4})

# rolling bass: root on the beat, octave and fifth rolling under it (D1 = 26)
ROLL = [26, 38, 26, 33, 26, 38, 36, 33]
bass_run = {"name": "bass", "recipe": M + "bass.tres", "steps": "Xxox" * 4, "length": 16,
            "notes": [26, 38, 33, 38, 26, 38, 36, 33, 26, 38, 33, 38, 29, 41, 36, 41], "gate": 0.6, "gain_db": -2.0}
bass_drop = {"name": "bass", "recipe": M + "bass.tres", "steps": "Xxox" * 8, "length": 32,
             "notes": [26, 38, 33, 38, 26, 38, 36, 33, 29, 41, 36, 41, 29, 41, 40, 36, 24, 36, 31, 36, 24, 36, 33, 31, 22, 34, 29, 34, 21, 33, 28, 33],
             "gate": 0.6, "gain_db": -1.0}
kick4 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick1 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...............", "length": 16, "gain_db": -2.0}
rim = {"name": "rim", "recipe": M + "rim.tres", "steps": "....x.......x..o", "length": 16, "gain_db": -12.0, "pan": -0.2}
hat_tick = {"name": "hat", "recipe": M + "hat.tres", "steps": "..o...o...o...o.", "length": 16, "gain_db": -15.0, "pan": 0.2}
hat_run = {"name": "hat", "recipe": M + "hat.tres", "steps": "o.x.o.x.o.x.o.xo", "length": 16, "gain_db": -12.0, "pan": 0.2}
snare = {"name": "snare", "recipe": M + "snare.tres", "steps": "....X.......X...", "length": 16, "gain_db": -3.0}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "1234567891234589", "length": 16, "gain_db": -6.0}
ride = {"name": "ride", "recipe": M + "ride.tres", "steps": "x.o.x.o.x.o.x.o.", "length": 16, "gain_db": -16.0, "pan": -0.25}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "..x.....x.....x.", "length": 16, "notes": ["D4", "D4", "C4"], "chord": [0, 3, 7], "gate": 1.0, "gain_db": -11.0}
drone = {"name": "drone", "recipe": M + "drone.tres", "steps": "x" + "." * 47, "length": 48, "notes": ["D2"], "chord": [0, 7, 12], "gate": 47.0, "gain_db": -8.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 31, "length": 32, "notes": ["D3", "A#2"], "chord": [0, 3, 7, 10], "gate": 31.0, "gain_db": -12.0}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name) + 7, "lanes": lanes}, typed={"lanes"})
pat("power", 48, [drone, hat_tick])
pat("run", 32, [kick4, bass_run, rim, hat_run])
pat("roll", 16, [roll, bass_run])
pat("drop", 32, [kick4, snare, bass_drop, hat_run, ride, stab, pad])
pat("outro", 16, [kick1, bass_run, pad])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 150.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "gantry_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "power", "bars": 1.0, "patterns": [M + "power.tres"], "automation": {"drone.cutoff_hz": [[0.0, 120.0], [1.0, 600.0]]}},
        {"name": "run", "bars": 2.75, "patterns": [M + "run.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 220.0], [1.0, 900.0]]}},
        {"name": "roll", "bars": 0.25, "patterns": [M + "roll.tres"], "automation": {"bass.cutoff_hz": [[0.0, 900.0], [1.0, 1600.0]]}},
        {"name": "drop", "bars": 3.0, "patterns": [M + "drop.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 700.0], [0.5, 1200.0], [1.0, 800.0]]}},
        {"name": "outro", "bars": 1.0, "patterns": [M + "outro.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 600.0], [1.0, 140.0]], "bass.gain_db": [[0.0, 0.0], [1.0, -12.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -6.0]]}},
        {"name": "tail", "bars": 0.75, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, gantry_map.tres and the 150 bpm song" % len(fx))
