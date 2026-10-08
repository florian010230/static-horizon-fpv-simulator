class_name Forest
extends RefCounted

## Trees by the thousand. Five species - spruce and pine (kind 0,
## "conifer"), a round broadleaf (oak/lime), birch and poplar (kind 1) -
## each a hand-shaped mesh: tiers of drooping branch skirts for the
## spruce, an umbrella crown on a bare orange trunk for the pine, lumpy
## clusters of leaf masses on real branches for the broadleaves. One
## material for leaves and bark (shaders/tree.gdshader), lit in the
## shader so randomly turned trees still face the sun correctly.
##
## Two levels of detail: the full trees as MultiMesh per 128 m chunk and
## species, drawn within NEAR_RANGE; beyond that, a merged mesh of crude
## stand-ins (a cone, a blob - ~40 triangles a tree) per 512 m chunk,
## always drawn. The stand-ins are smaller than the full crowns, so up
## close they sit inside them as the dense core of the foliage.
##
## Collision: a trunk cylinder plus a crown cylinder per tree, one static
## body per chunk.

const CHUNK: float = 128.0
const FAR_CHUNK: float = 512.0
## Full trees out to this distance, per graphics quality.
const NEAR_RANGE: Array[float] = [140.0, 220.0, 320.0]
## A chunk's centre to its farthest tree (half the diagonal, plus height).
const CHUNK_SLACK: float = 110.0

enum { SPRUCE, PINE, BROAD, BIRCH, POPLAR }
## Per species: [collision trunk height, crown radius, crown centre y, crown height]
const SHAPE := {
	SPRUCE: [4.0, 2.3, 8.0, 12.0], PINE: [11.0, 2.6, 14.0, 5.0], BROAD: [4.5, 3.6, 8.2, 7.0],
	BIRCH: [5.0, 2.0, 9.0, 8.0], POPLAR: [3.0, 1.9, 10.5, 15.0]}

static var _near: Dictionary = {}
static var _far: Dictionary = {}
static var _mat: ShaderMaterial

## trees: Array of [position: Vector3, kind: int (0 conifer, 1 broadleaf), scale: float]
## (the third argument is no longer used - every tree casts into the
## shadow map.)
static func plant(root: Node3D, trees: Array, _unused: Node3D = null) -> void:
	# Generated maps plant after build(), clear of buildings and roads.
	if root is BuiltMap and (root as BuiltMap).queue_trees(trees):
		return
	var holder := Node3D.new()
	holder.name = "Forest"
	root.add_child(holder)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var near_range: float = NEAR_RANGE[clampi(Settings.graphics_quality, 0, 2)]
	var chunks: Dictionary = {}
	var far: Dictionary = {}
	for t in trees:
		var p: Vector3 = t[0]
		var sp: int = _species(t[1], p)
		var key := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
		if not chunks.has(key):
			chunks[key] = {}
		if not chunks[key].has(sp):
			chunks[key][sp] = []
		var sc: float = t[2]
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), p)
		var tint: float = rng.randf_range(0.85, 1.12)
		var col := Color(tint * rng.randf_range(0.94, 1.06), tint, tint * rng.randf_range(0.9, 1.04))
		chunks[key][sp].append([xf, col, sc, p])
		var fk := Vector2i(floori(p.x / FAR_CHUNK), floori(p.z / FAR_CHUNK))
		if not far.has(fk):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			far[fk] = st
		far[fk].append_from(_far_mesh(sp), 0, xf)
	for key in chunks:
		var body := StaticBody3D.new()
		holder.add_child(body)
		for sp in chunks[key]:
			var list: Array = chunks[key][sp]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true
			mm.mesh = _near_mesh(sp)
			mm.instance_count = list.size()
			for i in range(list.size()):
				mm.set_instance_transform(i, list[i][0])
				mm.set_instance_color(i, list[i][1])
				_collider(body, list[i][3], sp, list[i][2])
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			# Only a coarse cut per chunk (its centre can be ~90 m from its
			# corner trees); the shader cuts each tree at near_range.
			mmi.material_override = near_material()
			mmi.visibility_range_end = near_range + CHUNK_SLACK
			mmi.visibility_range_end_margin = 20.0
			mmi.set_meta("geo_detail", true) # keeps its own range (Settings)
			holder.add_child(mmi)
	for fk in far:
		var mesh: ArrayMesh = far[fk].commit()
		mesh.surface_set_material(0, _material())
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.set_meta("geo_detail", true)
		holder.add_child(mi)

## Which species a tree of `kind` becomes - fixed by its position, so a
## map looks the same every load.
static func _species(kind: int, p: Vector3) -> int:
	var h: float = fposmod(sin(p.x * 12.9898 + p.z * 78.233) * 43758.5453, 1.0)
	if kind == 0:
		return SPRUCE if h < 0.7 else PINE
	return BROAD if h < 0.62 else (BIRCH if h < 0.86 else POPLAR)

static func _collider(body: StaticBody3D, pos: Vector3, sp: int, sc: float) -> void:
	var s: Array = SHAPE[sp]
	var trunk := CylinderShape3D.new()
	trunk.radius = 0.3 * sc
	trunk.height = s[0] * sc
	var cs := CollisionShape3D.new()
	cs.shape = trunk
	cs.position = pos + Vector3(0, s[0] * 0.5 * sc, 0)
	body.add_child(cs)
	var crown := CylinderShape3D.new()
	crown.radius = s[1] * sc
	crown.height = s[3] * sc
	var cc := CollisionShape3D.new()
	cc.shape = crown
	cc.position = pos + Vector3(0, s[2] * sc, 0)
	body.add_child(cc)

static var _near_mat: ShaderMaterial

## The full trees' material: the same, but each tree drawn only within
## sh_tree_near (Settings sets it per quality).
static func near_material() -> ShaderMaterial:
	if _near_mat == null:
		_near_mat = _material().duplicate() as ShaderMaterial
		_near_mat.set_shader_parameter("near_only", true)
	return _near_mat

static func _material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/tree.gdshader")
		_mat.set_shader_parameter("leaves", MapTextures.get_tex("foliage"))
		_mat.set_shader_parameter("bark", MapTextures.get_tex("bark"))
	return _mat

# --- meshes ------------------------------------------------------------------
# Built with a SurfaceTool: vertex colour = species colour x ambient
# occlusion (darker inside the crown and toward the ground), alpha 1 for
# foliage / 0 for bark.

const LEAF := {SPRUCE: Color(0.14, 0.26, 0.15), PINE: Color(0.17, 0.27, 0.15), BROAD: Color(0.25, 0.37, 0.13),
	BIRCH: Color(0.36, 0.47, 0.17), POPLAR: Color(0.2, 0.33, 0.12)}
const BARK := {SPRUCE: Color(0.33, 0.25, 0.19), PINE: Color(0.62, 0.38, 0.22), BROAD: Color(0.36, 0.31, 0.26),
	BIRCH: Color(0.86, 0.85, 0.8), POPLAR: Color(0.42, 0.4, 0.34)}

static func _near_mesh(sp: int) -> ArrayMesh:
	if _near.has(sp):
		return _near[sp]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + sp
	match sp:
		SPRUCE:
			_trunk(st, Vector3.ZERO, Vector3(0, 15.5, 0), 0.32, 0.06, BARK[sp])
			var tiers: int = 10
			for i in range(tiers):
				var f: float = float(i) / (tiers - 1)
				var y: float = lerpf(2.2, 13.6, f)
				var r: float = lerpf(2.7, 0.75, f) * rng.randf_range(0.9, 1.08)
				_skirt(st, y, y + lerpf(2.4, 1.6, f), r, 9, rng.randf() * TAU, lerpf(0.9, 0.35, f), LEAF[sp], f, rng)
			_skirt(st, 14.8, 16.6, 0.5, 6, 0.0, 0.2, LEAF[sp], 1.0, rng)
		PINE:
			_trunk(st, Vector3.ZERO, Vector3(0.25, 15.0, 0.1), 0.3, 0.12, BARK[sp])
			for i in range(4):
				var a: float = TAU * i / 4.0 + rng.randf_range(-0.4, 0.4)
				var tip := Vector3(cos(a) * 2.0, rng.randf_range(12.0, 14.2), sin(a) * 2.0)
				_trunk(st, Vector3(0.15, tip.y - 2.2, 0.05), tip, 0.12, 0.05, BARK[sp])
				_blob(st, tip + Vector3(0, 0.6, 0), Vector3(1.9, 1.0, 1.9), LEAF[sp], Vector3(0, 13.8, 0), 12.0, 3.2, rng)
			_blob(st, Vector3(0.2, 15.4, 0.1), Vector3(1.7, 1.1, 1.7), LEAF[sp], Vector3(0, 13.8, 0), 12.0, 3.2, rng)
		BROAD:
			_trunk(st, Vector3.ZERO, Vector3(0, 5.0, 0), 0.38, 0.26, BARK[sp])
			var centre := Vector3(0, 8.2, 0)
			_blob(st, centre + Vector3(0, 0.6, 0), Vector3(2.9, 2.6, 2.9), LEAF[sp], centre, 4.5, 4.2, rng)
			for i in range(6):
				var a: float = TAU * i / 6.0 + rng.randf_range(-0.3, 0.3)
				var c := Vector3(cos(a) * rng.randf_range(2.1, 2.8), rng.randf_range(6.6, 9.4), sin(a) * rng.randf_range(2.1, 2.8))
				_trunk(st, Vector3(0, 4.2 + rng.randf() * 0.8, 0), c * Vector3(0.75, 0.92, 0.75), 0.17, 0.07, BARK[sp])
				_blob(st, c, Vector3.ONE * rng.randf_range(1.7, 2.2), LEAF[sp], centre, 4.5, 4.2, rng)
		BIRCH:
			_trunk(st, Vector3.ZERO, Vector3(0.2, 13.0, 0), 0.2, 0.05, BARK[sp])
			for i in range(6):
				var y: float = lerpf(5.6, 12.4, i / 5.0)
				var a: float = i * 2.4
				var c := Vector3(cos(a) * 0.9, y, sin(a) * 0.9)
				_blob(st, c, Vector3(1.6, 1.4, 1.6) * lerpf(1.1, 0.7, i / 5.0), LEAF[sp], Vector3(0, 9.0, 0), 5.0, 2.3, rng)
		POPLAR:
			_trunk(st, Vector3.ZERO, Vector3(0, 16.0, 0), 0.3, 0.06, BARK[sp])
			for i in range(8):
				var y: float = lerpf(4.0, 17.0, i / 7.0)
				var a: float = i * 2.1
				var c := Vector3(cos(a) * 0.5, y, sin(a) * 0.5)
				_blob(st, c, Vector3(1.6, 2.2, 1.6) * lerpf(1.0, 0.6, i / 7.0), LEAF[sp], Vector3(0, 10.5, 0), 3.0, 1.9, rng)
	var mesh: ArrayMesh = st.commit()
	mesh.surface_set_material(0, _material())
	_near[sp] = mesh
	return mesh

static func _far_mesh(sp: int) -> ArrayMesh:
	if _far.has(sp):
		return _far[sp]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 40 + sp
	var dark: Color = LEAF[sp] * 0.82
	match sp:
		SPRUCE:
			_trunk(st, Vector3.ZERO, Vector3(0, 3.0, 0), 0.3, 0.25, BARK[sp], 4)
			_skirt(st, 1.8, 16.0, 2.2, 6, 0.0, 0.0, dark, 0.5, rng, false)
		PINE:
			_trunk(st, Vector3.ZERO, Vector3(0.2, 13.0, 0), 0.28, 0.15, BARK[sp], 4)
			_blob(st, Vector3(0.1, 14.2, 0), Vector3(2.6, 1.4, 2.6), dark, Vector3(0, 14, 0), 1.0, 3.0, rng, 0)
		_:
			var s: Array = SHAPE[sp]
			_trunk(st, Vector3.ZERO, Vector3(0, s[2] - s[3] * 0.3, 0), 0.3, 0.2, BARK[sp], 4)
			_blob(st, Vector3(0, s[2], 0), Vector3(s[1] * 0.8, s[3] * 0.42, s[1] * 0.8), dark, Vector3(0, s[2], 0), s[3] * 0.6, s[1], rng, 0)
	var mesh: ArrayMesh = st.commit()
	_far[sp] = mesh
	return mesh

static func _vert(st: SurfaceTool, p: Vector3, n: Vector3, c: Color) -> void:
	st.set_normal(n)
	st.set_color(c)
	st.add_vertex(p)

## A tapered trunk or branch from a to b (bark).
static func _trunk(st: SurfaceTool, a: Vector3, b: Vector3, r0: float, r1: float, col: Color, sides: int = 7) -> void:
	var axis: Vector3 = (b - a).normalized()
	var side: Vector3 = axis.cross(Vector3.RIGHT if absf(axis.x) < 0.9 else Vector3.FORWARD).normalized()
	var up: Vector3 = axis.cross(side)
	var c := Color(col.r, col.g, col.b, 0.0)
	for i in range(sides):
		var a0: float = TAU * i / sides
		var a1: float = TAU * (i + 1) / sides
		var d0: Vector3 = side * cos(a0) + up * sin(a0)
		var d1: Vector3 = side * cos(a1) + up * sin(a1)
		var cb := c * 0.7
		cb.a = 0.0
		_vert(st, a + d0 * r0, d0, cb)
		_vert(st, b + d1 * r1, d1, c)
		_vert(st, a + d1 * r0, d1, cb)
		_vert(st, a + d0 * r0, d0, cb)
		_vert(st, b + d0 * r1, d0, c)
		_vert(st, b + d1 * r1, d1, c)

## One tier of spruce branches: a star-shaped, drooping skirt from the
## trunk at y0 up to its tip at y1 - `points` branch tips, dipping by
## `droop` at their ends, with a darker underside.
static func _skirt(st: SurfaceTool, y0: float, y1: float, r: float, points: int, rot: float, droop: float, col: Color, f: float, rng: RandomNumberGenerator, jagged: bool = true) -> void:
	var rim: Array[Vector3] = []
	var n: int = points * 2 if jagged else points
	for k in range(n):
		var a: float = rot + TAU * k / n
		var outer: bool = (k % 2 == 0) or not jagged
		var rr: float = r * (rng.randf_range(0.88, 1.1) if outer else 0.58)
		rim.append(Vector3(cos(a) * rr, y0 - (droop if outer else droop * 0.3), sin(a) * rr))
	var apex := Vector3(0, y1, 0)
	var under := Vector3(0, y0 + (y1 - y0) * 0.25, 0)
	var top := Color(col.r, col.g, col.b, 1.0) * lerpf(0.85, 1.05, f)
	top.a = 1.0
	var low := col * 0.45
	low.a = 1.0
	for k in range(n):
		var p0: Vector3 = rim[k]
		var p1: Vector3 = rim[(k + 1) % n]
		var n0 := Vector3(p0.x, r * 0.9, p0.z).normalized()
		var n1 := Vector3(p1.x, r * 0.9, p1.z).normalized()
		_vert(st, apex, Vector3.UP, top * 1.1)
		_vert(st, p1, n1, top)
		_vert(st, p0, n0, top)
		_vert(st, under, Vector3.DOWN, low * 0.8)
		_vert(st, p0, Vector3(p0.x, -r, p0.z).normalized(), low)
		_vert(st, p1, Vector3(p1.x, -r, p1.z).normalized(), low)

## A lumpy leaf mass: a jittered icosphere (`subdiv` 1 = 80 faces) at c
## with radii rad. Normals blend the blob's own with the direction from
## the whole crown's centre - the soft round shading real crowns have.
## Darker toward the crown's inside and bottom (ambient occlusion).
static func _blob(st: SurfaceTool, c: Vector3, rad: Vector3, col: Color, crown: Vector3, crown_h: float, crown_r: float, rng: RandomNumberGenerator, subdiv: int = 1) -> void:
	var ico: Array = _ico(subdiv)
	var verts: PackedVector3Array = ico[0]
	var pts: Array[Vector3] = []
	var nrm: Array[Vector3] = []
	var cols: Array[Color] = []
	for v in verts:
		var p: Vector3 = c + v * rad * rng.randf_range(0.82, 1.12)
		pts.append(p)
		var away: Vector3 = (p - crown).normalized()
		nrm.append((v * 0.45 + away * 0.55).normalized())
		var hf: float = clampf((p.y - (crown.y - crown_h * 0.5)) / crown_h, 0.0, 1.0)
		var rf: float = clampf(Vector2(p.x - crown.x, p.z - crown.z).length() / crown_r, 0.0, 1.0)
		var ao: float = lerpf(0.55, 1.0, hf) * lerpf(0.72, 1.05, rf)
		var cc: Color = col * ao
		cc.a = 1.0
		cols.append(cc)
	for f in ico[1]:
		for i in [f.x, f.z, f.y]:
			_vert(st, pts[i], nrm[i], cols[i])

static var _icos: Dictionary = {}

## Unit icosphere: [vertices, faces (Vector3i)], subdivided `subdiv` times.
static func _ico(subdiv: int) -> Array:
	if _icos.has(subdiv):
		return _icos[subdiv]
	var t: float = (1.0 + sqrt(5.0)) / 2.0
	var v := PackedVector3Array([Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0),
		Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t),
		Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)])
	for i in range(v.size()):
		v[i] = v[i].normalized()
	var f: Array[Vector3i] = [Vector3i(0, 11, 5), Vector3i(0, 5, 1), Vector3i(0, 1, 7), Vector3i(0, 7, 10), Vector3i(0, 10, 11),
		Vector3i(1, 5, 9), Vector3i(5, 11, 4), Vector3i(11, 10, 2), Vector3i(10, 7, 6), Vector3i(7, 1, 8),
		Vector3i(3, 9, 4), Vector3i(3, 4, 2), Vector3i(3, 2, 6), Vector3i(3, 6, 8), Vector3i(3, 8, 9),
		Vector3i(4, 9, 5), Vector3i(2, 4, 11), Vector3i(6, 2, 10), Vector3i(8, 6, 7), Vector3i(9, 8, 1)]
	for _s in range(subdiv):
		var mid: Dictionary = {}
		var nf: Array[Vector3i] = []
		for tri in f:
			var m: Array[int] = []
			for e in [[tri.x, tri.y], [tri.y, tri.z], [tri.z, tri.x]]:
				var key := Vector2i(mini(e[0], e[1]), maxi(e[0], e[1]))
				if not mid.has(key):
					v.append(((v[e[0]] + v[e[1]]) * 0.5).normalized())
					mid[key] = v.size() - 1
				m.append(mid[key])
			nf.append(Vector3i(tri.x, m[0], m[2]))
			nf.append(Vector3i(tri.y, m[1], m[0]))
			nf.append(Vector3i(tri.z, m[2], m[1]))
			nf.append(Vector3i(m[0], m[1], m[2]))
		f = nf
	_icos[subdiv] = [v, f]
	return _icos[subdiv]
