shader_type canvas_item;
render_mode unshaded;

// The FPV video feed over the 3D view (FpvVideo, scripts/fpv_video.gd):
// the camera system's own look, and what a weak radio link does to it.
// The OSD is drawn on top (in real goggles it is overlaid by the
// goggles or the flight controller, so it stays crisp). One full-screen
// pass, 1-3 screen samples per pixel. It runs at full screen resolution
// (a Retina screen: 5 MP) - on the dev machine about a third of the frame
// rate, mostly the screen copy and the fill, not the samples. (A quad in
// the 3D view's transparent pass would run at the render scale, but the
// screen copy there is taken before transparent things - glass and water
// vanished under it.)
//
//  1 Analog (5.8 GHz FM video, NTSC/PAL composite): ~480 visible lines
//    (NTSC 525/PAL 625 total) and ~4.2 MHz luma bandwidth - roughly 440
//    picture elements across a line - with chroma at ~1.3 MHz (NTSC I;
//    PAL U/V similar), so colour bleeds sideways and lags right of the
//    edge it belongs to. FPV CMOS cams are tuned punchy (saturated, high
//    contrast), goggle LCDs show lifted grey blacks and a soft vignette.
//    A weak FM signal turns into "snow" (horizontally stretched noise,
//    white sparkles), the colour subcarrier is lost first (picture goes
//    black-and-white for moments), then horizontal sync slips (lines
//    tear sideways) and finally vertical sync (the picture rolls).
//    Sources: ITU-R BT.470 / SMPTE 170M (line counts, bandwidths);
//    Oscar Liang, "FPV video: analog vs digital" (breakup behaviour).
//  2 Digital (DJI O3 / Walksnail-like, H.264/H.265 at 25-50 Mbit/s,
//    1080p): sharp with a little encoder sharpening. A weak link first
//    lowers the bitrate (less detail, banding in smooth skies), then
//    loses packets: 16x16 macroblocks keep stale or smeared content
//    along a slice (to the right end of a row), the picture freezes for
//    a moment (the decoder repeats its last frame - done by FpvVideo,
//    which holds the camera) and latency grows.
//  3 HDZero (720p60 low-latency intra coding, no frame buffering): clean
//    and soft-ish at 720p; at the edge of range it breaks up suddenly in
//    horizontal stripes of corrupted 8x8 blocks, freezes, then drops.
//
// bad: 0 perfect link .. 1 lost, already per system (FpvVideo).

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform int look = 0;          // 0 clean (lens only), 1 analog, 2 digital, 3 HDZero
uniform float bad = 0.0;
uniform float seed = 0.0;      // noise time - held while the picture is frozen
uniform float fisheye = 0.0;
uniform float aspect = 1.6;
uniform float flash = 0.0;     // analog: colour lost for a moment (0..1)
uniform float tear = 0.0;      // analog: horizontal sync slipping (0..1)
uniform float roll = 0.0;      // analog: vertical roll (picture offset, 0..1)

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec3 tex(vec2 uv) {
	return texture(screen_tex, clamp(uv, vec2(0.001), vec2(0.999))).rgb;
}

// YIQ (NTSC's own colour space): luma and the two chroma components.
vec3 rgb2yiq(vec3 c) {
	return vec3(dot(c, vec3(0.299, 0.587, 0.114)), dot(c, vec3(0.596, -0.274, -0.322)), dot(c, vec3(0.211, -0.523, 0.312)));
}
vec3 yiq2rgb(vec3 y) {
	return vec3(y.x + 0.956 * y.y + 0.621 * y.z, y.x - 0.272 * y.y - 0.647 * y.z, y.x - 1.106 * y.y + 1.703 * y.z);
}

vec3 analog(vec2 uv, vec2 px) {
	float lines = 480.0;
	uv.y = fract(uv.y + roll);
	float line = floor(uv.y * lines);
	float fr = floor(seed * 30.0); // 30 frames/s (NTSC)
	// Horizontal sync: a fraction of a pixel of jitter on a good signal;
	// with a weak one whole bands of lines slip sideways.
	float j = hash12(vec2(line, fr)) - 0.5;
	float torn = step(1.0 - tear * 0.35, hash12(vec2(floor(line / 14.0), floor(seed * 12.0))));
	uv.x += j * px.x * (0.5 + 24.0 * bad * bad) + torn * (hash12(vec2(floor(line / 14.0), fr + 7.0)) - 0.3) * 0.09 * tear;
	// Luma: ~440 picture elements across; chroma ~3x softer, late by ~2
	// elements. Three samples (this pass runs at full screen resolution,
	// the dearest part of it on integrated graphics).
	float lw = 0.5 / 440.0;
	vec3 b = rgb2yiq(tex(uv));
	vec3 c = rgb2yiq(tex(uv + vec2(lw, 0.0)));
	vec3 cl = rgb2yiq(tex(uv - vec2(lw * 4.0, 0.0)));
	float y = b.x * 0.6 + c.x * 0.4;
	vec2 iq = (cl.yz + b.yz) * 0.5;
	// Camera: punchy colour and contrast; the colour fades as the signal does.
	iq *= 1.25 * (1.0 - smoothstep(0.45, 0.85, bad)) * (1.0 - flash);
	y = (y - 0.5) * 1.08 + 0.5;
	// Snow: noise in time along the line, so grains are stretched sideways.
	float g = hash12(vec2(floor(uv.x * 640.0 / (1.0 + 2.0 * hash12(vec2(line, 3.0)))), line + fr * 0.37 * lines));
	float snow = 0.025 + 0.85 * pow(bad, 1.6);
	y = mix(y, g, snow * 0.55) + (g - 0.5) * snow * 0.5;
	if (bad > 0.3) {
		// White sparkles: short bright streaks, many as the link fails.
		float sp = step(1.0 - 0.06 * bad * bad, hash12(vec2(floor(uv.x * 40.0), line * 1.7 + fr)));
		y += sp * 0.7 * smoothstep(0.3, 0.9, bad);
	}
	// The signal sinks into the noise; the flash pumps the brightness.
	y = mix(y, 0.12 + 0.3 * g, smoothstep(0.75, 1.0, bad) * 0.85) + flash * 0.12;
	vec3 col = yiq2rgb(vec3(y, iq));
	// Rolling hum bar, faint scanlines (240-line fields), goggle-LCD
	// black level and the lens's vignette.
	col *= 1.0 - 0.05 * (0.5 + 0.5 * sin((uv.y + seed * 0.11) * 6.283));
	col *= 1.0 - 0.06 * pow(sin(uv.y * 240.0 * 3.14159), 2.0);
	col = col * 0.95 + 0.035;
	return col;
}

vec3 digital(vec2 uv, vec2 px) {
	// Detail: encoder sharpening on a good link; less detail as the
	// bitrate drops (the same five taps, a wider blur).
	float lowrate = smoothstep(0.12, 0.65, bad);
	vec2 r = px * mix(1.0, 3.5, lowrate);
	vec3 c0 = tex(uv);
	vec3 n = tex(uv + vec2(r.x, r.y * 0.5)) + tex(uv - vec2(r.x, r.y * 0.5));
	float k = mix(0.3, -0.25, lowrate);
	vec3 col = c0 * (1.0 + 2.0 * k) - n * k;
	// Macroblocks (16 px of 1080) - damaged runs to the end of a slice.
	vec2 bsz = vec2(16.0 / 1080.0 / aspect, 16.0 / 1080.0);
	vec2 bp = floor(uv / bsz);
	float ep = floor(seed * 9.0);
	float pdam = smoothstep(0.35, 0.95, bad);
	float row = hash12(vec2(bp.y, ep));
	float start = hash12(vec2(bp.y, ep + 3.1)) * (1.0 / bsz.x);
	if (pdam > 0.0 && row < pdam * 0.6 && bp.x > start) {
		// Lost packets: the rest of the slice keeps stale content from
		// the wrong place (motion vectors applied to a frame it doesn't
		// have), coarse 4x4 detail; now and then a grey-green block.
		vec2 mv = (vec2(hash12(vec2(bp.y, ep + 5.0)), hash12(vec2(bp.y, ep + 9.0))) - 0.5) * bsz * vec2(5.0, 3.0);
		vec2 sub = bsz * 0.25;
		col = tex(floor((uv + mv) / sub) * sub + sub * 0.5);
		float grey = step(0.99, hash12(bp + ep));
		col = mix(col, vec3(0.42, 0.5, 0.4) * (0.8 + 0.4 * hash12(bp)), grey * 0.8);
	}
	// Banding at a low bitrate.
	if (bad > 0.35) {
		float lv = mix(255.0, 20.0, smoothstep(0.35, 0.95, bad));
		col = floor(col * lv + 0.5) / lv;
	}
	return col;
}

vec3 hdzero(vec2 uv, vec2 px) {
	// 720p: a little softer than the screen.
	vec2 h = vec2(0.5 / 1280.0, 0.5 / 720.0);
	vec3 col = (tex(uv + h) + tex(uv - h)) * 0.5;
	// Break-up: stripes of 8-line block rows hit by errors.
	vec2 bsz = vec2(8.0 / 720.0 / aspect, 8.0 / 720.0);
	vec2 bp = floor(uv / bsz);
	float ep = floor(seed * 20.0);
	float p = pow(smoothstep(0.35, 1.0, bad), 1.5);
	if (p > 0.0 && hash12(vec2(bp.y, ep)) < p * 0.5) {
		float blkn = hash12(bp + vec2(ep, 1.0));
		vec3 shifted = tex(vec2(uv.x + (hash12(vec2(bp.y, ep + 2.0)) - 0.5) * 0.2, uv.y));
		// Mostly grey sparkle with a little colour (wrongly decoded chroma).
		vec3 noise = mix(vec3(blkn), vec3(blkn, hash12(bp + vec2(ep, 2.0)), hash12(bp + vec2(ep, 3.0))), 0.35);
		col = mix(shifted, noise * 0.8, step(0.55, blkn) * 0.7);
	}
	col = mix(col, col * 0.15, smoothstep(0.85, 1.0, bad));
	return col;
}

void fragment() {
	vec2 uv = SCREEN_UV;
	if (fisheye > 0.0) {
		vec2 p = (uv - 0.5) * vec2(aspect, 1.0);
		float rc2 = dot(vec2(aspect, 1.0) * 0.5, vec2(aspect, 1.0) * 0.5);
		p *= (1.0 + fisheye * dot(p, p)) / (1.0 + fisheye * rc2);
		uv = p / vec2(aspect, 1.0) + 0.5;
	}
	vec2 px = SCREEN_PIXEL_SIZE;
	vec3 col;
	vec2 v = uv - 0.5;
	if (look == 1) {
		col = analog(uv, px);
		col *= 1.0 - dot(v, v) * 0.75;
	} else if (look == 2) {
		col = digital(uv, px);
		col *= 1.0 - dot(v, v) * 0.25;
	} else if (look == 3) {
		col = hdzero(uv, px);
		col *= 1.0 - dot(v, v) * 0.35;
	} else {
		col = tex(uv);
	}
	COLOR = vec4(max(col, vec3(0.0)), 1.0);
}
