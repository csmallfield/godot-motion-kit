# Kit notes: 2.5D extrusion (`addons/motion_kit/extrude/`)

New in take 2 (Megastructure). Three classes, all `@tool`, pure GDScript, no
shaders. Merge these rows into `docs/API.md` and `docs/techniques.md`.

## API

### MotionExtrudeCamera (RefCounted)

An orthographic camera. World axes: x east, y north, z up.

| Member | Notes |
| --- | --- |
| `yaw`, `pitch` | Degrees. Yaw 0 looks north from the south; pitch 0 is a flat front elevation, 35.26 with yaw 45 is true isometric, 90 is a plan. Blending both to 0 turns an iso view into a perfectly flat front view. |
| `target`, `scale`, `centre`, `roll` | The world point drawn at `centre`, pixels per world unit, screen roll in degrees. |
| `update()` | Recompute the basis (`right`, `up`, `forward`, `forward_h`). `MotionExtrude.prepare()` calls it. |
| `project(p)`, `vec(v)`, `depth(p)`, `ground_key(p)`, `facing(n)` | World point → screen; world direction → screen vector; distance into the scene; painter's key on the ground plan; whether a normal faces the camera. |
| `plane_transform(origin, a, b)` | The Transform2D that maps a plane's local (x, y) to the screen: for drawing into a face, or setting on a node (a MotionSvg on a face). |

### MotionSolid (RefCounted)

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

### MotionExtrude (RefCounted)

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

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| 2.5D extrusion | `MotionExtrude` + `MotionSolid` + `MotionExtrudeCamera`: build boxes, cylinders, pipes, wedges or SVG slabs, set them from `f`, `prepare()`, then `draw(canvas, filter)`. Animate the camera's yaw and pitch from isometric to 0/0 for a flat front view; move `origin.z` with `clip_z = 0` to raise solids out of the ground; put logos on caps with `cap_transform` and a `cap_polygon` mask; label faces with decals and `draw_text`. | Take 2 Megastructure: an isometric machine city rising in rings, the Minimal Humans monument unfolding its M layers in depth, the FTF logo rising out of the floor as one slab, read in a flat front elevation. |
