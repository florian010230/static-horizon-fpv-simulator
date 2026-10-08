shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// Trees (Forest, TreeCreator): one material for leaves and bark - vertex
// alpha 1 is foliage, 0 is bark, 0.4 a plain colour (fruit, flowers) -
// so a tree species is one draw call per chunk.
// Lit here, not baked: MultiMesh instances are turned at random, so a
// baked sun side would point the wrong way. Same formula as Geo.shade
// (ambient + sky fill + sun * N.L), with the crown's soft "spherical"
// normals, plus the sun shadow map and fog (world_common).

#include "res://shaders/world_common.gdshaderinc"

uniform sampler2D leaves : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D bark : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float leaf_scale = 0.7;
uniform float bark_scale = 1.6;
uniform float sway = 1.0;
// The full trees (near MultiMeshes) draw only within sh_tree_near of the
// camera, cut per tree here. Done per chunk by visibility ranges, a whole
// 128 m block of trees vanished at once, measured from the block's centre
// (0.10.0: "trees in an area disappear for a moment and come back").
uniform bool near_only = false;
global uniform float sh_tree_near;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	// A light breeze: crowns sway a few cm, more toward the top.
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	if (near_only && distance(o, INV_VIEW_MATRIX[3].xyz) > sh_tree_near) {
		VERTEX = vec3(0.0); // every triangle of this tree collapses to a point
	}
	float h = max(VERTEX.y - 2.0, 0.0) * COLOR.a;
	VERTEX.x += sin(TIME * 1.1 + o.x * 0.13 + o.z * 0.07) * 0.012 * h * sway;
	VERTEX.z += sin(TIME * 0.9 + o.z * 0.11) * 0.009 * h * sway;
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnrm);
	vec3 t;
	if (COLOR.a > 0.5) {
		vec3 w = pow(abs(n), vec3(2.0));
		w /= (w.x + w.y + w.z);
		vec3 p = wpos * leaf_scale;
		t = texture(leaves, p.xz).rgb * w.y + texture(leaves, p.xy).rgb * w.z + texture(leaves, p.zy).rgb * w.x;
	} else if (COLOR.a > 0.25) {
		t = vec3(1.0); // fruit, flowers (TreeCreator): the vertex colour as is
	} else {
		vec2 uv = vec2(atan(wnrm.x, wnrm.z) * 0.318, wpos.y * 0.25 * bark_scale);
		t = texture(bark, uv).rgb;
	}
	float ndl = max(dot(n, -sh_sun.xyz), 0.0);
	vec3 light = vec3(sh_light.x + sh_light.y * (0.5 + 0.5 * n.y)) + sh_sun_color.rgb * sh_light.z * ndl;
	vec3 c = COLOR.rgb * t * light;
	c = sh_apply_shadow(c, wpos, n);
	ALBEDO = sh_apply_fog(c, wpos, CAMERA_POSITION_WORLD);
}
