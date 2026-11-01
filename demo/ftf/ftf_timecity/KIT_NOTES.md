# Kit notes: heavy content through time displacement (Time City)

Round 4, Time City (Megastructure x Slit-Scan). The city of take 2 (MotionExtrude,
~600 solids) seen through MotionTimeSlices. Instanced naively that is one full
city per band (24-32 bands, 40-75 ms of draw each, plus its own sort): several
seconds a frame. Two new kit files and one pattern make it affordable. No
existing kit file was changed.

## New: `addons/motion_kit/fx/motion_view_rect.gd` (`class_name MotionViewRect`)

What part of a node's own space its viewport actually shows, for content that
culls itself. Each MotionTimeSlices band renders its instance into a
band-sized SubViewport with the content shifted to the band's source rect, so
the content can ask which strip it is drawing and skip everything else.

| Member | Notes |
| --- | --- |
| `of(item, pad = 0)` (static) | The rect of `item`'s local space its viewport shows (inverse canvas transform of the viewport's visible rect), grown by `pad`. In a band: that band's strip; at the root: the frame, through any shake or scale. Empty when not in the tree. Call it in `_frame` (MotionTimeSlices / MotionTimeCache place their holders before the walk reaches the content). |
| `is_partial(item, full)` (static) | True when the item renders into something smaller than `full`. |
| `box(cam, centre, half)` (static) | Screen bounds of a world box through an orthographic MotionExtrudeCamera: a cheap, exact per-cell cull before positioning anything. |

## New: `addons/motion_kit/fx/motion_time_cache.gd` (`class_name MotionTimeCache`)

Slit-scan and channel splits that render each moment once. Where every band
shows the same part of the content and only the moment differs, bands with an
equal (quantised) delay share one render.

| Member | Notes |
| --- | --- |
| `scene` / `builder`, `size` | As MotionTimeSlices. |
| `layout` | `ROWS`, `COLUMNS` (slit-scan: every band shows the slit, stretched across the band) or `CHANNELS` (three full-frame copies tinted R, G, B and added). |
| `bands`, `slots` | Number of bands; most distinct moments rendered per frame (one content instance each, built once). More distinct delays than slots are merged to `slots` evenly spaced levels. |
| `delay`, `profile` (MotionTimeSlices.Profile), `waves`, `phase`, `seed_value`, `profile_fn`, `step` | As MotionTimeSlices; `step` (default 1 frame) is what makes bands share. |
| `slit_pos`, `slit_width` | The slit each slot renders (a `slit_width`-pixel column or row): the slot viewport is that size, so a slot costs a line, not a frame. |
| `channel_shares` | CHANNELS: delay share per channel. `[1, 0, 0]` = red lags, green and blue together: a red/cyan split in two renders instead of three. |
| `reveal`, `reveal_from` | Show only some bands (as MotionTimeSlices). |
| `region()`, `moments()`, `profile_at(u, k)`, `rebuild()` | Helpers. |

Frame purity: the delays, their distinct sorted set and the slot each moment
goes to are recomputed from f every frame; a slot is a nested composition with
`start` = its delay. Nothing persists. Hand-over from MotionTimeSlices: fold the
columns into the slit at delay 0 (every band then shows the same line), switch,
then grow the delay: the switch is invisible.

## Pattern: shared world, per-band pose (in this take)

`city_world.gd` holds the solids once (a static shared by every instance of
`src_city.gd`). Each instance only stores its own `f` and view rect:

- `_frame(f)`: `view = MotionViewRect.of(self, 6)`; a light pose (camera,
  monument, logo slab: enough for SVG cap transforms and masks).
- every draw_fn starts with `world.pose(f, view)`: camera, then each cell is
  culled by `MotionViewRect.box` before its heights are computed, then
  `MotionExtrude.cull_rect = view` and `prepare()` sorts only what the strip
  shows. Posing is a pure function of (f, view) and is skipped when the world
  is already posed for that pair, so it runs once per band per frame. Canvas
  redraws run in queue order, so one band's canvases draw back to back.
- decals that draw long strips (the platform's serial band) cull their items
  to the view too.

## techniques.md rows

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Heavy content through time slices | Content calls `MotionViewRect.of(self)` in `_frame` and culls to it (MotionExtrude: `cull_rect` + per-cell `MotionViewRect.box`); keep geometry in one shared static world and pose it per instance at draw time. Rows/columns then cost about one picture plus a per-band overhead. | Time City: the 600-solid machine city through 32 columns and 24 rows. |
| Slit-scan / channel split cache | `MotionTimeCache` (COLUMNS / ROWS / CHANNELS) with `step` quantised delays: each distinct delay rendered once into a slit-sized slot and shared. | Time City outro: 96 slit-scan columns from ~19 renders of a 3-pixel line; red/cyan time splits on the hold accents from two renders. |

## Cost (measured)

Shared 2-core VM, Xvfb + llvmpipe. Full Movie Maker render of the take: 420
frames in 233 s, **0.55 s a frame** on average. Per mode, from a harness that
calls `render(f)` and forces a draw (script + draw_fns + GL, no PNG write):

| Mode | Instances posed | Cost a frame |
| --- | --- | --- |
| plain (one city) | 1 | ~0.40 s |
| 32 columns, time wave / ripple (MotionTimeSlices) | 27-32 | ~0.48 s |
| 24 rows, crane / slab smear (MotionTimeSlices) | 24 | ~0.80-0.87 s |
| 32 columns folding into the slit (MotionTimeSlices) | 32 | ~0.89 s |
| red/cyan split (MotionTimeCache CHANNELS, 2 slots) | 2 | ~0.65-0.72 s |
| 96-column slit-scan (MotionTimeCache, <= 15 slots of 3 px) | 13-17 | ~0.24 s |

For comparison, the same 96-column streak through MotionTimeSlices measured
1.9 s a frame (96 posed bands), and posing each band twice (once in `_frame`,
once at draw) cost ~40 % more script time than the light-pose split above.
Without the per-band cull every band would draw the whole city (40-75 ms of
draw plus its sort each).

Limits: MotionViewRect culling needs content that can cull (MotionExtrude,
or your own bounds); BOXES bands each contain the centre, so culling helps
them little. MotionTimeCache only covers the shared-slit and channel cases:
for plain time displacement (each band its own place) MotionTimeSlices with a
culling content is the cheaper one (band-sized renders). Slots are built once
(`slots` instances), so keep `slots` to what the profile needs.
