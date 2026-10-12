class_name VillageCourse
extends RaceCourse

## A small timed course on a freestyle map (Village): it waits until the
## drone flies through its START gate, then shows the next-gate marker and
## the racing line (if switched on) for one lap. At START again: a note
## "time / your best" for 5 s. It ends by itself 90 s after the last gate
## reached, 500 m away from every gate, or at a reset. One course runs at
## a time. Best time per course over all drones, in
## village_courses.cfg - shown only in the note and on Achievements.
## No HUD bar, no results card, no ghost.
## The calls are race-track calls (RaceCourse.build_track); most of the
## gates are already in the (cached) map, so they only register here on a
## throwaway Geo; ["new", call] draws a piece for real (the course's own
## Geo, built at load time), ["opening", pos, yaw, w, h] registers an
## opening with nothing drawn (the hoop).

const COURSES: Dictionary = {"club": "Club Course", "slalom": "Flag Slalom"}
const TIMEOUT: float = 90.0
const FAR: float = 500.0
static var BEST_PATH: String = save_path("village_courses.cfg")
static var _active: VillageCourse = null

var course_id: String = ""
var running: bool = false
var _last_gate_t: float = 0.0

static func create(map: Node3D, id: String, calls: Array) -> VillageCourse:
	var vc := VillageCourse.new()
	vc.name = "Course_" + id
	vc.course_id = id
	map.add_child(vc)
	var cached := Geo.new()
	add_materials(cached)
	var g := Geo.new()
	if map is BuiltMap:
		for p in ["sun_dir", "sun", "sun_tint", "ambient", "sky"]:
			g.set(p, (map as BuiltMap).geo.get(p))
	add_materials(g)
	var fn: Dictionary = {"start": "start_gate", "gate": "gate", "sized": "gate_sized", "dive": "dive_gate",
		"hurdle": "hurdle", "turn": "turn_flag", "hanging": "hanging_gate", "ladder": "ladder"}
	for c: Array in calls:
		if c[0] == "opening":
			vc._register(Transform3D(Basis(Vector3.UP, c[2]), c[1]), c[3], c[4])
		elif c[0] == "new":
			var nc: Array = c[1]
			vc.callv(fn[nc[0]], [g] + nc.slice(1))
		else:
			vc.callv(fn[c[0]], [cached] + c.slice(1))
	vc._build_flags()
	g.commit(vc)
	return vc

func start(p_drone: Drone, p_ui: Node) -> void:
	drone = p_drone
	ui = p_ui
	_prev_pos = drone.global_position
	_build_marker()
	if Settings.race_line_on():
		_build_line()
	_show(false)
	drone.was_reset.connect(stop)

static func best_time(id: String) -> float:
	var cfg := ConfigFile.new()
	cfg.load(BEST_PATH)
	var e: Variant = cfg.get_value("best", id, [])
	return float(e[0]) if e is Array and not e.is_empty() else -1.0

func _physics_process(delta: float) -> void:
	if drone == null or _gates.is_empty():
		return
	_time += delta
	var pos: Vector3 = drone.global_position
	if pos.distance_to(_prev_pos) > 8.0:
		stop()
	elif not running:
		if (_active == null or not is_instance_valid(_active)) and _crossed(_gates[0], _prev_pos, pos):
			_begin()
	elif _crossed(_gates[_next], _prev_pos, pos):
		_gate()
	elif _time - _last_gate_t > TIMEOUT or _far(pos):
		stop()
	_prev_pos = pos

func _begin() -> void:
	running = true
	_active = self
	_lap_start = _time
	_last_gate_t = _time
	_next = 1
	_show(true)
	_place_marker()
	_play("go")

func _gate() -> void:
	_last_gate_t = _time
	if _next == 0:
		_finish_course()
		return
	_play("gate")
	_next = (_next + 1) % _gates.size()
	_place_marker()

func _finish_course() -> void:
	var t: float = _time - _lap_start
	var best: float = best_time(course_id)
	var new_best: bool = best < 0.0 or t < best
	if new_best:
		var cfg := ConfigFile.new()
		cfg.load(BEST_PATH)
		cfg.set_value("best", course_id, [t, Time.get_date_string_from_system()])
		cfg.save(BEST_PATH)
	_play("pb" if new_best else "finish")
	if ui and ui.has_method("flash_message"):
		var line2: String = "NEW BEST" if new_best else "your best %s" % _fmt(best)
		ui.flash_message("%s  %s\n%s" % [COURSES.get(course_id, course_id).to_upper(), _fmt(t), line2], 4.1)
	stop()

## Ends the run quietly (timeout, far away, a reset, or the finish).
func stop() -> void:
	running = false
	if _active == self:
		_active = null
	_next = 0
	_show(false)

func _show(on: bool) -> void:
	if _marker:
		_marker.visible = on
	if _line:
		_line.visible = on
	if _flag_decal:
		(_flag_decal.material_override as ShaderMaterial).set_shader_parameter("active", -1.0)

func _far(pos: Vector3) -> bool:
	for g in _gates:
		if (g.xf.origin as Vector3).distance_to(pos) < FAR:
			return false
	return true

func _process(delta: float) -> void:
	if running:
		super._process(delta)
