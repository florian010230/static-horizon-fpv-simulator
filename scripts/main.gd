extends Node3D

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
	_apply_textures()
	Settings.apply_shadow_setting()

## albedo_color multiplies with albedo_texture - every material below
## originally had a flat, fairly dark albedo_color from before it had a
## texture at all (e.g. the ground's near-black-when-multiplied 0.2ish
## green). Reset to white so the texture's own baked colors show at
## full brightness instead of being crushed by a leftover tint.
func _apply_textures() -> void:
	var grass: ImageTexture = ProceduralTextures.grass_texture()
	var ground_mat: StandardMaterial3D = $Ground/MeshInstance3D.get_surface_override_material(0)
	ground_mat.albedo_texture = grass
	ground_mat.albedo_color = Color.WHITE
	ground_mat.uv1_scale = Vector3(70, 70, 1)

	var brick: ImageTexture = ProceduralTextures.brick_texture()
	var building_mat: StandardMaterial3D = $Building/MeshInstance3D.get_surface_override_material(0)
	building_mat.albedo_texture = brick
	building_mat.albedo_color = Color.WHITE
	building_mat.uv1_scale = Vector3(4, 10, 1)

	var siding: ImageTexture = ProceduralTextures.siding_texture()
	for house_path in ["House1", "House2"]:
		# Direct children only, deliberately - HollowBuilding's own wall/
		# floor/ceiling meshes live right under the house root, while the
		# separate peaked Roof child (its own distinct color) sits one
		# level deeper and should be left alone.
		for child in get_node(house_path).get_children():
			if child is MeshInstance3D:
				var mat := StandardMaterial3D.new()
				mat.albedo_texture = siding
				mat.uv1_scale = Vector3(3, 2, 1)
				child.set_surface_override_material(0, mat)

	var asphalt: ImageTexture = ProceduralTextures.asphalt_texture()
	var street_mat: StandardMaterial3D = $Street/MeshInstance3D.get_surface_override_material(0)
	street_mat.albedo_texture = asphalt
	street_mat.albedo_color = Color.WHITE
	street_mat.uv1_scale = Vector3(43, 3, 1)

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
