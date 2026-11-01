// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: crisp screen-space outlines (MotionEdges3D meshes).
// Each edge is a quad whose four vertices all sit on the edge's endpoints;
// the vertex stage widens it to `width_px` pixels in screen space (constant
// width in perspective and orthographic views), extends it half a width past
// each end so corners close, and pulls it `bias` units towards the camera so
// it wins the depth test against its own faces while solids in front still
// hide it. Crease edges draw whenever a neighbouring face looks at the camera
// (or always, for edges built without orientation); smooth edges draw only on
// the silhouette (one face towards the camera, one away), so cylinders get
// their outline sides. Segments crossing the near plane are clipped first.
//   VERTEX  this endpoint          NORMAL   face A normal
//   CUSTOM0 other endpoint, side   CUSTOM1  face B normal, kind (0 smooth, 1 crease, 2 always)
//   UV2     group key (moves with its object, see motion_flat_3d.gdshaderinc)
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://addons/motion_kit/three/motion_flat_3d.gdshaderinc"

uniform vec4 color : source_color = vec4(0.06, 0.06, 0.07, 1.0);
uniform float width_px = 1.6;
uniform float bias = 0.04;
uniform float clip_near = 0.12;

void vertex() {
	float off = mk_group_offset(UV2);
	vec3 pa = VERTEX + vec3(0.0, off, 0.0);
	vec3 pb = CUSTOM0.xyz + vec3(0.0, off, 0.0);
	float side = CUSTOM0.w;
	float kind = CUSTOM1.w;
	vec4 va = MODELVIEW_MATRIX * vec4(pa, 1.0);
	vec4 vb = MODELVIEW_MATRIX * vec4(pb, 1.0);
	bool ortho = PROJECTION_MATRIX[3][3] > 0.5;
	vec3 to_cam = ortho ? vec3(0.0, 0.0, 1.0) : -va.xyz;
	vec3 na = (MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz;
	vec3 nb = (MODELVIEW_MATRIX * vec4(CUSTOM1.xyz, 0.0)).xyz;
	bool fa = dot(na, to_cam) > 0.0;
	bool fb = dot(nb, to_cam) > 0.0;
	bool vis = kind > 1.5 || ((fa || fb) && (kind > 0.5 || fa != fb));
	// clip against the near plane (view z is negative in front of the camera)
	float zc = -clip_near;
	if (va.z > zc && vb.z > zc) {
		vis = false;
	} else if (va.z > zc) {
		va = mix(va, vb, (va.z - zc) / (va.z - vb.z));
	} else if (vb.z > zc) {
		vb = mix(vb, va, (vb.z - zc) / (vb.z - va.z));
	}
	va.z += bias;
	vb.z += bias;
	vec4 ca = PROJECTION_MATRIX * va;
	vec4 cb = PROJECTION_MATRIX * vb;
	vec2 half_vp = VIEWPORT_SIZE * 0.5;
	vec2 sa = ca.xy / ca.w * half_vp;
	vec2 sb = cb.xy / cb.w * half_vp;
	vec2 dir = sb - sa;
	float len = length(dir);
	dir = len > 1e-4 ? dir / len : vec2(1.0, 0.0);
	vec2 perp = vec2(-dir.y, dir.x);
	vec2 px = (perp * side - dir) * width_px * 0.5;
	ca.xy += px / half_vp * ca.w;
	POSITION = vis ? ca : vec4(10.0, 10.0, 0.5, 1.0);
}

void fragment() {
	ALBEDO = mk_fog(color.rgb * energy, -VERTEX.z);
}
