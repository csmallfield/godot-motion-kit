# Kit notes: MotionWarpField (liquid colour fields and warped content)

New files: `addons/motion_kit/warp/motion_warp_field.gd` (`class_name MotionWarpField`,
`@tool`, extends `Node2D`) and `motion_warp_field.gdshader`. No existing kit file was
changed.

## API (rows for docs/API.md)

`MotionWarpField`: a procedural colour field and/or an offscreen content layer, drawn in
one quad, both pushed through a seeded analytic domain warp, palette-cycled,
kaleidoscoped and mirrored in a rippling horizon.

| Member | Notes |
| --- | --- |
| `size`, `seed`, `render_scale`, `level` | Quad size (origin top-left), noise seed, content viewport density, overall opacity (premultiplied; `modulate` also applies). |
| `draw_field` | Draw the procedural field (off for a content-only layer). |
| `centre` | Centre of rings, rays, the sun, the iris, the shockwave ring and the kaleidoscope. |
| `rings`, `rays`, `stripes` | Weights of concentric rings, radial rays and horizontal stripes; mix them (rings + rays = spirals; rays under a kaleidoscope = petals). |
| `freq`, `phase`, `twist`, `steps` | Bands per 1000 px (rays: per turn); scroll in bands (animate for flowing bands, kick it on beats); ray twist with radius; posterize into hard anti-aliased bands (1 = one colour per band). |
| `field_level`, `iris`, `iris_soft` | Field brightness; show it only within `iris` px of `centre` (a bloom from the sun, or a closing iris). |
| `ring_r`, `ring_w`, `ring_gain`, `ring_color` | A bright ring about `centre` (radius < 0 = off): shockwaves. |
| `sun_r`, `sun_color`, `sun_color_b`, `sun_slits`, `sun_slit_scroll`, `sun_glow` | A disc at `centre` with a top-to-bottom gradient and 70s cut lines across its lower half; it warps with the field. |
| `pal_a`, `pal_b`, `pal_c`, `pal_d`, `set_palette()` | Cosine palette a + b cos(2π(c t + d)). |
| `pal_shift`, `pal_spread` | Cycle the palette (animate it); palette cycles per band. |
| `gradient`, `lut_mix`, static `bands_gradient(colors, hard)` | A Gradient LUT (repeats) blended in over the cosine palette; `bands_gradient` builds hard-step gradients from colour lists. |
| `content` | Node2D rendered offscreen (full `size`): add a MotionSvg, MotionText, shapes. Hidden or empty content costs nothing. |
| `content_warp`, `content_melt`, `content_chroma`, `content_level` | px of liquid displacement, px of downward drip (columns of varying length), px of RGB split, opacity of the content. Animate them to 0 to set a logo solid. |
| `warp`, `warp_scale`, `warp_speed` | px of two-level domain warp on the field, px per noise cell, noise drift per frame. |
| `kaleido`, `segments`, `kaleido_spin` | Blend (0..1) into a kaleidoscope about `centre`; the fold happens before the warp, so the liquid structure itself becomes the mandala. |
| `horizon`, `ripple`, `reflect_dim`, `horizon_glow`, `horizon_color` | Below `horizon` (px) the scene mirrors as rippling water, darker with depth; a glowing horizon line. Content above the horizon is reflected too; content below it is never drawn directly, so a logo moved up through the horizon surfaces out of the water. |

Frame purity: everything is a uniform; `_frame(f)` sets `time`, which drives the noise
drift and the water ripples. The noise is seeded value noise, the warp analytic (no
feedback buffer), so seeking, scrubbing and reverse are exact.

Cost: one full-quad fragment pass. The field costs about 18 value-noise lookups a
pixel with the warp on (two fbm levels, three octaves); the content layer is one
SubViewport the size of the quad (skipped while hidden or empty) and one to three
texture reads. The FTF LSD Sunrise take (one field + two content layers, 1920×1080)
renders at about 0.45 s a frame under Xvfb software GL on 2 shared cores.

Limits: one kaleidoscope centre and one horizon per node; `steps` bands alias a little
where the warp folds bands very tightly; content outside the quad is clipped before
the warp pulls it in, so keep warped content inside `size`.

## techniques.md row

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Liquid colour fields and melting logos | `MotionWarpField`: mix `rings` / `rays` / `stripes`, posterize with `steps`, colour with a cosine palette or `gradient`, cycle `pal_shift`, kick `phase` on beats, add `warp`; set `kaleido` for a mandala, `horizon` for a mirror sea. Put a logo under `content` and animate `content_warp` / `content_melt` / `content_chroma` to 0 to set it solid. | The FTF LSD Sunrise take: a striped 70s sun rising through acid rings over a mirror sea, the Minimal Humans lockup surfacing out of the water as liquid and setting solid on the bar, a kaleidoscope mandala, the FTF logo poured in liquid and set on the drop, then melting back into the sea. |
