shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// GrassTufts' top-down capture: every surface writes its depth below the
// orthographic camera (packed into red/green; GrassTufts turns it back
// into a height) and whether it is grass ground (blue). (Depth, not a
// world-height varying: the varying came out centimetres-to-metres off
// on the dev machine's GL driver.)

uniform float grass = 0.0;

void fragment() {
	float d = clamp(FRAGCOORD.z, 0.0, 0.99999);
	ALBEDO = vec3(floor(d * 255.0) / 255.0, fract(d * 255.0), grass); // written as-is (no sRGB step), like shadow_depth
}
