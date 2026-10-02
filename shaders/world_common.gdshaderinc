// Shared by every world surface (see scripts/world_shading.gd): the
// cheap distance fog and the static sun shadow map. All values are
// global shader uniforms (project.godot [shader_globals]) set once per
// map by WorldShading - no per-material setup.

// Fog: x begin, y end (m), z density (exponential fog), w mode
// (0 off, 1 depth fog begin..end, 2 exponential).
global uniform vec4 sh_fog;
global uniform vec4 sh_fog_color;
// Sun: xyz direction the light travels, w shadow strength (0 = off).
global uniform vec4 sh_sun;
// The baked light's parts (see Geo.shade): x ambient, y sky, z sun.
global uniform vec4 sh_light;
global uniform vec4 sh_sun_color;
// Colour grade: x contrast, y saturation, z warmth (+ = warmer).
global uniform vec4 sh_grade;
// World -> shadow map: uv = (r0.p, r1.p), depth = r2.p (p = (pos, 1)).
global uniform vec4 sh_shadow_r0;
global uniform vec4 sh_shadow_r1;
global uniform vec4 sh_shadow_r2;
// x depth bias (map units), y normal offset (m), z PCF on (1/0).
global uniform vec4 sh_shadow_info;
global uniform sampler2D sh_shadow_map : filter_nearest, repeat_disable;

float sh_depth_at(ivec2 i, ivec2 size) {
	vec2 t = texelFetch(sh_shadow_map, clamp(i, ivec2(0), size - 1), 0).rg;
	return t.r + t.g / 255.0;
}

// 0 lit .. 1 fully in shadow. n = world normal (facing the viewer).
float sh_shadow(vec3 wpos, vec3 n) {
	if (sh_sun.w <= 0.0) {
		return 0.0;
	}
	vec3 p = wpos + n * sh_shadow_info.y;
	vec4 p4 = vec4(p, 1.0);
	vec3 s = vec3(dot(sh_shadow_r0, p4), dot(sh_shadow_r1, p4), dot(sh_shadow_r2, p4));
	if (s.x <= 0.0 || s.y <= 0.0 || s.x >= 1.0 || s.y >= 1.0 || s.z >= 1.0) {
		return 0.0;
	}
	ivec2 size = textureSize(sh_shadow_map, 0);
	float z = s.z - sh_shadow_info.x;
	if (sh_shadow_info.z < 0.5) {
		return step(sh_depth_at(ivec2(s.xy * vec2(size)), size), z);
	}
	// Bilinear PCF: four depth tests, blended - soft 1-texel edges.
	vec2 tc = s.xy * vec2(size) - 0.5;
	ivec2 i = ivec2(floor(tc));
	vec2 f = fract(tc);
	float a = step(sh_depth_at(i, size), z);
	float b = step(sh_depth_at(i + ivec2(1, 0), size), z);
	float c = step(sh_depth_at(i + ivec2(0, 1), size), z);
	float d = step(sh_depth_at(i + ivec2(1, 1), size), z);
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// Takes the sun's share out of a baked colour where the surface is in
// shadow: the vertex colour is ambient + sky + sun * N.L (Geo.shade),
// so the shadowed colour is that colour * (ambient + sky) / total -
// boosted (x1.7): the baked light is ambient-heavy (it has to read on
// every face), and an exact shadow then only darkened ground by ~30%,
// which got lost in textures. Real sun shadows are about half as bright.
vec3 sh_apply_shadow(vec3 c, vec3 wpos, vec3 n) {
	float ndl = dot(n, -sh_sun.xyz);
	if (sh_sun.w <= 0.0 || ndl <= 0.0) {
		return c;
	}
	float sh = sh_shadow(wpos, n);
	if (sh <= 0.0) {
		return c;
	}
	float base = sh_light.x + sh_light.y * (0.5 + 0.5 * n.y);
	float direct = sh_light.z * ndl;
	return c * (1.0 - sh_sun.w * sh * min(1.7 * direct / max(base + direct, 0.001), 0.62));
}

vec3 sh_grade_color(vec3 c) {
	if (sh_grade.x <= 0.0) {
		return c;
	}
	float l = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(vec3(l), c, sh_grade.y);
	c = (c - 0.45) * sh_grade.x + 0.45;
	c *= vec3(1.0 + sh_grade.z, 1.0, 1.0 - sh_grade.z);
	return max(c, vec3(0.0));
}

vec3 sh_apply_fog(vec3 c, vec3 wpos, vec3 cam) {
	c = sh_grade_color(c);
	if (sh_fog.w < 0.5) {
		return c;
	}
	float d = length(wpos - cam);
	float f;
	if (sh_fog.w < 1.5) {
		f = clamp((d - sh_fog.x) / max(sh_fog.y - sh_fog.x, 1.0), 0.0, 1.0);
		f = f * f * (3.0 - 2.0 * f);
	} else {
		f = 1.0 - exp(-sh_fog.z * d);
	}
	return mix(c, sh_fog_color.rgb, f);
}
