extends BuiltMap

## Race Field - a club race day on a mown field (Low performance).
## Course (fly order, north = -z), all MultiGP standard obstacles, a
## clockwise lap round the whole field (redesigned 2026-10-02 for flow:
## every straight ends in a different kind of obstacle, two dives, a
## climb through the ladder's top, turn flags at the corners):
##   START (0,30) east -> gate (25,30) -> left: gate (45,8) north ->
##   ladder, top opening (45,-20) -> dive gate (35,-45) -> left: hurdle
##   (10,-55) west -> double gate, upper (-15,-52) -> tower gate
##   (-45,-50) -> left: gate (-62,-20) south -> dive gate (-60,5) ->
##   left: hurdle (-40,28) east -> gate (-20,30) -> START.
## South of the course: safety net, pilot stand, pit tents, car park.

var course: RaceCourse
## Hedgerow trees from the surrounding farm fields, planted with the tree ring.
var _field_trees: Array = []
var _field_polys: Array = []
var _field_views: Array = []

## FieldCreator wants a TerrainCreator for the ground and its drape grid; this
## field is dead flat, so a flat stand-in with a grid at the origin answers.
class FlatLand extends TerrainCreator:
	func ground(_x: float, _z: float) -> float:
		return 0.0

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-55, 25, 0), "shadow_ground_y": 0.0, "shadow_region": Rect2(-128, -128, 256, 256)}

func border() -> Array:
	return [110.0, 140.0, 250.0, 310.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(30, 28, 70), Vector3(-15, 0, -5)],
		["start", Vector3(-8, 1.3, 30), Vector3(25, 1.3, 30)],
		["ladder", Vector3(45, 3.5, -2), Vector3(45, 4.2, -20)],
		["dive", Vector3(35, 9, -32), Vector3(35, 4, -45)],
		["pits", Vector3(-10, 3, 45), Vector3(10, 1, 62)],
		# The tree ring round the field.
		["treeline_n", Vector3(-10, 5, -50), Vector3(-10, 6, -130)],
		["treeline_e", Vector3(50, 3, 10), Vector3(130, 6, 40)],
		["fields", Vector3(-20, 55, 60), Vector3(20, 0, -110)],
	] + _field_views

func build() -> void:
	geo.ao_height = 1.5
	RaceCourse.add_materials(geo)
	geo.add_material("field", Geo.ground_mat(MapTextures.get_tex("mown_grass"), Color.WHITE, 12.0, 1, 0.2))
	geo.add_material("meadow", Geo.ground_mat(MapTextures.get_tex("meadow"), Color(0.95, 0.95, 0.9), 8.0, 0, 0.45))
	geo.add_material("gravel", Geo.ground_mat(ProceduralTextures.gravel_texture(), Color(0.7, 0.68, 0.64), 3.0, 2, 0.3))
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

	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "meadow")
	geo.slab(Rect2(-80, -70, 140, 125), 0.05, 0.1, "field")
	geo.slab(Rect2(-40, 58, 90, 22), 0.05, 0.1, "gravel") # pits + car park

	course = RaceCourse.new()
	course.name = "RaceCourse"
	add_child(course)
	var E: float = -PI * 0.5
	var W: float = PI * 0.5
	var S: float = PI
	course.start_gate(geo, Vector3(0, 0.05, 30), E)
	course.gate(geo, Vector3(25, 0.05, 30), E)
	course.gate(geo, Vector3(45, 0.05, 8), 0.0, 1, 0.0, 0, "gate_b")
	course.gate(geo, Vector3(45, 0.05, -20), 0.0, 3, 0.0, 2)           # ladder, top opening
	course.dive_gate(geo, Vector3(35, 0.05, -45), 0.0, 5.0)
	course.hurdle(geo, Vector3(10, 0.05, -55), W, "gate_a")
	course.gate(geo, Vector3(-15, 0.05, -52), W, 2, 0.0, 1, "gate_b")  # double gate, upper
	course.gate(geo, Vector3(-45, 0.05, -50), W, 1, 1.52)              # tower gate
	course.gate(geo, Vector3(-62, 0.05, -20), S, 1, 0.0, 0, "gate_b")
	course.dive_gate(geo, Vector3(-60, 0.05, 5), 0.0, 4.0, "gate_a")
	course.hurdle(geo, Vector3(-40, 0.05, 28), E)
	course.gate(geo, Vector3(-20, 0.05, 30), E, 1, 0.0, 0, "gate_b")
	# Turn flags at the corners.
	for p in [Vector3(56, 0.05, 40), Vector3(52, 0.05, -58), Vector3(-68, 0.05, -60), Vector3(-70, 0.05, 36)]:
		course.flag(geo, p, "gate_b")

	_safety_net(52.0, -60.0, 50.0)
	_pilot_stand(Vector3(12, 0.05, 56))
	for i in range(4):
		_tent(Vector3(-30 + i * 9, 0.05, 64), "canopy_blue" if i % 2 == 0 else "canopy_orange")
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in range(14):
		if rng.randf() < 0.8:
			fleet.car(Vector3(-36 + i * 3.0, 0.05, 76), PI if i % 2 else 0.0, Fleet.random_paint(rng), ["estate", "suv", "van", "hatch", "pickup"][rng.randi() % 5])
	_country_road(rng)
	_farm_fields()
	_trees()

## Farm fields round the course (FieldCreator): wheat east, rapeseed north,
## stubble with round bales west, a mown meadow with bales north-east. All
## are 25 m or more outside the mown field, so the racing line and its
## surroundings stay as they were; scenery only (the crops do not collide).
func _farm_fields() -> void:
	var land := FlatLand.new()
	land.set_extent(Rect2(-200, -200, 400, 400), 8.0)
	land._nx = 51
	land._nz = 51
	var frng := RandomNumberGenerator.new()
	frng.seed = 33
	for fd: Array in [
		["wheat", [Vector2(85, -75), Vector2(135, -75), Vector2(135, -5), Vector2(85, -5)], [0, 1]],
		["rapeseed", [Vector2(-100, -135), Vector2(-20, -135), Vector2(-20, -95), Vector2(-100, -95)], [0]],
		["stubble", [Vector2(-150, -50), Vector2(-105, -50), Vector2(-105, 30), Vector2(-150, 30)], [0, 3]],
		["meadow", [Vector2(70, -150), Vector2(130, -150), Vector2(130, -95), Vector2(70, -95)], [1]],
	]:
		var fi: Dictionary = FieldCreator.build(geo, land, fd[1], fd[0], frng, {"hedges": fd[2]})
		_field_trees.append_array(fi.trees)
		_field_views.append_array(fi.views)
		_field_polys.append(FieldCreator.poly(fd[1]))

## The lane from the car park to the country road, which runs past the
## field and on out of the map both ways; a farm and a clubhouse.
func _country_road(rng: RandomNumberGenerator) -> void:
	var roads := Roads.new(geo, rng, fleet)
	roads.junction(Vector3(5, 0, 100), Vector2(7, 7), [], 0.0)
	roads.road(Route.from(Vector3(5, 0, 80), 90.0).straight(16.5, 4.0), 4.5, {"centre": "none", "old": true})
	for r in [Route.from(Vector3(1.5, 0, 100), 180.0).straight(900.0, 16.0).arc(1200.0, 8.0, 16.0).straight(2200.0, 20.0),
			Route.from(Vector3(8.5, 0, 100), 0.0).straight(700.0, 16.0).arc(1500.0, -6.0, 16.0).straight(2400.0, 20.0)]:
		roads.road(r, 7.0, {"verge": 1.2, "detail": 500.0, "edge_lines": true})
		roads.traffic(Route.from_pts(r.slice(0.0, 700.0)), 7.0, 1, 6.0, 0.15)
	var city := City.new(geo, rng, fleet)
	# Clubhouse by the car park, a farm across the road.
	city.building(Vector3(40, 0.05, 70), Vector2(14, 8), 0.0, 1, "cty_plaster_warm", "gable", false)
	city.house(Vector3(-60, 0, 125), 0.0, 14, 10, 2)
	for k in range(3):
		city.building(Vector3(-30 + k * 22, 0, 135), Vector2(18, 12), 0.0, 2, "cty_brick", "gable", false)

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

## The tree ring round the field (TreeCreator): maples, birches and
## spruces, grown taller than garden trees (old field-edge trees, the size the
## old Forest trees here were); few copper beeches (plain), they shout. The
## odd surprise stays switched on: a race-day field is exactly where a
## quad ends up stuck in a crown.
func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	var trees: Array = []
	for i in range(160):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(100, 190)
		var p := Vector3(cos(a) * r - 10, 0, sin(a) * r)
		var f: float = rng.randf()
		var sp: String = "maple" if f < 0.45 else ("birch" if f < 0.7 else "spruce")
		# (the rng draws happen before the field test: the ring keeps its layout)
		var entry: Array = [p, sp, rng.randi(), "random", rng.randf() < 0.6, rng.randf_range(1.3, 1.7) * (1.25 if sp == "spruce" else 1.0)]
		var inside: bool = false
		for poly: PackedVector2Array in _field_polys:
			inside = inside or Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), poly)
		if not inside:
			trees.append(entry) # not in a crop
	trees.append_array(_field_trees)
	TreeCreator.plant(self, geo, trees)
