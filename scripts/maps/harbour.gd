extends BuiltMap

## Harbour - a port city's whole freight-and-rail system (High
## performance), laid out the way the goods move (north = -z, sea +z):
##   container ships at the quay -> ship-to-shore cranes -> container
##   stacks -> intermodal rail terminal (8 loading tracks under two
##   rail-mounted gantry cranes) -> marshalling yard (hump, 16 sorting
##   tracks, locomotive depot, signal gantries) -> four-track main line
##   west -> the central station: a 250 m train shed of three arched
##   bays over 8 platform tracks, station building with clock tower,
##   the city round it, road bridges over the rail corridor.
## Real sizes: ISO containers 12.2 x 2.44 x 2.59 m, standard gauge
## 1.435 m, 4.5 m track centres, ~25 m coaches, STS cranes ~50 m to the
## boom. FPV lines: container aisles, crane legs and booms, under the
## road bridges, straight down the train shed between the trains, over
## the yard's wagon rows, round the lighthouse.

const QUAY_Z: float = 0.0
const WATER_Y: float = -3.0
const CONT := Vector3(12.2, 2.59, 2.44)

var rng := RandomNumberGenerator.new()
var _colors: Array[String] = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-35, 30, 0), "sun_color": Color(1.0, 0.94, 0.84), "fog_density": 0.00025, "aerial": 0.08,
		"sky_top": Color(0.32, 0.52, 0.8), "sky_horizon": Color(0.78, 0.84, 0.9),
		"ground_horizon": Color(0.3, 0.45, 0.55), "ground_bottom": Color(0.12, 0.25, 0.32),
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-1150, -760, 1760, 1000)}

func border() -> Array:
	return [1250.0, 1400.0, 220.0, 280.0]

func preview_views() -> Array:
	return [
		["overview", Vector3(-160, 70, 120), Vector3(0, 0, -40)],
		["cranes", Vector3(-80, 20, 30), Vector3(40, 30, 0)],
		["stacks", Vector3(-40, 4, -60), Vector3(40, 3, -60)],
		["ship", Vector3(-120, 8, 40), Vector3(0, 10, 32)],
		["lighthouse", Vector3(150, 20, 190), Vector3(200, 15, 230)],
		["rail_terminal", Vector3(-160, 30, -300), Vector3(0, 5, -370)],
		["yard", Vector3(600, 45, -420), Vector3(100, 0, -510)],
		["station_shed", Vector3(-790, 9, -327), Vector3(-1060, 8, -327)],
		["station_outside", Vector3(-700, 60, -180), Vector3(-930, 10, -330)],
	]

func build() -> void:
	rng.seed = 2024
	geo.ao_height = 2.5
	geo.add_material("paving", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.9, 0.9, 0.88), 8.0))
	geo.add_material("quay", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color.WHITE, 5.0))
	geo.add_material("water", Geo.water_mat(Color(0.1, 0.28, 0.36)))
	geo.add_material("crane", Geo.flat_mat(Color(0.2, 0.42, 0.72)))
	geo.add_material("crane_red", Geo.flat_mat(Color(0.75, 0.2, 0.15)))
	geo.add_material("hull", Geo.flat_mat(Color(0.12, 0.14, 0.18)))
	geo.add_material("hull_red", Geo.flat_mat(Color(0.55, 0.14, 0.12)))
	geo.add_material("white", Geo.flat_mat(Color(0.92, 0.92, 0.9)))
	geo.add_material("glass", Geo.flat_mat(Color(0.1, 0.13, 0.16)))
	geo.add_material("rail", Geo.flat_mat(Color(0.35, 0.33, 0.3)))
	geo.add_material("warehouse", Geo.tex_mat(MapTextures.get_tex("corrugated_rust"), Color(0.8, 0.85, 0.9), 4.0))
	geo.add_material("rock", Geo.tex_mat(MapTextures.get_tex("rock"), Color(0.8, 0.78, 0.74), 4.0))
	geo.add_material("yellow", Geo.flat_mat(Color(0.95, 0.72, 0.1)))
	geo.add_material("line", Geo.flat_mat(Color(0.95, 0.85, 0.3)))
	var ctex: Texture2D = MapTextures.get_tex("corrugated_plain")
	for c in [["c_red", Color(0.72, 0.16, 0.12)], ["c_blue", Color(0.12, 0.3, 0.62)], ["c_green", Color(0.18, 0.45, 0.25)],
		["c_orange", Color(0.9, 0.45, 0.12)], ["c_grey", Color(0.55, 0.56, 0.58)], ["c_white", Color(0.92, 0.92, 0.9)]]:
		geo.add_material(c[0], Geo.tex_mat(ctex, c[1], 2.44))
		_colors.append(c[0])

	geo.add_material("bed_x", Geo.tex_mat(MapTextures.get_tex("trackbed_x"), Color.WHITE, 1.2))
	geo.add_material("bed_z", Geo.tex_mat(MapTextures.get_tex("trackbed_z"), Color.WHITE, 1.2))
	geo.add_material("facade", Geo.tex_mat(MapTextures.get_tex("facade"), Color.WHITE, 3.5))
	geo.add_material("facade_dark", Geo.tex_mat(MapTextures.get_tex("facade"), Color(0.75, 0.72, 0.7), 3.5))
	geo.add_material("sandstone", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.25, 1.1, 0.85), 4.0))
	geo.add_material("asphalt", Geo.tex_mat(MapTextures.get_tex("cracked_asphalt"), Color.WHITE, 8.0))
	geo.add_material("grass", Geo.tex_mat(MapTextures.get_tex("meadow"), Color.WHITE, 10.0))
	geo.add_material("ice_white", Geo.flat_mat(Color(0.94, 0.94, 0.95)))
	geo.add_material("ice_red", Geo.flat_mat(Color(0.8, 0.1, 0.12)))
	geo.add_material("loco_red", Geo.flat_mat(Color(0.7, 0.12, 0.1)))
	geo.add_material("wagon_brown", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.45, 0.28, 0.2), 2.0))
	geo.add_material("tank_black", Geo.flat_mat(Color(0.16, 0.16, 0.17)))
	geo.add_material("tank_white", Geo.flat_mat(Color(0.82, 0.83, 0.84)))
	var shed_glass := Geo.flat_mat(Color(0.75, 0.85, 0.9, 0.35))
	shed_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	geo.add_material("shed_glass", shed_glass)

	geo.slab(Rect2(-3000, 0, 6000, 3000), WATER_Y, 0.3, "water")
	geo.slab(Rect2(-260, -300, 820, 300), 0.0, 5.0, "paving")       # terminal, 5 m quay wall
	geo.add_material("gravel", Geo.tex_mat(ProceduralTextures.gravel_texture(), Color(0.62, 0.6, 0.57), 3.0))
	geo.slab(Rect2(-1250, -760, 1850, 460), 0.0, 5.0, "gravel")      # rail lands
	geo.slab(Rect2(-3000, -3000, 6000, 3000), -0.1, 1.0, "grass")    # hinterland to the horizon
	geo.slab(Rect2(-3000, -300, 2740, 300), 0.0, 5.0, "paving")      # west waterfront
	geo.box(Vector3(0, -2.5, 0.2), Vector3(520, 5.4, 0.4), "quay", 0.0, true, false)
	for x in range(-250, 251, 12):
		geo.cylinder(Vector3(x, 0, 1.0), Vector3(x, 0.6, 1.0), 0.25, "rail", 8) # bollards
	for dz in [-3.0, -33.0]:
		geo.box(Vector3(0, 0.08, dz), Vector3(520, 0.08, 0.3), "rail", 0.0, false, false) # crane rails
	for i in range(3):
		_sts_crane(Vector3(-90 + i * 70, 0, -18), i == 1)
	_ship(Vector3(-10, 0, 34))
	for bx in range(4):
		for bz in range(3):
			_stack_block(Vector3(-150 + bx * 75, 0, -70 - bz * 45))
	_warehouse(Vector3(420, 0, -150))
	_ship2(Vector3(420, 0, 30))
	_rail_terminal()
	_yard()
	_main_line()
	_station()
	_city()
	_breakwater()
	for p in [Vector3(120, 0, 60), Vector3(150, 0, 90)]:
		_tug(p)

# --- rail ---------------------------------------------------------------------

## Track along x or z (axis-aligned; sleepers are in the bed texture)
## or angled (fans, crossovers).
func _track(a: Vector3, b: Vector3) -> void:
	var d: Vector3 = b - a
	var along_x: bool = absf(d.x) >= absf(d.z)
	geo.beam(a + Vector3(0, 0.12, 0), b + Vector3(0, 0.12, 0), Vector2(3.0, 0.24), "bed_x" if along_x else "bed_z", true, false)
	var side: Vector3 = d.normalized().cross(Vector3.UP)
	for s in [-0.72, 0.72]:
		geo.beam(a + side * s + Vector3(0, 0.32, 0), b + side * s + Vector3(0, 0.32, 0), Vector2(0.08, 0.16), "rail", false, false)

## A train standing on a track along x: a list of wagon kinds from x0.
func _train(x0: float, z: float, kinds: Array) -> void:
	var x: float = x0
	for k in kinds:
		var length: float = {"flat": 19.6, "tank": 15.0, "box": 16.5, "hopper": 13.0, "loco": 19.0, "ice_head": 21.0, "ice": 25.5}[k]
		_wagon(Vector3(x + length * 0.5, 0, z), k, length)
		x += length + 0.8

func _wagon(c: Vector3, kind: String, length: float) -> void:
	var y0: float = 0.45
	for dx in [-length * 0.5 + 2.5, length * 0.5 - 2.5]:
		geo.box(c + Vector3(dx, y0 + 0.5, 0), Vector3(2.8, 0.9, 2.3), "rail")
	match kind:
		"flat":
			geo.box(c + Vector3(0, y0 + 1.1, 0), Vector3(length, 0.3, 2.8), "rail")
			var n: int = rng.randi_range(0, 2) if length > 13 else 1
			for i in range(n):
				geo.box(c + Vector3(-CONT.x * 0.5 * (n - 1) + i * (CONT.x + 0.3), y0 + 1.25 + CONT.y * 0.5, 0), CONT, _colors[rng.randi() % _colors.size()])
		"tank":
			geo.box(c + Vector3(0, y0 + 1.1, 0), Vector3(length, 0.3, 2.6), "rail")
			var m: String = "tank_black" if rng.randf() < 0.6 else "tank_white"
			geo.cylinder(c + Vector3(-length * 0.5 + 0.8, y0 + 2.8, 0), c + Vector3(length * 0.5 - 0.8, y0 + 2.8, 0), 1.45, m, 14)
		"box":
			geo.box(c + Vector3(0, y0 + 2.8, 0), Vector3(length, 3.6, 2.9), "wagon_brown")
		"hopper":
			geo.box(c + Vector3(0, y0 + 2.6, 0), Vector3(length, 3.2, 3.0), "c_grey")
		"loco":
			geo.box(c + Vector3(0, y0 + 2.3, 0), Vector3(length, 3.0, 3.0), "loco_red")
			geo.box(c + Vector3(length * 0.5 - 1.2, y0 + 3.0, 0), Vector3(0.6, 1.0, 2.6), "glass", 0.0, false, false)
		"ice_head":
			geo.box(c + Vector3(-2.0, y0 + 2.4, 0), Vector3(length - 4.0, 3.4, 2.95), "ice_white")
			geo.cone(c + Vector3(length * 0.5 - 4.0, y0 + 2.3, 0), c + Vector3(length * 0.5, y0 + 1.6, 0), 1.7, 0.4, "ice_white", 8)
			geo.box(c + Vector3(-2.0, y0 + 1.25, 0), Vector3(length - 4.0, 0.3, 3.0), "ice_red", 0.0, false, false)
			geo.box(c + Vector3(length * 0.5 - 4.5, y0 + 3.3, 0), Vector3(1.4, 0.8, 2.97), "glass", 0.0, false, false)
		"ice":
			geo.box(c + Vector3(0, y0 + 2.4, 0), Vector3(length, 3.4, 2.95), "ice_white")
			geo.box(c + Vector3(0, y0 + 2.9, 0), Vector3(length - 2.0, 0.9, 2.97), "glass", 0.0, false, false)
			geo.box(c + Vector3(0, y0 + 1.25, 0), Vector3(length, 0.3, 3.0), "ice_red", 0.0, false, false)

## Intermodal terminal: 8 loading tracks, two rail-mounted gantry
## cranes spanning them, container trains being loaded.
func _rail_terminal() -> void:
	for i in range(8):
		var z: float = -335.0 - i * 5.0
		_track(Vector3(-420, 0, z), Vector3(420, 0, z))
		if i in [0, 2, 3, 5, 7]:
			var kinds: Array = ["loco"]
			for w in range(rng.randi_range(12, 22)):
				kinds.append("flat")
			_train(-380 + rng.randf_range(0, 60), z, kinds)
	for x in [-120.0, 170.0]:
		for z in [-322.0, -383.0]:
			for dx in [-8.0, 8.0]:
				geo.box(Vector3(x + dx, 14, z), Vector3(1.4, 28, 1.4), "yellow")
			geo.box(Vector3(x, 1.0, z), Vector3(20, 2.0, 3), "yellow")
		for dx in [-7.0, 7.0]:
			geo.box(Vector3(x + dx, 29, -352.5), Vector3(1.8, 2.6, 66), "yellow")
		geo.box(Vector3(x, 31, -345), Vector3(16, 3, 6), "crane_red")
		geo.beam(Vector3(x, 30, -345), Vector3(x, 8, -345), Vector2(0.15, 0.15), "rail", false)
		geo.box(Vector3(x, 7.5, -345), Vector3(12.4, 0.6, 2.6), "yellow") # spreader
	# Fans of track from the terminal west to the main line.
	for i in range(8):
		_track(Vector3(-420, 0, -335.0 - i * 5.0), Vector3(-520, 0, -345.0 - (i % 4) * 5.0))

## Marshalling yard: hump in the east, 16 sorting tracks, loco depot.
func _yard() -> void:
	for i in range(16):
		var z: float = -440.0 - i * 5.0
		_track(Vector3(-420, 0, z), Vector3(440, 0, z))
		if rng.randf() < 0.8:
			var kinds: Array = []
			for w in range(rng.randi_range(8, 30)):
				kinds.append(["tank", "box", "hopper", "flat", "box", "tank"][rng.randi() % 6])
			_train(rng.randf_range(-400, 100), z, kinds)
		_track(Vector3(440, 0, z), Vector3(520, 0, -477.5))
	# The hump: an embankment the wagons roll down into the yard, with
	# the control tower beside it.
	geo.beam(Vector3(520, 0, -477.5), Vector3(640, 4.5, -477.5), Vector2(12, 0.2), "grass")
	geo.box(Vector3(580, 2.2, -477.5), Vector3(120, 4.4, 10), "grass")
	_track(Vector3(520, 4.5, -477.5), Vector3(640, 4.5, -477.5))
	geo.box(Vector3(560, 9, -505), Vector3(8, 18, 8), "facade")
	geo.box(Vector3(560, 19.5, -505), Vector3(10, 3, 10), "glass")
	geo.box(Vector3(560, 21.3, -505), Vector3(11, 0.6, 11), "white")
	for x in [-350.0, -100.0, 150.0, 400.0]:
		_floodlight(Vector3(x, 0, -436))
		_floodlight(Vector3(x, 0, -522))
	for x in [-300.0, 50.0, 350.0]:
		_floodlight(Vector3(x, 0, -392))
	_catenary(-420, 440, -434, -522, [])
	# Signal gantries across the yard.
	for x in [-300.0, 0.0, 300.0]:
		for z in [-432.0, -522.0]:
			geo.box(Vector3(x, 5, z), Vector3(0.6, 10, 0.6), "rail")
		geo.box(Vector3(x, 10, -477), Vector3(0.6, 0.8, 90), "rail")
	# Locomotive depot: a shed with four tracks and locos inside.
	var dz: float = -600.0
	for i in range(4):
		_track(Vector3(-420, 0, dz + i * 6.0), Vector3(-160, 0, dz + i * 6.0))
		_train(-300 + rng.randf_range(0, 40), dz + i * 6.0, ["loco", "loco"])
	geo.box(Vector3(-270, 5.5, dz - 5.0), Vector3(120, 11, 0.4), "wagon_brown")
	geo.box(Vector3(-270, 5.5, dz + 23.0), Vector3(120, 11, 0.4), "wagon_brown")
	geo.box(Vector3(-270, 11.2, dz + 9.0), Vector3(120, 0.4, 28.4), "wagon_brown")
	for i in range(3):
		geo.box(Vector3(-270, 11.6, dz + 1.0 + i * 8.0), Vector3(118, 0.6, 2.0), "shed_glass", 0.0, false, false)

## Four-track main line west to the station, crossed by two road bridges.
func _main_line() -> void:
	_catenary(-790, -520, -312, -378, [])
	_catenary(-1060, -800, -294, -384, [])
	# Freight depot and warehouses between the station and the yard.
	for i in range(4):
		var c := Vector3(-760 + i * 80, 0, -560)
		geo.box(c + Vector3(0, 6, 0), Vector3(60, 12, 36), "warehouse")
		for k in range(4):
			geo.box(c + Vector3(-22 + k * 14, 3, 18.1), Vector3(8, 6, 0.2), "glass", 0.0, false, false)
	for i in range(3):
		_track(Vector3(-780, 0, -535.0 + i * 5.0), Vector3(-420, 0, -535.0 + i * 5.0))
		_train(-760 + rng.randf_range(0, 80), -535.0 + i * 5.0, ["loco", "box", "box", "box", "tank", "tank", "box", "box"])
	for p in [Vector3(-760, 0, -660), Vector3(-560, 0, -700)]:
		geo.slab(Rect2(p.x, p.z, 120, 50), 0.06, 0.1, "asphalt")
		for k in range(24):
			_parked_truck(p + Vector3(8 + (k % 8) * 14, 0, 10 + (k / 8) * 16))
	for i in range(4):
		var z: float = -345.0 - i * 5.0
		_track(Vector3(-520, 0, z), Vector3(-790, 0, -318.0 - i * 9.0 * 2.0 + (0.0 if i < 2 else 0.0)))
	for i in range(16):
		_track(Vector3(-420, 0, -440.0 - i * 5.0), Vector3(-520, 0, -360.0))
	for x in [-620.0, -700.0]:
		geo.box(Vector3(x, 8.5, -350), Vector3(14, 0.8, 190), "quay")        # deck
		for z in [-255.0, -445.0]:
			geo.box(Vector3(x, 4.2, z), Vector3(14, 8.4, 6), "quay")
		for z in [-300.0, -400.0]:
			geo.box(Vector3(x, 4.2, z), Vector3(2, 8.4, 2), "quay")           # piers between tracks
		for sx in [-6.8, 6.8]:
			geo.box(Vector3(x + sx, 9.5, -350), Vector3(0.3, 1.2, 190), "rail")

## Overhead line: a mast every 50 m each side of a track group, a
## cross beam over it, and the contact wires along each track.
func _catenary(x0: float, x1: float, z0: float, z1: float, tracks: Array) -> void:
	var n: int = int((x1 - x0) / 50.0)
	for k in range(n + 1):
		var x: float = x0 + k * (x1 - x0) / n
		for z in [z0, z1]:
			geo.box(Vector3(x, 4.2, z), Vector3(0.4, 8.4, 0.4), "rail")
		geo.box(Vector3(x, 8.0, (z0 + z1) * 0.5), Vector3(0.3, 0.3, absf(z1 - z0)), "rail")
	for z in tracks:
		geo.box(Vector3((x0 + x1) * 0.5, 6.1, z), Vector3(x1 - x0, 0.04, 0.04), "rail", 0.0, false, false)

## A floodlight tower: a 30 m mast with a lamp head.
func _floodlight(p: Vector3) -> void:
	geo.cylinder(p, p + Vector3(0, 30, 0), 0.35, "rail", 8)
	geo.box(p + Vector3(0, 30.5, 0), Vector3(4, 1.4, 1.2), "white")

## Central station: 8 platform tracks under a three-bay arched shed.
func _station() -> void:
	var x0: float = -1060.0
	var x1: float = -800.0
	var tz: Array[float] = []
	for i in range(8):
		tz.append(-300.0 - i * 9.0 - (i / 2) * 0.0)
	for i in range(8):
		_track(Vector3(x0 - 60, 0, tz[i]), Vector3(x1, 0, tz[i]))
		_track(Vector3(x1, 0, tz[i]), Vector3(-790, 0, -318.0 - (i / 2) * 18.0))
	# Platforms between track pairs: 0.76 m high, with benches and lamps.
	for i in range(0, 8, 2):
		var pz: float = (tz[i] + tz[i + 1]) * 0.5
		geo.box(Vector3((x0 + x1) * 0.5, 0.38, pz), Vector3(x1 - x0, 0.76, 4.5), "paving")
		for k in range(10):
			var px: float = x0 + 15 + k * 24
			geo.box(Vector3(px, 2.3, pz), Vector3(0.15, 3.0, 0.15), "rail")
			geo.box(Vector3(px, 3.8, pz), Vector3(1.6, 0.2, 0.5), "white")
	# Trains in the station: long white intercity sets.
	for i in [0, 3, 4, 7]:
		var kinds: Array = ["ice_head"]
		for c in range(8):
			kinds.append("ice")
		kinds.append("ice_head")
		_train(x0 + 5, tz[i], kinds)
	# The shed: three barrel vaults side by side, steel ribs every 12 m,
	# glass between; open at both ends.
	var zs: Array[float] = [-294.0, -324.0, -354.0, -384.0]
	for bay in range(3):
		var za: float = zs[bay]
		var zb: float = zs[bay + 1]
		var zc: float = (za + zb) * 0.5
		var r: float = (za - zb) * 0.5
		var spring: float = 12.0
		var n: int = int((x1 - x0) / 12.0)
		for k in range(n + 1):
			var x: float = x0 + k * (x1 - x0) / n
			var prev := Vector3(x, spring, za)
			for seg in range(1, 13):
				var a: float = PI * seg / 12.0
				var p := Vector3(x, spring + sin(a) * r * 0.75, zc + cos(a) * r)
				geo.beam(prev, p, Vector2(0.4, 0.8), "crane")
				prev = p
		for seg in range(12):
			var a0: float = PI * seg / 12.0
			var a1: float = PI * (seg + 1) / 12.0
			var p0 := Vector3((x0 + x1) * 0.5, spring + sin(a0) * r * 0.75, zc + cos(a0) * r)
			var p1 := Vector3((x0 + x1) * 0.5, spring + sin(a1) * r * 0.75, zc + cos(a1) * r)
			var mid: Vector3 = (p0 + p1) * 0.5
			var basis := Basis.looking_at((p1 - p0).normalized(), Vector3.RIGHT)
			geo.box_xf(Transform3D(basis, mid), Vector3(0.1, x1 - x0, p0.distance_to(p1)), "shed_glass" if seg % 3 != 0 else "white", true, false)
	for z in zs:
		for k in range(12):
			var x: float = x0 + k * (x1 - x0) / 11.0
			geo.box(Vector3(x, 6, z), Vector3(0.9, 12, 0.9), "crane")
		geo.box(Vector3((x0 + x1) * 0.5, 12.2, z), Vector3(x1 - x0, 0.8, 1.2), "crane")
	# Station building north of the shed, clock tower at the west end.
	var bz: float = -405.0
	geo.box(Vector3((x0 + x1) * 0.5, 9, bz), Vector3(x1 - x0, 18, 24), "sandstone")
	geo.box(Vector3((x0 + x1) * 0.5, 18.6, bz), Vector3(x1 - x0 + 2, 1.2, 26), "white")
	for k in range(8):
		geo.box(Vector3(x0 + 20 + k * 31, 8, bz - 12.1), Vector3(8, 10, 0.2), "glass", 0.0, false, false)
	var tower := Vector3(x0 + 20, 0, bz - 4)
	geo.box(tower + Vector3(0, 28, 0), Vector3(12, 56, 12), "sandstone")
	geo.cylinder(tower + Vector3(0, 46, -6.2), tower + Vector3(0, 46, -6.4), 3.5, "white", 20)
	geo.cone(tower + Vector3(0, 56, 0), tower + Vector3(0, 66, 0), 8.0, 0.3, "loco_red", 4)
	geo.slab(Rect2(x0, bz - 90, x1 - x0, 76), 0.06, 0.1, "asphalt") # station square

## City blocks round the station and behind the yard, and roads.
func _city() -> void:
	for i in range(70):
		var p := Vector2(rng.randf_range(-1250, 560), rng.randf_range(-980, -650))
		if i < 25:
			p = Vector2(rng.randf_range(-1250, -760), rng.randf_range(-640, -500))
		var h: float = rng.randf_range(12, 45)
		var w := Vector2(rng.randf_range(20, 45), rng.randf_range(20, 40))
		geo.box(Vector3(p.x, h * 0.5, p.y), Vector3(w.x, h, w.y), "facade" if i % 3 else "facade_dark")
		geo.box(Vector3(p.x, h + 0.3, p.y), Vector3(w.x + 0.6, 0.6, w.y + 0.6), "quay")
	for z in [-630.0, -1000.0]:
		geo.slab(Rect2(-1250, z, 1850, 14), 0.06, 0.1, "asphalt")
	for x in [-620.0, -700.0]:
		geo.slab(Rect2(x - 7, -1000, 14, 540), 0.06, 0.1, "asphalt")

func _parked_truck(p: Vector3) -> void:
	if rng.randf() < 0.3:
		return
	geo.box(p + Vector3(0, 1.8, 0), Vector3(2.5, 2.6, 12.2), _colors[rng.randi() % _colors.size()])
	geo.box(p + Vector3(0, 1.6, 7.2), Vector3(2.5, 3.0, 2.2), "white")

## A bulk carrier at the second berth.
func _ship2(o: Vector3) -> void:
	geo.box(o + Vector3(0, 2, 0), Vector3(190, 12, 30), "hull_red")
	for i in range(5):
		geo.box(o + Vector3(-60 + i * 28, 8.6, 0), Vector3(18, 1.2, 22), "hull")
	geo.box(o + Vector3(-85, 16, 0), Vector3(12, 16, 26), "white")
	geo.box(o + Vector3(-85, 22, 0), Vector3(12.2, 2.5, 30), "glass")

func _cont(c: Vector3, yaw: float = 0.0) -> void:
	geo.box(c + Vector3(0, CONT.y * 0.5, 0), CONT, _colors[rng.randi() % _colors.size()], yaw)

## Container block: 5 containers long (x), 6 rows (z), stacked 1-4
## high, with 1.5 m gaps between rows - wide enough to fly between.
func _stack_block(o: Vector3) -> void:
	for row in range(6):
		for col in range(4):
			var h: int = rng.randi_range(1, 4)
			if rng.randf() < 0.1:
				continue
			for lvl in range(h):
				_cont(o + Vector3(col * (CONT.x + 0.6), lvl * CONT.y, row * (CONT.z + 1.5)))

## Ship-to-shore crane: legs over the quay rails, a boom out over the
## ship, machinery house, stair tower. Rail gauge 30 m.
func _sts_crane(o: Vector3, boom_up: bool) -> void:
	for dx in [-9.0, 9.0]:
		for dz in [-15.0, 15.0]:
			geo.box(o + Vector3(dx, 20, dz), Vector3(1.5, 40, 1.5), "crane")
		geo.beam(o + Vector3(dx, 12, -15), o + Vector3(dx, 12, 15), Vector2(1.2, 1.5), "crane")
		geo.beam(o + Vector3(dx, 2, -15), o + Vector3(dx, 38, 15), Vector2(0.8, 0.8), "crane")
	for dz in [-15.0, 15.0]:
		geo.beam(o + Vector3(-9, 40, dz), o + Vector3(9, 40, dz), Vector2(1.5, 1.5), "crane")
	# Boom: out over the water (+z) and a back-reach over the land.
	var boom_end: Vector3 = o + (Vector3(0, 72, 45) if boom_up else Vector3(0, 42, 70))
	for dx in [-3.5, 3.5]:
		geo.beam(o + Vector3(dx, 42, -35), o + Vector3(dx, 42, 15), Vector2(1.0, 2.0), "crane")
		geo.beam(o + Vector3(dx, 42, 15), boom_end + Vector3(dx, 0, 0), Vector2(1.0, 2.0), "crane")
	# A-frame on top and the stays.
	geo.beam(o + Vector3(-5, 40, 0), o + Vector3(0, 60, 0), Vector2(1, 1), "crane")
	geo.beam(o + Vector3(5, 40, 0), o + Vector3(0, 60, 0), Vector2(1, 1), "crane")
	geo.beam(o + Vector3(0, 60, 0), boom_end, Vector2(0.3, 0.3), "rail")
	geo.beam(o + Vector3(0, 60, 0), o + Vector3(0, 42, -35), Vector2(0.3, 0.3), "rail")
	geo.box(o + Vector3(0, 45, -25), Vector3(10, 6, 12), "white")
	geo.box(o + Vector3(0, 40.5, 8), Vector3(4, 3, 4), "crane_red") # trolley + cab
	for w in range(4):
		geo.box(o + Vector3(-9 + (w % 2) * 18, 0.8, -15 + (w / 2) * 30), Vector3(3, 1.6, 6), "yellow")

## Container ship alongside: hull, bow, stern with the bridge, deck
## cargo in bays with gaps (the lashing bridges) between them.
func _ship(o: Vector3) -> void:
	var L: float = 230.0
	var B: float = 32.0
	geo.box(o + Vector3(0, 2, 0), Vector3(L, 12, B), "hull")
	geo.box(o + Vector3(0, -3.5, 0), Vector3(L, 1.5, B + 0.2), "hull_red", 0.0, false, false)
	geo.cone(o + Vector3(L * 0.5, 2, 0), o + Vector3(L * 0.5 + 18, 5, 0), B * 0.5, 2, "hull", 4)
	var bridge := o + Vector3(-L * 0.5 + 30, 8, 0)
	geo.box(bridge + Vector3(0, 12, 0), Vector3(14, 24, B - 4), "white")
	geo.box(bridge + Vector3(0, 22, 0), Vector3(14.2, 3, B + 6), "glass")
	geo.box(bridge + Vector3(-10, 14, 0), Vector3(5, 18, 5), "hull_red") # funnel
	for bay in range(10):
		var x: float = o.x - L * 0.5 + 55 + bay * 17
		for row in range(12):
			var h: int = rng.randi_range(2, 6)
			for lvl in range(h):
				var c := Vector3(x, 8 + lvl * CONT.y, o.z - B * 0.5 + 2 + row * CONT.z)
				geo.box(c + Vector3(0, CONT.y * 0.5, 0), CONT, _colors[rng.randi() % _colors.size()], 0.0, true, lvl == h - 1)

func _warehouse(o: Vector3) -> void:
	geo.box(o + Vector3(0, 7, 0), Vector3(80, 14, 40), "warehouse")
	for i in range(5):
		geo.box(o + Vector3(-32 + i * 16, 3, 20.05), Vector3(8, 6, 0.1), "glass", 0.0, false, false)

## A rock breakwater with a lighthouse at its head.
func _breakwater() -> void:
	for i in range(30):
		var p := Vector3(260 + i * 1.5, 0, 20 + i * 7.5)
		geo.box(p + Vector3(0, -1.0, 0), Vector3(12, 5, 9), "rock", rng.randf() * 0.4)
	var lh := Vector3(305, 0, 235)
	geo.cylinder(lh + Vector3(0, -3, 0), lh + Vector3(0, 2, 0), 8, "rock", 12)
	geo.lathe(lh + Vector3(0, 2, 0), [Vector2(3.2, 0), Vector2(2.4, 22)], "white", 16)
	geo.lathe(lh + Vector3(0, 9, 0), [Vector2(3.0, 0), Vector2(3.0, 3)], "crane_red", 16)
	geo.cylinder(lh + Vector3(0, 24, 0), lh + Vector3(0, 27, 0), 2.2, "glass", 12)
	geo.cone(lh + Vector3(0, 27, 0), lh + Vector3(0, 29.5, 0), 2.6, 0.2, "crane_red", 12)

func _tug(p: Vector3) -> void:
	geo.box(p + Vector3(0, -1.5, 0), Vector3(9, 3, 28), "hull_red")
	geo.box(p + Vector3(0, 2, -3), Vector3(7, 4, 9), "white")
	geo.box(p + Vector3(0, 4.5, -3), Vector3(7.2, 1.2, 9.2), "glass")
