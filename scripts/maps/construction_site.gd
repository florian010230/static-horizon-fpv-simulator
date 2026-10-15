extends BuiltMap

## Construction Site (High performance) - a company campus that is
## entirely under construction (v3, 2026-10-14). North = -z.
##
## Land (TerrainCreator): a forested hill to the west and south-west, open
## plain and fields to the east, a low ridge in the south-east. Two roads
## (RoadCreator) come in, each out of a tunnel portal - road A from the
## forest hill, road B from under the ridge - and meet in front of the
## gatehouse (x 0, z 150), the only way in. Inside the fence (x +-200,
## z -160..150): a gravel loop road, a cross road (z 0), a spine (x 0).
##
## North row: three towers (T1 concrete core 130 m, T2 steel frame 110 m,
## T3 glazed/open frame 145 m), four tower cranes, three walkway bridges,
## the parking garage. East: offices A and B, lab C, the cabins and yard.
## South: test and production hall, canteen D, warehouse with a truck
## yard, a foundation pit for a fourth tower, a pipe rack between hall and
## warehouse. Every entrance is registered (BuiltMap.register_entrance):
## the self-test checks that a site road reaches each one.

const LAND := Rect2(-720, -520, 1440, 1040)
const CAMPUS := Rect2(-215, -175, 430, 350) ## levelled (y 0)
const FENCE := Rect2(-200, -160, 400, 310)
const PIT := CampusKit.PIT
const PIT_DEPTH: float = CampusKit.PIT_DEPTH
const PLAZA := Rect2(-18, 192, 36, 26)
## Tunnel portals: road level, the point on the face, the direction the road leaves.
const PORTAL_A := Vector3(-282, 6.0, 160)
const PORTAL_B := Vector3(322, 2.5, 205)
const TUNNEL_LEN: float = 42.0 ## from the face back to where the road starts inside the hill
const TUNNEL_CUT: int = 5 ## the first segments (the part inside the hill) leave the land alone

## The fields on the plain east of the campus (plain landscape only: a crop or a ground layer).
const FIELDS: Array = [
	["wheat", [Vector2(285, -230), Vector2(395, -225), Vector2(400, -120), Vector2(290, -125)]],
	["rapeseed", [Vector2(415, -228), Vector2(520, -222), Vector2(525, -118), Vector2(420, -122)]],
	["ploughed", [Vector2(285, -100), Vector2(395, -95), Vector2(398, 5), Vector2(288, 0)]],
	["stubble", [Vector2(415, -98), Vector2(520, -92), Vector2(522, 8), Vector2(418, 3)]],
]

var land: TerrainCreator
var kit: CampusKit
var roads: Roads
var rng := RandomNumberGenerator.new()
var _road_a: RoadCreator
var _road_b: RoadCreator
var _road_g: RoadCreator

func map_env() -> Dictionary:
	# Late afternoon: warm, fairly low sun - the cranes and the towers
	# throw long shadows across the campus.
	return {"sun_rot": Vector3(-24, -58, 0), "sun_color": Color(1.0, 0.82, 0.62), "sun_energy": 1.4, "fog_begin": 420.0,
		"sky_top": Color(0.28, 0.45, 0.74), "sky_horizon": Color(0.92, 0.82, 0.72),
		"shadow_ground_y": 0.0, "shadow_region": Rect2(-300, -220, 600, 470)}

func border() -> Array:
	return [480.0, 560.0, 250.0, 310.0, Vector2(0, 20)]

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func cacheable() -> bool:
	return true

func cache_state() -> Dictionary:
	return {"land": land.grid_state()}

func restore_state(state: Dictionary) -> void:
	land = TerrainCreator.from_grid_state(state.land)

func preview_views() -> Array:
	return CampusViews.list()

## Lines that must stay flyable: the three lift shafts, the walkways, both
## tunnels, the corridors of the offices, the garage level 1, a warehouse
## aisle and the hall's doors.
func clear_lines() -> Array:
	var L: Array = []
	for t: Array in [["T1", CampusTowers.T1, 136.0], ["T2", CampusTowers.T2, 112.0], ["T3", CampusTowers.T3, 146.0]]:
		var c: Vector3 = t[1]
		L.append(["lift shaft " + t[0], Vector3(c.x - 0.5, 1.4, c.z), Vector3(c.x - 0.5, t[2], c.z)])
	var fh: float = CampusTowers.FH
	L.append(["walkway 1", Vector3(-115.0, 4 * fh + 1.3, -100.0), Vector3(-96.0, 4 * fh + 1.3, -100.0)])
	L.append(["walkway 2", Vector3(-60.0, 10 * fh + 1.3, -104.0), Vector3(-41.0, 10 * fh + 1.3, -104.0)])
	L.append(["walkway 3", Vector3(-60.0, 16 * fh + 1.3, -96.0), Vector3(-41.0, 16 * fh + 1.3, -96.0)])
	for rd: RoadCreator in [_road_a, _road_b]:
		var p0: Vector3 = rd.line.pts[0]
		var d: Vector3 = rd.line.pts[1] - p0
		d.y = 0.0
		d = d.normalized()
		L.append(["tunnel", p0 + d * 12.0 + Vector3(0, 1.6, 0), p0 - d * 5.0 + Vector3(0, 1.6, 0)])
	L.append(["office A corridor", Vector3(137.0, 1.7, -111.0), Vector3(159.0, 1.7, -111.0)])
	L.append(["office B corridor", Vector3(145.5, 1.7, -86.7), Vector3(154.3, 1.7, -86.7)])
	L.append(["office B corridor, studs", Vector3(145.5, 8.1, -86.7), Vector3(154.3, 8.1, -86.7)])
	L.append(["garage level 1", Vector3(21.0, 5.5, -103.0), Vector3(68.0, 5.5, -103.0)])
	L.append(["warehouse aisle", Vector3(29.0, 3.4, 44.0), Vector3(29.0, 3.4, 14.0)])
	L.append(["warehouse dock", Vector3(31.0, 2.7, 56.0), Vector3(31.0, 2.7, 44.0)])
	L.append(["hall north door", Vector3(-100.0, 1.7, 2.0), Vector3(-100.0, 1.7, 22.0)])
	L.append(["hall east door", Vector3(-60.0, 1.7, 30.0), Vector3(-100.0, 1.7, 30.0)])
	return L

func build() -> void:
	rng.seed = 5150
	geo.ao_height = 2.5
	CampusKit.add_materials(geo)
	kit = CampusKit.new(self, rng, fleet)
	var lrng := RandomNumberGenerator.new()
	lrng.seed = 23
	roads = Roads.new(geo, lrng, fleet)
	_land_and_roads(lrng)
	_site_ground()
	_site_roads()
	_fence_and_gate()
	_portals()
	CampusTowers.new(kit).build_all()
	CampusBig.new(kit).build_all()
	CampusOffices.new(kit).build_all()
	CampusYard.new(kit, roads).build_all()
	_ground_patches()
	_woods_and_fields(lrng)
	if OS.has_environment("SH_CUTOFF_TEST"):
		# Dev aid: an entrance in the middle of nowhere - the "nothing cut off" check must fail with it.
		if OS.get_environment("SH_CUTOFF_TEST") == "2":
			# ... or on a little road of its own that joins nothing.
			geo._lane(Vector2(-110, -150), Vector2(-90, -150), 3.0)
			register_entrance(Vector3(-100, 0, -150), "entrance on an island road (SH_CUTOFF_TEST=2)")
		else:
			register_entrance(Vector3(-100, 0, 180), "bogus entrance in the field (SH_CUTOFF_TEST)")

# --- land, roads, portals ------------------------------------------------------------------------

func _land_and_roads(lrng: RandomNumberGenerator) -> void:
	land = TerrainCreator.make(41, "gentle")
	land.set_extent(LAND)
	land.flat_rect(CAMPUS, 0.0, 45.0) # (the datum)
	land.flat_rect(PLAZA.grow(6.0), 0.0, 30.0)
	land.flat_rect(PIT, -PIT_DEPTH, 8.0)
	land.hill(Vector2(-380, 60), 215.0, 52.0) # the forest hill
	land.hill(Vector2(-300, 330), 120.0, 16.0)
	land.hill(Vector2(-600, -250), 260.0, 80.0) # the far end of the forest hill
	land.hill(Vector2(-520, 360), 220.0, 60.0)
	land.hill(Vector2(400, 215), 150.0, 42.0) # the low ridge in the south-east
	land.hill(Vector2(330, 330), 120.0, 14.0)
	land.keep_clear(Vector2(PORTAL_A.x, PORTAL_A.z), 38.0)
	land.keep_clear(Vector2(PORTAL_B.x, PORTAL_B.z), 38.0)
	land.keep_clear(Vector2(0, 20), 215.0)
	for fd: Array in FIELDS:
		land.keep_clear_poly(FieldCreator.poly(fd[1]))
	var pa := Vector2(PORTAL_A.x, PORTAL_A.z)
	var pb := Vector2(PORTAL_B.x, PORTAL_B.z)
	var out_a: Vector3 = Route.dir_of(20.0)
	var out_b: Vector3 = Route.dir_of(180.0 - 10.0)
	var start_a: Vector3 = PORTAL_A - out_a * TUNNEL_LEN
	var start_b: Vector3 = PORTAL_B - out_b * TUNNEL_LEN
	_road_a = RoadCreator.plan(land, start_a, 20.0, [Vector2(-210, 192), Vector2(-120, 205), Vector2(-14, 205)], 7.0,
		{"radius": 70.0, "lead": TUNNEL_LEN + 24.0, "end": "entrance", "verge": 1.0,
		"hold": [[pa, PORTAL_A.y, 55.0], [Vector2(-10, 205), 0.0, 70.0]]})
	_road_b = RoadCreator.plan(land, start_b, 170.0, [Vector2(250, 225), Vector2(150, 210), Vector2(14, 205)], 7.0,
		{"radius": 70.0, "lead": TUNNEL_LEN + 24.0, "end": "entrance", "verge": 1.0,
		"hold": [[pb, PORTAL_B.y, 55.0], [Vector2(10, 205), 0.0, 70.0]]})
	_road_g = RoadCreator.plan(land, Vector3(0, 0, 200), -90.0, [Vector2(0, 150)], 8.0, {"radius": 30.0, "lead": 12.0, "end": "entrance", "verge": 1.0,
		"hold": [[Vector2(0, 175), 0.0, 40.0]]})
	# The tunnel stretches: the land is left alone there (no cutting into
	# the hill itself), the road is not drawn there either (see below).
	for rd: RoadCreator in [_road_a, _road_b]:
		for k in range(TUNNEL_CUT):
			rd.line.bridge[k] = 1
	land.build(self, geo, LAND)
	if OS.has_environment("SH_PORTALS"):
		for pp: Vector3 in [PORTAL_A, PORTAL_B]:
			var od: Vector3 = Route.dir_of(20.0 if pp == PORTAL_A else 170.0)
			var line: String = ""
			for kk in [-30, -20, -10, 0, 10, 20, 40, 80]:
				var q: Vector3 = pp + od * kk
				line += " %d:%.1f" % [kk, land.staged(q.x, q.z, TerrainCreator.FLATS)]
			print("PORTAL natural ground along the road from ", pp, " (negative = into the hill): ", line, " road at start ", (_road_a if pp == PORTAL_A else _road_b).line.pts[7])
	# Draw only from the portal on: the tube has its own floor.
	for rd: RoadCreator in [_road_a, _road_b]:
		var np: Array[Vector3] = []
		for k in range(7, rd.line.pts.size()):
			np.append(rd.line.pts[k])
		rd.line.pts = np
		rd.line.bridge = rd.line.bridge.slice(7)
	for rd: RoadCreator in [_road_a, _road_b, _road_g]:
		rd.draw(geo, roads, lrng)
	# The plaza in front of the gate: all three roads end on it.
	geo.add_material("plaza_mark", Geo.ground_flat(Color(0.92, 0.92, 0.9), 3))
	geo.slab(PLAZA, 0.0, 0.6, "rd_asphalt")
	geo._lane(Vector2(PLAZA.position.x, PLAZA.get_center().y), Vector2(PLAZA.end.x, PLAZA.get_center().y), PLAZA.size.y * 0.5)

func _portals() -> void:
	var cp := CampusPortal.new(kit)
	for rd: RoadCreator in [_road_a, _road_b]:
		var p0: Vector3 = rd.line.pts[0]
		var dir: Vector3 = rd.line.pts[1] - p0
		dir.y = 0.0
		dir = dir.normalized()
		# The tube is as long as the cutting is flat: where the hill's ramp
		# starts behind the face, the tube ends (the terrain mesh can't be
		# carved, a ramp through the tube's air would show inside it).
		var L: float = 6.0
		for q in range(1, 90):
			var s: float = q * 0.5
			var pt: Vector3 = p0 - dir * s
			if land.ground(pt.x, pt.z) > p0.y + 0.1:
				break
			L = s
		cp.portal(p0, dir, 7.0, maxf(L - 0.6, 6.0))

# --- the campus ground -------------------------------------------------------------------------------------

## Gravel inside the haul-road loop (and an apron at the gate); outside the
## loop the meadow is left (only trodden flat). The pit: bare earth draped
## on the terrain, floor and banks.
const LOOP_GROUND := Rect2(-178, -138, 356, 266)

func _site_ground() -> void:
	for r in CampusKit.rect_minus(LOOP_GROUND, [PIT.grow(9.0)]):
		geo.slab(r, 0.0, 1.0, "site", false)
	geo.slab(Rect2(-22, LOOP_GROUND.end.y, 44, FENCE.end.y - 2.0 - LOOP_GROUND.end.y), 0.0, 1.0, "site", false)
	var fc := FieldCreator.new()
	fc.geo = geo
	fc.land = land
	var e: Rect2 = PIT.grow(9.0)
	fc._drape(PackedVector2Array([e.position, Vector2(e.end.x, e.position.y), e.end, Vector2(e.position.x, e.end.y)]), 0.03, "bank")
	# The bank starts falling a little before the gravel ends (8 m terrain
	# grid): an earth skirt under the gravel's edge closes the step, or the
	# meadow under the gravel shows through it.
	var cx: float = e.get_center().x
	var cz: float = e.get_center().y
	for s in [-1.0, 1.0]:
		geo.box(Vector3(cx, -0.75, cz + s * (e.size.y * 0.5 - 0.05)), Vector3(e.size.x, 1.5, 0.08), "mud", 0.0, false, false)
		geo.box(Vector3(cx + s * (e.size.x * 0.5 - 0.05), -0.75, cz), Vector3(0.08, 1.5, e.size.y), "mud", 0.0, false, false)

## Patches on the open gravel (seen from the air it was one brown sheet):
## weeds where nobody drives, wet mud, lighter crushed stone. Laid last,
## off the roads, the pit and everything standing.
func _ground_patches() -> void:
	var prng := RandomNumberGenerator.new()
	prng.seed = 3407
	var placed: Array = [] # [centre, r]
	var area: Rect2 = LOOP_GROUND.grow(-4.0)
	var tries: int = 0
	while placed.size() < 70 and tries < 1500:
		tries += 1
		var r: float = prng.randf_range(3.5, 11.0)
		var c := Vector2(prng.randf_range(area.position.x + r, area.end.x - r), prng.randf_range(area.position.y + r, area.end.y - r))
		if PIT.grow(10.0 + r).has_point(c) or geo.on_lane(c, r + 1.0):
			continue
		var free: bool = not geo.blocked(c, r * 0.5, 0.0, 0.6)
		for q: Array in placed:
			if c.distance_to(q[0]) < r + q[1] + 1.0:
				free = false
		if not free:
			continue
		var n: int = 14
		var ph := Vector2(prng.randf() * TAU, prng.randf() * TAU)
		var rim: Array[Vector2] = []
		for i in range(n):
			var a: float = TAU * i / n
			rim.append(c + Vector2(cos(a), sin(a)) * r * (1.0 + 0.22 * sin(3.0 * a + ph.x) + 0.12 * sin(5.0 * a + ph.y)))
		for q in rim:
			if geo.blocked(q, 0.3, 0.0, 0.6) or geo.on_lane(q, 0.5):
				free = false
		if not free:
			continue
		placed.append([c, r])
		var kind: float = prng.randf()
		var mat: String = "weeds" if kind < 0.4 else ("mudpatch" if kind < 0.75 else "stone")
		var tri := PackedVector3Array()
		for i in range(n):
			var a: Vector2 = rim[i]
			var b: Vector2 = rim[(i + 1) % n]
			tri.append_array([Vector3(c.x, 0.0, c.y), Vector3(a.x, 0.0, a.y), Vector3(b.x, 0.0, b.y)])
		geo.tris(tri, mat)

func _site_roads() -> void:
	# Horizontal roads whole, vertical ones cut where they cross them (same
	# layer: no overlaps).
	var hs: Array = [[-130.0, -175.0, 175.0, 10.0], [0.0, -175.0, 175.0, 8.0], [120.0, -175.0, 175.0, 10.0],
		[-70.0, -165.0, 165.0, 7.0], [-98.0, 108.0, 165.0, 7.0]]
	var vs: Array = [[-170.0, -135.0, 125.0, 10.0], [170.0, -135.0, 125.0, 10.0], [0.0, -135.0, 150.0, 8.0],
		[-62.0, 0.0, 120.0, 6.0],
		[CampusTowers.T1.x, -85.5, -70.0, 6.0], [CampusTowers.T2.x, -85.5, -70.0, 6.0], [CampusTowers.T3.x, -85.5, -70.0, 6.0],
		[-69.0, 82.0, 90.0, 8.0]]
	for h: Array in hs:
		kit.haul(Rect2(h[1], h[0] - h[3] * 0.5, h[2] - h[1], h[3]))
	for v: Array in vs:
		var cuts: Array = []
		for h: Array in hs:
			var x0: float = v[0] - v[3] * 0.5
			var x1: float = v[0] + v[3] * 0.5
			if h[1] < x1 and h[2] > x0 and h[0] + h[3] * 0.5 > v[1] and h[0] - h[3] * 0.5 < v[2]:
				cuts.append([h[0] - h[3] * 0.5, h[0] + h[3] * 0.5])
		cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var z: float = v[1]
		for c: Array in cuts:
			if c[0] > z + 0.01:
				kit.haul(Rect2(v[0] - v[3] * 0.5, z, v[3], c[0] - z))
			z = maxf(z, c[1])
		if v[2] > z + 0.01:
			kit.haul(Rect2(v[0] - v[3] * 0.5, z, v[3], v[2] - z))

func _fence_and_gate() -> void:
	var outs: Array = [Vector3(0, 0, -1), Vector3(0, 0, 1), Vector3(-1, 0, 0), Vector3(1, 0, 0)]
	var gate_x := 0.0
	var gap := 7.0
	var seg_i: int = 0
	for side in range(4):
		var along_x: bool = side < 2
		var out: Vector3 = outs[side]
		var fixed: float = FENCE.position.y if side == 0 else (FENCE.end.y if side == 1 else (FENCE.position.x if side == 2 else FENCE.end.x))
		var a0: float = FENCE.position.x if along_x else FENCE.position.y
		var a1: float = FENCE.end.x if along_x else FENCE.end.y
		var t: float = a0
		while t < a1 - 0.1:
			var seg: float = minf(3.5, a1 - t)
			var mid: float = t + seg * 0.5
			var skip: bool = false
			if side == 1 and absf(mid - gate_x) < gap + seg * 0.5:
				skip = true
			# A road through the fence (the loop's spokes are inside, so none).
			if not skip:
				var pos := Vector3(mid, 1.15, fixed) if along_x else Vector3(fixed, 1.15, mid)
				geo.box(pos, Vector3(seg - 0.05, 2.7, 0.08) if along_x else Vector3(0.08, 2.7, seg - 0.05), "hoarding" if int(mid / 7.0) % 3 else "hoarding_w", 0.0, true, false)
				seg_i += 1
				if seg_i % 9 == 0 and seg > 3.0:
					_banner(pos, out, seg - 0.5, seg_i / 9)
			t += seg
	CampusYard.gate(kit, Vector3(gate_x, 0, FENCE.end.y), Vector3(0, 0, 1), gap * 2.0)
	register_entrance(Vector3(0, 0, FENCE.end.y - 1.0), "gatehouse", true)

const BANNERS: Array = [
	["BAUSTELLE", "Betreten verboten"], ["STATIC BAU GmbH", "Wir bauen auf Sie"], ["Eltern haften", "für ihre Kinder"],
	["HIER ENTSTEHT", "Der Campus der Zukunft"], ["Achtung", "Baustellenverkehr"], ["Kran im Betrieb", "Drohnen bitte oben bleiben"],
	["Danke für Ihre Geduld", "Fertig im Frühjahr"], ["Sicherheit zuerst", "Helm auf, Kopf an"]]

func _banner(pos: Vector3, out: Vector3, width: float, idx: int) -> void:
	var f: Transform3D = Transform3D(Basis.looking_at(-out, Vector3.UP), Vector3(pos.x, 0.0, pos.z))
	kit.bf(f, Vector3(0, 1.5, 0.06), Vector3(width, 1.2, 0.04), ["banner_a", "banner_b", "banner_c"][idx % 3], false, false)
	var t: Array = BANNERS[idx % BANNERS.size()]
	var dark: bool = idx % 3 == 0
	StreetKit._label(geo, t[0], f * Transform3D(Basis(), Vector3(0, 1.72, 0.09)), 0.0085, Color(0.1, 0.1, 0.1) if dark else Color(0.97, 0.97, 0.95), width - 0.4)
	StreetKit._label(geo, t[1], f * Transform3D(Basis(), Vector3(0, 1.26, 0.09)), 0.005, Color(0.1, 0.1, 0.1) if dark else Color(0.9, 0.9, 0.88), width - 0.4)

# --- woods and fields --------------------------------------------------------------------------------------

func _woods_and_fields(lrng: RandomNumberGenerator) -> void:
	var trees: Array = []
	for fd: Array in FIELDS:
		trees.append_array(FieldCreator.build(geo, land, fd[1], fd[0], lrng, {"hedges": [0]}).trees)
	var woods: Array = [[Vector2(-380, 60), 215.0], [Vector2(-300, 330), 110.0], [Vector2(-600, -250), 240.0], [Vector2(-520, 360), 200.0]]
	trees.append_array(land.woods(lrng, Rect2(-715, -500, 500, 900), 1500, 1000.0, woods))
	TreeCreator.plant(self, geo, trees)
