class_name TextCheck
extends RefCounted

## Text on walls and signs (Label3D) must lie flat on what carries it:
## every point of the text's area has a solid surface right behind it,
## no more than GAP behind the text. Rays from a grid over each label
## (2026-10-14: the user saw bando graffiti standing off its wall and
## sign text running past the sign). Tests the visible meshes, not the
## collision (many sign boards don't collide).
##   TextCheck.run(scene) -> [[text, position, problem], ...]

const GAP: float = 0.04 ## text may stand this far in front of its surface
const REACH: float = 0.3 ## rays start this far in front, end this far behind

static func run(root: Node) -> Array:
	var out: Array = []
	if not root is Node3D:
		return out
	# The visible surfaces (sign boards often have no collision): every
	# mesh's triangles near a label, in world space.
	var meshes: Array = [] # [MeshInstance3D, global AABB]
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree() or (mi.layers & (1 << 19)) != 0:
			continue
		meshes.append([mi, mi.global_transform * mi.get_aabb()])
	var cache: Dictionary = {} # MeshInstance3D -> PackedVector3Array (world triangles)
	for n in root.find_children("*", "Label3D", true, false):
		var lb := n as Label3D
		if lb.billboard != BaseMaterial3D.BILLBOARD_DISABLED or not lb.is_visible_in_tree() or lb.text.strip_edges() == "":
			continue
		if lb.has_meta("free_text"): # meant to hang in the air (none yet)
			continue
		var bb: AABB = lb.get_aabb()
		if bb.size.x < 0.01 or bb.size.y < 0.01:
			continue
		var xf: Transform3D = lb.global_transform
		var nrm: Vector3 = xf.basis.z.normalized()
		var box: AABB = (xf * bb).grow(REACH + 0.05)
		var tris := PackedVector3Array()
		for e: Array in meshes:
			if not (e[1] as AABB).intersects(box):
				continue
			if not cache.has(e[0]):
				cache[e[0]] = _world_tris(e[0])
			var all: PackedVector3Array = cache[e[0]]
			for t in range(0, all.size(), 3):
				var tb := AABB(all[t], Vector3.ZERO).expand(all[t + 1]).expand(all[t + 2])
				if tb.intersects(box):
					tris.append(all[t]); tris.append(all[t + 1]); tris.append(all[t + 2])
		var air: int = 0
		var off: int = 0
		var far: float = 0.0
		for i in range(5):
			for j in range(3):
				var p: Vector3 = xf * Vector3(bb.position.x + bb.size.x * (0.08 + 0.84 * i / 4.0), bb.position.y + bb.size.y * (0.15 + 0.7 * j / 2.0), 0.0)
				# The nearest surface behind (or just in front of) the text.
				var best: float = INF
				for t in range(0, tris.size(), 3):
					var h: Variant = Geometry3D.segment_intersects_triangle(p + nrm * REACH, p - nrm * REACH, tris[t], tris[t + 1], tris[t + 2])
					if h != null:
						var behind: float = -((h as Vector3) - p).dot(nrm)
						if behind > -GAP and behind < best:
							best = behind
				if best == INF:
					air += 1
				elif best > GAP:
					off += 1
					far = maxf(far, best)
		if air > 0:
			out.append([lb.text, lb.global_position, "%d of 15 points over nothing" % air])
		elif off > 0:
			out.append([lb.text, lb.global_position, "%d of 15 points %.2f m off the surface" % [off, far]])
	# Painted spots (BuiltMap.decal_spots): the wall right behind the
	# whole area - rays against the collision (walls collide).
	if root is BuiltMap and not (root as BuiltMap).decal_spots.is_empty():
		var space: PhysicsDirectSpaceState3D = (root as Node3D).get_world_3d().direct_space_state
		for e: Array in (root as BuiltMap).decal_spots:
			var p: Vector3 = e[0]
			var nrm: Vector3 = (e[1] as Vector3).normalized()
			var side: Vector3 = Vector3.UP.cross(nrm).normalized()
			var air: int = 0
			var off: int = 0
			var far: float = 0.0
			for i in range(5):
				for j in range(3):
					var q: Vector3 = p + side * (e[2] as float) * (-0.45 + 0.9 * i / 4.0) + Vector3.UP * (e[3] as float) * (-0.4 + 0.8 * j / 2.0)
					var h: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(q + nrm * REACH, q - nrm * REACH))
					if h.is_empty():
						air += 1
						continue
					var behind: float = -(h.position - q).dot(nrm)
					if absf(behind) > 0.02:
						off += 1
						if absf(behind) > absf(far):
							far = behind
			if air > 0:
				out.append(["(graffiti)", p, "%d of 15 points over nothing" % air])
			elif off > 0:
				out.append(["(graffiti)", p, "%d of 15 points %.2f m off the wall (- = inside it)" % [off, far]])
	return out

static func _world_tris(mi: MeshInstance3D) -> PackedVector3Array:
	var out := PackedVector3Array()
	var xf: Transform3D = mi.global_transform
	for si in range(mi.mesh.get_surface_count()):
		if mi.mesh.surface_get_primitive_type(si) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr: Array = mi.mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		if idx.is_empty():
			for k in range(v.size()):
				out.append(xf * v[k])
		else:
			for k in idx:
				out.append(xf * v[k])
	return out
