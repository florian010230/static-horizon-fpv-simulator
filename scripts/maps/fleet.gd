class_name Fleet
extends RefCounted

## Parked and moving cars by the thousand. Building every car as Geo
## geometry cost ~10 ms each in GDScript (a city street network has
## a couple of thousand) - so each car kind is built once per heading
## (the full Vehicles.car model), tinted once per paint colour, and
## copied into merged chunk meshes (see commit). An earlier MultiMesh
## version made ~2000 draw calls in a city map.
##
## Light is baked into the vertex colours (see Geo), which depends on
## which way the car faces - so each kind is built for 8 headings and a
## car uses the nearest one (at most 22.5 degrees off - not visible).
## Collision: one box per car.
##
## Far from where the drone can fly (2026-10-04, RAM): a chunk more than
## FAR_LOD outside the map's reset border can only ever be seen from
## that far away - its cars are a seven-box stand-in (~250 vertices
## instead of ~1,800: body, glasshouse, roof, four wheels, same paint and
## baked light) and get no collision (the drone can't reach them). A
## chunk farther out than Geo.DETAIL_RANGE (where car batches stop being
## drawn) is never drawn at all and is left out. Harbour: see
## notes/r2-flight.md for the numbers.

const CHUNK: float = 128.0
const BINS: int = 8
const FAR_LOD: float = 120.0

var geo: Geo ## the map's Geo, for its light settings
var _items: Dictionary = {} # Vector2i chunk -> Array of [kind, bin, Transform3D, Color]
static var _paint_mat: StandardMaterial3D

func _init(g: Geo) -> void:
	geo = g

## Paint colours weighted like real traffic (white, black, greys first).
static func random_paint(rng: RandomNumberGenerator) -> Color:
	var r: float = rng.randf()
	var p: Array = Vehicles.PAINTS
	if r < 0.22:
		return p[9]
	if r < 0.4:
		return p[3]
	if r < 0.55:
		return p[4]
	if r < 0.67:
		return p[5]
	return p[rng.randi() % p.size()]

## A car standing at p (road surface), facing along local -z (yaw).
func car(p: Vector3, yaw: float, paint: Color, kind: String = "sedan") -> void:
	var step: float = TAU / BINS
	var bin: int = posmod(roundi(yaw / step), BINS)
	var xf := Transform3D(Basis(Vector3.UP, yaw - bin * step), p)
	var key := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
	if not _items.has(key):
		_items[key] = []
	_items[key].append([kind, bin, xf, paint, yaw])

func count() -> int:
	var n: int = 0
	for k in _items:
		n += _items[k].size()
	return n

## Builds the nodes under root. Call once, after all cars are placed.
## Per 128 m chunk, every car's model (built once per kind, heading and
## paint) is copied into one mesh per material - its arrays transformed
## and appended in bulk - so a chunk full of cars is ~9 draw calls.
func commit(root: Node3D) -> void:
	# Drop cars that would stand inside a building, a truck, a pillar or
	# another car (Geo's footprints); each kept car reserves its own.
	var dropped: int = 0
	for key in _items:
		var kept: Array = []
		for it in _items[key]:
			var spec: Array = Vehicles.CAR_SPECS.get(it[0], Vehicles.CAR_SPECS.sedan)
			var p: Vector3 = it[2].origin
			var ax := Vector2(cos(it[4]), -sin(it[4]))
			var half := Vector2(spec[1] * 0.5 - 0.15, spec[0] * 0.5 - 0.25)
			if geo.blocked(Vector2(p.x, p.z), 0.0, p.y + 0.45, p.y + spec[2] - 0.1) or _blocked_box(p, ax, half, spec[2]):
				dropped += 1
				continue
			geo.reserve(Vector2(p.x, p.z), ax, half, p.y + 0.3, p.y + spec[2])
			kept.append(it)
		_items[key] = kept
	if OS.has_environment("SH_PERF"):
		print("FLEET dropped %d" % dropped)
	var n_verts: int = 0
	var n_far: int = 0
	var n_gone: int = 0
	# The flight area: BuiltMap.border() = [warn r, reset r, .., centre].
	var area_c := Vector2.ZERO
	var area_r: float = INF
	if root.has_method("border"):
		var bd: Array = root.border()
		area_r = bd[1]
		area_c = bd[4] if bd.size() > 4 else Vector2.ZERO
	var holder := Node3D.new()
	holder.name = "Fleet"
	root.add_child(holder)
	for key in _items:
		var rect := Rect2(Vector2(key) * CHUNK, Vector2(CHUNK, CHUNK))
		var near_pt := Vector2(clampf(area_c.x, rect.position.x, rect.end.x), clampf(area_c.y, rect.position.y, rect.end.y))
		var outside: float = area_c.distance_to(near_pt) - area_r
		if outside > Geo.DETAIL_RANGE:
			n_gone += _items[key].size()
			continue
		var far: bool = outside > FAR_LOD
		if far:
			n_far += _items[key].size()
		# Per material: the chunk's vertices, normals, colours, UVs - each
		# car's model arrays transformed and appended in bulk (C++), not
		# SurfaceTool.append_from (which re-read the source mesh for every
		# car: 2 ms a car, 6 s for the Harbour's 2,900).
		var acc: Dictionary = {}
		var body := StaticBody3D.new()
		holder.add_child(body)
		for it in _items[key]:
			var xf: Transform3D = it[2]
			var rot := Transform3D(xf.basis, Vector3.ZERO)
			for surf: Array in _surfaces(it[0], it[1], it[3], far):
				var mat: Material = surf[0]
				# (Pieces collected here and joined once below: a packed array
				# held in an Array is a value - appending to it in place
				# appends to a copy.)
				if not acc.has(mat):
					acc[mat] = [[], [], []]
				var a: Array = acc[mat]
				a[0].append(xf * (surf[1] as PackedVector3Array))
				a[1].append(rot * (surf[2] as PackedVector3Array))
				a[2].append(surf[3])
			if far:
				continue
			var spec: Array = Vehicles.CAR_SPECS.get(it[0], Vehicles.CAR_SPECS.sedan)
			var p: Vector3 = it[2].origin
			var b := Basis(Vector3.UP, it[4])
			var shape := BoxShape3D.new()
			shape.size = Vector3(spec[1], spec[2] - 0.2, spec[0])
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.transform = Transform3D(b, p + Vector3(0, spec[2] * 0.5 + 0.1, 0))
			body.add_child(cs)
		for mat in acc:
			var a: Array = acc[mat]
			var vs := PackedVector3Array()
			var ns := PackedVector3Array()
			var cs2 := PackedColorArray()
			for i in range(a[0].size()):
				vs.append_array(a[0][i])
				ns.append_array(a[1][i])
				cs2.append_array(a[2][i])
			var arrays: Array = []
			arrays.resize(Mesh.ARRAY_MAX)
			arrays[Mesh.ARRAY_VERTEX] = vs
			arrays[Mesh.ARRAY_NORMAL] = ns
			arrays[Mesh.ARRAY_COLOR] = cs2
			# No UVs: every vehicle material is flat or world-triplanar. And
			# compressed (Geo.COMPRESS): 16-bit positions in the chunk's box,
			# octahedral normals, colour - 16 bytes a vertex (24 before).
			var mesh := ArrayMesh.new()
			mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, Geo.COMPRESS)
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.visibility_range_end = Geo.DETAIL_RANGE
			mi.visibility_range_end_margin = 40.0
			mi.set_meta("geo_detail", true)
			mi.set_meta("geo_batch", true)
			holder.add_child(mi)
			n_verts += vs.size()
	if OS.has_environment("SH_PERF"):
		print("FLEET %d vertices; %d far cars (stand-ins), %d never drawn (left out)" % [n_verts, n_far, n_gone])
	_items.clear()

## The four corners of a car's footprint, checked like its centre.
func _blocked_box(p: Vector3, ax: Vector2, half: Vector2, h: float) -> bool:
	var az := Vector2(-ax.y, ax.x)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q: Vector2 = Vector2(p.x, p.z) + ax * half.x * sx + az * half.y * sz
			if geo.blocked(q, 0.0, p.y + 0.45, p.y + h - 0.1):
				return true
	return false

var _parts: Dictionary = {}
var _models: Dictionary = {}
var _surf_cache: Dictionary = {}

## One model as plain arrays per surface, read once:
## [[material, vertices, normals, colours, uvs], ...] - unindexed.
func _surfaces(kind: String, bin: int, paint: Color, far: bool = false) -> Array:
	var mk: String = "%s|%d|%s|%s" % [kind, bin, paint.to_html(false), far]
	if _surf_cache.has(mk):
		return _surf_cache[mk]
	var model: ArrayMesh = _model(kind, bin, paint, far)
	var out: Array = []
	for s in range(model.get_surface_count()):
		var arr: Array = model.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var c: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var uv: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var idx: Variant = arr[Mesh.ARRAY_INDEX]
		if idx != null and (idx as PackedInt32Array).size() > 0:
			var ii: PackedInt32Array = idx
			var v2 := PackedVector3Array()
			var n2 := PackedVector3Array()
			var c2 := PackedColorArray()
			var uv2 := PackedVector2Array()
			for k in ii:
				v2.append(v[k])
				n2.append(n[k] if n.size() > k else Vector3.UP)
				c2.append(c[k] if c.size() > k else Color.WHITE)
				uv2.append(uv[k] if uv.size() > k else Vector2.ZERO)
			v = v2
			n = n2
			c = c2
			uv = uv2
		if n.size() != v.size():
			n.resize(v.size())
		if c.size() != v.size():
			c.resize(v.size())
			c.fill(Color.WHITE)
		if uv.size() != v.size():
			uv.resize(v.size())
		out.append([model.surface_get_material(s), v, n, c, uv])
	_surf_cache[mk] = out
	return out

## One car model: the kind at a heading, its body in `paint` (the paint
## is multiplied into the body's baked vertex colours).
func _model(kind: String, bin: int, paint: Color, far: bool = false) -> ArrayMesh:
	var mk: String = "%s|%d|%s|%s" % [kind, bin, paint.to_html(false), far]
	if _models.has(mk):
		return _models[mk]
	var pk: String = "%s|%d|%s" % [kind, bin, far]
	if not _parts.has(pk):
		_parts[pk] = _build(kind, bin, far)
	var pair: Array = _parts[pk]
	var m := ArrayMesh.new()
	var body: ArrayMesh = pair[0]
	for s in range(body.get_surface_count()):
		var arrays: Array = body.surface_get_arrays(s)
		var cols: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in range(cols.size()):
			cols[i] = cols[i] * paint
		arrays[Mesh.ARRAY_COLOR] = cols
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		m.surface_set_material(m.get_surface_count() - 1, body.surface_get_material(s))
	var rest: ArrayMesh = pair[1]
	for s in range(rest.get_surface_count()):
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, rest.surface_get_arrays(s))
		m.surface_set_material(m.get_surface_count() - 1, rest.surface_get_material(s))
	_models[mk] = m
	return m

## [painted body mesh, everything else] for one kind at one heading.
func _build(kind: String, bin: int, far: bool = false) -> Array:
	var g := Geo.new()
	g.sun_dir = geo.sun_dir
	g.sun = geo.sun
	g.sky = geo.sky
	g.ambient = geo.ambient
	g.sun_tint = geo.sun_tint
	g.ao_ground_y = 0.0
	g.ao_height = geo.ao_height
	g.ao_min = geo.ao_min
	# The map's own vehicle materials (shared, so all cars of a chunk
	# merge into one mesh per material).
	Vehicles.ensure_materials(geo)
	for k in geo._mats:
		if k.begins_with("veh_"):
			g.add_material(k, geo._mats[k])
	if _paint_mat == null:
		_paint_mat = Geo.flat_mat(Color.WHITE, 0.35, 0.3)
	g.add_material("fleet_paint", _paint_mat)
	if far:
		_stand_in(g, kind, bin * TAU / BINS)
	else:
		Vehicles.car(g, Vector3.ZERO, bin * TAU / BINS, "fleet_paint", kind)
	var all: ArrayMesh = g.build_mesh()
	var a := ArrayMesh.new()
	var b := ArrayMesh.new()
	for s in range(all.get_surface_count()):
		var target: ArrayMesh = a if all.surface_get_material(s) == _paint_mat else b
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, all.surface_get_arrays(s))
		target.surface_set_material(target.get_surface_count() - 1, all.surface_get_material(s))
	return [a, b]

## The far stand-in: Vehicles.car's proportions (CAR_SPECS) in seven
## boxes - lower body, glasshouse, roof, four wheels.
static func _stand_in(g: Geo, kind: String, yaw: float) -> void:
	var s: Array = Vehicles.CAR_SPECS.get(kind, Vehicles.CAR_SPECS.sedan)
	var L: float = s[0]
	var W: float = s[1]
	var H: float = s[2]
	var belt: float = s[3]
	var wr: float = s[9]
	var clear: float = wr * 0.7
	var zf: float = -L * 0.5
	var zws: float = zf + s[5]
	var zrr: float = minf(zws + s[6] + s[7], L * 0.5 - 0.05)
	var t := Transform3D(Basis(Vector3.UP, yaw), Vector3.ZERO)
	var part := func(c: Vector3, size: Vector3, mat: String) -> void:
		g.box_xf(t * Transform3D(Basis(), c), size, mat, false, false)
	part.call(Vector3(0, (clear + belt) * 0.5, 0), Vector3(W, belt - clear, L - 0.1), "fleet_paint")
	var gz0: float = zws + s[6] * 0.5
	part.call(Vector3(0, (belt + H - 0.06) * 0.5, (gz0 + zrr) * 0.5), Vector3(W - 0.16, H - 0.06 - belt, zrr - gz0), "veh_glass")
	part.call(Vector3(0, H - 0.03, (gz0 + zrr) * 0.5), Vector3(W - 0.2, 0.06, zrr - gz0 - 0.1), "fleet_paint")
	for zc in [zf + s[10], L * 0.5 - s[11]]:
		for sx in [-1.0, 1.0]:
			part.call(Vector3(sx * (W * 0.5 - 0.11), wr, zc), Vector3(0.2, wr * 2.0, wr * 2.0), "veh_tyre")
