extends BuiltMap

## Office - a Tiny Whoop race on the 5th floor of an open-plan office
## (Low performance). 36 x 22 m, 3 m ceiling. Four rows of desk
## clusters, a glass meeting room, a kitchen corner, reception. Whoop
## gates are 60 cm (typical whoop-race size), on floor stands, poles
## and one on a desk. Course (fly order, north = -z):
##   START (-11,-3.5) east -> (0,-3.5) -> (7,0.5) south -> (2,8.5) west
##   -> (-6,8.5) on a table -> (-13,2) north -> START.
## Windows are real glass (collides - no flying out); a city below.

const ROOM := AABB(Vector3(-18, 0, -11), Vector3(36, 3.0, 22))

var course: RaceCourse

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-35, 150, 0), "fog_density": 0.002, "ambient_energy": 1.35}

func check_border() -> void:
	WorldBorder.check_box(drone, ui, ROOM.position, ROOM.end, 12.0, get_tree())

func preview_views() -> Array:
	return [
		["overview", Vector3(-17, 2.7, 10), Vector3(5, 0.5, -6)],
		["start", Vector3(-15, 0.7, -3.5), Vector3(0, 0.6, -3.5)],
		["meeting", Vector3(6, 1.5, -2), Vector3(14, 0.8, -8)],
		["kitchen", Vector3(-8, 1.6, 4), Vector3(-16, 0.8, 9)],
	]

func build() -> void:
	geo.ao_height = 0.8
	geo.ao_min = 0.65
	RaceCourse.add_materials(geo)
	geo.add_material("carpet", Geo.tex_mat(MapTextures.get_tex("fabric"), Color(0.42, 0.44, 0.5), 0.8))
	geo.add_material("wall", Geo.flat_mat(Color(0.9, 0.9, 0.88)))
	geo.add_material("ceiling", Geo.flat_mat(Color(0.95, 0.95, 0.95)))
	geo.add_material("lamp", Geo.glow_mat(Color(1, 1, 0.97), 1.2))
	geo.add_material("desk", Geo.flat_mat(Color(0.82, 0.8, 0.76)))
	geo.add_material("metal", Geo.flat_mat(Color(0.35, 0.36, 0.38)))
	geo.add_material("screen", Geo.flat_mat(Color(0.06, 0.07, 0.09)))
	geo.add_material("chair", Geo.flat_mat(Color(0.15, 0.16, 0.2)))
	geo.add_material("wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color.WHITE, 1.2))
	geo.add_material("plant", Geo.flat_mat(Color(0.2, 0.45, 0.2)))
	geo.add_material("pot", Geo.flat_mat(Color(0.85, 0.85, 0.82)))
	geo.add_material("accent", Geo.flat_mat(Color(0.12, 0.43, 0.88)))
	geo.add_material("city", Geo.flat_mat(Color(0.62, 0.64, 0.68)))
	geo.add_material("street", Geo.flat_mat(Color(0.3, 0.31, 0.33)))
	var glass := Geo.flat_mat(Color(0.7, 0.85, 0.95, 0.22))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	geo.add_material("glass", glass)

	var r: AABB = ROOM
	geo.slab(Rect2(r.position.x, r.position.z, r.size.x, r.size.z), 0.0, 0.3, "carpet")
	geo.box(Vector3(0, 3.1, 0), Vector3(r.size.x, 0.2, r.size.z), "ceiling")
	for i in range(7):
		for j in range(4):
			geo.box(Vector3(-15 + i * 5, 2.98, -7.5 + j * 5), Vector3(1.2, 0.04, 0.6), "lamp", 0.0, false, false)
	_outer_walls()
	_desks()
	_meeting_room(Rect2(8, -11, 10, 8))
	_kitchen()
	for p in [Vector3(-10, 0, -5), Vector3(-10, 0, 5), Vector3(5.5, 0, 5)]:
		geo.box(p + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5), "wall")
	for p in [Vector3(-17, 0, -10), Vector3(17, 0, 10), Vector3(5, 0, -10)]:
		geo.cylinder(p, p + Vector3(0, 0.45, 0), 0.25, "pot", 10)
		geo.lathe(p + Vector3(0, 0.45, 0), [Vector2(0.2, 0), Vector2(0.45, 0.4), Vector2(0.35, 1.0), Vector2(0.05, 1.3)], "plant", 9)
	_city()

	course = RaceCourse.new()
	course.name = "RaceCourse"
	add_child(course)
	var E: float = -PI * 0.5
	var W: float = PI * 0.5
	var S: float = PI
	var w: float = 0.6
	var bar: float = 0.05
	course.gate_sized(geo, Vector3(-11, 0.02, -3.5), E, w, w, bar, 0.3, "gate_dark")
	course.gate_sized(geo, Vector3(0, 0.02, -3.5), E, w, w, bar, 1.0, "gate_a")
	course.gate_sized(geo, Vector3(7, 0.02, 0.5), S, w, w, bar, 0.3, "gate_b")
	course.gate_sized(geo, Vector3(2, 0.02, 8.5), W, w, w, bar, 1.4, "gate_a")
	geo.box(Vector3(-6, 0.37, 8.5), Vector3(1.2, 0.74, 0.8), "desk")
	course.gate_sized(geo, Vector3(-6, 0.76, 8.5), W, w, w, bar, 0.0, "gate_b")
	course.gate_sized(geo, Vector3(-13, 0.02, 2), 0.0, w, w, bar, 0.3, "gate_a")

func after_build() -> void:
	course.setup("office", drone, ui)

## Outer walls: solid below 0.9 m and above 2.6 m, glass between.
func _outer_walls() -> void:
	var r: AABB = ROOM
	var sides := [[Vector3(0, 0, r.position.z), Vector3(r.size.x, 0, 0.2)], [Vector3(0, 0, r.end.z), Vector3(r.size.x, 0, 0.2)],
		[Vector3(r.position.x, 0, 0), Vector3(0.2, 0, r.size.z)], [Vector3(r.end.x, 0, 0), Vector3(0.2, 0, r.size.z)]]
	for sd in sides:
		var c: Vector3 = sd[0]
		var sz: Vector3 = sd[1]
		geo.box(c + Vector3(0, 0.45, 0), sz + Vector3(0, 0.9, 0), "wall")
		geo.box(c + Vector3(0, 2.8, 0), sz + Vector3(0, 0.4, 0), "wall")
		geo.box(c + Vector3(0, 1.75, 0), sz + Vector3(0, 1.7, 0), "glass", 0.0, true, false)

func _desks() -> void:
	# Clusters of four desks (two facing two), each with monitor + chair.
	for row in [-6.0, -1.0, 4.0]:
		for cx in [-8.0, -4.6, -1.2, 2.2]:
			for dz in [-0.4, 0.4]:
				for dx in [-0.8, 0.8]:
					var p := Vector3(cx + dx, 0, row + dz)
					geo.box(p + Vector3(0, 0.73, 0), Vector3(1.56, 0.03, 0.78), "desk")
					geo.box(p + Vector3(0, 0.36, 0), Vector3(1.5, 0.72, 0.03), "metal")
					geo.box(p + Vector3(0, 1.0, dz * 0.4), Vector3(0.6, 0.36, 0.03), "screen")
					geo.box(p + Vector3(0, 0.8, dz * 0.4), Vector3(0.05, 0.14, 0.05), "metal")
					var chair := p + Vector3(0, 0, dz * 2.2)
					geo.box(chair + Vector3(0, 0.46, 0), Vector3(0.5, 0.08, 0.5), "chair")
					geo.box(chair + Vector3(0, 0.8, 0.25 * signf(dz)), Vector3(0.48, 0.6, 0.06), "chair")
					geo.cylinder(chair + Vector3(0, 0.05, 0), chair + Vector3(0, 0.42, 0), 0.03, "metal", 6)

func _meeting_room(rr: Rect2) -> void:
	# Glass walls on the open-office sides, a door gap facing the desks.
	geo.box(Vector3(rr.position.x, 1.5, rr.get_center().y - 1.0), Vector3(0.05, 3.0, rr.size.y - 2.0), "glass", 0.0, true, false)
	geo.box(Vector3(rr.position.x, 1.5, rr.end.y - 0.5), Vector3(0.05, 3.0, 1.0), "glass", 0.0, true, false)
	geo.box(Vector3(rr.get_center().x, 1.5, rr.end.y), Vector3(rr.size.x, 3.0, 0.05), "glass", 0.0, true, false)
	var c := Vector3(rr.get_center().x, 0, rr.get_center().y)
	geo.box(c + Vector3(0, 0.74, 0), Vector3(5, 0.05, 1.8), "wood")
	for dx in [-2.0, 2.0]:
		geo.box(c + Vector3(dx, 0.36, 0), Vector3(0.08, 0.72, 1.4), "metal")
	for i in range(4):
		for s in [-1.3, 1.3]:
			geo.box(c + Vector3(-1.8 + i * 1.2, 0.46, s), Vector3(0.5, 0.08, 0.5), "accent")
	geo.box(Vector3(rr.end.x - 0.15, 1.5, c.z), Vector3(0.05, 1.2, 2.4), "desk") # whiteboard

func _kitchen() -> void:
	geo.box(Vector3(-17.6, 0.45, 8), Vector3(0.6, 0.9, 6), "desk")
	geo.box(Vector3(-15, 0.45, 10.6), Vector3(5, 0.9, 0.6), "desk")
	geo.box(Vector3(-17.6, 0.95, 8), Vector3(0.62, 0.04, 6.02), "wood")
	geo.box(Vector3(-17.6, 1.0, 11.0 - 0.4), Vector3(0.7, 2.0, 0.7), "metal") # fridge
	geo.box(Vector3(-14, 1.05, 7), Vector3(1.6, 0.05, 0.8), "wood")          # bar table
	geo.box(Vector3(-14, 0.52, 7), Vector3(0.1, 1.04, 0.1), "metal")
	geo.box(Vector3(-12, 0.5, -9), Vector3(4, 1.0, 1.2), "accent")            # reception desk

## The city 20 m below the windows: the street grid round this block
## (out into the haze), traffic, blocks and towers.
func _city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var roads := Roads.new(geo, rng, fleet)
	var city := City.new(geo, rng, fleet)
	var y: float = -20.0
	geo.add_material("ground_far", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 0, 0.3))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), y, 0.5, "ground_far", false)
	var xs: Array = [-150.0, -50.0, 50.0, 150.0]
	var zs: Array = [-130.0, -40.0, 40.0, 130.0]
	var blocks: Array[Rect2] = roads.grid(xs, zs, [12.0, 14.0, 14.0, 12.0], [12.0, 14.0, 14.0, 12.0], 3.0, y, {"n": 1500.0, "s": 1500.0, "w": 1500.0, "e": 1500.0}, {"traffic": 18.0, "lamps": 32.0, "detail": 300.0})
	for r: Rect2 in blocks:
		if r.has_point(Vector2(0, 0)):
			continue # this building's block
		if r.get_center().length() > 130.0:
			city.filler_block(r, y, 4, 10)
		elif rng.randf() < 0.3:
			city.tower(r, y, rng.randf_range(35.0, 80.0))
		else:
			city.perimeter_block(r, y, 5, 9)
	for i in range(-6, 6):
		for j in range(-6, 6):
			var c := Vector2(i * 100.0 + 50.0, j * 90.0 + 45.0)
			if absf(c.x) < 170.0 and absf(c.y) < 150.0:
				continue
			city.filler_block(Rect2(c.x - 38.0, c.y - 33.0, 76.0, 66.0), y, 4, 12)
	# This building's own shell below the office floor.
	geo.box(Vector3(0, -10.2, 0), Vector3(36.4, 20, 22.4), "wall", 0.0, false, false)
