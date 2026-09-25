extends Node3D

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
	_apply_textures()
	_spawn_trees()
	Settings.apply_shadow_setting()

func _apply_textures() -> void:
	var grass: ImageTexture = ProceduralTextures.grass_texture()
	var ground_mat: StandardMaterial3D = $Ground/MeshInstance3D.get_surface_override_material(0)
	ground_mat.albedo_texture = grass
	ground_mat.uv1_scale = Vector3(70, 70, 1)

	var brick: ImageTexture = ProceduralTextures.brick_texture()
	var building_mat: StandardMaterial3D = $Building/MeshInstance3D.get_surface_override_material(0)
	building_mat.albedo_texture = brick
	building_mat.uv1_scale = Vector3(4, 10, 1)

	var siding: ImageTexture = ProceduralTextures.siding_texture()
	for path in ["House1/MeshInstance3D", "House2/MeshInstance3D"]:
		var house_mat: StandardMaterial3D = get_node(path).get_surface_override_material(0)
		house_mat.albedo_texture = siding
		house_mat.uv1_scale = Vector3(3, 3, 1)

	# Baked panel seams (concrete_texture) plus a per-surface tint fake the
	# directional lighting real shadows would give - floor brightest
	# (catches bounce light), ceiling darkest (most occluded), walls in
	# between - so floor/ceiling/walls read as distinct even with shadow
	# rendering off, and passing each seam gives a sense of speed/depth
	# while flying through.
	var concrete: ImageTexture = ProceduralTextures.concrete_texture()
	var tunnel_tints := {
		"TunnelFloor/MeshInstance3D": Color(1.0, 1.0, 1.0),
		"TunnelCeiling/MeshInstance3D": Color(0.5, 0.5, 0.53),
		"TunnelWallLeft/MeshInstance3D": Color(0.72, 0.72, 0.75),
		"TunnelWallRight/MeshInstance3D": Color(0.72, 0.72, 0.75),
	}
	for path: String in tunnel_tints:
		var mesh_instance: MeshInstance3D = get_node(path)
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = concrete
		mat.albedo_color = tunnel_tints[path]
		mat.uv1_scale = Vector3(6, 20, 1)
		mesh_instance.set_surface_override_material(0, mat)

## Trees are drawn with MultiMeshInstance3D - hundreds of instances cost
## just 2 draw calls total (one per layer), instead of hundreds of
## individual nodes. No collision on them (deliberate trade-off: cheap
## decoration, not obstacles - keeps the instance count free of any
## per-tree physics cost).
func _spawn_trees() -> void:
	var trunk_mesh := CylinderMesh.new()
	trunk_mesh.top_radius = 0.35
	trunk_mesh.bottom_radius = 0.45
	trunk_mesh.height = 4.0
	var trunk_mat := StandardMaterial3D.new()
	trunk_mat.albedo_color = Color(0.35, 0.24, 0.15)
	trunk_mesh.material = trunk_mat

	var foliage_mesh := CylinderMesh.new()
	foliage_mesh.top_radius = 0.0
	foliage_mesh.bottom_radius = 3.0
	foliage_mesh.height = 6.0
	var foliage_mat := StandardMaterial3D.new()
	foliage_mat.albedo_color = Color(0.2, 0.38, 0.18)
	foliage_mesh.material = foliage_mat

	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var positions: Array[Vector3] = []
	while positions.size() < 80:
		var x: float = rng.randf_range(-215.0, 215.0)
		var z: float = rng.randf_range(-215.0, 215.0)
		if Vector2(x, z).length() < 70.0:
			continue # keep the core play area (buildings/gates/tunnel) clear
		positions.append(Vector3(x, 0.5, z))

	var trunk_mm := MultiMesh.new()
	trunk_mm.transform_format = MultiMesh.TRANSFORM_3D
	trunk_mm.mesh = trunk_mesh
	trunk_mm.instance_count = positions.size()

	var foliage_mm := MultiMesh.new()
	foliage_mm.transform_format = MultiMesh.TRANSFORM_3D
	foliage_mm.mesh = foliage_mesh
	foliage_mm.instance_count = positions.size()

	for i in range(positions.size()):
		var p: Vector3 = positions[i]
		var s: float = rng.randf_range(0.7, 1.3)
		var basis := Basis().scaled(Vector3(s, s, s))
		trunk_mm.set_instance_transform(i, Transform3D(basis, p + Vector3(0, 2.0 * s, 0)))
		foliage_mm.set_instance_transform(i, Transform3D(basis, p + Vector3(0, 7.0 * s, 0)))

	var trunk_instance := MultiMeshInstance3D.new()
	trunk_instance.multimesh = trunk_mm
	add_child(trunk_instance)

	var foliage_instance := MultiMeshInstance3D.new()
	foliage_instance.multimesh = foliage_mm
	add_child(foliage_instance)
