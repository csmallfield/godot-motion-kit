# Techniques and best practices

The kit is for making motion graphics directly in Godot: intros, idents, title cards,
HUD and menu animation, transitions. The eighteen SCF intros in `demo/scf/` were the
test bed (each was checked frame by frame against a browser render), so every technique
below has a working example you can open. `demo/examples/race_ident.gd` shows a piece
made from a written brief with no original to copy.

For a new piece, start from the workflow in
[`skills/godot-motion-kit/SKILL.md`](../skills/godot-motion-kit/SKILL.md), use this page
to pick techniques, and [API.md](API.md) for the details.

## Time and composition

Everything starts from one rule: a piece is a pure function of the frame number `f`.
That rule buys scrubbing, reversing, audio lock and exact offline renders for free.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Frame-pure `_frame(f)` | Extend `MotionComposition` and compute every property from `f` alone; never accumulate state across frames. | A results screen you can scrub in the editor (Inspector → Preview Frame) and render with Movie Maker, identical every time. |
| Springs | `MK.spring(f, at, damping, stiffness)` returns 0→1 starting at frame `at`; multiply sizes, offsets or scales by it. | Discs and tags that overshoot and settle as they land (every intro's pop-ins). |
| Staggered starts | Offset `at` per item: `at = 40 + i * 2`. | Menu rows that cascade in (the demo menu), letters dropping one after another (F3). |
| Easing and keyframes | `MK.interp(f, [a, b, c], [v0, v1, v2], easing)` for multi-key moves; `MK.map` for a clamped, eased 0→1. | A camera dolly that eases in, holds, then whips out (F4's dive). |
| Windows and fades | `MK.prog(f, start, dur)`, `MK.win(f, a, b)`, `MK.rise(f, start)`. | A caption that fades and rises in at frame 34 and out before the outro. |
| Deterministic randomness | `MK.rand(seed)` instead of `randf()`; seed with index and frame (`rand(i * 3.3 + seed)`). | Block-dissolve order, glitch bands and a Game of Life soup that are the same on every playback (F5). |
| Stepped motion | `MK.step(f, 2)` quantises time to twos. | F1 Strobe's rows and ticker scroll on twos; A Pit Lane's speed readout jitters every third frame. |
| Impact shake | `MK.shake(f, at)` / `MK.shakes(f, [hits])` returns a decaying offset for a parent node. | A screen kick on each countdown number (race ident) or checkpoint (F4). |
| Markers and segments | `markers = {"in": 0, "hold": 110}`, then `play_segment("in", "hold")`. | A pause menu that builds in, then waits on its hold frame for input. |
| Reverse as outro | `play_backwards(0)` replays the build-in mirrored. | The demo menu leaves by running its entrance backwards. |
| Nested compositions | A composition inside another sees `f - start` and hides outside its own duration, like a Remotion `<Sequence>`. | A reusable lower third dropped into several pieces at different times. |
| Audio-locked clock | `clock = AUDIO` with `audio` set: the frame follows the stream's playback position. | A title card that stays on the beat even when the game hitches. |
| Time-scale immunity | `ignore_time_scale` (default on) keeps the piece at full speed. | Hit-stop or slow motion in gameplay while the HUD keeps animating. |
| Hand-rolled 3D | `MK.rot_x`, `MK.rot_y`, `MK.project` project points; draw them with `MotionCanvas`. | C Vector Track's wireframe track and the rotating wireframe mark above it. |

## Sound and cues

Sound follows the picture through a cue sheet: declared moments that fire as playback
crosses them. Picture and sound come from one set of numbers, so retiming a beat
retimes its sound.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Declare a cue | `cue(at, name, intensity, data)` in `_init`; it returns `at`, so `MK.spring(f, cue(66, &"go"), ...)` keeps one number. | The race ident's whooshes, count blips, GO hit, tick and pop. |
| Beat grid | `beats(bpm, from, to)` puts a cue on every beat with accents. | Cuts and pops on a 120 bpm grid; a pulse that a music system can lock to. |
| Play WAVs on cues | A `MotionCuePlayer` maps names (or `prefix*`) to streams; intensity sets volume, `data.pitch` the pitch. | The race ident's sound effects, with no audio code in the piece. |
| Listen to everything | Connect to `MotionCue.bus.fired` once, instead of to each composition. | A game-wide audio manager hearing every intro, transition and HUD piece. |
| Schedule ahead | `cues_between(f, f + lookahead)` for sounds that must start exactly on a frame. | An audio kit queueing hits a few frames early to beat output latency. |
| Hand off to sound design | `export_cue_sheet(path)` writes JSON with frames, times, names, intensities and data. | Feeding a synthesis script or a DAW session, instead of copying frame numbers by hand. |
| Offline renders with sound | Movie Maker records cue-driven sound into `f.wav` (measured 1–10 ms from the frame). | Review videos that carry their effects with them. |

## SVG and logos

Import an `.svg` as **Motion SVG** and each shape stays a separate part you can move,
recolour and draw on, rasterized at the size it appears on screen.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Per-part transforms | `svg.apply(func(i): return {tx, ty, s, sx, sy, rot, pivot, o})` once per frame. | The S, C and F discs springing out one by one (E1). |
| Selecting parts | `only` for a subset; `MotionSvgData.find(name)` by id, class or group; `sorted_by_x()` for reading order. | Animate a wordmark letter by letter while the monogram holds still. |
| Recolour for free | Single-colour parts are white rasters tinted at draw time: set `fill` per part. | A team-colour logo in a race intro; a logo flashing white on a hit. |
| Self-drawing outline | `draw` 0→1 strokes each contour from its start; `fill_o` fades the fill in after it. | The wordmark tracing itself in amber before its fill fades up (MH lockup in E1). |
| Per-part blur | `blur` (Vector2, logo units) is a Gaussian on one part; `blur_region` limits it. | A logo part smeared sideways as it whips out of frame (A Pit Lane). |
| Crop and stretch | `crop` maps a logo region to `width`, like a viewBox; `stretch_h` makes a stretched strip. | Just the wordmark of a lockup (F2, F5); a barcode stretched to 720 px tall (D1). |
| Jelly drop | Per-part `ty` falls with gravity, then `sx`/`sy` squash about the part's bottom (`GooKit.jelly`). | Letters that fall in and wobble on landing (F3 and the G wordmarks). |
| Rise from the baseline | Animate `sy` from 0 with an overshooting curve, pivot at the bottom edge. | Ferrofluid letters pulled up out of the floor (G4). |
| Parts as a pile | Give every part a `tx`/`ty`/`rot` toward a heap, then spring it home. | Every logo piece dropped into one sticky mass that pulls apart into the lockup (G5). |
| Pixel builds | `MotionPixelGrid.cells_from_svg(data, cols, palette)` turns a logo into cells. | A logo assembling pixel by pixel on a retro loading screen. |
| Group opacity | Put the `MotionSvg` in a `CanvasGroup` and fade the group's `self_modulate.a`. | Fading a whole lockup without its overlapping parts showing through each other. |
| Prewarm | `prewarm()` rasterizes ahead of time. | Rasterize during a loading screen so the first frame of a big zoom doesn't hitch. |

## Type

`MotionText` lays out glyphs the way a browser does (same line boxes, tracking and
baselines), then lets every glyph move on its own.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Tracking | `tracking` in em, like CSS `letter-spacing`; animate it for a settle. | PRESENTS tightening into place (MH lockup); GRID READY in the race ident. |
| Per-glyph animation | `glyph_fn = func(i, f)` returns `{tx, ty, s, sx, sy, rot, o, color, hide}` per character. | MOTION KIT letters springing up one at a time in the demo menu; coloured bullets in F1's ticker. |
| Typewriter | `MK.typed(text, f, start, cps)`, or `visible_chars` to keep the line's layout fixed while it types. | D1's terminal lines; F5's console and blinking block cursor. |
| Line boxes and baselines | Leave `line_height` at 0 for the font's own, or set a multiple; `get_baseline()` aligns mixed sizes. | Big numerals and small units on one baseline in a lap-time readout. |
| Font fallbacks | Add subset fonts to a font's `fallbacks` for glyphs the main face lacks. | ■ ▲ ✓ █ and kanji in a Latin mono font (B Print, F4's stamps, F5's cursor). |
| Vertical Japanese | `vertical = true` with `box_width` as the column height: columns run right to left with kinsoku line breaking. | The 物語文脈構造 side column in B Print. |
| Text stroke | `stroke_width` and `stroke_color`; a transparent `color` gives outline-only type. | F1 Strobe's huge outlined words racing past. |
| Pills and tags | `MotionPill`: text on a rounded background with padding; its origin is its centre, so scaling pops it in place. | OPEN FORMAT / 1.0 tags under every SCF lockup; LAP 1/3 in the race ident. |
| Scale, not size | Keep `font_size` fixed and animate `scale`. | B Print's 900 px letters: animating the size cost a 50 ms re-raster every frame. |

## Shapes, gradients and loop-built graphics

Vector primitives are drawn analytically, so they stay crisp at any scale and cost one
quad each.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| SDF shapes | `MotionShape` circle, rect (or pill), ring or arc, with dashes, borders and a box-shadow `blur`. | The supergraphic discs in E1 and the demo menu; a soft-shadowed HUD panel. |
| Gradients | `MotionGradient.linear(size, angle, colours, stops)`, `radial(...)`, conic; angles are CSS degrees. | C Vector Track's radial glow behind the track; a sky ramp behind a title. |
| Scrolling hazard stripes | `MotionGradient.stripes(size, -45, [AMBER, AMBER, BLACK, BLACK], [0, 34, 34, 68])`, then animate `shift`. | A Pit Lane's pit-wall stripes; the race ident's crawling bands. |
| Blend modes | `blend` = MULTIPLY, SCREEN, OVERLAY or ADD reads what is drawn behind it. | A multiply tint over a photo; screen-blended light streaks. |
| Ring stacks and moiré | `MotionGradient.rings(size, centre, colour, width, gap, count)`: 90 concentric strokes in one quad. | Two ring fields sliding into F2's moiré; a sonar ping on a radar HUD. |
| Immediate-mode drawing | `MotionCanvas.draw_fn = func(c, f)` with `line`, `polyline`, `polygon`, `circle`, `ring`, `ellipse`, `rect`. | C's track floor, A's speed lines, the race ident's radiating streaks. |
| Dash patterns | `dashed_polyline(points, colour, width, dash, gap, offset)`; animating `offset` marches the ants. | B3's leader lines; a route preview crawling along a track map. |
| Thin lines | Lines under 1 px draw at 1 px with their width as alpha. | Hairline grids and reticles that don't flicker as they move. |
| Cell grids | `MotionCells` draws a palette-indexed byte per cell in one quad; set `cells` each frame or `set_cell()`. | F5's Game of Life; an LED scoreboard, minimap or pixel reveal. |
| Graphic marks | `MotionMarks` statics draw into any CanvasItem with an `opacity`: `chevrons` (march them with `phase`), `chevron_row`/`chevron_up`/`chevron_strip`/`arrow` for decals, `checker`, `hatch` (clipped to any polygon), `barcode`, `xbox`, `crosshair`, `plus`, `warning_triangle`, `hazard_clamp`, `barrier`. | The FTF intro's HUD furniture; signage decals on the megastructure and greebles; the Warning take's clamps and gates. |
| Paths by arc length | `MotionPath.new(points)` measures a polyline: `point_at(s)`, `tangent_at(s, window)`, `sub(a, b)` in px or `sub_fraction(a, b)`, `nearest(p)`; build paths with `rounded`, `arc_corners`, `rounded_rect` and `offset`. `MotionMarks.ribbon` / `stripe_bundle` draw thick bands along them. | Livery stripes drawing on along a rounded route (FTF intro), a marker riding a pipe, a train on a metro line. |
| Hazard tape | `MotionTape.pose(spec, f)` then `MotionTape.draw(c, spec, pose, f)`: stripes in path space, torn ends, a whip wave, exits (follow, back, tear). | The Warning take's thrown tapes, the tape wall that tears open on the drop, the tape frame round the logo. |

## Effects

`MotionFX` renders its `content` offscreen and draws it back through an effect stack;
`MotionOverlay` adds full-screen film effects. One `MotionFX` shares a single blur
pass, so nest two when you need two blurs.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Gaussian blur | `blur` is sigma, like CSS `filter: blur()`; animate it for focus pulls. | A Pit Lane's logo blurring as it exits; G3's microscope refocusing as the slide changes. |
| Glow | `glow` (sigma) and `glow_strength` add a blurred copy in the content's own colours underneath. | C Vector Track's neon lines; the race ident's GO. |
| Drop and text shadow | `shadow_color`, `shadow_blur` (a CSS radius, sigma × 2) and `shadow_offset`. | F1's shadowed type; readable captions over busy gameplay. |
| Glitch slices with RGB split | `set_slices(amount, split, count, seed)` shifts horizontal bands and splits channels. | D1's broken-transmission bursts; a damaged HUD flickering when the ship is hit. |
| Invert | `invert` 0→1 on the whole group. | B Print flipping ink and paper in one frame. |
| Pixelate and brightness | `pixel_size` and `brightness`. | A pixelated transition into a retro mini-game; a white flash on impact. |
| Metaball goo | `blur`, then `alpha_matrix = Vector2(26, -11)` and a `flood_color`: circles merge into liquid. `GooKit.goo()` wraps it. | F3 and G1–G4: lava-lamp wax, poured paint, dividing cells, ferrofluid spikes. |
| Colour-keeping goo | The same with `source_atop = true`: crisp shapes melt together at the seams, each keeping its colour. | G5's sticky heap of logo parts; a melting title card. |
| Isolated blending | A `MotionFX` gives its content its own backdrop. | F2's ring rush blending only within its own group. |
| TV static | `MotionOverlay` STATIC reseeds every frame; set `opacity`. | D1's channel-change static; a lost-signal camera feed. |
| CRT | `MotionOverlay` CRT (scanlines, rolling band, vignette) and `MK.crt_off(f, at)` for the tube switching off. | D1's power-off collapse to a dot; a retro attract screen. |
| Supersampling | `render_scale` above 1 renders the group larger. | A crisp 4K trailer render of the same scene. |

## Reveals, masks and transitions

Most reveals are a mask drawn by a parent: set `clip_children` on a `MotionCanvas` (or a
`ColorRect`), draw the mask shapes, and the children show only inside them.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Clipped rows | A `ColorRect` with `clip_children`, as `overflow: hidden`; the mask follows rotation and scale. | F1's bands of giant words sliding inside skewed strips. |
| Comb reveal | Horizontal teeth that grow with `t`; children appear through them. | F2's wordmarks combing in line by line. |
| Block dissolve | Squares drawn where `MK.rand(i * 3.3 + seed) < t`. | F5's wordmarks resolving out of blocks; a level card dissolving in. |
| Liquid flood | A polygon whose top edge is a sine wave rising over time. | F3's cream flooding up to take the frame. |
| Goo swallow and drips | A huge goo blob rising from below, or columns of blobs running down. | G1's dark wax swallowing the lamp; G2's ink dripping over everything. |
| Iris | A radial ramp from transparent to black at radius r, plus a ring and ticks. | G3's microscope iris; a scope or binocular view. |
| Jelly slump | Translate, scale and skew a layer about its top edge and round its bottom corners. | G5's blue frame slumping off the screen. |
| Dive through a mark | Scale a group about a point (13–70×) so the viewer flies through a part. | F4 diving through the C disc into the next beat. |
| Scene transitions | `await MotionTransition.change_scene(path, style)` with circle, bars, clock, fade, glitch or crt; `cover()` and `uncover()` around your own loading. | The demo menu into each intro; race end into results while the next track loads. |

## Game layer

Authored motion runs from the frame; reactive motion runs from input. Both use the same
spring maths, so a hover feels like the intros.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Reactive controls | Add a `MotionReactive` under any `Control`: hover, focus and press scale, offset and tint, on springs. Works inside Containers. | The demo menu's buttons under mouse, keyboard or gamepad focus. |
| Springs for input | `MotionSpring.new(initial, damping, stiffness)`, set `target`, call `step(delta)`. | A speedometer needle or boost gauge that chases the real value with overshoot. |
| Build-in, hold, outro | Markers `in` and `hold`, `play_segment("in", "hold")`, then `play_backwards()` on choice. | A pause or results screen that waits on its hold frame, then reverses out. |
| Fit to any window | `fit_to_viewport` letterboxes the 1920×1080 reference into the window. | Pieces that look right at 1366×768 and ultrawide alike. |
| Pause-safe UI | A root composition runs while the tree is paused, unless you set its process mode. | The pause menu animates while the race is frozen behind it. |

## Time displacement, print, extrusion, 3D and glyph fields

Added with the five FTF intro takes in `demo/ftf/` (Slit-Scan, Megastructure, Riso, Gantry, Glyph Field); API in [API.md](API.md#added-with-the-ftf-intro-takes), cost and limits in each take's `KIT_NOTES.md`.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Time displacement and slit-scan | `MotionTimeSlices` with a content composition: `layout` COLUMNS / ROWS / BOXES / CHANNELS, `delay` and `profile` set each band's lag; `slit` 0→1 turns it into a slit-scan photograph. Animate `delay` and `slit` to 0 to snap sharp on a beat. | The FTF Slit-Scan take: the MH lockup and the FTF logo pour out of a cyan slit as stargate streaks and unfold sharp on the bar; a BOXES tunnel where each beat's pattern is born in the centre and rushes outward; a CHANNELS time split that fringes the logo cyan and magenta on accents; a scanner bump (CUSTOM profile) rippling across the held logo; the logo stretched into a streak as it leaves. |
| 2.5D extrusion | `MotionExtrude` + `MotionSolid` + `MotionExtrudeCamera`: build boxes, cylinders, pipes, wedges or SVG slabs, set them from `f`, `prepare()`, then `draw(canvas, filter)`. Animate the camera's yaw and pitch from isometric to 0/0 for a flat front view; move `origin.z` with `clip_z = 0` to raise solids out of the ground; put logos on caps with `cap_transform` and a `cap_polygon` mask; label faces with decals and `draw_text`. | Take 2 Megastructure: an isometric machine city rising in rings, the Minimal Humans monument unfolding its M layers in depth, the FTF logo rising out of the floor as one slab, read in a flat front elevation. |
| Colour plates with overprint | A `MotionPaper`, then one `MotionPlate` per ink over it; draw each plate's artwork in black, knockouts in white. Plates multiply, so overlaps mix like real ink. | FTF Riso: the Minimal Humans M printed as red and amber plates knocked out by the cream front layer, inside a black panel with the M knocked out of it. |
| Halftone screens | `cell` (px), `angle_deg`, `dot`; draw greys or set `tone_scale` for the tint. Different angles per plate avoid moiré, or turn one slowly for a shimmer. | The huge halftone "01" and "9000"; a halftone drop shadow under the FTF logo whose screen turns slowly during the hold. |
| Printing in | Animate `roll` with `MotionPlate.print_in(f, at)` and give `roll_dir` per plate; `roll_shadow` adds the roller's shadow. | Every colour arriving on its own beat, rolled across the sheet from a different side. |
| Registration snap | `misregister` / `misrotate` from `MotionPlate.register(f, settle_at, error)`; add a seeded shiver on twos before it. | All plates locking into register on the downbeat, with a press judder from `MotionPlate.thunk`. |
| Ink texture | `roughness`, `grain`, `mottle`, `slur`. | A hand-pressed approval stamp (rough, speckled, red over pink); the lime plate's slurred second impression. |
| Flood | A plate with one solid rect over the whole sheet, rolled on. | The black flood that ends the FTF Riso intro on black. |
| 3D stage in a composition | `MotionStage3D` hosts a World3D; set the camera from `f` in `_frame` (`ride()` along a Curve3D, `blend()` to a hero pose); 2D type and HUD sit over it; `to_screen()` pins callouts to 3D points | The FTF Gantry take: a camera riding a banked neon circuit, then craning to face the logo sign, with callouts pinned to its corners |
| Extruded logos | `MotionSvgMesh.build(svg, width, {depth, part_fn})`, one MeshInstance3D with `MotionStage3D.unlit()`; raise letters with `part_fn` depth/z | The Minimal Humans lockup and the FTF logo as solid signs on gantries; the camera, not the letters, does the animating |
| Light chases and trails | Write a distance into UV2.x (track distance, logo x); animate `lit_to` for a chase, `lit_from`/`lit_to` together for a moving window | The circuit powering up beat by beat and cutting far-to-near in the outro; ships as light trails on a ribbon along the track |
| 2D on 3D surfaces | `MotionPanel3D` with kit text and marks under `canvas` | PRESENTS typing across a gantry beam; sponsor boards and DR billboards with katakana and chevrons |
| Glyph field | `MotionGlyphField` with a `charset`; add a logo or text under `mask_content` so it lights the glyphs; animate `reveal` (dissolve or sweep), `scan_y`, `ring_r`, `rain`, `fall_t` and `solidify`. | The FTF Glyph Field take: MINIMAL HUMANS resolves behind a scan band, condenses into the solid lockup on a shockwave, decays in a data storm (a `MotionCanvas` of random blocks in the mask), the FTF logo zooms out of giant glyph letters and condenses on the drop, then falls away column by column. Also: a loading screen whose title is built from cycling characters, a "hacked" HUD panel, a matrix-rain menu background that spells the selected item. |

## Warp fields, transit maps, greebles, cables, flow, paths, planes and tilings

Added with the eight titled FTF intro takes in `demo/ftf/` (LSD Sunrise, Insane Subway Map, Greebles, Cables, Fuel Lines, Warning, Checkerboard City, Houndstooth); API in [API.md](API.md#added-with-the-ftf-title-takes), cost and limits in each take's `KIT_NOTES.md`.

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Liquid colour fields and melting logos | `MotionWarpField`: mix `rings` / `rays` / `stripes`, posterize with `steps`, colour with a cosine palette or `gradient`, cycle `pal_shift`, kick `phase` on beats, add `warp`; set `kaleido` for a mandala, `horizon` for a mirror sea. Put a logo under `content` and animate `content_warp` / `content_melt` / `content_chroma` to 0 to set it solid. | The FTF LSD Sunrise take: a striped 70s sun rising through acid rings over a mirror sea, the Minimal Humans lockup surfacing out of the water as liquid and setting solid on the bar, a kaleidoscope mandala, the FTF logo poured in liquid and set on the drop, then melting back into the sea. |
| Transit maps | `MotionMetroMap`: `add_line` with grid waypoints (or `add_path` with any contour), `build()`, then in a `MotionCanvas` draw each line with `draw_line(c, i, a, b)` for draw-on and retract, `draw_train` by arc length, `draw_interchange` at hubs and `MotionMetroMap.label` for zoom-proof station names. Lines that share corridors bundle and bend concentrically. | The FTF Insane Subway Map take: MINIMAL HUMANS written as triple routes (stacked red, amber and cream like the M monogram), a 140-line network exploding on eighths while the camera rides the pink line's head, and the FTF logo built from concentric contour lines (`Geometry2D.offset_polygon` rings added with `add_path`) with trains circling the letters and a light chasing round every contour on each beat. Also: a route preview in a menu, a progress map between levels, a tube-style track select. |
| Greebles with a zoom LOD | `MotionGreebler`: `add_block` / `add_rect` for bold extruded shapes, `add_sides` + `add_detail` (with `avoid` = the letters) for a logo drawn by `MotionSvg`; draw from a `MotionCanvas` with the camera's scale and origin. Push the camera in and detail resolves by on-screen size; `lod` per structure keeps logo faces clean wide; `rest_chance` leaves plain plates so the bold shapes read; `reveal_front` cascades detail outward on a beat; `set_offset` moves doors and clamps. | The FTF Greebles take: opening pressed against the Minimal Humans monogram's machinery and pulling back until the lockup is a clean monument; a dive into a plinth hatch through cascading detail into blast doors; the FTF hull plate set in a greebled sky-city superstructure whose panels cascade out from it; parallax layers at three depths with haze, then a pull-out to a city of floating structures. |
| Cables | `MotionCable` routes drawn by a `MotionCableSet`: snake in with `reveal`, sag with `tension` and pull taut on a spring, `tugs` for twangs and whips, `pulses` for current, connectors that land in sockets (`plug_length`), and two sets with `z_ranges` to wrap cables round a node. | The FTF Cables take: three cables slam their connectors into a patch strip and power the Minimal Humans M layer by layer; six cables wrap the dead FTF plate in a lattice and are ripped off; eight cables harpoon into the plate's rim on the drop and hold it in tension, pulses landing on every beat, until the plugs are pulled and it falls. Also: a patch-bay menu, a power-up loading screen, cables trailing from a ship in a garage scene. |
| Flow along paths | `MotionFlow.add_pipe(points, {width, fluid})`, then each frame `apply(func(i): return {draw, fill, drain, flow, pulse_gain})`: `draw` traces the pipe, `fill` sends fluid down it, `drain` empties it, `flow` moves pulses and bubbles; a stepped beat count in `flow` makes it pump. | FTF Fuel Lines: a fuel schematic whose lines trace themselves, flood on valve beats, lurch on every beat in the hold and drain one by one in the outro; pulses chasing round the logo's rim as a pressure ring. Also: a data bus in a HUD, a loading bar that is a pipe, a route preview. |
| Liquid fill | `MotionLiquidFill` with the logo under `fill` (and a lighter copy under `surface`); animate `level`, give `kicks` for pours and slams. | The Minimal Humans lockup filling with fuel in its own colours and draining away; the FTF logo racing to brim-full on the drop and slapping in its top band on every beat; sight glasses using `MotionLiquidFill.slosh()`. |
| Text on a path | `MotionTextPath` with `points` (and `closed`), `repeat` to tile, animate `offset` to scroll; `show_from`/`show_to` reveal it with whatever draws the path; `glyph_fn` for waves along the path | The Warning take: multilingual warnings (WARNING / ACHTUNG / 警告 / ВНИМАНИЕ) running along thrown hazard tape that whips as it lands; the logo's name crawling round a closed tape frame; ticker tapes along the top and bottom |
| Rotating beacons | `MotionBeacon` over the scene, `angle = MotionBeacon.spin(f, period)`; two lamps turning in opposite directions; speed them up for an escalation by continuing the angle from the switch frame | Two warning lamps sweeping amber and pink beams across the placard, the signs and the logo, the lens flaring each time a beam faces the viewer |
| Hazard tape | `MotionTape` (promoted from the take's `warning_tape.gd`): a ribbon along a path with stripes laid out in path space (they bend with it), square or torn ends, a decaying whip wave, and exits (follow, back, tear) | Tape thrown across on the beats, a wall of tape that tears open on the logo at the drop, nine tapes snapping closed over the screen and yanked away |
| Pattern planes | `MotionPatternPlane`: set `ground_offset.y` from a travel table, `pitch`/`yaw`/`roll`/`height` for the camera, `curve`/`channel`/`hill`/`wave` to bend it, `cell` to pulse it, `motion_blur_for()` against strobing; sandwich a sign between a back and a `clip`ped front layer so it rises out of the floor; place canvas geometry with `project()` / `ground_point()` / `draw_checker_quad()`. | The FTF Checkerboard City take: a dive onto the board, a checker city sprouting, the Minimal Humans monument rising over the horizon at sunrise, a barrel roll through the board curled into a tube, the FTF logo rising out of the floor on the drop with a shockwave through the checks, and the ground folding up into a wall. Also: an OutRun road, a Tron grid menu floor, an op-art loading screen. |
| Op-art tiling | `MotionTiling` with a `motif`; animate `cell`, `angle`, `scroll`, `bulge` and `ripple` for a living cloth. | The FTF Houndstooth take: a full-frame woven houndstooth that bulges like a Vasarely sphere, ripples out from the logo on the beat, and is sucked into a pinch before the drop. |
| A logo formed by the pattern | Put the logo under `mask_content`; inside it turn tiles 45° (`rot_by.x`), grow them to fill their cells (`scale_by.x`), and take the logo's colours (`mask_color`, `mask_ground`); shrink the halo (`scale_by.y`) for a black margin. | MINIMAL HUMANS and FULL THROTTLE FLUX reading as regions of the cloth before they exist as vectors. |
| Parting the cloth | Draw the vector logo under the tiling; `scale_and.x = -1` and `clear_and.x = 1` with a `DISC` ring growing from the logo centre: cells inside vanish one by one and the vector shows through. Shrink the ring to weave it back. | The drop: the cloth parts from the centre in six frames and the full-size logo is underneath. |
| Colourway and motif sweeps | `alt_by.w = 1` (and `motif_by.w = 1`) with a `sweep` front and `jitter`; after a sweep, make the new colourway the base and sweep to the next. | Black/cream to pink to lime checker and back, each on the beat, cell by cell. |
| Shrink-out | `ring_mode = OUTSIDE`, `scale_by.z = -1`, ring radius to 0 with `jitter`. | The outro: tiles shrink to nothing toward the centre. |

## 3D patterns, graphic 3D, time caches, slit-scan planes and voxels

Added with the five FTF mixture takes; API in [API.md](API.md#added-with-the-ftf-mixture-takes).

| Technique | How to use it | Practical example |
| --- | --- | --- |
| Patterned 3D worlds | `MotionPattern3D.material()` on a `ground()` plane (world XZ, `motion_for()` against strobing, `sheen` toward the sun, `ring()` shockwaves) and on `box()`-built towers / gantries (UV space, vertex colours, `grow()` to sprout them as the camera nears); `MotionSkyDome3D` for the banded sun; a logo plate with checks via `uv_scale` | The FTF Night Circuit take: a neon skyway over an endless checkerboard at dusk, checker towers sprouting and streaming past, checkered gantries, the FTF sign on checkered pillars rising out of the board with a shockwave, the OutRun sun framed under it and sinking at the end |
| Heavy content through time slices | Content calls `MotionViewRect.of(self)` in `_frame` and culls to it (MotionExtrude: `cull_rect` + per-cell `MotionViewRect.box`); keep geometry in one shared static world and pose it per instance at draw time. Rows/columns then cost about one picture plus a per-band overhead. | Time City: the 600-solid machine city through 32 columns and 24 rows. |
| Slit-scan / channel split cache | `MotionTimeCache` (COLUMNS / ROWS / CHANNELS) with `step` quantised delays: each distinct delay rendered once into a slit-sized slot and shared. | Time City outro: 96 slit-scan columns from ~19 renders of a 3-pixel line; red/cyan time splits on the hold accents from two renders. |
| Perspective → orthographic blend | `MotionLens3D.look(...)` for the flying camera, `MotionLens3D.extrude(45, 35.264, scale, target)` for the iso view, `fly.mix(iso, t_pose, t_lens).apply(stage.camera)`; `flat.fog_for(lens, ...)` and fade fog with t_lens | Canyon: the camera lifts out of a street and its view flattens into the Megastructure take's exact isometric view while the FTF slab rises out of the plaza |
| Flat graphic 3D | `MotionFlat3D` materials per palette colour (top/lit/dark), merged builders, `MotionEdges3D` outlines, `MotionDecalAtlas` markings | The MC-202 city as real 3D: the whole city in about ten draw calls, readable both in a low perspective canyon flight and in iso |
| City motion in the shader | Put each object's ground anchor in UV2; `flat.pulse(origin, f - beat)` and `flat.sink(origin, f - start)` every frame; `flat.offset(key)` for CPU nodes | The city bobbing in rings on every beat of the hold and sinking into the ground in rings at the end |
| Shader-side slit-scan for planes | `MotionPlaneScan` (a MotionPatternPlane): give it `history_fn` (the board's travel, cell, blur, colours, sun and level at any frame) and call `capture(f)`; `scan` 0→1 unrolls the board into the slit, `walls` 0→1 bends flat streaks into perspective walls (`axis` VERTICAL / HORIZONTAL / TUNNEL about `slit_at`), `delay`/`delay_curve`/`delay_step`/`ripple` shape the time profile, `split` fringes it red/green/blue. Unfold to `scan = 0, delay = 0` to snap sharp. | The FTF Stargate Board take: the board's columns lag into chevrons as Minimal Humans pours out of the slit; row ripples on the kicks; the board unrolls into 2001 walls, then a floor-and-ceiling corridor, then a four-wall tunnel whose delay profile sweeps through every beat and snaps on the next; it unfolds sharp on the drop and drains to black as flat streaks. |
| RGB time split over any background | `MotionTimeSplit` with a content composition and a `region`; animate `delay` up on accents and back to 0. | The FTF logo fringing on the accents over the racing board in the Stargate Board take. |
| Voxel logo assembly | `MotionVoxelize.from_svg(data, cols, rows)` → `targets(height_fn)`; `MotionBlockPlan.assign_nearest(block_cells, target_cells)`; one `MotionBlockPlan` per transition with `set_move(i, from, to, key)`; per frame `pose(i, f)` sets each `MotionSolid` box's origin and depth. Light the faces with `MotionFaceLights` in decals; colour blocks by `progress()` so they light up as they land. | Round 4 Assembly: a night city's blocks re-stack into the Minimal Humans lockup (three height tiers in cream, amber, red) and then into the FTF logo, in waves on the beat; the vector logo slab slams onto the voxel sculpture on the drop. |

## Best practices: building motion that holds up

- **Build once, set every frame.** Create nodes in `_ready` behind a `_built` guard;
  `_frame(f)` only sets properties. Creating nodes per frame hitches and breaks scrubbing.
- **Derive everything from `f`.** If something must evolve step by step (F5's Game of
  Life), cache each step by frame and replay from the cache, so seeking back still works.
- **Seed, never roll.** `MK.rand(i * k + seed)` everywhere; `randf()` makes renders
  unrepeatable.
- **Stagger by index.** Start times like `at + i * 1.2` give cascades for free, and one
  constant retimes the whole group.
- **Animate transforms, not layout.** Move, scale and rotate nodes; don't animate
  `font_size`, widths or anything that re-rasterizes or re-lays out.
- **Pivot nodes for scaling.** Put a node at the point something should scale or rotate
  about and parent the element to it, offset by half its size (`_centred()` in the race
  ident); then `scale` pops it in place.
- **Fade groups as one layer.** Wrap overlapping parts in a `CanvasGroup` or `MotionFX`
  before fading, or the overlaps show through.
- **Hide what can't be seen.** `visible = false` on finished beats; a hidden `MotionFX`
  also stops rendering offscreen.
- **Give blurs room.** Size a `MotionFX` past the frame by three sigma; content outside
  it is clipped before the blur.
- **One canvas beats many nodes.** Loop-built graphics belong in one `MotionCanvas` or
  `MotionCells`, not hundreds of nodes.
- **Share per family.** Pieces in a series share helpers (`PrintKit`, `GooKit`); a fix
  there fixes every piece that uses it.
- **Leave clean edges.** End on an empty frame (black, cream, the game's background) so
  the piece can cut straight into the next shot, and say which in the brief.
- **Review the render, not the code.** Render with `tools/render.sh`, look at a contact
  sheet from `tools/sheet/sheet.py` at the beat frames, fix, re-render. The race ident's
  first sheet caught a pill sitting on a stripe band and a glow that blurred the text.
- **Check by scrubbing and reversing.** A piece that only looks right when played forward
  from frame 0 has hidden state.

## Best practices: Godot traps, performance and offline rendering

| Trap | Symptom | Fix |
| --- | --- | --- |
| `clip_children` takes its mask only from `draw_*` calls | A shader-drawn mask clips nothing | Draw mask shapes with a `MotionCanvas` |
| Clipping inside a transparent `SubViewport` | Clipped content loses its alpha inside a `MotionFX` | Clip outside the `MotionFX` |
| An empty clip mask clips nothing | Everything flashes on when a reveal is at 1% | Hide the node while the mask would draw nothing |
| `CanvasGroup` sizes its buffer from child bounds | A huge polygon (a tunnel ring near the camera) breaks it | Use a frame-sized `MotionFX` instead |
| Viewports render in the order they became active | A blur pass shows the previous frame | Handled: `MotionFX` restarts its blur pass after its content |
| `BackBufferCopy` RECT mode under nested transforms | Blended gradients read an empty backdrop | Handled: blends copy the whole viewport |
| The canvas keeps only texture RIDs | A cache evicting a texture mid-frame blacks out the screen | Handled: `MotionSvg` holds its last draw's textures |
| Transparent texels are black in rasterized SVGs | Dark fringes where a part overlaps its own colour | Handled: premultiplied rasters (`fix_alpha_edges()` also works but costs 10×) |
| Rasters past 4096 px | Parts cropped during big zooms | Handled: density capped a step below the limit |
| Godot's physics jitter fix under Movie Maker | Frames 2–4 land between frames | Handled: root compositions set `Engine.physics_jitter_fix = 0` for movie renders |
| Indexed writes to a packed-array property (`cells[i] = v`) | The setter never runs | Use `set_cell()`, or call `refresh()` |
| GDScript divides integers as integers | `118 / 25` is 4 | Convert to float first |
| Type inference from Variants | Parse errors on `:=` from a Dictionary or Callable result | Declare the type: `var at: float = ...` |
| `Vector2` is 32-bit | Drift in long accumulations | Keep time and accumulations in `float` (64-bit) |

**Performance.** Script cost per frame is 0.2–1.5 ms across all the demo pieces on a
2-core VM (`tests/perf.tscn`). GPU cost is the real budget for blur-heavy pieces: the goo
intros run up to seven full-screen blur layers. Profile on the target machine, and when a
piece must run during gameplay, cut layers, shrink each `MotionFX` to the area its content
covers, or blur at a lower `render_scale`.

**Offline rendering.** `tools/render.sh <scene> <out> <frames> [start]` renders with Movie
Maker (frames plus `f.wav`). Without a GPU it uses software GL under Xvfb: simple pieces
take about a minute, goo pieces 5–45 minutes. Split long renders with a start frame
(`-- --mk-start=N`), and run one render at a time on a small machine.

## Appendix: porting a piece made in a browser

Only needed when an existing Remotion, CSS or SVG animation has to be matched exactly, as
with the SCF intros. Port line for line, render both, compare with
`tools/compare/compare.py` (per-frame SSIM, worst-frame sheet, side-by-side video), and
expect the last 1% to be browser behaviour rather than the piece's own code: border-box
sizing, the 4 px strut under inline SVGs, rounded font metrics, per-glyph font fallback,
linearRGB SVG filters, pixel-sampled gradient stops, stacking contexts and three different
blur conventions. [porting-from-remotion.md](porting-from-remotion.md) lists each with its
fix.
