extends BuiltMap

## Race Field - a club race day on a mown field (Low performance).
## Course (fly order, north = -z), all MultiGP standard obstacles:
##   START (0,25) north -> gate (0,0) -> ladder, top opening (0,-30)
##   -> turn flag -> dive gate (-25,-45) -> tower gate (-45,-22) south
##   -> hurdle (-45,2) -> double gate, upper opening (-26,34) east
##   -> turn flag (8,46) -> back through START.
## South of the course: safety net, pilot stand, pit tents, car park.

var course: RaceCourse

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-55, 25, 0), "shadow_ground_y": 0.0, "shadow_region": Rect2(-128, -128, 256, 256)}

func border() -> Array:
	return [110.0, 140.0, 60.0, 90.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(30, 28, 70), Vector3(-15, 0, -5)],
		["start", Vector3(0, 1.3, 33), Vector3(0, 1.3, 0)],
		["ladder", Vector3(0, 3.5, -12), Vector3(0, 4.0, -30)],
		["dive", Vector3(-12, 7, -45), Vector3(-25, 3, -45)],
		["pits", Vector3(-10, 3, 45), Vector3(10, 1, 62)],
	]

func build() -> void:
	geo.ao_height = 1.5
	RaceCourse.add_materials(geo)
	geo.add_material("field", Geo.tex_mat(MapTextures.get_tex("mown_grass"), Color.WHITE, 12.0))
	geo.add_material("meadow", Geo.tex_mat(MapTextures.get_tex("meadow"), Color(0.95, 0.95, 0.9), 8.0))
	geo.add_material("gravel", Geo.tex_mat(ProceduralTextures.gravel_texture(), Color(0.7, 0.68, 0.64), 3.0))
	geo.add_material("net", Geo.flat_mat(Color(0.08, 0.08, 0.08), 0.9))
	geo.add_material("post", Geo.flat_mat(Color(0.75, 0.75, 0.75), 0.4, 0.4))
	geo.add_material("canopy_blue", Geo.flat_mat(Color(0.14, 0.38, 0.85), 0.7))
	geo.add_material("canopy_orange", Geo.flat_mat(Color(0.92, 0.4, 0.1), 0.7))
	geo.add_material("table", Geo.flat_mat(Color(0.88, 0.88, 0.86), 0.6))
	geo.add_material("wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color.WHITE, 1.5))
	geo.add_material("car_red", Geo.flat_mat(Color(0.6, 0.12, 0.1), 0.3, 0.4))
	geo.add_material("car_grey", Geo.flat_mat(Color(0.5, 0.52, 0.55), 0.3, 0.4))
	geo.add_material("car_white", Geo.flat_mat(Color(0.85, 0.86, 0.86), 0.3, 0.4))
	geo.add_material("glass", Geo.flat_mat(Color(0.1, 0.13, 0.16), 0.1, 0.5))

	geo.slab(Rect2(-200, -200, 400, 400), 0.0, 0.4, "meadow")
	geo.slab(Rect2(-80, -70, 140, 125), 0.05, 0.1, "field")
	geo.slab(Rect2(-40, 58, 90, 22), 0.05, 0.1, "gravel") # pits + car park

	course = RaceCourse.new()
	course.name = "RaceCourse"
	add_child(course)
	course.start_gate(geo, Vector3(0, 0.05, 25), 0.0)
	course.gate(geo, Vector3(0, 0.05, 0), 0.0)
	course.gate(geo, Vector3(0, 0.05, -30), 0.0, 3, 0.0, 2, "gate_b") # ladder, top opening
	course.flag(geo, Vector3(1, 0.05, -52), "gate_b")
	course.dive_gate(geo, Vector3(-25, 0.05, -45), 0.0, 4.0)
	course.gate(geo, Vector3(-45, 0.05, -22), PI, 1, 1.52)            # tower gate, flown south
	course.hurdle(geo, Vector3(-45, 0.05, 2), PI)
	course.gate(geo, Vector3(-26, 0.05, 34), -PI * 0.5, 2, 0.0, 1)   # double gate, upper
	course.flag(geo, Vector3(8, 0.05, 46))
	for p in [Vector3(-60, 0.05, -40), Vector3(-15, 0.05, -60), Vector3(30, 0.05, 10)]:
		course.flag(geo, p, "gate_b")

	_safety_net(52.0, -60.0, 50.0)
	_pilot_stand(Vector3(12, 0.05, 56))
	for i in range(4):
		_tent(Vector3(-30 + i * 9, 0.05, 64), "canopy_blue" if i % 2 == 0 else "canopy_orange")
	for i in range(7):
		_car(Vector3(-28 + i * 5.5, 0.05, 75), ["car_red", "car_grey", "car_white"][i % 3])
	_trees()

func after_build() -> void:
	course.setup("race_field", drone, ui)

## Tall black net between the course and the people.
func _safety_net(z: float, x0: float, x1: float) -> void:
	var n: int = int((x1 - x0) / 4.0)
	for i in range(n + 1):
		var x: float = x0 + i * 4.0
		geo.cylinder(Vector3(x, 0.05, z), Vector3(x, 3.5, z), 0.05, "post", 6)
	for y in [0.3, 1.2, 2.1, 3.0, 3.45]:
		geo.box(Vector3((x0 + x1) * 0.5, y, z), Vector3(x1 - x0, 0.03, 0.03), "net")
	for i in range(n * 4):
		var x: float = x0 + i * 1.0 + 0.5
		geo.box(Vector3(x, 1.75, z), Vector3(0.02, 3.4, 0.02), "net", 0.0, false, false)

func _pilot_stand(o: Vector3) -> void:
	geo.box(o + Vector3(0, 0.5, 0), Vector3(8, 1.0, 3), "wood")
	for dx in [-3.8, 3.8]:
		for dz in [-1.3, 1.3]:
			geo.box(o + Vector3(dx, 2.0, dz), Vector3(0.1, 2.0, 0.1), "post")
	geo.box(o + Vector3(0, 3.05, 0), Vector3(8.6, 0.1, 3.6), "canopy_blue")
	for i in range(4):
		geo.box(o + Vector3(-3 + i * 2, 1.35, -0.5), Vector3(0.5, 0.7, 0.5), "table") # pilot chairs

func _tent(o: Vector3, canopy: String) -> void:
	for dx in [-1.5, 1.5]:
		for dz in [-1.5, 1.5]:
			geo.box(o + Vector3(dx, 1.1, dz), Vector3(0.05, 2.2, 0.05), "post")
	geo.cone(o + Vector3(0, 2.2, 0), o + Vector3(0, 2.9, 0), 2.2, 0.05, canopy, 4, true)
	geo.box(o + Vector3(0, 0.75, -0.8), Vector3(2.4, 0.05, 0.8), "table")
	for dx in [-1.1, 1.1]:
		geo.box(o + Vector3(dx, 0.37, -0.8), Vector3(0.05, 0.74, 0.7), "post")

func _car(o: Vector3, paint: String) -> void:
	geo.box(o + Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.3), paint)
	geo.box(o + Vector3(0, 1.15, 0.2), Vector3(1.6, 0.55, 2.3), "glass")
	for dx in [-0.8, 0.8]:
		for dz in [-1.4, 1.4]:
			geo.cylinder(o + Vector3(dx - 0.1, 0.33, dz), o + Vector3(dx + 0.1, 0.33, dz), 0.32, "net", 10)

func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var trees: Array = []
	for i in range(160):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(100, 190)
		var p := Vector3(cos(a) * r - 10, 0, sin(a) * r)
		trees.append([p, rng.randi_range(0, 1), rng.randf_range(0.9, 1.4)])
	Forest.plant(self, trees)
