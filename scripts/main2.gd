extends Node3D

## Second map: a small working industrial site, not just three
## interchangeable sheds - an entrance road forks to a Main Production
## Hall (Hall1) and a Warehouse (Hall2, fed by a rail spur and loading
## dock) with a secondary Assembly building (Hall3) further out, plus an
## Office near the gate, storage tanks and chimneys for silhouette, and
## the same big connecting pipes/masts as before. Halls reuse the same
## HollowBuilding primitive as the small houses (see hollow_building.gd)
## but scaled up with door-to-ceiling openings on opposite walls, so each
## is a straight fly-through rather than a house with rooms.

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
	_apply_textures()
	BuildingStyles.apply_ground_surfaces(get_tree())
	BuildingStyles.add_far_ground(self, 0.5)
	BuildingStyles.extend_edge_roads(self)
	BuiltMap.apply_depth_fog($WorldEnvironment.environment)
	# The engine sun lights nothing on some GPUs - bake it (see LightBaker).
	LightBaker.bake(self, $Sun, 0.52)
	Settings.apply_graphics_settings()

func _process(_delta: float) -> void:
	WorldBorder.check(_drone, _ui, 200.0, 260.0, 120.0, 170.0, get_tree())

func _apply_textures() -> void:
	var concrete: ImageTexture = ProceduralTextures.concrete_texture()

	var ground_mat: StandardMaterial3D = $Ground/MeshInstance3D.get_surface_override_material(0)
	# Grass outside the perimeter wall; the concrete yard texture only
	# goes on SiteSlab, the paved area inside it.
	ground_mat.albedo_texture = ProceduralTextures.grass_texture()
	ground_mat.albedo_color = Color.WHITE
	ground_mat.uv1_scale = Vector3(70, 70, 1)
	var site_mat: StandardMaterial3D = $SiteSlab.get_surface_override_material(0)
	site_mat.albedo_texture = ProceduralTextures.factory_ground_texture()
	site_mat.uv1_triplanar = true
	site_mat.uv1_world_triplanar = true
	site_mat.uv1_scale = Vector3(1.0 / 16.0, 1.0 / 16.0, 1.0 / 16.0)

	var asphalt: ImageTexture = ProceduralTextures.asphalt_plain_texture() # (the lane-wear one would run crosswise under the ground shader's top-down projection)
	var main_road_mat: StandardMaterial3D = $MainRoad/MeshInstance3D.get_surface_override_material(0)
	main_road_mat.albedo_texture = asphalt
	main_road_mat.albedo_color = Color(0.3, 0.3, 0.32) # same tone as every other road
	main_road_mat.uv1_scale = Vector3(3, 28, 1)

	var warehouse_road_mat: StandardMaterial3D = $WarehouseRoad/MeshInstance3D.get_surface_override_material(0)
	warehouse_road_mat.albedo_texture = asphalt
	warehouse_road_mat.albedo_color = Color(0.3, 0.3, 0.32) # same tone as every other road
	warehouse_road_mat.uv1_scale = Vector3(20, 3, 1)
