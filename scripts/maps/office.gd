extends BuiltMap

## Office - a Tiny Whoop race on the 5th floor of an open-plan office
## (Low performance). 36 x 22 m, 3 m ceiling. Four rows of desk
## clusters, a glass meeting room, a kitchen corner, reception. Whoop
## gates are 60 cm (typical whoop-race size), on floor stands, poles
## and one on a desk. Course (fly order, north = -z):
##   START (-11,-3.5) east -> (0,-3.5) -> (7,0.5) south -> (2,8.5) west
##   -> (-6,8.5) on a table -> (-13,2) north -> START.
## Windows are real glass (collides - no flying out); a city below.

## Rebuilt 2026-10-10 for the race mode rework (6 tracks per race map,
## DEV_TODO "Race mode rework"): the empty east half is furnished as
## places the tracks can use (ANCHORS) - the meeting room got a second
## door (fly through it), a lounge with a ping-pong table, a server room
## with rack aisles, two phone booths by the reception. Track 1 is the
## course below, unchanged (its line stays clear of all of them).
const ROOM := AABB(Vector3(-18, 0, -11), Vector3(36, 3.0, 22))
const ANCHORS: Dictionary = {
	"meeting": Rect2(8, -11, 10, 8), ## doors: west wall z -5..-4, south wall x 15.6..16.6
	"lounge": Rect2(10, -1.5, 7.5, 5.5), ## sofas, ping-pong table at (13.5, 1) - under, over, round
	"server": Rect2(11.5, 5.5, 6.5, 5.5), ## door in the west wall z 7..8; two rack aisles running east-west
	"booths": [Vector3(-6.5, 0, -10.1), Vector3(-3.5, 0, -10.1)], ## phone booths, open fronts facing south
	"open": Rect2(4, -2, 5, 12), ## kept clear: gates of the other tracks
}
## The garden gnome: on top of the server rack by the window.
const GNOME := Transform3D(Basis(Vector3.UP, 2.4), Vector3(15.9, 2.0, 9.4))

var course: RaceCourse

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-35, 150, 0), "fog_density": 0.002, "ambient_energy": 1.35}

func check_border() -> void:
	WorldBorder.check_box(drone, ui, ROOM.position, ROOM.end, 12.0, get_tree())

func preview_views() -> Array:
	return [
		["overview", Vector3(-17, 2.7, 10), Vector3(5, 0.5, -6)],
		["start", Vector3(-15, 0.7, -3.5), Vector3(0, 0.6, -3.5)],
		["meeting", Vector3(6, 1.5, -2), Vector3(14, 0.8, -8)],
		["kitchen", Vector3(-8, 1.6, 4), Vector3(-16, 0.8, 9)],
		["lounge", Vector3(8, 1.4, 4), Vector3(14, 0.6, 0)],
		["server", Vector3(11, 1.2, 7.5), Vector3(17, 1.0, 7.5)],
		["meeting_door", Vector3(16, 1.0, 1), Vector3(16, 0.9, -6)],
		["booths", Vector3(-5, 1.3, -5), Vector3(-5, 1.0, -10)],
		["gnome", Vector3(13.8, 2.6, 8.2), Vector3(15.9, 2.0, 9.4)],
	]

func build() -> void:
	geo.ao_height = 0.8
	geo.ao_min = 0.65
	RaceCourse.add_materials(geo)
	geo.add_material("carpet", Geo.tex_mat(MapTextures.get_tex("fabric"), Color(0.42, 0.44, 0.5), 0.8))
	geo.add_material("wall", Geo.flat_mat(Color(0.9, 0.9, 0.88)))
	geo.add_material("ceiling", Geo.flat_mat(Color(0.95, 0.95, 0.95)))
	geo.add_material("lamp", Geo.glow_mat(Color(1, 1, 0.97), 1.2))
	geo.add_material("desk", Geo.flat_mat(Color(0.82, 0.8, 0.76)))
	geo.add_material("metal", Geo.flat_mat(Color(0.35, 0.36, 0.38)))
	geo.add_material("screen", Geo.flat_mat(Color(0.06, 0.07, 0.09)))
	geo.add_material("chair", Geo.flat_mat(Color(0.15, 0.16, 0.2)))
	geo.add_material("wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color.WHITE, 1.2))
	geo.add_material("plant", Geo.flat_mat(Color(0.2, 0.45, 0.2)))
	geo.add_material("pot", Geo.flat_mat(Color(0.85, 0.85, 0.82)))
	geo.add_material("accent", Geo.flat_mat(Color(0.12, 0.43, 0.88)))
	geo.add_material("city", Geo.flat_mat(Color(0.62, 0.64, 0.68)))
	geo.add_material("street", Geo.flat_mat(Color(0.3, 0.31, 0.33)))
	var glass := Geo.flat_mat(Color(0.7, 0.85, 0.95, 0.22))
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	geo.add_material("glass", glass)

	var r: AABB = ROOM
	geo.slab(Rect2(r.position.x, r.position.z, r.size.x, r.size.z), 0.0, 0.3, "carpet")
	geo.box(Vector3(0, 3.1, 0), Vector3(r.size.x, 0.2, r.size.z), "ceiling")
	for i in range(7):
		for j in range(4):
			geo.box(Vector3(-15 + i * 5, 2.98, -7.5 + j * 5), Vector3(1.2, 0.04, 0.6), "lamp", 0.0, false, false)
	_outer_walls()
	_desks()
	_meeting_room(Rect2(8, -11, 10, 8))
	_kitchen()
	_lounge()
	_server_room()
	_booths()
	for p in [Vector3(-10, 0, -5), Vector3(-10, 0, 5), Vector3(5.5, 0, 5)]:
		geo.box(p + Vector3(0, 1.5, 0), Vector3(0.5, 3.0, 0.5), "wall")
	for p in [Vector3(-17, 0, -10), Vector3(17, 0, 10), Vector3(5, 0, -10)]:
		geo.cylinder(p, p + Vector3(0, 0.45, 0), 0.25, "pot", 10)
		geo.lathe(p + Vector3(0, 0.45, 0), [Vector2(0.2, 0), Vector2(0.45, 0.4), Vector2(0.35, 1.0), Vector2(0.05, 1.3)], "plant", 9)
	_city()


func after_build() -> void:
	course = RaceCourse.make(self, tracks(), {"ao_height": 0.8, "ao_min": 0.65})
	course.setup("office", drone, ui)
	Collectibles.gnome(self, "office", 0, GNOME)

## Outer walls: solid below 0.9 m and above 2.6 m, glass between.
func _outer_walls() -> void:
	var r: AABB = ROOM
	var sides := [[Vector3(0, 0, r.position.z), Vector3(r.size.x, 0, 0.2)], [Vector3(0, 0, r.end.z), Vector3(r.size.x, 0, 0.2)],
		[Vector3(r.position.x, 0, 0), Vector3(0.2, 0, r.size.z)], [Vector3(r.end.x, 0, 0), Vector3(0.2, 0, r.size.z)]]
	for sd in sides:
		var c: Vector3 = sd[0]
		var sz: Vector3 = sd[1]
		geo.box(c + Vector3(0, 0.45, 0), sz + Vector3(0, 0.9, 0), "wall")
		geo.box(c + Vector3(0, 2.8, 0), sz + Vector3(0, 0.4, 0), "wall")
		geo.box(c + Vector3(0, 1.75, 0), sz + Vector3(0, 1.7, 0), "glass", 0.0, true, false)

func _desks() -> void:
	# Clusters of four desks (two facing two), each with monitor + chair.
	for row in [-6.0, -1.0, 4.0]:
		for cx in [-8.0, -4.6, -1.2, 2.2]:
			for dz in [-0.4, 0.4]:
				for dx in [-0.8, 0.8]:
					var p := Vector3(cx + dx, 0, row + dz)
					geo.box(p + Vector3(0, 0.73, 0), Vector3(1.56, 0.03, 0.78), "desk")
					geo.box(p + Vector3(0, 0.36, 0), Vector3(1.5, 0.72, 0.03), "metal")
					geo.box(p + Vector3(0, 1.0, dz * 0.4), Vector3(0.6, 0.36, 0.03), "screen")
					geo.box(p + Vector3(0, 0.8, dz * 0.4), Vector3(0.05, 0.14, 0.05), "metal")
					var chair := p + Vector3(0, 0, dz * 2.2)
					geo.box(chair + Vector3(0, 0.46, 0), Vector3(0.5, 0.08, 0.5), "chair")
					geo.box(chair + Vector3(0, 0.8, 0.25 * signf(dz)), Vector3(0.48, 0.6, 0.06), "chair")
					geo.cylinder(chair + Vector3(0, 0.05, 0), chair + Vector3(0, 0.42, 0), 0.03, "metal", 6)

func _meeting_room(rr: Rect2) -> void:
	# Glass walls on the open-office sides, a door gap facing the desks.
	geo.box(Vector3(rr.position.x, 1.5, rr.get_center().y - 1.0), Vector3(0.05, 3.0, rr.size.y - 2.0), "glass", 0.0, true, false)
	geo.box(Vector3(rr.position.x, 1.5, rr.end.y - 0.5), Vector3(0.05, 3.0, 1.0), "glass", 0.0, true, false)
	# South wall: glass with a second door near the east end (x 15.6..16.6).
	geo.box(Vector3((rr.position.x + 15.6) * 0.5, 1.5, rr.end.y), Vector3(15.6 - rr.position.x, 3.0, 0.05), "glass", 0.0, true, false)
	geo.box(Vector3((16.6 + rr.end.x) * 0.5, 1.5, rr.end.y), Vector3(rr.end.x - 16.6, 3.0, 0.05), "glass", 0.0, true, false)
	geo.box(Vector3(16.1, 2.55, rr.end.y), Vector3(1.0, 0.9, 0.05), "glass", 0.0, true, false)
	var c := Vector3(rr.get_center().x, 0, rr.get_center().y)
	geo.box(c + Vector3(0, 0.74, 0), Vector3(5, 0.05, 1.8), "wood")
	for dx in [-2.0, 2.0]:
		geo.box(c + Vector3(dx, 0.36, 0), Vector3(0.08, 0.72, 1.4), "metal")
	for i in range(4):
		for s in [-1.3, 1.3]:
			geo.box(c + Vector3(-1.8 + i * 1.2, 0.46, s), Vector3(0.5, 0.08, 0.5), "accent")
	geo.box(Vector3(rr.end.x - 0.15, 1.5, c.z), Vector3(0.05, 1.2, 2.4), "desk") # whiteboard

func _kitchen() -> void:
	geo.box(Vector3(-17.6, 0.45, 8), Vector3(0.6, 0.9, 6), "desk")
	geo.box(Vector3(-15, 0.45, 10.6), Vector3(5, 0.9, 0.6), "desk")
	geo.box(Vector3(-17.6, 0.95, 8), Vector3(0.62, 0.04, 6.02), "wood")
	geo.box(Vector3(-17.6, 1.0, 11.0 - 0.4), Vector3(0.7, 2.0, 0.7), "metal") # fridge
	geo.box(Vector3(-14, 1.05, 7), Vector3(1.6, 0.05, 0.8), "wood")          # bar table
	geo.box(Vector3(-14, 0.52, 7), Vector3(0.1, 1.04, 0.1), "metal")
	geo.box(Vector3(-12, 0.5, -9), Vector3(4, 1.0, 1.2), "accent")            # reception desk

## The city 20 m below the windows: the street grid round this block
## (out into the haze), traffic, blocks and towers.
func _city() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var roads := Roads.new(geo, rng, fleet)
	var city := City.new(geo, rng, fleet)
	var y: float = -20.0
	geo.add_material("ground_far", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 0, 0.3))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), y, 0.5, "ground_far", false)
	var xs: Array = [-150.0, -50.0, 50.0, 150.0]
	var zs: Array = [-130.0, -40.0, 40.0, 130.0]
	var blocks: Array[Rect2] = roads.grid(xs, zs, [12.0, 14.0, 14.0, 12.0], [12.0, 14.0, 14.0, 12.0], 3.0, y, {"n": 1500.0, "s": 1500.0, "w": 1500.0, "e": 1500.0}, {"traffic": 18.0, "lamps": 32.0, "detail": 300.0})
	for r: Rect2 in blocks:
		if r.has_point(Vector2(0, 0)):
			continue # this building's block
		if r.get_center().length() > 130.0:
			city.filler_block(r, y, 4, 10)
		elif rng.randf() < 0.3:
			city.tower(r, y, rng.randf_range(35.0, 80.0))
		else:
			city.perimeter_block(r, y, 5, 9)
	for i in range(-6, 6):
		for j in range(-6, 6):
			var c := Vector2(i * 100.0 + 50.0, j * 90.0 + 45.0)
			if absf(c.x) < 170.0 and absf(c.y) < 150.0:
				continue
			city.filler_block(Rect2(c.x - 38.0, c.y - 33.0, 76.0, 66.0), y, 4, 12)
	# This building's own shell below the office floor.
	geo.box(Vector3(0, -10.2, 0), Vector3(36.4, 20, 22.4), "wall", 0.0, false, false)

## Lounge: an L-sofa, two beanbags, a coffee table, a floor lamp, and the
## ping-pong table (a 2.74 x 1.525 m table, 76 cm high, net 15.25 cm).
func _lounge() -> void:
	var a: Rect2 = ANCHORS.lounge
	var x0: float = a.position.x
	var z1: float = a.end.y
	geo.box(Vector3(x0 + 3.0, 0.22, z1 - 0.45), Vector3(4.0, 0.44, 0.9), "accent")
	geo.box(Vector3(x0 + 3.0, 0.6, z1 - 0.1), Vector3(4.0, 0.5, 0.2), "accent")
	geo.box(Vector3(a.end.x - 0.45, 0.22, z1 - 1.9), Vector3(0.9, 0.44, 2.0), "accent")
	geo.box(Vector3(a.end.x - 0.1, 0.6, z1 - 1.9), Vector3(0.2, 0.5, 2.0), "accent")
	for q in [Vector3(x0 + 0.6, 0, z1 - 2.0), Vector3(x0 + 1.5, 0, z1 - 2.6)]:
		geo.lathe(q, [Vector2(0.38, 0), Vector2(0.42, 0.18), Vector2(0.3, 0.4), Vector2(0.05, 0.48)], "chair", 10)
	geo.box(Vector3(x0 + 3.0, 0.2, z1 - 1.6), Vector3(1.2, 0.4, 0.6), "wood")
	var fl := Vector3(a.end.x - 0.4, 0, z1 - 0.4)
	geo.cylinder(fl, fl + Vector3(0, 1.6, 0), 0.02, "metal", 6)
	geo.cylinder(fl + Vector3(0, 1.5, 0), fl + Vector3(0, 1.75, 0), 0.18, "lamp", 10)
	# Ping-pong table: top on two folding frames, the net across.
	var t := Vector3(13.5, 0, 0.2)
	geo.tint = Color(0.15, 0.35, 0.25)
	geo.box(t + Vector3(0, 0.74, 0), Vector3(2.74, 0.03, 1.525), "desk")
	geo.tint = Color.WHITE
	geo.box(t + Vector3(0, 0.756, 0), Vector3(2.74, 0.004, 0.02), "pot", 0.0, false, false)
	for sx in [-0.9, 0.9]:
		geo.box(t + Vector3(sx, 0.36, 0), Vector3(0.05, 0.72, 1.3), "metal")
	geo.box(t + Vector3(0, 0.83, 0), Vector3(0.02, 0.15, 1.7), "chair", 0.0, false)

## Server room in the south-east corner: solid walls, a door in the west
## wall, two rows of racks (2 m tall) with an aisle between and round them.
func _server_room() -> void:
	var a: Rect2 = ANCHORS.server
	var x0: float = a.position.x
	var z0: float = a.position.y
	# North wall (to the open office), west wall with the door at z 7..8.
	geo.box(Vector3(a.get_center().x, 1.5, z0), Vector3(a.size.x, 3.0, 0.15), "wall")
	geo.box(Vector3(x0, 1.5, (z0 + 7.0) * 0.5), Vector3(0.15, 3.0, 7.0 - z0), "wall")
	geo.box(Vector3(x0, 1.5, (8.0 + a.end.y) * 0.5), Vector3(0.15, 3.0, a.end.y - 8.0), "wall")
	geo.box(Vector3(x0, 2.6, 7.5), Vector3(0.15, 0.8, 1.0), "wall")
	for rz in [6.6, 9.4]:
		for k in range(6):
			var q := Vector3(x0 + 1.6 + k * 0.62, 0, rz)
			geo.box(q + Vector3(0, 1.0, 0), Vector3(0.6, 2.0, 1.0), "screen")
			geo.box(q + Vector3(0, 1.0, 0.52 * signf(8.0 - rz)), Vector3(0.5, 1.8, 0.04), "lamp" if k % 3 == 1 else "metal", 0.0, false, false) # (4 cm proud of the rack front: 1 cm flickered)
	# Cable tray over the racks, a cooling unit on the east wall.
	geo.box(Vector3(x0 + 3.2, 2.7, 8.0), Vector3(4.0, 0.08, 0.4), "metal", 0.0, false)
	for sx in [-1.8, 1.8]:
		geo.box(Vector3(x0 + 3.2 + sx, 2.87, 8.0), Vector3(0.04, 0.26, 0.04), "metal", 0.0, false)
	geo.box(Vector3(a.end.x - 0.45, 0.9, 8.0), Vector3(0.7, 1.8, 1.2), "desk")

## Two phone booths by the reception: acoustic pods, open fronts.
func _booths() -> void:
	for q: Vector3 in ANCHORS.booths:
		geo.box(q + Vector3(0, 1.1, -0.55), Vector3(1.2, 2.2, 0.1), "accent")
		for sx in [-0.6, 0.6]:
			geo.box(q + Vector3(sx, 1.1, 0), Vector3(0.08, 2.2, 1.2), "accent")
		geo.box(q + Vector3(0, 2.24, 0), Vector3(1.28, 0.08, 1.2), "accent")
		geo.box(q + Vector3(0, 0.75, -0.3), Vector3(0.9, 0.04, 0.4), "wood")
		geo.box(q + Vector3(0, 0.45, 0.1), Vector3(0.45, 0.06, 0.45), "chair")
		geo.box(q + Vector3(0, 0.22, 0.1), Vector3(0.08, 0.42, 0.08), "metal")

## The map's tracks (RaceCourse.make builds the one Settings.race_track
## picks, at load time on top of the cached map): 2 easy, 2 medium, 2
## hard. Whoop scale: 60 cm gates, flags at k 0.3, a whoop ladder (0.9 m
## gaps). Aisles: north z -3.5, middle z 1.5, south z 8.5; desk clusters
## x -9.6..3.8 in rows z -6, -1, 4.
## Yaw: -PI/2 flies east (+x), PI/2 west, 0 north (-z), PI south.
func tracks() -> Array:
	var E: float = -PI * 0.5
	var W: float = PI * 0.5
	var N: float = 0.0
	var S: float = PI
	const K: float = 0.3
	var t1: Array = [
		["sized", Vector3(-11, 0.02, -3.5), -PI * 0.5, 0.6, 0.6, 0.05, 0.3, "gate_dark"],
		["sized", Vector3(0, 0.02, -3.5), -PI * 0.5, 0.6, 0.6, 0.05, 1.0, "gate_a"],
		["sized", Vector3(7, 0.02, 0.5), PI, 0.6, 0.6, 0.05, 0.3, "gate_b"],
		["sized", Vector3(2, 0.02, 8.5), PI * 0.5, 0.6, 0.6, 0.05, 1.4, "gate_a"],
		# Up under the ceiling between the high gate and the desk gate: a gate
		# hung from the ceiling on two wires.
		["hanging", Vector3(-2, 2.2, 8.5), PI * 0.5, 2.98, "gate_b", 0.6, 0.6],
		["box", Vector3(-6, 0.37, 8.5), Vector3(1.2, 0.74, 0.8), Color(0.82, 0.8, 0.76)], # the desk
		["sized", Vector3(-6, 0.76, 8.5), PI * 0.5, 0.6, 0.6, 0.05, 0.0, "gate_b"],
		["sized", Vector3(-13, 0.02, 2), 0.0, 0.6, 0.6, 0.05, 0.3, "gate_a"],
	]
	return [
		{"id": "after_hours", "name": "After Hours", "level": "easy", "calls": t1},
		# Easy: east along the middle aisle, south round the open area, west
		# along the south aisle past the kitchen, north home.
		{"id": "coffee_run", "name": "Coffee Run", "level": "easy", "calls": [
			["sized", Vector3(-11, 0.02, 1.5), E, 0.6, 0.6, 0.05, 0.3, "gate_dark"],
			["sized", Vector3(3, 0.02, 1.5), E, 0.6, 0.6, 0.05, 0.5, "gate_a"],
			["sized", Vector3(7, 0.02, 6), S, 0.6, 0.6, 0.05, 0.3, "gate_b"],
			["sized", Vector3(-2, 0.02, 8.5), W, 0.6, 0.6, 0.05, 0.8, "gate_a"],
			["sized", Vector3(-12, 0.02, 8.5), W, 0.6, 0.6, 0.05, 0.3, "gate_b"],
			["sized", Vector3(-15, 0.02, 5), N, 0.6, 0.6, 0.05, 0.4, "gate_a"],
		]},
		# Medium: east along the north aisle, in at the meeting room's west
		# door, round the far side of the table, out the south door, round a
		# flag at the ping-pong table, west over the desks (a gate on a desk
		# cluster), a flag in the U-turn home.
		{"id": "meeting", "name": "Meeting", "level": "medium", "calls": [
			["sized", Vector3(-7.5, 0.02, -3.5), E, 0.6, 0.6, 0.05, 0.3, "gate_dark"],
			["sized", Vector3(7.8, 0.02, -4.5), E, 0.6, 0.6, 0.05, 0.5, "gate_a"], # west door
			["sized", Vector3(13, 0.02, -9.7), E, 0.6, 0.6, 0.05, 0.5, "gate_b"], # behind the table
			["sized", Vector3(16.1, 0.02, -2.9), S, 0.6, 0.6, 0.05, 0.4, "gate_a"], # south door
			["turn", Vector3(14.6, 0.02, 1.3), W, "left", "gate_b", K], # round the ping-pong table
			["sized", Vector3(-4.6, 0.76, -1), W, 0.6, 0.6, 0.05, 0.45, "gate_b"], # on the desks, over the monitors
			["turn", Vector3(-12.8, 0.02, -2.25), N, "left", "gate_a", K],
		]},
		# Medium: a three-flag slalom along the south aisle, a low gate in the
		# open area and a gate hung from the ceiling just past it (climb!),
		# west along the north aisle through a low gate, home past the kitchen.
		{"id": "open_plan", "name": "Open Plan", "level": "medium", "calls": [
			["sized", Vector3(-10, 0.02, 9.3), E, 0.6, 0.6, 0.05, 0.3, "gate_dark"],
			["turn", Vector3(-6, 0.02, 8.5), E, "left", "gate_a", K],
			["turn", Vector3(-1, 0.02, 8.5), E, "right", "gate_b", K],
			["turn", Vector3(3.5, 0.02, 8.5), E, "left", "gate_a", K],
			["sized", Vector3(7, 0.02, 6), N, 0.6, 0.6, 0.05, 0.1, "gate_b"], # low ...
			["hanging", Vector3(7, 2.3, 1.5), N, 2.98, "gate_a", 0.6, 0.6], # ... then up under the ceiling
			["sized", Vector3(-4, 0.02, -3.5), W, 0.6, 0.6, 0.05, 0.1, "gate_b"], # low gate, north aisle
		]},
		# Hard: into the server room, east down the rack aisle, a hairpin round
		# the end of the racks, west along the back, out the door; under the
		# ping-pong table (southward) and a loop round it, the whoop ladder,
		# round the pillars home.
		{"id": "server_sprint", "name": "Server Sprint", "level": "hard", "calls": [
			["sized", Vector3(-9, 0.02, 1.5), E, 0.6, 0.6, 0.05, 0.3, "gate_dark"],
			["sized", Vector3(13.3, 0.02, 7.6), E, 0.6, 0.6, 0.05, 0.4, "gate_a"], # rack aisle
			["sized", Vector3(14.5, 0.02, 10.45), W, 0.6, 0.6, 0.05, 0.4, "gate_b"], # behind the racks, after the hairpin (square: the aisle is 1.1 m)
			["sized", Vector3(10.8, 0.02, 7.5), W, 0.6, 0.6, 0.05, 0.4, "gate_a"], # out the door
			["sized", Vector3(13.9, 0.02, 0.2), S, 0.6, 0.5, 0.04, 0.0, "gate_b"], # under the ping-pong table
			["turn", Vector3(15.4, 0.02, -0.2), N, "right", "gate_a", K], # back up its east side
			["ladder", Vector3(6.5, 0.02, -1.0), W, 0.9, "gate_b", 0.6],
			["turn", Vector3(5.0, 0.02, 5.0), S, "right", "gate_a", K], # west of the pillar
			["turn", Vector3(-10.6, 0.02, 5.0), N, "left", "gate_b", K], # round the other pillar
		]},
		# Hard, a lap of (nearly) everything: a three-flag slalom east along
		# the middle aisle, the whoop ladder, the meeting room in at the south
		# door and out at the west door, a gate hung from the ceiling over
		# the north aisle, a snake of three gates (two hairpins), home.
		{"id": "overtime", "name": "Overtime", "level": "hard", "calls": [
			["sized", Vector3(-11.5, 0.02, 1.5), E, 0.6, 0.6, 0.05, 0.3, "gate_dark"],
			["turn", Vector3(-6, 0.02, 1.5), E, "left", "gate_a", K],
			["turn", Vector3(-2, 0.02, 1.5), E, "right", "gate_b", K],
			["turn", Vector3(2, 0.02, 1.5), E, "left", "gate_a", K],
			["ladder", Vector3(6.5, 0.02, 1.5), E, 0.9, "gate_b", 0.6],
			["sized", Vector3(16.1, 0.02, -2.9), N, 0.6, 0.6, 0.05, 0.4, "gate_a"], # south door, in
			["sized", Vector3(13, 0.02, -9.7), W, 0.6, 0.6, 0.05, 0.5, "gate_b"], # behind the table
			["sized", Vector3(7.8, 0.02, -4.5), W, 0.6, 0.6, 0.05, 0.5, "gate_a"], # west door, out
			["hanging", Vector3(-2.5, 2.2, -3.5), W, 2.98, "gate_b", 0.6, 0.6],
			["sized", Vector3(-13, 0.02, -4.0), W + 0.35, 0.6, 0.6, 0.05, 0.3, "gate_a"], # snake: west, east, west
			["sized", Vector3(-13, 0.02, -2.2), E - 0.35, 0.6, 0.6, 0.05, 0.3, "gate_b"],
			["sized", Vector3(-13, 0.02, -0.4), W + 0.35, 0.6, 0.6, 0.05, 0.3, "gate_a"],
		]},
	]
