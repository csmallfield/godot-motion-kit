# Kit notes: MotionTimeSlices (time displacement and slit-scan)

New file: `addons/motion_kit/fx/motion_time_slices.gd` (`class_name MotionTimeSlices`,
`@tool`, extends `Node2D`). No existing kit file was changed.

## API (rows for docs/API.md, under Effects)

`MotionTimeSlices`: the content (a `MotionComposition`, from `scene` or a `builder`
Callable) is instanced once per band, and each band shows it at `f - delay(band)`.

| Member | Notes |
| --- | --- |
| `scene: PackedScene`, `builder: Callable` | The content, instanced once per band (`builder.call()` must return a `MotionComposition`). It draws on the parent's timeline and must accept negative frames. |
| `size` | Area the bands cover, and the content's reference size (1920×1080). |
| `layout` | `ROWS`, `COLUMNS`, `BOXES` (nested boxes about the centre, drawn outside in: a square tunnel), `CHANNELS` (three full-frame copies tinted R, G, B and added: a time-split chromatic fringe). Changing it, `bands`, `size` or `scene` rebuilds the bands. |
| `bands` | Number of bands (CHANNELS is always 3). |
| `delay` | Frames the most delayed band lags. Animate it to 0 for a sharp picture. |
| `profile` | How the delay spreads across the bands: `LINEAR`, `REVERSE`, `CENTRE`, `EDGES`, `SINE` (`waves`, `phase`), `RANDOM` (`seed_value`), `CUSTOM` (`profile_fn(u) -> 0..1`, u = 0..1 across the bands). |
| `step` | Quantise each band's delay to steps of this many frames (stutter). |
| `slit` | 0 = each band shows its own place (time displacement); 1 = every band shows the slit (slit-scan: streaks). In between the bands unfold from the slit. |
| `slit_pos`, `slit_width` | Where the slit is across the bands (0..1: COLUMNS x, ROWS y) and how much of the content each band shows at `slit = 1` (pixels; for BOXES the width of the centre box). Narrower than the band, it is stretched: streaks. |
| `box_power` | BOXES spacing: box k is scaled `(1 - k / bands) ^ box_power`. |
| `reveal`, `reveal_from` | Show only the bands within `reveal` (0..1 of the bands) of `reveal_from`; hidden bands cost nothing. Opens a streak field out of the slit. |
| `band_rects()`, `source_rect(k)`, `profile_at(u, k)`, `rebuild()` | Helpers. |

How it stays frame-pure: each band's instance is a nested composition whose `start` is
set to the band's delay in `_frame(f)`, just before the parent's frame walk reaches it,
so the walk renders it at `f - delay`. Nothing is kept between frames: seeking renders
pixel-identical frames to playback (checked on the FTF take), reverse and scrubbing work.

Cost: every band renders into its own SubViewport the size of the band, with the
content shifted to the band's source rectangle, and a `Sprite2D` draws the band with a
region (stretched when the slit is narrower than the band). Rows or columns cost one
frame of fill in total plus the content's script cost once per band; BOXES costs the
sum of the box areas (about `bands / (2 p + 1)` frames for `box_power` p); CHANNELS
three frames. Hidden bands and hidden nodes stop rendering, and their instances return
at once from the frame walk. In the FTF take (160 + 160 columns, 14 boxes, 3 channels
built; 160 live at a time) a full Movie Maker render runs at about 0.38 s a frame
under Xvfb software GL on 2 cores.

Limits: the content is instanced per band, so keep it light (one logo, a few canvases);
`source_rect` is clamped to the band size (a slit wider than its band is not
compressed); BOXES needs opaque content (inner boxes cover outer ones); CHANNELS needs
content on an opaque dark background (it adds).

## techniques.md row (Effects)

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Time displacement and slit-scan | `MotionTimeSlices` with a content composition: `layout` COLUMNS / ROWS / BOXES / CHANNELS, `delay` and `profile` set each band's lag; `slit` 0→1 turns it into a slit-scan photograph. Animate `delay` and `slit` to 0 to snap sharp on a beat. | The FTF Slit-Scan take: the MH lockup and the FTF logo pour out of a cyan slit as stargate streaks and unfold sharp on the bar; a BOXES tunnel where each beat's pattern is born in the centre and rushes outward; a CHANNELS time split that fringes the logo cyan and magenta on accents; a scanner bump (CUSTOM profile) rippling across the held logo; the logo stretched into a streak as it leaves. |
