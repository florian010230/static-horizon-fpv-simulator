shader_type spatial;
render_mode unshaded, cull_back, fog_disabled;

#include "res://shaders/world_common.gdshaderinc"

// Ground layers of the generated maps (terrain, paving, roads, road
// markings). Stacked ground surfaces lie a few cm apart - at a few
// hundred metres the depth buffer can't tell them apart any more and
// they flicker through each other (z-fighting). Each layer is drawn a
// small fraction of its distance closer to the camera (`pull`), which
// keeps the upper layer in front at any distance while moving it by
// only millimetres up close.
//
// Otherwise it matches Geo.tex_mat: world-space triplanar texture
// (same projection as StandardMaterial3D's world triplanar), tint,
// baked light from the vertex colour, the sun shadow map and fog
// (world_common.gdshaderinc). Plus a large-scale variation
// (`macro`) so a tiled ground texture doesn't read as a repeating grid.

uniform sampler2D tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_tex = true;
// Sample by the mesh's UVs instead of world triplanar (Geo.sweep beds).
uniform bool use_uv = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform float scale = 0.25;
uniform float pull = 0.0;
uniform float macro = 0.0;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vec4 vp = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vp.xyz *= (1.0 - pull);
	POSITION = PROJECTION_MATRIX * vp;
}

void fragment() {
	vec3 c = tint.rgb * COLOR.rgb;
	if (use_tex && use_uv) {
		c *= texture(tex, UV).rgb;
	} else if (use_tex) {
		vec3 w = pow(abs(wnrm), vec3(4.0));
		w /= (w.x + w.y + w.z);
		vec3 p = wpos * scale * vec3(1.0, -1.0, 1.0);
		vec3 t = texture(tex, p.xy).rgb * w.z + texture(tex, p.xz).rgb * w.y + texture(tex, p.zy * vec2(-1.0, 1.0)).rgb * w.x;
		c *= t;
	}
	if (macro > 0.0) {
		// Two very low-frequency samples of the texture's own luminance.
		// Relative to the texture's mean (its smallest mip level).
		float mean = max(dot(textureLod(tex, vec2(0.5), 12.0).rgb, vec3(0.333)), 0.05);
		float m1 = dot(texture(tex, wpos.xz * scale * 0.061).rgb, vec3(0.333)) / mean;
		float m2 = dot(texture(tex, wpos.zx * scale * 0.017 + vec2(0.37, 0.71)).rgb, vec3(0.333)) / mean;
		c *= clamp(1.0 + macro * ((m1 - 1.0) * 1.2 + (m2 - 1.0) * 0.9), 0.6, 1.4);
	}
	c = sh_surface_detail(c, wpos, normalize(wnrm), CAMERA_POSITION_WORLD, true);
	c = sh_apply_shadow(c, wpos, normalize(wnrm));
	c = sh_apply_fog(c, wpos, CAMERA_POSITION_WORLD);
	ALBEDO = c;
}
