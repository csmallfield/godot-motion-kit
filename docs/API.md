# Motion Kit API

All coordinates are pixels in the composition's reference space (1920×1080 unless you
change `MotionComposition.size`). Frames are floats; at 60 Hz and above the same
functions are evaluated between whole frames.

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
`MotionSvgData.from_string(text)` / `from_file(path)`.

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

`MotionFonts.font(path, msdf=false)` loads ttf/otf/woff/woff2 with browser-like settings
(no hinting, sub-pixel positioning). MSDF keeps glyphs sharp while they scale up, but
small sizes can show corner artefacts, so it is off by default.

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
for a group's opacity use `modulate.a` on the canvas.

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
| `profile` | How the delay spreads across the bands: `LINEAR`, `REVERSE`, `CENTRE`, `EDGES`, `SINE` (`waves`, `phase`), `RANDOM` (`seed_value`), `CUSTOM` (`profile_fn(u) -> 0..1`, u = 0..1 across the bands). |
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
| static `path_frame(curve, s, height, side) -> Transform3D` | The frame of a Curve3D at distance s: -Z along travel, Y = the curve's up vector with tilt (banking); continues straight past the ends |
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
