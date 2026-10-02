shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;

// The flight-area border (WorldBorder), shown while the HUD warns: the
// whole wall and ceiling as a glowing grid, finer and striped close to
// the drone.

uniform vec3 drone_pos;
uniform float strength = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 0.32, 0.12, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	// The whole border shows: a coarse 16 m grid everywhere, the fine 2 m
	// grid and hazard stripes near the drone, a faint fill in between.
	float d = distance(wpos, drone_pos);
	float near = 1.0 - smoothstep(6.0, 40.0, d);
	vec3 g = abs(fract(wpos / 2.0 + 0.5) - 0.5) / fwidth(wpos / 2.0);
	float fine = (1.0 - clamp(min(min(g.x, g.y), g.z) - 0.5, 0.0, 1.0)) * near;
	vec3 g2 = abs(fract(wpos / 16.0 + 0.5) - 0.5) / fwidth(wpos / 16.0);
	float coarse = 1.0 - clamp(min(min(g2.x, g2.y), g2.z) - 0.8, 0.0, 1.0);
	float stripes = step(0.5, fract((wpos.x + wpos.y + wpos.z) * 0.125)) * 0.18 * near;
	float pulse = 0.8 + 0.2 * sin(TIME * 6.0);
	float a = max(fine * 0.85, coarse * 0.6) + stripes + 0.07 + 0.08 * near;
	ALBEDO = line_color.rgb * (1.0 + max(fine, coarse));
	ALPHA = clamp(a * strength * pulse, 0.0, 1.0);
}
