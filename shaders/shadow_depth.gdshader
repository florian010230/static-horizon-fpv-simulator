shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Renders the static sun shadow map once per map (WorldShading.capture):
// every caster writes its depth along the sun, packed into red/green.

#include "res://shaders/world_common.gdshaderinc"

varying float z;

void vertex() {
	z = dot(sh_shadow_r2, vec4((MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz, 1.0));
}

void fragment() {
	float d = clamp(z, 0.0, 0.99999);
	vec3 enc = vec3(floor(d * 255.0) / 255.0, fract(d * 255.0), 0.0);
	ALBEDO = enc; // (written as-is: no sRGB conversion here, measured)
}
