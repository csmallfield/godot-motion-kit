# Kit notes: MotionGreebler (procedural hard-surface detail with a zoom LOD)

New file: `addons/motion_kit/greeble/motion_greebler.gd` (`class_name MotionGreebler`,
`@tool`, extends `RefCounted`). Pure GDScript, no shaders. No existing kit file was changed.

## API (rows for docs/API.md)

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
| `set_offset(id, v)`, `set_visible(id, on)`, `set_alpha(id, a)` | Move (doors, clamps), hide or fade a structure per frame. |
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

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Greebles with a zoom LOD | `MotionGreebler`: `add_block` / `add_rect` for bold extruded shapes, `add_sides` + `add_detail` (with `avoid` = the letters) for a logo drawn by `MotionSvg`; draw from a `MotionCanvas` with the camera's scale and origin. Push the camera in and detail resolves by on-screen size; `lod` per structure keeps logo faces clean wide; `rest_chance` leaves plain plates so the bold shapes read; `reveal_front` cascades detail outward on a beat; `set_offset` moves doors and clamps. | The FTF Greebles take: opening pressed against the Minimal Humans monogram's machinery and pulling back until the lockup is a clean monument; a dive into a plinth hatch through cascading detail into blast doors; the FTF hull plate set in a greebled sky-city superstructure whose panels cascade out from it; parallax layers at three depths with haze, then a pull-out to a city of floating structures. |
