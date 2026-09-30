class_name MapTextures
extends RefCounted

## Textures for the generated maps. Built from FastNoiseLite's seamless
## noise images (computed in C++, so a 256x256 texture costs a few ms,
## not a GDScript per-pixel loop) and cached - every map asking for
## "rust" shares one texture.

static var _cache: Dictionary = {}

static func get_tex(tex_name: String) -> Texture2D:
	if not _cache.has(tex_name):
		var img: Image = MapTextures.new().call("_" + tex_name)
		img.generate_mipmaps()
		_cache[tex_name] = ImageTexture.create_from_image(img)
	return _cache[tex_name]

## Tileable grayscale noise, remapped to lo..hi.
static func _noise(size: int, freq: float, seed_value: int, octaves: int = 4) -> Image:
	var n := FastNoiseLite.new()
	n.seed = seed_value
	n.frequency = freq
	n.fractal_octaves = octaves
	var img: Image = n.get_seamless_image(size, size)
	img.convert(Image.FORMAT_RGB8)
	return img

## Two noise layers blended through a colour ramp: base colour, a
## patchy second colour, and fine grain.
static func _ramp(size: int, a: Color, b: Color, patch_freq: float, grain: float, seed_value: int) -> Image:
	var patches := _noise(size, patch_freq, seed_value)
	var fine := _noise(size, 0.25, seed_value + 7, 2)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var p: float = smoothstep(0.35, 0.65, patches.get_pixel(x, y).r)
			var g: float = 1.0 + (fine.get_pixel(x, y).r - 0.5) * grain
			var c: Color = a.lerp(b, p) * g
			img.set_pixel(x, y, Color(c.r, c.g, c.b))
	return img

## Weathered steel: brown-orange rust over darker scale, with vertical
## run-off streaks (rain carries rust down a wall).
static func _rust() -> Image:
	var img := _ramp(256, Color(0.33, 0.2, 0.13), Color(0.55, 0.28, 0.12), 0.012, 0.35, 11)
	_streaks(img, 60, Color(0.25, 0.13, 0.07), 12)
	return img

## Painted steel gone chalky, rust blooming through.
static func _paint_rust() -> Image:
	return _ramp(256, Color(0.5, 0.5, 0.48), Color(0.5, 0.27, 0.12), 0.02, 0.25, 12)

static func _corrugated_rust() -> Image:
	var img := _rust()
	var ribs: int = 8
	for x in range(256):
		var v: float = 0.78 + 0.22 * sin(x / 256.0 * ribs * TAU)
		for y in range(256):
			img.set_pixel(x, y, img.get_pixel(x, y) * v)
	return img

## Old concrete: grey with damp stains, dark streaks from the top.
static func _old_concrete() -> Image:
	var img := _ramp(256, Color(0.52, 0.51, 0.48), Color(0.36, 0.36, 0.33), 0.015, 0.2, 13)
	_streaks(img, 40, Color(0.28, 0.28, 0.26), 14)
	return img

static func _dark_brick() -> Image:
	var img := _ramp(256, Color(0.42, 0.2, 0.15), Color(0.3, 0.16, 0.13), 0.05, 0.3, 15)
	var mortar := Color(0.36, 0.34, 0.31)
	for row in range(16):
		var y0: int = row * 16
		img.fill_rect(Rect2i(0, y0, 256, 2), mortar)
		var off: int = 0 if row % 2 == 0 else 16
		for col in range(9):
			img.fill_rect(Rect2i((col * 32 + off) % 256, y0, 2, 16), mortar)
	return img

static func _forest_floor() -> Image:
	return _ramp(256, Color(0.2, 0.26, 0.12), Color(0.3, 0.24, 0.14), 0.02, 0.4, 16)

static func _meadow() -> Image:
	return _ramp(256, Color(0.26, 0.4, 0.16), Color(0.36, 0.46, 0.2), 0.015, 0.3, 17)

static func _slag() -> Image:
	return _ramp(256, Color(0.2, 0.19, 0.18), Color(0.34, 0.3, 0.26), 0.04, 0.5, 18)

static func _cracked_asphalt() -> Image:
	var img := _ramp(256, Color(0.23, 0.23, 0.24), Color(0.3, 0.3, 0.29), 0.03, 0.3, 19)
	# Cracks with weeds: a few random-walk lines, dark with green edges.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20
	for i in range(6):
		var p := Vector2(rng.randf() * 256, rng.randf() * 256)
		var dir := Vector2.from_angle(rng.randf() * TAU)
		for s in range(120):
			dir = dir.rotated(rng.randf_range(-0.4, 0.4))
			p = (p + dir).posmod(256.0)
			img.set_pixel(int(p.x), int(p.y), Color(0.1, 0.1, 0.1))
			img.set_pixel(int(p.x + 1) % 256, int(p.y), Color(0.25, 0.33, 0.15))
	return img

## Rubber safety flooring (playgrounds): red speckle.
static func _rubber() -> Image:
	return _ramp(128, Color(0.55, 0.16, 0.12), Color(0.45, 0.13, 0.1), 0.2, 0.6, 21)

static func _sand() -> Image:
	return _ramp(128, Color(0.82, 0.72, 0.52), Color(0.74, 0.63, 0.44), 0.05, 0.25, 22)

static func _wood() -> Image:
	var img := _ramp(128, Color(0.55, 0.38, 0.22), Color(0.48, 0.32, 0.18), 0.08, 0.2, 23)
	for i in range(8):
		img.fill_rect(Rect2i(0, i * 16, 128, 1), Color(0.3, 0.2, 0.12))
	return img

## Race-gate padding: plain mesh fabric look.
static func _fabric() -> Image:
	var img := _noise(64, 0.3, 24, 1)
	for y in range(64):
		for x in range(64):
			var v: float = 0.85 + 0.15 * float((x + y) % 4 < 2) + (img.get_pixel(x, y).r - 0.5) * 0.1
			img.set_pixel(x, y, Color(v, v, v))
	return img

## Short grass for a race field, with mowing stripes (2 per tile).
static func _mown_grass() -> Image:
	var img := _meadow()
	for x in range(256):
		var v: float = 1.0 if (x / 128) % 2 == 0 else 0.88
		for y in range(256):
			img.set_pixel(x, y, img.get_pixel(x, y) * v)
	return img

## Neutral rock: grey-brown with strata bands - tinted per vertex by
## the maps (terrain tint), so one texture serves cliffs and scree.
static func _rock() -> Image:
	var img := _ramp(256, Color(0.62, 0.6, 0.57), Color(0.5, 0.48, 0.45), 0.02, 0.45, 25)
	for y in range(256):
		var band: float = 0.92 + 0.08 * sin(y / 256.0 * TAU * 6.0 + sin(y * 0.3))
		for x in range(256):
			img.set_pixel(x, y, img.get_pixel(x, y) * band)
	return img

## Neutral ground for tinted terrain: fine noise around mid grey.
static func _ground_neutral() -> Image:
	return _ramp(256, Color(0.8, 0.8, 0.8), Color(0.66, 0.66, 0.66), 0.03, 0.5, 26)

## Painted ribbed steel (containers): neutral grey, tinted per colour,
## with a little grime.
static func _corrugated_plain() -> Image:
	var img := _ramp(128, Color(0.9, 0.9, 0.9), Color(0.72, 0.7, 0.68), 0.04, 0.15, 27)
	for x in range(128):
		var v: float = 0.8 + 0.2 * sin(x / 128.0 * 10.0 * TAU)
		for y in range(128):
			img.set_pixel(x, y, img.get_pixel(x, y) * v)
	return img

## Track bed seen from above: ballast with a sleeper every 0.6 m
## (one tile = 1.2 m = two sleepers). _x: sleepers across a track that
## runs along world x; _z: along world z (under the top-down world
## projection the stripes must be perpendicular to the track).
static func _trackbed_x() -> Image:
	return _trackbed(true)

static func _trackbed_z() -> Image:
	return _trackbed(false)

static func _trackbed(across_x: bool) -> Image:
	var img := _ramp(128, Color(0.52, 0.5, 0.47), Color(0.42, 0.4, 0.38), 0.1, 0.6, 28)
	var sleeper := Color(0.24, 0.2, 0.17)
	for k in range(2):
		var c0: int = 16 + k * 64
		for i in range(c0, c0 + 22):
			for j in range(128):
				if across_x:
					img.set_pixel(i, j, img.get_pixel(i, j).lerp(sleeper, 0.85))
				else:
					img.set_pixel(j, i, img.get_pixel(j, i).lerp(sleeper, 0.85))
	return img

## City facade: windows in a grid (one tile = 3.5 m storey x 3.5 m bay).
static func _facade() -> Image:
	var img := _ramp(128, Color(0.78, 0.74, 0.68), Color(0.7, 0.66, 0.6), 0.05, 0.15, 29)
	img.fill_rect(Rect2i(30, 34, 68, 64), Color(0.22, 0.26, 0.3))
	img.fill_rect(Rect2i(30, 64, 68, 3), Color(0.6, 0.6, 0.6))
	return img

static func _streaks(img: Image, count: int, color: Color, seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var size: int = img.get_width()
	for i in range(count):
		var x: int = rng.randi_range(0, size - 1)
		var y0: int = rng.randi_range(0, size - 1)
		var length: int = rng.randi_range(size / 6, size / 2)
		var w: int = rng.randi_range(1, 3)
		for j in range(length):
			var y: int = (y0 + j) % size
			var t: float = 0.35 * (1.0 - float(j) / length)
			for k in range(w):
				var px: int = (x + k) % size
				img.set_pixel(px, y, img.get_pixel(px, y).lerp(color, t))
