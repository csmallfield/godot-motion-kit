# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — take 2: MEGASTRUCTURE.
#
# Brief: the MC-202 poster made kinetic. A dense isometric machine city in
# signal red, cream, black and grey stands on a black platform: towers, silos,
# pipe racks, ramps, roof tanks, painted chevrons, EXIT arrows, serials and
# katakana. Everything is a real extruded solid seen through an orthographic
# camera, so the camera can crane from plan to isometric to a flat front
# elevation, where anything on a south face reads as clean 2D.
#   I   The city rises out of the platform in rings on sixteenths, radiating
#       from the plaza. The Minimal Humans monument rises out of the plaza
#       floor as one block, then unfolds on the beat: the M's three colour
#       layers telescope apart in depth and the wordmark pushes out of its
#       plane. A plinth in front is stamped PRESENTS. The camera swings down to
#       a near-front view to read it, then the monument sinks and the camera
#       whips across the rooftops.
#   II  Landing on the second plaza, the blocks in front drain into the floor
#       in rings; the FTF logo rises out of the ground as one pink slab and
#       locks with a slam. The camera swings to a flat front elevation: the logo
#       reads as 2D over a red/cream/black skyline, the platform's black face
#       printed with serials below it, the city pulsing on every beat.
#   III The camera pulls back to isometric, the city sinks back into the
#       platform in rings from the logo outwards (the logo first), then the
#       camera cranes to a plan view and dives into the empty platform top:
#       the last frames are flat ground colour, ready to cut to the menu.
#
# Tempo: 120 bpm, 4/4, first downbeat at frame 0: a beat is 15 frames, a bar
# 60. Music can be replaced by any 120 bpm track with its downbeat at 0.0 s.
#
# Beats (30 fps, 420 frames):
#   0-30    city rings rise out of the platform on sixteenths (8 rings)
#   45      monument starts rising out of the plaza; 60 it lands (bar 1)
#   75      unfold: M layers telescope, wordmark pushes out
#   90      PRESENTS stamped on the plinth; 97.5 katakana
#   105-135 near-front view: the lockup reads
#   135     monument sinks; 150 whip pan across the roofs
#   180     arrive at the FTF plaza (bar 3); blocks drain in rings
#   195     FTF slab rises out of the floor; 225 it locks (slam)
#   240     camera locks in front elevation (bar 4); hold, city pulses on beats
#   330     camera pulls back to iso
#   360     everything sinks in rings from the logo (bar 6)
#   372-405 crane to plan and dive into the platform; 405 empty ground; 420 end
#
# New kit technique: addons/motion_kit/extrude/ (MotionExtrude, MotionSolid,
# MotionExtrudeCamera): extruded solids, painter's ordering, ground cuts,
# decals in face planes and SVG artwork on caps.
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0

# ---- beat sheet (frames)
const BUILD := 0.0
const RINGS := 8
const RING_STEP := 3.75            # sixteenths
const MH_RISE := 45.0
const MH_LAND := 60.0
const MH_UNFOLD := 75.0
const STAMP := 90.0
const STAMP_JP := 97.5
const MH_SINK := 135.0
const WHIP := 150.0
const ARRIVE := 180.0
const FTF_RISE := 195.0
const FTF_LOCK := 225.0
const FRONT := 240.0
const BACK := 330.0
const SINK := 360.0
const DIVE := 390.0
const EMPTY := 405.0
const END := 420

# ---- palette (MC-202: red, cream, black, grey on paper)
const PAPER := Color("#efece4")
const GROUND := Color("#dedad0")
const MATS := {
	cream = [Color("#f8f4eb"), Color("#e6dfd0"), Color("#b7ae9e")],
	red = [Color("#f0453a"), Color("#d72c22"), Color("#901810")],
	black = [Color("#4b4b51"), Color("#2c2c31"), Color("#141417")],
	grey = [Color("#cfcdc6"), Color("#aeaca5"), Color("#7b7a75")],
	platform = [Color("#dedad0"), Color("#25252a"), Color("#111114")],
	pink = [Color("#ff5b93"), Color("#d21b5c"), Color("#8c0f3b")],
}
const RED := Color("#e8322a")
const INK := Color("#141417")
const CREAM := Color("#f8f4eb")
const EDGE := Color(0.08, 0.08, 0.09, 0.85)

# ---- world layout (1 unit = one city cell)
const NX := 24
const NY := 14
const MH_PLAZA := Rect2i(0, 0, 11, 5)       # cells kept clear for the monument
const FTF_PLAZA := Rect2i(11, 0, 13, 5)     # cells drained at ARRIVE
const MH_X := 1.6                          # monument's SVG top-left x
const MH_Y := 3.4                          # monument's back plane (north side)
const MH_WIDTH := 7.6                      # world width of the MH lockup
const FTF_X := 12.4
const FTF_Y := 3.3
const FTF_WIDTH := 10.0
const MH_SLAB := 0.22
const PED := 0.5                           # pedestal height under the monument
const LETTER_D := 0.32
const FTF_D := 0.6

var _built := false
var _scene := MotionExtrude.new()
var _cells: Array[Dictionary] = []
var _platform: MotionSolid
var _base_pipes: Array[MotionSolid] = []
var _mh_slabs: Array[MotionSolid] = []
var _mh_letters: Array[MotionSolid] = []
var _plinth: MotionSolid
var _backdrop: MotionSolid
var _ftf: MotionSolid
var _mh_h := 1.0
var _ftf_h := 1.0
var _mh_data: MotionSvgData
var _ftf_data: MotionSvgData

var _stage: Node2D
var _back: MotionCanvas
var _front: MotionCanvas
var _mh_sides: Array[MotionCanvas] = []
var _mh_masks: Array[MotionCanvas] = []
var _mh_svgs: Array[MotionSvg] = []
var _ftf_sides: MotionCanvas
var _ftf_mask: MotionCanvas
var _ftf_svg: MotionSvg
var _fill: ColorRect

var _font_mono: Font
var _font_wide: Font
var _font_jp: Font
var _active_y := MH_Y          # the monument the city is split around this frame
var _now := 0.0


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "logo": FTF_RISE, "hold": FRONT, "out": BACK}
	for k in RINGS:
		cue(BUILD + k * RING_STEP, &"city.ring", 0.55 + 0.05 * k, {pitch = [1.0, 1.12, 1.26, 1.33, 1.5, 1.68, 1.78, 2.0][k]})
	cue(MH_RISE, &"mh.rise", 0.8)
	cue(MH_LAND, &"mh.land", 1.0)
	cue(MH_UNFOLD, &"mh.unfold", 0.9)
	cue(STAMP, &"stamp", 0.9)
	cue(STAMP_JP, &"stamp.small", 0.6)
	cue(MH_SINK, &"sink", 0.7)
	cue(WHIP - 3.0, &"whip", 0.9)
	cue(ARRIVE, &"arrive", 0.9)
	cue(ARRIVE + 3.0, &"drain", 0.8)
	cue(FTF_RISE, &"ftf.rise", 1.0)
	cue(FTF_LOCK, &"ftf.lock", 1.0)
	cue(FRONT, &"cam.lock", 0.8)
	cue(BACK, &"cam.back", 0.7)
	cue(SINK, &"city.sink", 1.0)
	cue(DIVE, &"dive", 0.8)
	cue(EMPTY, &"end", 0.9)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _build() -> void:
	_built = true
	_font_mono = FTFKit.font("mono")
	_font_wide = FTFKit.font("wide")
	_font_jp = FTFKit.font("jp")
	_mh_data = _svg("res://demo/assets/logos/mh_logoFull_standard.svg")
	_ftf_data = _svg(FTFKit.LOGO)

	var bg := ColorRect.new()
	bg.color = PAPER
	bg.size = size
	add_child(bg)
	_stage = Node2D.new()
	add_child(_stage)
	_back = _canvas(_stage, func(c: MotionCanvas, f: float) -> void: _draw_back(c, f))

	_build_world()

	# Monument layers: the backdrop, then per M slab its sides and its artwork
	# (masked while cut by the ground).
	_mh_sides.append(_canvas(_stage, _sides_fn(_backdrop, true)))
	_mh_sides.append(_canvas(_stage, _sides_fn(_plinth, true)))
	for i in 3:
		_mh_sides.append(_canvas(_stage, _sides_fn(_mh_slabs[i])))
		var m := _mask_canvas([_mh_slabs[i]])
		_mh_masks.append(m)
		_mh_svgs.append(_svg_node(m, _mh_data, [i]))
	_mh_sides.append(_canvas(_stage, func(c: MotionCanvas, _f: float) -> void:
		for s in _mh_letters:
			_scene.draw_solid(c, s)))
	var lm := _mask_canvas(_mh_letters)
	_mh_masks.append(lm)
	_mh_svgs.append(_svg_node(lm, _mh_data, range(3, 16)))

	_ftf_sides = _canvas(_stage, _sides_fn(_ftf))
	_ftf_mask = _mask_canvas([_ftf])
	_ftf_svg = _svg_node(_ftf_mask, _ftf_data, [])

	_front = _canvas(_stage, func(c: MotionCanvas, f: float) -> void: _draw_front(c, f))
	_fill = ColorRect.new()
	_fill.size = size
	_fill.color = GROUND
	_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_fill)
	_add_sound()


func _msdf(path: String) -> FontFile:
	return MotionFonts.font(path, true)


func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _canvas(parent: Node, fn: Callable) -> MotionCanvas:
	var c := MotionCanvas.new()
	c.draw_fn = fn
	parent.add_child(c)
	return c


## Sides only (the cap is the SVG artwork above it), or everything for plain solids.
func _sides_fn(s: MotionSolid, with_cap := false) -> Callable:
	return func(c: MotionCanvas, _f: float) -> void:
		s.draw_front_cap = with_cap
		_scene.draw_solid(c, s)


## A canvas whose drawing masks its children: the cut outlines of `solids`' caps.
func _mask_canvas(solids: Array[MotionSolid]) -> MotionCanvas:
	var m := MotionCanvas.new()
	m.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		for s in solids:
			var poly := _scene.cap_polygon(s)
			if poly.size() >= 3 and absf(MotionExtrude._area2(poly)) > 2.0:
				c.draw_colored_polygon(poly, Color.WHITE)
	_stage.add_child(m)
	return m


func _svg_node(parent: Node, data: MotionSvgData, only: Array) -> MotionSvg:
	var s := MotionSvg.new()
	s.data = data
	s.width = data.view_box.size.x
	if not only.is_empty():
		s.only = PackedInt32Array(only)
	parent.add_child(s)
	return s


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_megastructure/audio/mega_map.tres"
	const SONG := "res://demo/ftf/ftf_megastructure/audio/music/mega_song.tres"
	const TRACK := "res://demo/ftf/ftf_megastructure/audio/ftf_megastructure_track.res"
	if ResourceLoader.exists(BRIDGE) and ResourceLoader.exists(MAP):
		var bridge: Node = (load(BRIDGE) as GDScript).new()
		bridge.set("cue_map", load(MAP))
		if ResourceLoader.exists(SONG):
			bridge.set("song", load(SONG))
		if ResourceLoader.exists(TRACK):
			bridge.set("track", load(TRACK))
		bridge.set("track_path", TRACK)
		add_child(bridge)
	elif ResourceLoader.exists(TRACK):
		var p := AudioStreamPlayer.new()
		p.stream = load(TRACK)
		add_child(p)
		audio = p
		clock = Clock.AUDIO


# ================================================================== world

func _mat(s: MotionSolid, key: String, edge := true) -> MotionSolid:
	var m: Array = MATS[key]
	s.paint(m[0], m[1], m[2])
	if edge and key != "black":
		s.stroke(EDGE, 1.2)
	s.data.mat = key
	return s


func _r(cx: int, cy: int, k: float) -> float:
	return MK.rand(cx * 13.13 + cy * 71.7 + k * 5.31 + 0.7)


func _pick_mat(cx: int, cy: int, k: float) -> String:
	var r := _r(cx, cy, k)
	if r < 0.42:
		return "cream"
	if r < 0.66:
		return "red"
	if r < 0.82:
		return "grey"
	return "black"


func _build_world() -> void:
	# The platform the city stands on: its top is the ground, its black faces
	# carry the serials.
	_platform = MotionSolid.box(Vector3(-0.7, -0.7, -1.5), Vector3(NX + 1.4, NY + 1.4, 1.5))
	_mat(_platform, "platform", false)
	_platform.sort_key = 1e9
	_platform.draw_front_cap = true
	_platform.add_decal(Vector3(0, -1, 0), func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _platform_face(c, sz, xf))
	_platform.add_decal(Vector3(1, 0, 0), func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _platform_east(c, sz, xf))
	# Pipes along the platform's south face (below ground, never cut).
	for k in 2:
		var p := MotionSolid.pipe(Vector3(-0.7, -0.84 - k * 0.1, -1.0 - k * 0.26), 0.11 - k * 0.02, NX + 1.4)
		_mat(p, "red" if k == 0 else "cream")
		p.sort_key = -1e9 + k
		p.layer = 1
		_base_pipes.append(p)
		_scene.add(p)

	for cy in NY:
		for cx in NX:
			_build_cell(cx, cy)

	# Minimal Humans monument: the M's three colour layers as slabs, the wordmark
	# as extruded letters, a black plinth in front.
	var mk := MH_WIDTH / _mh_data.view_box.size.x
	_mh_h = _mh_data.view_box.size.y * mk
	for i in 3:
		var s := MotionSolid.from_svg(_mh_data, i, mk, Vector3(MH_X, MH_Y, _mh_h), Vector3.RIGHT, Vector3(0, 0, 1), MH_SLAB)
		var col: Color = _mh_data.parts[i].fill
		s.paint(col.lightened(0.15), col.darkened(0.18), col.darkened(0.45))
		s.clip_z = PED
		_mh_slabs.append(s)
	for i in range(3, 16):
		var s := MotionSolid.from_svg(_mh_data, i, mk, Vector3(MH_X, MH_Y, _mh_h), Vector3.RIGHT, Vector3(0, 0, 1), LETTER_D)
		s.paint(Color("#fbf7ef"), Color("#cfc6b4"), Color("#8f8676"))
		s.clip_z = PED
		_mh_letters.append(s)
	# A black billboard wall behind the monument so the cream letters read.
	_backdrop = MotionSolid.new()
	_backdrop.set_outline(MotionSolid.rect_pts(MH_WIDTH + 1.2, 2.75))
	_backdrop.origin = Vector3(MH_X - 0.6, MH_Y + 1.35, 0.0)
	_backdrop.u = Vector3.RIGHT
	_backdrop.v = Vector3(0, 0, 1)
	_backdrop.depth = 0.3
	_mat(_backdrop, "black")
	_backdrop.clip_z = 0.0
	_backdrop.add_decal("front", func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _backdrop_face(c, sz, xf))
	# The pedestal the monument stands on, PRESENTS on its front. The monument
	# rises out of its top; the pedestal rises out of the ground.
	_plinth = MotionSolid.box(Vector3(MH_X - 0.25, MH_Y - 0.75, 0.0), Vector3(MH_WIDTH + 0.5, 1.45, PED))
	_mat(_plinth, "black")
	_plinth.clip_z = 0.0
	_plinth.add_decal(Vector3(0, -1, 0), func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D) -> void: _presents(c, sz, xf))

	var fk := FTF_WIDTH / _ftf_data.view_box.size.x
	_ftf_h = _ftf_data.view_box.size.y * fk
	_ftf = MotionSolid.from_svg(_ftf_data, FTFKit.RIM, fk, Vector3(FTF_X, FTF_Y, _ftf_h), Vector3.RIGHT, Vector3(0, 0, 1), FTF_D)
	_mat(_ftf, "pink")
	_ftf.clip_z = 0.0


func _in_rect(r: Rect2i, cx: int, cy: int) -> bool:
	return r.has_point(Vector2i(cx, cy))


func _build_cell(cx: int, cy: int) -> void:
	if _in_rect(MH_PLAZA, cx, cy):
		return
	var cell := {cx = cx, cy = cy, solids = [], rest = [], top = 0.0, ftf = _in_rect(FTF_PLAZA, cx, cy)}
	var o := Vector3(cx, cy, 0)
	var r := _r(cx, cy, 0)
	var south := cy <= 1
	var inset := 0.1
	var add := func(s: MotionSolid, stk: int) -> void:
		s.clip_z = 0.0
		s.stack = stk
		s.sort_at = Vector3(cx + 0.5, cy + 0.5, 0.0)
		s.data.cell = Vector2(cx + 0.5, cy + 0.5)
		cell.solids.append(s)
		cell.rest.append(s.origin.z)
		cell.top = maxf(cell.top, s.origin.z + (s.depth if s.normal().z > 0.5 else 0.6))
	var mat := _pick_mat(cx, cy, 1)
	if r < 0.08 and not south:
		return                                 # an empty lot
	if south:
		# The front rows stay low so the plazas and monuments read.
		var b := _mat(MotionSolid.box(o + Vector3(inset, inset, 0), Vector3(1 - 2 * inset, 1 - 2 * inset, 0.18 + 0.3 * _r(cx, cy, 2))), mat)
		add.call(b, 0)
		if _r(cx, cy, 3) > 0.5:
			var t := _mat(MotionSolid.cylinder(o + Vector3(0.5, 0.5, b.depth), 0.22, 0.25), "cream" if mat != "cream" else "red")
			add.call(t, 1)
			t.origin.z = b.depth
	elif r < 0.34:
		# Tower: shaft, a set-back cap, sometimes an antenna.
		var h := 1.8 + 2.6 * _r(cx, cy, 4)
		var b := _mat(MotionSolid.box(o + Vector3(inset, inset, 0), Vector3(1 - 2 * inset, 1 - 2 * inset, h)), mat)
		_tower_decals(b, cx, cy)
		add.call(b, 0)
		var c := _mat(MotionSolid.box(o + Vector3(0.24, 0.24, h), Vector3(0.52, 0.52, 0.35 + 0.3 * _r(cx, cy, 5))), _pick_mat(cx, cy, 6))
		add.call(c, 1)
		if _r(cx, cy, 7) > 0.55:
			var a := _mat(MotionSolid.cylinder(o + Vector3(0.5, 0.5, h + c.depth), 0.04, 0.7, 6), "black")
			add.call(a, 2)
	elif r < 0.58:
		# Mid block with roof plant: tanks or vent boxes.
		var h := 0.7 + 1.1 * _r(cx, cy, 8)
		var b := _mat(MotionSolid.box(o + Vector3(inset, inset, 0), Vector3(1 - 2 * inset, 1 - 2 * inset, h)), mat)
		_block_decals(b, cx, cy)
		add.call(b, 0)
		if _r(cx, cy, 9) > 0.45:
			var t := _mat(MotionSolid.cylinder(o + Vector3(0.38, 0.55, h), 0.2 + 0.08 * _r(cx, cy, 10), 0.35 + 0.3 * _r(cx, cy, 11)), "cream" if mat == "red" else "red")
			add.call(t, 1)
		else:
			for k in 2:
				var v := _mat(MotionSolid.box(o + Vector3(0.2 + k * 0.34, 0.3, h), Vector3(0.24, 0.42, 0.16)), "grey")
				v.add_decal("front", func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, _xf: Transform2D) -> void:
					for j in 4:
						c.draw_rect(Rect2(3, 4 + j * 10, sz.x - 6, 4), INK))
				add.call(v, 1)
	elif r < 0.74:
		# Silos on a low deck.
		var deck := _mat(MotionSolid.box(o + Vector3(0.05, 0.05, 0), Vector3(0.9, 0.9, 0.12)), "grey")
		add.call(deck, 0)
		var smat := "cream" if _r(cx, cy, 12) > 0.4 else "red"
		for k in 2:
			var s := _mat(MotionSolid.cylinder(o + Vector3(0.3 + k * 0.4, 0.3 + k * 0.4, 0.12), 0.19, 1.0 + 0.9 * _r(cx, cy, 13 + k), 14), smat)
			s.outline_width = 0.0
			if k == 0:
				s.add_decal("front", func(c: MotionCanvas, sz: Vector2, _s: MotionSolid, _xf: Transform2D) -> void:
					c.draw_circle(sz * 0.5, sz.x * 0.28, INK))
			add.call(s, 1 + k)
	elif r < 0.88:
		# A ramp, red, with chevrons.
		var w := _mat(MotionSolid.wedge(o + Vector3(0.08, 0.1, 0), 0.84, 0.8, 0.15, 1.1 + 0.8 * _r(cx, cy, 15)), "red" if mat != "red" else "cream")
		w.add_decal("front", func(c: MotionCanvas, sz: Vector2, s: MotionSolid, _xf: Transform2D) -> void:
			_chevrons(c, Vector2(8, sz.y - 22), 3, 14, CREAM if s.data.mat == "red" else RED))
		add.call(w, 0)
	else:
		# Pipe rack: two posts and two pipes running east.
		for k in 2:
			var post := _mat(MotionSolid.box(o + Vector3(0.12 + k * 0.66, 0.42, 0), Vector3(0.1, 0.16, 0.95)), "black")
			add.call(post, k)
		for k in 2:
			var p := _mat(MotionSolid.pipe(o + Vector3(0.0, 0.5, 0.55 + k * 0.3), 0.11, 1.0), "red" if k == 0 else "cream")
			p.outline_width = 0.0
			add.call(p, 2 + k)
	if cell.solids.is_empty():
		return
	for s in cell.solids:
		_scene.add(s)
	_cells.append(cell)


func _tower_decals(b: MotionSolid, cx: int, cy: int) -> void:
	var kind := int(_r(cx, cy, 20) * 4.0)
	var serial: String = ["MX-150", "A3", "FTF-09", "B-7", "K45", "S07", "T23", "N-9000"][int(_r(cx, cy, 21) * 8.0)]
	var jp: String = ["全開", "流束", "反重力", "第一", "起動", "信号", "機体"][int(_r(cx, cy, 22) * 7.0)]
	var accent := RED if b.data.mat != "red" else CREAM
	var ink := INK if b.data.mat in ["cream", "grey"] else CREAM
	b.add_decal(Vector3(0, -1, 0), _tower_face.bind(kind, serial, jp, accent, ink))
	if kind % 2 == 0:
		b.add_decal(Vector3(1, 0, 0), _tower_east.bind(accent))


func _tower_face(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D, kind: int, serial: String, jp: String, accent: Color, ink: Color) -> void:
	match kind:
		0:   # horizontal bands
			for j in 3:
				c.draw_rect(Rect2(0, 24 + j * 22, sz.x, 9), accent)
			_txt(c, xf, _font_mono, Vector2(8, sz.y - 14), serial, 13, ink)
		1:   # vertical serial up the face
			_txt(c, xf * Transform2D(-PI / 2, Vector2(sz.x - 12, sz.y - 10)), _font_wide, Vector2.ZERO, serial, 30, accent)
			c.draw_set_transform_matrix(xf)
			_txt(c, xf, _font_jp, Vector2(8, 30), jp, 18, ink)
		2:   # big circle
			c.draw_circle(Vector2(sz.x * 0.5, 50), 24, accent)
			c.draw_circle(Vector2(sz.x * 0.5, 50), 10, ink)
			_txt(c, xf, _font_mono, Vector2(8, 100), serial, 12, ink)
		_:   # chevrons climbing
			for j in 4:
				_chevron(c, Vector2(sz.x * 0.5, 30 + j * 22), 26, accent)


func _tower_east(c: MotionCanvas, sz: Vector2, _s: MotionSolid, _xf: Transform2D, accent: Color) -> void:
	c.draw_rect(Rect2(sz.x - 14, 0, 6, sz.y), accent)


func _block_decals(b: MotionSolid, cx: int, cy: int) -> void:
	var kind := int(_r(cx, cy, 30) * 3.0)
	var ink := INK if b.data.mat in ["cream", "grey"] else CREAM
	var accent := RED if b.data.mat != "red" else CREAM
	b.add_decal(Vector3(0, -1, 0), _block_face.bind(kind, accent, ink))


func _block_face(c: MotionCanvas, sz: Vector2, _s: MotionSolid, xf: Transform2D, kind: int, accent: Color, ink: Color) -> void:
	match kind:
		0:
			_txt(c, xf, _font_mono, Vector2(8, 22), "EXIT", 14, ink)
			_arrow(c, Vector2(52, 16), 18, accent)
		1:
			for j in 5:
				c.draw_rect(Rect2(6 + j * 14, 10, 8, sz.y - 20), accent)
		_:
			c.draw_rect(Rect2(0, 8, sz.x, 12), accent)


# ---------------------------------------------------------------- decals

## An upward chevron (^) of width w with its apex at `at`.
func _chevron(c: MotionCanvas, at: Vector2, w: float, col: Color) -> void:
	var h := w * 0.45
	var t := w * 0.24
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(-w * 0.5, h), at, at + Vector2(w * 0.5, h),
		at + Vector2(w * 0.5, h + t), at + Vector2(0, t), at + Vector2(-w * 0.5, h + t)]), col)


func _chevrons(c: MotionCanvas, at: Vector2, n: int, h: float, col: Color) -> void:
	for i in n:
		var x := at.x + i * h * 0.7
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, at.y), Vector2(x + h * 0.25, at.y), Vector2(x + h * 0.75, at.y + h * 0.5),
			Vector2(x + h * 0.25, at.y + h), Vector2(x, at.y + h), Vector2(x + h * 0.5, at.y + h * 0.5)]), col)


func _arrow(c: MotionCanvas, at: Vector2, s: float, col: Color) -> void:
	c.draw_colored_polygon(PackedVector2Array([at + Vector2(0, -s * 0.18), at + Vector2(s * 0.55, -s * 0.18), at + Vector2(s * 0.55, -s * 0.45),
		at + Vector2(s, 0), at + Vector2(s * 0.55, s * 0.45), at + Vector2(s * 0.55, s * 0.18), at + Vector2(0, s * 0.18)]), col)


func _platform_face(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	# The platform's south face: a strip of serials, katakana and markings,
	# readable in the front elevation under the logo. Pipes run below it.
	c.draw_rect(Rect2(0, 0, sz.x, 6), RED)
	var y := 42.0
	var x := 40.0
	var items := ["MEGASTRUCTURE 01", "フルスロットル・フラックス", "F-9000 // ANTI-GRAVITY LEAGUE", "反重力レース", "EXIT", "FULL THROTTLE FLUX", "全開流束", "MX-150 // 120 BPM", "第一", "MINIMAL HUMANS // BERLIN"]
	var k := 0
	while x < sz.x - 420.0:
		var t: String = items[k % items.size()]
		var fs := 22.0
		_txt(c, xf, _font_mono, Vector2(x, y), t, fs, CREAM if k % 4 != 2 else RED)
		x += _font_mono.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(fs)).x + 60.0
		if k % 3 == 0:
			_chevrons(c, Vector2(x - 46, y - 17), 2, 18, RED)
		k += 1
	# hazard hatch
	var hy := 58.0
	var i := 0.0
	while i < sz.x:
		c.draw_colored_polygon(PackedVector2Array([Vector2(i, hy), Vector2(i + 16, hy), Vector2(i + 30, hy + 18), Vector2(i + 14, hy + 18)]), Color(RED, 0.9))
		i += 36.0


func _platform_east(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	c.draw_rect(Rect2(0, 0, sz.x, 6), RED)
	_txt(c, xf, _font_wide, Vector2(40, 74), "MX-150", 46, CREAM)
	_txt(c, xf, _font_jp, Vector2(320, 70), "反重力レース　第一", 30, RED)


func _presents(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	var f := _now
	var s := MK.map(f, [STAMP, STAMP + 3], [0, 1], MK.ease_out)
	if s <= 0.0:
		return
	var a := minf(1.0, s * 2.0)
	var r := Rect2(24, 8, 296, sz.y - 16)
	var k := lerpf(1.25, 1.0, s)
	c.draw_rect(Rect2(r.get_center() - r.size * 0.5 * k, r.size * k), Color(RED, a))
	_txt(c, xf, _font_wide, Vector2(44, sz.y - 12), "PRESENTS", 28, Color(CREAM, a))
	var j := MK.map(f, [STAMP_JP, STAMP_JP + 3], [0, 1], MK.ease_out)
	if j > 0.0:
		_txt(c, xf, _font_jp, Vector2(350, sz.y - 13), "ミニマル・ヒューマンズ　提供", 24, Color(CREAM, j))


func _backdrop_face(c: MotionCanvas, sz: Vector2, xf: Transform2D) -> void:
	c.draw_rect(Rect2(0, 0, sz.x, 10), RED)
	_txt(c, xf, _font_mono, Vector2(24, 44), "MINIMAL HUMANS // FOSS STUDIO // BERLIN", 18, CREAM)
	_txt(c, xf, _font_jp, Vector2(sz.x - 330, 46), "ミニマル・ヒューマンズ", 24, RED)
	_chevrons(c, Vector2(sz.x - 120, 62), 4, 22, RED)
	for i in 6:
		c.draw_rect(Rect2(24 + i * 18, 64, 10, 22), CREAM if i % 2 == 0 else RED)


func _txt(c: MotionCanvas, xf: Transform2D, font: Font, pos: Vector2, t: String, size: float, col: Color) -> void:
	MotionExtrude.draw_text(c, xf, font, pos, t, size, col)


# ================================================================== motion

## Height offset of a city cell at frame f (0 = standing, negative = sunk).
func _cell_offset(cell: Dictionary, f: float) -> float:
	var depth: float = cell.top + 0.3
	var p := Vector2(cell.cx + 0.5, cell.cy + 0.5)
	# I: rings radiate from the MH plaza on sixteenths
	var d0 := p.distance_to(Vector2(MH_X + MH_WIDTH * 0.5, 2.0))
	var ring := mini(RINGS - 1, int(d0 / 2.9))
	var t0 := BUILD + ring * RING_STEP
	var up := MK.spring(f, t0, 15, 300)
	var off := -(1.0 - minf(up, 1.04)) * depth
	if f < t0:
		off = -depth
	# II: the FTF plaza drains in rings away from the logo
	var fc := Vector2(FTF_X + FTF_WIDTH * 0.5, 1.5)
	var df := p.distance_to(fc)
	if cell.ftf:
		var td := ARRIVE + 1.0 + floorf(df / 2.0) * 2.0
		off -= MK.map(f, [td, td + 7], [0, 1], MK.ease_in_quad) * depth
	# hold: a pulse runs out from the logo on every beat
	if f >= FRONT - 5.0 and f < SINK:
		var beat := floorf((f - FRONT) / 15.0)
		var bt := FRONT + beat * 15.0 + df * 0.5
		if f >= bt and f < BACK + 20.0:
			off -= 0.07 * exp(-(f - bt) * 0.35) * (1.0 - smoothstep(6.0, 14.0, df))
	# III: everything sinks in rings from the logo outwards
	var ts := SINK + 3.0 + floorf(df / 1.8) * 1.6
	off -= MK.map(f, [ts, ts + 8], [0, 1], MK.ease_in_quad) * (depth + 0.2)
	return off


func _camera(f: float) -> void:
	var cam := _scene.camera
	var t_open := Vector3(11.0, 6.0, 0.4)
	var t_mh := Vector3(MH_X + MH_WIDTH * 0.5, 2.8, 1.4)
	var t_ftf := Vector3(FTF_X + FTF_WIDTH * 0.5, 2.6, 1.0)
	var keys := [0.0, 58.0, 100.0, 135.0, 162.0, 180.0, 218.0, FRONT, BACK, 358.0, 372.0, EMPTY]
	cam.yaw = MK.interp(f, keys, [24, 36, 6, 6, 46, 36, 30, 0, 0, 40, 40, 40], MK.ease_in_out)
	cam.pitch = MK.interp(f, keys, [64, 31, 10, 12, 52, 32, 26, 2.5, 2.5, 34, 40, 90], MK.ease_in_out)
	# Zoom interpolates in log space, so dives and pull-backs read at an even pace.
	var zs := [56, 78, 150, 154, 62, 96, 104, 150, 154, 66, 70, 2600]
	var lz := []
	for z in zs:
		lz.append(log(float(z)))
	cam.scale = exp(MK.interp(f, keys, lz, MK.ease_in_out))
	var io := MK.bezier(0.6, 0.0, 0.25, 1.0)
	cam.target = t_open.lerp(t_mh, MK.map(f, [0, 70], [0, 1], MK.ease_in_out))
	cam.target = cam.target.lerp(t_ftf, MK.map(f, [140, 178], [0, 1], io))
	if f > SINK:
		cam.target = cam.target.lerp(Vector3(NX * 0.5, NY * 0.45, 0.0), MK.map(f, [SINK, EMPTY - 4], [0, 1], MK.ease_in_out))
	if f >= 100.0:
		cam.target.z = MK.interp(f, [100, 135, 180, 218, FRONT, BACK, 372], [1.4, 1.4, 0.9, 1.0, 1.5, 1.5, 0.0], MK.ease_in_out)
	# hold: a slow breathing yaw shows the slab's depth without breaking the read
	if f > FRONT and f < BACK:
		cam.yaw += 3.5 * sin((f - FRONT) * TAU / 120.0) * MK.map(f, [FRONT, FRONT + 20], [0, 1]) * (1.0 - MK.map(f, [BACK - 20, BACK], [0, 1]))
	cam.centre = Vector2(960, 540) + MK.shakes(f, [MH_LAND, FTF_LOCK], 16, 9) + MK.shakes(f, [STAMP, ARRIVE], 6, 6)


func _frame(f: float) -> void:
	if not _built:
		return
	_now = f
	_camera(f)
	for cell in _cells:
		var off := _cell_offset(cell, f)
		var sol: Array = cell.solids
		var rest: Array = cell.rest
		var gone: bool = off < -(cell.top as float) - 0.05
		for i in sol.size():
			var s: MotionSolid = sol[i]
			s.origin.z = (rest[i] as float) + off
			s.visible = not gone
	# Monument: rises out of the plaza, unfolds, sinks.
	var mh_up := MK.map(f, [MH_RISE + 1, MH_LAND], [0, 1], MK.bezier(0.5, 0.0, 0.2, 1.0))
	var mh_down := MK.map(f, [MH_SINK, MH_SINK + 13], [0, 1], MK.ease_in_quad)
	var mh_off := -(1.0 - mh_up + mh_down) * (_mh_h + 0.6)
	var unfold := MK.spring(f, MH_UNFOLD, 14, 220)
	var gap := 0.42 * unfold
	for i in 3:
		var s := _mh_slabs[i]
		s.origin = Vector3(MH_X, MH_Y + (2 - i) * gap, PED + _mh_h + mh_off)
	for s in _mh_letters:
		s.origin = Vector3(MH_X, MH_Y, PED + _mh_h + mh_off)
		s.depth = lerpf(0.04, LETTER_D, unfold)
	_plinth.origin.z = -(1.0 - MK.map(f, [MH_RISE - 6, MH_RISE + 2], [0, 1], MK.ease_out)) * (PED + 0.1) - MK.map(f, [MH_SINK + 8, MH_SINK + 16], [0, 1], MK.ease_in_quad) * (PED + 0.1)
	_backdrop.origin.z = -(1.0 - MK.map(f, [MH_RISE - 3, MH_LAND - 2], [0, 1], MK.bezier(0.5, 0.0, 0.2, 1.0)) + mh_down) * 3.0
	var mh_on := f >= MH_RISE - 8 and f < MH_SINK + 18
	# FTF slab: rises out of the floor, locks, sinks first at the end.
	var ftf_up := MK.map(f, [FTF_RISE, FTF_LOCK], [0, 1], MK.bezier(0.45, 0.0, 0.12, 1.0))
	var ftf_down := MK.map(f, [SINK, SINK + 12], [0, 1], MK.ease_in_quad)
	_ftf.origin.z = _ftf_h - (1.0 - ftf_up + ftf_down) * (_ftf_h + 0.4)
	var ftf_on := f >= FTF_RISE and f < SINK + 13
	_active_y = MH_Y if f < 160.0 else FTF_Y
	_scene.prepare()

	for c in _mh_sides:
		c.visible = mh_on
	for i in _mh_masks.size():
		_place_cap(_mh_masks[i], _mh_svgs[i], _mh_slabs[i] if i < 3 else _mh_letters[0], mh_on, i == 3)
	_ftf_sides.visible = ftf_on
	_place_cap(_ftf_mask, _ftf_svg, _ftf, ftf_on, false)

	# end: the dive lands flat on the ground colour
	_fill.color.a = MK.map(f, [EMPTY - 8, EMPTY], [0, 1], MK.linear)
	_fill.visible = _fill.color.a > 0.0


## Put an SVG on a solid's cap; masked while the solid is cut by the ground.
func _place_cap(mask: MotionCanvas, svg: MotionSvg, s: MotionSolid, on: bool, letters: bool) -> void:
	if not on:
		mask.visible = false
		return
	svg.transform = _scene.cap_transform(s)
	var whole := _scene.cap_unclipped(s) if not letters else _all_unclipped(_mh_letters)
	if whole:
		mask.clip_children = CanvasItem.CLIP_CHILDREN_DISABLED
		mask.visible = true
		mask.draw_fn = Callable()
		mask.queue_redraw()
		return
	var any := false
	var list: Array[MotionSolid] = []
	if letters:
		list = _mh_letters
	else:
		list.append(s)
	for q in list:
		if _scene.cap_polygon(q).size() >= 3:
			any = true
			break
	mask.visible = any
	mask.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
	mask.draw_fn = func(c: MotionCanvas, _f: float) -> void:
		for q in list:
			var poly := _scene.cap_polygon(q)
			if poly.size() >= 3 and absf(MotionExtrude._area2(poly)) > 2.0:
				c.draw_colored_polygon(poly, Color.WHITE)
	mask.queue_redraw()


func _all_unclipped(list: Array[MotionSolid]) -> bool:
	for s in list:
		if not _scene.cap_unclipped(s):
			return false
	return true


# ---------------------------------------------------------------- drawing

func _is_front(s: MotionSolid) -> bool:
	if s.layer == 1:
		return true
	var cpos: Vector2 = s.data.get("cell", Vector2(-1, 99))
	return cpos.y < _active_y - 0.6


func _draw_back(c: MotionCanvas, f: float) -> void:
	_scene.draw_solid(c, _platform)
	_ground_markings(c, f)
	_scene.draw(c, func(s: MotionSolid) -> bool:
		return s != _platform and not _is_front(s) and not _mh_slabs.has(s) and not _mh_letters.has(s) and s != _plinth and s != _ftf)


func _draw_front(c: MotionCanvas, _f: float) -> void:
	_scene.draw(c, func(s: MotionSolid) -> bool:
		return _is_front(s) and not _mh_slabs.has(s) and not _mh_letters.has(s) and s != _plinth and s != _ftf)


## Painted markings on the platform top (ground plane decals).
func _ground_markings(c: MotionCanvas, f: float) -> void:
	var cam := _scene.camera
	var xf := cam.plane_transform(Vector3(0, NY, 0), Vector3(1, 0, 0) / MotionExtrude.DECAL_PX, Vector3(0, -1, 0) / MotionExtrude.DECAL_PX)
	c.draw_set_transform_matrix(xf)
	var gy := func(y: float) -> float: return (NY - y) * MotionExtrude.DECAL_PX
	# MH plaza: a runway of hatching and EXIT arrows
	var on1 := MK.map(f, [20, 30], [0, 1], MK.ease_out)
	if on1 > 0.0:
		var x0 := MH_X * 100.0
		for i in int(18 * on1):
			var x := x0 + i * 42.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, gy.call(1.1)), Vector2(x + 20, gy.call(1.1)), Vector2(x + 44, gy.call(0.65)), Vector2(x + 24, gy.call(0.65))]), Color(INK, 0.85))
		_txt(c, xf, _font_mono, Vector2(x0, gy.call(0.25)), "PLAZA 01 // EXIT >>", 22, RED)
	# FTF plaza: chevron runway pointing at the logo, appearing as the blocks drain
	var on2 := MK.map(f, [ARRIVE + 4, ARRIVE + 14], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [SINK + 20, SINK + 30], [0, 1]))
	if on2 > 0.0:
		var x1 := FTF_X * 100.0
		for i in int(14 * on2):
			_chevrons(c, Vector2(x1 + 40 + i * 64, gy.call(2.25)), 1, 46, RED if i % 2 == 0 else INK)
		_txt(c, xf, _font_mono, Vector2(x1, gy.call(0.3)), "PLAZA 02 // F-9000 // GRID 01", 22, INK)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
