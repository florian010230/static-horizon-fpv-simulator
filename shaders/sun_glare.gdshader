shader_type canvas_item;
render_mode unshaded, blend_add;

// Sun glare in the camera (SunGlare): the halo round the sun, a short
// horizontal streak and the veiling glare that lifts the whole picture
// when the sun is in or near the frame - what a small FPV camera lens
// does looking into the sun. Added on top of the 3D view, under the
// camera look (the video system sees the flare as part of its picture).
// Pure arithmetic, no texture reads; hidden when the sun is out of view.

uniform vec2 sun_uv = vec2(0.5);
uniform float strength = 0.0;
uniform float aspect = 1.6;
uniform vec3 tint : source_color = vec3(1.0, 0.95, 0.85);

void fragment() {
	vec2 d = (SCREEN_UV - sun_uv) * vec2(aspect, 1.0);
	float r2 = dot(d, d);
	float halo = 0.5 * exp(-r2 * 180.0) + 0.16 * exp(-sqrt(r2) * 5.0);
	float streak = 0.18 * exp(-abs(d.y) * 120.0) * exp(-abs(d.x) * 3.0);
	float veil = 0.07;
	COLOR = vec4(tint * strength * (halo + streak + veil), 1.0);
}
