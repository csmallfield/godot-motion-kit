# SPDX-License-Identifier: Apache-2.0
# Hazard tape for the FTF Warning take. Promoted to the kit as MotionTape
# (addons/motion_kit/shapes/motion_tape.gd); the piece calls it directly and
# these forward to it for anything still preloading this script.
extends RefCounted


## Deprecated: use MotionTape.path.
static func path(spec: Dictionary, f: float) -> Dictionary:
	return MotionTape.path(spec, f)


## Deprecated: use MotionTape.pieces.
static func pieces(spec: Dictionary, total: float, f: float) -> Array:
	return MotionTape.pieces(spec, total, f)


## Deprecated: use MotionTape.pose.
static func pose(spec: Dictionary, f: float) -> Dictionary:
	return MotionTape.pose(spec, f)


## Deprecated: use MotionTape.draw.
static func draw(c: MotionCanvas, spec: Dictionary, p: Dictionary, f: float, opacity := 1.0) -> void:
	MotionTape.draw(c, spec, p, f, opacity)


## Deprecated: use MotionTape.edge.
static func _edge(p: Dictionary, s: float, side: float) -> Vector2:
	return MotionTape.edge(p, s, side)


## Deprecated: use MotionTape.edge_run.
static func _edge_run(p: Dictionary, s0: float, s1: float, side: float, step := 20.0) -> PackedVector2Array:
	return MotionTape.edge_run(p, s0, s1, side, step)


## Deprecated: use MotionPath.rounded_rect.
static func rounded_rect(r: Rect2, radius: float, seg := 8) -> PackedVector2Array:
	return MotionPath.rounded_rect(r, radius, seg)
