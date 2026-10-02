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
##   border()     - [warn radius, reset radius, warn height, reset height,
##                   optional centre: Vector2 (x, z) of the circle]
##   check_border() - for box-shaped (indoor) maps instead

var geo := Geo.new()
var fleet: Fleet ## parked/moving cars as MultiMesh (see Fleet), committed after build()
var sun: DirectionalLight3D
@onready var drone: Drone = $Drone
@onready var ui: CanvasLayer = $UI

func build() -> void:
	pass

var _building: bool = false
var _queued_trees: Array = []

## Forest.plant during build() lands here; planted after build().
func queue_trees(trees: Array) -> bool:
	if not _building:
		return false
	_queued_trees.append_array(trees)
	return true

## Solid pieces touching nothing (Geo.floating) - the self-test wants none.
func floating_pieces() -> Array:
	var g: Callable = Callable(self, "_height") if has_method("_height") else func(_x: float, _z: float) -> float: return 0.0
	return geo.floating(g)

func _plant_trees() -> void:
	var kept: Array = []
	for t in _queued_trees:
		var p: Vector3 = t[0]
		var q := Vector2(p.x, p.z)
		if geo.blocked(q, 0.7 * t[2], p.y + 0.6, p.y + 5.0 * t[2]) or geo.on_lane(q, 1.2):
			continue
		kept.append(t)
	if OS.has_environment("SH_PERF"):
		print("TREES kept %d of %d" % [kept.size(), _queued_trees.size()])
	if not kept.is_empty():
		Forest.plant(self, kept)
	_queued_trees.clear()

func map_env() -> Dictionary:
	return {}

## Runs after the geometry exists and the UI knows the drone.
func after_build() -> void:
	pass

func border() -> Array:
	return [200.0, 260.0, 120.0, 170.0]

func _ready() -> void:
	_make_environment(map_env())
	fleet = Fleet.new(geo)
	_building = true
	build()
	_building = false
	# Scattered things go last, around whatever the map built: parked cars
	# and trees that would stand inside a building, a crane, another car,
	# or (trees) on a road or track are dropped (Geo's footprints).
	fleet.commit(self)
	_plant_trees()
	if OS.has_environment("SH_FLOAT"):
		var f: Array = floating_pieces()
		print("FLOATING %s: %d" % [name, f.size()])
		for k in range(mini(f.size(), 60)):
			print("  float ", f[k])
	geo.commit(self)
	if ui.has_method("set_drone"):
		ui.set_drone(drone)
	after_build()
	Settings.apply_graphics_settings()
	if OS.has_environment("SH_PERF"):
		# Measure the real cost: no frame cap, no vsync.
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

func _process(_delta: float) -> void:
	check_border()
	# Dev aid: SH_PERF=1 in the environment prints draw calls and FPS.
	if OS.has_environment("SH_PERF") and Engine.get_process_frames() % 200 == 0:
		print("PERF draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " prims=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME), " fps=", Engine.get_frames_per_second())

func check_border() -> void:
	var b: Array = border()
	WorldBorder.check(drone, ui, b[0], b[1], b[2], b[3], get_tree(), b[4] if b.size() > 4 else Vector2.ZERO)

## Sky, sun, ambient, fog and glow. (The High maps keep fog very light
## on purpose - the user wants to see far; Terrain.far_ring hides the
## map edge instead.) Graphics quality decides the extras:
## glow and height fog only on High (they're full-screen passes).
## Depth fog for the hand-made maps too (village, factory): the same
## horizon fade as the generated ones (see _make_environment).
static func apply_depth_fog(env: Environment, begin: float = 280.0) -> void:
	var horizon := Color(0.75, 0.82, 0.9)
	if env.sky and env.sky.sky_material is ProceduralSkyMaterial:
		var sm := env.sky.sky_material as ProceduralSkyMaterial
		horizon = sm.sky_horizon_color
		sm.ground_horizon_color = horizon
		sm.ground_bottom_color = horizon.darkened(0.15)
		sm.ground_curve = 0.3
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = horizon
	env.fog_depth_curve = 2.2
	env.fog_depth_begin = begin
	env.fog_depth_end = 1500.0
	env.fog_sky_affect = 0.0
	env.set_meta("depth_fog", begin)

static var _cloud_tex: ImageTexture

## Swaps the plain gradient sky for shaders/sky_clouds.gdshader: the same
## colours, plus clouds lit by the sun and the sun's glow. Map env key
## "clouds": cover threshold (lower = more clouds, 1.2 = clear sky).
func _cloud_sky(sky: Sky, base: ProceduralSkyMaterial, e: Dictionary) -> void:
	cloud_sky(sky, base, sun, e.get("clouds", 0.55 if e.get("fog", true) else 1.2), get_node_or_null("WorldEnvironment"))

## Same for any scene's sky (the hand-made maps call it via Settings).
static func cloud_sky(sky: Sky, base: ProceduralSkyMaterial, sun_light: DirectionalLight3D, coverage: float, we: WorldEnvironment) -> void:
	if _cloud_tex == null:
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.seed = 7
		n.frequency = 0.012
		n.fractal_octaves = 5
		n.fractal_gain = 0.55
		var img: Image = n.get_seamless_image(512, 512)
		img.convert(Image.FORMAT_L8)
		img.generate_mipmaps()
		_cloud_tex = ImageTexture.create_from_image(img)
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/sky_clouds.gdshader")
	m.set_shader_parameter("top_color", base.sky_top_color)
	m.set_shader_parameter("horizon_color", base.sky_horizon_color)
	m.set_shader_parameter("ground_color", base.ground_horizon_color)
	m.set_shader_parameter("sun_dir", sun_light.global_transform.basis.z)
	m.set_shader_parameter("sun_color", sun_light.light_color)
	m.set_shader_parameter("clouds", _cloud_tex)
	m.set_shader_parameter("coverage", coverage)
	sky.sky_material = m
	# Nothing reads the sky's reflections (unshaded materials) - don't
	# have the renderer keep them up to date.
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	sky.process_mode = Sky.PROCESS_MODE_QUALITY
	if we:
		we.environment.reflected_light_source = Environment.REFLECTION_SOURCE_DISABLED

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
		if e.get("indoor", false):
			env.fog_light_color = e.get("fog_color", Color(0.7, 0.76, 0.82))
			env.fog_density = e.get("fog_density", 0.0008)
			env.fog_sky_affect = 0.2
		else:
			# Depth fog: clear air near the drone, thickening into the
			# sky's horizon colour and fully opaque just before the far
			# plane (Settings._fit_fog sets the distances from the
			# camera) - the world fades into the horizon instead of
			# ending at a visible edge. The sky itself stays untouched.
			env.fog_mode = Environment.FOG_MODE_DEPTH
			env.fog_light_color = e.get("fog_color", sky_mat.sky_horizon_color)
			env.fog_depth_curve = e.get("fog_curve", 2.2)
			env.fog_depth_begin = e.get("fog_begin", 350.0)
			env.fog_depth_end = 1500.0
			env.fog_sky_affect = 0.0
			env.set_meta("depth_fog", env.fog_depth_begin)
			# Below the horizon the sky is only seen past the far plane:
			# make it the fog colour, or a dark band shows there.
			sky_mat.ground_horizon_color = env.fog_light_color
			sky_mat.ground_bottom_color = env.fog_light_color.darkened(0.15)
			sky_mat.ground_curve = 0.3
		env.fog_aerial_perspective = e.get("aerial", 0.15)
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
	_cloud_sky(sky, sky_mat, e)
	# The light is baked into Geo's vertex colors (see Geo's header).
	geo.sun_dir = -sun.global_transform.basis.z
	geo.sun = 0.5 * sun.light_energy
	geo.sun_tint = sun.light_color
	geo.ambient = 0.56 * env.ambient_light_energy
	# On GPUs where the engine sun does work it would light the drone
	# model only - nothing else uses lit materials in a generated map.
	set_meta("light_parts", Vector3(geo.ambient, geo.sky, geo.sun))
	# Sun shadow map area (WorldShading): the map's own, or the border
	# circle's square. Indoor maps get none.
	if not e.get("indoor", false) and e.get("shadows", true):
		var region: Rect2 = e.get("shadow_region", Rect2())
		if not region.has_area():
			var b: Array = border()
			var c: Vector2 = b[4] if b.size() > 4 else Vector2.ZERO
			var r: float = minf(b[0], 800.0)
			region = Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0)
		set_meta("shadow_region", region)
