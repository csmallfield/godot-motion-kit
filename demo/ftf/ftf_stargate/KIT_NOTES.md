# Kit notes: MotionPlaneScan (shader-side time displacement and slit-scan for planes) and MotionTimeSplit

New files, no existing kit file changed:

- `addons/motion_kit/plane/motion_plane_scan.gd` (`class_name MotionPlaneScan`, `@tool`, extends `MotionPatternPlane`)
- `addons/motion_kit/plane/motion_plane_scan.gdshader`
- `addons/motion_kit/fx/motion_time_split.gd` (`class_name MotionTimeSplit`, `@tool`, extends `Node2D`)

## MotionPlaneScan

The plane's own time displacement, per pixel, in its one quad. Each pixel picks a
source pixel (its own place, or the slit, optionally seen through a perspective wall)
and a time (frames back), and the shader evaluates the plane there and then. What
changes with time comes from a small float texture: the last `history` frames of the
plane's state, sampled from a pure function of the frame. MotionTimeSlices does the
same for any content by instancing it per band; for a pattern plane this is the same
idea with every pixel its own band, at the cost of one plane render (three pattern
evaluations while the RGB split is on).

### API (rows for docs/API.md, after MotionPatternPlane)

Everything in MotionPatternPlane, plus:

| Member | Notes |
| --- | --- |
| `history_fn: Callable`, `capture(f)`, `history` | `history_fn(t) -> Dictionary` is the plane's time-varying state at frame t (pure; must accept negative t). Keys, all optional (missing ones use the current property): `offset` (ground_offset), `cell`, `blur` (motion_blur), `color_a`, `color_b`, `accent` (accent_color), `sun` (sun size scale), `level`. `capture(f)` samples f, f-1 … f-(history-1) into a 5-row RGBAF texture (the plane also captures by itself in its own `_frame` while `history_fn` is set; call it yourself, then `sync_now()`, after changing other properties). Camera, bends, fog, sky colours and the ring are shared by every time. |
| `scan` | 0 = each pixel at its own place (pure time displacement: the delay grows with the distance from the slit line); 1 = every pixel reads the slit. In between the picture unrolls from the slit. |
| `axis` | `VERTICAL` (a vertical slit through `slit_at.x`: walls left and right), `HORIZONTAL` (a horizontal slit through `slit_at.y`: walls above and below), `TUNNEL` (both, split along the diagonals of `wall_ref`: four walls). |
| `slit_at` | Where the slit lines cross, in pixels: the vanishing point of the walls. |
| `walls`, `wall_ref`, `wall_near` | 0 = flat streaks (the slit stretched sideways, as MotionTimeSlices COLUMNS/ROWS at slit = 1); 1 = perspective walls: along the slit the source is magnified by `wall_ref / distance` (so the slit is seen ever smaller toward the vanishing point, 1:1 at `wall_ref`), and the delay grows with log(distance / `wall_near`), full at `wall_ref`. What crosses the slit now is born at the vanishing point and rushes outward, accelerating. `wall_ref` = half the frame makes TUNNEL's four walls tile the frame. |
| `gap`, `gap_color` | Walls: where the source leaves the frame (the wedges toward the vanishing point on two-wall axes), mix to this colour (black: the 2001 look; 0 shows the plane beyond the frame). |
| `delay_span` | Flat: the distance from the slit line (pixels, per axis) where the delay reaches its full share. |
| `delay`, `delay_curve`, `delay_step`, `ripple` | Frames back at the full share (keep below `history`); share = u ^ curve (u 0 at the slit, 1 at the span / near the camera) + `ripple.x * sin(2π(ripple.y·u − ripple.z))`; `delay_step` quantises (a stutter). Sweep `delay_curve` through a beat and snap `delay` on the next to make the profile breathe on the music. |
| `split` | RGB time split: green reads `split` frames further back than red, blue twice as far. A fraction of a frame is plenty on a fast board (it is a fraction of a check). |
| `delay_at(px)` | The shader's delay function in GDScript (for HUD readouts or 2D layers that should streak in step). |

### Motion blur across times

The pattern's box filter is widened by the motion blur **of the moment each sample
shows** (`blur` in the history), plus the screen-space derivative of the pattern
coordinate, which now includes the change of time across the pixel. So a streak wall
where neighbouring pixels are a frame apart filters across that frame's travel
(no aliasing toward the vanishing point, where the time gradient is steep: it settles to
the average colour), and a band showing a slower moment gets that moment's narrower blur.
Checked on the take: no strobing or backward-running checks in the walls, the tunnel or
the flat streaks.

### Frame purity

`capture(f)` calls `history_fn` for f − i only; the history texture is rebuilt every
frame; the shader reads only uniforms, the texture and the pixel. Travel is a table
integrated once and extended linearly to negative frames. Seeked stills match the
continuous render pixel-wise (see the take's report).

### Cost

One full-screen quad: the plane's ray hit once per pixel, then 1 (or 3 with `split`)
pattern evaluations with 5 history texel pairs each. Under Xvfb llvmpipe on the shared
2 cores the take's whole frame (board, 160-column MotionTimeSlices for the logos, the
time split, towers, HUD) renders at about 0.5 s; the scan itself is a small part of it.
History capture is 100 Dictionary calls and 500 `set_pixel` per frame (about 2 ms).

### Limits

- Only what the history carries changes with time. The camera, bends, sky colours, fog,
  wave and ring are shared by every time, so a camera move shows on all walls at once.
- The plane part of the shader is a copy of `motion_pattern_plane.gdshader`; keep the
  two in step (a later refactor could move the shared part into a `.gdshaderinc`).
- TUNNEL's diagonal seams have a derivative discontinuity: the filter widens there and
  draws a thin average-colour line (reads as the tunnel's corners).
- 2D geometry drawn on the plane (`draw_checker_quad` towers) does not scan: hide or sink
  it while the scan is on, or put it in a MotionTimeSlices.

## MotionTimeSplit

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

## Kit bug found (not fixed, existing file)

`MotionPatternPlane.draw_checker_quad` can recurse without end when a receding face
crosses the near plane while the camera is pitched/yawed/rolled: it clips in world z but
tests camera depth, so a clipped corner can still fail the test and is clipped again by
zero. The take avoids it by clipping faces to z ≥ 3 itself. A fix would test camera depth
in the clip (or recurse at most once).

## techniques.md rows

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Shader-side slit-scan for planes | `MotionPlaneScan` (a MotionPatternPlane): give it `history_fn` (the board's travel, cell, blur, colours, sun and level at any frame) and call `capture(f)`; `scan` 0→1 unrolls the board into the slit, `walls` 0→1 bends flat streaks into perspective walls (`axis` VERTICAL / HORIZONTAL / TUNNEL about `slit_at`), `delay`/`delay_curve`/`delay_step`/`ripple` shape the time profile, `split` fringes it red/green/blue. Unfold to `scan = 0, delay = 0` to snap sharp. | The FTF Stargate Board take: the board's columns lag into chevrons as Minimal Humans pours out of the slit; row ripples on the kicks; the board unrolls into 2001 walls, then a floor-and-ceiling corridor, then a four-wall tunnel whose delay profile sweeps through every beat and snaps on the next; it unfolds sharp on the drop and drains to black as flat streaks. |
| RGB time split over any background | `MotionTimeSplit` with a content composition and a `region`; animate `delay` up on accents and back to 0. | The FTF logo fringing on the accents over the racing board in the Stargate Board take. |
