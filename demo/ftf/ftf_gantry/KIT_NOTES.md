# Kit notes: 3D in compositions (from the Gantry take)

New files in `addons/motion_kit/three/` (no existing kit file was edited):

| File | Class / role |
| --- | --- |
| `motion_stage_3d.gd` | `MotionStage3D` (Node2D): a 3D world rendered in an internal SubViewport and drawn as part of the 2D piece |
| `motion_svg_mesh.gd` | `MotionSvgMesh` (RefCounted): extruded 3D ArrayMeshes from `MotionSvgData` |
| `motion_panel_3d.gd` | `MotionPanel3D` (MeshInstance3D): any 2D kit content on a quad in the 3D world |
| `motion_unlit_3d.gdshader` | flat emissive material: vertex colour x tint x energy, light window on UV2.x, environment fog |
| `motion_panel_3d.gdshader` | the panel's unshaded textured material |

## API rows (for docs/API.md)

### MotionStage3D (Node2D)

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

### MotionSvgMesh (static)

| Member | Notes |
| --- | --- |
| `build(data, width, opts) -> ArrayMesh` | Every part extruded: front cap (+Z), back cap, side walls; one surface. `opts`: `depth`, `tolerance`, `anchor`, `layer` (z step per part), `side_shade`, `only`, `part_fn(i) -> {hide, color, side_color, back_color, depth, z}`, `uv2_x(i, uv) -> float` |
| `append(st, data, width, opts, xform)` | The same into an open SurfaceTool (merge logos into larger meshes) |
| Vertex data | COLOR = part colour (sides darker), UV = viewBox position 0..1, UV2 = (UV.x, part index) |
| Holes | A contour inside an odd number of the part's other contours (majority of its vertices inside) is a hole; caps cut each hole open with a hairline slit so Godot's ear-clipper sees simple polygons; side walls follow the true contours. Triangles are not consistently wound: use a material with culling off (`unlit()` is) |

### MotionPanel3D (MeshInstance3D)

| Member | Notes |
| --- | --- |
| `pixel_size`, `world_size` | Panel resolution and quad size (quad in local XY, facing +Z) |
| `canvas: Node2D` | Put kit 2D nodes here; (0,0) is the top-left pixel |
| `energy`, `tint`, `background` | Brightness (above 1 glows), tint, fill behind the content |
| `animated`, `refresh()` | Re-render every frame, or once (static boards are cheaper) |

## techniques.md rows

| Technique | How to use it | Practical example |
| --- | --- | --- |
| 3D stage in a composition | `MotionStage3D` hosts a World3D; set the camera from `f` in `_frame` (`ride()` along a Curve3D, `blend()` to a hero pose); 2D type and HUD sit over it; `to_screen()` pins callouts to 3D points | The FTF Gantry take: a camera riding a banked neon circuit, then craning to face the logo sign, with callouts pinned to its corners |
| Extruded logos | `MotionSvgMesh.build(svg, width, {depth, part_fn})`, one MeshInstance3D with `MotionStage3D.unlit()`; raise letters with `part_fn` depth/z | The Minimal Humans lockup and the FTF logo as solid signs on gantries; the camera, not the letters, does the animating |
| Light chases and trails | Write a distance into UV2.x (track distance, logo x); animate `lit_to` for a chase, `lit_from`/`lit_to` together for a moving window | The circuit powering up beat by beat and cutting far-to-near in the outro; ships as light trails on a ribbon along the track |
| 2D on 3D surfaces | `MotionPanel3D` with kit text and marks under `canvas` | PRESENTS typing across a gantry beam; sponsor boards and DR billboards with katakana and chevrons |

## Frame purity and cost

- Nothing integrates at runtime: the camera's distance along the circuit is a table
  built once from a speed profile (integrated on eighths of a frame) and looked up by
  frame; materials and camera are set from `f` only. Seeking, scrubbing and reverse work.
- Geometry is built once (about 25 ms for an extruded logo of ~7k vertices); the
  circuit, gantries, tunnel and skyline are merged into a few ArrayMeshes, one per
  material, so a frame is about a dozen draw calls plus one viewport per panel.
- Software GL (llvmpipe, 1920×1080, MSAA 4x, glow, 2 shared cores): about 0.65 s a
  frame, 4.5 minutes for the 420-frame piece. Static panels use `animated = false`.
