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
## Rebuilt 2026-10-10 for the race mode rework (6 tracks per race map,
## DEV_TODO "Race mode rework"): the mown field is bigger (170 x 143 m)
## and carries fixed scenery the tracks can use (ANCHORS): a scaffold
## tower in the north-west corner, an old cattle shed (fly through) in
## the north-east, a straw-bale chicane along the north edge, a parked
## tractor with a bale trailer on the west edge. Track 1 is the course
## below, unchanged; the infield (ANCHORS "infield") stays clear for the
## other tracks' gates.

## Fixed points on the field for the coming tracks (and the race mode's
## track data): where each piece of scenery is and its way through.
const FIELD := Rect2(-95, -88, 170, 143)
const ANCHORS: Dictionary = {
	"scaffold": Vector3(-78, 0, -72), ## 6 x 6 m, 12 m tall, open bays at 3/6/9 m; dive through the middle
	"shed": Vector3(60, 0, -72), ## 18 x 8 m, ridge along x; doors at both ends (x +-9), roof half fallen in
	"bales": Rect2(-40, -82, 70, 4), ## the chicane: bale pairs with 6 m gaps along z -80
	"tractor": Vector3(-88, 0, 18), ## tractor + trailer, facing north - a hurdle to skim
	"infield": Rect2(-45, -40, 80, 60), ## kept clear: gates of the other tracks
}

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
	return [150.0, 185.0, 250.0, 310.0]

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
		["scaffold", Vector3(-60, 6, -55), Vector3(-78, 5, -72)],
		["shed", Vector3(80, 3, -72), Vector3(60, 2.5, -72)],
		["bales", Vector3(-50, 3, -70), Vector3(20, 1, -80)],
		["clubhouse", Vector3(78, 4, 86), Vector3(63, 2, 68)],
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
	geo.slab(FIELD, 0.05, 0.1, "field")
	geo.slab(Rect2(-40, 58, 90, 22), 0.05, 0.1, "gravel") # pits + car park

	_anchors()
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
	# (HouseCreator, one storey, open: fly in through the terrace door.)
	HouseCreator.build(geo, Vector3(63, 0.05, 68), 0.0, 4711, {"storeys": 1, "garage": "none"})
	city.house(Vector3(-60, 0, 125), 0.0, 14, 10, 2)
	for k in range(3):
		city.building(Vector3(-30 + k * 22, 0, 135), Vector2(18, 12), 0.0, 2, "cty_brick", "gable", false)

func after_build() -> void:
	course = RaceCourse.make(self, tracks())
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
		var inside: bool = FIELD.grow(8.0).has_point(Vector2(p.x, p.z))
		for poly: PackedVector2Array in _field_polys:
			inside = inside or Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), poly)
		if not inside:
			trees.append(entry) # not in a crop
	trees.append_array(_field_trees)
	TreeCreator.plant(self, geo, trees)

## The field's fixed scenery (ANCHORS): things every track can use.
func _anchors() -> void:
	var r := RandomNumberGenerator.new()
	r.seed = 1210
	if not geo.has_material("rf_straw"):
		geo.add_material("rf_straw", Geo.flat_mat(Color(0.86, 0.72, 0.38), 0.9))
		geo.add_material("rf_plank", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.8, 0.72, 0.6), 1.5))
		geo.add_material("rf_stone", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.05, 0.95, 0.88), 3.0))
	# Scaffold tower: 2 x 2 bays of 3 m, four lifts; planked decks at 3 m
	# (half) and 9 m (round the edge only) - the middle open from the top
	# down to the 3 m deck: a dive.
	var sc: Vector3 = ANCHORS.scaffold
	for i in range(3):
		for j in range(3):
			var q: Vector3 = sc + Vector3(-3.0 + i * 3.0, 0, -3.0 + j * 3.0)
			geo.cylinder(q + Vector3(0, 0.05, 0), q + Vector3(0, 12.0, 0), 0.05, "post", 6)
			geo.box(q + Vector3(0, 0.1, 0), Vector3(0.3, 0.1, 0.3), "rf_plank")
	for y in [3.0, 6.0, 9.0, 12.0]:
		for k in range(3):
			var o: float = -3.0 + k * 3.0
			geo.beam(sc + Vector3(-3, y, o), sc + Vector3(3, y, o), Vector2(0.1, 0.1), "post")
			geo.beam(sc + Vector3(o, y, -3), sc + Vector3(o, y, 3), Vector2(0.1, 0.1), "post")
	geo.box(sc + Vector3(-1.5, 3.08, 0), Vector3(3.0, 0.06, 6.0), "rf_plank")
	for e: Array in [[Vector3(0, 9.08, -2.4), Vector3(6, 0.06, 1.2)], [Vector3(0, 9.08, 2.4), Vector3(6, 0.06, 1.2)],
			[Vector3(-2.4, 9.08, 0), Vector3(1.2, 0.06, 3.6)], [Vector3(2.4, 9.08, 0), Vector3(1.2, 0.06, 3.6)]]:
		geo.box(sc + e[0], e[1], "rf_plank")
	for d in [-1.0, 1.0]: # diagonal braces on two faces
		geo.beam(sc + Vector3(-3, 0.1, d * 3.0), sc + Vector3(3, 6.0, d * 3.0), Vector2(0.08, 0.08), "post")
	# Old cattle shed: stone walls, doors at both gable ends, windows down the
	# sides, the roof's south slope fallen in.
	var sh: Vector3 = ANCHORS.shed
	var L: float = 18.0
	var B: float = 8.0
	var xf := Transform3D(Basis(), sh)
	for s in [-1.0, 1.0]:
		var side := Transform3D(Basis(), sh + Vector3(0, 0, s * B * 0.5))
		BuildKit.wall(geo, side, -L * 0.5, L * 0.5, 0.0, 3.6, 0.5, [Rect2(-6.0, 1.2, 1.4, 1.2), Rect2(-1.0, 1.2, 1.4, 1.2), Rect2(4.0, 1.2, 1.4, 1.2)], "rf_stone", 0.0)
		var end := Transform3D(Basis(Vector3.UP, PI * 0.5), sh + Vector3(s * (L * 0.5 - 0.25), 0, 0))
		BuildKit.wall(geo, end, -B * 0.5 + 0.5, B * 0.5 - 0.5, 0.0, 3.6, 0.5, [Rect2(-1.6, 0.0, 3.2, 3.0)], "rf_stone", 0.0)
		BuildKit.gable(geo, end, -B * 0.5, B * 0.5, 3.6, 2.6, 0.5, "rf_stone")
	BuildKit.roof(geo, Transform3D(Basis(Vector3.UP, PI * 0.5), sh), B * 0.5, L + 0.8, 3.6, atan(2.6 / (B * 0.5)), 0.15, 0.4, "rf_plank", -1)
	# Straw-bale chicane: pairs of round bales, a 6 m gap between pairs,
	# every third pair topped with a third bale.
	var bz: float = ANCHORS.bales.get_center().y
	var x: float = ANCHORS.bales.position.x
	var k: int = 0
	while x < ANCHORS.bales.end.x:
		for dx in [0.0, 1.6]:
			geo.cylinder(Vector3(x + dx, 0.8, bz - 0.6), Vector3(x + dx, 0.8, bz + 0.6), 0.75, "rf_straw", 14)
		if k % 3 == 0:
			geo.cylinder(Vector3(x + 0.8, 2.1, bz - 0.6), Vector3(x + 0.8, 2.1, bz + 0.6), 0.75, "rf_straw", 14)
		x += 7.6
		k += 1
	# Tractor with a bale trailer on the west edge.
	FarmCreator.tractor(geo, ANCHORS.tractor + Vector3(0, 0.05, 0), 0.0, "fm_red", true, r)

## The map's tracks (RaceCourse.make builds the one Settings.race_track
## picks, at load time on top of the cached map). Tracks 2-6 are
## placeholders (track 1's course) until they are designed.
func tracks() -> Array:
	var t1: Array = [
		["start", Vector3(0, 0.05, 30), -PI * 0.5],
		["gate", Vector3(25, 0.05, 30), -PI * 0.5],
		["gate", Vector3(45, 0.05, 8), 0.0, 1, 0.0, 0, "gate_b"],
		["gate", Vector3(45, 0.05, -20), 0.0, 3, 0.0, 2], # ladder, top opening
		["dive", Vector3(35, 0.05, -45), 0.0, 5.0],
		["hurdle", Vector3(10, 0.05, -55), PI * 0.5, "gate_a"],
		["gate", Vector3(-15, 0.05, -52), PI * 0.5, 2, 0.0, 1, "gate_b"], # double gate, upper
		["gate", Vector3(-45, 0.05, -50), PI * 0.5, 1, 1.52], # tower gate
		["gate", Vector3(-62, 0.05, -20), PI, 1, 0.0, 0, "gate_b"],
		["dive", Vector3(-60, 0.05, 5), 0.0, 4.0, "gate_a"],
		["hurdle", Vector3(-40, 0.05, 28), -PI * 0.5],
		["gate", Vector3(-20, 0.05, 30), -PI * 0.5, 1, 0.0, 0, "gate_b"],
		# Turn flags at the corners.
		["flag", Vector3(56, 0.05, 40), "gate_b"], ["flag", Vector3(52, 0.05, -58), "gate_b"],
		["flag", Vector3(-68, 0.05, -60), "gate_b"], ["flag", Vector3(-70, 0.05, 36), "gate_b"],
	]
	var out: Array = [{"name": "Club Loop", "level": "easy", "calls": t1}]
	for k in range(2, 7):
		out.append({"name": "Track %d" % k, "level": ["easy", "medium", "medium", "hard", "hard"][k - 2], "calls": t1})
	return out
