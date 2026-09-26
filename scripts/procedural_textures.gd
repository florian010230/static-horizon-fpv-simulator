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
