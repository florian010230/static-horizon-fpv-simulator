extends Node3D

## Third map: a real-size school - a 45 x 27 m sports hall (the standard
## German "Dreifeldhalle") with two handball/indoor-football goals,
## a foyer, a 70 m corridor and five classrooms. Indoors only: the
## entrance is a glass door and the emergency exit is closed, so the
## schoolyard outside is only something to look at through the windows. Sized and furnished for a Tiny Whoop
## specifically - real tiny whoops exist precisely to fly indoors like
## this, unlike the village/factory maps which suit the bigger Static Three.
## Always flies the whoop (MapCatalog's "drone" entry - Drone applies
## it), since a 245g freestyle quad has no business in a school corridor.

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
	_apply_textures()
	# The engine sun lights nothing on some GPUs - bake it (see LightBaker).
	LightBaker.bake(self, $Sun, -0.1)
	Settings.apply_graphics_settings()

func _process(_delta: float) -> void:
	# The school's footprint: sports hall, foyer, corridor, classrooms.
	# All outside doors/windows are closed, so this only ever fires if
	# the drone clips through something.
	WorldBorder.check_box(_drone, _ui, Vector3(-23.5, -1.0, -14.5), Vector3(51.0, 8.5, 37.0), 4.0, get_tree())

func _apply_textures() -> void:
	BuildingStyles.apply_ground_surfaces(get_tree())
	_textured_group("grass", ProceduralTextures.grass_texture(), Vector3(1.0 / 6.0, 1.0 / 6.0, 1.0 / 6.0), false)
	# Wall bars (Sprossenwand): 1 m wide units, rungs every ~15 cm; the
	# gaps are real (alpha scissor), so the wall shows through them.
	_textured_group("wallbars", ProceduralTextures.wallbars_texture(), Vector3(1.0, 1.0 / 2.7, 1.0), true)
	# Locker banks: one 0.5 m door per texture tile across, 1.8 m tall.
	_textured_group("lockers", ProceduralTextures.lockers_texture(), Vector3(2.0, 1.0 / 1.8, 2.0), false)

func _textured_group(group: String, tex: Texture2D, scale: Vector3, cutout: bool) -> void:
	for node in get_tree().get_nodes_in_group(group):
		var mat: StandardMaterial3D = (node as MeshInstance3D).get_surface_override_material(0)
		mat.albedo_texture = tex
		mat.uv1_triplanar = true
		mat.uv1_world_triplanar = true
		mat.uv1_scale = scale
		if cutout:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			mat.alpha_scissor_threshold = 0.5
