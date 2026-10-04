class_name CityHouseCreator
extends RefCounted

## Creator: town houses standing shoulder to shoulder along a street, in
## three styles a German town actually has side by side:
## - "altbau" (around 1900): 4-5 tall storeys in pastel plaster, a
##   rusticated ground floor, framed windows with sills and crosses,
##   string courses and a heavy cornice, a steep tiled roof with
##   dormers and chimneys, iron balconies on the middle axis; now and
##   then an archway through to the courtyard behind (fly through it).
## - "fifties" (1950s-60s): 3-4 lower storeys, plain plaster, a grid of
##   smaller windows, a glass-block stairwell strip, loggia balconies
##   with solid fronts, a low tiled roof.
## - "modern": 4-6 storeys, white render with a timber section, big
##   windows with dark frames, glass balconies, a flat roof with a
##   set-back top floor, its terrace, a lift housing and vents.
## Ground floors are often shops: a big window, a name board, sometimes
## an awning. Houses are closed (no interiors); the glass is dark.
##
##   var lots: Array = CityHouseCreator.plan_row(land, road, d0, d1, side, opts)   before land.build
##   CityHouseCreator.build_row(geo, lots, seed) -> {"views": [...]}
##   CityHouseCreator.build(geo, frame, width, depth, style, rng, opts)   one house
## frame: origin at the middle of the front wall's foot (pavement
## level), +z out to the street, x along it; the house fills x +-w/2,
## z 0..-depth. Real numbers: Altbau storeys 3.4-4 m, windows ~1.2 x 2 m
## at ~2.8 m centres; 1950s storeys ~2.85 m; modern ~3.1 m.

const STYLES := ["altbau", "fifties", "modern"]
const WALK: float = 3.0 ## pavement width in front of a row
const SHOPS := ["Bäckerei", "Apotheke", "Café Sonne", "Blumen Lang", "Friseur", "Kiosk", "Metzgerei", "Bücher", "Eiscafé", "Optik", "Schuhe Weber", "Weinstube", "Reisebüro", "Fahrräder", "Imbiss", "Schreibwaren"]
const PLASTER := {
	"altbau": [Color(1.0, 0.93, 0.78), Color(0.98, 0.82, 0.58), Color(1.0, 0.86, 0.82), Color(0.84, 0.89, 0.93), Color(0.87, 0.91, 0.79), Color(0.97, 0.96, 0.92)],
	"fifties": [Color(0.93, 0.88, 0.74), Color(0.98, 0.94, 0.7), Color(0.84, 0.85, 0.84), Color(0.82, 0.9, 0.82), Color(0.96, 0.86, 0.78)],
	"modern": [Color(0.96, 0.96, 0.95), Color(0.9, 0.9, 0.9), Color(0.82, 0.83, 0.85)],
}

var geo: Geo
var rng: RandomNumberGenerator
var f: Transform3D
var W: float
var D: float
var style: String
var col: Color
var gf: float ## ground floor height
var fl: float ## upper storey height
var floors: int
var H: float ## wall top
var views: Array = []
var opts: Dictionary

static func ensure_materials(g: Geo) -> void:
	if g.has_material("ch_plaster"):
		return
	g.add_material("ch_plaster", Geo.tex_mat(MapTextures.get_tex("plaster"), Color(1.12, 1.12, 1.1), 3.0))
	g.add_material("ch_trim", Geo.flat_mat(Color.WHITE, 0.6))
	g.add_material("ch_glass", Geo.flat_mat(Color(0.24, 0.3, 0.36), 0.1, 0.4))
	g.add_material("ch_shop", Geo.tex_mat(MapTextures.get_tex("shopfront"), Color(1.05, 1.05, 1.05), 7.0))
	g.add_material("ch_roof", Geo.tex_mat(MapTextures.get_tex("roof_tiles"), Color.WHITE, 2.5))
	g.add_material("ch_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.0, 0.85, 0.7), 1.2))
	g.add_material("ch_flat", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.75, 0.75, 0.74), 4.0))
	g.add_material("chd_metal", Geo.flat_mat(Color(0.16, 0.16, 0.17), 0.5, 0.5))
	g.add_material("chd_paint", Geo.flat_mat(Color.WHITE, 0.5))
	g.detail_prefixes.append("chd_")

## Lots along a road stretch (d0..d1 m along it) on one side: houses
## 9-16 m wide, 11-14 m deep, standing behind a pavement; each lot's
## ground is levelled to the road's bed (as VillageKit plots are).
## opts: seed, styles (weights by name), walk (pavement width).
static func plan_row(land: TerrainCreator, road: RoadCreator, d0: float, d1: float, side: float, o: Dictionary = {}) -> Array:
	var r := RandomNumberGenerator.new()
	r.seed = o.get("seed", 1)
	var route: Route = Route.from_pts(road.line.pts)
	var walk: float = o.get("walk", WALK)
	var weights: Dictionary = o.get("styles", {"altbau": 0.5, "fifties": 0.3, "modern": 0.2})
	var lots: Array = []
	var d: float = d0
	var prev_style: String = ""
	while true:
		var w: float = snappedf(r.randf_range(9.0, 16.0), 0.5)
		if d + w > d1:
			break
		var s: Array = route.sample(d + w * 0.5)
		var p: Vector3 = s[0]
		var t: Vector3 = s[1]
		var out: Vector3 = Vector3(-t.z, 0, t.x) * side
		var front: Vector3 = p + out * (road.line.half + walk)
		front.y = p.y + Roads.KERB
		var zdir: Vector3 = -out
		var frame := Transform3D(Basis(Vector3.UP, atan2(zdir.x, zdir.z)), front)
		var depth: float = snappedf(r.randf_range(11.0, 14.0), 0.5)
		var st: String = _pick(r, weights, prev_style)
		prev_style = st
		var level: float = p.y - TerrainCreator.ROAD_SINK
		var m: float = land.road_bed()
		var c_real3: Vector3 = frame * Vector3(0, 0, -depth * 0.5)
		var c_ext3: Vector3 = frame * Vector3(0, 0, -depth * 0.5 - m * 0.5)
		var ax := Vector2(frame.basis.x.x, frame.basis.x.z).normalized()
		land.flat_plot(Vector2(c_ext3.x, c_ext3.z), ax, w * 0.5 + 1.0, depth * 0.5 + m * 0.5 + 1.0, level, 8.0, [Vector2(c_real3.x, c_real3.z), w * 0.5, depth * 0.5])
		lots.append({"frame": frame, "width": w, "depth": depth, "style": st, "road": road, "d": d + w * 0.5, "side": side})
		d += w
	return lots

static func _pick(r: RandomNumberGenerator, weights: Dictionary, not_this: String) -> String:
	for _try in range(4):
		var total: float = 0.0
		for k: String in weights:
			total += weights[k]
		var x: float = r.randf() * total
		for k: String in weights:
			x -= weights[k]
			if x <= 0.0:
				if k != not_this or _try == 3:
					return k
				break
	return weights.keys()[0]

static func build_row(g: Geo, lots: Array, seed_value: int) -> Dictionary:
	ensure_materials(g)
	var r := RandomNumberGenerator.new()
	r.seed = seed_value
	var out: Array = []
	var shown: Dictionary = {}
	for i in range(lots.size()):
		var lot: Dictionary = lots[i]
		var info: Dictionary = build(g, lot.frame, lot.width, lot.depth, lot.style, r, {})
		for v: Array in info.views:
			# One view per style and the first archway; numbered, so none
			# overwrites another.
			if not shown.has(v[0]):
				shown[v[0]] = true
				out.append(["%s_%02d" % [v[0], i], v[1], v[2]])
	return {"views": out}

static func build(g: Geo, frame: Transform3D, width: float, depth: float, style_name: String, r: RandomNumberGenerator, o: Dictionary = {}) -> Dictionary:
	ensure_materials(g)
	var h := CityHouseCreator.new()
	h.geo = g
	h.rng = r
	h.f = frame
	h.W = width
	h.D = depth
	h.style = style_name
	h.opts = o
	h._build()
	return {"views": h.views}

# --- helpers (all in the house frame) ---------------------------------------------

func _box(c: Vector3, s: Vector3, mat: String, collide: bool = true) -> void:
	geo.box_on(f * Transform3D(Basis(), c), s, mat, f.origin.y, collide)

func _boxr(c: Vector3, s: Vector3, mat: String, rx: float, collide: bool = true) -> void:
	geo.box_xf(f * Transform3D(Basis(Vector3.RIGHT, rx), c), s, mat, collide)

func _tint(c: Color) -> void:
	geo.tint = c

# --- the house --------------------------------------------------------------------------

func _build() -> void:
	match style:
		"altbau":
			gf = rng.randf_range(3.8, 4.2)
			fl = rng.randf_range(3.3, 3.6)
			floors = rng.randi_range(4, 5)
		"fifties":
			gf = 3.0
			fl = 2.85
			floors = rng.randi_range(3, 4)
		_:
			gf = 3.6
			fl = 3.1
			floors = rng.randi_range(4, 6)
	H = gf + (floors - 1) * fl
	var cols: Array = PLASTER[style]
	col = cols[rng.randi() % cols.size()] * rng.randf_range(0.96, 1.03)
	var bays: int = maxi(2, int(W / (2.8 if style != "modern" else 3.4)))
	var bay: float = W / bays
	var shop: bool = rng.randf() < {"altbau": 0.6, "fifties": 0.4, "modern": 0.45}[style]
	var arch: bool = style == "altbau" and W >= 12.0 and rng.randf() < 0.3
	var arch_x: float = (-W * 0.5 + bay * 0.5) if rng.randf() < 0.5 else (W * 0.5 - bay * 0.5)
	var door_x: float = (W * 0.5 - bay * 0.5) * (1.0 if arch_x < 0.0 else -1.0)
	if not arch:
		door_x = (bays / 2 - (bays - 1) * 0.5) * bay if not shop else (W * 0.5 - bay * 0.5)
	_body(arch, arch_x, bay)
	_ground_floor(shop, arch, arch_x, door_x, bay, bays)
	for fi in range(1, floors):
		var y0: float = gf + (fi - 1) * fl
		for b in range(bays):
			var x: float = -W * 0.5 + bay * (b + 0.5)
			_window(Vector3(x, y0, 0.0), 1.0, fi)
			_window(Vector3(x, y0, -D), -1.0, fi)
		if style == "altbau":
			_tint(col * 0.94)
			_box(Vector3(0, y0 - 0.05, 0.06), Vector3(W, 0.16, 0.14), "ch_plaster", false) # string course
	_balconies(bays, bay)
	match style:
		"modern":
			_flat_roof()
		_:
			_pitched_roof(bays, bay)
	geo.tint = Color.WHITE
	if arch:
		views.append(["archway", f * Vector3(arch_x, 2.0, 6.0), f * Vector3(arch_x, 1.8, -D)])
	views.append(["town_" + style, f * Vector3(-W * 0.8, 3.0, 6.5), f * Vector3(W * 0.2, H * 0.55, 0.0)])

## Walls: one box per part; with an archway the ground floor leaves a
## passage open front to back (lined, with a lit vault).
func _body(arch: bool, arch_x: float, bay: float) -> void:
	var aw: float = minf(bay, 3.4)
	var ah: float = minf(gf - 0.4, 3.6)
	_tint(col)
	if arch:
		var x0: float = -W * 0.5
		var x1: float = W * 0.5
		var a0: float = arch_x - aw * 0.5
		var a1: float = arch_x + aw * 0.5
		if a0 - x0 > 0.05:
			_box(Vector3((x0 + a0) * 0.5, gf * 0.5, -D * 0.5), Vector3(a0 - x0, gf, D), "ch_plaster")
		if x1 - a1 > 0.05:
			_box(Vector3((a1 + x1) * 0.5, gf * 0.5, -D * 0.5), Vector3(x1 - a1, gf, D), "ch_plaster")
		_box(Vector3(arch_x, (ah + gf) * 0.5, -D * 0.5), Vector3(aw, gf - ah, D), "ch_plaster")
		# The passage's cobbles and a lamp in its vault.
		_tint(Color(0.55, 0.53, 0.5))
		_box(Vector3(arch_x, 0.02, -D * 0.5), Vector3(aw, 0.04, D + 0.4), "ch_flat", false)
		_tint(Color(1.0, 0.95, 0.8))
		_box(Vector3(arch_x, ah - 0.06, -D * 0.5), Vector3(0.3, 0.06, 0.3), "chd_paint", false)
		# Its frame on the street side.
		_tint(col * 0.85)
		for s in [-1.0, 1.0]:
			_box(Vector3(arch_x + s * (aw * 0.5 + 0.12), ah * 0.5, 0.08), Vector3(0.24, ah, 0.16), "ch_plaster", false)
		_box(Vector3(arch_x, ah + 0.15, 0.08), Vector3(aw + 0.48, 0.3, 0.16), "ch_plaster", false)
	else:
		_box(Vector3(0, gf * 0.5, -D * 0.5), Vector3(W, gf, D), "ch_plaster")
	_tint(col)
	_box(Vector3(0, gf + (H - gf) * 0.5, -D * 0.5), Vector3(W, H - gf, D), "ch_plaster")
	if style == "altbau":
		# Rusticated ground floor: a darker band with grooves.
		_tint(col * 0.86)
		for k in range(int(gf / 0.6)):
			_box(Vector3(0, 0.3 + k * 0.6, 0.02), Vector3(W, 0.05, 0.04), "ch_plaster", false)
	# Plinth.
	_tint(Color(0.55, 0.53, 0.5))
	_box(Vector3(0, 0.25, 0.03), Vector3(W, 0.5, 0.06), "ch_flat", false)

func _ground_floor(shop: bool, arch: bool, arch_x: float, door_x: float, bay: float, bays: int) -> void:
	# The house door: wood, a step, a fanlight over it.
	_tint(Color(0.75, 0.6, 0.45) if rng.randf() < 0.6 else Color(0.35, 0.42, 0.5))
	_box(Vector3(door_x, 1.25, 0.04), Vector3(1.2, 2.5, 0.08), "ch_wood", false)
	_tint(Color(0.7, 0.7, 0.68))
	_box(Vector3(door_x, 0.08, 0.35), Vector3(1.8, 0.16, 0.7), "ch_flat")
	if style == "altbau":
		_tint(Color.WHITE)
		_box(Vector3(door_x, 2.85, 0.04), Vector3(1.2, 0.5, 0.06), "ch_glass", false)
		_tint(col * 0.85)
		_box(Vector3(door_x, 3.25, 0.1), Vector3(1.7, 0.2, 0.2), "ch_plaster", false)
	if shop:
		# A shop across the rest of the front: a big window, its name.
		var x0: float = -W * 0.5 + 0.4
		var x1: float = W * 0.5 - 0.4
		if door_x < 0.0:
			x0 = door_x + 1.0
		else:
			x1 = door_x - 1.0
		if arch:
			if arch_x < door_x:
				x0 = maxf(x0, arch_x + minf(bay, 3.4) * 0.5 + 0.5)
			else:
				x1 = minf(x1, arch_x - minf(bay, 3.4) * 0.5 - 0.5)
		if x1 - x0 > 2.0:
			var cx: float = (x0 + x1) * 0.5
			var sw: float = x1 - x0
			_tint(Color(0.22, 0.22, 0.24))
			_box(Vector3(cx, 1.55, 0.05), Vector3(sw + 0.2, 2.5, 0.1), "chd_metal", false)
			_tint(Color.WHITE)
			_box(Vector3(cx, 1.55, 0.08), Vector3(sw, 2.3, 0.06), "ch_shop", false)
			# Window bars every ~2 m.
			_tint(Color(0.22, 0.22, 0.24))
			var nb: int = int(sw / 2.0)
			for k in range(1, nb):
				_box(Vector3(x0 + sw * k / nb, 1.55, 0.12), Vector3(0.08, 2.3, 0.04), "chd_metal", false)
			var sign_col: Color = [Color(0.15, 0.3, 0.55), Color(0.55, 0.15, 0.12), Color(0.2, 0.4, 0.25), Color(0.12, 0.12, 0.13), Color(0.85, 0.75, 0.6)][rng.randi() % 5]
			_tint(sign_col)
			_box(Vector3(cx, 3.15, 0.08), Vector3(sw, 0.55, 0.12), "chd_paint", false)
			var name_txt: String = SHOPS[rng.randi() % SHOPS.size()]
			StreetKit._label(geo, name_txt, f * Transform3D(Basis(), Vector3(cx, 3.15, 0.15)), 0.006, Color(0.98, 0.95, 0.85) if sign_col.v < 0.6 else Color(0.1, 0.1, 0.1))
			if rng.randf() < 0.55:
				# Awning, tilted out over the pavement, and its valance.
				var aw_col: Color = [Color(0.75, 0.15, 0.12), Color(0.15, 0.4, 0.25), Color(0.9, 0.75, 0.3), Color(0.2, 0.3, 0.55)][rng.randi() % 4]
				_tint(aw_col)
				geo.box_xf(f * Transform3D(Basis(Vector3.RIGHT, 0.35), Vector3(cx, 2.85, 0.75)), Vector3(sw, 0.05, 1.6), "chd_paint", false)
				_tint(aw_col * 0.85)
				_box(Vector3(cx, 2.42, 1.5), Vector3(sw, 0.25, 0.03), "chd_paint", false)
	else:
		for b in range(bays):
			var x: float = -W * 0.5 + bay * (b + 0.5)
			if absf(x - door_x) < 1.2 or (arch and absf(x - arch_x) < bay * 0.6):
				continue
			_window(Vector3(x, 0.0, 0.0), 1.0, 0)
	# The back: windows on the ground floor too.
	for b in range(bays):
		var x: float = -W * 0.5 + bay * (b + 0.5)
		if arch and absf(x - arch_x) < bay * 0.6:
			continue
		_window(Vector3(x, 0.0, -D), -1.0, 0)

## A window on a storey whose floor is at p.y (x = its axis, z = the
## wall), facing `face` (+1 front, -1 back): frame, sill, glass and, by
## style, a surround with a cornice or a cross.
func _window(p: Vector3, face: float, storey: int) -> void:
	var w: float
	var h: float
	var sill: float
	var stor_h: float = gf if storey == 0 else fl
	match style:
		"altbau":
			w = 1.2
			h = minf(2.1, stor_h - 1.3)
			sill = 0.9
		"fifties":
			w = 1.3
			h = 1.4
			sill = 0.95
		_:
			w = 2.2
			h = stor_h - 0.7
			sill = 0.15
	var y: float = p.y + sill + h * 0.5
	var z: float = p.z
	var out: float = face
	var front: bool = face > 0.0
	# Glass, just proud of the wall; frames round it stand out further.
	_tint(Color.WHITE * rng.randf_range(0.8, 1.5)) # some panes catch the sky
	_box(Vector3(p.x, y, z + out * 0.03), Vector3(w, h, 0.06), "ch_glass", false)
	var frame_col: Color = Color(0.2, 0.21, 0.23) if style == "modern" else Color(0.97, 0.97, 0.95)
	_tint(frame_col)
	_box(Vector3(p.x, y - h * 0.5 - 0.04, z + out * 0.09), Vector3(w + 0.2, 0.08, 0.18 if not front else 0.22), "ch_trim", false) # sill
	if not front:
		geo.tint = Color.WHITE
		return
	for s in [-1.0, 1.0]:
		_box(Vector3(p.x + s * (w * 0.5 + 0.04), y, z + out * 0.06), Vector3(0.08, h, 0.12), "ch_trim", false)
	_box(Vector3(p.x, y + h * 0.5 + 0.04, z + out * 0.06), Vector3(w + 0.16, 0.08, 0.12), "ch_trim", false)
	match style:
		"altbau":
			# The cross, and a surround with a little cornice over it.
			_box(Vector3(p.x, y, z + out * 0.07), Vector3(0.06, h, 0.04), "chd_paint", false)
			_box(Vector3(p.x, y + h * 0.18, z + out * 0.07), Vector3(w, 0.06, 0.04), "chd_paint", false)
			_tint(col * 0.88)
			_box(Vector3(p.x, y + h * 0.5 + 0.2, z + out * 0.1), Vector3(w + 0.5, 0.14, 0.2), "ch_plaster", false)
			if storey == 1:
				_box(Vector3(p.x, y + h * 0.5 + 0.45, z + out * 0.06), Vector3(w + 0.2, 0.3, 0.12), "ch_plaster", false)
		"fifties":
			_box(Vector3(p.x, y, z + out * 0.07), Vector3(0.06, h, 0.04), "chd_paint", false)
			if rng.randf() < 0.3: # a roller shutter half down
				_tint(Color(0.8, 0.78, 0.72))
				_box(Vector3(p.x, y + h * 0.25, z + out * 0.05), Vector3(w, h * 0.5, 0.04), "chd_paint", false)
		_:
			pass
	# Now and then a window box of flowers.
	if style != "modern" and storey > 0 and rng.randf() < 0.12:
		_tint(Color(0.45, 0.3, 0.2))
		_box(Vector3(p.x, y - h * 0.5 + 0.12, z + out * 0.28), Vector3(w * 0.9, 0.2, 0.22), "chd_paint", false)
		_tint([Color(0.9, 0.15, 0.2), Color(0.95, 0.5, 0.7), Color(1.0, 0.85, 0.2)][rng.randi() % 3])
		_box(Vector3(p.x, y - h * 0.5 + 0.28, z + out * 0.28), Vector3(w * 0.85, 0.14, 0.2), "chd_paint", false)
	geo.tint = Color.WHITE

func _balconies(bays: int, bay: float) -> void:
	match style:
		"altbau":
			if rng.randf() > 0.45:
				return
			var x: float = -W * 0.5 + bay * (bays / 2 + 0.5) if bays % 2 == 1 else 0.0
			var bw: float = minf(bay * (1.0 if bays % 2 == 1 else 2.0) - 0.4, 3.6)
			for fi in range(1, floors - 1):
				var y: float = gf + (fi - 1) * fl
				_tint(col * 0.9)
				_box(Vector3(x, y, 0.65), Vector3(bw, 0.18, 1.3), "ch_plaster")
				_railing(Vector3(x, y + 0.09, 1.25), bw, true)
				for s in [-1.0, 1.0]:
					_railing(Vector3(x + s * bw * 0.5, y + 0.09, 0.65), 1.2, false)
		"fifties":
			for fi in range(1, floors):
				var y: float = gf + (fi - 1) * fl
				for b in range(bays):
					if b % 3 != 1:
						continue
					var x: float = -W * 0.5 + bay * (b + 0.5)
					_tint(Color(0.7, 0.7, 0.68))
					_box(Vector3(x, y - 0.08, 0.6), Vector3(bay - 0.2, 0.16, 1.2), "ch_flat")
					_tint([Color(0.7, 0.3, 0.2), Color(0.3, 0.5, 0.6), Color(0.85, 0.8, 0.6)][(fi + b) % 3])
					_box(Vector3(x, y + 0.5, 1.17), Vector3(bay - 0.2, 0.9, 0.06), "chd_paint", false)
		_:
			for fi in range(1, floors - 1):
				var y: float = gf + (fi - 1) * fl
				for b in range(bays):
					if (b + fi) % 2 != 0:
						continue
					var x: float = -W * 0.5 + bay * (b + 0.5)
					_tint(Color(0.85, 0.85, 0.85))
					_box(Vector3(x, y - 0.1, 0.8), Vector3(bay - 0.3, 0.2, 1.6), "ch_flat")
					_tint(Color(0.7, 0.85, 0.9))
					_box(Vector3(x, y + 0.5, 1.58), Vector3(bay - 0.3, 1.0, 0.03), "ch_glass", false)
	geo.tint = Color.WHITE

## An iron railing 1 m high along local x (or z), bars every 12 cm.
func _railing(c: Vector3, length: float, along_x: bool) -> void:
	_tint(Color(0.15, 0.15, 0.16))
	if along_x:
		_box(c + Vector3(0, 1.0, 0), Vector3(length, 0.05, 0.05), "chd_metal", false)
		var n: int = int(length / 0.12)
		for k in range(0, n + 1, 2):
			_box(c + Vector3(-length * 0.5 + k * length / n, 0.5, 0), Vector3(0.025, 1.0, 0.025), "chd_metal", false)
	else:
		_box(c + Vector3(0, 1.0, 0), Vector3(0.05, 0.05, length), "chd_metal", false)
		_box(c + Vector3(0, 0.5, 0), Vector3(0.03, 1.0, length), "chd_metal", false)

## Pitched roof, ridge along the street: two tiled planes, gable walls
## at both ends (the neighbour's may stand taller - a fire wall), a
## cornice at the eaves, dormers on the front slope, chimneys.
func _pitched_roof(bays: int, bay: float) -> void:
	var pitch: float = deg_to_rad(rng.randf_range(42.0, 50.0) if style == "altbau" else rng.randf_range(28.0, 34.0))
	var over: float = 0.45 if style == "altbau" else 0.3
	var run: float = D * 0.5 + over
	var rise: float = D * 0.5 * tan(pitch)
	var plane: float = run / cos(pitch)
	var roof_col: Color = [Color(0.85, 0.42, 0.3), Color(0.55, 0.3, 0.25), Color(0.4, 0.42, 0.46)][rng.randi() % 3]
	_tint(roof_col)
	for s in [-1.0, 1.0]:
		var zc: float = -D * 0.5 + s * run * 0.5
		var yc: float = H + rise - (run * 0.5) * tan(pitch) + 0.1
		_boxr(Vector3(0, yc, zc), Vector3(W + 0.02, 0.2, plane + 0.05), "ch_roof", s * pitch)
	_box(Vector3(0, H + rise + 0.12, -D * 0.5), Vector3(W + 0.02, 0.25, 0.4), "ch_roof")
	_tint(col)
	for s in [-1.0, 1.0]:
		geo.prism(f * Transform3D(Basis(), Vector3(s * (W * 0.5 - 0.15), 0, 0)), [Vector2(0.0, H - 0.02), Vector2(-D, H - 0.02), Vector2(-D * 0.5, H + rise)], 0.3, "ch_plaster")
	# Eaves cornice front and back.
	_tint(col * 0.9 if style == "altbau" else Color(0.95, 0.95, 0.93))
	for z in [0.0, -D]:
		var oz: float = 0.2 if z == 0.0 else -0.2
		_box(Vector3(0, H - 0.25, z + oz), Vector3(W, 0.5 if style == "altbau" else 0.25, 0.45 if style == "altbau" else 0.25), "ch_plaster", false)
	# Dormers (Altbau): every other bay, a third of the way up.
	if style == "altbau":
		for b in range(bays):
			if b % 2 == 0 and bays > 2:
				continue
			var x: float = -W * 0.5 + bay * (b + 0.5)
			var zf: float = -1.4
			var yb: float = H + (-zf) * tan(pitch) - 0.25
			_tint(col)
			_box(Vector3(x, yb + 0.85, zf - 1.0), Vector3(1.5, 1.7, 2.0), "ch_plaster")
			_tint(Color.WHITE)
			_box(Vector3(x, yb + 0.9, zf + 0.02), Vector3(0.9, 1.2, 0.06), "ch_glass", false)
			_tint(Color(0.97, 0.97, 0.95))
			_box(Vector3(x, yb + 0.28, zf + 0.06), Vector3(1.05, 0.08, 0.12), "ch_trim", false)
			_tint(roof_col)
			geo.prism(f * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x, 0, zf - 1.0)), [Vector2(-0.9, yb + 1.7), Vector2(0.9, yb + 1.7), Vector2(0.0, yb + 2.3)], 2.3, "ch_roof")
	# Chimneys on the ridge.
	_tint(Color(0.55, 0.3, 0.25))
	for k in range(rng.randi_range(1, 2)):
		var x: float = rng.randf_range(-W * 0.35, W * 0.35)
		_box(Vector3(x, H + rise + 0.6, -D * 0.5 + rng.randf_range(-1.5, 1.5)), Vector3(0.6, 1.8, 0.6), "ch_flat")
	geo.tint = Color.WHITE

## Flat roof: a parapet, the top floor set back with its terrace and a
## glass railing, a lift housing and vents.
func _flat_roof() -> void:
	_tint(Color(0.5, 0.5, 0.5))
	_box(Vector3(0, H + 0.05, -D * 0.5), Vector3(W, 0.1, D), "ch_flat")
	_tint(col)
	for z in [-0.15, -D + 0.15]:
		_box(Vector3(0, H + 0.45, z), Vector3(W, 0.8, 0.3), "ch_plaster")
	# The set-back top floor (Staffelgeschoss), 2.5 m in from the front.
	var top_h: float = 3.0
	var zf: float = -2.5
	_tint(col)
	var tz0: float = zf # its front wall
	var tz1: float = -D + 1.0 # its back wall
	_box(Vector3(0, H + top_h * 0.5, (tz0 + tz1) * 0.5), Vector3(W - 0.6, top_h, tz0 - tz1), "ch_plaster")
	var bays: int = maxi(2, int(W / 3.4))
	for b in range(bays):
		var x: float = -W * 0.5 + 0.3 + (W - 0.6) * (b + 0.5) / bays
		_tint(Color.WHITE)
		_box(Vector3(x, H + 1.4, zf + 0.03), Vector3((W - 0.6) / bays - 0.5, 2.4, 0.06), "ch_glass", false)
	_tint(Color(0.3, 0.3, 0.32))
	_box(Vector3(0, H + top_h + 0.1, (tz0 + tz1) * 0.5), Vector3(W - 0.4, 0.2, tz0 - tz1 + 0.6), "ch_flat")
	_tint(Color(0.7, 0.85, 0.9))
	_box(Vector3(0, H + 1.3, -0.3), Vector3(W - 0.4, 1.0, 0.04), "ch_glass", false)
	# Lift housing and vents.
	_tint(col * 0.9)
	_box(Vector3(-W * 0.25, H + top_h + 1.4, (tz0 + tz1) * 0.5), Vector3(2.2, 2.6, 2.4), "ch_plaster")
	_tint(Color(0.6, 0.62, 0.64))
	for k in range(rng.randi_range(2, 4)):
		_box(Vector3(rng.randf_range(-W * 0.35, W * 0.35), H + top_h + 0.45, rng.randf_range(tz1 + 1.0, tz0 - 1.0)), Vector3(0.6, 0.5, 0.6), "chd_paint")
	# A timber-clad section on the front, in the top floors.
	if rng.randf() < 0.6:
		_tint(Color(0.85, 0.65, 0.45))
		var x: float = W * 0.5 - 1.6 if rng.randf() < 0.5 else -W * 0.5 + 1.6
		_box(Vector3(x, gf + (H - gf) * 0.5, 0.04), Vector3(2.4, H - gf, 0.08), "ch_wood", false)
	geo.tint = Color.WHITE
