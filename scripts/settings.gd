extends Node

# Preloaded, not global classes (in-game update packs can't add those).
const TakeRecorder = preload("res://scripts/take_recorder.gd")

## Autoloaded singleton holding options that need to survive scene
## changes (menu <-> gameplay): crosshair, fullscreen, shadow quality.

var crosshair_enabled: bool = true
## On by default: WorldShading's static sun shadow map (rendered once
## per map) plus the drone's own DroneShadow, not Godot's shadow maps -
## those rendered nothing at all on the dev machine's Intel GPU.
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
## Render distance (m): how far the world is drawn before it fades into
## the fog. Its own setting since 2026-10 (it used to follow the
## quality); the slider in Settings -> Graphics.
var view_distance: float = 1200.0
const VIEW_DISTANCE_MIN: float = 300.0
const VIEW_DISTANCE_MAX: float = 3000.0
const SMALL_OBJECT_SIZE: float = 3.0
const MEDIUM_OBJECT_SIZE: float = 12.0
var max_fps: int = 60 ## 0 means uncapped ("Unlimited" in the menu slider).
## VSync (Settings -> Screen): on, frames wait for the screen - smooth,
## at most the screen's refresh rate. Off, as many frames as the computer
## manages (an FPS limit above 60 or "Unlimited" really goes past 60) -
## but on a weak machine frames then come unevenly (seen as jerking at
## ~45 fps on the dev Mac), and the picture can tear.
var vsync: bool = true

## FPV camera, set from the in-game pause menu and kept across maps.
var camera_angle_deg: float = 25.0
var camera_fov_deg: float = 80.0

## Acro rates exactly like Betaflight's Rates tab (see Rates): the rate
## type and, per axis, the three numbers the Configurator shows. What a
## freshly spawned drone flies with; the pause menu changes them live.
var rates_type: int = Rates.ACTUAL
var rates_roll: Array = [70.0, 670.0, 0.54]
var rates_pitch: Array = [70.0, 670.0, 0.54]
var rates_yaw: Array = [70.0, 670.0, 0.54]

## Rate profiles (2026-10-14, user: "two or more rate profiles, saved and
## switchable"): like Betaflight's rateprofiles, each holds the rate type,
## the three axes and throttle MID/EXPO. The fields above are always the
## active profile's; switching stores them into their slot and loads the
## other. Switched in Settings -> Rates or by an assigned radio switch
## (InputManager "rates" control: a 3-position switch picks 1/2/3, a
## button steps through them).
const RATE_PROFILES: int = 3
var rate_profile: int = 0
var rate_profiles: Array = []

func _rate_snapshot() -> Dictionary:
	return {"type": rates_type, "roll": rates_roll.duplicate(), "pitch": rates_pitch.duplicate(), "yaw": rates_yaw.duplicate(),
		"mid": throttle_mid, "expo": throttle_expo}

## Fills missing slots with copies of the active rates (first start, or a
## settings file from before profiles).
func _ensure_rate_profiles() -> void:
	while rate_profiles.size() < RATE_PROFILES:
		rate_profiles.append(_rate_snapshot())
	rate_profile = clampi(rate_profile, 0, RATE_PROFILES - 1)

func select_rate_profile(i: int) -> void:
	_ensure_rate_profiles()
	i = clampi(i, 0, RATE_PROFILES - 1)
	if i == rate_profile:
		return
	rate_profiles[rate_profile] = _rate_snapshot()
	var p: Dictionary = rate_profiles[i]
	rates_type = int(p.get("type", Rates.ACTUAL))
	rates_roll = (p.get("roll", rates_roll) as Array).duplicate()
	rates_pitch = (p.get("pitch", rates_pitch) as Array).duplicate()
	rates_yaw = (p.get("yaw", rates_yaw) as Array).duplicate()
	throttle_mid = float(p.get("mid", 0.5))
	throttle_expo = float(p.get("expo", 0.0))
	rate_profile = i
	rate_profile_changed.emit(i)

signal rate_profile_changed(i: int)

func rate_values(axis: int) -> Array:
	return [rates_roll, rates_pitch, rates_yaw][axis]

func set_rate_values(axis: int, v: Array) -> void:
	match axis:
		0: rates_roll = v
		1: rates_pitch = v
		2: rates_yaw = v

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

## (Before Round 2: the analog video look, 0 off/1 light/2 strong - only
## read once now, to carry it over to camera_look.)
var video_effect: int = 0
## FPV camera system (FpvVideo): 0 Clean, 1 Analog, 2 Digital (DJI/
## Walksnail-like), 3 HDZero - its picture and how a weak video link
## breaks up (distance, walls and hills between drone and pilot).
var camera_look: int = 0
## Wind on outdoor maps: 0 off, 1 light, 2 medium, 3 strong (mean wind
## at 10 m: 3 / 6 / 10 m/s, plus gusts and turbulence - see Drone._wind).
## (Before 2026-10-04: 0 off, 1 light, 2 "gusty" ~7 m/s - now medium.)
var wind_level: int = 0
const WIND_NAMES: Array[String] = ["Off", "Light", "Medium", "Strong"]
const WIND_SPEEDS: Array[float] = [0.0, 3.0, 6.0, 10.0]
## Prop damage (Drone): a hard prop strike chips a prop - less thrust on
## that motor, vibration, a slight pull. Reset repairs. Off by default.
var prop_damage: bool = false
## Water damage (Drone._update_water): on, a drone in the water splashes,
## cuts its motors and is reset; off, it flies through with a splash in
## and out and some drag. On by default (user, 2026-10-14).
var water_damage: bool = true
## Race mode: a translucent ghost flies your best lap (RaceCourse).
var race_ghost: bool = true
## Competition rule (MultiGP style): a missed gate voids the lap instead of
## "go back". Off by default (decided 2026-10-11).
var race_strict: bool = false
## Keyboard flying: how far a held key pushes the stick (0.3-1.0); the
## stick ramps there (InputManager.KB_RAMP). And the key guide on screen.
var keyboard_strength: float = 0.6
var keyboard_help: bool = true
## The racing line through a race track's gates (RaceCourse._build_line):
## its hue in degrees (full saturation), -1 = off. One slider in
## Settings -> Flight: far left Off, then the colour wheel. Orange default.
var race_line_hue: int = 30
## (Saved files from before the slider had "race_line" on/off: _load.)
func race_line_on() -> bool:
	return race_line_hue >= 0
func race_line_colour() -> Color:
	return Color.from_hsv(clampi(race_line_hue, 0, 359) / 360.0, 1.0, 1.0)
## How far ahead the racing line reaches (RaceCourse._update_line):
## always the next gate, then more gates (up to 3) while the line is
## shorter than this target - close gates show several, a long straight
## one. 0 Short / 1 Medium / 2 Long.
const RACE_LINE_LENGTHS: Array[float] = [25.0, 45.0, 70.0]
var race_line_length: int = 1
func race_line_target() -> float:
	return RACE_LINE_LENGTHS[clampi(race_line_length, 0, 2)]

## Pilot aids from the sim research (Liftoff / Velocidrone have them):
## live stick overlay in the OSD (optional, off by default), Betaflight's
## throttle MID/EXPO, a fisheye camera lens (0 off, 1 light, 2 strong).
## (No turtle mode: a quad on its back rights itself after 2 s anyway.)
var stick_overlay: bool = false
## Prop wash in the flight model (Drone._prop_wash) - on by default.
var prop_wash: bool = true
var throttle_mid: float = 0.5
var throttle_expo: float = 0.0
var lens_fisheye: int = 0
## Ask GitHub on menu start whether a newer release exists (Updater);
## a quiet line in the menu, never a popup. Default on (user, 2026-10-21), asked on the first-run card.
var check_updates: bool = true
## The first-run card (main menu) was shown: nothing is sent before it.
var first_run_done: bool = false
## "Low-res window": on a high-density screen (Retina, scaled Windows)
## the whole window - 3D, HUD, menus - runs at half the pixels each way,
## from the next start (DISPLAY_OVERRIDE). Back in 0.11.1 (user,
## 2026-10-22): 0.11.0's live "Full 3D resolution" halved only the 3D,
## which looked worse and gave no FPS (the 3D is not pixel-bound on the
## dev Mac; presenting the Retina window is).
var low_res_window: bool = false
## Opt-in ("Yes, count me" on the first-run card, or Settings): send
## version + platform once, at the first start (FirstStartPing).
var count_first_start: bool = false
## That one ping went through - never send it again (any version).
var first_start_pinged: bool = false

## Betaflight's throttle curve (rc.c, thrMid/thrExpo): identity at MID
## 0.5 / EXPO 0, flatter around MID with expo.
func throttle_curve(t: float) -> float:
	var t2: float = t - throttle_mid
	var y: float = (1.0 - throttle_mid) if t2 > 0.0 else (throttle_mid if t2 < 0.0 else 1.0)
	return clampf(throttle_mid + t2 * (1.0 - throttle_expo + throttle_expo * t2 * t2 / maxf(y * y, 0.0001)), 0.0, 1.0)

## Freestyle (every map, race maps without timing) or Race (race maps
## only: lap timer, ghost, personal bests). Picked in the menu.
const MODE_FREESTYLE: int = 0
const MODE_RACE: int = 1
var game_mode: int = MODE_FREESTYLE

## Which real frame Drone.apply_profile() should spawn as - "seeker3" or
## "whoop" (see drone.gd's PROFILES). Set by the menu's drone-choice panel.
var selected_drone: String = "seeker3"
## Race maps: which of the map's tracks (1-based, RaceCourse.make) the
## next race map load builds. Set by the track menu.
var race_track: int = 1

## Everything above that a pilot sets survives a restart. Rather than a
## save() call at every place a setting changes (menu, pause menu, the
## in-flight panel...), a snapshot is compared once a second and written
## when it differs. Skipped under --selftest / --dev-preview, which
## change settings freely and must neither read nor overwrite the
## pilot's own file.
const SETTINGS_PATH: String = "user://settings.cfg"
const SAVED_FIELDS: Array[String] = ["crosshair_enabled", "shadows_enabled", "graphics_quality", "performance_mode",
	"max_fps", "vsync", "camera_angle_deg", "camera_fov_deg", "view_distance", "rates_type", "rates_roll", "rates_pitch", "rates_yaw",
	"selected_drone", "game_mode", "osd_enabled", "battery_enabled", "video_effect", "wind_level", "units",
	"stick_overlay", "prop_wash", "throttle_mid", "throttle_expo", "lens_fisheye",
	"prop_damage", "water_damage", "race_ghost", "race_strict", "keyboard_strength", "keyboard_help", "race_line_hue", "race_line_length", "check_updates", "first_run_done", "low_res_window", "count_first_start", "first_start_pinged", "camera_look", "rate_profile", "rate_profiles"]
var _persist: bool = true
var _last_saved: String = ""
var _save_timer: float = 0.0
var _fullscreen_saved: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS # (F11 in the pause menu too)
	var args := OS.get_cmdline_user_args()
	# (Also not for a `-s <script>` dev run: it must not save either.)
	_persist = not (args.has("--selftest") or args.has("--dev-preview") or OS.get_cmdline_args().has("-s") or OS.get_cmdline_args().has("--script"))
	if _persist:
		_load()
	apply_fps_cap(max_fps)
	_last_saved = _snapshot()
	if _persist and not FileAccess.file_exists(DISPLAY_OVERRIDE):
		_last_saved = "" # (the first save writes it - from 0.11.0 or a first start)

func _process(delta: float) -> void:
	_update_far_with_height()
	_settle_window_mode()
	if not _persist or _want_fullscreen >= 0:
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
	if not rate_profiles.is_empty():
		rate_profiles[rate_profile] = _rate_snapshot() # (the active slot follows edits)
	var parts: Array[String] = [str(is_fullscreen())]
	for f in SAVED_FIELDS:
		parts.append(str(get(f)))
	return "|".join(parts)

## Starts from the file on disk, so keys this version doesn't know (written
## by a newer version the pilot also runs) survive a save.
func _save(path: String = SETTINGS_PATH) -> void:
	var cfg := ConfigFile.new()
	cfg.load(path)
	for f in SAVED_FIELDS:
		cfg.set_value("settings", f, get(f))
	cfg.set_value("settings", "fullscreen", is_fullscreen())
	cfg.save(path)
	# (Not from a --record-all dev session: 0.11.0 would read the file.)
	if path == SETTINGS_PATH and not TakeRecorder.active():
		write_display_override(DISPLAY_OVERRIDE)

func _load() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		_first_window.call_deferred()
		return
	for f in SAVED_FIELDS:
		if cfg.has_section_key("settings", f):
			var v = cfg.get_value("settings", f)
			if typeof(v) == typeof(get(f)) or (typeof(get(f)) == TYPE_FLOAT and typeof(v) == TYPE_INT):
				set(f, v)
	# Before the colour slider (2026-10-11): a plain on/off racing line.
	if not cfg.has_section_key("settings", "race_line_hue") and cfg.get_value("settings", "race_line", true) == false:
		race_line_hue = -1
	# Before per-axis rates (2026-10): one Actual Rates curve for all axes.
	if not cfg.has_section_key("settings", "rates_roll") and cfg.has_section_key("settings", "rate_max_deg"):
		var old: Array = [float(cfg.get_value("settings", "rate_center_sensitivity_deg", 70.0)), float(cfg.get_value("settings", "rate_max_deg", 670.0)), float(cfg.get_value("settings", "rate_expo", 0.54))]
		rates_type = Rates.ACTUAL
		rates_roll = old.duplicate()
		rates_pitch = old.duplicate()
		rates_yaw = old.duplicate()
	for axis in range(3):
		var v: Array = rate_values(axis)
		if v.size() != 3:
			set_rate_values(axis, Rates.DEFAULTS[Rates.ACTUAL].duplicate())
	if not cfg.has_section_key("settings", "camera_look") and video_effect > 0:
		camera_look = 1 # the old analog look -> the Analog camera
	_ensure_rate_profiles()
	if not Drone.PROFILES.has(selected_drone):
		selected_drone = "seeker3"
	# 0.11.0's "Full 3D resolution" off, and 0.10.x's override file
	# (0.11.0 deleted that file and set low_res_3d instead).
	if not cfg.has_section_key("settings", "low_res_window"):
		var old := ConfigFile.new()
		low_res_window = cfg.get_value("settings", "low_res_3d", false) == true or \
			(old.load(DISPLAY_OVERRIDE) == OK and old.get_value("display", "window/dpi/allow_hidpi", true) == false)
	# The saved choice both ways (until 0.11.0 only fullscreen was
	# re-applied; a windowed pilot got fullscreen at every start).
	if cfg.has_section_key("settings", "fullscreen"):
		_want_fullscreen = 1 if cfg.get_value("settings", "fullscreen") == true else 0
	else:
		_first_window.call_deferred()

## Camera angle / FOV changed (Settings screen or pause menu): the drone
## and every open slider follow.
signal camera_changed

func set_camera_angle(v: float) -> void:
	camera_angle_deg = v
	camera_changed.emit()

func set_camera_fov(v: float) -> void:
	camera_fov_deg = v
	camera_changed.emit()

## Keeps a slider (UIKit.slider: the HSlider is the last child of
## `parent` right after the call) in step with a camera value changed
## elsewhere.
func follow_camera(parent: Control, value_label: Label, getter: Callable, suffix: String) -> void:
	var sl := parent.get_child(parent.get_child_count() - 1) as HSlider
	camera_changed.connect(func():
		if not is_instance_valid(sl):
			return
		var v: float = getter.call()
		if not is_equal_approx(sl.value, v):
			sl.set_value_no_signal(v)
			value_label.text = str(int(round(v))) + suffix)

func set_max_fps(v: int) -> void:
	max_fps = v
	apply_fps_cap(v)

## Sets the frame cap, and VSync as chosen (see `vsync`).
func apply_fps_cap(cap: int) -> void:
	Engine.max_fps = cap
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if vsync else DisplayServer.VSYNC_DISABLED)

func set_vsync(on: bool) -> void:
	vsync = on
	apply_fps_cap(Engine.max_fps)

## Called once by every map in its _ready(): shadows, render scale,
## per-object draw distances and the drone camera's view distance.
func apply_graphics_settings() -> void:
	RenderingServer.global_shader_parameter_set("sh_tree_near", Forest.NEAR_RANGE[clampi(graphics_quality, 0, 2)])
	apply_shadow_setting()
	Engine.physics_ticks_per_second = PHYSICS_HZ_PERFORMANCE if performance_mode else PHYSICS_HZ_NORMAL
	var q: int = clampi(graphics_quality, 0, 2)
	var vp: Viewport = get_viewport()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = render_scale(q)
	var scene: Node = get_tree().current_scene
	if scene == null:
		return
	_apply_draw_distances(scene, QUALITY_SMALL_RANGE[q], QUALITY_MEDIUM_RANGE[q])
	var drone: Node = scene.find_child("Drone", true, false)
	if drone is RigidBody3D:
		(drone as RigidBody3D).contact_monitor = performance_mode
	var cam: Camera3D = vp.get_camera_3d()
	if cam:
		# (The whoop's camera keeps its own shorter limit: its near plane
		# is 12 mm, and depth precision runs out far beyond 400 m.)
		cam.far = minf(cam.get_meta("profile_far", cam.far), clampf(view_distance, VIEW_DISTANCE_MIN, VIEW_DISTANCE_MAX))
		_fit_fog(scene, cam.far)
	LooksFx.attach(scene)

## The 3D render scale for a quality. With "Full screen resolution" off on
## a high-density screen the window has half the pixels each way, so the
## 3D is drawn at twice the share (up to all of it) - the same 3D detail
## as with full resolution; only the HUD, menus and the camera look get
## the cheaper, softer pixels.
func render_scale(q: int) -> float:
	var sc: float = QUALITY_RENDER_SCALE[clampi(q, 0, 2)]
	if reduced_resolution_active() and DisplayServer.screen_get_dpi() >= 150:
		sc = minf(1.0, sc * 2.0)
	return sc

static func high_density_screen() -> bool:
	return DisplayServer.screen_get_dpi() >= 150

## Named in project.godot as project_settings_override: the engine reads
## it before the window opens, so the window starts in the pilot's mode
## (fullscreen or not) and, with "Low-res window", without HiDPI - the
## whole game at half the pixels. Written with every settings save.
## Measured on the dev Mac (Iris 6100, 2880x1800), Village on Low:
## 43 fps with full resolution, 62 fps without (0.10.x).
const DISPLAY_OVERRIDE: String = "user://display_override.cfg"

func write_display_override(path: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("display", "window/size/mode", DisplayServer.WINDOW_MODE_FULLSCREEN if is_fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED)
	if low_res_window:
		cfg.set_value("display", "window/dpi/allow_hidpi", false)
	cfg.save(path)

## "Low-res window" differs from how this window was opened: the change
## waits for a restart.
func low_res_restart_pending() -> bool:
	return low_res_window != reduced_resolution_active()

## The saved window mode (-1 = none). macOS ignores a mode change while
## the window is still entering project.godot's fullscreen, so it is
## re-applied until it holds (for the first 5 s of frames only).
var _want_fullscreen: int = -1
var _settle_t: int = 0
var _settle_start: int = 0
func _settle_window_mode() -> void:
	if _want_fullscreen < 0:
		return
	var now: int = Time.get_ticks_msec()
	if _settle_start == 0:
		_settle_start = now
	if now - _settle_start > 5000:
		_want_fullscreen = -1
		return
	if is_fullscreen() != (_want_fullscreen == 1) and now - _settle_t > 500:
		_settle_t = now
		if _want_fullscreen == 1:
			set_fullscreen(true)
		else:
			_first_window()

## The very first start (no saved settings): a window at ~80% of the
## screen, centred, instead of project.godot's fullscreen (user,
## 2026-10-21) - from then on the override file opens it as left.
func _first_window() -> void:
	_want_fullscreen = 0
	set_fullscreen(false)
	var r: Rect2i = DisplayServer.screen_get_usable_rect()
	var sz := Vector2i(Vector2(r.size) * 0.8)
	DisplayServer.window_set_size(sz)
	DisplayServer.window_set_position(r.position + (r.size - sz) / 2)

## F11, Alt+Enter (and macOS's Ctrl+Cmd+F) toggle fullscreen anywhere.
func _input(event: InputEvent) -> void:
	var k := event as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	if k.keycode == KEY_F11 or (k.keycode in [KEY_ENTER, KEY_KP_ENTER] and k.alt_pressed) or (k.keycode == KEY_F and k.ctrl_pressed and k.meta_pressed):
		_want_fullscreen = -1
		set_fullscreen(not is_fullscreen())
		get_viewport().set_input_as_handled()

## A race map's shadow map holds its track's gates: one cached file per
## track (and the track's rev).
func _shadow_suffix(scene: Node) -> String:
	var rc: RaceCourse = scene.get_node_or_null("RaceCourse") as RaceCourse
	return "-shadow.bin" if rc == null else "-shadow-t%d-r%d.bin" % [rc.track, rc.rev]

## Closes the game and starts it again (settings and the override file
## saved first) - the window's resolution mode can only change at startup.
func restart_game() -> void:
	if _persist:
		_save()
	var args: PackedStringArray = OS.get_cmdline_args()
	if not OS.has_feature("template"):
		# Run from the project folder: Godot's own arguments (--path) aren't
		# in get_cmdline_args, and without them it opens the project manager.
		args = PackedStringArray(["--path", ProjectSettings.globalize_path("res://")]) + args
	OS.set_restart_on_exit(true, args)
	get_tree().quit()

## True if the window runs at reduced resolution right now (the file was
## there at startup).
func reduced_resolution_active() -> bool:
	return not bool(ProjectSettings.get_setting("display/window/dpi/allow_hidpi", true))

## Haze scale height (m): how fast the low-level haze thins with height.
const HAZE_SCALE_HEIGHT: float = 220.0

## Depth fog turns fully into the horizon colour just before the
## camera's far plane - so the end of the drawn world is never a visible
## edge, whatever the view distance (WorldShading's own cheap fog).
func _fit_fog(scene: Node, far: float) -> void:
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we:
		WorldShading.fit_fog(we.environment, far)
	# The haze thins out with height on the outdoor generated maps
	# (world_common sh_haze_thin), measured from the spawn's ground.
	var info: Dictionary = MapCatalog.for_scene(scene.scene_file_path)
	var drone := scene.find_child("Drone", true, false) as Node3D
	if scene is BuiltMap and drone and not info.get("indoor", false):
		_haze = Vector4(drone.global_position.y, HAZE_SCALE_HEIGHT, far * 0.96, 0)
		_haze_far = far
	else:
		_haze = Vector4.ZERO
		_haze_far = 0.0
	RenderingServer.global_shader_parameter_set("sh_haze_h", _haze)

## With the haze thinning upward the view from high up reaches further,
## so the far plane grows with the height above the map's ground (up to
## the drone camera's own limit) - otherwise the end of the drawn world
## would sit as a ring of fog 1 km away under a clear sky.
var _haze := Vector4.ZERO
var _haze_far: float = 0.0
const FAR_PER_HEIGHT: float = 1.0 / 250.0

func _update_far_with_height() -> void:
	if _haze_far <= 0.0:
		return
	var cam: Camera3D = get_viewport().get_camera_3d()
	if cam == null or not cam.has_meta("profile_far"):
		return
	var agl: float = maxf(cam.global_position.y - _haze.x, 0.0)
	var far: float = minf(float(cam.get_meta("profile_far")), _haze_far * (1.0 + agl * FAR_PER_HEIGHT))
	if absf(far - cam.far) < cam.far * 0.02:
		return
	cam.far = far
	_haze.z = far * 0.96
	RenderingServer.global_shader_parameter_set("sh_haze_h", _haze)

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

## The area a map's sun shadow map covers: generated maps say it
## themselves (meta "shadow_region", see BuiltMap); the hand-made school
## is indoors and has none.

## Converts the map's materials to WorldShading (fog, sun shadows) and
## switches the shadows. The shadow map itself is rendered once per map.
func apply_shadow_setting() -> void:
	var scene: Node = get_tree().current_scene
	var sun := get_tree().root.find_child("Sun", true, false) as DirectionalLight3D
	if scene == null:
		return
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	WorldShading.setup(scene, we.environment if we else null)
	# Hand-made maps: their gradient sky gets the clouds too (BuiltMap does
	# its own).
	if we and sun and not (scene is BuiltMap) and we.environment.sky and we.environment.sky.sky_material is ProceduralSkyMaterial:
		BuiltMap.cloud_sky(we.environment.sky, we.environment.sky.sky_material, sun, 0.6, we)
	var region: Rect2 = scene.get_meta("shadow_region", Rect2())
	if sun:
		sun.shadow_enabled = false # engine shadow maps: see WorldShading
		var parts: Vector3 = scene.get_meta("light_parts", Vector3(0.45, 0.14, 0.55))
		WorldShading.set_light(-sun.global_transform.basis.z, parts.x, parts.y, parts.z, sun.light_color)
		if region.has_area() and not scene.has_meta("shadow_map_done"):
			scene.set_meta("shadow_map_done", true)
			WorldShading.clear_shadow_map()
			WorldShading.capture(scene, -sun.global_transform.basis.z, region, WorldShading.RES[clampi(graphics_quality, 0, 2)],
				MapCache.path(scene, _shadow_suffix(scene)) if scene is BuiltMap and MapCache.enabled(scene) else "")
	if not region.has_area():
		WorldShading.clear_shadow_map()
	WorldShading.set_shadows(shadows_enabled and region.has_area())
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
