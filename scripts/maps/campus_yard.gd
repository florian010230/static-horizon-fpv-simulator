class_name CampusYard
extends RefCounted

## What fills the spaces between the buildings: the gatehouse and its
## barrier, the site cabins (stacked, with stairs and a walkway), the
## rebar and formwork yard, material piles, containers stacked two high,
## truck trailers on stands (fly under them), scaffold passages, the
## mixers, the mobile crane, portaloos, floodlights, lamps, mud and
## puddles, and scattered clutter - left clear on the roads and in front of
## every door.

var k: CampusKit
var geo: Geo
var roads: Roads
var rng := RandomNumberGenerator.new()

func _init(kit: CampusKit, r: Roads) -> void:
	k = kit
	geo = kit.geo
	roads = r
	rng.seed = 2610

func build_all() -> void:
	_cabins(Vector3(135.0, 0, 12.5))
	_east_yard()
	_courtyard()
	_south_yard()
	_loop_details()
	_wheel_wash_and_mud()
	# Clutter wherever there is room left (its own random numbers).
	var yr := RandomNumberGenerator.new()
	yr.seed = 2611
	var pit: Rect2 = CampusKit.PIT.grow(10.0)
	YardProps.scatter(geo, Rect2(-166, -64, 330, 58), 0.0, 90, yr, [])
	YardProps.scatter(geo, Rect2(-165, -90, 330, 16), 0.0, 24, yr, [])
	YardProps.scatter(geo, Rect2(-166, 56, 96, 58), 0.0, 14, yr, [pit])
	YardProps.scatter(geo, Rect2(-60, 56, 76, 42), 0.0, 20, yr, [])
	YardProps.scatter(geo, Rect2(100, 40, 66, 74), 0.0, 22, yr, [])
	YardProps.scatter(geo, Rect2(-100, -158, 270, 26), 0.0, 18, yr, [])

# --- the gate -----------------------------------------------------------------------------------------------

## c on the fence line at the gate, out = away from the site, gw = the gap.
## Posts with lamps, the sliding leaf pushed aside, a lowered barrier across
## the incoming lane, a guard hut, the signs.
static func gate(kit: CampusKit, c: Vector3, out: Vector3, gw: float) -> void:
	var geo: Geo = kit.geo
	var f: Transform3D = CampusKit.out_frame(c + out * 0.5, out)
	for s in [-1.0, 1.0]:
		kit.bf(f, Vector3(s * gw * 0.5, 1.3, 0), Vector3(0.3, 3.1, 0.3), "steel")
		kit.bf(f, Vector3(s * gw * 0.5, 2.95, 0), Vector3(0.3, 0.3, 0.3), "lamp_amber", false, false)
	kit.bf(f, Vector3(gw * 0.5 + 3.5, 1.05, -0.5), Vector3(6.0, 2.1, 0.06), "hoarding_w")
	geo.beam(f * Vector3(gw * 0.5 + 0.7, 0.15, -0.55), f * Vector3(gw * 0.5 + 6.3, 2.0, -0.55), Vector2(0.08, 0.08), "steel", false, false)
	# Barrier: a post at the east side, the striped boom lowered across the east lane.
	var along := Vector3(-out.z, 0, out.x)
	var post: Vector3 = c + along * -4.6 - out * 1.5
	kit.bf(f, Vector3(-4.6, 0.45, -1.5), Vector3(0.35, 1.5, 0.35), "crane_red")
	for k2 in range(8):
		var xa: float = -4.4 + k2 * 0.6
		var xb: float = xa + 0.6
		geo.beam(f * Vector3(xa, 1.05, -1.5), f * Vector3(xb, 1.05, -1.5), Vector2(0.1, 0.12), "tape" if k2 % 2 == 0 else "tape_w", true, false)
	# The hut.
	var hx: float = -gw * 0.5 - 3.2
	kit.bf(f, Vector3(hx, 1.25, -2.8), Vector3(3.0, 2.5, 2.4), "cabin")
	kit.bf(f, Vector3(hx, 2.55, -2.8), Vector3(3.4, 0.1, 2.8), "steel")
	kit.bf(f, Vector3(hx + 1.51, 1.5, -2.8), Vector3(0.03, 0.9, 1.6), "dark", false, false)
	StreetKit._label(geo, "Pförtner", f * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(hx + 1.53, 2.15, -2.8)), 0.0065, Color(0.1, 0.1, 0.1), 1.6)
	# Speed limit and the drone ban outside the gate.
	var foot: Vector3 = c + out * 3.4 - along * (gw * 0.5 + 2.0)
	foot.y = 0.0
	SignCreator.post(geo, foot, atan2(along.x, along.z), [["no_drones", "Kran hat Vorfahrt"], ["speed", "10"]])
	# A site board on the hoarding beside the gate.
	var bf: Transform3D = CampusKit.out_frame(c + out * 0.08 + along * (gw * 0.5 + 6.0), out)
	_site_board(kit, bf)

static func _site_board(kit: CampusKit, f: Transform3D) -> void:
	var geo: Geo = kit.geo
	kit.bf(f, Vector3(0, 1.5, 0.03), Vector3(3.0, 1.5, 0.05), "sg_back", false, false)
	var L := func(z: float) -> Transform3D: return f * Transform3D(Basis(), Vector3(0, 1.5, 0.09 + z))
	geo.plate(L.call(0.0), SignCreator._rect(2.9, 1.46), "sg_white")
	geo.plate(L.call(0.008), SignCreator._rect(2.9, 0.34).map(func(q: Vector2) -> Vector2: return q + Vector2(0, 0.53)), "sg_blue")
	StreetKit._label(geo, "BAUSTELLE", L.call(0.016) * Transform3D(Basis(), Vector3(0, 0.53, 0)), 0.0048, Color(0.97, 0.97, 0.95), 2.2)
	for i in range(5):
		var cp := Vector2(-1.1 + i * 0.55, 0.08)
		var disc: String = "sg_red" if i == 4 else "sg_blue"
		geo.plate(L.call(0.008), SignCreator._circle(0.21, 20).map(func(q: Vector2) -> Vector2: return q + cp), disc)
		geo.plate(L.call(0.016), SignCreator._rect(0.28, 0.07).map(func(q: Vector2) -> Vector2: return q + cp), "sg_white")
	StreetKit._label(geo, "Betreten für Unbefugte verboten", L.call(0.016) * Transform3D(Basis(), Vector3(0, -0.34, 0)), 0.0036, Color(0.1, 0.1, 0.1), 2.6)
	StreetKit._label(geo, "Eltern haften für ihre Kinder", L.call(0.016) * Transform3D(Basis(), Vector3(0, -0.52, 0)), 0.0036, Color(0.1, 0.1, 0.1), 2.6)

# --- site cabins -----------------------------------------------------------------------------------------------

## Site cabins in two rows, two high, back to back round an aisle, a stair
## at the west end and a walkway; flagpole and a picnic bench.
func _cabins(o: Vector3) -> void:
	var n: int = 6
	var len: float = n * 6.1
	geo.begin_object("site cabins")
	for row in range(2):
		var z: float = o.z + (-3.3 if row == 0 else 3.3)
		var face: float = -1.0 if row == 0 else 1.0
		for lvl in range(2):
			for i in range(n):
				var cx: float = o.x - len * 0.5 + 3.05 + i * 6.1
				var m: String = "cabin" if (i + lvl + row) % 3 else "cabin_blue"
				var cy: float = 1.3 + lvl * 2.62
				geo.box(Vector3(cx, cy, z), Vector3(6.0, 2.6, 2.44), m)
				geo.box(Vector3(cx - 1.8, cy - 0.35, z + face * 1.23), Vector3(0.95, 1.9, 0.03), "dark", 0.0, false, false)
				geo.box(Vector3(cx + 1.4, cy + 0.15, z + face * 1.23), Vector3(1.4, 0.9, 0.03), "dark", 0.0, false, false)
				geo.box(Vector3(cx + 1.4, cy + 0.15, z - face * 1.23), Vector3(1.4, 0.9, 0.03), "dark", 0.0, false, false)
		for i in range(0, n, 2):
			geo.box(Vector3(o.x - len * 0.5 + 3.05 + i * 6.1, 5.4, z), Vector3(1.0, 0.5, 0.8), "steel")
	var wx: float = o.x - len * 0.5
	var wz: float = o.z - 3.3 - 1.22
	geo.beam(Vector3(wx - 4.0, 0.0, wz - 1.0), Vector3(wx - 0.3, 2.62, wz - 1.0), Vector2(1.0, 0.15), "steel")
	geo.box(Vector3(wx - 0.6, 2.57, wz - 0.9), Vector3(1.6, 0.1, 1.4), "steel")
	geo.box(Vector3(o.x, 2.62, wz - 1.0), Vector3(len, 0.1, 1.2), "steel")
	for i in range(int(len / 3.0) + 1):
		var px: float = wx + i * 3.0
		geo.cylinder(Vector3(px, 2.62, wz - 1.55), Vector3(px, 3.7, wz - 1.55), 0.025, "steel", 4, true, false, false)
	geo.beam(Vector3(wx, 3.7, wz - 1.55), Vector3(wx + len, 3.7, wz - 1.55), Vector2(0.05, 0.05), "steel", false, false)
	for i in range(0, int(len / 6.1) + 1, 2):
		geo.cylinder(Vector3(wx + i * 6.1, 0.0, wz - 1.4), Vector3(wx + i * 6.1, 2.6, wz - 1.4), 0.05, "steel", 6)
	# A second stair at the east end (to the roof deck) - and the notice.
	var fp := Vector3(o.x + len * 0.5 + 5.0, 0, o.z + 7.0)
	geo.cylinder(fp, fp + Vector3(0, 9.0, 0), 0.07, "steel", 8)
	geo.box(fp + Vector3(0.75, 8.2, 0), Vector3(1.4, 0.9, 0.03), "banner_a", 0.0, false, false)
	var pf := Vector3(o.x + 8.0, 0, o.z + 9.0)
	geo.box(pf + Vector3(0, 0.75, 0), Vector3(2.0, 0.06, 0.7), "wood")
	for s in [-0.6, 0.6]:
		geo.box(pf + Vector3(0, 0.45, s), Vector3(2.0, 0.05, 0.25), "wood")
		geo.box(pf + Vector3(-0.8, 0.37, s * 0.5), Vector3(0.06, 0.75, 1.0), "steel")
		geo.box(pf + Vector3(0.8, 0.37, s * 0.5), Vector3(0.06, 0.75, 1.0), "steel")
	var nf: Transform3D = CampusKit.out_frame(Vector3(o.x + 3.0, 0, o.z + 3.3 + 1.23), Vector3(0, 0, 1))
	k.bf(nf, Vector3(0, 1.5, 0.02), Vector3(1.4, 0.9, 0.03), "hoarding_w", false, false)
	StreetKit._label(geo, "Kaffeepause", nf * Transform3D(Basis(), Vector3(0, 1.7, 0.045)), 0.009, Color(0.1, 0.1, 0.1), 1.2)
	StreetKit._label(geo, "10:00 bis 17:00", nf * Transform3D(Basis(), Vector3(0, 1.3, 0.045)), 0.006, Color(0.5, 0.1, 0.1), 1.2)
	geo.end_object()
	k.map.register_entrance(Vector3(wx - 3.0, 0.0, wz - 1.0 - 0.2), "cabin stair")
	# Portaloos in a row by the cabins (the second open, with a toilet).
	for i in range(4):
		k.portaloo(Vector3(o.x - 12.0 + i * 1.6, 0, o.z + 8.5), 0.0, i == 1)

# --- the east yard: rebar, formwork, containers, trailers on stands ------------------------------------------------

func _east_yard() -> void:
	# Rebar racks in two rows, the bending shed.
	for r in range(2):
		for c in range(5):
			k.rebar_rack(Vector3(114.0 + c * 8.5, 0, 52.0 + r * 12.0), 0.0, 3 + (c + r) % 2)
	k.shed(Vector3(133.0, 0, 76.0), 0.0, 18.0, 7.0, 3.4, "cabin")
	for i in range(5):
		var cage := Vector3(126.0 + i * 3.0, 0.6, 76.0)
		geo.pipe(cage + Vector3(0, 0, -2.5), cage + Vector3(0, 0, 2.5), 0.6, 0.06, "rebar", 8)
	geo.box(Vector3(142.0, 0.5, 76.0), Vector3(1.6, 1.0, 5.0), "steel_red")
	# Formwork: racks of wall panels, flat stacks, bundles of props.
	for r in range(2):
		for c in range(3):
			k.panel_rack(Vector3(138.0 + c * 7.0, 0, 90.0 + r * 8.0), 0.15 * r, 12 - c, "banner_a" if (r + c) % 2 == 0 else "wood")
	for i in range(4):
		for lvl in range(rng.randi_range(3, 6)):
			geo.box(Vector3(115.0 + i * 3.4, 0.12 + lvl * 0.24, 94.0), Vector3(2.5, 0.22, 2.7), "wood")
	for i in range(3):
		geo.box(Vector3(118.0 + i * 6.0, 0.25, 102.0), Vector3(5.0, 0.5, 0.5), "steel")
		geo.box(Vector3(118.0 + i * 6.0, 0.75, 102.0), Vector3(5.0, 0.5, 0.5), "steel_red")
	# Containers stacked two high, two rows.
	var cm: Array = ["veh_paint1", "veh_paint2", "veh_paint6", "veh_trailer"]
	for i in range(3):
		for lvl in range(2):
			k.container(Vector3(158.0, lvl * 2.62, 54.0 + i * 2.8), 0.0, cm[(i + lvl) % 4])
	# Truck trailers on stands: you can fly under them.
	for i in range(3):
		_trailer_on_stands(Vector3(118.0 + i * 14.0, 0, 108.0), PI * 0.5)
	# The mobile crane, boom up toward the garage.
	Vehicles.mobile_crane(geo, Vector3(100.0, 0.02, 60.0), -0.9, 34.0, 62.0)
	Vehicles.wheel_loader(geo, Vector3(156.0, 0.02, 100.0), 2.4)

## A 12 m trailer box on its landing legs at the front and a rear bogie
## frame: 1.4 m of air under it.
func _trailer_on_stands(p: Vector3, yaw: float) -> void:
	var f := Transform3D(Basis(Vector3.UP, yaw), p)
	k.bf(f, Vector3(0, 1.4 + 1.35, 0), Vector3(2.55, 2.7, 12.2), "veh_trailer")
	k.bf(f, Vector3(0, 1.3, 0), Vector3(2.3, 0.2, 12.0), "veh_black")
	for sz in [-5.0, 5.0]:
		for sx in [-1.0, 1.0]:
			k.bf(f, Vector3(sx * 1.0, 0.65, sz), Vector3(0.15, 1.3, 0.15), "steel")
		k.bf(f, Vector3(0, 0.08, sz), Vector3(2.4, 0.16, 0.5), "wood")

# --- the courtyard between the towers and the hall --------------------------------------------------------------------

func _courtyard() -> void:
	# Containers stacked two high by the west loop (a block of six).
	var cm: Array = ["veh_paint1", "veh_paint2", "veh_paint6", "veh_trailer"]
	for i in range(3):
		for j in range(2):
			for lvl in range(2):
				k.container(Vector3(-150.0 + i * 6.3, lvl * 2.62, -38.0 + j * 2.6), 0.0, cm[(i + j + lvl) % 4])
	# Trailers on stands, scaffold passages.
	_trailer_on_stands(Vector3(-110.0, 0, -50.0), 0.0)
	_trailer_on_stands(Vector3(-96.0, 0, -50.0), 0.0)
	_trailer_on_stands(Vector3(40.0, 0, -30.0), PI * 0.5)
	k.scaffold_passage(Vector3(-88.0, 0, -22.0), 17.5, 3.6, 0.0)
	k.scaffold_passage(Vector3(60.0, 0, -52.0), 12.5, 3.4, PI * 0.5)
	# Rebar cages, a rebar stock, stacked pipes, material heaps.
	for i in range(6):
		var cage := Vector3(-60.0 + i * 2.6, 0.6, -52.0)
		geo.pipe(cage + Vector3(0, 0, -2.8), cage + Vector3(0, 0, 2.8), 0.6, 0.06, "rebar", 8)
	for i in range(3):
		k.rebar_rack(Vector3(-40.0 + i * 3.0, 0, -22.0), 0.0, 3)
	k.pipe_stack(Vector3(-130.0, 0, -22.0), 0.0, 3, 6.0, 0.55)
	k.pipe_stack(Vector3(-118.0, 0, -22.0), 0.0, 2, 6.0, 0.55)
	geo.cone(Vector3(-20.0, 0, -50.0), Vector3(-20.0, 4.2, -50.0), 7.0, 0.5, "sand", 12)
	geo.cone(Vector3(-38.0, 0, -52.0), Vector3(-38.0, 3.2, -52.0), 5.5, 0.5, "gravel_pile", 12)
	for sx in [-1.0, 1.0]:
		for lvl in range(2):
			geo.box(Vector3(-20.0 + sx * 9.0, 0.4 + lvl * 0.8, -50.0), Vector3(1.6, 0.8, 8.0), "concrete_old")
	# Concrete mixers waiting on the west loop road, a tipper, an excavator.
	Vehicles.mixer(geo, Vector3(-170.0, 0.02, 32.0), 0.0, "veh_paint2")
	Vehicles.mixer(geo, Vector3(-170.0, 0.02, 45.0), 0.0, "veh_paint0")
	Vehicles.tipper(geo, Vector3(-170.0, 0.02, 58.0), 0.0, "veh_paint1", "gravel_pile")
	Vehicles.excavator(geo, Vector3(-135.0, 0.02, -62.0), 0.4, 0.6, "site_orange")
	# Skips and the portaloo row in the corner.
	for i in range(3):
		k.skip(Vector3(-190.0 + i * 3.4, 0, -150.0 + i * 0.4), 0.1 * i)
	for i in range(4):
		k.portaloo(Vector3(-190.0 + i * 1.6, 0, -120.0), 0.0, false)

# --- the south yard: staff parking, heaps, pipes --------------------------------------------------------------------------

func _south_yard() -> void:
	for i in range(11):
		k.fleet.car(Vector3(-20.0 + i * 3.0, 0.02, 111.0), 0.0 if i % 2 == 0 else PI, Fleet.random_paint(rng), ["hatch", "suv", "van", "pickup"][rng.randi() % 4])
	geo.cone(Vector3(-45.0, 0, 76.0), Vector3(-45.0, 5.0, 76.0), 8.0, 0.5, "sand", 12)
	geo.cone(Vector3(-28.0, 0, 78.0), Vector3(-28.0, 4.0, 78.0), 6.5, 0.5, "gravel_pile", 12)
	k.pipe_stack(Vector3(-45.0, 0, 96.0), 0.0, 3, 6.0, 0.55)
	k.pipe_stack(Vector3(-36.0, 0, 96.0), 0.0, 3, 6.0, 0.55)
	for i in range(5):
		k.pallet(Vector3(-20.0 + i * 3.0, 0, 96.0), 0.0, 0.4 + (i % 3) * 0.4, "brick")
	Vehicles.wheel_loader(geo, Vector3(-38.0, 0.02, 88.0), 0.6)

# --- floodlights, lamps, flags ----------------------------------------------------------------------------------------------------

func _loop_details() -> void:
	for p in [Vector3(-182, 0, -150), Vector3(182, 0, -150), Vector3(-182, 0, 140), Vector3(182, 0, 140), Vector3(-182, 0, -20), Vector3(182, 0, -20),
			Vector3(-182, 0, 60), Vector3(182, 0, 60), Vector3(-90, 0, -148), Vector3(90, 0, -148), Vector3(-90, 0, 138), Vector3(90, 0, 138)]:
		geo.box(p + Vector3(0, 0.25, 0), Vector3(1.2, 0.5, 1.2), "concrete_old")
		geo.cylinder(p, p + Vector3(0, 22, 0), 0.25, "steel", 8)
		geo.box(p + Vector3(0, 22.4, 0), Vector3(2.4, 0.8, 0.8), "lamp", 0.0, false, false)
	# Street lamps along the north loop and the spine (on the outside edge).
	var x: float = -165.0
	while x < 170.0:
		if absf(x) > 12.0 and absf(absf(x) - 133.0) > 20.0:
			roads.lamp(Vector3(x, 0.0, -136.5), Vector3(x, 0.0, -130.0))
		x += 45.0
	var z: float = -120.0
	while z < 140.0:
		if absf(z) > 10.0 and absf(z - 120.0) > 10.0 and absf(z + 70.0) > 10.0 and absf(z + 130.0) > 10.0:
			roads.lamp(Vector3(5.5, 0.0, z), Vector3(0.0, 0.0, z))
		z += 45.0
	# The assembly point (Sammelplatz): a green board on two posts near the gate.
	var af: Transform3D = CampusKit.out_frame(Vector3(24.0, 0, 134.0), Vector3(0, 0, 1))
	for s in [-0.6, 0.6]:
		k.bf(af, Vector3(s, 1.0, 0), Vector3(0.08, 2.0, 0.08), "steel")
	k.bf(af, Vector3(0, 1.8, 0.06), Vector3(1.6, 0.9, 0.04), "sign_green", false, false)
	geo.plate(af * Transform3D(Basis(), Vector3(-0.45, 1.8, 0.09)), SignCreator._rect(0.5, 0.14), "sg_white")
	geo.plate(af * Transform3D(Basis(), Vector3(-0.45, 1.8, 0.09)), SignCreator._rect(0.14, 0.5), "sg_white")
	StreetKit._label(geo, "Sammelplatz", af * Transform3D(Basis(), Vector3(0.3, 1.8, 0.09)), 0.0065, Color(0.97, 0.97, 0.95), 0.9)
	# Jersey barriers along the pit approach.
	for i in range(10):
		geo.frustum(Transform3D(Basis(), Vector3(-130.0 + i * 3.0, 0.4, 56.5)), Vector3(0.6, 0.8, 2.9), 0.2, 2.9, 0.0, "concrete_old")

func _wheel_wash_and_mud() -> void:
	k.wheel_wash(Vector3(0.0, 0.0, 136.0))
	geo.slab(Rect2(-4.0, 112.0, 8.0, 14.0), 0.0, 1.0, "mudpatch", false)
	for r in [Rect2(-3.5, 114.0, 3.0, 2.2), Rect2(0.5, 118.0, 2.5, 1.6), Rect2(-120.0, -134.5, 4.0, 2.0), Rect2(60.0, -125.8, 3.5, 1.8),
			Rect2(-169.0, 20.0, 3.4, 2.0), Rect2(166.0, 30.0, 3.0, 2.4), Rect2(40.0, 117.0, 4.5, 2.2), Rect2(-60.0, 3.0, 4.0, 1.8)]:
		geo.slab(r, 0.0, 1.0, "puddle", false)
