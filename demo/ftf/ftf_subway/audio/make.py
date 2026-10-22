#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF take "Insane Subway Map" (demo/ftf/ftf_subway): effect
recipes, the cue map and a 150 bpm transit-techno bed, for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_subway/audio/make.py

Sound sheet (shared reverb 0.4, a station hall; music ducks 6 dB under hits):
  line       a glass station ping per new line, climbing a D pentatonic
  mh.draw    a felt-pen scribble: a slow ratchet that speeds up as the word draws
  chime      the station two-tone (ding-dong, glass), the word complete
  presents   a soft FM bell under PRESENTS
  explode    a deep boom and a rushing whoosh: the network explodes
  burst      short bright plucks on every eighth of the explosion, climbing
  pink       a saw glide riding the pink line's head (filtered)
  box        a tight band whoosh as the inset box opens
  riser      noise and saw swelling for 1.2 s into the drop
  drop       heavy kick, sub boing and a metal bell: the logo lands
  label      a fine ticker as the station label types
  express    a pass-by: whoosh with a falling tone
  door       the doors-closing beep (square, short)
  retract    a reversed whoosh as the lines pull back
  zoomout    a sine dive as the map shrinks to a dot
  blip       a final glass ping with a soft sub
Music: 150 bpm, 4/4, first downbeat at 0.0 s; a bar is 48 frames.
  intro  bar 0       station-jingle arp and rail clacks
  mh     bars 1-3    clacks, offbeat hats, a soft bass
  build  bar 3       kick on fours, snare roll, bass opening up
  drop   bars 4-7    full groove: kick, clap, hats, clacks, bass, pad chords
  outro  bar 7       kick and clacks, bass closing down
  tail   bars 8-8.75 silence; the final blip rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_subway/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "line": dict(voice="mallet", params={"freq_hz": 1174.66, "material": "&glass", "hardness": 0.55, "decay_s": 0.35},
                 bind=pitched(-16.0, -8.0), send=0.4, seed=301),
    "mh_draw": dict(voice="ratchet", params={"length_s": 1.5, "start_rate_hz": 16.0, "end_rate_hz": 70.0, "click_hz": 2400.0, "q": 2.5,
                    "jitter": 0.3, "fade": 0.2}, bind=level(-22.0, -12.0), seed=302),
    "chime": dict(voice="mallet", params={"freq_hz": 1318.51, "material": "&glass", "hardness": 0.45, "decay_s": 0.9},
                  layers=[{"voice": "&mallet", "params": {"freq_hz": 1046.5, "material": "&glass", "hardness": 0.45, "decay_s": 1.1},
                           "gain_db": -1.0, "offset_s": 0.4}],
                  bind=level(-10.0, -3.0), send=0.5, seed=303),
    "presents": dict(voice="fm", params={"freq_hz": 587.33, "ratio": 3.5, "index": 4.0, "index_end": 0.4, "index_decay_s": 0.3,
                     "decay_s": 0.9, "gate_s": 0.5}, bind=level(-14.0, -6.0), send=0.45, seed=304),
    "explode": dict(voice="boing", params={"start_hz": 140.0, "end_hz": 36.0, "drop_s": 0.2, "decay_s": 0.6, "sub": 1.0, "click": 0.6},
                    layers=[{"voice": "&whoosh", "params": {"length_s": 0.9, "low_hz": 200.0, "high_hz": 8000.0, "peak": 0.25, "noise": "&pink"},
                             "gain_db": -3.0}],
                    bind=level(-6.0, 0.0), send=0.3, seed=305),
    "burst": dict(voice="pluck", params={"freq_hz": 587.33, "brightness": 0.7, "decay_s": 0.18, "tone_hz": 6000.0},
                  bind=pitched(-16.0, -8.0), vary={"decay_s": 0.2}, send=0.3, seed=306),
    "pink": dict(voice="tone", params={"wave": "&saw", "freq_hz": 220.0, "end_hz": 880.0, "glide_s": 0.5, "attack_s": 0.2,
                 "decay_s": 0.3, "sustain": 0.8, "gate_s": 1.1, "release_s": 0.05, "length_s": 1.2},
                 fx=[{"type": "lowpass", "cutoff_hz": 2400.0, "slope_db": 24.0}], bind=level(-18.0, -11.0), send=0.25, seed=307),
    "box": dict(voice="whoosh", params={"length_s": 0.25, "low_hz": 600.0, "high_hz": 5000.0, "peak": 0.8, "mode": "&band", "q": 1.4},
                bind=level(-16.0, -8.0), send=0.2, seed=308),
    "riser": dict(voice="tone", params={"wave": "&saw", "freq_hz": 150.0, "end_hz": 1600.0, "glide_s": 0.6, "attack_s": 0.9,
                  "decay_s": 0.3, "sustain": 1.0, "gate_s": 1.2, "release_s": 0.004, "length_s": 1.2},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 1.2, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.97, "shape": 3.0,
                           "noise": "&pink"}, "gain_db": -2.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 7000.0, "slope_db": 12.0}],
                  bind=level(-14.0, -7.0), send=0.15, offset_s=-1.2, seed=309),
    "drop": dict(voice="kick", params={"tune_hz": 45.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.55, "click": 0.7, "drive": 0.45},
                 layers=[{"voice": "&boing", "params": {"start_hz": 150.0, "end_hz": 38.0, "drop_s": 0.15, "decay_s": 0.5, "sub": 1.0, "click": 0.0},
                          "gain_db": -4.0},
                         {"voice": "&mallet", "params": {"freq_hz": 293.66, "material": "&metal", "hardness": 0.9, "decay_s": 0.9}, "gain_db": -7.0}],
                 bind=level(-4.0, 0.0), send=0.35, seed=310),
    "label": dict(voice="ratchet", params={"length_s": 0.45, "start_rate_hz": 60.0, "end_rate_hz": 40.0, "click_hz": 6500.0, "q": 6.0, "fade": 0.5},
                  bind=level(-24.0, -14.0), seed=311),
    "express": dict(voice="whoosh", params={"length_s": 0.85, "low_hz": 250.0, "high_hz": 6000.0, "peak": 0.5, "shape": 1.6, "noise": "&pink"},
                    layers=[{"voice": "&tone", "params": {"wave": "&triangle", "freq_hz": 900.0, "end_hz": 600.0, "glide_s": 0.25, "attack_s": 0.2,
                             "decay_s": 0.4, "gate_s": 0.6, "length_s": 0.8}, "gain_db": -12.0}],
                    bind=pitched(-12.0, -4.0), send=0.3, seed=312),
    "door": dict(voice="tone", params={"wave": "&square", "freq_hz": 880.0, "decay_s": 0.06, "sustain": 0.8, "gate_s": 0.07, "release_s": 0.01,
                 "length_s": 0.1}, fx=[{"type": "lowpass", "cutoff_hz": 4000.0}], bind=level(-20.0, -12.0), send=0.25, seed=313),
    "retract": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 300.0, "high_hz": 7000.0, "peak": 0.2, "noise": "&pink"},
                    transforms=[{"type": "reverse"}], offset_s=-0.4, bind=level(-12.0, -5.0), send=0.25, seed=314),
    "zoomout": dict(voice="tone", params={"wave": "&sine", "freq_hz": 900.0, "end_hz": 80.0, "glide_s": 0.3, "attack_s": 0.02, "decay_s": 0.6,
                    "gate_s": 0.8, "length_s": 1.0}, bind=level(-14.0, -7.0), send=0.3, seed=315),
    "blip": dict(voice="mallet", params={"freq_hz": 1760.0, "material": "&glass", "hardness": 0.6, "decay_s": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 120.0, "end_hz": 55.0, "drop_s": 0.08, "decay_s": 0.25, "sub": 0.8, "click": 0.1},
                          "gain_db": -8.0}],
                 bind=level(-8.0, -2.0), send=0.5, seed=316),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "subway_map.tres"), {
    "line": R + "line.tres", "mh.draw": R + "mh_draw.tres", "chime": R + "chime.tres", "presents": R + "presents.tres",
    "explode": R + "explode.tres", "burst": R + "burst.tres", "pink": R + "pink.tres", "box": R + "box.tres",
    "riser": R + "riser.tres", "drop": R + "drop.tres", "label": R + "label.tres", "express": R + "express.tres",
    "door": R + "door.tres", "retract": R + "retract.tres", "zoomout": R + "zoomout.tres", "blip": R + "blip.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.4, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -2.0}, end_fade_s=0.4)
with open(os.path.join(D, "subway_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 6.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.25}\n')

# ------------------------------------------------------------------ music (150 bpm, D minor pentatonic)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 48.0, "punch": 3.8, "decay_s": 0.27, "click": 0.5, "drive": 0.3}, bind=level(-7.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=402, send=0.3,
       params={"color_hz": 1400.0, "tail_decay_s": 0.12}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=403, send=0.2,
       params={"tone_hz": 200.0, "tone": 0.4, "noise": 0.9, "noise_hz": 6000.0, "noise_decay_s": 0.09},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=404, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.035, "tone_hz": 9500.0, "metal": 0.6}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "clack.tres"), voice="click", seed=405, vary={"freq_hz": 0.12}, vary_variants=4,
       params={"freq_hz": 1800.0, "mode": "&band", "q": 6.0, "decay_s": 0.02, "body_hz": 180.0, "body": 0.6}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=406,
       params={"position": 0.62, "sub": 0.35, "cutoff_hz": 380.0, "env_octaves": 2.6, "filter_decay_s": 0.1, "q": 3.0,
               "attack_s": 0.002, "decay_s": 0.12, "sustain": 0.4, "release_s": 0.03}, bind=level(-9.0, 0.0))
recipe(os.path.join(MD, "chime.tres"), voice="mallet", seed=407, send=0.45,
       params={"freq_hz": 880.0, "material": "&glass", "hardness": 0.5, "decay_s": 0.5}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=408, send=0.5,
       params={"position": 0.55, "unison": 5, "detune_cents": 16.0, "cutoff_hz": 1300.0, "env_octaves": 0.5, "filter_decay_s": 1.0,
               "q": 0.7, "attack_s": 0.3, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.3})

# the station jingle: D pentatonic, one bar
jingle = {"name": "chime", "recipe": M + "chime.tres", "steps": "x.x.x...x.x.x...", "length": 16,
          "notes": [81, 78, 74, 76, 83, 81], "gain_db": -8.0}
clack = {"name": "clack", "recipe": M + "clack.tres", "steps": "x..x.x......x..x", "length": 16, "gain_db": -8.0}
clack_soft = dict(clack, gain_db=-13.0)
hat = {"name": "hat", "recipe": M + "hat.tres", "steps": "..x...x...x...xo", "length": 16, "gain_db": -12.0, "pan": 0.15}
hat16 = {"name": "hat", "recipe": M + "hat.tres", "steps": "o.x.o.x.o.x.o.xo", "length": 16, "gain_db": -11.0, "pan": 0.15}
kick4 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick_soft = {"name": "kick", "recipe": M + "kick.tres", "steps": "o.......o.......", "length": 16, "gain_db": -6.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -4.0}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "..o...o.o.o.oxoxxxxxxxxxxxXXXXXX", "length": 32, "gain_db": -6.0}
BASS = [38, 38, 50, 38, 45, 38, 48, 50]  # D2 ...
bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.xxx.x.x.xxx.x.", "length": 16, "notes": BASS, "gate": 0.7, "gain_db": -3.0}
bass_soft = dict(bass, steps="x.......x.......", gain_db=-6.0)
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 47, "length": 48, "notes": [50, 46, 48],
       "chord": [0, 3, 7, 10], "gate": 46.0, "gain_db": -11.0}

P = "AKPattern"
pat = lambda name, steps, lanes, swing=0.5: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                                     {"steps": steps, "seed": len(name), "swing": swing, "lanes": lanes}, typed={"lanes"})
pat("intro", 16, [jingle, clack_soft])
pat("mh", 32, [jingle, clack, hat, kick_soft, bass_soft])
pat("build", 32, [kick4, clack, hat16, roll, bass])
pat("drop", 48, [kick4, clap, clack, hat16, bass, pad], swing=0.54)
pat("outro", 16, [kick4, clack, hat, bass])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 150.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "subway_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"]},
        {"name": "mh", "bars": 2.0, "patterns": [M + "mh.tres"]},
        {"name": "build", "bars": 1.0, "patterns": [M + "build.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 300.0], [1.0, 1500.0]]}},
        {"name": "drop", "bars": 3.0, "patterns": [M + "drop.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 700.0], [0.5, 1600.0], [1.0, 900.0]]}},
        {"name": "outro", "bars": 1.0, "patterns": [M + "outro.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 800.0], [1.0, 200.0]], "bass.gain_db": [[0.0, 0.0], [1.0, -12.0]],
                        "kick.gain_db": [[0.0, 0.0], [1.0, -8.0]]}},
        {"name": "tail", "bars": 0.75, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, subway_map.tres and the 150 bpm song" % len(fx))
