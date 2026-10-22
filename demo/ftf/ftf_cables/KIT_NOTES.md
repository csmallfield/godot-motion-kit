# Kit notes: cables (`addons/motion_kit/cable/`)

New in the Cables take. Two classes, both `@tool`, pure GDScript (draw calls, no
shaders). No existing kit file was changed.

| File | Class |
| --- | --- |
| `motion_cable.gd` | `MotionCable` (RefCounted): one cable's description and its built curve |
| `motion_cable_set.gd` | `MotionCableSet` (extends MotionCanvas): draws cables as glossy shaded tubes in depth order, plus connector and socket helpers |

## API

### MotionCable (RefCounted)

A thick cable along a route of waypoints. Set its properties from `f`; a
`MotionCableSet` builds and draws it.

| Member | Notes |
| --- | --- |
| `points` | Route waypoints in pixels (≥ 2). The curve is a centripetal Catmull-Rom spline through every one (no cusps or loops where long and short spans meet, which a thick tube would turn into spikes). |
| `pinned` | false (default): the whole route hangs as one span between its ends: sag and wobble use one envelope over the route. true: every waypoint is a pin (hook, clip, the edge of a plate it wraps) and each span sags and wobbles on its own. |
| `tension`, `sag`, `sag_ref`, `gravity` | 0 = slack, 1 = taut. Sag in pixels for a span `sag_ref` px long (longer spans sag more, clamped ×0.15–3). Animate `tension` with a spring to pull a cable taut on a beat. |
| `tugs`, `static tug(at, amp, period, decay)` | Damped wobbles across the chord starting on frame `at` (pixels, frames per swing, frames to 1/e). A twang when a plug lands, a twitch on an accent, a whip when it's yanked. |
| `start`, `reveal` | The drawn part, 0..1 of the length. Grow `reveal` to snake a cable in head first along its route; shrink it to pull it back out the way it came. The head connector rides the `reveal` end. |
| `width`, `jacket`, `edge`, `gloss`, `light` | Tube diameter; body colour; rim colour (alpha 0 = jacket darkened); specular strength; direction towards the light (the highlight stays on the lit side as the cable turns). |
| `bands`, `stripe_every`, `stripe_len`, `stripe_color`, `stripe_phase` | Jacket bands `[{u, len, color}]` and repeating stripes, shaded like the tube. |
| `pulses` | Light pulses `[{u, len, color, power}]` drawn as glowing segments: animate `u` for current running along the cable. |
| `glow`, `glow_color` | A powered halo around the tube (0..1). |
| `glint` | A specular hotspot at u (< 0 off): slide it for a wet sheen. |
| `plug_head`, `plug_tail` | `Plug.NONE / JACK / MULTIPIN / BLADE / BARREL`. |
| `plug_color`, `plug_band`, `plug_lit`, `plug_light` | Connector housing, ID ring (alpha 0 = jacket), indicator brightness and colour. |
| `static plug_length(kind, width)` | Rear-to-front length of a connector: put a route's last point `plug_length` behind a socket so the plug lands in it. |
| `z`, `z_ranges` | Depth; `[[u0, u1, z], ...]` overrides it on parts of the route, so a cable weaves over and under other cables or nodes. |
| `shadow`, `shadow_offset`, `opacity`, `layer` | Drop shadow (alpha 0 = none), fade, free tag for filters. |
| `build(f)`, `curve()`, `length()`, `point_at(u)`, `tangent_at(u)`, `sub(a, b)`, `pieces()` | Build the curve for a frame (cached while nothing changes), then query it: pin labels or particles to a cable with `point_at`. |

### MotionCableSet (MotionCanvas)

| Member | Notes |
| --- | --- |
| `cables` | The cables to draw. Sets may share cables. |
| `z_min`, `z_max` | Draw only the parts of cables within this depth window. Put one set below a node and one above it, and give cables `z_ranges`, to wrap cables round a logo (front spans over it, back spans under it). |
| `shadows`, `filter` | Shadows on/off; `Callable(cable) -> bool`. |
| `static draw_plug(canvas, kind, pos, dir, width, housing, band, lit, light, op)` | A connector anywhere, rear at `pos`, pointing along `dir`. |
| `static draw_port(canvas, pos, dir, width, lit, led, op)` | A face-on panel socket with a chrome bezel and an LED ring. |

Each cable part draws: its shadow; a glow halo if powered; the tube (rim, body,
lit side and a specular line, offset towards the light); bands and stripes;
pulses; the glint; its connector. Parts sort by depth, then cable order.

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Cables | `MotionCable` routes drawn by a `MotionCableSet`: snake in with `reveal`, sag with `tension` and pull taut on a spring, `tugs` for twangs and whips, `pulses` for current, connectors that land in sockets (`plug_length`), and two sets with `z_ranges` to wrap cables round a node. | The FTF Cables take: three cables slam their connectors into a patch strip and power the Minimal Humans M layer by layer; six cables wrap the dead FTF plate in a lattice and are ripped off; eight cables harpoon into the plate's rim on the drop and hold it in tension, pulses landing on every beat, until the plugs are pulled and it falls. Also: a patch-bay menu, a power-up loading screen, cables trailing from a ship in a garage scene. |

## Frame purity

Nothing persists between frames: the piece sets every cable property from `f`;
tugs are closed-form damped sines of `f - at`; `build(f)` recomputes the curve
from the properties (it caches only while the key, which includes `f`, is
unchanged). Seeking, scrubbing and reverse are exact.

## Cost

A cable part is about 6–9 `draw_polyline` calls over its samples (18 per span by
default), plus one per band, stripe and pulse. The FTF take draws up to ~20
cables (6 hanging in the back, 6 wrapping with ~25 spans each, 8 suspension
lines) and renders at roughly the speed of the first FTF intro under software GL.
Wrapped cables with many short spans: lower `samples` (8 is plenty).

## Limits

- Depth ordering is per cable part, not per pixel: two parts at the same depth
  that cross draw in cable order.
- `z_ranges` are fractions of the built curve's length; the piece computes them
  from waypoint chord lengths, which is close enough when the switch happens at a
  bend (an edge the cable wraps round).
- A bend tighter than the tube's own radius overlaps itself and shows spikes
  (a real cable can't bend that tight either): give U-turns a radius of at least
  the cable width, as the wraps in the FTF take do (a 4-point arc, 2.8 × width).
- Shadows are drawn under each part, so a cable's shadow can fall on cables
  drawn before it but not on nodes outside its set.
