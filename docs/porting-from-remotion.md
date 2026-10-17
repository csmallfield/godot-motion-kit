# Porting a Remotion piece

The SCF intros were moved across line for line. The translation is mechanical once you
know the handful of places where the browser behaves in ways that aren't obvious.

## The mapping

| Remotion | Motion Kit |
| --- | --- |
| `useCurrentFrame()` | the `f` argument of `_frame(f)` |
| `spring({frame: f - at, fps, config})` | `MK.spring(f, at, damping, stiffness, mass, fps)` |
| `interpolate(f, in, out, {clamp, easing})` | `MK.interp(f, in, out, easing)` (or `MK.map`, eased by default) |
| `Easing.bezier(a, b, c, d)` | `MK.bezier(a, b, c, d)` |
| the SCF `ease` curve | `MK.ease_out` (renamed: `ease` would shadow Godot's built-in `ease()`) |
| `<div style={{position:"absolute", left, top}}>` | a `Node2D` at `(left, top)` |
| `right: r`, `bottom: b` | `left = 1920 - r - width`, `top = 1080 - b - height` |
| `transform: scale(s)` on a div (origin = centre) | `MotionShape` with its default centre anchor, `scale = s` |
| `transformOrigin: "0 0"` | a plain `Node2D` container scaled about its origin |
| `borderRadius: "50%"` disc | `MotionShape` CIRCLE |
| `<Logo part={(i) => ...}>` | `MotionSvg.apply(func(i): ...)`, with the same keys (`fillO` → `fill_o`, `drawWidth` → `draw_width`) |
| CSS text, `letterSpacing: "0.3em"` | `MotionText.tracking = 0.3` |
| `lineHeight: 0.9` | `MotionText.line_height = 0.9` |
| `opacity` | `modulate.a` |
| `filter: brightness(k)` | `modulate = Color(k, k, k)` |
| `box-shadow: 0 0 30px c` | a `MotionShape` the element's size, `blur = 30` |
| `{cond && <X/>}` | `x.visible = cond` (build nodes once in `_ready`, toggle per frame) |
| `<Sequence from={n} durationInFrames={d}>` | a nested `MotionComposition` with `start = n`, `duration = d` (hidden outside its range) |
| `<Audio src=...>` | `audio` on the composition |

## Things that bit, and what to do

1. **Chromium's self-drawing stroke is not what the code says.** `strokeDasharray =
   "d 2"` with `pathLength = 1` and `vector-effect: non-scaling-stroke` measures the dash
   and gap in screen pixels but the path in logo units. On a logo drawn at 3× its viewBox,
   `draw = 1` shows only a third of the outline, and the gap is short enough for the
   pattern to repeat. The pattern also restarts on every subpath. Set
   `MotionSvg.chromium_draw = true` to reproduce this exactly. New work should leave it
   off, so `draw` means the true fraction.
2. **Frame 0.** Movie Maker writes an image after the first process step. Compositions
   hold their first frame on `play()`, so image 0 is frame 0, as in Remotion.
3. **Float precision.** `Vector2` and `Transform2D` are 32-bit in standard Godot builds;
   the maths in `MK` returns 64-bit floats. Keep values as floats until they become positions.
4. **Godot's JSON reader rounds 17-digit decimals.** Fixtures use exactly representable seeds.
5. **Children of the scene.** If a composition builds its nodes in `_ready`, guard with a
   flag rather than `get_child_count() == 0`: the scene's own children (the sound player)
   count too.
6. **Typed GDScript and lambdas.** `Callable.call()` returns a Variant, so write
   `var s: float = fn.call(...)` rather than `:=`.
7. **Noise.** SVG `feTurbulence` can't be matched pixel for pixel. `MotionOverlay` STATIC is
   tuned to the same mean and spread, and comparisons should exclude those frames.
