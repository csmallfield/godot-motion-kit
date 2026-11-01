# Kit notes: flat graphic 3D and the perspective/orthographic lens (Canyon take)

New in round 4 (Canyon, "Through the Megastructure"). All new files live in
`addons/motion_kit/three/`; **no existing kit file was edited**. Merge these
rows into `docs/API.md` and `docs/techniques.md`.

| File | Class / role |
| --- | --- |
| `motion_lens_3d.gd` | `MotionLens3D` (RefCounted): a camera pose that blends perspective into orthographic without a pop, and matches a `MotionExtrudeCamera` exactly |
| `motion_flat_3d.gd` | `MotionFlat3D` (RefCounted): the MotionExtrude look in real 3D: face-tone materials, depth fog, frame-pure group motion, builders |
| `motion_edges_3d.gd` | `MotionEdges3D` (RefCounted): screen-space crease and silhouette outlines |
| `motion_decal_atlas.gd` | `MotionDecalAtlas` (Node): 2D kit drawings rendered once into an atlas for decals |
| `motion_flat_3d.gdshaderinc` | shared group motion (sink rings, beat pulse) and depth fog |
| `motion_flat_3d_faces.gdshaderinc` | the face-tone body |
| `motion_flat_3d.gdshader` / `motion_flat_3d_double.gdshader` | face tones, back faces culled / two-sided |
| `motion_edges_3d.gdshader` | constant-pixel-width outline ribbons |
| `motion_decal_3d.gdshader` | tinted, alpha-blended atlas decals |

## API rows (for docs/API.md)

### MotionLens3D (RefCounted)

A lens frames `target`: `frame_h` world units fill the screen height on the
plane through the target. `persp` scales perspective strength k = tan(fov/2) ·
persp; the camera sits at distance frame_h / 2k, so lowering persp is a dolly
zoom that keeps the target the same size. Past `ortho_at` the lens becomes a
true orthographic camera of size `frame_h` (the residual perspective there is
depth range / distance, about 0.1 %, under a pixel at the frame edge).

| Member | Notes |
| --- | --- |
| `target`, `basis`, `frame_h`, `persp`, `fov` | Framed point, orientation (−Z looks at the target), world units across the screen height, perspective strength 0..1, vertical FOV at persp 1 |
| `offset` | Screen offset of the target in pixels (MotionExtrudeCamera `centre` − screen centre; also good for shakes). Perspective: a lens shift (frustum offset); orthographic: camera h/v offset |
| `keep`, `depth`, `near_min`, `ortho_at`, `view_h` | Scene depth kept in front of the target (the near plane rides there once the camera backs away, clearing what would come between), behind it (far plane); smallest near plane; ortho switch distance (20000); screen height in px |
| static `look(from, at, fov, up, roll)` | A free perspective camera as a lens |
| static `from_transform(xf, fov, focus)` | Any camera transform, framing the point `focus` ahead |
| static `extrude(yaw, pitch, scale, at, centre, screen)` | The exact orthographic view a `MotionExtrudeCamera` with these values draws (45 / 35.264 = true isometric), in Godot axes |
| static `extrude_basis(yaw, pitch)`, `from_extrude(p)` | The matching camera basis; MotionExtrude (x east, y north, z up) → Godot (x, z, −y) |
| `mix(b, t, t_lens = t)` | Blend: target lerp, basis slerp, frame_h in log space, k linear (an even flattening). A separate `t_lens` flattens later than the view turns, so the backing-away camera clears the scene |
| `apply(camera)` | Sets projection (FRUSTUM for perspective: Camera3D clamps `fov` to ≥ 1°, the frustum's near-plane size has no limit), size, near/far, transform and offsets |
| `k()`, `camera_distance()`, `is_ortho()`, `transform()`, `project(p)` | Helpers; `project` predicts screen positions without a camera |

### MotionFlat3D (RefCounted)

| Member | Notes |
| --- | --- |
| `material(top, lit, dark, under, soft, moves = true, two_sided = false)` | Face tones by world normal: up-facing `top`, sides facing the horizontal `light` `lit`, sides facing away `dark`, down-facing `under`; `soft` 0 = a hard poster terminator. Vertex colour multiplies. `moves` false = ignores group motion (ground). `two_sided` for meshes without consistent winding (MotionSvgMesh: paint white tones so the part colours show) |
| `edges(color, width_px, bias)`, `decals(atlas, moves)`, `register(m, moves)` | Outline / decal materials registered with the look; any shader including `motion_flat_3d.gdshaderinc` can be registered |
| `light`, `energy`, `fog_color/begin/end/amount` | Horizontal light direction (Godot axes); brightness (fade to black); linear depth fog |
| `fog(color, begin, end, amount)`, `fog_for(lens, color, before, after, amount)` | Depth fog; `fog_for` measures from a lens's target plane, so the dolly zoom keeps the same fog around what it frames |
| `sink(origin, t, step, width, dur, depth)` | Rings sinking from `origin` (ground x, z): ring k = floor(d / width) starts at t = k·step and drops `depth` over `dur` frames (ease in). Into an opaque ground: the ground hides what sinks |
| `pulse(origin, t, amp, speed, decay, reach)` | A bob running out at `speed` units/frame, `t` = frames since the beat |
| `apply()` | Push everything to every registered material, once per frame |
| `offset(key)` | The shader's group offset in GDScript, for nodes moved on the CPU (traffic) |
| static `begin()`, `instance(mesh, mat)` | SurfaceTool / MeshInstance3D helpers |
| static `box(st, p, size, key, col, edges, bottom)`, `cylinder(st, base, r, h, key, col, edges, seg)`, `pipe(st, a, b, r, key, col, edges, seg)`, `quad(...)`, `decal(st, c, half_u, half_v, uv, key, col)` | Builders with explicit normals, Godot winding, vertex colour and the group key in UV2; pass a `MotionEdges3D` to get the matching outline. Cylinders are flat-faceted (crisp terminator, identical in perspective and ortho) |

Group key: every vertex's UV2 holds its object's ground anchor (x, z). The
vertex stage adds the group offset to y, so faces, edges and decals of one
object move together inside merged meshes; nodes using the same key (a crane
on a tower) move with it too.

### MotionEdges3D (RefCounted)

| Member | Notes |
| --- | --- |
| `add(a, b, na, nb, kind, key)`, `add_loop(...)`, `commit()`, `count()` | Edge a→b between faces with normals na, nb. Kinds: `SMOOTH` (silhouette only: one face toward the camera, one away), `CREASE` (when either face looks at the camera), `ALWAYS` (the depth test decides) |
| static `material(color, width_px, bias)` | Constant pixel width in perspective and ortho; ends extended half a width so corners close; pulled `bias` units toward the camera to beat its own faces; near-plane clipping per segment |
| static `from_mesh(mesh, {crease_deg, weld, kind, key, xform})` | Outline any mesh: welds vertices, keeps boundaries and creases (winding-proof |cos| test). Used on MotionSvgMesh logos (kind ALWAYS) |

### MotionDecalAtlas (Node)

| Member | Notes |
| --- | --- |
| `MotionDecalAtlas.new(size)`, `add(px, fn) -> Rect2` | Shelf-packed cells drawn by `fn(c: MotionCanvas, size)`; returns the UV rect for `MotionFlat3D.decal()`. Draw in white; vertex colour tints |
| `texture`, `viewport`, `pad`, `refresh()` | Renders once (UPDATE_ONCE); add it to the tree before the first frame (it renders before the 3D stage, so stills and seeks get their decals) |

## techniques.md rows

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Perspective → orthographic blend | `MotionLens3D.look(...)` for the flying camera, `MotionLens3D.extrude(45, 35.264, scale, target)` for the iso view, `fly.mix(iso, t_pose, t_lens).apply(stage.camera)`; `flat.fog_for(lens, ...)` and fade fog with t_lens | Canyon: the camera lifts out of a street and its view flattens into the Megastructure take's exact isometric view while the FTF slab rises out of the plaza |
| Flat graphic 3D | `MotionFlat3D` materials per palette colour (top/lit/dark), merged builders, `MotionEdges3D` outlines, `MotionDecalAtlas` markings | The MC-202 city as real 3D: the whole city in about ten draw calls, readable both in a low perspective canyon flight and in iso |
| City motion in the shader | Put each object's ground anchor in UV2; `flat.pulse(origin, f - beat)` and `flat.sink(origin, f - start)` every frame; `flat.offset(key)` for CPU nodes | The city bobbing in rings on every beat of the hold and sinking into the ground in rings at the end |

## Frame purity

Nothing integrates at runtime. The ride's distance along the route is a
monotone cubic (Fritsch–Carlson) through (frame, place) anchors, tabulated per
frame; walkways and pipe racks are built where the camera is on each beat
(so fly-bys land on the cue frames). Lens, materials, group motion, cranes,
traffic (positions modulo lane length), doors and the slab are set from `f`
only. The atlas and panels render from `f` (atlas once). Verified: frames 90,
230 and 300 rendered alone by seeking (`stills.sh`) are pixel-identical to the
same frames of the full render (max difference 0).

## Cost

- Build: every building and piece of street furniture is merged into one
  mesh per palette colour, one edge mesh, two decal meshes and the ground;
  plus monument, slab, 6 cranes and ~34 pods as small nodes.
- Per frame: ~0 ms of GDScript beyond setting ~20 uniforms per material.
- Render (software GL llvmpipe, 1920×1080, MSAA 4x, 2 shared cores): the
  420-frame piece in 3 min 34 s, about 0.51 s a frame, including the city
  build (a few seconds at startup).

## Limits

- Face tones assume an unshaded graphic look: no cast shadows or AO.
- Outlines are geometry: only edges that exist in the mesh (no screen-space
  contour of arbitrary implicit shapes); silhouettes of smooth meshes need
  consistent winding (the builders' meshes have it; MotionSvgMesh doesn't, so
  logos get crease outlines only).
- Decals are alpha-blended without mipmaps: very small far text shimmers
  (fog hides it in perspective; in iso the atlas is drawn near 1:1).
- `MotionLens3D` offsets are exact on the target plane; the ortho switch is
  a ~0.1 % residual perspective (measured < 0.25 mean pixel difference at the
  switch, flat-faceted geometry).
