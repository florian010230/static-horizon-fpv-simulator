extends BuiltMap

## Playground - a fenced neighbourhood playground at real size, for the
## Tiny Whoop (Low performance: small, few materials, no terrain).
##
## Layout (north = -z; spawn on the path just inside the gate):
##   south fence, gate  -> paved path -> small plaza with benches
##   west:  play tower (two towers, rope bridge, slide, climbing net,
##          fireman's pole) on rubber flooring
##   north-east: swing set;   north: merry-go-round
##   south-west: tunnel tubes and a see-saw;  south-east: sandbox
##   outside: trees, a street and a row of houses to the north.

const FENCE := Rect2(-22, -16, 44, 32)

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-42, -30, 0), "fog_density": 0.0012,
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-64, -64, 128, 128)}

func border() -> Array:
	return [40.0, 55.0, 18.0, 28.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(0, 14, 26), Vector3(-2, 0, -4)],
		["tower", Vector3(-6, 1.6, -3), Vector3(-15, 1.5, -9)],
		["swings", Vector3(12, 1.2, -4), Vector3(12, 1.2, -10)],
		["tube", Vector3(-19.5, 0.62, 6), Vector3(-12, 0.62, 6)],
		["top", Vector3(0, 45, 0.1), Vector3(0, 0, 0)],
		["trees", Vector3(4, 2.5, 12), Vector3(28, 4, 30)],
	]

func build() -> void:
	geo.ao_height = 1.2
	geo.add_material("grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.add_material("rubber", Geo.ground_mat(MapTextures.get_tex("rubber"), Color.WHITE, 2.0, 2, 0.2))
	geo.add_material("sand", Geo.tex_mat(MapTextures.get_tex("sand"), Color.WHITE, 2.0))
	geo.add_material("paving", Geo.ground_mat(ProceduralTextures.paving_texture(), Color(0.78, 0.76, 0.72), 2.0, 1, 0.2))
	geo.add_material("wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color.WHITE, 1.5))
	geo.add_material("red", Geo.flat_mat(Color(0.78, 0.16, 0.12), 0.5))
	geo.add_material("blue", Geo.flat_mat(Color(0.14, 0.36, 0.72), 0.5))
	geo.add_material("yellow", Geo.flat_mat(Color(0.92, 0.72, 0.1), 0.5))
	geo.add_material("green", Geo.flat_mat(Color(0.2, 0.55, 0.25), 0.5))
	geo.add_material("steel", Geo.flat_mat(Color(0.62, 0.64, 0.66), 0.35, 0.6))
	geo.add_material("rope", Geo.flat_mat(Color(0.35, 0.28, 0.18), 0.9))
	geo.add_material("concrete", Geo.tex_mat(ProceduralTextures.concrete_texture(), Color(0.9, 0.9, 0.88), 3.0))
	geo.add_material("plaster", Geo.flat_mat(Color(0.86, 0.8, 0.7)))
	geo.add_material("roof", Geo.flat_mat(Color(0.5, 0.2, 0.15)))
	geo.add_material("window", Geo.flat_mat(Color(0.16, 0.2, 0.25), 0.2, 0.3))
	geo.add_material("hedge", Geo.flat_mat(Color(0.18, 0.34, 0.14), 0.95))

	# Ground layers, 5-6 cm apart (flush layers z-fight at distance).
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "grass")
	geo.slab(Rect2(-1.2, 1.0, 2.4, 22.0), 0.05, 0.1, "paving")      # path from the gate
	geo.slab(Rect2(-5, -3, 10, 6), 0.05, 0.1, "paving")              # plaza
	geo.slab(Rect2(-20.5, -14.5, 17, 15), 0.06, 0.1, "rubber")        # tower
	geo.slab(Rect2(6.5, -14.5, 12, 9), 0.06, 0.1, "rubber")           # swings
	geo.slab(Rect2(-19, 3.5, 13, 9), 0.06, 0.1, "rubber")             # tubes/see-saw
	_street()

	_fence()
	_play_tower(Vector3(-15, 0, -9))
	_swings(Vector3(12, 0, -10))
	_merry_go_round(Vector3(0, 0, -10))
	_tubes_and_seesaw()
	_sandbox(Rect2(8, 4, 8, 7))
	_plaza_furniture()
	_shelter(Vector3(-17, 0, 13))
	_houses()
	_trees()

func after_build() -> void:
	Collectibles.gnome(self, "playground", 0, Transform3D(Basis(Vector3.UP, 2.4), Vector3(3.2, 0.0, 15.0)))

func _fence() -> void:
	var r := FENCE
	var corners: Array[Vector2] = [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in range(4):
		var a: Vector2 = corners[i]
		var b: Vector2 = corners[(i + 1) % 4]
		var segs: int = int(a.distance_to(b) / 2.5)
		for s in range(segs):
			var p0: Vector2 = a.lerp(b, float(s) / segs)
			var p1: Vector2 = a.lerp(b, float(s + 1) / segs)
			# The gate: a gap in the south fence around x = 0.
			if i == 2 and absf((p0.x + p1.x) * 0.5) < 1.5:
				continue
			geo.box(Vector3(p0.x, 0.55, p0.y), Vector3(0.08, 1.1, 0.08), "green")
			for y in [0.35, 0.95]:
				geo.beam(Vector3(p0.x, y, p0.y), Vector3(p1.x, y, p1.y), Vector2(0.04, 0.04), "green")
			for k in range(1, 10):
				var q: Vector2 = p0.lerp(p1, k / 10.0)
				geo.box(Vector3(q.x, 0.62, q.y), Vector3(0.025, 0.7, 0.025), "green", 0.0, true, false)
	# Hedge outside the north fence.
	geo.box(Vector3(0, 0.6, -17.2), Vector3(44, 1.2, 0.9), "hedge")

func _play_tower(o: Vector3) -> void:
	var plat_y: float = 1.5
	for tx in [0.0, 6.0]:
		var c: Vector3 = o + Vector3(tx, 0, 0)
		for dx in [-0.8, 0.8]:
			for dz in [-0.8, 0.8]:
				geo.box(c + Vector3(dx, 1.45, dz), Vector3(0.12, 2.9, 0.12), "wood")
		geo.box(c + Vector3(0, plat_y, 0), Vector3(1.72, 0.08, 1.72), "wood")
		# Pyramid roof (a 4-sided cone) and railings on three sides.
		geo.cone(c + Vector3(0, 2.9, 0), c + Vector3(0, 3.7, 0), 1.35, 0.02, "red" if tx == 0.0 else "blue", 4)
		for side in [Vector3(0, 0, -0.8), Vector3(0, 0, 0.8)]:
			geo.box(c + side + Vector3(0, plat_y + 0.45, 0), Vector3(1.6, 0.9, 0.05), "yellow")
	# Rope bridge between the towers: plank deck and rope hand rails.
	var a: Vector3 = o + Vector3(0.86, plat_y, 0)
	var b: Vector3 = o + Vector3(5.14, plat_y, 0)
	for i in range(12):
		var t: float = (i + 0.5) / 12.0
		var sag: float = sin(t * PI) * 0.18
		geo.box(a.lerp(b, t) - Vector3(0, sag, 0), Vector3(0.28, 0.05, 0.9), "wood")
	for dz in [-0.5, 0.5]:
		geo.beam(a + Vector3(0, 0.8, dz), b + Vector3(0, 0.8, dz), Vector2(0.04, 0.04), "rope")
	# Slide off the east tower.
	var s0: Vector3 = o + Vector3(6.9, plat_y, 0)
	var s1: Vector3 = o + Vector3(10.4, 0.35, 0)
	geo.beam(s0, s1, Vector2(0.5, 0.05), "steel")
	for dz in [-0.27, 0.27]:
		geo.beam(s0 + Vector3(0, 0.15, dz), s1 + Vector3(0, 0.15, dz), Vector2(0.04, 0.3), "yellow")
	# Climbing net up the west tower: a rope grid.
	var n0: Vector3 = o + Vector3(-3.2, 0.06, 0)
	var n1: Vector3 = o + Vector3(-0.86, plat_y, 0)
	for k in range(5):
		var dz: float = -0.8 + k * 0.4
		geo.beam(n0 + Vector3(0, 0, dz), n1 + Vector3(0, 0, dz), Vector2(0.03, 0.03), "rope")
	for k in range(1, 6):
		var p: Vector3 = n0.lerp(n1, k / 6.0)
		geo.beam(p + Vector3(0, 0, -0.8), p + Vector3(0, 0, 0.8), Vector2(0.03, 0.03), "rope")
	# Fireman's pole.
	geo.cylinder(o + Vector3(0, 0, -1.8), o + Vector3(0, 2.8, -1.8), 0.035, "steel", 8)
	geo.beam(o + Vector3(0, 2.8, -1.8), o + Vector3(0, 2.8, -0.8), Vector2(0.05, 0.05), "steel")

func _swings(o: Vector3) -> void:
	var top_y: float = 2.4
	for x in [-4.0, 4.0]:
		for dz in [-1.2, 1.2]:
			geo.beam(o + Vector3(x, 0, dz), o + Vector3(x, top_y, 0), Vector2(0.1, 0.1), "blue")
	geo.cylinder(o + Vector3(-4.1, top_y, 0), o + Vector3(4.1, top_y, 0), 0.07, "blue", 10)
	for x in [-2.0, 0.0, 2.0]:
		for dx in [-0.22, 0.22]:
			geo.beam(o + Vector3(x + dx, top_y, 0), o + Vector3(x + dx, 0.5, 0), Vector2(0.015, 0.015), "steel")
		geo.box(o + Vector3(x, 0.48, 0), Vector3(0.5, 0.04, 0.2), "rope")

func _merry_go_round(o: Vector3) -> void:
	geo.slab(Rect2(o.x - 2.2, o.z - 2.2, 4.4, 4.4), 0.06, 0.1, "rubber")
	geo.cylinder(o + Vector3(0, 0.2, 0), o + Vector3(0, 0.32, 0), 1.5, "red", 20)
	geo.cylinder(o + Vector3(0, 0.32, 0), o + Vector3(0, 1.0, 0), 0.06, "steel", 8)
	for i in range(6):
		var a: float = TAU * i / 6.0
		var r := Vector3(cos(a), 0, sin(a))
		geo.beam(o + Vector3(0, 0.95, 0), o + r * 1.3 + Vector3(0, 0.75, 0), Vector2(0.035, 0.035), "steel")
		geo.beam(o + r * 1.3 + Vector3(0, 0.32, 0), o + r * 1.3 + Vector3(0, 0.75, 0), Vector2(0.035, 0.035), "steel")

func _tubes_and_seesaw() -> void:
	# Two crawl tubes - big enough for a whoop to fly straight through.
	geo.pipe(Vector3(-17.5, 0.62, 6), Vector3(-13.5, 0.62, 6), 0.55, 0.06, "yellow", 20)
	geo.pipe(Vector3(-12, 0.62, 9.5), Vector3(-12, 0.62, 5.5), 0.55, 0.06, "green", 20)
	# See-saw.
	var c := Vector3(-16, 0, 10)
	geo.box(c + Vector3(0, 0.3, 0), Vector3(0.3, 0.5, 0.4), "steel")
	var tilt: float = 0.18
	geo.beam(c + Vector3(-1.8, 0.45 - sin(tilt) * 1.8, 0), c + Vector3(1.8, 0.45 + sin(tilt) * 1.8, 0), Vector2(0.3, 0.06), "red")

func _sandbox(r: Rect2) -> void:
	geo.slab(r.grow(-0.1), 0.1, 0.2, "sand")
	for side in [[r.position, Vector2(r.end.x, r.position.y)], [Vector2(r.end.x, r.position.y), r.end], [r.end, Vector2(r.position.x, r.end.y)], [Vector2(r.position.x, r.end.y), r.position]]:
		geo.beam(Vector3(side[0].x, 0.15, side[0].y), Vector3(side[1].x, 0.15, side[1].y), Vector2(0.18, 0.3), "wood")
	geo.box(Vector3(r.get_center().x + 2, 0.3, r.get_center().y), Vector3(1.2, 0.4, 0.8), "wood") # sand table

func _plaza_furniture() -> void:
	for p in [Vector3(-3.5, 0, -2.2), Vector3(3.5, 0, -2.2), Vector3(-3.5, 0, 2.2), Vector3(3.5, 0, 2.2)]:
		_bench(p)
	geo.cylinder(Vector3(4.6, 0.1, 0), Vector3(4.6, 0.95, 0), 0.25, "green", 10) # bin
	# Concrete table-tennis table.
	geo.box(Vector3(3, 0.38, 9), Vector3(0.4, 0.66, 1.2), "concrete")
	geo.box(Vector3(3, 0.74, 9), Vector3(2.74, 0.06, 1.52), "concrete")
	geo.box(Vector3(3, 0.85, 9), Vector3(0.03, 0.16, 1.6), "steel")
	# Lamp posts along the path.
	for z in [3.0, 13.0]:
		geo.cylinder(Vector3(1.8, 0.05, z), Vector3(1.8, 4.0, z), 0.06, "steel", 8)
		geo.box(Vector3(1.8, 4.05, z), Vector3(0.5, 0.12, 0.25), "steel")

func _bench(p: Vector3) -> void:
	geo.box(p + Vector3(0, 0.45, 0), Vector3(1.8, 0.05, 0.4), "wood")
	geo.box(p + Vector3(0, 0.75, 0.2 * signf(p.z)), Vector3(1.8, 0.3, 0.04), "wood")
	for dx in [-0.75, 0.75]:
		geo.box(p + Vector3(dx, 0.22, 0), Vector3(0.06, 0.44, 0.4), "steel")

func _shelter(o: Vector3) -> void:
	for dx in [-1.8, 1.8]:
		for dz in [-1.3, 1.3]:
			geo.box(o + Vector3(dx, 1.2, dz), Vector3(0.15, 2.4, 0.15), "wood")
	geo.box(o + Vector3(0, 2.5, 0), Vector3(4.2, 0.12, 3.2), "roof")
	geo.box(o + Vector3(0, 0.75, 0), Vector3(3.0, 0.06, 1.0), "wood")

## The street north of the playground: through the neighbourhood and on
## out of the map both ways, a side street south along the park's east
## side, parked cars, a few driving, houses along both.
var rng := RandomNumberGenerator.new()

func _street() -> void:
	rng.seed = 77
	var roads := Roads.new(geo, rng, fleet)
	var city := City.new(geo, rng, fleet)
	roads.junction(Vector3(34, 0, -23.5), Vector2(7, 7), ["w", "e"], 1.8)
	var w := Route.from(Vector3(30.5, 0, -23.5), 180.0).straight(3000.0, 20.0)
	var e := Route.from(Vector3(37.5, 0, -23.5), 0.0).straight(3000.0, 20.0)
	var side := Route.from(Vector3(34, 0, -20.0), 90.0).straight(3000.0, 20.0)
	for r in [w, e, side]:
		roads.road(r, 7.0, {"walk": 1.8, "lamps": 25.0, "detail": 350.0})
		roads.parked(Route.from_pts(r.slice(0.0, 300.0)), 2.3, 0.4)
		roads.traffic(Route.from_pts(r.slice(0.0, 500.0)), 4.0, 1, 8.0, 0.0)
	# Houses along the street (the six opposite the playground are below).
	for k in range(30):
		for sgn in [-1.0, 1.0]:
			var x: float = sgn * (62.0 + k * 16.0)
			city.house(Vector3(x, 0, -36), 0.0, rng.randf_range(9, 12), 9.0)
			if absf(x) > 50.0:
				city.house(Vector3(x, 0, -9), 0.0, rng.randf_range(9, 12), 9.0)
	for k in range(25):
		city.house(Vector3(48, 0, 5 + k * 16.0), PI * 0.5, rng.randf_range(9, 12), 9.0)
	Forest.plant(self, city.trees, self)

## A row of simple houses across the street, so the playground sits in
## a neighbourhood instead of in a void.
func _houses() -> void:
	for i in range(6):
		var c := Vector3(-45 + i * 18, 0, -36)
		var w: float = 10.0 + (i % 3)
		geo.box(c + Vector3(0, 3.2, 0), Vector3(w, 6.4, 9), "plaster")
		# Gable roof: two tilted slabs.
		for s in [-1.0, 1.0]:
			var xf := Transform3D(Basis(Vector3.RIGHT, s * 0.6), c + Vector3(0, 7.7, s * 2.4))
			geo.box_xf(xf, Vector3(w + 0.6, 0.2, 5.8), "roof")
		geo.box(c + Vector3(0, 1.1, 4.52), Vector3(1.0, 2.1, 0.05), "rope")
		for fy in [1.6, 4.6]:
			for fx in [-w * 0.32, w * 0.32] + ([] if fy < 3.0 else [0.0]):
				geo.box(c + Vector3(fx, fy, 4.52), Vector3(1.3, 1.3, 0.05), "window", 0.0, false, false)

## Trees (TreeCreator): big maples and birches shading the playground
## inside the fence, the garden mix round it - now and then a birdhouse
## or a tyre swing to find.
func _trees() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var trees: Array = []
	for p in [Vector2(-20, 14), Vector2(20, 14), Vector2(19, -2), Vector2(-3, -14), Vector2(-20, 1)]:
		trees.append([Vector3(p.x, 0, p.y), "maple" if rng.randf() < 0.7 else "birch", rng.randi(), "random", true, rng.randf_range(1.0, 1.15)])
	for i in range(40):
		var a: float = rng.randf() * TAU
		var p := Vector2(cos(a) * rng.randf_range(28, 70), sin(a) * rng.randf_range(24, 70))
		if p.y < -18 and p.y > -44:
			continue # street and houses
		trees.append([Vector3(p.x, 0, p.y), "", rng.randi(), "random", false, rng.randf_range(1.1, 1.4)])
	TreeCreator.plant(self, geo, trees)
