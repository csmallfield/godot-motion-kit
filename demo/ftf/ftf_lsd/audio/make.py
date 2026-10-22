#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF LSD Sunrise take (demo/ftf/ftf_lsd): effect recipes, the
cue map and a 100 bpm balearic acid song for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_lsd/audio/make.py

Sound sheet (warm, wet, a big soft space; music ducks 6 dB under the hits):
  dawn        a low swelling pad chord with air: the horizon glowing
  sun.peek    a slow glass bell fifth as the sun breaks the horizon
  rise        a liquid upward glide with a bubbling ratchet: MH surfacing
  set         a warm FM bell chord with a sub bloom: MH sets solid
  presents    soft plucks running up a pentatonic phrase
  melt        a gloopy downward glide with a wobble: MH melts into the sea
  kaleido     a shimmering reversed swell into the mandala
  segment     a metallic mallet hit, pitched up per segment step
  pour        a rising liquid riser that peaks on the drop
  drop        warm kick, sub boom, bell cluster and a wash: the logo sets
  kana        a quiet pluck run as the katakana writes
  bloom       a shimmering airy whoosh with a high bell
  ripple      a wobbling sine wave on the logo ripples
  melt.out    a long gloopy downward slide
  sink        a sinking tone and dark wash as the sun goes down
  last        a single low bell ringing into black
Music: 100 bpm, 4/4, first downbeat at 0.0 s; a bar is 72 frames (2.4 s).
  dawn    bar 0        pad + bell arp, no drums
  groove  bar 1        soft kick, offbeat hat, pad, arp
  trip    bars 2-2.75  + clap, shaker, acid line opening up
  break   bar 2.75     riser only
  full    bars 3-4.67  kick, clap, hats, acid, bass, pad, arp
  outro   bars 4.67-5.5 pad, arp and acid fading, acid closing
  tail    to the end   silence; the last bell rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_lsd/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

# E minor / G major colours: E2 82.41, B2 123.47, E3 164.81, G3 196.0, B3 246.94, D4 293.66, E4 329.63, G4 392, B4 493.88
fx = {
    "dawn": dict(voice="wavetable", params={"freq_hz": 82.41, "position": 0.45, "unison": 5, "detune_cents": 18.0, "cutoff_hz": 700.0, "env_octaves": 0.4,
                 "attack_s": 0.9, "decay_s": 0.5, "sustain": 0.8, "gate_s": 1.6, "release_s": 0.5},
                 layers=[{"voice": "&wavetable", "params": {"freq_hz": 123.47, "position": 0.4, "unison": 3, "cutoff_hz": 900.0, "attack_s": 0.9, "sustain": 0.8, "gate_s": 1.6, "release_s": 0.5}, "gain_db": -4.0},
                         {"voice": "&whoosh", "params": {"length_s": 2.0, "low_hz": 400.0, "high_hz": 3000.0, "peak": 0.7, "noise": "&pink"}, "gain_db": -14.0}],
                 bind=level(-12.0, -6.0), send=0.6, seed=301),
    "sun_peek": dict(voice="mallet", params={"freq_hz": 659.25, "material": "&glass", "hardness": 0.3, "decay_s": 1.4},
                     layers=[{"voice": "&mallet", "params": {"freq_hz": 987.77, "material": "&glass", "hardness": 0.3, "decay_s": 1.2}, "gain_db": -5.0, "offset_s": 0.12}],
                     bind=level(-12.0, -5.0), send=0.65, seed=302),
    "rise": dict(voice="tone", params={"wave": "&sine", "freq_hz": 140.0, "end_hz": 620.0, "glide_s": 0.5, "attack_s": 0.25, "decay_s": 0.4, "sustain": 0.6, "gate_s": 1.2, "release_s": 0.2, "vibrato_hz": 6.0, "vibrato_semitones": 0.6},
                 layers=[{"voice": "&ratchet", "params": {"length_s": 1.3, "start_rate_hz": 10.0, "end_rate_hz": 34.0, "click_hz": 900.0, "q": 6.0, "jitter": 0.35, "fade": 0.2}, "gain_db": -12.0}],
                 bind=level(-14.0, -7.0), send=0.5, seed=303),
    "set": dict(voice="fm", params={"freq_hz": 196.0, "ratio": 3.0, "index": 3.0, "index_end": 0.6, "index_decay_s": 0.5, "decay_s": 1.4, "gate_s": 0.6, "release_s": 0.6},
                layers=[{"voice": "&fm", "params": {"freq_hz": 246.94, "ratio": 3.0, "index": 2.5, "index_end": 0.5, "decay_s": 1.3, "gate_s": 0.6}, "gain_db": -3.0},
                        {"voice": "&fm", "params": {"freq_hz": 293.66, "ratio": 2.0, "index": 2.0, "index_end": 0.4, "decay_s": 1.2, "gate_s": 0.6}, "gain_db": -5.0},
                        {"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 41.0, "drop_s": 0.12, "decay_s": 0.5, "sub": 1.0, "click": 0.1}, "gain_db": -5.0}],
                bind=pitched(-8.0, -1.0), send=0.5, seed=304),
    "presents": dict(voice="pluck", params={"freq_hz": 659.25, "brightness": 0.45, "decay_s": 0.35, "tone_hz": 4000.0},
                     layers=[{"voice": "&pluck", "params": {"freq_hz": 783.99, "brightness": 0.45, "decay_s": 0.35}, "gain_db": -2.0, "offset_s": 0.09},
                             {"voice": "&pluck", "params": {"freq_hz": 987.77, "brightness": 0.45, "decay_s": 0.35}, "gain_db": -3.0, "offset_s": 0.18},
                             {"voice": "&pluck", "params": {"freq_hz": 1174.66, "brightness": 0.45, "decay_s": 0.5}, "gain_db": -4.0, "offset_s": 0.27}],
                     bind=level(-16.0, -9.0), send=0.5, seed=305),
    "melt": dict(voice="tone", params={"wave": "&triangle", "freq_hz": 700.0, "end_hz": 90.0, "glide_s": 0.35, "attack_s": 0.01, "decay_s": 0.5, "sustain": 0.4, "gate_s": 0.6, "release_s": 0.2, "vibrato_hz": 7.0, "vibrato_semitones": 1.2},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.8, "low_hz": 150.0, "high_hz": 1600.0, "peak": 0.25, "noise": "&brown"}, "gain_db": -8.0}],
                 bind=level(-12.0, -5.0), send=0.45, seed=306),
    "kaleido": dict(voice="whoosh", params={"length_s": 0.8, "low_hz": 1200.0, "high_hz": 11000.0, "peak": 0.9, "shape": 2.5, "mode": "&band", "q": 2.0},
                    layers=[{"voice": "&mallet", "params": {"freq_hz": 1975.53, "material": "&glass", "hardness": 0.6, "decay_s": 0.8}, "gain_db": -10.0, "offset_s": 0.7}],
                    transforms=[], bind=level(-14.0, -6.0), send=0.55, offset_s=-0.7, seed=307),
    "segment": dict(voice="mallet", params={"freq_hz": 493.88, "material": "&metal", "hardness": 0.7, "decay_s": 0.6},
                    bind=pitched(-14.0, -6.0), send=0.5, seed=308),
    "pour": dict(voice="tone", params={"wave": "&saw", "freq_hz": 110.0, "end_hz": 880.0, "glide_s": 0.3, "attack_s": 0.5, "decay_s": 0.2, "sustain": 1.0, "gate_s": 0.6, "release_s": 0.004, "length_s": 0.6},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 300.0, "high_hz": 8000.0, "peak": 0.97, "shape": 3.0, "noise": "&pink"}, "gain_db": -3.0},
                         {"voice": "&ratchet", "params": {"length_s": 0.6, "start_rate_hz": 12.0, "end_rate_hz": 60.0, "click_hz": 1400.0, "q": 5.0, "jitter": 0.3, "fade": 0.0}, "gain_db": -12.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 6000.0, "slope_db": 12.0}],
                 bind=level(-12.0, -5.0), send=0.3, seed=309),
    "drop": dict(voice="kick", params={"tune_hz": 46.0, "punch": 4.0, "drop_s": 0.04, "decay_s": 0.55, "click": 0.5, "drive": 0.3},
                 layers=[{"voice": "&boing", "params": {"start_hz": 130.0, "end_hz": 41.0, "drop_s": 0.15, "decay_s": 0.6, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&fm", "params": {"freq_hz": 329.63, "ratio": 3.5, "index": 4.0, "index_end": 0.5, "decay_s": 1.6, "gate_s": 0.5}, "gain_db": -9.0},
                         {"voice": "&fm", "params": {"freq_hz": 493.88, "ratio": 2.0, "index": 3.0, "index_end": 0.4, "decay_s": 1.4, "gate_s": 0.5}, "gain_db": -11.0},
                         {"voice": "&whoosh", "params": {"length_s": 1.2, "low_hz": 300.0, "high_hz": 7000.0, "peak": 0.05, "shape": 2.0, "noise": "&pink"}, "gain_db": -9.0}],
                 bind=level(-4.0, 0.0), send=0.45, seed=310),
    "kana": dict(voice="pluck", params={"freq_hz": 1318.51, "brightness": 0.5, "decay_s": 0.18},
                 layers=[{"voice": "&pluck", "params": {"freq_hz": 1567.98, "brightness": 0.5, "decay_s": 0.18}, "gain_db": -2.0, "offset_s": 0.06},
                         {"voice": "&pluck", "params": {"freq_hz": 1975.53, "brightness": 0.5, "decay_s": 0.25}, "gain_db": -3.0, "offset_s": 0.12}],
                 bind=level(-20.0, -12.0), send=0.4, seed=311),
    "bloom": dict(voice="whoosh", params={"length_s": 1.0, "low_hz": 800.0, "high_hz": 9000.0, "peak": 0.5, "shape": 1.6, "mode": "&band", "q": 1.5},
                  layers=[{"voice": "&mallet", "params": {"freq_hz": 2637.02, "material": "&glass", "hardness": 0.5, "decay_s": 0.9}, "gain_db": -12.0}],
                  bind=level(-16.0, -8.0), send=0.55, seed=312),
    "ripple": dict(voice="tone", params={"wave": "&sine", "freq_hz": 330.0, "end_hz": 250.0, "glide_s": 0.2, "decay_s": 0.5, "gate_s": 0.4, "release_s": 0.2, "vibrato_hz": 9.0, "vibrato_semitones": 1.5},
                   bind=pitched(-14.0, -6.0), send=0.45, seed=313),
    "melt_out": dict(voice="tone", params={"wave": "&triangle", "freq_hz": 900.0, "end_hz": 60.0, "glide_s": 0.6, "attack_s": 0.02, "decay_s": 0.8, "sustain": 0.4, "gate_s": 1.0, "release_s": 0.3, "vibrato_hz": 6.0, "vibrato_semitones": 1.5},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 1.2, "low_hz": 120.0, "high_hz": 1400.0, "peak": 0.2, "noise": "&brown"}, "gain_db": -6.0}],
                     bind=level(-10.0, -4.0), send=0.5, seed=314),
    "sink": dict(voice="wavetable", params={"freq_hz": 164.81, "position": 0.5, "unison": 5, "detune_cents": 20.0, "cutoff_hz": 1200.0, "env_octaves": 0.0, "attack_s": 0.05, "sustain": 0.8, "gate_s": 1.0, "release_s": 0.4},
                 layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 164.81, "end_hz": 41.2, "glide_s": 0.6, "decay_s": 1.0, "sustain": 0.5, "gate_s": 1.0, "release_s": 0.3}, "gain_db": -3.0},
                         {"voice": "&whoosh", "params": {"length_s": 1.2, "low_hz": 100.0, "high_hz": 1200.0, "peak": 0.15, "noise": "&brown"}, "gain_db": -8.0}],
                 transforms=[{"type": "varispeed", "from": 1.0, "to": 0.45}],
                 bind=level(-10.0, -4.0), send=0.5, seed=315),
    "last": dict(voice="mallet", params={"freq_hz": 164.81, "material": "&glass", "hardness": 0.4, "decay_s": 0.25},
                 layers=[{"voice": "&boing", "params": {"start_hz": 82.0, "end_hz": 41.0, "drop_s": 0.1, "decay_s": 0.12, "sub": 0.8, "click": 0.0}, "gain_db": -6.0}],
                 bind=level(-8.0, -3.0), send=0.4, seed=316),
}

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "lsd_map.tres"), {
    "dawn": R + "dawn.tres", "sun.peek": R + "sun_peek.tres", "rise": R + "rise.tres", "set": R + "set.tres",
    "presents": R + "presents.tres", "melt": R + "melt.tres", "kaleido": R + "kaleido.tres", "segment": R + "segment.tres",
    "pour": R + "pour.tres", "drop": R + "drop.tres", "kana": R + "kana.tres", "bloom": R + "bloom.tres",
    "ripple": R + "ripple.tres", "melt.out": R + "melt_out.tres", "sink": R + "sink.tres", "last": R + "last.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.7, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -1.0}, end_fade_s=0.5)
with open(os.path.join(D, "lsd_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -20.0, "attack_s": 0.01, "release_s": 0.35}\n')

# ------------------------------------------------------------------ music (100 bpm)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 52.0, "punch": 2.5, "decay_s": 0.32, "click": 0.25, "drive": 0.15}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=402, send=0.45,
       params={"color_hz": 1400.0, "tail_decay_s": 0.16}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=403, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.09, "tone_hz": 9000.0, "metal": 0.5}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "shaker.tres"), voice="hat", seed=404, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.03, "tone_hz": 11000.0, "metal": 0.1}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "acid.tres"), voice="wavetable", seed=405,
       params={"position": 0.68, "sub": 0.15, "cutoff_hz": 380.0, "env_octaves": 3.4, "filter_decay_s": 0.14, "q": 7.0,
               "attack_s": 0.002, "decay_s": 0.14, "sustain": 0.4, "release_s": 0.03},
       fx=[{"type": "drive", "amount": 0.25}, {"type": "echo", "time_s": 0.45, "feedback": 0.3, "mix": 0.18}], bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=406,
       params={"position": 0.2, "sub": 0.6, "cutoff_hz": 500.0, "env_octaves": 1.0, "filter_decay_s": 0.15, "q": 0.9,
               "attack_s": 0.004, "decay_s": 0.2, "sustain": 0.6, "release_s": 0.06}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=407, send=0.6,
       params={"position": 0.5, "unison": 5, "detune_cents": 18.0, "cutoff_hz": 1300.0, "env_octaves": 0.4, "filter_decay_s": 1.0,
               "q": 0.7, "attack_s": 0.5, "decay_s": 0.8, "sustain": 0.75, "release_s": 0.5})
recipe(os.path.join(MD, "arp.tres"), voice="fm", seed=408, send=0.45,
       params={"ratio": 3.0, "index": 2.2, "index_end": 0.3, "index_decay_s": 0.15, "decay_s": 0.35, "gate_s": 0.1, "release_s": 0.2},
       fx=[{"type": "echo", "time_s": 0.45, "feedback": 0.35, "mix": 0.25}], bind=level(-12.0, 0.0))

# E minor: Em9 - Cmaj7 over two bars
ARP = ["E5", "B4", "G5", "D5", "B5", "G5", "D5", "B4"]
arp = {"name": "arp", "recipe": M + "arp.tres", "steps": "x.x.x.x.x.x.x.x.", "length": 16, "notes": ARP, "gate": 0.5, "gain_db": -10.0, "pan": 0.2}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 15 + "x" + "." * 15, "length": 32, "notes": ["E3", "C3"], "chord": [0, 7, 10, 14], "gate": 15.0, "gain_db": -10.0}
kick4 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick_soft = {"name": "kick", "recipe": M + "kick.tres", "steps": "o...o...o...o...", "length": 16, "gain_db": -4.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -6.0}
ohat = {"name": "hat", "recipe": M + "hat.tres", "steps": "..x...x...x...x.", "length": 16, "gain_db": -12.0, "pan": 0.15}
shaker = {"name": "shaker", "recipe": M + "shaker.tres", "steps": "xoxoxoxoxoxoxoxo", "length": 16, "gain_db": -18.0, "pan": -0.2}
ACID_STEPS = "x.xX.xx.x.Xx.x.x"
acid = {"name": "acid", "recipe": M + "acid.tres", "steps": ACID_STEPS, "length": 16, "notes": [40, 52, 40, 43, 47, 40, 50, 52, 45, 40], "gate": 0.7, "gain_db": -6.0}
bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "x..x..x...x..x..", "length": 16, "notes": ["E2", "E2", "G2", "D2", "E2"], "gate": 0.8, "gain_db": -6.0}

P = "AKPattern"
pat = lambda name, steps, lanes, swing=0.54: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                                      {"steps": steps, "seed": len(name), "swing": swing, "lanes": lanes}, typed={"lanes"})
pat("dawn", 32, [pad, arp])
pat("groove", 32, [pad, arp, kick_soft, ohat])
pat("trip", 32, [pad, arp, kick4, ohat, clap, shaker, acid])
pat("full", 32, [pad, arp, kick4, ohat, clap, shaker, acid, bass])
pat("outro", 32, [pad, arp, acid, shaker])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 100.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "lsd_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "dawn", "bars": 1.0, "patterns": [M + "dawn.tres"], "automation": {"pad.gain_db": [[0.0, -12.0], [1.0, 0.0]]}},
        {"name": "groove", "bars": 1.0, "patterns": [M + "groove.tres"]},
        {"name": "trip", "bars": 0.75, "patterns": [M + "trip.tres"],
         "automation": {"acid.cutoff_hz": [[0.0, 260.0], [1.0, 1300.0]], "acid.q": [[0.0, 4.0], [1.0, 9.0]]}},
        {"name": "break", "bars": 0.25, "patterns": [M + "silence.tres"]},
        {"name": "full", "bars": 5.0 / 3.0, "patterns": [M + "full.tres"],
         "automation": {"acid.cutoff_hz": [[0.0, 700.0], [0.5, 1700.0], [1.0, 900.0]]}},
        {"name": "outro", "bars": 5.0 / 6.0, "patterns": [M + "outro.tres"],
         "automation": {"acid.cutoff_hz": [[0.0, 800.0], [1.0, 200.0]], "acid.gain_db": [[0.0, 0.0], [1.0, -14.0]],
                        "arp.gain_db": [[0.0, 0.0], [1.0, -12.0]], "pad.gain_db": [[0.0, 0.0], [1.0, -10.0]]}},
        {"name": "tail", "bars": 0.25, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, lsd_map.tres and the 100 bpm song" % len(fx))
