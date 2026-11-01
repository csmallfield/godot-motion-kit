# Kit notes: flow along paths and liquid fill (`addons/motion_kit/flow/`)

New in the Fuel Lines take. Two classes, pure GDScript, no shaders; no existing
kit file was changed.

| File | Class |
| --- | --- |
| `motion_flow.gd` | `MotionFlow` (Node2D): fluid flowing along a network of pipes |
| `motion_liquid_fill.gd` | `MotionLiquidFill` (Node2D): content revealed below a sloshing liquid surface |

## API

### MotionFlow (Node2D)

A network of thick paths drawn in one `_draw`. Pipes are built once; every
frame you set each pipe's state (how far the fluid has got, how far it has
drained, how far its contents have moved), and the pipe draws wall, core,
fluid, pulses, bubbles and a bright travelling front from that state alone.

| Member | Notes |
| --- | --- |
| `add_pipe(points, opts) -> int` | A pipe through `points` (local px). `opts`: `width`, `wall_width`, `radius` (corners rounded once at build), `segments`, `wall`, `core`, `fluid`, `pulse` (pulse colour), `caps`, `arrows` (spacing of flow arrows on the core, 0 = none), `arrow_color`. Use `width` with `wall_width = 0` and transparent wall/core for pulses alone (a light chasing round an outline). |
| `add_node(pos, radius, ring, fill) -> int`, `set_node(i, {o, lit})` | Fittings and junctions drawn over the pipes. |
| `set_state(i, d)`, `apply(fn)` | Per-frame state; `apply(func(i): return {...})` like `MotionSvg.apply`. Unset keys reset to defaults. |
| state `draw`, `draw_from` | 0..1 of the wall drawn (a pipe tracing itself; un-drawing from its start). |
| state `fill`, `drain` | 0..1 fluid front and tail along the pipe: animate `fill` 0→1 for fuel arriving, `drain` 0→1 for a line emptying behind it. |
| state `flow` | px the contents have moved; drives pulses and bubbles. `f * speed` for a steady flow, a stepped/eased beat count for pumped flow. |
| state `pulse_len`, `pulse_gap`, `pulse_gain`, `pulse_color` | Slugs of brighter fluid moving with the flow. |
| state `glow`, `front_glow`, `bubbles`, `bubble_speed`, `bubble_color`, `fluid`, `opacity` | Halo strokes round the fluid, a bright bead on the travelling front, bubbles, per-frame colour override (purges, colour changes), opacity. |
| `length(i)`, `points(i)`, `point_at(i, s)`, `tangent_at(i, s)` | Arc-length queries (px), to place valves, labels or sounds on a pipe. |
| static `rounded(pts, r, seg)`, `sub_path(rec, a, b)` | Corner rounding; the piece of a pipe between two arc lengths. |

### MotionLiquidFill (Node2D)

A vessel (the rect 0..`size`) filling with liquid. Children of `fill` show only
below the surface, so a logo in its own colours fills up like a tank; children
of `surface` show only in a thin band at the surface (a lighter copy of the
logo makes a meniscus that follows the vessel's shape; with no children a plain
line is drawn).

| Member | Notes |
| --- | --- |
| `size`, `fill_level` (was `level`) | Vessel size; 0 = surface at the bottom edge, 1 = at the top (above 1 = brim-full, surface out of sight; just under 1 keeps a sloshing band in the top). |
| `tilt` | Surface slope (px, right end up). |
| `kicks` | Slosh impulses: `Vector2(frame, strength)` or `{at, amp, mode}` (mode 1 end-to-end, 2 central hump, default both). Pour, beat slaps, a slam. |
| `wave_amp`, `wave_freq`, `damping` | Slosh px per unit kick, angular frequency (rad/frame), decay per frame. |
| `ripple`, `ripple_len`, `ripple_speed` | Small travelling ripples always running. |
| `meniscus`, `meniscus_color` | Band thickness; plain line colour when `surface` is empty. |
| `bubbles`, `bubble_color`, `bubble_size`, `bubble_speed`, `seed` | Bubbles rising below the surface. |
| `foam`, `foam_color` | A row of small bubbles just under the surface (not drawn above a brim-full vessel). |
| `fill`, `surface` | Add content here. |
| `surface_y(x)` | Surface height (local px) at x, for placing things on it. |
| static `slosh(f, x01, kicks, amp, freq, damp) -> float` | The same slosh as a function, for vessels drawn in a canvas (sight glasses). |

Masks are drawn with draw calls on `clip_children` canvases, so they follow the
node's transform; the mask and band hide themselves when they would be empty
(an empty clip mask clips nothing).

**Frame purity.** Both are pure functions of the state set from `f`: the
surface is analytic (level, tilt, damped standing waves from the kick list,
travelling ripples), bubbles and foam are seeded by index and `f`, pipe
contents are positioned by arc length from `flow`. Nothing integrates between
frames. Pumped motion (pulses lurching on each beat) is a stepped, eased beat
count of `f`; a pump's rotation in the take is a running sum of its speed curve
built once into a table and looked up by frame. Frames reached by seeking match
the straight render.

**Cost.** MotionFlow: one `_draw`, a few polylines per pipe plus one per pulse
and bubble; the take's 9 pipes with pulses and bubbles are well under a
millisecond of script. MotionLiquidFill: one 64-point surface evaluated a few
times per frame (cost grows with the number of kicks, ~30 here) and two clip
canvases; the revealed content (a MotionSvg) draws twice (fill and meniscus
copy). The full take renders at about 0.28 s a frame under Xvfb software GL.

**Limits.** Pipe joins come from Godot's `draw_polyline`, so keep corners
rounded (the default radius) rather than sharp. The vessel is a rect: the
liquid follows its content's shape only because the content itself is the
shape (put the logo under `fill`). Slosh is a visual model, not a simulation.

## techniques.md rows

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Flow along paths | `MotionFlow.add_pipe(points, {width, fluid})`, then each frame `apply(func(i): return {draw, fill, drain, flow, pulse_gain})`: `draw` traces the pipe, `fill` sends fluid down it, `drain` empties it, `flow` moves pulses and bubbles; a stepped beat count in `flow` makes it pump. | FTF Fuel Lines: a fuel schematic whose lines trace themselves, flood on valve beats, lurch on every beat in the hold and drain one by one in the outro; pulses chasing round the logo's rim as a pressure ring. Also: a data bus in a HUD, a loading bar that is a pipe, a route preview. |
| Liquid fill | `MotionLiquidFill` with the logo under `fill` (and a lighter copy under `surface`); animate `fill_level`, give `kicks` for pours and slams. | The Minimal Humans lockup filling with fuel in its own colours and draining away; the FTF logo racing to brim-full on the drop and slapping in its top band on every beat; sight glasses using `MotionLiquidFill.slosh()`. |
