# SPDX-License-Identifier: Apache-2.0
# 2D cutouts: MotionCutoutAtlas (bake, layers, recolour) and
# MotionCutoutRig2D (views, pose, IK, depth, props, look).
extends RefCounted

# A body with a head whose own shapes are split by a child part (eyes), an
# arm chain, and a part hidden for variants.
const SVG := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 200">
  <g id="torso"><circle id="pivot-torso" cx="50" cy="150" r="2" fill="none"/>
    <rect fill="#3f8f5c" x="30" y="90" width="40" height="70"/>
    <path id="scarf" fill="#d8433b" d="M30 90 L70 90 L70 100 L30 100 Z"/>
    <g id="head"><circle id="pivot-head" cx="50" cy="90" r="2" fill="none"/>
      <circle id="face" fill="#f7cfa6" cx="50" cy="60" r="28"/>
      <g id="eyes"><circle id="pivot-eyes" cx="50" cy="60" r="2" fill="none"/>
        <circle class="flat" fill="#1f1a26" cx="60" cy="60" r="4"/></g>
      <path id="hair" fill="#8a3f2a" d="M22 50 C22 30 78 30 78 50 L78 40 L22 40 Z"/>
    </g>
    <g id="arm_upper"><circle id="pivot-arm_upper" cx="50" cy="100" r="2" fill="none"/>
      <rect fill="#3f8f5c" x="45" y="98" width="10" height="30"/>
      <g id="arm_lower"><circle id="pivot-arm_lower" cx="50" cy="126" r="2" fill="none"/>
        <rect fill="#3f8f5c" x="45" y="124" width="10" height="26"/>
        <g id="hand"><circle id="pivot-hand" cx="50" cy="150" r="2" fill="none"/>
          <circle fill="#f7cfa6" cx="50" cy="152" r="6"/></g></g></g>
  </g>
</svg>"""

const CARD := """<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 40">
  <rect fill="#dfe7ef" x="3" y="0" width="4" height="34"/>
</svg>"""

var _keep: Array[Node] = []


func _atlas(opts := {}) -> MotionCutoutAtlas:
	var data := MotionSvgData.from_string(SVG)
	var a := MotionCutoutAtlas.new()
	var o := {origin = Vector2(50, 190)}
	o.merge(opts, true)
	a.add_view(&"side", data, 1.0, o)
	a.add_view(&"side_left", data.mirrored(50), 1.0, o)
	a.add_card(&"stick", MotionSvgData.from_string(CARD), 1.0, Vector2(5, 34))
	a.bake()
	return a


func _rig(a: MotionCutoutAtlas) -> MotionCutoutRig2D:
	var r := MotionCutoutRig2D.new(a)
	r.paper_turn = false
	r.add_view(&"side", &"side", MotionCutoutRig2D.RIGHT)
	r.add_view(&"side_left", &"side_left", MotionCutoutRig2D.LEFT)
	_keep.append(r)
	return r


static func _cd(a: Color, b: Color) -> float:
	return Vector3(a.r - b.r, a.g - b.g, a.b - b.b).length()


func _free() -> void:
	for n in _keep:
		n.free()
	_keep.clear()


# ------------------------------------------------------------------ atlas

func test_atlas_layers_and_regions() -> String:
	var a := _atlas()
	var v: Dictionary = a.views[&"side"]
	# torso, head, eyes, head again (hair after the eyes), arm_upper, arm_lower, hand
	var parts := (v.layers as Array).map(func(L) -> StringName: return L.part)
	if parts != [&"torso", &"head", &"eyes", &"head", &"arm_upper", &"arm_lower", &"hand"]:
		return "layers: %s" % [parts]
	var size := a.texture.get_size()
	var rects := []
	for L in v.layers:
		var r: Rect2 = L.region
		if r.size.x < 1 or r.position.x < 0 or r.end.x > size.x or r.end.y > size.y:
			return "region out of the texture: %s" % r
		for o in rects:
			if (o as Rect2).intersects(r):
				return "regions overlap"
		rects.append(r)
	if not (v.pivot[&"head"] as Vector2).is_equal_approx(Vector2(0, -100)):
		return "head pivot: %s" % v.pivot[&"head"]
	if v.parent[&"eyes"] != &"head" or v.parent[&"head"] != &"torso":
		return "hierarchy"
	return ""


func test_atlas_outline_and_hide() -> String:
	var a := _atlas({hide = ["scarf"], outline = 2.0})
	var img := a.texture.get_image()
	# the torso layer: its top-left outline texel is ink, its centre is the fill
	var L: Dictionary = a.views[&"side"].layers[0]
	var r: Rect2 = L.region
	var ink := img.get_pixelv(Vector2i(r.position) + Vector2i(roundi(29.0 - 50.0 - L.offset.x), roundi(120.0 - 150.0 - L.offset.y)))
	var mid := img.get_pixelv(Vector2i(r.position) + Vector2i(roundi(50.0 - 50.0 - L.offset.x), roundi(130.0 - 150.0 - L.offset.y)))
	if ink.v > 0.3:
		return "expected ink at the outline, got %s" % ink
	if _cd(mid, Color("#3f8f5c")) > 0.05:
		return "expected the torso fill mid-layer, got %s" % mid
	# hidden: no scarf red anywhere in the torso layer
	for y in int(r.size.y):
		for x in int(r.size.x):
			var c := img.get_pixel(int(r.position.x) + x, int(r.position.y) + y)
			if c.a > 0.5 and c.r > 0.7 and c.g < 0.4:
				return "the hidden scarf was baked"
	return ""


func test_hue_map_recolours_and_keeps_greys() -> String:
	var data := MotionSvgData.from_string(SVG)
	var m := MotionCutoutAtlas.hue_map(data, Color("#3f8f5c"), Color("#5c3f8f"))
	var g: Color = m.get("3f8f5c", Color.BLACK)
	if _cd(g, Color("#5c3f8f")) > 0.02:
		return "the anchor colour should map onto the target: %s" % g
	if m.has("1f1a26"):
		return "near-greys should stay as drawn"
	var a := MotionCutoutAtlas.new()
	a.add_view(&"v", data, 1.0, {origin = Vector2(50, 190), recolor = m, outline = 0.0})
	a.bake()
	var L: Dictionary = a.views[&"v"].layers[0]
	var mid := a.texture.get_image().get_pixelv(Vector2i((L.region as Rect2).position) + Vector2i(roundi(-L.offset.x), roundi(-20.0 - L.offset.y)))
	if _cd(mid, Color("#5c3f8f")) > 0.06:
		return "baked fill not recoloured: %s" % mid
	return ""


# ------------------------------------------------------------------ rig

func test_rig_pose_and_apply() -> String:
	var r := _rig(_atlas())
	if r.view != &"side" or r.mirrored:
		_free()
		return "first view"
	if r.layer_count() != 7:
		_free()
		return "sprite pool: %d" % r.layer_count()
	r.pose(&"head", PI * 0.5)
	r.apply()
	# the eyes pivot sits 30 px above the head pivot: turned 90 degrees clockwise it goes right
	var e := r.part_point(&"eyes")
	var h := r.part_point(&"head")
	var ok := (e - h).is_equal_approx(Vector2(30, 0))
	_free()
	return "" if ok else "eyes after a quarter turn: %s" % (e - h)


func test_rig_solve_limb() -> String:
	var r := _rig(_atlas())
	var target := r.rest_pivot(&"arm_upper") + Vector2(30, 20)
	var reached := r.solve_limb(&"arm_upper", &"arm_lower", &"hand", target, 1.0)
	var got := r.part_point(&"hand")
	_free()
	if not reached:
		return "target should be in reach"
	return "" if got.distance_to(target) < 0.01 else "hand at %s, wanted %s" % [got, target]


func test_rig_face_views_and_sides() -> String:
	var r := _rig(_atlas())
	r.face(Vector2.LEFT)
	if r.view != &"side_left" or r.mirrored or not r.left:
		_free()
		return "facing left should pick the LEFT view unmirrored"
	r.face(Vector2.RIGHT)
	var right_ok := r.view == &"side" and not r.left
	# a MIRROR view flips for the left
	var m := MotionCutoutRig2D.new(r.atlas)
	_keep.append(m)
	m.paper_turn = false
	m.add_view(&"side", &"side", MotionCutoutRig2D.MIRROR)
	m.face(Vector2.LEFT)
	var mir := m.mirrored and m.flip.scale.x < 0.0
	_free()
	if not right_ok:
		return "facing right"
	return "" if mir else "MIRROR view should flip for the left"


func test_rig_paper_turn_swaps_when_narrow() -> String:
	var r := _rig(_atlas())
	r.paper_turn = true
	r.face(Vector2.LEFT)
	if r.view != &"side":
		_free()
		return "with a paper turn the swap waits for step()"
	var swapped_at := -1.0
	for i in 60:
		r.step(1.0 / 60.0)
		if r.view == &"side_left" and swapped_at < 0.0:
			swapped_at = r.turn.value
	var settled := r.turn.value > 0.95
	_free()
	if swapped_at < 0.0:
		return "never swapped"
	if swapped_at > 0.3:
		return "swapped while still wide: %s" % swapped_at
	return "" if settled else "didn't open back up"


func test_rig_depth_reorders_layers() -> String:
	var r := _rig(_atlas())
	var last := func() -> Sprite2D:
		var s: Sprite2D = null
		for c in r.body.get_children():
			if (c as Sprite2D).visible:
				s = c
		return s
	var before: Sprite2D = last.call()
	var hand_region := before.region_rect    # the hand draws last
	r.depth(&"head", 1)
	var after: Sprite2D = last.call()
	var head_on_top := after.region_rect != hand_region
	r.depth(&"arm_upper", -1)
	var first: Sprite2D = r.body.get_child(0)
	var v: Dictionary = r.atlas.views[&"side"]
	var arm_first := first.region_rect == (v.layers[4].region as Rect2)
	r.depth(&"head", 0)
	r.depth(&"arm_upper", 0)
	var restored := (r.body.get_child(0) as Sprite2D).region_rect == (v.layers[0].region as Rect2)
	_free()
	if not head_on_top:
		return "head should draw last with depth +1"
	if not arm_first:
		return "the arm chain should draw first with depth -1"
	return "" if restored else "depth 0 should restore the drawn order"


func test_rig_props_follow_their_part() -> String:
	var a := _atlas()
	var r := _rig(a)
	r.add_prop(&"stick", &"hand", &"stick", Vector2(0, 2), 0.0, false)
	if r.layer_count() != 8:
		_free()
		return "prop layer missing: %d" % r.layer_count()
	r.pose(&"arm_upper", 0.4)
	r.apply()
	var hand := r.part_transform(&"hand")
	var stick := r.part_transform(&"stick")
	var ok := (stick.origin - hand * Vector2(0, 2)).length() < 0.001
	# drawn just behind the hand: the sprite before the hand's
	var idx_hand := -1
	var idx_stick := -1
	var hand_region: Rect2 = a.views[&"side"].layers[6].region
	var stick_region: Rect2 = a.views[&"stick"].layers[0].region
	for i in r.body.get_child_count():
		var s := r.body.get_child(i) as Sprite2D
		if s.region_rect == hand_region:
			idx_hand = i
		elif s.region_rect == stick_region:
			idx_stick = i
	_free()
	if not ok:
		return "prop doesn't follow the hand"
	return "" if idx_stick == idx_hand - 1 else "prop order: stick %d, hand %d" % [idx_stick, idx_hand]


func test_rig_set_look_encoding() -> String:
	var r := _rig(_atlas())
	r.set_look(Color(1, 0.5, 0.5), 0.0, 0.4)
	var faded := r.modulate.is_equal_approx(Color(1, 0.5, 0.5, 0.4))
	r.set_look(Color.WHITE, 0.6)
	var flashed := is_equal_approx(r.modulate.a, 1.6)
	var shared := (r.body.get_child(0) as Sprite2D).material == MotionCutoutAtlas.material()
	_free()
	if not faded:
		return "tint and fade"
	if not flashed:
		return "a flash rides on alpha above 1"
	return "" if shared else "every layer should share the one material"
