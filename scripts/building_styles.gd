class_name BuildingStyles
extends RefCounted

## Named looks for HollowBuilding, plus a cache so every building of the
## same style shares one material (and every texture is generated only
## once per run, however many houses use it).
##
## Interior styles are designed around one rule: floor, walls and
## ceiling must never be confusable, even with shadows off and even in
## a single glance at speed. Each style gets
##   - a floor with its own texture and color (planks, linoleum, a
##     sports court, concrete),
##   - wall "bands" from the floor up (skirting board, a painted lower
##     wall, a gym's wood impact panelling) - they always sit at the
##     bottom of a wall, so they show which way is down,
##   - a ceiling with a pattern floors and walls never have (wood beams,
##     a suspended tile grid, skylights, trusses) and, where real rooms
##     have them, glowing lamps.
## Real references: German school corridors/classrooms are almost
## always painted with a darker, washable lower band (roughly the
## bottom 1.2-1.5 m) under a light upper wall, with 600 mm suspended
## ceiling tiles and recessed light panels; school sports halls line the
## walls with wood impact panelling up to about 2 m.

const BIG: float = 999.0

static var _materials: Dictionary = {}
static var _textures: Dictionary = {}

static func interior(style_name: String, legacy_wall: Color = Color(0.7, 0.52, 0.38), legacy_floor: Color = Color(0.5, 0.47, 0.42)) -> Dictionary:
	match style_name:
		"house":
			return {
				"name": "house",
				"bands": [[0.12, Color(0.36, 0.23, 0.13)], [BIG, Color(0.96, 0.93, 0.87)]],
				"wall_tex": "plaster", "wall_tile": Vector2(2.0, 2.0),
				"floor_tex": "planks", "floor_tile": Vector2(2.4, 2.4), "floor_color": Color(1, 1, 1),
				"ceil_tex": "beams", "ceil_tile": Vector2(2.4, 2.4), "ceil_color": Color(1, 1, 1),
				"ao_floor": 0.55, "ao_ceil": 0.72,
			}
		"factory":
			return {
				"name": "factory",
				"bands": [[0.15, Color(0.18, 0.18, 0.19)], [2.4, Color(0.42, 0.52, 0.47)], [2.55, Color(0.95, 0.78, 0.1)], [BIG, Color(0.86, 0.88, 0.9)]],
				"wall_tex": "corrugated", "wall_tile": Vector2(1.2, 4.0),
				"floor_tex": "concrete_floor", "floor_tile": Vector2(16.0, 16.0), "floor_color": Color(0.95, 0.95, 0.95),
				"ceil_tex": "skylight", "ceil_tile": Vector2(8.0, 8.0), "ceil_color": Color(1, 1, 1), "ceil_emit": true,
				"ao_floor": 0.6, "ao_ceil": 0.75,
			}
		"gym":
			return {
				"name": "gym",
				"bands": [[0.1, Color(0.22, 0.17, 0.12)], [2.0, Color(0.86, 0.68, 0.45)], [2.12, Color(0.3, 0.24, 0.18)], [BIG, Color(0.84, 0.87, 0.9)]],
				"wall_tex": "boards", "wall_tile": Vector2(2.4, 2.4),
				"floor_tex": "gym_court", "floor_stretch": true, "floor_tile": Vector2(1, 1), "floor_color": Color(1, 1, 1),
				"ceil_tex": "gym_ceiling", "ceil_tile": Vector2(6.0, 6.0), "ceil_color": Color(1, 1, 1), "ceil_emit": true,
				"ao_floor": 0.6, "ao_ceil": 0.7,
			}
		"school":
			return {
				"name": "school",
				"bands": [[0.1, Color(0.28, 0.28, 0.3)], [1.4, Color(0.3, 0.56, 0.6)], [1.47, Color(0.2, 0.3, 0.34)], [BIG, Color(0.96, 0.95, 0.91)]],
				"wall_tex": "plaster", "wall_tile": Vector2(2.0, 2.0),
				"floor_tex": "linoleum", "floor_tile": Vector2(3.0, 3.0), "floor_color": Color(0.72, 0.7, 0.6),
				"ceil_tex": "ceiling_tiles", "ceil_tile": Vector2(2.4, 2.4), "ceil_color": Color(1, 1, 1), "ceil_emit": true,
				"ao_floor": 0.55, "ao_ceil": 0.72,
			}
		"classroom":
			return {
				"name": "classroom",
				"bands": [[0.1, Color(0.28, 0.28, 0.3)], [1.3, Color(0.93, 0.74, 0.38)], [1.36, Color(0.45, 0.33, 0.18)], [BIG, Color(0.97, 0.96, 0.92)]],
				"wall_tex": "plaster", "wall_tile": Vector2(2.0, 2.0),
				"floor_tex": "linoleum", "floor_tile": Vector2(3.0, 3.0), "floor_color": Color(0.55, 0.66, 0.6),
				"ceil_tex": "ceiling_tiles", "ceil_tile": Vector2(2.4, 2.4), "ceil_color": Color(1, 1, 1), "ceil_emit": true,
				"ao_floor": 0.55, "ao_ceil": 0.72,
			}
		"office":
			return {
				"name": "office",
				"bands": [[0.08, Color(0.3, 0.3, 0.32)], [BIG, Color(0.95, 0.95, 0.93)]],
				"wall_tex": "plaster", "wall_tile": Vector2(2.0, 2.0),
				"floor_tex": "linoleum", "floor_tile": Vector2(2.0, 2.0), "floor_color": Color(0.35, 0.42, 0.58),
				"ceil_tex": "ceiling_tiles", "ceil_tile": Vector2(2.4, 2.4), "ceil_color": Color(1, 1, 1), "ceil_emit": true,
				"ao_floor": 0.55, "ao_ceil": 0.72,
			}
	return {
		"name": "plain_%s_%s" % [legacy_wall.to_html(), legacy_floor.to_html()],
		"bands": [[BIG, legacy_wall]],
		"wall_tex": "plaster", "wall_tile": Vector2(2.0, 2.0),
		"floor_tex": "plaster", "floor_tile": Vector2(2.0, 2.0), "floor_color": legacy_floor,
		"ceil_tex": "plaster", "ceil_tile": Vector2(2.0, 2.0), "ceil_color": legacy_floor * 0.8,
		"ao_floor": 0.6, "ao_ceil": 0.75,
	}

static func exterior(style_name: String) -> Dictionary:
	match style_name:
		"plaster":
			return {"name": "plaster", "color": Color(0.94, 0.91, 0.84), "wall_tex": "render", "wall_tile": Vector2(3.0, 3.0), "roof_tex": "gravel", "roof_tile": Vector2(4, 4)}
		"brick":
			return {"name": "brick", "color": Color(1, 1, 1), "wall_tex": "brick_plain", "wall_tile": Vector2(2.0, 2.0), "roof_tex": "gravel", "roof_tile": Vector2(4, 4)}
		"metal":
			return {"name": "metal", "color": Color(0.78, 0.8, 0.84), "wall_tex": "corrugated", "wall_tile": Vector2(1.2, 4.0), "roof_tex": "gravel", "roof_tile": Vector2(4, 4)}
		"concrete":
			return {"name": "concrete", "color": Color(0.8, 0.8, 0.78), "wall_tex": "concrete_panels", "wall_tile": Vector2(6.0, 3.0), "roof_tex": "gravel", "roof_tile": Vector2(4, 4)}
	return {"name": "siding", "color": Color(1, 1, 1), "wall_tex": "siding_plain", "wall_tile": Vector2(2.4, 2.4), "roof_tex": "gravel", "roof_tile": Vector2(4, 4)}

## part: "wall", "floor", "ceil" (interior styles) or "wall", "roof"
## (exterior styles). Vertex colors carry the bands/AO/tint, the texture
## carries the pattern - so the material itself can be shared widely.
static func material(style: Dictionary, part: String, building_size: Vector3 = Vector3.ZERO) -> StandardMaterial3D:
	var tex_name: String = style.get(part + "_tex", "plaster")
	var key: String = "%s/%s/%s" % [style.name, part, tex_name]
	if tex_name == "gym_court":
		key += "/%.1fx%.1f" % [building_size.x, building_size.z]
	if _materials.has(key):
		return _materials[key]
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.85
	# Interior surfaces: unshaded, lighting baked into vertex colors by
	# HollowBuilding (see its INTERIOR_LIGHT). Exterior ones stay lit by
	# the real sun.
	if style.has("bands"):
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if tex_name == "gym_court":
		mat.albedo_texture = _gym_court(building_size)
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	else:
		mat.albedo_texture = texture(tex_name)
	if part == "ceil" and style.get("ceil_emit", false):
		mat.emission_enabled = true
		mat.emission = Color(1, 1, 1)
		mat.emission_energy_multiplier = 1.4
		mat.emission_texture = texture(tex_name + "_emit")
	_materials[key] = mat
	return mat

## Everything the layout generator tagged by surface type (see the node
## groups in Main.tscn / Main2.tscn) - world-space top projection, so a 200 m road
## and a 5 m ramp get the same texture density without per-node UV
## scales.
static func apply_ground_surfaces(tree: SceneTree) -> void:
	var surfaces := {
		"asphalt": [ProceduralTextures.asphalt_plain_texture(), 4.0],
		"paving": [ProceduralTextures.paving_texture(), 2.0],
		"gravel": [ProceduralTextures.gravel_texture(), 3.0],
		"field": [ProceduralTextures.field_texture(), 8.0],
	}
	for group: String in surfaces:
		var tex: Texture2D = surfaces[group][0]
		var tile: float = surfaces[group][1]
		for node in tree.get_nodes_in_group(group):
			var mi := node as MeshInstance3D
			var mat: StandardMaterial3D = mi.get_surface_override_material(0)
			mat.albedo_texture = tex
			mat.uv1_triplanar = true
			mat.uv1_world_triplanar = true
			mat.uv1_scale = Vector3(1.0 / tile, 1.0 / tile, 1.0 / tile)

## A big grass plane under the playable ground, reaching to the horizon
## (visual only, no collision). Past the 500 m ground box the sky's dark
## "underside" used to show through below the horizon - looking toward
## the map edge from any height made the landscape go dark.
static func add_far_ground(root: Node3D, top_y: float) -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(6000, 6000)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ProceduralTextures.grass_texture()
	mat.uv1_triplanar = true
	mat.uv1_world_triplanar = true
	mat.uv1_scale = Vector3(1.0 / 7.0, 1.0 / 7.0, 1.0 / 7.0)
	plane.material = mat
	var mi := MeshInstance3D.new()
	mi.name = "FarGround"
	mi.mesh = plane
	mi.position = Vector3(0, top_y - 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)

static func glass_material() -> StandardMaterial3D:
	if _materials.has("glass"):
		return _materials["glass"]
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.62, 0.78, 0.88, 0.3)
	mat.metallic = 0.4
	mat.roughness = 0.05
	_materials["glass"] = mat
	return mat

static func glass_outside_material() -> StandardMaterial3D:
	if _materials.has("glass_out"):
		return _materials["glass_out"]
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	# Not glossy: a mirror-like pane reflected the bright sky and read as
	# more wall when looking toward the sun. Matte dark reads as a window
	# from every angle.
	mat.albedo_color = Color(0.16, 0.22, 0.29, 0.82)
	mat.metallic = 0.0
	mat.roughness = 0.35
	_materials["glass_out"] = mat
	return mat

static func trim_material() -> StandardMaterial3D:
	if _materials.has("trim"):
		return _materials["trim"]
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.89, 0.86)
	mat.roughness = 0.7
	_materials["trim"] = mat
	return mat

static func texture(tex_name: String) -> Texture2D:
	if _textures.has(tex_name):
		return _textures[tex_name]
	var img: Image
	match tex_name:
		"plaster": img = ProceduralTextures.plaster_image(128, 0.86, 1.0, 11)
		"render": img = ProceduralTextures.plaster_image(128, 0.8, 1.0, 12)
		"planks": img = ProceduralTextures.planks_image(256)
		"beams": img = ProceduralTextures.beams_image(256)
		"boards": img = ProceduralTextures.boards_image(128)
		"corrugated": img = ProceduralTextures.corrugated_image(128)
		"concrete_floor": img = ProceduralTextures.factory_ground_texture().get_image()
		"linoleum": img = ProceduralTextures.linoleum_image(128)
		"siding_plain": img = ProceduralTextures.siding_plain_image(128)
		"brick_plain": img = ProceduralTextures.brick_plain_image(128)
		"concrete_panels": img = ProceduralTextures.concrete_panels_image(128)
		"gravel": img = ProceduralTextures.plaster_image(128, 0.3, 0.45, 13)
		"roof_tiles": img = ProceduralTextures.roof_tiles_image(128)
		"ceiling_tiles", "ceiling_tiles_emit": img = ProceduralTextures.ceiling_tiles_image(256, tex_name.ends_with("_emit"))
		"skylight", "skylight_emit": img = ProceduralTextures.skylight_image(256, tex_name.ends_with("_emit"))
		"gym_ceiling", "gym_ceiling_emit": img = ProceduralTextures.gym_ceiling_image(256, tex_name.ends_with("_emit"))
		_: img = ProceduralTextures.plaster_image(64, 0.9, 1.0, 1)
	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[tex_name] = tex
	return tex

## A handball court (the standard 40 x 20 m, IHF rules: 6 m goal area
## arcs drawn from each goal post, dashed 9 m free-throw line, 7 m
## penalty mark) plus a volleyball court (9 x 18 m) in a second color -
## the usual overlay in a German school's multi-purpose sports hall.
## Drawn to scale for this particular floor, so the lines land where the
## 3D goals actually stand; the goal areas are filled in, which makes
## both ends of the hall recognizable from anywhere in the room.
static func _gym_court(floor_size: Vector3) -> Texture2D:
	var key: String = "court_%.1fx%.1f" % [floor_size.x, floor_size.z]
	if _textures.has(key):
		return _textures[key]
	var w: int = 1024
	var h: int = int(round(w * floor_size.z / floor_size.x))
	var ppm: float = w / floor_size.x
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	img.fill(Color(0.8, 0.62, 0.4))
	# Plank stripes along the long axis, a subtle darker line every 0.14 m.
	var plank_px: float = 0.14 * ppm
	var y := 0.0
	while y < h:
		img.fill_rect(Rect2i(0, int(y), w, 1), Color(0.74, 0.56, 0.35))
		y += plank_px
	var cx: float = w * 0.5
	var cy: float = h * 0.5
	var white := Color(0.97, 0.97, 0.95)
	var yellow := Color(0.98, 0.8, 0.12)
	var area := Color(0.25, 0.42, 0.68)
	var lw: int = maxi(2, int(round(0.05 * ppm)))
	var to_px := func(mx: float, mz: float) -> Vector2: return Vector2(cx + mx * ppm, cy + mz * ppm)

	# Filled goal areas: points within 6 m of the goal-line segment
	# between the posts (+/-1.5 m), which is exactly the IHF "D" shape.
	for side in [-1.0, 1.0]:
		var gx: float = side * 20.0
		var x0: int = int(cx + minf(gx, gx - side * 6.0) * ppm)
		var x1: int = int(cx + maxf(gx, gx - side * 6.0) * ppm)
		var y0: int = int(cy - 7.5 * ppm)
		var y1: int = int(cy + 7.5 * ppm)
		for py in range(maxi(0, y0), mini(h, y1 + 1)):
			for px in range(maxi(0, x0), mini(w, x1 + 1)):
				var mx: float = (px - cx) / ppm
				var mz: float = (py - cy) / ppm
				if (mx - gx) * side > 0.0:
					continue
				var dz: float = maxf(absf(mz) - 1.5, 0.0)
				if Vector2(mx - gx, dz).length() <= 6.0:
					img.set_pixel(px, py, area)

	var line := func(ax: float, az: float, bx: float, bz: float, col: Color) -> void:
		var a: Vector2 = to_px.call(ax, az)
		var b: Vector2 = to_px.call(bx, bz)
		var r := Rect2i(int(minf(a.x, b.x)) - lw / 2, int(minf(a.y, b.y)) - lw / 2, int(absf(b.x - a.x)) + lw, int(absf(b.y - a.y)) + lw)
		img.fill_rect(r, col)
	var arc := func(ox: float, oz: float, r: float, a0: float, a1: float, col: Color, dashed: bool) -> void:
		var steps: int = int(r * absf(a1 - a0) * ppm)
		for i in range(steps + 1):
			var a: float = lerpf(a0, a1, i / float(steps))
			if dashed and int(r * absf(a - a0) / 0.15) % 2 == 1:
				continue
			var p: Vector2 = to_px.call(ox + cos(a) * r, oz + sin(a) * r)
			img.fill_rect(Rect2i(int(p.x) - lw / 2, int(p.y) - lw / 2, lw, lw), col)

	# Volleyball first so handball lines draw on top where they cross.
	line.call(-9.0, -4.5, 9.0, -4.5, yellow)
	line.call(-9.0, 4.5, 9.0, 4.5, yellow)
	line.call(-9.0, -4.5, -9.0, 4.5, yellow)
	line.call(9.0, -4.5, 9.0, 4.5, yellow)
	line.call(-3.0, -4.5, -3.0, 4.5, yellow)
	line.call(3.0, -4.5, 3.0, 4.5, yellow)

	line.call(-20.0, -10.0, 20.0, -10.0, white)
	line.call(-20.0, 10.0, 20.0, 10.0, white)
	line.call(-20.0, -10.0, -20.0, 10.0, white)
	line.call(20.0, -10.0, 20.0, 10.0, white)
	line.call(0.0, -10.0, 0.0, 10.0, white)
	for side in [-1.0, 1.0]:
		var gx: float = side * 20.0
		var inward: float = -side
		# 6 m goal area line: two quarter arcs from the posts + straight part.
		line.call(gx + inward * 6.0, -1.5, gx + inward * 6.0, 1.5, white)
		var base_a: float = 0.0 if inward > 0.0 else PI
		arc.call(gx, -1.5, 6.0, base_a, base_a - inward * PI * 0.5, white, false)
		arc.call(gx, 1.5, 6.0, base_a, base_a + inward * PI * 0.5, white, false)
		# 9 m free-throw line, dashed.
		line.call(gx + inward * 9.0, -1.5, gx + inward * 9.0, 1.5, white)
		arc.call(gx, -1.5, 9.0, base_a, base_a - inward * 1.2, white, true)
		arc.call(gx, 1.5, 9.0, base_a, base_a + inward * 1.2, white, true)
		# 7 m penalty mark (1 m long).
		line.call(gx + inward * 7.0, -0.5, gx + inward * 7.0, 0.5, white)
	arc.call(0.0, 0.0, 1.8, 0.0, TAU, white, false)

	img.generate_mipmaps()
	var tex := ImageTexture.create_from_image(img)
	_textures[key] = tex
	return tex
