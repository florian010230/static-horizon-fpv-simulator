class_name Embankment
extends StaticBody3D

## A straight earth dam with a trapezoid cross-section, running along
## local X - what a railway line (or road) sits on where it crosses low
## ground. Optionally carries a ballast bed with sleepers and two rails
## on top. Built at runtime from one ArrayMesh plus one convex collision
## shape, so a 200 m embankment is a single cheap object.
##
## The village map uses it to give its tunnel an actual reason to exist:
## a farm track passes *under* the railway through it.

@export var length: float = 100.0
@export var height: float = 7.5
@export var top_width: float = 8.0
## Horizontal run per meter of rise on each side (1.5 = a typical 1:1.5
## earthwork slope).
@export var slope: float = 1.5
@export var has_track: bool = true
## Multiplies the shared grass texture (already green) - keep near white.
@export var grass_color: Color = Color(0.92, 0.95, 0.88)

func _ready() -> void:
	var hl: float = length * 0.5
	var ht: float = top_width * 0.5
	var hb: float = ht + height * slope
	# Cross-section corners (z, y), counter-clockwise seen from +X.
	var section: Array[Vector2] = [Vector2(-hb, 0), Vector2(hb, 0), Vector2(ht, height), Vector2(-ht, height)]

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(4):
		var a: Vector2 = section[i]
		var b: Vector2 = section[(i + 1) % 4]
		if a.y == 0.0 and b.y == 0.0:
			continue # bottom face sits on the ground, never visible
		var p0 := Vector3(-hl, a.y, a.x)
		var p1 := Vector3(hl, a.y, a.x)
		var p2 := Vector3(hl, b.y, b.x)
		var p3 := Vector3(-hl, b.y, b.x)
		var n: Vector3 = (p1 - p0).cross(p3 - p0).normalized()
		var edge: float = (b - a).length()
		_quad(st, [p0, p1, p2, p3], [Vector2(-hl, 0) / 4.0, Vector2(hl, 0) / 4.0, Vector2(hl, edge) / 4.0, Vector2(-hl, edge) / 4.0], n)
	for side in [-1.0, 1.0]:
		var pts: Array = []
		for c in section:
			pts.append(Vector3(side * hl, c.y, c.x))
		var n := Vector3(side, 0, 0)
		_quad(st, pts, [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)], n)
	var mesh: ArrayMesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = grass_color
	mat.albedo_texture = ProceduralTextures.grass_texture()
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

	var shape := ConvexPolygonShape3D.new()
	var points := PackedVector3Array()
	for c in section:
		points.append(Vector3(-hl, c.y, c.x))
		points.append(Vector3(hl, c.y, c.x))
	shape.points = points
	var cs := CollisionShape3D.new()
	cs.shape = shape
	add_child(cs)

	if has_track:
		_build_track(hl)

func _build_track(hl: float) -> void:
	var ballast := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(length, 0.35, 3.4)
	ballast.mesh = bm
	ballast.position = Vector3(0, height + 0.175, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_texture = _sleeper_texture()
	# World-space top projection: texture u runs along X, one tile per
	# 1.8 m (3 sleepers at the usual ~0.6 m spacing), v spans the bed's
	# 3.4 m width, offset so the sleepers sit centered on it.
	bmat.uv1_triplanar = true
	bmat.uv1_world_triplanar = true
	bmat.uv1_scale = Vector3(1.0 / 1.8, 1.0, 1.0 / 3.4)
	bmat.uv1_offset = Vector3(0, 0, -(global_position.z - 1.7) / 3.4)
	ballast.set_surface_override_material(0, bmat)
	add_child(ballast)
	var bshape := BoxShape3D.new()
	bshape.size = bm.size
	var bcs := CollisionShape3D.new()
	bcs.shape = bshape
	bcs.position = ballast.position
	add_child(bcs)
	# Standard gauge: 1.435 m between rail heads.
	for z in [-0.7175, 0.7175]:
		var rail := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(length, 0.16, 0.08)
		rail.mesh = rm
		rail.position = Vector3(0, height + 0.43, z)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.45, 0.42, 0.4)
		rmat.metallic = 0.6
		rmat.roughness = 0.4
		rail.set_surface_override_material(0, rmat)
		add_child(rail)

## Gray ballast with dark wooden sleepers across it - the BoxMesh's top
## face UVs are laid out so this repeats along the track.
static func _sleeper_texture() -> ImageTexture:
	var img := ProceduralTextures.plaster_image(64, 0.42, 0.58, 31)
	for i in range(3):
		img.fill_rect(Rect2i(i * 64 / 3 + 3, 8, 9, 48), Color(0.28, 0.2, 0.14))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

func _quad(st: SurfaceTool, p: Array, uv: Array, n: Vector3) -> void:
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	var geo_n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if geo_n.dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.add_vertex(p[i])
