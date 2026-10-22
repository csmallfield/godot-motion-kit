# Kit additions from FTF take 3 (RISO): print plates

New files, all under `addons/motion_kit/print/`:

| File | What |
| --- | --- |
| `motion_plate.gd` / `motion_plate.gdshader` | `MotionPlate`: one colour plate of a print, multiplied onto what's under it |
| `motion_paper.gd` / `motion_paper.gdshader` | `MotionPaper`: an uncoated sheet to print on |

No existing kit file was changed.

## API (for docs/API.md, new section "Print")

### MotionPlate (Node2D)

Put what the plate prints under `content`, drawn in **black on transparent**: black prints
solid ink, greys print a tint (`ink = alpha − luma` of the premultiplied render), and white
**knocks out** (a white shape over a black one leaves paper). The plate renders offscreen
and is drawn back with `blend_mul`, so plates **overprint** each other and the paper the way
transparent inks do. Draw plates over an opaque backdrop (a `MotionPaper`), not inside a
transparent `MotionFX`.

| Member | Notes |
| --- | --- |
| `size` | Plate (content) size in pixels, usually the frame. |
| `ink`, `density`, `tone_scale` | Ink colour; how much ink is laid (0..1, animate to fade a plate in); a multiplier on the content's ink amount (draw black, set 0.4 for a 40% tint). |
| `misregister`, `misrotate` | Registration error in pixels and degrees about the plate's centre. The halftone screen moves with the plate. |
| `cell`, `angle_deg`, `dot` | AM halftone: cell in pixels (0 = solid ink), screen angle, `Dot.ROUND / LINE / SQUARE / DIAMOND`. Dot size comes from the tone at each cell's centre; dots are clipped to the artwork's own edge, so solids keep crisp outlines. |
| `roughness`, `grain`, `mottle`, `seed` | Ragged edges (pixels), speckles where ink missed (0..1), uneven laydown (0..1), noise seed. All static. |
| `slur`, `slur_amount` | A doubled ghost image (press slur / second impression). |
| `roll`, `roll_dir`, `roll_soft`, `roll_shadow` | The press roller: ink only where it has passed (0..1 along `roll_dir`), with a ragged edge `roll_soft` px wide and a shadow band at the roller while it moves. |
| `content` | Where to add what the plate prints. |
| `static register(f, settle_at, error, snap=3) -> Vector2` | Holds `error` until `settle_at`, then snaps into register over `snap` frames with a small overshoot. Multiply a rotation by `register(f, at, Vector2(1, 0)).x`. |
| `static print_in(f, at, frames=10) -> float` | Roller progress for a plate printed at `at`. |
| `static thunk(f, ats, amp=4, dur=6) -> Vector2` | A press judder (alternating vertical offset) for a parent node. |

A hidden plate stops rendering its content (its SubViewport stops updating).

### MotionPaper (Node2D)

A `size` rectangle (origin top-left) of paper: seeded mottling, tooth (`grain`), `fibres`,
`edge_shade`, plus a blurred drop `shadow` under the sheet. Static; move the node to feed
sheets through a press.

## Techniques row (for docs/techniques.md, under Effects or a new "Print" table)

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Colour plates with overprint | A `MotionPaper`, then one `MotionPlate` per ink over it; draw each plate's artwork in black, knockouts in white. Plates multiply, so overlaps mix like real ink. | FTF Riso: the Minimal Humans M printed as red and amber plates knocked out by the cream front layer, inside a black panel with the M knocked out of it. |
| Halftone screens | `cell` (px), `angle_deg`, `dot`; draw greys or set `tone_scale` for the tint. Different angles per plate avoid moiré, or turn one slowly for a shimmer. | The huge halftone "01" and "9000"; a halftone drop shadow under the FTF logo whose screen turns slowly during the hold. |
| Printing in | Animate `roll` with `MotionPlate.print_in(f, at)` and give `roll_dir` per plate; `roll_shadow` adds the roller's shadow. | Every colour arriving on its own beat, rolled across the sheet from a different side. |
| Registration snap | `misregister` / `misrotate` from `MotionPlate.register(f, settle_at, error)`; add a seeded shiver on twos before it. | All plates locking into register on the downbeat, with a press judder from `MotionPlate.thunk`. |
| Ink texture | `roughness`, `grain`, `mottle`, `slur`. | A hand-pressed approval stamp (rough, speckled, red over pink); the lime plate's slurred second impression. |
| Flood | A plate with one solid rect over the whole sheet, rolled on. | The black flood that ends the FTF Riso intro on black. |

## Cost and purity

Each plate is one full-frame SubViewport plus one fragment shader pass (two texture
reads for halftone, a few value-noise lookups). Hidden plates cost nothing. The FTF Riso
piece has up to 15 plates on screen during the sheet change and renders under Xvfb
software GL at roughly real-time ÷ 6–8 on two shared cores. Everything is a function of the
plate's properties, which the piece sets from `f`; all noise is seeded and static, so
scrubbing, seeking and reverse are exact.
