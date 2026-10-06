class_name FarmCreator
extends RefCounted

## Creator: a farmstead on its own level yard - a big timber barn with
## its doors slid open at both ends (fly straight through; hay stacked
## inside, a loft to dive under), a grain silo, an open machine shed, the
## farmhouse (HouseCreator, closed), a tractor with a trailer of bales.
## The map places it and brings a lane to the yard's west edge.
##
##   var farm: Dictionary = FarmCreator.plan(land, centre, size)   before land.build
##   FarmCreator.build(geo, land, farm, seed) -> {"views": [...], "trees": [...]}
##   FarmCreator.tractor(geo, p, yaw, paint, trailer)   for a field too
## The yard is axis-aligned (x east, z south); the lane comes in at the
## middle of its east edge (plan's `entry` +1) or its west edge (-1) -
## the layout mirrors to keep that side open: barn along the north edge
## at the far end, silo on the near north corner, machine shed on the
## near south corner, house on the far south corner.
## Real numbers: a German Feldscheune ~25 x 14 m, eaves 6 m, ridge ~11 m,
## doors 5 x 5 m; a farm silo 5-6 m across, 15-20 m tall; a mid-size
## tractor 4.5 m long, rear wheels 1.7 m, front 1.1 m.

const BARN_L: float = 26.0
const BARN_B: float = 14.0
const BARN_EAVES: float = 6.0
const BARN_RIDGE: float = 11.0
const DOOR_W: float = 6.0
const DOOR_H: float = 5.2

static func ensure_materials(g: Geo) -> void:
	if g.has_material("fm_boards"):
		return
	g.add_material("fm_boards", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.62, 0.3, 0.22), 2.0))
	g.add_material("fm_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.9, 0.78, 0.62), 1.2))
	g.add_material("fm_roof", Geo.tex_mat(MapTextures.get_tex("roof_tiles"), Color(0.8, 0.5, 0.4), 3.0))
	g.add_material("fm_metal", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.82, 0.84, 0.85), 2.0))
	g.add_material("fm_stone", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.85, 0.83, 0.8), 3.0))
	g.add_material("fm_yard", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(1.0, 0.96, 0.9), 4.0, 1, 0.4))
	g.add_material("fm_paint", Geo.flat_mat(Color.WHITE, 0.5))
	g.add_material("fm_dark", Geo.flat_mat(Color(0.12, 0.12, 0.13), 0.6))
	# The barn's own (lit inside by _barn_light, not the shadow map).
	g.add_material("fm_bin", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.95, 0.8, 0.64), 2.0)) # bare boards inside
	g.add_material("fm_bstone", Geo.tex_mat(MapTextures.get_tex("concrete_slab"), Color(1.0, 0.94, 0.85), 4.0))
	g.add_material("fm_bwood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.9, 0.78, 0.62), 1.2))
	g.add_material("fm_bstraw", Geo.tex_mat(MapTextures.get_tex("straw"), Color.WHITE, 1.5))
	g.add_material("fm_bsky", Geo.flat_mat(Color(1.0, 0.98, 0.9), 0.4))
	for m in ["fm_bin", "fm_bstone", "fm_bwood", "fm_bstraw", "fm_bsky"]:
		g.material(m).set_meta("no_shadow", true)
	var shaft := StandardMaterial3D.new()
	shaft.albedo_color = Color(1.0, 0.94, 0.75, 0.08)
	shaft.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	shaft.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shaft.cull_mode = BaseMaterial3D.CULL_DISABLED
	shaft.vertex_color_use_as_albedo = false
	g.add_material("fm_shaft", shaft)
	FieldCreator.ensure_materials(g)
	Vehicles.ensure_materials(g)
	g.detail_prefixes.append("fmd_")
	g.add_material("fmd_paint", Geo.flat_mat(Color.WHITE, 0.5))
	g.add_material("fm_manure", Geo.tex_mat(MapTextures.get_tex("straw"), Color(0.75, 0.62, 0.48), 1.2))

## Levels the yard (before land.build): centre (x, z), size (x, z) in m.
## The level is the land's own height there (averaged), so the yard
## sits in it rather than on a mound.
static func plan(land: TerrainCreator, centre: Vector2, size: Vector2, entry: float = 1.0) -> Dictionary:
	var sum: float = 0.0
	var n: int = 0
	for fx in [-0.5, 0.0, 0.5]:
		for fz in [-0.5, 0.0, 0.5]:
			sum += land.staged(centre.x + fx * size.x, centre.y + fz * size.y, TerrainCreator.RIVERS)
			n += 1
	var y: float = snappedf(sum / n, 0.1)
	var m: float = land.road_bed()
	land.flat_plot(centre, Vector2(1, 0), size.x * 0.5 + m, size.y * 0.5 + m, y, 30.0, [centre, size.x * 0.5, size.y * 0.5])
	land.keep_clear(centre, size.length() * 0.5 + 10.0, true)
	return {"c": centre, "size": size, "y": y, "entry": entry}

static func build(g: Geo, land: TerrainCreator, farm: Dictionary, seed_value: int) -> Dictionary:
	ensure_materials(g)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var c: Vector2 = farm.c
	var y: float = farm.y
	var o := Vector3(c.x, y, c.y)
	var sz: Vector2 = farm.size
	var views: Array = []
	# The yard: gravel over the level ground.
	var hx: float = sz.x * 0.5
	var hz: float = sz.y * 0.5
	g.polygon([o + Vector3(-hx, 0.03, -hz), o + Vector3(hx, 0.03, -hz), o + Vector3(hx, 0.03, hz), o + Vector3(-hx, 0.03, hz)], "fm_yard", false)
	var ex: float = farm.get("entry", 1.0) # +1: the lane side is east
	# The barn along the north side at the far end, its doors east and west.
	var barn: Vector3 = o + Vector3(ex * (-hx + BARN_L * 0.5 + 4.0), 0, -hz + BARN_B * 0.5 + 4.0)
	_barn(g, barn, rng)
	views.append(["barn_through", barn + Vector3(-BARN_L * 0.5 - 18.0, 3.0, 0.5), barn + Vector3(BARN_L * 0.5, 2.5, 0)])
	views.append(["barn_inside", barn + Vector3(-BARN_L * 0.5 + 3.0, 2.0, 3.5), barn + Vector3(BARN_L * 0.3, 2.5, -2.0)])
	# Grain silo on the near north corner, the machine shed near south.
	var silo: Vector3 = o + Vector3(ex * (hx - 5.0), 0, -hz + 6.0)
	_silo(g, silo, ex)
	var shed: Vector3 = o + Vector3(ex * (hx - 14.0), 0, hz - 5.0)
	_machine_shed(g, shed, rng)
	# The farmhouse in the south-west corner, door to the yard (north).
	var house: Dictionary = HouseCreator.build(g, o + Vector3(ex * (-hx + 11.0), 0, hz - 8.0), PI, rng.randi(), {"interior": false, "garage": "none", "storeys": 2})
	views.append_array(house.views.slice(0, 1))
	# The tractor in the yard with a trailer of bales.
	var tp: Vector3 = o + Vector3(ex * -4.0, 0.0, 4.0)
	tractor(g, tp, PI * 0.5 + rng.randf_range(-0.2, 0.2), ["fm_green", "fm_red", "fm_blue"][rng.randi() % 3], true, rng)
	views.append(["farm", o + Vector3(ex * (hx + 25.0), 22.0, hz + 30.0), o])
	views.append(["tractor", tp + Vector3(-6.0, 2.2, 6.0), tp])
	views.append_array(_yard_things(g, o, ex, hx, hz, farm.get("chickens", 0)))
	# A walnut tree by the house, a couple of fruit trees.
	var trees: Array = [[o + Vector3(ex * (-hx + 4.0), -0.05, hz + 6.0), "maple", rng.randi(), "none"],
		[o + Vector3(ex * (-hx - 4.0), -0.05, hz - 2.0), "apple", rng.randi(), "none"]]
	return {"views": views, "trees": trees, "barn": barn}

## The farmyard's small things, each on the first free spot of a few
## (Geo.blocked): a manure heap in its concrete bunker by the barn, a
## diesel tank on its stand by the machine shed, a dog kennel by the
## house - and, as the rare surprise (1 farm in 3), chickens out
## pecking in the yard. Own dice (seeded from the farm's place), so the
## farm's other pieces stay as they were.
## chickens: 0 = by the dice, 1 = always, -1 = never (a lab, a map's choice).
static func _yard_things(g: Geo, o: Vector3, ex: float, hx: float, hz: float, chickens: int = 0) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = hash([snappedf(o.x, 0.1), snappedf(o.z, 0.1), "yard"])
	var views: Array = []
	var y: float = o.y + 0.03 # the gravel's top
	# Manure heap (Mistplatte): a slab with three low walls, the heap in it.
	var mp: Vector3 = _spot(g, o, [Vector3(ex * 6.0, 0, -hz + 7.0), Vector3(ex * 8.0, 0, -hz + 12.0), Vector3(ex * -2.0, 0, -4.0)], 3.6, y)
	if mp != Vector3.INF:
		g.tint = Color(0.72, 0.72, 0.7)
		g.box_on(Transform3D(Basis(), mp + Vector3(0, 0.08, 0)), Vector3(7.0, 0.16, 5.0), "fm_stone", y)
		for e: Array in [[Vector3(0, 0.75, -2.4), Vector3(7.0, 1.2, 0.2)], [Vector3(-3.4, 0.75, 0), Vector3(0.2, 1.2, 4.6)], [Vector3(3.4, 0.75, 0), Vector3(0.2, 1.2, 4.6)]]:
			g.box(mp + (e[0] as Vector3), e[1], "fm_stone")
		g.tint = Color(0.42, 0.32, 0.22)
		g.frustum(Transform3D(Basis(), mp + Vector3(0, 0.16 + 0.65, -0.2)), Vector3(6.2, 1.3, 4.2), 3.0, 1.6, 0.0, "fm_manure")
		g.tint = Color.WHITE
		g.box(mp + Vector3(1.0, 1.5, 0.3), Vector3(0.05, 1.3, 0.05), "fm_wood", false) # a fork stuck in it
		views.append(["farm_manure", mp + Vector3(ex * 7.0, 3.0, 7.0), mp])
	# Diesel tank on a stand with its pump, by the machine shed.
	var tp: Vector3 = _spot(g, o, [Vector3(ex * (hx - 24.0), 0, hz - 5.0), Vector3(ex * (hx - 4.0), 0, hz - 12.0), Vector3(ex * (hx - 4.0), 0, 10.0)], 2.0, y)
	if tp != Vector3.INF:
		g.tint = Color(0.45, 0.45, 0.47)
		for dz in [-0.8, 0.8]:
			g.box_on(Transform3D(Basis(), tp + Vector3(0, 0.45, dz)), Vector3(1.0, 0.9, 0.15), "fm_paint", y)
		g.tint = [Color(0.2, 0.45, 0.25), Color(0.75, 0.15, 0.1)][r.randi() % 2]
		g.cylinder(tp + Vector3(0, 1.5, -1.3), tp + Vector3(0, 1.5, 1.3), 0.62, "fm_paint", 14)
		g.tint = Color(0.2, 0.2, 0.22)
		g.box(tp + Vector3(0.68, 1.4, 0.6), Vector3(0.12, 0.5, 0.3), "fmd_paint", 0.0, false) # the pump
		g.cylinder(tp + Vector3(0.74, 1.2, 0.6), tp + Vector3(0.74, 0.4, 0.75), 0.025, "fmd_paint", 4, false) # its hose
		g.tint = Color.WHITE
	# The dog's kennel by the house, its bowl in front.
	var kp: Vector3 = _spot(g, o, [Vector3(ex * (-hx + 20.0), 0, hz - 7.0), Vector3(ex * (-hx + 18.0), 0, hz - 12.0), Vector3(ex * (-hx + 4.0), 0, 2.0)], 1.2, y)
	if kp != Vector3.INF:
		var kx := Transform3D(Basis(Vector3.UP, PI * 0.5 * ex), kp)
		g.tint = Color(0.75, 0.55, 0.35)
		g.box_on(kx * Transform3D(Basis(), Vector3(0, 0.45, 0)), Vector3(0.9, 0.8, 1.1), "fm_wood", y)
		g.tint = Color(0.6, 0.25, 0.18)
		g.prism(kx * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), [Vector2(-0.6, 0.85), Vector2(0.6, 0.85), Vector2(0, 1.3)], 1.3, "fm_paint")
		g.tint = Color(0.08, 0.07, 0.06)
		g.box_xf(kx * Transform3D(Basis(), Vector3(0, 0.38, -0.56)), Vector3(0.4, 0.5, 0.03), "fmd_paint", false) # the way in
		g.tint = Color(0.15, 0.35, 0.7)
		g.cylinder(kx * Vector3(0.3, 0.0, -1.0), kx * Vector3(0.3, 0.1, -1.0), 0.13, "fmd_paint", 10)
		g.tint = Color.WHITE
		views.append(["farm_kennel", kx * Vector3(1.5, 1.4, -3.5), kx * Vector3(0, 0.5, 0)])
	# Chickens, now and then: a few hens pecking about by the barn door.
	var hens: bool = r.randf() < 0.34
	if chickens != 0:
		hens = chickens > 0
	if hens:
		var cc: Vector3 = o + Vector3(ex * -2.0, 0, -hz + 2.5 + BARN_B * 0.5 + 4.0)
		var n: int = r.randi_range(4, 7)
		for k in range(n):
			var hp: Vector3 = cc + Vector3(r.randf_range(-4.0, 4.0), 0, r.randf_range(-2.5, 2.5))
			if g.blocked(Vector2(hp.x, hp.z), 0.3, y + 0.05, y + 0.5):
				continue
			hp.y = y
			_hen(g, Transform3D(Basis(Vector3.UP, r.randf() * TAU), hp), r.randf() < 0.4, r.randf() < 0.5)
		views.append(["farm_chickens", cc + Vector3(ex * 4.0, 1.0, 4.0), cc])
	return views

## The first spot (relative to o) with r m free round it.
static func _spot(g: Geo, o: Vector3, cands: Array, r: float, y: float) -> Vector3:
	for q: Vector3 in cands:
		var p: Vector3 = o + q
		if not g.blocked(Vector2(p.x, p.z), r, y + 0.1, y + 2.0) and not g.on_lane(Vector2(p.x, p.z), r * 0.5):
			p.y = y
			return p
	return Vector3.INF

## A hen, 40 cm long (white or brown), pecking (head down) or looking up.
static func _hen(g: Geo, xf: Transform3D, white: bool, pecking: bool) -> void:
	var body: Color = Color(0.95, 0.94, 0.9) if white else Color(0.6, 0.32, 0.15)
	g.tint = Color(0.85, 0.65, 0.2)
	for e in [-0.05, 0.05]:
		g.box_xf(xf * Transform3D(Basis(), Vector3(e, 0.07, 0)), Vector3(0.025, 0.14, 0.025), "fmd_paint", false)
	g.tint = body
	g.box_xf(xf * Transform3D(Basis(Vector3.RIGHT, -0.25), Vector3(0, 0.24, 0.03)), Vector3(0.2, 0.2, 0.32), "fmd_paint", false)
	g.box_xf(xf * Transform3D(Basis(Vector3.RIGHT, 0.6), Vector3(0, 0.33, 0.17)), Vector3(0.14, 0.14, 0.08), "fmd_paint", false) # tail
	var head: Vector3 = Vector3(0, 0.12, -0.24) if pecking else Vector3(0, 0.42, -0.14)
	g.box_xf(xf * Transform3D(Basis(), head), Vector3(0.09, 0.1, 0.1), "fmd_paint", false)
	g.tint = Color(0.85, 0.12, 0.1)
	g.box_xf(xf * Transform3D(Basis(), head + Vector3(0, 0.07, 0.0)), Vector3(0.02, 0.05, 0.08), "fmd_paint", false)
	g.tint = Color(0.95, 0.7, 0.15)
	g.box_xf(xf * Transform3D(Basis(), head + Vector3(0, -0.01, -0.07)), Vector3(0.03, 0.03, 0.05), "fmd_paint", false)
	g.tint = Color.WHITE

## The barn: plank walls on a stone plinth, a big door opening in each
## gable, the leaves slid aside; inside, hay stacked to the loft. Inside
## it sits in its own roof's shadow, so its inner faces carry baked barn
## light instead of the shadow map (materials "fm_b*", no_shadow; see
## _barn_light): dim, brighter toward the open doors, and two skylights
## (corrugated light panels, as real barns have) in the sunny slope that
## throw dusty light shafts onto the floor.
static func _barn(g: Geo, c: Vector3, rng: RandomNumberGenerator) -> void:
	var L: float = BARN_L
	var B: float = BARN_B
	var E: float = BARN_EAVES
	var R: float = BARN_RIDGE
	var T: float = 0.3
	# The skylights: x ranges along the barn, on the slope facing the sun
	# (ss), between u0..u1 along the slope (0 = eaves). Clear of the loft.
	var ss: float = 1.0 if -g.sun_dir.z >= 0.0 else -1.0
	var run: float = B * 0.5 + 0.7
	var a: float = atan2(R - E, B * 0.5)
	var plane: float = run / cos(a)
	var sky: Array = [[-L * 0.32 - 0.7, -L * 0.32 + 0.7], [-L * 0.08 - 0.7, -L * 0.08 + 0.7]]
	var u0: float = plane * 0.38
	var u1: float = plane * 0.62
	# Each skylight's corners (under the roof) and where the sun through
	# them lands on the floor - the light shaft between, the sun patch.
	var patches: Array = [] # [top corners, floor corners]
	var sd: Vector3 = g.sun_dir.normalized()
	var fy: float = c.y + 0.54
	var rxf := Transform3D(Basis(Vector3.RIGHT, ss * a), c + Vector3(0, R - (run * 0.5) * tan(a) + 0.12, ss * run * 0.5))
	var szc: float = ss * ((plane + 0.1) * 0.5 - (u0 + u1) * 0.5)
	for sk: Array in sky:
		var top: Array = []
		var foot: Array = []
		for k: Vector2 in [Vector2(sk[0], -1), Vector2(sk[1], -1), Vector2(sk[1], 1), Vector2(sk[0], 1)]:
			var q: Vector3 = rxf * Vector3(k.x, -0.12, szc + k.y * (u1 - u0) * 0.5)
			top.append(q)
			foot.append(q + sd * ((q.y - fy) / maxf(-sd.y, 0.2)))
		patches.append([top, foot])
	var saved: Callable = g.light_fn
	var inside: Callable = func(n: Vector3, p: Vector3) -> Color: return _barn_light(g, n, p, c, patches)
	# Plinth, and the floor on it in 0.5 m cells (the light changes across it).
	g.box_on(Transform3D(Basis(), c + Vector3(0, 0.25, 0)), Vector3(L + 0.4, 0.5, B + 0.4), "fm_stone", c.y)
	g.light_fn = inside
	g.quad_grid(c + Vector3(-L * 0.5, 0.54, -B * 0.5 + T), Vector3(L, 0, 0), Vector3(0, 0, B - 2.0 * T), Vector3.UP, "fm_bstone", 0.5, true)
	g.light_fn = saved
	# Long walls; inside, weathered boards (lit as inside, 1 m cells).
	for s in [-1.0, 1.0]:
		g.box(c + Vector3(0, 0.5 + (E - 0.5) * 0.5, s * (B * 0.5 - T * 0.5)), Vector3(L, E - 0.5, T), "fm_boards")
		g.light_fn = inside
		g.quad_grid(c + Vector3(-L * 0.5 + T, 0.5, s * (B * 0.5 - T - 0.01)), Vector3(L - 2.0 * T, 0, 0), Vector3(0, E - 0.5, 0), Vector3(0, 0, -s), "fm_bin", 1.0)
		g.light_fn = saved
	for s in [-1.0, 1.0]:
		# Small dark windows high up, every 5 m.
		for k in range(4):
			var x: float = -L * 0.5 + 4.0 + k * 6.0
			g.box(c + Vector3(x, E - 1.4, s * (B * 0.5 + 0.01)), Vector3(1.2, 0.8, 0.05), "fm_dark", 0.0, false)
	# Gable ends: wall either side of the door, a lintel, the triangle.
	var side_w: float = (B - DOOR_W) * 0.5
	for s in [-1.0, 1.0]:
		var x: float = s * (L * 0.5 - T * 0.5)
		for k in [-1.0, 1.0]:
			g.box(c + Vector3(x, 0.5 + (E - 0.5) * 0.5, k * (DOOR_W * 0.5 + side_w * 0.5)), Vector3(T, E - 0.5, side_w), "fm_boards")
		g.box(c + Vector3(x, (DOOR_H + 0.5 + E) * 0.5, 0), Vector3(T, E - DOOR_H - 0.5, DOOR_W), "fm_boards")
		g.prism(Transform3D(Basis(), c + Vector3(x, 0, 0)), [Vector2(-B * 0.5, E), Vector2(B * 0.5, E), Vector2(0, R)], T, "fm_boards")
		# The inside of the gable.
		var xi: float = s * (L * 0.5 - T - 0.01)
		var nin := Vector3(-s, 0, 0)
		g.light_fn = inside
		for k in [-1.0, 1.0]:
			var z0: float = k * DOOR_W * 0.5
			g.quad_grid(c + Vector3(xi, 0.5, z0), Vector3(0, 0, k * (side_w - T)), Vector3(0, E - 0.5, 0), nin, "fm_bin", 1.0)
		g.quad_grid(c + Vector3(xi, 0.5 + DOOR_H, -DOOR_W * 0.5), Vector3(0, 0, DOOR_W), Vector3(0, E - DOOR_H - 0.5, 0), nin, "fm_bin", 1.0)
		g.prism(Transform3D(Basis(), c + Vector3(xi + s * 0.005, 0, 0)), [Vector2(-B * 0.5 + T, E - 0.05), Vector2(B * 0.5 - T, E - 0.05), Vector2(0, R - 0.1)], 0.01, "fm_bin", false)
		g.light_fn = saved
		# The two leaves, slid open along the wall outside it, with braces.
		for k in [-1.0, 1.0]:
			var lc: Vector3 = c + Vector3(s * (L * 0.5 + 0.12), 0.5 + DOOR_H * 0.5, k * (DOOR_W * 0.5 + 1.5))
			g.box(lc, Vector3(0.12, DOOR_H, 3.1), "fm_wood")
			g.tint = Color(0.75, 0.75, 0.75)
			g.beam(lc + Vector3(s * 0.08, -DOOR_H * 0.45, -1.4 * k), lc + Vector3(s * 0.08, DOOR_H * 0.45, 1.4 * k), Vector2(0.06, 0.18), "fm_wood", false)
			g.tint = Color.WHITE
		# The door track above the opening.
		g.box(c + Vector3(s * (L * 0.5 + 0.2), 0.5 + DOOR_H + 0.15, 0), Vector3(0.12, 0.15, DOOR_W + 6.4), "fm_dark")
	# Roof: two pitched planes with an overhang, the sunny one cut round
	# the skylights; under each, a lining of boards (lit as inside).
	for s in [-1.0, 1.0]:
		var bas := Basis(Vector3.RIGHT, s * a)
		var mid := c + Vector3(0, R - (run * 0.5) * tan(a) + 0.12, s * run * 0.5)
		var xf := Transform3D(bas, mid)
		# (Local z runs down the slope toward the eaves for s = +1, up
		# for s = -1: u measured from the eaves maps to z = s * (plane/2 - u).)
		var pieces: Array = [] # [x0, x1, u0, u1]
		if s == ss:
			var xs: float = -(L + 1.2) * 0.5
			for sk: Array in sky:
				pieces.append([xs, sk[0], 0.0, plane + 0.1])
				pieces.append([sk[0], sk[1], 0.0, u0])
				pieces.append([sk[0], sk[1], u1, plane + 0.1])
				xs = sk[1]
			pieces.append([xs, (L + 1.2) * 0.5, 0.0, plane + 0.1])
		else:
			pieces.append([-(L + 1.2) * 0.5, (L + 1.2) * 0.5, 0.0, plane + 0.1])
		for pc: Array in pieces:
			var zc: float = s * ((plane + 0.1) * 0.5 - (pc[2] + pc[3]) * 0.5)
			g.box_xf(xf * Transform3D(Basis(), Vector3((pc[0] + pc[1]) * 0.5, 0, zc)), Vector3(pc[1] - pc[0], 0.2, pc[3] - pc[2]), "fm_roof")
			g.light_fn = inside
			g.box_xf(xf * Transform3D(Basis(), Vector3((minf(pc[1], L * 0.5) + maxf(pc[0], -L * 0.5)) * 0.5, -0.12, zc)), Vector3(minf(pc[1], L * 0.5) - maxf(pc[0], -L * 0.5), 0.03, pc[3] - pc[2]), "fm_bin", false)
			g.light_fn = saved
		if s == ss:
			for sk: Array in sky:
				var zc: float = s * ((plane + 0.1) * 0.5 - (u0 + u1) * 0.5)
				g.box_xf(xf * Transform3D(Basis(), Vector3((sk[0] + sk[1]) * 0.5, -0.02, zc)), Vector3(sk[1] - sk[0], 0.06, u1 - u0), "fm_bsky", false)
	g.box(c + Vector3(0, R + 0.15, 0), Vector3(L + 1.2, 0.3, 0.5), "fm_roof")
	# The light shafts: dusty sunlight from each skylight to its patch -
	# four see-through sides, no ends (Geo.tris: no footprint either).
	for pt: Array in patches:
		var tq: Array = pt[0]
		var fq: Array = pt[1]
		var tri := PackedVector3Array()
		for k in range(4):
			var k1: int = (k + 1) % 4
			tri.append_array([tq[k], tq[k1], fq[k1], tq[k], fq[k1], fq[k]])
		g.tris(tri, "fm_shaft")
	g.light_fn = inside
	# Inside: a hay loft over the east third on two beams and posts...
	var loft_x0: float = L * 0.5 - 8.0
	g.box(c + Vector3((loft_x0 + L * 0.5 - T) * 0.5, 3.4, 0), Vector3(L * 0.5 - T - loft_x0, 0.2, B - 2.0 * T), "fm_bwood")
	for k in [-1.0, 1.0]:
		g.box(c + Vector3(loft_x0 + 0.2, 1.95, k * (B * 0.5 - 2.0)), Vector3(0.3, 2.9, 0.3), "fm_bwood")
	g.box(c + Vector3(loft_x0 + 0.2, 3.2, 0), Vector3(0.3, 0.3, B - 2.0 * T), "fm_bwood")
	# ...a ladder up to it...
	for k in [-0.25, 0.25]:
		g.beam(c + Vector3(loft_x0 - 1.2, 0.55, 2.0 + k), c + Vector3(loft_x0 - 0.1, 3.5, 2.0 + k), Vector2(0.06, 0.08), "fm_bwood", false)
	# ...and square bales stacked up there and along the north wall.
	for row in range(3):
		for k in range(7):
			g.tint = Color.WHITE * rng.randf_range(0.82, 1.0)
			g.box(c + Vector3(loft_x0 + 0.9 + row * 1.0 + rng.randf_range(-0.05, 0.05), 3.5 + 0.2 + rng.randi_range(0, 1) * 0.0, -B * 0.5 + 1.0 + k * 1.75), Vector3(0.9, 0.4, 1.1), "fm_bstraw")
	for layer in range(3):
		for k in range(8 - layer * 2):
			g.tint = Color.WHITE * rng.randf_range(0.82, 1.0)
			g.box(c + Vector3(-L * 0.5 + 2.0 + k * 1.15 + layer * 1.15, 0.54 + 0.2 + layer * 0.4, -B * 0.5 + 1.0), Vector3(1.1, 0.4, 0.9), "fm_bstraw")
	g.tint = Color.WHITE
	g.light_fn = saved

## Baked light for the barn's faces (world normal n, point p; barn
## centre c at its foot): faces turned outward get the ordinary daylight
## (Geo.shade); inner ones a dim barn: ~45 % ambient, daylight spilling in
## through the two door openings (fading over ~6 m), sunlit patches under
## the skylights, darker under the loft.
static func _barn_light(g: Geo, n: Vector3, p: Vector3, c: Vector3, patches: Array) -> Color:
	var q: Vector3 = p - c
	var v: float = 0.34 + 0.1 * maxf(n.y, 0.0)
	# Through the doors: from both gable openings.
	for sx in [-1.0, 1.0]:
		var door := Vector3(sx * BARN_L * 0.5, 0.5 + DOOR_H * 0.5, 0)
		var d: float = (q - door).length()
		var facing: float = 0.6 + 0.4 * maxf(n.dot((door - q).normalized()), 0.0)
		v += 0.5 * exp(-d / 5.0) * facing
	# Under the loft, the light hardly gets in.
	if q.x > BARN_L * 0.5 - 8.0 and q.y < 3.3:
		v *= 0.8
	var col := Color(v, v * 0.96, v * 0.88)
	# Sun patches from the skylights, on whatever is at floor level there
	# (soft-edged: five points round p tested against the patch).
	for pt: Array in patches:
		var fq: Array = pt[1]
		if absf(p.y - (fq[0] as Vector3).y) > 0.6:
			continue
		var poly := PackedVector2Array()
		var box := Rect2(Vector2(fq[0].x, fq[0].z), Vector2.ZERO)
		for w: Vector3 in fq:
			poly.append(Vector2(w.x, w.z))
			box = box.expand(Vector2(w.x, w.z))
		if not box.grow(0.3).has_point(Vector2(p.x, p.z)):
			continue
		var k: float = 0.0
		for o: Vector2 in [Vector2.ZERO, Vector2(0.25, 0), Vector2(-0.25, 0), Vector2(0, 0.25), Vector2(0, -0.25)]:
			if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z) + o, poly):
				k += 0.2
		if k > 0.0:
			col += Color(0.75, 0.66, 0.45) * k
	return Color(minf(col.r, 1.0), minf(col.g, 1.0), minf(col.b, 1.0))

static func _silo(g: Geo, p: Vector3, ex: float) -> void:
	var r: float = 2.8
	var h: float = 16.0
	g.cylinder(p + Vector3(0, -0.3, 0), p + Vector3(0, 0.6, 0), r + 0.4, "fm_stone", 20)
	g.cylinder(p + Vector3(0, 0.6, 0), p + Vector3(0, h, 0), r, "fm_metal", 20)
	g.cone(p + Vector3(0, h, 0), p + Vector3(0, h + 2.2, 0), r + 0.15, 0.3, "fm_metal", 20)
	# Ladder up its side and a walkway ring at the top.
	g.tint = Color(0.5, 0.5, 0.52)
	for k in [-0.22, 0.22]:
		g.beam(p + Vector3(r + 0.25, 0.6, k), p + Vector3(r + 0.25, h + 0.8, k), Vector2(0.05, 0.05), "fm_paint", false)
	g.box(p + Vector3(r + 0.12, h * 0.5, 0), Vector3(0.24, 0.1, 0.4), "fm_paint", 0.0, false) # ladder bracket
	g.tint = Color.WHITE
	# A pipe from its top down to a hopper toward the yard.
	g.beam(p + Vector3(0, h + 1.8, 0), p + Vector3(-ex * 6.0, 7.0, 0), Vector2(0.35, 0.35), "fm_metal")
	g.cylinder(p + Vector3(-ex * 6.0, 0.0, 0), p + Vector3(-ex * 6.0, 7.2, 0), 0.25, "fm_metal", 10)

## An open-fronted machine shed: posts, a lean-to roof, a back wall.
static func _machine_shed(g: Geo, c: Vector3, rng: RandomNumberGenerator) -> void:
	var w: float = 16.0
	var d: float = 8.0
	for k in range(5):
		var x: float = -w * 0.5 + k * w / 4.0
		g.box(c + Vector3(x, 2.2, -d * 0.5 + 0.2), Vector3(0.25, 4.4, 0.25), "fm_wood")
	g.box(c + Vector3(0, 1.8, d * 0.5 - 0.15), Vector3(w, 3.6, 0.3), "fm_boards")
	for s in [-1.0, 1.0]:
		g.box(c + Vector3(s * (w * 0.5 - 0.15), 1.8, 0), Vector3(0.3, 3.6, d), "fm_boards")
	var a: float = atan2(0.8, d)
	g.box_xf(Transform3D(Basis(Vector3.RIGHT, a), c + Vector3(0, 4.25, 0)), Vector3(w + 0.8, 0.15, d + 1.2), "fm_metal")
	# Inside: a plough and a pile of crates.
	g.tint = Color(0.6, 0.15, 0.12)
	g.box(c + Vector3(-3.0, 0.5, 1.0), Vector3(3.0, 0.3, 1.2), "fm_paint")
	for k in range(4):
		g.cone(c + Vector3(-4.2 + k * 0.8, 0.65, 1.0), c + Vector3(-4.0 + k * 0.8, 0.0, 1.7), 0.12, 0.03, "fm_paint", 6)
	g.tint = Color.WHITE
	for k in range(3):
		g.box(c + Vector3(4.0 + k * 0.9, 0.3 + (k % 2) * 0.0, 2.6), Vector3(0.8, 0.6, 0.8), "fm_wood")

## A tractor at p heading along yaw (Vehicles convention: forward is
## local -z), optionally pulling a flat trailer of round bales.
static func tractor(g: Geo, p: Vector3, yaw: float, paint: String, trailer: bool = false, rng: RandomNumberGenerator = null) -> void:
	ensure_materials(g)
	if not g.has_material(paint):
		var col: Color = {"fm_green": Color(0.2, 0.42, 0.18), "fm_red": Color(0.72, 0.12, 0.08), "fm_blue": Color(0.12, 0.28, 0.6)}.get(paint, Color(0.3, 0.5, 0.2))
		g.add_material(paint, Geo.flat_mat(col, 0.35, 0.2))
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	# On a slope it leans with the ground under its wheels (a plane
	# through them) and sits on its lowest tyre - judged at each tyre's
	# front and back edge too, so none hangs over a dip.
	var wheels: Array = [Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(-0.9, 0, -1.35), Vector3(0.9, 0, -1.35)]
	if trailer:
		wheels.append_array([Vector3(-1, 0, 4.64), Vector3(1, 0, 4.64), Vector3(-1, 0, 6.56), Vector3(1, 0, 6.56)]) # (the trailer's, see below)
	var gy := func(q: Vector3) -> float:
		var w: Vector3 = xf * q
		var h: float = g.floor_fn.call(w.x, w.z) if g.floor_fn.is_valid() else -1e6
		return h if h > -1e5 else p.y
	var lf: Vector3 = Vector3.ZERO # mean wheel contact, left / right / front / back
	var rt: Vector3 = Vector3.ZERO
	var fr: Vector3 = Vector3.ZERO
	var bk: Vector3 = Vector3.ZERO
	var zmax: float = wheels[wheels.size() - 1].z
	for q: Vector3 in wheels:
		var w: Vector3 = xf * q
		w.y = gy.call(q)
		if q.x < 0.0:
			lf += w / (wheels.size() * 0.5)
		else:
			rt += w / (wheels.size() * 0.5)
		if q.z < 0.0:
			fr += w * 0.5
		elif q.z == zmax:
			bk += w * 0.5
	var n: Vector3 = (rt - lf).cross(bk - fr).normalized()
	if n.y < 0.0:
		n = -n
	var tilt := Basis(Quaternion(Vector3.UP, n)) if n.y > 0.5 and n.y < 0.9999 else Basis()
	xf = Transform3D(tilt * Basis(Vector3.UP, yaw), Vector3(p.x, p.y, p.z))
	# (Each tyre's foot down to the lowest ground round it: a round thing
	# on a slope otherwise shows light under its downhill side.)
	var dy: float = INF
	for q: Vector3 in wheels:
		var low: float = (xf * q).y
		var hs: Array = []
		for dz in [-0.85, 0.0, 0.85]:
			for dx in [-1.1, 0.0, 1.1]:
				var w: Vector3 = xf * (q + Vector3(dx, 0, dz))
				var h: float = g.floor_fn.call(w.x, w.z) if g.floor_fn.is_valid() else -1e6
				hs.append(h if h > -1e5 else p.y)
		for h: float in hs:
			dy = minf(dy, h - low)
	p.y += dy - 0.02
	xf = Transform3D(tilt * Basis(Vector3.UP, yaw), p)
	# Wheels: big ones at the back (z +), small at the front.
	for sx in [-1.0, 1.0]:
		Vehicles._wheel(g, xf, Vector3(sx * 0.95, 0.85, 1.0), 0.85, 0.55)
		Vehicles._wheel(g, xf, Vector3(sx * 0.85, 0.52, -1.35), 0.52, 0.38)
	# Frame, engine hood, mudguards, the cab.
	Vehicles._bx(g, xf, Vector3(0, 0.95, -0.4), Vector3(0.9, 0.5, 3.4), "veh_black", true)
	Vehicles._bx(g, xf, Vector3(0, 1.45, -1.0), Vector3(0.95, 0.85, 2.0), paint, true)
	Vehicles._bx(g, xf, Vector3(0, 1.05, -2.05), Vector3(0.8, 0.6, 0.12), "veh_black")
	for sx in [-1.0, 1.0]:
		Vehicles._bx(g, xf, Vector3(sx * 0.95, 1.78, 1.0), Vector3(0.6, 0.08, 1.6), paint)
	var cab := Vector3(0, 2.25, 0.75)
	Vehicles._bx(g, xf, cab + Vector3(0, -0.45, 0), Vector3(1.4, 0.4, 1.5), paint, true)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			Vehicles._bx(g, xf, cab + Vector3(sx * 0.66, 0.4, sz * 0.7), Vector3(0.07, 1.3, 0.07), "veh_black", true)
	Vehicles._bx(g, xf, cab + Vector3(0, 0.35, 0), Vector3(1.3, 1.1, 1.38), "veh_glass")
	Vehicles._bx(g, xf, cab + Vector3(0, 1.1, 0), Vector3(1.55, 0.12, 1.65), paint, true)
	# Exhaust stack and a beacon on the roof.
	g.cylinder(xf * Vector3(0.35, 1.8, -1.6), xf * Vector3(0.35, 3.0, -1.6), 0.06, "veh_steel", 8, false)
	Vehicles._bx(g, xf, cab + Vector3(0.5, 1.22, 0.5), Vector3(0.14, 0.12, 0.14), "veh_amber")
	if not trailer:
		return
	# The trailer: drawbar, a flat bed on two axles, three round bales.
	var tb := Vector3(0, 0, 5.6)
	Vehicles._bx(g, xf, Vector3(0, 0.75, 2.4), Vector3(0.12, 0.12, 1.8), "veh_black", true)
	Vehicles._bx(g, xf, tb + Vector3(0, 1.0, 0), Vector3(2.3, 0.15, 6.0), "fm_wood", true)
	for sz in [-1.6, 1.6]:
		for sx in [-1.0, 1.0]:
			Vehicles._wheel(g, xf, tb + Vector3(sx * 1.0, 0.45, sz * 0.6), 0.45, 0.3)
		Vehicles._bx(g, xf, tb + Vector3(0, 0.7, sz * 0.6), Vector3(2.0, 0.5, 0.25), "veh_black", true)
	for k in range(3):
		var bc: Vector3 = xf * (tb + Vector3(0, 1.08 + 0.75, -2.0 + k * 2.0))
		var ax: Vector3 = xf.basis.x * 0.6
		g.tint = Color.WHITE * (rng.randf_range(0.9, 1.05) if rng != null else 1.0)
		g.cylinder(bc - ax, bc + ax, 0.75, "fd_straw", 16)
	g.tint = Color.WHITE
