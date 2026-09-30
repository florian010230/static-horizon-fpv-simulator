shader_type spatial;

// Ground surfaces (grass, roads, sidewalks, paving, gravel, fields) with
// the map's baked sun shadows multiplied in. Texture is projected in
// world space from above (so every road piece tiles the same), and the
// shadow mask is a top-down image of where shadows fall (FakeShadows).

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap, repeat_enable;
uniform vec4 albedo_color : source_color = vec4(1.0);
uniform float tile = 6.0;
uniform float roughness = 0.9;
uniform sampler2D shadow_mask : filter_linear, repeat_disable;
uniform vec2 mask_origin = vec2(-250.0);
uniform vec2 mask_size = vec2(500.0);
uniform float shadow_strength = 0.0;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, world_pos.xz / tile).rgb * albedo_color.rgb;
	vec2 uv = (world_pos.xz - mask_origin) / mask_size;
	float m = 0.0;
	if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0) {
		m = texture(shadow_mask, uv).r;
	}
	ALBEDO = c * (1.0 - shadow_strength * m);
	ROUGHNESS = roughness;
}
