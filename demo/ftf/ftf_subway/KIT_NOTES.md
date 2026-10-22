# Kit notes: MotionMetroMap (transit diagrams)

New file: `addons/motion_kit/metro/motion_metro_map.gd` (`class_name MotionMetroMap`,
`@tool`, extends `RefCounted`). No existing kit file was changed.

## API (rows for docs/API.md)

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
| `length(i)`, `path(i)`, `point_at(i, s)`, `dir_at(i, s)`, `sub_path(i, a, b)`, `s_near(i, p)` | Arc-length queries (pixels; closed lines wrap). |
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

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Transit maps | `MotionMetroMap`: `add_line` with grid waypoints (or `add_path` with any contour), `build()`, then in a `MotionCanvas` draw each line with `draw_line(c, i, a, b)` for draw-on and retract, `draw_train` by arc length, `draw_interchange` at hubs and `MotionMetroMap.label` for zoom-proof station names. Lines that share corridors bundle and bend concentrically. | The FTF Insane Subway Map take: MINIMAL HUMANS written as triple routes (stacked red, amber and cream like the M monogram), a 140-line network exploding on eighths while the camera rides the pink line's head, and the FTF logo built from concentric contour lines (`Geometry2D.offset_polygon` rings added with `add_path`) with trains circling the letters and a light chasing round every contour on each beat. Also: a route preview in a menu, a progress map between levels, a tube-style track select. |
