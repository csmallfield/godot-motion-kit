# Kit notes: MotionTiling (op-art tilings driven by fields)

New files: `addons/motion_kit/tiling/motion_tiling.gd` (`class_name MotionTiling`,
`@tool`, extends `Node2D`) and `motion_tiling.gdshader`. No existing kit file was changed.

## API (rows for docs/API.md)

### MotionTiling (Node2D)

A full-frame tiling drawn in one quad. Each cell holds one tile of a motif; every cell
can rotate, scale, invert, switch colourway, switch motif and open up, driven by four
fields. Anything added under `mask_content` is rendered offscreen and becomes the MASK.

| Member | Notes |
| --- | --- |
| `size`, `cell`, `origin`, `angle`, `scroll`, `seed` | Field size; tile period in px; rotation centre; global rotation (degrees); offset in the tiling's own frame; hash seed. |
| `motif`, `motif_b` | `Motif.HOUNDSTOOTH` (woven as real 2/2 twill: 4 dark / 4 light threads in warp and weft, warp on top on alternate diagonals), `CHECKER` (2 × 2 per tile), `PINWHEEL`, `DOTS`, `CHEVRON`, `STRIPES`. `motif_b` is what the motif channel switches a cell to. |
| `ink_a`, `ink_b`, `alt_a`, `alt_b`, `alt_hard` | Motif and ground colours, and a second colourway the alt channel switches to; `alt_hard` (default true) switches each cell at once (crisp fronts) instead of blending. |
| `gap_color` | What shows where a cell's tile is smaller than the cell (rotated or shrunk tiles). |
| `mask_color`, `mask_ground`, `mask_ground_shade` | Inside the mask, the motif takes the mask's own colour; the ground takes it times the shade. Light parts of a logo weave light, coloured parts as a deeper weave of themselves, so the logo reads in the cloth. |
| `bulge_c`, `bulge_r`, `bulge` | Vasarely sphere: above 0 magnifies, below 0 pinches (−0.95..0.95). |
| `ripple_c`, `ripple_r`, `ripple_w`, `ripple_amp` | A radial ripple through the fabric (`ripple_r` < 0 = off). |
| `mask_content`, `mask_pixel`, `mask_warp`, `mask_scale` | The mask subtree; per-pixel mask edge (crisp letters made of cells, two cell evaluations per pixel) or per cell (stepped); sample the mask in the warped fabric (the shape bends with the cloth); mask render scale. |
| `halo_r` | Reach of the HALO field: the band just outside the mask. |
| `ring_c`, `ring_r`, `ring_w`, `ring_mode` | The RING field: `BAND` (a pulse), `DISC` (1 inside), `OUTSIDE`. `ring_r` < 0 = off. |
| `sweep`, `sweep_angle`, `sweep_w` | The SWEEP field: a straight front `sweep` px from the field centre along the angle; cells it has passed are 1. |
| `jitter` | 0..1 per-cell stagger of the ring and sweep fronts (cells flip one by one). |
| channels `rot_*`, `scale_*`, `inv_*`, `alt_*`, `clear_*`, `motif_*` | Each is `*_base + *_by · (mask, halo, ring, sweep) + *_and · (ring×mask, sweep×mask, ring×halo, sweep×halo)`. rot in radians, scale multiplies the tile (≤ 0 hides it), inv swaps motif and ground, alt switches colourway, clear makes the gap transparent (what's under the tiling shows through), motif > 0.5 switches to `motif_b`. The `and` terms gate a front by the mask or halo: "cells inside the logo vanish as the ring passes". |
| `by(mask, halo, ring, sweep)`, `gated(ring_mask, sweep_mask, ring_halo, sweep_halo)` (static) | Build the Vector4 weights. |
| `reset_channels()` | Every channel back to neutral; call at the top of `_frame` and set only what this frame needs. |
| `level` | Overall opacity. |

## techniques.md rows

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Op-art tiling | `MotionTiling` with a `motif`; animate `cell`, `angle`, `scroll`, `bulge` and `ripple` for a living cloth. | The FTF Houndstooth take: a full-frame woven houndstooth that bulges like a Vasarely sphere, ripples out from the logo on the beat, and is sucked into a pinch before the drop. |
| A logo formed by the pattern | Put the logo under `mask_content`; inside it turn tiles 45° (`rot_by.x`), grow them to fill their cells (`scale_by.x`), and take the logo's colours (`mask_color`, `mask_ground`); shrink the halo (`scale_by.y`) for a black margin. | MINIMAL HUMANS and FULL THROTTLE FLUX reading as regions of the cloth before they exist as vectors. |
| Parting the cloth | Draw the vector logo under the tiling; `scale_and.x = -1` and `clear_and.x = 1` with a `DISC` ring growing from the logo centre: cells inside vanish one by one and the vector shows through. Shrink the ring to weave it back. | The drop: the cloth parts from the centre in six frames and the full-size logo is underneath. |
| Colourway and motif sweeps | `alt_by.w = 1` (and `motif_by.w = 1`) with a `sweep` front and `jitter`; after a sweep, make the new colourway the base and sweep to the next. | Black/cream to pink to lime checker and back, each on the beat, cell by cell. |
| Shrink-out | `ring_mode = OUTSIDE`, `scale_by.z = -1`, ring radius to 0 with `jitter`. | The outro: tiles shrink to nothing toward the centre. |

## Frame purity, cost, limits

- Frame-pure: the shader reads only uniforms; the piece resets the channels and sets
  everything from `f` each frame; per-cell randomness is a hash of the cell and `seed`.
  Seeking matches playback (checked on the take).
- Cost: one full-frame quad; per pixel one or two cell evaluations (two with
  `mask_pixel` and a mask) and nine mask taps; the mask viewport renders at
  `mask_scale` (0.5 default) and stops while the tiling is hidden or has no visible
  mask. The take renders at about 0.3–0.5 s a frame in software GL on shared cores.
- Limits: a tile is clipped to its cell (a tile scaled above about 1.41 or rotated
  shows its own clipped square); the drivers are sampled at each cell's centre in the
  warped fabric, so under a strong bulge the halo and cell-based mask drift from an
  unwarped vector drawn under the tiling (keep bulges away from a parted logo, or set
  `mask_warp` while the logo is cloth); `mask_pixel` blends two cell results by the
  mask's coverage, so a soft mask edge shows both for a pixel or two.
