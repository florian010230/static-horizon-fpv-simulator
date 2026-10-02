class_name Geo
extends RefCounted

## Batched geometry builder for the generated maps. Every primitive
## (box, cylinder, hollow tube, lathe) is written straight into a shared
## SurfaceTool per (material, 64 m cell) - so a map of thousands of
## pieces is a few dozen draw calls, and the cells still frustum-cull.
## Collidable triangles go into one ConcavePolygonShape3D per cell
## (backface collision on, so hollow things - pipes, cooling towers,
## halls - really are hollow). Sun shadows come from WorldShading's
## shadow map, rendered from these meshes once per map.
##
## Lighting is baked into the vertex colors and every material is
## unshaded: the engine's DirectionalLight3D has no effect at all on the
## dev machine (Intel Iris 6100, macOS, Compatibility renderer - measured:
## identical pixels at sun energy 0 and 3, in every map), a known class
## of Intel/macOS OpenGL driver bugs (godotengine/godot#74763). Baking
## looks the same on every GPU and costs nothing per frame. Per vertex:
##   ambient + sky fill (faces pointing up) + sun * max(N.L, 0)
## times a cheap ambient occlusion: surfaces darken toward the ground
## (`ao_ground_y`) over `ao_height` metres - the grounded look real
## contact shadows give. BuiltMap copies the sun direction and the
## map's ambient into these fields.
##
## Winding: Godot treats clockwise triangles as front faces; _tri()
## orders every triangle from its intended normal, so callers never
## think about it.

const CELL: float = 64.0
## Batch cell size for what is built next (64 m default; far filler
## content uses bigger cells - fewer draw calls where nothing is near).
var cell: float = CELL
## Materials of small details (markings, lamps, rails, vehicles...):
## their batches stop drawing past DETAIL_RANGE - sub-pixel out there,
## and thousands of draw calls saved.
var detail_prefixes: Array[String] = ["rd_line", "rd_steel", "rd_lamp", "rd_kerb", "rd_barrier", "veh_", "train_", "rw_rail", "rw_steel", "rw_black", "rw_yellow", "rw_red", "rw_green", "rw_white", "rw_mast", "groove", "cty_metal", "cty_cornice", "boat_", "site_", "yard_"]
const DETAIL_RANGE: float = 450.0
## Long, cheap surfaces (roads, pavements, track beds, far ground) and
## small details batch in 256 m cells: a road running 2 km out of the
## map is then 8 draw calls, not 30.
var coarse_prefixes: Array[String] = ["rd_", "far_", "rw_", "groove", "cty_far", "prop_road"]
const COARSE_CELL: float = 256.0
var _mat_cell: Dictionary = {}

var ao_ground_y: float = 0.0
var ao_height: float = 3.0
var ao_min: float = 0.55
var sun_dir: Vector3 = Vector3(0.4, -0.75, -0.5).normalized() ## direction the light travels
var sun: float = 0.5
var sky: float = 0.14
var ambient: float = 0.42
var sun_tint: Color = Color(1.0, 0.97, 0.9)
## Multiplies the baked vertex colour of everything drawn next: colour
## variants of one material (house paints, roof tiles) without a
## material - and a draw call - per variant.
var tint: Color = Color.WHITE

var _mats: Dictionary = {}
var _batches: Dictionary = {} # "mat|cx|cz" -> SurfaceTool
var _batch_mat: Dictionary = {}
var _col: Dictionary = {} # "cx|cz" -> Array of Vector3 (a plain Array:
# appending to a PackedVector3Array held in a Dictionary copies it every time)
var _cell_key: String = ""
var _cell_col: Array = []

# --- materials ---------------------------------------------------------------

func add_material(mat_name: String, mat: Material) -> void:
	if mat.resource_name == "":
		mat.resource_name = mat_name
	_mats[mat_name] = mat

func has_material(mat_name: String) -> bool:
	return _mats.has(mat_name)

## World-projected (triplanar) texture: no UVs needed on any primitive,
## the texture stays the same real-world size on every face.
static func tex_mat(tex: Texture2D, tint: Color = Color.WHITE, metres_per_tile: float = 4.0, roughness: float = 0.9, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / metres_per_tile
	m.roughness = roughness
	m.metallic = metallic
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

## Texture mapped by the primitive's own UVs (Geo.sweep with uv_tile):
## sleepers that follow a curved track, lane markings along a road.
static func uv_mat(tex: Texture2D, tint: Color = Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = tint
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

static func flat_mat(color: Color, roughness: float = 0.85, metallic: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	m.vertex_color_use_as_albedo = true
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

## Water: a flat, slightly see-through surface with a sky sheen. Real
## reflections would need engine lighting (see the header) - a bright
## unshaded tint reads as water from a drone's height.
static func water_mat(deep: Color = Color(0.12, 0.3, 0.38), alpha: float = 0.88) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(deep.r, deep.g, deep.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = MapTextures.get_tex("ground_neutral")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 30.0
	return m

## A ground layer (see shaders/geo_layer.gdshader): the same look as
## tex_mat/flat_mat, drawn `layer` steps toward the camera so stacked
## ground surfaces (terrain < paving < road < markings) never flicker
## through each other at a distance. `macro` adds large-scale variation.
const LAYER_PULL: float = 0.0025
static var _layer_shader: Shader

static func ground_mat(tex: Texture2D, tint: Color = Color.WHITE, metres_per_tile: float = 4.0, layer: int = 1, macro: float = 0.35, uv_mapped: bool = false) -> ShaderMaterial:
	if _layer_shader == null:
		_layer_shader = load("res://shaders/geo_layer.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _layer_shader
	m.set_shader_parameter("use_tex", tex != null)
	if tex != null:
		m.set_shader_parameter("tex", tex)
	m.set_shader_parameter("tint", tint)
	m.set_shader_parameter("scale", 1.0 / metres_per_tile)
	m.set_shader_parameter("pull", LAYER_PULL * layer)
	m.set_shader_parameter("macro", macro if tex != null and not uv_mapped else 0.0)
	m.set_shader_parameter("use_uv", uv_mapped)
	return m

static func ground_flat(color: Color, layer: int = 1) -> ShaderMaterial:
	return ground_mat(null, color, 1.0, layer, 0.0)

static func glow_mat(color: Color, energy: float = 2.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m

# --- footprints -----------------------------------------------------------------
# Every solid primitive leaves its footprint (an oriented rectangle on
# the ground plus its height range), every road/rail sweep its lane, so
# whatever is scattered afterwards - trees, parked cars - can avoid
# being placed inside something (BuiltMap / Fleet check these).

const OBS_CELL: float = 32.0
var _obs: Array = [] # [centre: Vector2, axis: Vector2, half: Vector2, y0, y1]
var _obs_grid: Dictionary = {}
var _lanes: Array = [] # [a: Vector2, b: Vector2, half width]
var _lane_grid: Dictionary = {}

func _obstacle(c: Vector2, ax: Vector2, half: Vector2, y0: float, y1: float, collide: bool = true) -> void:
	_support.append([c, ax.normalized(), half, y0, y1])
	_grid_add(_sup_grid, c, minf(half.length(), 400.0), _support.size() - 1)
	if not collide or y1 - y0 < 0.3:
		return # flat: paving, kerbs, markings
	var r: float = half.length()
	if r > 120.0:
		return # whole ground slabs
	_obs.append([c, ax.normalized(), half, y0, y1, _cell_key.get_slice("|", 0)])
	_grid_add(_obs_grid, c, r, _obs.size() - 1)

func _obstacle_box(o: Vector3, hx: Vector3, hz: Vector3, corners: Array, collide: bool = true) -> void:
	var y0: float = INF
	var y1: float = -INF
	for p: Vector3 in corners:
		y0 = minf(y0, p.y)
		y1 = maxf(y1, p.y)
	var ax := Vector2(hx.x, hx.z)
	var az := Vector2(hz.x, hz.z)
	_obstacle(Vector2(o.x, o.z), ax if ax.length() > 0.001 else Vector2(1, 0), Vector2(ax.length(), az.length()), y0, y1, collide)

func _obstacle_points(pts: Array, collide: bool = true) -> void:
	var mn := Vector3(INF, INF, INF)
	var mx := Vector3(-INF, -INF, -INF)
	for p: Vector3 in pts:
		mn = mn.min(p)
		mx = mx.max(p)
	if (mx.x - mn.x) * (mx.z - mn.z) > 600.0:
		return # a long diagonal brace: its box would cover far too much
	_obstacle(Vector2(mn.x + mx.x, mn.z + mx.z) * 0.5, Vector2(1, 0), Vector2(mx.x - mn.x, mx.z - mn.z) * 0.5, mn.y, mx.y, collide)

func _lane(a: Vector2, b: Vector2, half: float) -> void:
	_lanes.append([a, b, half])
	_grid_add(_lane_grid, (a + b) * 0.5, (b - a).length() * 0.5 + half, _lanes.size() - 1)

func _grid_add(grid: Dictionary, c: Vector2, r: float, idx: int) -> void:
	for gx in range(floori((c.x - r) / OBS_CELL), floori((c.x + r) / OBS_CELL) + 1):
		for gz in range(floori((c.y - r) / OBS_CELL), floori((c.y + r) / OBS_CELL) + 1):
			var k := Vector2i(gx, gz)
			if not grid.has(k):
				grid[k] = []
			grid[k].append(idx)

## Is a circle of radius r at p (x, z) inside any solid between heights y0 and y1?
func blocked(p: Vector2, r: float, y0: float, y1: float) -> bool:
	for idx in _obs_grid.get(Vector2i(floori(p.x / OBS_CELL), floori(p.y / OBS_CELL)), []):
		var o: Array = _obs[idx]
		if o[4] <= y0 or o[3] >= y1:
			continue
		var d: Vector2 = p - o[0]
		var ax: Vector2 = o[1]
		if absf(d.dot(ax)) <= o[2].x + r and absf(d.dot(Vector2(-ax.y, ax.x))) <= o[2].y + r:
			return true
	return false

## Is p (x, z) on a road or track (within `margin` of its edge)?
func on_lane(p: Vector2, margin: float) -> bool:
	for idx in _lane_grid.get(Vector2i(floori(p.x / OBS_CELL), floori(p.y / OBS_CELL)), []):
		var l: Array = _lanes[idx]
		var a: Vector2 = l[0]
		var ab: Vector2 = l[1] - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		if (a + ab * t).distance_to(p) < l[2] + margin:
			return true
	return false

## Everything solid, flat or not (for the floating-object check).
var _support: Array = []
var _sup_grid: Dictionary = {}

func _overlaps(a: Array, b: Array) -> bool:
	# a's footprint rectangle against b's: separating-axis test on both
	# rectangles' axes, with 0.15 m slack (a support only has to touch).
	for r in [a, b]:
		var ax: Vector2 = r[1]
		for axis in [ax, Vector2(-ax.y, ax.x)]:
			var ca: float = (a[0] as Vector2).dot(axis)
			var cb: float = (b[0] as Vector2).dot(axis)
			var ea: float = absf(axis.dot(a[1])) * a[2].x + absf(axis.dot(Vector2(-a[1].y, a[1].x))) * a[2].y
			var eb: float = absf(axis.dot(b[1])) * b[2].x + absf(axis.dot(Vector2(-b[1].y, b[1].x))) * b[2].y
			if absf(ca - cb) > ea + eb + 0.15:
				return false
	return true

## Dev check (SH_FLOAT=1): solid pieces above the ground that touch
## nothing at all - no other piece within 0.35 m of their height range
## where their footprints meet (hanging from above counts as attached).
## ground: Callable(x, z) -> ground height.
func floating(ground: Callable) -> Array:
	var out: Array = []
	for i in range(_obs.size()):
		var o: Array = _obs[i]
		var c: Vector2 = o[0]
		var g: float = ground.call(c.x, c.y)
		if o[3] < g + 0.35:
			continue
		var held: bool = false
		var rr: float = (o[2] as Vector2).length() + 1.0
		for gx in range(floori((c.x - rr) / OBS_CELL), floori((c.x + rr) / OBS_CELL) + 1):
			for gz in range(floori((c.y - rr) / OBS_CELL), floori((c.y + rr) / OBS_CELL) + 1):
				for j in _sup_grid.get(Vector2i(gx, gz), []):
					var q: Array = _support[j]
					if q[0] == o[0] and q[3] == o[3] and q[4] == o[4]:
						continue
					if q[3] - 0.35 <= o[4] and o[3] <= q[4] + 0.35 and _overlaps(o, q):
						held = true
						break
				if held:
					break
			if held:
				break
		if not held:
			out.append([Vector3(c.x, o[3], c.y), o[5], o[2]])
	return out

## Marks an area as taken (parked cars, so trees and other cars avoid them).
func reserve(c: Vector2, ax: Vector2, half: Vector2, y0: float, y1: float) -> void:
	_obstacle(c, ax, half, y0, y1)

# --- primitives --------------------------------------------------------------

## Axis-aligned box (optionally turned about Y), by center and size.
func box(center: Vector3, size: Vector3, mat: String, yaw: float = 0.0, collide: bool = true, shadow: bool = true) -> void:
	box_xf(Transform3D(Basis(Vector3.UP, yaw), center), size, mat, collide, shadow)

## Box with any orientation. Faces are emitted in world space.
func box_xf(xf: Transform3D, size: Vector3, mat: String, collide: bool = true, shadow: bool = true) -> void:
	var h: Vector3 = size * 0.5
	var c: Array[Vector3] = []
	for i in range(8):
		c.append(xf * Vector3(h.x if i & 1 else -h.x, h.y if i & 2 else -h.y, h.z if i & 4 else -h.z))
	_begin(mat, xf.origin, collide)
	var b: Basis = xf.basis
	if absf(b.y.normalized().y) > 0.9:
		_obstacle_box(xf.origin, b.x * h.x, b.z * h.z, c, collide)
	else:
		_obstacle_points(c, collide)
	# (corner bit 0 = +x, bit 1 = +y, bit 2 = +z)
	_quad(c[1], c[3], c[7], c[5], b.x, collide)
	_quad(c[0], c[4], c[6], c[2], -b.x, collide)
	_quad(c[2], c[6], c[7], c[3], b.y, collide)
	_quad(c[0], c[1], c[5], c[4], -b.y, collide)
	_quad(c[4], c[5], c[7], c[6], b.z, collide)
	_quad(c[0], c[2], c[3], c[1], -b.z, collide)
	if shadow:
		_shadow(PackedVector3Array(c))

## Any convex 8-corner solid ("hexahedron"): corners in the same order
## as box_xf's (bit 0 = +x, bit 1 = +y, bit 2 = +z), each placed freely -
## tapered cabins, sloped bonnets, wedge noses. Face normals come from
## the face itself, pointed away from the solid's centre.
func hexa(c: Array, mat: String, collide: bool = true, shadow: bool = true) -> void:
	var centre := Vector3.ZERO
	for p in c:
		centre += p
	centre /= 8.0
	_begin(mat, centre, collide)
	_obstacle_points(c, collide)
	for f in [[1, 3, 7, 5], [0, 4, 6, 2], [2, 6, 7, 3], [0, 1, 5, 4], [4, 5, 7, 6], [0, 2, 3, 1]]:
		var a: Vector3 = c[f[0]]
		var b: Vector3 = c[f[1]]
		var cc: Vector3 = c[f[2]]
		var d: Vector3 = c[f[3]]
		var n: Vector3 = (cc - a).cross(d - b)
		if n.length() < 1e-6:
			continue
		n = n.normalized()
		if n.dot((a + b + cc + d) * 0.25 - centre) < 0.0:
			n = -n
		_quad(a, b, cc, d, n, collide)
	if shadow:
		_shadow(PackedVector3Array(c))

## hexa() from a local frame: a box whose top face is shrunk/shifted.
## size = bottom (x, h, z); top_x/top_z = top face size; top_off = top
## face centre offset along local z (e.g. a cabin set back).
func frustum(xf: Transform3D, size: Vector3, top_x: float, top_z: float, top_off: float, mat: String, collide: bool = true, shadow: bool = true) -> void:
	var pts: Array = []
	for i in range(8):
		var top: bool = i & 2
		var hx: float = (top_x if top else size.x) * 0.5
		var hz: float = (top_z if top else size.z) * 0.5
		var off: float = top_off if top else 0.0
		pts.append(xf * Vector3(hx if i & 1 else -hx, size.y * 0.5 if top else -size.y * 0.5, (hz if i & 4 else -hz) + off))
	hexa(pts, mat, collide, shadow)

## Beam from a to b with a square cross-section (girders, rails, bracing).
func beam(a: Vector3, b: Vector3, thickness: Vector2, mat: String, collide: bool = true, shadow: bool = true) -> void:
	var d: Vector3 = b - a
	if d.length() < 0.001:
		return
	var up: Vector3 = Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(d.normalized(), up)
	box_xf(Transform3D(basis, (a + b) * 0.5), Vector3(thickness.x, thickness.y, d.length()), mat, collide, shadow)

## Solid cylinder from a to b (columns, tanks, chimneys seen from outside).
func cylinder(a: Vector3, b: Vector3, r: float, mat: String, sides: int = 14, collide: bool = true, caps: bool = true, shadow: bool = true) -> void:
	_tube(a, b, r, r, 0.0, mat, sides, collide, caps, shadow)

## Hollow tube you can fly through: outer wall, inner wall, end rings.
func pipe(a: Vector3, b: Vector3, r: float, wall: float, mat: String, sides: int = 18, collide: bool = true, shadow: bool = true) -> void:
	_tube(a, b, r, r, wall, mat, sides, collide, false, shadow)

## Cone / tapered cylinder (r0 at a, r1 at b).
func cone(a: Vector3, b: Vector3, r0: float, r1: float, mat: String, sides: int = 14, collide: bool = true, shadow: bool = true) -> void:
	_tube(a, b, r0, r1, 0.0, mat, sides, collide, true, shadow)

## Surface of revolution around a vertical axis through `base`.
## profile: Vector2(radius, height) from bottom to top. `wall` > 0 makes
## it a shell with an inside surface too (cooling tower, open hopper).
func lathe(base: Vector3, profile: Array, mat: String, sides: int = 24, wall: float = 0.0, collide: bool = true, shadow: bool = true) -> void:
	_begin(mat, base, collide)
	if profile.size() > 1:
		var rmax: float = 0.0
		for q: Vector2 in profile:
			rmax = maxf(rmax, q.x)
		_obstacle(Vector2(base.x, base.z), Vector2(1, 0), Vector2(rmax, rmax), base.y + profile[0].y, base.y + profile[profile.size() - 1].y, collide)
	var pts := PackedVector3Array()
	for layer in ([0.0, wall] if wall > 0.0 else [0.0]):
		var inward: bool = layer > 0.0
		for i in range(profile.size() - 1):
			var p0: Vector2 = profile[i]
			var p1: Vector2 = profile[i + 1]
			var r0: float = maxf(p0.x - layer, 0.01)
			var r1: float = maxf(p1.x - layer, 0.01)
			for s in range(sides):
				var a0: float = TAU * s / sides
				var a1: float = TAU * (s + 1) / sides
				var q0 := base + Vector3(cos(a0) * r0, p0.y, sin(a0) * r0)
				var q1 := base + Vector3(cos(a1) * r0, p0.y, sin(a1) * r0)
				var q2 := base + Vector3(cos(a1) * r1, p1.y, sin(a1) * r1)
				var q3 := base + Vector3(cos(a0) * r1, p1.y, sin(a0) * r1)
				var mid: float = (a0 + a1) * 0.5
				var n := Vector3(cos(mid), (r0 - r1) / maxf(p1.y - p0.y, 0.01), sin(mid)).normalized()
				_quad(q0, q1, q2, q3, -n if inward else n, collide)
				if i == 0 or i == profile.size() - 2:
					pts.append(q0 if i == 0 else q2)
	if wall > 0.0:
		# Rim at the top (and bottom) joining outside and inside.
		for end in [0, profile.size() - 1]:
			var p: Vector2 = profile[end]
			for s in range(sides):
				var a0: float = TAU * s / sides
				var a1: float = TAU * (s + 1) / sides
				var o0 := base + Vector3(cos(a0) * p.x, p.y, sin(a0) * p.x)
				var o1 := base + Vector3(cos(a1) * p.x, p.y, sin(a1) * p.x)
				var i0 := base + Vector3(cos(a0) * (p.x - wall), p.y, sin(a0) * (p.x - wall))
				var i1 := base + Vector3(cos(a1) * (p.x - wall), p.y, sin(a1) * (p.x - wall))
				_quad(o0, o1, i1, i0, Vector3.UP if end > 0 else Vector3.DOWN, collide)
	if shadow:
		_shadow(pts)

## Flat ground-lying slab: a box whose top is at `top_y`.
func slab(rect: Rect2, top_y: float, thickness: float, mat: String, collide: bool = true) -> void:
	var c := Vector3(rect.get_center().x, top_y - thickness * 0.5, rect.get_center().y)
	box(c, Vector3(rect.size.x, thickness, rect.size.y), mat, 0.0, collide, false)

## Extrudes a 2D cross-section along a path (see Route): rails,
## ballast beds, roads, kerbs, pipes, conveyor galleries - one unbroken
## piece through every curve, so things that should connect do.
## profile: Array of Vector2(x across to the right of travel, y up).
## Face normals point away from `inside` (a point in profile space;
## default: far below, so road tops face up); a closed profile uses
## its centre instead, and `flip` turns them inward (a pipe's inside).
## uv_tile > 0 writes UVs (u across 0..1, v = metres along / uv_tile)
## for UV-mapped materials such as the sleeper bed (Geo.uv_mat).
func sweep(path: Array[Vector3], profile: Array, mat: String, closed: bool = false, collide: bool = true, shadow: bool = false, uv_tile: float = 0.0, smooth: bool = false, flip: bool = false, inside: Vector2 = Vector2(0, -1000)) -> void:
	var n: int = path.size()
	var m: int = profile.size()
	if n < 2 or m < 2:
		return
	# Every sweep segment counts as support (bridge decks, gallery
	# floors, rails) for the floating check.
	var pmin: float = INF
	var pmax: float = -INF
	var pw: float = 0.0
	for q: Vector2 in profile:
		pmin = minf(pmin, q.y)
		pmax = maxf(pmax, q.y)
		pw = maxf(pw, absf(q.x))
	for i in range(n - 1):
		var a2 := Vector2(path[i].x, path[i].z)
		var b2 := Vector2(path[i + 1].x, path[i + 1].z)
		var ax2: Vector2 = (b2 - a2).normalized() if a2.distance_to(b2) > 0.001 else Vector2(1, 0)
		var yl: float = minf(path[i].y, path[i + 1].y) + pmin
		var yh: float = maxf(path[i].y, path[i + 1].y) + pmax
		_support.append([(a2 + b2) * 0.5, ax2, Vector2(a2.distance_to(b2) * 0.5 + 0.2, pw), yl, yh])
		_grid_add(_sup_grid, (a2 + b2) * 0.5, a2.distance_to(b2) * 0.5 + pw, _support.size() - 1)
	if mat.begins_with("rd_asphalt") or mat.begins_with("rw_ballast"):
		var half: float = 0.0
		for q: Vector2 in profile:
			half = maxf(half, absf(q.x))
		for i in range(n - 1):
			_lane(Vector2(path[i].x, path[i].z), Vector2(path[i + 1].x, path[i + 1].z), half)
	if closed:
		inside = Vector2.ZERO
		for q: Vector2 in profile:
			inside += q
		inside /= m
	var edges: int = m if closed else m - 1
	var en: Array[Vector2] = []
	for j in range(edges):
		var p0: Vector2 = profile[j]
		var p1: Vector2 = profile[(j + 1) % m]
		var e: Vector2 = p1 - p0
		var nn: Vector2 = Vector2(e.y, -e.x).normalized()
		if ((p0 + p1) * 0.5 - inside).dot(nn) < 0.0:
			nn = -nn
		en.append(-nn if flip else nn)
	var vn: Array[Vector2] = []
	var us: Array[float] = []
	var ulen: float = 0.0
	for j in range(m):
		if j > 0:
			ulen += (profile[j] - profile[j - 1]).length()
		us.append(ulen)
		var a: Vector2 = en[(j - 1 + edges) % edges] if (closed or j > 0) else en[0]
		var b: Vector2 = en[j] if j < edges else en[edges - 1]
		vn.append((a + b).normalized())
	# A frame per path point: side (profile x) and up (profile y).
	var sides: Array[Vector3] = []
	var ups: Array[Vector3] = []
	var dist: Array[float] = []
	var prev_side := Vector3.ZERO
	var acc: float = 0.0
	for i in range(n):
		var t: Vector3 = (path[mini(i + 1, n - 1)] - path[maxi(i - 1, 0)]).normalized()
		var side: Vector3 = t.cross(Vector3.UP)
		if side.length() < 0.05:
			side = prev_side if prev_side != Vector3.ZERO else t.cross(Vector3.FORWARD)
		side = side.normalized()
		prev_side = side
		sides.append(side)
		ups.append(side.cross(t).normalized())
		if i > 0:
			acc += path[i].distance_to(path[i - 1])
		dist.append(acc)
	for i in range(n - 1):
		_begin(mat, (path[i] + path[i + 1]) * 0.5, collide)
		var st: SurfaceTool = _batches[_cell_key]
		var outline := PackedVector3Array()
		for j in range(edges):
			var j1: int = (j + 1) % m
			var corner: Array = []
			for c in [[i, j], [i, j1], [i + 1, j1], [i + 1, j]]:
				var q: Vector2 = profile[c[1]]
				var pos: Vector3 = path[c[0]] + sides[c[0]] * q.x + ups[c[0]] * q.y
				var nv: Vector2 = vn[c[1]] if smooth else en[j]
				var nrm: Vector3 = (sides[c[0]] * nv.x + ups[c[0]] * nv.y).normalized()
				var uv := Vector2((us[c[1]] if not (closed and c[1] == 0 and j == edges - 1) else ulen + (profile[0] - profile[m - 1]).length()) / maxf(ulen, 0.001), dist[c[0]] / uv_tile) if uv_tile > 0.0 else Vector2.ZERO
				corner.append([pos, nrm, uv])
				if shadow:
					outline.append(pos)
			var face_n: Vector3 = (sides[i] * en[j].x + ups[i] * en[j].y).normalized()
			for tri in [[0, 1, 2], [0, 2, 3]]:
				var order: Array = [corner[tri[0]], corner[tri[1]], corner[tri[2]]]
				if (order[1][0] - order[0][0]).cross(order[2][0] - order[0][0]).dot(face_n) > 0.0:
					order = [order[0], order[2], order[1]]
				for v in order:
					st.set_normal(v[1])
					st.set_uv(v[2])
					st.set_color(shade(v[1], v[0].y) * tint)
					st.add_vertex(v[0])
					if collide:
						_cell_col.append(v[0])
		if shadow:
			_shadow(outline)

## A side silhouette extruded across a vehicle's width: `profile` is a
## simple polygon of Vector2(z, y) in xf's local frame (any winding, may
## be concave - wheel arches, a cab behind a bonnet), extruded from
## x = -width/2 to +width/2, both sides capped. This is what gives cars,
## lorries and locomotives their real outline instead of stacked boxes.
func prism(xf: Transform3D, profile: Array, width: float, mat: String, collide: bool = true, shadow: bool = true) -> void:
	if true:
		var pts: Array = []
		for q: Vector2 in profile:
			pts.append(xf * Vector3(-width * 0.5, q.y, q.x))
			pts.append(xf * Vector3(width * 0.5, q.y, q.x))
		_obstacle_points(pts, collide)
	var poly := PackedVector2Array(profile)
	var m: int = poly.size()
	var area: float = 0.0
	for j in range(m):
		var a: Vector2 = poly[j]
		var b: Vector2 = poly[(j + 1) % m]
		area += a.x * b.y - b.x * a.y
	var ccw: bool = area > 0.0
	var w: float = width * 0.5
	var left: Array[Vector3] = []
	var right: Array[Vector3] = []
	for q in poly:
		left.append(xf * Vector3(-w, q.y, q.x))
		right.append(xf * Vector3(w, q.y, q.x))
	_begin(mat, xf.origin, collide)
	var bs: Basis = xf.basis
	for j in range(m):
		var j1: int = (j + 1) % m
		var e: Vector2 = poly[j1] - poly[j]
		var n2 := Vector2(e.y, -e.x) if ccw else Vector2(-e.y, e.x) # (z, y) outward
		if n2.length() < 1e-6:
			continue
		n2 = n2.normalized()
		_quad(left[j], left[j1], right[j1], right[j], (bs * Vector3(0, n2.y, n2.x)).normalized(), collide)
	var tris: PackedInt32Array = Geometry2D.triangulate_polygon(poly)
	var nl: Vector3 = (bs * Vector3(-1, 0, 0)).normalized()
	for t in range(0, tris.size(), 3):
		_tri(left[tris[t]], left[tris[t + 1]], left[tris[t + 2]], nl, collide)
		_tri(right[tris[t]], right[tris[t + 1]], right[tris[t + 2]], -nl, collide)
	if shadow:
		var pts := PackedVector3Array(left)
		pts.append_array(PackedVector3Array(right))
		_shadow(pts)

## Circle of radius r as a sweep profile (pipes, tanks lying down).
static func circle(r: float, sides: int = 12) -> Array:
	var out: Array = []
	for i in range(sides):
		var a: float = TAU * i / sides
		out.append(Vector2(cos(a), sin(a)) * r)
	return out

## Pipe along a path: outer wall, optionally hollow (inner wall facing
## in, so you can fly through), open ends.
func pipe_path(path: Array[Vector3], r: float, mat: String, hollow_wall: float = 0.0, sides: int = 14, collide: bool = true, shadow: bool = true) -> void:
	sweep(path, circle(r, sides), mat, true, collide, shadow, 0.0, true)
	if hollow_wall > 0.0:
		sweep(path, circle(r - hollow_wall, sides), mat, true, collide, false, 0.0, true, true)

# --- internals ---------------------------------------------------------------

func _tube(a: Vector3, b: Vector3, r0: float, r1: float, wall: float, mat: String, sides: int, collide: bool, caps: bool, shadow: bool) -> void:
	var d: Vector3 = b - a
	var length: float = d.length()
	if length < 0.001:
		return
	var up: Vector3 = Vector3.UP if absf(d.normalized().y) < 0.99 else Vector3.RIGHT
	var basis := Basis.looking_at(d / length, up) # local -Z runs a -> b
	_begin(mat, (a + b) * 0.5, collide)
	if true:
		var rr: float = maxf(r0, r1)
		var flat := Vector3(d.x, 0, d.z)
		var lo: float = minf(a.y, b.y) - (rr if absf(d.y) < length * 0.7 else 0.0)
		var hi: float = maxf(a.y, b.y) + (rr if absf(d.y) < length * 0.7 else 0.0)
		if flat.length() < 0.01:
			_obstacle(Vector2(a.x, a.z), Vector2(1, 0), Vector2(rr, rr), lo, hi, collide)
		else:
			var ax := Vector2(flat.x, flat.z).normalized()
			var mid: Vector3 = (a + b) * 0.5
			_obstacle(Vector2(mid.x, mid.z), ax, Vector2(flat.length() * 0.5 + rr, rr), lo, hi, collide)
	var pts := PackedVector3Array()
	var layers: Array = [[r0, r1, false]]
	if wall > 0.0:
		layers.append([r0 - wall, r1 - wall, true])
	for l in layers:
		var ra: float = l[0]
		var rb: float = l[1]
		for s in range(sides):
			var a0: float = TAU * s / sides
			var a1: float = TAU * (s + 1) / sides
			var q0: Vector3 = a + basis * Vector3(cos(a0) * ra, sin(a0) * ra, 0.0)
			var q1: Vector3 = a + basis * Vector3(cos(a1) * ra, sin(a1) * ra, 0.0)
			var q2: Vector3 = a + basis * Vector3(cos(a1) * rb, sin(a1) * rb, -length)
			var q3: Vector3 = a + basis * Vector3(cos(a0) * rb, sin(a0) * rb, -length)
			var mid: float = (a0 + a1) * 0.5
			var n: Vector3 = basis * Vector3(cos(mid), sin(mid), 0.0)
			_quad(q0, q1, q2, q3, -n if l[2] else n, collide)
			if not l[2]:
				pts.append(q0)
				pts.append(q3)
	for end in [0, 1]:
		var center: Vector3 = a if end == 0 else b
		var rr: float = r0 if end == 0 else r1
		var n_end: Vector3 = -(d / length) if end == 0 else d / length
		for s in range(sides):
			var a0: float = TAU * s / sides
			var a1: float = TAU * (s + 1) / sides
			var z: float = 0.0 if end == 0 else -length
			var o0: Vector3 = a + basis * Vector3(cos(a0) * rr, sin(a0) * rr, z)
			var o1: Vector3 = a + basis * Vector3(cos(a1) * rr, sin(a1) * rr, z)
			if wall > 0.0:
				var ri: float = rr - wall
				var i0: Vector3 = a + basis * Vector3(cos(a0) * ri, sin(a0) * ri, z)
				var i1: Vector3 = a + basis * Vector3(cos(a1) * ri, sin(a1) * ri, z)
				_quad(o0, o1, i1, i0, n_end, collide)
			elif caps:
				_tri(center, o0, o1, n_end, collide)
	if shadow:
		_shadow(pts)

func _begin(mat: String, pos: Vector3, collide: bool) -> void:
	assert(_mats.has(mat), "Geo: unknown material " + mat)
	if not _mat_cell.has(mat):
		var coarse: bool = false
		for pre in coarse_prefixes + detail_prefixes:
			if mat.begins_with(pre):
				coarse = true
				break
		_mat_cell[mat] = coarse
	var cs: float = maxf(cell, COARSE_CELL) if _mat_cell[mat] else cell
	var cx: int = floori(pos.x / cs)
	var cz: int = floori(pos.z / cs)
	var key: String = "%s|%d|%d|%d" % [mat, cx, cz, int(cs)]
	if not _batches.has(key):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		st.set_uv(Vector2.ZERO) # every batch has UVs (sweep writes them; the format is fixed by the first vertex)
		_batches[key] = st
		_batch_mat[key] = mat
	_cell_key = key
	var ck: String = "%d|%d|%d" % [cx, cz, int(cs)]
	if not _col.has(ck):
		_col[ck] = []
	_cell_col = _col[ck]

func _quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, collide: bool) -> void:
	_tri(a, b, c, n, collide)
	_tri(a, c, d, n, collide)

func _tri(a: Vector3, b: Vector3, c: Vector3, n: Vector3, collide: bool) -> void:
	var st: SurfaceTool = _batches[_cell_key]
	var order: Array[Vector3] = [a, b, c]
	if (b - a).cross(c - a).dot(n) > 0.0:
		order = [a, c, b]
	for p in order:
		st.set_normal(n)
		st.set_color(shade(n, p.y) * tint)
		st.add_vertex(p)
	if collide:
		_cell_col.append_array(order)

## Baked light for a surface with normal n at height y (see the header).
func shade(n: Vector3, y: float) -> Color:
	var f: float = clampf((y - ao_ground_y) / ao_height, 0.0, 1.0)
	var ao: float = lerpf(ao_min, 1.0, f * f * (3.0 - 2.0 * f))
	var direct: float = sun * maxf(n.dot(-sun_dir), 0.0)
	var base: float = ambient + sky * (0.5 + 0.5 * n.y)
	var c: Color = Color(base, base, base * 1.04) + sun_tint * direct
	return Color(minf(c.r * ao, 1.0), minf(c.g * ao, 1.0), minf(c.b * ao, 1.0))

## (Shadows are WorldShading's shadow map now - every surface casts.
## The `shadow` flags on the primitives are kept for callers' sake.)
func _shadow(_pts: PackedVector3Array) -> void:
	pass

## Turns everything into nodes under `root`. Call once, after building.
func commit(root: Node3D) -> void:
	var holder := Node3D.new()
	holder.name = "Generated"
	root.add_child(holder)
	for key in _batches:
		var st: SurfaceTool = _batches[key]
		var mesh: ArrayMesh = st.commit()
		if mesh.get_surface_count() == 0:
			continue
		mesh.surface_set_material(0, _mats[_batch_mat[key]])
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_meta("geo_batch", true)
		for pre in detail_prefixes:
			if _batch_mat[key].begins_with(pre):
				mi.visibility_range_end = DETAIL_RANGE
				mi.visibility_range_end_margin = 40.0
				mi.set_meta("geo_detail", true)
				break
		holder.add_child(mi)
	var body := StaticBody3D.new()
	body.name = "GeneratedCollision"
	holder.add_child(body)
	for ck in _col:
		var faces := PackedVector3Array(_col[ck])
		if faces.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.backface_collision = true
		shape.set_faces(faces)
		var cs := CollisionShape3D.new()
		cs.shape = shape
		body.add_child(cs)
	_batches.clear()
	_col.clear()

## Everything built so far as one local-space mesh (one surface per
## material) instead of scene nodes - for MultiMesh sources like trees.
func build_mesh() -> ArrayMesh:
	var by_mat: Dictionary = {}
	for key in _batches:
		var m: String = _batch_mat[key]
		if not by_mat.has(m):
			by_mat[m] = []
		by_mat[m].append(_batches[key])
	var mesh := ArrayMesh.new()
	for m in by_mat:
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for part: SurfaceTool in by_mat[m]:
			st.append_from(part.commit(), 0, Transform3D.IDENTITY)
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _mats[m])
	_batches.clear()
	_col.clear()
	return mesh
