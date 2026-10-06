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
// Surface detail (WorldShading.set_detail, by graphics quality): x close-up
// detail strength, y distance (m) it has faded out by, z large-scale wear.
// sh_detail_tex: tileable noise, R/G fine detail, B/A large blotches.
global uniform vec4 sh_detail;
global uniform sampler2D sh_detail_tex : filter_linear_mipmap, repeat_enable;

// Breaks up flat colours and tiled textures: large-scale wear, dirt and
// a slight warm/cool drift everywhere (two samples), and fine grain that
// fades in near the camera (two more, only within the fade distance).
// Projected on the surface's dominant plane (ground: always top-down);
// the frequencies don't divide each other, so nothing repeats visibly.
vec3 sh_surface_detail(vec3 c, vec3 wpos, vec3 n, vec3 cam, bool ground) {
	if (sh_detail.x <= 0.0 && sh_detail.z <= 0.0) {
		return c;
	}
	vec3 an = abs(n);
	vec2 p = (ground || an.y > max(an.x, an.z)) ? wpos.xz : (an.x > an.z ? wpos.zy : wpos.xy);
	vec4 m = texture(sh_detail_tex, p * 0.023 + vec2(0.31, 0.17));
	float m2 = texture(sh_detail_tex, p * 0.087 + vec2(0.71, 0.43)).a;
	float wear = (m.b - 0.5) + (m2 - 0.5) * 0.6;
	c *= 1.0 + sh_detail.z * (wear + (m.r - 0.5) * vec3(0.35, 0.0, -0.35));
	float d = length(wpos - cam);
	float f = 1.0 - smoothstep(sh_detail.y * 0.35, sh_detail.y, d);
	if (f > 0.0 && sh_detail.x > 0.0) {
		float a = texture(sh_detail_tex, p * 1.37).r;
		float b = texture(sh_detail_tex, p * 5.3 + vec2(0.5)).g;
		c *= 1.0 + sh_detail.x * f * ((a - 0.5) * 0.9 + (b - 0.5) * 0.7);
	}
	return c;
}

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

// The haze's colour by view direction (outdoor depth fog only): warmer
// and brighter toward the sun - forward (Mie) scattering in the haze,
// strongest with a low sun, whose light crosses the most air - and a
// touch cooler away from it. sky_clouds.gdshader adds the same glow to
// the sky at the horizon, so world and sky meet without a seam.
float sh_haze_glow(float sd, float sun_el) {
	float low = 1.0 - clamp(sun_el, 0.0, 1.0);
	return pow(sd, 6.0) * (0.18 + 0.32 * low * low) + pow(sd, 40.0) * 0.25 * low;
}

vec3 sh_haze_color(vec3 v) {
	if (sh_fog.w > 1.5) {
		return sh_fog_color.rgb;
	}
	vec3 to_sun = -sh_sun.xyz;
	float sd = max(dot(normalize(vec3(v.x, 0.0, v.z) + vec3(0.0, 0.0001, 0.0)), to_sun), 0.0);
	float low = 1.0 - clamp(to_sun.y, 0.0, 1.0);
	vec3 c = sh_fog_color.rgb + sh_sun_color.rgb * sh_haze_glow(sd, to_sun.y);
	return c * mix(vec3(1.0), vec3(0.95, 0.98, 1.03), (1.0 - sd) * low * 0.6);
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
	return mix(c, sh_haze_color(normalize(wpos - cam)), f);
}
