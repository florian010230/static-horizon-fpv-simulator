class_name FpvVideo
extends ColorRect

## The FPV video feed (Settings -> Camera & HUD -> Camera): Clean, Analog,
## Digital or HDZero - the look of each system (shaders/fpv_video.gdshader)
## and a video link from the drone to the pilot that weakens with
## distance and with walls and hills in between. Also the lens fisheye.
## A full-screen pass under the OSD, made by ui.gd; hidden (free) on
## Clean without fisheye. Only for the FPV view (and the replay's FPV
## camera - a DVR records what the goggles showed), not chase/LOS.
##
## The link (link budget in dB, the way RF people reason about range):
##   margin = budget - free-space path loss(distance) - obstruction loss
##            - antenna null overhead + slow fading
## Free-space path loss at 5.8 GHz: 20*log10(d / 1 m) + 47.7 dB (Friis).
## Budget 117 dB: a 200 mW VTX (+23 dBm), ~2 dBi antennas on both ends,
## a receiver that stays clean to about -90 dBm - so a clear line of
## sight stays clean to several hundred metres and gets noisy around a
## kilometre, as real 200 mW analog does. Obstructions come from rays
## between the pilot (spawn point, 1.5 m up) and the drone a few times a
## second: each surface crossed costs 4 dB plus 0.25 dB per metre of
## stuff behind it (5.8 GHz through a brick or wood wall: ~5-15 dB,
## concrete more - ITU-R P.2040; foliage ~1 dB/m - ITU-R P.833), capped
## at 30 dB (the signal still gets round corners by reflection). Each
## system turns the margin into its own "badness" (0 perfect .. 1 lost):
## analog degrades gradually from ~15 dB
## down; the digital systems have better receivers (OFDM, diversity) and
## stay perfect longer, then fail over a few dB ("the cliff").

const BUDGET_DB: float = 117.0
const WALL_DB: float = 4.0
const DEPTH_DB_PER_M: float = 0.25
const MAX_OBSTRUCTION_DB: float = 30.0
const MAX_THICKNESS: float = 40.0
const RAY_INTERVAL: float = 0.15
const PILOT_HEIGHT: float = 1.5
const LOOK_NAMES: Array[String] = ["Clean", "Analog", "Digital", "HDZero"]

## Dev/test aid: >= 0 forces the link quality (1 - badness) for every look.
static var force_quality: float = -1.0

var ui: Node
## Link margin (dB, smoothed) and the current look's badness/quality.
var margin_db: float = 60.0
var badness: float = 0.0
## 0..100 for the OSD ("LQ"), or -1 on Clean.
var link_quality: int = -1

var _mat: ShaderMaterial
var _obstruction_db: float = 0.0
var _obstruction_target: float = 0.0
var _ray_t: float = 0.0
var _fade_noise := FastNoiseLite.new()
var _t: float = 0.0
var _seed: float = 0.0
# Analog events
var _flash_t: float = 0.0
var _tear: float = 0.0
var _roll: float = 0.0
# Digital/HDZero: freezes and latency, by rendering from a held camera.
var _freeze_t: float = 0.0
var _hold_cam: Camera3D
var _hist: Array = [] # [time, Transform3D] of the FPV camera, newest last
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/fpv_video.gdshader")
	material = _mat
	_fade_noise.seed = 11
	_fade_noise.frequency = 0.35
	_rng.seed = 5

func setup(p_ui: Node) -> void:
	ui = p_ui

func _ready() -> void:
	# The sun glare (LooksFx) belongs under the camera look.
	var g: Node = get_parent().get_node_or_null("SunGlare")
	if g:
		get_parent().move_child.call_deferred(g, 0)

func _drone() -> Drone:
	return ui.get("_drone") as Drone if ui else null

## The camera whose picture is on screen when it is an FPV view (the
## drone's own, or the replay's in FPV mode), else null.
func _fpv_camera() -> Camera3D:
	var d: Drone = _drone()
	if d == null or ui.get("_los_cam") != null:
		return null
	var rp: Replay = ui.get("replay")
	if rp and rp.active:
		return rp._cam if rp._cam_mode == 1 else null
	return d.get_node_or_null("CameraMount/Camera3D") as Camera3D

func _process(delta: float) -> void:
	var look: int = clampi(Settings.camera_look, 0, 3)
	var cam: Camera3D = _fpv_camera()
	var rp: Replay = ui.get("replay") if ui else null
	var fish: float = [0.0, 0.22, 0.5][clampi(Settings.lens_fisheye, 0, 2)]
	if cam == null:
		# Chase/LOS: plain picture (the replay's chase view keeps the lens
		# as before - a GoPro-style chase cam).
		look = 0
		if ui and ui.get("_los_cam") != null:
			fish = 0.0
	_t += delta
	var replaying: bool = rp != null and rp.active
	if cam:
		_update_link(cam, delta, look)
	else:
		badness = 0.0
	link_quality = -1 if look == 0 or cam == null else int(round(100.0 * (1.0 - badness)))
	visible = look != 0 or fish > 0.0
	_update_events(delta, look)
	var flying_cam: bool = cam != null and not replaying
	_update_hold(flying_cam, delta, look)
	if not visible:
		return
	var vsz: Vector2 = get_viewport_rect().size
	_mat.set_shader_parameter("look", look)
	_mat.set_shader_parameter("bad", badness)
	_mat.set_shader_parameter("seed", _seed)
	_mat.set_shader_parameter("fisheye", fish)
	_mat.set_shader_parameter("aspect", vsz.x / maxf(vsz.y, 1.0))
	_mat.set_shader_parameter("flash", clampf(_flash_t * 8.0, 0.0, 1.0))
	_mat.set_shader_parameter("tear", _tear)
	_mat.set_shader_parameter("roll", _roll)

# --- the link --------------------------------------------------------------------

func _pilot() -> Vector3:
	var d: Drone = _drone()
	return d._spawn_transform.origin + Vector3(0, PILOT_HEIGHT, 0)

func _update_link(cam: Camera3D, delta: float, look: int) -> void:
	var src: Vector3 = cam.global_position
	var pilot: Vector3 = _pilot()
	_ray_t -= delta
	if _ray_t <= 0.0:
		_ray_t = RAY_INTERVAL
		_obstruction_target = _obstruction(pilot, src)
	# Smoothed: a wall edge passing doesn't switch the picture on and off.
	_obstruction_db = lerpf(_obstruction_db, _obstruction_target, 1.0 - exp(-delta / 0.25))
	var d: float = maxf(pilot.distance_to(src), 1.0)
	var fspl: float = 20.0 * log(d) / log(10.0) + 47.7
	# Straight overhead the pilot's (vertical) antenna has its null.
	var el: float = absf(src.y - pilot.y) / d
	var null_db: float = 10.0 * pow(el, 4.0) * smoothstep(5.0, 25.0, d)
	# Multipath fading: a few dB, slow, more when far away.
	var fade: float = _fade_noise.get_noise_1d(_t * 6.0) * (1.0 + clampf(d / 300.0, 0.0, 2.0))
	margin_db = BUDGET_DB - fspl - _obstruction_db - null_db + fade
	badness = bad_for(look, margin_db)
	if force_quality >= 0.0:
		badness = 1.0 - force_quality

## How bad each system's picture is at a link margin (dB).
static func bad_for(look: int, m: float) -> float:
	match look:
		1: return clampf((15.0 - m) / 19.0, 0.0, 1.0)       # analog: gradual
		2: return clampf((0.0 - m) / 9.0, 0.0, 1.0)         # digital: +8 dB receiver, fails over ~9 dB
		3: return clampf((3.0 - m) / 6.0, 0.0, 1.0)         # HDZero: late and sudden
	return 0.0

## dB lost to what stands between pilot and drone: every surface the
## line crosses (rays stepped through each hit), plus how thick the thing
## behind each hit is (a ray back from up to 40 m further on finds its
## far side) - a wall, a whole building block or a hill.
func _obstruction(a: Vector3, b: Vector3) -> float:
	var d: Drone = _drone()
	var space: PhysicsDirectSpaceState3D = d.get_world_3d().direct_space_state
	var excl: Array[RID] = [d.get_rid()]
	var dist: float = a.distance_to(b)
	if dist < 0.5:
		return 0.0
	var dir: Vector3 = (b - a) / dist
	var loss: float = 0.0
	var from: Vector3 = a
	for k in range(6):
		var q := PhysicsRayQueryParameters3D.create(from, b)
		q.exclude = excl
		var h: Dictionary = space.intersect_ray(q)
		if h.is_empty():
			break
		var p: Vector3 = h.position
		var ahead: float = minf(MAX_THICKNESS, a.distance_to(b) - a.distance_to(p))
		var thick: float = ahead
		if ahead > 0.1:
			var r := PhysicsRayQueryParameters3D.create(p + dir * ahead, p)
			r.exclude = excl
			var back: Dictionary = space.intersect_ray(r)
			if not back.is_empty():
				thick = p.distance_to(back.position)
		loss += WALL_DB + thick * DEPTH_DB_PER_M
		if loss >= MAX_OBSTRUCTION_DB:
			break
		from = p + dir * 0.08
		if a.distance_to(from) >= dist:
			break
	return minf(loss, MAX_OBSTRUCTION_DB)

# --- per-system events -----------------------------------------------------------

func _update_events(delta: float, look: int) -> void:
	var frozen: bool = _freeze_t > 0.0
	if not frozen:
		_seed = _t
	_flash_t = maxf(_flash_t - delta, 0.0)
	_freeze_t = maxf(_freeze_t - delta, 0.0)
	var b: float = badness
	if look == 1:
		# Colour lost for a moment, sync slipping, the picture rolling.
		if b > 0.45 and _rng.randf() < (b - 0.45) * 3.0 * delta:
			_flash_t = _rng.randf_range(0.06, 0.18)
		_tear = lerpf(_tear, smoothstep(0.35, 0.95, b) * (0.5 + 0.5 * _rng.randf()), 1.0 - exp(-delta / 0.08))
		if b > 0.8:
			_roll = fmod(_roll + delta * (b - 0.8) * 4.0 * (0.5 + _rng.randf()), 1.0)
		else:
			_roll = lerpf(_roll, 0.0 if _roll < 0.5 else 1.0, 1.0 - exp(-delta / 0.1))
	else:
		_tear = 0.0
		_roll = 0.0
		if look >= 2 and not frozen:
			var from: float = 0.55 if look == 2 else 0.4
			if b > from and _rng.randf() < (b - from) * (6.0 if look == 2 else 5.0) * delta:
				_freeze_t = _rng.randf_range(0.06, 0.12 + 0.35 * b)
			if b > 0.97:
				_freeze_t = _rng.randf_range(0.2, 0.6) # lost: the last frame stays

## Extra latency (s) over the analog feed: DJI O3 ~28-40 ms glass to
## glass at a good link vs ~10-20 ms analog and ~3-5 ms HDZero (published
## glass-to-glass measurements, e.g. Oscar Liang's latency tests) - here
## the difference, growing as a weak digital link buffers more.
static func extra_latency(look: int, b: float) -> float:
	if look == 2:
		return 0.016 + 0.06 * smoothstep(0.2, 0.9, b)
	return 0.0

## Freezes and latency: the picture comes from a held/delayed copy of the
## FPV camera (the world is static, so rendering from where the camera
## was IS the old frame; costs nothing extra).
func _update_hold(flying_cam: bool, delta: float, look: int) -> void:
	var d: Drone = _drone()
	var cam: Camera3D = d.get_node_or_null("CameraMount/Camera3D") as Camera3D if d else null
	if cam == null:
		return
	var vp_cam: Camera3D = get_viewport().get_camera_3d()
	var lat: float = extra_latency(look, badness)
	var want: bool = flying_cam and (lat > 0.0 or _freeze_t > 0.0) and (vp_cam == cam or vp_cam == _hold_cam)
	# History of where the camera was, for the delay.
	_hist.append([_t, cam.get_global_transform_interpolated()])
	while _hist.size() > 2 and _hist[1][0] < _t - 0.5:
		_hist.pop_front()
	if not want:
		if _hold_cam and vp_cam == _hold_cam:
			cam.current = true
		return
	if _hold_cam == null:
		_hold_cam = Camera3D.new()
		_hold_cam.name = "FpvHoldCam"
		_hold_cam.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
		_hold_cam.set_meta("dynamic", true)
		d.get_parent().add_child(_hold_cam)
	_hold_cam.fov = cam.fov
	_hold_cam.near = cam.near
	_hold_cam.far = cam.far
	_hold_cam.cull_mask = cam.cull_mask
	_hold_cam.keep_aspect = cam.keep_aspect
	if _freeze_t <= 0.0:
		_hold_cam.global_transform = _delayed(_t - lat)
	if not _hold_cam.current:
		_hold_cam.current = true

func _delayed(t: float) -> Transform3D:
	for i in range(_hist.size() - 1, -1, -1):
		if _hist[i][0] <= t:
			if i + 1 < _hist.size():
				var a: Array = _hist[i]
				var b: Array = _hist[i + 1]
				var f: float = clampf((t - a[0]) / maxf(b[0] - a[0], 0.0001), 0.0, 1.0)
				return (a[1] as Transform3D).interpolate_with(b[1], f)
			return _hist[i][1]
	return _hist[0][1]

func _exit_tree() -> void:
	if _hold_cam and is_instance_valid(_hold_cam):
		_hold_cam.queue_free()
