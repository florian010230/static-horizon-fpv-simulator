shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Garden flowers (GardenCreator): clumps drawn as MultiMesh, a handful of
// shapes shared by every bed. Vertex alpha 1 is leaves (foliage texture),
// 0.4 petals - their colour comes from the clump (INSTANCE_CUSTOM.rgb), so
// one shape serves every colour - and 0.2 a plain colour (stems, the
// yellow eye of a daisy). Lit like the trees (tree.gdshader).

#include "res://shaders/world_common.gdshaderinc"

uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float leaf_scale = 2.2;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 col;
varying float kind;

void vertex() {
	col = COLOR.rgb;
	kind = COLOR.a;
	if (COLOR.a > 0.3 && COLOR.a < 0.5) {
		col *= INSTANCE_CUSTOM.rgb;
	}
	// The faintest breeze in the petals.
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = VERTEX.y * step(COLOR.a, 0.5);
	VERTEX.x += sin(TIME * 1.7 + o.x * 0.9 + o.z * 0.5) * 0.02 * h;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 t = vec3(1.0);
	if (kind > 0.5) {
		vec3 w = pow(abs(n), vec3(2.0));
		w /= (w.x + w.y + w.z);
		vec3 p = wpos * leaf_scale;
		t = texture(leaves, p.xz).rgb * w.y + texture(leaves, p.xy).rgb * w.z + texture(leaves, p.zy).rgb * w.x;
	}
	float ndl = max(dot(n, -sh_sun.xyz), 0.0);
	vec3 light = vec3(sh_light.x + sh_light.y * (0.5 + 0.5 * n.y)) + sh_sun_color.rgb * sh_light.z * ndl;
	vec3 c = col * t * light;
	c = sh_apply_shadow(c, wpos, n);
	ALBEDO = sh_apply_fog(c, wpos, CAMERA_POSITION_WORLD);
}
