shader_type spatial;
render_mode unshaded, cull_disabled, fog_disabled;

// The quad models (DroneFrameBuilder): a small studio light rig computed
// in view space - key light from the upper left, a fill, a rim from
// behind, Blinn specular - so the menu's turntable drone always looks lit
// the same way, on every GPU (the engine's lights do nothing on the dev
// machine's Intel GPU, see CLAUDE.md). Carbon parts sample a twill weave.

uniform vec4 albedo : source_color = vec4(1.0);
uniform sampler2D weave : source_color, filter_linear_mipmap, repeat_enable;
uniform bool use_weave = false;
uniform float weave_scale = 60.0;
uniform float metallic = 0.0;
uniform float gloss = 0.4;

varying vec3 lpos;
varying vec3 lnrm;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 base = albedo.rgb;
	if (use_weave) {
		vec3 w = abs(normalize(lnrm));
		vec2 uv = w.y > 0.6 ? lpos.xz : (w.x > w.z ? lpos.zy : lpos.xy);
		base *= texture(weave, uv * weave_scale).rgb;
	}
	vec3 key = normalize(vec3(-0.45, 0.75, 0.55));
	vec3 fill = normalize(vec3(0.7, 0.15, 0.45));
	float dk = max(dot(n, key), 0.0);
	float df = max(dot(n, fill), 0.0);
	vec3 col = base * (0.24 + 0.8 * dk + 0.22 * df);
	vec3 h = normalize(key + vec3(0.0, 0.0, 1.0));
	float spec = pow(max(dot(n, h), 0.0), mix(8.0, 90.0, gloss)) * mix(0.25, 1.1, gloss);
	col += mix(vec3(0.06), base * 1.4, metallic) * spec * 3.0;
	float rim = pow(1.0 - max(n.z, 0.0), 3.0);
	col += vec3(0.55, 0.62, 0.75) * rim * 0.22;
	ALBEDO = col;
	// ALPHA_LINE (the props' see-through variant writes ALPHA here)
}
