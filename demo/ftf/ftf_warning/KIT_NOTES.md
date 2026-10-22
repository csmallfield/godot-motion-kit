# Kit notes: text on a path and rotating beacons (from the Warning take)

New files (no existing kit file was changed):

| File | Class |
| --- | --- |
| `addons/motion_kit/text/motion_text_path.gd` | `MotionTextPath` (Node2D): text set along any polyline, like SVG `<textPath>` |
| `addons/motion_kit/fx/motion_beacon.gd` | `MotionBeacon` (Node2D): a rotating beacon light (shader inside the script) |

The hazard tape itself (stripes in path space, torn ends, whip wave) is a take helper,
`demo/ftf/ftf_warning/warning_tape.gd`, built on `MotionTextPath`'s static path maths.

## API rows (for docs/API.md)

### MotionTextPath (Node2D)

Glyphs are shaped once with the font's fallbacks (as `MotionText` shapes them), then
each is placed at its own arc length on the path and turned to the path's direction.

| Member | Notes |
| --- | --- |
| `text`, `font`, `font_size`, `color`, `tracking` | As `MotionText` (tracking in em) |
| `points`, `closed` | The path in the node's space (sample curves finely); `closed` joins the ends and wraps arc lengths |
| `offset` | Where the text starts along the path, px. Animate it to scroll; any value works |
| `align` | `START`, `CENTER`, `END`: where a single copy sits relative to `offset` |
| `repeat`, `gap`, `fit_loop` | Tile the text along the whole path `gap` px apart; on a closed path `fit_loop` (default on) stretches the gap so whole copies fill the loop |
| `baseline`, `shift` | Baseline across the path in em (0.35 centres capitals on it; 0 sits the baseline on it); extra sideways shift in px (+ = right of travel) |
| `upright`, `flip` | Keep glyphs unrotated; turn them 180° |
| `show_from`, `show_to`, `edge_fade` | Only glyphs whose centre lies between these arc lengths are drawn (`show_to` < 0 = the end), fading over `edge_fade` px: text that appears with a tape being laid |
| `glyph_fn(i, s) -> Dictionary` | Per-glyph overrides `tx` (along), `ty` (across), `s`, `rot`, `o`, `color`, `hide`; `i` = character index, `s` = arc length |
| `get_text_width()`, `path_length()`, `point_at(s)`, `tangent_at(s)` | Measurements |
| static `path_lengths(pts, closed)`, `path_point(pts, lengths, closed, s)`, `path_tangent(pts, lengths, closed, s, window)` | The arc-length model, shared with anything else that follows the path (ribbons, tapes, markers). Open paths extend straight past their ends; tangents are chords over ±window so corners don't snap |

### MotionBeacon (Node2D)

One quad over `size`, drawn additively, so the beams light whatever is under them.

| Member | Notes |
| --- | --- |
| `size`, `centre` | Area the light can reach (origin top-left) and the lamp position |
| `angle`, static `spin(f, period, phase, direction)` | Direction of the first beam (radians); `spin` gives the angle for a lamp turning once every `period` frames |
| `beams`, `beam_width`, `softness`, `lens` | 1–4 evenly spaced beams; half-angle (degrees) and soft share; beam width at the lamp (beams don't start as a point) |
| `reach`, `falloff`, `color`, `intensity` | Distance fade (px, power), colour, beam brightness |
| `core`, `core_intensity` | Lens glow radius and brightness |
| `flare_dir`, `flare_power`, `streak`, `streak_intensity` | The lens flares (glow, halo and a horizontal streak) as a beam swings to `flare_dir` (the viewer) |
| `squash` | Vertical scale of the beam field (< 1: light thrown across a floor or wall) |
| `level`, `blend` | Overall level (0 = off, not drawn); `ADD` (default) or `MIX` |

## techniques.md rows

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Text on a path | `MotionTextPath` with `points` (and `closed`), `repeat` to tile, animate `offset` to scroll; `show_from`/`show_to` reveal it with whatever draws the path; `glyph_fn` for waves along the path | The Warning take: multilingual warnings (WARNING / ACHTUNG / 警告 / ВНИМАНИЕ) running along thrown hazard tape that whips as it lands; the logo's name crawling round a closed tape frame; ticker tapes along the top and bottom |
| Rotating beacons | `MotionBeacon` over the scene, `angle = MotionBeacon.spin(f, period)`; two lamps turning in opposite directions; speed them up for an escalation by continuing the angle from the switch frame | Two warning lamps sweeping amber and pink beams across the placard, the signs and the logo, the lens flaring each time a beam faces the viewer |
| Hazard tape (take helper) | `warning_tape.gd`: a ribbon along a path with stripes laid out in path space (they bend with it), square or torn ends, a decaying whip wave, and exits (follow, back, tear) | Tape thrown across on the beats, a wall of tape that tears open on the logo at the drop, nine tapes snapping closed over the screen and yanked away |

## Frame purity

Every property is set from `f`: tape poses are recomputed each frame from their spec
(`pose(spec, f)`), text offsets are `speed × f`, beacon angles are `spin(f, ...)`
(piecewise after the escalation, continuous at the switch). Nothing is accumulated.
Checked by rendering frames by seeking and comparing them with the full render.

## Cost

`MotionTextPath`: one TextServer glyph draw per visible glyph, two path look-ups per
glyph (binary search on the arc-length table). A 2000 px ticker at 30 px is ~150
glyphs. `MotionBeacon`: one full-frame quad with a 4-iteration loop per pixel.
The Warning take (up to ~20 tapes, 10 text paths, two beacons) renders in software GL
at well under 1 s a frame.

## Limits

- `MotionTextPath` places glyphs by their centre on the path; on tight curves wide
  glyphs overhang (sample the path finely, keep the radius above ~2 font sizes).
- Text runs in the path's direction: a path drawn right to left puts the text upside
  down (reverse the points, or accept it on loops, as on a badge).
- `MotionBeacon` is additive light, not occlusion: beams pass through everything.
