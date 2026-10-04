class_name FieldCreator
extends RefCounted

## Creator: a field - four corners laid out by the map, a crop by name.
## Standing crops (wheat, maize, rapeseed) are a canopy draped over the
## land at the crop's height: rows in its texture, a wall of stalks round
## its edge, the tractor's tramlines across it. It doesn't collide - skim
## it, dip into it. Bare fields (ploughed, stubble, meadow) are a layer on
## the ground; stubble and mown meadows get round bales where the baler
## dropped them, and a stack by the field's first corner. A field can have
## a hedgerow along some of its edges.
##
##   FieldCreator.build(geo, land, corners, crop, rng, opts) -> {"trees": [...], "views": [...]}
## corners: 4 x Vector2 (x, z), in order round the field. The rows run
## along the world axis nearest the first edge (corners 0 -> 1).
## opts: hedges (edge indices 0..3 with a hedgerow), bales (true/false),
## name (for the view).
## Real numbers: wheat ~0.9 m, rapeseed ~1.3 m, maize ~2.5 m; rows
## 0.75 m (maize; drawn so for all - finer rows only shimmer); tramlines
## every 18-24 m, wheel tracks 1.8 m apart; round bales 1.5 m across,
## 1.2 m wide.

const CROPS := {
	"wheat": {"h": 0.95, "tint": Color(1.08, 0.82, 0.32), "tex": "rows", "tram": true},
	"maize": {"h": 2.4, "tint": Color(0.45, 0.62, 0.27), "tex": "rows", "tram": false},
	"rapeseed": {"h": 1.3, "tint": Color(1.05, 0.9, 0.2), "tex": "rows", "tram": true},
	"ploughed": {"h": 0.0, "tint": Color(1.0, 1.0, 1.0), "tex": "furrows", "tram": false},
	"stubble": {"h": 0.0, "tint": Color(0.98, 0.88, 0.62), "tex": "rows", "tram": true},
	"meadow": {"h": 0.0, "tint": Color(0.5, 0.68, 0.3), "tex": "rows", "tile": 16.0, "tram": false}, # mown in 2 m swathes
}
const STEP: float = 6.0 ## sampling (m) of a crop's edge wall
const TRAM_EVERY: float = 20.0

var geo: Geo
var land: TerrainCreator
var rng: RandomNumberGenerator
var c: Array = [] # corners, Vector2
var crop: String
var along_z: bool

static func ensure_materials(g: Geo) -> void:
	if g.has_material("fd_track"):
		return
	g.add_material("fd_track", Geo.ground_flat(Color(0.36, 0.3, 0.2), 2))
	g.add_material("fd_straw", Geo.tex_mat(MapTextures.get_tex("straw"), Color.WHITE, 1.5))
	g.add_material("fd_hay", Geo.tex_mat(MapTextures.get_tex("straw"), Color(0.85, 1.0, 0.62), 1.5))

static func build(g: Geo, t: TerrainCreator, corners: Array, crop_name: String, r: RandomNumberGenerator, opts: Dictionary = {}) -> Dictionary:
	ensure_materials(g)
	var fc := FieldCreator.new()
	fc.geo = g
	fc.land = t
	fc.rng = r
	fc.c = corners
	fc.crop = crop_name
	var d: Vector2 = (corners[1] as Vector2) - (corners[0] as Vector2)
	fc.along_z = absf(d.y) > absf(d.x)
	return fc._build(opts)

## The field as a polygon, for keeping woods and scattered trees out of
## it (TerrainCreator.keep_clear_poly) before the land is built.
static func poly(corners: Array) -> PackedVector2Array:
	return PackedVector2Array(corners)

func _build(opts: Dictionary) -> Dictionary:
	var spec: Dictionary = CROPS[crop]
	var h: float = spec.h
	if h > 0.0:
		_canopy(h)
	else:
		_layer()
	if spec.tram:
		_tramlines(h)
	if opts.get("bales", crop == "stubble" or crop == "meadow"):
		_bales()
	var trees: Array = []
	for e: int in opts.get("hedges", []):
		trees.append_array(_hedgerow(e))
	var mid: Vector2 = _centre()
	var a: Vector2 = c[0]
	var out: Vector2 = (a - mid).normalized()
	var eye := Vector2(a.x, a.y) + out * 25.0
	var views: Array = [["field_" + opts.get("name", crop), Vector3(eye.x, land.ground(eye.x, eye.y) + 9.0, eye.y), Vector3(mid.x, land.ground(mid.x, mid.y) + h, mid.y)]]
	if _stack_at != Vector3.INF:
		var to_mid: Vector3 = (Vector3(mid.x, _stack_at.y, mid.y) - _stack_at).normalized()
		views.append(["bales_" + crop, _stack_at + to_mid * 7.0 + Vector3(0, 2.2, 0) + Vector3(-to_mid.z, 0, to_mid.x) * 3.0, _stack_at + Vector3(0, 1.2, 0)])
	if h > 0.0:
		# From inside the crop, at a whoop's height, and skimming its top.
		var inside: Vector2 = (c[0] as Vector2).lerp(mid, 0.35)
		var gi: float = land.ground(inside.x, inside.y)
		views.append(["in_" + crop, Vector3(inside.x, gi + h * 0.45, inside.y), Vector3(mid.x, land.ground(mid.x, mid.y) + h * 0.5, mid.y)])
		views.append(["skim_" + crop, Vector3(inside.x, gi + h + 0.5, inside.y), Vector3(mid.x, land.ground(mid.x, mid.y) + h + 0.2, mid.y)])
	return {"trees": trees, "views": views}

func _centre() -> Vector2:
	return ((c[0] as Vector2) + c[1] + c[2] + c[3]) * 0.25

## Point (u, v) in 0..1 across the quad (u along edge 0 -> 1).
func _at(u: float, v: float) -> Vector2:
	var a: Vector2 = (c[0] as Vector2).lerp(c[1], u)
	var b: Vector2 = (c[3] as Vector2).lerp(c[2], u)
	return a.lerp(b, v)

func _mat(tex_dir_z: bool) -> String:
	var spec: Dictionary = CROPS[crop]
	var tex_name: String = spec.tex
	var key: String = "fd_%s_%s" % [crop, "z" if tex_dir_z else "x"]
	if not geo.has_material(key):
		var tex: Texture2D = MapTextures.get_tex(tex_name + ("_z" if tex_dir_z else "_x"))
		geo.add_material(key, Geo.ground_mat(tex, spec.tint, spec.get("tile", 6.0), 1, 0.45))
	return key

## The terrain inside polygon `area`, on the terrain's own triangles
## (cut at the polygon's edge), lifted by `lift`: it lies exactly
## parallel to the ground - a surface sampled on a grid of its own cut
## into the land wherever the land curved between its points.
func _drape(area: PackedVector2Array, lift: float, mat: String) -> PackedVector3Array:
	var r: Rect2 = land._rect
	var st: float = land._step
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q: Vector2 in area:
		mn = mn.min(q)
		mx = mx.max(q)
	var ix0: int = maxi(0, floori((mn.x - r.position.x) / st))
	var ix1: int = mini(land._nx - 2, floori((mx.x - r.position.x) / st))
	var iz0: int = maxi(0, floori((mn.y - r.position.y) / st))
	var iz1: int = mini(land._nz - 2, floori((mx.y - r.position.y) / st))
	var out := PackedVector3Array()
	for iz in range(iz0, iz1 + 1):
		for ix in range(ix0, ix1 + 1):
			var x0: float = r.position.x + ix * st
			var z0: float = r.position.y + iz * st
			var p00 := Vector3(x0, land.ground(x0, z0) + lift, z0)
			var p10 := Vector3(x0 + st, land.ground(x0 + st, z0) + lift, z0)
			var p01 := Vector3(x0, land.ground(x0, z0 + st) + lift, z0 + st)
			var p11 := Vector3(x0 + st, land.ground(x0 + st, z0 + st) + lift, z0 + st)
			# (The terrain splits each cell along the 10-01 diagonal.)
			for tri: Array in [[p00, p10, p01], [p10, p11, p01]]:
				var t2 := PackedVector2Array([Vector2(tri[0].x, tri[0].z), Vector2(tri[1].x, tri[1].z), Vector2(tri[2].x, tri[2].z)])
				if Geometry2D.is_point_in_polygon(t2[0], area) and Geometry2D.is_point_in_polygon(t2[1], area) and Geometry2D.is_point_in_polygon(t2[2], area):
					out.append_array(PackedVector3Array(tri)) # (fields are convex: all corners in = all in)
					continue
				for cp: PackedVector2Array in Geometry2D.intersect_polygons(t2, area):
					var idx: PackedInt32Array = Geometry2D.triangulate_polygon(cp)
					for k: int in idx:
						var q: Vector2 = cp[k]
						out.append(Vector3(q.x, _plane_y(tri, q), q.y))
	geo.tris(out, mat)
	return out

## Height at q (x, z) on the plane through triangle tri.
static func _plane_y(tri: Array, q: Vector2) -> float:
	var a: Vector3 = tri[0]
	var b: Vector3 = tri[1]
	var c: Vector3 = tri[2]
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(q.x - a.x, q.y - a.z)
	var den: float = v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-9:
		return a.y
	var u: float = (v2.x * v1.y - v1.x * v2.y) / den
	var v: float = (v0.x * v2.y - v2.x * v0.y) / den
	return a.y + (b.y - a.y) * u + (c.y - a.y) * v

## A standing crop: its top over the land, and a wall of stalks round it.
## Inside (fly into it - it doesn't collide) the top has a shaded
## underside and rows of stalks stand under it (_stalks).
func _canopy(h: float) -> void:
	var roof: PackedVector3Array = _drape(PackedVector2Array(c), h, _mat(along_z))
	var under: String = "fd_%s_under" % crop
	if not geo.has_material(under):
		var spec: Dictionary = CROPS[crop]
		geo.add_material(under, Geo.ground_mat(MapTextures.get_tex("rows_z" if along_z else "rows_x"), (spec.tint as Color) * 0.6, 6.0, 1, 0.0))
	for i in range(roof.size()): # the same triangles, 4 cm lower, facing down
		roof[i].y -= 0.04
	geo.tris(roof, under, false, true)
	_stalks(h)
	# The edge: from just under the ground up to a hair over the top (the
	# top's edge bends with the land's triangles; the wall is sampled).
	var mid: Vector2 = _centre()
	var centre := Vector3(mid.x, land.ground(mid.x, mid.y) + h * 0.5, mid.y)
	var side_mat: String = _mat(true) # stalks stand upright on every side (see MapTextures._rows)
	for e in range(4):
		var a: Vector2 = c[e]
		var b: Vector2 = c[(e + 1) % 4]
		var n: int = maxi(1, ceili(a.distance_to(b) / STEP))
		var top := PackedVector3Array()
		var bottom := PackedVector3Array()
		for i in range(n + 1):
			var q: Vector2 = a.lerp(b, float(i) / n)
			var g: float = land.ground(q.x, q.y)
			top.append(Vector3(q.x, g + h + 0.04, q.y))
			bottom.append(Vector3(q.x, g - 0.15, q.y))
		geo.strip([bottom, top], side_mat, false, [Vector3(centre.x, (bottom[0].y + top[0].y) * 0.5, centre.z)])

# --- stalks inside a standing crop ---------------------------------------------------
# One 4 x 4 m patch of stalk rows per crop (rows 0.5 m apart, from below
# the ground to just under the top), placed on a 4 m grid across the field
# as MultiMesh, tilted with the land - a few thousand copies, one draw
# call a field, no build time.

const PATCH: float = 4.0
const STALK_RANGE: float = 140.0
static var _stalk_meshes: Dictionary = {}

func _stalks(h: float) -> void:
	var shrunk: Array = Geometry2D.offset_polygon(PackedVector2Array(c), -PATCH * 0.6)
	if shrunk.is_empty():
		return
	var inner: PackedVector2Array = shrunk[0]
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q: Vector2 in inner:
		mn = mn.min(q)
		mx = mx.max(q)
	var xfs: Array = []
	var yaw: float = 0.0 if along_z else PI * 0.5 # the patch's rows run along its z
	var x: float = snappedf(mn.x, PATCH)
	while x <= mx.x:
		var z: float = snappedf(mn.y, PATCH)
		while z <= mx.y:
			var q := Vector2(x, z)
			if Geometry2D.is_point_in_polygon(q, inner):
				var g: float = land.ground(q.x, q.y)
				var n := Vector3(land.ground(q.x - 2.0, q.y) - land.ground(q.x + 2.0, q.y), 4.0, land.ground(q.x, q.y - 2.0) - land.ground(q.x, q.y + 2.0)).normalized()
				xfs.append(Transform3D(Basis(Quaternion(Vector3.UP, n)) * Basis(Vector3.UP, yaw), Vector3(q.x, g, q.y)))
			z += PATCH
		x += PATCH
	if xfs.is_empty():
		return
	var mesh: ArrayMesh = _stalk_mesh(crop, h)
	geo.on_commit.append(func(holder: Node3D) -> void:
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true # (else the compatibility renderer multiplies in black)
		mm.mesh = mesh
		mm.instance_count = xfs.size()
		for i in range(xfs.size()):
			mm.set_instance_transform(i, xfs[i])
			mm.set_instance_color(i, Color.WHITE)
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = STALK_RANGE
		mmi.set_meta("geo_detail", true)
		holder.add_child(mmi))

## The patch: rows along local z, double-sided, darker toward the ground
## (the light doesn't get down there), top 12 cm under the crop's top.
static func _stalk_mesh(crop_name: String, h: float) -> ArrayMesh:
	if _stalk_meshes.has(crop_name):
		return _stalk_meshes[crop_name]
	var tint: Color = CROPS[crop_name].tint
	var mat: StandardMaterial3D = Geo.tex_mat(MapTextures.get_tex("stalks"), Color.WHITE, 1.0)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR # see between the stalks
	mat.alpha_scissor_threshold = 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var top: float = h - 0.12
	var lo := Color(tint.r * 0.35, tint.g * 0.42, tint.b * 0.25)
	var hi := Color(tint.r * 0.9, tint.g * 0.9, tint.b * 0.8)
	var half: float = PATCH * 0.5
	for k in range(int(PATCH / 0.5)):
		var x: float = -half + 0.25 + k * 0.5
		var q: Array = [Vector3(x, -0.5, -half), Vector3(x, -0.5, half), Vector3(x, top, half), Vector3(x, top, -half)]
		var cols: Array = [lo, lo, hi, hi]
		for i: int in [0, 1, 2, 0, 2, 3]:
			st.set_color(cols[i])
			st.set_normal(Vector3.RIGHT)
			st.add_vertex(q[i])
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, mat)
	_stalk_meshes[crop_name] = mesh
	return mesh

## A bare field: a layer on the ground (furrows, stubble, mown grass).
func _layer() -> void:
	_drape(PackedVector2Array(c), 0.03, _mat(along_z))

## Tramlines: pairs of wheel tracks along the rows, every ~20 m.
func _tramlines(h: float) -> void:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for q: Vector2 in c:
		mn = mn.min(q)
		mx = mx.max(q)
	var poly := PackedVector2Array(c)
	var span: float = (mx.x - mn.x) if along_z else (mx.y - mn.y)
	var k: float = TRAM_EVERY * 0.5 + rng.randf_range(0.0, 4.0)
	while k < span - 4.0:
		for s in [-0.9, 0.9]:
			var a: Vector2
			var b: Vector2
			if along_z:
				a = Vector2(mn.x + k + s, mn.y - 1.0)
				b = Vector2(mn.x + k + s, mx.y + 1.0)
			else:
				a = Vector2(mn.x - 1.0, mn.y + k + s)
				b = Vector2(mx.x + 1.0, mn.y + k + s)
			for seg: PackedVector2Array in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array([a, b]), poly):
				_track(seg[0], seg[seg.size() - 1], h)
		k += TRAM_EVERY
	return

func _track(a: Vector2, b: Vector2, h: float) -> void:
	var dir: Vector2 = (b - a).normalized()
	var side: Vector2 = Vector2(-dir.y, dir.x) * 0.22
	_drape(PackedVector2Array([a - side, b - side, b + side, a + side]), h + 0.03, "fd_track")

## Round bales where the baler dropped them (in loose lines along the
## rows), and a stack of six by the first corner.
func _bales() -> void:
	var wrapped: bool = crop == "meadow" # hay off the meadow: greener than straw
	var line_every: float = rng.randf_range(18.0, 26.0)
	var v: float = line_every / maxf((c[0] as Vector2).distance_to(c[3]), 1.0) * 0.5
	while v < 0.95:
		var u: float = rng.randf_range(0.04, 0.12)
		while u < 0.95:
			if rng.randf() < 0.75:
				var q: Vector2 = _at(u, v + rng.randf_range(-0.01, 0.01))
				_bale(q, rng.randf() * TAU, wrapped)
			u += rng.randf_range(0.08, 0.16)
		v += line_every / maxf((c[0] as Vector2).distance_to(c[3]), 1.0)
	# The stack, lying side by side, 3 - 2 - 1.
	var mid: Vector2 = _centre()
	var s0: Vector2 = (c[0] as Vector2).lerp(mid, 0.12)
	var ax: Vector2 = ((c[1] as Vector2) - (c[0] as Vector2)).normalized()
	var yaw: float = atan2(ax.x, ax.y)
	var base: float = INF
	for k in range(3):
		var q: Vector2 = s0 + ax * (k - 1) * 1.55
		base = minf(base, _foot(q, 1.0))
	_stack_at = Vector3(s0.x, base, s0.y)
	for row in range(3):
		for k in range(3 - row):
			var q: Vector2 = s0 + ax * ((k - (2 - row) * 0.5) * 1.55)
			_bale_at(Vector3(q.x, base + 0.75 + row * 1.3, q.y), yaw + PI * 0.5, wrapped and row == 0)

var _stack_at := Vector3.INF

## Lowest ground under a round thing of radius r at q.
func _foot(q: Vector2, r: float) -> float:
	var lo: float = INF
	for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r), Vector2(r, r) * 0.71, Vector2(-r, r) * 0.71, Vector2(r, -r) * 0.71, Vector2(-r, -r) * 0.71]:
		lo = minf(lo, land.ground(q.x + o.x, q.y + o.y))
	return lo

func _bale(q: Vector2, yaw: float, wrapped: bool) -> void:
	if geo.on_lane(q, 1.0):
		return
	_bale_at(Vector3(q.x, _foot(q, 1.0) + 0.72, q.y), yaw, wrapped)

## A round bale lying on its side, its axis turned by yaw: straw (golden)
## or hay (yellow-green), the rolled layers showing as rings on its ends.
func _bale_at(p: Vector3, yaw: float, hay: bool) -> void:
	var ax := Vector3(cos(yaw), 0, -sin(yaw)) * 0.6
	var mat: String = "fd_hay" if hay else "fd_straw"
	var shade: float = rng.randf_range(0.92, 1.06)
	geo.tint = Color(shade, shade, shade)
	geo.cylinder(p - ax, p + ax, 0.75, mat, 16)
	var out: Vector3 = ax.normalized()
	for s in [-1.0, 1.0]:
		var e: Vector3 = p + ax * s
		for ring: Array in [[0.58, 0.78], [0.3, 0.85]]:
			geo.tint = Color(shade, shade, shade) * float(ring[1])
			geo.cylinder(e, e + out * s * 0.015 * (1.0 + ring[0]), ring[0], mat, 10, false, true, false)
	geo.tint = Color.WHITE

## A hedgerow along edge e (corner e to e + 1), just outside it: bushes
## close together, now and then a tree - TreeCreator entries.
func _hedgerow(e: int) -> Array:
	var a: Vector2 = c[e]
	var b: Vector2 = c[(e + 1) % 4]
	var out: Vector2 = Vector2(-(b - a).y, (b - a).x).normalized()
	if out.dot(a - _centre()) < 0.0:
		out = -out
	var trees: Array = []
	var L: float = a.distance_to(b)
	var d: float = 2.0
	while d < L - 2.0:
		var q: Vector2 = a.lerp(b, d / L) + out * rng.randf_range(1.6, 2.6)
		if not geo.on_lane(q, 2.0) and not land.on_line(q.x, q.y, 2.0):
			var tree: bool = rng.randf() < 0.07
			trees.append([Vector3(q.x, land.ground(q.x, q.y) - 0.05, q.y), ["maple", "apple", "birch"][rng.randi() % 3] if tree else "bush", rng.randi(), "none"])
		d += rng.randf_range(2.6, 3.6)
	return trees
