class_name LightBaker
extends RefCounted

## Bakes the sun into the hand-made maps (village, factory, school) at
## load time: every lit StandardMaterial3D mesh gets per-vertex light
## (Geo.shade - ambient + sky fill + sun * N.L, darkening toward the
## ground) and an unshaded copy of its material.
##
## Why: the engine's DirectionalLight3D has no effect whatsoever on the
## dev machine (Intel Iris 6100, macOS, Compatibility renderer) -
## measured 2026-09-27: identical screenshots at sun energy 0 and 3 in
## the factory map. Every map was lit by ambient light alone: flat, and
## sun-facing and shaded sides looked the same. Baking is GPU-independent
## and free per frame. Unshaded materials, glow materials, the drone and
## generated (Geo) maps are left alone.

static func bake(root: Node, sun: DirectionalLight3D, ground_y: float, ambient: float = 0.45, sun_strength: float = 0.55) -> void:
	var g := Geo.new()
	g.sun_dir = -sun.global_transform.basis.z
	g.sun = sun_strength
	g.sun_tint = sun.light_color
	g.ambient = ambient
	g.ao_ground_y = ground_y
	g.ao_height = 2.5
	g.ao_min = 0.7
	var cache: Dictionary = {}
	_walk(root, g, cache)

static func _walk(node: Node, g: Geo, cache: Dictionary) -> void:
	if node is Drone or node is CanvasLayer:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null and not node.has_meta("geo_batch"):
		_bake_instance(node, g, cache)
	for child in node.get_children():
		_walk(child, g, cache)

static func _bake_instance(mi: MeshInstance3D, g: Geo, cache: Dictionary) -> void:
	var mesh: Mesh = mi.mesh
	var xf: Transform3D = mi.global_transform
	var nbasis: Basis = xf.basis.inverse().transposed()
	var baked := ArrayMesh.new()
	var any: bool = false
	var mats: Array[Material] = []
	for s in range(mesh.get_surface_count()):
		var mat: Material = mi.material_override
		if mat == null and s < mi.get_surface_override_material_count():
			mat = mi.get_surface_override_material(s)
		if mat == null:
			mat = mesh.surface_get_material(s)
		var arrays: Array = mesh.surface_get_arrays(s)
		var sm := mat as StandardMaterial3D
		if sm != null and sm.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and not sm.emission_enabled and arrays[Mesh.ARRAY_NORMAL] != null:
			var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var old = arrays[Mesh.ARRAY_COLOR]
			var use_old: bool = sm.vertex_color_use_as_albedo and old != null
			var colors := PackedColorArray()
			colors.resize(verts.size())
			for i in range(verts.size()):
				var c: Color = g.shade((nbasis * normals[i]).normalized(), (xf * verts[i]).y)
				if use_old:
					c *= old[i]
				colors[i] = c
			arrays[Mesh.ARRAY_COLOR] = colors
			if not cache.has(sm):
				var u: StandardMaterial3D = sm.duplicate()
				u.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				u.vertex_color_use_as_albedo = true
				cache[sm] = u
			mat = cache[sm]
			any = true
		baked.add_surface_from_arrays((mesh as ArrayMesh).surface_get_primitive_type(s) if mesh is ArrayMesh else Mesh.PRIMITIVE_TRIANGLES, arrays)
		mats.append(mat)
	if not any:
		return
	for s in range(mats.size()):
		baked.surface_set_material(s, mats[s])
	mi.material_override = null
	mi.mesh = baked
	for s in range(mi.get_surface_override_material_count()):
		mi.set_surface_override_material(s, null)
