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

Movie Maker renders advance exactly one movie frame per image (`movie_fps`, default the
composition's `fps`): Godot's process delta wobbles over the first frames. To split or
resume a long Movie Maker render, pass `-- --mk-start=N` on the command line:
the top-level composition starts at frame N (the files still count from 0).

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
part is drawn from a lower-density raster rather than cropped. Outlines are live anti-aliased polylines. `modulate.a`
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
glyph's outline, painted over the fill. `get_text_size()` gives the width (including tracking after the last character, as CSS
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
small state texture only), `get_cell(x, y)`.

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
