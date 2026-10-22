#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF "Fuel Lines" take (demo/ftf/ftf_fuel/ftf_fuel.gd): effect
recipes, the cue map and a 180 bpm "piston techno" bed for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_fuel/audio/make.py

Sound sheet (engine bay: pneumatics, pumps, liquid; shared reverb 0.3, music
ducks 7 dB under the hits):
  pump.start   motor spinning up: a saw glide with accelerating ratchet ticks
  trace        fine dry ticks as pipes draw themselves
  trace.out    the same ticks, reversed, as the schematic un-draws
  valve        pneumatic clack: a woody body click plus a short steam spit
  valve.close  a lower, drier clack
  pour         fuel pouring in: liquid bloops (wobbling boing) over brown rush
  full         tank full: a deep thunk and a metal bar note
  gauge        needle slamming over: a metal tick with a short rattle
  placard      a riveted plate clanking into place
  drain        draining out: a sine gurgling down over brown noise
  surge        the manifold flooding: a low pink whoosh
  rim          the tank rim tracing itself: a charge-up glide
  riser        pressure building into the drop (swells in, peaks on the drop)
  drop         the tank slams full: driven kick, sub, splash and clang
  slap         fuel slapping the tank top on each beat: wet band-passed slap
  sweep        the pressure wave through the letters each bar
  purge        coolant purge: a long steam hiss
  clunk        the last valve: a big metal clunk into reverb
Music: 180 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 40 frames.
  intro    bars 0-3       sub pulses, steam hats, sparse bloops (Minimal Humans)
  network  bars 3-4.75    kick and pistons in, pumping bass opening up
  gap      a beat         only the riser
  drop     bars 5-8.5     full groove: kick, piston clank, bass, bloop arp, horn stab
  outro    bars 8.5-10    kick and bass running down
  tail     half a bar     silence; the clunk rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_fuel/audio/"
M = "res://demo/ftf/ftf_fuel/audio/music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "pump_start": dict(voice="tone", params={"wave": "&saw", "freq_hz": 45.0, "end_hz": 150.0, "glide_s": 0.35, "attack_s": 0.05, "decay_s": 0.4,
                       "sustain": 0.6, "gate_s": 0.6, "release_s": 0.15, "length_s": 0.9},
                       layers=[{"voice": "&ratchet", "params": {"length_s": 0.8, "start_rate_hz": 8.0, "end_rate_hz": 40.0, "click_hz": 1800.0, "q": 3.0, "fade": 0.2}, "gain_db": -6.0}],
                       fx=[{"type": "lowpass", "cutoff_hz": 1800.0, "slope_db": 24.0}],
                       bind=pitched(-12.0, -4.0), send=0.15, seed=301),
    "trace": dict(voice="ratchet", params={"length_s": 0.5, "start_rate_hz": 60.0, "end_rate_hz": 40.0, "click_hz": 7000.0, "q": 5.0, "fade": 0.5, "jitter": 0.3},
                  bind=level(-24.0, -14.0), seed=302),
    "valve": dict(voice="click", params={"freq_hz": 1600.0, "mode": "&band", "q": 6.0, "decay_s": 0.012, "body_hz": 140.0, "body": 0.8},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 0.16, "low_hz": 3000.0, "high_hz": 9000.0, "peak": 0.15, "shape": 2.0, "mode": "&high"}, "gain_db": -9.0, "offset_s": 0.01}],
                  bind=pitched(-10.0, -2.0), send=0.2, seed=303),
    "pour": dict(voice="boing", params={"start_hz": 520.0, "end_hz": 260.0, "drop_s": 0.04, "decay_s": 0.09, "wobble_hz": 18.0, "wobble_semitones": 5.0, "sub": 0.1, "click": 0.0},
                 layers=[{"voice": "&boing", "params": {"start_hz": 700.0, "end_hz": 330.0, "drop_s": 0.03, "decay_s": 0.07, "wobble_hz": 22.0, "wobble_semitones": 4.0, "click": 0.0}, "gain_db": -3.0, "offset_s": 0.11},
                         {"voice": "&boing", "params": {"start_hz": 440.0, "end_hz": 220.0, "drop_s": 0.04, "decay_s": 0.08, "wobble_hz": 16.0, "wobble_semitones": 6.0, "click": 0.0}, "gain_db": -4.0, "offset_s": 0.24},
                         {"voice": "&whoosh", "params": {"length_s": 1.3, "low_hz": 150.0, "high_hz": 900.0, "peak": 0.5, "shape": 1.2, "noise": "&brown"}, "gain_db": -6.0}],
                 bind=level(-12.0, -4.0), send=0.25, seed=304),
    "full": dict(voice="boing", params={"start_hz": 180.0, "end_hz": 55.0, "drop_s": 0.05, "decay_s": 0.35, "sub": 0.8, "click": 0.4},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 196.0, "material": "&bar", "hardness": 0.6, "decay_s": 0.6}, "gain_db": -6.0}],
                 bind=pitched(-6.0, 0.0), send=0.35, seed=305),
    "gauge": dict(voice="click", params={"freq_hz": 4200.0, "mode": "&band", "q": 9.0, "decay_s": 0.02, "body_hz": 0.0},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 0.12, "start_rate_hz": 90.0, "end_rate_hz": 40.0, "click_hz": 5000.0, "q": 6.0, "fade": 0.8}, "gain_db": -10.0, "offset_s": 0.02}],
                  bind=pitched(-16.0, -8.0), send=0.15, seed=306),
    "placard": dict(voice="mallet", params={"freq_hz": 330.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.25},
                    layers=[{"voice": "&click", "params": {"freq_hz": 2400.0, "mode": "&band", "q": 3.0, "decay_s": 0.006, "body_hz": 110.0, "body": 0.6}, "gain_db": -4.0}],
                    bind=level(-12.0, -5.0), send=0.25, seed=307),
    "drain": dict(voice="tone", params={"wave": "&sine", "freq_hz": 420.0, "end_hz": 90.0, "glide_s": 0.4, "vibrato_hz": 14.0, "vibrato_semitones": 2.5,
                  "attack_s": 0.02, "decay_s": 0.6, "sustain": 0.4, "gate_s": 0.7, "release_s": 0.2, "length_s": 1.0},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 1.0, "low_hz": 120.0, "high_hz": 700.0, "peak": 0.3, "shape": 1.2, "noise": "&brown"}, "gain_db": -5.0}],
                  bind=pitched(-10.0, -3.0), send=0.3, seed=308),
    "surge": dict(voice="whoosh", params={"length_s": 0.7, "low_hz": 120.0, "high_hz": 2600.0, "peak": 0.3, "shape": 1.5, "noise": "&pink"},
                  bind=level(-12.0, -4.0), send=0.25, seed=309),
    "rim": dict(voice="tone", params={"wave": "&saw", "freq_hz": 220.0, "end_hz": 880.0, "glide_s": 0.25, "attack_s": 0.02, "decay_s": 0.3, "sustain": 0.3, "gate_s": 0.45, "release_s": 0.1, "length_s": 0.6},
                fx=[{"type": "bandpass", "cutoff_hz": 1400.0, "q": 1.5}],
                bind=level(-16.0, -8.0), send=0.3, seed=310),
    "riser": dict(voice="whoosh", params={"length_s": 0.75, "low_hz": 200.0, "high_hz": 7000.0, "peak": 0.96, "shape": 3.0, "mode": "&band", "q": 2.5, "noise": "&pink"},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 0.75, "start_rate_hz": 10.0, "end_rate_hz": 70.0, "click_hz": 3000.0, "q": 4.0, "fade": 0.0}, "gain_db": -8.0},
                          {"voice": "&tone", "params": {"wave": "&square", "width": 0.3, "freq_hz": 110.0, "end_hz": 440.0, "glide_s": 0.4, "attack_s": 0.5, "sustain": 1.0, "gate_s": 0.75, "release_s": 0.003, "length_s": 0.75}, "gain_db": -12.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 8000.0, "slope_db": 12.0}],
                  bind=level(-12.0, -5.0), send=0.15, offset_s=-0.75, seed=311),
    "drop": dict(voice="kick", params={"tune_hz": 46.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.55, "click": 0.7, "drive": 0.55},
                 layers=[{"voice": "&boing", "params": {"start_hz": 150.0, "end_hz": 40.0, "drop_s": 0.15, "decay_s": 0.45, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.5, "low_hz": 500.0, "high_hz": 6000.0, "peak": 0.05, "shape": 2.0, "noise": "&pink"}, "gain_db": -7.0},
                         {"voice": "&mallet", "params": {"freq_hz": 147.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.6}, "gain_db": -9.0}],
                 bind=level(-4.0, 0.0), send=0.3, seed=312),
    "slap": dict(voice="whoosh", params={"length_s": 0.09, "low_hz": 700.0, "high_hz": 2600.0, "peak": 0.08, "shape": 2.5, "mode": "&band", "q": 2.0},
                 layers=[{"voice": "&boing", "params": {"start_hz": 600.0, "end_hz": 300.0, "drop_s": 0.02, "decay_s": 0.05, "wobble_hz": 20.0, "wobble_semitones": 3.0, "click": 0.0}, "gain_db": -6.0}],
                 bind=pitched(-20.0, -11.0), vary={"high_hz": 0.2, "length_s": 0.15}, vary_variants=4, send=0.2, seed=313),
    "sweep": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 400.0, "high_hz": 6000.0, "peak": 0.45, "shape": 2.0},
                  layers=[{"voice": "&tone", "params": {"wave": "&triangle", "freq_hz": 660.0, "end_hz": 1320.0, "glide_s": 0.15, "decay_s": 0.2, "gate_s": 0.2, "length_s": 0.4}, "gain_db": -12.0}],
                  bind=level(-14.0, -7.0), send=0.3, seed=314),
    "purge": dict(voice="whoosh", params={"length_s": 0.9, "low_hz": 2500.0, "high_hz": 9500.0, "peak": 0.12, "shape": 1.2, "mode": "&high"},
                  bind=level(-14.0, -7.0), send=0.2, seed=315),
    "clunk": dict(voice="boing", params={"start_hz": 140.0, "end_hz": 48.0, "drop_s": 0.06, "decay_s": 0.4, "sub": 0.9, "click": 0.6},
                  layers=[{"voice": "&mallet", "params": {"freq_hz": 110.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.9}, "gain_db": -5.0},
                          {"voice": "&click", "params": {"freq_hz": 1200.0, "mode": "&band", "q": 4.0, "decay_s": 0.015, "body_hz": 90.0, "body": 0.8}, "gain_db": -3.0}],
                  bind=level(-4.0, 0.0), send=0.5, seed=316),
}
fx["valve_close"] = dict(fx["valve"], params=dict(fx["valve"]["params"], freq_hz=1100.0, body_hz=110.0), layers=[], seed=317)
fx["trace_out"] = dict(fx["trace"], transforms=[{"type": "reverse"}], offset_s=-0.5, seed=318)

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

names = {"pump.start": "pump_start", "trace": "trace", "trace.out": "trace_out", "valve": "valve", "valve.close": "valve_close",
         "pour": "pour", "full": "full", "gauge": "gauge", "placard": "placard", "drain": "drain", "surge": "surge", "rim": "rim",
         "riser": "riser", "drop": "drop", "slap": "slap", "sweep": "sweep", "purge": "purge", "clunk": "clunk"}
cue_map(os.path.join(D, "fuel_map.tres"), {k: R + v + ".tres" for k, v in names.items()},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.3, "damp": 0.55, "width": 1.0, "quality": "&full", "return_db": -2.0}, end_fade_s=0.4)
with open(os.path.join(D, "fuel_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 7.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.2}\n')

# ------------------------------------------------------------------ music (180 bpm)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 52.0, "punch": 4.0, "decay_s": 0.22, "click": 0.5, "drive": 0.45}, bind=level(-7.0, 0.0))
recipe(os.path.join(MD, "piston.tres"), voice="fm", seed=402, send=0.2,
       params={"freq_hz": 330.0, "ratio": 3.5, "index": 6.0, "index_end": 0.5, "index_decay_s": 0.04, "decay_s": 0.09, "gate_s": 0.05, "release_s": 0.04},
       layers=[{"voice": "&snare", "params": {"tone_hz": 240.0, "tone": 0.2, "noise": 0.7, "noise_hz": 6500.0, "noise_decay_s": 0.07}, "gain_db": -4.0}],
       vary={"index": 0.2}, vary_variants=4, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "steam.tres"), voice="hat", seed=403, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.07, "tone_hz": 7000.0, "metal": 0.25}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "tick.tres"), voice="hat", seed=404, params={"decay_s": 0.02, "tone_hz": 11000.0, "metal": 0.7}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=405,
       params={"position": 0.85, "sub": 0.5, "cutoff_hz": 380.0, "env_octaves": 2.4, "filter_decay_s": 0.06, "q": 2.5,
               "attack_s": 0.002, "decay_s": 0.08, "sustain": 0.2, "release_s": 0.02},
       fx=[{"type": "drive", "amount": 0.3}], bind=level(-9.0, 0.0))
recipe(os.path.join(MD, "bloop.tres"), voice="fm", seed=406, send=0.35,
       params={"freq_hz": 660.0, "ratio": 1.0, "index": 2.5, "index_end": 0.0, "index_decay_s": 0.05, "decay_s": 0.1, "gate_s": 0.06, "release_s": 0.05},
       bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "horn.tres"), voice="wavetable", seed=407, send=0.4,
       params={"position": 0.95, "unison": 5, "detune_cents": 18.0, "cutoff_hz": 1200.0, "env_octaves": 1.6, "filter_decay_s": 0.12,
               "q": 1.4, "attack_s": 0.004, "decay_s": 0.2, "sustain": 0.2, "release_s": 0.08})

# F minor-ish: the bass pumps eighths, the bloops climb a pentatonic run.
bass_notes = [29, 29, 41, 29, 32, 29, 41, 34]
bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.x.X.x.x.x.X.x.", "length": 16, "notes": bass_notes, "gate": 0.7, "gain_db": -3.0}
bass_soft = dict(bass, steps="o...o...o...o...", gain_db=-8.0)
kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.......X.....x.", "length": 16}
kick_one = {"name": "kick", "recipe": M + "kick.tres", "steps": "o" + "." * 15, "length": 16, "gain_db": -5.0}
kick_four = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
piston = {"name": "piston", "recipe": M + "piston.tres", "steps": "....X.......X..o", "length": 16, "gain_db": -3.0}
piston_roll = {"name": "piston", "recipe": M + "piston.tres", "steps": "....X.......X..o....X...o.oXoXXX", "length": 32, "gain_db": -3.0}
steam = {"name": "steam", "recipe": M + "steam.tres", "steps": "..x...x...x...x.", "length": 16, "gain_db": -13.0, "pan": -0.2}
tick = {"name": "tick", "recipe": M + "tick.tres", "steps": "x.o.x.oox.o.x.oo", "length": 16, "gain_db": -16.0, "pan": 0.25}
bloop = {"name": "bloop", "recipe": M + "bloop.tres", "steps": "x..x..x.x..x.x..", "length": 16, "degrees": [1, 3, 5, 8, 5, 3, 6, 4], "scale": "minor_pentatonic", "root": "F5", "gain_db": -15.0}
bloop_sparse = dict(bloop, steps="x.......x.....x.", gain_db=-17.0)
horn = {"name": "horn", "recipe": M + "horn.tres", "steps": "X" + "." * 31, "length": 32, "notes": ["F4", "Ab4"], "chord": [0, 3, 7, 10], "gate": 3.0, "gain_db": -11.0}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name) + 40, "lanes": lanes}, typed={"lanes"})
pat("intro", 16, [bass_soft, kick_one, steam, bloop_sparse])
pat("network", 32, [kick, piston_roll, steam, tick, bass, bloop_sparse])
pat("drop", 32, [kick, piston, steam, tick, bass, bloop, horn])
pat("outro", 16, [kick_four, steam, bass])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 180.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "fuel_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 3.0, "patterns": [M + "intro.tres"], "automation": {"bass.cutoff_hz": [[0.0, 220.0], [1.0, 380.0]]}},
        {"name": "network", "bars": 1.75, "patterns": [M + "network.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 300.0], [1.0, 1300.0]], "bass.q": [[0.0, 2.0], [1.0, 6.0]]}},
        {"name": "gap", "bars": 0.25, "patterns": [M + "silence.tres"]},
        {"name": "drop", "bars": 3.5, "patterns": [M + "drop.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 900.0], [0.5, 1500.0], [1.0, 800.0]]}},
        {"name": "outro", "bars": 1.5, "patterns": [M + "outro.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 800.0], [1.0, 150.0]], "bass.gain_db": [[0.0, 0.0], [1.0, -14.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -10.0]]}},
        {"name": "tail", "bars": 0.5, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, fuel_map.tres and the 180 bpm song" % len(fx))
