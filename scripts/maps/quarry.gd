extends BuiltMap

## Quarry - an open-pit hard-rock quarry in wooded hills (High
## performance). The pit is ~260 m across and 60 m deep, cut in six
## 10 m benches (the terraces real quarries leave for stability and
## haul roads), with a flooded sump at the bottom. On the rim: the
## primary crusher, conveyor galleries down to screening/stockpiles,
## an office. In the pit: haul trucks, an excavator, a drill rig.
## FPV lines: dives down the bench faces, the conveyor gallery, the
## crusher tower, low passes over the water.

const PIT_R: float = 130.0
const DEPTH: float = 60.0
const BENCHES: int = 6
const WATER_Y: float = -57.0

var rng := RandomNumberGenerator.new()
var _noise := FastNoiseLite.new()

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-40, -130, 0), "sun_color": Color(1.0, 0.93, 0.8), "fog_density": 0.00028, "aerial": 0.08,
		"sky_top": Color(0.3, 0.5, 0.8)}

func border() -> Array:
	return [850.0, 950.0, 220.0, 280.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(170, 60, 170), Vector3(0, -40, 0)],
		["benches", Vector3(-60, -25, 40), Vector3(60, -45, -40)],
		["crusher", Vector3(150, 20, -40), Vector3(175, 10, -5)],
		["water", Vector3(-30, -54, 0), Vector3(40, -55, 0)],
	]

## The main pit, plus an older, smaller worked-out pit to the
## north-east (3 benches, flooded), and the village's levelled ground.
const PIT2 := Vector3(520, 0, -380)
const VILLAGE := Rect2(-620, 260, 250, 200)

func _height(x: float, z: float) -> float:
	var n: float = _noise.get_noise_2d(x, z)
	var r: float = Vector2(x, z * 1.15).length()
	if r < PIT_R:
		return _pit(r, PIT_R, 45.0, DEPTH, BENCHES) + n * 0.8
	var r2: float = Vector2(x - PIT2.x, z - PIT2.z).length()
	if r2 < 80.0:
		return _pit(r2, 80.0, 25.0, 30.0, 3) + n * 0.8
	var outside: float = maxf(0.0, (r - PIT_R) * 0.06) * (0.6 + 0.4 * n) + n * 2.0 + maxf(r - 700.0, 0.0) * 0.08 * (0.5 + n)
	var ddx: float = maxf(maxf(VILLAGE.position.x - x, x - VILLAGE.end.x), 0.0)
	var ddz: float = maxf(maxf(VILLAGE.position.y - z, z - VILLAGE.end.y), 0.0)
	var dv: float = sqrt(ddx * ddx + ddz * ddz)
	return lerpf(3.0, outside, smoothstep(0.0, 50.0, dv))

## Stepped pit profile: `benches` faces of equal height with flat berms.
static func _pit(r: float, radius: float, floor_r: float, depth: float, benches: int) -> float:
	var t: float = clampf((radius - r) / (radius - floor_r), 0.0, 1.0) * benches
	var k: float = floorf(t)
	var frac: float = t - k
	var step: float = k + smoothstep(0.0, 0.28, frac) if k < benches else float(benches)
	return -depth * step / benches

func _tint(n: Vector3, p: Vector3) -> Color:
	var steep: float = 1.0 - n.y
	var rock := Color(0.9, 0.86, 0.8)
	var grass := Color(0.55, 0.7, 0.4)
	var c: Color = rock if p.y < -1.0 or steep > 0.25 else grass.lerp(rock, clampf(steep * 3.0, 0.0, 1.0))
	return geo.shade(n, p.y + 50.0) * c

func build() -> void:
	rng.seed = 77
	_noise.seed = 5
	_noise.frequency = 0.01
	geo.ao_height = 4.0
	geo.add_material("terrain", Geo.tex_mat(MapTextures.get_tex("rock"), Color.WHITE, 14.0))
	geo.add_material("water", Geo.water_mat())
	geo.add_material("yellow", Geo.flat_mat(Color(0.9, 0.68, 0.1)))
	geo.add_material("steel", Geo.tex_mat(MapTextures.get_tex("paint_rust"), Color.WHITE, 4.0))
	geo.add_material("rust", Geo.tex_mat(MapTextures.get_tex("rust"), Color.WHITE, 5.0))
	geo.add_material("concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color.WHITE, 5.0))
	geo.add_material("gravel", Geo.tex_mat(ProceduralTextures.gravel_texture(), Color(0.8, 0.78, 0.74), 3.0))
	geo.add_material("dark", Geo.flat_mat(Color(0.12, 0.12, 0.13)))
	Terrain.build(self, Rect2(-950, -950, 1900, 1900), 7.0, _height, geo._mats["terrain"], _tint)
	Terrain.far_ring(self, Rect2(-950, -950, 1900, 1900), Rect2(-4000, -4000, 8000, 8000), 64.0, _height, geo._mats["terrain"], _tint)
	geo.slab(Rect2(-60, -52, 120, 104), WATER_Y, 0.2, "water")
	geo.slab(Rect2(PIT2.x - 30, PIT2.z - 30, 60, 60), -27.0, 0.2, "water")
	MapProps.town(geo, VILLAGE, _height, rng)
	geo.beam(Vector3(-370, 3.1, 330), Vector3(160, 0.4, 60), Vector2(8, 0.3), "prop_road", true, false)
	_crusher(Vector3(175, 0, -10))
	for i in range(3):
		_pile(Vector3(220 + i * 28, 0, 40), 12, 9, "gravel")
	_office(Vector3(190, 0, 60))
	for p in [Vector3(-80, -40, 20), Vector3(40, -30, 75), Vector3(10, -60, -30)]:
		_truck(Vector3(p.x, _height(p.x, p.z), p.z), rng.randf() * TAU)
	_excavator(Vector3(-35, _height(-35, -30), -30))
	_drill(Vector3(95, _height(95, -20), -20))
	_forest()

func _pile(c: Vector3, r: float, h: float, mat: String) -> void:
	geo.lathe(c, [Vector2(r, 0), Vector2(r * 0.6, h * 0.6), Vector2(0.1, h)], mat, 16)

## Primary crusher on the rim: a tower with a feed hopper, and an
## enclosed conveyor gallery out to the stockpiles.
func _crusher(o: Vector3) -> void:
	geo.box(o + Vector3(0, 9, 0), Vector3(14, 18, 12), "concrete")
	geo.cone(o + Vector3(-9, 16, 0), o + Vector3(-9, 11, 0), 5, 1.5, "rust", 8)
	for dx in [-1.0, 1.0]:
		for dz in [-1.0, 1.0]:
			geo.beam(o + Vector3(-9 + dx * 3.5, 0, dz * 3.5), o + Vector3(-9 + dx * 3.5, 11, dz * 3.5), Vector2(0.5, 0.5), "steel")
	var a := o + Vector3(7, 14, 0)
	var b := Vector3(248, 12, 40)
	var basis := Basis.looking_at((b - a).normalized(), Vector3.UP)
	var n: int = int(a.distance_to(b) / 6.0)
	for i in range(n):
		var p0: Vector3 = a.lerp(b, float(i) / n)
		var mid: Vector3 = a.lerp(b, (i + 0.5) / n)
		var seg: float = a.distance_to(b) / n
		geo.box_xf(Transform3D(basis, mid + basis * Vector3(0, -1.5, 0)), Vector3(3, 0.2, seg), "steel")
		geo.box_xf(Transform3D(basis, mid + basis * Vector3(0, 1.5, 0)), Vector3(3, 0.15, seg), "rust")
		for sx in [-1.5, 1.5]:
			if rng.randf() > 0.3:
				geo.box_xf(Transform3D(basis, mid + basis * Vector3(sx, 0, 0)), Vector3(0.1, 3, seg), "rust")
		if i % 2 == 0:
			geo.beam(Vector3(p0.x, 0, p0.z), p0 - Vector3(0, 1.6, 0), Vector2(0.4, 0.4), "steel")

func _office(o: Vector3) -> void:
	geo.slab(Rect2(o.x - 20, o.z - 14, 40, 28), 0.3, 0.6, "gravel")
	geo.box(o + Vector3(0, 2.0, 0), Vector3(14, 3.6, 7), "concrete")
	geo.box(o + Vector3(0, 2.2, 3.52), Vector3(10, 1.2, 0.05), "dark", 0.0, false, false)

func _truck(p: Vector3, yaw: float) -> void:
	# A 100 t rigid haul truck: the wheels alone are taller than a person.
	var b := Basis(Vector3.UP, yaw)
	geo.box_xf(Transform3D(b, p + Vector3(0, 2.6, 0)), Vector3(6, 1.2, 10), "yellow")
	geo.box_xf(Transform3D(b, p + b * Vector3(0, 4.2, -1.5)), Vector3(6.2, 2.0, 7), "yellow")
	geo.box_xf(Transform3D(b, p + b * Vector3(-1.8, 4.4, 4.2)), Vector3(2.2, 1.8, 2), "dark")
	for dx in [-2.7, 2.7]:
		for dz in [-3.2, 3.5]:
			var w: Vector3 = p + b * Vector3(dx, 1.6, dz)
			geo.cylinder(w - b.x * 0.6, w + b.x * 0.6, 1.6, "dark", 12)

func _excavator(p: Vector3) -> void:
	geo.box(p + Vector3(0, 1.0, 0), Vector3(5, 2, 7), "dark")
	geo.box(p + Vector3(0, 3.2, 0), Vector3(5, 2.6, 6), "yellow", 0.6)
	var boom0 := p + Vector3(1.5, 4, -2)
	var boom1 := p + Vector3(6, 9, -8)
	geo.beam(boom0, boom1, Vector2(0.9, 1.2), "yellow")
	geo.beam(boom1, p + Vector3(9, 2, -10), Vector2(0.7, 0.9), "yellow")
	geo.box(p + Vector3(9, 1.2, -10), Vector3(2.5, 1.8, 2), "rust")

func _drill(p: Vector3) -> void:
	geo.box(p + Vector3(0, 1.2, 0), Vector3(3, 2.4, 6), "yellow")
	geo.box(p + Vector3(0, 8, -2.5), Vector3(0.6, 14, 0.6), "steel")

func _forest() -> void:
	var trees: Array = []
	var attempts: int = 0
	while trees.size() < 6000 and attempts < 30000:
		attempts += 1
		var x: float = rng.randf_range(-940, 940)
		var z: float = rng.randf_range(-940, 940)
		if Vector2(x, z * 1.15).length() < PIT_R + 12.0 or Vector2(x - PIT2.x, z - PIT2.z).length() < 90.0 or VILLAGE.grow(12.0).has_point(Vector2(x, z)):
			continue
		if Rect2(140, -40, 150, 120).has_point(Vector2(x, z)):
			continue # crusher, stockpiles, office
		trees.append([Vector3(x, _height(x, z) - 0.2, z), 0 if rng.randf() < 0.55 else 1, rng.randf_range(0.8, 1.5)])
	Forest.plant(self, trees)
