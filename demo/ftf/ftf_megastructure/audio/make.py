#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for FTF take 2, MEGASTRUCTURE (demo/ftf/ftf_megastructure): effect
recipes, the cue map and a 120 bpm industrial electro bed, for the Godot Audio
Kit. Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_megastructure/audio/make.py

Sound sheet (a big hard room; metal, hydraulics and stamps; music ducks 8 dB):
  city.ring     a metal latch clank per ring of rising blocks, climbing
  mh.rise       low hydraulic swell (brown noise + a falling sine) into the land
  mh.land       heavy machine clank: sub thump, metal bar, short noise slap
  mh.unfold     two-stage latch: ratchet run and a bright metal knock
  stamp         rubber stamp thud with a paper slap
  stamp.small   a small stamp, higher
  sink          reversed hydraulic hiss, falling
  whip          fast pink-noise whoosh across the roofs
  arrive        a dull boom as the camera lands
  drain         stepped descending ratchet: blocks draining away
  ftf.rise      a long rising machine swell (saw glide + rumble), 1 s
  ftf.lock      the big one: kick, sub boing, metal clang, noise slap
  cam.lock      a bright FM bell, the front elevation locking
  cam.back      soft whoosh pulling back
  city.sink     long falling hydraulic with a ratchet
  dive          airy whoosh into the ground
  end           a final low latch
Music: 120 bpm, 4/4, first downbeat at 0.0 s (frame 0), a bar is 60 frames.
  build  bar 0       kick, metal tick, bass pulse
  mh     bars 1-2.5  + clap, FM metal hits, square arp
  fill   bar 2.5-3   kick drops out, a snare roll under the whip
  drive  bars 3-5.5  full groove: kick, clap, hats, bass, arp, metal
  outro  5.5-6.75    kick and bass thinning out
  tail   6.75-7      silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_megastructure/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "city_ring": dict(voice="mallet", params={"freq_hz": 330.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.12, "damping": 1.2},
                      layers=[{"voice": "&click", "params": {"freq_hz": 3200.0, "mode": "&band", "q": 6.0, "decay_s": 0.004, "body_hz": 110.0, "body": 0.6}, "gain_db": -4.0}],
                      bind=pitched(-16.0, -7.0), send=0.2, seed=301),
    "mh_rise": dict(voice="whoosh", params={"length_s": 0.55, "low_hz": 80.0, "high_hz": 900.0, "peak": 0.92, "shape": 2.0, "noise": "&brown"},
                    layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 55.0, "end_hz": 110.0, "glide_s": 0.3, "attack_s": 0.3, "decay_s": 0.2, "sustain": 1.0, "gate_s": 0.5, "length_s": 0.5}, "gain_db": -6.0}],
                    bind=level(-12.0, -4.0), send=0.25, seed=302),
    "mh_land": dict(voice="boing", params={"start_hz": 150.0, "end_hz": 45.0, "drop_s": 0.05, "decay_s": 0.35, "sub": 1.0, "click": 0.9, "click_hz": 4000.0},
                    layers=[{"voice": "&mallet", "params": {"freq_hz": 140.0, "material": "&bar", "hardness": 1.0, "decay_s": 0.45}, "gain_db": -5.0},
                            {"voice": "&snare", "params": {"tone_hz": 160.0, "tone": 0.2, "noise": 1.0, "noise_hz": 3500.0, "noise_decay_s": 0.09}, "gain_db": -8.0}],
                    bind=level(-4.0, 0.0), send=0.35, seed=303),
    "mh_unfold": dict(voice="ratchet", params={"length_s": 0.22, "start_rate_hz": 30.0, "end_rate_hz": 90.0, "click_hz": 2400.0, "q": 5.0, "fade": 0.0},
                      layers=[{"voice": "&mallet", "params": {"freq_hz": 880.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.3}, "gain_db": -4.0, "offset_s": 0.2},
                              {"voice": "&boing", "params": {"start_hz": 240.0, "end_hz": 90.0, "drop_s": 0.03, "decay_s": 0.12, "sub": 0.4, "click": 0.5}, "gain_db": -5.0, "offset_s": 0.2}],
                      bind=level(-8.0, -1.0), send=0.3, seed=304),
    "stamp": dict(voice="boing", params={"start_hz": 110.0, "end_hz": 60.0, "drop_s": 0.02, "decay_s": 0.09, "sub": 0.5, "click": 1.0, "click_hz": 2200.0},
                  layers=[{"voice": "&clap", "params": {"bursts": 1, "tail_decay_s": 0.05, "color_hz": 1600.0}, "gain_db": -6.0}],
                  bind=level(-6.0, -1.0), send=0.25, seed=305),
    "stamp_small": dict(voice="click", params={"freq_hz": 1800.0, "mode": "&band", "q": 2.0, "decay_s": 0.02, "body_hz": 180.0, "body": 0.8},
                        bind=level(-14.0, -6.0), send=0.2, seed=306),
    "sink": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 90.0, "high_hz": 1400.0, "peak": 0.25, "noise": "&brown"},
                 layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 160.0, "end_hz": 45.0, "glide_s": 0.15, "decay_s": 0.4, "gate_s": 0.4, "length_s": 0.5}, "gain_db": -6.0}],
                 bind=level(-12.0, -4.0), send=0.3, seed=307),
    "whip": dict(voice="whoosh", params={"length_s": 0.45, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.55, "shape": 2.4, "noise": "&pink"},
                 bind=level(-10.0, -2.0), send=0.3, seed=308),
    "arrive": dict(voice="boing", params={"start_hz": 90.0, "end_hz": 38.0, "drop_s": 0.12, "decay_s": 0.5, "sub": 1.0, "click": 0.2},
                   bind=level(-8.0, -2.0), send=0.4, seed=309),
    "drain": dict(voice="ratchet", params={"length_s": 0.42, "start_rate_hz": 28.0, "end_rate_hz": 10.0, "click_hz": 1400.0, "q": 4.0, "fade": 0.5, "accent_every": 2.0},
                  layers=[{"voice": "&tone", "params": {"wave": "&triangle", "freq_hz": 300.0, "end_hz": 70.0, "glide_s": 0.15, "decay_s": 0.35, "gate_s": 0.35, "length_s": 0.42}, "gain_db": -10.0}],
                  bind=level(-12.0, -4.0), send=0.25, seed=310),
    "ftf_rise": dict(voice="tone", params={"wave": "&saw", "freq_hz": 45.0, "end_hz": 180.0, "glide_s": 0.5, "attack_s": 0.6, "decay_s": 0.2, "sustain": 1.0, "gate_s": 0.95, "release_s": 0.02, "length_s": 1.0},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 1.0, "low_hz": 60.0, "high_hz": 2200.0, "peak": 0.95, "shape": 2.6, "noise": "&brown"}, "gain_db": -1.0}],
                     fx=[{"type": "lowpass", "cutoff_hz": 1800.0, "slope_db": 24.0}, {"type": "drive", "amount": 0.3}],
                     bind=level(-10.0, -3.0), send=0.2, seed=311),
    "ftf_lock": dict(voice="kick", params={"tune_hz": 42.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.55, "click": 0.8, "drive": 0.5},
                     layers=[{"voice": "&boing", "params": {"start_hz": 120.0, "end_hz": 36.0, "drop_s": 0.12, "decay_s": 0.45, "sub": 1.0, "click": 0.0}, "gain_db": -5.0},
                             {"voice": "&mallet", "params": {"freq_hz": 196.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.7}, "gain_db": -5.0},
                             {"voice": "&snare", "params": {"tone_hz": 150.0, "tone": 0.3, "noise": 1.0, "noise_hz": 5000.0, "noise_decay_s": 0.16}, "gain_db": -6.0}],
                     bind=level(-3.0, 0.0), send=0.4, seed=312),
    "cam_lock": dict(voice="fm", params={"freq_hz": 1046.5, "ratio": 3.5, "index": 4.0, "index_end": 0.3, "index_decay_s": 0.25, "decay_s": 0.7, "gate_s": 0.1, "release_s": 0.4},
                     bind=level(-14.0, -7.0), send=0.45, seed=313),
    "cam_back": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 250.0, "high_hz": 3500.0, "peak": 0.5, "noise": "&pink"},
                     bind=level(-16.0, -8.0), send=0.3, seed=314),
    "city_sink": dict(voice="whoosh", params={"length_s": 1.0, "low_hz": 60.0, "high_hz": 1600.0, "peak": 0.2, "shape": 1.6, "noise": "&brown"},
                      layers=[{"voice": "&ratchet", "params": {"length_s": 0.9, "start_rate_hz": 40.0, "end_rate_hz": 8.0, "click_hz": 1100.0, "q": 4.0, "fade": 0.7}, "gain_db": -6.0},
                              {"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 140.0, "end_hz": 35.0, "glide_s": 0.35, "decay_s": 0.8, "gate_s": 0.8, "length_s": 1.0}, "gain_db": -5.0}],
                      bind=level(-8.0, -2.0), send=0.3, seed=315),
    "dive": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 500.0, "high_hz": 7000.0, "peak": 0.85, "shape": 2.0},
                 layers=[{"voice": "&click", "params": {"freq_hz": 5000.0, "mode": "&band", "q": 2.0, "decay_s": 0.004}, "gain_db": -6.0}],
                 bind=level(-14.0, -6.0), send=0.3, seed=316),
    "end": dict(voice="click", params={"freq_hz": 900.0, "mode": "&band", "q": 3.0, "decay_s": 0.03, "body_hz": 70.0, "body": 1.0},
                layers=[{"voice": "&mallet", "params": {"freq_hz": 110.0, "material": "&bar", "hardness": 0.8, "decay_s": 0.25}, "gain_db": -6.0}],
                bind=level(-8.0, -2.0), send=0.35, seed=317),
}

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "mega_map.tres"), {
    "city.ring": R + "city_ring.tres", "mh.rise": R + "mh_rise.tres", "mh.land": R + "mh_land.tres", "mh.unfold": R + "mh_unfold.tres",
    "stamp": R + "stamp.tres", "stamp.small": R + "stamp_small.tres", "sink": R + "sink.tres", "whip": R + "whip.tres",
    "arrive": R + "arrive.tres", "drain": R + "drain.tres", "ftf.rise": R + "ftf_rise.tres", "ftf.lock": R + "ftf_lock.tres",
    "cam.lock": R + "cam_lock.tres", "cam.back": R + "cam_back.tres", "city.sink": R + "city_sink.tres", "dive": R + "dive.tres",
    "end": R + "end.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.55, "damp": 0.35, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.3)
with open(os.path.join(D, "mega_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 8.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music (120 bpm, D minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 46.0, "punch": 4.0, "decay_s": 0.32, "click": 0.6, "drive": 0.45}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=402, send=0.35,
       params={"bursts": 4, "color_hz": 1500.0, "tail_decay_s": 0.14}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=403, send=0.25,
       params={"tone_hz": 220.0, "tone": 0.35, "noise": 0.9, "noise_hz": 6500.0, "noise_decay_s": 0.08},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-16.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=404, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.025, "tone_hz": 10500.0, "metal": 0.8}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "metal.tres"), voice="fm", seed=405, send=0.3,
       params={"freq_hz": 293.66, "ratio": 2.76, "index": 6.0, "index_end": 0.5, "index_decay_s": 0.05, "decay_s": 0.16, "gate_s": 0.02, "release_s": 0.08},
       bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=406,
       params={"position": 1.0, "sub": 0.5, "cutoff_hz": 380.0, "env_octaves": 2.0, "filter_decay_s": 0.09, "q": 2.5,
               "attack_s": 0.002, "decay_s": 0.1, "sustain": 0.5, "release_s": 0.03},
       bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "arp.tres"), voice="wavetable", seed=407, send=0.35,
       params={"position": 0.95, "cutoff_hz": 1600.0, "env_octaves": 1.6, "filter_decay_s": 0.06, "q": 3.0,
               "attack_s": 0.002, "decay_s": 0.08, "sustain": 0.0, "release_s": 0.04},
       bind=level(-10.0, 0.0))

BASS_NOTES = [38, 38, 50, 38, 41, 38, 48, 38]          # D2 D2 D3 D2 F2 D2 C3 D2 (eighths)
ARP = ["D5", "A4", "F4", "A4", "D5", "C5", "A4", "F4", "D5", "A4", "F4", "A4", "E5", "C5", "A4", "G4"]
kick = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick_light = {"name": "kick", "recipe": M + "kick.tres", "steps": "x.......x.......", "length": 16, "gain_db": -3.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -6.0}
hat = {"name": "hat", "recipe": M + "hat.tres", "steps": "o.x.o.x.o.x.o.xo", "length": 16, "gain_db": -13.0, "pan": 0.2}
metal = {"name": "metal", "recipe": M + "metal.tres", "steps": "..x..x....x..x.x", "length": 16, "gain_db": -12.0, "pan": -0.25}
tick = {"name": "metal", "recipe": M + "metal.tres", "steps": "..o...o...o...o.", "length": 16, "gain_db": -15.0, "pan": -0.25}
bass = {"name": "bass", "recipe": M + "bass.tres", "steps": "x.x.x.x.x.x.x.x.", "length": 16, "notes": BASS_NOTES, "gate": 0.7, "gain_db": -4.0}
arp = {"name": "arp", "recipe": M + "arp.tres", "steps": "x" * 16, "length": 16, "notes": ARP, "gate": 0.6, "gain_db": -13.0, "pan": 0.15}
arp_sparse = dict(arp, steps="x.x.x.x.x.x.x.x.", gain_db=-15.0)
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "o.o.o.o.x.x.xxXX", "length": 16, "gain_db": -6.0}

P = "AKPattern"
pat = lambda name, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                    {"steps": 16, "seed": len(name), "lanes": lanes}, typed={"lanes"})
pat("build", [kick, tick, bass])
pat("mh", [kick, clap, metal, bass, arp_sparse])
pat("fill", [roll, dict(bass, steps="x...............")])
pat("drive", [kick, clap, hat, metal, bass, arp])
pat("outro", [kick_light, hat, bass])
pat("silence", [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 120.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "mega_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "build", "bars": 1.0, "patterns": [M + "build.tres"], "automation": {"bass.cutoff_hz": [[0.0, 200.0], [1.0, 380.0]]}},
        {"name": "mh", "bars": 1.5, "patterns": [M + "mh.tres"]},
        {"name": "fill", "bars": 0.5, "patterns": [M + "fill.tres"]},
        {"name": "drive", "bars": 2.5, "patterns": [M + "drive.tres"],
         "automation": {"arp.cutoff_hz": [[0.0, 900.0], [0.6, 2600.0], [1.0, 1800.0]], "bass.cutoff_hz": [[0.0, 380.0], [1.0, 620.0]]}},
        {"name": "outro", "bars": 1.25, "patterns": [M + "outro.tres"],
         "automation": {"bass.gain_db": [[0.0, 0.0], [1.0, -14.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -10.0]], "bass.cutoff_hz": [[0.0, 500.0], [1.0, 160.0]]}},
        {"name": "tail", "bars": 0.25, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, mega_map.tres and the 120 bpm song" % len(fx))
