# SPDX-License-Identifier: Apache-2.0
## One cable: a thick, glossy, shaded tube along a route of pinned waypoints,
## with sag, decaying wobble after tugs, coloured jacket bands, travelling light
## pulses and a connector at its head. A pure description: set its properties
## from the frame, and a MotionCableSet draws it (with others, in depth order).
##
##   var c := MotionCable.new()
##   c.points = PackedVector2Array([Vector2(-100, 900), Vector2(500, 760), port - Vector2(80, 0)])
##   c.width = 30; c.jacket = PINK; c.plug_head = MotionCable.Plug.JACK
##   # in _frame(f):
##   c.reveal = MK.map(f, [0, 20], [0, 1], MK.ease_in_out)     # snake in along the route
##   c.tension = MK.spring(f, 20, 9, 160)                     # slack, then pulled taut
##   c.tugs = [MotionCable.tug(20, 30)]                        # twang when it lands
##
## Geometry: the route is a centripetal Catmull-Rom curve through `points`. Each span between
## two waypoints sags along `gravity` by `sag * (1 - tension)` (scaled by the span's
## length) with a parabolic profile, and wobbles across its chord from `tugs`, each
## a damped sine that starts on its frame. Waypoints stay pinned, so a cable can be
## held at ports, hooks and clips while the spans between them swing.
##
## `start` and `reveal` (0..1 of the route's length) set which part is drawn: grow
## `reveal` to snake a cable in head first, shrink it to pull it back out the way it
## came; the head connector rides the `reveal` end. Pass the same `frame` the cable
## is drawn at (`MotionCableSet` does) so tugs know the time.
@tool
class_name MotionCable
extends RefCounted

enum Plug { NONE, JACK, MULTIPIN, BLADE, BARREL }

## Route waypoints in pixels (at least two). The curve passes through every one.
var points := PackedVector2Array()
## Curve samples per span between waypoints.
var samples := 18
## Tube diameter in pixels.
var width := 28.0
## Jacket colour: the tube's lit body.
var jacket := Color("#e92067")
## Colour of the tube's shaded edges; empty (alpha 0) derives it from the jacket.
var edge := Color(0, 0, 0, 0)
## Specular strength 0..1 (0 = matte rubber, 1 = wet gloss).
var gloss := 0.8
## Where the light comes from (screen direction, towards the light).
var light := Vector2(-0.55, -0.83)
## 0 = slack (full sag), 1 = taut (straight spans).
var tension := 1.0
## Sag in pixels of a slack span `sag_ref` pixels long; longer spans sag more.
var sag := 140.0
var sag_ref := 600.0
var gravity := Vector2(0, 1)
## false: the whole route hangs as one span between its two ends (the waypoints
## shape it but don't hold it up); true: every waypoint is a pin (a hook or clip)
## and each span between them sags and wobbles on its own.
var pinned := false
## Tugs: [{at, amp, period, decay}] (frames, pixels, frames per swing, frames to 1/e).
## Build them with MotionCable.tug().
var tugs: Array = []
## Drawn part of the route, 0..1 of its length: from `start` to `reveal`.
var start := 0.0
var reveal := 1.0
## The kit's name for `start` (partial drawing is `reveal_from` .. `reveal`).
var reveal_from: float:
	get: return start
	set(v): start = v
## Coloured bands along the jacket: [{u, len, color}] (u 0..1, len in pixels).
var bands: Array = []
## Repeating stripes: every `stripe_every` px a `stripe_len` px band (0 = off).
var stripe_every := 0.0
var stripe_len := 18.0
var stripe_color := Color(1, 1, 1)
var stripe_phase := 0.0
## Light pulses: [{u, len, color, power}] (u 0..1 of the route, len in pixels).
var pulses: Array = []
## Glow around the tube when powered (0..1) and its colour (alpha 0 = jacket).
var glow := 0.0
var glow_color := Color(0, 0, 0, 0)
## A specular hotspot that slides along the tube (u 0..1, < 0 = off).
var glint := -1.0
## Connector at the head (the `reveal` end) and at the tail (the `start` end).
var plug_head := Plug.NONE
var plug_tail := Plug.NONE
## Connector housing colour (boots, collars); chrome parts are drawn in greys.
var plug_color := Color("#16161a")
## A coloured ID ring on the connector (alpha 0 = jacket colour).
var plug_band := Color(0, 0, 0, 0)
## Lit indicator on the connector (0..1).
var plug_lit := 0.0
var plug_light := Color("#d7ff1f")
## Depth: higher draws on top. `z_ranges` overrides it on parts of the route:
## [[u0, u1, z], ...], so a cable can weave over and under others.
var z := 0.0
var z_ranges: Array = []
## Drop shadow (alpha 0 = none) and its offset.
var shadow := Color(0, 0, 0, 0.5)
var shadow_offset := Vector2(9, 14)
var opacity := 1.0
## Free tag for MotionCableSet filters.
var layer := 0

var _pts := PackedVector2Array()
var _cum := PackedFloat32Array()
var _path := MotionPath.new()
var _key := ""


## A tug on frame `at`: the spans swing `amp` pixels across their chords and settle.
static func tug(at: float, amp := 26.0, period := 9.0, decay := 14.0) -> Dictionary:
	return {at = at, amp = amp, period = period, decay = decay}


## Length of a connector from its rear (where the cable enters) to its front face.
static func plug_length(kind: int, w: float) -> float:
	match kind:
		Plug.JACK:
			return w * 4.6
		Plug.MULTIPIN:
			return w * 3.6
		Plug.BLADE:
			return w * 3.0
		Plug.BARREL:
			return w * 2.8
	return 0.0


## Build the curve for frame `f` (cached while nothing it depends on changes).
func build(f: float) -> void:
	var key := "%s|%s|%s|%s|%s|%s|%s|%s|%s" % [f, points, tension, sag, gravity, tugs, samples, sag_ref, pinned]
	if key == _key:
		return
	_key = key
	_pts = PackedVector2Array()
	var n := points.size()
	if n < 2:
		_cum = PackedFloat32Array()
		_path = MotionPath.new()
		return
	var wob := 0.0
	for t in tugs:
		var dt: float = f - float(t.at)
		if dt >= 0.0:
			wob += float(t.amp) * exp(-dt / maxf(0.001, float(t.decay))) * sin(TAU * dt / maxf(0.001, float(t.period)))
	var g := gravity.normalized()
	# whole-route mode: one envelope over the route's chord length
	var wp_cum := [0.0]
	for i in range(1, n):
		wp_cum.append(float(wp_cum[i - 1]) + points[i].distance_to(points[i - 1]))
	var wp_total := maxf(float(wp_cum[n - 1]), 0.001)
	var whole := points[n - 1] - points[0]
	var g_nrm := Vector2(-whole.y, whole.x).normalized()
	var g_sag := sag * (1.0 - clampf(tension, 0.0, 1.5)) * clampf(wp_total / sag_ref, 0.15, 3.0)
	var g_wob := wob * clampf(wp_total / 600.0, 0.3, 1.6)
	for i in n - 1:
		var p0 := points[i - 1] if i > 0 else points[0] * 2.0 - points[1]
		var p1 := points[i]
		var p2 := points[i + 1]
		var p3 := points[i + 2] if i + 2 < n else points[n - 1] * 2.0 - points[n - 2]
		var chord := p2 - p1
		var clen := chord.length()
		var nrm := Vector2(-chord.y, chord.x) / maxf(clen, 0.001)
		var sg := sag * (1.0 - clampf(tension, 0.0, 1.5)) * clampf(clen / sag_ref, 0.15, 3.0)
		var ph := float(i) * 1.7
		var count := maxi(2, samples)
		for k in count:
			if i < n - 2 and k == count - 1:
				break
			var t := float(k) / float(count - 1)
			var p := _catmull(p0, p1, p2, p3, t)
			if pinned:
				p += g * sg * 4.0 * t * (1.0 - t)
				if wob != 0.0:
					p += nrm * wob * (sin(PI * t) + 0.35 * sin(TAU * t + ph) * sin(PI * t)) * clampf(clen / 400.0, 0.2, 1.5)
			else:
				var u := (float(wp_cum[i]) + t * clen) / wp_total
				p += g * g_sag * 4.0 * u * (1.0 - u)
				if wob != 0.0:
					p += g_nrm * g_wob * (sin(PI * u) + 0.4 * sin(TAU * u) * sin(PI * u))
			_pts.append(p)
	_path = MotionPath.new(_pts)
	_cum = _path.lengths


## Centripetal Catmull-Rom (Barry-Goldman, alpha 0.5): no cusps or loops where
## long and short spans meet, which a thick tube would turn into spikes.
static func _catmull(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, u: float) -> Vector2:
	var t0 := 0.0
	var t1 := t0 + maxf(sqrt(p0.distance_to(p1)), 0.01)
	var t2 := t1 + maxf(sqrt(p1.distance_to(p2)), 0.01)
	var t3 := t2 + maxf(sqrt(p2.distance_to(p3)), 0.01)
	var t := lerpf(t1, t2, u)
	var a1 := p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
	var a2 := p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
	var a3 := p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
	var b1 := a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
	var b2 := a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
	return b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1))


## The built curve (call build first).
func curve() -> PackedVector2Array:
	return _pts


## The built curve as a measured MotionPath (call build first).
func path() -> MotionPath:
	return _path


func length() -> float:
	return _cum[_cum.size() - 1] if _cum.size() > 0 else 0.0


## Point at fraction u (0..1) of the built curve's length.
func point_at(u: float) -> Vector2:
	if _pts.size() < 2:
		return points[0] if points.size() > 0 else Vector2.ZERO
	return _path.point_at(clampf(u, 0.0, 1.0) * length())


## Unit tangent at fraction u (direction of travel from start to end): the
## segment's direction, looking one point further over a degenerate segment.
func tangent_at(u: float) -> Vector2:
	if _pts.size() < 2:
		return Vector2.RIGHT
	var i := _path.index_at(clampf(u, 0.0, 1.0) * length())
	var d := _pts[i + 1] - _pts[i]
	if d.length() < 0.001 and i + 2 < _pts.size():
		d = _pts[i + 2] - _pts[i]
	return d.normalized()


## The part of the built curve between fractions a and b, with near-duplicate
## points dropped (MotionPath.sub_clean).
func sub(a: float, b: float) -> PackedVector2Array:
	if _pts.size() < 2:
		return PackedVector2Array()
	var total := length()
	return _path.sub_clean(clampf(a, 0.0, 1.0) * total, clampf(b, 0.0, 1.0) * total)


## Depth at fraction u.
func z_at(u: float) -> float:
	for r in z_ranges:
		if u >= float(r[0]) and u <= float(r[1]):
			return float(r[2])
	return z


## Pieces of the drawn part with their depths: [[u0, u1, z], ...].
func pieces() -> Array:
	var a := clampf(start, 0.0, 1.0)
	var b := clampf(reveal, 0.0, 1.0)
	if b <= a:
		return []
	if z_ranges.is_empty():
		return [[a, b, z]]
	var cuts := [a, b]
	for r in z_ranges:
		for v in [float(r[0]), float(r[1])]:
			if v > a and v < b:
				cuts.append(v)
	cuts.sort()
	var out := []
	for i in cuts.size() - 1:
		var u0: float = cuts[i]
		var u1: float = cuts[i + 1]
		if u1 - u0 <= 0.0:
			continue
		out.append([u0, u1, z_at((u0 + u1) * 0.5)])
	return out
