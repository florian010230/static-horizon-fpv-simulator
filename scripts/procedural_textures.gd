class_name ProceduralTextures

## Small tileable textures generated at runtime, so the project needs no
## external image assets (keeps it dependency-free and easy to share).

static func grass_texture(size: int = 128) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 1
	noise.frequency = 0.08
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var low := Color(0.18, 0.32, 0.15)
	var high := Color(0.32, 0.48, 0.22)
	for y in range(size):
		for x in range(size):
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			img.set_pixel(x, y, low.lerp(high, n))
	return ImageTexture.create_from_image(img)

static func brick_texture(size: int = 128) -> ImageTexture:
	var brick_color := Color(0.5, 0.27, 0.2)
	var mortar_color := Color(0.72, 0.69, 0.64)
	var window_color := Color(0.25, 0.32, 0.38)
	var window_frame := Color(0.85, 0.83, 0.78)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var brick_h: int = size / 8
	var brick_w: int = size / 4
	var mortar: int = max(1, size / 48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	# A 2x2 grid of windows per tile, brick fills the rest - reads as a
	# regular office/apartment facade once the texture repeats across a
	# whole building face.
	var cell: int = size / 2
	var win_margin: int = cell / 5
	for y in range(size):
		var row: int = int(y / float(brick_h))
		var offset: int = (brick_w / 2) if (row % 2 == 1) else 0
		var cy: int = y % cell
		for x in range(size):
			var cx: int = x % cell
			if cx >= win_margin and cx < cell - win_margin and cy >= win_margin and cy < cell - win_margin:
				var is_frame: bool = cx < win_margin + 2 or cx >= cell - win_margin - 2 or cy < win_margin + 2 or cy >= cell - win_margin - 2
				img.set_pixel(x, y, window_frame if is_frame else window_color)
				continue
			var xx: int = (x + offset) % brick_w
			var yy: int = y % brick_h
			if xx < mortar or yy < mortar:
				img.set_pixel(x, y, mortar_color)
			else:
				var shade: float = 1.0 + rng.randf_range(-0.06, 0.06)
				img.set_pixel(x, y, Color(brick_color.r * shade, brick_color.g * shade, brick_color.b * shade))
	return ImageTexture.create_from_image(img)

## Baked panel seams + an AO gradient toward each seam, in place of real
## shadows (which cost real-time rendering): reads as distinct tunnel
## segments with a sense of depth even under flat ambient lighting.
static func concrete_texture(size: int = 128) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.05
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var low := Color(0.38, 0.38, 0.4)
	var high := Color(0.5, 0.5, 0.52)
	var seam_color := Color(0.16, 0.16, 0.18)
	var panel_h: int = size / 2
	var seam_w: int = max(1, size / 32)
	for y in range(size):
		var py: int = y % panel_h
		var edge_dist: float = min(py, panel_h - py) / float(panel_h / 2)
		var ao: float = clamp(0.4 + 0.6 * edge_dist, 0.4, 1.0)
		var is_seam: bool = py < seam_w or py >= panel_h - seam_w
		for x in range(size):
			if is_seam:
				img.set_pixel(x, y, seam_color)
				continue
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var c: Color = low.lerp(high, n)
			img.set_pixel(x, y, Color(c.r * ao, c.g * ao, c.b * ao))
	return ImageTexture.create_from_image(img)

## Fine aggregate speckle plus a few tire-wear streaks down the middle of
## each lane - reads as worn asphalt rather than a flat gray slab once
## tiled down the street's length.
static func asphalt_texture(size: int = 128) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 4
	noise.frequency = 0.35
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var low := Color(0.16, 0.16, 0.17)
	var high := Color(0.24, 0.24, 0.26)
	var wear := Color(0.12, 0.12, 0.13)
	for y in range(size):
		for x in range(size):
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var c: Color = low.lerp(high, n)
			var dist_from_lane_center: float = absf((x % (size / 2)) - size / 4.0) / (size / 4.0)
			if dist_from_lane_center < 0.15:
				c = c.lerp(wear, 0.5)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## A concrete yard slab: a grid of expansion joints plus a few
## randomized oil-stain blotches - reads as a used industrial yard rather
## than a flat gray plane once tiled across the whole factory ground.
static func factory_ground_texture(size: int = 256) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 5
	noise.frequency = 0.06
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var low := Color(0.52, 0.52, 0.54)
	var high := Color(0.62, 0.62, 0.64)
	var joint_color := Color(0.32, 0.32, 0.34)
	var joint_w: int = max(1, size / 64)
	var cell: int = size / 4
	for y in range(size):
		var on_joint_y: bool = (y % cell) < joint_w
		for x in range(size):
			var on_joint: bool = on_joint_y or (x % cell) < joint_w
			if on_joint:
				img.set_pixel(x, y, joint_color)
				continue
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			img.set_pixel(x, y, low.lerp(high, n))

	# A handful of soft dark oil-stain blotches, fixed seed so the tile
	# stays deterministic/reproducible like every other texture here.
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for i in range(6):
		var cx: float = rng.randf_range(0, size)
		var cy: float = rng.randf_range(0, size)
		var r: float = rng.randf_range(size * 0.04, size * 0.11)
		var y0: int = max(0, int(cy - r))
		var y1: int = min(size, int(cy + r))
		var x0: int = max(0, int(cx - r))
		var x1: int = min(size, int(cx + r))
		for y in range(y0, y1):
			for x in range(x0, x1):
				var d: float = Vector2(x - cx, y - cy).length()
				if d < r:
					var t: float = (1.0 - d / r) * 0.5
					img.set_pixel(x, y, img.get_pixel(x, y).lerp(Color(0.14, 0.13, 0.12), t))
	return ImageTexture.create_from_image(img)

static func siding_texture(size: int = 128) -> ImageTexture:
	var plank_color := Color(0.72, 0.55, 0.4)
	var line_color := Color(0.5, 0.37, 0.26)
	var window_color := Color(0.55, 0.68, 0.72)
	var window_frame := Color(0.95, 0.92, 0.85)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var plank_h: int = size / 10
	var line_h: int = max(1, size / 64)
	var win_margin: int = size / 3
	for y in range(size):
		var is_line: bool = (y % plank_h) < line_h
		var in_win_y: bool = y >= win_margin and y < size - win_margin
		for x in range(size):
			var in_win_x: bool = x >= win_margin and x < size - win_margin
			if in_win_x and in_win_y:
				var is_frame: bool = x < win_margin + 2 or x >= size - win_margin - 2 or y < win_margin + 2 or y >= size - win_margin - 2
				img.set_pixel(x, y, window_frame if is_frame else window_color)
				continue
			var c: Color = line_color if is_line else plank_color
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

# --- Building surface patterns (see BuildingStyles) ----------------------
# These return Images rather than textures: BuildingStyles adds mipmaps
# and caches them. Most are near-white/neutral on purpose - the actual
# color comes from the building's vertex colors (wall bands, tint, fake
# AO), so one pattern serves many paint colors. The bigger ones are
# built from fill_rect() calls instead of per-pixel loops: per-pixel
# work in GDScript is slow enough to show up as startup time on the
# weak hardware this project targets.

static func plaster_image(size: int, lo: float, hi: float, seed_value: int) -> Image:
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.12
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	for y in range(size):
		for x in range(size):
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			var v: float = lerpf(lo, hi, n)
			img.set_pixel(x, y, Color(v, v, v))
	return img

## Wooden floor boards: 10 boards per tile (a 2.4 m tile -> 24 cm
## boards), each its own tone, with staggered end joints.
static func planks_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var boards: int = 10
	var bw: int = size / boards
	for b in range(boards):
		var tone: float = rng.randf_range(0.82, 1.08)
		var base := Color(0.62 * tone, 0.43 * tone, 0.26 * tone)
		img.fill_rect(Rect2i(b * bw, 0, bw, size), base)
		# a few grain streaks
		for g in range(4):
			var gx: int = b * bw + rng.randi_range(2, bw - 3)
			img.fill_rect(Rect2i(gx, 0, 1, size), base.darkened(0.12))
		img.fill_rect(Rect2i(b * bw, 0, 1, size), Color(0.25, 0.16, 0.09))
		var joint: int = rng.randi_range(0, size - 1)
		img.fill_rect(Rect2i(b * bw, joint, bw, 1), Color(0.25, 0.16, 0.09))
	return img

## Plaster ceiling with one dark exposed timber beam per tile.
static func beams_image(size: int) -> Image:
	var img := plaster_image(size, 0.9, 1.0, 22)
	var beam_w: int = int(size * 0.075)
	var x0: int = size / 2 - beam_w / 2
	img.fill_rect(Rect2i(x0, 0, beam_w, size), Color(0.36, 0.24, 0.14))
	img.fill_rect(Rect2i(x0, 0, 2, size), Color(0.24, 0.15, 0.08))
	img.fill_rect(Rect2i(x0 + beam_w - 2, 0, 2, size), Color(0.24, 0.15, 0.08))
	# the beam's shadow on the plaster next to it
	img.fill_rect(Rect2i(x0 + beam_w, 0, beam_w / 2, size), Color(0.8, 0.8, 0.8))
	return img

## Subtle vertical board joints - wood panelling low on a gym wall,
## block joints above (both just read as texture, color from bands).
static func boards_image(size: int) -> Image:
	var img := plaster_image(size, 0.9, 1.0, 23)
	var n: int = 8
	for i in range(n):
		img.fill_rect(Rect2i(i * size / n, 0, 1, size), Color(0.7, 0.7, 0.7))
	return img

## Trapezoidal profiled steel sheet: a sine-shaded rib pattern.
static func corrugated_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var ribs: int = 6
	for x in range(size):
		var v: float = 0.82 + 0.18 * sin(x / float(size) * ribs * TAU)
		img.fill_rect(Rect2i(x, 0, 1, size), Color(v, v, v))
	return img

## Speckled sheet flooring.
static func linoleum_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.92, 0.92, 0.92))
	var rng := RandomNumberGenerator.new()
	rng.seed = 24
	for i in range(size * size / 10):
		var v: float = rng.randf_range(0.7, 1.0)
		img.set_pixel(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), Color(v, v, v))
	return img

## Horizontal wooden cladding boards (no painted window - the houses
## have real windows now).
static func siding_plain_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.74, 0.57, 0.41))
	var plank_h: int = size / 10
	for y in range(0, size, plank_h):
		img.fill_rect(Rect2i(0, y, size, maxi(1, size / 64)), Color(0.5, 0.37, 0.26))
		img.fill_rect(Rect2i(0, y + maxi(1, size / 64), size, 1), Color(0.8, 0.63, 0.47))
	return img

static func brick_plain_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	img.fill(Color(0.72, 0.69, 0.64))
	var rng := RandomNumberGenerator.new()
	rng.seed = 25
	var bh: int = size / 8
	var bw: int = size / 4
	var m: int = maxi(1, size / 48)
	for row in range(8):
		var off: int = (bw / 2) if row % 2 == 1 else 0
		for col in range(-1, 5):
			var shade: float = rng.randf_range(0.88, 1.1)
			img.fill_rect(Rect2i(col * bw + off + m, row * bh + m, bw - m, bh - m), Color(0.52 * shade, 0.28 * shade, 0.2 * shade))
	return img

## Precast concrete facade panels with dark joints.
static func concrete_panels_image(size: int) -> Image:
	var img := plaster_image(size, 0.82, 0.98, 26)
	img.fill_rect(Rect2i(0, 0, size, 2), Color(0.4, 0.4, 0.4))
	img.fill_rect(Rect2i(0, 0, 2, size), Color(0.4, 0.4, 0.4))
	return img

## Clay roof tiles, neutral - HollowBuilding.roof_color tints them.
static func roof_tiles_image(size: int) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var rows: int = 8
	var rh: int = size / rows
	for r in range(rows):
		for y in range(rh):
			var v: float = lerpf(1.0, 0.7, y / float(rh))
			img.fill_rect(Rect2i(0, r * rh + y, size, 1), Color(v, v, v))
		var off: int = (size / 12) if r % 2 == 1 else 0
		for c in range(7):
			img.fill_rect(Rect2i(c * size / 6 + off, r * rh, 1, rh), Color(0.6, 0.6, 0.6))
	return img

## 600 mm suspended ceiling: a 4x4 grid of tiles per 2.4 m texture tile
## with one recessed 600x600 light panel. emit=true returns just the
## lamp as a white-on-black emission mask.
static func ceiling_tiles_image(size: int, emit: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var cell: int = size / 4
	var lamp := Rect2i(cell + 3, cell + 3, cell * 2 - 6, cell - 6)
	if emit:
		img.fill(Color.BLACK)
		img.fill_rect(lamp, Color(0.95, 0.95, 0.9))
		return img
	img.fill(Color(0.9, 0.9, 0.88))
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	for i in range(size * size / 14):
		var v: float = rng.randf_range(0.78, 0.88)
		img.set_pixel(rng.randi_range(0, size - 1), rng.randi_range(0, size - 1), Color(v, v, v))
	for i in range(4):
		img.fill_rect(Rect2i(i * cell, 0, 2, size), Color(0.62, 0.62, 0.62))
		img.fill_rect(Rect2i(0, i * cell, size, 2), Color(0.62, 0.62, 0.62))
	img.fill_rect(lamp.grow(2), Color(0.55, 0.55, 0.55))
	img.fill_rect(lamp, Color(1, 1, 0.97))
	return img

## Factory roof from inside: dark steel deck, lighter purlins, and a
## ridge skylight strip (the classic sawtooth/strip rooflight of an
## industrial hall) that glows.
static func skylight_image(size: int, emit: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var strip := Rect2i(size * 2 / 5, 0, size / 5, size)
	if emit:
		img.fill(Color.BLACK)
		img.fill_rect(strip, Color(0.85, 0.9, 1.0))
		return img
	img.fill(Color(0.32, 0.33, 0.35))
	for i in range(8):
		img.fill_rect(Rect2i(0, i * size / 8, size, 3), Color(0.5, 0.5, 0.52))
	img.fill_rect(Rect2i(0, 0, 6, size), Color(0.2, 0.2, 0.22))
	img.fill_rect(strip, Color(0.92, 0.95, 1.0))
	for i in range(4):
		img.fill_rect(Rect2i(strip.position.x, i * size / 4, strip.size.x, 2), Color(0.4, 0.42, 0.45))
	return img

## Sports hall ceiling: light acoustic panels, a dark steel truss per
## tile, and two long lamp fittings hung either side of it.
static func gym_ceiling_image(size: int, emit: bool) -> Image:
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var lamp_a := Rect2i(size / 5, size / 8, size / 10, size * 3 / 4)
	var lamp_b := Rect2i(size * 7 / 10, size / 8, size / 10, size * 3 / 4)
	if emit:
		img.fill(Color.BLACK)
		img.fill_rect(lamp_a, Color(1, 1, 0.95))
		img.fill_rect(lamp_b, Color(1, 1, 0.95))
		return img
	img.fill(Color(0.78, 0.8, 0.82))
	for i in range(6):
		img.fill_rect(Rect2i(0, i * size / 6, size, 1), Color(0.66, 0.68, 0.7))
	img.fill_rect(Rect2i(size / 2 - size / 24, 0, size / 12, size), Color(0.22, 0.23, 0.25))
	img.fill_rect(lamp_a.grow(2), Color(0.35, 0.35, 0.37))
	img.fill_rect(lamp_b.grow(2), Color(0.35, 0.35, 0.37))
	img.fill_rect(lamp_a, Color(1, 1, 0.96))
	img.fill_rect(lamp_b, Color(1, 1, 0.96))
	return img

## Plain worn asphalt (no directional lane wear, so it works on roads
## running either way under world-space projection).
static func asphalt_plain_texture() -> ImageTexture:
	var img := plaster_image(128, 0.62, 0.82, 41)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Concrete paving slabs, 50 cm grid (one texture tile = 2 m).
static func paving_texture() -> ImageTexture:
	var img := plaster_image(128, 0.88, 1.0, 42)
	for i in range(4):
		img.fill_rect(Rect2i(i * 32, 0, 1, 128), Color(0.62, 0.62, 0.62))
		img.fill_rect(Rect2i(0, i * 32, 128, 1), Color(0.62, 0.62, 0.62))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Compacted gravel / dirt track.
static func gravel_texture() -> ImageTexture:
	var img := plaster_image(128, 0.7, 1.0, 43)
	var rng := RandomNumberGenerator.new()
	rng.seed = 44
	for i in range(900):
		var v: float = rng.randf_range(0.45, 1.1)
		img.set_pixel(rng.randi_range(0, 127), rng.randi_range(0, 127), Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Ploughed field furrows (8 per tile).
static func field_texture() -> ImageTexture:
	var img := Image.create(128, 128, false, Image.FORMAT_RGB8)
	for x in range(128):
		var v: float = 0.78 + 0.22 * sin(x / 128.0 * 8.0 * TAU)
		img.fill_rect(Rect2i(x, 0, 1, 128), Color(v, v, v))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Tunnel/culvert ceiling: dark concrete, and optionally a strip of lamp
## fittings down the middle (u = 0.5, running along v - the tunnel's
## length under world projection).
static func tube_ceiling_texture(lamps: bool) -> ImageTexture:
	var img := plaster_image(64, 0.26, 0.34, 45)
	if lamps:
		for i in range(4):
			img.fill_rect(Rect2i(28, i * 16 + 2, 8, 10), Color(1, 0.97, 0.88))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Gym wall bars: two light-wood rails per 1 m unit and round-ish rungs
## every ~15 cm, everything else fully transparent (alpha scissor).
static func wallbars_texture() -> ImageTexture:
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var wood := Color(0.82, 0.65, 0.42, 1)
	img.fill_rect(Rect2i(0, 0, 4, 128), wood)
	img.fill_rect(Rect2i(60, 0, 4, 128), wood)
	for i in range(18):
		img.fill_rect(Rect2i(0, i * 128 / 18 + 2, 64, 3), wood)
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## School locker doors: one door per tile, vent slits at the top, a
## handle, a dark gap to the next door.
static func lockers_texture() -> ImageTexture:
	var img := Image.create(32, 64, false, Image.FORMAT_RGB8)
	img.fill(Color(0.36, 0.5, 0.68))
	img.fill_rect(Rect2i(0, 0, 1, 64), Color(0.15, 0.18, 0.22))
	for i in range(4):
		img.fill_rect(Rect2i(8, 5 + i * 3, 16, 1), Color(0.18, 0.24, 0.32))
	img.fill_rect(Rect2i(25, 28, 3, 8), Color(0.8, 0.8, 0.82))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
