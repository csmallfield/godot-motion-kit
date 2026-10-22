#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF Cables take (demo/ftf/ftf_cables/ftf_cables.gd): effect
recipes, the cue map and a 90 bpm half-time bed, for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/ftf_cables/audio/make.py

Sound sheet (shared reverb 0.4, a heavy room; music ducks 8 dB under the hits):
  snake        rubbery slither: brown-noise whoosh with a slow drag ratchet
  plug.in      heavy connector clunk: sub thump, metal bite, latch click (climbs)
  power.on     current arriving: saw glide up under a rising hiss
  taut         cable twang: low plucked string with a sprung thump
  presents     two-operator bell, low and wide
  pulse        a zap racing along a line: square blip diving fast
  plug.out     yank: popping sine, latch click, short whoosh
  power.down   sine dive into crackle
  wrap         a cable whipping round the plate: band whoosh plus rubber creak
  squeeze      slow creak of tightening cables over a low thump
  riser        noise and saw swelling for 1.3 s into the drop
  rip          the cocoon torn off: big whoosh with a zipper ratchet
  drop         eight plugs slamming home: driven kick, sub, metal clang, arc crackle
  surge        mains hum swelling with crackle
  fall         the plate falling: dark whoosh downward
  crash        it lands off frame: low boom, metal, crackle tail
Music: 90 bpm, 4/4, half-time (snare on beat 3), first downbeat at 0.0 s; a
beat is 20 frames, a bar 80.
  intro  bar 0       kick, mains hum, sparse hats (patch bay powers up)
  mh     bar 1       half-time groove, sub bass
  build  bar 2       16th hats and a rising bass filter (cocoon)
  drop   bars 3-4.2  full: groove, sub, metal stabs, open hats (logo hold)
  outro  bars 4.2-5  kick and sub closing down (plugs pulled)
  tail   bar 5-5.25  silence
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/ftf_cables/audio/"
M = "res://demo/ftf/ftf_cables/audio/music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

fx = {
    "snake": dict(voice="whoosh", params={"length_s": 0.75, "low_hz": 120.0, "high_hz": 1400.0, "peak": 0.55, "shape": 1.4, "noise": "&brown"},
                  layers=[{"voice": "&ratchet", "params": {"length_s": 0.7, "start_rate_hz": 9.0, "end_rate_hz": 16.0, "click_hz": 700.0, "q": 6.0, "fade": 0.4, "jitter": 0.3}, "gain_db": -10.0}],
                  bind=pitched(-14.0, -6.0), vary={"high_hz": 0.2}, vary_variants=3, send=0.25, seed=301),
    "plug_in": dict(voice="boing", params={"start_hz": 190.0, "end_hz": 55.0, "drop_s": 0.04, "decay_s": 0.22, "sub": 0.9, "click": 1.0, "click_hz": 4200.0},
                    layers=[{"voice": "&mallet", "params": {"freq_hz": 210.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.35}, "gain_db": -8.0},
                            {"voice": "&click", "params": {"freq_hz": 3200.0, "mode": "&band", "q": 6.0, "decay_s": 0.01, "body_hz": 120.0, "body": 0.6}, "gain_db": -4.0, "offset_s": 0.03}],
                    bind=pitched(-6.0, 0.0), send=0.3, seed=302),
    "power_on": dict(voice="tone", params={"wave": "&saw", "freq_hz": 70.0, "end_hz": 420.0, "glide_s": 0.18, "attack_s": 0.01, "decay_s": 0.4, "sustain": 0.0, "gate_s": 0.45, "length_s": 0.7},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 0.55, "low_hz": 400.0, "high_hz": 8000.0, "peak": 0.35, "noise": "&white"}, "gain_db": -9.0}],
                     fx=[{"type": "lowpass", "cutoff_hz": 3800.0, "slope_db": 12.0}, {"type": "drive", "amount": 0.3}],
                     bind=level(-10.0, -2.0), send=0.3, seed=303),
    "taut": dict(voice="pluck", params={"freq_hz": 82.4, "brightness": 0.85, "decay_s": 0.9, "tone_hz": 3000.0},
                 layers=[{"voice": "&boing", "params": {"start_hz": 140.0, "end_hz": 60.0, "drop_s": 0.06, "decay_s": 0.25, "wobble_hz": 9.0, "wobble_semitones": 2.0, "sub": 0.6, "click": 0.3}, "gain_db": -6.0}],
                 bind=pitched(-10.0, -2.0), send=0.3, seed=304),
    "presents": dict(voice="fm", params={"freq_hz": 174.6, "ratio": 3.5, "index": 4.0, "index_end": 0.6, "index_decay_s": 0.4, "decay_s": 1.4, "gate_s": 0.2, "release_s": 0.6},
                     layers=[{"voice": "&fm", "params": {"freq_hz": 261.6, "ratio": 2.0, "index": 2.0, "index_end": 0.3, "decay_s": 1.0, "gate_s": 0.15}, "gain_db": -7.0, "offset_s": 0.08}],
                     bind=level(-10.0, -3.0), send=0.5, seed=305),
    "pulse": dict(voice="tone", params={"wave": "&square", "freq_hz": 2400.0, "end_hz": 500.0, "glide_s": 0.05, "decay_s": 0.08, "gate_s": 0.08, "length_s": 0.16},
                  layers=[{"voice": "&click", "params": {"freq_hz": 6000.0, "mode": "&high", "decay_s": 0.004}, "gain_db": -10.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 5000.0}],
                  bind=pitched(-20.0, -11.0), send=0.25, seed=306),
    "plug_out": dict(voice="tone", params={"wave": "&sine", "freq_hz": 700.0, "end_hz": 180.0, "glide_s": 0.03, "decay_s": 0.08, "gate_s": 0.08, "length_s": 0.18},
                     layers=[{"voice": "&click", "params": {"freq_hz": 2600.0, "mode": "&band", "q": 5.0, "decay_s": 0.012, "body_hz": 90.0, "body": 0.5}, "gain_db": -3.0},
                             {"voice": "&whoosh", "params": {"length_s": 0.3, "low_hz": 300.0, "high_hz": 3000.0, "peak": 0.25, "noise": "&pink"}, "gain_db": -9.0}],
                     bind=pitched(-10.0, -3.0), send=0.25, seed=307),
    "power_down": dict(voice="tone", params={"wave": "&sine", "freq_hz": 420.0, "end_hz": 40.0, "glide_s": 0.25, "decay_s": 0.5, "gate_s": 0.5, "length_s": 0.7},
                       layers=[{"voice": "&static", "params": {"length_s": 0.5, "hiss": 0.2, "crackles_per_s": 90.0, "crackle": 0.8, "fade_s": 0.1}, "gain_db": -12.0}],
                       bind=level(-10.0, -3.0), send=0.35, seed=308),
    "wrap": dict(voice="whoosh", params={"length_s": 0.5, "low_hz": 250.0, "high_hz": 3200.0, "peak": 0.5, "mode": "&band", "q": 1.0, "noise": "&pink"},
                 layers=[{"voice": "&ratchet", "params": {"length_s": 0.45, "start_rate_hz": 14.0, "end_rate_hz": 30.0, "click_hz": 1100.0, "q": 9.0, "fade": 0.5, "jitter": 0.25}, "gain_db": -12.0, "offset_s": 0.1}],
                 bind=pitched(-16.0, -8.0), vary={"high_hz": 0.2}, vary_variants=3, send=0.3, seed=309),
    "squeeze": dict(voice="ratchet", params={"length_s": 0.9, "start_rate_hz": 26.0, "end_rate_hz": 7.0, "click_hz": 850.0, "q": 9.0, "fade": 0.3, "jitter": 0.3},
                    layers=[{"voice": "&boing", "params": {"start_hz": 110.0, "end_hz": 45.0, "drop_s": 0.08, "decay_s": 0.35, "sub": 0.9, "click": 0.2}, "gain_db": -4.0}],
                    bind=level(-10.0, -3.0), send=0.35, seed=310),
    "riser": dict(voice="tone", params={"wave": "&saw", "freq_hz": 55.0, "end_hz": 880.0, "glide_s": 0.7, "attack_s": 1.1, "decay_s": 0.3, "sustain": 1.0, "gate_s": 1.3, "release_s": 0.004, "length_s": 1.3},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 1.3, "low_hz": 200.0, "high_hz": 8000.0, "peak": 0.97, "shape": 3.2, "noise": "&pink"}, "gain_db": -3.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 6000.0, "slope_db": 12.0}],
                  bind=level(-14.0, -6.0), send=0.15, offset_s=-1.3, seed=311),
    "rip": dict(voice="whoosh", params={"length_s": 0.45, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.45, "shape": 1.6, "noise": "&white"},
                layers=[{"voice": "&ratchet", "params": {"length_s": 0.35, "start_rate_hz": 90.0, "end_rate_hz": 160.0, "click_hz": 3600.0, "q": 4.0, "fade": 0.3}, "gain_db": -8.0}],
                bind=level(-10.0, -2.0), send=0.25, seed=312),
    "drop": dict(voice="kick", params={"tune_hz": 42.0, "punch": 5.0, "drop_s": 0.05, "decay_s": 0.7, "click": 0.8, "drive": 0.55},
                 layers=[{"voice": "&boing", "params": {"start_hz": 150.0, "end_hz": 36.0, "drop_s": 0.16, "decay_s": 0.6, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&mallet", "params": {"freq_hz": 160.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.8}, "gain_db": -8.0},
                         {"voice": "&static", "params": {"length_s": 0.35, "hiss": 0.4, "color_hz": 4000.0, "crackles_per_s": 600.0, "crackle": 1.0, "fade_s": 0.05}, "gain_db": -10.0}],
                 bind=level(-4.0, 0.0), send=0.35, seed=313),
    "surge": dict(voice="tone", params={"wave": "&saw", "freq_hz": 55.0, "attack_s": 0.25, "decay_s": 0.3, "sustain": 0.6, "gate_s": 0.45, "release_s": 0.15, "length_s": 0.8},
                  layers=[{"voice": "&static", "params": {"length_s": 0.7, "hiss": 0.15, "crackles_per_s": 200.0, "crackle": 0.7, "flicker_hz": 12.0, "fade_s": 0.1}, "gain_db": -10.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 1600.0}],
                  bind=level(-12.0, -4.0), send=0.3, seed=314),
    "fall": dict(voice="whoosh", params={"length_s": 0.7, "low_hz": 110.0, "high_hz": 1300.0, "peak": 0.12, "shape": 1.3, "noise": "&brown"},
                 bind=level(-12.0, -4.0), send=0.3, seed=315),
    "crash": dict(voice="boing", params={"start_hz": 120.0, "end_hz": 32.0, "drop_s": 0.12, "decay_s": 0.7, "sub": 1.0, "click": 0.6},
                  layers=[{"voice": "&mallet", "params": {"freq_hz": 110.0, "material": "&metal", "hardness": 0.9, "decay_s": 0.9}, "gain_db": -8.0},
                          {"voice": "&snare", "params": {"tone_hz": 120.0, "tone": 0.3, "noise": 1.0, "noise_hz": 3000.0, "noise_decay_s": 0.4}, "gain_db": -8.0},
                          {"voice": "&static", "params": {"length_s": 0.9, "hiss": 0.1, "crackles_per_s": 60.0, "crackle": 0.8, "fade_s": 0.4}, "gain_db": -14.0, "offset_s": 0.1}],
                  fx=[{"type": "lowpass", "cutoff_hz": 2800.0}],
                  bind=level(-6.0, -1.0), send=0.5, seed=316),
}
for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "cables_map.tres"), {
    "snake": R + "snake.tres", "plug.in": R + "plug_in.tres", "power.on": R + "power_on.tres", "taut": R + "taut.tres",
    "presents": R + "presents.tres", "pulse": R + "pulse.tres", "plug.out": R + "plug_out.tres", "power.down": R + "power_down.tres",
    "wrap": R + "wrap.tres", "squeeze": R + "squeeze.tres", "riser": R + "riser.tres", "rip": R + "rip.tres",
    "drop": R + "drop.tres", "surge": R + "surge.tres", "fall": R + "fall.tres", "crash": R + "crash.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.6, "damp": 0.45, "width": 1.0, "quality": "&full", "return_db": -3.0}, end_fade_s=0.4)
with open(os.path.join(D, "cables_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 8.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.3}\n')

# ------------------------------------------------------------------ music (90 bpm half-time)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=401,
       params={"tune_hz": 46.0, "punch": 4.0, "decay_s": 0.42, "click": 0.5, "drive": 0.45}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=402, send=0.35,
       params={"tone_hz": 170.0, "tone": 0.6, "noise": 0.9, "noise_hz": 4200.0, "noise_decay_s": 0.24},
       fx=[{"type": "drive", "amount": 0.25}], vary={"noise_hz": 0.1}, vary_variants=3, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=403, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.028, "tone_hz": 8800.0, "metal": 0.7}, bind=level(-12.0, 0.0))
recipe(os.path.join(MD, "ohat.tres"), voice="hat", seed=404, params={"decay_s": 0.3, "tone_hz": 7800.0, "metal": 0.8}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "sub.tres"), voice="wavetable", seed=405,
       params={"position": 0.18, "sub": 0.6, "cutoff_hz": 260.0, "env_octaves": 2.0, "filter_decay_s": 0.2, "q": 1.4,
               "attack_s": 0.004, "decay_s": 0.3, "sustain": 0.7, "release_s": 0.08},
       fx=[{"type": "drive", "amount": 0.3}], bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "hum.tres"), voice="wavetable", seed=406, send=0.3,
       params={"position": 0.7, "unison": 3, "detune_cents": 8.0, "cutoff_hz": 380.0, "env_octaves": 0.3, "filter_decay_s": 1.0,
               "q": 1.0, "attack_s": 0.6, "decay_s": 1.0, "sustain": 0.8, "release_s": 0.4})
recipe(os.path.join(MD, "stab.tres"), voice="fm", seed=407, send=0.4,
       params={"ratio": 1.41, "index": 5.0, "index_end": 0.4, "index_decay_s": 0.12, "decay_s": 0.3, "gate_s": 0.12, "release_s": 0.15},
       bind=level(-10.0, 0.0))

# F minor. One bar = 16 steps (4 per beat); half-time: kick on 1, snare on 3.
kick_ht = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.........x.....", "length": 16}
kick_soft = {"name": "kick", "recipe": M + "kick.tres", "steps": "o.......o.......", "length": 16, "gain_db": -4.0}
snare_ht = {"name": "snare", "recipe": M + "snare.tres", "steps": "........X......o", "length": 16, "gain_db": -2.0}
hat_ht = {"name": "hat", "recipe": M + "hat.tres", "steps": "x.o.x.o.x.o.x.oo", "length": 16, "gain_db": -12.0, "pan": 0.15}
hat_sparse = {"name": "hat", "recipe": M + "hat.tres", "steps": "....o.......o...", "length": 16, "gain_db": -14.0, "pan": 0.15}
hat_16 = {"name": "hat", "recipe": M + "hat.tres", "steps": "xoxoxoxoxoxoxxxx", "length": 16, "gain_db": -12.0, "pan": 0.15}
ohat = {"name": "ohat", "recipe": M + "ohat.tres", "steps": "......x.......x.", "length": 16, "gain_db": -15.0, "pan": -0.2}
sub = {"name": "sub", "recipe": M + "sub.tres", "steps": "X.....x...x.....", "length": 16, "notes": ["F1", "F1", "Ab1"], "gate": 0.9, "gain_db": -2.0}
sub_drop = {"name": "sub", "recipe": M + "sub.tres", "steps": "X.....x...x...x.", "length": 16, "notes": ["F1", "F1", "Ab1", "C2"], "gate": 0.9, "gain_db": -2.0}
hum = {"name": "hum", "recipe": M + "hum.tres", "steps": "x" + "." * 15, "length": 16, "notes": ["F2"], "chord": [0, 7], "gate": 15.0, "gain_db": -14.0}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "...x......x..x..", "length": 16, "notes": ["F3", "Ab3", "C4"], "gate": 1.0, "gain_db": -11.0}

P = "AKPattern"
pat = lambda name, lanes, swing=0.54: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                                {"steps": 16, "seed": len(name), "swing": swing, "lanes": lanes}, typed={"lanes"})
pat("intro", [kick_soft, hum, hat_sparse])
pat("mh", [kick_ht, snare_ht, hat_ht, sub, hum])
pat("build", [kick_ht, snare_ht, hat_16, sub, hum])
pat("drop", [kick_ht, snare_ht, hat_ht, ohat, sub_drop, stab, hum])
pat("outro", [kick_ht, sub, hat_sparse])
pat("silence", [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 90.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "cables_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 1.0, "patterns": [M + "intro.tres"]},
        {"name": "mh", "bars": 1.0, "patterns": [M + "mh.tres"]},
        {"name": "build", "bars": 0.9, "patterns": [M + "build.tres"],
         "automation": {"sub.cutoff_hz": [[0.0, 200.0], [1.0, 900.0]], "hat.gain_db": [[0.0, -6.0], [1.0, 0.0]]}},
        {"name": "gap", "bars": 0.1, "patterns": [M + "silence.tres"]},
        {"name": "drop", "bars": 1.2, "patterns": [M + "drop.tres"],
         "automation": {"sub.cutoff_hz": [[0.0, 500.0], [1.0, 320.0]]}},
        {"name": "outro", "bars": 0.8, "patterns": [M + "outro.tres"],
         "automation": {"sub.cutoff_hz": [[0.0, 300.0], [1.0, 120.0]], "sub.gain_db": [[0.0, 0.0], [1.0, -12.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -9.0]]}},
        {"name": "tail", "bars": 0.25, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, cables_map.tres and the 90 bpm song" % len(fx))
