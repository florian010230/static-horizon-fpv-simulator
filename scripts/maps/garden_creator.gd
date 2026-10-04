class_name GardenCreator
extends RefCounted

## Creator: the plot round a house - called by HouseCreator.build_plot,
## not by maps. One kind of boundary all round, one height (a trimmed
## hedge, a white or wooden picket fence, post-and-rail, or a low stone
## wall), with a gate where the front path meets the street and an
## opening for the driveway. Flower beds in front of the house, and the
## garden behind it: trees, bushes, sometimes a flower border, a shed
## with stepping stones to it, a bench, a bird bath, a little pond, a
## washing line, vegetable beds, a trampoline or a sandpit. And now and then a garden gnome by the path - very
## rarely a whole army of them.
##
##   GardenCreator.build(geo, plot, house_info, rng) -> {"trees": [...], "views": [...]}
## plot: {"frame": Transform3D (origin mid street edge, +z to the street,
## x along it), "width", "depth"}; house_info: HouseCreator.build()'s
## result (gate, drive, xf, size).
## Real numbers: front fences 0.8-1.0 m, side hedges 1.4-1.8 m, posts
## every ~2.4 m, a garden shed ~2.5 x 2 m.

const GNOME_CHANCE: float = 0.06
const GNOME_ARMY_CHANCE: float = 0.01

var geo: Geo
var f: Transform3D
var rng: RandomNumberGenerator
var W: float
var D: float

static func ensure_materials(g: Geo) -> void:
	if g.has_material("gd_paint"):
		return
	g.add_material("gd_paint", Geo.flat_mat(Color.WHITE, 0.6))
	g.add_material("gd_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.05, 0.95, 0.85), 1.2))
	g.add_material("gd_hedge", Geo.tex_mat(MapTextures.get_tex("foliage"), Color(0.62, 0.8, 0.48), 0.9))
	g.add_material("gd_stone", Geo.tex_mat(MapTextures.get_tex("rock"), Color(1.0, 0.95, 0.88), 1.5))
	g.add_material("gd_soil", Geo.flat_mat(Color(0.33, 0.24, 0.17), 0.95))
	g.detail_prefixes.append("gd_")

static func build(g: Geo, plot: Dictionary, house: Dictionary, r: RandomNumberGenerator) -> Dictionary:
	ensure_materials(g)
	var gc := GardenCreator.new()
	gc.geo = g
	gc.f = plot.frame
	gc.rng = r
	gc.W = plot.width
	gc.D = plot.depth
	return gc._build(house)

func _build(house: Dictionary) -> Dictionary:
	var inv: Transform3D = f.affine_inverse()
	var gaps: Array = [] # [x centre, half width] on the street edge
	if house.gate != Vector3.INF:
		gaps.append([(inv * (house.gate as Vector3)).x, 0.9])
	if house.drive != Vector3.INF:
		gaps.append([(inv * (house.drive as Vector3)).x, 1.9])
	# One kind of boundary all round the plot, the same height everywhere.
	var front: String = _pick_style()
	fence_h = {"hedge": rng.randf_range(1.1, 1.6), "picket_white": 0.95, "picket_wood": 0.95, "rails": 1.1, "wall": 0.75}[front]
	var hw: float = W * 0.5
	_edge(Vector3(-hw, 0, 0), Vector3(hw, 0, 0), front, gaps)
	_edge(Vector3(-hw, 0, -D), Vector3(hw, 0, -D), front, [])
	_edge(Vector3(-hw, 0, -D), Vector3(-hw, 0, 0), front, [])
	_edge(Vector3(hw, 0, -D), Vector3(hw, 0, 0), front, [])
	# Gate posts at the path.
	if house.gate != Vector3.INF:
		var gx: float = (inv * (house.gate as Vector3)).x
		var post_mat: String = {"wall": "gd_stone", "picket_wood": "gd_wood", "rails": "gd_wood"}.get(front, "gd_paint")
		geo.tint = Color(0.92, 0.92, 0.9) if post_mat == "gd_paint" else (Color(0.8, 0.66, 0.5) if post_mat == "gd_wood" else Color.WHITE)
		if front != "hedge":
			for s in [-1.0, 1.0]:
				_box(Vector3(gx + s * 0.95, (fence_h + 0.2) * 0.5, -0.05), Vector3(0.14, fence_h + 0.2, 0.14), post_mat)
		geo.tint = Color.WHITE
	var trees: Array = []
	var views: Array = []
	# The back garden: from the house's terrace to the back fence.
	var house_back: float = -(HouseCreator.PLOT_SETBACK + 5.4 + house.size.y * 0.5 + 3.5)
	var yard := Rect2(-hw + 1.5, -D + 1.5, W - 3.0, maxf(house_back - (-D + 1.5), 2.0))
	for i in range(rng.randi_range(1, 3)):
		trees.append([_world(Vector3(rng.randf_range(yard.position.x + 1.5, yard.end.x - 1.5), -0.05, rng.randf_range(yard.position.y + 1.5, yard.position.y + 4.5))), "", rng.randi(), "random"])
	for i in range(rng.randi_range(2, 4)):
		var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
		trees.append([_world(Vector3(sx * (hw - 1.9), -0.05, rng.randf_range(-D + 2.0, -3.0))), "bush", rng.randi(), "none"])
	var used: Array = [] # rects taken in the yard
	var flowers: Array = _palette()
	tall_kind = ["tulip", "daisy", "spike"][rng.randi() % 3]
	_flowers = _flower_list(geo)
	# In front of the house: flower beds either side of the path.
	if rng.randf() < 0.75:
		var gx: float = (inv * (house.gate as Vector3)).x if house.gate != Vector3.INF else 0.0
		var face: float = -(HouseCreator.PLOT_SETBACK + 5.4 - house.size.y * 0.5) + 0.75
		var half_house: float = house.size.x * 0.5 - 0.4
		for side in [-1.0, 1.0]:
			var a: float = gx + side * 1.4
			var b: float = side * half_house
			if (b - a) * side > 1.5:
				_flower_bed(Vector3((a + b) * 0.5, 0, face), absf(b - a), 0.9, flowers)
	# A flower border along one side of the garden.
	if rng.randf() < 0.45:
		var sx: float = -1.0 if rng.randf() < 0.5 else 1.0
		var zb: float = rng.randf_range(yard.position.y + 1.0, maxf(yard.end.y - 9.0, yard.position.y + 1.0))
		var bed := Vector3(sx * (hw - 1.3), 0, zb + 4.0)
		_flower_bed(bed, 8.0, 1.0, flowers, true)
	if rng.randf() < 0.35:
		var r: Rect2 = _spot(yard, Vector2(2.6, 2.2), used)
		_shed(r)
		if r.size != Vector2.ZERO:
			_stepping_stones(Vector3(r.get_center().x, 0, r.end.y + 0.3), Vector3(rng.randf_range(-2.0, 2.0), 0, yard.end.y))
	if rng.randf() < 0.35:
		_bench(_spot(yard, Vector2(2.0, 1.2), used))
	if rng.randf() < 0.15:
		_bird_bath(_spot(yard, Vector2(1.0, 1.0), used))
	if rng.randf() < 0.1:
		_garden_pond(_spot(yard, Vector2(3.2, 2.6), used))
	if rng.randf() < 0.3:
		_washing_line(_spot(yard, Vector2(4.4, 1.0), used))
	if rng.randf() < 0.3:
		_veg_beds(_spot(yard, Vector2(3.2, 3.0), used))
	if rng.randf() < 0.15:
		_trampoline(_spot(yard, Vector2(3.6, 3.6), used))
	elif rng.randf() < 0.12:
		_sandpit(_spot(yard, Vector2(2.2, 2.2), used))
	# Household bins inside the front fence, beside the path - on the side
	# away from the drive. (Own random numbers: the rest of the garden
	# stays as it was.)
	var brng := RandomNumberGenerator.new()
	brng.seed = rng.seed + 5
	if house.gate != Vector3.INF and brng.randf() < 0.6:
		var gx0: float = (inv * (house.gate as Vector3)).x
		var side: float = -1.0
		if house.drive != Vector3.INF and signf((inv * (house.drive as Vector3)).x - gx0) < 0.0:
			side = 1.0
		var bx: float = gx0 + side * (2.4 if side < 0.0 else 3.4) # (+ side: past the gnome's spot)
		StreetKit.wheelie_bins(geo, f * Vector3(bx, 0, -1.0), atan2(f.basis.z.x, f.basis.z.z), brng.randi_range(2, 3), brng)
	# Surprise: a garden gnome by the path - very rarely an army of them.
	var gnome_x: float = (inv * (house.gate as Vector3)).x if house.gate != Vector3.INF else 0.0
	if rng.randf() < GNOME_ARMY_CHANCE or OS.has_environment("SH_GNOMES"):
		for k in range(15):
			_gnome(Vector3(gnome_x + 2.0 + (k % 5) * 0.7, 0, -2.0 - (k / 5) * 0.8), 0.0)
		views.append(["gnome_army", _world(Vector3(gnome_x + 3.4, 1.4, 3.5)), _world(Vector3(gnome_x + 3.4, 0.3, -2.8))])
	elif rng.randf() < GNOME_CHANCE:
		_gnome(Vector3(gnome_x + 1.4, 0, -1.6), rng.randf_range(-0.5, 0.5))
	return {"trees": trees, "views": views}

var fence_h: float = 1.0

func _pick_style() -> String:
	var r: float = rng.randf()
	if r < 0.35:
		return "hedge"
	if r < 0.6:
		return "picket_white"
	if r < 0.75:
		return "picket_wood"
	if r < 0.87:
		return "rails"
	return "wall"

## Two or three flower colours that go together, per garden.
func _palette() -> Array:
	var sets: Array = [
		[Color(0.95, 0.25, 0.3), Color(1.0, 0.85, 0.3), Color(0.98, 0.98, 0.95)],
		[Color(0.6, 0.35, 0.85), Color(0.95, 0.55, 0.75), Color(0.98, 0.98, 0.95)],
		[Color(1.0, 0.55, 0.15), Color(1.0, 0.85, 0.3), Color(0.9, 0.2, 0.2)],
		[Color(0.35, 0.5, 0.95), Color(0.98, 0.98, 0.95), Color(0.95, 0.75, 0.85)],
	]
	return sets[rng.randi() % sets.size()]

## A bed of flowers centred at c (plot frame): dark soil edged with a
## low board, two rows of flower clumps - the tall kind at the back,
## low bedding plants in front - in drifts of one colour, the way beds
## are planted.
func _flower_bed(c: Vector3, length: float, depth: float, cols: Array, along_z: bool = false) -> void:
	var size: Vector3 = Vector3(depth, 0.12, length) if along_z else Vector3(length, 0.12, depth)
	geo.tint = Color.WHITE
	_box(c + Vector3(0, 0.05, 0), size, "gd_soil", false)
	geo.tint = Color(0.75, 0.62, 0.48)
	_box(c + Vector3(0, 0.07, 0), size + Vector3(0.1, -0.06, 0.1), "gd_wood", false)
	geo.tint = Color.WHITE
	var n: int = maxi(2, int(length / 0.42))
	for row in [-1.0, 1.0]:
		var kind: String = tall_kind if row < 0.0 else "mound"
		var col: Color = cols[rng.randi() % cols.size()]
		for k in range(n):
			if k % 3 == 0 and rng.randf() < 0.6:
				col = cols[rng.randi() % cols.size()] # the next drift
			var t: float = (k + 0.5) / n - 0.5 + rng.randf_range(-0.02, 0.02)
			var off: float = row * depth * 0.22 + rng.randf_range(-0.04, 0.04)
			var p: Vector3 = c + (Vector3(off, 0.09, t * length) if along_z else Vector3(t * length, 0.09, off))
			var sc: float = rng.randf_range(0.85, 1.15)
			_flowers.append([f * Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p), kind, col * rng.randf_range(0.92, 1.05)])

## This garden's tall flowers (the back row of its beds).
var tall_kind: String = "tulip"
## [world transform, kind, colour] for every clump - planted as MultiMesh.
var _flowers: Array = []

# --- flowers ------------------------------------------------------------------------
# A few clump shapes, built once, drawn as MultiMesh per 64 m cell and
# shape: a thousand clumps cost a few draw calls and no build time.
# shaders/flower.gdshader: alpha 1 leaves, 0.4 petals (coloured per
# clump), 0.2 plain colour.

const FLOWER_KINDS: Array = ["mound", "tulip", "daisy", "spike"]
const FLOWER_RANGE: float = 110.0 ## a 40 cm clump is a few pixels further out
const FLOWER_CELL: float = 64.0
static var _fmesh: Dictionary = {}
static var _fmat: ShaderMaterial

## The clumps of one geo, planted when it commits.
static func _flower_list(g: Geo) -> Array:
	if not g.has_meta("gd_flowers"):
		var list: Array = []
		g.set_meta("gd_flowers", list)
		g.on_commit.append(func(holder: Node3D) -> void:
			_plant_flowers(holder, list)
			g.remove_meta("gd_flowers"))
	return g.get_meta("gd_flowers")

static func _plant_flowers(holder: Node3D, list: Array) -> void:
	if OS.has_environment("SH_PERF"):
		var tris: int = 0
		for e: Array in list:
			tris += (_flower_mesh(e[1]).surface_get_array_len(0)) / 3
		print("FLOWERS %d clumps, %d triangles" % [list.size(), tris])
	var cells: Dictionary = {}
	for e: Array in list:
		var o: Vector3 = (e[0] as Transform3D).origin
		var key := [Vector2i(floori(o.x / FLOWER_CELL), floori(o.z / FLOWER_CELL)), e[1]]
		if not cells.has(key):
			cells[key] = []
		cells[key].append(e)
	for key: Array in cells:
		var items: Array = cells[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		mm.use_colors = true # (else the compatibility renderer multiplies in black)
		mm.mesh = _flower_mesh(key[1])
		mm.instance_count = items.size()
		for i in range(items.size()):
			mm.set_instance_transform(i, items[i][0])
			mm.set_instance_custom_data(i, items[i][2])
			mm.set_instance_color(i, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = FLOWER_RANGE
		mmi.visibility_range_end_margin = 20.0
		mmi.set_meta("geo_detail", true)
		holder.add_child(mmi)

static func _flower_mesh(kind: String) -> ArrayMesh:
	if _fmesh.has(kind):
		return _fmesh[kind]
	if _fmat == null:
		_fmat = ShaderMaterial.new()
		_fmat.shader = load("res://shaders/flower.gdshader")
		_fmat.set_shader_parameter("leaves", MapTextures.get_tex("foliage"))
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new()
	r.seed = hash(kind)
	var leaf := Color(0.4, 0.6, 0.3, 1.0)
	var stem := Color(0.28, 0.45, 0.2, 0.2)
	var eye := Color(0.98, 0.8, 0.15, 0.2)
	match kind:
		"mound":
			# Bedding plants (begonias, petunias): a leafy cushion dotted
			# with small open flowers.
			_fdome(st, 0.22, 0.16, leaf, r)
			for i in range(14):
				var a: float = i * 2.4 + r.randf_range(-0.2, 0.2) # spread like seeds in a head
				var d: float = 0.2 * sqrt((i + 0.5) / 14.0)
				var y: float = 0.16 * sqrt(maxf(1.0 - (d / 0.22) * (d / 0.22), 0.05)) + 0.03
				var up: Vector3 = Vector3(cos(a) * d / 0.22, 1.1, sin(a) * d / 0.22).normalized()
				var c := Vector3(cos(a) * d, y, sin(a) * d)
				_fstar(st, c, up, r.randf_range(0.05, 0.065), 5, Color(1, 1, 1, 0.4), r, false)
				_fstar(st, c + up * 0.012, up, 0.016, 3, eye, r, false)
		"daisy":
			# Marguerites: white-and-yellow or coloured flowers on stems
			# over a low tuft.
			_fdome(st, 0.18, 0.14, leaf, r)
			for i in range(6):
				var a: float = TAU * i / 6.0 + r.randf_range(-0.4, 0.4)
				var top := Vector3(cos(a) * 0.13, r.randf_range(0.32, 0.5), sin(a) * 0.13)
				_fstem(st, Vector3(cos(a) * 0.03, 0.05, sin(a) * 0.03), top, 0.006, stem)
				var up: Vector3 = Vector3(cos(a) * 0.6, 1.0, sin(a) * 0.6).normalized()
				_fstar(st, top, up, 0.085, 9, Color(1, 1, 1, 0.4), r)
				_fstar(st, top + up * 0.015, up, 0.03, 3, eye, r, false)
		"tulip":
			# Tulips: broad upright leaves, stems, closed cups.
			for i in range(4):
				var a: float = TAU * i / 4.0 + r.randf_range(-0.3, 0.3)
				_fblade(st, Vector3(cos(a) * 0.03, 0.0, sin(a) * 0.03), Vector3(cos(a), 0, sin(a)), 0.05, r.randf_range(0.22, 0.3), leaf)
			for i in range(4):
				var a: float = TAU * i / 4.0 + PI * 0.25 + r.randf_range(-0.3, 0.3)
				var top := Vector3(cos(a) * 0.07, r.randf_range(0.36, 0.46), sin(a) * 0.07)
				_fstem(st, Vector3(cos(a) * 0.02, 0.0, sin(a) * 0.02), top, 0.008, stem)
				_fcup(st, top, 0.04, 0.08, Color(1, 1, 1, 0.4))
		"spike":
			# Lupins: a leafy base, tall spikes of small flowers getting
			# smaller to the tip.
			_fdome(st, 0.2, 0.15, leaf, r)
			for i in range(2):
				var a: float = PI * i + r.randf_range(-0.4, 0.4)
				var b := Vector3(cos(a) * 0.07, 0.1, sin(a) * 0.07)
				var hgt: float = r.randf_range(0.45, 0.6)
				_fstem(st, b, b + Vector3(0, hgt + 0.08, 0), 0.006, stem)
				# Rings of florets facing out all round, smaller to the tip.
				for k in range(7):
					var f: float = k / 6.0
					var tint: float = lerpf(0.82, 1.05, f) # the lower ones a shade darker
					var y: float = 0.16 + f * hgt * 0.85
					var rad: float = lerpf(0.045, 0.02, f)
					for j in range(3):
						var aj: float = TAU * j / 3.0 + k * 1.1
						var out := Vector3(cos(aj), 0.7, sin(aj)).normalized()
						_fstar(st, b + Vector3(cos(aj) * rad * 0.6, y, sin(aj) * rad * 0.6), out, rad * 1.15, 4, Color(tint, tint, tint, 0.4), r, false)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, _fmat)
	_fmesh[kind] = mesh
	return mesh

static func _fv(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_color(c)
	st.set_normal(n)
	st.add_vertex(p)

## A leafy cushion: radius r, height h, slightly uneven, darker low down.
static func _fdome(st: SurfaceTool, r: float, h: float, col: Color, rng: RandomNumberGenerator) -> void:
	var seg: int = 8
	var rings: Array = [[0.0, 1.0, 0.6], [0.55, 0.82, 0.85], [0.9, 0.42, 1.0]] # [height, radius, shade]
	var pts: Array = []
	for ring: Array in rings:
		var row: Array = []
		for i in range(seg):
			var a: float = TAU * i / seg
			var rr: float = r * ring[1] * rng.randf_range(0.88, 1.1)
			row.append(Vector3(cos(a) * rr, h * ring[0], sin(a) * rr))
		pts.append(row)
	var top := Vector3(0, h, 0)
	for j in range(rings.size() - 1):
		for i in range(seg):
			var i1: int = (i + 1) % seg
			var q: Array = [pts[j][i], pts[j][i1], pts[j + 1][i1], pts[j + 1][i]]
			var sh: Array = [rings[j][2], rings[j][2], rings[j + 1][2], rings[j + 1][2]]
			for t in [[0, 1, 2], [0, 2, 3]]:
				for k: int in t:
					var p: Vector3 = q[k]
					_fv(st, p, Vector3(p.x / r, (p.y / h) * 0.8 + 0.3, p.z / r).normalized(), Color(col.r * sh[k], col.g * sh[k], col.b * sh[k], 1.0))
	for i in range(seg):
		var a: Vector3 = pts[-1][i]
		var b: Vector3 = pts[-1][(i + 1) % seg]
		for p: Vector3 in [a, b, top]:
			_fv(st, p, Vector3(p.x / r, 1.0, p.z / r).normalized(), col)

## An open flower facing `up`: n petals round a centre, each a kite (two
## triangles) or, for the small ones, a single pointed triangle.
static func _fstar(st: SurfaceTool, c: Vector3, up: Vector3, r: float, n: int, col: Color, rng: RandomNumberGenerator, kite: bool = true) -> void:
	var t1: Vector3 = up.cross(Vector3.RIGHT if absf(up.x) < 0.9 else Vector3.FORWARD).normalized()
	var t2: Vector3 = up.cross(t1)
	var a0: float = rng.randf() * TAU
	var w: float = PI / n
	for i in range(n):
		var a: float = a0 + TAU * i / n
		var tip: Vector3 = c + (t1 * cos(a) + t2 * sin(a)) * r + up * r * 0.4
		var l: Vector3 = c + (t1 * cos(a - w) + t2 * sin(a - w)) * r * 0.45 + up * r * 0.1
		var rr: Vector3 = c + (t1 * cos(a + w) + t2 * sin(a + w)) * r * 0.45 + up * r * 0.1
		for p: Vector3 in ([c, l, tip, c, tip, rr] if kite else [l, tip, rr]):
			_fv(st, p, up, col)

## A thin stem: two crossed strips from a to b.
static func _fstem(st: SurfaceTool, a: Vector3, b: Vector3, w: float, col: Color) -> void:
	for side: Vector3 in [Vector3(w, 0, 0), Vector3(0, 0, w)]:
		var n: Vector3 = side.cross(b - a).normalized()
		for p: Vector3 in [a - side, a + side, b + side, a - side, b + side, b - side]:
			_fv(st, p, n, col)

## A strap leaf from its foot, leaning out along `out`.
static func _fblade(st: SurfaceTool, foot: Vector3, out: Vector3, w: float, h: float, col: Color) -> void:
	var side: Vector3 = out.cross(Vector3.UP).normalized() * w
	var mid: Vector3 = foot + out * h * 0.15 + Vector3(0, h * 0.55, 0)
	var tip: Vector3 = foot + out * h * 0.4 + Vector3(0, h, 0)
	var n: Vector3 = out
	var dark := Color(col.r * 0.7, col.g * 0.7, col.b * 0.7, col.a)
	for tri: Array in [[foot - side * 0.6, foot + side * 0.6, mid + side], [foot - side * 0.6, mid + side, mid - side], [mid - side, mid + side, tip]]:
		for k in range(3):
			_fv(st, tri[k], n, dark if (tri[k] as Vector3).y < h * 0.3 else col)

## A closed cup (a tulip): petals standing round the top of its stem.
static func _fcup(st: SurfaceTool, base: Vector3, r: float, h: float, col: Color) -> void:
	var seg: int = 6
	for i in range(seg):
		var a0: float = TAU * i / seg
		var a1: float = TAU * (i + 1) / seg
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var b0: Vector3 = base + d0 * r * 0.5
		var b1: Vector3 = base + d1 * r * 0.5
		var t0: Vector3 = base + d0 * r + Vector3(0, h, 0)
		var t1: Vector3 = base + d1 * r + Vector3(0, h, 0)
		var tm: Vector3 = base + (d0 + d1).normalized() * r * 1.05 + Vector3(0, h * 1.12, 0) # pointed petal tips
		var n: Vector3 = (d0 + d1).normalized()
		var low := Color(col.r * 0.85, col.g * 0.85, col.b * 0.85, col.a)
		for p: Vector3 in [b0, b1, t1, b0, t1, t0]:
			_fv(st, p, n, low if p.y < base.y + h * 0.5 else col)
		for p: Vector3 in [t0, t1, tm]:
			_fv(st, p, n, col)
	for i in range(seg): # its bottom
		var a0: float = TAU * i / seg
		var a1: float = TAU * (i + 1) / seg
		for p: Vector3 in [base, base + Vector3(cos(a0), 0, sin(a0)) * r * 0.5, base + Vector3(cos(a1), 0, sin(a1)) * r * 0.5]:
			_fv(st, p, Vector3.DOWN, col)

func _bench(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	geo.tint = Color(0.62, 0.45, 0.3)
	_box(c + Vector3(0, 0.45, 0), Vector3(1.6, 0.06, 0.45), "gd_wood")
	_box(c + Vector3(0, 0.75, -0.22), Vector3(1.6, 0.4, 0.05), "gd_wood")
	geo.tint = Color(0.2, 0.2, 0.22)
	for sx in [-0.7, 0.7]:
		_box(c + Vector3(sx, 0.22, 0), Vector3(0.06, 0.44, 0.45), "gd_paint")
	geo.tint = Color.WHITE

func _bird_bath(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	geo.tint = Color(0.85, 0.83, 0.78)
	geo.cylinder(f * _foot(c, 0.09), f * (c + Vector3(0, 0.75, 0)), 0.09, "gd_stone", 8)
	geo.cylinder(f * (c + Vector3(0, 0.75, 0)), f * (c + Vector3(0, 0.85, 0)), 0.4, "gd_stone", 14)
	geo.tint = Color(0.55, 0.75, 0.85)
	geo.cylinder(f * (c + Vector3(0, 0.85, 0)), f * (c + Vector3(0, 0.86, 0)), 0.34, "gd_paint", 14, false)
	geo.tint = Color.WHITE

## A little garden pond: water ringed with stones.
func _garden_pond(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	if not geo.has_material("gd_water"):
		geo.add_material("gd_water", Geo.water_mat(Color(0.15, 0.3, 0.3), 0.85))
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	geo.cylinder(f * (c + Vector3(0, 0.0, 0)), f * (c + Vector3(0, 0.06, 0)), 1.1, "gd_water", 20, false)
	geo.tint = Color(0.75, 0.72, 0.68)
	for k in range(14):
		var a: float = TAU * k / 14.0
		var p: Vector3 = c + Vector3(cos(a) * 1.25, 0.08, sin(a) * 1.0)
		_box(p, Vector3(0.35, 0.16, 0.28) * rng.randf_range(0.8, 1.2), "gd_stone", false, a)
	geo.tint = Color(0.3, 0.6, 0.25)
	geo.cylinder(f * (c + Vector3(0.3, 0.07, 0.2)), f * (c + Vector3(0.3, 0.075, 0.2)), 0.18, "gd_paint", 8, false)
	geo.tint = Color.WHITE

## Stepping stones across the lawn from a to b (plot frame).
func _stepping_stones(a: Vector3, b: Vector3) -> void:
	var n: int = int(a.distance_to(b) / 0.8)
	geo.tint = Color(0.8, 0.78, 0.74)
	for k in range(n):
		var p: Vector3 = a.lerp(b, (k + 0.5) / n)
		_box(p + Vector3(rng.randf_range(-0.1, 0.1), 0.02, 0), Vector3(0.5, 0.05, 0.4), "gd_stone", false, rng.randf_range(-0.3, 0.3))
	geo.tint = Color.WHITE

func _world(p: Vector3) -> Vector3:
	return f * p

## Pieces standing on the plot reach down into the real ground under
## them (Geo.box_on) - at the plot's edges the land may already fall
## away towards the road or the neighbour.
func _box(c: Vector3, s: Vector3, mat: String, collide: bool = true, yaw: float = 0.0) -> void:
	geo.box_on(f * Transform3D(Basis(Vector3.UP, yaw), c), s, mat, f.origin.y, collide)

## p (plot frame, on the plot level) lowered to reach into the real
## ground there - the foot of a cylinder or cone.
func _foot(p: Vector3, r: float = 0.0) -> Vector3:
	var w: Vector3 = f * p
	var pts: Array = [w]
	if r > 0.0:
		pts.append_array([w + Vector3(r, 0, 0), w - Vector3(r, 0, 0), w + Vector3(0, 0, r), w - Vector3(0, 0, r)])
	return Vector3(p.x, p.y - (w.y - geo.sunk(pts, w.y)), p.z)

## A free spot of `size` in the yard (plot frame), or the yard's middle.
func _spot(yard: Rect2, size: Vector2, used: Array) -> Rect2:
	for _try in range(12):
		var x: float = rng.randf_range(yard.position.x, maxf(yard.end.x - size.x, yard.position.x))
		var z: float = rng.randf_range(yard.position.y, maxf(yard.end.y - size.y, yard.position.y))
		var r := Rect2(x, z, size.x, size.y)
		var free: bool = yard.encloses(r)
		for u: Rect2 in used:
			if u.grow(0.8).intersects(r):
				free = false
		if free:
			used.append(r)
			return r
	return Rect2()

## One side of the plot from a to b (plot frame, on the ground), in a
## style, leaving the gaps (x centre, half width) open - for the street side.
func _edge(a: Vector3, b: Vector3, style: String, gaps: Array) -> void:
	var L: float = a.distance_to(b)
	var dir: Vector3 = (b - a) / L
	# Runs between the gaps (gaps are given as x on the street edge).
	var runs: Array = [[0.0, L]]
	for gp: Array in gaps:
		var g0: float = gp[0] - gp[1] - a.x
		var g1: float = gp[0] + gp[1] - a.x
		var next: Array = []
		for r: Array in runs:
			if g1 <= r[0] or g0 >= r[1]:
				next.append(r)
			else:
				if g0 > r[0]:
					next.append([r[0], g0])
				if g1 < r[1]:
					next.append([g1, r[1]])
		runs = next
	var yaw: float = atan2(dir.x, dir.z)
	for r: Array in runs:
		var len: float = r[1] - r[0]
		if len < 0.4:
			continue
		var p0: Vector3 = a + dir * r[0]
		var mid: Vector3 = a + dir * ((r[0] + r[1]) * 0.5)
		match style:
			"hedge":
				_hedge(p0, dir, len)
			"wall":
				geo.tint = Color.WHITE
				_box(mid + Vector3(0, fence_h * 0.5 - 0.03, 0), Vector3(0.3, fence_h - 0.06, len), "gd_stone", true, yaw)
				_box(mid + Vector3(0, fence_h - 0.02, 0), Vector3(0.38, 0.06, len + 0.08), "gd_stone", false, yaw)
			"rails":
				geo.tint = Color(0.75, 0.62, 0.48)
				_posts(p0, dir, len, 1.25, 2.4, "gd_wood")
				for y in [0.45, 0.95]:
					_box(mid + Vector3(0, y, 0), Vector3(0.05, 0.1, len), "gd_wood", true, yaw)
				geo.tint = Color.WHITE
			"picket_white", "picket_wood":
				var white: bool = style == "picket_white"
				var tall: float = fence_h
				geo.tint = Color(0.95, 0.95, 0.93) if white else Color(0.8, 0.66, 0.5)
				var mat: String = "gd_paint" if white else "gd_wood"
				_posts(p0, dir, len, tall + 0.1, 2.4, mat)
				for y in [0.25, tall - 0.2]:
					_box(mid + Vector3(0, y, 0), Vector3(0.03, 0.07, len), mat, true, yaw)
				var k: float = 0.15
				while k < len - 0.1:
					var c: Vector3 = p0 + dir * k
					_box(c + Vector3(0, tall * 0.5, 0), Vector3(0.025, tall, 0.08), mat, false, yaw)
					k += 0.24
				geo.tint = Color.WHITE

## A trimmed hedge: a rounded body (wider at the bottom, a soft crown),
## in sections of about three metres that vary a little in height and
## width and shade - the way a clipped hedge actually looks - each a
## capped prism, so its ends are closed at the gate.
func _hedge(p0: Vector3, dir: Vector3, len: float) -> void:
	var n: int = maxi(1, int(round(len / 3.0)))
	var seg: float = len / n
	var a: float = atan2(-dir.z, dir.x) # local x along the run
	for k in range(n):
		var h: float = fence_h * rng.randf_range(0.95, 1.04)
		var w: float = rng.randf_range(0.36, 0.42)
		var prof: Array = [Vector2(w * 0.85, 0.0), Vector2(w, h * 0.35), Vector2(w * 0.95, h * 0.72),
			Vector2(w * 0.7, h * 0.93), Vector2(w * 0.3, h), Vector2(-w * 0.3, h), Vector2(-w * 0.7, h * 0.93),
			Vector2(-w * 0.95, h * 0.72), Vector2(-w, h * 0.35), Vector2(-w * 0.85, 0.0)]
		var c: Vector3 = p0 + dir * (seg * (k + 0.5))
		# Its foot follows the real ground under the section (both ends,
		# both faces, the middle).
		var side := Vector3(-dir.z, 0, dir.x) * w
		var ends: Array = []
		for e in [-0.5, 0.0, 0.5]:
			for sd in [-1.0, 1.0]:
				ends.append(f * (c + dir * seg * e + side * sd))
		var foot: float = geo.sunk(ends, (f * c).y) - (f * c).y
		if foot < 0.0:
			prof[0].y = foot
			prof[-1].y = foot
		geo.tint = Color(rng.randf_range(0.92, 1.0), 1.0, rng.randf_range(0.9, 1.0)) * rng.randf_range(0.9, 1.06)
		geo.prism(f * Transform3D(Basis(Vector3.UP, a), c), prof, seg + 0.06, "gd_hedge")
	geo.tint = Color.WHITE

func _posts(p0: Vector3, dir: Vector3, len: float, h: float, every: float, mat: String) -> void:
	var n: int = maxi(1, int(ceil(len / every)))
	for k in range(n + 1):
		var c: Vector3 = p0 + dir * (len * k / n)
		_box(c + Vector3(0, h * 0.5, 0), Vector3(0.1, h, 0.1), mat)

func _shed(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	var col: Color = [Color(0.55, 0.38, 0.25), Color(0.35, 0.45, 0.35), Color(0.75, 0.25, 0.2)][rng.randi() % 3]
	geo.tint = col
	_box(c + Vector3(0, 1.0, 0), Vector3(r.size.x - 0.2, 2.0, r.size.y - 0.2), "gd_wood")
	geo.tint = Color(0.3, 0.3, 0.32)
	for s in [-1.0, 1.0]:
		geo.box_xf(f * Transform3D(Basis(Vector3.FORWARD, s * 0.45), c + Vector3(s * r.size.x * 0.26, 2.25, 0)), Vector3(r.size.x * 0.58, 0.06, r.size.y + 0.1), "gd_paint")
	geo.tint = col.darkened(0.3)
	_box(c + Vector3(0, 0.95, r.size.y * 0.5 - 0.09), Vector3(0.8, 1.8, 0.04), "gd_wood", false)
	geo.tint = Color.WHITE

func _washing_line(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	var a := Vector3(r.position.x, 0, r.get_center().y)
	var b := Vector3(r.end.x, 0, r.get_center().y)
	geo.tint = Color(0.6, 0.6, 0.62)
	for p: Vector3 in [a, b]:
		_box(p + Vector3(0, 0.9, 0), Vector3(0.06, 1.8, 0.06), "gd_paint")
		_box(p + Vector3(0, 1.78, 0), Vector3(0.05, 0.05, 0.9), "gd_paint")
	geo.tint = Color(0.9, 0.9, 0.9)
	for z in [-0.35, 0.35]:
		geo.beam(f * (a + Vector3(0, 1.76, z)), f * (b + Vector3(0, 1.76, z)), Vector2(0.01, 0.01), "gd_paint", false)
	# Laundry: shirts and towels in bright colours.
	var cols: Array = [Color(0.9, 0.2, 0.2), Color(0.2, 0.4, 0.85), Color(0.95, 0.95, 0.9), Color(0.95, 0.8, 0.2), Color(0.3, 0.7, 0.4)]
	var x: float = a.x + 0.4
	while x < b.x - 0.5:
		var w: float = rng.randf_range(0.4, 0.8)
		geo.tint = cols[rng.randi() % cols.size()]
		var z: float = -0.35 if rng.randf() < 0.5 else 0.35
		_box(Vector3(x + w * 0.5, 1.45, a.z + z), Vector3(w, rng.randf_range(0.4, 0.65), 0.02), "gd_paint", false)
		x += w + rng.randf_range(0.1, 0.4)
	geo.tint = Color.WHITE

func _veg_beds(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	for k in range(2):
		var c := Vector3(r.position.x + 0.7 + k * 1.7, 0, r.get_center().y)
		geo.tint = Color(0.75, 0.6, 0.45)
		_box(c + Vector3(0, 0.2, 0), Vector3(1.2, 0.4, r.size.y - 0.2), "gd_wood")
		geo.tint = Color.WHITE
		_box(c + Vector3(0, 0.41, 0), Vector3(1.1, 0.02, r.size.y - 0.3), "gd_soil", false)
		geo.tint = Color(0.35, 0.6, 0.25)
		var z: float = -r.size.y * 0.5 + 0.4
		while z < r.size.y * 0.5 - 0.3:
			for xo in [-0.3, 0.3]:
				var p: Vector3 = c + Vector3(xo, 0.42, z)
				geo.cone(f * p, f * (p + Vector3(0, rng.randf_range(0.15, 0.3), 0)), 0.12, 0.02, "gd_paint", 5, false)
			z += 0.45
	geo.tint = Color.WHITE

func _trampoline(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	geo.tint = Color(0.5, 0.5, 0.55)
	for k in range(6):
		var a: float = TAU * k / 6.0
		var p: Vector3 = c + Vector3(cos(a), 0, sin(a)) * 1.6
		geo.cylinder(f * _foot(p, 0.04), f * (p + Vector3(0, 0.9, 0)), 0.04, "gd_paint", 6)
	geo.tint = Color(0.15, 0.4, 0.8)
	geo.cylinder(f * (c + Vector3(0, 0.82, 0)), f * (c + Vector3(0, 0.92, 0)), 1.75, "gd_paint", 20)
	geo.tint = Color(0.08, 0.08, 0.08)
	geo.cylinder(f * (c + Vector3(0, 0.92, 0)), f * (c + Vector3(0, 0.94, 0)), 1.45, "gd_paint", 20, false)
	geo.tint = Color.WHITE

func _sandpit(r: Rect2) -> void:
	if r.size == Vector2.ZERO:
		return
	var c := Vector3(r.get_center().x, 0, r.get_center().y)
	geo.tint = Color(0.75, 0.6, 0.45)
	for s in [-1.0, 1.0]:
		_box(c + Vector3(s * (r.size.x * 0.5 - 0.1), 0.15, 0), Vector3(0.15, 0.3, r.size.y), "gd_wood")
		_box(c + Vector3(0, 0.15, s * (r.size.y * 0.5 - 0.1)), Vector3(r.size.x, 0.3, 0.15), "gd_wood")
	geo.tint = Color(0.95, 0.85, 0.6)
	_box(c + Vector3(0, 0.2, 0), Vector3(r.size.x - 0.3, 0.06, r.size.y - 0.3), "gd_paint", false)
	geo.tint = Color(0.95, 0.3, 0.2)
	geo.cone(f * (c + Vector3(0.4, 0.23, 0.2)), f * (c + Vector3(0.4, 0.4, 0.2)), 0.12, 0.08, "gd_paint", 8, false)
	geo.tint = Color.WHITE

## A garden gnome (~40 cm): red pointed hat, white beard, blue coat.
func _gnome(p: Vector3, yaw: float) -> void:
	var b := Transform3D(Basis(Vector3.UP, yaw), p)
	geo.tint = Color(0.2, 0.35, 0.75)
	geo.cylinder(f * _foot(b * Vector3(0, 0, 0), 0.09), f * (b * Vector3(0, 0.2, 0)), 0.09, "gd_paint", 8)
	geo.tint = Color(0.95, 0.8, 0.7)
	geo.cylinder(f * (b * Vector3(0, 0.2, 0)), f * (b * Vector3(0, 0.29, 0)), 0.065, "gd_paint", 8, false)
	geo.tint = Color(0.97, 0.97, 0.97)
	geo.cone(f * (b * Vector3(0, 0.12, 0.05)), f * (b * Vector3(0, 0.26, 0.07)), 0.07, 0.02, "gd_paint", 8, false)
	geo.tint = Color(0.85, 0.12, 0.1)
	geo.cone(f * (b * Vector3(0, 0.28, 0)), f * (b * Vector3(0, 0.45, -0.02)), 0.075, 0.005, "gd_paint", 8, false)
	geo.tint = Color.WHITE
