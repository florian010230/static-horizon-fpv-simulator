extends Node3D

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
	_apply_textures()

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
