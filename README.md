# Godot Motion Kit

Motion graphics for Godot (written for 4.5+, tested on 4.7.2): compositions that are a pure function of the frame,
Remotion-exact springs and easing, part-level SVG logo animation, kinetic type,
glitch and CRT effects, scene transitions, and spring feedback for UI.
It is pure GDScript, with no GDExtension and no build step.

It was built by porting two of the SCF intros from Remotion line for line and comparing
the renders frame by frame:

| Intro | Frames | Mean SSIM vs Remotion | Worst frame |
| --- | --- | --- | --- |
| E1 Supergraphic | 420 | 0.9987 | 0.9975 |
| D1 Signal, all frames | 420 | 0.945 | 0.175 (TV static) |
| D1 Signal, excluding the 48 frames of random TV static | 372 | 0.987 | 0.934 |

Random static can't match pixel for pixel, so those frames are reported separately.
`tools/compare/compare.py` reproduces all of these numbers.

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
| `MK` | `spring`, `bezier` and named easings, `map`/`interp`, `prog`, `win`, `rand`, `shake`, `typed`, `crt_off`, `timecode` |
| `MotionComposition` | Root of a piece: fps, duration, markers, play / seek / reverse / segments, process, audio or manual clock, fit-to-viewport |
| `MotionSvg` + `MotionSvgData` | SVG kept as vector parts; per-part move, scale, rotate, recolour, fade, self-drawing outline |
| `MotionText`, `MotionFonts`, `MotionPill` | Glyph-by-glyph type with CSS-style tracking and line height; tag pills |
| `MotionShape` | SDF circle, rect, pill, ring, arc, with dashes and exact Gaussian blur (box-shadow) |
| `MotionFX`, `MotionOverlay`, `MotionPixelGrid` | Slice glitch with RGB split, pixelate, brightness, goo; TV static, CRT; pixel builds from an SVG |
| `MotionSpring`, `MotionReactive` | Stateful springs for input; drop-in hover, focus and press feedback for any Control |
| `MotionTransition` (autoload) | `change_scene(path, style)` with circle, bars, clock, fade, glitch, crt |

See [docs/API.md](docs/API.md) for the reference and
[docs/porting-from-remotion.md](docs/porting-from-remotion.md) for moving a Remotion
piece across.

## Demo

Open the project and run it. The menu builds in, reacts to mouse, keyboard and gamepad,
and plays the two remade intros through transitions. Its TRANSITIONS item cycles
through the six styles. The intros are in `demo/scf/`.

## Tests and comparisons

```sh
godot --headless --import --path .
godot --headless --path . --script res://tests/run_tests.gd   # parity, SVG, springs
godot --path . res://tests/perf.tscn                          # CPU per frame

# Render an intro with Movie Maker, then compare with a Remotion render of the original:
godot --path . --write-movie out/E1/f.png --fixed-fps 30 --quit-after 420 res://demo/scf/e1_supergraphic.tscn
python3 tools/compare/compare.py <remotion_frames_dir> out/E1 out/E1-compare --label E1
```

The parity fixture (`tests/fixtures/remotion_parity.json`) holds values computed by
Remotion itself. Springs match to within 7e-16 over 4,620 values, and easing and
interpolation to within 3e-14. Regenerate it with `tools/parity` (`npm install && npm run fixture`).

## Licence

Apache-2.0 for the code. The logos, soundtracks and fonts in `demo/assets/` have their
own terms; see [NOTICE](NOTICE).
