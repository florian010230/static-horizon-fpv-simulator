shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled, shadows_disabled;

// Grass tufts and pebbles round the camera (GrassTufts): every instance
// has a fixed place in a lattice that repeats every 2*radius metres and
// is wrapped round the camera in the vertex shader - so tufts stay put in
// the world, no CPU work per frame. Height, "is this grass" and the
// ground's colour come from a top-down capture of the map made once at
// load (depth packed in red/green, grass in blue; colour incl. baked
// light and sun shadow), so a tuft takes the colour of the ground it
// stands on and never stands on a road, a roof or in water.



uniform sampler2D hmap : filter_nearest, repeat_disable;
uniform sampler2D cmap : source_color, filter_linear, repeat_disable;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 0.0); // x0, z0, size
uniform float radius = 14.0;
uniform vec2 cap = vec2(700.0, 1400.0); // capture camera height and far plane (near 1)
uniform bool stones = false;

varying vec3 col;
varying vec3 wpos;

vec3 texel(ivec2 i, ivec2 sz) {
	vec3 t = texelFetch(hmap, clamp(i, ivec2(0), sz - 1), 0).rgb;
	return vec3(t.r + t.g / 255.0, t.b, 0.0);
}

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	vec3 cam = CAMERA_POSITION_WORLD;
	float span = radius * 2.0;
	vec2 xz = cam.xz + mod(base.xz - cam.xz + radius, vec2(span)) - radius;
	vec2 uv = (xz - region.xy) / region.z;
	ivec2 sz = textureSize(hmap, 0);
	vec2 tc = uv * vec2(sz) - 0.5;
	ivec2 i = ivec2(floor(tc));
	vec2 f = fract(tc);
	vec3 a = texel(i, sz), b = texel(i + ivec2(1, 0), sz), c = texel(i + ivec2(0, 1), sz), d = texel(i + ivec2(1, 1), sz);
	vec3 h = mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
	// Depth below the camera (reversed: 1 at the near plane) -> height.
	float gy = cap.x - cap.y + h.x * (cap.y - 1.0);
	float grass = min(min(a.y, b.y), min(c.y, d.y)); // conservative at edges
	// Not across a step (a cliff's edge, a wall): there the four heights
	// blend into a level in mid-air.
	float spread = (max(max(a.x, b.x), max(c.x, d.x)) - min(min(a.x, b.x), min(c.x, d.x))) * (cap.y - 1.0);
	grass *= step(spread, 1.5);
	vec3 g = texture(cmap, uv).rgb;
	// Green ground only (no rock, sand, snow, soil).
	float green = smoothstep(0.0, 0.04, g.g - max(g.r, g.b) * 0.92);
	float dist = length(xz - cam.xz);
	// (Shrunk right at the lens: a quad resting in the grass would see
	// nothing but two blades.)
	float s = step(0.5, grass) * green * smoothstep(radius, radius * 0.75, dist) * smoothstep(0.2, 0.9, length(vec3(xz.x, gy, xz.y) - cam));
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) {
		s = 0.0;
	}
	float rnd = fract(base.x * 3.17 + base.z * 7.31);
	vec3 v = mat3(MODEL_MATRIX) * VERTEX * s;
	// Breeze: the tips sway a little.
	float tip = COLOR.a;
	if (!stones) {
		v.x += sin(TIME * 1.9 + xz.x * 0.7 + xz.y * 0.4) * 0.03 * tip * s;
		v.z += sin(TIME * 1.5 + xz.y * 0.6) * 0.02 * tip * s;
	}
	wpos = vec3(xz.x, gy - 0.02, xz.y) + v;
	// Ground colour, darker at the base, lighter and yellower at the tips;
	// pebbles grey-brown and lit from above.
	if (stones) {
		col = mix(vec3(0.42, 0.4, 0.37), g, 0.35) * (0.7 + 0.5 * max(NORMAL.y, 0.0)) * (0.8 + 0.4 * rnd);
	} else {
		col = g * mix(0.62, 1.12, tip) * mix(vec3(1.0), vec3(1.08, 1.06, 0.82), tip * rnd);
	}
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * vec4(wpos, 1.0));
}

void fragment() {
	ALBEDO = col; // (the captured ground colour is already graded; no fog this close)
}
