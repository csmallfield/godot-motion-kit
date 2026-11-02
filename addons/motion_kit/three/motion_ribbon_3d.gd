# SPDX-License-Identifier: Apache-2.0
## A flat ribbon through a moving polyline (a MotionChain's points): a strip
## in the node's XY plane (facing +Z, like cutout cards) with a width that
## tapers along it, and an ink outline drawn as a wider strip just behind,
## so a moving scarf matches outlined cutout parts without rebuilding edge
## geometry each frame. Rebuilt every update() (ImmediateMesh): meant for a
## handful of short chains, not hundreds.
##
##   var scarf := MotionRibbon3D.new()
##   scarf.material_override = flat.cutout()
##   scarf.width_from = 0.06; scarf.width_to = 0.02
##   scarf.color = Color("#d8433b")
##   scarf.update(chain.render_points(frac))
@tool
class_name MotionRibbon3D
extends MeshInstance3D

var width_from := 0.05
var width_to := 0.02
var color := Color.WHITE
## Outline thickness (metres each side) and colour; 0 = none.
var outline := 0.006
var outline_color := Color("#1b1622")
## How far behind the strip the outline sits (along -Z).
var outline_depth := 0.002
## A round-ish end: the last segment narrows to a point.
var pointed := false

var _im := ImmediateMesh.new()


func _init() -> void:
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Rebuild the strip through `pts` (in this node's space).
func update(pts: PackedVector3Array) -> void:
	_im.clear_surfaces()
	var n := pts.size()
	if n < 2:
		return
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	if outline > 0.0:
		_strip(pts, outline, outline_color, -outline_depth)
	_strip(pts, 0.0, color, 0.0)
	_im.surface_end()


func _strip(pts: PackedVector3Array, grow: float, col: Color, z: float) -> void:
	var n := pts.size()
	var left := PackedVector3Array()
	var right := PackedVector3Array()
	for i in n:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, n - 1)]
		var t := Vector2(b.x - a.x, b.y - a.y)
		t = t.normalized() if t.length_squared() > 1e-12 else Vector2.DOWN
		var u := float(i) / float(n - 1)
		var w := lerpf(width_from, width_to, u) * 0.5
		if pointed and i == n - 1:
			w = 0.0
		w += grow
		var nrm := Vector3(-t.y, t.x, 0.0) * w
		var p := pts[i] + Vector3(0, 0, z)
		left.append(p + nrm)
		right.append(p - nrm)
	for i in n - 1:
		for v in [left[i], right[i], right[i + 1], left[i], right[i + 1], left[i + 1]]:
			_im.surface_set_color(col)
			_im.surface_set_normal(Vector3.BACK)
			_im.surface_add_vertex(v)
