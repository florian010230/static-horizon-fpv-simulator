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
## along with every new lap (saved per map + drone, like the best time).
const GHOST_HZ: float = 20.0
const GHOST_PATH: String = "user://race_ghosts.cfg"
var _lap_samples: PackedVector3Array = PackedVector3Array()
var _lap_rot: PackedVector3Array = PackedVector3Array()
var _ghost_pos: PackedVector3Array = PackedVector3Array()
var _ghost_rot: PackedVector3Array = PackedVector3Array()
var _sample_t: float = 0.0
var _ghost: Node3D

func setup(p_map_id: String, p_drone: Drone, p_ui: Node) -> void:
	map_id = p_map_id
	drone = p_drone
	ui = p_ui
	_best = _load_best()
	_prev_pos = drone.global_position
	_build_marker()
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
	# LED gates (Drone Racing League style): self-lit, bloom on High.
	for led in [["led_blue", Color(0.2, 0.55, 1.0)], ["led_orange", Color(1.0, 0.45, 0.1)], ["led_green", Color(0.2, 1.0, 0.4)], ["led_pink", Color(1.0, 0.25, 0.7)]]:
		geo.add_material(led[0], Geo.glow_mat(led[1], 2.5))

## A square frame around an opening, in the plane of `xf` (opening
## centre, local X across, local Y up).
func _frame(geo: Geo, xf: Transform3D, w: float, h: float, mat: String) -> void:
	var p: float = PANEL
	var d: float = 0.06
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, h * 0.5 + p * 0.5, 0)), Vector3(w + 2 * p, p, d), mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - p * 0.5, 0)), Vector3(w + 2 * p, p, d), mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(-w * 0.5 - p * 0.5, 0, 0)), Vector3(p, h, d), mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(w * 0.5 + p * 0.5, 0, 0)), Vector3(p, h, d), mat)

func _register(xf: Transform3D, w: float, h: float) -> void:
	_gates.append({"xf": xf, "w": w, "h": h})

## Standing gate(s) on the ground at `pos`, facing `yaw` (flown through
## toward -Z after turning by yaw). stack = 1 standard, 2 double, 3
## ladder; `lift` raises the lowest one (a tower gate: 1.52 m).
## `through` picks which stacked opening counts (0 = lowest).
func gate(geo: Geo, pos: Vector3, yaw: float, stack: int = 1, lift: float = 0.0, through: int = 0, mat: String = "gate_a") -> void:
	var basis := Basis(Vector3.UP, yaw)
	for i in range(stack):
		var cy: float = lift + PANEL + GATE * 0.5 + i * (GATE + PANEL)
		var xf := Transform3D(basis, pos + Vector3(0, cy, 0))
		var alt: String = {"gate_a": "gate_b", "gate_b": "gate_a", "led_blue": "led_orange", "led_orange": "led_blue"}.get(mat, mat)
		_frame(geo, xf, GATE, GATE, mat if i % 2 == 0 else alt)
		if i == through:
			_register(xf, GATE, GATE)
	if lift > 0.0:
		for sx in [-1.0, 1.0]:
			var leg: Vector3 = pos + basis * Vector3(sx * (GATE * 0.5 + PANEL * 0.5), 0, 0)
			geo.box(leg + Vector3(0, lift * 0.5, 0), Vector3(0.08, lift, 0.08), "gate_pole", yaw)

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
	if lift > 0.0:
		geo.box(pos + Vector3(0, lift * 0.5, 0), Vector3(bar, lift, bar), "gate_pole", yaw)
	_register(xf, w, h)

## The start/finish gate: a standard gate with a wide black-and-white
## banner on top. Always the first gate of the course.
func start_gate(geo: Geo, pos: Vector3, yaw: float) -> void:
	gate(geo, pos, yaw, 1, 0.0, 0, "gate_dark")
	var basis := Basis(Vector3.UP, yaw)
	var top: Vector3 = pos + Vector3(0, PANEL * 2 + GATE + 0.45, 0)
	for i in range(8):
		var x: float = -1.4 + i * 0.4
		geo.box_xf(Transform3D(basis, top + basis * Vector3(x, 0.2, 0)), Vector3(0.4, 0.4, 0.05), "gate_white" if i % 2 == 0 else "gate_dark")
		geo.box_xf(Transform3D(basis, top + basis * Vector3(x, -0.2, 0)), Vector3(0.4, 0.4, 0.05), "gate_dark" if i % 2 == 0 else "gate_white")
	for sx in [-1.0, 1.0]:
		geo.box(pos + basis * Vector3(sx * 1.6, 0, 0) + Vector3(0, 1.6, 0), Vector3(0.08, 3.2, 0.08), "gate_pole", yaw)

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

## A hurdle: wide and low - fly under the bar, over the ground.
func hurdle(geo: Geo, pos: Vector3, yaw: float, mat: String = "gate_b") -> void:
	var w: float = 2.44
	var h: float = 0.76
	var xf := Transform3D(Basis(Vector3.UP, yaw), pos + Vector3(0, h * 0.5, 0))
	var basis := Basis(Vector3.UP, yaw)
	geo.box_xf(Transform3D(basis, pos + Vector3(0, h + PANEL * 0.5, 0)), Vector3(w + 2 * PANEL, PANEL, 0.06), mat)
	for sx in [-1.0, 1.0]:
		geo.box_xf(Transform3D(basis, pos + basis * Vector3(sx * (w * 0.5 + PANEL * 0.5), (h + PANEL) * 0.5, 0)), Vector3(PANEL, h + PANEL, 0.06), mat)
	_register(xf, w, h)

## A turn flag: tall curved "teardrop" banner on a pole. Visual only.
func flag(geo: Geo, pos: Vector3, mat: String = "gate_a") -> void:
	geo.cylinder(pos, pos + Vector3(0, 3.6, 0), 0.03, "gate_pole", 6)
	for i in range(6):
		var t: float = i / 6.0
		var w: float = 0.55 * sin((t * 0.85 + 0.1) * PI)
		geo.box(pos + Vector3(w * 0.5 + 0.03, 3.4 - t * 2.6, 0), Vector3(w, 0.44, 0.02), mat, 0.0, false)

# --- running the race --------------------------------------------------------

func _physics_process(delta: float) -> void:
	if drone == null or _gates.is_empty():
		return
	_time += delta
	var pos: Vector3 = drone.global_position
	if pos.distance_to(_prev_pos) > 8.0:
		_reset_run() # R / crash reset / world border: the run is void
	elif _crossed(_gates[_next], _prev_pos, pos):
		_passed()
	_prev_pos = pos
	if _lap_start >= 0.0:
		_sample_t += delta
		if _sample_t >= 1.0 / GHOST_HZ:
			_sample_t = 0.0
			_lap_samples.append(pos)
			_lap_rot.append(drone.global_transform.basis.get_euler())
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
			if _best < 0.0 or _last_lap < _best:
				_best = _last_lap
				_save_best()
				_ghost_pos = _lap_samples.duplicate()
				_ghost_rot = _lap_rot.duplicate()
				_save_ghost()
		_lap_samples.clear()
		_lap_rot.clear()
		_sample_t = 0.0
		_lap += 1
		_lap_start = _time
	_next = (_next + 1) % _gates.size()
	_place_marker()

func _reset_run() -> void:
	_lap_samples.clear()
	_lap_rot.clear()
	_next = 0
	_lap = 0
	_lap_start = -1.0
	_place_marker()

func current_lap_time() -> float:
	return _time - _lap_start if _lap_start >= 0.0 else 0.0

func _update_hud() -> void:
	if ui == null or not ui.has_method("set_race_info"):
		return
	var best: String = _fmt(_best) if _best >= 0.0 else "--"
	if _lap_start < 0.0:
		ui.set_race_info("Fly through the START gate    Best %s" % best)
		return
	var last: String = ("   Last %s" % _fmt(_last_lap)) if _last_lap >= 0.0 else ""
	ui.set_race_info("Lap %d   %s   Gate %d/%d   Best %s%s" % [_lap, _fmt(current_lap_time()), (_next - 1 + _gates.size()) % _gates.size() + 1, _gates.size(), best, last])

static func _fmt(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]

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

## A translucent, glowing stand-in shaped roughly like a quad.
func _build_ghost() -> void:
	_ghost = Node3D.new()
	_ghost.name = "Ghost"
	add_child(_ghost)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(0.4, 0.8, 1.0, 0.45)
	var s: float = drone.arm_length * 2.4
	for part in [[Vector3(s, 0.02, 0.03), 0.785], [Vector3(s, 0.02, 0.03), -0.785], [Vector3(0.05, 0.04, 0.08), 0.0]]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[0]
		mi.mesh = bm
		mi.material_override = mat
		mi.rotation.y = part[1]
		_ghost.add_child(mi)
	_ghost.visible = false

func _update_ghost() -> void:
	if _ghost == null:
		return
	var n: int = _ghost_pos.size()
	_ghost.visible = n > 1 and _lap_start >= 0.0
	if not _ghost.visible:
		return
	var f: float = current_lap_time() * GHOST_HZ
	var i: int = mini(int(f), n - 2)
	var t: float = clampf(f - i, 0.0, 1.0)
	if int(f) >= n - 1:
		_ghost.visible = false # the ghost already finished its lap
		return
	_ghost.global_position = _ghost_pos[i].lerp(_ghost_pos[i + 1], t)
	_ghost.rotation = _ghost_rot[i]

func _save_ghost() -> void:
	var cfg := ConfigFile.new()
	cfg.load(GHOST_PATH)
	cfg.set_value(map_id, _key() + "_pos", _ghost_pos)
	cfg.set_value(map_id, _key() + "_rot", _ghost_rot)
	cfg.save(GHOST_PATH)

func _load_ghost() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GHOST_PATH) != OK:
		return
	_ghost_pos = cfg.get_value(map_id, _key() + "_pos", PackedVector3Array())
	_ghost_rot = cfg.get_value(map_id, _key() + "_rot", PackedVector3Array())

func _key() -> String:
	return Settings.selected_drone

func _load_best() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return -1.0
	return cfg.get_value(map_id, _key(), -1.0)

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)
	cfg.set_value(map_id, _key(), _best)
	cfg.save(RECORDS_PATH)
