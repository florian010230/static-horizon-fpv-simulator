extends Node3D

## Second map: an industrial factory yard, reusing the same HollowBuilding
## primitive as the small houses (see hollow_building.gd) but scaled up
## with door-to-ceiling openings on opposite walls, so each hall is a
## straight fly-through rather than a house with rooms.

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
	_apply_textures()
	Settings.apply_shadow_setting()

func _apply_textures() -> void:
	var concrete: ImageTexture = ProceduralTextures.concrete_texture()

	var ground_mat: StandardMaterial3D = $Ground/MeshInstance3D.get_surface_override_material(0)
	ground_mat.albedo_texture = concrete
	ground_mat.albedo_color = Color.WHITE
	ground_mat.uv1_scale = Vector3(90, 90, 1)

	# concrete_texture was built dark/moody for lit-from-outside tunnel
	# interiors - multiplying it in made these big sunlit exterior walls
	# read as near-black instead of the corrugated steel look intended.
	# A flat, bright panel color reads far better at this scale.
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.72, 0.74, 0.78)
	var floor_mat := StandardMaterial3D.new()
	floor_mat.albedo_texture = concrete
	floor_mat.albedo_color = Color(0.9, 0.9, 0.92)
	floor_mat.uv1_scale = Vector3(4, 4, 1)
	for hall_path in ["Hall1", "Hall2", "Hall3"]:
		var hall: Node = get_node(hall_path)
		for i in range(hall.get_child_count()):
			var child: Node = hall.get_child(i)
			if child is MeshInstance3D:
				# HollowBuilding._build() always adds floor then ceiling
				# first (each as a mesh+collision pair, so indices 0-3),
				# before any wall segments - give those two the tiled
				# concrete look while every wall segment gets the flat
				# panel color.
				child.set_surface_override_material(0, floor_mat if i < 4 else panel_mat)
