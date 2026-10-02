shader_type sky;

// The generated maps' sky (BuiltMap): gradient from the horizon colour
// to the zenith, a sun disc with its glow, and clouds - a noise texture
// made once at load, projected onto a flat cloud layer (so they shrink
// toward the horizon like real clouds), lit brighter on the sun's side
// and tinted by the sun (orange at sunset), drifting slowly. Below the
// horizon: the fog colour (the world fades into it, see world_common).

uniform vec3 top_color : source_color = vec3(0.3, 0.5, 0.8);
uniform vec3 horizon_color : source_color = vec3(0.75, 0.82, 0.9);
uniform vec3 ground_color : source_color = vec3(0.75, 0.82, 0.9);
uniform vec3 sun_dir = vec3(0.0, 0.7, 0.7); // toward the sun
uniform vec3 sun_color : source_color = vec3(1.0, 0.95, 0.85);
uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;
uniform float coverage = 0.55; // higher = fewer clouds (1.2 = none)

void sky() {
	// Only the camera's view gets clouds: the cubemap passes (ambient and
	// reflection maps - nothing here uses them, every material is
	// unshaded) get the plain gradient, so drifting clouds don't force a
	// full cubemap re-render every frame.
	if (AT_CUBEMAP_PASS) {
		COLOR = mix(horizon_color, top_color, clamp(EYEDIR.y, 0.0, 1.0));
	} else {
	vec3 d = normalize(EYEDIR);
	float el = d.y;
	vec3 sd3 = normalize(sun_dir);
	float sd = max(dot(d, sd3), 0.0);
	vec3 col;
	if (el < 0.0) {
		col = ground_color;
	} else {
		col = mix(horizon_color, top_color, pow(clamp(el, 0.0, 1.0), 0.5));
		// The sky glows warmer around a low sun.
		col += sun_color * pow(sd, 6.0) * 0.18 * (1.0 - el);
		if (coverage < 1.15) {
			vec2 p = d.xz / (el + 0.1) * 0.09 + vec2(TIME * 0.0015, TIME * 0.0006);
			float n = texture(clouds, p).r * 0.7 + texture(clouds, p * 2.9 + vec2(0.37, 0.11)).r * 0.3;
			float c = smoothstep(coverage, coverage + 0.22, n) * smoothstep(0.0, 0.16, el);
			vec3 lit = mix(horizon_color * 0.85 + vec3(0.1), vec3(1.0), 0.45 + 0.55 * pow(sd, 2.0));
			lit = mix(lit, lit * sun_color * 1.15, 0.4) * (0.78 + 0.32 * n);
			col = mix(col, lit, c * 0.92);
		}
		col += sun_color * (pow(sd, 1400.0) * 4.0 + pow(sd, 60.0) * 0.3);
	}
	COLOR = col;
	}
}
