extends BuiltMap

## Mountain Lake - an alpine lake in a ring of peaks (High
## performance). The lake is ~280 m across; the mountains climb to
## ~200 m with rock faces and snow on top, pine forest up to the
## treeline (~110 m). A wooden cabin with a pier (spawn), a boathouse,
## a chapel on a knoll, a concrete dam at the outlet in the south, a
## waterfall off the eastern cliffs, a cable car line up the west slope.
## FPV lines: mountain surfing down the ridges, skimming the lake,
## diving the dam face, the cable line, the waterfall.

const LAKE_R: float = 140.0
const WATER_Y: float = 0.0

var rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()
var _ridge := FastNoiseLite.new()

func map_env() -> Dictionary:
	# Evening alpenglow: the sun low over the ridge, warm light on the
	# peaks, the valley already in long shadow.
	return {"sun_rot": Vector3(-13, 128, 0), "sun_color": Color(1.0, 0.74, 0.52), "sun_energy": 1.55, "fog_begin": 450.0,
		"sky_top": Color(0.22, 0.36, 0.64), "sky_horizon": Color(0.95, 0.76, 0.64),
		"ambient": Color(0.66, 0.66, 0.74), "ambient_energy": 0.76}

func border() -> Array:
	return [950.0, 1050.0, 480.0, 560.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(0, 90, 260), Vector3(0, 20, -80)],
		["cabin", Vector3(-25, 6, -110), Vector3(0, 3, -140)],
		["dam", Vector3(40, 12, 190), Vector3(0, 0, 150)],
		["ridge", Vector3(-300, 170, -80), Vector3(-100, 40, 0)],
		["village", Vector3(-120, 25, 60), Vector3(-250, 4, 60)],
		["road_valley", Vector3(20, 25, 330), Vector3(-80, 5, 180)],
		["road_north", Vector3(-230, 20, -20), Vector3(-120, 5, -150)],
	]

## The lakeside village on the west shore, on levelled ground.
const VILLAGE := Rect2(-330, -20, 150, 150)

## The valley road: up the outlet valley from the south (out of the
## map), past the dam, along the shore into the village, then north
## past the chapel and the cable car station to the cabin's car park.
## Corner points; the road's own grade comes from the land, smoothed.
const ROAD_S: Array = [Vector2(0, 2600), Vector2(0, 420), Vector2(-8, 260), Vector2(-60, 200), Vector2(-140, 168), Vector2(-178, 118), Vector2(-183.5, 94)]
const ROAD_N: Array = [Vector2(-183.5, -8), Vector2(-200, -40), Vector2(-202, -90), Vector2(-150, -135), Vector2(-100, -152), Vector2(-40, -182), Vector2(-12, -184)]
var _roads: Array = []

func _road_paths() -> Array:
	if _roads.is_empty():
		for corners in [ROAD_S, ROAD_N]:
			var c3: Array = []
			for q: Vector2 in corners:
				c3.append(Vector3(q.x, 0, q.y))
			var pts: Array[Vector3] = Route.rounded(c3, 30.0, 8)
			var dense := Route.new()
			dense.pts.append(pts[0])
			for i in range(1, pts.size()):
				dense.to(pts[i], 8.0)
			var ys: Array[float] = []
			for p in dense.pts:
				ys.append(maxf(_base_height(p.x, p.z), WATER_Y + 1.6))
			for i in range(dense.pts.size()):
				var acc: float = 0.0
				var n: int = 0
				for k in range(maxi(i - 6, 0), mini(i + 7, ys.size())):
					acc += ys[k]
					n += 1
				dense.pts[i].y = acc / n
			var bx := Rect2(Vector2(dense.pts[0].x, dense.pts[0].z), Vector2.ZERO)
			for p in dense.pts:
				bx = bx.expand(Vector2(p.x, p.z))
			_roads.append([dense, bx.grow(40.0)])
	return _roads

## Terrain with the road cut in: a flat bed at the road's grade, easing
## back into the hillside over 25 m.
func _height(x: float, z: float) -> float:
	var h: float = _base_height(x, z)
	for r in _road_paths():
		if not r[1].has_point(Vector2(x, z)):
			continue
		var pts: Array[Vector3] = r[0].pts
		var best: float = INF
		var fy: float = 0.0
		for i in range(pts.size() - 1):
			var a: Vector3 = pts[i]
			var b: Vector3 = pts[i + 1]
			var ab := Vector2(b.x - a.x, b.z - a.z)
			var t: float = clampf(Vector2(x - a.x, z - a.z).dot(ab) / maxf(ab.length_squared(), 0.001), 0.0, 1.0)
			var d: float = Vector2(x - a.x - ab.x * t, z - a.z - ab.y * t).length()
			if d < best:
				best = d
				fy = lerpf(a.y, b.y, t)
		h = lerpf(fy - 0.05, h, smoothstep(6.0, 31.0, best))
	return h

func _base_height(x: float, z: float) -> float:
	var raw: float = _raw_height(x, z)
	var ddx: float = maxf(maxf(VILLAGE.position.x - x, x - VILLAGE.end.x), 0.0)
	var ddz: float = maxf(maxf(VILLAGE.position.y - z, z - VILLAGE.end.y), 0.0)
	return lerpf(4.0, raw, smoothstep(0.0, 40.0, sqrt(ddx * ddx + ddz * ddz)))

func _raw_height(x: float, z: float) -> float:
	var r: float = Vector2(x, z).length()
	var n: float = _noise.get_noise_2d(x, z)
	if r < LAKE_R:
		return -8.0 * (1.0 - pow(r / LAKE_R, 2.0)) - 0.5 + n
	var d: float = r - LAKE_R
	var ridge: float = 1.0 - absf(_ridge.get_noise_2d(x, z))
	var mountain: float = smoothstep(30.0, 380.0, d) * (90.0 + ridge * ridge * 130.0)
	var h: float = minf(d * 0.12 + mountain + n * 6.0, 420.0 + ridge * 120.0)
	# The outlet valley to the south, dammed.
	var valley: float = smoothstep(0.0, 1.0, 1.0 - absf(x) / 40.0) if z > 0.0 else 0.0
	return lerpf(h, minf(h, 2.0 + d * 0.05), valley * smoothstep(0.0, 60.0, d))

func _tint(n: Vector3, p: Vector3) -> Color:
	var steep: float = 1.0 - n.y
	var c: Color
	if p.y < 1.2:
		c = Color(0.85, 0.78, 0.62) # shore gravel / sand
	elif p.y > 150.0 + _noise.get_noise_2d(p.x * 3.0, p.z * 3.0) * 20.0 and steep < 0.45:
		c = Color(1.6, 1.62, 1.7)   # snow
	elif steep > 0.32:
		c = Color(0.82, 0.8, 0.78)  # rock
	else:
		c = Color(0.5, 0.64, 0.36).lerp(Color(0.62, 0.6, 0.45), clampf(p.y / 140.0, 0.0, 1.0))
	return geo.shade(n, p.y + 50.0) * c

func build() -> void:
	rng.seed = 8848
	_noise.seed = 3
	_noise.frequency = 0.012
	_ridge.seed = 9
	_ridge.frequency = 0.004
	_ridge.fractal_octaves = 5
	geo.ao_height = 2.5
	geo.add_material("terrain", Geo.tex_mat(MapTextures.get_tex("rock"), Color.WHITE, 18.0))
	geo.add_material("water", Geo.water_mat(Color(0.08, 0.32, 0.4), 0.9))
	geo.add_material("wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.75, 0.6, 0.45), 1.6))
	geo.add_material("roof", Geo.flat_mat(Color(0.32, 0.22, 0.18)))
	geo.add_material("stone", Geo.tex_mat(MapTextures.get_tex("rock"), Color(0.9, 0.88, 0.84), 3.0))
	geo.add_material("concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color.WHITE, 6.0))
	geo.add_material("white", Geo.flat_mat(Color(0.93, 0.92, 0.9)))
	geo.add_material("steel", Geo.flat_mat(Color(0.5, 0.52, 0.55)))
	geo.add_material("cable", Geo.flat_mat(Color(0.15, 0.15, 0.15)))
	geo.add_material("red", Geo.flat_mat(Color(0.75, 0.15, 0.12)))
	geo.add_material("falls", Geo.glow_mat(Color(0.85, 0.93, 1.0), 0.9))
	Terrain.build(self, Rect2(-1100, -1100, 2200, 2200), 8.0, _height, geo._mats["terrain"], _tint)
	Terrain.far_ring(self, Rect2(-1100, -1100, 2200, 2200), Rect2(-6000, -6000, 12000, 12000), 80.0, _height, geo._mats["terrain"], _tint)
	MapProps.town(geo, VILLAGE, _height, rng)
	_valley_road()
	geo.slab(Rect2(-LAKE_R - 20, -LAKE_R - 20, 2 * LAKE_R + 40, 2 * LAKE_R + 80), WATER_Y, 0.2, "water")
	_cabin(Vector3(0, 0, -150))
	_chapel(Vector3(-170, 0, -60))
	_dam(Vector3(0, 0, 165))
	_waterfall(Vector3(185, 0, -30))
	_cable_car(Vector3(-100, 0, -130), Vector3(-400, 0, -310))
	_lake_life()
	_forest()

func _valley_road() -> void:
	var roads := Roads.new(geo, rng, fleet)
	for r in _road_paths():
		var route: Route = r[0]
		roads.road(route, 6.5, {"verge": 1.5, "lamps": 0.0, "detail": 900.0, "edge_lines": true})
		roads.traffic(Route.from_pts(route.slice(0.0, minf(route.length(), 900.0))), 6.5, 1, 10.0, 0.1)
	# Car park at the cabin end, a bus at the cable car station.
	var cp := Vector3(-12, 0, -184)
	cp.y = _height(cp.x, cp.z)
	geo.slab(Rect2(cp.x - 4, cp.z - 9, 22, 12), cp.y + 0.04, 0.3, "prop_road", false)
	for k in range(4):
		fleet.car(Vector3(cp.x + k * 3.0, cp.y + 0.05, cp.z - 6), 0.0, Fleet.random_paint(rng), ["suv", "estate", "hatch"][k % 3])
	var bs := Vector3(-100, 0, -148)
	Vehicles.bus(geo, Vector3(bs.x, _height(bs.x, bs.z) + 0.05, bs.z), PI * 0.4, "veh_paint7")

func _ground(x: float, z: float) -> float:
	return maxf(_height(x, z), WATER_Y)

## Log cabin on the north shore, its pier out over the lake.
func _cabin(o: Vector3) -> void:
	var y: float = _ground(o.x, o.z - 10.0) + 0.3
	var c := Vector3(o.x, y, o.z - 12.0)
	geo.box(c + Vector3(0, -2.0, 0), Vector3(10, 4.2, 8), "stone")
	geo.box(c + Vector3(0, 1.6, 0), Vector3(9, 3.2, 7), "wood")
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.RIGHT, s * 0.7), c + Vector3(0, 4.3, s * 2.1)), Vector3(10, 0.25, 5.4), "roof")
	geo.box(c + Vector3(3, 5, 0), Vector3(1, 3, 1), "stone")
	# Pier: planks on posts, 30 m out, a boathouse at the end.
	for i in range(15):
		var p := Vector3(o.x, 1.1, o.z + 2 + i * 2.0)
		geo.box(p, Vector3(2.6, 0.12, 1.9), "wood")
		geo.box(p + Vector3(1.2, -1.5, 0), Vector3(0.2, 3, 0.2), "wood")
		geo.box(p + Vector3(-1.2, -1.5, 0), Vector3(0.2, 3, 0.2), "wood")
	var bh := Vector3(o.x + 6, 1.1, o.z + 26)
	geo.box(bh + Vector3(0, 1.8, 3), Vector3(6, 3.6, 0.2), "wood")
	for sx in [-3.0, 3.0]:
		geo.box(bh + Vector3(sx, 1.8, 0), Vector3(0.2, 3.6, 6), "wood")
	geo.box(bh + Vector3(0, 3.7, 0), Vector3(7, 0.2, 7), "roof")
	geo.box(bh + Vector3(0, -0.6, 0), Vector3(1.6, 0.6, 4.5), "red") # rowing boat

func _chapel(o: Vector3) -> void:
	var y: float = _ground(o.x, o.z)
	var c := Vector3(o.x, y, o.z)
	geo.box(c + Vector3(0, 2.5, 0), Vector3(6, 6, 10), "white")
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.FORWARD, s * 0.75), c + Vector3(s * 1.7, 7.0, 0)), Vector3(4.6, 0.25, 10.6), "roof")
	geo.box(c + Vector3(0, 6, 5.5), Vector3(3, 12, 3), "white")
	geo.cone(c + Vector3(0, 12, 5.5), c + Vector3(0, 17, 5.5), 2.2, 0.05, "roof", 4)

## Arch-gravity dam across the outlet valley, crest walkable.
func _dam(o: Vector3) -> void:
	var crest: float = 6.0
	for i in range(13):
		var a0: float = deg_to_rad(-40 + i * 6.7)
		var p := o + Vector3(sin(a0) * 60.0, 0, -cos(a0) * 60.0 + 60.0)
		var bottom: float = _height(p.x, p.z + 6.0) - 3.0
		var hgt: float = crest - bottom
		geo.box(Vector3(p.x, bottom + hgt * 0.5, p.z), Vector3(7.2, hgt, 5.0), "concrete", -a0)
		geo.box(Vector3(p.x, crest + 0.6, p.z - 2.2), Vector3(7.2, 1.2, 0.3), "concrete", -a0)
	geo.box(o + Vector3(0, crest - 1.5, 6), Vector3(10, 3, 1), "falls", 0.0, false, false) # spillway sheet

## Waterfall: a bright sheet down the eastern cliff into the lake.
func _waterfall(o: Vector3) -> void:
	var top: float = _height(o.x + 15.0, o.z)
	geo.box(Vector3(o.x, top * 0.5, o.z), Vector3(1.2, top, 7), "falls", 0.0, false, false)
	geo.box(Vector3(o.x - 4, 0.3, o.z), Vector3(8, 0.4, 12), "falls", 0.0, false, false) # foam

## Cable car: towers every ~90 m up the slope, two cables, a cabin.
func _cable_car(a: Vector3, b: Vector3) -> void:
	var n: int = 4
	var tops: Array[Vector3] = []
	for i in range(n + 1):
		var p: Vector3 = a.lerp(b, float(i) / n)
		var g: float = _ground(p.x, p.z)
		var t := Vector3(p.x, g + 18.0, p.z)
		geo.beam(Vector3(p.x - 1.5, g, p.z), t, Vector2(0.6, 0.6), "steel")
		geo.beam(Vector3(p.x + 1.5, g, p.z), t, Vector2(0.6, 0.6), "steel")
		geo.box(t, Vector3(0.6, 0.6, 6), "steel")
		tops.append(t)
	for i in range(n):
		for dz in [-2.8, 2.8]:
			geo.beam(tops[i] + Vector3(0, 0, dz), tops[i + 1] + Vector3(0, 0, dz), Vector2(0.08, 0.08), "cable", false)
	var mid: Vector3 = tops[1].lerp(tops[2], 0.4) + Vector3(0, -3.5, 2.8)
	geo.box(mid, Vector3(2.4, 2.6, 2.2), "red")
	geo.box(mid + Vector3(0, 2.2, 0), Vector3(0.2, 2.0, 0.2), "steel")

## People at the lake: boats (moored at the pier and out on the water),
## a campground on the east shore with tents and caravans, a lakeside
## hotel by the village, the cable car's two stations.
func _lake_life() -> void:
	Vehicles.ensure_materials(geo)
	for i in range(4):
		Vehicles.boat(geo, Vector3(-4 + (i % 2) * 8, -0.2, -120 + i * 6), PI * 0.5, i == 3)
	for i in range(6):
		var a: float = rng.randf() * TAU
		var r: float = rng.randf_range(30, 110)
		Vehicles.boat(geo, Vector3(cos(a) * r, -0.2, sin(a) * r), rng.randf() * TAU, rng.randf() < 0.6)
	var camp := Vector3(150, 0, 60)
	for i in range(14):
		var q := camp + Vector3(rng.randf_range(-25, 25), 0, rng.randf_range(-25, 25))
		q.y = _ground(q.x, q.z)
		if i % 3 == 0:
			geo.box(q + Vector3(0, 1.4, 0), Vector3(2.3, 2.4, 6.5), "white", rng.randf() * TAU)
		else:
			geo.cone(q, q + Vector3(0, 1.6, 0), 1.8, 0.05, ["red", "steel", "wood"][rng.randi() % 3], 4)
	var hotel := Vector3(-200, 0, 150)
	hotel.y = _ground(hotel.x, hotel.z)
	geo.box(hotel + Vector3(0, 7, 0), Vector3(40, 14, 16), "white")
	geo.box(hotel + Vector3(0, 8, 8.1), Vector3(38, 10, 0.1), "wood", 0.0, false, false)
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.RIGHT, s * 0.5), hotel + Vector3(0, 16, s * 4.5)), Vector3(42, 0.3, 10), "roof")
	for i in range(8):
		fleet.car(Vector3(hotel.x - 18 + i * 5, hotel.y + 0.1, hotel.z + 16), 0.0, Fleet.random_paint(rng), "suv" if i % 3 == 0 else "hatch")
	# Cable car stations at both ends of the line.
	for end in [Vector3(-100, 0, -130), Vector3(-400, 0, -310)]:
		var g: float = _ground(end.x, end.z)
		geo.box(Vector3(end.x, g + 4, end.z), Vector3(10, 8, 14), "concrete")
		geo.box(Vector3(end.x, g + 8.4, end.z), Vector3(11, 0.8, 15), "red")

func _forest() -> void:
	var trees: Array = []
	var attempts: int = 0
	while trees.size() < 6500 and attempts < 40000:
		attempts += 1
		var x: float = rng.randf_range(-1090, 1090)
		var z: float = rng.randf_range(-1090, 1090)
		if VILLAGE.grow(10.0).has_point(Vector2(x, z)):
			continue
		if absf(_height(x, z) - _base_height(x, z)) > 0.8:
			continue # the road's cutting
		var y: float = _height(x, z)
		if y < 1.5 or y > 110.0 + rng.randf() * 20.0:
			continue # water / above the treeline
		var dx: float = 3.0
		var slope: float = absf(_height(x + dx, z) - y) + absf(_height(x, z + dx) - y)
		if slope > 5.0:
			continue # too steep: rock face
		if Vector2(x, z + 162).length() < 25.0 or Vector2(x + 170, z + 60).length() < 20.0:
			continue # cabin, chapel
		trees.append([Vector3(x, y - 0.3, z), 0 if rng.randf() < 0.85 else 1, rng.randf_range(0.8, 1.5)])
	Forest.plant(self, trees)
