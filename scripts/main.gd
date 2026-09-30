extends Node3D

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
	_apply_textures()
	BuildingStyles.add_far_ground(self, 0.5)
	# The engine sun lights nothing on some GPUs - bake it (see LightBaker).
	LightBaker.bake(self, $Sun, 0.5)
	Settings.apply_graphics_settings()

func _process(_delta: float) -> void:
	WorldBorder.check(_drone, _ui, 200.0, 260.0, 120.0, 170.0, get_tree())

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

	var asphalt: ImageTexture = ProceduralTextures.asphalt_plain_texture() # (the lane-wear one would run crosswise under the ground shader's top-down projection)
	var street_mat: StandardMaterial3D = $Street/MeshInstance3D.get_surface_override_material(0)
	street_mat.albedo_texture = asphalt
	street_mat.albedo_color = Color(0.3, 0.3, 0.32) # same tone as every other road
	street_mat.uv1_scale = Vector3(43, 3, 1)

	# Branches off the street toward the FPV field - so the street leads
	# somewhere at both ends (houses one way, the practice field the
	# other) instead of just fading out past the last house.
	var connector_mat: StandardMaterial3D = $ConnectorRoad/MeshInstance3D.get_surface_override_material(0)
	connector_mat.albedo_texture = asphalt
	connector_mat.albedo_color = Color(0.3, 0.3, 0.32) # same tone as every other road
	connector_mat.uv1_scale = Vector3(2, 7, 1)

	BuildingStyles.apply_ground_surfaces(get_tree())

	_apply_tube_materials("Tunnel", -40.0, 9.0, true)
	_apply_tube_materials("Pipe", 35.0, 4.6, false)

## The tunnel (and the smaller pipe) used to get the same dark, seamed
## concrete on every face, only tinted differently - in flight, walls
## and ceiling were still easy to mix up, especially rolled over. Now
## each surface gets a clearly different look, unshaded with the light
## baked in (the sun lighting the *inside* of a covered tunnel was
## never right anyway): a light asphalt floor, light concrete wall
## panels, and a dark ceiling - with a line of lamps down the middle of
## the tunnel's, the one cue that instantly says "that way is up".
## World-space projection so the lamp line lands on the centerline no
## matter how the BoxMesh lays out its own UVs.
func _apply_tube_materials(prefix: String, center_x: float, width: float, lamps: bool) -> void:
	var floor_mat := StandardMaterial3D.new()
	floor_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	floor_mat.albedo_texture = ProceduralTextures.asphalt_plain_texture()
	floor_mat.albedo_color = Color(0.72, 0.72, 0.74)
	floor_mat.uv1_triplanar = true
	floor_mat.uv1_world_triplanar = true
	floor_mat.uv1_scale = Vector3(0.25, 0.25, 0.25)

	var wall_mat := StandardMaterial3D.new()
	wall_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	wall_mat.albedo_texture = BuildingStyles.texture("concrete_panels")
	wall_mat.albedo_color = Color(0.82, 0.81, 0.78)
	wall_mat.uv1_triplanar = true
	wall_mat.uv1_world_triplanar = true
	wall_mat.uv1_scale = Vector3(1.0 / 4.0, 1.0 / 3.0, 1.0 / 4.0)

	var ceil_mat := StandardMaterial3D.new()
	ceil_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ceil_mat.albedo_texture = ProceduralTextures.tube_ceiling_texture(lamps)
	ceil_mat.uv1_triplanar = true
	ceil_mat.uv1_world_triplanar = true
	ceil_mat.uv1_scale = Vector3(1.0 / width, 1.0 / 6.0, 1.0 / 6.0)
	ceil_mat.uv1_offset = Vector3(0.5 - center_x / width, 0, 0)

	(get_node(prefix + "Floor/MeshInstance3D") as MeshInstance3D).set_surface_override_material(0, floor_mat)
	(get_node(prefix + "Ceiling/MeshInstance3D") as MeshInstance3D).set_surface_override_material(0, ceil_mat)
	(get_node(prefix + "WallLeft/MeshInstance3D") as MeshInstance3D).set_surface_override_material(0, wall_mat)
	(get_node(prefix + "WallRight/MeshInstance3D") as MeshInstance3D).set_surface_override_material(0, wall_mat)
