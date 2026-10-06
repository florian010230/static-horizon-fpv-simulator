class_name IndustryCreator
extends RefCounted

## Creator: the pieces of an industrial estate, each placed by the map
## (designed layout, generated detail):
##   IndustryCreator.plan(land, centre, size) -> site       levels the site, before land.build
##   IndustryCreator.yard(geo, site)                        concrete apron
##   IndustryCreator.hall(geo, xf, length, width, height, rng, opts) -> views
##       steel-framed production hall: corrugated cladding, a sawtooth
##       north-light roof (or a shallow gable), roller doors in the gable
##       ends - one open, fly in: columns, a crane runway and an overhead
##       crane inside - loading docks with dock shelters on one long side,
##       an office annex at one end
##   IndustryCreator.tanks(geo, c, nx, nz, rng)             tank farm in a bund wall
##   IndustryCreator.pipe_rack(geo, land, path, height)     portal frames carrying pipes - fly under
##   IndustryCreator.chimney(geo, p, height)                with red-and-white bands at the top
##   IndustryCreator.silos(geo, p, n, rng, hopper) -> views grain silos, a headhouse, a covered
##       conveyor gallery up from a hopper - open at both ends: fly up it
##   IndustryCreator.fence(geo, site, gate_side)            mesh fence, gatehouse and barrier
## xf for a hall: origin at the middle of its floor, x across (width), z
## along (length). Real numbers: halls 10-12 m to the eaves, sawtooth
## bays ~8 m; tanks 8-12 m across; silos ~7 m across, 20-30 m tall;
## industrial chimneys 30-60 m.

static func ensure_materials(g: Geo) -> void:
	if g.has_material("in_clad"):
		return
	g.add_material("in_clad", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(1.35, 1.38, 1.4), 2.0))
	g.add_material("in_concrete", Geo.tex_mat(MapTextures.get_tex("concrete_slab"), Color(1.15, 1.15, 1.13), 6.0))
	g.add_material("in_apron", Geo.ground_mat(MapTextures.get_tex("concrete_slab"), Color(1.0, 1.0, 0.98), 10.0, 1, 0.2))
	g.add_material("in_steel", Geo.flat_mat(Color.WHITE, 0.5, 0.5))
	g.add_material("in_glass", Geo.flat_mat(Color(0.55, 0.65, 0.7), 0.1, 0.3))
	g.add_material("in_light", Geo.flat_mat(Color(0.88, 0.9, 0.86), 0.4)) # polycarbonate light bands
	g.add_material("in_paint", Geo.flat_mat(Color.WHITE, 0.5))
	g.add_material("in_brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.1, 1.0, 0.95), 3.0))
	g.add_material("ind_paint", Geo.flat_mat(Color.WHITE, 0.5))
	g.add_material("ind_mark", Geo.ground_flat(Color.WHITE, 3)) # painted lines on a floor or yard (a layer: they never flicker)
	# The hall floor: lit by the roof glazing, not left in the roof's
	# shadow (the shadow map can't see light through glass).
	g.add_material("in_floor", Geo.tex_mat(MapTextures.get_tex("concrete_slab"), Color(1.05, 1.05, 1.03), 6.0))
	g.material("in_floor").set_meta("no_shadow", true)
	g.add_material("in_lamp", Geo.flat_mat(Color(1.6, 1.6, 1.5), 0.5)) # lit: never shaded darker
	g.material("in_lamp").set_meta("no_shadow", true)
	g.detail_prefixes.append("ind_")
	Vehicles.ensure_materials(g)

static func plan(land: TerrainCreator, centre: Vector2, size: Vector2) -> Dictionary:
	var sum: float = 0.0
	for fx in [-0.5, 0.0, 0.5]:
		for fz in [-0.5, 0.0, 0.5]:
			sum += land.staged(centre.x + fx * size.x, centre.y + fz * size.y, TerrainCreator.RIVERS)
	var y: float = snappedf(sum / 9.0, 0.1)
	var m: float = land.road_bed()
	land.flat_plot(centre, Vector2(1, 0), size.x * 0.5 + m, size.y * 0.5 + m, y, 30.0, [centre, size.x * 0.5, size.y * 0.5])
	land.keep_clear(centre, size.length() * 0.5 + 10.0, true)
	return {"c": centre, "size": size, "y": y}

static func yard(g: Geo, site: Dictionary) -> void:
	ensure_materials(g)
	var o := Vector3(site.c.x, site.y + 0.03, site.c.y)
	var h: Vector2 = site.size * 0.5
	g.polygon([o + Vector3(-h.x, 0, -h.y), o + Vector3(h.x, 0, -h.y), o + Vector3(h.x, 0, h.y), o + Vector3(-h.x, 0, h.y)], "in_apron", false)
	# Painted lanes: a yellow line round the inside of the site.
	g.tint = Color(0.95, 0.8, 0.15)
	for s in [-1.0, 1.0]:
		g.box(o + Vector3(0, 0.01, s * (h.y - 3.0)), Vector3(h.x * 2.0 - 6.0, 0.02, 0.15), "ind_mark", 0.0, false, false)
		g.box(o + Vector3(s * (h.x - 3.0), 0.01, 0), Vector3(0.15, 0.02, h.y * 2.0 - 6.0), "ind_mark", 0.0, false, false)
	g.tint = Color.WHITE

# --- the hall ------------------------------------------------------------------------------

## A box in the hall's frame, standing on its floor level (Geo.box_on).
static func _hb(g: Geo, xf: Transform3D, level: float, c: Vector3, s: Vector3, mat: String, collide: bool = true) -> void:
	g.box_on(xf * Transform3D(Basis(), c), s, mat, level, collide)

static func hall(g: Geo, xf: Transform3D, L: float, B: float, H: float, rng: RandomNumberGenerator, opts: Dictionary = {}) -> Array:
	ensure_materials(g)
	var views: Array = []
	var level: float = xf.origin.y
	var clad_col: Color = [Color(0.9, 0.92, 0.94), Color(0.75, 0.8, 0.85), Color(0.62, 0.7, 0.62), Color(0.85, 0.82, 0.75)][rng.randi() % 4]
	var trim_col: Color = [Color(0.2, 0.35, 0.6), Color(0.65, 0.15, 0.12), Color(0.25, 0.25, 0.27)][rng.randi() % 3]
	var T: float = 0.25
	# Floor slab and a concrete plinth wall 1 m high all round.
	g.tint = Color(0.8, 0.8, 0.78)
	_hb(g, xf, level, Vector3(0, 0.08, 0), Vector3(B, 0.16, L), "in_floor")
	# Long walls (x = +-B/2): cladding over a plinth, a light band under
	# the eaves; docks on the +x side.
	var n_docks: int = opts.get("docks", 3)
	var dock_z: Array = []
	for k in range(n_docks):
		dock_z.append(-L * 0.5 + L * (k + 1) / (n_docks + 1))
	for s in [-1.0, 1.0]:
		g.tint = Color(0.7, 0.7, 0.68)
		_hb(g, xf, level, Vector3(s * (B * 0.5 - T * 0.5), 0.5, 0), Vector3(T, 1.0, L), "in_concrete")
		g.tint = clad_col
		_hb(g, xf, level, Vector3(s * (B * 0.5 - T * 0.5), 1.0 + (H - 2.6) * 0.5, 0), Vector3(T, H - 2.6, L), "in_clad")
		g.tint = Color.WHITE
		_hb(g, xf, level, Vector3(s * (B * 0.5 - T * 0.5), H - 0.8, 0), Vector3(T + 0.02, 1.6, L), "in_light")
		g.tint = trim_col
		_hb(g, xf, level, Vector3(s * (B * 0.5 + 0.05), H + 0.1, 0), Vector3(0.3, 0.3, L + 0.6), "in_paint", false)
	# Docks: a raised platform outside, dock shelters, roller doors.
	for z: float in dock_z:
		g.tint = Color(0.65, 0.65, 0.63)
		_hb(g, xf, level, Vector3(B * 0.5 + 1.2, 0.6, z), Vector3(2.4, 1.2, 3.6), "in_concrete")
		g.tint = Color(0.12, 0.12, 0.13)
		_hb(g, xf, level, Vector3(B * 0.5 + 0.35, 2.7, z), Vector3(0.7, 3.4, 3.6), "ind_paint")
		g.tint = trim_col * 1.2
		_hb(g, xf, level, Vector3(B * 0.5 + 0.72, 2.7, z), Vector3(0.04, 2.8, 2.8), "in_paint", false)
	# Gable ends (z = +-L/2): two roller doors each; the first on the -z
	# end stands open.
	for s in [-1.0, 1.0]:
		var z: float = s * (L * 0.5 - T * 0.5)
		var dw: float = 5.5
		var dh: float = 5.5
		var xs: Array = [-B * 0.25, B * 0.25]
		# Wall pieces round the two openings.
		g.tint = clad_col
		var edges: Array = [-B * 0.5, xs[0] - dw * 0.5, xs[0] + dw * 0.5, xs[1] - dw * 0.5, xs[1] + dw * 0.5, B * 0.5]
		for k in range(0, 6, 2):
			var a: float = edges[k]
			var b: float = edges[k + 1]
			if b - a > 0.05:
				_hb(g, xf, level, Vector3((a + b) * 0.5, H * 0.5, z), Vector3(b - a, H, T), "in_clad")
		for xd: float in xs:
			_hb(g, xf, level, Vector3(xd, (dh + H) * 0.5, z), Vector3(dw, H - dh, T), "in_clad")
			# (opts "open_both": the +z end's first door open too - a straight fly-through.)
			var open: bool = xd == xs[0] and (s < 0.0 or opts.get("open_both", false))
			g.tint = trim_col
			for e in [-1.0, 1.0]:
				_hb(g, xf, level, Vector3(xd + e * (dw * 0.5 + 0.1), dh * 0.5, z + s * 0.12), Vector3(0.2, dh, 0.2), "in_paint", false)
			_hb(g, xf, level, Vector3(xd, dh + 0.3, z + s * 0.2), Vector3(dw + 0.4, 0.6, 0.6), "in_paint", false) # the door's coil box
			if not open:
				g.tint = Color(0.82, 0.83, 0.85)
				_hb(g, xf, level, Vector3(xd, dh * 0.5, z), Vector3(dw, dh, 0.12), "in_clad")
				g.tint = Color(0.6, 0.6, 0.62)
				for k in range(1, 6):
					_hb(g, xf, level, Vector3(xd, k * dh / 6.0, z + s * 0.07), Vector3(dw, 0.05, 0.03), "ind_paint", false)
		# The gable above the wall top (sawtooth: flat; gable roof: a triangle).
	# Roof.
	var saw: bool = opts.get("roof", "saw") == "saw"
	if saw:
		# North-light sawtooth across the length: each bay a sloping plane
		# and a vertical glazed face.
		var bays: int = maxi(2, int(L / 8.0))
		var bl: float = L / bays
		var rise: float = 2.6
		var a: float = atan2(rise, bl)
		var plane: float = bl / cos(a)
		for k in range(bays):
			var z0: float = -L * 0.5 + k * bl
			g.tint = Color(0.62, 0.64, 0.66)
			# (High at the bay's -z end, where the glazing stands.)
			g.box_xf(xf * Transform3D(Basis(Vector3.RIGHT, a), Vector3(0, H + rise * 0.5 + 0.1, z0 + bl * 0.5)), Vector3(B + 0.4, 0.15, plane + 0.05), "in_clad")
			g.tint = Color.WHITE
			_hb(g, xf, level, Vector3(0, H + rise * 0.5, z0 + 0.06), Vector3(B + 0.2, rise, 0.1), "in_glass")
			# The gable ends of each tooth.
			g.tint = clad_col
			for e in [-1.0, 1.0]:
				g.prism(xf * Transform3D(Basis(), Vector3(e * (B * 0.5 - T * 0.5), 0, 0)), [Vector2(z0, H), Vector2(z0 + bl, H), Vector2(z0, H + rise)], T, "in_clad")
	else:
		var rise: float = 2.4
		var a: float = atan2(rise, B * 0.5)
		var run: float = B * 0.5 + 0.5
		for s in [-1.0, 1.0]:
			g.tint = Color(0.62, 0.64, 0.66)
			g.box_xf(xf * Transform3D(Basis(Vector3.FORWARD, s * a), Vector3(s * run * 0.5, H + rise - run * 0.5 * tan(a) + 0.1, 0)), Vector3(run / cos(a) + 0.05, 0.15, L + 0.6), "in_clad")
		g.tint = clad_col
		for s in [-1.0, 1.0]:
			g.prism(xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, s * (L * 0.5 - T * 0.5))), [Vector2(-B * 0.5, H), Vector2(B * 0.5, H), Vector2(0, H + rise)], T, "in_clad")
	# Inside: a row of steel columns down each side, the crane runway on
	# them, an overhead crane with its hook, a few crates and a forklift.
	g.tint = Color(0.95, 0.75, 0.15)
	var cols: int = maxi(2, int(L / 8.0))
	for k in range(cols + 1):
		var z: float = -L * 0.5 + 0.6 + (L - 1.2) * k / cols
		for s in [-1.0, 1.0]:
			_hb(g, xf, level, Vector3(s * (B * 0.5 - 0.6), H * 0.5, z), Vector3(0.4, H, 0.4), "in_steel")
	for s in [-1.0, 1.0]:
		_hb(g, xf, level, Vector3(s * (B * 0.5 - 0.6), H - 2.2, 0), Vector3(0.5, 0.6, L - 1.2), "in_steel")
	var cz: float = rng.randf_range(-L * 0.25, L * 0.25)
	_hb(g, xf, level, Vector3(0, H - 1.7, cz), Vector3(B - 1.0, 0.8, 0.9), "in_steel")
	g.tint = Color(0.25, 0.25, 0.27)
	_hb(g, xf, level, Vector3(-B * 0.15, H - 2.3, cz), Vector3(1.2, 0.5, 1.2), "in_steel")
	g.cylinder(xf * Vector3(-B * 0.15, H - 2.5, cz), xf * Vector3(-B * 0.15, 3.0, cz), 0.03, "in_steel", 6, false)
	g.tint = Color(0.95, 0.75, 0.15)
	_hb(g, xf, level, Vector3(-B * 0.15, 2.85, cz), Vector3(0.4, 0.3, 0.25), "in_steel")
	g.tint = Color(0.75, 0.6, 0.42)
	for k in range(6):
		_hb(g, xf, level, Vector3(-B * 0.5 + 2.6 + (k % 3) * 1.4, 0.16 + 0.5 + (k / 3) * 1.0, L * 0.3), Vector3(1.2, 1.0, 1.2), "in_paint")
	_inside(g, xf, level, L, B, H)
	# Office annex at the +z end: two storeys, window bands, a canopy.
	if opts.get("office", true):
		var ow: float = minf(B, 24.0)
		var od: float = 9.0
		var oc := Vector3(0, 0, L * 0.5 + od * 0.5)
		g.tint = Color(0.92, 0.92, 0.9)
		_hb(g, xf, level, oc + Vector3(0, 3.5, 0), Vector3(ow, 7.0, od), "in_concrete")
		for fl in range(2):
			g.tint = Color.WHITE
			_hb(g, xf, level, oc + Vector3(0, 1.0 + fl * 3.4 + 0.75, od * 0.5 + 0.03), Vector3(ow - 1.0, 1.5, 0.06), "in_glass", false)
			for e in [-1.0, 1.0]:
				_hb(g, xf, level, oc + Vector3(e * (ow * 0.5 + 0.03), 1.0 + fl * 3.4 + 0.75, 0), Vector3(0.06, 1.5, od - 1.0), "in_glass", false)
		g.tint = trim_col
		_hb(g, xf, level, oc + Vector3(0, 7.15, 0), Vector3(ow + 0.3, 0.3, od + 0.3), "in_paint")
		_hb(g, xf, level, oc + Vector3(ow * 0.3, 2.9, od * 0.5 + 1.0), Vector3(3.0, 0.15, 2.0), "in_paint")
		g.tint = Color(0.3, 0.32, 0.35)
		_hb(g, xf, level, oc + Vector3(ow * 0.3, 1.2, od * 0.5 + 0.04), Vector3(1.8, 2.4, 0.08), "in_glass", false)
		var nm: String = ["Talbach Metallbau", "Hofmann Kunststoff", "Werk 2", "Brenner & Sohn"][rng.randi() % 4]
		StreetKit._label(g, nm, xf * Transform3D(Basis(), oc + Vector3(-ow * 0.15, 6.2, od * 0.5 + 0.05)), 0.012, Color(0.15, 0.15, 0.16))
	g.tint = Color.WHITE
	views.append(["hall", xf * Vector3(B * 0.5 + 25.0, 14.0, -L * 0.5 - 20.0), xf * Vector3(0, H * 0.5, 0)])
	views.append(["hall_door", xf * Vector3(-B * 0.25, 3.0, -L * 0.5 - 14.0), xf * Vector3(-B * 0.25, 3.0, 0)])
	views.append(["hall_inside", xf * Vector3(-B * 0.25, 3.5, -L * 0.5 + 3.0), xf * Vector3(0, H - 2.0, L * 0.3)])
	return views

## The hall's working floor, kept off the aisle from the open door (x =
## -B/4, +-3 m, painted lines either side - the fly-through stays clear):
## pallet racks with goods down the -x wall, a forklift beside them, a row
## of machine tools east of the aisle, workbenches along the +x wall,
## high-bay lamps hanging from the roof over it all. Its own dice (seeded
## from the hall's place), so `rng`'s sequence is as it was.
## Real numbers: pallet racks 1.1 m deep, 2.7 m bays, beam levels ~1.5 m
## apart; a Euro pallet 1.2 x 0.8 m; a 2.5 t forklift ~2.3 m long, 1.15 m
## wide; machining centres ~3 x 2.5 m, 2.5-3 m tall.
static func _inside(g: Geo, xf: Transform3D, level: float, L: float, B: float, H: float) -> void:
	var r := RandomNumberGenerator.new()
	r.seed = hash([snappedf(xf.origin.x, 0.1), snappedf(xf.origin.z, 0.1), L, B])
	var fy: float = 0.16 # the floor slab's top
	var ax: float = -B * 0.25
	# Aisle lines.
	g.tint = Color(0.95, 0.8, 0.15)
	for e in [-1.0, 1.0]:
		g.box_xf(xf * Transform3D(Basis(), Vector3(ax + e * 3.0, fy + 0.005, 0)), Vector3(0.12, 0.01, L - 1.0), "ind_mark", false)
	# Pallet racks along the -x wall, up to the crates at z = L * 0.3.
	var rx: float = -B * 0.5 + 1.55
	var z0: float = -L * 0.5 + 3.0
	var z1: float = L * 0.3 - 1.5
	var bay: float = 2.7
	var n_bays: int = int((z1 - z0) / bay)
	var levels: int = clampi(int((H - 3.0) / 1.6), 2, 5)
	var goods: Array = [Color(0.72, 0.58, 0.4), Color(0.85, 0.85, 0.82), Color(0.3, 0.45, 0.7), Color(0.75, 0.3, 0.2), Color(0.45, 0.5, 0.45)]
	for k in range(n_bays + 1):
		var z: float = z0 + k * bay
		g.tint = Color(0.15, 0.3, 0.6) # uprights
		for e in [-0.5, 0.5]:
			_hb(g, xf, level, Vector3(rx + e * 1.0, fy + levels * 0.8, z), Vector3(0.08, levels * 1.6, 0.08), "ind_paint")
	for lv in range(levels):
		var y: float = fy + 0.15 + lv * 1.6
		g.tint = Color(0.95, 0.45, 0.1) # beams
		for e in [-0.5, 0.5]:
			g.box_xf(xf * Transform3D(Basis(), Vector3(rx + e * 1.0, y, (z0 + z0 + n_bays * bay) * 0.5)), Vector3(0.06, 0.12, n_bays * bay), "ind_paint", false)
		for k in range(n_bays):
			# Three pallet places a bay: a run of pallets (one box), goods
			# on 1-3 of them (one box per run of the same goods).
			var n_p: int = r.randi_range(0, 3)
			if n_p == 0:
				continue
			var pz0: float = z0 + k * bay + 0.15
			g.tint = Color(0.8, 0.68, 0.5)
			g.box_xf(xf * Transform3D(Basis(), Vector3(rx, y + 0.13, pz0 + n_p * 0.425)), Vector3(1.15, 0.14, n_p * 0.85 - 0.07), "ind_paint", false)
			var gh: float = r.randf_range(0.5, 1.2)
			g.tint = goods[r.randi() % goods.size()] * r.randf_range(0.9, 1.05)
			g.box_xf(xf * Transform3D(Basis(), Vector3(rx, y + 0.2 + gh * 0.5, pz0 + n_p * 0.425)), Vector3(1.05, gh, n_p * 0.85 - 0.13), "ind_paint", false)
	# A forklift parked by the racks, forks down, pointing along the hall.
	var fz: float = z0 + n_bays * bay * 0.4
	var fx: float = rx + 2.05
	var fk := Transform3D(Basis(), Vector3(fx, fy, fz))
	g.tint = Color(0.95, 0.65, 0.1)
	g.box_xf(xf * fk * Transform3D(Basis(), Vector3(0, 0.75, 0.2)), Vector3(1.1, 0.9, 1.9), "ind_paint")
	g.tint = Color(0.2, 0.2, 0.22)
	g.box_xf(xf * fk * Transform3D(Basis(), Vector3(0, 0.75, 1.05)), Vector3(1.05, 0.7, 0.4), "ind_paint", false) # counterweight
	for e in [-0.5, 0.5]:
		g.box_xf(xf * fk * Transform3D(Basis(), Vector3(e * 0.95, 1.5, 0.1)), Vector3(0.06, 1.3, 0.06), "ind_paint", false) # cage posts
		g.box_xf(xf * fk * Transform3D(Basis(), Vector3(e * 0.95, 1.5, 0.9)), Vector3(0.06, 1.3, 0.06), "ind_paint", false)
	g.box_xf(xf * fk * Transform3D(Basis(), Vector3(0, 2.18, 0.5)), Vector3(1.1, 0.06, 1.0), "ind_paint", false)
	g.box_xf(xf * fk * Transform3D(Basis(), Vector3(0, 1.4, -0.85)), Vector3(0.8, 2.4, 0.12), "ind_paint", false) # mast
	for e in [-0.25, 0.25]:
		g.box_xf(xf * fk * Transform3D(Basis(), Vector3(e, 0.06, -1.5)), Vector3(0.12, 0.05, 1.15), "ind_paint", false) # forks
	for e in [-0.45, 0.45]:
		for wz in [-0.5, 0.75]:
			g.cylinder(xf * (fk * Vector3(e * 1.2, 0.3, wz)), xf * (fk * Vector3(e * 1.25, 0.3, wz)), 0.3, "ind_paint", 10, false)
	# Machine tools east of the aisle, every 7 m.
	var mx: float = ax + 3.0 + 3.5
	var z: float = -L * 0.5 + 8.0
	while z < L * 0.5 - 6.0:
		if absf(z - L * 0.3) > 2.5 or mx > -B * 0.5 + 6.0:
			var mw: float = r.randf_range(2.2, 3.0)
			var mh: float = r.randf_range(2.0, 2.8)
			var md: float = r.randf_range(2.4, 3.6)
			var body: Color = [Color(0.92, 0.92, 0.9), Color(0.8, 0.82, 0.84), Color(0.55, 0.65, 0.5)][r.randi() % 3]
			g.tint = body
			_hb(g, xf, level, Vector3(mx, fy + mh * 0.5, z), Vector3(mw, mh, md), "in_paint")
			g.tint = Color(0.15, 0.3, 0.55)
			_hb(g, xf, level, Vector3(mx, fy + 0.2, z), Vector3(mw + 0.04, 0.4, md + 0.04), "in_paint", false) # plinth stripe
			g.tint = Color(0.25, 0.3, 0.35)
			g.box_xf(xf * Transform3D(Basis(), Vector3(mx - mw * 0.5 - 0.02, fy + mh * 0.6, z)), Vector3(0.04, mh * 0.4, md * 0.5), "ind_paint", false) # the door's window
			g.tint = Color(0.2, 0.2, 0.22)
			g.box_xf(xf * Transform3D(Basis(), Vector3(mx - mw * 0.5 - 0.25, fy + 1.5, z + md * 0.5 - 0.2)), Vector3(0.12, 0.6, 0.45), "ind_paint", false) # control panel
			g.box_xf(xf * Transform3D(Basis(), Vector3(mx - mw * 0.5 - 0.1, fy + 1.5, z + md * 0.5 - 0.2)), Vector3(0.2, 0.08, 0.08), "ind_paint", false)
			# A light tower on it (green/amber/red).
			for k in range(3):
				g.tint = [Color(0.2, 0.8, 0.25), Color(1.0, 0.7, 0.1), Color(0.9, 0.15, 0.1)][k]
				g.cylinder(xf * Vector3(mx + mw * 0.3, fy + mh + k * 0.1, z - md * 0.3), xf * Vector3(mx + mw * 0.3, fy + mh + (k + 1) * 0.1, z - md * 0.3), 0.05, "ind_paint", 8, false)
		z += 7.0
	# Workbenches along the +x wall, a vice and a tool board over each.
	var bx: float = B * 0.5 - 1.35
	z = -L * 0.5 + 5.0
	while z < L * 0.5 - 4.0:
		g.tint = Color(0.35, 0.45, 0.55)
		for e in [-0.85, 0.85]:
			_hb(g, xf, level, Vector3(bx, fy + 0.42, z + e), Vector3(0.7, 0.84, 0.06), "ind_paint")
		g.tint = Color(0.75, 0.6, 0.42)
		_hb(g, xf, level, Vector3(bx, fy + 0.87, z), Vector3(0.8, 0.06, 2.0), "ind_paint")
		g.tint = Color(0.3, 0.32, 0.35)
		g.box_xf(xf * Transform3D(Basis(), Vector3(bx - 0.1, fy + 0.98, z + 0.6)), Vector3(0.2, 0.16, 0.14), "ind_paint", false)
		g.tint = Color(0.85, 0.85, 0.82)
		g.box_xf(xf * Transform3D(Basis(), Vector3(B * 0.5 - 0.27, fy + 1.7, z)), Vector3(0.04, 1.0, 1.6), "ind_paint", false)
		if r.randf() < 0.6: # a red tool chest beside it
			g.tint = Color(0.75, 0.12, 0.1)
			_hb(g, xf, level, Vector3(bx + 0.05, fy + 0.5, z + 1.45), Vector3(0.55, 1.0, 0.6), "ind_paint")
		z += 4.5
	# High-bay lamps: rows over the aisle and the machines, above the
	# crane's girder, each on a rod from the roof.
	g.tint = Color(1.0, 0.97, 0.88)
	for lx: float in [ax, ax + 6.5, B * 0.5 - 3.0]:
		z = -L * 0.5 + 4.0
		while z < L * 0.5 - 2.0:
			var top := xf * Vector3(lx, H + 0.1, z)
			var lamp := xf * Vector3(lx, H - 0.9, z)
			g.tint = Color(0.3, 0.3, 0.32)
			g.cylinder(lamp, top, 0.02, "ind_paint", 4, false)
			g.tint = Color(0.55, 0.57, 0.6)
			g.cone(lamp + Vector3(0, 0.3, 0), lamp, 0.12, 0.32, "ind_paint", 10, false)
			g.tint = Color(1.0, 0.98, 0.9)
			g.cylinder(lamp - Vector3(0, 0.02, 0), lamp, 0.3, "in_lamp", 10, false)
			z += 8.0
	g.tint = Color.WHITE

## Where the docks are (for parking trucks at them): positions on the
## +x wall, facing +x.
static func docks(xf: Transform3D, L: float, B: float, n: int = 3) -> Array:
	var out: Array = []
	for k in range(n):
		out.append(xf * Vector3(B * 0.5 + 2.4, 0, -L * 0.5 + L * (k + 1) / (n + 1)))
	return out

# --- tanks, pipes, chimney, silos -------------------------------------------------------

static func tanks(g: Geo, c: Vector3, nx: int, nz: int, rng: RandomNumberGenerator) -> Array:
	ensure_materials(g)
	var r: float = rng.randf_range(3.8, 5.0)
	var gap: float = r * 2.0 + 3.0
	var tops: Array = []
	for ix in range(nx):
		for iz in range(nz):
			var p: Vector3 = c + Vector3((ix - (nx - 1) * 0.5) * gap, 0, (iz - (nz - 1) * 0.5) * gap)
			var h: float = rng.randf_range(9.0, 13.0)
			g.tint = Color(0.6, 0.6, 0.58)
			g.cylinder(Vector3(p.x, g.sunk([p], p.y) - 0.2, p.z), p + Vector3(0, 0.4, 0), r + 0.3, "in_concrete", 20)
			g.tint = [Color(0.93, 0.93, 0.92), Color(0.88, 0.9, 0.92), Color(0.75, 0.78, 0.8)][rng.randi() % 3]
			g.cylinder(p + Vector3(0, 0.4, 0), p + Vector3(0, h, 0), r, "in_steel", 20)
			g.cone(p + Vector3(0, h, 0), p + Vector3(0, h + r * 0.25, 0), r + 0.05, 0.4, "in_steel", 20)
			# Ladder up its side with a cage, a rail round the top.
			g.tint = Color(0.95, 0.75, 0.15)
			var side := Vector3(cos(0.6 + ix), 0, sin(0.6 + ix))
			for k in [-0.25, 0.25]:
				var off: Vector3 = side * (r + 0.3) + Vector3(-side.z, 0, side.x) * k
				g.beam(p + off + Vector3(0, 0.4, 0), p + off + Vector3(0, h + 1.0, 0), Vector2(0.05, 0.05), "ind_paint", false)
			var n: int = 16
			for k in range(n):
				var a0: float = TAU * k / n
				var a1: float = TAU * (k + 1) / n
				g.beam(p + Vector3(cos(a0) * r, h + 1.0, sin(a0) * r), p + Vector3(cos(a1) * r, h + 1.0, sin(a1) * r), Vector2(0.05, 0.05), "ind_paint", false)
			tops.append(p + Vector3(0, h, 0))
	# The bund: a low concrete wall round them all.
	var hx: float = nx * gap * 0.5 + 1.0
	var hz: float = nz * gap * 0.5 + 1.0
	g.tint = Color(0.72, 0.72, 0.7)
	for s in [-1.0, 1.0]:
		g.box_on(Transform3D(Basis(), c + Vector3(0, 0.6, s * hz)), Vector3(hx * 2.0 + 0.4, 1.2, 0.4), "in_concrete", c.y)
		g.box_on(Transform3D(Basis(), c + Vector3(s * hx, 0.6, 0)), Vector3(0.4, 1.2, hz * 2.0), "in_concrete", c.y)
	g.tint = Color.WHITE
	return tops

## A pipe rack along `path` (x, z corners): a portal frame every 6 m,
## pipes on its beam at `height`, bending round the corners (no kinks).
static func pipe_rack(g: Geo, land: TerrainCreator, path: Array, height: float, base_y: float) -> void:
	ensure_materials(g)
	var corners: Array[Vector3] = []
	for q: Vector2 in path:
		corners.append(Vector3(q.x, base_y + height, q.y))
	var route: Array[Vector3] = Route.rounded(corners, 4.0, 8) if corners.size() > 2 else corners
	var r: Route = Route.from_pts(route)
	var L: float = r.length()
	var d: float = 0.0
	g.tint = Color(0.55, 0.57, 0.6)
	while d <= L:
		var s: Array = r.sample(d)
		var p: Vector3 = s[0]
		var t: Vector3 = s[1]
		var side := Vector3(-t.z, 0, t.x) * 1.4
		for e in [-1.0, 1.0]:
			var foot: Vector3 = p + side * e
			var gy: float = land.ground(foot.x, foot.z) if land != null else base_y
			g.box(Vector3(foot.x, (gy - 0.3 + p.y) * 0.5, foot.z), Vector3(0.3, p.y - gy + 0.3, 0.3), "in_steel", atan2(t.x, t.z))
		g.beam(p - side * 1.15, p + side * 1.15, Vector2(0.3, 0.3), "in_steel")
		d += 6.0
	for k in range(3):
		var o: float = -0.8 + k * 0.8
		var rad: float = [0.22, 0.3, 0.18][k]
		var pp: Array[Vector3] = Route.offset_pts(route, o)
		for i in range(pp.size()):
			pp[i].y += 0.15 + rad
		g.tint = [Color(0.85, 0.86, 0.88), Color(0.95, 0.8, 0.2), Color(0.75, 0.2, 0.15)][k]
		g.pipe_path(pp, rad, "in_steel", 0.0, 10, true, false)
	g.tint = Color.WHITE

static func chimney(g: Geo, p: Vector3, height: float) -> void:
	ensure_materials(g)
	g.tint = Color(0.6, 0.6, 0.58)
	g.cylinder(Vector3(p.x, g.sunk([p], p.y) - 0.3, p.z), p + Vector3(0, 1.0, 0), 3.0, "in_concrete", 16)
	g.tint = Color.WHITE
	g.cone(p + Vector3(0, 1.0, 0), p + Vector3(0, height - 6.0, 0), 2.4, 1.5, "in_brick", 16)
	# Aviation marking: red and white bands at the top.
	for k in range(3):
		g.tint = Color(0.8, 0.12, 0.1) if k % 2 == 0 else Color(0.95, 0.95, 0.93)
		var y0: float = height - 6.0 + k * 2.0
		g.cone(p + Vector3(0, y0, 0), p + Vector3(0, y0 + 2.0, 0), 1.5 - k * 0.04, 1.46 - k * 0.04, "in_concrete", 16)
	g.tint = Color(0.3, 0.3, 0.32)
	var n: int = 16
	for k in range(n): # the platform's rail
		var a0: float = TAU * k / n
		var a1: float = TAU * (k + 1) / n
		g.beam(p + Vector3(cos(a0) * 2.4, height - 9.0, sin(a0) * 2.4), p + Vector3(cos(a1) * 2.4, height - 9.0, sin(a1) * 2.4), Vector2(0.08, 0.08), "ind_paint", false)
	g.cylinder(p + Vector3(0, height - 10.2, 0), p + Vector3(0, height - 10.0, 0), 2.4, "in_steel", 16)
	g.tint = Color.WHITE

## n silos in a row along x from p, a headhouse across their tops, and
## a covered conveyor gallery from a hopper at `hopper` up into it -
## a square tube open at both ends, big enough to fly up.
static func silos(g: Geo, p: Vector3, n: int, rng: RandomNumberGenerator, hopper: Vector3) -> Array:
	ensure_materials(g)
	var r: float = 3.4
	var h: float = rng.randf_range(22.0, 26.0)
	for k in range(n):
		var c: Vector3 = p + Vector3(k * (r * 2.0 + 0.2), 0, 0)
		g.tint = Color(0.86, 0.85, 0.82)
		g.cylinder(Vector3(c.x, g.sunk([c], c.y) - 0.2, c.z), c + Vector3(0, h, 0), r, "in_concrete", 20)
	var span: float = (n - 1) * (r * 2.0 + 0.2) + r * 2.0
	var hc: Vector3 = p + Vector3((n - 1) * (r * 2.0 + 0.2) * 0.5, h + 2.0, 0)
	g.tint = Color(0.8, 0.8, 0.78)
	g.box(hc, Vector3(span, 4.0, r * 1.6), "in_concrete")
	g.tint = Color.WHITE
	g.box(hc + Vector3(0, 0.3, r * 0.8 + 0.03), Vector3(span - 2.0, 1.0, 0.06), "in_glass", 0.0, false)
	# The gallery: from over the hopper up to the headhouse's end wall,
	# its low end open 5 m up (fly in there), a chute down to the hopper.
	var top: Vector3 = hc + Vector3(-span * 0.5, -1.0, 0)
	var flat: Vector3 = Vector3(top.x - hopper.x, 0, top.z - hopper.z).normalized()
	var foot: Vector3 = hopper + flat * 3.0 + Vector3(0, 6.0, 0)
	var dir: Vector3 = (top - foot)
	var L: float = dir.length()
	var mid: Vector3 = (top + foot) * 0.5
	var bas := Basis.looking_at(dir.normalized(), Vector3.UP) # local -z along the gallery
	var gw: float = 3.2
	var gh: float = 3.0
	g.tint = Color(0.75, 0.78, 0.8)
	for e: Array in [[Vector3(0, -gh * 0.5, 0), Vector3(gw, 0.15, L)], [Vector3(0, gh * 0.5, 0), Vector3(gw, 0.15, L)],
			[Vector3(-gw * 0.5, 0, 0), Vector3(0.12, gh, L)], [Vector3(gw * 0.5, 0, 0), Vector3(0.12, gh, L)]]:
		g.box_xf(Transform3D(bas, mid) * Transform3D(Basis(), e[0]), e[1], "in_clad")
	# Trestles under it, and the hopper.
	g.tint = Color(0.55, 0.57, 0.6)
	for t in [0.33, 0.66]:
		var q: Vector3 = foot.lerp(top, t)
		var gy: float = hopper.y
		g.box(Vector3(q.x, (gy + q.y - gh * 0.5) * 0.5, q.z), Vector3(0.5, q.y - gh * 0.5 - gy, 2.6), "in_steel", atan2(dir.x, dir.z))
	g.tint = Color(0.45, 0.45, 0.47)
	g.box(hopper + Vector3(0, 0.6, 0), Vector3(4.0, 1.2, 4.0), "in_steel")
	g.cone(hopper + Vector3(0, 1.2, 0), hopper + Vector3(0, 2.6, 0), 2.2, 1.0, "in_steel", 8)
	g.beam(hopper + Vector3(0, 2.5, 0), foot + flat * 1.0 - Vector3(0, gh * 0.5 - 0.1, 0), Vector2(0.8, 0.8), "in_steel")
	g.tint = Color.WHITE
	return [["silos", hc + Vector3(span * 0.5 + 30.0, -h * 0.4, 30.0), hc + Vector3(0, -h * 0.4, 0)],
		["conveyor", foot - dir.normalized() * 9.0, top]]

## A mesh fence round the site (concrete posts, mesh, barbed wire), a
## gatehouse and a red-and-white barrier arm at the gate on side
## `gate` ("e" | "w" | "n" | "s"), the gate 8 m wide.
## opts "gaps": [[side, offset from the side's middle, half width], ...] -
## more openings without a gatehouse (a rail siding's way in).
static func fence(g: Geo, site: Dictionary, gate: String, opts: Dictionary = {}) -> Array:
	ensure_materials(g)
	if not g.has_material("ind_mesh"):
		var mesh: StandardMaterial3D = Geo.tex_mat(_mesh_tex(), Color(0.55, 0.6, 0.55), 0.6)
		mesh.cull_mode = BaseMaterial3D.CULL_DISABLED
		mesh.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		g.add_material("ind_mesh", mesh)
	var o := Vector3(site.c.x, site.y, site.c.y)
	var h: Vector2 = site.size * 0.5 + Vector2(1.0, 1.0)
	var sides: Dictionary = {"n": [Vector3(-h.x, 0, -h.y), Vector3(h.x, 0, -h.y)], "s": [Vector3(-h.x, 0, h.y), Vector3(h.x, 0, h.y)],
		"w": [Vector3(-h.x, 0, -h.y), Vector3(-h.x, 0, h.y)], "e": [Vector3(h.x, 0, -h.y), Vector3(h.x, 0, h.y)]}
	var views: Array = []
	for k: String in sides:
		var a: Vector3 = o + (sides[k][0] as Vector3)
		var b: Vector3 = o + (sides[k][1] as Vector3)
		var L: float = a.distance_to(b)
		var dir: Vector3 = (b - a) / L
		var cuts: Array = []
		if k == gate:
			cuts.append([L * 0.5 - 4.0, L * 0.5 + 4.0])
		for gp: Array in opts.get("gaps", []):
			if gp[0] == k:
				cuts.append([L * 0.5 + gp[1] - gp[2], L * 0.5 + gp[1] + gp[2]])
		cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var runs: Array = []
		var from: float = 0.0
		for c: Array in cuts:
			if c[0] - from > 0.5:
				runs.append([from, c[0]])
			from = c[1]
		if L - from > 0.5:
			runs.append([from, L])
		for run: Array in runs:
			var n: int = maxi(1, int((run[1] - run[0]) / 3.0))
			for i in range(n + 1):
				var q: Vector3 = a + dir * (run[0] + (run[1] - run[0]) * i / n)
				g.tint = Color(0.75, 0.75, 0.72)
				g.box_on(Transform3D(Basis(), q + Vector3(0, 1.1, 0)), Vector3(0.14, 2.2, 0.14), "in_concrete", o.y)
			var m0: Vector3 = a + dir * ((run[0] + run[1]) * 0.5)
			g.tint = Color.WHITE
			g.box(m0 + Vector3(0, 1.05, 0), Vector3(0.02, 1.9, run[1] - run[0]) if absf(dir.z) > 0.5 else Vector3(run[1] - run[0], 1.9, 0.02), "ind_mesh", 0.0, false, false)
			g.tint = Color(0.3, 0.3, 0.3)
			for y in [2.15, 2.3]:
				g.box(m0 + Vector3(0, y, 0), Vector3(0.02, 0.02, run[1] - run[0]) if absf(dir.z) > 0.5 else Vector3(run[1] - run[0], 0.02, 0.02), "ind_paint", 0.0, false, false)
		if k == gate:
			# Gatehouse inside the fence beside the gate, a barrier across it.
			var gm: Vector3 = a + dir * (L * 0.5)
			var inward: Vector3 = (o - gm)
			inward.y = 0.0
			inward = inward.normalized()
			var gh: Vector3 = gm + dir * 7.0 + inward * 3.0
			g.tint = Color(0.92, 0.92, 0.9)
			g.box_on(Transform3D(Basis(), gh + Vector3(0, 1.4, 0)), Vector3(3.0, 2.8, 3.0), "in_concrete", o.y)
			g.tint = Color.WHITE
			g.box(gh + Vector3(0, 1.6, 0) - inward * 1.52, Vector3(2.2, 1.0, 0.06) if absf(inward.z) > 0.5 else Vector3(0.06, 1.0, 2.2), "in_glass", 0.0, false)
			g.tint = Color(0.3, 0.3, 0.32)
			g.box(gh + Vector3(0, 2.9, 0), Vector3(3.4, 0.2, 3.4), "in_paint")
			var post: Vector3 = gm + dir * 4.3
			g.tint = Color(0.9, 0.85, 0.2)
			g.box_on(Transform3D(Basis(), post + Vector3(0, 0.55, 0)), Vector3(0.4, 1.1, 0.4), "in_paint", o.y)
			for s in range(8):
				g.tint = Color(0.85, 0.12, 0.1) if s % 2 == 0 else Color(0.96, 0.96, 0.95)
				g.beam(post + Vector3(0, 1.0, 0) - dir * (s * 1.0), post + Vector3(0, 1.0, 0) - dir * ((s + 1) * 1.0), Vector2(0.1, 0.1), "in_paint", true, false)
			g.tint = Color.WHITE
			views.append(["gate", gm - inward * 14.0 + Vector3(0, 2.5, 0), gm + inward * 10.0])
	g.tint = Color.WHITE
	return views

## Chain-link mesh: diagonal wires, see-through between them.
static func _mesh_tex() -> Texture2D:
	var size: int = 64
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	for i in range(size):
		for k in [0, size / 2]:
			img.set_pixel((i + k) % size, i, Color(0.8, 0.8, 0.8, 1.0))
			img.set_pixel((size - 1 - i + k) % size, i, Color(0.8, 0.8, 0.8, 1.0))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)
