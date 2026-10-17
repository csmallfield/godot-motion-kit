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
| part keys | `tx ty s sx sy rot pivot o fill stroke stroke_width draw draw_width fill_o hide` |
| `chromium_draw` | Reproduce Chromium's dash quirk when porting Remotion pieces (see the porting guide). |
| `oversample`, `prewarm()`, `clear_cache()` | Raster density and cache control. |

Single-colour parts are rasterized white by Godot's own ThorVG and tinted, so recolouring
them costs nothing; parts with both a fill and a stroke, or a gradient, keep their own
colours and `fill` tints them. Rasters are cached in √2 size steps (densities include the
window stretch), shared between nodes, and evicted least-recently-used beyond
`MotionSvg.cache_budget` (256 MB). Outlines are live anti-aliased polylines. Group opacity
is applied to each part separately, so overlapping parts inside a semi-transparent `<g>`
show their overlaps. `MotionSvgData.from_file()` needs the raw .svg, so it is for tools;
games `load()` the file imported as Motion SVG.

## MotionText (Node2D)

`text`, `font`, `font_size`, `color`, `tracking` (em, CSS letter-spacing), `line_height`
(multiple of the size; 0 = the font's own), `align` with `box_width`, `visible_chars`,
`uppercase`. Per-glyph overrides via `apply(fn)` / `glyph_fn(i, f)` with
`tx ty s sx sy rot o color hide`. The origin is the top-left of the line box, as for a CSS block.

`MotionFonts.font(path, msdf=false)` loads ttf/otf/woff/woff2 with browser-like settings
(no hinting, sub-pixel positioning). MSDF keeps glyphs sharp while they scale up, but
small sizes can show corner artefacts, so it is off by default.

`MotionPill`: text on a rounded background with CSS-style padding. Its origin is the
centre, so scaling pops it in place.

## MotionShape (Node2D)

`kind` = CIRCLE, RECT, RING or ARC; `size`, `color`, `radius` (corner; `size.y/2` gives a
pill), `thickness`, `sweep_from`/`sweep_to` (turns from 12 o'clock), `dashes`,
`dash_fill`, `blur` (CSS blur radius; exact Gaussian for square rects), `anchor`
(where the origin sits on the shape). `MotionShape.circle(d, col)` and `pill(w, h, col)` are shortcuts.

## Effects

- `MotionFX`: children placed under it in a scene move into `content` when the game runs
  (in the editor they draw without the effects). It renders `content` offscreen, then applies `set_slices(amount, split, count, seed)`
  (offsets identical to the SCF `Sliced`), `brightness`, `pixel_size`, `goo_blur` and `goo_sharp`.
  Raise `render_scale` for 4K output.
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
