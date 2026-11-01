// SPDX-License-Identifier: Apache-2.0
// Motion Kit 3D: flat graphic face tones by normal (the MotionExtrude look in
// real 3D). Up-facing faces take `top`, sides facing the horizontal light take
// `lit`, sides facing away `dark`, down-facing faces `under`; `soft` widens
// the lit/dark terminator (0 = a hard poster cut, also on cylinders). Vertex
// colour multiplies the tone. Unshaded, so it renders the same in every
// renderer and costs almost nothing; group motion and depth fog come from
// motion_flat_3d.gdshaderinc. Two-sided variant.
shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

#include "res://addons/motion_kit/three/motion_flat_3d_faces.gdshaderinc"
