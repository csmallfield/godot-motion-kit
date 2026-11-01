# SPDX-License-Identifier: Apache-2.0
# FULL THROTTLE FLUX — round 4: CANYON ("Through the Megastructure").
#
# Brief: the MC-202 machine city of the Megastructure take, built in REAL 3D
# (MotionStage3D) in the same flat red / cream / black / grey graphic look:
# faces toned by normal (top, lit, dark), crisp black outlines on every crease
# and silhouette, decals for serials, katakana, EXIT arrows, chevrons and
# hazard stripes. Daylight paper sky, depth fog to paper.
#   I   Black shutters open on a low, fast flight down a canyon street:
#       walkways and pipe racks overhead on the beat, oncoming pods whipping
#       past, long pipes streaking along the walls.
#   II  The camera bursts out of the canyon into a plaza and swings across the
#       front of the Minimal Humans monument: the lockup extruded on a black
#       plinth against a black billboard; the M's three colour layers
#       telescope apart on the beat, PRESENTS is stamped on the plinth, the
#       katakana follows. The camera keeps swinging (the layers' parallax keeps
#       the hold alive), then peels away into a second canyon: a pipe rack, two
#       walkways, a banked left-hander.
#   III Out of the canyon the camera lifts, and its projection blends from
#       perspective into the exact isometric orthographic view of the
#       Megastructure take (MotionLens3D: a dolly zoom that keeps the plaza
#       framed while the field of view collapses, then a true orthographic
#       camera of matching size, no pop). Hatch doors open in the plaza floor
#       and the FTF logo slab rises out of it as one piece, locking on the
#       drop, big and legible. Hold: the city pulses in rings on every beat,
#       tiny traffic runs the streets, tower cranes swing, chevrons chase
#       across the plaza towards the logo.
#   IV  The city sinks into the ground in rings from the logo outwards, the
#       logo sinks back into its slot, the hatch slams shut, the lights cut
#       and the shutters close: black.
#
# Tempo: 112.5 bpm, 4/4, first downbeat at frame 0: a beat is 16 frames, a bar
# 64. Any 112.5 bpm track with its downbeat at 0.0 s replaces the music.
#
# Beats (30 fps, 420 frames):
#   0-12      shutters open on the canyon flight (bar 0)
#   16/32/48  walkways overhead; 24/40/56 pipe racks; pods pass at 20, 44
#   60-64     out of the canyon mouth into the plaza (bar 1): monument revealed
#   80        M layers telescope apart (unfold)
#   96        PRESENTS stamped; 104 katakana
#   64-150    swing across the monument (readable ~70-148)
#   144       peel away (whip); 160 pipe rack; 168 walkway; 176 corner; 184 walkway
#   192       lift out of the canyon (bar 3)
#   200-250   projection blend: perspective -> isometric orthographic
#   224       hatch doors open; 228 the FTF slab starts rising
#   256       DROP: slab locks (bar 4); hold to 352, city pulses every beat
#   280/312   cranes swing
#   352       city sinks in rings (bar 5.5); 372 slab sinks; 384 hatch shuts
#   392-404   lights cut, shutters close; 404-420 black
#
# New kit techniques (addons/motion_kit/three/): MotionLens3D (perspective <->
# orthographic blend, MotionExtrudeCamera parity), MotionFlat3D (face tones
# by normal, depth fog, frame-pure ring/pulse group motion in the shader,
# builders), MotionEdges3D (screen-space crease + silhouette outlines),
# MotionDecalAtlas (2D markings drawn once, mapped onto 3D faces).
# Sound: audio/make.py writes the recipes, cue map and a 112.5 bpm song;
# tools/bake_audio.gd bakes them.
@tool
extends MotionComposition

const CB := preload("res://demo/ftf/ftf_canyon/canyon_build.gd")

# ---- beat sheet (frames)
const BPM := 112.5
const BEAT := 1800.0 / BPM          # frames per beat at 30 fps
const BAR := 4.0 * BEAT
const WALKS := [16.0, 32.0, 48.0, 168.0, 184.0]
const PIPES := [24.0, 40.0, 56.0, 160.0]
const PODS := [20.0, 44.0]
const MOUTH := 60.0
const PLAZA := 64.0
const UNFOLD := 80.0
const STAMP := 96.0
const STAMP_JP := 104.0
const PEEL := 144.0
const CORNER := 176.0
const LIFT := 192.0
const POSE := [200.0, 244.0]       # view turns to the iso direction
const FLATTEN := [206.0, 250.0]    # perspective -> orthographic
const HATCH := 224.0
const RISE := 228.0
const DROP := 256.0
const CRANES := [280.0, 312.0]
const SINK := 352.0
const FTF_SINK := 372.0
const SHUT := 384.0
const CUT := 392.0
const BLACK := 404.0
const END := 420

# ---- look
const PAPER := Color("#efece4")
const RED := Color("#e8322a")
const INK := Color("#141417")
const CREAM := Color("#f8f4eb")
const ISO_YAW := 45.0
const ISO_PITCH := 35.264
const ISO_SCALE := 122.0

# ---- world (grid coordinates: x east, y north; see canyon_build.gd)
const PED := 0.5                   # monument plinth height
const MH_W := 7.0
const MH_GAP := 0.32               # unfolded M layer spacing
const FTF_C := Vector2(9, 15)      # FTF plaza centre
const FTF_W := 10.0
const LEAN := 12.0                 # the slab leans back (degrees) to face the iso camera

var _built := false
var _stage: MotionStage3D
var _flat := MotionFlat3D.new()
var _atlas: MotionDecalAtlas
var _curve: Curve3D
var _travel: MotionTravel   # camera distance along the route per frame
var _cb: RefCounted

var _ink_fixed: ShaderMaterial
var _mh_layers: Array[Node3D] = []
var _mh_letters: Node3D
var _presents: MotionPanel3D
var _slab: Node3D
var _slab_h := 2.4
var _doors: Array[Node3D] = []
var _hatch: Node3D
var _floor: MotionPanel3D
var _cranes: Array[Node3D] = []
var _pods: Array[Node3D] = []
var _pod_specs: Array[Dictionary] = []
var _shut_top: ColorRect
var _shut_bot: ColorRect

var _font_mono: Font
var _font_wide: Font
var _font_jp: Font


func _init() -> void:
	duration = END
	bpm = BPM
	fps = 30
	markers = {"in": 0.0, "logo": RISE, "hold": DROP, "out": SINK}
	cue(0.0, &"open", 0.8)
	for i in WALKS.size():
		cue(WALKS[i] - 5.0, &"pass.walk", 0.75 + 0.05 * (i % 3), {pitch = [1.0, 0.92, 1.06, 0.97, 1.12][i]})
	for i in PIPES.size():
		cue(PIPES[i] - 2.0, &"pass.pipe", 0.65, {pitch = [1.0, 1.12, 0.94, 1.06][i]})
	for i in PODS.size():
		cue(PODS[i] - 9.0, &"pod", 0.85, {pitch = [1.0, 0.89][i]})
	cue(MOUTH - 4.0, &"mouth", 0.8)
	cue(PLAZA, &"mh.reveal", 1.0)
	cue(UNFOLD, &"mh.unfold", 0.9)
	cue(STAMP, &"stamp", 0.9)
	cue(STAMP_JP, &"stamp.small", 0.6)
	cue(PEEL - 4.0, &"whip", 0.9)
	cue(CORNER - 3.0, &"bank", 0.8)
	cue(LIFT, &"lift", 0.9)
	cue(FLATTEN[0], &"lens", 0.9)
	cue(HATCH, &"hatch", 0.8)
	cue(RISE, &"ftf.rise", 1.0)
	cue(DROP, &"ftf.lock", 1.0)
	for i in CRANES.size():
		cue(CRANES[i], &"crane", 0.6, {pitch = [1.0, 0.84][i]})
	cue(SINK, &"city.sink", 1.0)
	cue(FTF_SINK, &"ftf.sink", 0.8)
	cue(SHUT, &"hatch.shut", 0.9)
	cue(CUT, &"cut", 1.0)


func _ready() -> void:
	if not _built:
		_build()
	super._ready()


# ================================================================== timing

## Camera anchors: (frame, grid point) pairs the ride passes through; the
## distance along the route between them is a monotone cubic of the frame.
const ANCHORS := [[0.0, Vector2(-5, -46)], [MOUTH, Vector2(-4.95, -8.6)], [108.0, Vector2(0, -6.15)],
	[146.0, Vector2(5.4, -5.4)], [CORNER, Vector2(14.7, -4.6)], [LIFT, Vector2(15, 3.0)],
	[212.0, Vector2(15, 7.6)], [248.0, Vector2(15, 10.0)]]

## The route (grid x, y, camera height); corners rounded by the curve.
const ROUTE := [Vector3(-5, -50, 0.42), Vector3(-5, -40, 0.42), Vector3(-5, -30, 0.42), Vector3(-5, -20, 0.42),
	Vector3(-5, -11, 0.44), Vector3(-4.9, -8.4, 0.5), Vector3(-4.3, -7.0, 0.6), Vector3(-3.0, -6.4, 0.72),
	Vector3(-1.2, -6.2, 0.8), Vector3(1.0, -6.15, 0.82), Vector3(3.0, -6.0, 0.78), Vector3(4.8, -5.6, 0.66),
	Vector3(6.4, -5.15, 0.52), Vector3(8.0, -5.0, 0.45), Vector3(11.0, -5.0, 0.45), Vector3(13.4, -5.0, 0.45),
	Vector3(14.5, -4.75, 0.45), Vector3(15.0, -3.9, 0.45), Vector3(15.0, -1.0, 0.45), Vector3(15.0, 3.0, 0.45),
	Vector3(15.0, 7.0, 0.5), Vector3(15.0, 11.0, 0.6), Vector3(15.0, 14.0, 0.7)]


func _make_curve() -> void:
	var bank := {13: 0.0, 15: -0.18, 16: -0.32, 17: -0.18, 5: 0.06, 6: 0.14, 7: 0.1}
	var pts: Array[Vector3] = []
	var tilts: Array[float] = []
	for i in ROUTE.size():
		var q: Vector3 = ROUTE[i]
		pts.append(CB.w(q.x, q.y, q.z))
		tilts.append(bank.get(i, 0.0))
	_curve = MotionTrack3D.circuit(pts, tilts, 0.18, 0.1)


func _make_table() -> void:
	# a monotone cubic through the anchors: the camera passes each landmark on its frame
	var xs: Array[float] = []
	var ys: Array[float] = []
	for a in ANCHORS:
		var g: Vector2 = a[1]
		xs.append(a[0])
		ys.append(_curve.get_closest_offset(CB.w(g.x, g.y, 0.5)))
	_travel = MotionTravel.from_anchors(xs, ys, END + 2)


## Camera distance along the route at frame f (pure: a table lookup).
func s_at(f: float) -> float:
	return _travel.at(f)


func _grid_at(s: float) -> Vector2:
	var p := _curve.sample_baked(clampf(s, 0.0, _curve.get_baked_length()))
	return Vector2(p.x, -p.z)


# ================================================================== build

func _build() -> void:
	_built = true
	_font_mono = FTFKit.font("mono")
	_font_wide = FTFKit.font("wide")
	_font_jp = FTFKit.font("jp")
	_make_curve()
	_make_table()

	var bg := ColorRect.new()
	bg.color = PAPER
	bg.size = size
	add_child(bg)
	_stage = MotionStage3D.new()
	_stage.size = size
	add_child(_stage)
	_stage.environment.background_color = PAPER

	_atlas = MotionDecalAtlas.new()
	_stage.world.add_child(_atlas)
	_cb = CB.new()
	_atlas_cells()
	_build_city()
	_build_monument()
	_build_slab()
	_build_cranes()
	_build_pods()

	_shut_top = ColorRect.new()
	_shut_top.color = Color.BLACK
	add_child(_shut_top)
	_shut_bot = ColorRect.new()
	_shut_bot.color = Color.BLACK
	add_child(_shut_bot)
	_add_sound()


## Atlas cells: white artwork, tinted per decal.
func _atlas_cells() -> void:
	var cb: Variant = _cb
	var put := func(name: String, px: Vector2i, fn: Callable) -> void:
		cb.uv[name] = _atlas.add(px, fn)
		cb.aspect[name] = float(px.y) / float(px.x)
	var wht := Color.WHITE
	var text_cell := func(font: Font, t: String, px: Vector2i, fs: int) -> Callable:
		return func(c: MotionCanvas, sz: Vector2) -> void:
			var s := fs
			var wdt := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
			if wdt > sz.x - 16.0:
				s = int(s * (sz.x - 16.0) / wdt)
				wdt = font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x
			var asc := font.get_ascent(s)
			var dsc := font.get_descent(s)
			c.draw_string(font, Vector2((sz.x - wdt) * 0.5, (sz.y + asc - dsc) * 0.5), t, HORIZONTAL_ALIGNMENT_LEFT, -1, s, wht)
	for i in CB.SERIALS.size():
		put.call("ser%d" % i, Vector2i(512, 128), text_cell.call(_font_wide, CB.SERIALS[i], Vector2i(512, 128), 96))
	var jps := ["全開", "流束", "反重力", "第一", "起動", "信号", "機体"]
	for i in jps.size():
		var t: String = jps[i]
		put.call("jp%d" % i, Vector2i(128, 400), func(c: MotionCanvas, sz: Vector2) -> void:
			var n := t.length()
			var fs := int(minf(104.0, (sz.y - 16.0) / n / 1.05))
			for k in n:
				var y := 8.0 + (k + 0.82) * fs * 1.05 + (sz.y - 16.0 - n * fs * 1.05) * 0.5
				c.draw_string(_font_jp, Vector2(0, y), t[k], HORIZONTAL_ALIGNMENT_CENTER, sz.x, fs, wht))
	put.call("exit", Vector2i(512, 128), func(c: MotionCanvas, sz: Vector2) -> void:
		c.draw_string(_font_mono, Vector2(14, 92), "EXIT", HORIZONTAL_ALIGNMENT_LEFT, -1, 92, wht)
		var a := Vector2(300, 64)
		var s := 150.0
		c.draw_colored_polygon(PackedVector2Array([a + Vector2(0, -s * 0.13), a + Vector2(s * 0.55, -s * 0.13), a + Vector2(s * 0.55, -s * 0.36),
			a + Vector2(s, 0), a + Vector2(s * 0.55, s * 0.36), a + Vector2(s * 0.55, s * 0.13), a + Vector2(0, s * 0.13)]), wht))
	put.call("hazard", Vector2i(512, 48), func(c: MotionCanvas, sz: Vector2) -> void:
		var x := -48.0
		while x < sz.x:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, sz.y), Vector2(x + 22, sz.y), Vector2(x + 50, 0), Vector2(x + 28, 0)]), wht)
			x += 44.0)
	put.call("chev_v", Vector2i(128, 400), func(c: MotionCanvas, sz: Vector2) -> void:
		for k in 5:
			var y := 30.0 + k * 74.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(10, y + 50), Vector2(64, y), Vector2(118, y + 50), Vector2(118, y + 76),
				Vector2(64, y + 26), Vector2(10, y + 76)]), wht))
	put.call("chev_h", Vector2i(512, 128), func(c: MotionCanvas, sz: Vector2) -> void:
		for k in 5:
			var x := 16.0 + k * 96.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, 10), Vector2(x + 30, 10), Vector2(x + 76, 64), Vector2(x + 30, 118),
				Vector2(x, 118), Vector2(x + 46, 64)]), wht))
	put.call("chev_up", Vector2i(256, 256), func(c: MotionCanvas, sz: Vector2) -> void:
		for k in 2:
			var y := 40.0 + k * 96.0
			c.draw_colored_polygon(PackedVector2Array([Vector2(16, y + 90), Vector2(128, y), Vector2(240, y + 90), Vector2(240, y + 130),
				Vector2(128, y + 40), Vector2(16, y + 130)]), wht))
	for i in range(1, 7):
		put.call("num%d" % i, Vector2i(256, 192), text_cell.call(_font_wide, "%02d" % i, Vector2i(256, 192), 150))
	put.call("circle", Vector2i(256, 256), func(c: MotionCanvas, sz: Vector2) -> void:
		c.draw_arc(sz * 0.5, 112, 0, TAU, 64, wht, 18, true)
		c.draw_circle(sz * 0.5, 54, wht))
	put.call("helipad", Vector2i(256, 256), func(c: MotionCanvas, sz: Vector2) -> void:
		c.draw_arc(sz * 0.5, 116, 0, TAU, 64, wht, 10, true)
		c.draw_rect(Rect2(78, 64, 28, 128), wht)
		c.draw_rect(Rect2(150, 64, 28, 128), wht)
		c.draw_rect(Rect2(78, 114, 100, 28), wht))
	put.call("barcode", Vector2i(256, 128), func(c: MotionCanvas, sz: Vector2) -> void:
		var x := 8.0
		var k := 0
		while x < sz.x - 12.0:
			var bw := 4.0 + 10.0 * MK.rand(k * 3.1 + 2.0)
			c.draw_rect(Rect2(x, 8, bw, sz.y - 16), wht)
			x += bw + 4.0 + 8.0 * MK.rand(k * 1.7 + 9.0)
			k += 1)
	put.call("solid", Vector2i(256, 32), func(c: MotionCanvas, sz: Vector2) -> void: c.draw_rect(Rect2(Vector2.ZERO, sz), wht))
	put.call("dash", Vector2i(32, 256), func(c: MotionCanvas, sz: Vector2) -> void: c.draw_rect(Rect2(Vector2.ZERO, sz), wht))
	put.call("vent", Vector2i(128, 128), func(c: MotionCanvas, sz: Vector2) -> void:
		for k in 5:
			c.draw_rect(Rect2(8, 8 + k * 24, 112, 12), wht))
	put.call("hatch_h", Vector2i(256, 64), func(c: MotionCanvas, sz: Vector2) -> void:
		for k in 8:
			c.draw_rect(Rect2(6 + k * 32, 4, 18, 56), wht))
	put.call("hatch_d", Vector2i(512, 64), func(c: MotionCanvas, sz: Vector2) -> void:
		var x := -64.0
		while x < sz.x:
			c.draw_colored_polygon(PackedVector2Array([Vector2(x, sz.y), Vector2(x + 26, sz.y), Vector2(x + 90, 0), Vector2(x + 64, 0)]), wht)
			x += 52.0)
	put.call("plaza1", Vector2i(1024, 96), text_cell.call(_font_mono, "PLAZA 01 // EXIT >>", Vector2i(1024, 96), 76))
	put.call("mhline", Vector2i(1024, 80), text_cell.call(_font_mono, "MINIMAL HUMANS // FOSS STUDIO // BERLIN", Vector2i(1024, 80), 60))
	put.call("mhjp", Vector2i(768, 96), text_cell.call(_font_jp, "ミニマル・ヒューマンズ", Vector2i(768, 96), 76))
	put.call("league", Vector2i(1024, 80), text_cell.call(_font_mono, "F-9000 // ANTI-GRAVITY LEAGUE", Vector2i(1024, 80), 60))
	put.call("ftfjp", Vector2i(1024, 96), text_cell.call(_font_jp, "フルスロットル・フラックス", Vector2i(1024, 96), 76))


func _build_city() -> void:
	var cb: Variant = _cb
	cb.set_route([[Vector2(-5, -52), Vector2(-5, -8)], [Vector2(8, -5), Vector2(15, -5)], [Vector2(15, -5), Vector2(15, 10)]])
	cb.build_city()
	# street furniture on the route, placed where the camera is on each beat
	for i in WALKS.size():
		var g := _grid_at(s_at(WALKS[i]))
		var ns: bool = WALKS[i] < 100.0 or WALKS[i] > CORNER
		cb.walkway(-5.0 if WALKS[i] < 100.0 else (15.0 if ns else g.x), g.y if ns else -5.0, ns, 1.05 + 0.25 * MK.rand(i * 3.3),
			["red", "cream", "black", "cream", "red"][i])
	for i in PIPES.size():
		var g := _grid_at(s_at(PIPES[i]))
		var ns: bool = PIPES[i] < 100.0
		cb.pipe_rack(-5.0 if ns else g.x, g.y if ns else -5.0, ns, 0.98 + 0.12 * MK.rand(i * 7.1))
	for sp in [[-44.0, -31.0, 1.0, 0.53, 0.05, "red"], [-28.0, -12.0, 1.0, 0.53, 0.05, "red"], [-41.0, -19.0, 1.65, -0.53, 0.05, "cream"]]:
		cb.wall_pipe(Vector2(-5, sp[0]), Vector2(-5, sp[1]), sp[2], sp[3], sp[4], sp[5])
	cb.wall_pipe(Vector2(8.5, -5), Vector2(13.5, -5), 1.15, -0.53, 0.05, "cream")
	cb.wall_pipe(Vector2(15, -3), Vector2(15, 8), 1.05, 0.53, 0.05, "red")
	cb.wall_pipe(Vector2(15, -2), Vector2(15, 6), 1.6, -0.53, 0.05, "grey")
	for bl in [[-38.0, 1.0, "red", "jp0"], [-29.0, -1.0, "black", "jp3"], [-21.0, 1.0, "cream", "jp2"], [-13.0, -1.0, "red", "jp5"]]:
		cb.blade(-5.0, bl[0], true, bl[1], 1.15, bl[2], bl[3])
	cb.blade(15.0, -0.5, true, -1.0, 1.1, "black", "jp1")
	cb.blade(15.0, 5.5, true, 1.0, 1.15, "red", "jp6")
	# MH plaza: billboard wall behind the monument, plinth, ground markings
	var bk := CB.key_of(0, 1.45)
	var bp := Vector3(-4.7, 0, -1.6)
	var bsz := Vector3(9.4, 3.0, 0.3)
	cb.box("black", bp, bsz, bk)
	cb.face_decal("solid", bp, bsz, 0, 0.5, 2.92, 9.4, bk, RED)
	cb.face_decal("mhline", bp, bsz, 0, 0.27, 2.62, 4.2, bk, CREAM)
	cb.face_decal("mhjp", bp, bsz, 0, 0.82, 2.62, 2.4, bk, RED)
	cb.face_decal("chev_h", bp, bsz, 0, 0.93, 0.3, 0.9, bk, RED)
	cb.face_decal("hazard", bp, bsz, 0, 0.5, 0.06, 9.4, bk, RED)
	var pk := CB.key_of(0, 0)
	cb.box("black", Vector3(-4.0, 0, -1.3), Vector3(8.0, PED, 2.2), pk)
	for k in 11:
		cb.flat_decal("hatch_d", CB.w(-4.0 + k * 0.8, -2.2, 0.006), 0.8, Vector2(1e4, 1e4), INK, 0.0, true)
	cb.flat_decal("plaza1", CB.w(-3.6, -7.3, 0.006), 3.2, Vector2(1e4, 1e4), RED, 0.0, true)
	for k in 3:
		cb.flat_decal("chev_up", CB.w(-5.0, -7.6 + k * 0.9, 0.006), 0.7, Vector2(1e4, 1e4), RED, -PI * 0.25, true)
	# FTF plaza: the hatch slot is part of the slab rig; markings on its floor panel

	var mats := {}
	for m in CB.MATS.keys():
		var t: Array = CB.MATS[m]
		mats[m] = _flat.material(t[0], t[1], t[2])
	for m in cb.st.keys():
		_stage.world.add_child(MotionFlat3D.instance((cb.st[m] as SurfaceTool).commit(), mats[m]))
	var gmat := _flat.material(CB.GROUND, CB.GROUND, CB.GROUND, CB.GROUND, 0.0, false)
	_stage.world.add_child(MotionFlat3D.instance((cb.ground as SurfaceTool).commit(), gmat))
	_stage.world.add_child(MotionFlat3D.instance((cb.edges as MotionEdges3D).commit(), _flat.edges(INK, 1.7)))
	_stage.world.add_child(MotionFlat3D.instance((cb.decals as SurfaceTool).commit(), _flat.decals(_atlas.texture)))
	_stage.world.add_child(MotionFlat3D.instance((cb.ground_decals as SurfaceTool).commit(), _flat.decals(_atlas.texture, false)))
	_ink_fixed = _flat.register(MotionEdges3D.material(INK, 1.7), false)


## A node holding a mesh with the fixed white-tone material and its outline.
func _logo_node(parent: Node3D, mesh: ArrayMesh) -> Node3D:
	var n := Node3D.new()
	parent.add_child(n)
	var mat := _flat.material(Color.WHITE, Color.WHITE, Color.WHITE, Color.WHITE, 0.0, false, true)
	n.add_child(MotionFlat3D.instance(mesh, mat))
	n.add_child(MotionFlat3D.instance(MotionEdges3D.from_mesh(mesh, {crease_deg = 40.0}), _ink_fixed))
	return n


func _build_monument() -> void:
	var mh: MotionSvgData = load("res://demo/assets/logos/mh_logoFull_standard.svg")
	var root := Node3D.new()
	root.position = Vector3(0, PED, 0.25)
	_stage.world.add_child(root)
	for i in 3:
		var mesh := MotionSvgMesh.build(mh, MH_W, {depth = 0.16, anchor = Vector2(0.5, 1.0), only = [i], side_shade = 0.4,
			part_fn = func(_p: int) -> Dictionary: return {z = 0.0}})
		_mh_layers.append(_logo_node(root, mesh))
	var letters := MotionSvgMesh.build(mh, MH_W, {depth = 0.26, anchor = Vector2(0.5, 1.0), only = range(3, 16), side_shade = 0.45,
		part_fn = func(_p: int) -> Dictionary: return {z = 0.0, color = Color("#fbf7ef")}})
	_mh_letters = _logo_node(root, letters)
	# PRESENTS on the plinth's front face
	_presents = MotionPanel3D.new()
	_presents.pixel_size = Vector2i(2048, 112)
	_presents.world_size = Vector2(7.6, 7.6 * 112.0 / 2048.0)
	_presents.background = Color(0, 0, 0, 0)
	_presents.position = Vector3(0, PED * 0.5, 0.9 + 0.006)
	_stage.world.add_child(_presents)
	var pc := MotionCanvas.new()
	pc.draw_fn = _draw_presents
	_presents.canvas.add_child(pc)


func _draw_presents(c: MotionCanvas, f: float) -> void:
	var s := MK.map(f, [STAMP, STAMP + 3.0], [0, 1], MK.ease_out)
	if s > 0.0:
		var a := minf(1.0, s * 2.0)
		var r := Rect2(520, 6, 1008, 100)
		var k := lerpf(1.3, 1.0, s)
		c.draw_rect(Rect2(r.get_center() - r.size * 0.5 * k, r.size * k), Color(RED, a))
		var t := "PRESENTS"
		var fs := 76
		var wd := _font_wide.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		c.draw_string(_font_wide, Vector2(1024 - wd * 0.5, 88), t, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(CREAM, a))
	var j := MK.map(f, [STAMP_JP, STAMP_JP + 3.0], [0, 1], MK.ease_out)
	if j > 0.0:
		c.draw_string(_font_jp, Vector2(1560, 80), "提供", HORIZONTAL_ALIGNMENT_LEFT, -1, 60, Color(RED, j))
		c.draw_string(_font_mono, Vector2(80, 76), "MH//01 // 112.5", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, Color(CREAM, j))


func _ftf_basis() -> Basis:
	return Basis(Vector3.UP, deg_to_rad(ISO_YAW)) * Basis(Vector3.RIGHT, -deg_to_rad(LEAN))


func _build_slab() -> void:
	var logo: MotionSvgData = load(FTFKit.LOGO)
	_slab_h = FTF_W * logo.view_box.size.y / logo.view_box.size.x
	var proud: Array = FTFKit.WORD + FTFKit.FLUX_TOP + FTFKit.FLUX_BOT + [FTFKit.FLUX_BOWL, FTFKit.TAB] + FTFKit.SMALL + FTFKit.CHECKS
	var mesh := MotionSvgMesh.build(logo, FTF_W, {depth = 0.5, anchor = Vector2(0.5, 1.0), side_shade = 0.42,
		part_fn = func(i: int) -> Dictionary:
			if i == FTFKit.PLATE:
				return {depth = 0.5, z = 0.0, color = Color("#f6f3ec")}
			if i == FTFKit.RIM:
				return {depth = 0.7, z = -0.1}
			if proud.has(i):
				return {depth = 0.18, z = 0.5 + i * 0.004}
			return {}})
	var base := Node3D.new()
	base.position = CB.w(FTF_C.x, FTF_C.y)
	base.basis = _ftf_basis()
	_stage.world.add_child(base)
	_slab = _logo_node(base, mesh)
	# the hatch: a black slot with two doors sliding apart along the slab normal
	_hatch = Node3D.new()
	_hatch.position = CB.w(FTF_C.x, FTF_C.y)
	_hatch.basis = Basis(Vector3.UP, deg_to_rad(ISO_YAW))
	_stage.world.add_child(_hatch)
	var black := _flat.material(Color("#2c2c31"), Color("#1d1d21"), Color("#101012"), Color(0, 0, 0, 0), 0.0, false)
	var slot := MotionFlat3D.begin()
	var hw := FTF_W * 0.5 + 0.5
	MotionFlat3D.quad(slot, Vector3(-hw, 0.01, 0.8), Vector3(hw, 0.01, 0.8), Vector3(hw, 0.01, -0.8), Vector3(-hw, 0.01, -0.8), Vector3.UP, Vector2.ZERO, Color(0.35, 0.35, 0.35))
	_hatch.add_child(MotionFlat3D.instance(slot.commit(), black))
	var dmat := _flat.material(Color("#4b4b51"), Color("#2c2c31"), Color("#141417"), Color(0, 0, 0, 0), 0.0, false)
	var dec := _flat.decals(_atlas.texture, false)
	for sgn in [-1.0, 1.0]:
		var door := Node3D.new()
		_hatch.add_child(door)
		var st := MotionFlat3D.begin()
		var e := MotionEdges3D.new()
		var z0 := 0.0 if sgn > 0.0 else -0.82
		MotionFlat3D.box(st, Vector3(-hw, 0.012, z0), Vector3(hw * 2.0, 0.06, 0.82), Vector2.ZERO, Color.WHITE, e)
		door.add_child(MotionFlat3D.instance(st.commit(), dmat))
		door.add_child(MotionFlat3D.instance(e.commit(), _ink_fixed))
		var ds := MotionFlat3D.begin()
		var cbv: Variant = _cb
		var hz: Rect2 = cbv.uv["hazard"]
		var n := 6
		for k in n:
			var cx := -hw + (k + 0.5) * hw * 2.0 / n
			MotionFlat3D.decal(ds, Vector3(cx, 0.085, z0 + 0.41), Vector3(hw / n - 0.04, 0, 0), Vector3(0, 0, -0.09), hz, Vector2.ZERO, RED)
		door.add_child(MotionFlat3D.instance(ds.commit(), dec))
		door.set_meta("sgn", sgn)
		_doors.append(door)
	# the plaza floor: an animated panel (chevrons chasing towards the logo)
	_floor = MotionPanel3D.new()
	_floor.pixel_size = Vector2i(1024, 1024)
	_floor.world_size = Vector2(8.8, 8.8)
	_floor.background = Color(0, 0, 0, 0)
	_floor.position = CB.w(FTF_C.x, FTF_C.y, 0.008)
	_floor.basis = Basis(Vector3.UP, deg_to_rad(ISO_YAW)) * Basis(Vector3.RIGHT, -PI * 0.5)
	_stage.world.add_child(_floor)
	var fc := MotionCanvas.new()
	fc.draw_fn = _draw_floor
	_floor.canvas.add_child(fc)


## The FTF plaza floor (panel pixels: 1024 = 8.8 units; +x along the slab, -y towards the camera side is +y).
func _draw_floor(c: MotionCanvas, f: float) -> void:
	var on := MK.map(f, [HATCH - 8.0, HATCH + 8.0], [0, 1], MK.ease_out) * (1.0 - MK.map(f, [CUT - 2.0, CUT + 4.0], [0, 1], MK.linear))
	if on <= 0.0:
		return
	var px := 1024.0 / 8.8
	# border hatch
	var y0 := 512.0 + 1.6 * px
	var x := 40.0
	while x < 984.0 * on:
		c.draw_colored_polygon(PackedVector2Array([Vector2(x, y0), Vector2(x + 18, y0), Vector2(x + 42, y0 + 30), Vector2(x + 24, y0 + 30)]), Color(INK, 0.85))
		x += 40.0
	# chevron runway pointing at the slab (from the camera side), chasing on beats
	var hold := f >= DROP - 4.0 and f < SINK + 16.0
	for k in 5:
		var y := 512.0 + 2.4 * px + k * 62.0
		var lit := hold and int(floorf((f - DROP) / 4.0)) % 5 == 4 - k
		var col := RED if lit or not hold else Color(INK, 0.9)
		if k > int(5.0 * on):
			break
		c.draw_colored_polygon(PackedVector2Array([Vector2(452, y + 34), Vector2(512, y), Vector2(572, y + 34), Vector2(572, y + 52),
			Vector2(512, y + 18), Vector2(452, y + 52)]), col)
	c.draw_string(_font_mono, Vector2(60, 980), "PLAZA 02 // F-9000 // GRID 01", HORIZONTAL_ALIGNMENT_LEFT, -1, 30, Color(INK, on))
	c.draw_string(_font_jp, Vector2(700, 984), "反重力レース", HORIZONTAL_ALIGNMENT_LEFT, -1, 34, Color(RED, on))


func _build_cranes() -> void:
	var cb: Variant = _cb
	var mats := {}
	for m in ["red", "cream", "black"]:
		var t: Array = CB.MATS[m]
		mats[m] = _flat.material(t[0], t[1], t[2])
	var ink := _flat.edges(INK, 1.4)
	for spec in cb.cranes:
		var pos: Vector3 = spec.pos
		var k: Vector2 = spec.key
		var ln: float = spec.len
		var root := Node3D.new()
		root.position = pos
		_stage.world.add_child(root)
		var parts := {"red": MotionFlat3D.begin(), "cream": MotionFlat3D.begin(), "black": MotionFlat3D.begin()}
		var e := MotionEdges3D.new()
		var mast := 1.1
		MotionFlat3D.box(parts.red, Vector3(-0.06, 0, -0.06), Vector3(0.12, mast, 0.12), k, Color.WHITE, e)
		for m in parts.keys():
			root.add_child(MotionFlat3D.instance((parts[m] as SurfaceTool).commit(), mats[m]))
		root.add_child(MotionFlat3D.instance(e.commit(), ink))
		var jib := Node3D.new()
		jib.position = Vector3(0, mast, 0)
		root.add_child(jib)
		var jp := {"red": MotionFlat3D.begin(), "cream": MotionFlat3D.begin(), "black": MotionFlat3D.begin()}
		var je := MotionEdges3D.new()
		MotionFlat3D.box(jp.cream, Vector3(-0.5, 0.0, -0.045), Vector3(ln + 0.5, 0.09, 0.09), k, Color.WHITE, je)
		MotionFlat3D.box(jp.black, Vector3(-0.62, -0.16, -0.08), Vector3(0.22, 0.16, 0.16), k, Color.WHITE, je)
		MotionFlat3D.box(jp.red, Vector3(-0.08, -0.12, -0.08), Vector3(0.16, 0.12, 0.16), k, Color.WHITE, je)
		MotionFlat3D.box(jp.red, Vector3(-0.03, 0.09, -0.03), Vector3(0.06, 0.32, 0.06), k, Color.WHITE, je)
		var hook := ln * 0.72
		MotionFlat3D.box(jp.black, Vector3(hook - 0.006, -0.62, -0.006), Vector3(0.012, 0.62, 0.012), k, Color.WHITE, null)
		MotionFlat3D.box(jp.red, Vector3(hook - 0.05, -0.72, -0.05), Vector3(0.1, 0.1, 0.1), k, Color.WHITE, je)
		for m in jp.keys():
			jib.add_child(MotionFlat3D.instance((jp[m] as SurfaceTool).commit(), mats[m]))
		jib.add_child(MotionFlat3D.instance(je.commit(), ink))
		jib.set_meta("seed", spec.seed)
		_cranes.append(jib)


func _build_pods() -> void:
	var cols := [["red", CB.MATS.red], ["cream", CB.MATS.cream]]
	var meshes := []
	for cpair in cols:
		var t: Array = cpair[1]
		var m := _flat.material(t[0], t[1], t[2], Color(0, 0, 0, 0), 0.0, false)
		var st := MotionFlat3D.begin()
		var e := MotionEdges3D.new()
		MotionFlat3D.box(st, Vector3(-0.07, 0.03, -0.17), Vector3(0.14, 0.09, 0.34), Vector2.ZERO, Color.WHITE, e)
		MotionFlat3D.box(st, Vector3(-0.05, 0.12, -0.06), Vector3(0.1, 0.05, 0.14), Vector2.ZERO, Color(0.25, 0.25, 0.27), e)
		meshes.append([st.commit(), m, e.commit()])
	# traffic lanes around the FTF plaza: [ns, line, from, to]
	var lanes := [[true, 15.0, -2.0, 30.0], [true, 5.0, 2.0, 30.0], [true, 20.0, 0.0, 30.0], [true, 0.0, 0.0, 28.0],
		[false, 10.0, -4.0, 26.0], [false, 20.0, -4.0, 26.0], [false, 5.0, -4.0, 26.0], [false, 25.0, -2.0, 26.0]]
	var n := 0
	for li in lanes.size():
		var ln: Array = lanes[li]
		for q in 5:
			var dir := 1.0 if (q + li) % 2 == 0 else -1.0
			_pod_specs.append({ns = ln[0], line = ln[1], a = ln[2], b = ln[3], dir = dir, side = 0.22 * dir,
				speed = 0.1 + 0.12 * MK.rand(n * 3.7 + 1.0), phase = MK.rand(n * 5.3 + 2.0), canyon = false})
			n += 1
	# oncoming pods in the first canyon, passing the camera on PODS
	for i in PODS.size():
		_pod_specs.append({canyon = true, at = PODS[i], s = s_at(PODS[i]), side = [0.27, -0.25][i], speed = 0.42})
	for i in _pod_specs.size():
		var mm: Array = meshes[i % 2]
		var pod := Node3D.new()
		pod.add_child(MotionFlat3D.instance(mm[0], mm[1]))
		pod.add_child(MotionFlat3D.instance(mm[2], _ink_fixed))
		_stage.world.add_child(pod)
		_pods.append(pod)


## Sound: the Audio Kit's bridge when it is linked, else the committed bake.
func _add_sound() -> void:
	if Engine.is_editor_hint():
		return
	const BRIDGE := "res://addons/audio_kit/bridge_motion/cue_bridge.gd"
	const MAP := "res://demo/ftf/ftf_canyon/audio/canyon_map.tres"
	const SONG := "res://demo/ftf/ftf_canyon/audio/music/canyon_song.tres"
	const TRACK := "res://demo/ftf/ftf_canyon/audio/ftf_canyon_track.res"
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


# ================================================================== camera

func _mh_centre() -> Vector3:
	return Vector3(0, PED + 0.95, 0.3)


func _ftf_target() -> Vector3:
	return CB.w(FTF_C.x, FTF_C.y, 1.15)


func _iso(f: float) -> MotionLens3D:
	var push := MK.map(f, [DROP, SINK + 30.0], [0, 1], MK.ease_in_out)
	var sc := ISO_SCALE * lerpf(1.0, 1.08, push)
	# hold: a slow orthographic track along the slab keeps the frame moving
	var pan := MotionLens3D.extrude_basis(ISO_YAW, ISO_PITCH).x * lerpf(-0.22, 0.22, push)
	var l := MotionLens3D.extrude(ISO_YAW, ISO_PITCH, sc, _ftf_target() + pan, Vector2(960, 560))
	l.offset += MK.shakes(f, [DROP], 20, 12) + MK.shakes(f, [SHUT], 6, 6)
	l.keep = 60.0
	return l


func _lens(f: float) -> MotionLens3D:
	var s := s_at(f)
	var spd := s_at(f + 0.5) - s_at(f - 0.5)
	var fr := MotionStage3D.path_frame(_curve, s)
	var pos := fr.origin
	var up := fr.basis.y
	# rumble with speed
	var rum := 0.012 * minf(spd, 0.7)
	pos += fr.basis * Vector3(sin(f * 2.3) * 0.6 + sin(f * 5.9) * 0.4, sin(f * 3.1) * 0.5 + sin(f * 7.7) * 0.5, 0.0) * rum
	# lift out of the canyon
	var lift := MK.map(f, [LIFT, LIFT + 44.0], [0, 1], MK.ease_in_out)
	pos.y += 5.2 * lift
	var ahead := MotionStage3D.path_frame(_curve, s + 5.0).origin + Vector3(0, 0.12, 0)
	var w_mh := MK.map(f, [48.0, 70.0], [0, 1], MK.ease_in_out) * (1.0 - MK.map(f, [136.0, 158.0], [0, 1], MK.ease_in_out))
	var look := ahead.lerp(_mh_centre(), w_mh)
	look = look.lerp(_ftf_target(), lift)
	var fov := 60.0 + 14.0 * clampf(spd / 0.6, 0.0, 1.0)
	var fly := MotionLens3D.look(pos, look, fov, up.lerp(Vector3.UP, lift).normalized())
	fly.keep = 60.0
	fly.ortho_at = 20000.0
	var tp := MK.map(f, [POSE[0], POSE[1]], [0, 1], MK.ease_in_out)
	var tl := MK.map(f, [FLATTEN[0], FLATTEN[1]], [0, 1], MK.ease_in_out)
	if tp <= 0.0 and tl <= 0.0:
		return fly
	return fly.mix(_iso(f), tp, tl)


# ================================================================== frame

func _frame(f: float) -> void:
	if not _built:
		return
	var lens := _lens(f)
	lens.near_min = 0.12
	lens.apply(_stage.camera)
	var tl := MK.map(f, [FLATTEN[0], FLATTEN[1]], [0, 1], MK.ease_in_out)
	_flat.fog_for(lens, PAPER, 3.0, 30.0, 1.0 - tl)

	# ---- city: pulses on every beat in the hold, sinks in rings at the end
	var key := CB.key_of(FTF_C.x, FTF_C.y)
	if f >= DROP and f < SINK + 24.0:
		var beat := floorf((f - DROP) / BEAT)
		var amp := 0.34 if beat == 0.0 else 0.13
		_flat.pulse(key, f - (DROP + beat * BEAT), amp, 1.3, 0.24, 17.0)
	else:
		_flat.pulse(key, 1e4, 0.0)
	_flat.sink(key, f - SINK, 2.0, 1.6, 9.0, 7.0)
	var cut := MK.map(f, [CUT, CUT + 10.0], [0, 1], MK.ease_in_quad)
	_flat.energy = 1.0 - cut
	_flat.apply()
	_stage.environment.background_color = PAPER * (1.0 - cut)
	_stage.environment.background_color.a = 1.0

	# ---- monument: M layers telescope on UNFOLD, letters push out
	var unfold := MK.spring(f, UNFOLD, 13, 210)
	var breathe := 0.04 * sin((f - UNFOLD) * TAU / 64.0) * MK.map(f, [UNFOLD + 8.0, UNFOLD + 24.0], [0, 1])
	for i in 3:
		_mh_layers[i].position.z = -(2 - i) * (0.03 + MH_GAP * unfold + breathe)
	_mh_letters.scale = Vector3(1, 1, lerpf(0.08, 1.0, clampf(unfold, 0.0, 1.2)))
	var mh_on := f < LIFT + 40.0
	_mh_letters.get_parent().visible = mh_on
	_presents.visible = mh_on

	# ---- hatch and slab
	var open := MK.map(f, [HATCH, HATCH + 8.0], [0, 1], MK.ease_out_back) * (1.0 - MK.map(f, [SHUT - 4.0, SHUT], [0, 1], MK.ease_in_quad))
	for d in _doors:
		var sgn: float = d.get_meta("sgn")
		d.position.z = sgn * 0.86 * open
	_hatch.visible = f >= HATCH - 40.0
	var up := MK.map(f, [RISE, DROP], [0, 1], MK.bezier(0.4, 0.0, 0.85, 0.75))
	var down := MK.map(f, [FTF_SINK, FTF_SINK + 8.0], [0, 1], MK.ease_in_quad)
	var lock := 0.0
	if f >= DROP:
		lock = 0.16 * exp(-(f - DROP) * 0.28) * sin((f - DROP) * 0.75)
	var h := -(_slab_h + 0.4) * (1.0 - up + down) + 0.04 + lock
	_slab.position = Vector3(0, h, 0)
	_slab.visible = f >= RISE - 1.0 and f < FTF_SINK + 14.0
	_floor.visible = f >= HATCH - 10.0 and f < CUT + 6.0

	# ---- cranes: slow swing, a turn on their beats
	for i in _cranes.size():
		var jib := _cranes[i]
		var sd: float = jib.get_meta("seed")
		var turn := 0.0
		for c in CRANES.size():
			turn += 1.1 * MK.map(f, [CRANES[c] + (i % 3) * 4.0, CRANES[c] + (i % 3) * 4.0 + 20.0], [0, 1], MK.ease_in_out) * (1.0 if i % 2 == 0 else -1.0)
		jib.rotation.y = MK.rand(sd) * TAU + 0.4 * sin(f * TAU / 160.0 + sd) + turn

	# ---- traffic
	for i in _pods.size():
		_place_pod(i, f)

	# ---- shutters
	var open_k := MK.map(f, [1.0, 13.0], [0, 1], MK.ease_out)
	var close_k := MK.map(f, [CUT + 2.0, BLACK], [0, 1], MK.ease_in_quad)
	var hh := 540.0 * (1.0 - open_k + close_k)
	hh = clampf(hh, 0.0, 541.0)
	_shut_top.size = Vector2(1920, hh)
	_shut_top.position = Vector2.ZERO
	_shut_bot.size = Vector2(1920, hh)
	_shut_bot.position = Vector2(0, 1080 - hh)
	_shut_top.visible = hh > 0.0
	_shut_bot.visible = hh > 0.0


func _place_pod(i: int, f: float) -> void:
	var sp: Dictionary = _pod_specs[i]
	var pod := _pods[i]
	if sp.canyon:
		var at: float = sp.at
		var s: float = sp.s - (f - at) * (sp.speed as float)
		var on := f > at - 60.0 and f < at + 12.0
		pod.visible = on
		if on:
			var fr := MotionStage3D.path_frame(_curve, s, 0.0, sp.side)
			pod.position = Vector3(fr.origin.x, 0.14 + 0.02 * sin(f * 0.9 + at), fr.origin.z)
			pod.basis = Basis(Vector3.UP, atan2(fr.basis.z.x, fr.basis.z.z))
		return
	var a: float = sp.a
	var b: float = sp.b
	var t := fposmod((sp.phase as float) + (sp.speed as float) * f / (b - a), 1.0)
	if (sp.dir as float) < 0.0:
		t = 1.0 - t
	var along := lerpf(a, b, t)
	var line: float = sp.line
	var side: float = sp.side
	var g := Vector2(line + side, along) if sp.ns else Vector2(along, line - side)
	var y := _flat.offset(CB.key_of(g.x, g.y)) + 0.0
	pod.visible = y > -0.25 and f < CUT + 4.0
	pod.position = CB.w(g.x, g.y, 0.0 + minf(0.0, y))
	pod.basis = Basis(Vector3.UP, (0.0 if (sp.dir as float) > 0.0 else PI) + (0.0 if sp.ns else PI * 0.5))
