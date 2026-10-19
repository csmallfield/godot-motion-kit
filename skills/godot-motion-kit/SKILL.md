---
name: godot-motion-kit
description: Make motion graphics directly in Godot 4 with the Godot Motion Kit addon (intros, idents, logo reveals, kinetic type, title cards, animated HUD or menus, transitions), from a brief to a rendered, reviewed piece with cue-driven sound.
---

# Making motion graphics in Godot with the Motion Kit

The Godot Motion Kit (`addons/motion_kit`, repo `csmallfield/godot-motion-kit`) is a
pure-GDScript addon for authored motion: compositions that are a pure function of the
frame number, springs and easing, part-level SVG animation, browser-exact type,
analytic shapes and gradients, offscreen effects (blur, glow, glitch, goo), reveals and
scene transitions. Pieces are made **directly in Godot**: write a brief, turn it into a
beat sheet in frames, build it, render it, look at the frames, and revise.

This skill covers that loop. The repo's `docs/techniques.md` catalogues every technique
with a working example, and `docs/API.md` has the full reference; read them when the
repo is available.

## 0. Before starting

- Check the project has `addons/motion_kit/` and the plugin is enabled (Project Settings
  → Plugins → Motion Kit; it registers the `MotionTransition` autoload and the Motion SVG
  importer). If it's missing, copy the folder from the repo, along with `tools/render.sh`
  and `tools/sheet/` for rendering and review (section 5).
- Find the Godot 4 binary (`godot` on PATH, or ask). Rendering needs a display; headless
  machines use Xvfb with software GL (correct, slow for blur-heavy pieces).
- Look at what the project already has: brand SVGs, fonts, colour constants, shared
  helpers from earlier pieces (for example `demo/scf/brand.gd`, `PrintKit`, `GooKit`). A
  new piece in an existing family should reuse them.

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

Defaults that worked for every SCF intro: 1920×1080 reference, 30 fps, 10–14 s
(300–420 frames); **build-in → a long hold with subtle motion → an outro that ends on an
empty frame** (black, paper or the game's background) so it can cut straight into the next
shot; the outro is often the build-in in reverse.

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

Put beats on a musical grid if there will be sound (120 bpm = a beat every 15 frames).
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
  automaton), cache each step by frame and replay from the cache.
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

Pick techniques from the brief; `docs/techniques.md` gives each one an example.

**Time (MK, static).** `spring(f, at, damping=10, stiffness=100)` 0→1 with overshoot;
`interp(f, inputs, outputs, easing)` multi-key; `map(f, in, out, easing=ease_out)` clamped;
`prog(f, start, dur)`, `win(f, a, b)`, `rise(f, start)`; easings `ease_out`, `ease_in_out`,
`ease_in_back`, `ease_out_back`, `ease_in_quad`, `bezier(x1, y1, x2, y2)`; `rand(seed)`;
`step(f, n)` (on twos); `shake(f, at)` / `shakes(f, [ats], amp, dur)`;
`typed(text, f, start, cps)`; `crt_off(f, at)`; `timecode(f)`; `rot_x`, `rot_y`,
`project` for wireframe 3D.

**Composition.** `play()`, `play_segment("in", "hold")`, `play_backwards(0)` (reverse
outro), `seek(f)`, `render(f)`; `clock = AUDIO` with `audio` locks to the soundtrack;
nested compositions see `f - start`; `fit_to_viewport`; `preview_frame` scrubs in the
editor. Cues: `cue(at, name, intensity, data)`, `beats(bpm, from, to)`,
`cues_between(a, b)`, `export_cue_sheet(path)`, signals `cue_fired` and `cue_sync`,
global `MotionCue.bus`; `MotionCuePlayer` plays WAVs on cues.

**SVG.** Import as Motion SVG; `MotionSvg` with `data`, `width`, `only`, `crop`;
`apply(func(i): return {...})` per frame with keys `tx ty s sx sy rot pivot o fill stroke
draw draw_width fill_o hide blur`. `draw` 0→1 traces outlines; single-colour parts recolour
for free via `fill`. Fade a whole logo as one layer inside a `CanvasGroup`.

**Type.** `MotionText`: `font` (`MotionFonts.font(path)`), `font_size`, `color`,
`tracking` (em), `line_height`, `align` + `box_width`, `visible_chars`, `uppercase`,
`stroke_width`/`stroke_color`, `vertical`; `glyph_fn = func(i, f)` per character;
`get_text_size()`, `get_baseline()`. `MotionPill` for tags. Add subset fonts to
`fallbacks` for symbols the main font lacks.

**Shapes and drawing.** `MotionShape` (CIRCLE, RECT, RING, ARC; `MotionShape.circle(d,
col)`, `pill(w, h, col)`; dashes, borders, box-shadow `blur`). `MotionGradient.linear`,
`radial`, `stripes` (animate `shift`), `rings` (moiré), with `blend` MULTIPLY / SCREEN /
OVERLAY / ADD. `MotionCanvas.draw_fn = func(c, f)` with `line`, `polyline`, `polygon`,
`circle`, `ring`, `ellipse`, `rect`, `dashed_polyline` for anything built from loops.
`MotionCells` for palette byte grids.

**Effects.** `MotionFX` (put nodes under `.content`; size it to the frame plus room for
blur): `blur` (sigma), `glow` + `glow_strength`, `shadow_color`/`shadow_blur`/
`shadow_offset`, `set_slices(amount, split, count, seed)` (glitch + RGB split),
`pixel_size`, `brightness`, `invert`, goo (`blur` + `alpha_matrix = Vector2(26, -11)` +
`flood_color`; `source_atop = true` keeps each shape's colour), `render_scale`. One
`MotionFX` has one blur radius; nest two for two. `MotionOverlay` kind STATIC or CRT.
`MotionPixelGrid.cells_from_svg()` for pixel builds.

**Reveals.** `clip_children = CanvasItem.CLIP_CHILDREN_ONLY` on a `MotionCanvas` that
draws the mask (strips, comb teeth, random blocks, an iris), children inside it. Polygons
with animated edges for floods and wipes.

**Game layer.** `MotionTransition.change_scene(path, style)` (circle, bars, clock, fade,
glitch, crt), `cover()` / `uncover()`; `MotionReactive` under any Control for spring
hover / focus / press; `MotionSpring` for input-driven values.

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
- For sound design outside Godot, `export_cue_sheet(path)` writes every cue as JSON
  (frames, seconds, names, intensities, data).
- Playback fires each crossed cue once, in order; seeking fires none (listeners get a
  `seek` sync); reverse fires with `reversed = true`; loops fire every pass; nested
  compositions fire from the root. Scrubbing with `render(f)` fires nothing.
- When a timing changes, change the constant: the cue moves with it.

## 7. Deliver

- The scene and script, the brief and beat sheet in the header, the cue sheet in
  `_init`, assets in the project.
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
- Software-GL renders of goo or many blurs take minutes per piece; render one at a time
  and split long ones with a start frame.
- Only when matching an existing browser animation exactly (porting a Remotion/CSS/SVG
  piece) do the browser rules matter: read `docs/porting-from-remotion.md` and compare
  with `tools/compare/compare.py`.
