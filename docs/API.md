# Motion Kit API

All coordinates are pixels in the composition's reference space (1920×1080 unless you
change `MotionComposition.size`). Frames are floats; at 60 Hz and above the same
functions are evaluated between whole frames.

**Conventions.** Names mean the same thing across the kit:

- **Partial drawing** is a pair of fractions 0..1 of the length (or of the bands, cells,
  parts): `reveal` is how far it is drawn (its end), `reveal_from` where the drawn part
  starts. MotionCable (`reveal_from` = `start`), MotionFlow states (`reveal` /
  `reveal_from` keys for `draw` / `draw_from`), MotionTimeSlices and MotionTimeCache
  (`reveal` share of the bands around `reveal_from`) and MotionGlyphField (`reveal` share
  of the cells) follow it. Pixel windows keep their own names (`MotionTextPath.show_from`
  / `show_to` in px of arc length), as do per-level arrays (`MotionGreebler.reveal`) and
  explicit arguments (`MotionMetroMap.draw_line(c, i, a, b)`).
- **`seed`** is every node's and plan's random seed (float). The older `seed_value`
  (MotionLiquidFill, MotionTimeSlices, MotionTimeCache) and `seed_v` (MotionBlockPlan)
  still work as deprecated aliases.
- **`opacity`** is alpha (0..1); per-structure opacity is `set_opacity(id, a)`
  (MotionGreebler; `set_alpha` is its deprecated alias). **`level`** is brightness or an
  overall fade on fields, planes and skies (and on/off on MotionBeacon); a liquid's fill
  height is `MotionLiquidFill.fill_level` (`level` is its deprecated alias).
- **`_frame(f)`**: nodes that need per-frame work do it in their own `_frame` when given
  a pure function of the frame (`MotionPlaneScan.history_fn`, `MotionFlow.state_fn`,
  `MotionCanvas.draw_fn`); calling the manual method (`capture(f)`, `apply(fn)`) still works.

## MK (static maths)

| Function | Notes |
| --- | --- |
| `spring(f, at=0, damping=10, stiffness=100, mass=1, fps=30)` | 0→1 from frame `at`. Same numbers and results as Remotion `spring()`, including its critically damped curve for every damping ratio of 1 or more. |
| `spring_to(f, at, from, to, ...)` | Spring between two values. |
| `bezier(x1, y1, x2, y2) -> Callable` | CSS cubic-bezier easing. |
| `ease_out`, `ease_in_out`, `ease_in_back`, `ease_out_back`, `ease_in_quad`, `linear` | Named curves (`ease_out` = bezier(0.22, 1, 0.36, 1), the SCF `ease`). |
| `interp(x, inputs, outputs, easing=linear, left=CLAMP, right=CLAMP)` | Remotion `interpolate`: multi-key, eased per segment, CLAMP / EXTEND / IDENTITY (EXTEND eases beyond the range, as Remotion does). |
| `map(f, inputs, outputs, easing=ease_out)` | Clamped, eased by default. |
| `prog(f, start, dur=18, easing=ease_out)` | 0→1 over a window. |
| `win(f, a, b, fade=12)` | Fade in at `a`, out by `b`. |
| `rise(f, start, dist=24, dur=18) -> {o, y}` | Fade-and-rise. |
| `rand(seed)` | Deterministic in [0, 1); matches the SCF Remotion `rand`. |
| `step(f, n)` | Quantise to every n frames (on twos). |
| `shake(f, at, amp=18, dur=10) -> Vector2`, `shakes(f, ats, ...)` | Decaying impact shake. |
| `typed(text, f, start, cps=38, fps=30)` | Typewriter. |
| `crt_off(f, at) -> {scale: Vector2, bright, dot}` | Tube power-off curve. |
| `timecode(f, fps=30)` | HH:MM:SS:FF; negative frames read as 0. |
| `springy`, `wob` | Smaller helpers from the SCF pieces. |
| `beat_frames(bpm, fps=30)` | Frames per beat (150 bpm -> 12). |
| `beat_pulse(f, beat, from=0, to=INF, rate=0.3, tau=0)` | 0..1 pulse on every beat in `[from, to)`: 1 on the beat, decaying `exp(-t * rate)` (or `exp(-t / tau)` with `tau` > 0). |
| `decay_kick(f, ats, amp, rate=0.45, alternate=true)` | Sum of decaying kicks from each frame in `ats`, alternating sign (camera jolts one way, then the other). |
| `accent(f, ats, rate=0.3)` | 0..1: 1 right after the latest of `ats`, decaying. |
| `flicker(f, at, seed_v, settle=8, low=0.15)` | A lamp striking on at `at`: a seeded stutter between 1 and `low` for `settle` frames, then 1. |
| `rot_x(p, a)`, `rot_y(p, a)` | Rotate a `Vector3` about the X or Y axis (radians). |
| `project(p, cam_z, focal, centre, near=40) -> Vector3 or null` | Pinhole projection seen from `z = cam_z`: (screen x, screen y, depth), or null nearer than `near`. For wireframes drawn with `MotionCanvas`; use Godot's 3D nodes for real 3D. |

## MotionComposition (Node2D)

Override `_frame(f)`. Descendants that define `_frame(f)` are called after it, including
nodes inside a `MotionFX`. A nested composition receives `f - start` and, like a Remotion
`<Sequence>`, is hidden outside `[0, duration)` of its own time (`hide_outside`); with
`loop` it repeats inside the parent's time.

| Member | Notes |
| --- | --- |
| `fps`, `duration`, `loop`, `speed`, `autoplay` | |
| `clock` | `PROCESS` (default), `AUDIO` (frame follows `audio`'s playback position), `MANUAL` |
| `audio: AudioStreamPlayer` | Started (at the current frame) by `play()` and forward `play_segment()`, re-seeked on loop, stopped when playing backwards. Movie Maker renders always use exact process time. |
| `markers: Dictionary` | Named frames for `play_segment("in", "hold")`. |
| `ignore_time_scale` | Default true: hit-stop and slow motion don't slow the UI. A root composition runs while paused unless you set its process mode. |
| `size`, `fit_to_viewport` | Reference size; letterbox-fit into the viewport. |
| `bpm`, `beat_frames()`, `bar_frames(beats=4)`, `beat_at(f, from=0)` | Tempo (0 = none); frames per beat and bar; the fractional beat number at f. Pieces keep `const BEAT := 1800.0 / BPM` for constant expressions and set `bpm = BPM`. |
| `as_source() -> self` | Make this a source sampled by another composition (slit-scan, time effects): `duration` 100000, `autoplay` and `hide_outside` off. |
| `preview_frame` | Editor scrub slider (scripts must be `@tool`). |
| `play(from=-1)`, `play_backwards(to=0)`, `play_segment(a, b)`, `stop()`, `seek(f)`, `render(f)` | |
| signals `finished`, `segment_finished(name)` | |

Under Movie Maker a root composition sets `Engine.physics_jitter_fix` to 0, so every
image is exactly one step (the jitter fix otherwise wobbles the first frames' deltas).
To split or resume a long Movie Maker render, pass `-- --mk-start=N` on the command line:
the top-level composition starts at frame N (the files still count from 0).

## Cues (MotionComposition, MotionCue, MotionCuePlayer)

A composition keeps a **cue sheet**: the moments sound (or anything else) should land on.
Cues are declared, not detected: the picture is a pure function of `f`, so nothing in it
"starts" in a way the kit could notice. Declare them from the same constants the
animation uses, and they fire as playback crosses them, whether or not anything listens.

```gdscript
func _init() -> void:
	cue(12, &"count", 0.7, {pitch = 0.9})     # returns 12
	beats(120, 0, 240)                         # a cue on every beat, accents every 4th

func _frame(f: float) -> void:
	var s := MK.spring(f, cue(66, &"go"), 8, 180)   # one number for picture and sound
```

| Member | Notes |
| --- | --- |
| `cue(at, name, intensity=1, data={}) -> float` | Declare a cue at frame `at` of this composition; returns `at`. The same name at the same frame updates it. |
| `beats(bpm, from, to, name=&"beat", intensity=0.6, accent_every=4)` | A cue per beat, `data.beat` = index, intensity 1 on accents. |
| `clear_cues()` | Remove this composition's own cues. |
| `get_cue_sheet() -> Array[MotionCue]` | Every cue that can fire in this timeline, sorted: its own and nested compositions' (offset by `start`, repeated when they loop, dropped outside their duration). |
| `cues_between(a, b, inclusive=false)` | Cues in (a, b], to schedule sounds ahead of the picture. |
| `export_cue_sheet(path="") -> String` | JSON `{fps, duration, cues: [{frame, time, name, intensity, data}]}` for sound design tools. |
| signal `cue_fired(cue)` | Playback crossed a cue. |
| signal `cue_sync(frame, state)` | `&"start"`, `&"seek"` (a jump) or `&"stop"` (stopped or finished). |

`MotionCue`: `name`, `frame` (in the firing composition's timeline), `time` (seconds),
`intensity` (0..1 by convention), `data` (free-form: `pitch`, `volume_db`, `pan`, a sound
id…), `reversed`, `composition` (the one that declared it) and `local_frame`.
`MotionCue.bus` relays every composition's cues (`fired(cue)`) and changes
(`sync(composition, frame, state)`), so an audio system subscribes once.

Firing rules, which an audio system can rely on:

- Playback fires each cue it crosses exactly once, in order, including one on the frame
  playback starts from. A long frame (a hitch) fires everything it skipped over.
- `seek()` fires nothing in between and emits `seek`; `stop()` and the end emit `stop`.
- Backwards playback fires cues in reverse order with `reversed = true`.
- A loop fires every pass. Nested compositions' cues fire from the root composition.
- `render(f)` (scrubbing, the editor slider) never fires cues.
- Cues fire after the frame is drawn, from `_process`. Live, a sound starts on the next
  audio mix (plus output latency); for tighter sync, schedule from `cues_between(f, f +
  lookahead)`. Under Movie Maker the measured offset is 1–10 ms, so offline renders carry
  their sound with them.
- A cue marks where its sound should **start**. A sound with a lead-in (a whoosh peaking
  250 ms in) needs its cue earlier, or a listener that aligns the sound's own sync point.

`MotionCuePlayer` is the stand-in listener: a Node with `composition` (empty listens to
every composition through the bus), `sounds` (cue name, `prefix*` or `*` → AudioStream;
exact match first, then the longest prefix), `volume_db`, `bus`, `voices`,
`play_reversed` and `stop_on_sync` (stop sounding voices on seek and stop). Intensity sets
the volume (linear) and `data.volume_db` / `data.pitch` adjust it. Signal
`played(cue, player)`.

## MotionSvg (Node2D) and MotionSvgData (Resource)

Import an `.svg` as **Motion SVG** (Import dock → Import As), or build one with
`MotionSvgData.from_string(text)` / `from_file(path)`; `MotionSvgData.load_any(path)` loads
the imported resource when there is one, else parses the .svg (one call for pieces that
must work either way). `data.contours(parts, k=1, tl=ZERO, tolerance=0.25, clean=false)`
flattens one part index or a list of them into world-space polygons (`svg * k + tl`);
`clean` drops a repeated closing point and degenerate contours.

`MotionSvgData`: `view_box`, `parts` (tag, id, classes, groups, fill, stroke, bbox, cubic
contours), `find(name)` (by id, class or group id), `sorted_by_x()`, `centre(i)`,
`outline(i, tolerance)`, `to_svg_string()`, `warnings`.

`MotionSvg`:

| Member | Notes |
| --- | --- |
| `data`, `width` | Width in pixels; the viewBox top-left sits at the node origin. |
| `only`, `crop`, `stretch_h` | Subset of parts; the logo region that maps to `width` (like a viewBox, nothing is clipped); a stretched strip. |
| `apply(fn)` | `fn(i) -> Dictionary` per part. `part_fn(i, f)` is the per-frame variant. |
| part keys | `tx ty s sx sy rot pivot o fill stroke stroke_width draw draw_width fill_o hide`, plus `blur` (Vector2 standard deviation in logo units, an SVG `feGaussianBlur`) and `blur_region` (Rect2 filter region as fractions of the part's bounds) |
| `chromium_draw` | Reproduce Chromium's dash quirk when porting Remotion pieces (see the porting guide). |
| `oversample`, `prewarm()`, `clear_cache()` | Raster density and cache control. |

Rasters are made for the node's on-screen scale, separately per axis (a logo stretched 5×
vertically gets 5× the density down, not across), and re-made when the scale moves into
another density step.

Single-colour parts are rasterized white by Godot's own ThorVG and tinted, so recolouring
them costs nothing; parts with both a fill and a stroke, or a gradient, keep their own
colours and `fill` tints them. Rasters are cached in √2 size steps (densities include the
window stretch), shared between nodes, and evicted least-recently-used beyond
`MotionSvg.cache_budget` (256 MB); a raster the current frame draws stays alive until the
next draw even if the cache drops it. A raster is capped at 4096 px a side: past that the
part is drawn from a lower-density raster rather than cropped. Rasters are stored with
premultiplied alpha, so filtering leaves no dark fringe where a part lies over its own
colour; `MotionSvg.default_material()` (set on every node) un-premultiplies them, and a
`material` of your own must do the same. Outlines are live anti-aliased polylines. `modulate.a`
applies to each part separately, so overlapping parts show through each other while a
logo fades. For CSS `opacity` on a wrapper (one composited layer), put the `MotionSvg` in
a `CanvasGroup` and fade the group's `self_modulate.a`. `MotionSvgData.from_file()` needs the raw .svg, so it is for tools;
games `load()` the file imported as Motion SVG.

## MotionText (Node2D)

`text`, `font`, `font_size`, `color`, `tracking` (em, CSS letter-spacing), `line_height`
(multiple of the size; 0 = the font's own), `align` with `box_width`, `visible_chars`,
`uppercase`. Per-glyph overrides via `apply(fn)` / `glyph_fn(i, f)` with
`tx ty s sx sy rot o color hide`. The origin is the top-left of the line box, as for a CSS block.
`stroke_width` / `stroke_color` are CSS `-webkit-text-stroke`: a stroke centred on each
glyph's outline, painted over all the fills (a transparent `color` gives outline-only
type). Widths snap to half pixels; animate scale rather than the width. `get_text_size()` gives the width (including tracking after the last character, as CSS
does) and the line-box height; `get_baseline()` the distance from the top to the first
baseline, for CSS `align-items: baseline` layouts.

Animate a text's `scale`, not its `font_size`: each new size rasterizes new glyphs.

`vertical = true` is CSS `writing-mode: vertical-rl`: glyphs stand upright in columns that
run top to bottom and right to left, using the font's vertical forms (the long-vowel mark
turns, small kana shift). `box_width` becomes the available column height; text wraps
between characters and never starts a column with punctuation, a small kana or a long-vowel
mark (Japanese kinsoku), as browsers do. The column is as thick as the horizontal line box,
with glyphs centred on it. All glyphs stand upright, as with `text-orientation: upright`.
Where no legal break exists, the column overflows, as in a browser.

Line boxes follow Chromium: with `line_height = 0` ("normal") each line is as tall as the
largest ascent plus descent among the faces its glyphs actually use (a fallback face only
counts when one of its glyphs is on the line), and each face's ascent and descent are
rounded to whole pixels, as Chromium rounds them. FreeType rounds those metrics up, so the
kit recovers the exact values from several large sizes and rounds them itself.

`MotionFonts.font(path, msdf=false, fallbacks=[])` loads ttf/otf/woff/woff2 with browser-like settings
(no hinting, sub-pixel positioning). MSDF keeps glyphs sharp while they scale up, but
small sizes can show corner artefacts, so it is off by default. `fallbacks` (Fonts tried
for missing glyphs, e.g. a Japanese subset) give a font of its own per combination: never
assign `.fallbacks` on a font from `MotionFonts`, it is shared with every other caller of
that file (before this, two pieces' fallbacks could overwrite each other by load order).

`MotionText.make(parent, font, size, col, text, tracking=0, pos=ZERO)` is the one-line
factory (adds the node to `parent`).

`MotionFonts.draw_screen_text(c, xf, font, pos, text, size, col, align, ladder=1.06,
min_px=0, width=-1, anchor=0, screen_scale=0)` draws canvas text rasterised at its
on-screen size (measured from `xf`, or `screen_scale`), snapped to a geometric `ladder` of
sizes so a zooming camera reuses glyph rasters; `MotionFonts.ladder_size(px, ladder,
floor_steps)` is the snap alone. MotionExtrude.draw_text (ladder 1.06) and
MotionMetroMap.label (1.08) use it; MotionGreebler's stencils use the ladder.

`MotionPill`: text on a rounded background with CSS-style padding and an optional
`border_width` / `border_color` (outside the padding). Its origin is the centre, so
scaling pops it in place; `get_box_size()` gives the outer size.

## MotionShape (Node2D)

`kind` = CIRCLE, RECT, RING or ARC; `size`, `color`, `radius` (corner; `size.y/2` gives a
pill), `thickness`, `sweep_from`/`sweep_to` (turns from 12 o'clock), `dashes`,
`dash_fill`, `blur` (a CSS box-shadow blur radius, standard deviation = blur / 2; exact
Gaussian for square rects; for `filter: blur(x)` pass `2 * x`), `border_width` and
`border_color` (a CSS border inside the edge), `anchor` (where the origin sits on the
shape). `MotionShape.circle(d, col)` and `pill(w, h, col)` are shortcuts.

## MotionGradient (Node2D)

A `size` rectangle (origin top-left) filled with a CSS gradient. `kind` = LINEAR (`angle`
in CSS degrees: 180 is top to bottom, 90 left to right), RADIAL (an ellipse through the
farthest corner from `center`, as `radial-gradient(ellipse at …)`), CONIC (from 12
o'clock) or STRIPES (`repeating-linear-gradient`: `positions` in pixels, the last one
is the repeat length). `colors` and `positions` hold up to 8 stops. `shift` is CSS
`background-position` in pixels, so animating it scrolls stripes. `blend` = NORMAL, ADD,
MULTIPLY, SCREEN or OVERLAY blends with what is drawn behind it (CSS `mix-blend-mode`);
`opacity`. Shortcuts: `MotionGradient.linear(size, angle, colors, positions)`,
`stripes(...)`, `radial(size, colors, positions, at)`.

RINGS draws `ring_count` concentric circle strokes (`ring_width` px wide, radii
`ring_r0 + i * ring_gap` about `ring_center`, in `colors[0]`), optionally clipped to a
circle of radius `ring_clip`: a stack of SVG `<circle>`s in one quad, anti-aliased in
screen space, so a moiré of 90 rings over 90 rings costs two quads.
`MotionGradient.rings(size, center, col, width, gap, count=90, r0=6)`.

Blend modes read the backdrop of the viewport they draw in. To blend with only part of
the scene (an isolated CSS stacking context), put the group in a `MotionFX`.

## MotionCanvas (Node2D)

Immediate-mode drawing for one frame. Set `draw_fn = func(c: MotionCanvas, f: float)`;
it runs whenever the frame changes. Helpers: `line(a, b, col, w, opacity)`,
`dashed(a, b, col, w, dash, gap, opacity)`, `polyline(pts, col, w, opacity, closed)`,
`polygon(pts, fill, stroke, w, opacity)`, `circle(c, r, fill, opacity)`,
`ring(c, r, col, w, opacity)`, `ellipse(c, rx, ry, col, w, opacity)`,
`rect(r, col, opacity, w)`, `dashed_polyline(pts, col, w, dash, gap, offset, opacity)` (SVG
`stroke-dasharray` with `stroke-dashoffset`; the pattern runs on around corners). Lines thinner than a pixel draw at 1 px with their width as
alpha, as a browser rasterizes them. Each call's `opacity` applies to that shape alone;
for a group's opacity use `modulate.a` on the canvas. The helpers are `MotionMarks`'
primitives, which draw into any CanvasItem.

## Paths, polygons, marks and tape: MotionPath, MotionPoly, MotionMarks, MotionTape

Shared geometry and loop-built graphics. Before these existed, MotionFlow, MotionCable,
MotionMetroMap, MotionTextPath, MotionFaceLights and FTFKit each measured paths their own
way, five classes had their own signed area and point-in-polygon, and the FTF pieces
drew chevrons, hatching and tape with private helpers. Those now delegate here; their old
methods still work (marked Deprecated where a direct replacement exists).

### MotionPath (RefCounted, `core/motion_path.gd`)

A measured polyline: `MotionPath.new(points, closed := false, f32_sum := false)`.
Arc lengths are pixels; fractions are 0..1 of `length`.

| Member | Notes |
| --- | --- |
| `points`, `lengths`, `length` | The polyline, cumulative lengths (one more entry when closed), total |
| `closed`, `wrap`, `extend` | `closed`: an implied segment back to the start, arc lengths wrap. `wrap`: wrap without the implied segment (a path that already ends at its start). `extend`: open paths run straight on past their ends instead of clamping |
| `point_at(s)`, `point_at_fraction(u)` | Position |
| `tangent_at(s, window)`, `tangent_at_fraction(u, window)` | Chord over ±window px (smooth through corners); `Vector2.RIGHT` where there is no direction |
| `direction_at(s)` | Direction of the segment holding s (turns at each point) |
| `index_at(s)`, `segment_count()` | Segment lookup (binary search) |
| `sub(a, b, before)`, `sub_fraction(a, b)` | The part between two arc lengths: the end points plus every point between. `before` picks the segment ending at an exact point hit (MotionFlow's convention) |
| `sub_clean(a, b, min_step, min_span)` | `sub` for thick strokes: drops points closer than `min_step` (MotionCable's tube) |
| `nearest(p)` | Arc length of the nearest path point |
| static `cumulative(pts, closed, f32_sum)`, `polyline_length(pts)` | Measuring without an object |
| static `point_on(pts, lengths, closed, s)`, `tangent_on(...)` | MotionTextPath's model on raw arrays (wrap when closed, extend when open) |
| static `slice(pts, a, b)`, `slice_fraction(pts, a, b)` | One-walk sub-path of an unmeasured polyline |
| static `rounded(pts, r, seg, merge_straight)` | Corners replaced by a `seg`+1-point curve of radius r (FTFKit/MotionFlow style) |
| static `arc_corners(pts, radii)` | True circular arcs, one radius per corner (MotionMetroMap's bends) |
| static `round_polygon(poly, r, samples)`, `rounded_rect(rect, radius, seg)` | Closed shapes with soft corners (signs, tape frames) |
| static `offset(pts, d)` | Sideways copy, miter-compensated so a band keeps its width through bends |

`f32_sum` sums lengths in single precision as they are stored (MotionTextPath's model, kept
so text placed along a path does not move); `length` is the last cumulative length and
may be set to a more precise total (MotionMetroMap does).

### MotionPoly (static, `core/motion_poly.gd`)

| Function | Notes |
| --- | --- |
| `area2(p)`, `signed_area(p)` | Shoelace sum (positive = counter-clockwise with y up, clockwise on screen) |
| `bounds(p)`, `bounds_all(contours)` | Bounding rectangles (`Rect2()` when empty) |
| `contains(contours, pt, evenodd)` | Nonzero (default) or even-odd fill rule by edge crossings |
| `count_containing(contours, pt, skip)` | How many contours contain pt (`Geometry2D`); odd = inside under even-odd |
| `prepare(contours)`, `contains_prepared(prepared, pt)` | Even-odd tests against contours with cached bounds (MotionGreebler) |
| `contour_inside(a, b)`, `hole_flags(contours, majority)` | Nesting: a contour inside an odd number of others is a hole; `majority` tests most of its vertices, false only the first |
| `rect(r)`, `chamfered_rect(r, c)` | Builders |

### MotionMarks (static, `shapes/motion_marks.gd`)

Every mark takes a `CanvasItem` first (a MotionCanvas, a node's `_draw`, a MotionExtrude or
MotionGreebler decal callback) and has an `opacity` argument.

| Function | Notes |
| --- | --- |
| `line`, `polyline`, `polygon`, `rect`, `circle`, `ring`, `fade`, `thin` | MotionCanvas's primitives as statics (MotionCanvas now calls these) |
| `chevrons(c, origin, n, h, col, phase, dir, on, opacity)` | A marching row; `phase` 0..1 moves one slot, `on` grows the row |
| `chevron_row(c, at, n, h, col)`, `chevron_up(c, apex, w, col)`, `chevron_strip(c, rect, n, col)`, `arrow(c, at, s, col)` | Compact decal marks (no triangulation check, cheap in bulk) |
| `checker(c, pos, cols, rows, cell, col, on, seed)`, `hatch(c, area, spacing, width, col, angle, shift)`, `barcode(c, rect, col, seed, on, opacity, vertical)` | Fields and fills; `on` reveals |
| `xbox`, `crosshair`, `plus`, `rect_pts` | Registration marks |
| `ribbon(c, pts, width, col, a, b, round_ends)`, `stripe_bundle(c, pts, widths, cols, gap, a, b)` | Bands along a path from fraction a to b |
| `triangle(centre, h)`, `warning_triangle(c, centre, h, fill, ink)` | ISO 7010-style sign frame |
| `hazard_clamp(c, corner, sx, sy, arm, thick, col_a, col_b)`, `barrier(c, pivot, angle, length, thick, col_a, col_b, ink, ground)` | Hazard furniture |

### MotionTape (static, `shapes/motion_tape.gd`)

Tape along any path, as a Dictionary spec posed per frame: `MotionTape.pose(spec, f)` then
`MotionTape.draw(c, spec, pose, f, opacity)`. Spec keys: `a`/`b` or `pts`/`closed`, `width`,
`style` (`stripes`, `solid`, `text`), `col_a`, `col_b`, `period`, `duty`, `slant`, `scroll`,
`at`, `dur`, `out` (`follow`, `back`, `tear`), `out_at`, `out_dur`, `tear`, `wave_amp`,
`wave_len`, `wave_decay`, `wave_speed`, `seed`. The pose holds `path` (a MotionPath), `pts`,
`lengths`, `closed`, `total` and `pieces`; give a MotionTextPath `pose.pts` to set text on
the tape. `edge(pose, s, side)` and `edge_run(...)` place things across it.

## Travel tables: MotionTravel (RefCounted, `core/motion_travel.gd`)

Distance over time, tabled once in `_build()` so every frame is a lookup (a camera flying
a track, a pump's spin). Entry i is the distance at frame i; `at(f)` interpolates.

| Member | Notes |
| --- | --- |
| static `from_speed(fn, size, substeps=8, precise=false, midpoint=true)` | Integrate `fn(f)` (units per frame) on `substeps` midpoint slices per frame (`midpoint=false`: left sum, e.g. one sample a frame). |
| static `from_keys(keys, values, size, easing=ease_in_out, substeps=8, precise=false)` | The speed as `MK.interp` keys. |
| static `from_anchors(frames, distances, size, precise=true)` | A monotone (Fritsch-Carlson) cubic through hand-placed (frame, distance) anchors: passes each landmark on its frame, never overshoots; linear past the last. |
| static `keyed_speed(pairs, f)` | Speed from `[[frame, speed], ...]`, smoothstepped between pairs (a speed function for `from_speed`). |
| `at(f)`, `speed(f)`, `frame_speed(f)` | Distance; speed (the function, or the table's slope for anchors); speed sampled at whole frames at table precision (speedometers, motion blur). |
| `extrapolate`, `end` | Outside the table clamp (default) or run on at the end speeds: `f * speed(0)` before 0, `at(end) + (f - end) * speed(end)` after `end`. |
| `precise` | Float64 table (long tracks) instead of Float32. |

## City plans: MotionCityPlan (RefCounted, `city/motion_city_plan.gd`)

A procedural machine city as plain data, so the same lots feed the 2.5D look (MotionExtrude)
or real 3D (MotionFlat3D). Plan space is x east, y north, z up, one unit per lot. Every
choice is the pure lot hash `rand(i, j, key) = MK.rand(i * hash_i + j * hash_j + key * hash_k + seed)`,
so call order never matters.

```gdscript
var plan := MotionCityPlan.new()
plan.grid = Rect2i(0, 0, 24, 14)
plan.skip = [Rect2i(0, 0, 11, 5)]                       # a plaza
plan.prepare = func(cell: Dictionary) -> void:
	if cell.j <= 1: cell.force = "low"                   # low front rows
for cell in plan.build():
	var parts: Array = cell.parts
	var sol := plan.solids(cell, func(s: MotionSolid, mat: String) -> void: _paint(s, mat))
	for n in sol.size():
		if parts[n].role == "shaft": sol[n].add_decal(Vector3(0, -1, 0), _face)
		scene.add(sol[n])
# or in 3D: MotionCityPlan.to_flat3d(cell, surfaces_by_mat, key, edges)
```

| Member | Notes |
| --- | --- |
| `grid`, `skip`, `include` | Lots to plan (rows outer), rects left out, optional `func(i, j) -> bool` filter. |
| `street_every`, `street_at` | Per-axis street period and phase (`posmod(i, every.x) == at.x`); street lots get kind `"street"`, no parts. |
| `seed`, `hash_i`, `hash_j`, `hash_k` | The hash (defaults 0.7, 13.13, 71.7, 5.31). `rand(i, j, k)`, `pick(i, j, k)` (material), `is_street(i, j)`. |
| `materials`, `mat_split`, `mat_key` | Names light → dark (grammar uses [0] light, [1] accent, [2] neutral, [3] dark) and the picker thresholds. |
| `kinds`, `kind_split`, `empty_below`, `kind_key` | `r < empty_below` is empty, else first `kinds[n]` with `r < kind_split[n]`, else the last. Built in: tower, block, silos, ramp, stack, rack, low. |
| `prepare` | `func(cell)` before the kind draw: set `force` (a kind, never empty), `cap` (height cap), `h_range` ([base, span] main height) or own fields. |
| `shape` | Overrides of `SHAPE` (the grammar's numbers: ranges `[base, span, key]`, chances `[threshold, key]`, offsets, sizes, segments). Doubles only. |
| `builders` | `kind -> func(plan, cell, o)` to add or replace a kind with `add_box`/`add_cylinder`/`add_pipe`/`add_wedge` and `local(x, y, z)`. |
| `corner`, `corner_inset`, `y_dir` | Lot frame: corner `o = (i + corner[0] + corner_inset[0], j + ...)`, local y times `y_dir` (-1: lots laid out southwards from their north-west corner, as y-up builders do). |
| `build()`, `plan_lot(i, j)`, `cells` | Records `{i, j, kind, mat, r, h, top, cap, forced, corner, parts}`; parts `{type, role, mat, stack, at, size / r, h / to, len / w, h0, h1, seg, plain}`. |
| `solids(cell, paint)`, static `solid(part)` | 2.5D: one MotionSolid per part in order (`paint(s, mat)` then `plain` parts lose their outline). |
| static `to_flat3d(cell, surfaces, key, edges=null, col)`, static `to_y_up(p)` | 3D: parts into `surfaces[mat]` (MotionFlat3D builders) with outlines; plan → y-up is `(x, z, -y)`, exact. |

Decals and dressing stay in the piece, keyed on `cell.kind` and `part.role` (shaft, cap,
mast, tank, vent, deck, silo, ramp, step, post, pipe). Megastructure and Time City use the
defaults (Time City overrides segment counts); Canyon passes its own thresholds, numbers,
street rule and a y-down lot frame and gets the same parts its y-up builder made.

## Offscreen rendering: MotionOffscreen (static, `core/motion_offscreen.gd`)

The setup every node that renders a CanvasItem subtree into a texture first shares
(MotionFX, MotionTiling and MotionGlyphField masks, MotionPlate, MotionWarpField,
MotionTimeSplit, MotionTimeSlices, MotionTimeCache, MotionDecalAtlas, MotionPanel3D):

```gdscript
content = MotionOffscreen.holder("Content")
_vp = MotionOffscreen.make(self, content)               # in _init
MotionOffscreen.fit(_vp, size, render_scale)           # in _resize (and _ready)
MotionOffscreen.gate(_vp, is_visible_in_tree())        # in _process / _frame
```

| Function | Notes |
| --- | --- |
| `make(owner, content=null, mode=UPDATE_ALWAYS, filter=-1, px=(-1, -1), internal=INTERNAL_MODE_FRONT) -> SubViewport` | A transparent, 2D-only SubViewport holding `content`, added to `owner` as an internal child. `filter`: a `Viewport.DefaultCanvasItemTextureFilter` (-1 keeps the default); `px`: its size, if known. |
| `viewport(mode, filter, px) -> SubViewport` | The same, not added anywhere. Viewports render in the order they were created: when the content holds offscreen nodes of its own (a time effect's copies), create the viewport first, then the content. |
| `holder(name) -> Node2D` | A named content root. |
| `pixels(size, scale=1, round_px=true) -> Vector2i` | `size * scale`, rounded (or truncated), at least 1×1. |
| `fit(vp, size, scale=1, round_px=true)` | Size the viewport to `pixels(...)` and scale its canvas by `scale` (only possible in the tree; call it again from `_ready`). |
| `gate(vp, on) -> bool` | Render every frame while `on`, not at all otherwise; true when the mode changed. |

## Shader includes

| Include | Holds |
| --- | --- |
| `shaders/motion_noise.gdshaderinc` | `mk_hash21(p, s)`, `mk_vnoise2(p, s)`, `mk_hash31(p, s)`, `mk_vnoise3(p, s)`, `mk_fbm3(p, s, octaves, lacunarity, shift)`: the kit's hash and value noise with the seed term `s` passed in, so each shader keeps its own constants (`mk_hash21(p, seed * 0.618)` in static and tiling, `seed * 0.1234` in paper, plate and glyphs, `mk_hash31(p, seed * 0.0137)` in the warp field). |
| `shaders/motion_sun.gdshaderinc` | The banded OutRun sun: `sun_band_cut(v, bands, aa)`, `sun_tint(v, bottom, top)`, `sun_glow_k(ang, radius)`; each caller keeps its own antialiasing (screen pixels on the planes, `fwidth` on the sky dome). |
| `plane/motion_pattern.gdshaderinc` | Box-filtered `checker`, `band` (`box_int`), `lines`, `dots` (MotionPatternPlane, MotionPlaneScan, MotionPattern3D). With `#define MK_PLANE` before it, also the plane model the two plane shaders share: `cam_to_world`, `plane_hit`, `ground_coord`, the ring, `pattern_colour`, `accent_lanes` and `plane_sky`. |

## MotionCells (Node2D)

A grid of palette-coloured cells drawn from one byte per cell in a single quad: cellular
automata, LED boards, pixel mosaics, minimaps. `columns`, `rows`, `cell_size`, `inset`
(gap inside each cell edge; fractional insets are anti-aliased exactly, so 1.5 gives the
half-covered edge pixels of an SVG `<rect x="1.5">`), `palette` (up to 16 colours, index 0
never drawn), `grid_color` / `grid_width` (lines on every boundary; crossings compound
like overlapping rects), `cells` (row-major `PackedByteArray`; setting it re-uploads the
small state texture only), `get_cell(x, y)`, `set_cell(x, y, v)` (uploads once at the end of
the frame). An indexed write `cells[i] = v` doesn't run the setter: call `refresh()` after
editing the array in place. Values past the palette draw nothing.

## Effects

- `MotionFX`: children placed under it in a scene move into `content` when the game runs
  (in the editor they draw without the effects). It renders `content` offscreen, then applies `set_slices(amount, split, count, seed)`
  (offsets identical to the SCF `Sliced`), `brightness`, `pixel_size`, `goo_blur` and `goo_sharp`.
  `invert` is CSS `filter: invert()`, 0 to 1.
  Raise `render_scale` for 4K output. Its `modulate` is the group's opacity and tint
  (one composited layer, like CSS `opacity` on a wrapper).
  - Blur family, sharing one separable Gaussian pass: `blur` is CSS `filter: blur()`
    (the value is the standard deviation, σ); `glow` (σ) and `glow_strength` draw a
    blurred copy in the content's own colours under it (an SVG `feMerge` glow);
    `shadow_color`, `shadow_blur` and `shadow_offset` draw a tinted blurred copy under it,
    with `shadow_blur` a CSS `text-shadow` / `box-shadow` radius (σ = radius / 2). Because
    the pass is shared, set only one of them per `MotionFX`; nest two for both.
  - SVG goo: `alpha_matrix` (Vector2) is the alpha row of an `feColorMatrix` applied after
    the blur (alpha · x + y, e.g. `Vector2(26, -11)`); `flood_color` then fills the result
    (`feFlood` + `feComposite in`), or leave it transparent to keep the blurred colours.
    `source_atop` draws the unblurred content over that goo, clipped to it
    (`feComposite in="SourceGraphic" operator="atop"`): crisp shapes that melt into each
    other where the goo bridges them, each keeping its colour.
  - The content is clipped to `size`, so give blurred content room (CSS doesn't clip).
    `MotionFX` scaled by its parent scales its blur with it, as CSS does for a filter
    under a transform.
- `MotionOverlay`: `kind` = STATIC (reseeds every frame, `opacity`) or CRT (scanlines,
  rolling band, vignette).
- `MotionPixelGrid`: `MotionPixelGrid.cells_from_svg(data, cols, palette)`, then `set_grid()`.
  Use `show_fn(i)` for build-ins and `recolor` to swap colours.

## Game layer

- `MotionSpring.new(initial, damping, stiffness, mass)`: set `target`, call `step(delta)` every
  frame. Stepping matches `MK.spring` exactly. `snap(v)`, `is_settled()`.
- `MotionReactive`: put it under a Control, including Controls inside Containers. It
  handles `hover_scale`, `focus_scale`, `press_scale`, `hover_offset`, `hover_tint`,
  `damping` and `stiffness`. Position is only touched when `hover_offset` is set, and any
  move made by layout or your code becomes the new rest position.
- `MotionTransition` (autoload): `await change_scene(path_or_packed, style, origin)`,
  `await cover(style)`, `await uncover(style)`. Also `colour`, `bar_colours`, `frames`,
  `busy`, and signals `covered` and `finished`. Styles: `circle`, `bars`, `clock`, `fade`,
  `glitch`, `crt` (an unknown name warns and fades).

## Added with the FTF intro takes

New techniques built for the five Full Throttle Flux intro takes; each has a working example in `demo/ftf/`.

### Time displacement and slit-scan: MotionTimeSlices

From the FTF intro take `demo/ftf/ftf_slitscan/` (notes: `demo/ftf/ftf_slitscan/KIT_NOTES.md`).

`MotionTimeSlices`: the content (a `MotionComposition`, from `scene` or a `builder`
Callable) is instanced once per band, and each band shows it at `f - delay(band)`.

| Member | Notes |
| --- | --- |
| `scene: PackedScene`, `builder: Callable` | The content, instanced once per band (`builder.call()` must return a `MotionComposition`). It draws on the parent's timeline and must accept negative frames. |
| `size` | Area the bands cover, and the content's reference size (1920×1080). |
| `layout` | `ROWS`, `COLUMNS`, `BOXES` (nested boxes about the centre, drawn outside in: a square tunnel), `CHANNELS` (three full-frame copies tinted R, G, B and added: a time-split chromatic fringe). Changing it, `bands`, `size` or `scene` rebuilds the bands. |
| `bands` | Number of bands (CHANNELS is always 3). |
| `delay` | Frames the most delayed band lags. Animate it to 0 for a sharp picture. |
| `profile` | How the delay spreads across the bands: `LINEAR`, `REVERSE`, `CENTRE`, `EDGES`, `SINE` (`waves`, `phase`), `RANDOM` (`seed`; `seed_value` is a deprecated alias), `CUSTOM` (`profile_fn(u) -> 0..1`, u = 0..1 across the bands). |
| `step` | Quantise each band's delay to steps of this many frames (stutter). |
| `slit` | 0 = each band shows its own place (time displacement); 1 = every band shows the slit (slit-scan: streaks). In between the bands unfold from the slit. |
| `slit_pos`, `slit_width` | Where the slit is across the bands (0..1: COLUMNS x, ROWS y) and how much of the content each band shows at `slit = 1` (pixels; for BOXES the width of the centre box). Narrower than the band, it is stretched: streaks. |
| `box_power` | BOXES spacing: box k is scaled `(1 - k / bands) ^ box_power`. |
| `reveal`, `reveal_from` | Show only the bands within `reveal` (0..1 of the bands) of `reveal_from`; hidden bands cost nothing. Opens a streak field out of the slit. |
| `band_rects()`, `source_rect(k)`, `profile_at(u, k)`, `rebuild()` | Helpers. |

How it stays frame-pure: each band's instance is a nested composition whose `start` is
set to the band's delay in `_frame(f)`, just before the parent's frame walk reaches it,
so the walk renders it at `f - delay`. Nothing is kept between frames: seeking renders
pixel-identical frames to playback (checked on the FTF take), reverse and scrubbing work.

Cost: every band renders into its own SubViewport the size of the band, with the
content shifted to the band's source rectangle, and a `Sprite2D` draws the band with a
region (stretched when the slit is narrower than the band). Rows or columns cost one
frame of fill in total plus the content's script cost once per band; BOXES costs the
sum of the box areas (about `bands / (2 p + 1)` frames for `box_power` p); CHANNELS
three frames. Hidden bands and hidden nodes stop rendering, and their instances return
at once from the frame walk. In the FTF take (160 + 160 columns, 14 boxes, 3 channels
built; 160 live at a time) a full Movie Maker render runs at about 0.38 s a frame
under Xvfb software GL on 2 cores.

Limits: the content is instanced per band, so keep it light (one logo, a few canvases);
`source_rect` is clamped to the band size (a slit wider than its band is not
compressed); BOXES needs opaque content (inner boxes cover outer ones); CHANNELS needs
content on an opaque dark background (it adds).

### 2.5D extrusion: MotionExtrude, MotionSolid, MotionExtrudeCamera

From the FTF intro take `demo/ftf/ftf_megastructure/` (notes: `demo/ftf/ftf_megastructure/KIT_NOTES.md`).

#### MotionExtrudeCamera (RefCounted)

An orthographic camera. World axes: x east, y north, z up.

| Member | Notes |
| --- | --- |
| `yaw`, `pitch` | Degrees. Yaw 0 looks north from the south; pitch 0 is a flat front elevation, 35.26 with yaw 45 is true isometric, 90 is a plan. Blending both to 0 turns an iso view into a perfectly flat front view. |
| `target`, `scale`, `centre`, `roll` | The world point drawn at `centre`, pixels per world unit, screen roll in degrees. |
| `update()` | Recompute the basis (`right`, `up`, `forward`, `forward_h`). `MotionExtrude.prepare()` calls it. |
| `project(p)`, `vec(v)`, `depth(p)`, `ground_key(p)`, `facing(n)` | World point → screen; world direction → screen vector; distance into the scene; painter's key on the ground plan; whether a normal faces the camera. |
| `to_lens(screen=(1920, 1080)) -> MotionLens3D` | The orthographic MotionLens3D that draws this exact view (yaw, pitch, roll, scale, centre) of a MotionStage3D scene: `to_lens().project(MotionLens3D.from_extrude(p)) == project(p)` (tested). |
| `plane_transform(origin, a, b)` | The Transform2D that maps a plane's local (x, y) to the screen: for drawing into a face, or setting on a node (a MotionSvg on a face). |

#### MotionSolid (RefCounted)

A 2D outline in a plane (`origin` + a·`u` + b·`v`) extruded along n = u × v by `depth`.

| Member | Notes |
| --- | --- |
| `outline` / `set_outline(pts)` | Outer contour (any winding; made CCW). Holes are not walled. |
| `origin`, `u`, `v`, `depth` | Floor solids use u = x, v = y (n up); south-facing walls use u = x, v = z (n points at the camera). |
| `top`, `lit`, `dark`, `cap`, `smooth`, `paint(t, l, d)` | Face colours by normal: up-facing, facing the scene light, facing away; `cap` overrides both caps; `smooth` blends sides by angle (cylinders). |
| `outline_color`, `outline_width`, `stroke(c, w)`, `opacity` | Edge strokes per face. |
| `draw_front_cap`, `draw_back_cap`, `visible` | |
| `clip_z` | Cut everything below this height: solids rise out of (or sink into) the ground by moving `origin.z`. |
| `sort_key`, `sort_at`, `stack`, `layer` | Painter's key override; the ground point to key on (give a block and its roof tanks the same point); tie-break within one footprint; a free tag for draw filters. |
| `add_decal(face, fn)` | Draw in a face's plane right after it: `face` = `"front"`, `"back"` or an outward normal (`Vector3(0, -1, 0)` = the south walls). `fn(c, size, solid, xf)` gets the face size in decal units (100 per world unit) and its transform. Decals skip faces cut by `clip_z`, so markings appear once a face is fully out. |
| `box(pos, size)`, `cylinder(base, r, h)`, `pipe(start, r, length, axis)`, `wedge(pos, length, width, h0, h1)` | Shapes. |
| `from_svg(data, part, k, at, u, v, depth)` | A slab from an SVG part's largest contour (SVG top-left at `at`, `k` world units per SVG unit, SVG y down along −v). Sets `data.svg_k` for `cap_transform`. |

#### MotionExtrude (RefCounted)

| Member | Notes |
| --- | --- |
| `camera`, `solids`, `add(s)`, `light`, `top_threshold`, `min_area` | |
| `prepare()` | Once per frame after setting camera and solids: updates the camera and sorts. |
| `draw(canvas, filter = Callable())` | Draw the prepared solids (those `filter(solid)` accepts) into a MotionCanvas. Several canvases with filters interleave solids with other nodes (an SVG on a cap between the city behind and the city in front). |
| `draw_solid(canvas, s)` | One solid: visible sides far to near, then the visible cap, with decals. |
| `cap_transform(s)`, `cap_polygon(s)`, `cap_unclipped(s)` | Put a MotionSvg on a `from_svg` solid's cap (set the MotionSvg's `width` to the viewBox width and its `transform` to `cap_transform`); while the solid is cut by the ground, draw `cap_polygon` into a `clip_children` MotionCanvas holding the MotionSvg, and turn the mask off once `cap_unclipped` (the mask edge is aliased). |
| `draw_text(c, xf, font, pos, text, size, col)` (static) | Text in a face plane rasterized at its on-screen size (sharp at any zoom, no MSDF corner artefacts). |
| `clip_above(pts, h)` (static) | Sutherland–Hodgman cut of a planar 3D polygon at a height. |

**Frame purity.** Nothing persists between frames: the piece sets every solid's
position, depth and colours from `f`, `prepare()` re-sorts from scratch, and
the canvases redraw. Seeking, scrubbing and reversing work.

**Ordering.** Solids sort by their ground key along the camera's horizontal view
direction (far first), then `stack`, then height; inside a solid the visible
sides draw far to near and the facing cap last. Exact for solids on a grid that
don't overlap in plan, seen from above the horizon with the camera on one side
(yaw within ±90). Solids spanning many cells (signs, walls, a logo slab) go in
their own canvases between filtered city layers.

**Cost.** Take 2's city is 647 solids (24 × 14 cells plus the monument), about
2,500 visible faces and up to ~150 text decals a frame. Measured on the shared
2-core VM: the piece's `_frame` (positions, heights, sort) 8–10 ms; drawing every
solid 36–76 ms, roughly half of it decal text. Culling (`cull_rect`), skipping
decals on faces under `min_decal_area` and text under `min_text_px`, and snapping
text raster sizes to a 6% ladder (so a zooming camera reuses glyphs) took the draw
from 55–95 ms to that. Offline it renders at ~0.4 s a frame under software GL.
For a live menu background, use fewer cells or bake the city's far layers.

### Print: MotionPlate, MotionPaper

From the FTF intro take `demo/ftf/ftf_riso/` (notes: `demo/ftf/ftf_riso/KIT_NOTES.md`).

#### MotionPlate (Node2D)

Put what the plate prints under `content`, drawn in **black on transparent**: black prints
solid ink, greys print a tint (`ink = alpha − luma` of the premultiplied render), and white
**knocks out** (a white shape over a black one leaves paper). The plate renders offscreen
and is drawn back with `blend_mul`, so plates **overprint** each other and the paper the way
transparent inks do. Draw plates over an opaque backdrop (a `MotionPaper`), not inside a
transparent `MotionFX`.

| Member | Notes |
| --- | --- |
| `size` | Plate (content) size in pixels, usually the frame. |
| `ink`, `density`, `tone_scale` | Ink colour; how much ink is laid (0..1, animate to fade a plate in); a multiplier on the content's ink amount (draw black, set 0.4 for a 40% tint). |
| `misregister`, `misrotate` | Registration error in pixels and degrees about the plate's centre. The halftone screen moves with the plate. |
| `cell`, `angle_deg`, `dot` | AM halftone: cell in pixels (0 = solid ink), screen angle, `Dot.ROUND / LINE / SQUARE / DIAMOND`. Dot size comes from the tone at each cell's centre; dots are clipped to the artwork's own edge, so solids keep crisp outlines. |
| `roughness`, `grain`, `mottle`, `seed` | Ragged edges (pixels), speckles where ink missed (0..1), uneven laydown (0..1), noise seed. All static. |
| `slur`, `slur_amount` | A doubled ghost image (press slur / second impression). |
| `roll`, `roll_dir`, `roll_soft`, `roll_shadow` | The press roller: ink only where it has passed (0..1 along `roll_dir`), with a ragged edge `roll_soft` px wide and a shadow band at the roller while it moves. |
| `content` | Where to add what the plate prints. |
| `static register(f, settle_at, error, snap=3) -> Vector2` | Holds `error` until `settle_at`, then snaps into register over `snap` frames with a small overshoot. Multiply a rotation by `register(f, at, Vector2(1, 0)).x`. |
| `static print_in(f, at, frames=10) -> float` | Roller progress for a plate printed at `at`. |
| `static thunk(f, ats, amp=4, dur=6) -> Vector2` | A press judder (alternating vertical offset) for a parent node. |

A hidden plate stops rendering its content (its SubViewport stops updating).

#### MotionPaper (Node2D)

A `size` rectangle (origin top-left) of paper: seeded mottling, tooth (`grain`), `fibres`,
`edge_shade`, plus a blurred drop `shadow` under the sheet. Static; move the node to feed
sheets through a press.

Each plate is one full-frame SubViewport plus one fragment shader pass (two texture
reads for halftone, a few value-noise lookups). Hidden plates cost nothing. The FTF Riso
piece has up to 15 plates on screen during the sheet change and renders under Xvfb
software GL at roughly real-time ÷ 6–8 on two shared cores. Everything is a function of the
plate's properties, which the piece sets from `f`; all noise is seeded and static, so
scrubbing, seeking and reverse are exact.

### 3D in compositions: MotionStage3D, MotionSvgMesh, MotionPanel3D

From the FTF intro take `demo/ftf/ftf_gantry/` (notes: `demo/ftf/ftf_gantry/KIT_NOTES.md`).

#### MotionStage3D (Node2D)

| Member | Notes |
| --- | --- |
| `size`, `render_scale`, `msaa`, `transparent` | Output size in composition pixels; internal resolution; MSAA for 3D; let 2D drawn earlier show through |
| `world: Node3D`, `camera: Camera3D`, `environment: Environment`, `viewport: SubViewport` | Put 3D content under `world`; Node3D children authored under the stage in a scene move there at runtime. Nodes with `_frame(f)` under `world` are reached by the composition like any other |
| `set_camera(xform, fov)` | Place the camera (vertical FOV in degrees) |
| `night(sky, fog, fog_density, glow)` | Background, exponential fog and HDR glow in one call |
| `to_screen(p) -> Vector2`, `in_front(p)` | Project a world point into composition pixels (pin 2D callouts to 3D objects) |
| static `path_frame(curve, s, height, side) -> Transform3D` (track builders: `MotionTrack3D`) | The frame of a Curve3D at distance s: -Z along travel, Y = the curve's up vector with tilt (banking); continues straight past the ends |
| static `ride(curve, s, height, look_ahead, look_height, side)` | A camera riding a curve, looking a set distance ahead |
| static `look(from, to, up, roll)`, `blend(a, b, t)` | Look-at transform; position-lerp / rotation-slerp between two camera transforms |
| static `unlit(tint, energy, dim) -> ShaderMaterial` | The kit's flat 3D material. Parameters: `tint`, `energy` (above 1 glows), `lit_from`/`lit_to`/`lit_soft`/`dim` (UV2.x window: a light chase or a moving light trail) |

#### MotionSvgMesh (static)

| Member | Notes |
| --- | --- |
| `build(data, width, opts) -> ArrayMesh` | Every part extruded: front cap (+Z), back cap, side walls; one surface. `opts`: `depth`, `tolerance`, `anchor`, `layer` (z step per part), `side_shade`, `only`, `part_fn(i) -> {hide, color, side_color, back_color, depth, z}`, `uv2_x(i, uv) -> float` |
| `append(st, data, width, opts, xform)` | The same into an open SurfaceTool (merge logos into larger meshes) |
| Vertex data | COLOR = part colour (sides darker), UV = viewBox position 0..1, UV2 = (UV.x, part index) |
| Holes | A contour inside an odd number of the part's other contours (majority of its vertices inside) is a hole; caps cut each hole open with a hairline slit so Godot's ear-clipper sees simple polygons; side walls follow the true contours. Triangles are not consistently wound: use a material with culling off (`unlit()` is) |

#### MotionPanel3D (MeshInstance3D)

| Member | Notes |
| --- | --- |
| `pixel_size`, `world_size` | Panel resolution and quad size (quad in local XY, facing +Z) |
| `canvas: Node2D` | Put kit 2D nodes here; (0,0) is the top-left pixel |
| `energy`, `tint`, `background` | Brightness (above 1 glows), tint, fill behind the content |
| `animated`, `refresh()` | Re-render every frame, or once (static boards are cheaper) |

- Nothing integrates at runtime: the camera's distance along the circuit is a table
  built once from a speed profile (integrated on eighths of a frame) and looked up by
  frame; materials and camera are set from `f` only. Seeking, scrubbing and reverse work.
- Geometry is built once (about 25 ms for an extruded logo of ~7k vertices); the
  circuit, gantries, tunnel and skyline are merged into a few ArrayMeshes, one per
  material, so a frame is about a dozen draw calls plus one viewport per panel.
- Software GL (llvmpipe, 1920×1080, MSAA 4x, glow, 2 shared cores): about 0.65 s a
  frame, 4.5 minutes for the 420-frame piece. Static panels use `animated = false`.

### Glyph fields: MotionGlyphField

From the FTF intro take `demo/ftf/ftf_glyphfield/` (notes: `demo/ftf/ftf_glyphfield/KIT_NOTES.md`).

#### MotionGlyphField (Node2D)

A grid of cycling glyphs drawn in one quad. Each cell picks its glyph from a hash of
(cell, time step) at its own seeded rate; its brightness and colour come from a
**mask**: anything added under `mask_content` is rendered offscreen and read back per
cell (five taps for coverage, the centre tap for colour), so logos and type appear as
dense, bright glyphs. A glyph atlas is drawn once from `font` and `charset` at the cell
size, so glyphs stay crisp; it stops updating after a few frames.

| Member | Notes |
| --- | --- |
| `size`, `cell`, `font`, `charset`, `glyph_scale`, `font_scale`, `seed` | Field size, cell size (px), glyph source, glyph size in its cell, atlas font size as a share of the cell, hash seed. |
| `dim_range`, `lit_range` | `Vector2i(start, count)` into `charset` for the dim field and for lit cells (count 0 = all). Put thin glyphs in one, dense glyphs and blocks in the other. `glyph_index(ch)` finds a character. |
| `cycle_min`, `cycle_max`, `lit_cycle` | Glyph changes per frame, per cell, between min and max; lit cells multiply by `lit_cycle`. |
| `mask_content` | Node2D inside the mask viewport: add logos, text, shapes, a `MotionCanvas`. Its colours become the lit glyphs' colours. `mask_scale` renders it smaller for speed. |
| `threshold`, `softness` | Cell coverage (0..1) at which a cell lights. Draw a part of the mask at low opacity to keep it out of the glyphs (and still in `solidify`). |
| `reveal`, `reveal_sweep`, `reveal_angle` | Share of lit cells shown: a seeded dissolve (`reveal_sweep = 0`) or a straight sweep along the angle (1). |
| `lit_color`, `tint`, `lit_level` | Override the mask colour (`tint` 1) and dim the lit layer. |
| `lit_fill`, `lit_invert`, `ink_color` | Lit cells get a filled block in their colour; `lit_invert` stencils the glyph out of it in `ink_color` (terminal-highlight look, much more legible). |
| `base_color`, `base_density`, `base_level`, `base_flicker` | The dim field: colour, share of cells showing a glyph, brightness, seeded blinking. |
| `base_color_b`, `base_front`, `base_front_jitter` | Cells left of `base_front` (px) take `base_color_b`: a moving colour front. |
| `scroll`, `rain`, `rain_var` | Grid offset; rain moves columns down at their own speeds while the mask stays put (glyphs pass through the logo). |
| `fall_t`, `fall_g`, `fall_spread` | Gravity: frames since the fall began (< 0 off), px/frame², per-column delay. Falling cells carry their mask brightness, so a lit logo falls apart column by column. |
| `hot_color`, `scan_y`, `scan_w`, `scan_gain` | A horizontal band that lights and whitens the glyphs it passes. |
| `ring_c`, `ring_r`, `ring_w`, `ring_gain` | A ring (radius < 0 = off): a shockwave through the field. |
| `solidify`, `solidify_noise`, `solidify_sweep` | Cells switch from glyphs to the solid mask (randomly, or outwards from `ring_c`); at 1 the mask is shown whole, so a logo condenses into its real vector form. |
| `level` | Overall opacity. |
| `frame` | Set by `_frame(f)`; drives cycling, rain and blinking. |

Frame-pure: every animated value is a uniform written in `_frame(f)`; glyph steps are
`floor(f * rate + phase)` and every random choice is a hash of the cell index, so
scrubbing, seeking and reverse are exact. Cost: one quad with ~6 texture taps per pixel,
one field-sized mask viewport (skipped while the field is hidden), and the atlas drawn
for its first few frames. Under software GL a 1920×1080 field with an 18 px cell plus a
second 54 px field renders the FTF take at roughly the same speed as the first intro.

## Added with the FTF title takes

New techniques built for the eight titled Full Throttle Flux intro takes; each has a working example in `demo/ftf/`.

### Warp fields: MotionWarpField

From the FTF intro take `demo/ftf/ftf_lsd/` (notes: `demo/ftf/ftf_lsd/KIT_NOTES.md`).

New files: `addons/motion_kit/warp/motion_warp_field.gd` (`class_name MotionWarpField`,
`@tool`, extends `Node2D`) and `motion_warp_field.gdshader`. No existing kit file was
changed.

#### API (rows for docs/API.md)

`MotionWarpField`: a procedural colour field and/or an offscreen content layer, drawn in
one quad, both pushed through a seeded analytic domain warp, palette-cycled,
kaleidoscoped and mirrored in a rippling horizon.

| Member | Notes |
| --- | --- |
| `size`, `seed`, `render_scale`, `level` | Quad size (origin top-left), noise seed, content viewport density, overall opacity (premultiplied; `modulate` also applies). |
| `draw_field` | Draw the procedural field (off for a content-only layer). |
| `centre` | Centre of rings, rays, the sun, the iris, the shockwave ring and the kaleidoscope. |
| `rings`, `rays`, `stripes` | Weights of concentric rings, radial rays and horizontal stripes; mix them (rings + rays = spirals; rays under a kaleidoscope = petals). |
| `freq`, `phase`, `twist`, `steps` | Bands per 1000 px (rays: per turn); scroll in bands (animate for flowing bands, kick it on beats); ray twist with radius; posterize into hard anti-aliased bands (1 = one colour per band). |
| `field_level`, `iris`, `iris_soft` | Field brightness; show it only within `iris` px of `centre` (a bloom from the sun, or a closing iris). |
| `ring_r`, `ring_w`, `ring_gain`, `ring_color` | A bright ring about `centre` (radius < 0 = off): shockwaves. |
| `sun_r`, `sun_color`, `sun_color_b`, `sun_slits`, `sun_slit_scroll`, `sun_glow` | A disc at `centre` with a top-to-bottom gradient and 70s cut lines across its lower half; it warps with the field. |
| `pal_a`, `pal_b`, `pal_c`, `pal_d`, `set_palette()` | Cosine palette a + b cos(2π(c t + d)). |
| `pal_shift`, `pal_spread` | Cycle the palette (animate it); palette cycles per band. |
| `gradient`, `lut_mix`, static `bands_gradient(colors, hard)` | A Gradient LUT (repeats) blended in over the cosine palette; `bands_gradient` builds hard-step gradients from colour lists. |
| `content` | Node2D rendered offscreen (full `size`): add a MotionSvg, MotionText, shapes. Hidden or empty content costs nothing. |
| `content_warp`, `content_melt`, `content_chroma`, `content_level` | px of liquid displacement, px of downward drip (columns of varying length), px of RGB split, opacity of the content. Animate them to 0 to set a logo solid. |
| `warp`, `warp_scale`, `warp_speed` | px of two-level domain warp on the field, px per noise cell, noise drift per frame. |
| `kaleido`, `segments`, `kaleido_spin` | Blend (0..1) into a kaleidoscope about `centre`; the fold happens before the warp, so the liquid structure itself becomes the mandala. |
| `horizon`, `ripple`, `reflect_dim`, `horizon_glow`, `horizon_color` | Below `horizon` (px) the scene mirrors as rippling water, darker with depth; a glowing horizon line. Content above the horizon is reflected too; content below it is never drawn directly, so a logo moved up through the horizon surfaces out of the water. |

Frame purity: everything is a uniform; `_frame(f)` sets `time`, which drives the noise
drift and the water ripples. The noise is seeded value noise, the warp analytic (no
feedback buffer), so seeking, scrubbing and reverse are exact.

Cost: one full-quad fragment pass. The field costs about 18 value-noise lookups a
pixel with the warp on (two fbm levels, three octaves); the content layer is one
SubViewport the size of the quad (skipped while hidden or empty) and one to three
texture reads. The FTF LSD Sunrise take (one field + two content layers, 1920×1080)
renders at about 0.45 s a frame under Xvfb software GL on 2 shared cores.

Limits: one kaleidoscope centre and one horizon per node; `steps` bands alias a little
where the warp folds bands very tightly; content outside the quad is clipped before
the warp pulls it in, so keep warped content inside `size`.

### Transit maps: MotionMetroMap

From the FTF intro take `demo/ftf/ftf_subway/` (notes: `demo/ftf/ftf_subway/KIT_NOTES.md`).

New file: `addons/motion_kit/metro/motion_metro_map.gd` (`class_name MotionMetroMap`,
`@tool`, extends `RefCounted`). No existing kit file was changed.

#### API (rows for docs/API.md)

`MotionMetroMap` holds the geometry of a transit diagram; the piece draws it into a
`MotionCanvas` from its `draw_fn`, choosing per line how much is drawn each frame.
Node (x, y) sits at `origin + Vector2(x, y) * cell` pixels.

| Member | Notes |
| --- | --- |
| `cell`, `origin` | Pixels per grid unit; pixel position of node (0, 0). |
| `spacing`, `width` | Distance between parallel lines in a shared corridor; default line width. |
| `radius`, `min_radius`, `jog_radius` | Bend radius of a corridor's centreline in cells (lines inside a bend get less, outside more, so bundles bend concentrically); smallest radius in px; radius of the 45-degree jogs a line makes when its slot changes. |
| `casing`, `casing_color` | Background-coloured casing either side of each line (crossings interrupt, as on printed maps); 0 = none. |
| `add_line(id, color, waypoints, opts) -> int` | A line through grid waypoints, routed octilinearly between them. `opts`: `mode` (`"diag"` diagonal first, `"straight"`, `"mid"`), `width`, `order` (bundle order), `bundle` (false = never offset into corridors), `shift` (Vector2 px, e.g. a stacked-layer look), `closed`, `radius` (cells), `meta`. |
| `add_path(id, color, points, opts) -> int` | A line along a ready-made pixel path (a logo contour, a hand-drawn route): not bundled or rounded. `opts`: `width`, `closed`, `shift`, `meta`. |
| `build()` | Route, bundle (each corridor's lines sorted by `order`, offset by `spacing`), offset (miters at turns, 45-degree jogs on slot changes), round (circular arcs) and measure every line. Call once. |
| static `route(a, b, mode)`, `canonical_route(a, b, mode)` | Octilinear node path between two nodes; the canonical form takes the same nodes whichever way it is travelled, so opposite-direction lines share a corridor. |
| `length(i)`, `path(i)`, `point_at(i, s)`, `dir_at(i, s)`, `sub_path(i, a, b)`, `s_near(i, p)` | Arc-length queries (pixels; closed lines wrap). `measured(i)` returns the line as a `MotionPath`. |
| `corridor(a, b)`, `node_point(i, k)`, `points_at(node)` | Lines in a corridor; where line i passes its k-th node; every line's position at a node. |
| `draw_line(c, i, a, b, opacity, w_scale, col, with_casing)` | Draw line i from fraction a to b (draw-on and retract). |
| `draw_span(c, i, sa, sb, col, w)` | A stretch by arc length, no casing, wrapping on closed lines: light chases, highlights, expresses. |
| `draw_train(c, i, s, len, col, w, outline)` | A capsule following the line, centred at arc length s. |
| `draw_terminus(c, i, at_end, len)`, `draw_tick(c, i, s, side, len)` | Terminus bar; station tick on one side. |
| `draw_interchange(c, node, s, r, fill, outline, pts)` | A white capsule with an outline joining every line at a node, scaled by `s`. |
| static `label(c, font, pos, text, size, zoom, col, align, min_px)` | Text rasterized at its on-screen size (size snapped to a 1.08 ladder so a zooming camera reuses glyphs), so labels stay sharp at any zoom; labels under `min_px` on screen are skipped. |

**Frame purity.** Everything is computed once in `build()`; drawing only reads cached
arrays, and the piece passes each line's fractions, train positions and opacities from
`f`. Seeking to frames 230 and 352 gave renders within one 8-bit level of the
straight-through render.

**Cost.** Build: about 0.3 s for the FTF take (140 lines, about 1,300 stations, 140
logo contour paths). Per frame, the piece's `_frame` is under 0.2 ms; drawing is a
couple of `draw_polyline` calls per visible line plus ticks, labels and trains, culled
to the view by the piece. The full 420-frame Movie Maker render ran at about 0.23 s a
frame under Xvfb software GL.

**Limits.** Bundling keeps a global order per corridor, not across turns, so lines can
cross where corridors meet (as in "insane" maps; a real map would need an ordering
solver). Line reversals (a route doubling back on itself) are left as spikes; avoid them
in the waypoints. `draw_interchange` joins the two farthest points, so very spread
interchanges become long pills.

### Greebles: MotionGreebler

From the FTF intro take `demo/ftf/ftf_greebles/` (notes: `demo/ftf/ftf_greebles/KIT_NOTES.md`).

New file: `addons/motion_kit/greeble/motion_greebler.gd` (`class_name MotionGreebler`,
`@tool`, extends `RefCounted`). Pure GDScript, no shaders. No existing kit file was changed.

#### API (rows for docs/API.md)

`MotionGreebler` builds seeded panel trees inside shapes and draws them, in screen space,
through a scale + origin camera (`screen = world * s + origin`). Each item fades in by its
size on screen, so pushing a camera in resolves secondary panels and then tertiary greebles
out of bold shapes, and pulling out makes them read clean again.

| Member | Notes |
| --- | --- |
| `add_block(poly, depth, opts) -> id` | An extruded polygon (the bold shape: face plus sides seen along `extrude_dir`) with panels and greebles inside it. |
| `add_rect(rect, depth, chamfer, opts) -> id` | `add_block` of a rectangle with 45-degree chamfered corners (`chamfered(r, c)` gives the polygon). |
| `add_sides(contours, depth, opts) -> id` | Only the extruded sides of a shape whose face is drawn by something else (a `MotionSvg` logo on top). Contours are even-odd, so letters with holes work. `detail = true` also greebles its face. |
| `add_detail(contours, opts) -> id` | Panels and greebles inside a shape, no base: greeble a logo's face. |
| `add_item(id, kind, rect, level, extra)` | One hand-placed item (`Kind.HAZARD`, `STENCIL` with `txt` and `c`, `LIGHT`...). |
| opts | `seed`, `max_level`, `min_size`, `greeble_chance`, `rest_chance`, `raise_chance`, `depth_k` (bevel depth), `first_level`, `avoid` (contours kept clear, e.g. a logo's letters) + `margin`; per structure `face`, `side_lit`, `side_dark`, `haze` (added), `lod` (multiplier on `lod_px`: above 1 keeps a structure clean until the camera is closer). |
| `set_offset(id, v)`, `set_visible(id, on)`, `set_opacity(id, a)` | Move (doors, clamps), hide or fade a structure per frame (`set_alpha` is the deprecated name of `set_opacity`). |
| `draw(canvas, s, origin, f, view)` | Draw everything into any CanvasItem (call from a `MotionCanvas` draw_fn). |
| Generation | `max_level`, `min_size`, `split_chance[level]`, `inset_chance`, `raise_chance`, `rest_chance` + `rest_levels` (plain plates at the top levels: areas of rest), `greeble_chance`, `stencils`. |
| Look | `face`, `tone_jitter`, `bevel_light`, `bevel_shade`, `recess`, `recess_deep`, `seam`, `side_lit`, `side_dark`, `pipe`, `accent`, `accent2`, `ink`, `lamp`, `lamp_alt`, `lamp_off`, `extrude_dir`, `font` (stencils). |
| Draw controls | `lod_px` / `lod_band` (screen size at which items start / finish fading in), `haze_color` + `haze` (aerial perspective, negative values also lerp), `reveal[level]`, `reveal_origin` / `reveal_front` / `reveal_soft` (a growing radius: a cascade of detail), `lamp_level`, `lamp_period`. `stats_drawn` after a draw. |
| Greeble kinds | `PANEL` (raised or recessed, bevelled, seamed), `VENT`, `GRILLE`, `BOLTS`, `PIPE` (with collars), `LIGHT` (seeded blink), `FAN` (turning), `HAZARD`, `STENCIL`, `BOXES`, `SLOT` (lamps in a slit), `CHEVRON`. Counts are fixed at build so nothing pops while zooming. |

Frame purity: structures are built once; `draw()` reads only its arguments and the public
controls, and lamps and fans are functions of `f`. Seeking renders the same frame as playback.

Cost: building is the expensive part (the FTF take builds about 100,000 items across six
greeblers in ~3 s at scene load: subdivision tests rectangles against even-odd contours).
Drawing culls whole structures by bounds, skips whole levels once their largest item is
below `lod_px` on screen, and culls items to the view, so a frame draws a few thousand items
(tens of ms in GDScript). Stencil text is drawn at its on-screen size (snapped to an 8 %
ladder, so a zoom reuses glyphs). For a live menu, build fewer levels or bake far layers.

Limits: panels are axis-aligned rectangles (a rotating camera means rotating the canvas);
a block's face must be a simple polygon (no holes; use `add_sides` + an SVG for logos);
the extruded sides are a fixed oblique projection along `extrude_dir`, not real 3D.

### Cables: MotionCable, MotionCableSet

From the FTF intro take `demo/ftf/ftf_cables/` (notes: `demo/ftf/ftf_cables/KIT_NOTES.md`).

New in the Cables take. Two classes, both `@tool`, pure GDScript (draw calls, no
shaders). No existing kit file was changed.

| File | Class |
| --- | --- |
| `motion_cable.gd` | `MotionCable` (RefCounted): one cable's description and its built curve |
| `motion_cable_set.gd` | `MotionCableSet` (extends MotionCanvas): draws cables as glossy shaded tubes in depth order, plus connector and socket helpers |

#### API

##### MotionCable (RefCounted)

A thick cable along a route of waypoints. Set its properties from `f`; a
`MotionCableSet` builds and draws it.

| Member | Notes |
| --- | --- |
| `points` | Route waypoints in pixels (≥ 2). The curve is a centripetal Catmull-Rom spline through every one (no cusps or loops where long and short spans meet, which a thick tube would turn into spikes). |
| `pinned` | false (default): the whole route hangs as one span between its ends: sag and wobble use one envelope over the route. true: every waypoint is a pin (hook, clip, the edge of a plate it wraps) and each span sags and wobbles on its own. |
| `tension`, `sag`, `sag_ref`, `gravity` | 0 = slack, 1 = taut. Sag in pixels for a span `sag_ref` px long (longer spans sag more, clamped ×0.15–3). Animate `tension` with a spring to pull a cable taut on a beat. |
| `tugs`, `static tug(at, amp, period, decay)` | Damped wobbles across the chord starting on frame `at` (pixels, frames per swing, frames to 1/e). A twang when a plug lands, a twitch on an accent, a whip when it's yanked. |
| `start` (alias `reveal_from`), `reveal` | The drawn part, 0..1 of the length. Grow `reveal` to snake a cable in head first along its route; shrink it to pull it back out the way it came. The head connector rides the `reveal` end. |
| `width`, `jacket`, `edge`, `gloss`, `light` | Tube diameter; body colour; rim colour (alpha 0 = jacket darkened); specular strength; direction towards the light (the highlight stays on the lit side as the cable turns). |
| `bands`, `stripe_every`, `stripe_len`, `stripe_color`, `stripe_phase` | Jacket bands `[{u, len, color}]` and repeating stripes, shaded like the tube. |
| `pulses` | Light pulses `[{u, len, color, power}]` drawn as glowing segments: animate `u` for current running along the cable. |
| `glow`, `glow_color` | A powered halo around the tube (0..1). |
| `glint` | A specular hotspot at u (< 0 off): slide it for a wet sheen. |
| `plug_head`, `plug_tail` | `Plug.NONE / JACK / MULTIPIN / BLADE / BARREL`. |
| `plug_color`, `plug_band`, `plug_lit`, `plug_light` | Connector housing, ID ring (alpha 0 = jacket), indicator brightness and colour. |
| `static plug_length(kind, width)` | Rear-to-front length of a connector: put a route's last point `plug_length` behind a socket so the plug lands in it. |
| `z`, `z_ranges` | Depth; `[[u0, u1, z], ...]` overrides it on parts of the route, so a cable weaves over and under other cables or nodes. |
| `shadow`, `shadow_offset`, `opacity`, `layer` | Drop shadow (alpha 0 = none), fade, free tag for filters. |
| `build(f)`, `curve()`, `length()`, `point_at(u)`, `tangent_at(u)`, `sub(a, b)`, `pieces()` | Build the curve for a frame (cached while nothing changes), then query it: pin labels or particles to a cable with `point_at`. `path()` returns the built curve as a `MotionPath`. |

##### MotionCableSet (MotionCanvas)

| Member | Notes |
| --- | --- |
| `cables` | The cables to draw. Sets may share cables. |
| `z_min`, `z_max` | Draw only the parts of cables within this depth window. Put one set below a node and one above it, and give cables `z_ranges`, to wrap cables round a logo (front spans over it, back spans under it). |
| `shadows`, `filter` | Shadows on/off; `Callable(cable) -> bool`. |
| `static draw_plug(canvas, kind, pos, dir, width, housing, band, lit, light, op)` | A connector anywhere, rear at `pos`, pointing along `dir`. |
| `static draw_port(canvas, pos, dir, width, lit, led, op)` | A face-on panel socket with a chrome bezel and an LED ring. |

Each cable part draws: its shadow; a glow halo if powered; the tube (rim, body,
lit side and a specular line, offset towards the light); bands and stripes;
pulses; the glint; its connector. Parts sort by depth, then cable order.

#### Frame purity

Nothing persists between frames: the piece sets every cable property from `f`;
tugs are closed-form damped sines of `f - at`; `build(f)` recomputes the curve
from the properties (it caches only while the key, which includes `f`, is
unchanged). Seeking, scrubbing and reverse are exact.

#### Cost

A cable part is about 6–9 `draw_polyline` calls over its samples (18 per span by
default), plus one per band, stripe and pulse. The FTF take draws up to ~20
cables (6 hanging in the back, 6 wrapping with ~25 spans each, 8 suspension
lines) and renders at roughly the speed of the first FTF intro under software GL.
Wrapped cables with many short spans: lower `samples` (8 is plenty).

#### Limits

- Depth ordering is per cable part, not per pixel: two parts at the same depth
  that cross draw in cable order.
- `z_ranges` are fractions of the built curve's length; the piece computes them
  from waypoint chord lengths, which is close enough when the switch happens at a
  bend (an edge the cable wraps round).
- A bend tighter than the tube's own radius overlaps itself and shows spikes
  (a real cable can't bend that tight either): give U-turns a radius of at least
  the cable width, as the wraps in the FTF take do (a 4-point arc, 2.8 × width).
- Shadows are drawn under each part, so a cable's shadow can fall on cables
  drawn before it but not on nodes outside its set.

### Flow and liquid: MotionFlow, MotionLiquidFill

From the FTF intro take `demo/ftf/ftf_fuel/` (notes: `demo/ftf/ftf_fuel/KIT_NOTES.md`).

New in the Fuel Lines take. Two classes, pure GDScript, no shaders; no existing
kit file was changed.

| File | Class |
| --- | --- |
| `motion_flow.gd` | `MotionFlow` (Node2D): fluid flowing along a network of pipes |
| `motion_liquid_fill.gd` | `MotionLiquidFill` (Node2D): content revealed below a sloshing liquid surface |

#### API

##### MotionFlow (Node2D)

A network of thick paths drawn in one `_draw`. Pipes are built once; every
frame you set each pipe's state (how far the fluid has got, how far it has
drained, how far its contents have moved), and the pipe draws wall, core,
fluid, pulses, bubbles and a bright travelling front from that state alone.

| Member | Notes |
| --- | --- |
| `add_pipe(points, opts) -> int` | A pipe through `points` (local px). `opts`: `width`, `wall_width`, `radius` (corners rounded once at build), `segments`, `wall`, `core`, `fluid`, `pulse` (pulse colour), `caps`, `arrows` (spacing of flow arrows on the core, 0 = none), `arrow_color`. Use `width` with `wall_width = 0` and transparent wall/core for pulses alone (a light chasing round an outline). |
| `add_node(pos, radius, ring, fill) -> int`, `set_node(i, {o, lit})` | Fittings and junctions drawn over the pipes. |
| `set_state(i, d)`, `apply(fn)` | Per-frame state; `apply(func(i): return {...})` like `MotionSvg.apply`. Unset keys reset to defaults. |
| `state_fn(i, f) -> Dictionary` | Optional: set it once and the flow applies it to every pipe in its own `_frame(f)` (manual `apply` / `set_state` still work). |
| state `draw`, `draw_from` (keys `reveal`, `reveal_from` too) | 0..1 of the wall drawn (a pipe tracing itself; un-drawing from its start). |
| state `fill`, `drain` | 0..1 fluid front and tail along the pipe: animate `fill` 0→1 for fuel arriving, `drain` 0→1 for a line emptying behind it. |
| state `flow` | px the contents have moved; drives pulses and bubbles. `f * speed` for a steady flow, a stepped/eased beat count for pumped flow. |
| state `pulse_len`, `pulse_gap`, `pulse_gain`, `pulse_color` | Slugs of brighter fluid moving with the flow. |
| state `glow`, `front_glow`, `bubbles`, `bubble_speed`, `bubble_color`, `fluid`, `opacity` | Halo strokes round the fluid, a bright bead on the travelling front, bubbles, per-frame colour override (purges, colour changes), opacity. |
| `length(i)`, `points(i)`, `point_at(i, s)`, `tangent_at(i, s)`, `path(i)` | Arc-length queries (px), to place valves, labels or sounds on a pipe; `path(i)` is the pipe as a `MotionPath`. |
| static `rounded(pts, r, seg)`, `sub_path(rec, a, b)` | Deprecated: `MotionPath.rounded`, `path(i).sub(a, b, true)`. |

##### MotionLiquidFill (Node2D)

A vessel (the rect 0..`size`) filling with liquid. Children of `fill` show only
below the surface, so a logo in its own colours fills up like a tank; children
of `surface` show only in a thin band at the surface (a lighter copy of the
logo makes a meniscus that follows the vessel's shape; with no children a plain
line is drawn).

| Member | Notes |
| --- | --- |
| `size`, `fill_level` | Vessel size; how full: 0 = surface at the bottom edge, 1 = at the top (above 1 = brim-full, surface out of sight; just under 1 keeps a sloshing band in the top). `level` is the deprecated name. |
| `tilt` | Surface slope (px, right end up). |
| `kicks` | Slosh impulses: `Vector2(frame, strength)` or `{at, amp, mode}` (mode 1 end-to-end, 2 central hump, default both). Pour, beat slaps, a slam. |
| `wave_amp`, `wave_freq`, `damping` | Slosh px per unit kick, angular frequency (rad/frame), decay per frame. |
| `ripple`, `ripple_len`, `ripple_speed` | Small travelling ripples always running. |
| `meniscus`, `meniscus_color` | Band thickness; plain line colour when `surface` is empty. |
| `bubbles`, `bubble_color`, `bubble_size`, `bubble_speed`, `seed` | Bubbles rising below the surface (`seed_value`: deprecated alias). |
| `foam`, `foam_color` | A row of small bubbles just under the surface (not drawn above a brim-full vessel). |
| `fill`, `surface` | Add content here. |
| `surface_y(x)` | Surface height (local px) at x, for placing things on it. |
| static `slosh(f, x01, kicks, amp, freq, damp) -> float` | The same slosh as a function, for vessels drawn in a canvas (sight glasses). |

Masks are drawn with draw calls on `clip_children` canvases, so they follow the
node's transform; the mask and band hide themselves when they would be empty
(an empty clip mask clips nothing).

**Frame purity.** Both are pure functions of the state set from `f`: the
surface is analytic (level, tilt, damped standing waves from the kick list,
travelling ripples), bubbles and foam are seeded by index and `f`, pipe
contents are positioned by arc length from `flow`. Nothing integrates between
frames. Pumped motion (pulses lurching on each beat) is a stepped, eased beat
count of `f`; a pump's rotation in the take is a running sum of its speed curve
built once into a table and looked up by frame. Frames reached by seeking match
the straight render.

**Cost.** MotionFlow: one `_draw`, a few polylines per pipe plus one per pulse
and bubble; the take's 9 pipes with pulses and bubbles are well under a
millisecond of script. MotionLiquidFill: one 64-point surface evaluated a few
times per frame (cost grows with the number of kicks, ~30 here) and two clip
canvases; the revealed content (a MotionSvg) draws twice (fill and meniscus
copy). The full take renders at about 0.28 s a frame under Xvfb software GL.

**Limits.** Pipe joins come from Godot's `draw_polyline`, so keep corners
rounded (the default radius) rather than sharp. The vessel is a rect: the
liquid follows its content's shape only because the content itself is the
shape (put the logo under `fill`). Slosh is a visual model, not a simulation.

### Text on a path and beacons: MotionTextPath, MotionBeacon

From the FTF intro take `demo/ftf/ftf_warning/` (notes: `demo/ftf/ftf_warning/KIT_NOTES.md`).

New files (no existing kit file was changed):

| File | Class |
| --- | --- |
| `addons/motion_kit/text/motion_text_path.gd` | `MotionTextPath` (Node2D): text set along any polyline, like SVG `<textPath>` |
| `addons/motion_kit/fx/motion_beacon.gd` | `MotionBeacon` (Node2D): a rotating beacon light (shader inside the script) |

The hazard tape itself (stripes in path space, torn ends, whip wave) started as a take
helper and is now the kit's `MotionTape` (`addons/motion_kit/shapes/motion_tape.gd`), built
on `MotionPath` in `MotionTextPath`'s arc-length model.

#### API rows (for docs/API.md)

##### MotionTextPath (Node2D)

Glyphs are shaped once with the font's fallbacks (as `MotionText` shapes them), then
each is placed at its own arc length on the path and turned to the path's direction.

| Member | Notes |
| --- | --- |
| `text`, `font`, `font_size`, `color`, `tracking` | As `MotionText` (tracking in em) |
| `points`, `closed` | The path in the node's space (sample curves finely); `closed` joins the ends and wraps arc lengths |
| `offset` | Where the text starts along the path, px. Animate it to scroll; any value works |
| `align` | `START`, `CENTER`, `END`: where a single copy sits relative to `offset` |
| `repeat`, `gap`, `fit_loop` | Tile the text along the whole path `gap` px apart; on a closed path `fit_loop` (default on) stretches the gap so whole copies fill the loop |
| `baseline`, `shift` | Baseline across the path in em (0.35 centres capitals on it; 0 sits the baseline on it); extra sideways shift in px (+ = right of travel) |
| `upright`, `flip` | Keep glyphs unrotated; turn them 180° |
| `show_from`, `show_to`, `edge_fade` | Only glyphs whose centre lies between these arc lengths are drawn (`show_to` < 0 = the end), fading over `edge_fade` px: text that appears with a tape being laid |
| `glyph_fn(i, s) -> Dictionary` | Per-glyph overrides `tx` (along), `ty` (across), `s`, `rot`, `o`, `color`, `hide`; `i` = character index, `s` = arc length |
| `get_text_width()`, `path_length()`, `point_at(s)`, `tangent_at(s)` | Measurements |
| `measured()` | The path as a `MotionPath` (closed paths wrap, open ones run straight on past their ends) |
| static `path_lengths(pts, closed)`, `path_point(pts, lengths, closed, s)`, `path_tangent(pts, lengths, closed, s, window)` | Deprecated: `MotionPath.cumulative(pts, closed, true)`, `MotionPath.point_on`, `MotionPath.tangent_on`. Open paths extend straight past their ends; tangents are chords over ±window so corners don't snap |

##### MotionBeacon (Node2D)

One quad over `size`, drawn additively, so the beams light whatever is under them.

| Member | Notes |
| --- | --- |
| `size`, `centre` | Area the light can reach (origin top-left) and the lamp position |
| `angle`, static `spin(f, period, phase, direction)` | Direction of the first beam (radians); `spin` gives the angle for a lamp turning once every `period` frames |
| `beams`, `beam_width`, `softness`, `lens` | 1–4 evenly spaced beams; half-angle (degrees) and soft share; beam width at the lamp (beams don't start as a point) |
| `reach`, `falloff`, `color`, `intensity` | Distance fade (px, power), colour, beam brightness |
| `core`, `core_intensity` | Lens glow radius and brightness |
| `flare_dir`, `flare_power`, `streak`, `streak_intensity` | The lens flares (glow, halo and a horizontal streak) as a beam swings to `flare_dir` (the viewer) |
| `squash` | Vertical scale of the beam field (< 1: light thrown across a floor or wall) |
| `level`, `blend` | Overall level (0 = off, not drawn); `ADD` (default) or `MIX` |

#### Frame purity

Every property is set from `f`: tape poses are recomputed each frame from their spec
(`pose(spec, f)`), text offsets are `speed × f`, beacon angles are `spin(f, ...)`
(piecewise after the escalation, continuous at the switch). Nothing is accumulated.
Checked by rendering frames by seeking and comparing them with the full render.

#### Cost

`MotionTextPath`: one TextServer glyph draw per visible glyph, two path look-ups per
glyph (binary search on the arc-length table). A 2000 px ticker at 30 px is ~150
glyphs. `MotionBeacon`: one full-frame quad with a 4-iteration loop per pixel.
The Warning take (up to ~20 tapes, 10 text paths, two beacons) renders in software GL
at well under 1 s a frame.

#### Limits

- `MotionTextPath` places glyphs by their centre on the path; on tight curves wide
  glyphs overhang (sample the path finely, keep the radius above ~2 font sizes).
- Text runs in the path's direction: a path drawn right to left puts the text upside
  down (reverse the points, or accept it on loops, as on a badge).
- `MotionBeacon` is additive light, not occlusion: beams pass through everything.

### Pattern planes: MotionPatternPlane

From the FTF intro take `demo/ftf/ftf_checkercity/` (notes: `demo/ftf/ftf_checkercity/KIT_NOTES.md`).

New files in `addons/motion_kit/plane/`: `motion_pattern_plane.gd` (`class_name
MotionPatternPlane`, `@tool`, extends `Node2D`) and `motion_pattern_plane.gdshader`.
No existing kit file was changed.

#### API (rows for docs/API.md)

`MotionPatternPlane`: an infinite patterned ground (and optional ceiling) seen through a
pinhole camera, ray-cast per pixel in one quad, with a sky, a banded OutRun sun, fog, bends
and a ring. Camera space: x right, y up, z forward; the camera sits at the origin `height`
above the ground.

| Member | Notes |
| --- | --- |
| `size`, `fov`, `principal` | Quad size (pixels, origin top-left), vertical field of view (degrees), principal point as a fraction of the size. |
| `pitch`, `yaw`, `roll`, `height` | Camera orientation (degrees; pitch up, yaw right, roll clockwise) and height above the ground. |
| `ground_offset` | (lateral, travel) in world units: flying forward is `ground_offset.y = distance(f)`. |
| `curve`, `channel`, `hill`, `wave` | Bends: the road turns (lateral shift `curve * z²`); the sides curl up (`y += channel * x²`, a half-pipe that becomes a tube); the ground ahead folds up into a wall (`y += hill * z²`); a sideways ripple (amplitude, frequency per unit of z, phase). The first three are intersected analytically. |
| `pattern`, `cell`, `cell_scroll`, `pattern_shift` | `CHECKER`, `STRIPES`, `GRID`, `DOTS`, `TEXTURE` (`texture`). `cell` is the cell size in world units: animate it to pulse the pattern about the camera; `cell_scroll` is the size the offsets scroll at, so the travel speed doesn't change with the pulse. `pattern_shift` in cells. |
| `color_a`, `color_b`, `line_width` | Pattern colours; GRID line width / DOTS radius as a fraction of a cell. |
| `accent_color`, `accent_every`, `accent_width` | A coloured lane every n cells along the travel (alpha = strength; the surface stays opaque). |
| `motion_blur`, `motion_blur_for(per_frame, shutter)` | Analytic motion blur: the pattern's box filter widens by the movement while the shutter is open (in cells), so fast travel smears along the motion instead of strobing or running backwards. |
| `fog_color`, `fog_range` | Fog toward the horizon: start and full distances. Set `sky_horizon` to the same colour for a seamless horizon. |
| `ceiling`, `ceiling_height`, `ceiling_a`, `ceiling_b`, `ceiling_alpha` | A second, flat patterned plane overhead (a checker sky), blended over the sky. |
| `draw_sky`, `sky_top`, `sky_horizon`, `sky_spread` | The sky gradient where rays miss every surface. |
| `sun_elevation`, `sun_azimuth`, `sun_size`, `sun_top`, `sun_bottom`, `sun_bands`, `sun_glow` | A sun fixed in the world (degrees), with a vertical gradient, OutRun bands cut across its lower part (count, scroll, top of the banded area) and a glow. |
| `clip` | Draw only surfaces whose forward distance is in [x, y). See "Sandwich layers". |
| `ring`, `ring_color`, `ring_push` | A ring on the ground (camera-relative centre x, z, radius, width): it tints the pattern and pushes it outward by `ring_push` cells (a shockwave through the floor). |
| `level`, `opacity` | `level` multiplies the colour (fade to black without transparency); `opacity` is the alpha. |
| `copy_from(other)`, `sync_now()` | Mirror every setting of another plane (a front layer); push the uniforms immediately (they are otherwise pushed once per frame, deferred). |
| `project(p) -> Vector3`, `to_camera(p)`, `scale_at(depth)`, `focal()`, `centre()` | The shader's camera in GDScript: a camera-relative world point to (screen x, screen y, depth); pixels per world unit at a depth (place 2D nodes facing the camera). |
| `ground_y(x, z)`, `ground_point(gx, z, up)`, `rel_z(world_z)`, `fog_at(dist)` | The ground's height with the bends; a point on the ground for a pattern-space lateral position (follows `curve`, `channel`, `hill`); an absolute travel position to camera-relative z; the shader's fog amount. |
| `draw_checker_box(c, x0, x1, z0, z1, h, cell, col, ink, side, side_tint, near_z=0.6, clip_side=false, min_px=4)` | A checker building on the ground: its inner side face (toward the road, tinted) and its front face when in front of `near_z`; `clip_side` starts the side at `near_z` (rolling cameras). |
| `draw_checker_quad(c, a, b, cc, d, cols, rows, col_a, col_b, min_px, near)` | Draw a planar quad of camera-relative corners into a `MotionCanvas` as a perspective-correct checkerboard (projected vertex by vertex), fogged like the plane, clipped at the near plane, falling back to one flat polygon when cells get smaller than `min_px`. Checker skyscrapers are two calls per building. |

##### Sandwich layers

Draw the plane twice: a full layer at the back, and a front layer (`copy_from` the back one,
`draw_sky = false`, `ceiling = false`, `clip = Vector2(-1e9, D)`). Anything drawn between them
standing at forward distance D is hidden where it goes below the ground, so a sign or logo
rises out of the floor or sinks back into it, and a monument rises over the horizon. Canvas
geometry nearer than D goes after the front layer; farther goes between the back layer and
the sandwiched sign.

##### Frame purity

Every property is set from `f`; the shader reads only uniforms and the pixel position.
Travel is a table built once from a speed profile (integrated on eighths of a frame) and
looked up by frame. In the FTF take, frames rendered by seeking straight to them match the
continuous render (checked at frames 100, 230 and 360).

##### Cost

One full-screen quad per layer: a ray-quadric intersection, a box-filtered pattern with
screen-space derivatives, fog, sky and sun. Under Xvfb software GL two full-screen layers,
up to ~50 checker buildings (about 2,000 small polygons drawn straight with
`draw_colored_polygon`) and the logos render at about 0.6 s a frame on the shared 2 cores.

##### Limits

- `wave` and `ring_push` move the pattern, not the geometry (they don't change the silhouette).
- `curve` is a shear of the pattern and of points placed with `ground_point`; it is not a true
  bend of the geometry, so it looks right for moderate values (OutRun roads).
- The ceiling is flat (no bends) and is skipped where the bent ground is nearer.
- Strong `channel` turns the floor into a parabolic tube centred on the camera, not a cylinder.
- `draw_checker_quad` cells are not antialiased: render with MSAA or supersampling if it matters.

### Tilings: MotionTiling

From the FTF intro take `demo/ftf/ftf_houndstooth/` (notes: `demo/ftf/ftf_houndstooth/KIT_NOTES.md`).

New files: `addons/motion_kit/tiling/motion_tiling.gd` (`class_name MotionTiling`,
`@tool`, extends `Node2D`) and `motion_tiling.gdshader`. No existing kit file was changed.

#### API (rows for docs/API.md)

##### MotionTiling (Node2D)

A full-frame tiling drawn in one quad. Each cell holds one tile of a motif; every cell
can rotate, scale, invert, switch colourway, switch motif and open up, driven by four
fields. Anything added under `mask_content` is rendered offscreen and becomes the MASK.

| Member | Notes |
| --- | --- |
| `size`, `cell`, `origin`, `angle`, `scroll`, `seed` | Field size; tile period in px; rotation centre; global rotation (degrees); offset in the tiling's own frame; hash seed. |
| `motif`, `motif_b` | `Motif.HOUNDSTOOTH` (woven as real 2/2 twill: 4 dark / 4 light threads in warp and weft, warp on top on alternate diagonals), `CHECKER` (2 × 2 per tile), `PINWHEEL`, `DOTS`, `CHEVRON`, `STRIPES`. `motif_b` is what the motif channel switches a cell to. |
| `ink_a`, `ink_b`, `alt_a`, `alt_b`, `alt_hard` | Motif and ground colours, and a second colourway the alt channel switches to; `alt_hard` (default true) switches each cell at once (crisp fronts) instead of blending. |
| `gap_color` | What shows where a cell's tile is smaller than the cell (rotated or shrunk tiles). |
| `mask_color`, `mask_ground`, `mask_ground_shade` | Inside the mask, the motif takes the mask's own colour; the ground takes it times the shade. Light parts of a logo weave light, coloured parts as a deeper weave of themselves, so the logo reads in the cloth. |
| `bulge_c`, `bulge_r`, `bulge` | Vasarely sphere: above 0 magnifies, below 0 pinches (−0.95..0.95). |
| `ripple_c`, `ripple_r`, `ripple_w`, `ripple_amp` | A radial ripple through the fabric (`ripple_r` < 0 = off). |
| `mask_content`, `mask_pixel`, `mask_warp`, `mask_scale` | The mask subtree; per-pixel mask edge (crisp letters made of cells, two cell evaluations per pixel) or per cell (stepped); sample the mask in the warped fabric (the shape bends with the cloth); mask render scale. |
| `halo_r` | Reach of the HALO field: the band just outside the mask. |
| `ring_c`, `ring_r`, `ring_w`, `ring_mode` | The RING field: `BAND` (a pulse), `DISC` (1 inside), `OUTSIDE`. `ring_r` < 0 = off. |
| `sweep`, `sweep_angle`, `sweep_w` | The SWEEP field: a straight front `sweep` px from the field centre along the angle; cells it has passed are 1. |
| `jitter` | 0..1 per-cell stagger of the ring and sweep fronts (cells flip one by one). |
| channels `rot_*`, `scale_*`, `inv_*`, `alt_*`, `clear_*`, `motif_*` | Each is `*_base + *_by · (mask, halo, ring, sweep) + *_and · (ring×mask, sweep×mask, ring×halo, sweep×halo)`. rot in radians, scale multiplies the tile (≤ 0 hides it), inv swaps motif and ground, alt switches colourway, clear makes the gap transparent (what's under the tiling shows through), motif > 0.5 switches to `motif_b`. The `and` terms gate a front by the mask or halo: "cells inside the logo vanish as the ring passes". |
| `by(mask, halo, ring, sweep)`, `gated(ring_mask, sweep_mask, ring_halo, sweep_halo)` (static) | Build the Vector4 weights. |
| `reset_channels()` | Every channel back to neutral; call at the top of `_frame` and set only what this frame needs. |
| `level` | Overall opacity. |

#### Frame purity, cost, limits

- Frame-pure: the shader reads only uniforms; the piece resets the channels and sets
  everything from `f` each frame; per-cell randomness is a hash of the cell and `seed`.
  Seeking matches playback (checked on the take).
- Cost: one full-frame quad; per pixel one or two cell evaluations (two with
  `mask_pixel` and a mask) and nine mask taps; the mask viewport renders at
  `mask_scale` (0.5 default) and stops while the tiling is hidden or has no visible
  mask. The take renders at about 0.3–0.5 s a frame in software GL on shared cores.
- Limits: a tile is clipped to its cell (a tile scaled above about 1.41 or rotated
  shows its own clipped square); the drivers are sampled at each cell's centre in the
  warped fabric, so under a strong bulge the halo and cell-based mask drift from an
  unwarped vector drawn under the tiling (keep bulges away from a parted logo, or set
  `mask_warp` while the logo is cloth); `mask_pixel` blends two cell results by the
  mask's coverage, so a soft mask edge shows both for a pixel or two.

## Added with the FTF mixture takes

New techniques built for the five mixture takes (Night Circuit, Time City, Through the Megastructure, Stargate Board, Assembly); each has a working example in `demo/ftf/`.

### Patterns and sky in 3D: MotionPattern3D, MotionSkyDome3D

From the FTF intro take `demo/ftf/ftf_nightcircuit/` (notes: `demo/ftf/ftf_nightcircuit/KIT_NOTES.md`).

The take mixes the Gantry take (a real 3D camera along a Curve3D in a
`MotionStage3D`) with Checkerboard City (`MotionPatternPlane`). Choice: the
checkerboard is **a pattern material on real geometry inside the stage**, not a
`MotionPatternPlane` layered behind it. Reasons: one camera, one depth buffer and
one fog for everything, so the FTF sign can rise out of the board (the board
occludes what is still under it), towers hide the board behind them, and the
board fogs into the horizon exactly like the track. No camera-sync helper is
needed. The cost is that the pattern plane's analytic bends (curve, channel,
hill, tube) are not available; a 3D take bends real geometry instead.

New files in `addons/motion_kit/three/` (no existing kit file was edited):

| File | Class / role |
| --- | --- |
| `motion_pattern_3d.gdshader` | box-filtered checker / stripes / grid / solid spatial material: world XZ, UV-in-metres or triplanar space, motion blur, face shading, sheen, ring shockwave, light window (UV2.x), sprouting by key |
| `motion_pattern_3d.gd` | `MotionPattern3D` (RefCounted, static): material, endless ground, UV-mapped boxes and quads, ring and grow helpers |
| `motion_sky_dome_3d.gdshader` | gradient sky + banded OutRun sun on a camera-centred dome |
| `motion_sky_dome_3d.gd` | `MotionSkyDome3D` (MeshInstance3D): the sky dome with MotionPatternPlane's sky / sun controls |

#### API rows (for docs/API.md)

##### MotionPattern3D (static)

| Member | Notes |
| --- | --- |
| `material(color_a, color_b, cell, space, pattern) -> ShaderMaterial` | `space`: `WORLD_XZ` (floors; world-locked, so the mesh can follow the camera), `UV` (UVs in metres, see `box()`: cells line up with each face's edges whatever its rotation), `TRIPLANAR` (XZ / ZY / XY by face normal). `pattern`: `CHECKER`, `STRIPES`, `GRID`, `SOLID`. Vertex colour tints `color_a` (one material, many building colours) |
| Shader parameters | `cell` (m), `offset` (cells; scroll), `uv_scale` (UV to metres for `UV` space, e.g. an extruded logo's 0..1 UVs), `line_width`, `energy`, `energy_b`, `motion`, `face_shade` (brightness of faces facing x / y / z), `sheen_color` / `sheen_dir` / `sheen_power`, `ring` / `ring_color` / `ring_energy` / `ring_push`, `grow`, `lit_from` / `lit_to` / `lit_soft` / `dim` (as `MotionStage3D.unlit()`) |
| `ground(parent, mat, size, y) -> MeshInstance3D`, `follow(floor, camera_pos)` | An endless floor: a big plane kept under the camera each frame; the pattern stays put |
| `motion_for(a, b, shutter) -> Vector3` | The `motion` uniform for a camera moving a to b in a frame: the filter footprint widens by the movement while the shutter is open, so a fast board smears along the travel instead of strobing or running backwards |
| `ring(mat, centre, radius, width, col, push)` | A shockwave ring on the floor (world centre; tints and pushes the pattern). `radius <= 0` turns it off |
| `grow(mat, key, from, to)` | Sprouts geometry: model-space y is scaled by `1 - smoothstep(from, to, UV2.x - key)`. Towers keyed by track distance with `key` = the camera's distance lie flat far ahead and rise as you approach (keeps the horizon and the sun open down a long straight) |
| `box(st, xform, size, col, uv2x, top)`, `quad(st, a, b, c, d, col, uv2x, uv0)` | Geometry for `UV` space: UVs in metres on every face (v from each side's base), UV2.x = a key for light windows and `grow` |

##### MotionTrack3D (static, `three/motion_track_3d.gd`)

Track builders shared by the Gantry and Night Circuit takes (unlit vertex colour, UV2.x =
distance along the track for `lit_from` / `lit_to` chases):

| Member | Notes |
| --- | --- |
| `circuit(points, tilts, handle=0.17, bake_interval=0.5) -> Curve3D` | Smooth banked curve through points (handles `handle` x neighbour-to-neighbour, flat ends) |
| `frame(curve, s, height, side)`, `level_frame(curve, s, side)` | Banked frame at distance s (MotionStage3D.path_frame); heading only, no bank (things standing beside the track) |
| `strip(st, curve, s0, s1, x0, y0, x1, y1, col, step=2)`, `quad(st, a, b, c, d, col, uv2x)` | Ribbons along the curve (deck, barriers, light strips), raw quads |
| `trail_lane(curve, length, x, y, col, half_w=0.35, half_h=0.25, step=1) -> ArrayMesh` | A cross-section ribbon to light as a moving ship trail |

Checkered faces use `MotionPattern3D.box / quad` (UVs in metres) instead.

##### MotionSkyDome3D (MeshInstance3D)

| Member | Notes |
| --- | --- |
| `sky_top`, `sky_horizon`, `sky_spread`, `sky_curve` | Gradient (spread = elevation sine where it reaches the top; curve = exponent) |
| `sun_elevation`, `sun_azimuth`, `sun_size` (degrees), `sun_top`, `sun_bottom`, `sun_bands`, `sun_glow`, `sun_energy`, `horizon_cut` | The MotionPatternPlane sun: a vertical gradient, OutRun bands (count, scroll, top of the banded area), glow; `horizon_cut` hides what has sunk below the horizon. Azimuth 0 looks down -Z, positive turns right |
| `level`, `radius` | Fade to black; dome radius (inside the camera's far plane) |
| `follow(camera)`, `sun_direction()`, `fog_to(environment)` | Centre on the camera each frame; unit vector to the sun (a floor's `sheen_dir`); set the fog colour to the horizon so fogged ground meets the sky without a seam |

#### Frame purity

Every uniform is set from `f` in `_frame`. The camera's distance along the circuit
is a table integrated once (eighths of a frame) and looked up; the board's
`motion` comes from the circuit at `s(f - 0.5)` and `s(f + 0.5)`; the sign's
transform, the ring centre (the sign's position at the ring's start frame), `grow`
and the light windows are functions of `f`. The ground plane and sky dome follow
the camera, which is itself a function of `f`. Checked: frames 101, 197 and 333
rendered by seeking are pixel-identical (max difference 0) to the same frames of
the continuous render.

#### Cost

The pattern shader is a handful of ALU per pixel (one box-filtered checker, a
derivative normal, optional sheen and ring) with no textures; the sky dome is one
sphere. Towers, gantries and pylons merge into one ArrayMesh per material. The
whole take (stage with MSAA 4x and glow, ~10 panel viewports, ~300 towers)
renders at about 0.8 s a frame under Xvfb software GL on the shared 2 cores
(5 min 40 s for the 420 frames, including Movie Maker PNG writes).

#### Limits

- The pattern's motion blur is a widened box filter along the world motion
  (good for a board under a moving camera); it does not blur geometry edges.
- `UV` space needs UVs in metres: use `box()` / `quad()`, or `uv_scale` for 0..1
  UVs. Triplanar space is axis-aligned (rotated boxes get diagonal cells).
- `grow` scales model-space y toward 0: keep the ground at the mesh's y = 0 and
  key whole buildings with one UV2.x so they rise as one.
- Face normals come from screen derivatives (flat faces only; no smoothing).
- Fog is the environment's (exponential here): set `fog_to()` so the horizon and
  fog agree; very low sun elevations need the ground to cover the dome below it.

### Cheaper time slices: MotionViewRect, MotionTimeCache

From the FTF intro take `demo/ftf/ftf_timecity/` (notes: `demo/ftf/ftf_timecity/KIT_NOTES.md`).

Round 4, Time City (Megastructure x Slit-Scan). The city of take 2 (MotionExtrude,
~600 solids) seen through MotionTimeSlices. Instanced naively that is one full
city per band (24-32 bands, 40-75 ms of draw each, plus its own sort): several
seconds a frame. Two new kit files and one pattern make it affordable. No
existing kit file was changed.

#### New: `addons/motion_kit/fx/motion_view_rect.gd` (`class_name MotionViewRect`)

What part of a node's own space its viewport actually shows, for content that
culls itself. Each MotionTimeSlices band renders its instance into a
band-sized SubViewport with the content shifted to the band's source rect, so
the content can ask which strip it is drawing and skip everything else.

| Member | Notes |
| --- | --- |
| `of(item, pad = 0)` (static) | The rect of `item`'s local space its viewport shows (inverse canvas transform of the viewport's visible rect), grown by `pad`. In a band: that band's strip; at the root: the frame, through any shake or scale. Empty when not in the tree. Call it in `_frame` (MotionTimeSlices / MotionTimeCache place their holders before the walk reaches the content). |
| `is_partial(item, full)` (static) | True when the item renders into something smaller than `full`. |
| `box(cam, centre, half)` (static) | Screen bounds of a world box through an orthographic MotionExtrudeCamera: a cheap, exact per-cell cull before positioning anything. |

Both time effects share one profile table: static `MotionTimeSlices.profile_value(shape,
u, k, waves, phase, seed_v, fn)` (their `profile_at(u, k)` call it).

#### New: `addons/motion_kit/fx/motion_time_cache.gd` (`class_name MotionTimeCache`)

Slit-scan and channel splits that render each moment once. Where every band
shows the same part of the content and only the moment differs, bands with an
equal (quantised) delay share one render.

| Member | Notes |
| --- | --- |
| `scene` / `builder`, `size` | As MotionTimeSlices. |
| `layout` | `ROWS`, `COLUMNS` (slit-scan: every band shows the slit, stretched across the band) or `CHANNELS` (three full-frame copies tinted R, G, B and added). |
| `bands`, `slots` | Number of bands; most distinct moments rendered per frame (one content instance each, built once). More distinct delays than slots are merged to `slots` evenly spaced levels. |
| `delay`, `profile` (MotionTimeSlices.Profile), `waves`, `phase`, `seed` (alias `seed_value`), `profile_fn`, `step` | As MotionTimeSlices; `step` (default 1 frame) is what makes bands share. |
| `slit_pos`, `slit_width` | The slit each slot renders (a `slit_width`-pixel column or row): the slot viewport is that size, so a slot costs a line, not a frame. |
| `channel_shares` | CHANNELS: delay share per channel. `[1, 0, 0]` = red lags, green and blue together: a red/cyan split in two renders instead of three. |
| `reveal`, `reveal_from` | Show only some bands (as MotionTimeSlices). |
| `region()`, `moments()`, `profile_at(u, k)`, `rebuild()` | Helpers. |

Frame purity: the delays, their distinct sorted set and the slot each moment
goes to are recomputed from f every frame; a slot is a nested composition with
`start` = its delay. Nothing persists. Hand-over from MotionTimeSlices: fold the
columns into the slit at delay 0 (every band then shows the same line), switch,
then grow the delay: the switch is invisible.

#### Pattern: shared world, per-band pose (in this take)

`city_world.gd` holds the solids once (a static shared by every instance of
`src_city.gd`). Each instance only stores its own `f` and view rect:

- `_frame(f)`: `view = MotionViewRect.of(self, 6)`; a light pose (camera,
  monument, logo slab: enough for SVG cap transforms and masks).
- every draw_fn starts with `world.pose(f, view)`: camera, then each cell is
  culled by `MotionViewRect.box` before its heights are computed, then
  `MotionExtrude.cull_rect = view` and `prepare()` sorts only what the strip
  shows. Posing is a pure function of (f, view) and is skipped when the world
  is already posed for that pair, so it runs once per band per frame. Canvas
  redraws run in queue order, so one band's canvases draw back to back.
- decals that draw long strips (the platform's serial band) cull their items
  to the view too.

#### Cost (measured)

Shared 2-core VM, Xvfb + llvmpipe. Full Movie Maker render of the take: 420
frames in 233 s, **0.55 s a frame** on average. Per mode, from a harness that
calls `render(f)` and forces a draw (script + draw_fns + GL, no PNG write):

| Mode | Instances posed | Cost a frame |
| --- | --- | --- |
| plain (one city) | 1 | ~0.40 s |
| 32 columns, time wave / ripple (MotionTimeSlices) | 27-32 | ~0.48 s |
| 24 rows, crane / slab smear (MotionTimeSlices) | 24 | ~0.80-0.87 s |
| 32 columns folding into the slit (MotionTimeSlices) | 32 | ~0.89 s |
| red/cyan split (MotionTimeCache CHANNELS, 2 slots) | 2 | ~0.65-0.72 s |
| 96-column slit-scan (MotionTimeCache, <= 15 slots of 3 px) | 13-17 | ~0.24 s |

For comparison, the same 96-column streak through MotionTimeSlices measured
1.9 s a frame (96 posed bands), and posing each band twice (once in `_frame`,
once at draw) cost ~40 % more script time than the light-pose split above.
Without the per-band cull every band would draw the whole city (40-75 ms of
draw plus its sort each).

Limits: MotionViewRect culling needs content that can cull (MotionExtrude,
or your own bounds); BOXES bands each contain the centre, so culling helps
them little. MotionTimeCache only covers the shared-slit and channel cases:
for plain time displacement (each band its own place) MotionTimeSlices with a
culling content is the cheaper one (band-sized renders). Slots are built once
(`slots` instances), so keep `slots` to what the profile needs.

### Graphic 3D: MotionLens3D, MotionFlat3D, MotionEdges3D, MotionDecalAtlas

From the FTF intro take `demo/ftf/ftf_canyon/` (notes: `demo/ftf/ftf_canyon/KIT_NOTES.md`).

New in round 4 (Canyon, "Through the Megastructure"). All new files live in
`addons/motion_kit/three/`; **no existing kit file was edited**. Merge these
rows into `docs/API.md` and `docs/techniques.md`.

| File | Class / role |
| --- | --- |
| `motion_lens_3d.gd` | `MotionLens3D` (RefCounted): a camera pose that blends perspective into orthographic without a pop, and matches a `MotionExtrudeCamera` exactly |
| `motion_flat_3d.gd` | `MotionFlat3D` (RefCounted): the MotionExtrude look in real 3D: face-tone materials, depth fog, frame-pure group motion, builders |
| `motion_edges_3d.gd` | `MotionEdges3D` (RefCounted): screen-space crease and silhouette outlines |
| `motion_decal_atlas.gd` | `MotionDecalAtlas` (Node): 2D kit drawings rendered once into an atlas for decals |
| `motion_flat_3d.gdshaderinc` | shared group motion (sink rings, beat pulse) and depth fog |
| `motion_flat_3d_faces.gdshaderinc` | the face-tone body |
| `motion_flat_3d.gdshader` / `motion_flat_3d_double.gdshader` | face tones, back faces culled / two-sided |
| `motion_edges_3d.gdshader` | constant-pixel-width outline ribbons |
| `motion_decal_3d.gdshader` | tinted, alpha-blended atlas decals |

#### API rows (for docs/API.md)

##### MotionLens3D (RefCounted)

A lens frames `target`: `frame_h` world units fill the screen height on the
plane through the target. `persp` scales perspective strength k = tan(fov/2) ·
persp; the camera sits at distance frame_h / 2k, so lowering persp is a dolly
zoom that keeps the target the same size. Past `ortho_at` the lens becomes a
true orthographic camera of size `frame_h` (the residual perspective there is
depth range / distance, about 0.1 %, under a pixel at the frame edge).

| Member | Notes |
| --- | --- |
| `target`, `basis`, `frame_h`, `persp`, `fov` | Framed point, orientation (−Z looks at the target), world units across the screen height, perspective strength 0..1, vertical FOV at persp 1 |
| `offset` | Screen offset of the target in pixels (MotionExtrudeCamera `centre` − screen centre; also good for shakes). Perspective: a lens shift (frustum offset); orthographic: camera h/v offset |
| `keep`, `depth`, `near_min`, `ortho_at`, `view_h` | Scene depth kept in front of the target (the near plane rides there once the camera backs away, clearing what would come between), behind it (far plane); smallest near plane; ortho switch distance (20000); screen height in px |
| static `look(from, at, fov, up, roll)` | A free perspective camera as a lens |
| static `from_transform(xf, fov, focus)` | Any camera transform, framing the point `focus` ahead |
| static `extrude(yaw, pitch, scale, at, centre, screen)` | The exact orthographic view a `MotionExtrudeCamera` with these values draws (45 / 35.264 = true isometric), in Godot axes |
| static `extrude_basis(yaw, pitch)`, `from_extrude(p)` | The matching camera basis; MotionExtrude (x east, y north, z up) → Godot (x, z, −y) |
| `mix(b, t, t_lens = t)` | Blend: target lerp, basis slerp, frame_h in log space, k linear (an even flattening). A separate `t_lens` flattens later than the view turns, so the backing-away camera clears the scene |
| `apply(camera)` | Sets projection (FRUSTUM for perspective: Camera3D clamps `fov` to ≥ 1°, the frustum's near-plane size has no limit), size, near/far, transform and offsets |
| `k()`, `camera_distance()`, `is_ortho()`, `transform()`, `project(p)` | Helpers; `project` predicts screen positions without a camera |

##### MotionFlat3D (RefCounted)

| Member | Notes |
| --- | --- |
| `material(top, lit, dark, under, soft, moves = true, two_sided = false)` | Face tones by world normal: up-facing `top`, sides facing the horizontal `light` `lit`, sides facing away `dark`, down-facing `under`; `soft` 0 = a hard poster terminator. Vertex colour multiplies. `moves` false = ignores group motion (ground). `two_sided` for meshes without consistent winding (MotionSvgMesh: paint white tones so the part colours show) |
| `edges(color, width_px, bias)`, `decals(atlas, moves)`, `register(m, moves)` | Outline / decal materials registered with the look; any shader including `motion_flat_3d.gdshaderinc` can be registered |
| `light`, `energy`, `fog_color/begin/end/amount` | Horizontal light direction (Godot axes); brightness (fade to black); linear depth fog |
| `fog(color, begin, end, amount)`, `fog_for(lens, color, before, after, amount)` | Depth fog; `fog_for` measures from a lens's target plane, so the dolly zoom keeps the same fog around what it frames |
| `sink(origin, t, step, width, dur, depth)` | Rings sinking from `origin` (ground x, z): ring k = floor(d / width) starts at t = k·step and drops `depth` over `dur` frames (ease in). Into an opaque ground: the ground hides what sinks |
| `pulse(origin, t, amp, speed, decay, reach)` | A bob running out at `speed` units/frame, `t` = frames since the beat |
| `apply()` | Push everything to every registered material, once per frame |
| `offset(key)` | The shader's group offset in GDScript, for nodes moved on the CPU (traffic) |
| static `begin()`, `instance(mesh, mat)` | SurfaceTool / MeshInstance3D helpers |
| static `box(st, p, size, key, col, edges, bottom)`, `cylinder(st, base, r, h, key, col, edges, seg)`, `pipe(st, a, b, r, key, col, edges, seg)`, `quad(...)`, `decal(st, c, half_u, half_v, uv, key, col)` | Builders with explicit normals, Godot winding, vertex colour and the group key in UV2; pass a `MotionEdges3D` to get the matching outline. Cylinders are flat-faceted (crisp terminator, identical in perspective and ortho) |

Group key: every vertex's UV2 holds its object's ground anchor (x, z). The
vertex stage adds the group offset to y, so faces, edges and decals of one
object move together inside merged meshes; nodes using the same key (a crane
on a tower) move with it too.

##### MotionEdges3D (RefCounted)

| Member | Notes |
| --- | --- |
| `add(a, b, na, nb, kind, key)`, `add_loop(...)`, `commit()`, `count()` | Edge a→b between faces with normals na, nb. Kinds: `SMOOTH` (silhouette only: one face toward the camera, one away), `CREASE` (when either face looks at the camera), `ALWAYS` (the depth test decides) |
| static `material(color, width_px, bias)` | Constant pixel width in perspective and ortho; ends extended half a width so corners close; pulled `bias` units toward the camera to beat its own faces; near-plane clipping per segment |
| static `from_mesh(mesh, {crease_deg, weld, kind, key, xform})` | Outline any mesh: welds vertices, keeps boundaries and creases (winding-proof |cos| test). Used on MotionSvgMesh logos (kind ALWAYS) |

##### MotionDecalAtlas (Node)

| Member | Notes |
| --- | --- |
| `MotionDecalAtlas.new(size)`, `add(px, fn) -> Rect2` | Shelf-packed cells drawn by `fn(c: MotionCanvas, size)`; returns the UV rect for `MotionFlat3D.decal()`. Draw in white; vertex colour tints |
| `texture`, `viewport`, `pad`, `refresh()` | Renders once (UPDATE_ONCE); add it to the tree before the first frame (it renders before the 3D stage, so stills and seeks get their decals) |

#### Frame purity

Nothing integrates at runtime. The ride's distance along the route is a
monotone cubic (Fritsch–Carlson) through (frame, place) anchors, tabulated per
frame; walkways and pipe racks are built where the camera is on each beat
(so fly-bys land on the cue frames). Lens, materials, group motion, cranes,
traffic (positions modulo lane length), doors and the slab are set from `f`
only. The atlas and panels render from `f` (atlas once). Verified: frames 90,
230 and 300 rendered alone by seeking (`stills.sh`) are pixel-identical to the
same frames of the full render (max difference 0).

#### Cost

- Build: every building and piece of street furniture is merged into one
  mesh per palette colour, one edge mesh, two decal meshes and the ground;
  plus monument, slab, 6 cranes and ~34 pods as small nodes.
- Per frame: ~0 ms of GDScript beyond setting ~20 uniforms per material.
- Render (software GL llvmpipe, 1920×1080, MSAA 4x, 2 shared cores): the
  420-frame piece in 3 min 34 s, about 0.51 s a frame, including the city
  build (a few seconds at startup).

#### Limits

- Face tones assume an unshaded graphic look: no cast shadows or AO.
- Outlines are geometry: only edges that exist in the mesh (no screen-space
  contour of arbitrary implicit shapes); silhouettes of smooth meshes need
  consistent winding (the builders' meshes have it; MotionSvgMesh doesn't, so
  logos get crease outlines only).
- Decals are alpha-blended without mipmaps: very small far text shimmers
  (fog hides it in perspective; in iso the atlas is drawn near 1:1).
- `MotionLens3D` offsets are exact on the target plane; the ortho switch is
  a ~0.1 % residual perspective (measured < 0.25 mean pixel difference at the
  switch, flat-faceted geometry).

### Slit-scan planes and time split: MotionPlaneScan, MotionTimeSplit

From the FTF intro take `demo/ftf/ftf_stargate/` (notes: `demo/ftf/ftf_stargate/KIT_NOTES.md`).

New files, no existing kit file changed:

- `addons/motion_kit/plane/motion_plane_scan.gd` (`class_name MotionPlaneScan`, `@tool`, extends `MotionPatternPlane`)
- `addons/motion_kit/plane/motion_plane_scan.gdshader`
- `addons/motion_kit/fx/motion_time_split.gd` (`class_name MotionTimeSplit`, `@tool`, extends `Node2D`)

#### MotionPlaneScan

The plane's own time displacement, per pixel, in its one quad. Each pixel picks a
source pixel (its own place, or the slit, optionally seen through a perspective wall)
and a time (frames back), and the shader evaluates the plane there and then. What
changes with time comes from a small float texture: the last `history` frames of the
plane's state, sampled from a pure function of the frame. MotionTimeSlices does the
same for any content by instancing it per band; for a pattern plane this is the same
idea with every pixel its own band, at the cost of one plane render (three pattern
evaluations while the RGB split is on).

##### API (rows for docs/API.md, after MotionPatternPlane)

Everything in MotionPatternPlane, plus:

| Member | Notes |
| --- | --- |
| `history_fn: Callable`, `capture(f)`, `history` | `history_fn(t) -> Dictionary` is the plane's time-varying state at frame t (pure; must accept negative t). Keys, all optional (missing ones use the current property): `offset` (ground_offset), `cell`, `blur` (motion_blur), `color_a`, `color_b`, `accent` (accent_color), `sun` (sun size scale), `level`. While `history_fn` is set the plane captures in its own `_frame(f)`; `capture(f)` samples f, f-1 … f-(history-1) into a 5-row RGBAF texture (call it yourself in `_frame`, then `sync_now()`, to capture after changing other properties; a frame already captured is not sampled twice). Camera, bends, fog, sky colours and the ring are shared by every time. |
| `scan` | 0 = each pixel at its own place (pure time displacement: the delay grows with the distance from the slit line); 1 = every pixel reads the slit. In between the picture unrolls from the slit. |
| `axis` | `VERTICAL` (a vertical slit through `slit_at.x`: walls left and right), `HORIZONTAL` (a horizontal slit through `slit_at.y`: walls above and below), `TUNNEL` (both, split along the diagonals of `wall_ref`: four walls). |
| `slit_at` | Where the slit lines cross, in pixels: the vanishing point of the walls. |
| `walls`, `wall_ref`, `wall_near` | 0 = flat streaks (the slit stretched sideways, as MotionTimeSlices COLUMNS/ROWS at slit = 1); 1 = perspective walls: along the slit the source is magnified by `wall_ref / distance` (so the slit is seen ever smaller toward the vanishing point, 1:1 at `wall_ref`), and the delay grows with log(distance / `wall_near`), full at `wall_ref`. What crosses the slit now is born at the vanishing point and rushes outward, accelerating. `wall_ref` = half the frame makes TUNNEL's four walls tile the frame. |
| `gap`, `gap_color` | Walls: where the source leaves the frame (the wedges toward the vanishing point on two-wall axes), mix to this colour (black: the 2001 look; 0 shows the plane beyond the frame). |
| `delay_span` | Flat: the distance from the slit line (pixels, per axis) where the delay reaches its full share. |
| `delay`, `delay_curve`, `delay_step`, `ripple` | Frames back at the full share (keep below `history`); share = u ^ curve (u 0 at the slit, 1 at the span / near the camera) + `ripple.x * sin(2π(ripple.y·u − ripple.z))`; `delay_step` quantises (a stutter). Sweep `delay_curve` through a beat and snap `delay` on the next to make the profile breathe on the music. |
| `split` | RGB time split: green reads `split` frames further back than red, blue twice as far. A fraction of a frame is plenty on a fast board (it is a fraction of a check). |
| `delay_at(px)` | The shader's delay function in GDScript (for HUD readouts or 2D layers that should streak in step). |

##### Motion blur across times

The pattern's box filter is widened by the motion blur **of the moment each sample
shows** (`blur` in the history), plus the screen-space derivative of the pattern
coordinate, which now includes the change of time across the pixel. So a streak wall
where neighbouring pixels are a frame apart filters across that frame's travel
(no aliasing toward the vanishing point, where the time gradient is steep: it settles to
the average colour), and a band showing a slower moment gets that moment's narrower blur.
Checked on the take: no strobing or backward-running checks in the walls, the tunnel or
the flat streaks.

##### Frame purity

`capture(f)` calls `history_fn` for f − i only; the history texture is rebuilt every
frame; the shader reads only uniforms, the texture and the pixel. Travel is a table
integrated once and extended linearly to negative frames. Seeked stills match the
continuous render pixel-wise (see the take's report).

##### Cost

One full-screen quad: the plane's ray hit once per pixel, then 1 (or 3 with `split`)
pattern evaluations with 5 history texel pairs each. Under Xvfb llvmpipe on the shared
2 cores the take's whole frame (board, 160-column MotionTimeSlices for the logos, the
time split, towers, HUD) renders at about 0.5 s; the scan itself is a small part of it.
History capture is 100 Dictionary calls and 500 `set_pixel` per frame (about 2 ms).

##### Limits

- Only what the history carries changes with time. The camera, bends, sky colours, fog,
  wave and ring are shared by every time, so a camera move shows on all walls at once.
- The plane part of the shader is a copy of `motion_pattern_plane.gdshader`; keep the
  two in step (a later refactor could move the shared part into a `.gdshaderinc`).
- TUNNEL's diagonal seams have a derivative discontinuity: the filter widens there and
  draws a thin average-colour line (reads as the tunnel's corners).
- 2D geometry drawn on the plane (`draw_checker_quad` towers) does not scan: hide or sink
  it while the scan is on, or put it in a MotionTimeSlices.

#### MotionTimeSplit

RGB time split for content on any background. MotionTimeSlices CHANNELS adds three tinted
copies, which needs an opaque dark background. MotionTimeSplit renders the content three
times (f, f − d, f − 2d by default) into region-sized SubViewports and draws three black
silhouettes (normal blend) under the three channels (added): where the copies coincide the
result is exactly the content, where it moves it fringes red/green/blue (cyan/magenta/yellow
where two overlap) over whatever is behind. With `delay` 0 the viewports stop and one plain
copy draws.

| Member | Notes |
| --- | --- |
| `scene: PackedScene`, `builder: Callable` | The content (a MotionComposition, global timeline, accepts negative frames); four instances (three copies and the plain one). |
| `region` | The part of the content's frame rendered (a logo's box plus its motion): the cost is three region-sized renders and six sprites while splitting. |
| `delay`, `shares`, `tints` | Frames green lags red (blue 2×); per-channel shares of the delay; the tints (summing to white). |

Frame purity: as MotionTimeSlices: each copy is a nested composition whose `start` is set
in `_frame(f)` before the parent's walk renders it at f − start. Cost in the take: a split
frame (1680×620 region) adds about 0.05 s under software GL; idle it costs one logo.
Limits: the content's edges are slightly darkened where alpha is partial (viewport
textures are drawn straight-alpha); content must move for the split to show.

#### Kit bug found (not fixed, existing file)

`MotionPatternPlane.draw_checker_quad` can recurse without end when a receding face
crosses the near plane while the camera is pitched/yawed/rolled: it clips in world z but
tests camera depth, so a clipped corner can still fail the test and is clipped again by
zero. The take avoids it by clipping faces to z ≥ 3 itself. A fix would test camera depth
in the clip (or recurse at most once).

### Voxel choreography: MotionVoxelize, MotionBlockPlan, MotionFaceLights

From the FTF intro take `demo/ftf/ftf_assembly/` (notes: `demo/ftf/ftf_assembly/KIT_NOTES.md`).

New in round 4 (Assembly). Three classes, all `@tool`, pure GDScript, no
shaders, no new nodes: they plug into the 2.5D extrusion classes
(`MotionExtrude` / `MotionSolid` / `MotionExtrudeCamera`). No existing kit file
was edited. Merge these rows into `docs/API.md` and `docs/techniques.md`.

#### API

##### MotionVoxelize (RefCounted)

Sample a mask onto a grid of cells, once, at build time.

| Member | Notes |
| --- | --- |
| `from_svg(data, cols, rows, parts = [], area = viewBox, ss = 3, threshold = 0.45, offsets = {})` (static) | Sample a MotionSvgData's parts (default: every filled part) with `ss`×`ss` samples per cell. Fill rules (nonzero/even-odd) are honoured, so counters stay open; later parts cover earlier ones. `offsets` (part → Vector2 in SVG units) shifts parts before sampling: pull stacked layers apart so each shows as its own band of cells (the MH M's three layers become three tiers). |
| `from_image(img, cols, rows, area, ss, threshold, use_luma)` (static) | Sample an Image's alpha (or luminance). For a CanvasItem mask, render it once into a SubViewport and pass `get_texture().get_image()`. Part is 0. |
| `from_fn(fn, cols, rows, ss, threshold)` (static) | `fn(uv: Vector2) -> int` over 0..1 (y down), a part id or -1. |
| `cols`, `rows`, `rect`, `cover`, `part`, `threshold` | Coverage 0..1 per cell; the majority part per cell (-1 empty); cells with `cover >= threshold` are filled. Row 0 is the top of the mask. |
| `filled(c, r)`, `part_at(c, r)` | |
| `targets(height_fn)` | Every filled cell as `{cell: Vector2i, h: float, part: int}`; `height_fn(part, cover, cell) -> float` sets the height (letters tall, plate low; <= 0 drops the cell). |
| `world(cell, origin)` | A cell's south-west corner on a ground grid (+y north, row 0 northmost), `origin` the grid's south-west cell. |
| `inside(contours, pt, evenodd)` (static) | Point in a multi-contour shape. |
| `ascii()` | The filled cells as text, one letter per part: check a resolution before building anything. |

##### MotionBlockPlan (RefCounted)

One move per block from layout A to layout B, in grid moves, in waves; a pure
function of the frame.

| Member | Notes |
| --- | --- |
| `MotionBlockPlan.new(n)`, `resize(n)`, `size()` | |
| `start`, `waves`, `wave_step`, `dur`, `jitter` | Wave k starts at `start + k * wave_step` (a beat, so moves land on the beat); each move takes `dur` frames; inside a wave, up to `jitter` frames of delay follow the key, so a wave ripples instead of firing as one block (and never as a per-letter cascade). |
| `lift`, `slide_max`, `sink_share`, `land`, `seed` (alias `seed_v`) | Flying cruise height (±40% per block, so crossing blocks fly at different heights); moves up to `slide_max` cells slide on the ground, longer ones fly (or, for `sink_share` of them, sink and rise); height overshoot on landing (servo telescoping). |
| `set_move(i, a, b, key, style = -1)` | `a`, `b` = Vector3(x, y, height). `key` 0..1 picks the wave (e.g. the target's elliptical distance from the logo's centre: middle out). `style`: `STAY` (height only), `SLIDE` (two axis legs on the ground, x/y order seeded), `FLY` (lift, two legs in the air, drop), `SINK` (down at the source, up at the target); -1 picks. |
| `pose(i, f)` | Vector4(x, y, lift above ground, height) at frame f. Clamped: before the move it returns `a`, after it `b`, so a chain of plans (A→B, B→C…) is evaluated by picking the latest plan whose `start` has passed. |
| `progress(i, f)`, `starts(i)`, `lands(i)`, `target(i)`, `origin(i)`, `style(i)`, `wave_frames()` | Light switches on landing, cues on wave frames. |
| `assign_nearest(blocks, targets, order = [], exclude = {})` (static) | Cheap matching: targets taken in `order` (default: farthest from their centroid first, so the rim claims blocks before the middle) each take the nearest free block, found with a bucketed ring search. Returns per target the block index (-1 when blocks ran out). Unassigned blocks are yours to park (crouch, sink). A block already standing on a target cell keeps it unless an earlier target took it, so the surplus never sits on a target. |

##### MotionFaceLights (RefCounted, static helpers for decals)

| Member | Notes |
| --- | --- |
| `windows(c, size, sd, f, col, level, lit, flicker, period, floor_px, pane, margin, palette)` | Rows of lit windows on a wall decal: one `draw_dashed_line` per lit floor. `lit` share of floors on, `flicker` chance a floor toggles every `period` frames (seeded, frame-pure), `level` dims all (power on/off), `palette` picks a colour per floor. |
| `strip(c, a, b, col, w, glow, glow_alpha)` | A neon line: a wide faint glow under a thin core. |
| `rim(c, size, col, w, glow, glow_alpha)` | A neon strip round a face (a roof's edge). |
| `chase(c, size, phase, length, col, w, glow)`, `chase_path(c, pts, phase, length, col, w, glow)` | A dash of light running round a face's rim, or round any closed polyline (a logo outline in a `cap_transform`). |

Decal sizes are decal units (100 per world unit). Small blocks need
`MotionExtrude.min_decal_area` lowered (this piece uses 70 px²; the default
600 skips faces under ~25 px).

**Frame purity.** Sampling and matching run once in `_build`; every plan is a
packed table of numbers and `pose()` is closed-form (cheap closed-form easings,
no Callables). Windows flicker from `MK.rand(seed, floor, floor(f / period))`.
Nothing accumulates. Checked pixel-wise: frames 77 and 381 rendered by seeking
are identical to the full render (max difference 0); see the take's report for
the MotionSvg first-frame raster note.

**Cost.** Voxelising the two logos (72×20 and 68×16 cells, 3×3 samples) and
matching 1,616 blocks to 827 and 1,073 targets: about 1 s at build, once.
Per frame, the piece's `_frame` (posing every block, colours, the sort) is
16–44 ms on the shared 2-core VM. The full 420-frame render (1,616 boxes, up
to ~3,500 faces, window strips, roof strips and chases, ground grid, spill and
traffic) took 187 s under software GL: **0.44 s a frame**, including the
encoder.

**Limits.** One block per cell: legibility is the grid's. Check with
`ascii()`: 72 cells across the Minimal Humans lockup reads; 68 across the FTF
logo gives the shapes, not the small text, which is why the real logo slab
lands on it. Flying blocks are drawn in their own canvas above the city (the
painter's key is a ground key, so a block in the air would otherwise sort
behind towers it is above); two blocks sliding through the same cell overlap
for a few frames. Matching is greedy, not optimal: paths can cross.

#### Found while checking purity (existing kit, not changed)

`MotionSvg` picks its raster density from the viewport's final transform at
draw time. On the very first frame of a Movie Maker run that starts mid-piece
(`render.sh … <start>`, `stills.sh`), that density lands in a different bucket
than in a continuous run, so the slab artwork's edges differ by up to ~190/255
on antialiased edge pixels (nothing else on the frame differs). Rendering from
298 shows 298 differing and 299/300 identical to the full render: a cold-start
raster choice, not state in the piece. A fix belongs in `MotionSvg` (resolve
the viewport scale once the window is sized, or redraw on the second frame).
