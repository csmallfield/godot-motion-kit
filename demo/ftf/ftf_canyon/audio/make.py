#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the Canyon take (demo/ftf/ftf_canyon/ftf_canyon.gd): effect
recipes, the cue map and a 112.5 bpm industrial-electro song for the Godot
Audio Kit. Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_canyon/audio/make.py

Sound sheet (a hard concrete canyon; machinery, hydraulics, doppler fly-bys;
shared reverb 0.5 with a short pre-delay feel; music ducks 7 dB):
  open         shutter unlatch: heavy relay thunk and a hiss, the engine roar opening
  pass.walk    overhead fly-by: band whoosh peaking under the walkway, a falling
               doppler tone and a low steel ring as the deck passes
  pass.pipe    pipe rack whipping past: short whoosh and a two-note pipe clank
  pod          oncoming pod: doppler saw falling a fifth inside a bright whoosh
  mouth        out of the canyon: the air opens, a wide brown whoosh
  mh.reveal    the monument: deep metal boom (sub boing, bar strike, kick)
  mh.unfold    hydraulic telescope: ratchet run under a rising hiss, latch knock
  stamp        PRESENTS: rubber stamp thud with a paper slap
  stamp.small  katakana: a small high stamp
  whip         peel away: fast pink whoosh
  bank         banked corner: a hover-skid, filtered noise and a gliding tone
  lift         hydraulic lift out of the canyon: saw glide up under brown noise
  lens         the projection collapsing to isometric: a long riser, a tone
               climbing two octaves with a narrowing noise band, peaking as
               the view goes orthographic
  hatch        floor hatch unlocks: clank, pneumatic hiss
  ftf.rise     the slab rising: a heavy hydraulic swell into the drop
  ftf.lock     DROP: driven kick, sub drop, steel clang, noise slap, minor FM chord
  crane        tower crane slewing: a small motor whine with a ratchet
  city.sink    the city sinking in rings: long falling hydraulic with a ratchet
  ftf.sink     the slab sinking: falling saw with a brown whoosh
  hatch.shut   the hatch slams: heavy clank and a sub thump
  cut          lights cut: relay clunk, tape-stopped hum, static burst
Music: 112.5 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 64 frames,
E minor.
  run     bars 0-1        four-on-the-floor, rolling 16th bass, pneumatic hiss, clanks
  plaza   bars 1-2.25     half-time: kick on 1, clap on 3, FM steel stabs, a cold pad
  canyon  bars 2.25-3     the drive back: kick, rolling bass, hats
  lift    bars 3-3.75     kick drops to the bar, bass filter opening, pad swelling
  roll    bars 3.75-4     snare roll into the drop
  drop    bars 4-5.5      full: kick, clap, hats, rolling bass, steel arp, anvil
  outro   bars 5.5-6.25   kick and bass thinning out
  tail    bars 6.25-6.56  silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_canyon/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
os.makedirs(MD, exist_ok=True)
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "open": dict(voice="click", params={"freq_hz": 1400.0, "mode": "&band", "q": 2.0, "decay_s": 0.03, "body_hz": 62.0, "body": 1.0},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.6, "low_hz": 120.0, "high_hz": 3200.0, "peak": 0.35, "shape": 1.6, "noise": "&pink"}, "gain_db": -5.0},
                         {"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 41.2, "end_hz": 82.4, "glide_s": 0.4, "attack_s": 0.15, "decay_s": 0.3, "sustain": 0.5, "gate_s": 0.5, "release_s": 0.1, "length_s": 0.7}, "gain_db": -12.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 5000.0}], bind=level(-8.0, -2.0), send=0.35, seed=601),
    "pass_walk": dict(voice="whoosh", params={"length_s": 0.34, "low_hz": 250.0, "high_hz": 5200.0, "peak": 0.5, "shape": 2.2, "mode": "&band", "q": 0.9, "noise": "&pink"},
                      layers=[{"voice": "&tone", "params": {"wave": "&triangle", "freq_hz": 660.0, "end_hz": 440.0, "glide_s": 0.16, "attack_s": 0.12, "decay_s": 0.16, "sustain": 0.0, "gate_s": 0.22, "length_s": 0.34}, "gain_db": -16.0},
                              {"voice": "&mallet", "params": {"freq_hz": 110.0, "material": "&metal", "hardness": 0.7, "decay_s": 0.35}, "gain_db": -11.0, "offset_s": 0.16}],
                      bind=pitched(-12.0, -4.0), vary={"high_hz": 0.12, "length_s": 0.08}, send=0.3, seed=602),
    "pass_pipe": dict(voice="whoosh", params={"length_s": 0.18, "low_hz": 600.0, "high_hz": 7000.0, "peak": 0.55, "shape": 2.0, "noise": "&white"},
                      layers=[{"voice": "&mallet", "params": {"freq_hz": 392.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.22}, "gain_db": -8.0, "offset_s": 0.06},
                              {"voice": "&mallet", "params": {"freq_hz": 587.3, "material": "&metal", "hardness": 1.0, "decay_s": 0.16}, "gain_db": -12.0, "offset_s": 0.09}],
                      bind=pitched(-14.0, -6.0), vary={"high_hz": 0.1}, send=0.3, seed=603),
    "pod": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 400.0, "high_hz": 8000.0, "peak": 0.6, "shape": 2.4, "mode": "&band", "q": 1.2},
                layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 740.0, "end_hz": 494.0, "glide_s": 0.12, "attack_s": 0.25, "decay_s": 0.22, "sustain": 0.0, "gate_s": 0.32, "length_s": 0.5}, "gain_db": -15.0},
                        {"voice": "&tone", "params": {"wave": "&square", "freq_hz": 370.0, "end_hz": 247.0, "glide_s": 0.12, "attack_s": 0.25, "decay_s": 0.2, "sustain": 0.0, "gate_s": 0.3, "length_s": 0.5}, "gain_db": -20.0}],
                fx=[{"type": "lowpass", "cutoff_hz": 6500.0}], bind=pitched(-12.0, -4.0), send=0.3, seed=604),
    "mouth": dict(voice="whoosh", params={"length_s": 0.8, "low_hz": 90.0, "high_hz": 2400.0, "peak": 0.3, "shape": 1.5, "noise": "&brown"},
                  bind=level(-12.0, -4.0), send=0.55, seed=605),
    "mh_reveal": dict(voice="boing", params={"start_hz": 130.0, "end_hz": 41.2, "drop_s": 0.08, "decay_s": 0.6, "sub": 1.0, "click": 0.6, "click_hz": 3200.0},
                      layers=[{"voice": "&mallet", "params": {"freq_hz": 82.4, "material": "&bar", "hardness": 1.0, "decay_s": 0.9}, "gain_db": -5.0},
                              {"voice": "&fm", "params": {"freq_hz": 164.8, "ratio": 1.41, "index": 5.0, "index_end": 0.4, "index_decay_s": 0.3, "decay_s": 1.0, "gate_s": 0.1, "release_s": 0.6}, "gain_db": -12.0}],
                      bind=level(-5.0, 0.0), send=0.45, seed=606),
    "mh_unfold": dict(voice="ratchet", params={"length_s": 0.3, "start_rate_hz": 26.0, "end_rate_hz": 70.0, "click_hz": 2000.0, "q": 4.0, "fade": 0.0},
                      layers=[{"voice": "&whoosh", "params": {"length_s": 0.36, "low_hz": 900.0, "high_hz": 9000.0, "peak": 0.9, "shape": 1.4, "mode": "&high"}, "gain_db": -12.0},
                              {"voice": "&mallet", "params": {"freq_hz": 659.3, "material": "&metal", "hardness": 1.0, "decay_s": 0.35}, "gain_db": -6.0, "offset_s": 0.3},
                              {"voice": "&boing", "params": {"start_hz": 200.0, "end_hz": 70.0, "drop_s": 0.04, "decay_s": 0.16, "sub": 0.5, "click": 0.5}, "gain_db": -5.0, "offset_s": 0.3}],
                      bind=level(-9.0, -2.0), send=0.35, seed=607),
    "stamp": dict(voice="boing", params={"start_hz": 120.0, "end_hz": 62.0, "drop_s": 0.02, "decay_s": 0.1, "sub": 0.5, "click": 1.0, "click_hz": 2000.0},
                  layers=[{"voice": "&clap", "params": {"bursts": 1, "tail_decay_s": 0.05, "color_hz": 1500.0}, "gain_db": -6.0}],
                  bind=level(-7.0, -1.0), send=0.3, seed=608),
    "stamp_small": dict(voice="click", params={"freq_hz": 1900.0, "mode": "&band", "q": 2.0, "decay_s": 0.02, "body_hz": 190.0, "body": 0.8},
                        bind=level(-14.0, -6.0), send=0.25, seed=609),
    "whip": dict(voice="whoosh", params={"length_s": 0.4, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.5, "shape": 2.4, "noise": "&pink"},
                 bind=level(-10.0, -2.0), send=0.3, seed=610),
    "bank": dict(voice="whoosh", params={"length_s": 0.45, "low_hz": 1200.0, "high_hz": 4200.0, "peak": 0.4, "shape": 1.6, "mode": "&band", "q": 3.0},
                 layers=[{"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 330.0, "end_hz": 247.0, "glide_s": 0.3, "attack_s": 0.08, "decay_s": 0.3, "sustain": 0.3, "gate_s": 0.35, "release_s": 0.08, "length_s": 0.45}, "gain_db": -16.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 5000.0}], bind=level(-12.0, -5.0), send=0.3, seed=611),
    "lift": dict(voice="tone", params={"wave": "&saw", "freq_hz": 41.2, "end_hz": 110.0, "glide_s": 0.9, "attack_s": 0.3, "decay_s": 0.4, "sustain": 0.8, "gate_s": 1.1, "release_s": 0.2, "length_s": 1.4},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 1.3, "low_hz": 70.0, "high_hz": 1500.0, "peak": 0.6, "shape": 1.8, "noise": "&brown"}, "gain_db": -3.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 1400.0, "slope_db": 24.0}, {"type": "drive", "amount": 0.25}],
                 bind=level(-12.0, -5.0), send=0.3, seed=612),
    "lens": dict(voice="tone", params={"wave": "&square", "width": 0.3, "freq_hz": 164.8, "end_hz": 659.3, "glide_s": 1.4, "attack_s": 1.2, "decay_s": 0.1, "sustain": 1.0, "gate_s": 1.45, "release_s": 0.05, "length_s": 1.5},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 1.5, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.96, "shape": 3.0, "mode": "&band", "q": 1.6, "noise": "&pink"}, "gain_db": -2.0}],
                 fx=[{"type": "lowpass", "cutoff_hz": 4500.0}], bind=level(-14.0, -7.0), send=0.4, seed=613),
    "hatch": dict(voice="click", params={"freq_hz": 1100.0, "mode": "&band", "q": 3.0, "decay_s": 0.04, "body_hz": 90.0, "body": 1.0},
                  layers=[{"voice": "&static", "params": {"length_s": 0.35, "hiss": 1.0, "color_hz": 6000.0, "q": 0.7, "crackles_per_s": 0.0, "crackle": 0.0, "fade_s": 0.2}, "gain_db": -12.0, "offset_s": 0.03},
                          {"voice": "&mallet", "params": {"freq_hz": 147.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.3}, "gain_db": -8.0}],
                  bind=level(-10.0, -3.0), send=0.35, seed=614),
    "ftf_rise": dict(voice="tone", params={"wave": "&saw", "freq_hz": 41.2, "end_hz": 164.8, "glide_s": 0.75, "attack_s": 0.6, "decay_s": 0.2, "sustain": 1.0, "gate_s": 0.9, "release_s": 0.02, "length_s": 0.94},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 0.94, "low_hz": 60.0, "high_hz": 2400.0, "peak": 0.97, "shape": 2.6, "noise": "&brown"}, "gain_db": -1.0},
                             {"voice": "&ratchet", "params": {"length_s": 0.9, "start_rate_hz": 12.0, "end_rate_hz": 40.0, "click_hz": 1300.0, "q": 4.0, "fade": 0.0}, "gain_db": -14.0}],
                     fx=[{"type": "lowpass", "cutoff_hz": 2000.0, "slope_db": 24.0}, {"type": "drive", "amount": 0.3}],
                     bind=level(-10.0, -3.0), send=0.2, seed=615),
    "ftf_lock": dict(voice="kick", params={"tune_hz": 41.2, "punch": 5.0, "drop_s": 0.05, "decay_s": 0.6, "click": 0.8, "drive": 0.55},
                     layers=[{"voice": "&boing", "params": {"start_hz": 130.0, "end_hz": 33.0, "drop_s": 0.15, "decay_s": 0.5, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                             {"voice": "&mallet", "params": {"freq_hz": 196.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.8}, "gain_db": -6.0},
                             {"voice": "&snare", "params": {"tone_hz": 150.0, "tone": 0.3, "noise": 1.0, "noise_hz": 5000.0, "noise_decay_s": 0.16}, "gain_db": -6.0},
                             {"voice": "&fm", "params": {"freq_hz": 164.8, "ratio": 3.5, "index": 6.0, "index_end": 0.8, "index_decay_s": 0.4, "decay_s": 1.0, "gate_s": 0.7, "release_s": 0.4}, "gain_db": -12.0},
                             {"voice": "&fm", "params": {"freq_hz": 196.0, "ratio": 3.5, "index": 6.0, "index_end": 0.8, "index_decay_s": 0.4, "decay_s": 1.0, "gate_s": 0.7, "release_s": 0.4}, "gain_db": -14.0}],
                     bind=level(-3.0, 0.0), send=0.4, seed=616),
    "crane": dict(voice="tone", params={"wave": "&square", "width": 0.25, "freq_hz": 220.0, "end_hz": 262.0, "glide_s": 0.4, "attack_s": 0.1, "decay_s": 0.3, "sustain": 0.5, "gate_s": 0.5, "release_s": 0.15, "length_s": 0.7},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 0.6, "start_rate_hz": 18.0, "end_rate_hz": 22.0, "click_hz": 2600.0, "q": 5.0, "fade": 0.4}, "gain_db": -6.0}],
                  fx=[{"type": "bandpass", "cutoff_hz": 900.0, "q": 0.8}], bind=pitched(-18.0, -11.0), send=0.3, seed=617),
    "city_sink": dict(voice="whoosh", params={"length_s": 1.1, "low_hz": 60.0, "high_hz": 1500.0, "peak": 0.2, "shape": 1.6, "noise": "&brown"},
                      layers=[{"voice": "&ratchet", "params": {"length_s": 1.0, "start_rate_hz": 40.0, "end_rate_hz": 8.0, "click_hz": 1000.0, "q": 4.0, "fade": 0.7}, "gain_db": -6.0},
                              {"voice": "&tone", "params": {"wave": "&saw", "freq_hz": 123.5, "end_hz": 30.9, "glide_s": 0.9, "decay_s": 0.9, "gate_s": 0.9, "length_s": 1.1}, "gain_db": -9.0}],
                      fx=[{"type": "lowpass", "cutoff_hz": 2200.0}], bind=level(-8.0, -2.0), send=0.3, seed=618),
    "ftf_sink": dict(voice="tone", params={"wave": "&saw", "freq_hz": 164.8, "end_hz": 41.2, "glide_s": 0.4, "attack_s": 0.01, "decay_s": 0.4, "sustain": 0.4, "gate_s": 0.4, "release_s": 0.1, "length_s": 0.5},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 0.45, "low_hz": 80.0, "high_hz": 1800.0, "peak": 0.2, "noise": "&brown"}, "gain_db": -3.0}],
                     fx=[{"type": "lowpass", "cutoff_hz": 1600.0}], bind=level(-10.0, -4.0), send=0.3, seed=619),
    "hatch_shut": dict(voice="boing", params={"start_hz": 110.0, "end_hz": 40.0, "drop_s": 0.05, "decay_s": 0.35, "sub": 1.0, "click": 0.9, "click_hz": 3000.0},
                       layers=[{"voice": "&mallet", "params": {"freq_hz": 123.5, "material": "&bar", "hardness": 1.0, "decay_s": 0.4}, "gain_db": -5.0},
                               {"voice": "&snare", "params": {"tone_hz": 160.0, "tone": 0.2, "noise": 1.0, "noise_hz": 3500.0, "noise_decay_s": 0.08}, "gain_db": -9.0}],
                       bind=level(-5.0, 0.0), send=0.35, seed=620),
    "cut": dict(voice="tone", params={"wave": "&saw", "freq_hz": 110.0, "attack_s": 0.002, "decay_s": 0.4, "sustain": 0.7, "gate_s": 0.45, "release_s": 0.1, "length_s": 0.6},
                layers=[{"voice": "&click", "params": {"freq_hz": 1200.0, "mode": "&band", "q": 2.5, "decay_s": 0.03, "body_hz": 60.0, "body": 1.0}, "gain_db": 0.0},
                        {"voice": "&static", "params": {"length_s": 0.18, "hiss": 0.8, "color_hz": 3000.0, "crackles_per_s": 600.0, "crackle": 1.0, "flicker_hz": 40.0}, "gain_db": -9.0},
                        {"voice": "&boing", "params": {"start_hz": 80.0, "end_hz": 30.0, "drop_s": 0.15, "decay_s": 0.4, "sub": 1.0, "click": 0.2}, "gain_db": -3.0}],
                fx=[{"type": "lowpass", "cutoff_hz": 2600.0}], transforms=[{"type": "varispeed", "from": 1.0, "to": 0.25}],
                bind=level(-6.0, 0.0), send=0.45, seed=621),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

names = {"open": "open", "pass.walk": "pass_walk", "pass.pipe": "pass_pipe", "pod": "pod", "mouth": "mouth", "mh.reveal": "mh_reveal",
         "mh.unfold": "mh_unfold", "stamp": "stamp", "stamp.small": "stamp_small", "whip": "whip", "bank": "bank", "lift": "lift",
         "lens": "lens", "hatch": "hatch", "ftf.rise": "ftf_rise", "ftf.lock": "ftf_lock", "crane": "crane", "city.sink": "city_sink",
         "ftf.sink": "ftf_sink", "hatch.shut": "hatch_shut", "cut": "cut"}
cue_map(os.path.join(D, "canyon_map.tres"), {k: R + v + ".tres" for k, v in names.items()},
        master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
        reverb={"room": 0.5, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -4.0}, end_fade_s=0.3)
with open(os.path.join(D, "canyon_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 7.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music (112.5 bpm, E minor)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=701,
       params={"tune_hz": 44.0, "punch": 4.5, "decay_s": 0.36, "click": 0.5, "drive": 0.5}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "clap.tres"), voice="clap", seed=702, send=0.4,
       params={"bursts": 3, "color_hz": 1300.0, "tail_decay_s": 0.16}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=703, send=0.3,
       params={"tone_hz": 200.0, "tone": 0.4, "noise": 0.9, "noise_hz": 5500.0, "noise_decay_s": 0.09},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-18.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=704, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.03, "tone_hz": 9500.0, "metal": 0.85}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "hiss.tres"), voice="static", seed=705, vary={"color_hz": 0.15}, vary_variants=4,
       params={"length_s": 0.09, "hiss": 1.0, "color_hz": 7000.0, "q": 0.8, "crackles_per_s": 0.0, "crackle": 0.0, "fade_s": 0.07},
       bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "clank.tres"), voice="fm", seed=706, send=0.35,
       params={"freq_hz": 329.6, "ratio": 1.41, "index": 7.0, "index_end": 0.6, "index_decay_s": 0.05, "decay_s": 0.18, "gate_s": 0.02, "release_s": 0.1},
       vary={"index": 0.15}, vary_variants=4, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "anvil.tres"), voice="mallet", seed=707, send=0.35,
       params={"freq_hz": 659.3, "material": "&metal", "hardness": 1.0, "decay_s": 0.25}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "bass.tres"), voice="wavetable", seed=708,
       params={"position": 0.8, "sub": 0.5, "cutoff_hz": 340.0, "env_octaves": 2.2, "filter_decay_s": 0.08, "q": 2.6,
               "attack_s": 0.002, "decay_s": 0.1, "sustain": 0.35, "release_s": 0.03},
       fx=[{"type": "drive", "amount": 0.45}], bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "arp.tres"), voice="fm", seed=709, send=0.35,
       params={"freq_hz": 329.6, "ratio": 2.0, "index": 3.0, "index_end": 0.4, "index_decay_s": 0.08, "decay_s": 0.16, "gate_s": 0.05, "release_s": 0.08},
       bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "stab.tres"), voice="fm", seed=710, send=0.5,
       params={"freq_hz": 329.6, "ratio": 3.5, "index": 5.0, "index_end": 0.6, "index_decay_s": 0.2, "decay_s": 0.5, "gate_s": 0.2, "release_s": 0.3},
       bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=711, send=0.6,
       params={"position": 0.5, "unison": 5, "detune_cents": 16.0, "cutoff_hz": 800.0, "env_octaves": 0.4, "filter_decay_s": 1.0,
               "q": 0.7, "attack_s": 0.6, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.4})

# rolling bass: E1 = 28; root on the beat, octave and fifth rolling under it
bass_roll = {"name": "bass", "recipe": M + "bass.tres", "steps": "Xxox" * 4, "length": 16,
             "notes": [28, 40, 35, 40, 28, 40, 38, 35, 28, 40, 35, 40, 31, 43, 38, 43], "gate": 0.6, "gain_db": -2.0}
bass_drop = {"name": "bass", "recipe": M + "bass.tres", "steps": "Xxox" * 8, "length": 32,
             "notes": [28, 40, 35, 40, 28, 40, 38, 35, 31, 43, 38, 43, 31, 43, 40, 38, 24, 36, 31, 36, 24, 36, 35, 31, 26, 38, 33, 38, 26, 38, 35, 33],
             "gate": 0.6, "gain_db": -1.0}
bass_half = {"name": "bass", "recipe": M + "bass.tres", "steps": "X.......x..x....", "length": 16, "notes": [28, 28, 40], "gate": 0.9, "gain_db": -3.0}
kick4 = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}
kick_half = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.........x.....", "length": 16, "gain_db": -1.0}
kick_bar = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...............", "length": 16, "gain_db": -2.0}
clap = {"name": "clap", "recipe": M + "clap.tres", "steps": "....X.......X...", "length": 16, "gain_db": -6.0}
clap3 = {"name": "clap", "recipe": M + "clap.tres", "steps": "........X.......", "length": 16, "gain_db": -6.0}
hat = {"name": "hat", "recipe": M + "hat.tres", "steps": "o.x.o.x.o.x.o.xo", "length": 16, "gain_db": -13.0, "pan": 0.2}
hiss = {"name": "hiss", "recipe": M + "hiss.tres", "steps": "..x...x...x...x.", "length": 16, "gain_db": -17.0, "pan": -0.3}
clank = {"name": "clank", "recipe": M + "clank.tres", "steps": "...x..x....x..x.", "length": 16, "gain_db": -15.0, "pan": -0.2}
anvil = {"name": "anvil", "recipe": M + "anvil.tres", "steps": "......x.......x.", "length": 16, "gain_db": -17.0, "pan": 0.3}
roll = {"name": "snare", "recipe": M + "snare.tres", "steps": "1234567891234589", "length": 16, "gain_db": -6.0}
arp = {"name": "arp", "recipe": M + "arp.tres", "steps": "x.xx.xx.x.xx.xx.", "length": 16,
       "notes": ["E5", "B4", "G4", "E5", "D5", "B4", "G4", "B4", "E5", "B4", "G4", "F#5", "D5", "B4"], "gate": 0.6, "gain_db": -16.0, "pan": 0.15}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "x.....x.........", "length": 16, "notes": ["E4", "D4"], "chord": [0, 3, 7], "gate": 1.0, "gain_db": -15.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 31, "length": 32, "notes": ["E3", "C3"], "chord": [0, 3, 7, 10], "gate": 31.0, "gain_db": -15.0}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name) + 11, "lanes": lanes}, typed={"lanes"})
pat("run", 16, [kick4, bass_roll, hiss, clank])
pat("plaza", 16, [kick_half, clap3, bass_half, stab, pad, anvil])
pat("canyon", 16, [kick4, bass_roll, hat, clank])
pat("lift", 16, [kick_bar, bass_roll, hiss, pad])
pat("roll", 16, [roll, bass_roll])
pat("drop", 32, [kick4, clap, hat, hiss, clank, anvil, bass_drop, arp, pad])
pat("outro", 16, [kick_bar, bass_half, hiss])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 112.5, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "canyon_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "run", "bars": 1.0, "patterns": [M + "run.tres"], "automation": {"bass.cutoff_hz": [[0.0, 260.0], [1.0, 520.0]]}},
        {"name": "plaza", "bars": 1.25, "patterns": [M + "plaza.tres"]},
        {"name": "canyon", "bars": 0.75, "patterns": [M + "canyon.tres"], "automation": {"bass.cutoff_hz": [[0.0, 400.0], [1.0, 700.0]]}},
        {"name": "lift", "bars": 0.75, "patterns": [M + "lift.tres"], "automation": {"bass.cutoff_hz": [[0.0, 220.0], [1.0, 1400.0]]}},
        {"name": "roll", "bars": 0.25, "patterns": [M + "roll.tres"], "automation": {"bass.cutoff_hz": [[0.0, 1400.0], [1.0, 2000.0]]}},
        {"name": "drop", "bars": 1.5, "patterns": [M + "drop.tres"],
         "automation": {"bass.cutoff_hz": [[0.0, 700.0], [0.5, 1100.0], [1.0, 800.0]], "arp.index": [[0.0, 2.0], [1.0, 4.5]]}},
        {"name": "outro", "bars": 0.75, "patterns": [M + "outro.tres"],
         "automation": {"bass.gain_db": [[0.0, 0.0], [1.0, -14.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -10.0]], "bass.cutoff_hz": [[0.0, 500.0], [1.0, 150.0]]}},
        {"name": "tail", "bars": 0.3125, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, canyon_map.tres and the 112.5 bpm song" % len(fx))
