class_name Forest
extends RefCounted

## Trees by the thousand: two species (conifer, broadleaf) as MultiMesh
## instances in 128 m chunks (each chunk culls on its own), random yaw,
## size and tint per tree, and real collision - a trunk cylinder plus a
## crown cylinder per tree, grouped into one static body per chunk.

const CHUNK: float = 128.0

static var _meshes: Dictionary = {}

## trees: Array of [position: Vector3, kind: int (0 conifer, 1 broadleaf), scale: float]
static func plant(root: Node3D, trees: Array, cast_shadows_into: Node3D = null) -> void:
	var holder := Node3D.new()
	holder.name = "Forest"
	root.add_child(holder)
	var chunks: Dictionary = {}
	for t in trees:
		var key := Vector2i(floori(t[0].x / CHUNK), floori(t[0].z / CHUNK))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var groups: Array = []
	for key in chunks:
		var body := StaticBody3D.new()
		holder.add_child(body)
		for kind in [0, 1]:
			var list: Array = chunks[key].filter(func(t): return t[1] == kind)
			if list.is_empty():
				continue
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = _mesh(kind)
			mm.instance_count = list.size()
			for i in range(list.size()):
				var t: Array = list[i]
				var sc: float = t[2]
				var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), t[0])
				mm.set_instance_transform(i, xf)
				var tint: float = rng.randf_range(0.8, 1.15)
				mm.set_instance_color(i, Color(tint * rng.randf_range(0.95, 1.05), tint, tint * rng.randf_range(0.9, 1.0)))
				_collider(body, t[0], kind, sc)
				if cast_shadows_into:
					groups.append(_outline(t[0], kind, sc))
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			holder.add_child(mmi)
	if cast_shadows_into:
		var g: Array = cast_shadows_into.get_meta("shadow_groups", [])
		g.append_array(groups)
		cast_shadows_into.set_meta("shadow_groups", g)

static func _collider(body: StaticBody3D, pos: Vector3, kind: int, sc: float) -> void:
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.3 * sc
	trunk.height = 4.0 * sc
	var cs := CollisionShape3D.new()
	cs.shape = trunk
	cs.position = pos + Vector3(0, 2.0 * sc, 0)
	body.add_child(cs)
	var crown := CylinderShape3D.new()
	crown.radius = (2.2 if kind == 0 else 3.0) * sc
	crown.height = (9.0 if kind == 0 else 6.0) * sc
	var cc := CollisionShape3D.new()
	cc.shape = crown
	cc.position = pos + Vector3(0, (8.0 if kind == 0 else 7.0) * sc, 0)
	body.add_child(cc)

static func _outline(pos: Vector3, kind: int, sc: float) -> PackedVector3Array:
	var pts := PackedVector3Array()
	var r: float = (2.4 if kind == 0 else 3.2) * sc
	var top: float = (13.0 if kind == 0 else 10.0) * sc
	for i in range(8):
		var a: float = TAU * i / 8.0
		pts.append(pos + Vector3(cos(a) * r, 3.5 * sc, sin(a) * r))
	pts.append(pos + Vector3(0, top, 0))
	pts.append(pos)
	return pts

static func _mesh(kind: int) -> ArrayMesh:
	if _meshes.has(kind):
		return _meshes[kind]
	var g := Geo.new()
	g.ao_height = 6.0
	g.ao_min = 0.45
	g.add_material("bark", Geo.flat_mat(Color(0.3, 0.22, 0.15)))
	g.add_material("leaf", Geo.flat_mat(Color(0.17, 0.3, 0.14) if kind == 0 else Color(0.25, 0.38, 0.15), 0.95))
	if kind == 0:
		g.cylinder(Vector3.ZERO, Vector3(0, 4, 0), 0.3, "bark", 6, false)
		g.cone(Vector3(0, 2.5, 0), Vector3(0, 8, 0), 2.6, 0.9, "leaf", 8, false)
		g.cone(Vector3(0, 6.5, 0), Vector3(0, 11, 0), 2.0, 0.5, "leaf", 8, false)
		g.cone(Vector3(0, 9.5, 0), Vector3(0, 13.5, 0), 1.3, 0.05, "leaf", 8, false)
	else:
		g.cylinder(Vector3.ZERO, Vector3(0, 5, 0), 0.32, "bark", 6, false)
		var crown: Array[Vector2] = [Vector2(0.4, 3.8), Vector2(2.6, 4.8), Vector2(3.3, 6.8), Vector2(2.8, 8.8), Vector2(1.4, 10.0), Vector2(0.05, 10.3)]
		g.lathe(Vector3.ZERO, crown, "leaf", 9, 0.0, false)
	_meshes[kind] = g.build_mesh()
	return _meshes[kind]
