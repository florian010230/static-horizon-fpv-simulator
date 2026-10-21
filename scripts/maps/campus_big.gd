class_name CampusBig
extends RefCounted

## The big buildings of the campus: the test and production hall (30 % of
## the roof still open), the warehouse with its truck yard, the parking
## garage, the pipe rack between hall and warehouse, the foundation pit.

const HALL := Rect2(-161, 6, 95, 48) ## x, z (world); 16 m high, long side along x
const WARE := Rect2(20, 6, 75, 42)
const GARAGE := Rect2(16, -123, 62, 48)
const LEVEL: float = 3.1 ## garage storey
const YARD := Rect2(20, 49, 75, 66)

var k: CampusKit
var geo: Geo
var rng := RandomNumberGenerator.new()

func _init(kit: CampusKit) -> void:
	k = kit
	geo = kit.geo
	rng.seed = 6226

func build_all() -> void:
	_hall()
	_warehouse()
	_garage()
	_pipe_rack()
	_pit()

# --- test and production hall ------------------------------------------------------------------

func _hall() -> void:
	var c := Vector3(HALL.get_center().x, 0, HALL.get_center().y)
	var xl: float = HALL.position.x
	var xr: float = HALL.end.x
	var z0: float = HALL.position.y
	var z1: float = HALL.end.y
	var eave: float = 13.0
	var ridge: float = 16.0
	geo.begin_object("production hall")
	# Floor.
	geo.tint = Color(0.82, 0.82, 0.8)
	geo.box(c + Vector3(0, -0.1, 0), Vector3(HALL.size.x - 0.4, 0.4, HALL.size.y - 0.4), "in_floor")
	# Walls: cladding over a low plinth; N wall with two open sectional doors
	# and a clerestory of open windows, E wall one door, S and W closed.
	geo.tint = Color(0.78, 0.82, 0.86)
	var clad := "in_clad"
	var door_n: Array = [-140.0, -100.0]
	var holes_n: Array = []
	for dx: float in door_n:
		holes_n.append(Rect2(dx - 3.0, 0.1, 6.0, 5.0))
	for i in range(11):
		var wx: float = xl + 8.0 + i * 8.0
		holes_n.append(Rect2(wx - 1.5, 10.0, 3.0, 1.3))
	k.wall("x", z0 + 0.1, xl, xr, -0.2, eave, 0.2, holes_n, clad)
	var holes_s: Array = []
	for i in range(11):
		holes_s.append(Rect2(xl + 8.0 + i * 8.0 - 1.5, 10.0, 3.0, 1.3))
	k.wall("x", z1 - 0.1, xl, xr, -0.2, eave, 0.2, holes_s, clad)
	var holes_e: Array = [Rect2(c.z - 3.0, 0.1, 6.0, 5.0), Rect2(c.z + 12.0, 0.1, 1.3, 2.4)]
	k.wall("z", xr - 0.1, z0 + 0.2, z1 - 0.2, -0.2, eave, 0.2, holes_e, clad)
	k.wall("z", xl + 0.1, z0 + 0.2, z1 - 0.2, -0.2, eave, 0.2, [Rect2(c.z + 12.0, 0.1, 1.3, 2.4)], clad)
	# Gables on the end walls.
	for gx: float in [xl + 0.1, xr - 0.1]:
		BuildKit.gable(geo, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(gx, 0, 0)), z0 + 0.2, z1 - 0.2, eave, ridge - eave, 0.2, clad)
	geo.tint = Color(0.45, 0.47, 0.5)
	for gx: float in [xl - 0.02, xr + 0.02]:
		geo.box(Vector3(gx, 0.5, c.z), Vector3(0.1, 1.0, HALL.size.y), "in_concrete", 0.0, false)
	# The sectional doors: housing above, tracks, the rolled-up panels.
	geo.tint = Color(0.25, 0.3, 0.38)
	for dx: float in door_n:
		geo.box(Vector3(dx, 5.55, z0 - 0.15), Vector3(6.6, 0.9, 0.5), "in_paint")
		for s in [-1.0, 1.0]:
			geo.box(Vector3(dx + s * 3.1, 2.6, z0 - 0.05), Vector3(0.14, 5.2, 0.16), "in_paint", 0.0, false)
		geo.box(Vector3(dx, 5.1, z0 + 0.5), Vector3(5.8, 0.5, 0.5), "in_clad", 0.0, false)
	geo.box(Vector3(xr + 0.15, 5.55, c.z), Vector3(0.5, 0.9, 6.6), "in_paint")
	geo.box(Vector3(xr - 0.45, 5.1, c.z), Vector3(0.5, 0.5, 5.8), "in_clad", 0.0, false) # (against the wall, as on the north doors: it stood 25 cm off)
	geo.tint = Color.WHITE
	# Portal frames every 7.9 m: columns, rafters.
	var nb: int = 12
	var bay: float = HALL.size.x / nb
	geo.tint = Color(0.3, 0.38, 0.55)
	for i in range(nb + 1):
		var fx: float = xl + 0.6 + i * (HALL.size.x - 1.2) / nb
		for s in [-1.0, 1.0]:
			var zc: float = c.z + s * (HALL.size.y * 0.5 - 0.5)
			geo.box(Vector3(fx, eave * 0.5, zc), Vector3(0.45, eave, 0.5), "in_steel")
			geo.beam(Vector3(fx, eave, zc), Vector3(fx, ridge, c.z), Vector2(0.3, 0.5), "in_steel")
	# Purlins along the roof (visible where the roof is open).
	geo.tint = Color(0.45, 0.47, 0.5)
	for s in [-1.0, 1.0]:
		for j in range(5):
			var t: float = j / 4.0
			var zc: float = c.z + s * (HALL.size.y * 0.5 - 0.5) * (1.0 - t)
			var yc: float = eave + (ridge - eave) * t
			geo.beam(Vector3(xl + 0.4, yc + 0.16, zc), Vector3(xr - 0.4, yc + 0.16, zc), Vector2(0.14, 0.22), "in_steel", false)
	# Roof panels: bays 0-3 (the west 30 %) are open on the south slope, 0-2 and one more strip
	# on the north slope - the roof is unfinished there.
	geo.tint = Color(0.82, 0.84, 0.86)
	var ang: float = atan2(ridge - eave, HALL.size.y * 0.5 - 0.5)
	var slope_len: float = sqrt(pow(HALL.size.y * 0.5 - 0.5, 2) + pow(ridge - eave, 2))
	var strips: int = 4
	for sgn in [-1.0, 1.0]:
		for b in range(nb):
			var open_bays: int = 4 if sgn > 0.0 else 3
			if b < open_bays:
				continue
			for st in range(strips):
				var t: float = (st + 0.5) / strips
				var zc: float = c.z + sgn * (HALL.size.y * 0.5 - 0.5) * (1.0 - t)
				var yc: float = eave + (ridge - eave) * t + 0.3
				var bx: float = xl + 0.6 + (b + 0.5) * (HALL.size.x - 1.2) / nb
				geo.box_xf(Transform3D(Basis(Vector3.RIGHT, sgn * ang), Vector3(bx, yc, zc)), Vector3(bay - 0.16, 0.1, slope_len / strips - 0.12), "in_clad")
	# Light strips in the closed roof.
	geo.tint = Color.WHITE
	for b in range(5, nb, 2):
		var bx: float = xl + 0.6 + (b + 0.5) * (HALL.size.x - 1.2) / nb
		for sgn in [-1.0, 1.0]:
			geo.box_xf(Transform3D(Basis(Vector3.RIGHT, sgn * ang), Vector3(bx, eave + (ridge - eave) * 0.5 + 0.36, c.z + sgn * (HALL.size.y * 0.25 - 0.3))), Vector3(bay - 0.9, 0.08, 2.0), "in_light", false)
	# Crane runway beams on brackets, the bridge crane (girder, trolley, hook, a load).
	var run_y: float = 10.2
	geo.tint = Color(0.8, 0.55, 0.1)
	for s in [-1.0, 1.0]:
		var rz: float = c.z + s * (HALL.size.y * 0.5 - 1.5)
		geo.box(Vector3(c.x, run_y, rz), Vector3(HALL.size.x - 2.0, 0.55, 0.45), "in_steel")
		for i in range(nb + 1):
			var fx: float = xl + 0.6 + i * (HALL.size.x - 1.2) / nb
			geo.box(Vector3(fx, run_y - 0.5, c.z + s * (HALL.size.y * 0.5 - 0.95)), Vector3(0.4, 0.5, 0.9), "in_steel", 0.0, false)
	var cx: float = c.x + 10.0
	geo.box(Vector3(cx, run_y + 0.85, c.z), Vector3(1.0, 1.4, HALL.size.y - 3.4), "in_steel")
	for s in [-1.0, 1.0]:
		geo.box(Vector3(cx, run_y + 0.55, c.z + s * (HALL.size.y * 0.5 - 1.5)), Vector3(2.4, 0.9, 1.0), "in_steel")
	geo.box(Vector3(cx, run_y + 1.8, c.z + 4.0), Vector3(1.8, 0.7, 2.4), "crane_red")
	geo.beam(Vector3(cx, run_y + 1.5, c.z + 4.0), Vector3(cx, 4.4, c.z + 4.0), Vector2(0.05, 0.05), "dark", false, false)
	geo.tint = Color.WHITE
	geo.box(Vector3(cx, 4.2, c.z + 4.0), Vector3(0.5, 0.5, 0.3), "crane_red", 0.0, false, false)
	geo.tint = Color(0.5, 0.52, 0.55)
	geo.box(Vector3(cx, 2.4, c.z + 4.0), Vector3(2.6, 1.4, 1.5), "in_steel") # an engine block on the hook
	for e in [-1.0, 1.0]:
		geo.beam(Vector3(cx, 4.0, c.z + 4.0), Vector3(cx + e * 1.1, 3.1, c.z + 4.0 + e * 0.5), Vector2(0.04, 0.04), "dark", false, false)
	# The test rig: a reaction frame over a strong floor, a ram on a concrete beam.
	var rx: float = c.x - 26.0
	var rz: float = c.z - 4.0
	geo.tint = Color(0.9, 0.62, 0.1)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			geo.box(Vector3(rx + sx * 5.5, 3.9, rz + sz * 3.4), Vector3(0.7, 7.6, 0.7), "in_steel")
		geo.box(Vector3(rx + sx * 5.5, 7.4, rz), Vector3(0.6, 0.8, 7.9), "in_steel")
	geo.box(Vector3(rx, 7.9, rz), Vector3(11.4, 0.9, 1.0), "in_steel")
	geo.tint = Color(0.75, 0.75, 0.78)
	geo.cylinder(Vector3(rx, 7.4, rz), Vector3(rx, 4.6, rz), 0.38, "in_steel", 12)
	geo.cylinder(Vector3(rx, 4.6, rz), Vector3(rx, 2.6, rz), 0.16, "in_steel", 8)
	geo.tint = Color(0.62, 0.62, 0.6)
	geo.box(Vector3(rx, 1.7, rz), Vector3(6.0, 0.9, 1.0), "in_concrete") # the specimen
	for sx in [-2.2, 2.2]:
		geo.box(Vector3(rx + sx, 0.65, rz), Vector3(0.8, 1.1, 1.3), "in_concrete")
	geo.tint = Color(0.3, 0.32, 0.36)
	geo.box(Vector3(rx, 0.25, rz), Vector3(12.0, 0.3, 8.6), "in_steel", 0.0, true, false) # the strong floor plate
	# Control cabin beside it.
	geo.tint = Color(0.9, 0.9, 0.86)
	geo.box(Vector3(rx + 11.0, 1.4, rz + 1.0), Vector3(3.6, 2.8, 2.6), "in_concrete")
	geo.tint = Color(0.1, 0.12, 0.14)
	geo.box(Vector3(rx + 9.18, 1.8, rz + 1.0), Vector3(0.04, 0.9, 1.8), "in_glass", 0.0, false, false)
	# Machines along the south wall (a lathe, a mill, a press, ...).
	var paints: Array = [Color(0.2, 0.4, 0.55), Color(0.35, 0.5, 0.35), Color(0.75, 0.25, 0.15), Color(0.5, 0.5, 0.52), Color(0.2, 0.4, 0.55), Color(0.85, 0.65, 0.12), Color(0.35, 0.5, 0.35)]
	for i in range(7):
		var mx: float = c.x - 37.0 + i * 11.0
		var mz: float = c.z + 17.5
		geo.tint = Color(0.25, 0.26, 0.28)
		geo.box(Vector3(mx, 0.45, mz), Vector3(4.6, 0.9, 2.6), "in_paint")
		geo.tint = paints[i]
		geo.box(Vector3(mx - 0.4, 1.6, mz), Vector3(3.6, 1.4, 2.2), "in_paint")
		geo.box(Vector3(mx + 1.8, 2.4, mz - 0.2), Vector3(1.0, 3.0, 1.6), "in_paint")
		geo.tint = Color(0.15, 0.15, 0.16)
		geo.box(Vector3(mx - 0.4, 2.45, mz + 0.9), Vector3(3.0, 0.3, 0.2), "in_paint", 0.0, false)
		geo.tint = Color(0.8, 0.82, 0.84)
		geo.cylinder(Vector3(mx - 1.6, 1.5, mz + 1.15), Vector3(mx + 0.4, 1.5, mz + 1.15), 0.2, "in_steel", 10)
		geo.tint = Color(0.15, 0.15, 0.18)
		geo.box(Vector3(mx + 2.5, 1.0, mz + 1.0), Vector3(0.5, 1.4, 0.5), "in_paint")
	# Racks of parts and pallets by the west wall, crates by the doors.
	geo.tint = Color(0.15, 0.3, 0.6)
	for j in range(2):
		for lvl in range(4):
			geo.box(Vector3(xl + 3.0 + j * 3.2, 0.3 + lvl * 1.5, c.z - 18.0), Vector3(2.6, 0.1, 1.0), "in_paint")
		for ux in [-1.3, 1.3]:
			for uz in [-0.45, 0.45]:
				geo.box(Vector3(xl + 3.0 + j * 3.2 + ux, 3.0, c.z - 18.0 + uz), Vector3(0.1, 6.0, 0.1), "in_paint")
	geo.tint = Color.WHITE
	for i in range(9):
		k.pallet(Vector3(xl + 8.0 + (i % 3) * 1.4, 0.1, c.z + 4.0 + (i / 3) * 1.2), rng.randf_range(-0.2, 0.2), rng.randf_range(0.5, 1.2), "carton" if i % 2 == 0 else "wrap")
	# Compressed-air pipe along the east wall, hanging lamps.
	geo.tint = Color(0.2, 0.45, 0.65)
	geo.cylinder(Vector3(xr - 1.0, 8.4, z0 + 1.0), Vector3(xr - 1.0, 8.4, z1 - 1.0), 0.12, "in_steel", 8, false)
	geo.tint = Color.WHITE
	for row in range(3):
		for i in range(11):
			var lx: float = xl + 5.0 + i * 8.4
			var lz: float = c.z - 12.0 + row * 12.0
			geo.box(Vector3(lx, 11.6, lz), Vector3(1.4, 0.12, 0.35), "in_lamp", 0.0, false, false)
			# Its cable up to the roof (the lamps hung in the air).
			# (To the purlin over it, which runs 0.25 m off the lamp row's line.)
			var cz: float = lz + signf(c.z - lz) * 0.17
			var ry: float = eave + (ridge - eave) * (1.0 - absf(cz - c.z) / ((z1 - z0) * 0.5)) + 0.05
			geo.box(Vector3(lx, (11.66 + ry) * 0.5, cz), Vector3(0.03, ry - 11.66, 0.03), "in_steel", 0.0, false, false)
	geo.end_object()
	k.map.register_entrance(Vector3(door_n[0], 0.0, z0 - 0.5), "hall door")
	k.map.register_entrance(Vector3(door_n[1], 0.0, z0 - 0.5), "hall door")
	k.map.register_entrance(Vector3(xr + 0.5, 0.0, c.z), "hall east door")

# --- the warehouse ---------------------------------------------------------------------------------------------

func _warehouse() -> void:
	var xl: float = WARE.position.x
	var xr: float = WARE.end.x
	var z0: float = WARE.position.y
	var z1: float = WARE.end.y
	var fl: float = 1.2 ## dock-high floor
	var top: float = 12.0
	geo.begin_object("warehouse")
	geo.tint = Color(0.8, 0.8, 0.78)
	geo.box(Vector3(WARE.get_center().x, (fl - 0.2) * 0.5, WARE.get_center().y), Vector3(WARE.size.x, fl + 0.2, WARE.size.y), "in_floor")
	geo.tint = Color(0.86, 0.84, 0.76)
	var docks: Array = [31.0, 42.5, 54.0, 65.5, 77.0, 88.5]
	var holes_s: Array = []
	for dx: float in docks:
		holes_s.append(Rect2(dx - 1.6, fl + 0.02, 3.2, 3.6))
	for i in range(7):
		holes_s.append(Rect2(xl + 8.0 + i * 10.0 - 1.5, 9.5, 3.0, 1.3))
	k.wall("x", z1 - 0.1, xl, xr, fl, top, 0.2, holes_s, "in_clad")
	var holes_n: Array = [Rect2(30.0 - 0.6, fl + 0.02, 1.2, 2.2), Rect2(85.0 - 0.6, fl + 0.02, 1.2, 2.2)]
	for i in range(7):
		holes_n.append(Rect2(xl + 8.0 + i * 10.0 - 1.5, 9.5, 3.0, 1.3))
	k.wall("x", z0 + 0.1, xl, xr, fl, top, 0.2, holes_n, "in_clad")
	k.wall("z", xl + 0.1, z0 + 0.2, z1 - 0.2, fl, top, 0.2, [Rect2(WARE.get_center().y - 0.7, 9.5, 1.5, 1.3)], "in_clad")
	k.wall("z", xr - 0.1, z0 + 0.2, z1 - 0.2, fl, top, 0.2, [Rect2(WARE.get_center().y - 0.7, 9.5, 1.5, 1.3)], "in_clad")
	geo.tint = Color(0.5, 0.52, 0.55)
	geo.box(Vector3(WARE.get_center().x, top + 0.2, WARE.get_center().y), Vector3(WARE.size.x + 0.4, 0.4, WARE.size.y + 0.4), "in_paint")
	for s in [-1.0, 1.0]:
		geo.box(Vector3(WARE.get_center().x, top + 0.7, WARE.get_center().y + s * (WARE.size.y * 0.5 + 0.1)), Vector3(WARE.size.x + 0.4, 0.6, 0.3), "in_paint")
		geo.box(Vector3(WARE.get_center().x + s * (WARE.size.x * 0.5 + 0.1), 0.7 + top, WARE.get_center().y), Vector3(0.3, 0.6, WARE.size.y), "in_paint")
	# Dock seals (black frames), bumpers, door tracks; the dock numbers.
	for i in range(docks.size()):
		var dx: float = docks[i]
		geo.tint = Color(0.08, 0.08, 0.09)
		geo.box(Vector3(dx, fl + 3.85, z1 + 0.25), Vector3(3.9, 0.45, 0.7), "in_paint")
		for s in [-1.0, 1.0]:
			geo.box(Vector3(dx + s * 1.85, fl + 1.85, z1 + 0.25), Vector3(0.4, 3.9, 0.7), "in_paint")
			geo.box(Vector3(dx + s * 1.4, 0.5, z1 + 0.15), Vector3(0.45, 0.6, 0.3), "in_paint")
		geo.tint = Color(0.75, 0.75, 0.72)
		geo.box(Vector3(dx, fl + 0.05, z1 - 0.2), Vector3(2.4, 0.1, 1.2), "in_steel", 0.0, true, false) # the dock leveller plate
		StreetKit._label(geo, str(i + 1), CampusKit.out_frame(Vector3(dx, fl + 5.2, z1 + 0.03), Vector3(0, 0, 1)), 0.014, Color(0.95, 0.8, 0.1), 0.7)
	geo.tint = Color.WHITE
	# The steps at the two north doors.
	geo.tint = Color(0.72, 0.72, 0.7)
	for dx: float in [30.0, 85.0]:
		for s in range(4):
			geo.box(Vector3(dx, 0.3 * (s + 1) * 0.5, z0 - 0.4 - 0.4 * (3 - s)), Vector3(1.8, 0.3 * (s + 1), 0.4), "in_concrete")
		k.map.register_entrance(Vector3(dx, 0.0, z0 - 1.6), "warehouse door")
	geo.tint = Color.WHITE
	# High-bay racks: 11 double rows along z, aisles 3.6 m wide.
	var levels: Array = [0.3, 2.4, 4.5, 6.6, 8.7]
	for pair in range(11):
		var xp: float = 26.0 + pair * 6.0
		for side in [-1.0, 1.0]:
			var xr0: float = xp + side * 0.65
			for j in range(11):
				var zf: float = 13.0 + j * 2.8
				for ux in [-0.5, 0.5]:
					geo.tint = Color(0.12, 0.28, 0.6)
					geo.box(Vector3(xr0 + ux, fl + 4.8, zf), Vector3(0.1, 9.6, 0.1), "in_paint")
			for lv in range(levels.size()):
				geo.tint = Color(0.9, 0.42, 0.08)
				for ux in [-0.5, 0.5]:
					geo.box(Vector3(xr0 + ux, fl + levels[lv], 13.0 + 14.0), Vector3(0.08, 0.14, 28.2), "in_paint")
				for j in range(10):
					if lv == 0 and rng.randf() < 0.1:
						continue
					if rng.randf() < 0.42:
						continue
					var zc: float = 13.0 + 1.4 + j * 2.8
					var h: float = rng.randf_range(1.0, 1.7)
					geo.tint = Color(1.0, 0.95, 0.88) if rng.randf() < 0.6 else Color(0.85, 0.9, 0.95)
					geo.box(Vector3(xr0, fl + levels[lv] + 0.07 + h * 0.5, zc), Vector3(0.98, h, 2.4), "carton" if rng.randf() < 0.6 else "wrap")
	geo.tint = Color.WHITE
	# Ceiling lamps in rows.
	for row in range(4):
		for i in range(12):
			geo.box(Vector3(xl + 4.0 + i * 6.2, top - 0.5, 12.0 + row * 9.0), Vector3(1.4, 0.12, 0.35), "in_lamp", 0.0, false, false)
			geo.box(Vector3(xl + 4.0 + i * 6.2, top - 0.22, 12.0 + row * 9.0), Vector3(0.03, 0.44, 0.03), "in_steel", 0.0, false, false) # its cable
	geo.end_object()
	# The truck yard: concrete pad onto the south loop road, two trucks backed
	# in at docks 2 and 5.
	k.haul(YARD, "pad")
	for i in range(docks.size()):
		k.map.register_entrance(Vector3(docks[i], 0.0, z1 + 3.0), "warehouse dock %d" % (i + 1))
	Vehicles.semi(geo, Vector3(docks[1], 0.02, z1 + 8.9), PI, "veh_paint1", "veh_trailer")
	Vehicles.semi(geo, Vector3(docks[4], 0.02, z1 + 8.9), PI, "veh_paint6", "veh_trailer")

# --- the parking garage --------------------------------------------------------------------------------------------

func _lv(i: int) -> float:
	return 0.12 + LEVEL * i

## Baked light for the garage's decks: no ground darkening, the covered
## floors a little dimmer than the roof deck.
func _gar_light(n: Vector3, p: Vector3) -> Color:
	var c: Color = geo.shade(n, 8.0)
	if p.y < _lv(4) - 0.2 and n.y > 0.5:
		c = Color(c.r * 0.7, c.g * 0.7, c.b * 0.72)
	elif n.y < -0.5:
		c = Color(c.r * 1.25, c.g * 1.25, c.b * 1.25)
	return c

func _garage() -> void:
	var g := GARAGE
	geo.begin_object("parking garage")
	var nx: int = 8
	var nz: int = 6
	var dx: float = g.size.x / nx
	var dz: float = g.size.y / nz
	# Ramp strips: x 20..44; k even south (z -81..-75.5), k odd north (z -122.5..-117).
	var ramp_x0: float = 20.0
	var ramp_x1: float = 44.0
	var rw: float = 5.6
	var strip_s := Rect2(ramp_x0, -75.4 - rw, ramp_x1 - ramp_x0, rw)
	var strip_n := Rect2(ramp_x0, -122.6, ramp_x1 - ramp_x0, rw)
	# The stair and lift core in the north-east corner.
	var st_o := Vector3(70.0, _lv(0), -122.6) # stair well's NW inner corner at its floor
	var st_w: float = 2.9
	var st_d: float = 6.0
	var lift_rect := Rect2(73.2, -122.6, 2.6, 2.6)
	var holes_core: Array = [k.stair_hole(st_o, st_w, st_d, LEVEL), lift_rect]
	geo.tint = Color(0.82, 0.82, 0.8)
	for lv in range(5):
		var y: float = _lv(lv)
		geo.light_fn = Callable(self, "_gar_light")
		var holes: Array = []
		if lv >= 1:
			holes.append(strip_s if (lv - 1) % 2 == 0 else strip_n)
			holes.append_array(holes_core)
		if lv == 0:
			geo.box(Vector3(g.get_center().x, y - 0.2, g.get_center().y), Vector3(g.size.x, 0.4, g.size.y), "gar_slab")
		else:
			k.slab_holes(g, y, 0.3, holes, "gar_slab")
		geo.light_fn = Callable()
		# Columns up to the next slab.
		if lv < 4:
			for ix in range(nx + 1):
				for iz in range(nz + 1):
					var cx: float = g.position.x + 0.3 + ix * (g.size.x - 0.6) / nx
					var cz: float = g.position.y + 0.3 + iz * (g.size.y - 0.6) / nz
					if Rect2(69.4, -123.5, 8.0, 11.0).has_point(Vector2(cx, cz)):
						continue
					geo.box(Vector3(cx, y + (LEVEL - 0.3) * 0.5, cz), Vector3(0.5, LEVEL - 0.3, 0.5), "concrete_old")
		# Parapet (crash barrier) round every upper level; open above it.
		if lv >= 1:
			var py: float = y + 0.45
			for s in [-1.0, 1.0]:
				geo.box(Vector3(g.get_center().x, py, g.get_center().y + s * (g.size.y * 0.5 - 0.15)), Vector3(g.size.x, 0.9, 0.3), "concrete_old")
				geo.box(Vector3(g.get_center().x + s * (g.size.x * 0.5 - 0.15), py, g.get_center().y), Vector3(0.3, 0.9, g.size.y - 0.6), "concrete_old")
		# Wheel stops, a few lamps under the slab above.
		if lv < 4:
			for i in range(10):
				geo.box(Vector3(g.position.x + 4.0 + i * 6.0, y + LEVEL - 0.45, g.get_center().y), Vector3(1.4, 0.1, 0.3), "lamp", 0.0, false, false)
				geo.box(Vector3(g.position.x + 4.0 + i * 6.0, y + LEVEL - 0.45, g.get_center().y - 16.0), Vector3(1.4, 0.1, 0.3), "lamp", 0.0, false, false)
				geo.box(Vector3(g.position.x + 4.0 + i * 6.0, y + LEVEL - 0.45, g.get_center().y + 16.0), Vector3(1.4, 0.1, 0.3), "lamp", 0.0, false, false)
	# The four ramps (13 % slopes): even ones along the south edge going east, odd ones along the north going west.
	for r in range(4):
		var ya: float = _lv(r)
		var yb: float = _lv(r + 1)
		var zc: float = strip_s.get_center().y if r % 2 == 0 else strip_n.get_center().y
		var a := Vector3(ramp_x0 if r % 2 == 0 else ramp_x1, ya, zc)
		var b := Vector3(ramp_x1 if r % 2 == 0 else ramp_x0, yb, zc)
		geo.light_fn = Callable(self, "_gar_light")
		geo.beam(a + Vector3(0, -0.15, 0), b + Vector3(0, -0.15, 0), Vector2(rw - 0.6, 0.3), "gar_slab")
		geo.light_fn = Callable()
		for s in [-1.0, 1.0]:
			geo.beam(a + Vector3(0, 0.45, s * (rw * 0.5 - 0.15)), b + Vector3(0, 0.45, s * (rw * 0.5 - 0.15)), Vector2(0.3, 0.9), "concrete_old")
		# A support wall under the middle.
		var mid: Vector3 = (a + b) * 0.5
		geo.box(Vector3(mid.x, ya + (mid.y - ya) * 0.5 - 0.05, zc), Vector3(0.5, mid.y - ya - 0.2, rw - 0.6), "concrete_old")
	# Stair and lift core: walls to the roof and a bit more, doorways on every level.
	var top: float = _lv(4) + 2.6
	var sd: Array = []
	var ld: Array = []
	for lv in range(5):
		sd.append(Rect2(st_o.x + 0.85, _lv(lv) + 0.02, 1.2, 2.2))
		ld.append(Rect2(lift_rect.position.x + 0.7, _lv(lv) + 0.02, 1.2, 2.2))
	var xs0: float = st_o.x - 0.15
	var xs1: float = st_o.x + st_w + 0.15
	k.wall("x", st_o.z - 0.15, xs0, xs1, -0.1, top, 0.3, [], "concrete_old")
	k.wall("x", st_o.z + st_d + 0.15, xs0, xs1, -0.1, top, 0.3, sd, "concrete_old")
	k.wall("z", xs0, st_o.z, st_o.z + st_d, -0.1, top, 0.3, [], "concrete_old")
	k.wall("z", xs1, st_o.z, st_o.z + st_d, -0.1, top, 0.3, [], "concrete_old")
	var lx0: float = xs1 + 0.15
	var lx1: float = lift_rect.end.x + 0.15
	k.wall("x", lift_rect.position.y - 0.15, lx0, lx1 + 0.15, -0.1, top, 0.3, [], "concrete_old")
	k.wall("x", lift_rect.end.y + 0.15, lx0, lx1, -0.1, top, 0.3, ld, "concrete_old")
	k.wall("z", lx1, lift_rect.position.y, lift_rect.end.y, -0.1, top, 0.3, [], "concrete_old")
	k.stair_well(Vector3(st_o.x, _lv(0), st_o.z), st_w, st_d, LEVEL, 4, "concrete_old")
	# A roof stair head and the lift's machine room are left open on purpose (fly down the shaft).
	# Cars (Fleet): about a third of the bays.
	var paints: Array = ["sedan", "hatch", "suv", "hatch", "van", "estate"]
	for lv in range(5):
		var y: float = _lv(lv) + 0.02
		for ix in range(nx):
			for sub in range(2):
				for iz in range(nz):
					if rng.randf() > 0.34:
						continue
					var px: float = g.position.x + ix * dx + 2.0 + sub * 3.6
					var pz: float = g.position.y + iz * dz + dz * 0.5
					var p2 := Vector2(px, pz)
					if strip_s.grow(1.8).has_point(p2) or strip_n.grow(1.8).has_point(p2) or Rect2(66, -124, 14, 14).has_point(p2):
						continue
					k.fleet.car(Vector3(px, y, pz), 0.0 if rng.randf() < 0.5 else PI, Fleet.random_paint(rng), paints[rng.randi() % paints.size()])
	geo.tint = Color.WHITE
	geo.end_object()
	k.map.register_entrance(Vector3(32.0, 0.0, g.end.y + 0.5), "garage ramp")
	k.map.register_entrance(Vector3(54.0, 0.0, g.end.y + 0.5), "garage level 0")

# --- pipe rack ----------------------------------------------------------------------------------------------------------

func _pipe_rack() -> void:
	IndustryCreator.pipe_rack(geo, k.map.get("land"), [Vector2(HALL.end.x, 36.0), Vector2(WARE.position.x, 36.0)], 5.8, 0.0)

# --- the foundation pit ---------------------------------------------------------------------------------------------------

func _pit() -> void:
	var p: Rect2 = CampusKit.PIT
	var d: float = CampusKit.PIT_DEPTH
	# (The pit floor and banks: bare earth draped on the terrain, ConstructionSite._site_ground.)
	geo.tint = Color.WHITE
	# The ramp: flat from the road to the bank, then down (a solid wedge).
	var pts: Array[Vector3] = []
	var x: float = -73.0
	while x >= -97.0:
		var t: float = clampf((-72.0 - x) / 24.0, 0.0, 1.0)
		pts.append(Vector3(x, -d * t, 86.0))
		x -= 2.0
	geo.sweep(pts, [Vector2(-4.2, -d - 1.2), Vector2(-4.0, 0.05), Vector2(4.0, 0.05), Vector2(4.2, -d - 1.2)], "mud", false, true, false)
	# The raft: blinding concrete, formwork boards round it, a rebar mat, column cages.
	var rf := Rect2(-136.0, 76.0, 34.0, 20.0)
	geo.box(Vector3(rf.get_center().x, -d + 0.2, rf.get_center().y), Vector3(rf.size.x, 0.3, rf.size.y), "concrete_old")
	for s in [-1.0, 1.0]:
		geo.box(Vector3(rf.get_center().x, -d + 0.65, rf.get_center().y + s * (rf.size.y * 0.5 + 0.1)), Vector3(rf.size.x + 0.4, 0.8, 0.12), "wood")
		geo.box(Vector3(rf.get_center().x + s * (rf.size.x * 0.5 + 0.1), -d + 0.65, rf.get_center().y), Vector3(0.12, 0.8, rf.size.y), "wood")
	for i in range(16):
		var q := Vector3(rf.position.x + 1.0 + i * 2.0, -d + 0.45, rf.end.y + 0.1)
		geo.beam(q + Vector3(0, 0.0, 1.6), q + Vector3(0, 0.8, 0.15), Vector2(0.08, 0.08), "wood", false, false)
	# Rebar: two layers of bars, every 0.5 m (thin, no collision).
	for i in range(0, 67):
		geo.box(Vector3(rf.position.x + 0.5 + i * 0.5, -d + 0.62, rf.get_center().y), Vector3(0.025, 0.025, rf.size.y - 0.8), "rebar", 0.0, false, false)
	for j in range(0, 39):
		geo.box(Vector3(rf.get_center().x, -d + 0.68, rf.position.y + 0.5 + j * 0.5), Vector3(rf.size.x - 0.8, 0.025, 0.025), "rebar", 0.0, false, false)
	# (the bars sit on spacers: small blocks)
	for i in range(8):
		for j in range(4):
			geo.box(Vector3(rf.position.x + 2.0 + i * 4.4, -d + 0.4, rf.position.y + 2.0 + j * 5.4), Vector3(0.15, 0.2, 0.15), "concrete_old", 0.0, false, false)
	# Column cages (rebar cages standing on the raft, 4 x 3).
	for i in range(4):
		for j in range(3):
			var cp := Vector3(rf.position.x + 5.0 + i * 8.0, -d + 0.35, rf.position.y + 3.5 + j * 6.5)
			for q in range(4):
				var o := Vector3((q % 2) * 0.7 - 0.35, 0, (q / 2) * 0.7 - 0.35)
				geo.cylinder(cp + o, cp + o + Vector3(0, 4.2, 0), 0.03, "rebar", 4, true, false, false)
			for h in range(5):
				geo.box(cp + Vector3(0, 0.6 + h * 0.8, 0), Vector3(0.78, 0.02, 0.78), "rebar", 0.0, false, false)
	# Excavator, a tipper, a pump hose down the ramp, a stack of formwork.
	Vehicles.excavator(geo, Vector3(-108.0, -d + 0.03, 98.0), 0.5, 0.5)
	Vehicles.tipper(geo, Vector3(-120.0, -d + 0.03, 100.0), 3.3, "veh_paint2", "mud")
	k.rebar_rack(Vector3(-143.0, -d + 0.03, 90.0), 0.0, 3)
	for lvl in range(4):
		geo.box(Vector3(-143.0, -d + 0.15 + lvl * 0.25, 78.0), Vector3(3.0, 0.22, 1.2), "wood")
	# A pump pipe down the ramp (on the ground, bent along it).
	geo.pipe_path(Route.rounded([Vector3(-70, 0.15, 88.0), Vector3(-72, 0.15, 88.0), Vector3(-96, -d + 0.15, 88.0), Vector3(-100, -d + 0.15, 88.0)], 1.0, 4), 0.1, "dark", 0.0, 8, false, false)
	# Tape round the edge, open at the ramp.
	var e: Rect2 = p.grow(9.5)
	k.tape(Vector3(e.position.x, 0, e.position.y), Vector3(e.end.x, 0, e.position.y))
	k.tape(Vector3(e.position.x, 0, e.position.y), Vector3(e.position.x, 0, e.end.y))
	k.tape(Vector3(e.position.x, 0, e.end.y), Vector3(e.end.x, 0, e.end.y))
	k.tape(Vector3(e.end.x, 0, e.position.y), Vector3(e.end.x, 0, 80.0))
	k.tape(Vector3(e.end.x, 0, 92.0), Vector3(e.end.x, 0, e.end.y))
	k.map.register_entrance(Vector3(-73.5, 0.0, 86.0), "pit ramp")
