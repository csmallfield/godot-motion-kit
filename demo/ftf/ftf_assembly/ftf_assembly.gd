# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — round 4: ASSEMBLY (a Megastructure variation, at night).
#
# Brief: the isometric megastructure at night. An ink/navy ground with a faint
# cell grid and streets, a city of graphite blocks with lit windows and neon
# roof strips in FTF pink, lime, cyan and white, small traffic running the
# streets. The city's blocks are voxels: they physically re-stack themselves
# into the logo, each block sliding, flying or telescoping along grid moves to
# a target cell of a voxelised logo (the logo's mask sampled on the city grid;
# heights from the mask), in waves on the beat, from the middle out.
#   I   Lights come on in rings. Four waves on the beat re-stack the city into
#       the Minimal Humans lockup, read from above: the M's three layers as
#       three height tiers lit cream, amber and red, the wordmark in cream.
#       PRESENTS lights up on the ground in front. Hold alive: windows
#       flicker, a light sweep runs over the sculpture, chases run round the
#       roof strips, traffic runs.
#   II  The blocks disperse back into the city in two half-beat waves. Four
#       more waves pull the city into the FTF logo (letters tall and pink,
#       the plate low and white) while the camera swings round; a crane up
#       into the drop, and on the drop the real vector logo slab slams down
#       onto the voxel sculpture (it compresses under it, a shock ring runs
#       through the city), big and legible. Hold alive: a light chases round
#       the slab's rim, the checker squares step on the beat, the city pulses.
#   III The slab lifts off, the sculpture's blocks scatter outwards and sink,
#       the city's lights die in rings to black.
#
# Tempo: 100 bpm, 4/4, first downbeat at frame 0: a beat is 18 frames, a bar 72.
#
# Beats (30 fps, 420 frames):
#   0        power: ground and grid fade up (0-12)
#   9-22.5   window rings switch on, on sixteenths (9, 13.5, 18, 22.5)
#   36       MH wave 1 lifts; 54, 72, 90 waves 2-4 (each lands a beat later)
#   108      MH sculpture complete (bar 1.5); 117 PRESENTS lights up
#   108-162  hold: sweep, chases, flicker, traffic
#   162      disperse, waves at 162 and 171; city back by 192
#   198      FTF wave 1; 216, 234, 252 waves 2-4; 270 sculpture set
#   270-288  crane up into the drop; slab falls from 283
#   288      DROP (bar 4): slab slams on the sculpture, shake, shock ring
#   288-360  hold: rim chase, checkers on the beat, city pulse, slow drift
#   360      slab lifts off (bar 5); 369, 378 scatter waves
#   378-405  lights die in rings; 405-420 black
#
# New kit techniques: addons/motion_kit/voxel/ (MotionVoxelize: sample a mask
# onto grid cells; MotionBlockPlan: match blocks to target cells and move them
# in grid moves, in waves; MotionFaceLights: windows, neon strips and chases on
# MotionSolid faces). See KIT_NOTES.md.
@tool
extends MotionComposition

const W := 1920.0
const H := 1080.0

# ---- tempo
const BEAT := 18.0
const BAR := 72.0

# ---- beat sheet (frames)
const POWER := 0.0
const RINGS := [9.0, 13.5, 18.0, 22.5]
const MH_AT := 36.0
const MH_DONE := 108.0
const PRESENTS_AT := 117.0
const DISP_AT := 162.0
const FTF_AT := 198.0
const FTF_SET := 270.0
const FALL := 283.0
const DROP := 288.0
const LIFT := 360.0
const SCATTER := 369.0
const DIE := 378.0
const BLACK := 405.0
const END := 420

# ---- palette (night; FTF colours for the light)
const VOID := Color("#020308")
const GROUND := Color("#0a0e1d")
const GRID := Color("#141c34")
const STREET := Color("#172040")
const TOP := Color("#262b38")
const LIT := Color("#1a1e29")
const DARK := Color("#0f1118")
const PINK := Color("#ff2f7d")
const LIME := Color("#d7ff1f")
const CYAN := Color("#19c3e6")
const WHITE := Color("#eef3ff")
const WIN := [Color("#dfe8ff"), Color("#dfe8ff"), Color("#dfe8ff"), Color("#9fe9ff"), Color("#19c3e6"), Color("#ffd9e8")]
const STRIPS := [PINK, LIME, CYAN, WHITE]
const MH_CREAM := Color("#ece5da")
const MH_AMBER := Color("#f4af3f")
const MH_RED := Color("#ef393b")
const FTF_PINK := Color("#ff3a82")
const FTF_PLATE := Color("#aab3c8")
const FTF_WHITE := Color("#f4f7ff")

# ---- world (1 unit = one cell)
const NX := 96
const NY := 40
const INSET := 0.07
const MH_COLS := 72
const MH_ROWS := 20
const MH_O := Vector2(12, 10)      # south-west cell of the MH grid
const FTF_COLS := 68
const FTF_ROWS := 16
const FTF_O := Vector2(14, 12)
const CENTRE := Vector2(48, 20)
const SLAB_Z := 1.62
const SLAB_D := 0.4

var _built := false
var _scene := MotionExtrude.new()
var _mh_data: MotionSvgData
var _ftf_data: MotionSvgData

# blocks (parallel arrays)
var _solids: Array[MotionSolid] = []
var _home := PackedVector3Array()
var _mh_col := PackedColorArray()
var _ftf_col := PackedColorArray()
var _ftf_cell := PackedVector2Array()
var _ftf_hidden := PackedByteArray()
var _rim := PackedColorArray()
var _ring := PackedFloat32Array()      # window power-on frame
var _seed := PackedFloat32Array()
var _g := PackedFloat32Array()         # sculpture light weight this frame
var _lv := PackedFloat32Array()        # window/strip light level this frame
var _tint := PackedColorArray()        # sculpture colour this frame
var _front := PackedByteArray()        # drawn after the slab this frame

var _mh: MotionBlockPlan
var _disp: MotionBlockPlan
var _ftf: MotionBlockPlan
var _out: MotionBlockPlan

var _slab: MotionSolid
var _slab_k := 1.0
var _rim_pts := PackedVector2Array()   # the slab rim in SVG units

var _stage: Node2D
var _ground: MotionCanvas
var _city: MotionCanvas
var _air: MotionCanvas
var _slab_sides: MotionCanvas
var _slab_svg: MotionSvg
var _slab_fx: MotionCanvas
var _front_c: MotionCanvas
var _bg: ColorRect

var _font_wide: Font
var _font_mono: Font
var _now := 0.0
var _power := 1.0
var _slab_on := false


func _init() -> void:
	duration = END
	fps = 30
	markers = {"in": 0.0, "mh": MH_DONE, "logo": FTF_AT, "hold": DROP, "out": LIFT}
	cue(POWER, &"power", 0.8)
	for k in RINGS.size():
		cue(RINGS[k], &"lights.on", 0.5 + 0.1 * k, {pitch = [1.0, 1.189, 1.335, 1.498][k]})
	# Minimal Humans: four waves on the beat; each beat lands one and lifts the next.
	cue(MH_AT, &"wave", 0.7)
	for k in 3:
		cue(MH_AT + BEAT * (k + 1), &"step", 0.6 + 0.1 * k, {pitch = [1.0, 1.122, 1.26][k]})
	cue(MH_DONE, &"mh.lock", 1.0)
	cue(PRESENTS_AT, &"presents", 0.7)
	cue(DISP_AT, &"disperse", 0.8)
	cue(DISP_AT + BEAT, &"settle", 0.6)
	# FTF: four waves, the set, the drop.
	cue(FTF_AT, &"wave", 0.8)
	for k in 3:
		cue(FTF_AT + BEAT * (k + 1), &"step", 0.7 + 0.1 * k, {pitch = [1.122, 1.26, 1.335][k]})
	cue(FTF_SET, &"ftf.set", 0.9)
	cue(DROP, &"drop", 1.0)
	cue(LIFT, &"lift", 0.8)
	cue(SCATTER, &"scatter", 0.8)
	cue(DIE, &"power.down", 0.9)
	cue(BLACK - 3.0, &"end", 0.7)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== build

func _build() -> void:
	_built = true
	_font_wide = FTFKit.font("wide")
	_font_mono = FTFKit.font("mono")
	_mh_data = _svg("res://demo/assets/logos/mh_logoFull_standard.svg")
	_ftf_data = _svg(FTFKit.LOGO)
	_scene.min_decal_area = 70.0
	_scene.light = Vector3(-0.5, -1.0, 0.0)

	_bg = ColorRect.new()
	_bg.color = VOID
	_bg.size = size
	add_child(_bg)
	_stage = Node2D.new()
	add_child(_stage)
	_ground = _canvas(func(c: MotionCanvas, f: float) -> void: _draw_ground(c, f))
	_city = _canvas(func(c: MotionCanvas, _f: float) -> void:
		_scene.draw(c, func(s: MotionSolid) -> bool: return s.layer == 0 and _front[s.data.i] == 0))
	_air = _canvas(func(c: MotionCanvas, _f: float) -> void:
		_scene.draw(c, func(s: MotionSolid) -> bool: return s.layer == 1))
	_slab_sides = _canvas(func(c: MotionCanvas, _f: float) -> void: _scene.draw_solid(c, _slab))
	_slab_svg = MotionSvg.new()
	_slab_svg.data = _ftf_data
	_slab_svg.width = _ftf_data.view_box.size.x
	_stage.add_child(_slab_svg)
	_slab_fx = _canvas(func(c: MotionCanvas, f: float) -> void: _draw_slab_fx(c, f))
	_front_c = _canvas(func(c: MotionCanvas, _f: float) -> void:
		_scene.draw(c, func(s: MotionSolid) -> bool: return s.layer == 0 and _front[s.data.i] == 1))

	_build_city()
	_build_plans()
	_build_slab()
	_add_sound()


func _svg(path: String) -> MotionSvgData:
	var res: Resource = load(path) if ResourceLoader.exists(path) else null
	return res if res is MotionSvgData else MotionSvgData.from_file(path)


func _canvas(fn: Callable) -> MotionCanvas:
	var c := MotionCanvas.new()
	c.draw_fn = fn
	_stage.add_child(c)
	return c


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_assembly/audio/assembly_map.tres"
	const SONG := "res://demo/ftf/ftf_assembly/audio/music/assembly_song.tres"
	const TRACK := "res://demo/ftf/ftf_assembly/audio/ftf_assembly_track.res"
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


func _r(x: float, y: float, k: float) -> float:
	return MK.rand(x * 13.13 + y * 71.7 + k * 5.31 + 0.37)


static func _street_x(cx: int) -> bool:
	return cx % 6 == 5


static func _street_y(cy: int) -> bool:
	return cy % 5 == 4


func _build_city() -> void:
	for cy in NY:
		for cx in NX:
			if _street_x(cx) or _street_y(cy):
				continue
			if _r(cx, cy, 0) > 0.63:
				continue
			var d := Vector2(cx + 0.5, cy + 0.5).distance_to(CENTRE)
			var t := _r(cx, cy, 1)
			var h := 0.6 + 3.2 * pow(t, 1.8) * (1.0 - 0.3 * clampf(d / 50.0, 0.0, 1.0))
			_add_block(Vector3(cx, cy, h), d)


func _add_block(home: Vector3, d: float) -> void:
	var i := _solids.size()
	var s := MotionSolid.box(Vector3(home.x + INSET, home.y + INSET, 0.0), Vector3(1.0 - 2.0 * INSET, 1.0 - 2.0 * INSET, home.z))
	s.paint(TOP, LIT, DARK)
	s.data.i = i
	_solids.append(s)
	_scene.add(s)
	_home.append(home)
	_seed.append(_r(home.x, home.y, 7) * 100.0)
	var rc := Color(0, 0, 0, 0)
	if _r(home.x, home.y, 3) < 0.34:
		rc = STRIPS[int(_r(home.x, home.y, 4) * 4.0) % 4]
	_rim.append(rc)
	# Windows switch on in rings from the middle, on sixteenths.
	_ring.append(RINGS[clampi(int(d / 11.0), 0, 3)])
	for face in [Vector3(0, -1, 0), Vector3(1, 0, 0), Vector3(-1, 0, 0)]:
		s.add_decal(face, func(c: MotionCanvas, sz: Vector2, so: MotionSolid, _xf: Transform2D) -> void: _wall(c, sz, so))
	s.add_decal("front", func(c: MotionCanvas, sz: Vector2, so: MotionSolid, _xf: Transform2D) -> void: _roof(c, sz, so))


# ---------------------------------------------------------------- plans

func _key(p: Vector2, o: Vector2, cols: int, rows: int) -> float:
	# Elliptical distance from the logo's centre, 0 (middle) .. 1 (rim).
	var c := o + Vector2(cols, rows) * 0.5
	var q := (p + Vector2(0.5, 0.5) - c) / (Vector2(cols, rows) * 0.5)
	return clampf(q.length() / 1.1, 0.0, 1.0)


func _build_plans() -> void:
	var n := _solids.size()
	_mh_col.resize(n)
	_ftf_col.resize(n)
	_ftf_cell.resize(n)
	_ftf_hidden.resize(n)
	_mh_col.fill(Color(0, 0, 0, 0))
	_ftf_col.fill(Color(0, 0, 0, 0))
	_ftf_hidden.fill(0)
	_g.resize(n)
	_lv.resize(n)
	_tint.resize(n)
	_front.resize(n)
	_front.fill(0)
	var homes := PackedVector2Array()
	for h in _home:
		homes.append(Vector2(h.x, h.y))

	# --- Minimal Humans: the M's three layers pulled apart (one band of cells
	# each), three height tiers; the wordmark one tier.
	var mh_vox := MotionVoxelize.from_svg(_mh_data, MH_COLS, MH_ROWS, [], Rect2(-2, -2, 490, 141.5), 3, 0.45,
		{1: Vector2(4.67, 4.15), 0: Vector2(9.34, 8.3)})
	var mh_t := mh_vox.targets(func(p: int, _cv: float, _cell: Vector2i) -> float:
		return [0.8, 1.55, 2.3][p] if p < 3 else 1.05)
	_mh = MotionBlockPlan.new(n)
	_mh.start = MH_AT
	_mh.waves = 4
	_mh.wave_step = BEAT
	_mh.dur = BEAT
	_mh.jitter = 3.0
	_mh.lift = 2.4
	_mh.sink_share = 0.3
	_mh.seed_v = 3.0
	var mh_who := _assign(mh_vox, mh_t, MH_O, homes)
	var mh_rect := Rect2(MH_O - Vector2(2, 3), Vector2(MH_COLS + 4, MH_ROWS + 5))
	for i in n:
		var h := _home[i]
		var p := Vector2(h.x, h.y)
		var crouch := 0.0 if mh_rect.has_point(p + Vector2(0.5, 0.5)) else h.z * 0.7
		_mh.set_move(i, h, Vector3(h.x, h.y, crouch), _key(p, MH_O, MH_COLS, MH_ROWS))
	var mh_rank := _rank_keys(mh_vox, mh_t, MH_O, MH_COLS, MH_ROWS)
	for t in mh_t.size():
		var bi := mh_who[t]
		if bi < 0:
			continue
		var cell: Vector2i = mh_t[t].cell
		var w := mh_vox.world(cell, MH_O)
		_mh.set_move(bi, _home[bi], Vector3(w.x, w.y, mh_t[t].h), mh_rank[t])
		var part: int = mh_t[t].part
		_mh_col[bi] = [MH_RED, MH_AMBER, MH_CREAM][part] if part < 3 else MH_CREAM

	# --- back home: outer blocks first, two half-beat waves.
	_disp = MotionBlockPlan.new(n)
	_disp.start = DISP_AT
	_disp.waves = 2
	_disp.wave_step = BEAT * 0.5
	_disp.dur = BEAT
	_disp.jitter = 3.0
	_disp.lift = 1.8
	_disp.sink_share = 0.2
	_disp.seed_v = 5.0
	for i in n:
		var a := _mh.target(i)
		_disp.set_move(i, a, _home[i], 1.0 - _key(Vector2(a.x, a.y), MH_O, MH_COLS, MH_ROWS))

	# --- FTF: the plate low and white, letters tall and pink.
	var ftf_vox := MotionVoxelize.from_svg(_ftf_data, FTF_COLS, FTF_ROWS)
	var ftf_t := ftf_vox.targets(func(p: int, _cv: float, _cell: Vector2i) -> float: return _ftf_height(p))
	_ftf = MotionBlockPlan.new(n)
	_ftf.start = FTF_AT
	_ftf.waves = 4
	_ftf.wave_step = BEAT
	_ftf.dur = BEAT
	_ftf.jitter = 3.0
	_ftf.lift = 2.8
	_ftf.sink_share = 0.25
	_ftf.seed_v = 7.0
	var ftf_who := _assign(ftf_vox, ftf_t, FTF_O, homes)
	var ftf_rect := Rect2(FTF_O - Vector2(2, 3), Vector2(FTF_COLS + 4, FTF_ROWS + 5))
	for i in n:
		var h := _home[i]
		var p := Vector2(h.x, h.y)
		var crouch := 0.0 if ftf_rect.has_point(p + Vector2(0.5, 0.5)) else h.z
		_ftf.set_move(i, h, Vector3(h.x, h.y, crouch), _key(p, FTF_O, FTF_COLS, FTF_ROWS))
		_ftf_cell[i] = Vector2(-99, -99)
	var filled := {}
	for t in ftf_t.size():
		filled[ftf_t[t].cell] = true
	var ftf_rank := _rank_keys(ftf_vox, ftf_t, FTF_O, FTF_COLS, FTF_ROWS)
	for t in ftf_t.size():
		var bi := ftf_who[t]
		if bi < 0:
			continue
		var cell: Vector2i = ftf_t[t].cell
		var w := ftf_vox.world(cell, FTF_O)
		_ftf.set_move(bi, _home[bi], Vector3(w.x, w.y, ftf_t[t].h), ftf_rank[t])
		_ftf_col[bi] = _ftf_colour(ftf_t[t].part)
		_ftf_cell[bi] = w
		# Under the slab: only blocks on its south, east and west edges show.
		var south: bool = filled.has(cell + Vector2i(0, 1))
		var east: bool = filled.has(cell + Vector2i(1, 0))
		var west: bool = filled.has(cell + Vector2i(-1, 0))
		_ftf_hidden[bi] = 1 if south and east and west else 0

	# --- outro: the sculpture scatters outwards and sinks, the city sinks.
	_out = MotionBlockPlan.new(n)
	_out.start = SCATTER
	_out.waves = 2
	_out.wave_step = BEAT * 0.5
	_out.dur = 24.0
	_out.jitter = 4.0
	_out.slide_max = 99.0
	_out.seed_v = 9.0
	var fc := FTF_O + Vector2(FTF_COLS, FTF_ROWS) * 0.5
	for i in n:
		var a := _ftf.target(i)
		var p := Vector2(a.x, a.y)
		if _ftf_col[i].a > 0.0:
			var d := (p + Vector2(0.5, 0.5) - fc) / Vector2(FTF_COLS, FTF_ROWS)
			var step := 1.0 + floorf(_r(p.x, p.y, 11) * 4.0)
			var to := p + (Vector2(signf(d.x), 0) if absf(d.x) > absf(d.y) else Vector2(0, signf(d.y))) * step
			_out.set_move(i, a, Vector3(to.x, to.y, 0.0), _key(p, FTF_O, FTF_COLS, FTF_ROWS), MotionBlockPlan.SLIDE)
		else:
			_out.set_move(i, a, Vector3(a.x, a.y, 0.0), 0.3 + 0.7 * clampf(p.distance_to(CENTRE) / 50.0, 0.0, 1.0), MotionBlockPlan.STAY)


## Wave keys by rank of distance from the logo's middle, so every wave moves
## the same number of blocks (middle first).
func _rank_keys(vox: MotionVoxelize, tg: Array[Dictionary], o: Vector2, cols: int, rows: int) -> PackedFloat32Array:
	var idx := range(tg.size())
	var d := PackedFloat32Array()
	for t in tg:
		d.append(_key(vox.world(t.cell, o), o, cols, rows))
	idx.sort_custom(func(a: int, b: int) -> bool: return d[a] < d[b])
	var out := PackedFloat32Array()
	out.resize(tg.size())
	for r in idx.size():
		out[idx[r]] = (r + 0.5) / idx.size()
	return out


## Match blocks to a voxel logo's targets (nearest free block, rim first).
func _assign(vox: MotionVoxelize, tg: Array[Dictionary], o: Vector2, homes: PackedVector2Array) -> PackedInt32Array:
	var cells := PackedVector2Array()
	for t in tg:
		cells.append(vox.world(t.cell, o))
	return MotionBlockPlan.assign_nearest(homes, cells)


func _ftf_height(p: int) -> float:
	if p == FTFKit.PLATE:
		return 0.3
	if p == FTFKit.RIM:
		return 0.85
	if p in FTFKit.WORD or p in FTFKit.FLUX_TOP or p == FTFKit.FLUX_BOWL:
		return 1.5
	if p == FTFKit.TAB:
		return 0.6
	if p in FTFKit.FLUX_BOT:
		return 1.15
	if p in FTFKit.CHECKS:
		return 0.9
	return 0.55   # small wordmark


func _ftf_colour(p: int) -> Color:
	if p == FTFKit.PLATE:
		return FTF_PLATE
	if p in FTFKit.FLUX_BOT or p in FTFKit.CHECKS or p in FTFKit.SMALL:
		return FTF_WHITE
	return FTF_PINK


func _build_slab() -> void:
	_slab_k = FTF_COLS / _ftf_data.view_box.size.x
	var at := Vector3(FTF_O.x, FTF_O.y + _ftf_data.view_box.size.y * _slab_k, SLAB_Z)
	_slab = MotionSolid.from_svg(_ftf_data, FTFKit.RIM, _slab_k, at, Vector3.RIGHT, Vector3(0, 1, 0), SLAB_D)
	_slab.paint(FTF_PINK, FTF_PINK.darkened(0.3), FTF_PINK.darkened(0.6))
	_slab.draw_front_cap = false
	_slab.draw_back_cap = false
	var best := PackedVector2Array()
	for cv in _ftf_data.outline(FTFKit.RIM, 0.5):
		if cv.size() > best.size():
			best = cv
	_rim_pts = best


# ================================================================== motion

func _plan_at(f: float) -> MotionBlockPlan:
	if f >= SCATTER:
		return _out
	if f >= FTF_AT:
		return _ftf
	if f >= DISP_AT:
		return _disp
	return _mh


func _camera(f: float) -> void:
	var cam := _scene.camera
	var keys := [0.0, 40.0, 108.0, 158.0, 186.0, 246.0, DROP, 330.0, LIFT, BLACK]
	cam.yaw = MK.interp(f, keys, [38, 27, 8, 6, 28, -22, 5, -1.5, -5, 0], MK.ease_in_out)
	cam.pitch = MK.interp(f, keys, [38, 44, 57, 59, 44, 42, 62, 63, 61, 86], MK.ease_in_out)
	var zs := [36.0, 27.0, 23.5, 24.5, 18.0, 19.0, 22.5, 23.3, 24.2, 15.0]
	var lz := []
	for z in zs:
		lz.append(log(float(z)))
	cam.scale = exp(MK.interp(f, keys, lz, MK.ease_in_out))
	# The crane into the drop lands exactly on it, then a small punch-in recoils.
	cam.scale *= 1.0 + 0.045 * exp(-maxf(0.0, f - DROP) * 0.25) * float(f >= DROP)
	var tz := MK.interp(f, [0, 108, 186, DROP, LIFT, BLACK], [1.2, 1.0, 0.5, 1.4, 1.4, 0.0], MK.ease_in_out)
	var ty := MK.interp(f, [0, 108, 186, DROP, LIFT], [21.0, 19.6, 18.0, 19.6, 19.6], MK.ease_in_out)
	cam.target = Vector3(CENTRE.x, ty, tz)
	cam.centre = Vector2(960, 540) + MK.shakes(f, [DROP], 18, 10) + MK.shakes(f, [MH_DONE], 5, 6)


## Holds: on every beat a few city blocks telescope up and back (servos).
func _twitch(i: int, f: float) -> float:
	var at := -1.0
	if f >= MH_DONE and f < DISP_AT:
		at = MH_DONE
	elif f >= DROP + BEAT and f < LIFT:
		at = DROP
	if at < 0.0:
		return 0.0
	var b := floorf((f - at) / BEAT)
	if MK.rand(i * 0.917 + b * 13.1) > 0.1:
		return 0.0
	var t := (f - at - b * BEAT) / BEAT
	return 0.4 * sin(PI * minf(1.0, t * 1.4)) * float(t < 0.72)


## Height bump of the shock ring after the drop, for a block at p.
func _shock(p: Vector2, f: float) -> float:
	if f < DROP or f > DROP + 40.0:
		return 0.0
	var r := (f - DROP) * 1.6
	var d := p.distance_to(CENTRE)
	return exp(-pow((d - r) / 2.2, 2.0)) * (1.0 - (f - DROP) / 40.0)


func _frame(f: float) -> void:
	if not _built:
		return
	_now = f
	_camera(f)
	_power = MK.map(f, [POWER, POWER + 12], [0, 1], MK.linear) * (1.0 - MK.map(f, [DIE + 6, BLACK], [0, 1], MK.linear))
	var plan := _plan_at(f)
	var fade_in := MK.map(f, [0, 14], [0, 1], MK.linear)
	_slab_on = f >= FALL and f < LIFT + 14.0
	var squash := 0.0
	if f >= DROP:
		squash = 0.16 * exp(-(f - DROP) * 0.35) * sin(minf((f - DROP) * 0.9, PI))
	# The light sweep over a sculpture, once a bar, left to right.
	var sweep_x := -100.0
	if f >= MH_DONE - 6.0 and f < DISP_AT + 6.0:
		sweep_x = MH_O.x - 8.0 + fposmod(f - (MH_DONE - 6.0), BAR) / BAR * (MH_COLS + 16.0)
	elif f >= DROP - 18.0 and f < LIFT:
		sweep_x = FTF_O.x - 8.0 + fposmod(f - FTF_SET, BAR) / BAR * (FTF_COLS + 16.0)
	var beat_pulse := 0.0
	if f >= DROP and f < LIFT:
		beat_pulse = exp(-fposmod(f - DROP, BEAT) * 0.3)
	for i in _solids.size():
		var s := _solids[i]
		var p := plan.pose(i, f)
		var h := p.w
		# sculpture light weights
		var gm := 0.0
		if _mh_col[i].a > 0.0:
			gm = smoothstep(0.7, 1.0, _mh.progress(i, f)) * (1.0 - smoothstep(0.0, 0.4, _disp.progress(i, f)))
		var gf := 0.0
		if _ftf_col[i].a > 0.0:
			gf = smoothstep(0.7, 1.0, _ftf.progress(i, f)) * (1.0 - smoothstep(0.1, 0.7, _out.progress(i, f)))
		var tint := _mh_col[i] if gm > 0.0 else _ftf_col[i]
		var g := maxf(gm, gf)
		# the drop squashes the sculpture; the shock ring lifts the city
		if gf > 0.0 and f >= DROP:
			h *= 1.0 - squash
		elif g == 0.0:
			h *= 1.0 + 0.35 * _shock(Vector2(p.x, p.y), f) + _twitch(i, f)
		var lv := (1.0 if f >= _ring[i] else 0.0) * (1.0 - smoothstep(0.1, 0.8, _out.progress(i, f)))
		if f > DIE:
			lv *= 1.0 - MK.map(f, [DIE + _key(Vector2(p.x, p.y), FTF_O, FTF_COLS, FTF_ROWS) * 14.0, DIE + 10.0 + _key(Vector2(p.x, p.y), FTF_O, FTF_COLS, FTF_ROWS) * 14.0], [0, 1], MK.linear)
		lv *= 1.0 + 0.35 * beat_pulse * (1.0 - g)
		_g[i] = g
		_lv[i] = lv
		var covered := f >= DROP and f < LIFT + 1.0 and gf > 0.99 and _ftf_hidden[i] == 1
		s.visible = h > 0.015 and not covered
		if not s.visible:
			continue
		s.origin = Vector3(p.x + INSET, p.y + INSET, p.z)
		s.depth = h
		s.layer = 1 if p.z > 0.04 else 0
		_front[i] = 1 if _slab_on and p.y < FTF_O.y - 0.5 else 0
		var k := fade_in * (_power if f > DIE else 1.0)
		if g > 0.0:
			var band := 0.0
			if sweep_x > -50.0:
				band = exp(-pow((p.x - sweep_x) / 2.5, 2.0))
			var lum := (0.92 + 0.08 * band) * lv
			var top := tint.lerp(Color.WHITE, 0.3 * band) * lum
			top.a = 1.0
			s.top = TOP.lerp(top, g) * k
			s.lit = LIT.lerp(tint.darkened(0.55), g) * k
			s.dark = DARK.lerp(tint.darkened(0.78), g) * k
			_tint[i] = tint
		else:
			s.top = TOP * k
			s.lit = LIT * k
			s.dark = DARK * k
		s.top.a = 1.0
		s.lit.a = 1.0
		s.dark.a = 1.0
	_place_slab(f)
	_scene.prepare()
	_bg.color = VOID * MK.map(f, [BLACK - 12, BLACK], [1, 0], MK.linear)
	_bg.color.a = 1.0


func _place_slab(f: float) -> void:
	var z := SLAB_Z
	if f < DROP:
		var t := MK.map(f, [FALL, DROP], [0, 1], MK.linear)
		z = SLAB_Z + 60.0 * pow(1.0 - t, 2.0)
	else:
		var sq := 0.16 * exp(-(f - DROP) * 0.35) * sin(minf((f - DROP) * 0.9, PI))
		z = SLAB_Z * (1.0 - sq)
	if f > LIFT:
		z += 140.0 * pow(MK.map(f, [LIFT, LIFT + 14], [0, 1], MK.linear), 2.0)
	_slab.origin.z = z
	_slab.visible = _slab_on
	_slab_sides.visible = _slab_on
	_slab_fx.visible = _slab_on
	_slab_svg.visible = _slab_on
	if _slab_on:
		_slab_svg.transform = _scene.cap_transform(_slab)
		var step := int(floorf(maxf(0.0, f - DROP) / BEAT))
		_slab_svg.apply(func(i: int) -> Variant:
			var ci: int = FTFKit.CHECKS.find(i)
			if ci < 0 or f < DROP:
				return null
			return {fill = FTF_PINK} if (ci + step) % 4 == 0 else null)


# ================================================================== drawing

func _wall(c: MotionCanvas, sz: Vector2, s: MotionSolid) -> void:
	var i: int = s.data.i
	var lv := _lv[i]
	if lv <= 0.01:
		return
	var g := _g[i]
	if g > 0.5:
		# Sculpture walls: floors lit in the sculpture's own colour.
		var t := _tint[i].lightened(0.25)
		MotionFaceLights.windows(c, sz, _seed[i], _now, t, lv * 0.85 * g, 0.7, 0.03, 9.0, 26.0, 16.0, 8.0)
	else:
		MotionFaceLights.windows(c, sz, _seed[i], _now, WIN[0], lv * (1.0 - g), 0.42, 0.05, 6.0, 24.0, 13.0, 9.0, WIN)
		var rc := _rim[i]
		if rc.a > 0.0 and int(_seed[i]) % 3 == 0 and sz.y > 60.0:
			# a vertical neon strip down one corner
			MotionFaceLights.strip(c, Vector2(5, 0), Vector2(5, sz.y), Color(rc, lv * (1.0 - g)), 4.0, 3.0, 0.2)


func _roof(c: MotionCanvas, sz: Vector2, s: MotionSolid) -> void:
	var i: int = s.data.i
	var rc := _rim[i]
	var lv := _lv[i] * (1.0 - _g[i])
	if rc.a <= 0.0 or lv <= 0.01:
		return
	MotionFaceLights.rim(c, sz, Color(rc, lv * 0.85), 5.0, 2.6, 0.22)
	if int(_seed[i] * 7.0) % 2 == 0:
		var ph := fposmod(_now / (BEAT * 2.0) + _seed[i] * 0.37, 1.0)
		MotionFaceLights.chase(c, sz, ph, 0.22, Color(WHITE, lv), 7.0, 2.4)


func _gp(x: float, y: float, z := 0.0) -> Vector2:
	return _scene.camera.project(Vector3(x, y, z))


func _draw_ground(c: MotionCanvas, f: float) -> void:
	var pw := _power
	if pw <= 0.0:
		return
	var m := 3.0
	var quad := PackedVector2Array([_gp(-m, -m), _gp(NX + m, -m), _gp(NX + m, NY + m), _gp(-m, NY + m)])
	c.draw_colored_polygon(quad, Color(GROUND * pw, 1.0))
	# the cell grid, then the streets
	var gc := Color(GRID, pw * 0.9)
	for x in range(0, NX + 1):
		if not _street_x(x - 1) and not _street_x(x):
			c.draw_line(_gp(x, 0), _gp(x, NY), gc, 1.0)
	for y in range(0, NY + 1):
		if not _street_y(y - 1) and not _street_y(y):
			c.draw_line(_gp(0, y), _gp(NX, y), gc, 1.0)
	var sc := Color(STREET, pw)
	var lw := 0.5 * _scene.camera.scale
	for x in NX:
		if _street_x(x):
			c.draw_line(_gp(x + 0.5, 0), _gp(x + 0.5, NY), sc, lw * 0.9)
	for y in NY:
		if _street_y(y):
			c.draw_line(_gp(0, y + 0.5), _gp(NX, y + 0.5), sc, lw * 0.9)
	_spill(c)
	_traffic(c, f, pw)
	_presents(c, f, pw)


## Light spilling from the sculpture onto the ground: a faint tinted pad under
## every lit block, overlapping into a soft pool.
func _spill(c: MotionCanvas) -> void:
	for i in _solids.size():
		var g := _g[i]
		if g < 0.2:
			continue
		var s := _solids[i]
		if not s.visible or s.origin.z > 0.05:
			continue
		var o := s.origin - Vector3(INSET, INSET, 0)
		var m := 0.55
		var col := Color(_tint[i], 0.075 * g * _lv[i])
		c.draw_colored_polygon(PackedVector2Array([_gp(o.x - m, o.y - m), _gp(o.x + 1 + m, o.y - m), _gp(o.x + 1 + m, o.y + 1 + m), _gp(o.x - m, o.y + 1 + m)]), col)


## Cars: head lights one way, tail lights the other, on every street.
func _traffic(c: MotionCanvas, f: float, pw: float) -> void:
	var on := MK.map(f, [RINGS[0], RINGS[3]], [0, 1], MK.linear) * pw
	if on <= 0.0:
		return
	var w := maxf(1.5, _scene.camera.scale * 0.12)
	var k := 0
	for x in NX:
		if not _street_x(x):
			continue
		for j in 3:
			_car(c, true, x + 0.5, f, k * 3 + j, float(NY), on, w)
		k += 1
	for y in NY:
		if not _street_y(y):
			continue
		for j in 4:
			_car(c, false, y + 0.5, f, k * 3 + j, float(NX), on, w)
		k += 1


func _car(c: MotionCanvas, vertical: bool, lane: float, f: float, id: int, length: float, on: float, w: float) -> void:
	var r := MK.rand(id * 3.71 + 0.5)
	var dir := 1.0 if MK.rand(id * 1.3) < 0.5 else -1.0
	var speed := 0.12 + 0.18 * MK.rand(id * 2.9)
	var off := 0.14 * dir
	var s := fposmod(r * length + dir * speed * f, length + 6.0) - 3.0
	var tail := s - dir * 1.6
	var col := WHITE if dir > 0.0 else PINK
	var a: Vector2
	var b: Vector2
	if vertical:
		a = _gp(lane + off, tail)
		b = _gp(lane + off, s)
	else:
		a = _gp(tail, lane + off)
		b = _gp(s, lane + off)
	c.draw_line(a, b, Color(col, 0.35 * on), w)
	c.draw_line(a.lerp(b, 0.75), b, Color(col, 0.95 * on), w * 1.4)


func _presents(c: MotionCanvas, f: float, pw: float) -> void:
	var a := MK.map(f, [PRESENTS_AT, PRESENTS_AT + 4], [0, 1], MK.linear) * (1.0 - MK.map(f, [DISP_AT, DISP_AT + 6], [0, 1], MK.linear)) * pw
	if a <= 0.0:
		return
	var cam := _scene.camera
	var y := MH_O.y - 1.7
	var xf := cam.plane_transform(Vector3(MH_O.x + 23.0, y, 0.0), Vector3(1, 0, 0) / MotionExtrude.DECAL_PX, Vector3(0, -1, 0) / MotionExtrude.DECAL_PX)
	# a neon underline, then the word, then a small caption
	c.draw_set_transform_matrix(xf)
	var fl := 0.75 + 0.25 * float(int(f) % 5 != 0 or f > PRESENTS_AT + 10.0)
	MotionFaceLights.strip(c, Vector2(0, 40), Vector2(2560, 40), Color(MH_AMBER, a * fl), 8.0, 3.0, 0.25)
	MotionExtrude.draw_text(c, xf, _font_wide, Vector2(0, 0), "PRESENTS", 170, Color(MH_CREAM, a * fl))
	MotionExtrude.draw_text(c, xf, _font_mono, Vector2(1300, -8), "MINIMAL HUMANS // BERLIN // FOSS", 54, Color(MH_AMBER, a * 0.9))
	c.draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_slab_fx(c: MotionCanvas, f: float) -> void:
	if f < DROP or _rim_pts.size() < 3:
		return
	# A light running round the slab's rim, a lap every two beats.
	c.draw_set_transform_matrix(_scene.cap_transform(_slab))
	var a := 1.0 - MK.map(f, [LIFT, LIFT + 8], [0, 1], MK.linear)
	for k in 2:
		var ph := (f - DROP) / (BEAT * 2.0) + k * 0.5
		MotionFaceLights.chase_path(c, _rim_pts, ph, 0.12, Color(WHITE, 0.95 * a), 5.0, 3.2)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)
