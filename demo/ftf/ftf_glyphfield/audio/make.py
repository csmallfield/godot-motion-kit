#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Glyph Field take (demo/ftf/ftf_glyphfield): effect
recipes, the cue map and a 90 bpm half-time song for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_glyphfield/audio/make.py

Sound sheet (dry, digital, a small dark room; music ducks 8 dB under the hits):
  field.in    crushed static fading up with the field
  scan        granular ticks accelerating with a sine sweep down: the scan band
  resolve     an FM bell fifth as MH resolves
  type        pitched data ticks, one per PRESENTS letter
  shock       sub drop with a metallic FM hit: MH condenses
  decay       crackling static bending down: a logo breaks back into glyphs
  storm       1.2 s of crushed static and an accelerating ratchet, cut dead
  cut         a single tape-stop thunk into silence
  zoom        heavy half-time hits, kick + sub + crushed slap, climbing
  suck        a reversed swell peaking on the drop
  drop        the big one: deep kick, long sub, metal, noise
  type.run    a fast fine ratchet as the katakana types
  scan.small  a short airy band sweep
  pulse       a soft sub blip on the hold's half-time pulses
  glitch      a crushed blip
  fall        a ratchet slowing down with a falling sine: the columns drop
  cursor      a square-wave cursor beep
  blip        the last FM ping with a sub under it
Music: 90 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 80 frames.
  intro  bars 0-1.5     pad, sparse ticks, sub pulse (MH)
  storm  bars 1.5-1.95  dense ticks only (the storm cue carries it)
  gap    to bar 2       silence (the cut)
  build  bars 2-2.95    sub notes on the zoom steps, ticks
  gap    to bar 3       silence before the drop
  drop   bars 3-4       half-time beat: kick, snare on 3, granular ticks, sub, data plinks
  outro  bars 4-4.75    kick on one, ticks thinning, sub fading
  tail   to 5.25        silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_glyphfield/audio/"
M = R + "music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "field_in": dict(voice="static", params={"length_s": 0.7, "hiss": 0.5, "color_hz": 5000.0, "q": 0.6, "crackles_per_s": 300.0, "crackle": 0.6, "fade_s": 0.3},
                     fx=[{"type": "bitcrush", "bits": 7.0}, {"type": "highpass", "cutoff_hz": 1500.0}], bind=level(-24.0, -14.0), seed=501),
    "scan": dict(voice="ratchet", params={"length_s": 0.67, "start_rate_hz": 14.0, "end_rate_hz": 70.0, "click_hz": 7500.0, "q": 6.0, "fade": 0.0, "jitter": 0.05},
                 layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 3200.0, "end_hz": 380.0, "glide_s": 0.25, "attack_s": 0.01, "decay_s": 0.5, "sustain": 0.4, "gate_s": 0.6, "length_s": 0.7}, "gain_db": -12.0}],
                 bind=level(-16.0, -8.0), seed=502),
    "resolve": dict(voice="fm", params={"freq_hz": 659.25, "ratio": 3.5, "index": 4.0, "index_end": 0.3, "index_decay_s": 0.25, "decay_s": 1.2, "gate_s": 0.4},
                    layers=[{"voice": "&fm", "params": {"freq_hz": 987.77, "ratio": 3.5, "index": 3.0, "index_end": 0.2, "index_decay_s": 0.2, "decay_s": 1.0, "gate_s": 0.3}, "gain_db": -5.0}],
                    bind=level(-12.0, -5.0), send=0.4, seed=503),
    "type": dict(voice="tone", params={"wave": "&square", "freq_hz": 1046.5, "decay_s": 0.03, "gate_s": 0.03, "length_s": 0.07},
                 layers=[{"voice": "&click", "params": {"freq_hz": 4500.0, "mode": "&band", "q": 4.0, "decay_s": 0.002}, "gain_db": -4.0}],
                 fx=[{"type": "bitcrush", "bits": 6.0}, {"type": "lowpass", "cutoff_hz": 7000.0}], bind=pitched(-20.0, -12.0), seed=504),
    "shock": dict(voice="boing", params={"start_hz": 140.0, "end_hz": 38.0, "drop_s": 0.12, "decay_s": 0.5, "sub": 1.0, "click": 0.6},
                  layers=[{"voice": "&fm", "params": {"freq_hz": 196.0, "ratio": 1.41, "index": 6.0, "index_end": 0.5, "index_decay_s": 0.15, "decay_s": 0.6, "gate_s": 0.2}, "gain_db": -8.0},
                          {"voice": "&whoosh", "params": {"length_s": 0.5, "low_hz": 200.0, "high_hz": 4000.0, "peak": 0.05}, "gain_db": -10.0}],
                  bind=level(-6.0, 0.0), send=0.3, seed=505),
    "decay": dict(voice="static", params={"length_s": 0.5, "hiss": 0.4, "color_hz": 2500.0, "q": 0.8, "crackles_per_s": 1600.0, "crackle": 1.0, "fade_s": 0.02},
                  fx=[{"type": "bitcrush", "bits": 5.0}], transforms=[{"type": "varispeed", "from": 1.0, "to": 0.4}], bind=level(-14.0, -6.0), seed=506),
    "storm": dict(voice="static", params={"length_s": 1.2, "hiss": 0.9, "color_hz": 3500.0, "q": 0.5, "crackles_per_s": 2400.0, "crackle": 1.0, "flicker_hz": 30.0, "flicker_depth": 0.7, "fade_s": 0.003},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 1.2, "start_rate_hz": 12.0, "end_rate_hz": 120.0, "click_hz": 3000.0, "q": 3.0, "fade": 0.0}, "gain_db": -2.0},
                          {"voice": "&whoosh", "params": {"length_s": 1.2, "low_hz": 400.0, "high_hz": 9000.0, "peak": 0.97, "shape": 2.5, "noise": "&pink"}, "gain_db": -6.0}],
                  fx=[{"type": "bitcrush", "bits": 5.0}], bind=level(-12.0, -4.0), seed=507),
    "cut": dict(voice="boing", params={"start_hz": 300.0, "end_hz": 40.0, "drop_s": 0.04, "decay_s": 0.08, "sub": 0.5, "click": 0.9, "click_hz": 3000.0},
                bind=level(-12.0, -4.0), seed=508),
    "zoom": dict(voice="kick", params={"tune_hz": 45.0, "punch": 4.0, "drop_s": 0.04, "decay_s": 0.45, "click": 0.6, "drive": 0.45},
                 layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 41.0, "drop_s": 0.1, "decay_s": 0.4, "sub": 1.0, "click": 0.0}, "gain_db": -5.0},
                         {"voice": "&static", "params": {"length_s": 0.08, "hiss": 1.0, "color_hz": 3000.0, "crackles_per_s": 3000.0, "crackle": 1.0, "fade_s": 0.003}, "gain_db": -8.0}],
                 fx=[{"type": "bitcrush", "bits": 9.0}], bind=pitched(-6.0, 0.0), send=0.2, seed=509),
    "suck": dict(voice="whoosh", params={"length_s": 0.8, "low_hz": 300.0, "high_hz": 8000.0, "peak": 0.15, "shape": 2.0, "noise": "&pink"},
                 transforms=[{"type": "reverse"}], offset_s=-0.8, bind=level(-14.0, -6.0), seed=510),
    "drop": dict(voice="kick", params={"tune_hz": 40.0, "punch": 5.0, "drop_s": 0.05, "decay_s": 0.8, "click": 0.8, "drive": 0.55},
                 layers=[{"voice": "&boing", "params": {"start_hz": 90.0, "end_hz": 33.0, "drop_s": 0.25, "decay_s": 0.9, "sub": 1.0, "click": 0.0}, "gain_db": -3.0},
                         {"voice": "&fm", "params": {"freq_hz": 146.8, "ratio": 1.41, "index": 8.0, "index_end": 0.4, "index_decay_s": 0.2, "decay_s": 0.9, "gate_s": 0.3}, "gain_db": -9.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.5, "low_hz": 500.0, "high_hz": 10000.0, "peak": 0.04, "shape": 2.5}, "gain_db": -8.0}],
                 bind=level(-3.0, 0.0), send=0.3, seed=511),
    "type_run": dict(voice="ratchet", params={"length_s": 0.87, "start_rate_hz": 30.0, "end_rate_hz": 30.0, "click_hz": 6500.0, "q": 7.0, "fade": 0.3, "accent_every": 2.0},
                     bind=level(-22.0, -13.0), seed=512),
    "scan_small": dict(voice="whoosh", params={"length_s": 0.47, "low_hz": 1500.0, "high_hz": 9000.0, "peak": 0.5, "mode": "&band", "q": 1.4},
                       bind=level(-20.0, -12.0), send=0.2, seed=513),
    "pulse": dict(voice="boing", params={"start_hz": 90.0, "end_hz": 48.0, "drop_s": 0.06, "decay_s": 0.18, "sub": 0.8, "click": 0.2},
                  bind=level(-16.0, -9.0), seed=514),
    "glitch": dict(voice="static", params={"length_s": 0.13, "hiss": 0.8, "color_hz": 4000.0, "crackles_per_s": 1200.0, "crackle": 1.0, "flicker_hz": 50.0, "fade_s": 0.003},
                   layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 1600.0, "end_hz": 200.0, "glide_s": 0.03, "decay_s": 0.06, "gate_s": 0.08, "length_s": 0.12}, "gain_db": -6.0}],
                   fx=[{"type": "bitcrush", "bits": 5.0}], bind=level(-14.0, -5.0), seed=515),
    "fall": dict(voice="ratchet", params={"length_s": 1.4, "start_rate_hz": 40.0, "end_rate_hz": 6.0, "click_hz": 2500.0, "q": 4.0, "fade": 0.7, "jitter": 0.2},
                 layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 900.0, "end_hz": 50.0, "glide_s": 0.5, "attack_s": 0.01, "decay_s": 1.0, "sustain": 0.3, "gate_s": 1.0, "length_s": 1.4}, "gain_db": -10.0}],
                 bind=level(-14.0, -6.0), send=0.25, seed=516),
    "cursor": dict(voice="tone", params={"wave": "&square", "freq_hz": 987.77, "decay_s": 0.08, "gate_s": 0.12, "sustain": 0.3, "length_s": 0.18},
                   fx=[{"type": "lowpass", "cutoff_hz": 4000.0}], bind=pitched(-18.0, -10.0), send=0.2, seed=517),
    "blip": dict(voice="fm", params={"freq_hz": 1318.5, "ratio": 2.0, "index": 3.0, "index_end": 0.1, "index_decay_s": 0.15, "decay_s": 0.8, "gate_s": 0.1},
                 layers=[{"voice": "&boing", "params": {"start_hz": 100.0, "end_hz": 45.0, "drop_s": 0.1, "decay_s": 0.3, "sub": 0.9, "click": 0.0}, "gain_db": -6.0}],
                 bind=level(-8.0, -2.0), send=0.45, seed=518),
}

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "gf_map.tres"), {
    "field.in": R + "field_in.tres", "scan": R + "scan.tres", "resolve": R + "resolve.tres", "type": R + "type.tres",
    "shock": R + "shock.tres", "decay": R + "decay.tres", "storm": R + "storm.tres", "cut": R + "cut.tres",
    "zoom": R + "zoom.tres", "suck": R + "suck.tres", "drop": R + "drop.tres", "type.run": R + "type_run.tres",
    "scan.small": R + "scan_small.tres", "pulse": R + "pulse.tres", "glitch": R + "glitch.tres", "fall": R + "fall.tres",
    "cursor": R + "cursor.tres", "blip": R + "blip.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.3, "damp": 0.6, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.4)
with open(os.path.join(D, "gf_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 8.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music (90 bpm, half-time)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=601,
       params={"tune_hz": 44.0, "punch": 4.0, "decay_s": 0.42, "click": 0.5, "drive": 0.4}, bind=level(-7.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=602, send=0.35,
       params={"tone_hz": 180.0, "tone": 0.45, "noise": 0.9, "noise_hz": 4500.0, "noise_decay_s": 0.22},
       fx=[{"type": "bitcrush", "bits": 10.0}], bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "tick.tres"), voice="click", seed=603, vary={"freq_hz": 0.2, "decay_s": 0.3}, vary_variants=4,
       params={"freq_hz": 8000.0, "mode": "&band", "q": 6.0, "decay_s": 0.004}, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "grain.tres"), voice="click", seed=604, vary={"freq_hz": 0.35}, vary_variants=4,
       params={"freq_hz": 3500.0, "mode": "&band", "q": 10.0, "decay_s": 0.012}, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "sub.tres"), voice="wavetable", seed=605,
       params={"position": 0.25, "sub": 0.8, "cutoff_hz": 260.0, "env_octaves": 1.5, "filter_decay_s": 0.2, "q": 1.4,
               "attack_s": 0.004, "decay_s": 0.5, "sustain": 0.5, "release_s": 0.08},
       fx=[{"type": "drive", "amount": 0.25}], bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "plink.tres"), voice="fm", seed=606, send=0.4,
       params={"ratio": 3.5, "index": 3.0, "index_end": 0.2, "index_decay_s": 0.08, "decay_s": 0.25, "gate_s": 0.05}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=607, send=0.5,
       params={"position": 0.45, "unison": 5, "detune_cents": 14.0, "cutoff_hz": 800.0, "env_octaves": 0.4, "filter_decay_s": 1.5,
               "q": 0.8, "attack_s": 0.6, "decay_s": 1.0, "sustain": 0.7, "release_s": 0.4})

# D minor. 16 steps a bar, a sixteenth = 5 frames.
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 31, "length": 32, "notes": ["D3"], "chord": [0, 7, 10, 15], "gate": 31.0, "gain_db": -11.0}
ticks_sparse = {"name": "tick", "recipe": M + "tick.tres", "steps": "o..o..o.o..o..o.", "length": 16, "gain_db": -14.0, "pan": 0.2}
sub_pulse = {"name": "sub", "recipe": M + "sub.tres", "steps": "x" + "." * 15, "length": 16, "notes": ["D1"], "gate": 6.0, "gain_db": -6.0}
ticks_storm = {"name": "tick", "recipe": M + "tick.tres", "steps": "XxoxXxoxXxoxXxox", "length": 16, "gain_db": -9.0}
grain = {"name": "grain", "recipe": M + "grain.tres", "steps": "x?x?x?x?x?x?x?x?", "length": 16, "gain_db": -16.0, "pan": -0.25}
sub_steps = {"name": "sub", "recipe": M + "sub.tres", "steps": "x...x...x...x...", "length": 16, "notes": ["D1", "F1", "G1", "A1"], "gate": 3.5, "gain_db": -5.0}
ticks_beat = {"name": "tick", "recipe": M + "tick.tres", "steps": "x.o.x.oox.o.x.oo", "length": 16, "gain_db": -12.0, "pan": 0.2}
kick_ht = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.........x.....", "length": 16}
snare_ht = {"name": "snare", "recipe": M + "snare.tres", "steps": "........X.......", "length": 16, "gain_db": -2.0}
sub_ht = {"name": "sub", "recipe": M + "sub.tres", "steps": "x.........x...x.", "length": 16, "notes": ["D1", "D1", "F1"], "gate": 2.5, "gain_db": -4.0}
plink = {"name": "plink", "recipe": M + "plink.tres", "steps": "..x?..?x..x?.?..", "length": 16, "notes": ["D5", "A5", "F5", "C6", "A5"], "gain_db": -15.0, "pan": 0.3, "probability": 0.8}
kick_one = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...............", "length": 16}
ticks_thin = {"name": "tick", "recipe": M + "tick.tres", "steps": "x...o...x...o.?.", "length": 16, "gain_db": -14.0}

P = "AKPattern"
pat = lambda name, steps, lanes: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                          {"steps": steps, "seed": len(name) + 40, "humanize_ms": 3.0, "lanes": lanes}, typed={"lanes"})
pat("intro", 32, [pad, ticks_sparse, sub_pulse])
pat("storm", 16, [ticks_storm, grain])
pat("build", 16, [sub_steps, ticks_beat, grain])
pat("drop", 16, [kick_ht, snare_ht, ticks_beat, grain, sub_ht, plink, pad])
pat("outro", 16, [kick_one, ticks_thin, sub_pulse, pad])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 90.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "gf_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.5, "patterns": [M + "intro.tres"]},
        {"name": "storm", "bars": 0.45, "patterns": [M + "storm.tres"], "automation": {"tick.gain_db": [[0.0, -8.0], [1.0, 0.0]]}},
        {"name": "gap1", "bars": 0.05, "patterns": [M + "silence.tres"]},
        {"name": "build", "bars": 0.95, "patterns": [M + "build.tres"], "automation": {"sub.cutoff_hz": [[0.0, 200.0], [1.0, 700.0]]}},
        {"name": "gap2", "bars": 0.05, "patterns": [M + "silence.tres"]},
        {"name": "drop", "bars": 1.0, "patterns": [M + "drop.tres"]},
        {"name": "outro", "bars": 0.75, "patterns": [M + "outro.tres"],
         "automation": {"sub.gain_db": [[0.0, 0.0], [1.0, -14.0]], "pad.gain_db": [[0.0, 0.0], [1.0, -10.0]], "tick.gain_db": [[0.0, 0.0], [1.0, -10.0]]}},
        {"name": "tail", "bars": 0.5, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, gf_map.tres and the 90 bpm song" % len(fx))
