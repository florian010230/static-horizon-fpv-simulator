shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

// Rocks (RockCreator): a few faceted boulder shapes drawn as MultiMesh,
// turned and scaled per instance - so the light can't be baked into the
// vertices (the sun side would turn with the rock); lit here like the
// trees (tree.gdshader), the rock texture in world space (triplanar),
// the vertex colour carrying the stone's own tint, lichen and occlusion.

#include "res://shaders/world_common.gdshaderinc"

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float scale = 0.33;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 w = pow(abs(n), vec3(4.0));
	w /= (w.x + w.y + w.z);
	vec3 p = wpos * scale;
	vec3 t = texture(tex, p.xz).rgb * w.y + texture(tex, p.xy).rgb * w.z + texture(tex, p.zy).rgb * w.x;
	float ndl = max(dot(n, -sh_sun.xyz), 0.0);
	vec3 light = vec3(sh_light.x + sh_light.y * (0.5 + 0.5 * n.y)) + sh_sun_color.rgb * sh_light.z * ndl;
	vec3 c = COLOR.rgb * t * light;
	c = sh_apply_shadow(c, wpos, n);
	ALBEDO = sh_apply_fog(c, wpos, CAMERA_POSITION_WORLD);
}
