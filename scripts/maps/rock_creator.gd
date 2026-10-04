class_name RockCreator
extends RefCounted

## Creator: boulders and stones - a handful of faceted shapes built once,
## drawn as MultiMesh (like TreeCreator's trees: one draw call per shape
## and 128 m chunk), each turned and sized, half buried in the ground,
## solid (a convex hull per shape and size, shared).
##
##   RockCreator.scatter(map, geo, land, rng, areas, avoid) -> {"placed": n, "views": [...]}
## areas: [centre: Vector2, radius, count, smallest, biggest] (sizes in m
## across); most rocks come out small, a few big. avoid: polygons (fields)
## kept free. Roads, water, levelled ground (plots, yards, the green) and
## anything already standing are kept free too; call before the trees,
## which then keep off the rocks.

const VARIANTS: int = 6
const CHUNK: float = 128.0
const RANGE: float = 500.0
static var _meshes: Array = []
static var _hulls: Array = []
static var _shapes: Dictionary = {}
static var _mat: ShaderMaterial

static func scatter(map: Node3D, geo: Geo, land: TerrainCreator, rng: RandomNumberGenerator, areas: Array, avoid: Array = []) -> Dictionary:
	_ensure_meshes()
	var chunks: Dictionary = {}
	var placed: int = 0
	var views: Array = []
	for ar: Array in areas:
		var centre: Vector2 = ar[0]
		var radius: float = ar[1]
		var tries: int = 0
		var n: int = 0
		var biggest: Array = [0.0, Vector2.ZERO, 0.0]
		while n < ar[2] and tries < ar[2] * 6:
			tries += 1
			var a: float = rng.randf() * TAU
			var q: Vector2 = centre + Vector2(cos(a), sin(a)) * radius * sqrt(rng.randf())
			var size: float = lerpf(ar[3], ar[4], pow(rng.randf(), 2.4))
			var r: float = size * 0.5
			var free: bool = not land.on_line(q.x, q.y, r + 2.0) and not land.in_pond(q.x, q.y, r + 2.0) and land.flatness(q.x, q.y) < 0.3 and not geo.on_lane(q, r + 1.5)
			for poly: PackedVector2Array in avoid:
				if free and Geometry2D.is_point_in_polygon(q, poly):
					free = false
			if not free:
				continue
			var lo: float = INF
			for o: Vector2 in [Vector2.ZERO, Vector2(r, 0), Vector2(-r, 0), Vector2(0, r), Vector2(0, -r)]:
				lo = minf(lo, land.ground(q.x + o.x, q.y + o.y))
			if geo.blocked(q, r, lo + 0.2, lo + size):
				continue
			var vi: int = rng.randi() % VARIANTS
			var sc: float = snappedf(size, 0.1)
			var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * sc), Vector3(q.x, lo, q.y))
			var key := Vector2i(floori(q.x / CHUNK), floori(q.y / CHUNK))
			if not chunks.has(key):
				chunks[key] = []
			chunks[key].append([xf, vi])
			geo.reserve(q, Vector2(1, 0), Vector2(r * 0.8, r * 0.8), lo, lo + size * 0.6)
			n += 1
			placed += 1
			if size > biggest[0]:
				biggest = [size, q, lo]
		if biggest[0] > 1.8:
			var bq: Vector2 = biggest[1]
			var bs: float = biggest[0]
			views.append(["rocks_%d" % views.size(), Vector3(bq.x + bs * 2.2 + 2.0, biggest[2] + bs * 0.9 + 0.8, bq.y + bs * 2.2 + 2.0), Vector3(bq.x, biggest[2] + bs * 0.3, bq.y)])
	var holder := Node3D.new()
	holder.name = "Rocks"
	map.add_child(holder)
	for key in chunks:
		var body := StaticBody3D.new()
		holder.add_child(body)
		var by_variant: Dictionary = {}
		for e: Array in chunks[key]:
			if not by_variant.has(e[1]):
				by_variant[e[1]] = []
			by_variant[e[1]].append(e[0])
			_collider(body, e[0], e[1])
		for vi: int in by_variant:
			var list: Array = by_variant[vi]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.use_colors = true # (the compatibility renderer multiplies it in either way)
			mm.mesh = _meshes[vi]
			mm.instance_count = list.size()
			for i in range(list.size()):
				mm.set_instance_transform(i, list[i])
				mm.set_instance_color(i, Color.WHITE)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.visibility_range_end = RANGE
			mmi.visibility_range_end_margin = 30.0
			mmi.set_meta("geo_detail", true)
			holder.add_child(mmi)
	return {"placed": placed, "views": views}

static func _collider(body: StaticBody3D, xf: Transform3D, vi: int) -> void:
	var sc: float = snappedf(xf.basis.get_scale().x, 0.1)
	var key: String = "%d@%.1f" % [vi, sc]
	if not _shapes.has(key):
		var sp := ConvexPolygonShape3D.new()
		var scaled := PackedVector3Array()
		for q: Vector3 in _hulls[vi]:
			scaled.append(q * sc)
		sp.points = scaled
		_shapes[key] = sp
	var owner: int = body.create_shape_owner(body)
	body.shape_owner_add_shape(owner, _shapes[key])
	body.shape_owner_set_transform(owner, Transform3D(xf.basis.orthonormalized(), xf.origin))

## The shapes: an icosphere, its corners pushed in and out by noise,
## squashed, the bottom flattened - unit size (1 m across), origin on the
## ground with a third of it below. Faceted (flat faces): a weathered
## boulder from a drone. Vertex colour: the stone's tint, darker low
## down, moss on some of the upward faces.
static func _ensure_meshes() -> void:
	if not _meshes.is_empty():
		return
	_mat = ShaderMaterial.new()
	_mat.shader = load("res://shaders/rock.gdshader")
	_mat.set_shader_parameter("tex", MapTextures.get_tex("rock"))
	var base: Array = _icosphere()
	var verts: Array = base[0]
	var faces: Array = base[1]
	for vi in range(VARIANTS):
		var noise := FastNoiseLite.new()
		noise.seed = 700 + vi
		noise.frequency = 1.3
		var rng := RandomNumberGenerator.new()
		rng.seed = 900 + vi
		var squash: float = rng.randf_range(0.5, 0.78)
		var stretch: float = rng.randf_range(1.0, 1.35)
		var tint := Color(0.92, 0.9, 0.86) * rng.randf_range(0.85, 1.08)
		var moved: Array = []
		var hull := PackedVector3Array()
		for v: Vector3 in verts:
			var k: float = 1.0 + 0.32 * noise.get_noise_3dv(v * 1.7)
			var q := Vector3(v.x * stretch, v.y * squash, v.z) * k * 0.5
			q.y = maxf(q.y, -0.3 * squash) + 0.12 # flat bottom, a third under ground
			moved.append(q)
			hull.append(q)
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f: Array in faces:
			var a: Vector3 = moved[f[0]]
			var b: Vector3 = moved[f[1]]
			var c: Vector3 = moved[f[2]]
			var n: Vector3 = (b - a).cross(c - a).normalized()
			if n.dot((a + b + c) / 3.0 - Vector3(0, 0.05, 0)) < 0.0:
				n = -n # outward
			if (b - a).cross(c - a).dot(n) > 0.0:
				var sw: Vector3 = b # Godot's front face winds the other way (as Geo._tri)
				b = c
				c = sw
			var moss: bool = n.y > 0.55 and rng.randf() < 0.45
			for p: Vector3 in [a, b, c]:
				var ao: float = lerpf(0.55, 1.0, clampf((p.y + 0.15) / 0.45, 0.0, 1.0))
				var col: Color = tint.lerp(Color(0.42, 0.5, 0.26), 0.55) if moss else tint
				st.set_color(Color(col.r * ao, col.g * ao, col.b * ao, 1.0))
				st.set_normal(n)
				st.add_vertex(p)
		var mesh: ArrayMesh = st.commit()
		mesh.surface_set_material(0, _mat)
		_meshes.append(mesh)
		_hulls.append(hull)

## Unit icosphere subdivided once: [vertices, faces (index triples,
## counter-clockwise from outside)].
static func _icosphere() -> Array:
	var t: float = (1.0 + sqrt(5.0)) * 0.5
	var v: Array = []
	for p in [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t),
			Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]:
		v.append(p.normalized())
	var f: Array = [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8],
		[3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	var mid: Dictionary = {}
	var half := func(a: int, b: int) -> int:
		var key := Vector2i(mini(a, b), maxi(a, b))
		if not mid.has(key):
			v.append(((v[a] as Vector3) + v[b]).normalized())
			mid[key] = v.size() - 1
		return mid[key]
	var out: Array = []
	for tri: Array in f:
		var ab: int = half.call(tri[0], tri[1])
		var bc: int = half.call(tri[1], tri[2])
		var ca: int = half.call(tri[2], tri[0])
		out.append_array([[tri[0], ab, ca], [tri[1], bc, ab], [tri[2], ca, bc], [ab, bc, ca]])
	return [v, out]
