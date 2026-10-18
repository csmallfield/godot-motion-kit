# Godot Motion Kit

Motion graphics for Godot (written for 4.5+, tested on 4.7.2): compositions that are a pure function of the frame,
Remotion-exact springs and easing, part-level SVG logo animation, kinetic type,
glitch and CRT effects, scene transitions, and spring feedback for UI.
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

| Piece | What it does |
| --- | --- |
| `MK` | `spring`, `bezier` and named easings, `map`/`interp`, `prog`, `win`, `rand`, `shake`, `typed`, `crt_off`, `timecode`; `rot_x`, `rot_y`, `project` for hand-rolled 3D |
| `MotionComposition` | Root of a piece: fps, duration, markers, play / seek / reverse / segments, process, audio or manual clock, fit-to-viewport |
| `MotionCue`, `MotionCuePlayer` | Cue sheets: declared moments (name, intensity, data) that fire as playback crosses them, relayed on one global bus, exportable as JSON; a stand-in player that maps cues to WAVs |
| `MotionSvg` + `MotionSvgData` | SVG kept as vector parts; per-part move, scale, rotate, recolour, fade, blur, self-drawing outline |
| `MotionText`, `MotionFonts`, `MotionPill` | Glyph-by-glyph type with CSS-style tracking, line height, text stroke and browser-exact line boxes; vertical Japanese; tag pills |
| `MotionShape` | SDF circle, rect, pill, ring, arc, with dashes, borders and exact Gaussian blur (box-shadow) |
| `MotionGradient` | CSS linear, radial, conic and repeating gradients (hazard stripes), concentric ring stacks (moiré), scrollable, with add / multiply / screen / overlay blending |
| `MotionCanvas` | Immediate-mode lines, dashes, polygons, circles, ellipses for loop-built SVG (wireframes, track floors, particle dust) |
| `MotionCells` | Palette-indexed byte grid in one quad with exact sub-pixel coverage: cellular automata, LED boards, pixel mosaics, minimaps |
| `MotionFX`, `MotionOverlay`, `MotionPixelGrid` | Offscreen group: Gaussian blur, glow, drop/text shadow, slice glitch with RGB split, pixelate, brightness, invert, SVG-exact goo (metaballs, flood fill, colour-keeping atop); TV static, CRT; pixel builds from an SVG |
| `MotionSpring`, `MotionReactive` | Stateful springs for input; drop-in hover, focus and press feedback for any Control |
| `MotionTransition` (autoload) | `change_scene(path, style)` with circle, bars, clock, fade, glitch, crt |

See [docs/techniques.md](docs/techniques.md) for what to use when (with examples and
best practices), [docs/API.md](docs/API.md) for the reference, and
[docs/porting-from-remotion.md](docs/porting-from-remotion.md) only if you need to match
an existing browser animation exactly.

## Demo

Open the project and run it. The menu builds in, reacts to mouse, keyboard and gamepad,
and plays the eighteen remade intros through transitions. Its TRANSITIONS item cycles
through the six styles. The intros are in `demo/scf/`.

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
