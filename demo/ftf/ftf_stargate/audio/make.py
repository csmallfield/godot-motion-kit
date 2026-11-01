#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Stargate Board take (demo/ftf/ftf_stargate/ftf_stargate.gd):
effect recipes, the cue map and a 180 bpm drum & bass song, for the Godot Audio
Kit. Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_stargate/audio/make.py

Sound sheet (shared reverb 0.38, music ducks 6 dB under the hits). The family is
TAPE: everything time-stretches, spins up, stops, flutters and stutters, the way
the picture's time does; a scanner tone traces the delay profile.
  open      tape spin-up of a saw chord and noise (0.15x -> 1x) as the board appears
  slit      three square scanner chirps climbing, with an echo, as the slit draws
  smear     a reversed, stretched swell (noise + saw) peaking on the MH snap
  snap      tight hit: sub boing, high click and a crushed tape chunk
  presents  tape flutter: a ratchet slowing from 1.6x as PRESENTS whips in
  ripple    a bell-tone that wows (varispeed 1 -> 0.6), pitched per kick
  unroll    a pad chord slowing down (1 -> 0.35x) under a falling scanner sweep
  gate      the stargate opens: driven kick, sub drop, long airy tail
  scanner   triangle scanner whose pitch saws up through each beat and snaps back
  flip      wall flip on 140: a short band whoosh and a woody knock
  tunnel    the four walls on 160: low impact and a rising band whoosh
  blip      square blips on each stargate beat, an F-minor pentatonic
  stutter   a crushed ratchet stutter tape-stopping (the delay quantises)
  pour      1.33 s tape spin-up (0.2x -> 1x) of saw, noise and sub into the drop, cut dead
  drop      the drop: driven kick, sub, glass and a noise slap
  fringe    the RGB time split as sound: three FM zaps 0 / 22 / 44 ms apart
  lane      a small mallet ping as the lanes recolour
  stretch   tape stop: a minor chord falling to nothing with a whoosh
  drain     a last reversed swell and a soft sub, gone by frame 396
Music: 180 bpm, 4/4, first downbeat at 0.0 s; a bar is 40 frames. F minor.
  intro   bar 0       pad swooping up from half speed, shaker, kick on the one
  mh      bars 1-3    half-time: kick, rim on 3, rolling hats, sub, pad
  gate    bars 3-5    two-step break with ghost snares, neuro bass, tape-drop stabs
  build   bar 5       drums out but a snare roll, bass filter rising
  drop    bars 6-8.5  full break, ride, neuro bass, stabs
  outro   bars 8.5-10 half-time again, bass closing, then the tape stop
  tail    bar 10-10.5 silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_stargate/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

BEAT_S = 1.0 / 3.0          # 180 bpm
F3, AB3, C4, EB4 = 174.61, 207.65, 261.63, 311.13


def saw_chord(freqs, length, gain=-8.0, cutoff=None, attack=0.01):
    out = []
    for i, hz in enumerate(freqs):
        out.append({"voice": "&tone", "params": {"wave": "&saw", "freq_hz": hz, "attack_s": attack, "sustain": 1.0,
                                                  "gate_s": length - 0.05, "release_s": 0.04, "length_s": length}, "gain_db": gain})
    return out


# the scanner: a saw-tooth in pitch, one ramp per beat, four beats
SCAN = []
for k in range(4):
    t0 = k * BEAT_S
    SCAN += [[t0, 420.0], [t0 + BEAT_S - 0.01, 1350.0]]
SCAN.append([4 * BEAT_S + 0.05, 420.0])

fx = {
    "open": dict(voice="whoosh", params={"length_s": 0.7, "low_hz": 200.0, "high_hz": 6000.0, "peak": 0.85, "shape": 2.0, "noise": "&pink"},
                 layers=saw_chord([F3 / 2, C4 / 2, AB3], 0.7, -10.0),
                 fx=[{"type": "lowpass", "cutoff_hz": 5000.0, "slope_db": 12.0}],
                 transforms=[{"type": "varispeed", "from": 0.15, "to": 1.0}, {"type": "fade", "out_s": 0.08}],
                 bind=level(-14.0, -7.0), send=0.25, seed=501),
    "slit": dict(voice="follow", params={"wave": "&square", "length_s": 0.36,
                 "pitch": [[0.0, 1800.0], [0.11, 1800.0], [0.12, 2400.0], [0.23, 2400.0], [0.24, 3200.0], [0.36, 3200.0]],
                 "level": [[0.0, 1.0], [0.08, 0.0], [0.12, 1.0], [0.2, 0.0], [0.24, 1.0], [0.34, 0.0]]},
                 fx=[{"type": "lowpass", "cutoff_hz": 5000.0}, {"type": "echo", "time_s": 1.0 / 6.0, "feedback": 0.3, "mix": 0.3}],
                 bind=level(-24.0, -15.0), send=0.3, seed=502),
    "smear": dict(voice="whoosh", params={"length_s": 0.75, "low_hz": 400.0, "high_hz": 9000.0, "peak": 0.15, "shape": 2.5, "noise": "&pink"},
                  layers=saw_chord([F3, AB3, C4], 0.75, -12.0, attack=0.3),
                  fx=[{"type": "lowpass", "cutoff_hz": 7000.0, "slope_db": 12.0}],
                  transforms=[{"type": "varispeed", "from": 1.0, "to": 0.5}, {"type": "reverse"}],
                  bind=level(-15.0, -7.0), send=0.25, offset_s=-1.0, seed=503),
    "snap": dict(voice="boing", params={"start_hz": 240.0, "end_hz": 55.0, "drop_s": 0.035, "decay_s": 0.2, "sub": 0.8, "click": 0.8, "click_hz": 10000.0},
                 layers=[{"voice": "&static", "params": {"length_s": 0.07, "hiss": 1.0, "color_hz": 2400.0, "q": 0.8, "crackles_per_s": 900.0, "crackle": 0.8, "fade_s": 0.004}, "gain_db": -9.0}],
                 fx=[{"type": "bitcrush", "bits": 7.0, "hold": 2}],
                 bind=level(-6.0, 0.0), send=0.3, seed=504),
    "presents": dict(voice="ratchet", params={"length_s": 0.32, "start_rate_hz": 70.0, "end_rate_hz": 24.0, "click_hz": 5200.0, "q": 4.0, "fade": 0.5},
                     transforms=[{"type": "varispeed", "from": 1.6, "to": 1.0}],
                     bind=level(-20.0, -12.0), send=0.2, seed=505),
    "ripple": dict(voice="fm", params={"freq_hz": 523.25, "ratio": 2.01, "index": 4.0, "index_end": 0.6, "index_decay_s": 0.3, "decay_s": 0.5, "gate_s": 0.3, "release_s": 0.15},
                   transforms=[{"type": "varispeed", "from": 1.0, "to": 0.6}],
                   bind=pitched(-16.0, -8.0), send=0.4, seed=506),
    "unroll": dict(voice="follow", params={"wave": "&triangle", "length_s": 0.66, "pitch": [[0.0, 2200.0], [0.66, 300.0]],
                   "level": [[0.0, 0.0], [0.04, 1.0], [0.5, 0.5], [0.66, 0.0]]},
                   layers=saw_chord([F3, AB3, C4, EB4], 0.66, -13.0, attack=0.02),
                   fx=[{"type": "lowpass", "cutoff_hz": 3500.0}],
                   transforms=[{"type": "varispeed", "from": 1.0, "to": 0.35}, {"type": "fade", "out_s": 0.1}],
                   bind=level(-14.0, -7.0), send=0.35, seed=507),
    "gate": dict(voice="kick", params={"tune_hz": 40.0, "punch": 6.0, "drop_s": 0.06, "decay_s": 0.8, "click": 0.7, "drive": 0.6},
                 layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 30.0, "drop_s": 0.3, "decay_s": 0.7, "sub": 1.0, "click": 0.0}, "gain_db": -5.0},
                         {"voice": "&whoosh", "params": {"length_s": 1.3, "low_hz": 1500.0, "high_hz": 12000.0, "peak": 0.02, "shape": 1.0, "mode": "&high"}, "gain_db": -11.0}],
                 bind=level(-4.0, 0.0), send=0.4, seed=508),
    "scanner": dict(voice="follow", params={"wave": "&triangle", "length_s": 4 * BEAT_S + 0.1, "pitch": SCAN,
                    "level": [[0.0, 0.0], [0.03, 1.0], [4 * BEAT_S - 0.1, 0.8], [4 * BEAT_S + 0.1, 0.0]]},
                    fx=[{"type": "lowpass", "cutoff_hz": 4000.0}, {"type": "echo", "time_s": BEAT_S / 2, "feedback": 0.25, "mix": 0.25}],
                    bind=pitched(-22.0, -14.0), send=0.3, seed=509),
    "flip": dict(voice="whoosh", params={"length_s": 0.25, "low_hz": 600.0, "high_hz": 6000.0, "peak": 0.6, "mode": "&band", "q": 2.0},
                 layers=[{"voice": "&click", "params": {"freq_hz": 900.0, "mode": "&band", "q": 6.0, "decay_s": 0.03, "body_hz": 120.0, "body": 0.6}, "gain_db": -4.0}],
                 bind=level(-14.0, -7.0), send=0.3, seed=510),
    "tunnel": dict(voice="boing", params={"start_hz": 140.0, "end_hz": 38.0, "drop_s": 0.12, "decay_s": 0.5, "sub": 1.0, "click": 0.5},
                   layers=[{"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 300.0, "high_hz": 8000.0, "peak": 0.9, "mode": "&band", "q": 1.5, "shape": 2.0}, "gain_db": -6.0}],
                   bind=level(-8.0, -2.0), send=0.35, seed=511),
    "blip": dict(voice="tone", params={"wave": "&square", "width": 0.3, "freq_hz": 698.46, "decay_s": 0.08, "gate_s": 0.05, "release_s": 0.04, "length_s": 0.16},
                 fx=[{"type": "lowpass", "cutoff_hz": 5000.0}],
                 bind=pitched(-22.0, -14.0), vary={"decay_s": 0.15}, vary_variants=4, send=0.3, seed=512),
    "stutter": dict(voice="ratchet", params={"length_s": 0.3, "start_rate_hz": 48.0, "end_rate_hz": 48.0, "click_hz": 3000.0, "q": 2.0, "fade": 0.2},
                    layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": F3, "sustain": 1.0, "gate_s": 0.28, "release_s": 0.01, "length_s": 0.3}, "gain_db": -10.0}],
                    fx=[{"type": "bitcrush", "bits": 5.0, "hold": 3}],
                    transforms=[{"type": "varispeed", "from": 1.0, "to": 0.4}],
                    bind=level(-16.0, -8.0), seed=513),
    "pour": dict(voice="whoosh", params={"length_s": 0.83, "low_hz": 250.0, "high_hz": 12000.0, "peak": 0.97, "shape": 3.0, "noise": "&pink"},
                 layers=saw_chord([F3 / 2, F3, C4], 0.83, -9.0, attack=0.55) +
                        [{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 43.65, "attack_s": 0.6, "sustain": 1.0, "gate_s": 0.82, "release_s": 0.01, "length_s": 0.83}, "gain_db": -8.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 9000.0, "slope_db": 12.0}],
                 transforms=[{"type": "varispeed", "from": 0.25, "to": 1.0}, {"type": "trim", "length_s": 1.32}, {"type": "fade", "out_s": 0.01}],
                 bind=level(-12.0, -5.0), send=0.15, seed=514),
    "drop": dict(voice="kick", params={"tune_hz": 44.0, "punch": 5.5, "drop_s": 0.045, "decay_s": 0.6, "click": 0.9, "drive": 0.6},
                 layers=[{"voice": "&boing", "params": {"start_hz": 160.0, "end_hz": 34.0, "drop_s": 0.15, "decay_s": 0.55, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&mallet", "params": {"freq_hz": 1396.9, "material": "&glass", "hardness": 0.9, "decay_s": 0.8}, "gain_db": -11.0},
                         {"voice": "&snare", "params": {"tone": 0.1, "noise": 1.0, "noise_hz": 6000.0, "noise_decay_s": 0.2}, "gain_db": -8.0}],
                 bind=level(-4.0, 0.0), send=0.35, seed=515),
    "fringe": dict(voice="fm", params={"freq_hz": 330.0, "ratio": 3.01, "index": 8.0, "index_end": 0.0, "index_decay_s": 0.05, "decay_s": 0.1, "gate_s": 0.06, "release_s": 0.04},
                   layers=[{"voice": "&fm", "params": {"freq_hz": 392.0, "ratio": 3.01, "index": 8.0, "index_end": 0.0, "index_decay_s": 0.05, "decay_s": 0.1, "gate_s": 0.06, "release_s": 0.04}, "gain_db": -3.0, "offset_s": 0.022},
                           {"voice": "&fm", "params": {"freq_hz": 466.2, "ratio": 3.01, "index": 8.0, "index_end": 0.0, "index_decay_s": 0.05, "decay_s": 0.1, "gate_s": 0.06, "release_s": 0.04}, "gain_db": -6.0, "offset_s": 0.044}],
                   bind=pitched(-15.0, -8.0), send=0.25, seed=516),
    "lane": dict(voice="mallet", params={"freq_hz": 1046.5, "material": "&bar", "hardness": 0.7, "decay_s": 0.25},
                 bind=pitched(-22.0, -14.0), send=0.4, seed=517),
    "stretch": dict(voice="whoosh", params={"length_s": 1.2, "low_hz": 200.0, "high_hz": 5000.0, "peak": 0.1, "noise": "&pink"},
                    layers=saw_chord([F3, AB3, C4, EB4], 1.2, -8.0),
                    fx=[{"type": "lowpass", "cutoff_hz": 3000.0}],
                    transforms=[{"type": "varispeed", "from": 1.0, "to": 0.0}, {"type": "fade", "out_s": 0.15}],
                    bind=level(-10.0, -4.0), send=0.3, seed=518),
    "drain": dict(voice="whoosh", params={"length_s": 0.6, "low_hz": 150.0, "high_hz": 3000.0, "peak": 0.95, "shape": 2.0, "noise": "&brown"},
                  layers=[{"voice": "&boing", "params": {"start_hz": 90.0, "end_hz": 40.0, "drop_s": 0.2, "decay_s": 0.12, "sub": 0.8, "click": 0.0, "length_s": 0.2}, "gain_db": -6.0, "offset_s": 0.58}],
                  transforms=[{"type": "fade", "out_s": 0.05}],
                  bind=level(-14.0, -7.0), send=0.3, seed=519),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "stargate_map.tres"), {k: R + k + ".tres" for k in fx},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.38, "damp": 0.5, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.4)
with open(os.path.join(D, "stargate_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.25}\n')

# ------------------------------------------------------------------ music (180 bpm, F minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=601,
       params={"tune_hz": 50.0, "punch": 4.5, "drop_s": 0.03, "decay_s": 0.24, "click": 0.7, "drive": 0.35}, bind=level(-7.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=602, send=0.22,
       params={"tone_hz": 200.0, "tone": 0.5, "tone_decay_s": 0.06, "noise": 0.95, "noise_hz": 5500.0, "noise_decay_s": 0.14},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-18.0, 0.0))
recipe(os.path.join(MD, "rim.tres"), voice="click", seed=603, send=0.3,
       params={"freq_hz": 1800.0, "mode": "&band", "q": 5.0, "decay_s": 0.02, "body_hz": 400.0, "body": 0.4}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=604, vary={"decay_s": 0.35}, vary_variants=4,
       params={"decay_s": 0.025, "tone_hz": 9500.0, "metal": 0.6}, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "shaker.tres"), voice="static", seed=605, vary={"color_hz": 0.1}, vary_variants=4,
       params={"length_s": 0.06, "hiss": 1.0, "color_hz": 8000.0, "q": 1.2, "crackles_per_s": 0.0, "fade_s": 0.03}, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "ride.tres"), voice="hat", seed=606, params={"decay_s": 0.4, "tone_hz": 6200.0, "metal": 0.9, "tune": 1.4}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=607,
       params={"position": 0.85, "unison": 5, "detune_cents": 22.0, "sub": 0.65, "cutoff_hz": 420.0, "env_octaves": 2.0, "filter_decay_s": 0.18, "q": 2.2,
               "attack_s": 0.005, "decay_s": 0.3, "sustain": 0.7, "release_s": 0.06},
       fx=[{"type": "drive", "amount": 0.45}, {"type": "bandpass", "cutoff_hz": 900.0, "q": 0.5}], bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "sub.tres"), voice="tone", seed=608, params={"wave": "&sine", "freq_hz": 43.65, "attack_s": 0.01, "decay_s": 0.5, "sustain": 0.6, "gate_s": 0.6, "release_s": 0.15},
       bind=level(-6.0, 0.0))
recipe(os.path.join(MD, "stab.tres"), voice="fm", seed=609, send=0.35,
       params={"ratio": 2.0, "index": 3.0, "index_end": 0.5, "index_decay_s": 0.15, "decay_s": 0.3, "gate_s": 0.2, "release_s": 0.1},
       transforms=[{"type": "varispeed", "from": 1.0, "to": 0.55}])          # every stab tape-drops
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=610, send=0.5,
       params={"position": 0.35, "unison": 5, "detune_cents": 16.0, "cutoff_hz": 1600.0, "env_octaves": 0.3, "filter_decay_s": 1.5,
               "q": 0.5, "attack_s": 0.3, "decay_s": 1.0, "sustain": 0.8, "release_s": 0.3},
       transforms=[{"type": "varispeed", "from": 0.5, "to": 1.0}])          # swoops up from half speed (tape start)

KS = lambda s: s.replace(" ", "")
kick_half = {"name": "kick", "recipe": M + "kick.tres", "steps": KS("X... .... .... .... X... .... ..x. ...."), "length": 32}
rim_half = {"name": "rim", "recipe": M + "rim.tres", "steps": KS(".... .... X... .... .... .... X... ..o."), "length": 32, "gain_db": -6.0}
hats_roll = {"name": "hat", "recipe": M + "hat.tres", "steps": KS("x.ox x.ox x.ox xoxo"), "length": 16, "gain_db": -13.0, "pan": 0.25}
shaker = {"name": "shaker", "recipe": M + "shaker.tres", "steps": KS(".o.o .o.o .o.o .ooo"), "length": 16, "gain_db": -18.0, "pan": -0.25}
kick_break = {"name": "kick", "recipe": M + "kick.tres", "steps": KS("X... .... .xX. .... X... .... ..x. ...."), "length": 32}
snare_break = {"name": "snare", "recipe": M + "snare.tres", "steps": KS(".... X..o .... X... .o.. X..o .... X.o."), "length": 32, "gain_db": -1.0}
ride = {"name": "ride", "recipe": M + "ride.tres", "steps": KS("..x. ..x. ..x. ..x."), "length": 16, "gain_db": -19.0, "pan": -0.2}
bass_gate = {"name": "bass", "recipe": M + "bass.tres", "steps": KS("X... ..x. ..X. .... X... .x.. x... .x.."), "length": 32,
             "notes": [29, 29, 32, 29, 36, 34, 29, 32], "gate": 1.6, "gain_db": -4.0}
bass_drop = {"name": "bass", "recipe": M + "bass.tres", "steps": KS("X... ..x. X.x. .... X... .x.. x.x. .x.x"), "length": 32,
             "notes": [29, 29, 32, 29, 27, 29, 36, 34, 32, 29], "gate": 1.4, "gain_db": -4.0}
sub_long = {"name": "sub", "recipe": M + "sub.tres", "steps": "x" + "." * 15, "length": 16, "notes": [29, 29, 32, 27], "gate": 12.0, "gain_db": -7.0}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": KS(".... ..x. .... .x.."), "length": 16, "notes": ["F4", "Ab4"], "chord": [0, 3, 7], "gate": 1.0, "gain_db": -13.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 31, "length": 32, "notes": ["F3", "Db3"], "chord": [0, 7, 10, 15], "gate": 30.0, "gain_db": -12.0}
pad_one = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 15, "length": 16, "notes": ["F3"], "chord": [0, 7, 10, 15], "gate": 15.0, "gain_db": -12.0}
kick_one = {"name": "kick", "recipe": M + "kick.tres", "steps": "X" + "." * 15, "length": 16, "gain_db": -2.0}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": KS("1... 2... 3.3. 4.4. 5555 6666 7777 8899"), "length": 32, "gain_db": -6.0}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name) + 11, "humanize_ms": 2.0, "lanes": lanes}, typed={"lanes"})
pat("intro", 16, [pad_one, shaker, kick_one])
pat("mh", 32, [kick_half, rim_half, hats_roll, sub_long, pad])
pat("gate", 32, [kick_break, snare_break, hats_roll, bass_gate, stab])
pat("build", 16, [dict(roll, length=16, steps=KS("1.2. 3.3. 5555 7799")), bass_gate, pad_one])
pat("drop", 32, [kick_break, snare_break, hats_roll, ride, bass_drop, stab])
pat("outro", 32, [kick_half, dict(rim_half, recipe=M + "snare.tres", gain_db=-4.0), shaker, sub_long])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 180.0, "beats_per_bar": 4, "offset_s": 0.0})
resource(os.path.join(MD, "song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"]},
        {"name": "mh", "bars": 2.0, "patterns": [M + "mh.tres"]},
        {"name": "gate", "bars": 2.0, "patterns": [M + "gate.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 300.0], [0.5, 900.0], [1.0, 600.0]]}},
        {"name": "build", "bars": 1.0, "patterns": [M + "build.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 250.0], [1.0, 1800.0]], "bass.gain_db": [[0.0, -8.0], [1.0, -3.0]]}},
        {"name": "drop", "bars": 2.5, "patterns": [M + "drop.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 700.0], [0.5, 1300.0], [1.0, 800.0]]}},
        {"name": "outro", "bars": 1.5, "patterns": [M + "outro.tres"],
         "automation": {"sub.gain_db": [[0.0, -7.0], [1.0, -20.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -12.0]]}},
        {"name": "tail", "bars": 0.5, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -5.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, the cue map and the 180 bpm song" % len(fx))
