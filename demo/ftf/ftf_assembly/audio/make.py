#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for FTF round 4, ASSEMBLY (demo/ftf/ftf_assembly): effect recipes, the
cue map and a 100 bpm dark minimal night-electro bed, for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_assembly/audio/make.py

Sound sheet (a cold wide night space; servos, hydraulics and glass; music ducks 7 dB):
  power        a mains hum swelling up with a relay clunk: the city wakes
  lights.on    glassy pings climbing a minor arpeggio, one per window ring
  wave         a servo whirr spinning up (filtered saw glide + gear ticks +
               hydraulic hiss): the first wave of blocks lifts off
  step         a block wave lands and the next lifts: hydraulic thunk, a short
               servo, a glass ping pitched up the scale
  mh.lock      the sculpture locks: deep thunk, sub, a glass chord (F minor)
  presents     a small glassy FM bell
  disperse     hydraulic release: falling brown-noise hiss, servo winding down
  settle       a soft thunk as the city settles back
  ftf.set      last wave lands and pressure builds: thunk, a 0.6 s riser
               (rising saw + noise) that peaks on the drop
  drop         the slab: kick, sub drop, a bar clang, glass shimmer, noise slap
  lift         the slab lifts off: rising hydraulic whoosh and servo
  scatter      blocks scatter: a ratchet clatter, servos winding down
  power.down   the lights die: a falling tone, mains hum dropping out
  end          a last low relay
Music: 100 bpm, 4/4, first downbeat at 0.0 s (frame 0), a bar is 72 frames.
  intro  bar 0         pad (F minor fifths), glass ticks
  mh     bars 1-2.25   kick, soft hats, sub bass, pad, glass bell arp
  break  2.25-2.75     pad and a long bass note (the blocks disperse)
  build  2.75-3.75     kick, bass, hats, filter opening
  rise   3.75-4        snare roll into the drop
  drop   4-5           full: kick, clap, hats, bass, bell arp, pad
  outro  5-5.83        pad and bass thinning out to nothing
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_assembly/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

F2, F3, AB3, C4, F4, AB4, C5, EB5, F5, AB5, C6 = 87.31, 174.61, 207.65, 261.63, 349.23, 415.30, 523.25, 622.25, 698.46, 830.61, 1046.5

servo = lambda f0, f1, length, gain: {"voice": "&tone", "params": {"wave": "&saw", "freq_hz": f0, "end_hz": f1, "glide_s": length * 0.45,
                                       "attack_s": 0.03, "decay_s": 0.1, "sustain": 0.8, "gate_s": length * 0.8, "release_s": 0.05, "length_s": length}, "gain_db": gain}
thunk = lambda hz, gain: {"voice": "&boing", "params": {"start_hz": hz, "end_hz": hz * 0.4, "drop_s": 0.04, "decay_s": 0.16, "sub": 0.8, "click": 0.7, "click_hz": 2600.0}, "gain_db": gain}
glass = lambda hz, gain, off=0.0, decay=0.9: {"voice": "&mallet", "params": {"freq_hz": hz, "material": "&glass", "hardness": 0.75, "decay_s": decay, "damping": 0.9}, "gain_db": gain, "offset_s": off}

fx = {
    "power": dict(voice="tone", params={"wave": "&saw", "freq_hz": 43.65, "attack_s": 0.25, "decay_s": 0.2, "sustain": 0.8, "gate_s": 0.45, "release_s": 0.1, "length_s": 0.7},
                  layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 87.31, "attack_s": 0.2, "sustain": 1.0, "gate_s": 0.45, "release_s": 0.1, "length_s": 0.7}, "gain_db": -4.0},
                          {"voice": "&click", "params": {"freq_hz": 1500.0, "mode": "&band", "q": 3.0, "decay_s": 0.012, "body_hz": 90.0, "body": 0.9}, "gain_db": -6.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 700.0, "slope_db": 24.0}],
                  bind=level(-12.0, -5.0), send=0.3, seed=501),
    "lights_on": dict(voice="mallet", params={"freq_hz": F5, "material": "&glass", "hardness": 0.8, "decay_s": 0.6, "damping": 1.0},
                      layers=[{"voice": "&click", "params": {"freq_hz": 4200.0, "mode": "&band", "q": 5.0, "decay_s": 0.003}, "gain_db": -10.0}],
                      bind=pitched(-17.0, -9.0), send=0.45, seed=502),
    "wave": dict(voice="tone", params={"wave": "&saw", "freq_hz": 110.0, "end_hz": 330.0, "glide_s": 0.22, "attack_s": 0.05, "decay_s": 0.1, "sustain": 0.8, "gate_s": 0.45, "release_s": 0.06, "length_s": 0.6},
                 layers=[{"voice": "&ratchet", "params": {"length_s": 0.5, "start_rate_hz": 18.0, "end_rate_hz": 60.0, "click_hz": 2200.0, "q": 4.0, "fade": 0.2}, "gain_db": -9.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 200.0, "high_hz": 2400.0, "peak": 0.35, "noise": "&brown"}, "gain_db": -6.0}],
                 fx=[{"type": "bandpass", "cutoff_hz": 900.0, "q": 1.2}],
                 bind=level(-12.0, -5.0), send=0.3, seed=503),
    "step": dict(voice="boing", params={"start_hz": 120.0, "end_hz": 48.0, "drop_s": 0.04, "decay_s": 0.18, "sub": 0.8, "click": 0.8, "click_hz": 2400.0},
                 layers=[servo(140.0, 300.0, 0.3, -14.0), glass(C6, -11.0, 0.0, 0.7),
                         {"voice": "&whoosh", "params": {"length_s": 0.25, "low_hz": 300.0, "high_hz": 3500.0, "peak": 0.1, "noise": "&brown"}, "gain_db": -12.0}],
                 bind=pitched(-9.0, -3.0), send=0.3, seed=504),
    "mh_lock": dict(voice="boing", params={"start_hz": 110.0, "end_hz": 40.0, "drop_s": 0.06, "decay_s": 0.35, "sub": 1.0, "click": 0.8, "click_hz": 3000.0},
                    layers=[glass(F5, -8.0, 0.0, 1.4), glass(AB5, -10.0, 0.0, 1.3), glass(C6, -11.0, 0.0, 1.2), glass(F4, -12.0, 0.0, 1.6)],
                    bind=level(-5.0, 0.0), send=0.45, seed=505),
    "presents": dict(voice="fm", params={"freq_hz": AB5, "ratio": 3.5, "index": 3.0, "index_end": 0.2, "index_decay_s": 0.2, "decay_s": 0.8, "gate_s": 0.05, "release_s": 0.5},
                     bind=level(-17.0, -10.0), send=0.5, seed=506),
    "disperse": dict(voice="whoosh", params={"length_s": 0.8, "low_hz": 120.0, "high_hz": 2600.0, "peak": 0.15, "shape": 1.4, "noise": "&brown"},
                     layers=[servo(320.0, 90.0, 0.7, -13.0),
                             {"voice": "&click", "params": {"freq_hz": 1200.0, "mode": "&band", "q": 3.0, "decay_s": 0.01, "body_hz": 80.0, "body": 0.8}, "gain_db": -8.0}],
                     bind=level(-11.0, -4.0), send=0.35, seed=507),
    "settle": dict(voice="boing", params={"start_hz": 90.0, "end_hz": 42.0, "drop_s": 0.05, "decay_s": 0.2, "sub": 0.6, "click": 0.5, "click_hz": 1800.0},
                   bind=level(-12.0, -6.0), send=0.3, seed=508),
    "ftf_set": dict(voice="boing", params={"start_hz": 130.0, "end_hz": 48.0, "drop_s": 0.04, "decay_s": 0.2, "sub": 0.9, "click": 0.8, "click_hz": 2600.0},
                    layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 55.0, "end_hz": 220.0, "glide_s": 0.3, "attack_s": 0.45, "decay_s": 0.1, "sustain": 1.0, "gate_s": 0.58, "release_s": 0.01, "length_s": 0.6}, "gain_db": -6.0},
                            {"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 150.0, "high_hz": 6000.0, "peak": 0.95, "shape": 2.8, "noise": "&pink"}, "gain_db": -4.0}],
                    fx=[{"type": "drive", "amount": 0.25}],
                    bind=level(-8.0, -2.0), send=0.3, seed=509),
    "drop": dict(voice="kick", params={"tune_hz": 41.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.6, "click": 0.8, "drive": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 34.0, "drop_s": 0.14, "decay_s": 0.5, "sub": 1.0, "click": 0.0}, "gain_db": -5.0},
                         {"voice": "&mallet", "params": {"freq_hz": 174.61, "material": "&bar", "hardness": 1.0, "decay_s": 0.7}, "gain_db": -7.0},
                         glass(F5, -10.0, 0.0, 1.6), glass(C6, -12.0, 0.02, 1.4),
                         {"voice": "&snare", "params": {"tone_hz": 140.0, "tone": 0.3, "noise": 1.0, "noise_hz": 4500.0, "noise_decay_s": 0.18}, "gain_db": -7.0}],
                 bind=level(-3.0, 0.0), send=0.4, seed=510),
    "lift": dict(voice="whoosh", params={"length_s": 0.6, "low_hz": 150.0, "high_hz": 5000.0, "peak": 0.6, "shape": 2.0, "noise": "&pink"},
                 layers=[servo(120.0, 420.0, 0.5, -12.0)],
                 bind=level(-11.0, -4.0), send=0.35, seed=511),
    "scatter": dict(voice="ratchet", params={"length_s": 0.6, "start_rate_hz": 45.0, "end_rate_hz": 9.0, "click_hz": 1500.0, "q": 4.0, "fade": 0.6, "jitter": 0.3},
                    layers=[servo(300.0, 70.0, 0.7, -12.0),
                            {"voice": "&whoosh", "params": {"length_s": 0.7, "low_hz": 100.0, "high_hz": 1500.0, "peak": 0.2, "noise": "&brown"}, "gain_db": -7.0}],
                    bind=level(-11.0, -4.0), send=0.3, seed=512),
    "power_down": dict(voice="tone", params={"wave": "&saw", "freq_hz": 220.0, "end_hz": 30.0, "glide_s": 0.35, "attack_s": 0.01, "decay_s": 0.3, "sustain": 0.7, "gate_s": 0.7, "release_s": 0.1, "length_s": 0.9},
                       layers=[glass(C6, -12.0, 0.0, 0.5), glass(AB5, -14.0, 0.12, 0.5), glass(F5, -16.0, 0.24, 0.6)],
                       fx=[{"type": "lowpass", "cutoff_hz": 1100.0, "slope_db": 24.0}],
                       bind=level(-11.0, -4.0), send=0.4, seed=513),
    "end": dict(voice="click", params={"freq_hz": 800.0, "mode": "&band", "q": 3.0, "decay_s": 0.025, "body_hz": 60.0, "body": 1.0},
                layers=[{"voice": "&boing", "params": {"start_hz": 70.0, "end_hz": 36.0, "drop_s": 0.05, "decay_s": 0.12, "sub": 0.6, "click": 0.0}, "gain_db": -6.0}],
                bind=level(-10.0, -4.0), send=0.3, seed=514),
}

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "assembly_map.tres"), {
    "power": R + "power.tres", "lights.on": R + "lights_on.tres", "wave": R + "wave.tres", "step": R + "step.tres",
    "mh.lock": R + "mh_lock.tres", "presents": R + "presents.tres", "disperse": R + "disperse.tres", "settle": R + "settle.tres",
    "ftf.set": R + "ftf_set.tres", "drop": R + "drop.tres", "lift": R + "lift.tres", "scatter": R + "scatter.tres",
    "power.down": R + "power_down.tres", "end": R + "end.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.7, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -4.0}, end_fade_s=0.4)
with open(os.path.join(D, "assembly_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 7.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music (100 bpm, F minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=601,
       params={"tune_hz": 44.0, "punch": 3.5, "decay_s": 0.38, "click": 0.35, "drive": 0.35}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=602, send=0.5,
       params={"bursts": 3, "color_hz": 1300.0, "tail_decay_s": 0.18}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=603, send=0.3,
       params={"tone_hz": 200.0, "tone": 0.3, "noise": 0.9, "noise_hz": 5500.0, "noise_decay_s": 0.07},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=604, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.02, "tone_hz": 9500.0, "metal": 0.5}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "tick.tres"), voice="mallet", seed=605, send=0.5, vary={"freq_hz": 0.02}, vary_variants=4,
       params={"freq_hz": 2093.0, "material": "&glass", "hardness": 0.9, "decay_s": 0.12, "damping": 1.4}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=606,
       params={"position": 0.7, "sub": 0.8, "cutoff_hz": 260.0, "env_octaves": 1.6, "filter_decay_s": 0.12, "q": 2.0,
               "attack_s": 0.003, "decay_s": 0.15, "sustain": 0.6, "release_s": 0.05},
       bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=607, send=0.6,
       params={"position": 0.62, "unison": 3, "detune_cents": 14.0, "cutoff_hz": 700.0, "env_octaves": 0.4, "filter_decay_s": 1.5, "q": 0.8,
               "attack_s": 0.5, "decay_s": 0.8, "sustain": 0.8, "release_s": 0.6},
       bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "bell.tres"), voice="fm", seed=608, send=0.55,
       params={"ratio": 3.5, "index": 2.4, "index_end": 0.2, "index_decay_s": 0.15, "decay_s": 0.45, "gate_s": 0.04, "release_s": 0.3},
       bind=level(-10.0, 0.0))

BASS = ["F1", "F1", "F2", "F1", "F1", "Ab1", "F1", "Eb2"]
ARP = ["F5", "C5", "Ab4", "C5", "Eb5", "C5", "Ab4", "F4"]
kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -8.0}
hat = {"name": "hat", "recipe": M + "hat.tres", "steps": "..o...x...o...x.", "length": 16, "gain_db": -14.0, "pan": 0.2}
hat16 = {"name": "hat", "recipe": M + "hat.tres", "steps": "o.x.o.x.oox.o.xo", "length": 16, "gain_db": -14.0, "pan": 0.2}
tick = {"name": "tick", "recipe": M + "tick.tres", "steps": "..o.....o..o....", "length": 16, "gain_db": -18.0, "pan": -0.3}
bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.x.x.x.x.x.x.x.", "length": 16, "notes": BASS, "gate": 0.6, "gain_db": -4.0}
bass_long = {"name": "bass", "recipe": M + "bass.tres", "steps": "x---------------", "length": 16, "notes": ["F1"], "gate": 0.95, "gain_db": -5.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x---------------", "length": 16, "notes": ["F3"], "chord": [0, 7, 12], "gate": 0.98, "gain_db": -13.0}
pad2 = dict(pad, notes=["Db3"])
bell = {"name": "bell", "recipe": M + "bell.tres", "steps": "x..x..x...x..x..", "length": 16, "notes": ARP, "gain_db": -15.0, "pan": 0.25}
bell_sparse = dict(bell, steps="x.......x.......", gain_db=-17.0)
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "o.o.x.x.xxxxXXXX", "length": 16, "gain_db": -7.0}

P = "AKPattern"
pat = lambda name, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                    {"steps": 16, "seed": len(name), "lanes": lanes}, typed={"lanes"})
pat("intro", [pad, tick, bell_sparse])
pat("mh", [kick, hat, bass, pad, bell_sparse, tick])
pat("mh2", [kick, hat, bass, pad2, bell_sparse, tick])
pat("brk", [pad2, bass_long, tick])
pat("build", [kick, hat16, bass, pad])
pat("rise", [kick, roll, bass])
pat("drop", [kick, clap, hat16, bass, bell, pad])
pat("outro", [pad2, dict(bass_long, notes=["F1"]), bell_sparse])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 100.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "assembly_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"], "automation": {"pad.cutoff_hz": [[0.0, 300.0], [1.0, 700.0]]}},
        {"name": "mh", "bars": 1.0, "patterns": [M + "mh.tres"]},
        {"name": "mh2", "bars": 0.25, "patterns": [M + "mh2.tres"]},
        {"name": "brk", "bars": 0.5, "patterns": [M + "brk.tres"]},
        {"name": "build", "bars": 1.0, "patterns": [M + "build.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 220.0], [1.0, 520.0]], "pad.cutoff_hz": [[0.0, 500.0], [1.0, 1400.0]]}},
        {"name": "rise", "bars": 0.25, "patterns": [M + "rise.tres"], "automation": {"bass.cutoff_hz": [[0.0, 520.0], [1.0, 900.0]]}},
        {"name": "drop", "bars": 1.0, "patterns": [M + "drop.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 420.0], [1.0, 600.0]], "bell.gain_db": [[0.0, -2.0], [1.0, 0.0]]}},
        {"name": "outro", "bars": 0.8333, "patterns": [M + "outro.tres"],
         "automation": {"pad.gain_db": [[0.0, 0.0], [0.7, -8.0], [1.0, -30.0]], "bass.gain_db": [[0.0, 0.0], [0.6, -14.0], [1.0, -40.0]],
                        "pad.cutoff_hz": [[0.0, 900.0], [1.0, 200.0]]}},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, assembly_map.tres and the 100 bpm song" % len(fx))
