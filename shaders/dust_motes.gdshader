shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled, shadows_disabled;

// Dust in the air (DustMotes): a few hundred tiny specks in a box that
// wraps round the camera - each speck has a fixed place in a repeating
// 14 m lattice and drifts slowly, so it stays put in the world while
// the drone flies through (no CPU work per frame). Brighter where the
// sun would catch it (looking across the light), faded out at the
// box's edge and right in front of the lens.

uniform float box = 14.0;
uniform float size = 0.012;
uniform vec3 color : source_color = vec3(1.0, 0.93, 0.8);
uniform float amount = 1.0;

varying float fade;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 drift = vec3(sin(TIME * 0.07 + base.y * 1.3), sin(TIME * 0.05 + base.x) * 0.6 - TIME * 0.015, cos(TIME * 0.06 + base.z * 1.1)) * 0.6;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 p = cam + mod(base + drift - cam + box * 0.5, vec3(box)) - box * 0.5;
	vec4 vp = VIEW_MATRIX * vec4(p, 1.0);
	float d = length(p - cam);
	fade = smoothstep(box * 0.5, box * 0.3, d) * smoothstep(0.15, 0.6, d);
	vp.xy += VERTEX.xy * size * (1.0 + 0.6 * fract(base.x * 7.31));
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	float r = length(UV - 0.5) * 2.0;
	float a = (1.0 - smoothstep(0.2, 1.0, r)) * fade * amount;
	ALBEDO = color * a * 0.35;
}
