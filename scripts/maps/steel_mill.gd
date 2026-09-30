extends BuiltMap

## Abandoned Steel Mill - the High-performance showcase map: a whole
## integrated steelworks, derelict and overgrown, in a forested valley.
##
## Laid out along the real process (sources in TODO.md):
##   coal + ore arrive by rail (west) -> stockyard with an ore bridge
##   coal -> coke oven battery (north-west) -> quench tower
##   coke + ore -> conveyor galleries -> skip bridges -> 2 blast furnaces
##   hot stoves (hot blast) -> bustle pipe; top gas -> downcomer ->
##   dust catcher -> gas main on trestles -> gas holder (north-east)
##   hot metal -> torpedo cars through the cast houses -> BOF shop (east)
##   -> rolling mill hall (far east) -> finished slabs on flat wagons
##   power plant (south): turbine hall, chimneys, cooling tower.
## North = -z. The site is x -360..360, z -210..190; forest all round.
##
## FPV lines by design: the gas main and the conveyor galleries are
## hollow (fly through them), the cooling tower is open (dive it), the
## quench tower is open-topped with big openings, halls have missing
## wall/roof panels, the skip bridges run up to the furnace tops.

const SITE := Rect2(-360, -210, 720, 400)
const BF := [Vector3(-60, 0, -35), Vector3(60, 0, -35)]
const TRACK_Z := 70.0
const TORPEDO_Z := 0.0

var rng := RandomNumberGenerator.new()

func map_env() -> Dictionary:
	# Hazy morning: low warm sun, height fog in the valley.
	return {"sun_rot": Vector3(-28, -60, 0), "sun_color": Color(1.0, 0.86, 0.68), "sun_energy": 1.25,
		"sky_top": Color(0.36, 0.5, 0.68), "sky_horizon": Color(0.8, 0.78, 0.72),
		"ground_horizon": Color(0.45, 0.47, 0.38), "ground_bottom": Color(0.2, 0.24, 0.16),
		"ambient": Color(0.62, 0.64, 0.66), "ambient_energy": 0.8,
		"fog_color": Color(0.74, 0.74, 0.7), "fog_density": 0.00028, "aerial": 0.08,
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-400, -400, 800, 800)}

func border() -> Array:
	return [950.0, 1050.0, 260.0, 330.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(160, 90, 260), Vector3(-20, 10, -20)],
		["furnaces", Vector3(0, 30, 45), Vector3(0, 25, -40)],
		["gas_main", Vector3(-70, 14.5, -110), Vector3(40, 14.5, -110)],
		["cooling_tower", Vector3(-120, 110, 150.1), Vector3(-120, 0, 150)],
		["rolling_mill", Vector3(256, 9, -15), Vector3(350, 6, -15)],
		["stockyard", Vector3(-200, 25, 130), Vector3(-280, 5, 80)],
		["coke", Vector3(-150, 20, -95), Vector3(-260, 8, -140)],
	]

func build() -> void:
	rng.seed = 1979
	geo.ao_height = 6.0
	geo.ao_min = 0.45
	_materials()
	_ground()
	_rail()
	_stockyard()
	_coke_plant()
	for i in range(2):
		_blast_furnace(BF[i], i, 1.0 if i == 0 else -1.0)
	_gas_main()
	_bof_shop()
	_rolling_mill()
	_power_plant()
	_extras()
	_town_and_heap()
	_forest()

# --- materials ----------------------------------------------------------------

func _materials() -> void:
	var rust := MapTextures.get_tex("rust")
	geo.add_material("rust", Geo.tex_mat(rust, Color.WHITE, 6.0, 0.8, 0.2))
	geo.add_material("rust_dark", Geo.tex_mat(rust, Color(0.7, 0.66, 0.62), 6.0, 0.85, 0.2))
	geo.add_material("paint", Geo.tex_mat(MapTextures.get_tex("paint_rust"), Color.WHITE, 5.0, 0.7, 0.1))
	geo.add_material("corrugated", Geo.tex_mat(MapTextures.get_tex("corrugated_rust"), Color(0.95, 0.92, 0.9), 4.0, 0.8, 0.2))
	geo.add_material("concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color.WHITE, 8.0))
	geo.add_material("brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color.WHITE, 3.0))
	geo.add_material("glass", Geo.flat_mat(Color(0.12, 0.14, 0.15), 0.15, 0.4))
	geo.add_material("asphalt", Geo.tex_mat(MapTextures.get_tex("cracked_asphalt"), Color.WHITE, 8.0))
	geo.add_material("slag", Geo.tex_mat(MapTextures.get_tex("slag"), Color.WHITE, 10.0))
	geo.add_material("weeds", Geo.tex_mat(MapTextures.get_tex("meadow"), Color(0.9, 0.9, 0.8), 10.0))
	geo.add_material("ore", Geo.tex_mat(MapTextures.get_tex("slag"), Color(1.6, 0.75, 0.5), 6.0))
	geo.add_material("coal", Geo.tex_mat(MapTextures.get_tex("slag"), Color(0.45, 0.45, 0.47), 6.0))
	geo.add_material("lime", Geo.tex_mat(MapTextures.get_tex("slag"), Color(2.4, 2.35, 2.2), 6.0))
	geo.add_material("sleeper", Geo.flat_mat(Color(0.25, 0.2, 0.16), 0.95))
	geo.add_material("rail", Geo.flat_mat(Color(0.45, 0.35, 0.3), 0.5, 0.6))
	geo.add_material("ballast", Geo.tex_mat(ProceduralTextures.gravel_texture(), Color(0.55, 0.52, 0.5), 2.0))
	geo.add_material("yellow", Geo.flat_mat(Color(0.75, 0.55, 0.12), 0.6, 0.2))
	var terrain_mat := Geo.tex_mat(MapTextures.get_tex("forest_floor"), Color.WHITE, 12.0)
	geo.add_material("terrain", terrain_mat)

# --- ground -------------------------------------------------------------------

## Flat inside the site, rising into wooded hills around it.
## The workers' town east of the works and the slag heap south-east sit
## on ground levelled for them.
const TOWN := Rect2(470, -170, 280, 240)
const TOWN_Y: float = 7.0

func _height(x: float, z: float) -> float:
	var raw: float = _raw_height(x, z)
	var dt: float = _rect_dist(TOWN, x, z)
	return lerpf(TOWN_Y, raw, smoothstep(0.0, 60.0, dt))

static func _rect_dist(r: Rect2, x: float, z: float) -> float:
	var ddx: float = maxf(maxf(r.position.x - x, x - r.end.x), 0.0)
	var ddz: float = maxf(maxf(r.position.y - z, z - r.end.y), 0.0)
	return sqrt(ddx * ddx + ddz * ddz)

func _raw_height(x: float, z: float) -> float:
	var dx: float = maxf(maxf(SITE.position.x - x, x - SITE.end.x), 0.0)
	var dz: float = maxf(maxf(SITE.position.y - z, z - SITE.end.y), 0.0)
	var d: float = sqrt(dx * dx + dz * dz)
	if d <= 0.0:
		return -0.4
	var ramp: float = smoothstep(0.0, 90.0, d)
	var n: float = _noise.get_noise_2d(x, z) * 0.5 + 0.5
	return -0.4 + ramp * (8.0 + n * 38.0) + maxf(d - 250.0, 0.0) * 0.12

var _noise := FastNoiseLite.new()

func _ground() -> void:
	_noise.seed = 31
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	var tshade := func(n: Vector3, p: Vector3) -> Color: return geo.shade(n, p.y + 50.0)
	Terrain.build(self, Rect2(-1100, -1000, 2200, 2000), 8.0, _height, geo._mats["terrain"], tshade)
	Terrain.far_ring(self, Rect2(-1100, -1000, 2200, 2000), Rect2(-4000, -4000, 8000, 8000), 64.0, _height, geo._mats["terrain"], tshade)
	# Site surface: slag/gravel fill, with concrete pads, roads, weeds.
	geo.slab(SITE, 0.0, 0.5, "slag")
	for r in [Rect2(-150, 100, 510, 10), Rect2(215, 110, 10, 80), Rect2(-200, -60, 10, 160)]:
		geo.slab(r, 0.06, 0.1, "asphalt")
	for i in range(40):
		var c := Vector2(rng.randf_range(SITE.position.x, SITE.end.x), rng.randf_range(SITE.position.y, SITE.end.y))
		geo.slab(Rect2(c, Vector2(rng.randf_range(8, 30), rng.randf_range(8, 30))), 0.12, 0.1, "weeds", false)

# --- rail -----------------------------------------------------------------------

## Standard gauge (1.435 m) track on a ballast bed.
func _track(a: Vector3, b: Vector3) -> void:
	var d: Vector3 = (b - a)
	var along: Vector3 = d.normalized()
	var side: Vector3 = along.cross(Vector3.UP).normalized()
	geo.beam(a + Vector3(0, 0.15, 0), b + Vector3(0, 0.15, 0), Vector2(3.2, 0.3), "ballast", true, false)
	for s in [-0.72, 0.72]:
		geo.beam(a + side * s + Vector3(0, 0.45, 0), b + side * s + Vector3(0, 0.45, 0), Vector2(0.08, 0.15), "rail", false, false)
	var n: int = int(d.length() / 0.9)
	for i in range(n):
		var p: Vector3 = a.lerp(b, (i + 0.5) / n)
		geo.beam(p - side * 1.25 + Vector3(0, 0.33, 0), p + side * 1.25 + Vector3(0, 0.33, 0), Vector2(0.25, 0.1), "sleeper", false, false)

func _rail() -> void:
	_track(Vector3(-760, 0, TRACK_Z), Vector3(330, 0, TRACK_Z))          # main line in from the west
	_track(Vector3(-330, 0, TRACK_Z + 22), Vector3(-150, 0, TRACK_Z + 22)) # stockyard siding
	_track(Vector3(-100, 0, TORPEDO_Z), Vector3(170, 0, TORPEDO_Z))         # torpedo line: cast houses -> BOF
	_track(Vector3(-100, 0, TORPEDO_Z), Vector3(-100, 0, TRACK_Z))
	_track(Vector3(185, 0, 30), Vector3(345, 0, 30))                        # finished goods, by the mill
	geo.box(Vector3(330, 0.9, TRACK_Z), Vector3(3, 1.4, 1.2), "yellow")    # buffer stop
	# Wagons where they were left: hoppers at the stockyard, torpedo cars
	# under the cast houses and at the BOF, flats with slabs by the mill.
	for i in range(7):
		_hopper(Vector3(-310 + i * 14.5, 0, TRACK_Z + 22), i % 3 == 0)
	_locomotive(Vector3(-205, 0, TRACK_Z + 22))
	for x in [BF[0].x, BF[1].x + 2, 130.0]:
		_torpedo(Vector3(x, 0, TORPEDO_Z))
	for i in range(5):
		_flat_wagon(Vector3(200 + i * 15, 0, 30), i != 2)
	for i in range(4):
		_hopper(Vector3(-40 + i * 14.5, 0, TRACK_Z), true)

func _hopper(o: Vector3, coal: bool) -> void:
	_bogies(o, 12.0)
	geo.box(o + Vector3(0, 1.4, 0), Vector3(12.5, 0.4, 2.9), "rust_dark")
	# Sloped hopper body: tapered cones along the wagon look like the
	# discharge chutes; a box on top is the open load space.
	geo.box(o + Vector3(0, 3.0, 0), Vector3(12.0, 2.4, 3.0), "rust")
	for dx in [-3.5, 0.0, 3.5]:
		geo.cone(o + Vector3(dx, 1.8, 0), o + Vector3(dx, 0.9, 0), 1.3, 0.4, "rust_dark", 4)
	geo.box(o + Vector3(0, 4.15, 0), Vector3(11.4, 0.1, 2.5), "coal" if coal else "ore", 0.0, false, false)

func _torpedo(o: Vector3) -> void:
	_bogies(o, 18.0)
	geo.box(o + Vector3(0, 1.4, 0), Vector3(19, 0.5, 2.8), "rust_dark")
	# The torpedo: a fat refractory-lined vessel with tapered ends and a
	# charging mouth on top.
	geo.cylinder(o + Vector3(-5, 3.2, 0), o + Vector3(5, 3.2, 0), 1.9, "rust", 16)
	geo.cone(o + Vector3(-5, 3.2, 0), o + Vector3(-9, 3.2, 0), 1.9, 0.9, "rust", 16)
	geo.cone(o + Vector3(5, 3.2, 0), o + Vector3(9, 3.2, 0), 1.9, 0.9, "rust", 16)
	geo.cylinder(o + Vector3(0, 4.8, 0), o + Vector3(0, 5.6, 0), 0.9, "rust_dark", 10)

func _flat_wagon(o: Vector3, loaded: bool) -> void:
	_bogies(o, 12.0)
	geo.box(o + Vector3(0, 1.45, 0), Vector3(13, 0.4, 2.9), "rust_dark")
	if loaded:
		for i in range(3):
			geo.box(o + Vector3(-4 + i * 4, 1.9 + (i % 2) * 0.25, 0), Vector3(3.6, 0.25 + (i % 2) * 0.25, 2.2), "rust")

func _locomotive(o: Vector3) -> void:
	_bogies(o, 13.0)
	geo.box(o + Vector3(0, 1.45, 0), Vector3(15, 0.5, 3.0), "rust_dark")
	geo.box(o + Vector3(1.5, 3.0, 0), Vector3(11, 2.6, 2.4), "yellow")
	geo.box(o + Vector3(-5.2, 3.4, 0), Vector3(3.2, 3.4, 3.0), "yellow")
	geo.box(o + Vector3(-5.2, 4.2, 0), Vector3(3.3, 1.0, 3.1), "glass", 0.0, false, false)

func _bogies(o: Vector3, spacing: float) -> void:
	for dx in [-spacing * 0.5 + 1.2, spacing * 0.5 - 1.2]:
		geo.box(o + Vector3(dx, 0.85, 0), Vector3(2.6, 0.7, 2.2), "rust_dark")
		for w in [-0.8, 0.8]:
			for s in [-0.72, 0.72]:
				geo.cylinder(o + Vector3(dx + w, 0.95, s - 0.06), o + Vector3(dx + w, 0.95, s + 0.06), 0.46, "rail", 10, false)

# --- stockyard ------------------------------------------------------------------

func _pile(c: Vector3, r: float, h: float, mat: String) -> void:
	var prof: Array[Vector2] = [Vector2(r, 0.0), Vector2(r * 0.7, h * 0.55), Vector2(r * 0.3, h * 0.92), Vector2(0.05, h)]
	geo.lathe(c, prof, mat, 16)

func _stockyard() -> void:
	# Long piles between the ore-bridge rails: ore, coal, limestone.
	for i in range(3):
		var x: float = -310 + i * 40
		_pile(Vector3(x, 0, 135), 16, 9, "ore")
		_pile(Vector3(x + 18, 0, 150), 12, 7, "coal")
	_pile(Vector3(-190, 0, 150), 11, 6, "lime")
	# Ore bridge: a 70 m gantry on rails either side of the piles, parked
	# over the yard, with its trolley and hanging grab.
	var bx: float = -290.0
	for z in [110.0, 175.0]:
		_track(Vector3(-340, 0, z), Vector3(-160, 0, z))
		for dx in [-6.0, 6.0]:
			geo.beam(Vector3(bx + dx, 0.5, z), Vector3(bx, 28, z), Vector2(1.2, 1.2), "paint")
	_truss(Vector3(bx, 30, 105), Vector3(bx, 30, 180), 4.0, 5.0, "paint")
	geo.box(Vector3(bx, 33.5, 140), Vector3(6, 3, 8), "paint")
	for dz in [-1.0, 1.0]:
		geo.beam(Vector3(bx, 32, 140 + dz), Vector3(bx, 16, 140 + dz), Vector2(0.08, 0.08), "rail", false)
	geo.cone(Vector3(bx, 16, 140), Vector3(bx, 13.5, 140), 1.8, 0.4, "rust_dark", 8)

## A box-lattice truss between a and b: 4 chords and diagonal bracing.
func _truss(a: Vector3, b: Vector3, w: float, h: float, mat: String) -> void:
	var along: Vector3 = (b - a).normalized()
	var side: Vector3 = along.cross(Vector3.UP).normalized() * w * 0.5
	var up: Vector3 = Vector3.UP * h * 0.5
	for c in [side + up, side - up, -side + up, -side - up]:
		geo.beam(a + c, b + c, Vector2(0.5, 0.5), mat)
	var n: int = int(a.distance_to(b) / 5.0)
	for i in range(n):
		var p0: Vector3 = a.lerp(b, float(i) / n)
		var p1: Vector3 = a.lerp(b, float(i + 1) / n)
		for s in [side, -side]:
			geo.beam(p0 + s - up, p1 + s + up, Vector2(0.25, 0.25), mat)
		geo.beam(p0 - side - up, p0 + side - up, Vector2(0.25, 0.25), mat)
		geo.beam(p0 - side + up, p0 + side + up, Vector2(0.25, 0.25), mat)

# --- coke plant -----------------------------------------------------------------

func _coke_plant() -> void:
	# The battery: a long brick block of ~50 ovens, charging deck on top
	# with the larry car's rails, standpipes along the back.
	var c := Vector3(-245, 0, -140)
	geo.box(c + Vector3(0, 6, 0), Vector3(110, 12, 14), "brick")
	geo.box(c + Vector3(0, 12.3, 0), Vector3(112, 0.6, 16), "concrete")
	for i in range(28):
		var x: float = c.x - 52 + i * 3.8
		geo.cylinder(Vector3(x, 12.6, c.z - 5.5), Vector3(x, 16.5, c.z - 5.5), 0.35, "rust", 8)
		geo.box(Vector3(x, 6, c.z + 7.1), Vector3(1.4, 10, 0.3), "rust_dark") # oven doors
	geo.beam(c + Vector3(-55, 16.8, -5.5), c + Vector3(55, 16.8, -5.5), Vector2(1.2, 1.2), "rust") # collecting main
	for dz in [-2.0, 2.0]:
		geo.beam(c + Vector3(-55, 12.8, dz), c + Vector3(55, 12.8, dz), Vector2(0.2, 0.2), "rail", false)
	geo.box(c + Vector3(20, 15, 0), Vector3(8, 4, 6), "yellow") # larry car
	# Coal tower at the east end; the coal gallery feeds it.
	geo.box(Vector3(-176, 17, -140), Vector3(14, 34, 14), "concrete")
	_gallery(Vector3(-260, 3, 120), Vector3(-176, 30, -130), 3.4)
	# Quench tower: open-topped, big openings on two sides - dive in.
	_open_tower(Vector3(-315, 0, -110), Vector2(12, 12), 36.0, "concrete")
	_track(Vector3(-315, 0, -140), Vector3(-315, 0, -100))
	# Battery chimney: 80 m of brick.
	_chimney(Vector3(-245, 0, -175), 80.0, 4.5, "brick")
	_hall(Vector3(-205, 0, -85), Vector3(40, 14, 24), "corrugated", {"s": [[0.0, 10.0, 8.0]]}) # by-product plant

## A tall hollow shaft: four walls with big openings, no roof.
func _open_tower(c: Vector3, fp: Vector2, h: float, mat: String) -> void:
	var t: float = 0.5
	for side in [[Vector3(0, 0, -fp.y * 0.5), Vector3(fp.x, 0, t)], [Vector3(0, 0, fp.y * 0.5), Vector3(fp.x, 0, t)], [Vector3(-fp.x * 0.5, 0, 0), Vector3(t, 0, fp.y)], [Vector3(fp.x * 0.5, 0, 0), Vector3(t, 0, fp.y)]]:
		var open: bool = side[0].x != 0.0
		if open:
			# Pillars and lintels: a 7 m opening from 6 m to 13 m up, and
			# another near the top.
			for band in [[0.0, 6.0], [13.0, 26.0], [31.0, h]]:
				geo.box(c + side[0] + Vector3(0, (band[0] + band[1]) * 0.5, 0), side[1] + Vector3(0, band[1] - band[0], 0), mat)
			for zo in [-1.0, 1.0]:
				for band in [[6.0, 13.0], [26.0, 31.0]]:
					geo.box(c + side[0] + Vector3(0, (band[0] + band[1]) * 0.5, zo * (fp.y * 0.5 - 1.25)), Vector3(t, band[1] - band[0], 2.5), mat)
		else:
			geo.box(c + side[0] + Vector3(0, h * 0.5, 0), side[1] + Vector3(0, h, 0), mat)

func _chimney(base: Vector3, h: float, r: float, mat: String) -> void:
	var prof: Array[Vector2] = [Vector2(r, 0), Vector2(r * 0.62, h)]
	geo.lathe(base, prof, mat, 18, 0.6)
	for y in [h * 0.4, h * 0.7, h - 1.0]:
		var rr: float = lerpf(r, r * 0.62, y / h) + 0.15
		geo.lathe(base + Vector3(0, y, 0), [Vector2(rr, 0), Vector2(rr, 0.8)], "rust_dark", 18, 0.3, false)

## Enclosed conveyor gallery on trestles, hollow inside (3.4 m square),
## with some side panels missing.
func _gallery(a: Vector3, b: Vector3, s: float) -> void:
	var d: Vector3 = b - a
	var basis := Basis.looking_at(d.normalized(), Vector3.UP)
	var n: int = int(d.length() / 6.0)
	for i in range(n):
		var p0: Vector3 = a.lerp(b, float(i) / n)
		var p1: Vector3 = a.lerp(b, float(i + 1) / n)
		var mid: Vector3 = (p0 + p1) * 0.5
		var seg: float = p0.distance_to(p1)
		var parts: Array = [[Vector3(0, -s * 0.5, 0), Vector3(s, 0.2, seg), "rust_dark"], [Vector3(0, s * 0.5, 0), Vector3(s, 0.15, seg), "corrugated"]]
		for sx in [-1.0, 1.0]:
			if rng.randf() > 0.2:
				parts.append([Vector3(sx * s * 0.5, 0, 0), Vector3(0.12, s, seg), "corrugated"])
		for part in parts:
			geo.box_xf(Transform3D(basis, mid + basis * part[0]), part[1], part[2])
		if i % 3 == 0 and p0.y > 4.0:
			for sx in [-1.0, 1.0]:
				var top: Vector3 = p0 + basis * Vector3(sx * s * 0.5, -s * 0.5, 0)
				geo.beam(Vector3(top.x, 0, top.z), top, Vector2(0.4, 0.4), "paint")

# --- blast furnaces -------------------------------------------------------------

## side: +1 = skip bridge and stock house toward +x (the middle, for
## the west furnace), dust catcher toward -x; -1 mirrors it.
func _blast_furnace(o: Vector3, idx: int, side: float) -> void:
	# Furnace shell: hearth, bosh, stack narrowing to the throat, then the
	# top with its uptakes. ~12 m hearth, ~45 m to the top platform.
	var prof: Array[Vector2] = [Vector2(7.5, 0), Vector2(7.5, 8), Vector2(9.0, 14), Vector2(8.5, 18), Vector2(6.5, 36), Vector2(5.0, 40)]
	geo.lathe(o, prof, "rust", 24)
	geo.box(o + Vector3(0, 40.5, 0), Vector3(16, 1.0, 16), "paint")          # top platform
	geo.cone(o + Vector3(0, 41, 0), o + Vector3(0, 46, 0), 4.5, 3.0, "rust_dark", 16)
	# Four uptakes rising from the top, joined into the downcomer.
	for i in range(4):
		var a: float = TAU * i / 4.0 + PI * 0.25
		var foot: Vector3 = o + Vector3(cos(a) * 3.2, 44, sin(a) * 3.2)
		geo.cylinder(foot, o + Vector3(cos(a) * 3.0, 54, sin(a) * 3.0), 0.9, "rust", 10)
	geo.box(o + Vector3(0, 54.5, 0), Vector3(8, 1.5, 8), "rust_dark")
	# Downcomer to the dust catcher on the outer side.
	var dc := o + Vector3(-24 * side, 0, 0)
	geo.cylinder(o + Vector3(-2 * side, 54.5, 0), dc + Vector3(0, 31, 0), 1.3, "rust", 12)
	geo.cylinder(dc + Vector3(0, 16, 0), dc + Vector3(0, 30, 0), 5.0, "rust", 18)
	geo.cone(dc + Vector3(0, 16, 0), dc + Vector3(0, 9, 0), 5.0, 0.8, "rust_dark", 18)
	geo.cone(dc + Vector3(0, 30, 0), dc + Vector3(0, 33, 0), 5.0, 1.2, "rust_dark", 18)
	for i in range(4):
		var a: float = TAU * i / 4.0
		geo.beam(dc + Vector3(cos(a) * 4.0, 0, sin(a) * 4.0), dc + Vector3(cos(a) * 4.0, 18, sin(a) * 4.0), Vector2(0.7, 0.7), "paint")
	# Hot stoves: three domed towers north of the furnace, the hot blast
	# main back to the bustle pipe ringing the furnace.
	for i in range(3):
		var s := o + Vector3(-14 + i * 14, 0, -40)
		geo.lathe(s, [Vector2(5.0, 0), Vector2(5.0, 34), Vector2(4.2, 38), Vector2(2.5, 40.5), Vector2(0.1, 41.2)], "paint", 20)
		geo.cylinder(s + Vector3(0, 10, 5.0), s + Vector3(0, 10, 8.0), 1.0, "rust", 10)
	geo.pipe(o + Vector3(-18, 10, -32), o + Vector3(18, 10, -32), 1.6, 0.2, "rust", 16)
	geo.pipe(o + Vector3(0, 10, -32), o + Vector3(0, 12, -11), 1.6, 0.2, "rust", 16)
	var ring: Array[Vector2] = [Vector2(11.2, 0), Vector2(11.2, 1.6)]
	geo.lathe(o + Vector3(0, 11.2, 0), ring, "rust_dark", 24, 1.6)
	# Skip bridge: inclined truss from the stock house up to the top.
	var skip_foot := o + Vector3(42 * side, 2, 0)
	_truss(skip_foot, o + Vector3(6 * side, 44, 0), 3.5, 3.0, "paint")
	_hall(o + Vector3(48 * side, 0, 0), Vector3(12, 12, 20), "corrugated", {("w" if side > 0 else "e"): [[0.0, 8.0, 7.0]]}) # stock house
	_gallery(Vector3(-150 + idx * 20, 3, 118), o + Vector3(48 * side, 13, 8), 3.4)
	# Cast house over the torpedo line, south of the furnace (the line
	# runs 5 m south of the hall's centre).
	_hall(o + Vector3(0, 0, 30), Vector3(36, 16, 26), "corrugated", {"w": [[5.0, 8.0, 7.0]], "e": [[5.0, 8.0, 7.0]], "n": [[0.0, 14.0, 12.0]]})
	# Furnace columns and a stair tower to the top.
	for i in range(4):
		var a: float = TAU * i / 4.0 + PI * 0.25
		geo.beam(o + Vector3(cos(a) * 11, 0, sin(a) * 11), o + Vector3(cos(a) * 8, 40, sin(a) * 8), Vector2(1.0, 1.0), "paint")
	_stair_tower(o + Vector3(11, 0, -11), 40.0)

func _stair_tower(o: Vector3, h: float) -> void:
	for dx in [-1.5, 1.5]:
		for dz in [-1.5, 1.5]:
			geo.box(o + Vector3(dx, h * 0.5, dz), Vector3(0.3, h, 0.3), "paint")
	for y in range(4, int(h), 4):
		geo.box(o + Vector3(0, y, 0), Vector3(3.3, 0.15, 3.3), "rust_dark", 0.0, true, false)

# --- gas main -------------------------------------------------------------------

## Blast-furnace gas from both dust catchers to the gas holder: a 3 m
## diameter main on trestles, 14 m up - hollow, fly through it (the
## joints are open, so you can get in and out along the way).
func _gas_main() -> void:
	var y: float = 14.5
	var pts: Array[Vector3] = [Vector3(BF[0].x - 24, y, -35), Vector3(BF[0].x - 24, y, -110), Vector3(250, y, -110), Vector3(250, y, -128)]
	geo.cylinder(Vector3(BF[0].x - 24, 31, -35), Vector3(BF[0].x - 24, y, -35), 1.2, "rust", 12)
	geo.cylinder(Vector3(BF[1].x + 24, 31, -35), Vector3(BF[1].x + 24, y, -35), 1.2, "rust", 12)
	geo.pipe(Vector3(BF[1].x + 24, y, -35), Vector3(BF[1].x + 24, y, -108.5), 1.5, 0.15, "rust", 18)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		var n: int = int(a.distance_to(b) / 24.0) + 1
		for k in range(n):
			var p0: Vector3 = a.lerp(b, float(k) / n)
			var p1: Vector3 = a.lerp(b, (k + 0.92) / n) # a small open gap at every joint
			geo.pipe(p0, p1, 1.5, 0.15, "rust", 18)
			geo.box(Vector3(p0.x, (y - 1.6) * 0.5, p0.z), Vector3(0.8, y - 1.6, 0.8), "paint")
			geo.box(Vector3(p0.x, y - 1.7, p0.z), Vector3(4.0, 0.3, 1.0) if absf(b.x - a.x) < 1.0 else Vector3(1.0, 0.3, 4.0), "paint")
	# Gas holder: a 45 m drum with its external guide frame.
	var gh := Vector3(250, 0, -150)
	geo.lathe(gh, [Vector2(22, 0), Vector2(22, 44), Vector2(18, 48), Vector2(0.2, 50)], "paint", 32)
	for i in range(16):
		var a: float = TAU * i / 16.0
		geo.beam(gh + Vector3(cos(a) * 23.5, 0, sin(a) * 23.5), gh + Vector3(cos(a) * 23.5, 52, sin(a) * 23.5), Vector2(0.8, 0.8), "rust_dark")
	for y2 in [15.0, 30.0, 45.0]:
		geo.lathe(gh + Vector3(0, y2, 0), [Vector2(24.2, 0), Vector2(24.2, 1.0)], "rust_dark", 32, 1.2)

# --- steel shop and rolling mill ------------------------------------------------

func _bof_shop() -> void:
	var c := Vector3(145, 0, -15)
	_hall(c, Vector3(70, 42, 90), "corrugated", {"w": [[TORPEDO_Z + 15.0, 10.0, 9.0]], "e": [[0.0, 20.0, 16.0]], "s": [[-20.0, 12.0, 10.0]]}, 0.3)
	# Converters: pear-shaped vessels on trunnions, ~8 m across.
	for dz in [-25.0, 0.0]:
		var v := c + Vector3(-5, 8, dz)
		geo.lathe(v, [Vector2(1.5, 0), Vector2(4.2, 2.0), Vector2(4.2, 7.0), Vector2(2.2, 10.5), Vector2(1.8, 11.2)], "rust", 18, 0.4)
		geo.box(v + Vector3(0, 4.5, 0), Vector3(1.2, 1.2, 11), "rust_dark")
		for sz in [-5.8, 5.8]:
			geo.box(Vector3(v.x, 6, v.z + sz), Vector3(2, 12, 1.2), "concrete")
	# Overhead ladle crane.
	for dx in [-30.0, 30.0]:
		geo.beam(c + Vector3(dx, 34, -44), c + Vector3(dx, 34, 44), Vector2(1.2, 2.0), "paint")
	geo.box(c + Vector3(0, 35.5, 10), Vector3(62, 3, 6), "yellow")
	# Continuous caster: the tall bay on the east side.
	_hall(c + Vector3(55, 0, -15), Vector3(40, 30, 40), "corrugated", {"w": [[0.0, 14.0, 12.0]], "e": [[0.0, 10.0, 8.0]]}, 0.35)

func _rolling_mill() -> void:
	var c := Vector3(293, 0, -15)
	_hall(c, Vector3(126, 20, 44), "corrugated", {"w": [[0.0, 12.0, 10.0]], "e": [[0.0, 12.0, 10.0]]}, 0.3)
	# Reheating furnace at the west end, then roll stands along a roller
	# table - a straight 120 m run down the hall.
	geo.box(c + Vector3(-52, 4, 0), Vector3(14, 8, 14), "brick")
	geo.box(c + Vector3(0, 0.7, 0), Vector3(110, 1.0, 3.0), "rust_dark")
	for i in range(6):
		var x: float = c.x - 35 + i * 12
		for dz in [-3.2, 3.2]:
			geo.box(Vector3(x, 4.5, c.z + dz), Vector3(3.0, 9.0, 1.4), "paint")
		geo.box(Vector3(x, 8.6, c.z), Vector3(3.0, 1.2, 7.8), "paint")
		geo.cylinder(Vector3(x, 2.6, c.z - 2.5), Vector3(x, 2.6, c.z + 2.5), 0.8, "rust", 12)
	# Crane runway and a stopped crane.
	for dz in [-19.0, 19.0]:
		geo.beam(c + Vector3(-62, 15, dz), c + Vector3(62, 15, dz), Vector2(0.8, 1.4), "paint")
	geo.box(c + Vector3(30, 16.2, 0), Vector3(5, 2.4, 39), "yellow")

## An abandoned industrial hall around a floor centre `o`, size (x, h, z).
## Built from 8 m bays: a brick base course, corrugated sheeting above
## with a window band, roof panels over trusses. `holes` is the chance
## that a sheet or roof panel is simply gone (rusted through / blown
## off) - those are the ways in. `doors`: side ("n","s","w","e") ->
## [[centre offset along the wall, width, height]] - always open.
func _hall(o: Vector3, size: Vector3, sheet: String, doors: Dictionary = {}, holes: float = 0.25) -> void:
	var hx: float = size.x * 0.5
	var hz: float = size.z * 0.5
	var h: float = size.y
	geo.slab(Rect2(o.x - hx, o.z - hz, size.x, size.z), 0.18, 0.2, "concrete")
	var sides := {"n": [Vector3(0, 0, -hz), Vector3.RIGHT, size.x], "s": [Vector3(0, 0, hz), Vector3.RIGHT, size.x],
		"w": [Vector3(-hx, 0, 0), Vector3.BACK, size.z], "e": [Vector3(hx, 0, 0), Vector3.BACK, size.z]}
	for key in sides:
		var base: Vector3 = o + sides[key][0]
		var dir: Vector3 = sides[key][1]
		var length: float = sides[key][2]
		var bays: int = maxi(1, int(round(length / 8.0)))
		var bay: float = length / bays
		var yaw: float = 0.0 if dir == Vector3.RIGHT else PI * 0.5
		for b in range(bays):
			var along: float = -length * 0.5 + (b + 0.5) * bay
			var p: Vector3 = base + dir * along
			geo.box(p - dir * bay * 0.5 + Vector3(0, h * 0.5, 0), Vector3(0.6, h, 0.6), "paint")
			var rows: int = int(h / 4.0)
			for r in range(rows):
				var y0: float = r * 4.0
				var y1: float = h if r == rows - 1 else y0 + 4.0
				if _in_door(doors.get(key, []), along, bay, y0):
					continue
				var mid := p + Vector3(0, (y0 + y1) * 0.5, 0)
				var sz := Vector3(bay - 0.6, y1 - y0, 0.25)
				if r == 0:
					geo.box(mid, sz, "brick", yaw)
				elif r == 1 and h > 10.0:
					if rng.randf() > holes * 1.6:
						geo.box(mid, sz, "glass", yaw, true, false)
				elif rng.randf() > holes:
					geo.box(mid, sz, sheet, yaw)
		geo.box(base + dir * length * 0.5 + Vector3(0, h * 0.5, 0), Vector3(0.6, h, 0.6), "paint")
	# Roof: trusses every 8 m across the short span, panels between.
	var along_x: bool = size.x >= size.z
	var span_len: float = size.x if along_x else size.z
	var n: int = maxi(1, int(round(span_len / 8.0)))
	for i in range(n):
		var t: float = -span_len * 0.5 + (i + 0.5) * span_len / n
		var pc := o + (Vector3(t, h, 0) if along_x else Vector3(0, h, t))
		var truss_a := pc + (Vector3(-span_len / n * 0.5, -0.8, -hz) if along_x else Vector3(-hx, -0.8, -span_len / n * 0.5))
		var truss_b := pc + (Vector3(-span_len / n * 0.5, -0.8, hz) if along_x else Vector3(hx, -0.8, -span_len / n * 0.5))
		geo.beam(truss_a, truss_b, Vector2(0.4, 1.2), "rust_dark")
		var strips: int = 4
		for k in range(strips):
			if rng.randf() < holes:
				continue
			var u: float = -0.5 + (k + 0.5) / strips
			var ps := pc + (Vector3(0, 0.2, u * size.z) if along_x else Vector3(u * size.x, 0.2, 0))
			var ss := Vector3(span_len / n, 0.2, size.z / strips) if along_x else Vector3(size.x / strips, 0.2, span_len / n)
			geo.box(ps, ss, sheet)

func _in_door(list: Array, along: float, bay: float, y0: float) -> bool:
	for d in list:
		if absf(along - d[0]) < (d[1] + bay) * 0.5 - 0.5 and y0 < d[2]:
			return true
	return false

# --- power plant, south ----------------------------------------------------------

func _power_plant() -> void:
	_hall(Vector3(30, 0, 150), Vector3(60, 26, 36), "brick", {"n": [[0.0, 10.0, 9.0]]}, 0.2)
	_chimney(Vector3(15, 0, 180), 95.0, 5.0, "brick")
	_chimney(Vector3(45, 0, 180), 90.0, 4.5, "concrete")
	# Hyperbolic cooling tower, 90 m: open at the top, gaps between the
	# support legs at the bottom - fly in low, climb out the top.
	var ct := Vector3(-120, 0, 150)
	var prof: Array[Vector2] = []
	for i in range(13):
		var t: float = i / 12.0
		var y: float = 8.0 + t * 82.0
		var r: float = 24.0 + 14.0 * pow(absf(t - 0.72) / 0.72, 2.0) if t < 0.72 else 24.0 + 6.0 * pow((t - 0.72) / 0.28, 2.0)
		prof.append(Vector2(r, y))
	geo.lathe(ct, prof, "concrete", 40, 0.8)
	for i in range(24):
		var a: float = TAU * i / 24.0
		var r0: float = prof[0].x
		geo.beam(ct + Vector3(cos(a) * r0, 0, sin(a) * r0), ct + Vector3(cos(a + 0.12) * r0, 8.2, sin(a + 0.12) * r0), Vector2(0.9, 0.9), "concrete")
	# Water tower.
	var wt := Vector3(-60, 0, 172)
	for i in range(4):
		var a: float = TAU * i / 4.0 + PI * 0.25
		geo.beam(wt + Vector3(cos(a) * 5, 0, sin(a) * 5), wt + Vector3(cos(a) * 3, 24, sin(a) * 3), Vector2(0.5, 0.5), "paint")
	geo.lathe(wt + Vector3(0, 24, 0), [Vector2(1.5, 0), Vector2(5.5, 3), Vector2(5.5, 9), Vector2(0.2, 11)], "paint", 18)

func _extras() -> void:
	# Gatehouse and office by the south entrance road.
	_hall(Vector3(245, 0, 150), Vector3(24, 8, 12), "brick", {"w": [[0.0, 3.0, 3.0]]}, 0.1)
	geo.box(Vector3(213, 1.5, 186), Vector3(0.5, 3, 0.5), "paint")
	geo.beam(Vector3(213, 1.2, 186), Vector3(226, 1.2, 186), Vector2(0.2, 0.2), "yellow")
	# Overgrowth: young trees inside the site, in the weedy patches.
	var trees: Array = []
	for i in range(120):
		var p := Vector3(rng.randf_range(-350, 350), 0.1, rng.randf_range(-200, 185))
		if _clear_of_buildings(p):
			trees.append([p, 1, rng.randf_range(0.5, 0.85)])
	Forest.plant(self, trees, self)

func _clear_of_buildings(p: Vector3) -> bool:
	var keep_out: Array[Rect2] = [Rect2(-110, -95, 220, 130), Rect2(80, -70, 300, 110), Rect2(-340, -190, 180, 120),
		Rect2(-340, 60, 200, 130), Rect2(-170, 110, 250, 90), Rect2(-790, 60, 1150, 22), Rect2(-100, -125, 380, 30), Rect2(220, -180, 60, 60)]
	for r in keep_out:
		if r.has_point(Vector2(p.x, p.z)):
			return false
	return true

## Workers' town (brick terraces, church) on the levelled ground east
## of the works, a road to the gate, and the slag heap: decades of
## furnace slag tipped into a terraced hill south-east of the site.
func _town_and_heap() -> void:
	MapProps.town(geo, TOWN, _height, rng, true)
	geo.beam(Vector3(360, 0.1, 105), Vector3(470, TOWN_Y + 0.1, 30), Vector2(8, 0.3), "asphalt", true, false)
	var heap := Vector3(470, 0, 330)
	var hy: float = _height(heap.x, heap.z)
	geo.lathe(heap + Vector3(0, hy - 2.0, 0), [Vector2(110, 0), Vector2(95, 12), Vector2(80, 14), Vector2(62, 28), Vector2(48, 30), Vector2(26, 44), Vector2(4, 46)], "slag", 28)

func _forest() -> void:
	var trees: Array = []
	var frng := RandomNumberGenerator.new()
	frng.seed = 4
	var attempts: int = 0
	while trees.size() < 7000 and attempts < 40000:
		attempts += 1
		var x: float = frng.randf_range(-1080, 1080)
		var z: float = frng.randf_range(-980, 980)
		if SITE.grow(6.0).has_point(Vector2(x, z)) or TOWN.grow(15.0).has_point(Vector2(x, z)) or Vector2(x - 470, z - 330).length() < 115.0:
			continue
		if absf(z - TRACK_Z) < 8.0 and x < SITE.position.x:
			continue # the railway cutting into the woods
		var y: float = _height(x, z)
		trees.append([Vector3(x, y - 0.2, z), 0 if frng.randf() < 0.65 else 1, frng.randf_range(0.9, 1.6)])
	Forest.plant(self, trees)
