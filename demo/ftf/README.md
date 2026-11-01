# Full Throttle Flux intro

A 14 s boot intro for Full Throttle Flux: "Minimal Humans presents" glitching
into FTF's acid palette, a run of team liveries, then the FTF logo slamming in
on the drop with an acid HUD around it. Wipeout / Designers Republic /
neo-futurist. The brief and the frame-by-frame beat sheet are in the header of
`ftf_intro.gd`.

| File | What it is |
| --- | --- |
| `ftf_intro.gd` / `.tscn` | The composition (1920×1080, 30 fps, 420 frames) and its cue sheet |
| `ftf_kit.gd` | `FTFKit`: palette, fonts, the FTF logo's part map; its drawn marks (chevrons, checkers, hatching, X boxes, crosshairs, barcodes, rounded ribbons, stripe bundles) forward to the kit's `MotionMarks` and `MotionPath`. Shared by the intro and every take |
| `assets/ftf_logo.svg` | `FTF_logo_pink_v1.svg` from the FTF repo, imported as Motion SVG |
| `assets/noto-jp-ftf-900.woff2` | Noto Sans JP Black, subset to the piece's Japanese (OFL, see `demo/assets/fonts/OFL-noto-sans-cjk-jp.txt`) |
| `audio/make.py` | Writes every sound recipe, the cue map and the music (sound sheet in its docstring) |
| `audio/ftf_intro_track.res` | The baked soundtrack, so the piece plays its sound without the audio kit |

## Pieces

The intro plus nineteen takes on it, each built around a kit family; they are the kit's
best working examples. Every take lives in its own folder with `<folder>.gd` /
`<folder>.tscn`, a `KIT_NOTES.md` (cost, limits and frame-purity checks of the classes
it introduced) and its sound in `audio/` (`make.py`, the cue map, the song and the
committed baked track). The family links go to the API reference; the classes were
added in four rounds (intro, five intro takes, eight title takes, five mixtures of the
favourites), shown in the Round column.

| Piece | Folder | Round | Tempo | Family | Kit technique | Render cost (software GL) |
| --- | --- | --- | --- | --- | --- | --- |
| FTF intro | `ftf_intro.gd` | intro | 150 bpm (12 f/beat) | [Core](../../docs/API.md#core), [SVG and text](../../docs/API.md#svg-and-text), [Shapes](../../docs/API.md#shapes-and-drawing), [Effects](../../docs/API.md#effects) | `MotionSvg`, `MotionText`, `MotionMarks`, `MotionPath`, `MotionFX`: glitch, liveries, logo slam, HUD | n/a |
| Slit-Scan | `ftf_slitscan/` | intro take | 180 bpm (10 f/beat) | [Time](../../docs/API.md#time) | `MotionTimeSlices` (fx/): time displacement, slit-scan, box tunnel, RGB time split | ~0.4 s/frame |
| Megastructure | `ftf_megastructure/` | intro take | 120 bpm (15 f/beat) | [2.5D](../../docs/API.md#25d-extrusion-and-cities) | `MotionExtrude`, `MotionSolid`, `MotionExtrudeCamera` (extrude/), `MotionCityPlan` (city/): 2.5D iso extrusion, iso→flat camera | ~0.4 s/frame |
| Riso | `ftf_riso/` | intro take | 100 bpm (18 f/beat) | [Print](../../docs/API.md#print) | `MotionPlate`, `MotionPaper` (print/): overprinting colour plates, halftone, registration, ink texture, press roller | ~1 s/frame (up to 15 plates) |
| Gantry | `ftf_gantry/` | intro take | 150 bpm (12 f/beat) | [3D](../../docs/API.md#3d) | `MotionStage3D`, `MotionSvgMesh`, `MotionPanel3D`, `MotionTrack3D` (three/): frame-driven 3D in a composition, extruded SVG meshes, 2D on 3D panels | ~0.65 s/frame |
| Glyph Field | `ftf_glyphfield/` | intro take | 90 bpm (20 f/beat) | [Fields and patterns](../../docs/API.md#fields-and-patterns) | `MotionGlyphField` (glyph/): shader glyph grid lit by any mask, rain, fall, scan, solidify | ~0.4 s/frame |
| LSD Sunrise | `ftf_lsd/` | title take | 100 bpm (18 f/beat) | [Fields and patterns](../../docs/API.md#fields-and-patterns) | `MotionWarpField` (warp/): banded fields, domain warp, kaleidoscope, mirror water, melting content | ~0.45 s/frame |
| Insane Subway Map | `ftf_subway/` | title take | 150 bpm (12 f/beat) | [Diagrams and flow](../../docs/API.md#diagrams-and-flow) | `MotionMetroMap` (metro/): octilinear routing, bundled corridors, draw-on, chases, trains, stations | ~0.23 s/frame |
| Greebles | `ftf_greebles/` | title take | 75 bpm (24 f/beat) | [2.5D](../../docs/API.md#25d-extrusion-and-cities) | `MotionGreebler` (greeble/): recursive panels and greebles with level of detail by on-screen size | ~0.7 s/frame |
| Cables | `ftf_cables/` | title take | 90 bpm (20 f/beat) | [Diagrams and flow](../../docs/API.md#diagrams-and-flow) | `MotionCable`, `MotionCableSet` (cable/): sagging shaded cables, tugs, pulses, connectors, over/under weaving | ~0.4 s/frame |
| Fuel Lines | `ftf_fuel/` | title take | 180 bpm (10 f/beat) | [Diagrams and flow](../../docs/API.md#diagrams-and-flow) | `MotionFlow`, `MotionLiquidFill` (flow/): pipe networks with flow, liquid fill with analytic slosh | ~0.28 s/frame |
| Warning | `ftf_warning/` | title take | 200 bpm (9 f/beat) | [SVG and text](../../docs/API.md#svg-and-text), [Effects](../../docs/API.md#effects) | `MotionTextPath` (text/), `MotionBeacon` (fx/), `MotionTape` (shapes/): text along paths, rotating beacon lights, hazard tape | ~0.4 s/frame |
| Checkerboard City | `ftf_checkercity/` | title take | 112.5 bpm (16 f/beat) | [Fields and patterns](../../docs/API.md#fields-and-patterns) | `MotionPatternPlane` (plane/): ray-cast pattern plane with curve, tube, fold, motion blur | ~0.37 s/frame |
| Houndstooth | `ftf_houndstooth/` | title take | 120 bpm (15 f/beat) | [Fields and patterns](../../docs/API.md#fields-and-patterns) | `MotionTiling` (tiling/): woven houndstooth and other motifs, per-cell transforms driven by a logo mask | ~0.33 s/frame |
| Night Circuit (Gantry × Checkerboard City) | `ftf_nightcircuit/` | mixture | 150 bpm (12 f/beat) | [3D](../../docs/API.md#3d) | `MotionPattern3D`, `MotionSkyDome3D` (three/): filtered patterns on 3D surfaces, OutRun sky dome | ~0.8 s/frame |
| Time City (Megastructure × Slit-Scan) | `ftf_timecity/` | mixture | 120 bpm (15 f/beat) | [Time](../../docs/API.md#time) | `MotionViewRect`, `MotionTimeCache` (fx/): per-band culling, shared renders for equal delays | ~0.55 s/frame |
| Through the Megastructure (Megastructure × Gantry) | `ftf_canyon/` | mixture | 112.5 bpm (16 f/beat) | [3D](../../docs/API.md#3d) | `MotionLens3D`, `MotionFlat3D`, `MotionEdges3D`, `MotionDecalAtlas` (three/): perspective→isometric blend, poster shading, outlines, decals | ~0.5 s/frame |
| Stargate Board (Checkerboard City × Slit-Scan) | `ftf_stargate/` | mixture | 180 bpm (10 f/beat) | [Fields and patterns](../../docs/API.md#fields-and-patterns), [Time](../../docs/API.md#time) | `MotionPlaneScan` (plane/), `MotionTimeSplit` (fx/): per-pixel slit-scan of the pattern plane, RGB time split over any background | ~0.44 s/frame |
| Assembly (Megastructure, night) | `ftf_assembly/` | mixture | 100 bpm (18 f/beat) | [2.5D](../../docs/API.md#25d-extrusion-and-cities) | `MotionVoxelize`, `MotionBlockPlan`, `MotionFaceLights` (voxel/): mask → grid targets, block choreography, lit windows and edge lights | ~0.44 s/frame |

All are 1920×1080, 30 fps, 420 frames, first downbeat at frame 0, and end on
an empty frame (Megastructure on its cream ground, the rest on black). A beat is
`1800 / bpm` frames (most takes keep `BPM` and `BEAT` constants and set `bpm = BPM`), so
music at the same tempo with its first downbeat at 0.0 s can replace a piece's song. Render costs are Movie Maker
under Xvfb software GL on two shared cores.

## Timing (intro)

150 bpm, 4/4, first downbeat at frame 0: a beat is exactly 12 frames, a bar 48.
Every animation and cue starts from the constants at the top of the script, so
retiming a beat moves its sound too. To swap in a different music track, keep
150 bpm with its first downbeat at 0.0 s; the drop lands on bar 4 (frame 192,
6.4 s).

Markers: `in` 0, `logo` 192, `hold` 264, `out` 336. For the game's boot, play it
and `await finished`, or skip by seeking to the end; it ends on black so it can
cut straight to the menu.

## Sound

Link the audio kit (`tools/link_audio_kit.sh`, a git-ignored symlink to
`../godot-audio-kit`) and each piece scores itself through an `AKCueBridge`;
without it, it plays its committed bake. After changing recipes, the song or any
cue timing, regenerate and re-bake (the intro shown; for a take use its folder,
e.g. `demo/ftf/ftf_gantry/audio/make.py` and `--piece=res://demo/ftf/ftf_gantry`):

```sh
tools/link_audio_kit.sh
python3 demo/ftf/audio/make.py
godot --headless --path . -s res://tools/bake_audio.gd -- --piece=res://demo/ftf/ftf_intro.tscn
godot --headless --path . -s res://addons/audio_kit/tools/review.gd -- \
    --cues demo/ftf/audio/ftf_intro_cues.json --map res://demo/ftf/audio/ftf_map.tres \
    --song res://demo/ftf/audio/music/ftf_song.tres --out out/review/ftf
python3 ../godot-audio-kit/tools/analyze/analyze.py out/review/ftf
```

`tools/bake_audio.gd` bakes any piece: `--piece=` names its folder
(`res://demo/ftf/ftf_gantry`, scene `<folder>/<folder name>.tscn`) or its
`.tscn` (the intro). It finds the piece's sound in `<folder>/audio/` by
convention (the one `*_map.tres`, `music/*song.tres`, `*_track.res` and
`*_cues.json`), writes the track and the cue sheet there, and takes
`--scene= --map= --song= --track= --cues=` overrides (e.g. a scratch
`--track=/tmp/t.res` to compare a re-bake without touching the committed one).

## Render

```sh
tools/render.sh res://demo/ftf/ftf_intro.tscn out/ftf 420
tools/render.sh res://demo/ftf/ftf_gantry/ftf_gantry.tscn out/gantry 420
ffmpeg -framerate 30 -i out/ftf/f%08d.png -i out/ftf/f.wav -c:v libx264 -pix_fmt yuv420p -crf 18 -shortest ftf_intro.mp4
```

The 3D takes (Gantry, Night Circuit, Through the Megastructure) were made and rendered
with the Compatibility renderer; their fog, glow and MSAA look different under Forward+
(see [Three ways to do 3D](../../docs/techniques.md#three-ways-to-do-3d)).

The FTF and Minimal Humans logos are Minimal Humans trademarks and are not
covered by the repository's Apache-2.0 grant.
