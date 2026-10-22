# Kit notes: MotionGlyphField

New in `addons/motion_kit/glyph/`: `motion_glyph_field.gd` (class `MotionGlyphField`)
and `motion_glyph_field.gdshader`. No existing kit file was edited.

## API.md rows

### MotionGlyphField (Node2D)

A grid of cycling glyphs drawn in one quad. Each cell picks its glyph from a hash of
(cell, time step) at its own seeded rate; its brightness and colour come from a
**mask**: anything added under `mask_content` is rendered offscreen and read back per
cell (five taps for coverage, the centre tap for colour), so logos and type appear as
dense, bright glyphs. A glyph atlas is drawn once from `font` and `charset` at the cell
size, so glyphs stay crisp; it stops updating after a few frames.

| Member | Notes |
| --- | --- |
| `size`, `cell`, `font`, `charset`, `glyph_scale`, `font_scale`, `seed` | Field size, cell size (px), glyph source, glyph size in its cell, atlas font size as a share of the cell, hash seed. |
| `dim_range`, `lit_range` | `Vector2i(start, count)` into `charset` for the dim field and for lit cells (count 0 = all). Put thin glyphs in one, dense glyphs and blocks in the other. `glyph_index(ch)` finds a character. |
| `cycle_min`, `cycle_max`, `lit_cycle` | Glyph changes per frame, per cell, between min and max; lit cells multiply by `lit_cycle`. |
| `mask_content` | Node2D inside the mask viewport: add logos, text, shapes, a `MotionCanvas`. Its colours become the lit glyphs' colours. `mask_scale` renders it smaller for speed. |
| `threshold`, `softness` | Cell coverage (0..1) at which a cell lights. Draw a part of the mask at low opacity to keep it out of the glyphs (and still in `solidify`). |
| `reveal`, `reveal_sweep`, `reveal_angle` | Share of lit cells shown: a seeded dissolve (`reveal_sweep = 0`) or a straight sweep along the angle (1). |
| `lit_color`, `tint`, `lit_level` | Override the mask colour (`tint` 1) and dim the lit layer. |
| `lit_fill`, `lit_invert`, `ink_color` | Lit cells get a filled block in their colour; `lit_invert` stencils the glyph out of it in `ink_color` (terminal-highlight look, much more legible). |
| `base_color`, `base_density`, `base_level`, `base_flicker` | The dim field: colour, share of cells showing a glyph, brightness, seeded blinking. |
| `base_color_b`, `base_front`, `base_front_jitter` | Cells left of `base_front` (px) take `base_color_b`: a moving colour front. |
| `scroll`, `rain`, `rain_var` | Grid offset; rain moves columns down at their own speeds while the mask stays put (glyphs pass through the logo). |
| `fall_t`, `fall_g`, `fall_spread` | Gravity: frames since the fall began (< 0 off), px/frame², per-column delay. Falling cells carry their mask brightness, so a lit logo falls apart column by column. |
| `hot_color`, `scan_y`, `scan_w`, `scan_gain` | A horizontal band that lights and whitens the glyphs it passes. |
| `ring_c`, `ring_r`, `ring_w`, `ring_gain` | A ring (radius < 0 = off): a shockwave through the field. |
| `solidify`, `solidify_noise`, `solidify_sweep` | Cells switch from glyphs to the solid mask (randomly, or outwards from `ring_c`); at 1 the mask is shown whole, so a logo condenses into its real vector form. |
| `level` | Overall opacity. |
| `frame` | Set by `_frame(f)`; drives cycling, rain and blinking. |

Frame-pure: every animated value is a uniform written in `_frame(f)`; glyph steps are
`floor(f * rate + phase)` and every random choice is a hash of the cell index, so
scrubbing, seeking and reverse are exact. Cost: one quad with ~6 texture taps per pixel,
one field-sized mask viewport (skipped while the field is hidden), and the atlas drawn
for its first few frames. Under software GL a 1920×1080 field with an 18 px cell plus a
second 54 px field renders the FTF take at roughly the same speed as the first intro.

## techniques.md row (Effects, or a new "Generative fields" section)

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Glyph field | `MotionGlyphField` with a `charset`; add a logo or text under `mask_content` so it lights the glyphs; animate `reveal` (dissolve or sweep), `scan_y`, `ring_r`, `rain`, `fall_t` and `solidify`. | The FTF Glyph Field take: MINIMAL HUMANS resolves behind a scan band, condenses into the solid lockup on a shockwave, decays in a data storm (a `MotionCanvas` of random blocks in the mask), the FTF logo zooms out of giant glyph letters and condenses on the drop, then falls away column by column. Also: a loading screen whose title is built from cycling characters, a "hacked" HUD panel, a matrix-rain menu background that spells the selected item. |

Traps: a mask part that should only appear when solidified (the FTF logo's white plate)
should sit below `threshold` (opacity ~0.2) while the logo is glyphs, or it lights as
much as the letters and the logo stops reading. Cells are 18 px: keep mask type at
~90 px or more if it should be readable as glyphs.
