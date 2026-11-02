---
name: godot-motion-kit
description: Make motion graphics directly in Godot 4 with the Godot Motion Kit addon (intros, idents, logo reveals, kinetic type, title cards, animated HUD or menus, transitions), from a brief to a rendered, reviewed piece with cue-driven sound.
---

# Making motion graphics in Godot with the Motion Kit

The Godot Motion Kit (`addons/motion_kit`, repo `csmallfield/godot-motion-kit`) is a
pure-GDScript addon for authored motion: compositions that are a pure function of the
frame number, springs and easing, part-level SVG animation, browser-exact type,
analytic shapes and gradients, offscreen effects (blur, glow, glitch, goo), reveals and
scene transitions, plus larger families grown from the Full Throttle Flux pieces: time
effects (slit-scan), shader fields and patterns, print, 2.5D extrusion and cities, real
3D stages, and diagrams (metro maps, pipes, cables). Pieces are made **directly in
Godot**: write a brief, turn it into a beat sheet in frames, build it, render it, look at
the frames, and revise.

This skill covers that loop. The repo's `docs/techniques.md` catalogues every technique
with a working example (and compares the three ways to do 3D), and `docs/API.md` has
the full reference, grouped by the same families as section 4; read them when the repo
is available.

## 0. Before starting

- Check the project has `addons/motion_kit/` and the plugin is enabled (Project Settings
  → Plugins → Motion Kit; it registers the `MotionTransition` autoload and the Motion SVG
  importer). If it's missing, copy the folder from the repo, along with `tools/render.sh`
  and `tools/sheet/` for rendering and review (section 5), and `tools/bake_audio.gd` if
  the piece will have a baked soundtrack (section 6).
- Find the Godot 4 binary (`godot` on PATH, or ask). Rendering needs a display; headless
  machines use Xvfb with software GL (correct, slow for blur-heavy pieces). The project
  uses the Compatibility renderer.
- Look at what the project already has: brand SVGs, fonts, colour constants, shared
  helpers from earlier pieces (for example `demo/scf/brand.gd`, `PrintKit`, `GooKit`,
  `demo/ftf/ftf_kit.gd`'s `FTFKit`). A new piece in an existing family should reuse
  them; anything generic belongs in the kit, not in a family helper.

## 1. The brief

Turn the request into a short written brief before any code. If the request is open
("make an intro for the game"), propose **three to five directions** first, one line
each: a name, the visual idea, the palette, and what the logo does. For example:

> **Pit Lane**: race-team ident, hazard stripes, HUD, 3-2-1, the logo slams in with motion blur. Black / amber / red.
> **Signal**: broadcast corruption, static, slice glitch and RGB split decode, CRT power-off.
> **Goo**: lava-lamp blobs pour into the logo; letters drop and land like jelly.

Let the person pick (or pick the strongest and say why). Then write the brief as the
header comment of the script: what happens, in order, in plain words, and the
end state.

Defaults that worked for every SCF intro and FTF take: 1920×1080 reference, 30 fps,
10–14 s (300–420 frames); **build-in → a long hold with subtle motion → an outro that
ends on an empty frame** (black, paper or the game's background) so it can cut straight
into the next shot; the outro is often the build-in in reverse.

Notes from reviews of the FTF takes (what made pieces land, and what didn't):

- Avoid letters springing in one after another (the bouncy staggered cascade is
  overused) and grids of logos or cards; let the logo arrive through the piece's own
  idea (a slit, a print plate, a camera move, a fill, a weave).
- The drop must punch: the logo big and legible on the impact frame, not small and
  growing into it afterwards. Prefer shake, rings and pulses to white flashes.
- Holds stay alive (beat pulses, travelling light, small secondary motion), including
  the first logo's hold; give each logo at least 1.5 s of clear reading time.
- Photosensitivity: no large-area flashes faster than 3 per second, no saturated red
  strobing.

## 2. The beat sheet

Under the brief, list the beats with frame numbers. Every animation in the code starts
from one of these numbers, so retiming is editing a constant:

```
# Beats (30 fps, 180 frames):
#   0-12      bands slam in (staggered springs)
#   12/30/48  3, 2, 1 (spring pop + shake on each)
#   66        GO: glow burst, speed lines, shake
#   80-110    title tracking settles; 96 pill pops
#   120-150   hold: bands crawl, GO breathes
#   150-174   out: everything springs away, ends on black
```

Put beats on a musical grid if there will be sound (120 bpm = a beat every 15 frames):
`const BPM := 120.0`, `const BEAT := 1800.0 / BPM`, `bpm = BPM` in `_init`;
`MK.beat_pulse(f, BEAT, from, to, rate)`, `MK.decay_kick`, `MK.accent` and `MK.flicker`
cover the usual beat-driven pulses, kicks and lamp strikes.
Every beat that should be heard becomes a `cue()` in the code (section 6).

## 3. Build it

Start every piece from this shape (`demo/examples/race_ident.gd` is a complete one):

```gdscript
@tool
extends MotionComposition
# TITLE — the brief, in plain words.
# Beats (30 fps, N frames): ...

const INK := Color("#0e0f12")
const AMBER := Color("#ffb627")
const TITLE_AT := 10        # beat-sheet frames as constants: picture and cues share them
const OUT := 150

var _built := false
var _stage: Node2D          # parent of everything that shakes
var _title: Node2D          # pivot at the title's centre, so scale pops it in place


func _init() -> void:
	duration = 180
	fps = 30
	markers = {"in": 0.0, "hold": 120.0, "out": float(OUT)}
	cue(TITLE_AT, &"title", 1.0)    # the beat sheet's moments, for sound (section 6)
	cue(OUT, &"whoosh.out", 0.8)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


func _build() -> void:      # create every node once
	_built = true
	var bg := ColorRect.new(); bg.color = INK; bg.size = size; add_child(bg)
	_stage = Node2D.new(); add_child(_stage)
	_title = Node2D.new(); _title.position = Vector2(960, 540); _stage.add_child(_title)
	var t := MotionText.new()
	t.font = MotionFonts.font("res://fonts/heavy.woff2")
	t.font_size = 120
	t.color = AMBER
	t.text = "TITLE"
	t.position = -t.get_text_size() * 0.5
	_title.add_child(t)


func _frame(f: float) -> void:   # set properties from f only
	if not _built:
		return
	var out := MK.interp(f, [OUT, OUT + 24], [0, 1], MK.ease_in_back)
	_stage.position = MK.shakes(f, [12, 30], 16, 8)
	var s := MK.spring(f, TITLE_AT, 12, 160) * (1.0 - out)
	_title.scale = Vector2.ONE * maxf(0.0, s)
	_title.visible = s > 0.0
```

Rules that keep a piece correct:

- **Pure function of `f`.** `_frame(f)` reads only `f` and constants. No accumulating
  state, no `randf()`, no timers. If something must evolve step by step (a cellular
  automaton), cache each step by frame and replay from the cache; anything that
  integrates a speed (a camera along a track) is a `MotionTravel` table built once.
- **Build once.** Create nodes in `_build()`; `_frame` only sets properties. Keep the
  `_built` guard (`@tool` scripts also run in the editor, where the preview slider
  calls `_frame`).
- **Seeded randomness.** `MK.rand(i * 3.3 + seed)`; vary the seed per element.
- **Stagger by index.** `MK.spring(f, at + i * 2, ...)`.
- **Animate transforms, not layout.** Animate `scale`, `position`, `rotation`,
  `modulate`. Never animate `font_size` (each size re-rasterizes glyphs) or sizes that
  re-lay out text.
- **Pivots.** To scale or rotate about a point, put a `Node2D` there and parent the
  element to it, offset by half its size; then `scale` pops it in place. `MotionPill` is
  already centred.
- **Hide finished things.** `visible = false` when fully transparent or scaled to 0; a
  hidden `MotionFX` stops rendering offscreen.
- **Static typing.** Declare types for values from Dictionaries and Callables
  (`var at: float = d.at`); `:=` on a Variant is a parse error with warnings as errors.
  Convert to float before dividing integers.

## 4. Technique quick reference

Pick techniques from the brief; `docs/techniques.md` gives each one an example, and
`docs/API.md` the members. Every class appears once, grouped as in the API.

**Core.** `MK` (static): `spring(f, at, damping=10, stiffness=100)` 0→1 with overshoot,
`interp(f, inputs, outputs, easing)`, `map`, `prog(f, start, dur)`, `win(f, a, b)`,
`rise`; easings `ease_out`, `ease_in_out`, `ease_in_back`, `ease_out_back`,
`ease_in_quad`, `bezier(x1, y1, x2, y2)`; `rand(seed)`, `step(f, n)`, `shake` /
`shakes(f, [ats], amp, dur)`, `typed`, `crt_off`, `timecode`; beats `beat_pulse`,
`decay_kick`, `accent`, `flicker`; `rot_x`, `rot_y`, `project` for wireframes.
`MotionComposition`: `play()`, `play_segment("in", "hold")`, `play_backwards(0)`,
`seek`, `render(f)`, `clock = AUDIO`, nested compositions see `f - start`,
`fit_to_viewport`, `preview_frame`, `bpm`, `as_source()` (content for time effects).
Cues: `cue(at, name, intensity, data)`, `beats(bpm, from, to)`, `cues_between`,
`export_cue_sheet`, global `MotionCue.bus`; `MotionCuePlayer` plays WAVs on cues.
`MotionTravel` tables distance over time (`from_speed` / `from_keys` / `from_anchors`,
`at(f)`). `MotionPath` measures polylines (`point_at(s)`, `tangent_at`, `sub` /
`sub_fraction`, `rounded`, `offset`); `MotionPoly` area, bounds, point-in-polygon.
`MotionOffscreen` (`make`, `fit`, `gate`) for any new node that renders offscreen.

**SVG and text.** `MotionSvg` (import as Motion SVG; `data`, `width`, `only`, `crop`;
`apply(func(i): return {...})` per frame with keys `tx ty s sx sy rot pivot o fill stroke
draw draw_width fill_o hide blur`; `draw` 0→1 traces outlines, `fill` recolours for
free; fade a whole logo inside a `CanvasGroup`). `MotionSvgData.load_any(path)`,
`contours(parts, k, tl)`, `find`, `sorted_by_x` (parsed by `MotionSvgParser`).
`MotionText` (`font`, `font_size`, `color`, `tracking` em, `line_height`, `align` +
`box_width`, `visible_chars`, `stroke_width`, `vertical`, `glyph_fn(i, f)`,
`get_text_size()`, `get_baseline()`; `MotionText.make(parent, font, size, col, text,
tracking)`). `MotionFonts.font(path, false, [fallback_fonts])` (never assign
`.fallbacks` on its fonts: they are shared), `draw_screen_text` for zoom-proof canvas
text. `MotionPill` tags. `MotionTextPath` text along a path (`offset` scrolls, `repeat`,
`show_from` / `show_to`).

**Shapes and drawing.** `MotionShape` (CIRCLE, RECT, RING, ARC; `circle(d, col)`,
`pill(w, h, col)`; dashes, borders, box-shadow `blur`). `MotionGradient` (`linear`,
`radial`, `stripes` + animated `shift`, `rings` moiré; `blend` MULTIPLY / SCREEN /
OVERLAY / ADD). `MotionCanvas.draw_fn = func(c, f)` with `line`, `polyline`, `polygon`,
`circle`, `ring`, `ellipse`, `rect`, `dashed_polyline`. `MotionCells` palette byte grids.
`MotionMarks` (static, any CanvasItem, with opacity): chevrons, arrows, checker, hatch,
barcode, crosshair, warning triangles, hazard clamps, ribbons and stripe bundles along
paths. `MotionTape` hazard tape along a path (`pose(spec, f)`, `draw`).

**Effects.** `MotionFX` (nodes under `.content`; size it to the frame plus 3σ): `blur`
(σ), `glow` + `glow_strength`, `shadow_color` / `shadow_blur` / `shadow_offset`,
`set_slices(amount, split, count, seed)` (glitch + RGB split), `pixel_size`,
`brightness`, `invert`, goo (`blur` + `alpha_matrix = Vector2(26, -11)` + `flood_color`;
`source_atop = true` keeps colours), `render_scale`; one blur radius per MotionFX, nest
two for two. `MotionOverlay` STATIC or CRT. `MotionPixelGrid.cells_from_svg()` pixel
builds. `MotionBeacon` rotating beacon light (`angle = spin(f, period)`).

**Time.** `MotionTimeSlices` (content instanced per band at `f - delay`: COLUMNS / ROWS /
BOXES / CHANNELS, `profile`, `slit` 0→1 = slit-scan, `reveal`); `MotionTimeCache`
(slit-scan and channel splits that render each distinct delay once); `MotionTimeSplit`
(RGB time split over any background); `MotionViewRect.of(self)` lets heavy content cull
to its band.

**Fields and patterns.** `MotionGlyphField` (cycling glyphs lit by a logo under
`mask_content`; `reveal`, `scan_y`, `ring_r`, `rain`, `fall_t`, `solidify`);
`MotionWarpField` (banded, domain-warped, kaleidoscoped colour fields, melting `content`,
mirror horizon); `MotionTiling` (houndstooth and other motifs whose cells rotate, scale,
invert and switch by mask, halo, ring and sweep); `MotionPatternPlane` (ray-cast endless
patterned ground with sky, banded sun, bends, sandwich `clip` layers, `project()`,
`draw_checker_box()`); `MotionPlaneScan` (the plane's own per-pixel slit-scan:
`history_fn`, `scan`, `walls`, `split`).

**Print.** `MotionPaper`, then one `MotionPlate` per ink (artwork in black, knockouts in
white; plates overprint by multiplying; halftone `cell` / `angle_deg`, `register()`,
`print_in()`, `thunk()`, `roughness` / `grain` / `slur`).

**2.5D extrusion and cities.** `MotionExtrudeCamera` (orthographic yaw / pitch: iso →
flat elevation; `to_lens()` for the matching 3D camera), `MotionSolid` (box, cylinder,
pipe, wedge, `from_svg` slab; `clip_z` to rise out of the ground; `add_decal`),
`MotionExtrude` (`prepare()`, `draw(canvas, filter)`, `cap_transform`, `draw_text`).
`MotionCityPlan` (seeded machine city as data → `solids()` or `to_flat3d()`).
`MotionGreebler` (panels and greebles that resolve as the camera pushes in). Voxels:
`MotionVoxelize` (mask → cells), `MotionBlockPlan` (blocks moving in waves,
`pose(i, f)`), `MotionFaceLights` (windows, neon rims and chases in decals).

**3D.** `MotionStage3D` (a World3D in the composition; camera from `f`: `ride()`,
`blend()`, `to_screen()`, `night()`, `unlit()`), `MotionLens3D` (perspective →
orthographic blend that ends on a MotionExtrudeCamera view), `MotionSvgMesh` (extruded
logos), `MotionPanel3D` (kit 2D on a 3D quad), `MotionFlat3D` (poster face tones, depth
fog, beat pulse and sink in the shader, builders) with `MotionEdges3D` (outlines) and
`MotionDecalAtlas` (decals), `MotionPattern3D` (checker / grid materials on geometry,
endless `ground()`, `grow()`), `MotionSkyDome3D` (sky with banded sun), `MotionTrack3D`
(banked circuits, ribbons, trails). Pieces are made under the Compatibility renderer;
fog, glow and MSAA differ under Forward+, so check 3D pieces there.

**Diagrams and flow.** `MotionMetroMap` (octilinear transit maps: `add_line`, `build()`,
`draw_line(c, i, a, b)`, trains, interchanges, `label`); `MotionFlow` (pipes: `draw`,
`fill`, `drain`, `flow`, pulses; `state_fn`); `MotionLiquidFill` (a logo filling with
sloshing liquid: `fill_level`, `kicks`); `MotionCable` + `MotionCableSet` (sagging shaded
cables: `reveal`, `tension`, `tugs`, `pulses`, plugs, over / under `z_ranges`).

**Shaders.** New shaders take noise from `shaders/motion_noise.gdshaderinc`
(`mk_hash21(p, seed * k)`, `mk_vnoise2/3`, `mk_fbm3`), patterns from
`plane/motion_pattern.gdshaderinc` and the banded sun from
`shaders/motion_sun.gdshaderinc`.

**Game layer.** `MotionTransition.change_scene(path, style)` (circle, bars, clock, fade,
glitch, crt), `cover()` / `uncover()`; `MotionReactive` under any Control for spring
hover / focus / press; `MotionSpring` (and `MotionSpring2D` / `3D`, `impulse()`) for
input-driven values. Live game systems: `MotionClock` (events, "frames since", per-entity
hit-stop with `freeze()`; feed `frames_since` to any `MK` curve), `MotionTrauma` (trauma
shake with directional kicks), `MotionFlat3D.cutout()` / `instanced` materials with
`set_flash` for per-actor reactions; cutout characters from SVG with `MotionCutoutRig`
(groups with pivot markers become nested part nodes; `pose`, `solve_limb` two-bone IK) and
`MotionCutout` (front / back / side views, or 8 directions with `front_34` / `back_34`, a
paper turn between them, `lean` toward the camera);
`MotionIK`, `MotionAimSpring` for look-at; `MotionGait` (+ `MotionGaitSettings`) plants feet
in world space, steps on arcs, and gives body dip and lean, mapped onto a view with
`MotionCutout.ground_to_card`; `MotionChain` (verlet scarves, capes, dangling props, shape
memory, drag) drawn with `MotionRibbon3D`; `MotionSquash` for squash and stretch; `MotionPoseCurve` (authored moves as channels,
markers and data in a `.tres`, sampled at frames since the move started); `MotionRipples`
(event rings for any shader) and `MotionGrass3D` (MultiMesh grass that sways and ripples).

**Naming.** Partial drawing is `reveal` (0..1, the drawn end) and `reveal_from` (its
start); random seeds are `seed`; alpha is `opacity` (`set_opacity(id, a)` per greeble
structure); `level` is brightness or a fade, except `MotionLiquidFill.fill_level` (how
full). Nodes given a pure per-frame function run it in their own `_frame`
(`MotionPlaneScan.history_fn`, `MotionFlow.state_fn(i, f)`). Old names still work; the
API's "Deprecated aliases" table lists them.

**Reveals.** `clip_children = CanvasItem.CLIP_CHILDREN_ONLY` on a `MotionCanvas` that
draws the mask (strips, comb teeth, random blocks, an iris), children inside it. Polygons
with animated edges for floods and wipes.

**Examples by family.** The FTF pieces in `demo/ftf/` (listed with tempo and technique
in `demo/ftf/README.md`) are the best working examples; read the matching one before
using a family for the first time:

- Core, type, SVG, marks, effects: `ftf_intro.gd` (+ `ftf_kit.gd`), `demo/examples/race_ident.gd`;
  goo, glitch and reveals: `demo/scf/` (F1–F5, G1–G5, D1)
- Time: `ftf_slitscan`, `ftf_timecity`, `ftf_stargate`
- Fields and patterns: `ftf_glyphfield`, `ftf_lsd`, `ftf_houndstooth`, `ftf_checkercity`, `ftf_stargate`
- Print: `ftf_riso`
- 2.5D extrusion and cities: `ftf_megastructure`, `ftf_timecity`, `ftf_assembly`, `ftf_greebles`
- 3D: `ftf_gantry`, `ftf_nightcircuit`, `ftf_canyon`
- Diagrams and flow: `ftf_subway`, `ftf_fuel`, `ftf_cables`
- Text on paths, tape, beacons: `ftf_warning`

## 5. Render and review

Never call a piece done from the code. Render it and look at it.

```sh
GODOT=/path/to/godot tools/render.sh res://path/piece.tscn out/piece 180
python3 tools/sheet/sheet.py out/piece out/piece-sheet.png --frames 0,12,30,66,90,130,160,179 --motion
```

`render.sh` writes `f00000000.png`… and `f.wav` with Movie Maker (pass a start frame to
resume or split a long render). `sheet.py` tiles the chosen frames with their numbers;
`--motion` prints how much each frame changes from the one before.

Look at the sheet (open the image) at every beat frame and just after it, and check:

- **Collisions and crowding:** text on stripes, elements touching the frame edge,
  things overlapping that shouldn't.
- **Legibility:** contrast, glow or blur softening type, text too small at 1080p.
- **Timing:** does each beat land where the beat sheet says; are there dead stretches
  (runs of near-zero motion outside the hold) or jumps (single-frame spikes that aren't
  intended cuts)?
- **Springs:** too much overshoot reads as a bounce, not a land; raise damping.
- **Ends:** the first frames build from nothing, and the last frame is the empty frame
  the brief promised.
- **Hierarchy:** the logo or title is the clear subject at every hold.

Fix, re-render, look again. Two rounds is normal. When the person asks for revisions,
change the brief and beat sheet first, then the code, then re-render the affected range.

Also check: scrub it in the editor (Preview Frame) and play it backwards; anything that
breaks has hidden state. For pieces that run during gameplay, run `tests/perf.tscn`-style
timing on the script cost and profile blur-heavy pieces on the target GPU.

## 6. Sound: cues

Declare every moment sound should land on as a cue, from the same constants the
animation uses, so picture and sound can't drift apart. Do this even with no sound yet:
cues fire whether or not anything listens, and an audio system can subscribe later.

```gdscript
func _init() -> void:
	cue(12, &"count", 0.7, {pitch = 0.9})   # frame, name, intensity 0..1, free-form data
	cue(GO_AT, &"go", 1.0)
	beats(120, 0, 240)                       # optional: a cue on every beat, accents every 4th
# in _frame, the same number drives the picture:  MK.spring(f, GO_AT, 8, 180)
```

- Name cues by what happens (`whoosh.in`, `count`, `hit`, `pop`), dot-separated so
  listeners can match families with `prefix*`. Intensity says how hard it lands; put
  `pitch`, `volume_db`, `pan` or a sound id in `data`.
- A cue marks where its sound **starts**. Place a whoosh's cue before the move it
  accompanies (its swell peaks later); hits and pops go on the landing frame.
- To hear it now, add a `MotionCuePlayer` with `composition = self` and
  `sounds = {&"whoosh.*": load(...), &"go": load(...)}`. Movie Maker records it into
  `f.wav`, so review renders carry their sound (measured 1–10 ms from the frame).
- A music bed or soundtrack goes on the composition's `audio` (with `clock = AUDIO` to
  lock the picture to it live).
- For sound made from code, use the **Godot Audio Kit** (`csmallfield/godot-audio-kit`,
  its own skill: `godot-audio-kit`). Add an `AKCueBridge` child with a cue map of
  recipes: BAKED renders the cue sheet into one sample-accurate track on `audio` and
  locks the clock to it; LIVE mixes the same timeline as it plays (native core). It
  adds music (a song whose sections follow the picture, notes optionally emitted back
  as cues) and measured review renders. Prefer it to MotionCuePlayer for anything
  beyond a few stock sounds.
- Bake the score into the project so the piece plays its sound without the audio kit:
  link it (`tools/link_audio_kit.sh`), then
  `godot --headless --path . -s res://tools/bake_audio.gd -- --piece=res://path/to/piece_folder`.
  By convention the piece folder holds `<folder name>.tscn` and its sound in `audio/`
  (one `*_map.tres`, `music/*song.tres`); the tool writes `*_track.res` and `*_cues.json`
  there. Override any path with `--scene= --map= --song= --track= --cues=` (a scratch
  `--track=` compares a re-bake without touching the committed one). Re-bake after
  changing recipes, the song or any cue timing. `demo/ftf/README.md` has the full loop.
- For sound design outside Godot, `export_cue_sheet(path)` writes every cue as JSON
  (frames, seconds, names, intensities, data).
- Playback fires each crossed cue once, in order; seeking fires none (listeners get a
  `seek` sync); reverse fires with `reversed = true`; loops fire every pass; nested
  compositions fire from the root. Scrubbing with `render(f)` fires nothing.
- When a timing changes, change the constant: the cue moves with it.

## 7. Deliver

- The scene and script, the brief and beat sheet in the header, the cue sheet in
  `_init`, assets in the project (and the baked track, if there is sound).
- A contact sheet of the beat frames and a video for review:
  `ffmpeg -framerate 30 -i out/piece/f%08d.png -i out/piece/f.wav -c:v libx264 -pix_fmt yuv420p -crf 18 -shortest piece.mp4`
- In the game: instantiate the scene and `play()`, or `play_segment("in", "hold")` and
  `play_backwards()` for menus; `await finished` before moving on; transition out with
  `MotionTransition`.

## 8. Traps

- `clip_children` masks only come from `draw_*` calls (not shaders), lose alpha inside a
  `MotionFX`'s viewport (clip outside it), and **an empty mask clips nothing**: hide the
  node while the mask would be empty.
- A `CanvasGroup` breaks with huge child bounds; use a frame-sized `MotionFX`.
- Content outside a `MotionFX`'s `size` is clipped before its blur; pad by 3 × sigma.
- A `MotionFX` scaled by its parent scales its blur too.
- Blend modes read the backdrop of the viewport they draw in; isolate a group in a
  `MotionFX`.
- Indexed writes to a packed-array property (`cells[i] = v`) don't run its setter.
- `const X := SomeClass` is a parse error; `MK` has no `ease_in` (use `ease_in_quad` or
  `bezier`).
- Time-effect content (MotionTimeSlices, MotionTimeCache, MotionTimeSplit) is instanced
  several times: keep it light or cull it with `MotionViewRect`, and make it accept
  negative frames (`as_source()`).
- Software-GL renders of goo or many blurs take minutes per piece; render one at a time
  and split long ones with a start frame.
- Only when matching an existing browser animation exactly (porting a Remotion/CSS/SVG
  piece) do the browser rules matter: read `docs/porting-from-remotion.md` and compare
  with `tools/compare/compare.py`.

## 9. Live game systems

The same curves run a game, not just a timeline: reactions are pure functions of "time
since the event", following behaviour uses springs, and simulation runs at the physics
rate. `demo/live/live_example.tscn` shows every piece in one small scene;
`csmallfield/cutout-isle` is a full action slice built on them. Read the API's Game layer,
MotionCutoutRig and MotionCutout entries before starting.

- **Time.** One `MotionClock` per entity, parented to a world clock. Mark events
  (`clock.mark(&"hit", data)`) and feed `clock.frames_since(&"hit")` to any `MK` curve
  (`MK.spring`, `MotionSquash.land`, `MK.shakes(clock.frame(), clock.frames(&"hit"), ...)`).
  Hit-stop is `clock.freeze(hold, ease)`: on the attacker and victim for per-entity
  hit-stop, on the world clock for global. Everything on an entity takes its time from
  its clock, including `_physics_process` (`delta * clock.rate()`), or a frozen entity
  keeps sliding. Keep the camera and HUD on real time.
- **Layers, one owner per property.** Each frame: `reset_pose()`, then authored pose
  (a `MotionPoseCurve` sampled at frames since the move started), procedural offsets
  (gait, lean, look-at), reactions (squash, flash), camera last. Two systems writing the
  same property fight.
- **Fixed-step simulation** (`MotionGait`, `MotionChain`) steps in `_physics_process` and
  is read in `_process` with `Engine.get_physics_interpolation_fraction()`. Nodes posed in
  `_process` get `physics_interpolation_mode = OFF` when the project interpolates physics.
- **Cutout characters.** Draw each view as an SVG whose rig parts are groups holding a
  pivot marker; `MotionCutoutRig.build` per view, `MotionCutout` to choose the view from
  the facing (paper turn between them) and `lean()` toward the camera (upright cards
  occlude correctly; the stretch keeps the art's proportions). Legs and arms reach
  targets with `solve_limb`; world feet from a gait become targets through
  `ground_to_card`. Props are `MotionCutoutRig.card`. Plain mirroring swaps a held
  sword between hands: give front and back `EITHER` (never flipped, drawn with the
  sword hand anatomically placed) and build the left side view from
  `side_data.mirrored()` as a `LEFT` view (the sword arm becomes the far arm, behind the
  body). Draw back-view arms behind the torso. A move can carry a part forward or back
  for its active frames (`rig.depth(part, value * rig.front_depth(part))` from a pose-curve
  channel), so the far sword arm swings in front of the body. Three views give 4 directions;
  adding `front_34` and `back_34` gives 8 (five drawings, mirrored). The 3/4 views cost
  the most: each needs its own art, prop attach points and per-view move channels
  (`arc.front_34`, falling back to the base channel), and flat parts show their overlaps
  most at 45 degrees. Characters use `MotionFlat3D.cutout()`
  (unlit vertex colour) and an outline material whose depth bias is below the layer step.
- **2D cutout characters (crowds).** For a 2D game, bake the same SVG views into one
  `MotionCutoutAtlas` (every character type in the same atlas, recoloured variants by
  `hue_map` merged per colour family, `hide` for parts only the hero wears) and draw each
  character as a `MotionCutoutRig2D`. Pose by index (`part_id` once, `pose_at`), call
  `apply()` only on frames you pose: idle and far characters on twos or threes, carrying
  the skipped time; off-screen ones not at all; fast events (launch, hit, attack) every
  frame. Put a swing's hand on the actual hitbox arc with `solve_limb` and `depth` the arm
  in front when the arc comes toward the camera, so what you see is what hits. Flash and
  tint through `set_look` only: never per-sprite materials, which break batching.
  `csmallfield/knockabout` is the example (its `entities/puppet/`).
- **Per-actor reactions:** a character gets its own `flat.actor()` material, shared by
  every part and view, and `rig.set_flash(color, amount)`. Props and world pieces use
  instance uniforms: `material(..., instanced = true)` or `cutout()`, then
  `MotionFlat3D.set_flash(node, color, amount)`. Every instance-uniform mesh holds a block
  of a global buffer, and the Compatibility renderer fits only a few hundred: a rig of 15
  parts in 5 views is 75 meshes, so never give rig parts instance uniforms. Flash small areas, at
  most three a second; prefer shake (`MotionTrauma` with `kick`), rings
  (`MotionRipples` through `MotionGrass3D`) and squash to flashes.
- **Juice that held up:** hit-stop 60–90 ms scaled by power, trauma 0.2–0.4 with a kick
  along the blow, a squash on the victim, an impact star that plays through the freeze on
  real time, a ring through the grass, a telegraph (a held windup and a glowing blade)
  before every enemy attack.
- **Cost.** Measure with `MotionPerfProbe` per system and show it in an overlay. A posed
  cutout character with gait, IK and a chain costs roughly 0.2–0.3 ms of GDScript on a
  2-core cloud VM; skip posing off screen (`VisibleOnScreenNotifier3D`) and keep crowds on
  simpler poses. Cloud renders use software GL: never quote their frame times as
  performance; profile on the target GPU.
- **Loading.** `MotionWarmup.run(camera, MotionWarmup.collect(scene))` compiles every
  material during loading, and audio pools render at load too.
