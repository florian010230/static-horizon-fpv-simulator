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

## Foliage (grey, tinted per species by the material): bright leaf
## clusters with dark gaps between them, so a crown reads as leaves
## rather than a painted ball.
static func _foliage() -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.seed = 31
	n.frequency = 0.09
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE
	var cells: Image = n.get_seamless_image(128, 128)
	var fine := _noise(128, 0.3, 32, 2)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for y in range(128):
		for x in range(128):
			var d: float = cells.get_pixel(x, y).r
			var v: float = lerpf(1.0, 0.45, smoothstep(0.35, 0.8, d)) * (0.85 + fine.get_pixel(x, y).r * 0.3)
			img.set_pixel(x, y, Color(v, v * 1.02, v * 0.95))
	return img

## Bark: vertical furrows (grey, tinted per species).
static func _bark() -> Image:
	var n := FastNoiseLite.new()
	n.seed = 33
	n.frequency = 0.04
	var img := Image.create(64, 64, false, Image.FORMAT_RGB8)
	var base: Image = n.get_seamless_image(64, 64)
	for y in range(64):
		for x in range(64):
			var f: float = 0.5 + 0.5 * sin(x * TAU * 6.0 / 64.0 + base.get_pixel(x, y).r * 6.0)
			var v: float = lerpf(0.55, 1.0, f) * (0.85 + base.get_pixel(x, (y * 3) % 64).r * 0.3)
			img.set_pixel(x, y, Color(v, v, v))
	return img

## Meadow: two greens in patches, darker clumps, fine blade grain and a
## sprinkle of dry stalks and small flowers.
static func _meadow() -> Image:
	var img := _ramp(256, Color(0.25, 0.39, 0.15), Color(0.35, 0.45, 0.19), 0.015, 0.35, 17)
	var clumps := _noise(256, 0.06, 171, 3)
	var rng := RandomNumberGenerator.new()
	rng.seed = 172
	for y in range(256):
		for x in range(256):
			var c: float = clumps.get_pixel(x, y).r
			if c > 0.62:
				img.set_pixel(x, y, img.get_pixel(x, y) * (1.0 - (c - 0.62) * 0.9))
	for i in range(900):
		var x: int = rng.randi() % 256
		var y: int = rng.randi() % 256
		var k: float = rng.randf()
		var col: Color = Color(0.55, 0.52, 0.3) if k < 0.6 else (Color(0.9, 0.88, 0.8) if k < 0.85 else Color(0.85, 0.75, 0.2))
		img.set_pixel(x, y, img.get_pixel(x, y).lerp(col, 0.6))
	return img

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

## Office-tower curtain wall: blue-grey glass, mullions every 1.5 m,
## spandrel bands at each 3.5 m floor (one tile = 3 m x 3.5 m).
static func _curtain_wall() -> Image:
	var img := _ramp(128, Color(0.28, 0.36, 0.46), Color(0.36, 0.45, 0.55), 0.03, 0.12, 30)
	img.fill_rect(Rect2i(0, 100, 128, 28), Color(0.2, 0.22, 0.25))
	for x in [0, 63]:
		img.fill_rect(Rect2i(x, 0, 3, 128), Color(0.62, 0.64, 0.66))
	return img

## Fresh asphalt: dark, fine aggregate speckle, faint patching.
static func _asphalt() -> Image:
	var img := _ramp(256, Color(0.2, 0.2, 0.21), Color(0.25, 0.25, 0.25), 0.02, 0.55, 40)
	var speck := _noise(256, 0.9, 41, 1)
	for y in range(256):
		for x in range(256):
			var v: float = speck.get_pixel(x, y).r
			if v > 0.72:
				img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.42, 0.41, 0.4), (v - 0.72) * 2.5))
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(3):
		var r := Rect2i(rng.randi() % 200, rng.randi() % 200, rng.randi_range(20, 56), rng.randi_range(14, 40))
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				img.set_pixel(x, y, img.get_pixel(x, y) * 0.88)
	return img

## Railway ballast: crushed grey stone (cellular noise = stones with
## dark gaps between them), a little rust-brown from brake dust.
static func _ballast() -> Image:
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_CELLULAR
	n.frequency = 0.09
	n.seed = 43
	n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
	var gaps: Image = n.get_seamless_image(256, 256)
	n.cellular_return_type = FastNoiseLite.RETURN_CELL_VALUE
	var cells: Image = n.get_seamless_image(256, 256)
	var tint := _noise(256, 0.01, 44, 2)
	var img := Image.create(256, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(256):
			var g: float = clampf(gaps.get_pixel(x, y).r * 2.2, 0.0, 1.0)
			var v: float = 0.4 + cells.get_pixel(x, y).r * 0.28
			var c := Color(v, v * 0.97, v * 0.93).lerp(Color(0.42, 0.3, 0.22), smoothstep(0.55, 0.8, tint.get_pixel(x, y).r) * 0.5)
			img.set_pixel(x, y, c * lerpf(0.35, 1.0, g))
	return img

## Track bed for UV-mapped tracks (Rails): across = image x (the 2.8 m
## bed), along = image y (1.2 m = two concrete sleepers on ballast),
## rail pads where the rails sit.
static func _sleepers() -> Image:
	var bal := _ballast()
	bal.resize(128, 128)
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	img.blit_rect(bal, Rect2i(0, 0, 128, 128), Vector2i.ZERO)
	var grain := _noise(128, 0.3, 45, 2)
	for k in range(2):
		var y0: int = 18 + k * 64
		for y in range(y0, y0 + 26):
			for x in range(3, 125):
				var v: float = 0.6 + (grain.get_pixel(x, y).r - 0.5) * 0.12
				var edge: bool = y == y0 or y == y0 + 25 or x == 3 or x == 124
				img.set_pixel(x, y, Color(v, v * 0.99, v * 0.96) * (0.75 if edge else 1.0))
			for rx in [30, 98]:
				for x in range(rx - 5, rx + 6):
					img.set_pixel(x, y, Color(0.16, 0.16, 0.17))
	return img

## Concrete paving slabs (pavements): 8 x 8 slabs per tile, each a
## slightly different grey, dark joints.
static func _paving_slabs() -> Image:
	var img := _ramp(256, Color(0.62, 0.61, 0.58), Color(0.54, 0.53, 0.5), 0.03, 0.2, 46)
	var rng := RandomNumberGenerator.new()
	rng.seed = 47
	for j in range(8):
		for i in range(8):
			var f: float = rng.randf_range(0.9, 1.08)
			for y in range(j * 32, j * 32 + 32):
				for x in range(i * 32, i * 32 + 32):
					var joint: bool = (x % 32) < 1 or (y % 32) < 1
					img.set_pixel(x, y, img.get_pixel(x, y) * (0.62 if joint else f))
	return img

## Gravel verge / site ground: brownish grey stones and dust.
static func _gravel_verge() -> Image:
	var img := _ballast()
	var dust := _ramp(256, Color(0.55, 0.5, 0.42), Color(0.48, 0.44, 0.37), 0.02, 0.3, 48)
	for y in range(256):
		for x in range(256):
			img.set_pixel(x, y, img.get_pixel(x, y).lerp(dust.get_pixel(x, y), 0.55))
	return img

## Clay roof tiles: rows of overlapping tiles, weathered.
static func _roof_tiles() -> Image:
	var img := _ramp(128, Color(0.62, 0.3, 0.2), Color(0.5, 0.27, 0.2), 0.05, 0.25, 49)
	for row in range(8):
		var y0: int = row * 16
		var off: int = 0 if row % 2 == 0 else 8
		for y in range(y0, y0 + 16):
			var shade: float = 0.72 + 0.28 * float(y - y0) / 15.0
			for x in range(128):
				var c: Color = img.get_pixel(x, y) * shade
				if (x + off) % 16 == 0:
					c *= 0.7
				img.set_pixel(x, y, c)
	return img

## Formwork concrete (fresh site concrete): light grey, panel joints
## every 2.5 x 1.25 m, tie holes (one tile = 2.5 m).
static func _formwork() -> Image:
	var img := _ramp(256, Color(0.7, 0.7, 0.68), Color(0.62, 0.62, 0.6), 0.02, 0.15, 50)
	for y in range(256):
		for x in range(256):
			if x % 256 < 2 or y % 128 < 2:
				img.set_pixel(x, y, img.get_pixel(x, y) * 0.7)
	for hx in [40, 128, 216]:
		for hy in [32, 96, 160, 224]:
			img.fill_rect(Rect2i(hx - 2, hy - 2, 5, 5), Color(0.3, 0.3, 0.3))
	return img

## Two bays x two storeys of a plastered city building (one tile = 7 m):
## framed windows with sills and a cross bar, some with curtains, some
## lit from inside, a cornice line at each floor.
static func _facade_b() -> Image:
	var img := _ramp(256, Color(0.8, 0.76, 0.69), Color(0.72, 0.68, 0.62), 0.04, 0.12, 51)
	var rng := RandomNumberGenerator.new()
	rng.seed = 52
	for fy in range(2):
		img.fill_rect(Rect2i(0, fy * 128 + 122, 256, 6), Color(0.66, 0.62, 0.56))
		for fx in range(2):
			var x0: int = fx * 128 + 36
			var y0: int = fy * 128 + 30
			img.fill_rect(Rect2i(x0 - 5, y0 - 5, 66, 82), Color(0.9, 0.88, 0.84))
			var k: float = rng.randf()
			var glass: Color = Color(0.2, 0.24, 0.28) if k < 0.6 else (Color(0.62, 0.52, 0.38) if k < 0.8 else Color(0.85, 0.75, 0.5))
			img.fill_rect(Rect2i(x0, y0, 56, 72), glass)
			img.fill_rect(Rect2i(x0 + 26, y0, 4, 72), Color(0.9, 0.9, 0.88))
			img.fill_rect(Rect2i(x0, y0 + 24, 56, 3), Color(0.9, 0.9, 0.88))
			img.fill_rect(Rect2i(x0 - 8, y0 + 76, 72, 6), Color(0.6, 0.58, 0.54))
	return img

## Shop fronts for ground floors (one tile = 7 m wide x 3.5 m): big
## windows, a door, an awning band.
static func _shopfront() -> Image:
	var img := _ramp(256, Color(0.34, 0.33, 0.32), Color(0.28, 0.28, 0.28), 0.05, 0.1, 53)
	var tmp := Image.create(256, 128, false, Image.FORMAT_RGB8)
	tmp.blit_rect(img, Rect2i(0, 0, 256, 128), Vector2i.ZERO)
	tmp.fill_rect(Rect2i(0, 0, 256, 22), Color(0.72, 0.2, 0.15))
	tmp.fill_rect(Rect2i(12, 34, 150, 84), Color(0.55, 0.6, 0.62))
	tmp.fill_rect(Rect2i(14, 36, 146, 80), Color(0.25, 0.3, 0.33))
	tmp.fill_rect(Rect2i(184, 40, 50, 88), Color(0.18, 0.2, 0.22))
	return tmp

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
