class_name TakeRecorder
extends Node

## Dev tool for trailer footage: with `-- --record-all` every flight is
## kept as a "take" - the drone's pose 60 times a second from the map
## load (or the last reset) until the next reset or map change, races
## with missed gates and crashes included. Each take is its own file in
## user://trailer_takes/ (map, track, drone, date, poses); race_ghosts.cfg
## and race_records.cfg are never touched (RaceCourse.save_path sends a
## record-all session's race saves to trailer_takes/race_saves/). The
## ghost renderer (scripts/ghost_cine.gd) replays and checks them.
## Started by DevPreviewCapture; inert without the flag.

const DIR: String = "user://trailer_takes"
const HZ: float = 60.0
## Shorter or stiller takes are dropped (sitting on the pad).
const MIN_SECONDS: float = 3.0
const MIN_TRAVEL: float = 5.0

static func active() -> bool:
	return OS.get_cmdline_user_args().has("--record-all")

var _scene: Node = null
var _drone: Drone = null
var _pos := PackedVector3Array()
var _rot := PackedVector4Array()
var _acc: float = 0.0
var _t0: String = ""
var _missed: Array = [] # [take time s, gate index] when the race reports a missed gate
var _rc: RaceCourse = null
var _last_missed: int = -1
var _meta: Dictionary = {} # what the take is, noted at its start (the map may be gone at its end)

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(DIR)
	process_physics_priority = 100 # after the drone moved
	print("TAKES recording every flight into ", ProjectSettings.globalize_path(DIR))

func _physics_process(delta: float) -> void:
	var sc: Node = get_tree().current_scene
	if sc != _scene:
		_end_take()
		_scene = sc
		_drone = _find_drone(sc) if sc else null
		if _drone:
			_drone.was_reset.connect(_end_take)
			# (A map change frees the scene before the next frame here: save
			# while it is leaving. Until 2026-10-22 such takes were lost.)
			sc.tree_exiting.connect(_end_take)
		_start_take()
	if _drone == null or not is_instance_valid(_drone):
		return
	_acc += delta
	if _acc < 1.0 / HZ:
		return
	_acc -= 1.0 / HZ
	if _rc and is_instance_valid(_rc) and _rc._missed_gate != _last_missed:
		_last_missed = _rc._missed_gate
		if _last_missed >= 0:
			_missed.append([_pos.size() / HZ, _last_missed])
	var q: Quaternion = _drone.global_basis.get_rotation_quaternion()
	_pos.append(_drone.global_position)
	_rot.append(Vector4(q.x, q.y, q.z, q.w))

func _exit_tree() -> void:
	_end_take()

func _start_take() -> void:
	_pos = PackedVector3Array()
	_rot = PackedVector4Array()
	_acc = 0.0
	_t0 = Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	_meta = {}
	_missed = []
	_rc = null
	_last_missed = -1
	if _scene and is_instance_valid(_scene) and _drone:
		var rc: RaceCourse = _find_course(_scene)
		_rc = rc
		_meta = {"map": rc.map_id if rc else _scene.name, "section": rc._section() if rc else _scene.name,
			"scene": _scene.scene_file_path, "track": Settings.race_track,
			"race": rc != null and Settings.game_mode == Settings.MODE_RACE, "drone": Settings.selected_drone}

func _end_take() -> void:
	var n: int = _pos.size()
	if n > 1 and n / HZ >= MIN_SECONDS and not _meta.is_empty():
		var travel: float = 0.0
		for k in range(1, n):
			travel += _pos[k].distance_to(_pos[k - 1])
		if travel >= MIN_TRAVEL:
			var where: String = _meta.section
			var cfg := ConfigFile.new()
			for k: String in _meta:
				cfg.set_value("take", k, _meta[k]) # map, section (map#track[@rev] as in race_ghosts.cfg), scene, track, race, drone
			cfg.set_value("take", "started", _t0)
			cfg.set_value("take", "hz", HZ) # (game time: a slowed session, --time-scale, replays at full speed)
			cfg.set_value("take", "flown_at_time_scale", Engine.time_scale)
			cfg.set_value("take", "seconds", n / HZ)
			cfg.set_value("take", "missed_gates", _missed)
			cfg.set_value("take", "pos", _pos)
			cfg.set_value("take", "q", _rot)
			var name: String = "%s_%s_%s.cfg" % [_t0, where.replace("#", "_").replace("@", "_r"), _meta.drone]
			cfg.save(DIR.path_join(name))
			print("TAKES saved %s (%.1f s, %.0f m)" % [name, n / HZ, travel])
	_start_take()

static func _find_drone(n: Node) -> Drone:
	if n is Drone:
		return n
	for c in n.get_children():
		var r: Drone = _find_drone(c)
		if r:
			return r
	return null

static func _find_course(n: Node) -> RaceCourse:
	if n is RaceCourse:
		return n
	for c in n.get_children():
		var r: RaceCourse = _find_course(c)
		if r:
			return r
	return null
