shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never, fog_disabled, shadows_disabled;

// The flight-area border (WorldBorder), shown while the HUD warns: a
// glowing grid with hazard stripes, visible only around the drone (it
// fades out a few dozen metres away) - a force field you can see, not a
// wall around the whole map.

uniform vec3 drone_pos;
uniform float strength = 0.0;
uniform vec4 line_color : source_color = vec4(1.0, 0.32, 0.12, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float d = distance(wpos, drone_pos);
	float fade = (1.0 - smoothstep(6.0, 34.0, d)) * strength;
	// 2 m grid along the surface (world xz plus height covers walls
	// and ceilings alike).
	vec3 g = abs(fract(wpos / 2.0 + 0.5) - 0.5) / fwidth(wpos / 2.0);
	float line = 1.0 - clamp(min(min(g.x, g.y), g.z) - 0.5, 0.0, 1.0);
	float stripes = step(0.5, fract((wpos.x + wpos.y + wpos.z) * 0.125)) * 0.18;
	float pulse = 0.75 + 0.25 * sin(TIME * 6.0);
	ALBEDO = line_color.rgb * (1.0 + line);
	ALPHA = clamp((line * 0.85 + stripes + 0.06) * fade * pulse, 0.0, 1.0);
}
