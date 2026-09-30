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
	var holder := Node3D.new()
	holder.name = "Terrain"
	root.add_child(holder)
	for cz in range(0, nz - 1, chunk_cells):
		for cx in range(0, nx - 1, chunk_cells):
			holder.add_child(_chunk(rect, spacing, h, nx, nz, cx, cz, mini(cx + chunk_cells, nx - 1), mini(cz + chunk_cells, nz - 1), mat, shade))
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

static func _chunk(rect: Rect2, s: float, h: PackedFloat32Array, nx: int, nz: int, x0: int, z0: int, x1: int, z1: int, mat: Material, shade: Callable) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for iz in range(z0, z1):
		for ix in range(x0, x1):
			var q: Array[Vector3] = [_p(rect, s, h, nx, ix, iz), _p(rect, s, h, nx, ix + 1, iz), _p(rect, s, h, nx, ix + 1, iz + 1), _p(rect, s, h, nx, ix, iz + 1)]
			for idx in [0, 1, 2, 0, 2, 3]: # clockwise from above = front (see Geo)
				var v: Vector3 = q[idx]
				var gx: int = ix + (1 if idx == 1 or idx == 2 else 0)
				var gz: int = iz + (1 if idx >= 2 else 0)
				var nrm: Vector3 = _normal(h, nx, nz, gx, gz, s)
				st.set_normal(nrm)
				st.set_color(shade.call(nrm, v))
				st.add_vertex(v)
	var mesh: ArrayMesh = st.commit()
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
