# Kit notes: MotionPatternPlane (ray-cast pattern planes)

New files in `addons/motion_kit/plane/`: `motion_pattern_plane.gd` (`class_name
MotionPatternPlane`, `@tool`, extends `Node2D`) and `motion_pattern_plane.gdshader`.
No existing kit file was changed.

## API (rows for docs/API.md)

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
| `draw_checker_quad(c, a, b, cc, d, cols, rows, col_a, col_b, min_px, near)` | Draw a planar quad of camera-relative corners into a `MotionCanvas` as a perspective-correct checkerboard (projected vertex by vertex), fogged like the plane, clipped at the near plane, falling back to one flat polygon when cells get smaller than `min_px`. Checker skyscrapers are two calls per building. |

### Sandwich layers

Draw the plane twice: a full layer at the back, and a front layer (`copy_from` the back one,
`draw_sky = false`, `ceiling = false`, `clip = Vector2(-1e9, D)`). Anything drawn between them
standing at forward distance D is hidden where it goes below the ground, so a sign or logo
rises out of the floor or sinks back into it, and a monument rises over the horizon. Canvas
geometry nearer than D goes after the front layer; farther goes between the back layer and
the sandwiched sign.

### Frame purity

Every property is set from `f`; the shader reads only uniforms and the pixel position.
Travel is a table built once from a speed profile (integrated on eighths of a frame) and
looked up by frame. In the FTF take, frames rendered by seeking straight to them match the
continuous render (checked at frames 100, 230 and 360).

### Cost

One full-screen quad per layer: a ray-quadric intersection, a box-filtered pattern with
screen-space derivatives, fog, sky and sun. Under Xvfb software GL two full-screen layers,
up to ~50 checker buildings (about 2,000 small polygons drawn straight with
`draw_colored_polygon`) and the logos render at about 0.6 s a frame on the shared 2 cores.

### Limits

- `wave` and `ring_push` move the pattern, not the geometry (they don't change the silhouette).
- `curve` is a shear of the pattern and of points placed with `ground_point`; it is not a true
  bend of the geometry, so it looks right for moderate values (OutRun roads).
- The ceiling is flat (no bends) and is skipped where the bent ground is nearer.
- Strong `channel` turns the floor into a parabolic tube centred on the camera, not a cylinder.
- `draw_checker_quad` cells are not antialiased: render with MSAA or supersampling if it matters.

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Pattern planes | `MotionPatternPlane`: set `ground_offset.y` from a travel table, `pitch`/`yaw`/`roll`/`height` for the camera, `curve`/`channel`/`hill`/`wave` to bend it, `cell` to pulse it, `motion_blur_for()` against strobing; sandwich a sign between a back and a `clip`ped front layer so it rises out of the floor; place canvas geometry with `project()` / `ground_point()` / `draw_checker_quad()`. | The FTF Checkerboard City take: a dive onto the board, a checker city sprouting, the Minimal Humans monument rising over the horizon at sunrise, a barrel roll through the board curled into a tube, the FTF logo rising out of the floor on the drop with a shockwave through the checks, and the ground folding up into a wall. Also: an OutRun road, a Tron grid menu floor, an op-art loading screen. |
