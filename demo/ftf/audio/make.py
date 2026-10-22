#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Sound for the FTF intro (demo/ftf/ftf_intro.gd): effect recipes, the cue map
and a 150 bpm breakbeat bed, written for the Godot Audio Kit.
Needs the audio kit linked (tools/link_audio_kit.sh). Regenerate:
    python3 demo/ftf/audio/make.py

Sound sheet (shared reverb 0.35; music ducks 7 dB under the hits):
  boot.rule    dry ratchet ticking along the boot rule
  mh.layer     warm sprung thumps, one per M layer, climbing (pitch in cue data)
  mh.letters   a ratchet zip running up as the wordmark pops
  mh.disc      round sine pops gliding up, one per disc
  mh.presents  a glassy two-note mallet chime under PRESENTS
  glitch       bitcrushed static burst with a falling square blip
  glitch.tear  long crushed static, tape-stopping down: MH tears apart
  sweep        big pink-noise whoosh peaking as the stripe bundle lands
  panel        punchy thump + snare crack per livery, climbing
  wall         short downward glide as K45 shrinks into the wall
  tile         metal mallet notes, pentatonic, one per tile
  iris         rising whoosh into the pink iris
  riser        saw glide and noise swelling for 1.2 s, cut dead on the gap
  drop         heavy driven kick, sub boing and a noise slap: the logo slam
  letters      a clattering ratchet as "Full Throttle" drops
  tab          short band whoosh as the tab slides in
  flux         metal clang: FLUX's halves smash together
  check        bright square blips climbing an arpeggio (checker squares)
  type         fast fine ratchet as the small type writes
  hud          triangle blips, one per HUD pop, climbing
  hud.out      reversed blips as the HUD leaves
  collapse     sine dive with a dark whoosh as the logo flattens
  zip          a fast high whoosh as the line shrinks to a dot
  blip         a final glass ping with a soft sub under it
Music: 150 bpm, 4/4, first downbeat at 0.0 s (frame 0); a bar is 48 frames.
  intro  bars 0-2      pad, soft kick, hats (Minimal Humans)
  build  bars 2-3.875  breakbeat in, acid bass opening up (liveries)
  gap    half a beat   silence before the drop
  drop   bars 4-7      full break, acid bass, offbeat stabs (logo + HUD hold)
  outro  bar 7         kick and hats, bass closing down (logo collapses)
  tail   bars 8-8.75   silence; the final blip rings out
"""
import os, sys

D = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.normpath(os.path.join(D, "../../.."))
AK = os.path.realpath(os.path.join(ROOT, "addons/audio_kit"))
sys.path.insert(0, os.path.join(AK, "../../tools"))
from write_recipes import recipe, cue_map, resource  # noqa: E402

R = "res://demo/ftf/audio/"
M = "res://demo/ftf/audio/music/"
MD = os.path.join(D, "music")
S = "res://addons/audio_kit/sequencer/"
level = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}}
pitched = lambda lo, hi: {"intensity": {"gain_db": [lo, hi]}, "data.pitch": "pitch_scale"}

# ------------------------------------------------------------------ effects
fx = {
    "boot_rule": dict(voice="ratchet", params={"length_s": 0.42, "start_rate_hz": 44.0, "end_rate_hz": 24.0, "click_hz": 6000.0, "q": 5.0, "fade": 0.6},
                      bind=level(-22.0, -12.0), seed=101),
    "mh_layer": dict(voice="boing", params={"start_hz": 300.0, "end_hz": 92.0, "drop_s": 0.05, "decay_s": 0.2, "wobble_hz": 6.0, "wobble_semitones": 2.0,
                     "sub": 0.5, "click": 0.3}, bind=pitched(-10.0, -2.0), send=0.2, seed=102),
    "mh_letters": dict(voice="ratchet", params={"length_s": 0.62, "start_rate_hz": 18.0, "end_rate_hz": 64.0, "click_hz": 3500.0, "q": 4.0, "fade": 0.1, "accent_every": 3.0},
                       bind=level(-18.0, -9.0), seed=103),
    "mh_disc": dict(voice="tone", params={"wave": "&sine", "freq_hz": 380.0, "end_hz": 900.0, "glide_s": 0.03, "decay_s": 0.09, "gate_s": 0.1, "length_s": 0.16},
                    layers=[{"voice": "&click", "params": {"freq_hz": 2500.0, "mode": "&band", "q": 2.0, "decay_s": 0.003}, "gain_db": -10.0}],
                    bind=pitched(-16.0, -6.0), send=0.25, seed=104),
    "mh_presents": dict(voice="mallet", params={"freq_hz": 659.25, "material": "&glass", "hardness": 0.5, "decay_s": 0.7},
                        layers=[{"voice": "&mallet", "params": {"freq_hz": 987.77, "material": "&glass", "hardness": 0.4, "decay_s": 0.6}, "gain_db": -5.0, "offset_s": 0.05}],
                        bind=level(-12.0, -4.0), send=0.45, seed=105),
    "glitch": dict(voice="static", params={"length_s": 0.12, "hiss": 0.8, "color_hz": 3200.0, "q": 0.8, "crackles_per_s": 900.0, "crackle": 0.9, "flicker_hz": 45.0, "fade_s": 0.003},
                   layers=[{"voice": "&tone", "params": {"wave": "&square", "freq_hz": 1250.0, "end_hz": 320.0, "glide_s": 0.04, "decay_s": 0.06, "gate_s": 0.08, "length_s": 0.12}, "gain_db": -9.0}],
                   fx=[{"type": "bitcrush", "bits": 6.0}],
                   bind=pitched(-14.0, -3.0), vary={"color_hz": 0.25}, vary_variants=4, seed=106),
    "glitch_tear": dict(voice="static", params={"length_s": 0.5, "hiss": 0.9, "color_hz": 2400.0, "q": 0.7, "crackles_per_s": 1400.0, "crackle": 1.0, "flicker_hz": 30.0, "fade_s": 0.01},
                        layers=[{"voice": "&boing", "params": {"start_hz": 900.0, "end_hz": 60.0, "drop_s": 0.12, "decay_s": 0.25, "sub": 0.4, "click": 0.8}, "gain_db": -4.0}],
                        fx=[{"type": "bitcrush", "bits": 5.0}],
                        transforms=[{"type": "varispeed", "from": 1.0, "to": 0.35}],
                        bind=level(-8.0, -1.0), seed=107),
    "sweep": dict(voice="whoosh", params={"length_s": 0.6, "low_hz": 200.0, "high_hz": 7500.0, "peak": 0.6, "shape": 1.8, "noise": "&pink"},
                  bind=level(-10.0, -1.0), send=0.3, seed=108),
    "panel": dict(voice="boing", params={"start_hz": 220.0, "end_hz": 58.0, "drop_s": 0.04, "decay_s": 0.22, "sub": 0.8, "click": 0.6},
                  layers=[{"voice": "&snare", "params": {"tone_hz": 210.0, "tone": 0.4, "noise": 0.8, "noise_hz": 6000.0, "noise_decay_s": 0.12}, "gain_db": -5.0}],
                  bind=pitched(-8.0, 0.0), send=0.25, seed=109),
    "wall": dict(voice="tone", params={"wave": "&triangle", "freq_hz": 900.0, "end_hz": 300.0, "glide_s": 0.08, "decay_s": 0.25, "gate_s": 0.25, "length_s": 0.35},
                 layers=[{"voice": "&whoosh", "params": {"length_s": 0.3, "low_hz": 300.0, "high_hz": 3000.0, "peak": 0.3}, "gain_db": -8.0}],
                 bind=level(-14.0, -6.0), send=0.3, seed=110),
    "tile": dict(voice="mallet", params={"freq_hz": 659.25, "material": "&metal", "hardness": 0.7, "decay_s": 0.25},
                 bind=pitched(-16.0, -7.0), send=0.3, seed=111),
    "iris": dict(voice="whoosh", params={"length_s": 0.22, "low_hz": 600.0, "high_hz": 9000.0, "peak": 0.8, "shape": 2.0},
                 bind=level(-14.0, -6.0), send=0.2, seed=112),
    "riser": dict(voice="tone", params={"wave": "&saw", "freq_hz": 140.0, "end_hz": 1700.0, "glide_s": 0.6, "attack_s": 0.9, "decay_s": 0.3, "sustain": 1.0, "gate_s": 1.2, "release_s": 0.004, "length_s": 1.2},
                  layers=[{"voice": "&whoosh", "params": {"length_s": 1.2, "low_hz": 300.0, "high_hz": 9000.0, "peak": 0.97, "shape": 3.0, "noise": "&pink"}, "gain_db": -2.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 7000.0, "slope_db": 12.0}],
                  bind=level(-14.0, -6.0), send=0.15, offset_s=-1.2, seed=113),
    "drop": dict(voice="kick", params={"tune_hz": 44.0, "punch": 5.0, "drop_s": 0.04, "decay_s": 0.6, "click": 0.7, "drive": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 160.0, "end_hz": 38.0, "drop_s": 0.15, "decay_s": 0.5, "sub": 1.0, "click": 0.0}, "gain_db": -4.0},
                         {"voice": "&whoosh", "params": {"length_s": 0.45, "low_hz": 400.0, "high_hz": 9000.0, "peak": 0.04, "shape": 2.5}, "gain_db": -6.0}],
                 bind=level(-4.0, 0.0), send=0.3, seed=114),
    "letters": dict(voice="ratchet", params={"length_s": 0.6, "start_rate_hz": 42.0, "end_rate_hz": 22.0, "click_hz": 2600.0, "q": 3.0, "fade": 0.4, "accent_every": 2.0},
                    bind=level(-14.0, -6.0), seed=115),
    "tab": dict(voice="whoosh", params={"length_s": 0.22, "low_hz": 500.0, "high_hz": 4000.0, "peak": 0.85, "mode": "&band", "q": 1.2},
                bind=level(-14.0, -6.0), send=0.2, seed=116),
    "flux": dict(voice="boing", params={"start_hz": 420.0, "end_hz": 70.0, "drop_s": 0.03, "decay_s": 0.3, "sub": 0.9, "click": 1.0, "click_hz": 9000.0},
                 layers=[{"voice": "&mallet", "params": {"freq_hz": 185.0, "material": "&metal", "hardness": 1.0, "decay_s": 0.5}, "gain_db": -6.0},
                         {"voice": "&snare", "params": {"tone_hz": 180.0, "tone": 0.3, "noise": 1.0, "noise_hz": 7000.0, "noise_decay_s": 0.18}, "gain_db": -6.0}],
                 bind=level(-4.0, 0.0), send=0.35, seed=117),
    "check": dict(voice="tone", params={"wave": "&square", "freq_hz": 1318.5, "decay_s": 0.04, "gate_s": 0.04, "length_s": 0.09},
                  layers=[{"voice": "&click", "params": {"freq_hz": 5000.0, "mode": "&band", "q": 3.0, "decay_s": 0.002}, "gain_db": -8.0}],
                  fx=[{"type": "lowpass", "cutoff_hz": 6000.0}],
                  bind=pitched(-20.0, -11.0), send=0.2, seed=118),
    "type": dict(voice="ratchet", params={"length_s": 0.5, "start_rate_hz": 70.0, "end_rate_hz": 50.0, "click_hz": 7000.0, "q": 6.0, "fade": 0.5},
                 bind=level(-24.0, -14.0), seed=119),
    "hud": dict(voice="tone", params={"wave": "&triangle", "freq_hz": 1760.0, "end_hz": 2640.0, "glide_s": 0.02, "decay_s": 0.06, "gate_s": 0.06, "length_s": 0.12},
                bind=pitched(-20.0, -11.0), send=0.25, seed=120),
    "collapse": dict(voice="tone", params={"wave": "&sine", "freq_hz": 620.0, "end_hz": 70.0, "glide_s": 0.12, "decay_s": 0.35, "gate_s": 0.35, "length_s": 0.5},
                     layers=[{"voice": "&whoosh", "params": {"length_s": 0.45, "low_hz": 120.0, "high_hz": 1800.0, "peak": 0.2, "noise": "&brown"}, "gain_db": -6.0}],
                     bind=level(-10.0, -3.0), send=0.3, seed=121),
    "zip": dict(voice="whoosh", params={"length_s": 0.3, "low_hz": 2000.0, "high_hz": 12000.0, "peak": 0.75, "shape": 2.2, "mode": "&band", "q": 1.5},
                layers=[{"voice": "&tone", "params": {"wave": "&sine", "freq_hz": 1500.0, "end_hz": 5000.0, "glide_s": 0.1, "decay_s": 0.2, "gate_s": 0.2, "length_s": 0.3}, "gain_db": -14.0}],
                bind=level(-14.0, -6.0), send=0.2, seed=122),
    "blip": dict(voice="mallet", params={"freq_hz": 1760.0, "material": "&glass", "hardness": 0.6, "decay_s": 0.5},
                 layers=[{"voice": "&boing", "params": {"start_hz": 120.0, "end_hz": 55.0, "drop_s": 0.08, "decay_s": 0.25, "sub": 0.8, "click": 0.1}, "gain_db": -8.0}],
                 bind=level(-8.0, -2.0), send=0.5, seed=123),
}
fx["hud_out"] = dict(fx["hud"], transforms=[{"type": "reverse"}], offset_s=-0.12)

for name, f in fx.items():
    recipe(os.path.join(D, name + ".tres"), **f)

cue_map(os.path.join(D, "ftf_map.tres"), {
    "boot.rule": R + "boot_rule.tres", "mh.layer": R + "mh_layer.tres", "mh.letters": R + "mh_letters.tres",
    "mh.disc": R + "mh_disc.tres", "mh.presents": R + "mh_presents.tres", "glitch": R + "glitch.tres",
    "glitch.tear": R + "glitch_tear.tres", "sweep": R + "sweep.tres", "panel": R + "panel.tres", "wall": R + "wall.tres",
    "tile": R + "tile.tres", "iris": R + "iris.tres", "riser": R + "riser.tres", "drop": R + "drop.tres",
    "letters": R + "letters.tres", "tab": R + "tab.tres", "flux": R + "flux.tres", "check": R + "check.tres",
    "type": R + "type.tres", "hud": R + "hud.tres", "hud.out": R + "hud_out.tres", "collapse": R + "collapse.tres",
    "zip": R + "zip.tres", "blip": R + "blip.tres",
}, master_fx=[{"type": "dcblock"}, {"type": "loudness", "target_lufs": -16.0}, {"type": "limit", "ceiling_db": -2.0}],
   reverb={"room": 0.35, "damp": 0.5, "width": 1.0, "quality": "&full", "return_db": -2.0}, end_fade_s=0.4)
# ducking is a cue map field write_recipes doesn't know; append it
with open(os.path.join(D, "ftf_map.tres"), "a") as fh:
    fh.write('duck = {"depth_db": 7.0, "full_at_db": -20.0, "attack_s": 0.005, "release_s": 0.25}\n')

# ------------------------------------------------------------------ music (150 bpm)
recipe(os.path.join(MD, "kick.tres"), voice="kick", seed=201,
       params={"tune_hz": 50.0, "punch": 3.5, "decay_s": 0.28, "click": 0.45, "drive": 0.35}, bind=level(-7.0, 0.0))
recipe(os.path.join(MD, "snare.tres"), voice="snare", seed=202, send=0.2,
       params={"tone_hz": 195.0, "tone": 0.5, "noise": 0.85, "noise_hz": 5500.0, "noise_decay_s": 0.15},
       vary={"noise_hz": 0.1}, vary_variants=4, bind=level(-14.0, 0.0))
recipe(os.path.join(MD, "hat.tres"), voice="hat", seed=203, vary={"decay_s": 0.3}, vary_variants=4,
       params={"decay_s": 0.03, "tone_hz": 9500.0, "metal": 0.6}, bind=level(-10.0, 0.0))
recipe(os.path.join(MD, "ohat.tres"), voice="hat", seed=204, params={"decay_s": 0.22, "tone_hz": 8500.0, "metal": 0.7}, bind=level(-8.0, 0.0))
recipe(os.path.join(MD, "acid.tres"), voice="wavetable", seed=205,
       params={"position": 0.7, "sub": 0.2, "cutoff_hz": 420.0, "env_octaves": 3.2, "filter_decay_s": 0.11, "q": 6.5,
               "attack_s": 0.002, "decay_s": 0.12, "sustain": 0.35, "release_s": 0.03},
       fx=[{"type": "drive", "amount": 0.35}], bind=level(-9.0, 0.0))
recipe(os.path.join(MD, "stab.tres"), voice="wavetable", seed=206, send=0.4,
       params={"position": 0.62, "unison": 5, "detune_cents": 22.0, "cutoff_hz": 1600.0, "env_octaves": 1.8, "filter_decay_s": 0.09,
               "q": 1.2, "attack_s": 0.002, "decay_s": 0.14, "sustain": 0.0, "release_s": 0.06})
recipe(os.path.join(MD, "pad.tres"), voice="wavetable", seed=207, send=0.5,
       params={"position": 0.5, "unison": 5, "detune_cents": 16.0, "cutoff_hz": 1100.0, "env_octaves": 0.5, "filter_decay_s": 1.0,
               "q": 0.7, "attack_s": 0.35, "decay_s": 0.8, "sustain": 0.7, "release_s": 0.3})

# Notes: E minor. The acid line, one bar, cycled over its hits.
ACID_STEPS = "X.xxX.x.xX.xx.Xx"
ACID_NOTES = [28, 40, 28, 31, 28, 38, 40, 28, 43, 28, 35]
acid = {"name": "acid", "recipe": M + "acid.tres", "steps": ACID_STEPS, "length": 16, "notes": ACID_NOTES, "gate": 0.7, "gain_db": -3.0}
kick_break = {"name": "kick", "recipe": M + "kick.tres", "steps": "X.........X.....X.X.......X..x..", "length": 32}
snare_break = {"name": "snare", "recipe": M + "snare.tres", "steps": "....X..o.o..X..o....X..o.o..X.oo", "length": 32, "gain_db": -2.0}
hat_break = {"name": "hat", "recipe": M + "hat.tres", "steps": "x.o.x.o.x.o.x.oo", "length": 16, "gain_db": -11.0, "pan": 0.15}
ohat = {"name": "ohat", "recipe": M + "ohat.tres", "steps": "..............x.", "length": 16, "gain_db": -13.0, "pan": -0.15}
stab = {"name": "stab", "recipe": M + "stab.tres", "steps": "...x.....x....x.", "length": 16, "notes": ["E4", "E4", "D4"], "chord": [0, 3, 7, 10], "gate": 1.0, "gain_db": -10.0}
pad = {"name": "pad", "recipe": M + "pad.tres", "steps": "x" + "." * 31, "length": 32, "notes": ["E3"], "chord": [0, 7, 10, 15], "gate": 31.0, "gain_db": -9.0}
kick_soft = {"name": "kick", "recipe": M + "kick.tres", "steps": "o...............", "length": 16, "gain_db": -4.0}
hat_soft = {"name": "hat", "recipe": M + "hat.tres", "steps": "..o...o...o...o.", "length": 16, "gain_db": -14.0, "pan": 0.15}
kick_four = {"name": "kick", "recipe": M + "kick.tres", "steps": "X...x...X...x...", "length": 16}

P = "AKPattern"
pat = lambda name, steps, lanes, swing=0.5: resource(os.path.join(MD, name + ".tres"), P, S + "pattern.gd",
                                                     {"steps": steps, "seed": len(name), "swing": swing, "lanes": lanes}, typed={"lanes"})
pat("intro", 32, [pad, kick_soft, hat_soft])
pat("build", 32, [kick_break, snare_break, hat_break, acid])
pat("drop", 32, [kick_break, snare_break, hat_break, ohat, acid, stab])
pat("outro", 16, [kick_four, hat_break, acid])
pat("silence", 16, [])
resource(os.path.join(MD, "tempo.tres"), "AKTempoMap", S + "tempo_map.gd", {"bpm": 150.0, "beats_per_bar": 4, "offset_s": 0.0})

resource(os.path.join(MD, "ftf_song.tres"), "AKSong", S + "song.gd", {
    "sections": [
        {"name": "intro", "bars": 2.0, "patterns": [M + "intro.tres"]},
        {"name": "build", "bars": 1.875, "patterns": [M + "build.tres"],
         "automation": {"acid.cutoff_hz": [[0.0, 260.0], [1.0, 1400.0]], "acid.q": [[0.0, 4.0], [1.0, 8.0]]}},
        {"name": "gap", "bars": 0.125, "patterns": [M + "silence.tres"]},
        {"name": "drop", "bars": 3.0, "patterns": [M + "drop.tres"],
         "automation": {"acid.cutoff_hz": [[0.0, 700.0], [0.5, 1800.0], [1.0, 900.0]]}},
        {"name": "outro", "bars": 1.0, "patterns": [M + "outro.tres"],
         "automation": {"acid.cutoff_hz": [[0.0, 900.0], [1.0, 200.0]], "acid.gain_db": [[0.0, 0.0], [1.0, -12.0]], "kick.gain_db": [[0.0, 0.0], [1.0, -8.0]]}},
        {"name": "tail", "bars": 0.75, "patterns": [M + "silence.tres"]},
    ],
    "gain_db": -4.0,
}, refs={"tempo": M + "tempo.tres"}, typed={"sections"})
print("wrote %d effect recipes, ftf_map.tres and the 150 bpm song" % len(fx))
