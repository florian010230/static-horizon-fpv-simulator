extends Node

## Autoloaded singleton holding options that need to survive scene
## changes (menu <-> gameplay): crosshair, fullscreen, shadow quality.

var crosshair_enabled: bool = true
## On by default: these are FakeShadows (computed once per map on the
## CPU, one draw call) plus the drone's own DroneShadow, not Godot's
## shadow maps - those rendered nothing at all on the dev machine's
## Intel GPU, and cost real GPU time where they do work.
var shadows_enabled: bool = true

## Graphics quality, so the sim runs on weak PCs too: 0 Low, 1 Medium
## (default), 2 High. Controls the 3D render resolution (the HUD/menu
## stay sharp - only the 3D view is scaled), how far away small objects
## (lamps, cars, sleepers, desks...) are still drawn, and the camera's
## view distance. On a Retina/HiDPI screen the 3D view otherwise renders
## at the full physical resolution (e.g. 2880x1800) - several times the
## pixels of a 1080p screen, which integrated graphics struggle with.
var graphics_quality: int = 1

## Performance mode, for stronger PCs: physics at 240 steps per second
## instead of 120 (a slightly crisper flight controller) and Godot's full
## collision tracking (contact_monitor) on the drone. Off by default -
## measured, that combination cost about three times the CPU per
## physics step, which is what weak PCs can't afford.
var performance_mode: bool = false
const PHYSICS_HZ_NORMAL: int = 120
const PHYSICS_HZ_PERFORMANCE: int = 240
const QUALITY_NAMES: Array[String] = ["Low", "Medium", "High"]
const QUALITY_RENDER_SCALE: Array[float] = [0.55, 0.75, 1.0]
## Beyond these distances objects smaller than SMALL_OBJECT_SIZE /
## MEDIUM_OBJECT_SIZE aren't drawn (0 = no limit).
const QUALITY_SMALL_RANGE: Array[float] = [80.0, 150.0, 300.0]
const QUALITY_MEDIUM_RANGE: Array[float] = [200.0, 400.0, 0.0]
const QUALITY_VIEW_DISTANCE: Array[float] = [650.0, 1300.0, 1800.0]
const SMALL_OBJECT_SIZE: float = 3.0
const MEDIUM_OBJECT_SIZE: float = 12.0
var max_fps: int = 60 ## 0 means uncapped ("Unlimited" in the menu slider).

## Acro's "Actual Rates" curve (see Drone.center_sensitivity_deg /
## max_rate_deg) - exposed here so a player can set their preferred feel
## once from the menu instead of re-tuning it every flight. The in-game
## "O" debug panel still live-edits the drone's own fields directly for
## quick A/B testing mid-flight; these are just what a freshly spawned
## drone starts from.
## FPV camera, set from the in-game pause menu and kept across maps.
var camera_angle_deg: float = 25.0
var camera_fov_deg: float = 80.0

var rate_center_sensitivity_deg: float = 70.0
var rate_max_deg: float = 670.0
## Betaflight Actual Rates' third number: 0 = the plain curve, up to 1 =
## much softer around centre stick.
var rate_expo: float = 0.54 ## Betaflight 4.x default (rc_expo 54)

## Betaflight-style on-screen display in the FPV view (timer, battery,
## speed, altitude...). The top-left key hints are separate.
var osd_enabled: bool = true
## Battery simulation: the pack drains, its voltage sags under load and
## a drained pack loses punch; the OSD shows voltage, mAh and flight
## time. Off (default): unlimited flight, no battery readout.
var battery_enabled: bool = false
## Units shown in the OSD and the drone specs: 0 metric (km/h, m, g),
## 1 imperial (mph, ft, oz).
var units: int = 0

func speed_text(mps: float) -> String:
	return ("%dmph" % int(round(mps * 2.23694))) if units == 1 else ("%dkm/h" % int(round(mps * 3.6)))

func height_text(m: float) -> String:
	return ("%dft" % int(round(m * 3.28084))) if units == 1 else ("%dm" % int(round(m)))

## A drone spec tag ("150 km/h", "245 g") in the chosen units.
func spec_tag(tag: String) -> String:
	if units != 1:
		return tag
	if tag.ends_with(" km/h"):
		return "%d mph" % int(round(float(tag.trim_suffix(" km/h")) * 0.621371))
	if tag.ends_with(" g"):
		return "%.1f oz" % (float(tag.trim_suffix(" g")) * 0.035274)
	return tag

func spec_tags(tags: Array) -> String:
	var out: Array[String] = []
	for t in tags:
		out.append(spec_tag(t))
	return "  ·  ".join(out)

## Analog video look over the FPV feed: 0 off, 1 light, 2 strong.
var video_effect: int = 0
const VIDEO_EFFECT_STRENGTH: Array[float] = [0.0, 0.45, 0.9]
## Wind on outdoor maps: 0 off, 1 light (~3 m/s), 2 gusty (~7 m/s with gusts).
var wind_level: int = 0

## Which real frame Drone.apply_profile() should spawn as - "seeker3" or
## "whoop" (see drone.gd's PROFILES). Set by the menu's drone-choice panel.
var selected_drone: String = "seeker3"

## Everything above that a pilot sets survives a restart. Rather than a
## save() call at every place a setting changes (menu, pause menu, the
## in-flight panel...), a snapshot is compared once a second and written
## when it differs. Skipped under --selftest / --dev-preview, which
## change settings freely and must neither read nor overwrite the
## pilot's own file.
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVED_FIELDS: Array[String] = ["crosshair_enabled", "shadows_enabled", "graphics_quality", "performance_mode",
	"max_fps", "camera_angle_deg", "camera_fov_deg", "rate_center_sensitivity_deg", "rate_max_deg", "rate_expo",
	"selected_drone", "osd_enabled", "battery_enabled", "video_effect", "wind_level", "units"]
var _persist: bool = true
var _last_saved: String = ""
var _save_timer: float = 0.0
var _fullscreen_saved: bool = false

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	_persist = not (args.has("--selftest") or args.has("--dev-preview"))
	if _persist:
		_load()
	Engine.max_fps = max_fps
	_last_saved = _snapshot()

func _process(delta: float) -> void:
	if not _persist:
		return
	_save_timer += delta
	if _save_timer < 1.0:
		return
	_save_timer = 0.0
	var snap: String = _snapshot()
	if snap != _last_saved:
		_save()
		_last_saved = snap

func _snapshot() -> String:
	var parts: Array[String] = [str(is_fullscreen())]
	for f in SAVED_FIELDS:
		parts.append(str(get(f)))
	return "|".join(parts)

func _save() -> void:
	var cfg := ConfigFile.new()
	for f in SAVED_FIELDS:
		cfg.set_value("settings", f, get(f))
	cfg.set_value("settings", "fullscreen", is_fullscreen())
	cfg.save(SETTINGS_PATH)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	for f in SAVED_FIELDS:
		if cfg.has_section_key("settings", f):
			var v = cfg.get_value("settings", f)
			if typeof(v) == typeof(get(f)) or (typeof(get(f)) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				set(f, v)
	if not Drone.PROFILES.has(selected_drone):
		selected_drone = "seeker3"
	if cfg.get_value("settings", "fullscreen", false):
		set_fullscreen.call_deferred(true)

func set_max_fps(v: int) -> void:
	max_fps = v
	Engine.max_fps = v

## Called once by every map in its _ready(): shadows, render scale,
## per-object draw distances and the drone camera's view distance.
func apply_graphics_settings() -> void:
	apply_shadow_setting()
	Engine.physics_ticks_per_second = PHYSICS_HZ_PERFORMANCE if performance_mode else PHYSICS_HZ_NORMAL
	var q: int = clampi(graphics_quality, 0, 2)
	var vp: Viewport = get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = QUALITY_RENDER_SCALE[q]
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_apply_draw_distances(scene, QUALITY_SMALL_RANGE[q], QUALITY_MEDIUM_RANGE[q])
	var drone: Node = scene.find_child("Drone", true, false)
	if drone is RigidBody3D:
		(drone as RigidBody3D).contact_monitor = performance_mode
	var cam: Camera3D = vp.get_camera_3d()
	if cam:
		cam.far = minf(cam.get_meta("profile_far", cam.far), QUALITY_VIEW_DISTANCE[q])
		_fit_fog(scene, cam.far)

## Generated maps use depth fog that turns fully into the horizon
## colour just before the camera's far plane - so the end of the drawn
## world is never a visible edge, whatever the view distance.
func _fit_fog(scene: Node, far: float) -> void:
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null or we.environment == null or not we.environment.has_meta("depth_fog"):
		return
	var env: Environment = we.environment
	var start: float = env.get_meta("depth_fog")
	env.fog_depth_end = far * 0.96
	env.fog_depth_begin = minf(start, far * 0.4)

func _apply_draw_distances(node: Node, small_range: float, medium_range: float) -> void:
	if node is GeometryInstance3D and not (node.get_parent() is Drone) and not node.has_meta("geo_detail"):
		var gi := node as GeometryInstance3D
		var size: float = gi.get_aabb().size.length() * _max_scale(gi)
		if node.has_meta("geo_batch"):
			# A generated map's batch is a whole 64 m cell of one material,
			# already culled by the frustum - a distance cut there made
			# whole rows of objects pop in and out. Only the Low setting
			# drops the far detail.
			size = SMALL_OBJECT_SIZE if (small_range < 100.0 and size < MEDIUM_OBJECT_SIZE) else MEDIUM_OBJECT_SIZE
		if size < SMALL_OBJECT_SIZE:
			gi.visibility_range_end = small_range
		elif size < MEDIUM_OBJECT_SIZE:
			gi.visibility_range_end = medium_range
		# Hysteresis: without a margin, an object right at the boundary
		# flickered on and off with every tiny change in distance.
		gi.visibility_range_end_margin = gi.visibility_range_end * 0.1
	for child in node.get_children():
		_apply_draw_distances(child, small_range, medium_range)

func _max_scale(n: Node3D) -> float:
	var s: Vector3 = n.global_transform.basis.get_scale()
	return maxf(s.x, maxf(s.y, s.z))

## Ground height per map for FakeShadows (the factory's paved site sits
## 2 cm above its grass). Maps without an entry (the indoor school) get
## no ground shadows, just the drone's own.
const SHADOW_GROUND_Y := {"Main": 0.5, "Main2": 0.52}

func apply_shadow_setting() -> void:
	var scene: Node = get_tree().current_scene
	var sun := get_tree().root.find_child("Sun", true, false) as DirectionalLight3D
	if scene == null or sun == null:
		return
	sun.shadow_enabled = false # engine shadow maps: see shadows_enabled
	# The ground shadow mask is built once per map (it doesn't depend on
	# the drone); later calls just switch it on/off.
	# Generated maps declare their own (meta "shadow_ground_y" and
	# optionally "shadow_region", see BuiltMap).
	var ground_y = scene.get_meta("shadow_ground_y") if scene.has_meta("shadow_ground_y") else SHADOW_GROUND_Y.get(scene.name, null)
	if ground_y != null and not scene.has_meta("ground_materials"):
		FakeShadows.build(scene, sun, ground_y, scene.get_meta("shadow_region", Rect2(-250, -250, 500, 500)))
	FakeShadows.set_enabled(scene, shadows_enabled)
	var old_drone_shadow: Node = scene.get_node_or_null("DroneShadow")
	if old_drone_shadow:
		old_drone_shadow.free()
	if not shadows_enabled:
		return
	var drone := scene.get_node_or_null("Drone") as Drone
	if drone:
		var ds := DroneShadow.new()
		ds.name = "DroneShadow"
		# Positioned every rendered frame from the already-interpolated
		# drone transform - interpolating it again would make it lag.
		ds.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		scene.add_child(ds)
		ds.setup(drone, sun, drone.arm_length * 2.0 + 0.05)

func set_fullscreen(v: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
