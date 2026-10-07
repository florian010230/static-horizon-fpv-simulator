extends BuiltMap

## Factory - Werk Lindner, a working coatings and metal plant on the edge
## of farmland, built by the creators from a layout laid out here by
## hand (replaces the hand-made scenes/Main2.tscn factory, 2026-10-05).
## Unlike the Abandoned Steel Mill: fresh paint, yellow lane lines, lamps
## on, trucks at the docks, a train being loaded.
##
## Layout: the site is a levelled rectangle (x east, z south, origin its
## middle), fenced, its gate and gatehouse on the public road to the
## east. Inside: the production hall in the west (open at both ends - the
## fly-through), the warehouse with its loading docks in the middle,
## lorries backed up to them; the office block by the gate; the boiler
## house and its chimney, a cooling tower, the tank farm, a pipe rack
## over the site road joining them; grain-style silos fed from the rail
## siding by a hopper and a conveyor gallery; the siding itself comes off
## the main line north of the site through its own gap in the fence to a
## loading platform under a canopy. The staff car park in the south-east.

const LAND := Rect2(-520, -520, 1040, 1040)
const SITE := Vector2(0, 0)
const SITE_SIZE := Vector2(230, 170)
const RAIL_Z: float = -135.0
var land: TerrainCreator
var _views: Array = []
var _gnomes: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-44, -40, 0), "clouds": 0.6,
		"shadow_region": Rect2(-300, -300, 600, 600)}

func border() -> Array:
	return [330.0, 390.0, 250.0, 310.0, Vector2(10, -20)]

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func preview_views() -> Array:
	return _views

func cacheable() -> bool:
	return true

func cache_state() -> Dictionary:
	return {"views": _views, "land": land.grid_state(), "gnomes": _gnomes}

func restore_state(state: Dictionary) -> void:
	_views = state.views
	land = TerrainCreator.from_grid_state(state.land)
	_gnomes = state.gnomes

func after_build() -> void:
	if OS.has_environment("SH_GLITCH"):
		var sg: Array = surface_glitches()
		print("GLITCH %s: %d %s" % [name, sg.size(), str(sg.slice(0, 12))])
	for i in range(_gnomes.size()):
		var g: Array = _gnomes[i]
		Collectibles.gnome(self, "factory", i, Transform3D(Basis(Vector3.UP, g[1]), g[0]))

## Glitch check for the self-test: terrain coming up through a road or
## the railway (RoadCreator.buried). Empty on a cached load.
var _lines: Array = []

func surface_glitches() -> Array:
	var out: Array = []
	for l: LandLine in _lines:
		out.append_array(RoadCreator.buried(land, l, LAND.grow(-16.0)))
	return out

func pieces() -> Dictionary:
	return {}

func _materials() -> void:
	if geo.has_material("fc_paint"):
		return
	geo.add_material("fc_paint", Geo.flat_mat(Color.WHITE, 0.5))
	geo.add_material("fc_glass", Geo.flat_mat(Color(0.45, 0.58, 0.68), 0.1, 0.3))
	geo.add_material("fc_concrete", Geo.tex_mat(MapTextures.get_tex("concrete_slab"), Color(1.12, 1.12, 1.1), 5.0))
	geo.add_material("fc_lamp", Geo.flat_mat(Color(1.7, 1.65, 1.4), 0.5))
	geo.material("fc_lamp").set_meta("no_shadow", true)
	geo.add_material("fcd_paint", Geo.flat_mat(Color.WHITE, 0.5))
	geo.add_material("fc_platform", Geo.ground_mat(MapTextures.get_tex("concrete_slab"), Color(0.95, 0.95, 0.92), 4.0, 2, 0.2))
	geo.add_material("fc_asphalt", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color(0.75, 0.75, 0.78), 6.0, 2, 0.2))
	geo.add_material("fci_paint", Geo.flat_mat(Color.WHITE, 0.5))
	geo.material("fci_paint").set_meta("no_shadow", true)
	geo.detail_prefixes.append("fcd_")
	geo.detail_prefixes.append("fci_")

func build() -> void:
	var t0: int = Time.get_ticks_msec()
	land = TerrainCreator.make(77, "gentle")
	land.set_extent(LAND)
	var site: Dictionary = IndustryCreator.plan(land, SITE, SITE_SIZE)
	var y: float = site.y
	# Level ground north of the site for the siding, under the main line.
	land.flat_rect(Rect2(-300, RAIL_Z - 15.0, 520, 70), y, 50.0)
	land.hill(Vector2(-380, 260), 220.0, 18.0)
	land.hill(Vector2(380, -330), 200.0, 14.0)
	land.keep_clear(SITE, 150.0, true)
	var rail := RailCreator.plan(land, Vector3(-1600, 0, RAIL_Z - 20.0), 0.0, [Vector2(-500, RAIL_Z), Vector2(0, RAIL_Z), Vector2(500, RAIL_Z - 10.0), Vector2(1600, RAIL_Z - 60.0)],
		{"hold": [[Vector2(-40, RAIL_Z), y + 0.06, 300.0]], "viaduct": false, "radius": 600.0})
	# The public road held at the yard's level past the gate (on a bank
	# there): left to the ground, it ran 2.3 m under the yard and the gate
	# road's turning circle lay buried in the yard's edge.
	var road := RoadCreator.plan(land, Vector3(170, 0, 1600), -90.0, [Vector2(160, 400), Vector2(150, 120), Vector2(150, -40), Vector2(190, -95), Vector2(400, -100), Vector2(1600, -60)], 7.0, {"radius": 70.0, "hold": [[Vector2(150, 0), y + 0.05, 14.0]]})
	var gate_rd := RoadCreator.branch(land, road, Vector2(150, 0), -1.0, [Vector2(SITE.x + SITE_SIZE.x * 0.5 + 11.0, 0)], 7.0, {"end": "turning", "lead": 8.0})
	var t1: int = Time.get_ticks_msec()
	land.build(self, geo, LAND)
	for rd: RoadCreator in [road, gate_rd]:
		_lines.append(rd.line)
	_lines.append(rail.line)
	_materials()
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 5
	var roads := Roads.new(geo, lrng, fleet)
	for rd: RoadCreator in [road, gate_rd]:
		rd.draw(geo, roads, lrng)
	VillageKit.lamps(roads, road, 200.0, road.line.length() * 0.5, 36.0)
	StreetKit.give_way(geo, gate_rd)
	var rails := Rails.new(geo)
	var ri: Dictionary = rail.draw(geo, rails, lrng)
	var main_r: Route = ri.route
	# --- the site ---
	IndustryCreator.yard(geo, site)
	var o := Vector3(SITE.x, y, SITE.y)
	var hx: float = SITE_SIZE.x * 0.5
	var hz: float = SITE_SIZE.y * 0.5
	var v: Array = []
	# Production hall: the fly-through, doors open at both ends.
	var hall_a := Transform3D(Basis(), o + Vector3(-72, 0, 12))
	var HA_L: float = 72.0
	var HA_B: float = 32.0
	var hall_v: Array = IndustryCreator.hall(geo, hall_a, HA_L, HA_B, 11.0, lrng, {"docks": 0, "office": false, "open_both": true})
	for e: Array in hall_v:
		v.append(["prod_" + e[0], e[1], e[2]])
	v.append(["prod_through", hall_a * Vector3(-HA_B * 0.25, 3.0, HA_L * 0.5 + 12.0), hall_a * Vector3(-HA_B * 0.25, 3.0, -HA_L * 0.5)])
	# Warehouse with docks to the east, lorries backed up.
	var hall_b := Transform3D(Basis(), o + Vector3(-6, 0, 22))
	v.append_array(IndustryCreator.hall(geo, hall_b, 60.0, 30.0, 10.0, lrng, {"docks": 4, "roof": "gable"}))
	var paints: Array = ["veh_paint1", "veh_paint6", "veh_paint9", "veh_paint2"]
	var k: int = 0
	for d: Vector3 in IndustryCreator.docks(hall_b, 60.0, 30.0, 4):
		if k != 2:
			Vehicles.semi(geo, d + Vector3(8.4, 0.02, 0), -PI * 0.5, paints[k % paints.size()], "veh_trailer")
		k += 1
	# Boiler house with its chimney; the pipe rack east to the tanks and the cooling tower.
	var bh := o + Vector3(-8, 0, -42)
	geo.box_on(Transform3D(Basis(), bh + Vector3(0, 4.5, 0)), Vector3(18, 9, 12), "in_brick", y)
	geo.tint = Color(0.25, 0.4, 0.6)
	geo.box(bh + Vector3(0, 9.15, 0), Vector3(18.6, 0.3, 12.6), "in_paint")
	geo.box(bh + Vector3(-9.05, 2.4, 0), Vector3(0.1, 4.6, 4.2), "in_paint", 0.0, false)
	geo.tint = Color.WHITE
	for wx in [-5.0, 0.0, 5.0]:
		geo.box(bh + Vector3(wx, 6.0, 6.05), Vector3(2.4, 2.4, 0.1), "fc_glass", 0.0, false)
	IndustryCreator.chimney(geo, bh + Vector3(14, 0, -2), 55.0)
	IndustryCreator.pipe_rack(geo, land, [Vector2(bh.x + 9.5, bh.z + 2.0), Vector2(o.x + 40, bh.z + 2.0), Vector2(o.x + 40, o.z + 40), Vector2(o.x + 58, o.z + 40)], 6.0, y)
	var tank_tops: Array = IndustryCreator.tanks(geo, o + Vector3(76, 0, 44), 2, 2, lrng)
	# A tanker at the tank farm's filling point.
	Vehicles.semi(geo, o + Vector3(102, 0.02, 30), PI, "veh_paint3", "veh_trailer")
	# Cooling tower.
	var ct_views: Array = _cooling_tower(o + Vector3(70, 0, -30))
	# Silos fed from the siding: hopper by the track, gallery up to the headhouse.
	v.append_array(IndustryCreator.silos(geo, o + Vector3(-104, 0, -50), 3, lrng, o + Vector3(-60, 0, -71)))
	# Containers waiting by the warehouse.
	var cmats: Array = ["veh_paint1", "veh_paint2", "veh_paint6", "veh_trailer"]
	for i in range(6):
		for lvl in range(1 + i % 2):
			geo.box(o + Vector3(-47 + (i % 3) * 7.0, 1.3 + lvl * 2.6, -16 + (i / 3) * 3.0), Vector3(6.06, 2.59, 2.44), cmats[(i + lvl) % cmats.size()])
	# --- the siding: off the main line, through the north fence, along
	# the loading platform, to its buffer stop ---
	var sd: float = main_r.dist_at_x(o.x + 150.0)
	var sid: Route = rails.turnout(main_r.reversed(), main_r.reversed().length() - sd, -1.0)
	sid.arc(190.0, -20.0, 3.0)
	sid.straight(40.0, 4.0)
	sid.arc(190.0, 26.34, 3.0)
	var siding_z: float = sid.end().z
	sid.to(Vector3(o.x - 95.0, sid.end().y, siding_z), 6.0)
	rails.track(sid, 1)
	rails.buffer_stop(sid)
	var plat_v: Array = _platform(o, siding_z, y)
	rails.train(sid.reversed(), 6.0, ["hopper", "hopper", "hopper", "box", "box"], lrng)
	rails.train(main_r, main_r.dist_at_x(-420.0), ["loco", "tank", "tank", "tank", "tank", "tank"], lrng)
	# --- fence with the gate on the east side and the siding's gap north ---
	var gap_x: float = _route_x_at_z(sid, o.z - hz - 1.0) - o.x
	v.append_array(IndustryCreator.fence(geo, site, "e", {"gaps": [["n", gap_x, 6.0]]}))
	# --- the office block by the gate ---
	var off_v: Array = _office(o + Vector3(88, 0, -70), y)
	# --- staff WC cabin behind the boiler house (the toilet, through its window) ---
	var wc_v: Array = _wc_cabin(o + Vector3(-30, 0, -50), y)
	# --- yard life: pallet stacks by the warehouse, a forklift on its way ---
	geo.tint = Color(0.8, 0.68, 0.5)
	for pi in range(8):
		var pp: Vector3 = o + Vector3(-28.0 + (pi % 4) * 1.6, 0, 56.0 + (pi / 4) * 1.4)
		var hgt: int = 1 + (pi * 7) % 4
		geo.box_on(Transform3D(Basis(), pp + Vector3(0, hgt * 0.075, 0)), Vector3(1.2, hgt * 0.15, 0.8), "fcd_paint", y)
		geo.tint = [Color(0.3, 0.45, 0.7), Color(0.85, 0.85, 0.82), Color(0.72, 0.58, 0.4)][pi % 3]
		geo.box(pp + Vector3(0, hgt * 0.15 + 0.5, 0), Vector3(1.1, 1.0, 0.75), "fcd_paint")
		geo.tint = Color(0.8, 0.68, 0.5)
	geo.tint = Color.WHITE
	# Painted walkways across the site road.
	geo.tint = Color(0.95, 0.95, 0.92)
	for zz in [-30.0, 60.0]:
		for wk in range(6):
			geo.box(o + Vector3(-50.0 + wk * 0.9, 0.06, zz), Vector3(0.45, 0.02, 3.0), "fcd_paint", 0.0, false, false)
	geo.tint = Color.WHITE
	# --- car park, lamps, lane lines ---
	var cp := Rect2(o.x + 30, o.z + hz - 22, 70, 18)
	geo.polygon([Vector3(cp.position.x, y + 0.05, cp.position.y), Vector3(cp.end.x, y + 0.05, cp.position.y), Vector3(cp.end.x, y + 0.05, cp.end.y), Vector3(cp.position.x, y + 0.05, cp.end.y)], "fc_asphalt", false)
	var crng := RandomNumberGenerator.new()
	crng.seed = 33
	geo.tint = Color(0.95, 0.95, 0.95)
	for i in range(15):
		var x: float = cp.position.x + 2.5 + i * 4.4
		geo.box(Vector3(x - 2.2, y + 0.07, cp.position.y + 4.5), Vector3(0.12, 0.02, 5.0), "fcd_paint", 0.0, false, false)
		# A wheel stop at the head of each bay (the car stands against it).
		geo.tint = Color(0.8, 0.8, 0.78)
		geo.box(Vector3(x, y + 0.06, cp.position.y + 2.2), Vector3(1.6, 0.12, 0.15), "fc_concrete")
		geo.tint = Color(0.95, 0.95, 0.95)
		if crng.randf() < 0.8:
			fleet.car(Vector3(x, y, cp.position.y + 4.0), 0.0, Fleet.random_paint(crng), ["sedan", "hatch", "estate", "suv", "van"][crng.randi() % 5])
	geo.tint = Color.WHITE
	for lp in [Vector3(-38, 0, -28), Vector3(40, 0, -60), Vector3(90, 0, 10), Vector3(-110, 0, 60), Vector3(20, 0, 70), Vector3(-30, 0, 60)]:
		_light_mast(o + lp, y)
	# --- countryside ---
	var trees: Array = []
	var woods: Array = [[Vector2(-380, 260), 160.0], [Vector2(380, -360), 150.0], [Vector2(-420, -300), 120.0], [Vector2(330, 330), 130.0]]
	trees.append_array(land.woods(lrng, LAND.grow(-60.0), 1800, 90.0, woods))
	for i in range(14):
		trees.append([Vector3(o.x - hx - 6.0, y, o.z - hz + 10 + i * 11.0), "birch" if i % 3 else "maple", 900 + i, "none"])
	TreeCreator.plant(self, geo, trees)
	if OS.has_environment("SH_PERF"):
		print("FACTORY plan %d ms, rest %d ms; site y %.2f, ground at car park %.2f" % [t1 - t0, Time.get_ticks_msec() - t1, y, land.ground(50, 67)])
	# Gnomes: on the forklift's roof in the production hall, on the office
	# roof between the AC units (added by _office), on the cooling tower's
	# inner ledge (added by _cooling_tower).
	var fk: Vector3 = _forklift_top(hall_a, HA_L, HA_B, 11.0)
	_gnomes.push_front([fk, 0.3])
	v.append(["gnome_forklift", fk + Vector3(1.5, 1.2, 2.0), fk])
	# --- views ---
	_views.append(["overview", o + Vector3(200, 90, 200), o + Vector3(-10, 0, -10)])
	_views.append(["top", o + Vector3(0, 230, 1), o])
	_views.append(["spawn_view", o + Vector3(hx - 12, 2.0, 8), o + Vector3(0, 4, 0)])
	_views.append(["entrance", o + Vector3(hx + 30, 4.0, 4), o + Vector3(hx - 20, 3, 0)])
	_views.append_array(v)
	_views.append_array(ct_views)
	_views.append_array(plat_v)
	_views.append_array(off_v)
	_views.append_array(wc_v)
	_views.append(["siding", Vector3(o.x + 60, y + 6, RAIL_Z + 20), Vector3(o.x - 40, y + 1, siding_z)])
	_views.append(["tanks", tank_tops[0] + Vector3(25, 2, 25), tank_tops[0] + Vector3(0, -5, 0)])

## x where a route crosses the line z (the siding through the fence).
func _route_x_at_z(r: Route, z: float) -> float:
	var p: Array[Vector3] = r.pts
	for i in range(p.size() - 1):
		if (p[i].z - z) * (p[i + 1].z - z) <= 0.0 and absf(p[i + 1].z - p[i].z) > 0.001:
			return lerpf(p[i].x, p[i + 1].x, (z - p[i].z) / (p[i + 1].z - p[i].z))
	return p[-1].x

## The forklift's roof in IndustryCreator's hall interior (same numbers
## as IndustryCreator._inside).
func _forklift_top(xf: Transform3D, L: float, B: float, H: float) -> Vector3:
	var rx: float = -B * 0.5 + 1.55
	var z0: float = -L * 0.5 + 3.0
	var z1: float = L * 0.3 - 1.5
	var n_bays: int = int((z1 - z0) / 2.7)
	return xf * Vector3(rx + 2.05, 0.16 + 2.21, z0 + n_bays * 2.7 * 0.4 + 0.5)

## A natural-draught cooling tower: a hyperboloid shell on a ring of
## diagonal legs - fly in under the shell's edge between the legs and up
## out of the top. Real numbers: small industrial towers 30-50 m tall,
## the shell's foot ~8 m up on its legs.
func _cooling_tower(c: Vector3) -> Array:
	var profile: Array = [Vector2(16.0, 7.0), Vector2(14.2, 12.0), Vector2(12.0, 20.0), Vector2(10.6, 28.0), Vector2(10.2, 33.0), Vector2(10.6, 38.0), Vector2(11.2, 42.0)]
	geo.tint = Color(0.82, 0.82, 0.8)
	geo.lathe(c, profile, "fc_concrete", 36, 0.5)
	# A ring beam under the shell's foot, the legs in V pairs down to their footings.
	geo.tint = Color(0.72, 0.72, 0.7)
	var n: int = 18
	for i in range(n):
		var a: float = TAU * i / n
		var a2: float = TAU * (i + 0.5) / n
		var top := c + Vector3(cos(a) * 15.8, 7.0, sin(a) * 15.8)
		var top2 := c + Vector3(cos(a2) * 15.8, 7.0, sin(a2) * 15.8)
		var foot := c + Vector3(cos((a + a2) * 0.5) * 16.4, 0.0, sin((a + a2) * 0.5) * 16.4)
		foot.y = geo.sunk([foot], c.y) - 0.2
		geo.beam(foot, top, Vector2(0.6, 0.6), "fc_concrete")
		geo.beam(foot, top2, Vector2(0.6, 0.6), "fc_concrete")
	# The basin: a low wall round the pond under it.
	geo.lathe(c, [Vector2(17.2, -0.2), Vector2(17.2, 0.9)], "fc_concrete", 36, 0.4)
	geo.tint = Color(1.3, 1.5, 1.5)
	geo.cylinder(c + Vector3(0, 0.1, 0), c + Vector3(0, 0.35, 0), 16.8, "fc_glass", 36, false)
	geo.tint = Color.WHITE
	# A ledge inside the shell (the fill's top) with the gnome on it.
	var gp: Vector3 = c + Vector3(-12.6, 12.0, 0)
	geo.tint = Color(0.7, 0.7, 0.68)
	geo.box(c + Vector3(-13.0, 11.85, 0), Vector3(1.6, 0.3, 4.0), "fc_concrete")
	geo.tint = Color.WHITE
	_gnomes.append([gp, PI * 0.5])
	return [["cooling_tower", c + Vector3(55, 20, 45), c + Vector3(0, 18, 0)],
		["cooling_inside", c + Vector3(8, 3.5, 6), c + Vector3(0, 40, 0)],
		["cooling_legs", c + Vector3(30, 3.0, 0), c + Vector3(0, 3, 0)],
		["gnome_cooling", c + Vector3(-9.5, 13.0, 1.5), gp]]

## Loading platform along the siding with a canopy on columns (fly
## under it beside the wagons), the hopper's track side.
func _platform(o: Vector3, z: float, y: float) -> Array:
	var x0: float = o.x - 40.0
	var x1: float = o.x + 30.0
	var pz: float = z + 4.6
	geo.tint = Color(0.75, 0.75, 0.72)
	geo.box_on(Transform3D(Basis(), Vector3((x0 + x1) * 0.5, y + 0.6, pz)), Vector3(x1 - x0, 1.2, 4.0), "fc_concrete", y)
	geo.tint = Color(0.95, 0.65, 0.1)
	# (a raised strip: a 2 cm one flickered with the platform top)
	geo.box(Vector3((x0 + x1) * 0.5, y + 1.23, pz - 1.8), Vector3(x1 - x0, 0.06, 0.25), "fcd_paint", 0.0, false, false)
	geo.tint = Color(0.2, 0.45, 0.7)
	var x: float = x0 + 2.0
	while x < x1:
		geo.box(Vector3(x, y + 4.7, pz + 1.5), Vector3(0.3, 7.0, 0.3), "fc_paint")
		x += 10.0
	geo.tint = Color(0.88, 0.9, 0.92)
	geo.box(Vector3((x0 + x1) * 0.5, y + 8.3, pz - 1.0), Vector3(x1 - x0 + 2.0, 0.3, 11.0), "in_clad")
	geo.tint = Color.WHITE
	return [["platform", Vector3(x1 + 18, y + 4, z - 8), Vector3(x0, y + 3, pz)],
		["under_canopy", Vector3(x1 + 4, y + 4.5, z - 1.5), Vector3(x0, y + 4.0, z)]]

## The office block by the gate: three storeys, ribbon windows, a
## glass stair tower, the company's name, AC units on the roof.
func _office(c: Vector3, y: float) -> Array:
	var W: float = 34.0
	var D: float = 14.0
	var H: float = 11.4
	geo.tint = Color(0.94, 0.94, 0.92)
	geo.box_on(Transform3D(Basis(), c + Vector3(0, H * 0.5, 0)), Vector3(W, H, D), "fc_concrete", y)
	for fl in range(3):
		for s in [-1.0, 1.0]:
			geo.tint = Color.WHITE
			geo.box(c + Vector3(0, 1.1 + fl * 3.6 + 0.85, s * (D * 0.5 + 0.03)), Vector3(W - 1.2, 1.7, 0.06), "fc_glass", 0.0, false)
	# Flat roof: grey membrane inside a blue parapet.
	geo.tint = Color(0.55, 0.56, 0.55)
	geo.box(c + Vector3(0, H + 0.05, 0), Vector3(W, 0.1, D), "fc_paint")
	geo.tint = Color(0.15, 0.4, 0.65)
	for sd in [-1.0, 1.0]:
		geo.box(c + Vector3(0, H + 0.4, sd * (D * 0.5 + 0.05)), Vector3(W + 0.4, 0.8, 0.3), "fc_paint")
		geo.box(c + Vector3(sd * (W * 0.5 + 0.05), H + 0.4, 0), Vector3(0.3, 0.8, D), "fc_paint")
	# Three flagpoles in front.
	for fi in range(3):
		var fp: Vector3 = c + Vector3(-8.0 + fi * 4.0, 0, D * 0.5 + 6.0)
		geo.tint = Color(0.85, 0.86, 0.88)
		geo.cylinder(Vector3(fp.x, geo.sunk([fp], y) - 0.1, fp.z), Vector3(fp.x, y + 9.0, fp.z), 0.06, "fc_paint", 8)
		geo.tint = [Color(0.15, 0.4, 0.65), Color(0.95, 0.95, 0.95), Color(0.9, 0.55, 0.1)][fi]
		geo.box(Vector3(fp.x + 1.0, y + 8.2, fp.z), Vector3(1.9, 1.2, 0.03), "fc_paint", 0.0, false)
	geo.box_on(Transform3D(Basis(), c + Vector3(W * 0.5 + 2.0, (H + 2.0) * 0.5, 0)), Vector3(4.0, H + 2.0, 5.0), "fc_glass", y)
	geo.tint = Color.WHITE
	StreetKit._label(geo, "LINDNER", Transform3D(Basis(), c + Vector3(-6.0, H - 1.0, D * 0.5 + 0.08)), 0.03, Color(0.12, 0.35, 0.6))
	StreetKit._label(geo, "Beschichtungen", Transform3D(Basis(), c + Vector3(8.0, H - 1.2, D * 0.5 + 0.08)), 0.014, Color(0.25, 0.27, 0.3))
	geo.tint = Color(0.75, 0.77, 0.8)
	for ax in [-10.0, -4.0, 6.0]:
		geo.box(c + Vector3(ax, H + 0.9, -1.0), Vector3(3.0, 1.6, 2.2), "fc_paint")
	geo.tint = Color.WHITE
	var gp := c + Vector3(1.0, H + 0.1, -1.0)
	_gnomes.append([gp, -PI * 0.5])
	return [["office", c + Vector3(-20, 8, 35), c + Vector3(0, 5, 0)], ["gnome_office", c + Vector3(1.0, H + 2.5, 4.0), gp]]

## A staff WC cabin: a painted container with a door ajar on the far
## side and a frosted window - the toilet stands inside.
func _wc_cabin(c: Vector3, y: float) -> Array:
	var xf := Transform3D(Basis(Vector3.UP, PI * 0.5), c)
	var L: float = 6.0
	var B: float = 2.44
	var H: float = 2.6
	geo.tint = Color(0.25, 0.5, 0.35)
	BuildKit.wall(geo, xf * Transform3D(Basis(), Vector3(0, 0, B * 0.5 - 0.05)), -L * 0.5, L * 0.5, 0.0, H, 0.1, [Rect2(1.2, 0.15, 0.9, 2.0)], "fc_paint", y)
	BuildKit.wall(geo, xf * Transform3D(Basis(), Vector3(0, 0, -B * 0.5 + 0.05)), -L * 0.5, L * 0.5, 0.0, H, 0.1, [Rect2(1.4, 1.5, 0.6, 0.5)], "fc_paint", y)
	for s in [-1.0, 1.0]:
		BuildKit.wall(geo, xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(s * (L * 0.5 - 0.05), 0, 0)), -B * 0.5 + 0.1, B * 0.5 - 0.1, 0.0, H, 0.1, [], "fc_paint", y)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, H + 0.05, 0)), Vector3(L, 0.1, B), "fc_paint")
	geo.tint = Color(0.9, 0.95, 0.95)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(1.7, 1.75, -B * 0.5 + 0.05)), Vector3(0.6, 0.5, 0.04), "fc_glass", false)
	geo.tint = Color(0.85, 0.85, 0.85)
	geo.box_on(xf * Transform3D(Basis(), Vector3(0, 0.07, 0)), Vector3(L - 0.2, 0.14, B - 0.2), "fci_paint", y)
	# The door, standing open.
	geo.tint = Color(0.2, 0.42, 0.3)
	geo.box_xf(xf * Transform3D(Basis(Vector3.UP, -1.1), Vector3(2.1, 1.15, B * 0.5 + 0.45)), Vector3(0.9, 2.0, 0.05), "fc_paint")
	geo.tint = Color.WHITE
	var trng := RandomNumberGenerator.new()
	trng.seed = 4242
	ToiletCreator.build(geo, xf * Transform3D(Basis(), Vector3(1.65, 0.14, -B * 0.5 + 0.1)), trng)
	return [["wc_cabin", xf * Vector3(1.6, 1.6, B * 0.5 + 4.0), xf * Vector3(1.6, 0.5, -B * 0.5)]]

## A yard light mast: a tall pole with a lamp head.
func _light_mast(p: Vector3, y: float) -> void:
	geo.tint = Color(0.55, 0.57, 0.6)
	geo.cylinder(Vector3(p.x, geo.sunk([p], y) - 0.1, p.z), Vector3(p.x, y + 14.0, p.z), 0.16, "fc_paint", 8)
	geo.box(Vector3(p.x, y + 14.2, p.z), Vector3(2.2, 0.3, 0.6), "fc_paint")
	geo.tint = Color.WHITE
	geo.box(Vector3(p.x, y + 14.03, p.z), Vector3(2.0, 0.04, 0.5), "fc_lamp", 0.0, false)
