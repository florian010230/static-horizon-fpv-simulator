shader_type canvas_item;

// Analog FPV video look over the whole picture: sensor noise, faint
// scanlines, a slight horizontal colour smear, rolling interference
// bands and a vignette - what a 5.8 GHz analog feed looks like in
// goggles. strength 0 = off.
uniform float strength : hint_range(0.0, 1.0) = 0.5;
// Fisheye lens (barrel distortion) like a real FPV camera's wide lens:
// 0 none. The picture is scaled so the corners still reach the corners.
uniform float fisheye = 0.0;
uniform float aspect = 1.6;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear;

float hash(vec2 p) { return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453); }

void fragment() {
	vec2 uv = SCREEN_UV;
	if (fisheye > 0.0) {
		vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
		float rc2 = dot(vec2(aspect, 1.0) * 0.5, vec2(aspect, 1.0) * 0.5);
		p *= (1.0 + fisheye * dot(p, p)) / (1.0 + fisheye * rc2);
		uv = p / vec2(aspect, 1.0) + 0.5;
	}
	float t = TIME;
	// Occasional rolling band that jitters the line horizontally.
	float band = smoothstep(0.985, 1.0, sin(uv.y * 3.0 - t * 1.7) * 0.5 + 0.5);
	uv.x += (hash(vec2(floor(uv.y * 240.0), floor(t * 30.0))) - 0.5) * 0.012 * band * strength;
	float smear = 0.0025 * strength;
	vec3 c;
	c.r = texture(screen_tex, uv + vec2(smear, 0.0)).r;
	c.g = texture(screen_tex, uv).g;
	c.b = texture(screen_tex, uv - vec2(smear, 0.0)).b;
	float n = hash(uv * vec2(640.0, 480.0) + fract(t * 7.0)) - 0.5;
	c += n * 0.16 * strength;
	c *= 1.0 - 0.06 * strength * step(0.5, fract(uv.y * 240.0));
	c = mix(c, vec3(dot(c, vec3(0.3, 0.59, 0.11))), 0.15 * strength);
	vec2 v = uv - 0.5;
	c *= 1.0 - dot(v, v) * 0.9 * strength;
	COLOR = vec4(c, 1.0);
}
