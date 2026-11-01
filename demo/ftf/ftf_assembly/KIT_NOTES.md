# Kit notes: voxelise and choreograph blocks (`addons/motion_kit/voxel/`)

New in round 4 (Assembly). Three classes, all `@tool`, pure GDScript, no
shaders, no new nodes: they plug into the 2.5D extrusion classes
(`MotionExtrude` / `MotionSolid` / `MotionExtrudeCamera`). No existing kit file
was edited. Merge these rows into `docs/API.md` and `docs/techniques.md`.

## API

### MotionVoxelize (RefCounted)

Sample a mask onto a grid of cells, once, at build time.

| Member | Notes |
| --- | --- |
| `from_svg(data, cols, rows, parts = [], area = viewBox, ss = 3, threshold = 0.45, offsets = {})` (static) | Sample a MotionSvgData's parts (default: every filled part) with `ss`×`ss` samples per cell. Fill rules (nonzero/even-odd) are honoured, so counters stay open; later parts cover earlier ones. `offsets` (part → Vector2 in SVG units) shifts parts before sampling: pull stacked layers apart so each shows as its own band of cells (the MH M's three layers become three tiers). |
| `from_image(img, cols, rows, area, ss, threshold, use_luma)` (static) | Sample an Image's alpha (or luminance). For a CanvasItem mask, render it once into a SubViewport and pass `get_texture().get_image()`. Part is 0. |
| `from_fn(fn, cols, rows, ss, threshold)` (static) | `fn(uv: Vector2) -> int` over 0..1 (y down), a part id or -1. |
| `cols`, `rows`, `rect`, `cover`, `part`, `threshold` | Coverage 0..1 per cell; the majority part per cell (-1 empty); cells with `cover >= threshold` are filled. Row 0 is the top of the mask. |
| `filled(c, r)`, `part_at(c, r)` | |
| `targets(height_fn)` | Every filled cell as `{cell: Vector2i, h: float, part: int}`; `height_fn(part, cover, cell) -> float` sets the height (letters tall, plate low; <= 0 drops the cell). |
| `world(cell, origin)` | A cell's south-west corner on a ground grid (+y north, row 0 northmost), `origin` the grid's south-west cell. |
| `inside(contours, pt, evenodd)` (static) | Point in a multi-contour shape. |
| `ascii()` | The filled cells as text, one letter per part: check a resolution before building anything. |

### MotionBlockPlan (RefCounted)

One move per block from layout A to layout B, in grid moves, in waves; a pure
function of the frame.

| Member | Notes |
| --- | --- |
| `MotionBlockPlan.new(n)`, `resize(n)`, `size()` | |
| `start`, `waves`, `wave_step`, `dur`, `jitter` | Wave k starts at `start + k * wave_step` (a beat, so moves land on the beat); each move takes `dur` frames; inside a wave, up to `jitter` frames of delay follow the key, so a wave ripples instead of firing as one block (and never as a per-letter cascade). |
| `lift`, `slide_max`, `sink_share`, `land`, `seed_v` | Flying cruise height (±40% per block, so crossing blocks fly at different heights); moves up to `slide_max` cells slide on the ground, longer ones fly (or, for `sink_share` of them, sink and rise); height overshoot on landing (servo telescoping). |
| `set_move(i, a, b, key, style = -1)` | `a`, `b` = Vector3(x, y, height). `key` 0..1 picks the wave (e.g. the target's elliptical distance from the logo's centre: middle out). `style`: `STAY` (height only), `SLIDE` (two axis legs on the ground, x/y order seeded), `FLY` (lift, two legs in the air, drop), `SINK` (down at the source, up at the target); -1 picks. |
| `pose(i, f)` | Vector4(x, y, lift above ground, height) at frame f. Clamped: before the move it returns `a`, after it `b`, so a chain of plans (A→B, B→C…) is evaluated by picking the latest plan whose `start` has passed. |
| `progress(i, f)`, `starts(i)`, `lands(i)`, `target(i)`, `origin(i)`, `style(i)`, `wave_frames()` | Light switches on landing, cues on wave frames. |
| `assign_nearest(blocks, targets, order = [], exclude = {})` (static) | Cheap matching: targets taken in `order` (default: farthest from their centroid first, so the rim claims blocks before the middle) each take the nearest free block, found with a bucketed ring search. Returns per target the block index (-1 when blocks ran out). Unassigned blocks are yours to park (crouch, sink). A block already standing on a target cell keeps it unless an earlier target took it, so the surplus never sits on a target. |

### MotionFaceLights (RefCounted, static helpers for decals)

| Member | Notes |
| --- | --- |
| `windows(c, size, sd, f, col, level, lit, flicker, period, floor_px, pane, margin, palette)` | Rows of lit windows on a wall decal: one `draw_dashed_line` per lit floor. `lit` share of floors on, `flicker` chance a floor toggles every `period` frames (seeded, frame-pure), `level` dims all (power on/off), `palette` picks a colour per floor. |
| `strip(c, a, b, col, w, glow, glow_alpha)` | A neon line: a wide faint glow under a thin core. |
| `rim(c, size, col, w, glow, glow_alpha)` | A neon strip round a face (a roof's edge). |
| `chase(c, size, phase, length, col, w, glow)`, `chase_path(c, pts, phase, length, col, w, glow)` | A dash of light running round a face's rim, or round any closed polyline (a logo outline in a `cap_transform`). |

Decal sizes are decal units (100 per world unit). Small blocks need
`MotionExtrude.min_decal_area` lowered (this piece uses 70 px²; the default
600 skips faces under ~25 px).

**Frame purity.** Sampling and matching run once in `_build`; every plan is a
packed table of numbers and `pose()` is closed-form (cheap closed-form easings,
no Callables). Windows flicker from `MK.rand(seed, floor, floor(f / period))`.
Nothing accumulates. Checked pixel-wise: frames 77 and 381 rendered by seeking
are identical to the full render (max difference 0); see the take's report for
the MotionSvg first-frame raster note.

**Cost.** Voxelising the two logos (72×20 and 68×16 cells, 3×3 samples) and
matching 1,616 blocks to 827 and 1,073 targets: about 1 s at build, once.
Per frame, the piece's `_frame` (posing every block, colours, the sort) is
16–44 ms on the shared 2-core VM. The full 420-frame render (1,616 boxes, up
to ~3,500 faces, window strips, roof strips and chases, ground grid, spill and
traffic) took 187 s under software GL: **0.44 s a frame**, including the
encoder.

**Limits.** One block per cell: legibility is the grid's. Check with
`ascii()`: 72 cells across the Minimal Humans lockup reads; 68 across the FTF
logo gives the shapes, not the small text, which is why the real logo slab
lands on it. Flying blocks are drawn in their own canvas above the city (the
painter's key is a ground key, so a block in the air would otherwise sort
behind towers it is above); two blocks sliding through the same cell overlap
for a few frames. Matching is greedy, not optimal: paths can cross.

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Voxel logo assembly | `MotionVoxelize.from_svg(data, cols, rows)` → `targets(height_fn)`; `MotionBlockPlan.assign_nearest(block_cells, target_cells)`; one `MotionBlockPlan` per transition with `set_move(i, from, to, key)`; per frame `pose(i, f)` sets each `MotionSolid` box's origin and depth. Light the faces with `MotionFaceLights` in decals; colour blocks by `progress()` so they light up as they land. | Round 4 Assembly: a night city's blocks re-stack into the Minimal Humans lockup (three height tiers in cream, amber, red) and then into the FTF logo, in waves on the beat; the vector logo slab slams onto the voxel sculpture on the drop. |

## Found while checking purity (existing kit, not changed)

`MotionSvg` picks its raster density from the viewport's final transform at
draw time. On the very first frame of a Movie Maker run that starts mid-piece
(`render.sh … <start>`, `stills.sh`), that density lands in a different bucket
than in a continuous run, so the slab artwork's edges differ by up to ~190/255
on antialiased edge pixels (nothing else on the frame differs). Rendering from
298 shows 298 differing and 299/300 identical to the full render: a cold-start
raster choice, not state in the piece. A fix belongs in `MotionSvg` (resolve
the viewport scale once the window is sized, or redraw on the second frame).
