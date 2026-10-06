class_name RaceCourse
extends Node3D

## A timed race course: an ordered list of gate openings, lap timing,
## best laps saved per map + drone, and a glowing marker on the next
## gate. Gate visuals and collision are built through the map's Geo.
##
## Gate types follow MultiGP's standard obstacles (multigp.com, "Drone
## Race Course Obstacles"): the standard gate is a 5 ft x 5 ft (1.52 m)
## opening framed by padded mesh panels; a double gate is two stacked, a
## ladder three stacked, a tower gate one raised 5 ft on legs; a dive
## gate lies flat up high and is flown through downward; flags only mark
## turns. Only the opening you have to fly through counts as the gate.
##
## Passing: every physics frame the drone's movement is checked against
## each next gate's plane in the gate's local space - it has to cross in
## the gate's forward direction (-Z) inside the opening. Checking the
## segment between two frames means even a 200 km/h pass (0.46 m per
## 120 Hz frame) can't skip through.

const RECORDS_PATH: String = "user://race_records.cfg"
const GATE: float = 1.52 ## MultiGP standard opening, 5 ft
const PANEL: float = 0.28 ## frame panel width
## A standing gate's frame rides this high on its feet: its bottom PVC
## tube, flush with the ground, flickered against the grass.
const FOOT: float = 0.04

var map_id: String = ""
var drone: Drone
var ui: Node
var _gates: Array[Dictionary] = [] # {xf: Transform3D (opening centre, -Z = fly direction), w, h}
var _next: int = 0
var _lap_start: float = -1.0
var _lap: int = 0
var _last_lap: float = -1.0
var _best: float = -1.0
var _prev_pos: Vector3
var _marker: Node3D
var _time: float = 0.0

## Ghost of the best lap: the current lap is sampled at GHOST_HZ; when a
## lap beats the best, its samples become the ghost, which then flies
## along with every new lap (saved per map + track layout + drone, like
## the best time; Settings.race_ghost hides it). The ghost is the drone's
## own model (DroneFrameBuilder), see-through and glowing; positions and
## rotations (quaternions, slerped) are interpolated between samples.
const GHOST_HZ: float = 30.0
const GHOST_PATH: String = "user://race_ghosts.cfg"
var _lap_samples: PackedVector3Array = PackedVector3Array()
var _lap_rot: PackedVector4Array = PackedVector4Array()
var _ghost_pos: PackedVector3Array = PackedVector3Array()
var _ghost_rot: PackedVector4Array = PackedVector4Array()
var _sample_t: float = 0.0
var _ghost: Node3D

func setup(p_map_id: String, p_drone: Drone, p_ui: Node) -> void:
	map_id = p_map_id
	drone = p_drone
	ui = p_ui
	# Freestyle mode: the gates are just obstacles - no timer, marker or ghost.
	if Settings.game_mode == Settings.MODE_FREESTYLE:
		set_physics_process(false)
		set_process(false)
		return
	_best = _load_best()
	_prev_pos = drone.global_position
	_build_marker()
	_build_numbers()
	_build_ghost()
	_load_ghost()
	_reset_run()

# --- building gates ----------------------------------------------------------

## Adds the materials the gate builders use (call once per Geo).
static func add_materials(geo: Geo) -> void:
	var fabric: Texture2D = MapTextures.get_tex("fabric")
	geo.add_material("gate_a", Geo.tex_mat(fabric, Color(0.12, 0.42, 0.9), 0.6, 0.8))
	geo.add_material("gate_b", Geo.tex_mat(fabric, Color(0.93, 0.36, 0.1), 0.6, 0.8))
	geo.add_material("gate_dark", Geo.tex_mat(fabric, Color(0.12, 0.12, 0.13), 0.6, 0.8))
	geo.add_material("gate_white", Geo.tex_mat(fabric, Color(0.92, 0.92, 0.9), 0.6, 0.8))
	geo.add_material("gate_pole", Geo.flat_mat(Color(0.85, 0.85, 0.85), 0.4, 0.3))
	geo.add_material("gate_trim", Geo.flat_mat(Color(0.96, 0.96, 0.94), 0.6))
	geo.add_material("gate_base", Geo.flat_mat(Color(0.16, 0.16, 0.17), 0.7))
	# LED gates (Drone Racing League style): self-lit, bloom on High.
	for led in [["led_blue", Color(0.2, 0.55, 1.0)], ["led_orange", Color(1.0, 0.45, 0.1)], ["led_green", Color(0.2, 1.0, 0.4)], ["led_pink", Color(1.0, 0.25, 0.7)]]:
		geo.add_material(led[0], Geo.glow_mat(led[1], 2.5))

## A square frame around an opening, in the plane of `xf` (opening
## centre, local X across, local Y up).
## Built like a real MultiGP gate: padded fabric panels (a little
## pillowed - thicker in the middle), white piping round the opening, a
## dark sponsor patch on the top panel, and the PVC tube frame showing at
## the outer edge.
func _frame(geo: Geo, xf: Transform3D, w: float, h: float, mat: String) -> void:
	var p: float = PANEL
	var d: float = 0.09
	var led: bool = mat.begins_with("led_")
	for side in [[Vector3(0, h * 0.5 + p * 0.5, 0), Vector3(w + 2 * p, p, d)], [Vector3(0, -h * 0.5 - p * 0.5, 0), Vector3(w + 2 * p, p, d)],
			[Vector3(-w * 0.5 - p * 0.5, 0, 0), Vector3(p, h, d)], [Vector3(w * 0.5 + p * 0.5, 0, 0), Vector3(p, h, d)]]:
		geo.box_xf(xf * Transform3D(Basis(), side[0]), side[1], mat if not led else "gate_dark")
		# The pillow: a slimmer, thicker strip down the panel's middle.
		var inner: Vector3 = side[1] * Vector3(0.82 if side[1].x > side[1].y else 0.55, 0.55 if side[1].x > side[1].y else 0.82, 1.6)
		geo.box_xf(xf * Transform3D(Basis(), side[0]), inner, mat if not led else "gate_dark", false, false)
	# Piping (or, on LED gates, the light strip) round the opening.
	var t: float = 0.035
	var pipe: String = "gate_trim" if not led else mat
	for e in [[Vector3(0, h * 0.5 + t * 0.5, 0), Vector3(w + 2 * t, t, d * 1.25)], [Vector3(0, -h * 0.5 - t * 0.5, 0), Vector3(w + 2 * t, t, d * 1.25)],
			[Vector3(-w * 0.5 - t * 0.5, 0, 0), Vector3(t, h, d * 1.25)], [Vector3(w * 0.5 + t * 0.5, 0, 0), Vector3(t, h, d * 1.25)]]:
		geo.box_xf(xf * Transform3D(Basis(), e[0]), e[1], pipe, false, false)
	# Outer PVC frame.
	for e in [[Vector3(0, h * 0.5 + p, 0), Vector3(w + 2 * p + 0.05, 0.05, 0.05)], [Vector3(0, -h * 0.5 - p, 0), Vector3(w + 2 * p + 0.05, 0.05, 0.05)],
			[Vector3(-w * 0.5 - p, 0, 0), Vector3(0.05, h + 2 * p, 0.05)], [Vector3(w * 0.5 + p, 0, 0), Vector3(0.05, h + 2 * p, 0.05)]]:
		geo.box_xf(xf * Transform3D(Basis(), e[0]), e[1], "gate_pole", false, false)
	if not led and w > 1.0:
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, h * 0.5 + p * 0.5, 0)), Vector3(w * 0.45, p * 0.6, d * 1.7), "gate_dark", false, false)

func _register(xf: Transform3D, w: float, h: float) -> void:
	_gates.append({"xf": xf, "w": w, "h": h})
	# Kept on the node too: a map loaded from the map cache gets this node
	# back without its script variables (see _ready).
	set_meta("gates", _gates)

func _ready() -> void:
	if _gates.is_empty() and has_meta("gates"):
		_gates.assign(get_meta("gates"))

## Standing gate(s) on the ground at `pos`, facing `yaw` (flown through
## toward -Z after turning by yaw). stack = 1 standard, 2 double, 3
## ladder; `lift` raises the lowest one (a tower gate: 1.52 m).
## `through` picks which stacked opening counts (0 = lowest).
func gate(geo: Geo, pos: Vector3, yaw: float, stack: int = 1, lift: float = 0.0, through: int = 0, mat: String = "gate_a") -> void:
	var basis := Basis(Vector3.UP, yaw)
	for i in range(stack):
		var cy: float = maxf(lift, FOOT) + PANEL + GATE * 0.5 + i * (GATE + PANEL)
		var xf := Transform3D(basis, pos + Vector3(0, cy, 0))
		var alt: String = {"gate_a": "gate_b", "gate_b": "gate_a", "led_blue": "led_orange", "led_orange": "led_blue"}.get(mat, mat)
		_frame(geo, xf, GATE, GATE, mat if i % 2 == 0 else alt)
		if i == through:
			_register(xf, GATE, GATE)
	if lift > 0.0:
		for sx in [-1.0, 1.0]:
			var leg: Vector3 = pos + basis * Vector3(sx * (GATE * 0.5 + PANEL * 0.5), 0, 0)
			geo.box(leg + Vector3(0, lift * 0.5, 0), Vector3(0.08, lift, 0.08), "gate_pole", yaw)
	_feet(geo, pos, basis, GATE * 0.5 + PANEL * 0.5)

## Weighted feet each side (real gates stand on sandbags / base plates).
func _feet(geo: Geo, pos: Vector3, basis: Basis, half: float) -> void:
	for sx in [-1.0, 1.0]:
		geo.box_xf(Transform3D(basis, pos + basis * Vector3(sx * half, 0.05, 0)), Vector3(0.22, 0.1, 0.7), "gate_base")

## Any-size single gate (whoop gates: ~0.4-0.6 m openings), with a thin
## frame of `bar` width, standing on the ground or at `lift` on a pole.
func gate_sized(geo: Geo, pos: Vector3, yaw: float, w: float, h: float, bar: float, lift: float = 0.0, mat: String = "gate_a") -> void:
	var basis := Basis(Vector3.UP, yaw)
	var xf := Transform3D(basis, pos + Vector3(0, lift + bar + h * 0.5, 0))
	var d: float = bar * 0.5
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, h * 0.5 + bar * 0.5, 0)), Vector3(w + 2 * bar, bar, d), mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - bar * 0.5, 0)), Vector3(w + 2 * bar, bar, d), mat)
	for sx in [-1.0, 1.0]:
		geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * (w * 0.5 + bar * 0.5), 0, 0)), Vector3(bar, h, d), mat)
	# White piping round the opening (LED gates: their light strip).
	var t: float = bar * 0.18
	var pipe: String = "gate_trim" if not mat.begins_with("led_") else mat
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, h * 0.5 + t * 0.5, 0)), Vector3(w, t, d * 1.3), pipe, false, false)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - t * 0.5, 0)), Vector3(w, t, d * 1.3), pipe, false, false)
	for sx in [-1.0, 1.0]:
		geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * (w * 0.5 + t * 0.5), 0, 0)), Vector3(t, h, d * 1.3), pipe, false, false)
	if lift > 0.0:
		geo.box(pos + Vector3(0, lift * 0.5, 0), Vector3(bar, lift, bar), "gate_pole", yaw)
		geo.box(pos + Vector3(0, 0.015, 0), Vector3(w * 0.6, 0.03, w * 0.4), "gate_base", yaw)
	_register(xf, w, h)

## The start/finish gate: a standard gate with a wide black-and-white
## banner on top. Always the first gate of the course.
func start_gate(geo: Geo, pos: Vector3, yaw: float) -> void:
	gate(geo, pos, yaw, 1, 0.0, 0, "gate_dark")
	var basis := Basis(Vector3.UP, yaw)
	var top: Vector3 = pos + Vector3(0, FOOT + PANEL * 2 + GATE + 0.45, 0)
	for i in range(8):
		var x: float = -1.4 + i * 0.4
		geo.box_xf(Transform3D(basis, top + basis * Vector3(x, 0.2, 0)), Vector3(0.4, 0.4, 0.05), "gate_white" if i % 2 == 0 else "gate_dark")
		geo.box_xf(Transform3D(basis, top + basis * Vector3(x, -0.2, 0)), Vector3(0.4, 0.4, 0.05), "gate_dark" if i % 2 == 0 else "gate_white")
	for sx in [-1.0, 1.0]:
		geo.box(pos + basis * Vector3(sx * 1.6, 0, 0) + Vector3(0, 1.6, 0), Vector3(0.08, 3.2, 0.08), "gate_pole", yaw)
	_feet(geo, pos, basis, 1.6)

## A dive gate: a standard gate lying flat on a stand `height` up, flown
## through downward. `yaw` sets which way the stand's frame runs.
func dive_gate(geo: Geo, pos: Vector3, yaw: float, height: float = 3.5, mat: String = "gate_b") -> void:
	# Opening's local -Z must point down: tip the frame forward 90 deg.
	var basis := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -PI * 0.5)
	var xf := Transform3D(basis, pos + Vector3(0, height, 0))
	_frame(geo, xf, GATE, GATE, mat)
	_register(xf, GATE, GATE)
	var yb := Basis(Vector3.UP, yaw)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var foot: Vector3 = pos + yb * Vector3(sx * (GATE * 0.5 + PANEL), 0, sz * (GATE * 0.5 + PANEL))
			geo.box(foot + Vector3(0, (height - 0.03) * 0.5, 0), Vector3(0.07, height - 0.03, 0.07), "gate_pole", yaw)

## A standard gate hung from the roof on two cables (centre `pos`), each
## cable from a bar spanning `span` m between two roof trusses at
## `ceiling_y` (their underside). Indoor tracks.
func hanging_gate(geo: Geo, pos: Vector3, yaw: float, ceiling_y: float, mat: String = "led_blue", span: float = 17.0, size: float = GATE) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var xf := Transform3D(basis, pos)
	var p: float = PANEL if size >= 1.0 else 0.05
	if size >= 1.0:
		_frame(geo, xf, size, size, mat)
		_register(xf, size, size)
	else:
		# A whoop-size gate: build it like gate_sized, centred on pos.
		gate_sized(geo, pos - Vector3(0, size * 0.5 + p, 0), yaw, size, size, p, 0.0, mat)
	var top: float = pos.y + size * 0.5 + p
	for sx in [-1.0, 1.0]:
		var c: Vector3 = pos + basis * Vector3(sx * (size * 0.5 + p * 0.5), 0, 0)
		geo.beam(Vector3(c.x, top, c.z), Vector3(c.x, ceiling_y, c.z), Vector2(0.03, 0.03), "gate_pole")
		# A bar from truss to truss (along the flying direction) per cable.
		geo.box_xf(Transform3D(basis, Vector3(c.x, ceiling_y - 0.1, c.z)), Vector3(0.15, 0.2, span), "gate_pole")

## A hurdle: wide and low - fly under the bar, over the ground.
func hurdle(geo: Geo, pos: Vector3, yaw: float, mat: String = "gate_b") -> void:
	var w: float = 2.44
	var h: float = 0.76
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, h * 0.5, 0))
	var basis := Basis(Vector3.UP, yaw)
	_feet(geo, pos, basis, w * 0.5 + PANEL * 0.5)
	geo.box_xf(Transform3D(basis, pos + Vector3(0, h + PANEL * 0.5, 0)), Vector3(w + 2 * PANEL, PANEL, 0.06), mat)
	for sx in [-1.0, 1.0]:
		geo.box_xf(Transform3D(basis, pos + basis * Vector3(sx * (w * 0.5 + PANEL * 0.5), (h + PANEL) * 0.5, 0)), Vector3(PANEL, h + PANEL, 0.06), mat)
	_register(xf, w, h)

## A turn flag: tall curved "teardrop" banner on a pole. Visual only.
func flag(geo: Geo, pos: Vector3, mat: String = "gate_a") -> void:
	geo.cylinder(pos, pos + Vector3(0, 3.6, 0), 0.03, "gate_pole", 6)
	geo.cylinder(pos, pos + Vector3(0, 0.06, 0), 0.25, "gate_base", 10)
	for i in range(6):
		var t: float = i / 6.0
		var w: float = 0.55 * sin((t * 0.85 + 0.1) * PI)
		geo.box(pos + Vector3(w * 0.5 + 0.03, 3.4 - t * 2.6, 0), Vector3(w, 0.44, 0.02), mat, 0.0, false)

# --- running the race --------------------------------------------------------
#
# A race is LAPS laps from a flying start: the clock starts at the first
# pass of the START gate and stops at the end of the last lap. Every
# gate shows the split against the best lap (green ahead, red behind);
# flying past the next gate through a later one says MISSED GATE. At the
# finish: lap times, total, and the track's top-5 races (per drone).

const LAPS: int = 3
const BOARD_PATH: String = "user://race_board.cfg"
var _race_laps: Array[float] = []
var _splits: Array[float] = []      # this lap: time at each gate
var _best_splits: Array = []        # the best lap's
var _delta_text: String = ""
var _delta_t: float = 0.0
var _missed_t: float = 0.0
var _missed_gate: int = -1
var _beep: AudioStreamPlayer

func _physics_process(delta: float) -> void:
	if drone == null or _gates.is_empty():
		return
	_time += delta
	_delta_t = maxf(_delta_t - delta, 0.0)
	_missed_t = maxf(_missed_t - delta, 0.0)
	var pos: Vector3 = drone.global_position
	if pos.distance_to(_prev_pos) > 8.0:
		_reset_run() # R / crash reset / world border: the run is void
	elif _crossed(_gates[_next], _prev_pos, pos):
		_passed()
	elif _lap_start >= 0.0:
		for i in range(_gates.size()):
			if i != _next and i != (_next - 1 + _gates.size()) % _gates.size() and _crossed(_gates[i], _prev_pos, pos):
				_missed_gate = _next
				_missed_t = 2.0
				_play("miss")
				break
	_prev_pos = pos
	if _lap_start >= 0.0:
		_sample_t += delta
		if _sample_t >= 1.0 / GHOST_HZ:
			_sample_t = 0.0
			_lap_samples.append(pos)
			var q: Quaternion = drone.global_transform.basis.get_rotation_quaternion()
			_lap_rot.append(Vector4(q.x, q.y, q.z, q.w))
	_update_ghost()
	_update_hud()

func _crossed(g: Dictionary, a: Vector3, b: Vector3) -> bool:
	var inv: Transform3D = g.xf.affine_inverse()
	var la: Vector3 = inv * a
	var lb: Vector3 = inv * b
	if not (la.z > 0.0 and lb.z <= 0.0):
		return false
	var t: float = la.z / (la.z - lb.z)
	var hit: Vector3 = la.lerp(lb, t)
	return absf(hit.x) <= g.w * 0.5 and absf(hit.y) <= g.h * 0.5

func _passed() -> void:
	if _next == 0:
		if _lap_start >= 0.0:
			_last_lap = _time - _lap_start
			_race_laps.append(_last_lap)
			if _best < 0.0 or _last_lap < _best:
				_pb_flash = 3.0 if _best >= 0.0 else 0.0
				_best = _last_lap
				_save_best()
				_best_splits = _splits.duplicate()
				_ghost_pos = _lap_samples.duplicate()
				_ghost_rot = _lap_rot.duplicate()
				_save_ghost()
				_play("pb")
			else:
				_play("lap")
			if _race_laps.size() >= LAPS:
				_finish()
				return
		else:
			_race_laps.clear()
			_play("go")
		_lap_samples.clear()
		_lap_rot.clear()
		_splits.clear()
		_sample_t = 0.0
		_lap += 1
		_lap_start = _time
	else:
		var t: float = _time - _lap_start
		_splits.append(t)
		var k: int = _splits.size() - 1
		if k < _best_splits.size():
			var dlt: float = t - float(_best_splits[k])
			_delta_text = "%s%.2f" % ["+" if dlt >= 0.0 else "-", absf(dlt)]
			_delta_t = 1.8
		_play("gate")
	_next = (_next + 1) % _gates.size()
	_place_marker()

## The last lap is in: results, the track's top 5, back to waiting at START.
func _finish() -> void:
	var total: float = 0.0
	for l in _race_laps:
		total += l
	var board: Array = _board()
	var date: String = Time.get_date_string_from_system()
	board.append([total, _race_laps.min(), date])
	board.sort_custom(func(x, y): return x[0] < y[0])
	var rank: int = -1
	for i in range(board.size()):
		if board[i][0] == total and board[i][2] == date:
			rank = i
			break
	board = board.slice(0, 5)
	var cfg := ConfigFile.new()
	cfg.load(BOARD_PATH)
	cfg.set_value(section(map_id), _key(), board)
	cfg.save(BOARD_PATH)
	_play("finish")
	if ui and ui.has_method("show_race_results"):
		var lines: Array[String] = []
		for i in range(_race_laps.size()):
			lines.append("Lap %d    %s%s" % [i + 1, _fmt(_race_laps[i]), "   best" if _race_laps[i] == _race_laps.min() else ""])
		lines.append("")
		lines.append("TOTAL    %s" % _fmt(total))
		lines.append("NEW TRACK RECORD" if rank == 0 else ("Rank %d of your races" % (rank + 1) if rank > 0 and rank < 5 else ""))
		lines.append("")
		lines.append("YOUR TOP 5")
		for i in range(board.size()):
			lines.append("%d.  %s    (%s)" % [i + 1, _fmt(board[i][0]), board[i][2]])
		lines.append("")
		lines.append("Fly through START to race again")
		ui.show_race_results("FINISH", lines)
	_race_laps.clear()
	_lap = 0
	_lap_start = -1.0
	_splits.clear()
	_next = 0 # the next race starts at the next pass of START
	_place_marker()

func _board() -> Array:
	var cfg := ConfigFile.new()
	if cfg.load(BOARD_PATH) != OK:
		return []
	return cfg.get_value(section(map_id), _key(), [])

## The track's top-5 races for the menu: {drone id: [[total, best lap, date], ...]}.
static func boards(p_map_id: String) -> Dictionary:
	var out := {}
	var cfg := ConfigFile.new()
	var sec: String = section(p_map_id)
	if cfg.load(BOARD_PATH) != OK or not cfg.has_section(sec):
		return out
	for k in cfg.get_section_keys(sec):
		out[k] = cfg.get_value(sec, k)
	return out

func _reset_run() -> void:
	_lap_samples.clear()
	_lap_rot.clear()
	_splits.clear()
	_race_laps.clear()
	_next = 0
	_lap = 0
	_lap_start = -1.0
	_place_marker()

func current_lap_time() -> float:
	return _time - _lap_start if _lap_start >= 0.0 else 0.0

var _pb_flash: float = 0.0

func _update_hud() -> void:
	if ui == null or not ui.has_method("set_race_info"):
		return
	var best: String = _fmt(_best) if _best >= 0.0 else "--"
	if _pb_flash > 0.0:
		_pb_flash -= get_physics_process_delta_time()
		ui.set_race_info("NEW PERSONAL BEST LAP  %s" % best)
		return
	if _lap_start < 0.0:
		ui.set_race_info("Fly through START - %d laps    Best lap %s" % [LAPS, best])
		return
	var line: String = "LAP %d/%d    %s    GATE %d/%d    BEST %s" % [_lap, LAPS, _fmt(current_lap_time()), (_next - 1 + _gates.size()) % _gates.size() + 1, _gates.size(), best]
	if _missed_t > 0.0:
		line += "\nMISSED GATE %d" % (_missed_gate + 1)
	elif _delta_t > 0.0:
		line += "\n" + _delta_text
	ui.set_race_info(line, _delta_text.begins_with("-") and _delta_t > 0.0 and _missed_t <= 0.0, _missed_t > 0.0 or (_delta_t > 0.0 and _delta_text.begins_with("+")))

# --- sounds -------------------------------------------------------------------
# Short synthesized beeps (no audio files): gate, lap, personal best,
# start, finish, missed gate - like a race timing system's tones.

const BEEPS := {
	"gate": [[1320.0, 0.07]],
	"lap": [[988.0, 0.09], [1320.0, 0.12]],
	"pb": [[1320.0, 0.08], [1568.0, 0.08], [1976.0, 0.16]],
	"go": [[1760.0, 0.25]],
	"finish": [[784.0, 0.12], [988.0, 0.12], [1175.0, 0.12], [1568.0, 0.3]],
	"miss": [[330.0, 0.18], [262.0, 0.25]],
}
static var _beep_cache: Dictionary = {}

func _play(kind: String) -> void:
	if _beep == null:
		_beep = AudioStreamPlayer.new()
		_beep.volume_db = -12.0
		add_child(_beep)
	if not _beep_cache.has(kind):
		var rate: int = 22050
		var data := PackedByteArray()
		for note in BEEPS[kind]:
			var n: int = int(rate * note[1])
			for i in range(n):
				var env: float = minf(1.0, minf(i / 200.0, (n - i) / 400.0))
				var v: float = sin(TAU * note[0] * i / rate) * 0.6 + sin(TAU * note[0] * 2.0 * i / rate) * 0.15
				var q: int = int(clampf(v * env, -1.0, 1.0) * 30000.0)
				data.append(q & 0xFF)
				data.append((q >> 8) & 0xFF)
		var w := AudioStreamWAV.new()
		w.format = AudioStreamWAV.FORMAT_16_BITS
		w.mix_rate = rate
		w.data = data
		_beep_cache[kind] = w
	_beep.stream = _beep_cache[kind]
	_beep.play()

static func _fmt(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]

## A number board over every gate (its place in the lap), readable from
## any side; START is "S".
func _build_numbers() -> void:
	for i in range(_gates.size()):
		var g: Dictionary = _gates[i]
		var sc: float = clampf(g.w / GATE, 0.35, 1.0)
		var lb := Label3D.new()
		lb.text = "S" if i == 0 else str(i)
		lb.font = UIKit.oswald_font()
		lb.font_size = 96
		lb.outline_size = 18
		lb.modulate = Color(1.0, 0.85, 0.2) if i == 0 else Color.WHITE
		lb.outline_modulate = Color(0.05, 0.05, 0.06)
		lb.pixel_size = 0.006 * sc
		lb.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
		lb.no_depth_test = false
		var up: Vector3 = g.xf.basis.y
		var top: Vector3 = g.xf.origin + (up * (g.h * 0.5 + PANEL + 0.45 * sc) if absf(up.y) > 0.5 else Vector3(0, 0.9 * sc, 0) + g.xf.basis.y * (g.h * 0.5 + PANEL))
		lb.position = to_local(top)
		add_child(lb)

## Four glowing bars just inside the next opening, plus a bobbing
## chevron above it - visible from across the field.
func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "NextGateMarker"
	add_child(_marker)
	var mat := Geo.glow_mat(Color(0.2, 1.0, 0.45), 3.0)
	for i in range(4):
		var mi := MeshInstance3D.new()
		mi.mesh = BoxMesh.new()
		mi.material_override = mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_marker.add_child(mi)
	var arrow := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.35
	cone.height = 0.5
	cone.radial_segments = 4
	arrow.mesh = cone
	arrow.material_override = mat
	arrow.name = "Arrow"
	arrow.rotation_degrees = Vector3(180, 0, 0)
	_marker.add_child(arrow)

func _place_marker() -> void:
	if _marker == null or _gates.is_empty():
		return
	var g: Dictionary = _gates[_next]
	_marker.global_transform = g.xf
	var w: float = g.w
	var h: float = g.h
	var t: float = 0.06
	var bars: Array = [[Vector3(0, h * 0.5 - t, 0), Vector3(w, t, t)], [Vector3(0, -h * 0.5 + t, 0), Vector3(w, t, t)],
		[Vector3(-w * 0.5 + t, 0, 0), Vector3(t, h, t)], [Vector3(w * 0.5 - t, 0, 0), Vector3(t, h, t)]]
	for i in range(4):
		var mi: MeshInstance3D = _marker.get_child(i)
		mi.position = bars[i][0]
		(mi.mesh as BoxMesh).size = bars[i][1]
	var arrow: Node3D = _marker.get_node("Arrow")
	# Scaled with the gate: a 60 cm whoop gate gets a small arrow.
	var sc: float = clampf(w / GATE, 0.3, 1.0)
	arrow.scale = Vector3.ONE * sc
	arrow.position = Vector3(0, h * 0.5 + 0.9 * sc, 0)

func _process(_delta: float) -> void:
	if _marker:
		var arrow: Node3D = _marker.get_node("Arrow")
		if not _gates.is_empty():
			arrow.position.y = _gates[_next].h * 0.5 + (0.9 + sin(Time.get_ticks_msec() * 0.004) * 0.15) * arrow.scale.y

## The drone's own model, see-through and glowing (one shared material
## over every part), on the drone's render layer rules: the FPV camera
## sees it, it casts no shadow and stays out of the shadow-map capture.
func _build_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "Ghost"
	_ghost.set_meta("dynamic", true)
	_ghost.set_meta("keep_material", true)
	add_child(_ghost)
	var p: Dictionary = Drone.PROFILES.get(Settings.selected_drone, Drone.PROFILES["seeker3"])
	var visual: Dictionary = p.visual.duplicate()
	visual["arm_length"] = p.arm_length
	DroneFrameBuilder.build(_ghost, visual)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.5, 0.9, 1.0, 0.6)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = false
	for c in _ghost.get_children():
		if c is GeometryInstance3D:
			var gi := c as GeometryInstance3D
			gi.material_override = mat
			gi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			gi.set_meta("keep_material", true)
	# A small glow around it, so a 3-inch ghost reads from 20 m away.
	var halo := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = p.arm_length * 2.2
	sm.height = p.arm_length * 4.4
	sm.radial_segments = 16
	sm.rings = 8
	halo.mesh = sm
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.albedo_color = Color(0.5, 0.9, 1.0, 0.16)
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.set_meta("keep_material", true)
	_ghost.add_child(halo)
	_ghost.visible = false

func _update_ghost() -> void:
	if _ghost == null:
		return
	var n: int = _ghost_pos.size()
	_ghost.visible = Settings.race_ghost and n > 1 and _ghost_rot.size() == n and _lap_start >= 0.0
	if not _ghost.visible:
		return
	var f: float = current_lap_time() * GHOST_HZ
	var i: int = mini(int(f), n - 2)
	var t: float = clampf(f - i, 0.0, 1.0)
	if int(f) >= n - 1:
		_ghost.visible = false # the ghost already finished its lap
		return
	var a: Vector4 = _ghost_rot[i]
	var b: Vector4 = _ghost_rot[i + 1]
	var q: Quaternion = Quaternion(a.x, a.y, a.z, a.w).slerp(Quaternion(b.x, b.y, b.z, b.w), t)
	_ghost.global_transform = Transform3D(Basis(q), _ghost_pos[i].lerp(_ghost_pos[i + 1], t))

func _save_ghost() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GHOST_PATH)
	cfg.set_value(section(map_id), _key() + "_pos", _ghost_pos)
	cfg.set_value(section(map_id), _key() + "_q", _ghost_rot)
	if cfg.has_section_key(section(map_id), _key() + "_rot"):
		cfg.erase_section_key(section(map_id), _key() + "_rot")
	cfg.save(GHOST_PATH)

## (Ghosts saved before 2026-10-04 kept Euler angles at 20 Hz under
## "_rot" - converted on load.)
func _load_ghost() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GHOST_PATH) != OK:
		return
	var sec: String = section(map_id)
	_ghost_pos = cfg.get_value(sec, _key() + "_pos", PackedVector3Array())
	if cfg.has_section_key(sec, _key() + "_q"):
		_ghost_rot = cfg.get_value(sec, _key() + "_q", PackedVector4Array())
		return
	var old: PackedVector3Array = cfg.get_value(sec, _key() + "_rot", PackedVector3Array())
	_ghost_rot = PackedVector4Array()
	for e in old:
		var q := Quaternion.from_euler(e)
		_ghost_rot.append(Vector4(q.x, q.y, q.z, q.w))
	# Old ghosts were sampled at 20 Hz: resample to GHOST_HZ.
	if old.size() > 1:
		var pos := PackedVector3Array()
		var rot := PackedVector4Array()
		var k: float = 20.0 / GHOST_HZ
		var j: float = 0.0
		while j < old.size() - 1:
			var i: int = int(j)
			var t: float = j - i
			pos.append(_ghost_pos[i].lerp(_ghost_pos[i + 1], t))
			var a: Vector4 = _ghost_rot[i]
			var b: Vector4 = _ghost_rot[i + 1]
			var q: Quaternion = Quaternion(a.x, a.y, a.z, a.w).slerp(Quaternion(b.x, b.y, b.z, b.w), t)
			rot.append(Vector4(q.x, q.y, q.z, q.w))
			j += k
		_ghost_pos = pos
		_ghost_rot = rot

## Records are kept per track layout: a redesigned track (MapCatalog
## "track": n) starts a fresh record table instead of comparing against
## laps flown on the old layout.
static func section(p_map_id: String) -> String:
	for m in MapCatalog.MAPS:
		if m.id == p_map_id and int(m.get("track", 1)) > 1:
			return "%s@%d" % [p_map_id, int(m.track)]
	return p_map_id

func _key() -> String:
	return Settings.selected_drone

func _load_best() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return -1.0
	_best_splits = cfg.get_value(section(map_id), _key() + "_splits", [])
	return cfg.get_value(section(map_id), _key(), -1.0)

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)
	cfg.set_value(section(map_id), _key(), _best)
	cfg.set_value(section(map_id), _key() + "_splits", _splits.duplicate())
	cfg.set_value(section(map_id), _key() + "_date", Time.get_date_string_from_system())
	cfg.save(RECORDS_PATH)

## Personal bests of a map for the menu: {drone id: [seconds, date]}.
static func records(p_map_id: String) -> Dictionary:
	var out := {}
	var cfg := ConfigFile.new()
	var sec: String = section(p_map_id)
	if cfg.load(RECORDS_PATH) != OK or not cfg.has_section(sec):
		return out
	for k in cfg.get_section_keys(sec):
		if not k.ends_with("_date") and not k.ends_with("_splits"):
			out[k] = [float(cfg.get_value(sec, k)), str(cfg.get_value(sec, k + "_date", ""))]
	return out
