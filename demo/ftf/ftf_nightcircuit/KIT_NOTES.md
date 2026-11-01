# Kit notes: patterned 3D worlds (from the Night Circuit take)

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

## API rows (for docs/API.md)

### MotionPattern3D (static)

| Member | Notes |
| --- | --- |
| `material(color_a, color_b, cell, space, pattern) -> ShaderMaterial` | `space`: `WORLD_XZ` (floors; world-locked, so the mesh can follow the camera), `UV` (UVs in metres, see `box()`: cells line up with each face's edges whatever its rotation), `TRIPLANAR` (XZ / ZY / XY by face normal). `pattern`: `CHECKER`, `STRIPES`, `GRID`, `SOLID`. Vertex colour tints `color_a` (one material, many building colours) |
| Shader parameters | `cell` (m), `offset` (cells; scroll), `uv_scale` (UV to metres for `UV` space, e.g. an extruded logo's 0..1 UVs), `line_width`, `energy`, `energy_b`, `motion`, `face_shade` (brightness of faces facing x / y / z), `sheen_color` / `sheen_dir` / `sheen_power`, `ring` / `ring_color` / `ring_energy` / `ring_push`, `grow`, `lit_from` / `lit_to` / `lit_soft` / `dim` (as `MotionStage3D.unlit()`) |
| `ground(parent, mat, size, y) -> MeshInstance3D`, `follow(floor, camera_pos)` | An endless floor: a big plane kept under the camera each frame; the pattern stays put |
| `motion_for(a, b, shutter) -> Vector3` | The `motion` uniform for a camera moving a to b in a frame: the filter footprint widens by the movement while the shutter is open, so a fast board smears along the travel instead of strobing or running backwards |
| `ring(mat, centre, radius, width, col, push)` | A shockwave ring on the floor (world centre; tints and pushes the pattern). `radius <= 0` turns it off |
| `grow(mat, key, from, to)` | Sprouts geometry: model-space y is scaled by `1 - smoothstep(from, to, UV2.x - key)`. Towers keyed by track distance with `key` = the camera's distance lie flat far ahead and rise as you approach (keeps the horizon and the sun open down a long straight) |
| `box(st, xform, size, col, uv2x, top)`, `quad(st, a, b, c, d, col, uv2x, uv0)` | Geometry for `UV` space: UVs in metres on every face (v from each side's base), UV2.x = a key for light windows and `grow` |

### MotionSkyDome3D (MeshInstance3D)

| Member | Notes |
| --- | --- |
| `sky_top`, `sky_horizon`, `sky_spread`, `sky_curve` | Gradient (spread = elevation sine where it reaches the top; curve = exponent) |
| `sun_elevation`, `sun_azimuth`, `sun_size` (degrees), `sun_top`, `sun_bottom`, `sun_bands`, `sun_glow`, `sun_energy`, `horizon_cut` | The MotionPatternPlane sun: a vertical gradient, OutRun bands (count, scroll, top of the banded area), glow; `horizon_cut` hides what has sunk below the horizon. Azimuth 0 looks down -Z, positive turns right |
| `level`, `radius` | Fade to black; dome radius (inside the camera's far plane) |
| `follow(camera)`, `sun_direction()`, `fog_to(environment)` | Centre on the camera each frame; unit vector to the sun (a floor's `sheen_dir`); set the fog colour to the horizon so fogged ground meets the sky without a seam |

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Patterned 3D worlds | `MotionPattern3D.material()` on a `ground()` plane (world XZ, `motion_for()` against strobing, `sheen` toward the sun, `ring()` shockwaves) and on `box()`-built towers / gantries (UV space, vertex colours, `grow()` to sprout them as the camera nears); `MotionSkyDome3D` for the banded sun; a logo plate with checks via `uv_scale` | The FTF Night Circuit take: a neon skyway over an endless checkerboard at dusk, checker towers sprouting and streaming past, checkered gantries, the FTF sign on checkered pillars rising out of the board with a shockwave, the OutRun sun framed under it and sinking at the end |

## Frame purity

Every uniform is set from `f` in `_frame`. The camera's distance along the circuit
is a table integrated once (eighths of a frame) and looked up; the board's
`motion` comes from the circuit at `s(f - 0.5)` and `s(f + 0.5)`; the sign's
transform, the ring centre (the sign's position at the ring's start frame), `grow`
and the light windows are functions of `f`. The ground plane and sky dome follow
the camera, which is itself a function of `f`. Checked: frames 101, 197 and 333
rendered by seeking are pixel-identical (max difference 0) to the same frames of
the continuous render.

## Cost

The pattern shader is a handful of ALU per pixel (one box-filtered checker, a
derivative normal, optional sheen and ring) with no textures; the sky dome is one
sphere. Towers, gantries and pylons merge into one ArrayMesh per material. The
whole take (stage with MSAA 4x and glow, ~10 panel viewports, ~300 towers)
renders at about 0.8 s a frame under Xvfb software GL on the shared 2 cores
(5 min 40 s for the 420 frames, including Movie Maker PNG writes).

## Limits

- The pattern's motion blur is a widened box filter along the world motion
  (good for a board under a moving camera); it does not blur geometry edges.
- `UV` space needs UVs in metres: use `box()` / `quad()`, or `uv_scale` for 0..1
  UVs. Triplanar space is axis-aligned (rotated boxes get diagonal cells).
- `grow` scales model-space y toward 0: keep the ground at the mesh's y = 0 and
  key whole buildings with one UV2.x so they rise as one.
- Face normals come from screen derivatives (flat faces only; no smoothing).
- Fog is the environment's (exponential here): set `fog_to()` so the horizon and
  fog agree; very low sun elevations need the ground to cover the dome below it.
