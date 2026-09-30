class_name BuiltMap
extends Node3D

## Base for the generated maps: the scene file holds only the Drone
## (its spawn point - move it in the editor like on any map) and the UI;
## everything else is built in build() through `geo` (see Geo), Terrain
## and Forest, from a compact per-map script.
##
## Subclasses override:
##   build()      - make the map
##   map_env()    - sky/sun/fog/ambient values (see _make_environment)
##   border()     - [warn radius, reset radius, warn height, reset height]
##   check_border() - for box-shaped (indoor) maps instead

var geo := Geo.new()
var sun: DirectionalLight3D
@onready var drone: Drone = $Drone
@onready var ui: CanvasLayer = $UI

func build() -> void:
	pass

func map_env() -> Dictionary:
	return {}

## Runs after the geometry exists and the UI knows the drone.
func after_build() -> void:
	pass

func border() -> Array:
	return [200.0, 260.0, 120.0, 170.0]

func _ready() -> void:
	_make_environment(map_env())
	build()
	geo.commit(self)
	if ui.has_method("set_drone"):
		ui.set_drone(drone)
	after_build()
	Settings.apply_graphics_settings()

func _process(_delta: float) -> void:
	check_border()

func check_border() -> void:
	var b: Array = border()
	WorldBorder.check(drone, ui, b[0], b[1], b[2], b[3], get_tree())

## Sky, sun, ambient, fog and glow. (The High maps keep fog very light
## on purpose - the user wants to see far; Terrain.far_ring hides the
## map edge instead.) Graphics quality decides the extras:
## glow and height fog only on High (they're full-screen passes).
func _make_environment(e: Dictionary) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = e.get("sky_top", Color(0.32, 0.52, 0.78))
	sky_mat.sky_horizon_color = e.get("sky_horizon", Color(0.72, 0.8, 0.88))
	sky_mat.ground_horizon_color = e.get("ground_horizon", Color(0.5, 0.58, 0.45))
	sky_mat.ground_bottom_color = e.get("ground_bottom", Color(0.25, 0.32, 0.2))
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = e.get("ambient", Color(0.62, 0.66, 0.7))
	env.ambient_light_energy = e.get("ambient_energy", 0.75)
	env.tonemap_mode = e.get("tonemap", Environment.TONE_MAPPER_LINEAR)
	env.tonemap_exposure = e.get("exposure", 1.0)
	var high: bool = Settings.graphics_quality >= 2
	if e.get("fog", true):
		env.fog_enabled = true
		env.fog_light_color = e.get("fog_color", Color(0.7, 0.76, 0.82))
		env.fog_density = e.get("fog_density", 0.0008)
		env.fog_aerial_perspective = e.get("aerial", 0.15)
		env.fog_sky_affect = 0.2
		if high and e.has("height_fog"):
			env.fog_height = e.height_fog[0]
			env.fog_height_density = e.height_fog[1]
	if high and e.get("glow", true):
		env.glow_enabled = true
		env.glow_intensity = 0.6
		env.glow_bloom = 0.05
		env.glow_hdr_threshold = 1.2
	var we := WorldEnvironment.new()
	we.name = "WorldEnvironment"
	we.environment = env
	add_child(we)
	sun = get_node_or_null("Sun")
	if sun == null:
		sun = DirectionalLight3D.new()
		sun.name = "Sun"
	sun.rotation_degrees = e.get("sun_rot", Vector3(-50, -35, 0))
	sun.light_color = e.get("sun_color", Color(1.0, 0.96, 0.88))
	sun.light_energy = e.get("sun_energy", 1.1)
	if not sun.is_inside_tree():
		add_child(sun)
	# The light is baked into Geo's vertex colors (see Geo's header).
	geo.sun_dir = -sun.global_transform.basis.z
	geo.sun = 0.5 * sun.light_energy
	geo.sun_tint = sun.light_color
	geo.ambient = 0.56 * env.ambient_light_energy
	# On GPUs where the engine sun does work it would light the drone
	# model only - nothing else uses lit materials in a generated map.
	if e.has("shadow_ground_y"):
		set_meta("shadow_ground_y", e.shadow_ground_y)
		set_meta("shadow_region", e.get("shadow_region", Rect2(-250, -250, 500, 500)))
