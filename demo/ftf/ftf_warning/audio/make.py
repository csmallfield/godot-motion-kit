#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Warning take (demo/ftf/ftf_warning/ftf_warning.gd):
effect recipes, the cue map and a 200 bpm gabber bed, for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_warning/audio/make.py

Sound sheet (dry industrial space, short room 0.25; music ducks 6 dB):
  alarm        a square-wave siren, wee-woo, once at the top
  whip         tape thrown in: a crack and a short swish (pitch in cue data)
  chain        chain rattle as the placard drops in
  slam         the placard hits the end of its chains: metal slam with a sub
  stamp        PRESENTS stamped: a dry thump with a clap
  stamp.small  提供, smaller and higher
  snap         the chains snap: a high metal ping and a downward swish
  sign         a warning sign stamped on: plate clank, climbing
  count        countdown beeps, square, climbing
  gate         barrier arm thunks down: hydraulic hiss and a knock
  wall         tape ripping across in a run
  drop         the drop: distorted kick, sub and a noise slap
  tear         the tape wall tearing open: crushed static and a fast rip
  clamp        hazard clamps hit: heavy clank
  bite         clamps bite on the bars: lighter clank
  klaxon       escalation: a buzzing two-tone horn
  close        tapes snapping closed across the screen
  yank         the tape wall yanked away: unspooling rip and a big swish
Music: 200 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 36 frames.
  intro    bar 0       kick on the one, ticking hats
  mh       bars 1-2    half-time kick, hats, a low hoover chord
  barrage  bar 3       four-to-the-floor gabber kick
  count    bar 4       kick, a snare roll building, hoover riser
  drop     bars 5-7    full gabber: kick, offbeat hats, hoover riff, clap
  alert    bars 8-9    as drop plus a square alarm arp (the escalation)
  outro    half bar    kick and hats only
  tail     to the end  silence (the yank and its tail)
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_warning/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "alarm": dict(voice="follow", params={"wave": "&square", "length_s": 1.05,
                  "pitch": [[0.0, 640.0], [0.17, 980.0], [0.35, 640.0], [0.52, 980.0], [0.7, 640.0], [0.87, 980.0], [1.05, 640.0]],
                  "level": [[0.0, 0.0], [0.04, 0.9], [0.9, 0.9], [1.05, 0.0]], "glide": 0.4},
                  fx=[{"type": "lowpass", "cutoff_hz": 3200.0, "slope_db": 24.0}, {"type": "drive", "amount": 0.3}],
                  bind=level(-16.0, -8.0), send=0.2, seed=301),
    "whip": dict(voice="whoosh", params={"length_s": 0.22, "low_hz": 900.0, "high_hz": 9000.0, "peak": 0.25, "shape": 2.4, "noise": "&white"},
                 layers=[{"voice": "&click", "params": {"freq_hz": 3200.0, "mode": "&band", "q": 3.0, "decay_s": 0.004, "body_hz": 220.0, "body": 0.4}, "gain_db": -2.0}],
                 bind=pitched(-14.0, -5.0), vary={"high_hz": 0.2, "length_s": 0.15}, vary_variants=4, send=0.15, seed=302),
    "chain": dict(voice="ratchet", params={"length_s": 0.26, "start_rate_hz": 46.0, "end_rate_hz": 22.0, "click_hz": 4300.0, "q": 9.0, "click_decay_s": 0.01,
                  "jitter": 0.35, "fade": 0.2}, bind=level(-16.0, -8.0), send=0.2, seed=303),
    "slam": dict(voice="boing", params={"start_hz": 320.0, "end_hz": 58.0, "drop_s": 0.04, "decay_s": 0.3, "sub": 0.9, "click": 1.0, "click_hz": 8000.0},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 147.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.5}, "gain_db": -5.0},
                         {"voice": "&snare", "params": {"tone_hz": 170.0, "tone": 0.3, "noise": 1.0, "noise_hz": 6000.0, "noise_decay_s": 0.16}, "gain_db": -7.0}],
                 bind=level(-5.0, 0.0), send=0.3, seed=304),
    "stamp": dict(voice="boing", params={"start_hz": 190.0, "end_hz": 70.0, "drop_s": 0.03, "decay_s": 0.12, "sub": 0.6, "click": 0.9},
                  layers=[{"voice": "&clap", "params": {"color_hz": 1500.0, "tail_decay_s": 0.08}, "gain_db": -4.0}],
                  bind=pitched(-8.0, -1.0), send=0.2, seed=305),
    "snap": dict(voice="mallet", params={"freq_hz": 1760.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.25},
                 layers=[{"voice": "&click", "params": {"freq_hz": 7000.0, "mode": "&high", "decay_s": 0.003}, "gain_db": 0.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.5, "low_hz": 200.0, "high_hz": 3000.0, "peak": 0.15, "noise": "&pink"}, "gain_db": -6.0, "offset_s": 0.03}],
                 bind=level(-10.0, -2.0), send=0.3, seed=306),
    "sign": dict(voice="boing", params={"start_hz": 260.0, "end_hz": 80.0, "drop_s": 0.03, "decay_s": 0.16, "sub": 0.5, "click": 0.9},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 330.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.3}, "gain_db": -6.0}],
                 bind=pitched(-8.0, -2.0), send=0.25, seed=307),
    "count": dict(voice="tone", params={"wave": "&square", "freq_hz": 880.0, "decay_s": 0.14, "sustain": 0.5, "gate_s": 0.12, "release_s": 0.03, "length_s": 0.2},
                  layers=[{"voice": "&click", "params": {"freq_hz": 5000.0, "mode": "&band", "q": 3.0, "decay_s": 0.002}, "gain_db": -6.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 5000.0}], bind=pitched(-14.0, -6.0), send=0.2, seed=308),
    "gate": dict(voice="whoosh", params={"length_s": 0.25, "low_hz": 300.0, "high_hz": 4500.0, "peak": 0.2, "shape": 1.2, "noise": "&white", "mode": "&band", "q": 1.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 140.0, "end_hz": 50.0, "drop_s": 0.05, "decay_s": 0.14, "sub": 0.6, "click": 0.6}, "gain_db": -2.0, "offset_s": 0.1}],
                 bind=level(-12.0, -4.0), send=0.25, seed=309),
    "wall": dict(voice="ratchet", params={"length_s": 0.32, "start_rate_hz": 140.0, "end_rate_hz": 70.0, "click_hz": 2600.0, "q": 2.0, "click_decay_s": 0.006, "jitter": 0.4, "fade": 0.1},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.3, "low_hz": 600.0, "high_hz": 8000.0, "peak": 0.7, "noise": "&pink"}, "gain_db": -4.0}],
                 bind=level(-12.0, -4.0), send=0.15, seed=310),
    "drop": dict(voice="kick", params={"tune_hz": 46.0, "punch": 6.0, "drop_s": 0.035, "decay_s": 0.55, "click": 0.8, "drive": 0.9},
                 layers=[{"voice": "&boing", "params": {"start_hz": 150.0, "end_hz": 36.0, "drop_s": 0.14, "decay_s": 0.5, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.4, "low_hz": 500.0, "high_hz": 10000.0, "peak": 0.04, "shape": 2.5}, "gain_db": -5.0}],
                 fx=[{"type": "drive", "amount": 0.5}], bind=level(-3.0, 0.0), send=0.25, seed=311),
    "tear": dict(voice="static", params={"length_s": 0.28, "hiss": 0.9, "color_hz": 3500.0, "q": 0.6, "crackles_per_s": 1600.0, "crackle": 1.0, "flicker_hz": 50.0, "fade_s": 0.01},
                 layers=[{"voice": "&ratchet", "params": {"length_s": 0.24, "start_rate_hz": 220.0, "end_rate_hz": 90.0, "click_hz": 3000.0, "q": 2.0, "jitter": 0.5}, "gain_db": -3.0}],
                 fx=[{"type": "bitcrush", "bits": 6.0}, {"type": "highpass", "cutoff_hz": 600.0}],
                 bind=level(-10.0, -3.0), send=0.15, seed=312),
    "clamp": dict(voice="mallet", params={"freq_hz": 98.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.6},
                  layers=[{"voice": "&boing", "params": {"start_hz": 240.0, "end_hz": 60.0, "drop_s": 0.03, "decay_s": 0.2, "sub": 0.8, "click": 1.0}, "gain_db": -2.0},
                          {"voice": "&click", "params": {"freq_hz": 6000.0, "mode": "&high", "decay_s": 0.004}, "gain_db": -2.0}],
                  bind=level(-5.0, 0.0), send=0.3, seed=313),
    "bite": dict(voice="mallet", params={"freq_hz": 196.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.25},
                 layers=[{"voice": "&click", "params": {"freq_hz": 5000.0, "mode": "&band", "q": 2.0, "decay_s": 0.003, "body_hz": 120.0, "body": 0.6}, "gain_db": -2.0}],
                 bind=level(-12.0, -5.0), send=0.2, seed=314),
    "klaxon": dict(voice="tone", params={"wave": "&saw", "freq_hz": 330.0, "end_hz": 300.0, "glide_s": 0.3, "vibrato_hz": 32.0, "vibrato_semitones": 0.5,
                   "attack_s": 0.01, "decay_s": 0.2, "sustain": 0.8, "gate_s": 0.42, "release_s": 0.05, "length_s": 0.55},
                   layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 415.0, "end_hz": 380.0, "glide_s": 0.3, "vibrato_hz": 32.0, "vibrato_semitones": 0.5,
                            "attack_s": 0.01, "decay_s": 0.2, "sustain": 0.8, "gate_s": 0.42, "release_s": 0.05, "length_s": 0.55}, "gain_db": -2.0}],
                   fx=[{"type": "lowpass", "cutoff_hz": 2600.0}, {"type": "drive", "amount": 0.4}],
                   bind=level(-12.0, -5.0), send=0.25, seed=315),
    "close": dict(voice="whoosh", params={"length_s": 0.3, "low_hz": 400.0, "high_hz": 9000.0, "peak": 0.35, "shape": 1.8, "noise": "&pink"},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 0.26, "start_rate_hz": 60.0, "end_rate_hz": 160.0, "click_hz": 2400.0, "q": 2.0, "jitter": 0.3}, "gain_db": -3.0},
                          {"voice": "&boing", "params": {"start_hz": 200.0, "end_hz": 60.0, "drop_s": 0.03, "decay_s": 0.15, "sub": 0.7, "click": 0.8}, "gain_db": -3.0, "offset_s": 0.24}],
                  bind=level(-8.0, -1.0), send=0.2, seed=316),
    "yank": dict(voice="whoosh", params={"length_s": 0.55, "low_hz": 300.0, "high_hz": 11000.0, "peak": 0.3, "shape": 1.6, "noise": "&white"},
                 layers=[{"voice": "&ratchet", "params": {"length_s": 0.45, "start_rate_hz": 200.0, "end_rate_hz": 40.0, "click_hz": 2000.0, "q": 2.0, "jitter": 0.4, "fade": 0.6}, "gain_db": -2.0}],
                 bind=level(-8.0, -1.0), send=0.3, seed=317),
}
fx["stamp_small"] = dict(fx["stamp"], bind=level(-12.0, -6.0), params=dict(fx["stamp"]["params"], start_hz=280.0, end_hz=110.0))

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

names = {"alarm": "alarm", "whip": "whip", "chain": "chain", "slam": "slam", "stamp": "stamp", "stamp.small": "stamp_small",
         "snap": "snap", "sign": "sign", "count": "count", "gate": "gate", "wall": "wall", "drop": "drop", "tear": "tear",
         "clamp": "clamp", "bite": "bite", "klaxon": "klaxon", "close": "close", "yank": "yank"}
cue_map(os.path.join(D, "warning_map.tres"), {k: R + v + ".tres" for k, v in names.items()},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.25, "damp": 0.6, "width": 1.0, "quality": "&full", "return_db": -4.0}, end_fade_s=0.4)
with open(os.path.join(D, "warning_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -18.0, "attack_s": 0.004, "release_s": 0.2}\n')

# ------------------------------------------------------------------ music (200 bpm gabber)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 52.0, "punch": 6.0, "drop_s": 0.03, "decay_s": 0.26, "click": 0.6, "drive": 0.95},
       fx=[{"type": "drive", "amount": 0.75}, {"type": "lowpass", "cutoff_hz": 7000.0}], bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=402, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.03, "tone_hz": 9500.0, "metal": 0.7}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=403, send=0.15,
       params={"tone_hz": 210.0, "tone": 0.4, "noise": 0.9, "noise_hz": 6000.0, "noise_decay_s": 0.1},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=404, send=0.2, params={"color_hz": 1400.0, "tail_decay_s": 0.1}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "hoover.tres"), voice="wavetable", seed=405, send=0.25,
       params={"position": 0.66, "unison": 7, "detune_cents": 45.0, "cutoff_hz": 2600.0, "env_octaves": 1.2, "filter_decay_s": 0.2, "q": 1.4,
               "attack_s": 0.004, "decay_s": 0.2, "sustain": 0.5, "release_s": 0.08},
       fx=[{"type": "drive", "amount": 0.4}], bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=406, send=0.4,
       params={"position": 0.62, "unison": 5, "detune_cents": 30.0, "cutoff_hz": 900.0, "env_octaves": 0.5, "q": 0.8,
               "attack_s": 0.2, "decay_s": 0.6, "sustain": 0.7, "release_s": 0.2})
recipe(os.path.join(MD, "arp.tres"), voice="tone", seed=407, send=0.2,
       params={"wave": "&square", "decay_s": 0.06, "sustain": 0.3, "gate_s": 0.05, "release_s": 0.02, "length_s": 0.1},
       fx=[{"type": "lowpass", "cutoff_hz": 4200.0}], bind=level(-10.0, 0.0))

kick1 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...............", "length": 16}
kick_half = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.......X.......", "length": 16, "gain_db": -2.0}
kick4 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...X...X...X...", "length": 16}
hat_tick = {"name": "hat", "recipe": M + "hat.tres", "steps": "..o...o...o...o.", "length": 16, "gain_db": -12.0, "pan": 0.2}
hat_off = {"name": "hat", "recipe": M + "hat.tres", "steps": "..x...x...x...x.", "length": 16, "gain_db": -9.0, "pan": 0.15}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "1.2.3.4.5.6.7789", "length": 16, "gain_db": -3.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....x.......x...", "length": 16, "gain_db": -8.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 31, "length": 32, "notes": ["A2"], "chord": [0, 7, 12, 15], "gate": 30.0, "gain_db": -10.0}
hoover = {"name": "hoover", "recipe": M + "hoover.tres", "steps": "X..x..x.x..x..x.", "length": 16,
          "notes": ["A3", "A3", "C4", "A3", "E4", "D4", "C4", "A3"], "gate": 0.9, "gain_db": -7.0}
riser = {"name": "hoover", "recipe": M + "hoover.tres", "steps": "x" + "." * 15, "length": 16, "notes": ["A2"], "chord": [0, 12], "gate": 15.0, "gain_db": -9.0}
arp = {"name": "arp", "recipe": M + "arp.tres", "steps": "xxxxxxxxxxxxxxxx", "length": 16,
       "notes": ["A5", "E5", "C5", "E5", "A5", "E5", "D5", "E5"], "gain_db": -16.0, "pan": -0.2}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name), "lanes": lanes}, typed={"lanes"})
pat("intro", 16, [kick1, hat_tick])
pat("mh", 32, [kick_half, hat_tick, pad])
pat("barrage", 16, [kick4, hat_off])
pat("count", 16, [kick4, hat_off, roll, riser])
pat("drop", 16, [kick4, hat_off, clap, hoover])
pat("alert", 16, [kick4, hat_off, clap, hoover, arp])
pat("outro", 16, [kick4, hat_off])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 200.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "warning_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"]},
        {"name": "mh", "bars": 2.0, "patterns": [M + "mh.tres"]},
        {"name": "barrage", "bars": 1.0, "patterns": [M + "barrage.tres"]},
        {"name": "count", "bars": 1.0, "patterns": [M + "count.tres"],
         "automation": {"hoover.cutoff_hz": [[0.0, 400.0], [1.0, 5000.0]]}},
        {"name": "drop", "bars": 3.0, "patterns": [M + "drop.tres"]},
        {"name": "alert", "bars": 2.0, "patterns": [M + "alert.tres"]},
        {"name": "outro", "bars": 0.5, "patterns": [M + "outro.tres"]},
        {"name": "tail", "bars": 1.1667, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, warning_map.tres and the 200 bpm song" % len(fx))
