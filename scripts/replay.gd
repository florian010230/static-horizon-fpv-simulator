class_name Replay
extends Node

## DVR: the last 60 s of the flight are always recorded (the drone's
## transform at 30 Hz - a few hundred KB), and P plays them back:
##   Space pause/play, Left/Right -/+5 s, Up/Down speed (1/4x - 2x),
##   C camera (chase, FPV, line of sight from the spawn point), P back to
##   flying - exactly where you left off (position, velocity, rotation).
## The flying drone is frozen meanwhile; a copy of its model (the same
## DroneFrameBuilder build) flies the recording. The top-ranked request
## in our sim research (Liftoff and Velocidrone both have it).

const HZ: float = 30.0
const SECONDS: float = 60.0
const SPEEDS: Array[float] = [0.25, 0.5, 1.0, 2.0]
const CAMS: Array[String] = ["Chase", "FPV", "Line of sight"]

var drone: Drone
var ui: Node
var active: bool = false
var _pos := PackedVector3Array()
var _rot: Array[Quaternion] = []
var _acc: float = 0.0
var _t: float = 0.0          # playback time, seconds from the start of the recording
var _speed: int = 2
var _paused: bool = false
var _cam_mode: int = 0
var _ghost: Node3D
var _cam: Camera3D
var _saved: Dictionary = {}
var _keys: Dictionary = {}
var _label: Label

func setup(p_drone: Drone, p_ui: Node) -> void:
	drone = p_drone
	ui = p_ui

func _physics_process(delta: float) -> void:
	if drone == null or active:
		return
	_acc += delta
	if _acc < 1.0 / HZ:
		return
	_acc = 0.0
	_pos.append(drone.global_position)
	_rot.append(drone.global_transform.basis.get_rotation_quaternion())
	var maxn: int = int(HZ * SECONDS)
	if _pos.size() > maxn:
		_pos = _pos.slice(_pos.size() - maxn)
		_rot = _rot.slice(_rot.size() - maxn)

func _process(delta: float) -> void:
	if drone == null:
		return
	if _pressed(KEY_P):
		if active:
			stop()
		elif _pos.size() > 10:
			start()
	if not active:
		return
	if _pressed(KEY_SPACE):
		_paused = not _paused
	if _pressed(KEY_LEFT):
		_t = maxf(_t - 5.0, 0.0)
	if _pressed(KEY_RIGHT):
		_t = minf(_t + 5.0, length())
	if _pressed(KEY_UP):
		_speed = mini(_speed + 1, SPEEDS.size() - 1)
	if _pressed(KEY_DOWN):
		_speed = maxi(_speed - 1, 0)
	if _pressed(KEY_C):
		_cam_mode = (_cam_mode + 1) % CAMS.size()
	if not _paused:
		_t += delta * SPEEDS[_speed]
		if _t >= length():
			_t = 0.0 # loop
	_place()
	_label.text = "REPLAY   %s / %s   x%s   %s\nSpace pause   Left/Right 5 s   Up/Down speed   C camera   P back to flying" % [
		_fmt(_t), _fmt(length()), str(SPEEDS[_speed]), CAMS[_cam_mode] + ("   PAUSED" if _paused else "")]

func length() -> float:
	return maxf(_pos.size() - 1, 0) / HZ

func _pressed(k: Key) -> bool:
	var down: bool = Input.is_key_pressed(k)
	var was: bool = _keys.get(k, false)
	_keys[k] = down
	return down and not was

func start() -> void:
	active = true
	_t = 0.0
	_paused = false
	_saved = {"xf": drone.global_transform, "v": drone.linear_velocity, "w": drone.angular_velocity}
	drone.freeze = true
	drone.visible = false
	_ghost = Node3D.new()
	_ghost.name = "ReplayDrone"
	drone.get_parent().add_child(_ghost)
	var p: Dictionary = Drone.PROFILES.get(Settings.selected_drone, Drone.PROFILES.seeker3)
	var visual: Dictionary = p.visual.duplicate()
	visual["arm_length"] = p.arm_length
	DroneFrameBuilder.build(_ghost, visual)
	_ghost.set_meta("dynamic", true)
	_cam = Camera3D.new()
	_cam.fov = 75.0
	_cam.near = 0.02
	_cam.far = Settings.view_distance
	drone.get_parent().add_child(_cam)
	_cam.current = true
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_label.position.y = -40
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_override("font", UIKit.oswald())
	_label.add_theme_font_size_override("font_size", 26)
	_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	_label.add_theme_constant_override("outline_size", 6)
	ui.add_child(_label)
	_place()

func stop() -> void:
	active = false
	if _ghost:
		_ghost.queue_free()
	if _cam:
		_cam.queue_free()
	if _label:
		_label.queue_free()
	drone.visible = true
	drone.freeze = false
	drone.global_transform = _saved.xf
	drone.linear_velocity = _saved.v
	drone.angular_velocity = _saved.w
	drone.reset_physics_interpolation()
	(drone.get_node("CameraMount/Camera3D") as Camera3D).current = true

func _place() -> void:
	var f: float = _t * HZ
	var i: int = clampi(int(f), 0, _pos.size() - 2)
	var k: float = clampf(f - i, 0.0, 1.0)
	var p: Vector3 = _pos[i].lerp(_pos[i + 1], k)
	var q: Quaternion = _rot[i].slerp(_rot[i + 1], k)
	var b := Basis(q)
	_ghost.global_transform = Transform3D(b, p)
	match _cam_mode:
		0: # chase: behind and above, heading-aligned, smoothed
			var fwd: Vector3 = -b.z
			fwd.y = 0.0
			fwd = fwd.normalized() if fwd.length() > 0.1 else Vector3.FORWARD
			var back: float = 2.5 + Drone.PROFILES.get(Settings.selected_drone, Drone.PROFILES.seeker3).arm_length * 15.0
			var want: Vector3 = p - fwd * back + Vector3(0, back * 0.4, 0)
			_cam.global_position = _cam.global_position.lerp(want, 0.15) if _cam.global_position.distance_to(want) < 30.0 else want
			_cam.look_at(p, Vector3.UP)
		1: # FPV: the camera's own uptilt
			var tilt := Basis(Vector3.RIGHT, deg_to_rad(Settings.camera_angle_deg))
			_cam.global_transform = Transform3D(b * tilt, p + b * Vector3(0, 0.02, -0.03))
			_cam.fov = Settings.camera_fov_deg
		2: # line of sight from where the pilot stands
			_cam.global_position = drone._spawn_transform.origin + Vector3(0, 1.7, 0) + drone._spawn_transform.basis.z * 3.0
			if _cam.global_position.distance_to(p) > 0.3:
				_cam.look_at(p, Vector3.UP)

static func _fmt(t: float) -> String:
	return "%d:%04.1f" % [int(t) / 60, fmod(t, 60.0)]
