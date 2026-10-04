class_name Terrain
extends RefCounted

## A heightfield ground: chunked meshes (so they frustum-cull) plus one
## HeightMapShape3D for collision. `height` is any Callable(x, z) ->
## float, so each map shapes its own land (flat where the buildings
## stand, hills beyond).

## shade: Callable(normal, position) -> Color - the baked light
## (Geo.shade) times whatever tint the map wants there (rock on steep
## faces, grass on flats, snow up high...).
static func build(root: Node3D, rect: Rect2, spacing: float, height: Callable, mat: Material, shade: Callable, chunk_cells: int = 32, collide: bool = true) -> void:
	var nx: int = int(rect.size.x / spacing) + 1
	var nz: int = int(rect.size.y / spacing) + 1
	var h := PackedFloat32Array()
	h.resize(nx * nz)
	for iz in range(nz):
		for ix in range(nx):
			h[iz * nx + ix] = height.call(rect.position.x + ix * spacing, rect.position.y + iz * spacing)
	# Normal and light once per grid point (each is shared by up to six
	# triangle corners).
	var nrms := PackedVector3Array()
	var cols := PackedColorArray()
	nrms.resize(nx * nz)
	cols.resize(nx * nz)
	for iz in range(nz):
		for ix in range(nx):
			var i: int = iz * nx + ix
			nrms[i] = _normal(h, nx, nz, ix, iz, spacing)
			cols[i] = shade.call(nrms[i], _p(rect, spacing, h, nx, ix, iz))
	var holder := Node3D.new()
	holder.name = "Terrain"
	root.add_child(holder)
	for cz in range(0, nz - 1, chunk_cells):
		for cx in range(0, nx - 1, chunk_cells):
			holder.add_child(_chunk(rect, spacing, h, nx, nrms, cols, cx, cz, mini(cx + chunk_cells, nx - 1), mini(cz + chunk_cells, nz - 1), mat))
	if not collide:
		return
	# Collision: HeightMapShape3D samples are 1 unit apart, so the shape is
	# scaled up uniformly by `spacing` (and the heights down by it).
	var data := PackedFloat32Array()
	data.resize(h.size())
	for i in range(h.size()):
		data[i] = h[i] / spacing
	var shape := HeightMapShape3D.new()
	shape.map_width = nx
	shape.map_depth = nz
	shape.map_data = data
	var body := StaticBody3D.new()
	body.name = "TerrainCollision"
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.scale = Vector3.ONE * spacing
	body.add_child(cs)
	body.position = Vector3(rect.position.x + (nx - 1) * spacing * 0.5, 0.0, rect.position.y + (nz - 1) * spacing * 0.5)
	holder.add_child(body)

## A coarse, collision-free ring of terrain far out to the horizon (the
## High maps have little fog, so a hard map edge would show). Inside
## `inner` it sits 30 m down, under the detailed terrain; in a one-cell
## margin round it, 1.5 m down so the detailed terrain wins where they
## overlap.
static func far_ring(root: Node3D, inner: Rect2, outer: Rect2, spacing: float, height: Callable, mat: Material, shade: Callable) -> void:
	var margin: float = spacing * 1.5
	var core: Rect2 = inner.grow(-margin)
	var h := func(x: float, z: float) -> float:
		var p := Vector2(x, z)
		if core.has_point(p):
			return height.call(x, z) - 30.0
		if inner.has_point(p):
			return height.call(x, z) - 1.5
		return height.call(x, z)
	build(root, outer, spacing, h, mat, shade, 16, false)

## One chunk as an indexed mesh: a vertex per grid point (normal and
## light from the shared arrays), two triangles per cell.
static func _chunk(rect: Rect2, s: float, h: PackedFloat32Array, nx: int, nrms: PackedVector3Array, cols: PackedColorArray, x0: int, z0: int, x1: int, z1: int, mat: Material) -> MeshInstance3D:
	var w: int = x1 - x0 + 1
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for iz in range(z0, z1 + 1):
		for ix in range(x0, x1 + 1):
			var i: int = iz * nx + ix
			verts.append(Vector3(rect.position.x + ix * s, h[i], rect.position.y + iz * s))
			normals.append(nrms[i])
			colors.append(cols[i])
	var idx := PackedInt32Array()
	for cz in range(z1 - z0):
		for cx in range(x1 - x0):
			var a: int = cz * w + cx
			# Split along the 10-01 diagonal, the way HeightMapShape3D splits
			# its cells - otherwise collision and the visible ground disagree
			# by up to half a cell's curvature, and a crashed drone ends up
			# resting under the visible ground. Clockwise from above = front.
			idx.append_array([a, a + 1, a + w, a + 1, a + w + 1, a + w])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.set_meta("geo_batch", true)
	return mi

static func _p(rect: Rect2, s: float, h: PackedFloat32Array, nx: int, ix: int, iz: int) -> Vector3:
	return Vector3(rect.position.x + ix * s, h[iz * nx + ix], rect.position.y + iz * s)

static func _normal(h: PackedFloat32Array, nx: int, nz: int, ix: int, iz: int, s: float) -> Vector3:
	var l: float = h[iz * nx + maxi(ix - 1, 0)]
	var r: float = h[iz * nx + mini(ix + 1, nx - 1)]
	var d: float = h[maxi(iz - 1, 0) * nx + ix]
	var u: float = h[mini(iz + 1, nz - 1) * nx + ix]
	return Vector3(l - r, 2.0 * s, d - u).normalized()
