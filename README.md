# Godot Motion Kit

Motion graphics for Godot (written for 4.5+, tested on 4.7.2): compositions that are a pure function of the frame,
Remotion-exact springs and easing, part-level SVG logo animation, kinetic type,
glitch and CRT effects, scene transitions, and spring feedback for UI; and beyond the
browser, slit-scan time effects, shader fields and pattern planes, print plates,
isometric extrusion, frame-driven 3D, transit maps, pipes and cables.
It is pure GDScript, with no GDExtension and no build step.

You make pieces directly in Godot: write a brief, turn it into a beat sheet in frames,
build it with the kit, render it and review the frames. The workflow is written up as an
agent skill in [skills/godot-motion-kit/SKILL.md](skills/godot-motion-kit/SKILL.md),
every technique has an example in [docs/techniques.md](docs/techniques.md), and
`demo/examples/race_ident.gd` is a piece made that way from scratch.

To prove the kit, eighteen of the SCF intros were ported from Remotion line for line and
their renders compared frame by frame (SSIM on luma at half size):

| Intro | Frames | Mean SSIM vs Remotion | Worst frame |
| --- | --- | --- | --- |
| E1 Supergraphic | 420 | 0.9994 | 0.9985 |
| D1 Signal, excluding the 48 frames of random TV static | 372 | 0.9875 | 0.934 |
| D1 Signal, all frames | 420 | 0.946 | 0.175 (TV static) |
| A Pit Lane | 300 | 0.9958 | 0.9862 |
| B Print | 300 | 0.9990 | 0.9954 |
| B1 Print | 410 | 0.9993 | 0.9956 |
| B2 Specimen | 420 | 0.9980 | 0.9970 |
| B3 Index | 420 | 0.9991 | 0.9984 |
| C Vector Track | 300 | 0.9967 | 0.9929 |
| F1 Strobe | 420 | 0.9993 | 0.9888 |
| F2 Moiré | 420 | 0.9987 | 0.9924 |
| F3 Goo | 420 | 0.9982 | 0.9898 |
| F4 Hyperspeed | 420 | 0.9978 | 0.9931 |
| F5 Automaton | 420 | 0.9996 | 0.9920 |
| G1 Lava | 420 | 0.9989 | 0.9915 |
| G2 Splash | 420 | 0.9993 | 0.9927 |
| G3 Cells | 420 | 0.9993 | 0.9910 |
| G4 Ferro | 420 | 0.9989 | 0.9818 |
| G5 Goo Pile | 420 | 0.9991 | 0.9916 |

Random static can't match pixel for pixel, so those frames are reported separately.
`tools/compare/compare.py` reproduces all of
these numbers.

## Install

Copy `addons/motion_kit` into your project and enable **Motion Kit** under
Project Settings → Plugins. Enabling it adds the `MotionTransition` autoload and the
**Motion SVG** importer.

## Ten-line example

```gdscript
extends MotionComposition   # fps 30, duration in frames, plays itself

@onready var logo: MotionSvg = $Logo     # data = an .svg imported as "Motion SVG"

func _frame(f: float) -> void:
	logo.apply(func(i: int):
		var at := 10.0 + i * 3.0
		if f < at: return {hide = true}
		return {s = MK.spring(f, at, 9, 160), draw = MK.map(f, [at, at + 20], [0, 1]), fill_o = MK.prog(f, at + 12, 10)})
```

Everything inside `_frame` reads only `f`, so the piece can be scrubbed in the editor
(Inspector → Preview Frame), played backwards as an outro, locked to its soundtrack,
and rendered offline frame-exactly with Movie Maker.

## What's in the kit

The kit is grouped into families; [docs/API.md](docs/API.md) uses the same grouping.

| Family | Classes | What it does |
| --- | --- | --- |
| Core | `MK`, `MotionComposition`, `MotionCue`, `MotionCuePlayer`, `MotionTravel`, `MotionPath`, `MotionPoly`, `MotionOffscreen` | Remotion-exact springs, easings and `interp`, seeded randomness, shakes, beat pulses; the root of a piece (fps, duration, markers, play / seek / reverse / segments, audio or manual clock, fit-to-viewport); cue sheets that fire as playback crosses them, on one global bus, exportable as JSON; distance-over-time tables; measured paths and polygon maths; offscreen viewport setup |
| SVG and text | `MotionSvg`, `MotionSvgData`, `MotionText`, `MotionFonts`, `MotionPill`, `MotionTextPath` | SVG kept as vector parts (per-part move, scale, rotate, recolour, fade, blur, self-drawing outline); glyph-by-glyph type with CSS tracking, line height, text stroke, browser-exact line boxes and vertical Japanese; font fallbacks and zoom-proof canvas text; tag pills; text along any path |
| Shapes and drawing | `MotionShape`, `MotionGradient`, `MotionCanvas`, `MotionCells`, `MotionMarks`, `MotionTape` | SDF shapes with exact Gaussian blur; CSS gradients, hazard stripes, moiré ring stacks and blend modes; immediate-mode drawing; palette byte grids; chevrons, hatching, barcodes, warning signs and ribbons for any CanvasItem; hazard tape along a path |
| Effects | `MotionFX`, `MotionOverlay`, `MotionPixelGrid`, `MotionBeacon` | Offscreen group: blur, glow, shadows, slice glitch with RGB split, pixelate, invert, SVG-exact goo; TV static and CRT; pixel builds from an SVG; rotating beacon lights |
| Time | `MotionTimeSlices`, `MotionTimeCache`, `MotionTimeSplit`, `MotionViewRect` | Time displacement, slit-scan, box tunnels and RGB time splits of any composition, with shared renders and per-band culling for heavy content |
| Fields and patterns | `MotionGlyphField`, `MotionWarpField`, `MotionTiling`, `MotionPatternPlane`, `MotionPlaneScan` | One-quad shader fields lit by any 2D mask: cycling glyphs, warped and kaleidoscoped colour fields, op-art tilings, ray-cast pattern planes with an OutRun sun, and their per-pixel slit-scan |
| Print | `MotionPlate`, `MotionPaper` | Overprinting ink plates with halftone, misregistration, press roller and ink texture on paper |
| 2.5D extrusion and cities | `MotionExtrude`, `MotionSolid`, `MotionExtrudeCamera`, `MotionCityPlan`, `MotionGreebler`, `MotionVoxelize`, `MotionBlockPlan`, `MotionFaceLights` | Vector-crisp isometric extrusion (iso to flat elevation), procedural machine cities, greebles with zoom level of detail, voxel logo assembly with lit windows |
| 3D | `MotionStage3D`, `MotionLens3D`, `MotionSvgMesh`, `MotionPanel3D`, `MotionCutoutRig`, `MotionCutout`, `MotionRibbon3D`, `MotionGrass3D`, `MotionWarmup`, `MotionFlat3D`, `MotionEdges3D`, `MotionDecalAtlas`, `MotionPattern3D`, `MotionSkyDome3D`, `MotionTrack3D` | Frame-driven 3D inside a composition or a game scene: perspective-to-isometric lens, extruded SVG logos, 2D panels, cutout characters from SVG (pivoted parts, two-bone IK, front / back / side views with a paper turn), outlined ribbons, grass that ripples, material warmup, poster shading with outlines, per-actor flashes and decals, patterned worlds, sky domes, banked tracks |
| Diagrams and flow | `MotionMetroMap`, `MotionFlow`, `MotionLiquidFill`, `MotionCable`, `MotionCableSet` | Octilinear transit maps, pipe networks with flowing fluid, logos filling with sloshing liquid, sagging shaded cables with plugs |
| Game layer | `MotionSpring` (+ `2D`, `3D`), `MotionAimSpring`, `MotionReactive`, `MotionTransition` (autoload), `MotionClock`, `MotionTrauma`, `MotionIK`, `MotionGait`, `MotionChain`, `MotionSquash`, `MotionPoseCurve`, `MotionRipples`, `MotionPerfProbe` | Springs for input; hover, focus and press feedback for any Control; `change_scene(path, style)` with circle, bars, clock, fade, glitch, crt. Live game systems: event clocks with per-entity hit-stop (so every `MK` curve runs on game events), trauma shake, two-bone IK, procedural gait with foot planting, verlet chains, squash and stretch, authored moves as data, event rings for shaders, per-system script timing |

See [docs/techniques.md](docs/techniques.md) for what to use when (with examples, best
practices and the three ways to do 3D), [docs/API.md](docs/API.md) for the reference, and
[docs/porting-from-remotion.md](docs/porting-from-remotion.md) only if you need to match
an existing browser animation exactly.

## Demo

Open the project and run it. The menu builds in, reacts to mouse, keyboard and gamepad,
and plays the eighteen remade intros through transitions. Its TRANSITIONS item cycles
through the six styles. The intros are in `demo/scf/`.

`demo/ftf/` holds the Full Throttle Flux boot intro and nineteen takes on it, each built
around a kit family (slit-scan, isometric cities, risograph plates, 3D gantries, glyph
fields, transit maps, cables, pattern planes and more) with its own baked soundtrack:
see [demo/ftf/README.md](demo/ftf/README.md) for the list with tempo, technique, render
cost and how to re-bake the sound.

`demo/live/live_example.tscn` shows the live game layer in one small scene: a cutout
walker with planted feet and a trailing scarf circles a post on rippling grass and bonks
it, with hit-stop, trauma shake and a wobble. [Cutout Isle](https://github.com/csmallfield/cutout-isle)
is a full 2.5D action slice built on it with the Godot Audio Kit.

## Tests and comparisons

```sh
godot --headless --import --path .
godot --headless --path . --script res://tests/run_tests.gd   # parity, SVG, springs
godot --path . res://tests/perf.tscn                          # CPU per frame
godot --path . res://tests/visual/render_check.tscn           # GPU: blur, shadow, group opacity, gradients
godot --path . res://tests/visual/render_check2.tscn          # GPU: cells, goo, rings, text stroke
godot --path . res://tests/visual/svg_cache_check.tscn        # GPU: SVG rasters outlive cache eviction

# Render any composition and review it as a contact sheet:
tools/render.sh res://demo/examples/race_ident.tscn out/race 180
python3 tools/sheet/sheet.py out/race out/race-sheet.png --every 15 --motion

# Porting only: render an intro with Movie Maker, then compare with a Remotion render of the original:
godot --path . --write-movie out/E1/f.png --fixed-fps 30 --quit-after 420 res://demo/scf/e1_supergraphic.tscn
python3 tools/compare/compare.py <remotion_frames_dir> out/E1 out/E1-compare --label E1

# Long renders can be split or resumed: frames 200-419 written as files 0-219
godot --path . --write-movie out/G1b/f.png --fixed-fps 30 --quit-after 220 res://demo/scf/g1_lava.tscn -- --mk-start=200
```

The parity fixture (`tests/fixtures/remotion_parity.json`) holds values computed by
Remotion itself. Springs match to within 7e-16 over 4,620 values, and easing and
interpolation to within 3e-14. Regenerate it with `tools/parity` (`npm install && npm run fixture`).

## Licence

Apache-2.0 for the code. The logos, soundtracks and fonts in `demo/assets/` have their
own terms; see [NOTICE](NOTICE).
