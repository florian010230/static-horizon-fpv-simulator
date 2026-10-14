extends BuiltMap

## Parking Garage - an abandoned multi-storey car park, the classic FPV
## "bando" (Medium performance). Decks 60 x 36 m, 3 m floor to floor
## (2.7 m clear - tight for a 5-inch), levels 0-3 plus the open roof.
## Ramps sit in a two-lane bay on the east side: lane A (x 31-35)
## carries the even ramps, lane B (x 35-39) the odd ones, so ramps never
## cross; the ends meet the landing strips at z = +-16. Collapsed slab
## sections (dive through two levels), broken parapets (fly out
## between the decks), stair towers, abandoned cars, graffiti.

const DECK := Rect2(-30, -18, 60, 36)
const LEVELS: int = 5 ## 0 = ground, 4 = roof
const FLOOR_H: float = 3.0
const HOLES := {2: [Rect2(-12, -4, 8, 8)], 3: [Rect2(10, 5, 6, 7), Rect2(-12, -4, 8, 8)], 4: [Rect2(-22, -10, 7, 6)]}

var rng := RandomNumberGenerator.new()

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-38, 55, 0), "sun_color": Color(1.0, 0.9, 0.78), "fog_density": 0.0018,
		"sky_top": Color(0.3, 0.45, 0.68), "sky_horizon": Color(0.82, 0.76, 0.66),
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-128, -128, 256, 256)}

func border() -> Array:
	return [140.0, 180.0, 250.0, 310.0]

func preview_views() -> Array:
	return [
		["outside", Vector3(-80, 20, 5), Vector3(0, 6, 0)],
		["deck1", Vector3(-28, 4.5, 12), Vector3(20, 4.2, -10)],
		["hole", Vector3(-8, 11, 8), Vector3(-8, 3, -1)],
		["ramp", Vector3(33, 1.6, 17), Vector3(33, 3.5, -10)],
		["roof", Vector3(-35, 16, -25), Vector3(10, 12, 10)],
		["town_houses", Vector3(-80, 12, 10), Vector3(-100, 10, 48)],
		["town_street", Vector3(-60, 5, 30), Vector3(-130, 8, 46)],
	]

func build() -> void:
	rng.seed = 404
	geo.ao_height = 1.2
	geo.add_material("concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color.WHITE, 5.0))
	geo.add_material("deck", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.85, 0.85, 0.84), 6.0))
	geo.add_material("paint_yellow", Geo.flat_mat(Color(0.92, 0.75, 0.15), 0.6))
	geo.add_material("paint_white", Geo.flat_mat(Color(0.92, 0.92, 0.88), 0.6))
	geo.add_material("lamp_dead", Geo.flat_mat(Color(0.2, 0.21, 0.22), 0.3))
	geo.add_material("steel_thin", Geo.flat_mat(Color(0.7, 0.72, 0.74), 0.3, 0.6))
	geo.add_material("asphalt", Geo.ground_mat(MapTextures.get_tex("cracked_asphalt"), Color.WHITE, 8.0, 1))
	geo.add_material("grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 8.0, 0, 0.45))
	geo.add_material("paint_line", Geo.flat_mat(Color(0.85, 0.82, 0.6)))
	geo.add_material("rust", Geo.tex_mat(MapTextures.get_tex("rust"), Color.WHITE, 4.0))
	geo.add_material("lamp", Geo.glow_mat(Color(0.9, 0.95, 1.0), 0.8))
	geo.add_material("glass", Geo.flat_mat(Color(0.12, 0.14, 0.16), 0.2))
	geo.add_material("city", Geo.flat_mat(Color(0.66, 0.62, 0.58)))
	for c in [["car_red", Color(0.55, 0.12, 0.1)], ["car_blue", Color(0.14, 0.24, 0.45)], ["car_grey", Color(0.45, 0.46, 0.48)], ["car_white", Color(0.8, 0.8, 0.78)]]:
		geo.add_material(c[0], Geo.flat_mat(c[1], 0.4))
	for c in [["tag_pink", Color(0.9, 0.25, 0.6)], ["tag_green", Color(0.3, 0.8, 0.3)], ["tag_yellow", Color(0.95, 0.8, 0.15)], ["tag_blue", Color(0.2, 0.5, 0.95)]]:
		geo.add_material(c[0], Geo.flat_mat(c[1], 0.6))

	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.5, "grass")
	geo.slab(Rect2(-45, -24, 90, 50), 0.06, 0.1, "asphalt") # ground level + apron
	# Inside, the light is the strip lamps' and the daylight from the open
	# sides, baked (Geo.light_fn) - sun and sky alone left every ceiling
	# black (2026-10-12).
	geo.light_fn = _garage_light
	for lvl in range(1, LEVELS):
		_deck(lvl)
	for lvl in range(LEVELS):
		_level_contents(lvl)
	_ramps()
	geo.light_fn = Callable()
	_stair_tower(Vector3(-33, 0, -21))
	_stair_tower(Vector3(-33, 0, 21))
	_surroundings()

## One deck: slab (minus collapsed holes), landing strip in the ramp
## bay, parapets with broken gaps, light strips underneath.
func _deck(lvl: int) -> void:
	var y: float = lvl * FLOOR_H
	for r in _minus_holes(DECK, HOLES.get(lvl, [])):
		geo.slab(r, y, 0.3, "deck")
	var end_z: float = 16.0 if lvl % 2 == 0 else -16.0
	geo.slab(Rect2(30, end_z - 2.0, 9, 4), y, 0.3, "deck")
	# Parapets: 1 m walls, some sections broken out.
	var edges: Array = [[Vector2(-30, -18), Vector2(30, -18)], [Vector2(-30, 18), Vector2(30, 18)], [Vector2(-30, -18), Vector2(-30, 18)]]
	for e in edges:
		var n: int = int(e[0].distance_to(e[1]) / 6.0)
		for i in range(n):
			if rng.randf() < 0.18:
				continue # broken out
			var a: Vector2 = e[0].lerp(e[1], float(i) / n)
			var b: Vector2 = e[0].lerp(e[1], float(i + 1) / n)
			geo.beam(Vector3(a.x, y + 0.5, a.y), Vector3(b.x, y + 0.5, b.y), Vector2(0.2, 1.0), "concrete")
	if lvl < LEVELS - 1:
		for i in range(6):
			# About one tube in four is dead.
			geo.box(Vector3(-25 + i * 10, y - 0.32, 0), Vector3(0.3, 0.05, 30), "lamp_dead" if (i * 7 + lvl * 3) % 4 == 0 else "lamp", 0.0, false, false)
	else:
		# Roof: lamp posts.
		for p in [Vector3(-20, y, -10), Vector3(0, y, -10), Vector3(20, y, -10), Vector3(-20, y, 10), Vector3(0, y, 10), Vector3(20, y, 10)]:
			geo.cylinder(p, p + Vector3(0, 6, 0), 0.1, "rust", 8)
			geo.box(p + Vector3(0.6, 6, 0), Vector3(1.4, 0.15, 0.4), "rust")

## Columns, parking bays, parked cars and graffiti on one level.
func _level_contents(lvl: int) -> void:
	var y: float = lvl * FLOOR_H
	if lvl < LEVELS - 1:
		for i in range(9):
			for j in range(5):
				var x: float = -30 + i * 7.5
				var z: float = -18 + j * 9.0
				if _in_hole(lvl + 1, Vector2(x, z), 0.5):
					continue # the column went down with the slab
				geo.box(Vector3(x, y + FLOOR_H * 0.5, z), Vector3(0.5, FLOOR_H - 0.3, 0.5), "concrete")
				if rng.randf() < 0.25:
					var tag: String = ["tag_pink", "tag_green", "tag_yellow", "tag_blue"][rng.randi() % 4]
					geo.box(Vector3(x + 0.26, y + 1.2, z), Vector3(0.02, rng.randf_range(0.6, 1.4), 0.45), tag, 0.0, false, false)
	# Bay lines and cars along both long sides.
	for side in [-1.0, 1.0]:
		for i in range(22):
			var x: float = -27 + i * 2.6
			geo.box(Vector3(x, y + 0.025, side * 13.5), Vector3(0.1, 0.04, 5.0), "paint_line", 0.0, false, false) # (4.5 cm: 3 cm over the deck flickered)
			var fpv_bay: bool = lvl == 0 and side > 0.0 and i == FPV_BAY
			if rng.randf() < 0.3 and not _in_hole(lvl, Vector2(x + 1.3, side * 13.5), 2.5):
				_car(Vector3(x + 1.3, y, side * 13.5), rng.randf_range(-0.1, 0.1), fpv_bay) # (the FPV car's bay still draws the same random numbers)
			if fpv_bay:
				_fpv_car(Vector3(x + 1.3, 0.06, side * 13.5))
	_car_park_paint(lvl, y)
	_bando(lvl, y)
	# Rubble under the collapsed holes above.
	for h: Rect2 in HOLES.get(lvl + 1, []):
		if not _in_hole(lvl, h.get_center(), 0.0):
			for k in range(8):
				var p := Vector3(rng.randf_range(h.position.x, h.end.x), y, rng.randf_range(h.position.y, h.end.y))
				var s: float = rng.randf_range(0.5, 1.8)
				geo.box_xf(Transform3D(Basis.from_euler(Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)), p + Vector3(0, s * 0.2, 0)), Vector3(s, 0.3, s * 0.8), "deck")

## Baked light inside the decks: a base, each working strip lamp (the
## dead ones as in _deck) falling off with distance and facing, daylight
## within ~8 m of an open side; the roof's top lies in full daylight.
func _garage_light(n: Vector3, p: Vector3) -> Color:
	var top: float = (LEVELS - 1) * FLOOR_H
	if p.y >= top - 0.05 and n.y > 0.5:
		return Color(1.05, 1.0, 0.95)
	var lvl: int = clampi(int(floor((p.y + 0.05) / FLOOR_H)), 0, LEVELS - 2)
	var l: float = 0.4
	var ty: float = (lvl + 1) * FLOOR_H - 0.32
	for i in range(6):
		if (i * 7 + (lvl + 1) * 3) % 4 == 0:
			continue # a dead tube
		var t := Vector3(-25 + i * 10, ty, clampf(p.z, -15.0, 15.0))
		var d: Vector3 = t - p
		var dist2: float = d.length_squared()
		var face: float = maxf(0.25, n.dot(d / maxf(sqrt(dist2), 0.01)))
		l += 0.85 * face / (1.0 + 0.06 * dist2)
	var edge: float = minf(18.0 - absf(p.z), p.x + 30.0)
	if p.x > 30.0:
		edge = 0.0 # the ramp bay is open
	l += 0.5 * clampf(1.0 - edge / 8.0, 0.0, 1.0)
	l = minf(l, 1.25)
	return Color(l, l * 0.99, l * 0.95)

## What makes it read as a car park: a yellow band and the level number
## on the middle row of columns, arrows down the aisle.
func _car_park_paint(lvl: int, y: float) -> void:
	if lvl >= LEVELS - 1:
		return
	for i in [1, 4, 7]:
		var x: float = -30 + i * 7.5
		if _in_hole(lvl + 1, Vector2(x, 0), 0.5):
			continue
		geo.box(Vector3(x, y + 0.6, 0), Vector3(0.54, 1.2, 0.54), "paint_yellow", 0.0, false, false)
		for sd in [-1.0, 1.0]:
			var l := Label3D.new()
			l.text = "P%d" % lvl if lvl > 0 else "E"
			l.font = UIKit.oswald_font()
			l.font_size = 96
			l.pixel_size = 0.004
			l.modulate = Color(0.12, 0.12, 0.13)
			l.outline_size = 0
			l.position = Vector3(x, y + 1.9, sd * 0.28)
			l.rotation.y = 0.0 if sd > 0 else PI
			add_child(l)
	for k in range(3):
		var x: float = -18 + k * 18
		var dir: float = 1.0 if lvl % 2 == 0 else -1.0
		geo.box(Vector3(x, y + 0.026, 0), Vector3(2.4, 0.04, 0.3), "paint_white", 0.0, false, false)
		for sd in [-1.0, 1.0]:
			geo.box(Vector3(x + dir * 1.05, y + 0.027, sd * 0.32), Vector3(0.9, 0.04, 0.25), "paint_white", dir * sd * 0.6, false, false)

## Abandoned: debris, a burnt-out car on level 1, shopping trolleys.
func _bando(lvl: int, y: float) -> void:
	if lvl >= LEVELS - 1:
		return
	for k in range(5):
		var p := Vector3(rng.randf_range(-26, 26), y, rng.randf_range(-8, 8))
		if _in_hole(lvl, Vector2(p.x, p.z), 1.0):
			continue
		var sz := Vector3(rng.randf_range(0.3, 1.0), rng.randf_range(0.1, 0.3), rng.randf_range(0.3, 0.9))
		geo.box(p + Vector3(0, sz.y * 0.5, 0), sz, "deck", rng.randf() * TAU)
	if lvl == 1:
		var c := Vector3(-14.7, y, -13.5)
		geo.box(c + Vector3(0, 0.5, 0), Vector3(1.8, 0.6, 4.3), "rust", 0.15)
		geo.box(c + Vector3(0, 1.02, 0.2), Vector3(1.5, 0.42, 2.0), "rust", 0.15)
	if lvl in [0, 2]:
		for k in range(2):
			var t := Vector3(rng.randf_range(-20, 20), y, rng.randf_range(-6, 6))
			var yaw: float = rng.randf() * TAU
			var b := Basis(Vector3.UP, yaw)
			for lx in [-0.3, 0.3]:
				for lz in [-0.4, 0.4]:
					geo.box(t + b * Vector3(lx, 0.25, lz), Vector3(0.03, 0.5, 0.03), "steel_thin", yaw, false)
			geo.box(t + Vector3(0, 0.75, 0), Vector3(0.6, 0.45, 0.9), "steel_thin", yaw, false)

func _car(p: Vector3, yaw: float, skip: bool = false) -> void:
	var paint: String = ["car_red", "car_blue", "car_grey", "car_white"][rng.randi() % 4]
	if skip:
		return
	# Nose into the bay (lengthwise along its 5 m lines - turned across, each
	# car reached into the next bay and the next car).
	geo.box(p + Vector3(0, 0.55, 0), Vector3(1.8, 0.7, 4.3), paint, yaw)
	geo.box(p + Vector3(0, 1.12, 0), Vector3(1.6, 0.5, 2.2), "glass", yaw)

const FPV_BAY: int = 8 ## the ground-level bay (south side, x -4.9) of the FPV car

## Easter egg (2026-10-14): one real parked car (Vehicles.car, a hatch, no
## shark-fin antenna) belongs to an FPV pilot - his goggles stand on the
## cowl against the windscreen (the glass is opaque, so not on the dash
## itself) and a drone backpack sits on the bonnet. Nose to the aisle.
func _fpv_car(p: Vector3) -> void:
	Vehicles.car(geo, p, 0.0, "veh_paint2", "hatch", false, false)
	EggProps.ensure(geo)
	# Hatch: nose at z = -2.05, bonnet from (-2.0, 0.80) up to (-1.07, 0.92).
	var a: float = atan2(0.12, 0.93)
	var bonnet := func(z: float) -> float: return 0.8 + (z + 2.0) / 0.93 * 0.12
	var cxf := Transform3D(Basis(), p)
	EggProps.backpack(geo, cxf * Transform3D(Basis(Vector3.RIGHT, -a), Vector3(-0.32, bonnet.call(-1.6) - 0.006, -1.6)))
	EggProps.goggles(geo, cxf * Transform3D(Basis(Vector3.RIGHT, -a), Vector3(0.38, bonnet.call(-1.4) - 0.006, -1.4)))

## Two-lane ramp bay (see header).
func _ramps() -> void:
	for k in range(LEVELS - 1):
		var lane_x: float = 33.0 if k % 2 == 0 else 37.0
		var z0: float = 14.0 if k % 2 == 0 else -14.0
		var a := Vector3(lane_x, k * FLOOR_H - 0.15, z0)
		var b := Vector3(lane_x, (k + 1) * FLOOR_H - 0.15, -z0)
		geo.beam(a, b, Vector2(3.8, 0.3), "deck")
		for s in [-1.0, 1.0]:
			geo.beam(a + Vector3(s * 1.95, 0.6, 0), b + Vector3(s * 1.95, 0.6, 0), Vector2(0.1, 0.9), "concrete")
	# Outer wall columns of the ramp bay.
	for z in [-18.0, -9.0, 0.0, 9.0, 18.0]:
		geo.box(Vector3(39.2, LEVELS * FLOOR_H * 0.5 - 1.5, z), Vector3(0.5, (LEVELS - 1) * FLOOR_H, 0.5), "concrete")

## Hollow stair shaft with a door opening on every level.
func _stair_tower(o: Vector3) -> void:
	var h: float = LEVELS * FLOOR_H + 1.0
	for side in [[Vector3(0, 0, -2), Vector3(4, 0, 0.25)], [Vector3(0, 0, 2), Vector3(4, 0, 0.25)], [Vector3(-2, 0, 0), Vector3(0.25, 0, 4)]]:
		geo.box(o + side[0] + Vector3(0, h * 0.5, 0), side[1] + Vector3(0, h, 0), "concrete")
	for lvl in range(LEVELS):
		var y: float = lvl * FLOOR_H
		geo.box(o + Vector3(2, y + 2.6, 0), Vector3(0.25, 0.8, 4), "concrete")    # lintel over the door
		for dz in [-1.5, 1.5]:
			geo.box(o + Vector3(2, y + 1.1, dz), Vector3(0.25, 2.2, 1.0), "concrete")
		geo.slab(Rect2(o.x - 2, o.z - 2, 4, 1.6), y + 1.5, 0.15, "concrete")      # landing
	geo.box(o + Vector3(0, h + 0.1, 0), Vector3(4.4, 0.2, 4.4), "concrete")

## The street in front (out of the map both ways, with a side street
## north past the garage's east side), town houses and blocks along
## both, a row of shops opposite, the grid carrying on into the haze.
func _surroundings() -> void:
	var roads := Roads.new(geo, rng, fleet)
	var city := City.new(geo, rng, fleet)
	# Real town houses (CityHouseCreator) in the blocks round the garage
	# (~22 ms a house, so a capped count); every block further out gets the
	# same houses in low detail (2026-10-12).
	city.house_centre = Vector2(-40, 0)
	city.house_radius = 110.0
	city.house_cap = 40
	city.lod_houses = true
	roads.junction(Vector3(60, 0, 31), Vector2(10, 10), ["w", "e", "n"], 2.5)
	var w := Route.from(Vector3(55, 0, 31), 180.0).straight(3055.0, 20.0)
	var e := Route.from(Vector3(65, 0, 31), 0.0).straight(3000.0, 20.0)
	var n := Route.from(Vector3(60, 0, 26), -90.0).straight(3000.0, 20.0)
	for r in [w, e, n]:
		roads.road(r, 10.0, {"walk": 2.5, "lamps": 28.0, "detail": 450.0})
		roads.parked(Route.from_pts(r.slice(8.0, 400.0)), 3.8, 0.5)
		roads.traffic(Route.from_pts(r.slice(0.0, 600.0)), 5.0, 1, 12.0, 0.1)
	# Opposite the garage: perimeter blocks along the street.
	var x: float = -560.0
	while x < 560.0:
		var bw: float = rng.randf_range(60.0, 90.0)
		if absf(x + bw * 0.5 - 60.0) > bw * 0.5 + 8.0:
			city.perimeter_block(Rect2(x, 38.5, bw, 50.0), 0.0, 3, 6)
		x += bw + 12.0
	# Behind and beside the garage: blocks and the east side street's houses.
	for k in range(12):
		var z: float = -40.0 - k * 60.0
		city.perimeter_block(Rect2(68.5, z - 50.0, 60.0, 50.0), 0.0, 3, 5)
		if k > 0:
			city.perimeter_block(Rect2(-80.0, z - 50.0, 128.0, 50.0), 0.0, 3, 5)
	for k in range(8):
		city.perimeter_block(Rect2(-160.0 - k * 80.0, -40.0, 70.0, 60.0), 0.0, 3, 5)
	Forest.plant(self, city.trees, self)

func _in_hole(lvl: int, p: Vector2, margin: float) -> bool:
	for h: Rect2 in HOLES.get(lvl, []):
		if h.grow(margin).has_point(p):
			return true
	return false

## Rect minus rectangular holes, as a set of rects (grid split on the
## holes' edges, keeping the cells not inside any hole).
func _minus_holes(r: Rect2, holes: Array) -> Array[Rect2]:
	var xs: Array[float] = [r.position.x, r.end.x]
	var zs: Array[float] = [r.position.y, r.end.y]
	for h: Rect2 in holes:
		xs.append_array([h.position.x, h.end.x])
		zs.append_array([h.position.y, h.end.y])
	xs.sort()
	zs.sort()
	var out: Array[Rect2] = []
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var cell := Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			if cell.size.x < 0.01 or cell.size.y < 0.01:
				continue
			var inside: bool = false
			for h: Rect2 in holes:
				if h.encloses(cell):
					inside = true
			if not inside:
				out.append(cell)
	return out
