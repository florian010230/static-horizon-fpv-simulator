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

const CHUNK: float = 128.0
const BINS: int = 8

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
## paint) is copied into one mesh per material with SurfaceTool.append_from
## - a C++ copy, fast - so a chunk full of cars is ~9 draw calls.
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
	var holder := Node3D.new()
	holder.name = "Fleet"
	root.add_child(holder)
	for key in _items:
		var tools: Dictionary = {}
		var body := StaticBody3D.new()
		holder.add_child(body)
		for it in _items[key]:
			var model: ArrayMesh = _model(it[0], it[1], it[3])
			for s in range(model.get_surface_count()):
				var mat: Material = model.surface_get_material(s)
				if not tools.has(mat):
					var st := SurfaceTool.new()
					st.begin(Mesh.PRIMITIVE_TRIANGLES)
					tools[mat] = st
				tools[mat].append_from(model, s, it[2])
			var spec: Array = Vehicles.CAR_SPECS.get(it[0], Vehicles.CAR_SPECS.sedan)
			var p: Vector3 = it[2].origin
			var b := Basis(Vector3.UP, it[4])
			var shape := BoxShape3D.new()
			shape.size = Vector3(spec[1], spec[2] - 0.2, spec[0])
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.transform = Transform3D(b, p + Vector3(0, spec[2] * 0.5 + 0.1, 0))
			body.add_child(cs)
		for mat in tools:
			var mesh: ArrayMesh = tools[mat].commit()
			mesh.surface_set_material(0, mat)
			var mi := MeshInstance3D.new()
			mi.mesh = mesh
			mi.visibility_range_end = Geo.DETAIL_RANGE
			mi.visibility_range_end_margin = 40.0
			mi.set_meta("geo_detail", true)
			mi.set_meta("geo_batch", true)
			holder.add_child(mi)
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

## One car model: the kind at a heading, its body in `paint` (the paint
## is multiplied into the body's baked vertex colours).
func _model(kind: String, bin: int, paint: Color) -> ArrayMesh:
	var mk: String = "%s|%d|%s" % [kind, bin, paint.to_html(false)]
	if _models.has(mk):
		return _models[mk]
	var pk: String = "%s|%d" % [kind, bin]
	if not _parts.has(pk):
		_parts[pk] = _build(kind, bin)
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
func _build(kind: String, bin: int) -> Array:
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
	Vehicles.car(g, Vector3.ZERO, bin * TAU / BINS, "fleet_paint", kind)
	var all: ArrayMesh = g.build_mesh()
	var a := ArrayMesh.new()
	var b := ArrayMesh.new()
	for s in range(all.get_surface_count()):
		var target: ArrayMesh = a if all.surface_get_material(s) == _paint_mat else b
		target.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, all.surface_get_arrays(s))
		target.surface_set_material(target.get_surface_count() - 1, all.surface_get_material(s))
	return [a, b]
