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
	FieldCreator.ensure_materials(g)
	Vehicles.ensure_materials(g)
	g.detail_prefixes.append("fmd_")
	g.add_material("fmd_paint", Geo.flat_mat(Color.WHITE, 0.5))

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
	# A walnut tree by the house, a couple of fruit trees.
	var trees: Array = [[o + Vector3(ex * (-hx + 4.0), -0.05, hz + 6.0), "maple", rng.randi(), "none"],
		[o + Vector3(ex * (-hx - 4.0), -0.05, hz - 2.0), "apple", rng.randi(), "none"]]
	return {"views": views, "trees": trees, "barn": barn}

## The barn: plank walls on a stone plinth, a big door opening in each
## gable, the leaves slid aside; inside, hay stacked to the loft.
static func _barn(g: Geo, c: Vector3, rng: RandomNumberGenerator) -> void:
	var L: float = BARN_L
	var B: float = BARN_B
	var E: float = BARN_EAVES
	var R: float = BARN_RIDGE
	var T: float = 0.3
	# Plinth and floor.
	g.box_on(Transform3D(Basis(), c + Vector3(0, 0.25, 0)), Vector3(L + 0.4, 0.5, B + 0.4), "fm_stone", c.y)
	g.box(c + Vector3(0, 0.52, 0), Vector3(L - 0.2, 0.04, B - 0.2), "fm_stone")
	# Long walls.
	for s in [-1.0, 1.0]:
		g.box(c + Vector3(0, 0.5 + (E - 0.5) * 0.5, s * (B * 0.5 - T * 0.5)), Vector3(L, E - 0.5, T), "fm_boards")
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
		# The two leaves, slid open along the wall outside it, with braces.
		for k in [-1.0, 1.0]:
			var lc: Vector3 = c + Vector3(s * (L * 0.5 + 0.12), 0.5 + DOOR_H * 0.5, k * (DOOR_W * 0.5 + 1.5))
			g.box(lc, Vector3(0.12, DOOR_H, 3.1), "fm_wood")
			g.tint = Color(0.75, 0.75, 0.75)
			g.beam(lc + Vector3(s * 0.08, -DOOR_H * 0.45, -1.4 * k), lc + Vector3(s * 0.08, DOOR_H * 0.45, 1.4 * k), Vector2(0.06, 0.18), "fm_wood", false)
			g.tint = Color.WHITE
		# The door track above the opening.
		g.box(c + Vector3(s * (L * 0.5 + 0.2), 0.5 + DOOR_H + 0.15, 0), Vector3(0.12, 0.15, DOOR_W + 6.4), "fm_dark")
	# Roof: two pitched planes with an overhang.
	var run: float = B * 0.5 + 0.7
	var a: float = atan2(R - E, B * 0.5)
	var plane: float = run / cos(a)
	for s in [-1.0, 1.0]:
		var mid := Vector3(0, R - (run * 0.5) * tan(a) + 0.12, s * run * 0.5)
		g.box_xf(Transform3D(Basis(Vector3.RIGHT, s * a), c + mid), Vector3(L + 1.2, 0.2, plane + 0.1), "fm_roof")
	g.box(c + Vector3(0, R + 0.15, 0), Vector3(L + 1.2, 0.3, 0.5), "fm_roof")
	# Inside: a hay loft over the east third on two beams and posts...
	var loft_x0: float = L * 0.5 - 8.0
	g.box(c + Vector3((loft_x0 + L * 0.5 - T) * 0.5, 3.4, 0), Vector3(L * 0.5 - T - loft_x0, 0.2, B - 2.0 * T), "fm_wood")
	for k in [-1.0, 1.0]:
		g.box(c + Vector3(loft_x0 + 0.2, 1.95, k * (B * 0.5 - 2.0)), Vector3(0.3, 2.9, 0.3), "fm_wood")
	g.box(c + Vector3(loft_x0 + 0.2, 3.2, 0), Vector3(0.3, 0.3, B - 2.0 * T), "fm_wood")
	# ...a ladder up to it...
	for k in [-0.25, 0.25]:
		g.beam(c + Vector3(loft_x0 - 1.2, 0.55, 2.0 + k), c + Vector3(loft_x0 - 0.1, 3.5, 2.0 + k), Vector2(0.06, 0.08), "fm_wood", false)
	# ...and square bales stacked up there and along the north wall.
	for row in range(3):
		for k in range(7):
			g.tint = Color.WHITE * rng.randf_range(0.82, 1.0)
			g.box(c + Vector3(loft_x0 + 0.9 + row * 1.0 + rng.randf_range(-0.05, 0.05), 3.5 + 0.2 + rng.randi_range(0, 1) * 0.0, -B * 0.5 + 1.0 + k * 1.75), Vector3(0.9, 0.4, 1.1), "fd_straw")
	for layer in range(3):
		for k in range(8 - layer * 2):
			g.tint = Color.WHITE * rng.randf_range(0.82, 1.0)
			g.box(c + Vector3(-L * 0.5 + 2.0 + k * 1.15 + layer * 1.15, 0.54 + 0.2 + layer * 0.4, -B * 0.5 + 1.0), Vector3(1.1, 0.4, 0.9), "fd_straw")
	g.tint = Color.WHITE

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
	# On a slope it sits on its lowest wheel (the others a little in the soil).
	var under: Array = []
	var wheels: Array = [Vector3(-1, 0, 1), Vector3(1, 0, 1), Vector3(-0.9, 0, -1.35), Vector3(0.9, 0, -1.35)]
	if trailer:
		wheels.append_array([Vector3(-1, 0, 4.0), Vector3(1, 0, 4.0), Vector3(-1, 0, 7.2), Vector3(1, 0, 7.2)])
	for q: Vector3 in wheels:
		under.append(xf * q)
	p.y = g.sunk(under, p.y + Geo.SINK) + Geo.SINK - 0.02
	xf = Transform3D(Basis(Vector3.UP, yaw), p)
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
