// Body of every converted world material (see WorldShading): the
// unshaded StandardMaterial3D look this project uses everywhere -
// albedo x vertex colour (baked light) x texture (UV or triplanar) -
// plus the static sun shadow and the cheap fog. The render_mode line
// (cull, transparency) is put in front by WorldShading per variant.

#include "res://shaders/world_common.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
// 0 none, 1 UV, 2 world triplanar, 3 object triplanar
uniform int tex_mode = 0;
uniform vec3 uv_scale = vec3(1.0);
uniform vec3 uv_offset = vec3(0.0);
uniform float tri_sharpness = 1.0;
uniform bool use_vcol = true;
uniform vec3 emission = vec3(0.0);
uniform bool receive_shadow = true;
uniform float alpha_cut = 0.5;

varying vec3 wpos;
varying vec3 wnrm;
varying vec3 tpos;
varying vec3 tnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	tpos = tex_mode == 2 ? wpos : VERTEX;
	tnrm = tex_mode == 2 ? wnrm : NORMAL;
	tpos = tpos * uv_scale + uv_offset;
}

void fragment() {
	vec4 c = albedo;
	if (use_vcol) {
		c *= COLOR;
	}
	if (tex_mode == 1) {
		c *= texture(tex, UV * uv_scale.xy + uv_offset.xy);
	} else if (tex_mode >= 2) {
		vec3 w = pow(abs(normalize(tnrm)), vec3(tri_sharpness));
		w /= max(w.x + w.y + w.z, 0.0001);
		vec3 p = tpos * vec3(1.0, -1.0, 1.0);
		c *= texture(tex, p.xy) * w.z + texture(tex, p.xz) * w.y + texture(tex, p.zy * vec2(-1.0, 1.0)) * w.x;
	}
#ifdef SCISSOR
	if (c.a < alpha_cut) {
		discard;
	}
#endif
	vec3 n = normalize(wnrm) * (FRONT_FACING ? 1.0 : -1.0);
	vec3 col = c.rgb;
	if (receive_shadow) {
		col = sh_apply_shadow(col, wpos, n);
	}
	col += emission;
	ALBEDO = sh_apply_fog(col, wpos, CAMERA_POSITION_WORLD);
#ifdef BLEND
	ALPHA = c.a;
#endif
}
