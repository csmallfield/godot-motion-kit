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
| `writing-mode: vertical-rl` | `MotionText.vertical = true`, `box_width` = the available height |
| `filter: invert(1)` | `MotionFX.invert = 1` |
| `strokeDasharray` + `strokeDashoffset` on a path | `MotionCanvas.dashed_polyline(..., offset)` |
| `opacity` | `modulate.a`; on a wrapper whose children overlap, a `CanvasGroup` (`self_modulate.a`) or `MotionFX` so it fades as one layer |
| `filter: brightness(k)` | `modulate = Color(k, k, k)` |
| `box-shadow: 0 0 30px c` | a `MotionShape` the element's size, `blur = 30` |
| `filter: blur(8px)` on a group | `MotionFX` with `blur = 8` |
| `text-shadow: 0 0 24px c` | the text inside a `MotionFX` with `shadow_color = c`, `shadow_blur = 24` |
| SVG `filter` with `feGaussianBlur` + `feMerge` (glow) | `MotionFX.glow` = the stdDeviation |
| `linear-gradient`, `radial-gradient`, `repeating-linear-gradient` | `MotionGradient` (`shift` for `background-position`) |
| `mix-blend-mode` | `MotionGradient.blend`; isolate the group in a `MotionFX` as the browser's stacking context does |
| `clip-path: inset(...)` | a `Control` with `clip_contents`, sized to the visible part |
| inline `<svg>` built in loops (`<line>`, `<polygon>`, `<circle>`) | `MotionCanvas` and its `draw_fn` |
| hand-rolled 3D (`rotX`, `rotY`, `proj`) | `MK.rot_x`, `MK.rot_y`, `MK.project` |
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
8. **Group opacity.** CSS `opacity` on a wrapper composites the wrapper as one layer, so
   a logo's face hides the shadow layers beneath it while it fades. `modulate.a` on a
   `MotionSvg` fades each part on its own, and the layers show through. Wrap it in a
   `CanvasGroup` and fade `self_modulate.a`, or put it in a `MotionFX`. SVG `<g opacity>`
   around overlapping shapes in a `MotionCanvas` is the same problem; where the overlap
   is a thin stroke over a fill, the C port pre-mixes the stroke colour instead.
9. **Three different blur numbers.** `filter: blur(x)` and `feGaussianBlur
   stdDeviation` are the standard deviation. `box-shadow` and `text-shadow` blur values
   are twice it. `MotionFX.blur` and `glow` take the former; `MotionShape.blur` and
   `MotionFX.shadow_blur` take the latter, so the CSS numbers copy across unchanged.
   A blur on a scaled element scales with it.
10. **Text sits where Chromium puts it** once the metrics match: a line box with
   `line-height: normal` is round(ascent) + round(descent) of the faces actually used.
   FreeType rounds both up, which put every baseline a pixel low until `MotionText`
   rounded them itself.
11. **Filter regions clip.** An SVG filter's default region is the element's bounding box
   plus 10% (or what the code sets, often -50%/200%). A glow on a nearly horizontal line
   can be clipped vertically in the browser. `MotionSvg`'s `blur_region` reproduces a
   region on parts; `MotionFX` clips only at its `size`, so give it room.
12. **Every box is border-box.** Remotion's own stylesheet sets `box-sizing: border-box` on
   every element, so a `width` or `height` includes padding and border. A 54 px band with
   3 px borders has 48 px of content. Getting this wrong cost A Pit Lane 0.04 of SSIM.
13. **An inline `<svg>` in a `<div>` makes the div 4 px taller.** The svg sits on the text
   baseline and the line keeps the default font's descent and half its line gap below it
   (Times New Roman, which is Liberation Serif on Linux, at 16 px). It matters whenever
   that div is centred, rotated about its centre, or stacked under something.
   `PrintKit.STRUT_GAP` holds the value; svgs that are flex items have no gap.
14. **Characters the web fonts lack come from system fonts.** Chromium falls back through
   fontconfig, and with synthetic bold when the weight is missing. Find the face with
   `fc-match 'monospace:charset=XXXX'`, subset just those glyphs, and add it to the Godot
   font's `fallbacks` (a `FontVariation` with `variation_embolden = 0.5` stands in for
   Chromium's fake bold).
15. **`white-space: nowrap` collapses spaces; `pre` keeps them.** Collapse runs of spaces
   yourself before handing text to `MotionText`.
16. **GDScript divides integers as integers.** `crop[2] / crop[3]` with whole numbers
   truncates (118 / 25 is 4). Convert to float first when porting arithmetic on arrays
   of numbers.
17. **Animate scale, not font size.** A CSS `fontSize` that changes every frame is cheap in
   the browser. In Godot every new size rasterizes a new set of glyphs, which cost B Print
   a 50 ms hitch per frame at 900 px. Keep `font_size` fixed and animate the node's `scale`.
