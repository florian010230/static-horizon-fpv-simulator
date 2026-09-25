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
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var brick_h: int = size / 8
	var brick_w: int = size / 4
	var mortar: int = max(1, size / 48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2
	for y in range(size):
		var row: int = int(y / float(brick_h))
		var offset: int = (brick_w / 2) if (row % 2 == 1) else 0
		for x in range(size):
			var xx: int = (x + offset) % brick_w
			var yy: int = y % brick_h
			if xx < mortar or yy < mortar:
				img.set_pixel(x, y, mortar_color)
			else:
				var shade: float = 1.0 + rng.randf_range(-0.06, 0.06)
				img.set_pixel(x, y, Color(brick_color.r * shade, brick_color.g * shade, brick_color.b * shade))
	return ImageTexture.create_from_image(img)

static func concrete_texture(size: int = 128) -> ImageTexture:
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.05
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var low := Color(0.38, 0.38, 0.4)
	var high := Color(0.5, 0.5, 0.52)
	for y in range(size):
		for x in range(size):
			var n: float = (noise.get_noise_2d(x, y) + 1.0) * 0.5
			img.set_pixel(x, y, low.lerp(high, n))
	return ImageTexture.create_from_image(img)

static func siding_texture(size: int = 128) -> ImageTexture:
	var plank_color := Color(0.72, 0.55, 0.4)
	var line_color := Color(0.5, 0.37, 0.26)
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var plank_h: int = size / 10
	var line_h: int = max(1, size / 64)
	for y in range(size):
		var is_line: bool = (y % plank_h) < line_h
		var c: Color = line_color if is_line else plank_color
		for x in range(size):
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)
