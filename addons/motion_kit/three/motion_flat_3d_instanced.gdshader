// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: motion_flat_3d.gdshader with per-instance `flash` and `tint`
// (instance uniforms), for actors and props that react one at a time: a hit
// flash on one enemy leaves the others that share the material alone.
// MotionFlat3D.material(..., instanced = true); MotionFlat3D.set_flash().
shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

#define MK_INSTANCED
#include "res://addons/motion_kit/three/motion_flat_3d_faces.gdshaderinc"
