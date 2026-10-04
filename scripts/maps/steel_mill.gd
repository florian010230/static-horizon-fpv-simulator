extends BuiltMap

## Abandoned Steel Mill - the High showcase map, laid out after the
## Völklinger Hütte (Saarland; UNESCO World Heritage since 1994), the
## only integrated ironworks of its era that survived complete. As
## there, everything lines up along the Saar valley (north = -z):
##
##   river Saar (south) - riverside road - main railway with Völklingen
##   station - the Cowper stoves (hot-blast heaters, 3 per furnace) -
##   the iron line under the cast houses - SIX blast furnaces in one row
##   - the inclined skip hoists (Schrägaufzüge) rising from - the
##   Möllerhalle, the burden bunker building on its concrete columns -
##   the suspended ore monorail (Erzhängebahn) bringing ore over from the
##   ore yard - coking plant and sinter plant (north) - the old town of
##   Völklingen on the hill.
##   West: the blower hall (Gebläsehalle) with the cold-blast main to
##   the stoves; the "Paradies", the overgrown corner nature took back.
##   East: gas holder, gas-cleaning/power house and its chimneys.
##
## Sources: Weltkulturerbe Völklinger Hütte site plan and photos
## (voelklinger-huette.org), Wikipedia "Völklinger Hütte". Distances
## are compressed (the real furnace row is ~300 m, here 216 m) - the
## whole works fits in ~700 x 400 m, and everything is close together.
##
## FPV lines by design: gaps between furnace legs, dust catchers and
## pipes; under the Möllerhalle between its columns (6 m clearance);
## the skip hoists to follow up to the furnace tops; the gas main and
## hot-blast pipes are hollow (in at the open joints); the quench tower
## and chimney tops are open to dive; the blower hall has missing
## windows; the monorail to chase.

const SITE := Rect2(-340, -195, 680, 420)
const FX: Array[float] = [-90.0, -54.0, -18.0, 18.0, 54.0, 90.0] ## furnace row
const FZ: float = 40.0
const IRON_Z: float = 64.0   ## iron line under the cast houses
const STOVE_Z: float = 96.0
const MAIN_Z: float = 170.0  ## main line (two tracks, +-4 m)
const MOLLER := Rect2(-122, -12, 244, 26)
const RIVER_Z: float = 240.0
const TOWN := Rect2(-280, -335, 560, 96)
const TOWN_Y: float = 14.0

var rng := RandomNumberGenerator.new()
var rails: Rails
var _noise := FastNoiseLite.new()

func map_env() -> Dictionary:
	# Hazy morning over the Saar: low warm sun from the east.
	return {"sun_rot": Vector3(-22, -75, 0), "sun_color": Color(1.0, 0.82, 0.62), "sun_energy": 1.3,
		"sky_top": Color(0.34, 0.48, 0.68), "sky_horizon": Color(0.86, 0.8, 0.7),
		"ambient": Color(0.64, 0.64, 0.66), "ambient_energy": 0.78,
		"fog_begin": 260.0, "shadow_region": Rect2(-430, -380, 860, 760)}

func border() -> Array:
	return [430.0, 520.0, 170.0, 230.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(180, 85, 230), Vector3(-10, 20, 20)],
		["furnace_row", Vector3(-150, 22, 74), Vector3(100, 18, 40)],
		["moller_under", Vector3(-100, 3.0, 7), Vector3(100, 3.0, 7)],
		["skip_hoist", Vector3(-30, 20, 75), Vector3(-18, 34, 30)],
		["stoves", Vector3(-130, 12, 115), Vector3(60, 14, 96)],
		["ore_yard", Vector3(-180, 35, -30), Vector3(-300, 5, -120)],
		["coke", Vector3(20, 30, -60), Vector3(160, 10, -130)],
		["blower_hall", Vector3(-140, 8, 10), Vector3(-200, 6, 10)],
		["station", Vector3(320, 12, 200), Vector3(150, 4, 170)],
		["town", Vector3(0, 40, -170), Vector3(0, 14, -290)],
		["horizon", Vector3(0, 60, 0), Vector3(-600, 20, 0)],
	]

func build() -> void:
	rng.seed = 1873 # the year the Völklingen ironworks was founded
	geo.ao_height = 6.0
	geo.ao_min = 0.45
	_noise.seed = 31
	_noise.frequency = 0.005
	_noise.fractal_octaves = 4
	_materials()
	_ground()
	_rail()
	_roads()
	_moller()
	for i in range(FX.size()):
		_blast_furnace(i)
	_gas()
	_stoves()
	_blower_hall()
	_monorail()
	_ore_yard()
	_coke_plant()
	_sinter_plant()
	_east_works()
	_station()
	_paradies()
	_decay()
	YardProps.scatter(geo, SITE.grow(-10.0), 0.05, 45, rng, [], true)
	MapProps.town(geo, TOWN, _height, rng, true)
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
	geo.add_material("slag_ground", Geo.ground_mat(MapTextures.get_tex("slag"), Color.WHITE, 10.0, 1, 0.5))
	geo.add_material("slag", Geo.tex_mat(MapTextures.get_tex("slag"), Color.WHITE, 10.0))
	geo.add_material("weeds", Geo.ground_mat(MapTextures.get_tex("meadow"), Color(0.9, 0.9, 0.8), 10.0, 3, 0.4))
	geo.add_material("ore", Geo.tex_mat(MapTextures.get_tex("slag"), Color(1.6, 0.75, 0.5), 6.0))
	geo.add_material("coal", Geo.tex_mat(MapTextures.get_tex("slag"), Color(0.45, 0.45, 0.47), 6.0))
	geo.add_material("rail", Geo.flat_mat(Color(0.45, 0.35, 0.3), 0.5, 0.6))
	geo.add_material("ballast", Geo.tex_mat(ProceduralTextures.gravel_texture(), Color(0.55, 0.52, 0.5), 2.0))
	geo.add_material("yellow", Geo.flat_mat(Color(0.75, 0.55, 0.12), 0.6, 0.2))
	geo.add_material("water", Geo.water_mat(Color(0.16, 0.26, 0.24), 0.9))
	geo.add_material("terrain", Geo.tex_mat(MapTextures.get_tex("forest_floor"), Color.WHITE, 12.0))
	geo.add_material("platform", Geo.ground_mat(MapTextures.get_tex("paving_slabs"), Color.WHITE, 3.0, 2))

# --- ground -------------------------------------------------------------------

## The Saar valley runs east-west: a flat floor for the works, the
## railway and the roads (all of them leave the map along it), the town
## on a terrace up the north slope, the river along the south.
func _height(x: float, z: float) -> float:
	var n: float = _noise.get_noise_2d(x, z) * 0.5 + 0.5
	if z < -205.0:
		var t: float = smoothstep(-205.0, -238.0, z)
		var y: float = TOWN_Y * t
		if z < -345.0:
			y += smoothstep(-345.0, -420.0, z) * (10.0 + n * 40.0) + maxf(-420.0 - z, 0.0) * 0.08
		return y
	if z > 228.0:
		var bank: float = -5.0 * smoothstep(228.0, 246.0, z)
		var far: float = smoothstep(318.0, 345.0, z) * (5.0 + 3.0 * n) + smoothstep(380.0, 470.0, z) * (8.0 + n * 34.0)
		return bank + far * (1.0 if z > 300.0 else 0.0)
	return -0.2

func _ground() -> void:
	var tshade := func(nn: Vector3, p: Vector3) -> Color: return geo.shade(nn, p.y + 50.0)
	var inner := Rect2(-1300, -900, 2600, 1600)
	Terrain.build(self, inner, 8.0, _height, geo._mats["terrain"], tshade)
	Terrain.far_ring(self, inner, Rect2(-4200, -4200, 8400, 8400), 64.0, _height, geo._mats["terrain"], tshade)
	# The works' surface: slag fill, weedy patches.
	geo.slab(SITE, 0.0, 0.5, "slag_ground")
	for i in range(55):
		var c := Vector2(rng.randf_range(SITE.position.x, SITE.end.x), rng.randf_range(SITE.position.y, SITE.end.y))
		geo.slab(Rect2(c, Vector2(rng.randf_range(8, 30), rng.randf_range(8, 30))), 0.12, 0.1, "weeds", false)
	# The Saar, running on out of sight both ways.
	geo.slab(Rect2(-4200, 236, 8400, 92), -2.2, 0.1, "water", false)
	# Quay wall along the works bank.
	geo.box(Vector3(0, -1.2, 230.5), Vector3(8400, 2.6, 1.0), "concrete")

# --- railway ----------------------------------------------------------------------

## The Saarbrücken - Trier main line: double track along the valley,
## through Völklingen station, out of sight both ways. Off it, through
## real turnouts: the iron line (east end, back west under the cast
## houses to a buffer stop past the first furnace) and the ore line
## (west end, curving north into the ore yard).
func _rail() -> void:
	rails = Rails.new(geo)
	var north := Route.from(Vector3(-3200, 0, MAIN_Z - 4.0), 0.0).straight(6400.0, 12.0)
	var south := Route.from(Vector3(-3200, 0, MAIN_Z + 4.0), 0.0).straight(6400.0, 12.0)
	rails.track(north, 0)
	rails.track(south, 0)
	rails.catenary(north, -1.0, 2600.0, 3800.0)
	rails.catenary(south, 1.0, 2600.0, 3800.0)
	# Crossover east of the station, so either track reaches the works.
	rails.crossover(south, south.dist_at_x(380.0), -1.0, 8.0, 1)
	# Iron line: leaves the north track heading west at x 640, reverse
	# curves north 102 m, then straight west under the cast houses.
	var west := north.reversed()
	var iron: Route = rails.turnout(west, west.dist_at_x(640.0), 1.0)
	_s_curve(iron, 1.0, MAIN_Z - 4.0 - IRON_Z, 320.0)
	iron.straight(absf(iron.end().x - (FX[0] - 30.0)), 12.0)
	rails.track(iron, 1)
	rails.buffer_stop(iron)
	# Ore line: off the north track at x -760, one long curve (R 300) round
	# to the north, into the ore yard.
	var ore: Route = rails.turnout(north, north.dist_at_x(-620.0), -1.0)
	ore.arc(300.0, -(90.0 - Rails.TURNOUT_ANGLE), 4.0)
	ore.straight(absf(ore.end().z - (-178.0)), 12.0)
	rails.track(ore, 1)
	rails.buffer_stop(ore)
	for x in [-520.0, 520.0]:
		rails.signal_at(north, north.dist_at_x(x), false)
	# Rolling stock where it was left: torpedo cars under the cast houses,
	# ore hoppers in the yard, a freight train on the main line.
	for i in [0, 2, 3, 5]:
		rails.train(iron, iron.dist_at_x(FX[i] + 13.0), ["torpedo"], rng)
	rails.train(iron, iron.dist_at_x(260.0), ["shunter", "torpedo", "torpedo"], rng)
	rails.train(ore, ore.length() - 120.0, ["hopper", "hopper", "hopper", "hopper", "hopper", "hopper", "hopper", "hopper"], rng)
	rails.train(south, south.dist_at_x(-420.0), ["loco", "hopper", "hopper", "hopper", "hopper", "hopper", "hopper", "hopper", "hopper", "hopper", "hopper"], rng)
	rails.train(north, north.dist_at_x(150.0), ["loco", "coach", "coach", "coach"], rng)

## Reverse curves taking `r` sideways by `off` metres back to the old
## heading (a turnout's diverging route continues from there).
func _s_curve(t: Route, side: float, off: float, r: float) -> void:
	var a0: float = deg_to_rad(Rails.TURNOUT_ANGLE)
	var gained: float = Rails.TURNOUT_R * (1.0 - cos(a0))
	var cos_a: float = clampf((gained + r * cos(a0) + r - off) / (2.0 * r), -1.0, 1.0)
	var a: float = rad_to_deg(acos(cos_a))
	t.arc(r, side * (a - Rails.TURNOUT_ANGLE), 3.0)
	t.arc(r, -side * a, 3.0)

## Völklingen station: a side platform on each track, shelters, the
## station building on the riverside road, a footbridge between.
func _station() -> void:
	var x0: float = 150.0
	var x1: float = 330.0
	for side in [-1.0, 1.0]:
		var z: float = MAIN_Z + side * 8.6
		geo.box(Vector3((x0 + x1) * 0.5, 0.45, z), Vector3(x1 - x0, 0.9, 5.0), "concrete")
		geo.slab(Rect2(x0, z - 2.5, x1 - x0, 5.0), 0.92, 0.05, "platform", false)
		for k in range(4):
			var sx: float = x0 + 30.0 + k * 40.0
			for dx in [-6.0, 6.0]:
				geo.box(Vector3(sx + dx, 2.6, z + side * 1.2), Vector3(0.25, 3.4, 0.25), "paint")
			geo.box(Vector3(sx, 4.4, z + side * 0.6), Vector3(14.0, 0.25, 3.4), "corrugated")
	# Footbridge over both tracks.
	var fx: float = 240.0
	for z in [MAIN_Z - 14.0, MAIN_Z + 14.0]:
		geo.box(Vector3(fx, 4.0, z), Vector3(4.0, 8.0, 4.0), "brick")
	geo.box(Vector3(fx, 8.3, MAIN_Z), Vector3(3.2, 0.4, 32.0), "concrete")
	for s in [-1.5, 1.5]:
		geo.box(Vector3(fx + s, 9.2, MAIN_Z), Vector3(0.15, 1.4, 32.0), "paint")
	geo.box(Vector3(fx, 10.4, MAIN_Z), Vector3(3.4, 0.2, 32.0), "corrugated")
	# Station building between platform and road.
	_hall(Vector3(205, 0, 194), Vector3(40, 10, 12), "brick", {"n": [[0.0, 4.0, 4.0]], "s": [[0.0, 4.0, 4.0]]}, 0.05)

# --- roads ----------------------------------------------------------------------

## The riverside road and the valley road north of the works run the
## length of the valley out of sight; the town's main street runs on
## along the hillside terrace both ways; the works road from the valley
## road down past the gas holder, over the iron line, to the visitors'
## car park.
func _roads() -> void:
	var roads := Roads.new(geo, rng, fleet)
	var river := Route.from(Vector3(-3000, 0, 214), 0.0).straight(6000.0, 12.0)
	roads.road(river, 8.0, {"detail": 2400.0, "lamps": true})
	roads.traffic(river, 8.0, 1, 10.0)
	var valley := Route.from(Vector3(-3000, 0, -200), 0.0).straight(6000.0, 12.0)
	roads.road(valley, 8.0, {"old": true, "detail": 2400.0})
	roads.junction(Vector3(135, 0, -200), Vector2(8, 8), [], 0.0, true)
	var works := Route.from(Vector3(135, 0, -196), 90.0).straight(196.0 + 80.0, 12.0)
	roads.road(works, 7.0, {"old": true, "centre": "none"})
	for x0 in [TOWN.end.x, TOWN.position.x]:
		var dir: float = 0.0 if x0 > 0.0 else 180.0
		roads.road(Route.from(Vector3(x0, TOWN_Y, -255), dir).straight(2600.0, 12.0), 7.0, {"old": true, "detail": 500.0})
	# Visitors' car park at the end of the works road.
	var cp := Rect2(139, 82, 56, 34)
	geo.slab(cp, 0.06, 0.1, "rd_asphalt_old", false)
	for row in range(2):
		for k in range(9):
			if rng.randf() < 0.7:
				fleet.car(Vector3(cp.position.x + 4.0 + k * 5.6, 0.1, cp.position.y + 5.0 + row * 24.0), PI if row == 0 else 0.0, Fleet.random_paint(rng), ["sedan", "hatch", "estate", "suv", "van"][rng.randi() % 5])

# --- Möllerhalle -------------------------------------------------------------------

## The burden bunker building: a 244 m long row of concrete bunkers on
## columns (ore, coke and limestone dropped from above, drawn off below
## into the skips). 7 m of clear height underneath, columns every 8 m -
## a 244 m slalom. Deck on top with a roofed shed (panels missing).
func _moller() -> void:
	var m: Rect2 = MOLLER
	var x: float = m.position.x
	while x <= m.end.x + 0.1:
		for z in [m.position.y + 1.0, m.get_center().y, m.end.y - 1.0]:
			geo.box(Vector3(x, 3.5, z), Vector3(1.2, 7.0, 1.2), "concrete")
		x += 8.0
	# Hoppers: one per bay and half-width, narrowing down to the gate.
	var bx: float = m.position.x + 4.0
	while bx < m.end.x:
		for zc in [m.position.y + 6.5, m.end.y - 6.5]:
			geo.frustum(Transform3D(Basis(), Vector3(bx, 9.5, zc)), Vector3(2.2, 5.0, 2.6), 7.4, 11.4, 0.0, "concrete")
			geo.box(Vector3(bx, 6.8, zc), Vector3(1.4, 0.4, 1.8), "rust_dark")
		bx += 8.0
	geo.box(Vector3(m.get_center().x, 13.5, m.get_center().y), Vector3(m.size.x + 1.2, 3.0, m.size.y), "concrete")
	geo.box(Vector3(m.get_center().x, 15.2, m.get_center().y), Vector3(m.size.x + 3.0, 0.4, m.size.y + 3.0), "concrete")
	# The shed on the deck: posts, roof panels, a third of them gone.
	x = m.position.x
	while x <= m.end.x + 0.1:
		for z in [m.position.y - 1.0, m.end.y + 1.0]:
			geo.box(Vector3(x, 18.6, z), Vector3(0.5, 6.8, 0.5), "paint")
		x += 16.0
	x = m.position.x
	while x < m.end.x - 1.0:
		if rng.randf() > 0.3:
			geo.box(Vector3(x + 8.0, 22.1, m.get_center().y), Vector3(15.6, 0.25, m.size.y + 3.0), "corrugated")
		geo.beam(Vector3(x, 21.8, m.position.y - 1.0), Vector3(x, 21.8, m.end.y + 1.0), Vector2(0.4, 0.6), "rust_dark")
		x += 16.0
	# Skip pits on the furnace side.
	for fx in FX:
		geo.box(Vector3(fx, 1.0, m.end.y + 3.5), Vector3(6.0, 2.0, 5.0), "concrete")

# --- blast furnaces ------------------------------------------------------------

## One furnace of the row: shell (hearth, bosh, stack, throat), a
## framework of four legs with catwalk rings, the bustle pipe ringing
## it, the top with its uptakes and bleeders, the downcomer to its dust
## catcher (south-east), its skip hoist up from the Möllerhalle, and its
## cast house over the iron line.
func _blast_furnace(i: int) -> void:
	var o := Vector3(FX[i], 0, FZ)
	geo.lathe(o, [Vector2(6.5, 0), Vector2(6.5, 7), Vector2(7.8, 12), Vector2(7.4, 15), Vector2(4.8, 32), Vector2(4.2, 35)], "rust", 24)
	geo.box(o + Vector3(0, 35.5, 0), Vector3(16, 0.8, 16), "paint")
	geo.cone(o + Vector3(0, 36, 0), o + Vector3(0, 41, 0), 4.0, 2.6, "rust_dark", 16)
	geo.box(o + Vector3(-5.5, 43, 5.5), Vector3(5, 4, 5), "corrugated") # top house
	for k in range(4):
		var a: float = TAU * k / 4.0 + PI * 0.25
		geo.cylinder(o + Vector3(cos(a) * 2.6, 40, sin(a) * 2.6), o + Vector3(cos(a) * 2.2, 48, sin(a) * 2.2), 0.7, "rust", 10)
	geo.box(o + Vector3(0, 48.6, 0), Vector3(6, 1.2, 6), "rust_dark")
	for s in [-1.0, 1.0]:
		geo.cylinder(o + Vector3(s * 1.6, 49, 0), o + Vector3(s * 1.6, 55, 0), 0.4, "rust", 8)
	# Framework: four legs, X-bracing on the east and west faces only
	# (the north and south faces stay open - the way through).
	var legs: Array[Vector3] = []
	for k in range(4):
		var a: float = TAU * k / 4.0 + PI * 0.25
		legs.append(o + Vector3(cos(a) * 10.5, 0, sin(a) * 10.5))
		geo.beam(legs[k], o + Vector3(cos(a) * 9.0, 35.2, sin(a) * 9.0), Vector2(0.9, 0.9), "paint")
	for pair in [[0, 3], [1, 2]]:
		var a: Vector3 = legs[pair[0]]
		var b: Vector3 = legs[pair[1]]
		for band in [[0.0, 17.0], [17.0, 34.0]]:
			var t0: float = band[0] / 35.2
			var t1: float = band[1] / 35.2
			var pa0: Vector3 = a.lerp(o + (a - o) * 0.857 + Vector3(0, 35.2, 0), t0)
			var pa1: Vector3 = a.lerp(o + (a - o) * 0.857 + Vector3(0, 35.2, 0), t1)
			var pb0: Vector3 = b.lerp(o + (b - o) * 0.857 + Vector3(0, 35.2, 0), t0)
			var pb1: Vector3 = b.lerp(o + (b - o) * 0.857 + Vector3(0, 35.2, 0), t1)
			geo.beam(pa0, pb1, Vector2(0.35, 0.35), "rust_dark")
			geo.beam(pb0, pa1, Vector2(0.35, 0.35), "rust_dark")
	for y in [12.0, 24.0]:
		geo.lathe(o + Vector3(0, y, 0), [Vector2(10.2, 0), Vector2(10.2, 0.3)], "rust_dark", 24, 1.6)
	# Bustle pipe and tuyere stocks.
	geo.lathe(o + Vector3(0, 13.4, 0), [Vector2(9.4, 0), Vector2(9.4, 1.3)], "rust", 24, 1.3)
	for k in range(10):
		var a: float = TAU * k / 10.0
		geo.beam(o + Vector3(cos(a) * 8.6, 13.6, sin(a) * 8.6), o + Vector3(cos(a) * 7.0, 9.5, sin(a) * 7.0), Vector2(0.35, 0.35), "rust_dark")
	_stair_tower(o + Vector3(-12.5, 0, 6.0), 35.0)
	# Downcomer to the dust catcher south-east.
	var dc := Vector3(FX[i] + 18.0, 0, FZ + 12.0)
	geo.cylinder(o + Vector3(2.0, 48.6, 1.0), dc + Vector3(0, 27.0, 0), 1.0, "rust", 12)
	geo.cylinder(dc + Vector3(0, 12, 0), dc + Vector3(0, 24, 0), 4.0, "rust", 18)
	geo.cone(dc + Vector3(0, 12, 0), dc + Vector3(0, 6, 0), 4.0, 0.7, "rust_dark", 18)
	geo.cone(dc + Vector3(0, 24, 0), dc + Vector3(0, 27, 0), 4.0, 1.1, "rust_dark", 18)
	for k in range(4):
		var a: float = TAU * k / 4.0
		geo.beam(dc + Vector3(cos(a) * 3.4, 0, sin(a) * 3.4), dc + Vector3(cos(a) * 3.4, 14, sin(a) * 3.4), Vector2(0.6, 0.6), "paint")
	# Skip hoist: the inclined truss from the pit up to the top.
	_truss(Vector3(FX[i], 2.5, MOLLER.end.y + 3.5), o + Vector3(0, 41.5, -4.5), 3.2, 2.6, "paint")
	# Cast house over the iron line: an open shed, the tapping runner
	# from the furnace out to the ladle cars.
	var ch := Vector3(FX[i], 0, IRON_Z)
	for dx in [-9.0, 9.0]:
		for dz in [-7.0, 7.0]:
			geo.box(ch + Vector3(dx, 5.0, dz), Vector3(0.7, 10.0, 0.7), "paint")
	geo.box(ch + Vector3(0, 10.3, 0), Vector3(19.0, 0.4, 15.0), "corrugated")
	geo.box(ch + Vector3(0, 11.4, 0), Vector3(6.0, 2.0, 15.0), "corrugated") # roof lantern
	geo.box(Vector3(FX[i] - 4.0, 1.0, FZ + 13.0), Vector3(1.6, 2.0, 9.0), "concrete")

func _stair_tower(o: Vector3, h: float) -> void:
	for dx in [-1.5, 1.5]:
		for dz in [-1.5, 1.5]:
			geo.box(o + Vector3(dx, h * 0.5, dz), Vector3(0.3, h, 0.3), "paint")
	for y in range(4, int(h), 4):
		geo.box(o + Vector3(0, y, 0), Vector3(3.3, 0.15, 3.3), "rust_dark", 0.0, true, false)

# --- gas and blast ------------------------------------------------------------------

## The clean-gas main: from every dust catcher up to a 2.8 m main on
## trestles 30 m up along the row, then north-east to the gas holder.
## Hollow, with open joints between sections - fly in.
func _gas() -> void:
	var y: float = 30.0
	var z: float = FZ + 12.0
	for i in range(FX.size()):
		geo.cylinder(Vector3(FX[i] + 18.0, 27.0, z), Vector3(FX[i] + 18.0, y - 1.2, z), 0.9, "rust", 10)
	var posts: Array[float] = []
	for fx in FX:
		posts.append(fx + 9.0)
	posts.append(150.0)
	geo.box(Vector3(FX[0] + 18.0, y, z), Vector3(1.0, 1.0, 1.0), "rust_dark")
	var xs: Array[float] = [FX[0] + 15.0]
	xs.append_array(posts)
	for k in range(xs.size() - 1):
		geo.pipe(Vector3(xs[k] + 0.9, y, z), Vector3(xs[k + 1] - 0.9, y, z), 1.4, 0.15, "rust", 16)
	for px in posts:
		geo.box(Vector3(px, (y - 1.5) * 0.5, z), Vector3(0.8, y - 1.5, 0.8), "paint")
		geo.box(Vector3(px, y - 1.6, z), Vector3(1.2, 0.3, 4.0), "paint", 0.0, true, false)
	var tail := Route.new()
	tail.pts = Route.rounded([Vector3(150.0, y, z), Vector3(156.0, y, z), Vector3(156.0, y, -20.0), Vector3(186.0, y, -20.0), Vector3(186.0, y, -40.0)], 5.0, 6)
	geo.pipe_path(tail.pts, 1.4, "rust", 0.15, 16)
	for q in [Vector3(156, 0, 20), Vector3(156, 0, -12), Vector3(176, 0, -20)]:
		geo.box(Vector3(q.x, (y - 1.5) * 0.5, q.z), Vector3(0.8, y - 1.5, 0.8), "paint")
	# Gas holder: a 36 m drum in its guide frame.
	var gh := Vector3(205, 0, -48)
	geo.lathe(gh, [Vector2(17, 0), Vector2(17, 34), Vector2(14, 37), Vector2(0.2, 39)], "paint", 32)
	for k in range(14):
		var a: float = TAU * k / 14.0
		geo.beam(gh + Vector3(cos(a) * 18.5, 0, sin(a) * 18.5), gh + Vector3(cos(a) * 18.5, 41, sin(a) * 18.5), Vector2(0.7, 0.7), "rust_dark")
	for y2 in [13.0, 26.0, 39.0]:
		geo.lathe(gh + Vector3(0, y2, 0), [Vector2(19.2, 0), Vector2(19.2, 0.9)], "rust_dark", 32, 1.1)

## Cowper stoves: three domed towers per furnace in one long row south
## of the iron line; the hot-blast main along them, a hot-blast pipe from
## each group north over the cast house to its furnace's bustle pipe;
## the cold-blast main from the blower hall along the back.
func _stoves() -> void:
	for i in range(FX.size()):
		for k in [-1, 0, 1]:
			var s := Vector3(FX[i] + k * 11.0, 0, STOVE_Z)
			geo.lathe(s, [Vector2(4.2, 0), Vector2(4.2, 28), Vector2(3.6, 31), Vector2(2.2, 33), Vector2(0.1, 33.8)], "paint", 20)
			geo.lathe(s + Vector3(0, 28, 0), [Vector2(5.0, 0), Vector2(5.0, 0.3)], "rust_dark", 20, 1.0)
			geo.cylinder(s + Vector3(0, 15, -4.0), s + Vector3(0, 15, -6.0), 0.8, "rust", 10)
		geo.pipe(Vector3(FX[i] - 13.0, 15, STOVE_Z - 6.4), Vector3(FX[i] + 13.0, 15, STOVE_Z - 6.4), 1.1, 0.12, "rust", 14)
		var hb := Route.new()
		hb.pts = Route.rounded([Vector3(FX[i] + 6.0, 15, STOVE_Z - 6.4), Vector3(FX[i] + 6.0, 15, FZ + 11.5), Vector3(FX[i] + 4.0, 14.0, FZ + 8.6)], 3.0, 6)
		geo.pipe_path(hb.pts, 1.1, "rust", 0.12, 14)
		geo.box(Vector3(FX[i] + 6.0, 7.2, STOVE_Z - 12.0), Vector3(0.6, 14.4, 0.6), "paint")
	var cold := Route.new()
	cold.pts = Route.rounded([Vector3(-200, 9, 26), Vector3(-200, 9, 113), Vector3(FX[5] + 14.0, 9, 113)], 6.0, 6)
	geo.pipe_path(cold.pts, 1.3, "rust", 0.14, 14)
	var d: float = 12.0
	while d < cold.length() - 4.0:
		var q: Vector3 = cold.sample(d)[0]
		geo.box(Vector3(q.x, 3.9, q.z), Vector3(0.6, 7.8, 0.6), "paint")
		d += 20.0

## The blower hall (Gebläsehalle): a long brick hall of gas-engine
## blowers - huge flywheels in a row - big windows, many broken.
func _blower_hall() -> void:
	var c := Vector3(-200, 0, 10)
	_hall(c, Vector3(70, 18, 30), "brick", {"e": [[0.0, 10.0, 9.0]], "w": [[0.0, 8.0, 8.0]], "s": [[0.0, 6.0, 6.0]]}, 0.35)
	for k in range(5):
		var x: float = c.x - 26.0 + k * 13.0
		geo.box(Vector3(x, 1.5, c.z + 4.0), Vector3(9.0, 3.0, 4.0), "concrete")
		geo.cylinder(Vector3(x, 6.0, c.z - 6.2), Vector3(x, 6.0, c.z - 4.8), 5.0, "rust_dark", 20)
		geo.box(Vector3(x, 4.2, c.z - 1.0), Vector3(2.4, 2.4, 10.0), "paint")
	for dz in [-13.0, 13.0]:
		geo.beam(Vector3(c.x - 35, 15, c.z + dz), Vector3(c.x + 35, 15, c.z + dz), Vector2(0.7, 1.2), "paint")
	geo.box(Vector3(c.x + 10, 16.4, c.z), Vector3(4, 2.0, 26.5), "yellow") # travelling crane

# --- ore monorail and ore yard ---------------------------------------------------------

## The suspended ore monorail (Erzhängebahn): an I-beam track on
## A-frames from the ore yard round to the Möllerhalle and along its
## deck, buckets hanging where they stopped. Chase it at 24 m.
func _monorail() -> void:
	var r := Route.new()
	r.pts = Route.rounded([Vector3(-300, 26, -160), Vector3(-300, 26, -52), Vector3(-152, 26, -52), Vector3(-128, 26, 1), Vector3(118, 26, 1)], 18.0, 10)
	geo.sweep(r.pts, [Vector2(0.25, -0.5), Vector2(0.25, 0.4), Vector2(-0.25, 0.4), Vector2(-0.25, -0.5)], "rust_dark", true)
	var d: float = 6.0
	var L: float = r.length()
	while d < L - 3.0:
		var q: Array = r.sample(d)
		var p: Vector3 = q[0]
		var t: Vector3 = q[1]
		var side := Vector3(-t.z, 0, t.x).normalized()
		var foot_y: float = 22.3 if MOLLER.grow(2.0).has_point(Vector2(p.x, p.z)) else 0.0
		for s in [-1.0, 1.0]:
			geo.beam(p + side * s * 4.0 + Vector3(0, foot_y - p.y, 0), p + Vector3(0, 0.4, 0), Vector2(0.45, 0.45), "paint")
		geo.beam(p + side * 4.3 + Vector3(0, 0.6, 0), p - side * 4.3 + Vector3(0, 0.6, 0), Vector2(0.4, 0.4), "paint")
		d += 24.0
	d = 15.0
	while d < L - 8.0:
		var p2: Vector3 = r.sample(d)[0]
		geo.beam(p2 + Vector3(0, -0.5, 0), p2 + Vector3(0, -2.4, 0), Vector2(0.12, 0.12), "rust_dark", false)
		geo.frustum(Transform3D(Basis(Vector3.UP, rng.randf()), p2 + Vector3(0, -3.3, 0)), Vector3(1.0, 1.6, 1.0), 1.7, 1.7, 0.0, "rust")
		d += rng.randf_range(22.0, 40.0)

func _pile(c: Vector3, r: float, h: float, mat: String) -> void:
	var prof: Array[Vector2] = [Vector2(r, 0.0), Vector2(r * 0.7, h * 0.55), Vector2(r * 0.3, h * 0.92), Vector2(0.05, h)]
	geo.lathe(c, prof, mat, 16)

## The ore yard by the ore line: long piles of ore and coal between the
## ore bridge's runway rails, the bridge parked over them.
func _ore_yard() -> void:
	for k in range(3):
		_pile(Vector3(-292 + k * 30, 0, -150), 13, 8, "ore")
		_pile(Vector3(-280 + k * 30, 0, -108), 11, 7, "coal" if k != 1 else "ore")
	_pile(Vector3(-205, 0, -95), 9, 5, "ore")
	var bz: float = -128.0
	for x in [-318.0, -186.0]:
		_track(Vector3(x, 0, -176), Vector3(x, 0, -72))
		for dz in [-6.0, 6.0]:
			geo.beam(Vector3(x, 0.5, bz + dz), Vector3(x, 32, bz), Vector2(1.2, 1.2), "paint")
	# (High enough for the monorail to pass underneath.)
	_truss(Vector3(-322, 34, bz), Vector3(-182, 34, bz), 4.0, 5.0, "paint")
	geo.box(Vector3(-262, 37.5, bz), Vector3(8, 3, 6), "paint")
	for dx in [-1.0, 1.0]:
		geo.beam(Vector3(-262 + dx, 36, bz), Vector3(-262 + dx, 15, bz), Vector2(0.08, 0.08), "rail", false)
	geo.cone(Vector3(-262, 15, bz), Vector3(-262, 12.5, bz), 1.8, 0.4, "rust_dark", 8)

## Crane runway track (the ore bridge's rails - they end at stops,
## like real crane runways).
func _track(a: Vector3, b: Vector3) -> void:
	var d: Vector3 = (b - a)
	var along: Vector3 = d.normalized()
	var side: Vector3 = along.cross(Vector3.UP).normalized()
	geo.beam(a + Vector3(0, 0.15, 0), b + Vector3(0, 0.15, 0), Vector2(3.2, 0.3), "ballast", true, false)
	for s in [-0.72, 0.72]:
		geo.beam(a + side * s + Vector3(0, 0.45, 0), b + side * s + Vector3(0, 0.45, 0), Vector2(0.08, 0.15), "rail", false, false)
	for e in [a, b]:
		geo.box(e + Vector3(0, 0.9, 0), Vector3(1.2, 1.2, 3.4) if absf(d.x) > absf(d.z) else Vector3(3.4, 1.2, 1.2), "yellow")

# --- coking, sinter, east works -----------------------------------------------------

func _coke_plant() -> void:
	var c := Vector3(220, 0, -140)
	geo.box(c + Vector3(0, 6, 0), Vector3(110, 12, 14), "brick")
	geo.box(c + Vector3(0, 12.3, 0), Vector3(112, 0.6, 16), "concrete")
	for k in range(28):
		var x: float = c.x - 52 + k * 3.8
		geo.cylinder(Vector3(x, 12.6, c.z - 5.5), Vector3(x, 16.5, c.z - 5.5), 0.35, "rust", 8)
		geo.box(Vector3(x, 6, c.z + 7.1), Vector3(1.4, 10, 0.3), "rust_dark")
	geo.beam(c + Vector3(-55, 16.8, -5.5), c + Vector3(55, 16.8, -5.5), Vector2(1.2, 1.2), "rust")
	geo.box(c + Vector3(20, 14.6, 0), Vector3(8, 4, 6), "yellow") # larry car, on the deck
	geo.box(Vector3(292, 17, -140), Vector3(14, 34, 14), "concrete") # coal tower
	_gallery(Vector3(292, 30, -130), Vector3(310, 4, -60), 3.4)
	_open_tower(Vector3(178, 0, -102), Vector2(12, 12), 34.0, "concrete") # quench tower
	_chimney(Vector3(230, 0, -178), 75.0, 4.5, "brick")

func _sinter_plant() -> void:
	var c := Vector3(-50, 0, -146)
	_hall(c, Vector3(110, 26, 40), "corrugated", {"s": [[-30.0, 12.0, 10.0], [30.0, 12.0, 10.0]], "e": [[0.0, 10.0, 9.0]]}, 0.3)
	_chimney(Vector3(-118, 0, -170), 62.0, 3.5, "concrete")
	# Sinter to the Möllerhalle deck: two enclosed conveyor galleries.
	for x in [-80.0, -20.0]:
		_gallery(Vector3(x, 22, -126), Vector3(x + 10.0, 17.5, -14), 3.4)

## Gas cleaning and power house with its chimneys, next to the holder.
func _east_works() -> void:
	_hall(Vector3(195, 0, 22), Vector3(56, 20, 28), "brick", {"w": [[0.0, 8.0, 8.0]], "n": [[10.0, 8.0, 8.0]]}, 0.25)
	_chimney(Vector3(238, 0, 8), 70.0, 4.0, "brick")
	_chimney(Vector3(238, 0, 34), 58.0, 3.5, "concrete")

# --- the Paradies, decay, forest -------------------------------------------------------

## The south-west corner where the works were left to nature: roofless
## concrete ruins, an old bunker frame to fly through, birch woods.
func _paradies() -> void:
	var trees: Array = []
	for k in range(90):
		var p := Vector3(rng.randf_range(-330, -220), 0.05, rng.randf_range(40, 150))
		trees.append([p, 1, rng.randf_range(0.6, 1.0)])
	for k in range(5):
		var c := Vector3(-300 + k * 22, 0, 60 + (k % 2) * 50)
		var w: float = rng.randf_range(10, 16)
		for s in [-1.0, 1.0]:
			geo.box(c + Vector3(s * w * 0.5, 2.5, 0), Vector3(0.5, rng.randf_range(2.0, 6.0), w), "concrete")
		geo.box(c + Vector3(0, 1.5, -w * 0.5), Vector3(w, 3.0, 0.5), "concrete")
	# The old coal bunker: a concrete frame on legs, open all round.
	var b := Vector3(-262, 0, 118)
	for dx in [-8.0, 8.0]:
		for dz in [-6.0, 6.0]:
			geo.box(b + Vector3(dx, 7.75, dz), Vector3(1.2, 15.5, 1.2), "concrete") # up to the top frame
	for y in [10.0, 15.0]:
		for s in [-1.0, 1.0]:
			geo.box(b + Vector3(0, y, s * 6.0), Vector3(17.2, 1.0, 1.0), "concrete")
			geo.box(b + Vector3(s * 8.0, y, 0), Vector3(1.0, 1.0, 13.2), "concrete")
	Forest.plant(self, trees)

func _decay() -> void:
	Vehicles.ensure_materials(geo)
	Vehicles.semi(geo, Vector3(-130, 0.1, 150), 0.2, "veh_rust", "rust")
	Vehicles.semi(geo, Vector3(265, 0.1, -60), 1.4, "veh_rust", "rust")
	for k in range(26):
		var q := Vector3(rng.randf_range(-320, 320), 0.1, rng.randf_range(-185, 150))
		var sc: float = rng.randf_range(2, 5)
		if geo.blocked(Vector2(q.x, q.z), sc, 0.3, 4.0) or geo.on_lane(Vector2(q.x, q.z), sc + 1.0):
			continue
		geo.lathe(q, [Vector2(sc, 0), Vector2(sc * 0.5, sc * 0.4), Vector2(0.1, sc * 0.55)], ["slag", "rust_dark", "concrete"][rng.randi() % 3], 7)
		for k2 in range(rng.randi_range(0, 4)):
			geo.cylinder(q + Vector3(sc + k2 * 0.7, 0, 1.0), q + Vector3(sc + k2 * 0.7, 0.9, 1.0), 0.3, "rust", 8)
	# Young trees inside the works, wherever they found ground.
	var trees: Array = []
	for k in range(160):
		trees.append([Vector3(rng.randf_range(-330, 330), 0.05, rng.randf_range(-190, 205)), 1, rng.randf_range(0.5, 0.8)])
	Forest.plant(self, trees)

func _forest() -> void:
	var trees: Array = []
	var frng := RandomNumberGenerator.new()
	frng.seed = 4
	var attempts: int = 0
	while trees.size() < 4500 and attempts < 30000:
		attempts += 1
		var x: float = frng.randf_range(-1250, 1250)
		var z: float = frng.randf_range(-880, 680)
		if SITE.grow(10.0).has_point(Vector2(x, z)) or TOWN.grow(12.0).has_point(Vector2(x, z)):
			continue
		if z > 232.0 and z < 335.0:
			continue # the river
		if absf(z + 255.0) < 8.0 or absf(z - MAIN_Z) < 14.0 or absf(z - 214.0) < 8.0 or absf(z + 200.0) < 8.0:
			continue # town street, railway, roads
		trees.append([Vector3(x, _height(x, z) - 0.2, z), 0 if frng.randf() < 0.55 else 1, frng.randf_range(0.9, 1.5)])
	Forest.plant(self, trees)

# --- shared builders ------------------------------------------------------------

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
