class_name CampusTowers
extends RefCounted

## The three towers, the four tower cranes, the walkway bridges and the
## concrete pump of the Construction Site campus. All 34 x 34 m, 3.6 m
## storeys; each at a different stage:
##   T1  bare concrete core to 130 m with the climbing formwork on top,
##       slabs and columns up to floor 6
##   T2  steel frame to 112 m, decking on floors 1-16
##   T3  concrete frame to 144 m, glazed to floor 22, open frame and edge
##       nets above
## Each has a real lift shaft (2.7 x 2.7 m inside, open at every floor and
## at the top: fly up it), a stair well with a doorway per floor, and open
## floors with props and pallets. Hoists on T1 and T3.

const T1 := Vector3(-133, 0, -106)
const T2 := Vector3(-78, 0, -106)
const T3 := Vector3(-23, 0, -106)
const FH: float = 3.6
const HALF: float = 17.0
## The core, relative to a tower's centre: stair (x -5.35..-2.0), lift (x -2.0..1.0),
## riser (x 1.0..4.0), walls 0.3 thick.
const CORE := Rect2(-5.5, -3.65, 9.65, 7.3)
const WALL: float = 0.3

var k: CampusKit
var geo: Geo
var rng := RandomNumberGenerator.new()

func _init(kit: CampusKit) -> void:
	k = kit
	geo = kit.geo
	rng.seed = 7117

func build_all() -> void:
	_t1()
	_t2()
	_t3()
	_bridges()
	_cranes()
	_pump()
	for t: Vector3 in [T1, T2, T3]:
		k.map.register_entrance(Vector3(t.x, 0.0, t.z + HALF + 0.8), "tower entrance")

# --- shared: the core --------------------------------------------------------------------------

func _wall_x(o: Vector3, zc: float, x0: float, x1: float, h: float, holes: Array) -> void:
	BuildKit.wall(geo, Transform3D(Basis(), Vector3(o.x, 0, o.z + zc)), x0, x1, -0.3, h, WALL, holes, "concrete")

func _wall_z(o: Vector3, xc: float, z0: float, z1: float, h: float, holes: Array) -> void:
	BuildKit.wall(geo, Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(o.x + xc, 0, o.z)), z0, z1, -0.3, h, WALL, holes, "concrete")

## The core from the ground to height h: a stair well (west), the lift
## shaft (middle, 2.7 x 2.7 inside, a doorway in its south face at every
## floor, open at the top) and a closed riser (east). Doorways at every
## floor from 0 to `floors`. Stairs from the ground to `stair_floors`.
func core(o: Vector3, floors: int, stair_floors: int, h: float) -> void:
	var stair_doors: Array = []
	var lift_doors: Array = []
	for f in range(floors):
		stair_doors.append(Rect2(-4.55, f * FH + (0.15 if f == 0 else 0.02), 1.2, 2.2))
		lift_doors.append(Rect2(-1.1, f * FH + (0.15 if f == 0 else 0.02), 1.2, 2.2))
	_wall_z(o, -5.35, -3.65, 3.65, h, [])
	_wall_x(o, -3.5, -5.5, -2.0, h, [])
	_wall_x(o, 3.5, -5.5, -2.0, h, stair_doors)
	_wall_z(o, -2.0, -3.5, 3.5, h, [])
	_wall_x(o, -1.5, -2.0, 1.0, h, [])
	_wall_x(o, 1.5, -2.0, 1.0, h, lift_doors)
	_wall_z(o, 1.0, -1.5, 1.5, h, [])
	_wall_x(o, -1.5, 1.0, 4.0, h, [])
	_wall_x(o, 1.5, 1.0, 4.0, h, [])
	_wall_z(o, 4.0, -1.5, 1.5, h, [])
	# Stairs: a dog-leg per storey in the well (inner 3.05 x 6.7 m).
	k.stair_well(Vector3(o.x - 5.2, 0.0, o.z - 3.35), 3.05, 6.7, FH, stair_floors)
	# The lift: guide rails on the shaft's back wall (not in the way).
	for gx in [-1.5, 0.5]:
		geo.box(Vector3(o.x + gx, h * 0.5, o.z - 1.3), Vector3(0.1, h, 0.1), "steel", 0.0, false, false)
	# The shaft's floor (a pit) and the landing in front of it.
	geo.box(Vector3(o.x - 0.5, 0.05, o.z), Vector3(2.8, 0.2, 2.8), "concrete")

## A slab (top at y) over the footprint with the core cut out.
func slab(o: Vector3, y: float, th: float, mat: String, half: float = HALF) -> void:
	var r := Rect2(o.x - half, o.z - half, half * 2.0, half * 2.0)
	var hole := Rect2(o.x + CORE.position.x - 0.15, o.z + CORE.position.y - 0.15, CORE.size.x + 0.3, CORE.size.y + 0.3)
	k.slab_holes(r, y, th, [hole], mat)

## Column positions on the 8 m grid (none in the core).
func col_grid() -> Array[Vector2]:
	var out: Array[Vector2] = []
	for ix in range(5):
		for iz in range(5):
			var c := Vector2(-16.0 + ix * 8.0, -16.0 + iz * 8.0)
			if CORE.grow(1.2).has_point(c):
				continue
			out.append(c)
	return out

## Yellow edge-protection net band round a floor.
func edge_net(o: Vector3, y: float, half: float = HALF) -> void:
	for side in range(4):
		var along_x: bool = side < 2
		var s: float = 1.0 if side % 2 == 0 else -1.0
		var pos: Vector3 = o + (Vector3(0, y + 0.55, s * (half - 0.05)) if along_x else Vector3(s * (half - 0.05), y + 0.55, 0))
		geo.box(pos, Vector3(half * 2.0, 0.9, 0.05) if along_x else Vector3(0.05, 0.9, half * 2.0), "net", 0.0, false, false)
		# Posts every 4 m.
		for i in range(9):
			var t: float = -half + i * half * 0.25
			var pp: Vector3 = o + (Vector3(t, y, s * (half - 0.05)) if along_x else Vector3(s * (half - 0.05), y, t))
			geo.cylinder(pp, pp + Vector3(0, 1.1, 0), 0.03, "steel", 4, true, false, false)

## Rebar starter bars on the columns of a top slab.
func starters(o: Vector3, y: float) -> void:
	for c in col_grid():
		if absf(c.x) != 16.0 and absf(c.y) != 16.0:
			continue
		for j in range(4):
			var q: Vector3 = o + Vector3(c.x + (j % 2) * 0.4 - 0.2, y, c.y + (j / 2) * 0.4 - 0.2)
			geo.cylinder(q, q + Vector3(0, 1.4, 0), 0.03, "rebar", 4, true, false, false)

# --- T1: the bare concrete core --------------------------------------------------------------------

func _t1() -> void:
	var o: Vector3 = T1
	var F: int = 36
	var top: float = (F + 2) * FH
	geo.begin_object("tower T1")
	# The raft and the six decked storeys.
	geo.box(o + Vector3(0, -0.05, 0), Vector3(HALF * 2.0 + 1.0, 0.3, HALF * 2.0 + 1.0), "concrete_old")
	for f in range(0, 6):
		for c in col_grid():
			geo.box(o + Vector3(c.x, f * FH + FH * 0.5 - 0.1, c.y), Vector3(0.8, FH - 0.2, 0.8), "concrete")
		slab(o, (f + 1) * FH, 0.3, "concrete")
		if f > 0:
			edge_net(o, f * FH)
	edge_net(o, 6 * FH)
	core(o, F + 2, F + 2, top)
	starters(o, 6 * FH)
	for f in range(1, 6):
		k.floor_pallets(o, HALF * 2.0, HALF * 2.0, f * FH, CORE, 3)
	k.props(o + Vector3(-12, 3 * FH, 6), Vector3(1.2, 0, 0), 6, 1.2, FH - 0.3)
	# Climbing formwork round the head of the core.
	_climbing(o, (F - 2) * FH, top)
	# Hoist on the east face up to the formwork.
	k.hoist(o + Vector3(HALF + 2.4, 0, 0.0), top - 4.0, Vector3(-1, 0, 0), 2.4 + HALF - CORE.end.x + 0.1, 10.0)
	geo.end_object()

## The climbing formwork: a ring platform outside the core, red
## screens on three sides, brackets back to the walls.
func _climbing(o: Vector3, y: float, top: float) -> void:
	var c := Rect2(o.x + CORE.position.x, o.z + CORE.position.y, CORE.size.x, CORE.size.y)
	var outer: Rect2 = c.grow(2.6)
	for pr in CampusKit.rect_minus_merged(outer, [c.grow(0.05)]):
		geo.box(Vector3(pr.get_center().x, y - 0.1, pr.get_center().y), Vector3(pr.size.x, 0.2, pr.size.y), "steel")
	# Brackets under the platform back to the core walls.
	for t in [-0.35, 0.0, 0.35]:
		for s in [-1.0, 1.0]:
			geo.beam(Vector3(c.position.x + c.size.x * (0.5 + t), y - 0.2, c.get_center().y + s * (c.size.y * 0.5 + 2.4)), Vector3(c.position.x + c.size.x * (0.5 + t), y - 2.6, c.get_center().y + s * (c.size.y * 0.5)), Vector2(0.25, 0.25), "steel")
		for s in [-1.0, 1.0]:
			geo.beam(Vector3(c.get_center().x + s * (c.size.x * 0.5 + 2.4), y - 0.2, c.position.y + c.size.y * (0.5 + t)), Vector3(c.get_center().x + s * (c.size.x * 0.5), y - 2.6, c.position.y + c.size.y * (0.5 + t)), Vector2(0.25, 0.25), "steel")
	# Screens (open on the south side: a way onto the platform) and the guard rail.
	var h: float = top - y + 2.4
	for side in range(3):
		var s: float = 1.0 if side % 2 == 0 else -1.0
		var pos: Vector3
		var size: Vector3
		if side == 0:
			pos = Vector3(c.get_center().x, y + h * 0.5, c.position.y - 2.5)
			size = Vector3(outer.size.x - 0.4, h, 0.2)
		elif side == 1:
			pos = Vector3(c.position.x - 2.5, y + h * 0.5, c.get_center().y)
			size = Vector3(0.2, h, outer.size.y - 0.4)
		else:
			pos = Vector3(c.end.x + 2.5, y + h * 0.5, c.get_center().y)
			size = Vector3(0.2, h, outer.size.y - 0.4)
		geo.box(pos, size, "screen")
		var along_x: bool = side == 0
		var n: int = int((size.x if along_x else size.z) / 2.4)
		for i in range(n + 1):
			var t: float = -(size.x if along_x else size.z) * 0.5 + 0.2 + i * ((size.x if along_x else size.z) - 0.4) / n
			var rp: Vector3 = pos + (Vector3(t, 0, -0.14) if along_x else Vector3(-0.14 if side == 1 else 0.14, 0, t))
			geo.box(rp, Vector3(0.12, h, 0.08) if along_x else Vector3(0.08, h, 0.12), "screen_rib", 0.0, true, false)
	# Rail on the open south side.
	geo.box(Vector3(c.get_center().x, y + 0.9, c.end.y + 2.5), Vector3(outer.size.x - 0.4, 0.06, 0.06), "tape", 0.0, false, false)
	# Rebar starter bars sticking out of the core's top.
	for i in range(5):
		var q := Vector3(c.position.x + 0.3 + i * 0.7, top, c.position.y + 0.15)
		geo.cylinder(q, q + Vector3(0, 1.3, 0), 0.03, "rebar", 4, true, false, false)

# --- T2: the steel frame -------------------------------------------------------------------------------

func _t2() -> void:
	var o: Vector3 = T2
	var F: int = 31
	var top: float = F * FH
	geo.begin_object("tower T2")
	geo.box(o + Vector3(0, -0.05, 0), Vector3(HALF * 2.0 + 1.0, 0.3, HALF * 2.0 + 1.0), "concrete_old")
	var cols: Array[Vector2] = col_grid()
	for f in range(F):
		var y: float = f * FH
		for c in cols:
			geo.box(o + Vector3(c.x, y + FH * 0.5, c.y), Vector3(0.45, FH, 0.45), "steel_primer")
		if f == 0:
			continue
		# Beams at this floor (x-beams a little taller than the z-beams: no coplanar tops).
		for iz in range(5):
			var z: float = -16.0 + iz * 8.0
			if iz == 2: # (not through the core)
				geo.box(o + Vector3(-11.0, y - 0.2, z), Vector3(10.0, 0.4, 0.25), "steel_primer")
				geo.box(o + Vector3(10.1, y - 0.2, z), Vector3(11.8, 0.4, 0.25), "steel_primer")
			else:
				geo.box(o + Vector3(0, y - 0.2, z), Vector3(32.0, 0.4, 0.25), "steel_primer")
		for ix in range(5):
			var x: float = -16.0 + ix * 8.0
			if ix == 2:
				geo.box(o + Vector3(x, y - 0.23, -10.0), Vector3(0.25, 0.34, 12.0), "steel_primer")
				geo.box(o + Vector3(x, y - 0.23, 10.0), Vector3(0.25, 0.34, 12.0), "steel_primer")
			else:
				geo.box(o + Vector3(x, y - 0.23, 0), Vector3(0.25, 0.34, 32.0), "steel_primer")
		if f <= 16:
			# Decking (a thin steel deck on the beams), the core left open.
			slab(o, y + 0.06, 0.1, "steel", HALF - 0.8)
			if f > 1:
				edge_net(o, y, 16.0)
		# Cross bracing in one bay per face, every other storey.
		if f % 2 == 0:
			for side in range(4):
				var along_x: bool = side < 2
				var s: float = 1.0 if side % 2 == 0 else -1.0
				var a: Vector3 = o + (Vector3(-16, y - FH, s * 16) if along_x else Vector3(s * 16, y - FH, -16))
				var b: Vector3 = o + (Vector3(-8, y, s * 16) if along_x else Vector3(s * 16, y, -8))
				geo.beam(a, b, Vector2(0.18, 0.18), "steel_primer", false, false)
				geo.beam(o + (Vector3(-8, y - FH, s * 16) if along_x else Vector3(s * 16, y - FH, -8)), o + (Vector3(-16, y, s * 16) if along_x else Vector3(s * 16, y, -16)), Vector2(0.18, 0.18), "steel_primer", false, false)
	# The concrete core to the top, stairs and lift all the way.
	core(o, F + 1, F + 1, (F + 1) * FH + 1.0)
	for f in range(1, 16):
		k.floor_pallets(o, HALF * 2.0, HALF * 2.0, f * FH + 0.06, CORE, 2)
	# A bundle of beams and a stack of decking on the 16th floor.
	for j in range(3):
		geo.box(o + Vector3(8.0, 16 * FH + 0.4 + j * 0.3, 9.0), Vector3(0.4, 0.28, 8.0), "steel_blue")
	k.props(o + Vector3(-12, 8 * FH + 0.06, -12), Vector3(1.4, 0, 0), 5, 1.2, FH - 0.5)
	geo.end_object()

# --- T3: glazed to floor 22, open frame above --------------------------------------------------------------

func _t3() -> void:
	var o: Vector3 = T3
	var F: int = 40
	var top: float = F * FH
	geo.begin_object("tower T3")
	geo.box(o + Vector3(0, -0.05, 0), Vector3(HALF * 2.0 + 1.0, 0.3, HALF * 2.0 + 1.0), "concrete_old")
	var cols: Array[Vector2] = col_grid()
	for f in range(F):
		var y: float = f * FH
		for c in cols:
			geo.box(o + Vector3(c.x, y + FH * 0.5 - 0.1, c.y), Vector3(0.8, FH - 0.2, 0.8), "concrete")
		slab(o, y + FH, 0.3, "concrete")
		if f < 22:
			# Curtain wall bays between the columns (a few missing: not finished).
			for side in range(4):
				var along_x: bool = side < 2
				var s: float = 1.0 if side % 2 == 0 else -1.0
				for b in range(4):
					var t: float = -12.0 + b * 8.0
					if f == 0 and side == 1 and b in [1, 2]:
						continue # the entrance: two open bays on the south face
					if f > 1 and rng.randf() < 0.14:
						continue
					var pos: Vector3 = o + (Vector3(t, y + FH * 0.5, s * (HALF + 0.1)) if along_x else Vector3(s * (HALF + 0.1), y + FH * 0.5, t))
					geo.box(pos, Vector3(7.2, FH - 0.4, 0.12) if along_x else Vector3(0.12, FH - 0.4, 7.2), "glass_panel")
		elif f >= 22:
			edge_net(o, y)
		if f >= 23 and f % 3 == 0:
			k.floor_pallets(o, HALF * 2.0, HALF * 2.0, y, CORE, 2)
	edge_net(o, top)
	core(o, F + 1, F + 1, top + 3.0)
	starters(o, top)
	for f in [9, 17, 22, 28, 34]:
		k.props(o + Vector3(-12, f * FH, 8), Vector3(1.4, 0, 0), 5, 1.2, FH - 0.3)
	# Hoist on the west face.
	k.hoist(o + Vector3(-HALF - 2.4, 0, 0.0), 92.0, Vector3(1, 0, 0), 2.6, 10.0)
	geo.end_object()

# --- walkway bridges ------------------------------------------------------------------------------------------

func _bridges() -> void:
	_walkway(Vector3(T1.x + HALF, 4 * FH, -100.0), Vector3(T2.x - HALF, 4 * FH, -100.0))
	_walkway(Vector3(T2.x + HALF, 10 * FH, -104.0), Vector3(T3.x - HALF, 10 * FH, -104.0))
	_walkway(Vector3(T2.x + HALF, 16 * FH, -96.0), Vector3(T3.x - HALF, 16 * FH, -96.0))

## A covered steel truss walkway between two towers: deck and girders
## underneath, a truss on each side (chords, verticals, diagonals), a roof.
func _walkway(a: Vector3, b: Vector3) -> void:
	var L: float = b.x - a.x
	var W: float = 2.6
	var Ht: float = 2.8
	var y: float = a.y
	var mx: float = (a.x + b.x) * 0.5
	geo.box(Vector3(mx, y - 0.1, a.z), Vector3(L + 0.6, 0.25, W + 0.2), "steel")
	for s in [-1.0, 1.0]:
		geo.box(Vector3(mx, y - 0.5, a.z + s * (W * 0.5 - 0.1)), Vector3(L + 0.6, 0.55, 0.25), "steel_blue")
		geo.box(Vector3(mx, y + Ht, a.z + s * (W * 0.5 + 0.05)), Vector3(L + 0.6, 0.22, 0.22), "steel_blue")
		geo.box(Vector3(mx, y + 0.45, a.z + s * (W * 0.5 + 0.05)), Vector3(L + 0.6, 0.12, 0.12), "steel_blue")
	var n: int = int(L / 3.0)
	var step: float = L / n
	for i in range(n + 1):
		var x: float = a.x + i * step
		for s in [-1.0, 1.0]:
			geo.box(Vector3(x, y + Ht * 0.5, a.z + s * (W * 0.5 + 0.05)), Vector3(0.18, Ht, 0.18), "steel_blue")
			if i < n:
				var x1: float = x + step
				var up: bool = i % 2 == 0
				geo.beam(Vector3(x, y + 0.45 if up else y + Ht, a.z + s * (W * 0.5 + 0.05)), Vector3(x1, y + Ht if up else y + 0.45, a.z + s * (W * 0.5 + 0.05)), Vector2(0.12, 0.12), "steel_blue")
		geo.box(Vector3(x, y + Ht + 0.05, a.z), Vector3(0.12, 0.12, W + 0.2), "steel_blue", 0.0, true, false)
	geo.box(Vector3(mx, y + Ht + 0.2, a.z), Vector3(L + 0.4, 0.06, W + 0.5), "cabin", 0.0, true, false)
	# A guard rail across the open end, a light.
	geo.box(Vector3(mx, y + Ht - 0.3, a.z), Vector3(1.2, 0.1, 0.1), "lamp", 0.0, false, false)
	geo.box(Vector3(mx, y + Ht - 0.02, a.z), Vector3(0.03, 0.46, 0.03), "steel_blue", 0.0, false, false) # its hanger (it hung free)

# --- cranes ---------------------------------------------------------------------------------------------------------

## Tie targets at the tower faces: [[y, point, spread], ...] for a crane at
## `base`. Up to `slab_to` m the struts end in the slab edge (or the frame's
## edge beam, at `face` m from the centre), higher up in the core's wall.
func _ties(base: Vector3, tower: Vector3, heights: Array, slab_to: float = 1e9, face: float = 16.7) -> Array:
	var out: Array = []
	var dx: float = signf(base.x - tower.x)
	for hh: float in heights:
		var yy: float = roundf(hh / FH) * FH
		if yy <= slab_to:
			var ty: float = yy - (0.15 if face > 16.5 else 0.2)
			out.append([ty, Vector3(tower.x + dx * face, ty, clampf(base.z, tower.z - 12.0, tower.z + 12.0)), 1.4])
		else:
			out.append([yy, Vector3(tower.x + (CORE.end.x - 0.2 if dx > 0.0 else CORE.position.x + 0.2), yy, tower.z), 0.8])
	return out

func _cranes() -> void:
	# Crane 1 carries the gnome (Easter egg, 10 %): its own random stream
	# seeded 5153 - the first draw (0.092) is under 0.10, so it shows; the
	# map's rng draws are not touched.
	var egg_rng := RandomNumberGenerator.new()
	egg_rng.seed = 5150 + 3
	var gnome: bool = egg_rng.randf() < 0.10
	var c1 := Vector3(-105.5, 0, -111)
	k.crane(c1, 164.0, 62.0, 80.0, "gnome" if gnome else "rebar", 0.62, 70.0, _ties(c1, T1, [14.4, 36, 61, 90, 118], 5 * FH))
	var c2 := Vector3(-50.5, 0, -111)
	k.crane(c2, 159.0, 60.0, 115.0, "beam", 0.55, 30.0, _ties(c2, T3, [18, 47, 76, 105, 134]))
	var c3 := Vector3(8.0, 0, -111)
	k.crane(c3, 169.0, 64.0, 70.0, "bucket", 0.7, 36.0, _ties(c3, T3, [25, 54, 83, 112, 141]))
	var c4 := Vector3(-105.5, 0, -90)
	k.crane(c4, 154.0, 58.0, 25.0, "panel", 0.5, 28.0, _ties(c4, T2, [22, 51, 80, 109], 1e9, 16.0))

# --- the concrete pump at T3 -------------------------------------------------------------------------------------

func _pump() -> void:
	var p := Vector3(T3.x + 11.0, 0, T3.z + HALF + 11.0)
	# The truck (stationary pump): chassis, cab, hopper, outriggers.
	geo.box(p + Vector3(0, 1.3, 0), Vector3(12.0, 1.2, 2.5), "hoarding_w")
	geo.prism(Transform3D(Basis(Vector3.UP, PI * 0.5), p), [Vector2(-6.0, 1.9), Vector2(-6.05, 3.2), Vector2(-4.4, 3.2), Vector2(-4.4, 1.9)], 2.4, "hoarding_w")
	for sz in [-1.0, 1.0]:
		for x in [-4.5, -3.0, 2.0, 3.5]:
			geo.cylinder(p + Vector3(x, 0.55, sz * 1.35), p + Vector3(x, 0.55, sz * 0.95), 0.55, "veh_tyre", 10)
		geo.beam(p + Vector3(-3.0, 1.2, sz * 1.2), p + Vector3(-5.0, 0.3, sz * 4.5), Vector2(0.3, 0.3), "hoarding_w")
		geo.beam(p + Vector3(3.0, 1.2, sz * 1.2), p + Vector3(5.0, 0.3, sz * 4.5), Vector2(0.3, 0.3), "hoarding_w")
	geo.frustum(Transform3D(Basis(), p + Vector3(3.5, 2.6, 0)), Vector3(2.0, 1.6, 2.2), 1.2, 1.6, 0.0, "steel")
	# The riser pipe up the face of T3 to the top deck, clamped to the slab edges.
	var top: float = 40 * FH
	var rx: float = T3.x + 11.0
	var rz: float = T3.z + HALF + 1.5
	var path: Array[Vector3] = [p + Vector3(2.5, 3.4, 0), Vector3(rx, 3.4, p.z - 2.0), Vector3(rx, 3.4, rz), Vector3(rx, top + 1.0, rz)]
	geo.pipe_path(Route.rounded(path, 0.9, 5), 0.13, "crane_red", 0.0, 8, true, false)
	var y: float = 3.6
	while y < top:
		geo.beam(Vector3(rx, y, rz), Vector3(rx, y, T3.z + HALF - 0.3), Vector2(0.1, 0.1), "steel", false, false)
		y += FH * 2.0
	# The placing boom folded on the top deck.
	var bp := Vector3(rx, top + 1.0, rz)
	geo.beam(bp, bp + Vector3(-9.0, 0.0, -9.0), Vector2(0.3, 0.3), "crane_red")
	geo.beam(bp + Vector3(-9.0, 0.0, -9.0), bp + Vector3(-18.0, 1.0, -9.5), Vector2(0.25, 0.25), "crane_red")
	geo.beam(bp + Vector3(-18.0, 1.0, -9.5), bp + Vector3(-19.0, -3.0, -9.5), Vector2(0.15, 0.15), "dark", false, false)
