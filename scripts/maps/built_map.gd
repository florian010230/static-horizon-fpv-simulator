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

## The map's ONE list of per-piece overrides (see Pieces): piece id ->
## {"seed": n} / {"remove": true} / pinned options. Ids show over every
## piece with SH_IDS=1.
func pieces() -> Dictionary:
	return {}

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
	if from_cache:
		push_warning("floating_pieces(): %s came from the map cache - Geo holds nothing to check" % name)
	var g: Callable = Callable(self, "_height") if has_method("_height") else func(_x: float, _z: float) -> float: return 0.0
	# Judged out to 100 m past the reset border: as close as anyone gets.
	var b: Array = border()
	return geo.floating(g, b[4] if b.size() > 4 else Vector2.ZERO, b[1] + 100.0)

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

## Map load cache (MapCache): on for every generated map since
## 2026-10-04 (Round 2). It works when everything this map needs after
## build() is either a node under the map or in cache_state(). Handled
## for every map automatically: the preview views (saved along, see
## views()), and script variables typed as a scripted node class that
## build() put under the map (e.g. `var course: RaceCourse`) - found
## again by class after a cached load (_rebind_nodes); such a node keeps
## what it needs in node metadata (RaceCourse: its gates). A map that
## keeps anything else (signals, other node references, data read after
## the build) either saves it in cache_state() or says false here.
## Check a map with `SH_SELFTEST_ONLY=cache` (fresh vs cached fingerprint).
func cacheable() -> bool:
	return true

## What the map's script needs after build() (preview views, the land for
## _height...), for a cached load: saved with the cache, handed back to
## restore_state() instead of running build(). Plain data only.
func cache_state() -> Dictionary:
	return {}

func restore_state(_state: Dictionary) -> void:
	pass

var _cached_views: Array = []

## Named camera views for dev shots and menu thumbnails:
## [[name, camera position, look-at target], ...] (maps override).
func preview_views() -> Array:
	return []

## The preview views (dev shots, menu thumbnails): the map's own, or on a
## cached load the ones saved with the cache (generated views live in
## script variables the build fills).
func views() -> Array:
	return _cached_views if from_cache else preview_views()

## After a cached load: script variables typed as a scripted node class
## (`var course: RaceCourse`) point at the map's child of that class again.
func _rebind_nodes() -> void:
	for prop in get_property_list():
		if not (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) or prop.type != TYPE_OBJECT or String(prop.class_name) == "":
			continue
		if get(prop.name) != null:
			continue
		for c in get_children():
			var sc: Script = c.get_script()
			if sc and sc.get_global_name() == prop.class_name:
				set(prop.name, c)
				break

## True when this load came from the map cache (build() didn't run; geo
## holds nothing).
var from_cache: bool = false

func _ready() -> void:
	var lt: Array = [Time.get_ticks_usec()] # SH_LOADTIME: phase times
	_make_environment(map_env())
	var use_cache: bool = MapCache.enabled(self)
	if use_cache:
		var state: Variant = MapCache.restore(self)
		if state != null:
			from_cache = true
			_cached_views = (state as Dictionary).get("_views", [])
			_rebind_nodes()
			restore_state(state)
			lt.append(Time.get_ticks_usec())
			_finish(lt, "cache")
			return
	var keep: Array = get_children()
	fleet = Fleet.new(geo)
	geo.pieces = pieces()
	_building = true
	build()
	_building = false
	lt.append(Time.get_ticks_usec())
	# Scattered things go last, around whatever the map built: parked cars
	# and trees that would stand inside a building, a crane, another car,
	# or (trees) on a road or track are dropped (Geo's footprints).
	fleet.commit(self)
	lt.append(Time.get_ticks_usec())
	_plant_trees()
	if OS.has_environment("SH_FLOAT"):
		if OS.get_environment("SH_FLOAT") != "1":
			geo.gap_limit = float(OS.get_environment("SH_FLOAT"))
		var f: Array = floating_pieces()
		print("FLOATING %s: %d" % [name, f.size()])
		var kinds: Dictionary = {}
		for e: Array in f:
			kinds["%s %s" % [e[3], e[1]]] = kinds.get("%s %s" % [e[3], e[1]], 0) + 1
		print("  by kind: ", kinds)
		for k in range(mini(f.size(), 60)):
			print("  float ", f[k])
	lt.append(Time.get_ticks_usec())
	geo.commit(self)
	Pieces.show_ids(self, geo)
	if OS.has_environment("SH_SURFCHECK"):
		print(SurfaceCheck.report(name, SurfaceCheck.run(self), 30))
	lt.append(Time.get_ticks_usec())
	if use_cache:
		var st: Dictionary = cache_state()
		st["_views"] = preview_views()
		var size: int = MapCache.save(self, keep, st)
		lt.append(Time.get_ticks_usec())
		if OS.has_environment("SH_LOADTIME"):
			print("LOAD %s: map cache written, %.1f MB" % [name, size / 1048576.0])
	_finish(lt, "save" if use_cache else "")

func _finish(lt: Array, how: String) -> void:
	if ui.has_method("set_drone"):
		ui.set_drone(drone)
	after_build()
	if not OS.has_environment("SH_FLOAT") and not OS.get_cmdline_user_args().has("--selftest"):
		geo.release_records() # (the floating check is the only later reader)
	Settings.apply_graphics_settings()
	lt.append(Time.get_ticks_usec())
	if OS.has_environment("SH_LOADTIME"):
		_report_load(lt, how)
	if OS.has_environment("SH_MAPHASH"):
		print("MAPHASH %s (%s): %s" % [name, "cache" if from_cache else "built", MapCache.fingerprint(self)])
	if OS.has_environment("SH_PERF"):
		# Measure the real cost: no frame cap, no vsync.
		Engine.max_fps = 0
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)

## Dev aid (SH_LOADTIME=1): where a map's load time goes - build()
## (the creators, GDScript), scattering (trees, cars), Geo.commit (meshes
## and collision shapes), graphics settings (incl. the shadow map
## render), and the first frames (shader compiling on the GPU driver).
func _report_load(lt: Array, how: String = "") -> void:
	var names: Array = ["build", "cars", "trees", "commit", "graphics+shadows"]
	if how == "cache":
		names = ["cache load", "graphics+shadows"]
	elif how == "save":
		names = ["build", "cars", "trees", "commit", "cache save", "graphics+shadows"]
	var line: String = "LOAD %s: engine up %d ms before _ready;" % [name, int(lt[0] / 1000.0)]
	for i in range(names.size()):
		line += " %s %d ms," % [names[i], int((lt[i + 1] - lt[i]) / 1000.0)]
	print(line)
	var t: int = Time.get_ticks_usec()
	var frames: Array = []
	for k in range(5):
		await get_tree().process_frame
		var n: int = Time.get_ticks_usec()
		frames.append(int((n - t) / 1000.0))
		t = n
	print("LOAD %s: first frames %s ms; ready to fly %d ms after engine start" % [name, frames, int(Time.get_ticks_usec() / 1000.0)])

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
