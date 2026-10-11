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

## The pilot's race saves. A --selftest or --dev-preview run keeps its own
## in user://selftest/ - the tests fly laps, and once (2026-10-10) left
## fake 0.25 s records in the real files; this way they can't, even when
## a run is killed halfway.
static var RECORDS_PATH: String = save_path("race_records.cfg")

static func save_path(file: String) -> String:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.has("--selftest") or args.has("--dev-preview"):
		DirAccess.make_dir_recursive_absolute("user://selftest")
		return "user://selftest/" + file
	return "user://" + file
const GATE: float = 1.52 ## MultiGP standard opening, 5 ft
const PANEL: float = 0.28 ## frame panel width
## A standing gate's frame rides this high on its feet: its bottom PVC
## tube, flush with the ground, flickered against the grass.
const FOOT: float = 0.04

var map_id: String = ""
## Which of the map's tracks this is (1-based; RaceCourse.make).
var track: int = 1
## The track's layout revision (a track's "rev": a redesigned track starts
## a fresh record table).
var rev: int = 1
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
static var GHOST_PATH: String = save_path("race_ghosts.cfg")
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
	migrate_saves()
	_spawn_at_start()
	_best = _load_best()
	_prev_pos = drone.global_position
	_build_marker()
	_build_numbers()
	if Settings.race_line_on():
		_build_line()
	_build_ghost()
	_load_ghost()
	_reset_run()
	# Every reset voids the run - also one that lands within a few metres
	# (a reset near the start gate used to be missed by the jump check in
	# _physics_process, leaving the gates mid-lap: "sometimes the gates
	# don't get reset", 2026-10-06).
	drone.was_reset.connect(_on_drone_reset)

## Race mode spawns (and resets) the drone on the ground a few metres in
## front of START, facing through it.
const SPAWN_BACK: float = 4.0
func _spawn_at_start() -> void:
	if _gates.is_empty() or drone == null:
		return
	var g: Dictionary = _gates[0]
	var fwd: Vector3 = (-g.xf.basis.z * Vector3(1, 0, 1)).normalized()
	var pos: Vector3 = g.xf.origin - fwd * (SPAWN_BACK if g.w >= 1.0 else 2.0) # a whoop gate: closer
	# On the floor below (a START may stand on a desk or a stage).
	var q := PhysicsRayQueryParameters3D.create(pos, pos - Vector3(0, 20, 0))
	q.exclude = [drone.get_rid()]
	var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
	pos.y = (hit.position.y if not hit.is_empty() else drone.global_position.y - 0.25) + 0.25
	drone.set_spawn(Transform3D(Basis.looking_at(fwd, Vector3.UP), pos))

func _on_drone_reset() -> void:
	_reset_run()
	_prev_pos = drone.global_position

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
	# Pass direction: a green ring round the opening on the side you fly in
	# from, a red one on the way-out side (self-lit, so the red reads in
	# the analog camera look too).
	geo.add_material("dir_in", Geo.glow_mat(Color(0.15, 1.0, 0.3), 2.2))
	geo.add_material("dir_out", Geo.glow_mat(Color(1.0, 0.1, 0.06), 2.2))

## The pass-direction rings of an opening (`xf` its centre, -Z the way
## through): green on the entry face (+Z), red on the exit face, each `rw`
## wide round the edge, `dz` out from the frame's middle - on the frame's
## faces, so each colour shows from its own side only. `bottom` false for
## an opening standing on the ground (a hurdle).
func _direction(geo: Geo, xf: Transform3D, w: float, h: float, dz: float, rw: float, bottom: bool = true) -> void:
	for side: Array in [[1.0, "dir_in"], [-1.0, "dir_out"]]:
		var z: float = side[0] * dz
		var edges: Array = [[Vector3(0, h * 0.5 + rw * 0.5, z), Vector3(w + 2 * rw, rw, 0.012)],
			[Vector3(-w * 0.5 - rw * 0.5, 0, z), Vector3(rw, h, 0.012)], [Vector3(w * 0.5 + rw * 0.5, 0, z), Vector3(rw, h, 0.012)]]
		if bottom:
			edges.append([Vector3(0, -h * 0.5 - rw * 0.5, z), Vector3(w + 2 * rw, rw, 0.012)])
		for e: Array in edges:
			geo.box_xf(xf * Transform3D(Basis(), e[0]), e[1], side[1], false, false)

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
			_direction(geo, xf, GATE, GATE, 0.0625, 0.07)
	if lift > 0.0:
		for sx in [-1.0, 1.0]:
			var leg: Vector3 = pos + basis * Vector3(sx * (GATE * 0.5 + PANEL * 0.5), 0, 0)
			geo.box(leg + Vector3(0, lift * 0.5, 0), Vector3(0.08, lift, 0.08), "gate_pole", yaw)
	_feet(geo, pos, basis, GATE * 0.5 + PANEL * 0.5)

## A split-S ladder: three openings stacked `gap` m apart (centre to
## centre) on two tall posts, flown top first (facing `yaw`), a split-S
## (roll inverted, half loop down) back through the middle (the other
## way), another split-S out through the bottom (facing `yaw` again).
## Each opening counts as its own gate. 3.5 m: a split-S at full rate
## costs the drones 1.4-1.7 m of height plus ~0.3 m to stop the sink
## (measured with the flight model at 8-14 m/s, 2026-10-10) - room for a
## pilot's split-S at a sane speed, not a free fall.
func ladder(geo: Geo, pos: Vector3, yaw: float, gap: float = 3.5, mat: String = "gate_b") -> void:
	var basis := Basis(Vector3.UP, yaw)
	var c0: float = FOOT + PANEL + GATE * 0.5
	var alt: String = {"gate_a": "gate_b", "gate_b": "gate_a"}.get(mat, mat)
	for i in [2, 1, 0]: # top first: the lap order
		var b: Basis = basis if i != 1 else Basis(Vector3.UP, yaw + PI)
		var xf := Transform3D(b, pos + Vector3(0, c0 + i * gap, 0))
		_frame(geo, xf, GATE, GATE, mat if i != 1 else alt)
		_register(xf, GATE, GATE)
		_direction(geo, xf, GATE, GATE, 0.0625, 0.07)
	var top: float = c0 + 2 * gap + GATE * 0.5 + PANEL
	for sx in [-1.0, 1.0]:
		var leg: Vector3 = pos + basis * Vector3(sx * (GATE * 0.5 + PANEL + 0.06), 0, 0)
		geo.box(leg + Vector3(0, top * 0.5, 0), Vector3(0.1, top, 0.1), "gate_pole", yaw)
	_feet(geo, pos, basis, GATE * 0.5 + PANEL + 0.06)

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
	_direction(geo, xf, w, h, d * 0.65 + 0.006, maxf(bar * 0.7, 0.03))
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
	_direction(geo, xf, GATE, GATE, 0.0625, 0.07)
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
		_direction(geo, xf, size, size, 0.0625, 0.07)
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
	_direction(geo, xf, w, h, 0.036, 0.07, false)

## A flag: tall curved "teardrop" banner on a pole. Visual only - scenery
## away from the course (a flag on a track is a turn_flag).
func flag(geo: Geo, pos: Vector3, mat: String = "gate_a") -> void:
	_flag_pole(geo, pos, Basis(), mat)

func _flag_pole(geo: Geo, pos: Vector3, basis: Basis, mat: String) -> void:
	geo.cylinder(pos, pos + Vector3(0, 3.6, 0), 0.03, "gate_pole", 6)
	geo.cylinder(pos, pos + Vector3(0, 0.06, 0), 0.25, "gate_base", 10)
	for i in range(6):
		var t: float = i / 6.0
		var w: float = 0.55 * sin((t * 0.85 + 0.1) * PI)
		geo.box_xf(Transform3D(basis, pos + basis * Vector3(w * 0.5 + 0.03, 3.4 - t * 2.6, 0)), Vector3(w, 0.44, 0.02), mat, false)

## A turn flag: a gate you pass on one side of a pole. Flying past it
## toward -Z (after turning by `yaw`), `side` "left" or "right" says
## which side of the flag to pass ("left": the flag stays on your right).
## It counts like a gate: an invisible opening FLAG_W wide from the pole
## out to the right side and FLAG_H up; passing the pole on the wrong side
## is a missed gate. The look (_build_flags): a feather banner on the
## wrong side, on the ground a soft green band of chevrons pointing the way
## on the right side and a red hatch on the wrong one. The racing line,
## the next-gate arrow and the number board use a FLAG_AIM square just
## beside the pole.
const FLAG_W: float = 8.0
const FLAG_H: float = 10.0
const FLAG_AIM: float = 3.0
const FLAG_COLOURS: Dictionary = {"gate_a": Color(0.12, 0.42, 0.9), "gate_b": Color(0.93, 0.36, 0.1)}
var _flags: Array[Dictionary] = [] # {pos, basis, s, colour, gate}
var _flag_decal: MeshInstance3D
func turn_flag(geo: Geo, pos: Vector3, yaw: float, side: String, mat: String = "gate_b") -> void:
	var basis := Basis(Vector3.UP, yaw)
	var s: float = 1.0 if side == "right" else -1.0
	geo.cylinder(pos, pos + Vector3(0, 3.7, 0), 0.03, "gate_pole", 6)
	geo.cylinder(pos, pos + Vector3(0, 0.06, 0), 0.25, "gate_base", 10)
	var aim := Transform3D(basis, pos + basis * Vector3(s * (FLAG_AIM * 0.5 + 0.1), 0, 0) + Vector3(0, FLAG_AIM * 0.5 + 0.1, 0))
	var zone := Transform3D(basis, pos + basis * Vector3(s * FLAG_W * 0.5, 0, 0) + Vector3(0, FLAG_H * 0.5, 0))
	_register(aim, FLAG_AIM, FLAG_AIM)
	_gates[_gates.size() - 1].merge({"zone": {"xf": zone, "w": FLAG_W, "h": FLAG_H}, "flag": s, "pole": pos})
	_flags.append({"pos": pos, "basis": basis, "s": s, "colour": FLAG_COLOURS.get(mat, Color(0.93, 0.36, 0.1)), "gate": _gates.size() - 1})

## The turn flags' banners (one mesh) and ground marks (one mesh, its
## shader lights up and animates the next flag's chevrons).
func _build_flags() -> void:
	if _flags.is_empty():
		return
	# Feather banners: a teardrop sail on the wrong side of the pole, a
	# little curved, team colour with a white stripe near the outer edge.
	var bv := PackedVector3Array()
	var bc := PackedColorArray()
	var bi := PackedInt32Array()
	var us: Array[float] = [0.0, 0.35, 0.7, 0.72, 0.84, 0.86, 1.0]
	const ROWS: int = 18
	for f in _flags:
		var out: Vector3 = f.basis * Vector3(-f.s, 0, 0) # away from the pass
		var back: Vector3 = f.basis * Vector3(0, 0, 1)
		var base: int = bv.size()
		for r in range(ROWS + 1):
			var t: float = float(r) / ROWS
			var w: float = 0.72 * sin(PI * pow(t, 0.62)) + 0.04
			var y: float = 3.62 - t * 2.75
			for u in us:
				var x: float = u * w
				var p: Vector3 = f.pos + Vector3(0, y, 0) + out * (x + 0.03) + back * (0.16 * u * u)
				bv.append(to_local(p))
				var white: bool = u > 0.71 and u < 0.85
				var c: Color = Color(0.96, 0.96, 0.94) if white else f.colour
				bc.append(c * (0.78 + 0.22 * (1.0 - t)) if not white else c * (0.85 + 0.15 * (1.0 - t)))
		var nu: int = us.size()
		for r in range(ROWS):
			for k in range(nu - 1):
				var i0: int = base + r * nu + k
				bi.append_array([i0, i0 + nu, i0 + 1, i0 + 1, i0 + nu, i0 + nu + 1])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = bv
	arr[Mesh.ARRAY_COLOR] = bc
	arr[Mesh.ARRAY_INDEX] = bi
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.vertex_color_use_as_albedo = true
	bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	var banners := MeshInstance3D.new()
	banners.name = "FlagBanners"
	banners.mesh = mesh
	banners.material_override = bm
	banners.set_meta("keep_material", true)
	add_child(banners)
	# Ground marks: one quad per flag, UV = metres across (+ = the pass
	# side) and ahead, UV2.x = its gate index.
	var gv := PackedVector3Array()
	var gu := PackedVector2Array()
	var g2 := PackedVector2Array()
	var gi := PackedInt32Array()
	for f in _flags:
		var base: int = gv.size()
		for c in [Vector2(-3.0, -3.0), Vector2(6.5, -3.0), Vector2(6.5, 3.0), Vector2(-3.0, 3.0)]:
			gv.append(to_local(f.pos + Vector3(0, 0.06, 0) + f.basis * Vector3(f.s * c.x, 0, -c.y)))
			gu.append(c)
			g2.append(Vector2(f.gate, 0))
		gi.append_array([base, base + 1, base + 2, base, base + 2, base + 3])
	arr = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = gv
	arr[Mesh.ARRAY_TEX_UV] = gu
	arr[Mesh.ARRAY_TEX_UV2] = g2
	arr[Mesh.ARRAY_INDEX] = gi
	mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform float active = -1.0;
void fragment() {
	float x = UV.x;  // metres from the pole, + = the side to pass
	float z = UV.y;  // metres ahead
	float on = step(abs(UV2.x - active), 0.5);
	float along = 1.0 - smoothstep(1.8, 3.0, abs(z));
	// Green: chevrons pointing ahead over a soft band, fading outward.
	float band = smoothstep(0.15, 0.7, x) * (1.0 - smoothstep(3.0, 6.5, x)) * along;
	float p = z + 0.6 * abs(x - 2.6);
	float st = fract(p / 1.5 - TIME * 0.9 * on);
	float chev = smoothstep(0.0, 0.06, st) * (1.0 - smoothstep(0.3, 0.36, st));
	float g = band * (0.16 + 0.6 * chev) * (0.6 + 0.4 * on);
	// Red: a diagonal hatch on the wrong side, fading out.
	float rb = smoothstep(-0.15, -0.6, x) * (1.0 - smoothstep(1.2, 3.0, -x)) * along;
	float hatch = smoothstep(0.45, 0.55, fract((x + z) * 1.25));
	float r = rb * (0.1 + 0.35 * hatch);
	ALBEDO = g >= r ? vec3(0.2, 1.0, 0.4) * 1.3 : vec3(1.0, 0.18, 0.12) * 1.2;
	ALPHA = clamp(max(g, r), 0.0, 0.85);
}
"""
	var gm := ShaderMaterial.new()
	gm.shader = sh
	_flag_decal = MeshInstance3D.new()
	_flag_decal.name = "FlagMarks"
	_flag_decal.mesh = mesh
	_flag_decal.material_override = gm
	_flag_decal.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_flag_decal.set_meta("keep_material", true)
	add_child(_flag_decal)

# --- tracks ------------------------------------------------------------------

## A race map's course, built at load time on top of the (cached) map:
## `tracks` is the map's list of {"name", "level", "calls"} (Settings
## .race_track picks one), `calls` the gate builders as data (see
## build_track). The gates get their own small Geo, committed under the
## course node - so one map cache serves every track. They are marked
## "dynamic" (left out of the static shadow map, which is cached with the
## map and would otherwise keep the shadows of whichever track was built
## first). opts: "ao_height", "ao_min" for the gates' baked AO.
static func make(map: BuiltMap, tracks: Array, opts: Dictionary = {}) -> RaceCourse:
	var t: int = clampi(Settings.race_track, 1, tracks.size())
	var g := Geo.new()
	for p in ["sun_dir", "sun", "sun_tint", "ambient", "sky"]:
		g.set(p, map.geo.get(p))
	g.ao_height = float(opts.get("ao_height", 1.5))
	g.ao_min = float(opts.get("ao_min", g.ao_min))
	add_materials(g)
	var rc := RaceCourse.new()
	rc.name = "RaceCourse"
	rc.track = t
	rc.rev = int(tracks[t - 1].get("rev", 1))
	map.add_child(rc)
	rc.build_track(g, tracks[t - 1].calls)
	g.commit(rc)
	rc.set_meta("dynamic", true)
	return rc

## Builds a track from data: each call is [kind, args...] with kind one of
## "start" | "gate" | "sized" | "dive" | "hurdle" | "flag" | "turn" | "hanging" | "ladder"
## (the builders above, args in their order after geo) or "box" (a plain
## prop: centre, size, colour - e.g. the desk under a gate; its own flat
## material, since the map's are not there on a cached load).
func build_track(geo: Geo, calls: Array) -> void:
	var fn: Dictionary = {"start": "start_gate", "gate": "gate", "sized": "gate_sized", "dive": "dive_gate",
		"hurdle": "hurdle", "flag": "flag", "turn": "turn_flag", "hanging": "hanging_gate", "ladder": "ladder"}
	for c: Array in calls:
		var kind: String = c[0]
		if kind == "box":
			var m: String = "prop_" + (c[3] as Color).to_html(false)
			if not geo.has_material(m):
				geo.add_material(m, Geo.flat_mat(c[3]))
			geo.box(c[1], c[2], m)
			continue
		assert(fn.has(kind), "unknown track call " + kind)
		callv(fn[kind], [geo] + c.slice(1))
	_build_flags()

## How many gates a track's calls register (for the self-test and menus).
static func gate_count(calls: Array) -> int:
	var n: int = 0
	for c: Array in calls:
		if c[0] in ["start", "gate", "sized", "dive", "hurdle", "hanging", "turn"]:
			n += 1
		elif c[0] == "ladder":
			n += 3
	return n

# --- running the race --------------------------------------------------------
#
# A race is LAPS laps from a flying start: the clock starts at the first
# pass of the START gate and stops at the end of the last lap. Every
# gate shows the split against the best lap (green ahead, red behind).
# Gates count strictly in order: flying through a later gate instead of
# the next one says "MISSED GATE n - go back" (with the way to it) until
# the missed gate is flown - the clock keeps running. At the finish: lap
# times, total, and the track's top-5 races (per drone).

const LAPS: int = 2
static var BOARD_PATH: String = save_path("race_board.cfg")
var _race_laps: Array[float] = []
var _splits: Array[float] = []      # this lap: time at each gate
var _best_splits: Array = []        # the best lap's
var _delta_text: String = ""
var _delta_t: float = 0.0
var _missed_gate: int = -1
var _beep: AudioStreamPlayer

func _physics_process(delta: float) -> void:
	if drone == null or _gates.is_empty():
		return
	_time += delta
	_delta_t = maxf(_delta_t - delta, 0.0)
	var pos: Vector3 = drone.global_position
	if pos.distance_to(_prev_pos) > 8.0:
		_reset_run() # R / crash reset / world border: the run is void
	elif _crossed(_gates[_next], _prev_pos, pos):
		_passed()
	elif _lap_start >= 0.0 and _gates[_next].has("flag") and _wrong_side(_gates[_next], _prev_pos, pos):
		if _missed_gate != _next:
			_play("miss")
		_missed_gate = _next # past the flag on the wrong side: go back round it
	elif _lap_start >= 0.0:
		for i in range(_gates.size()):
			# A flag's wide invisible opening only counts as the next gate:
			# flying through one elsewhere on the lap isn't skipping ahead.
			if i != _next and i != (_next - 1 + _gates.size()) % _gates.size() and not _gates[i].has("flag") and _crossed(_gates[i], _prev_pos, pos):
				if _missed_gate != _next:
					_play("miss")
				_missed_gate = _next # until it is flown (_passed)
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
	var z: Dictionary = g.get("zone", g) # a turn flag: its wide opening
	var hit: Variant = _plane_hit(z.xf, a, b)
	return hit != null and absf(hit.x) <= z.w * 0.5 and absf(hit.y) <= z.h * 0.5

## Past a turn flag on the wrong side: across its line within FLAG_W of
## the pole on the other side.
func _wrong_side(g: Dictionary, a: Vector3, b: Vector3) -> bool:
	var z: Dictionary = g.zone
	var hit: Variant = _plane_hit(z.xf, a, b)
	if hit == null or absf(hit.y) > z.h * 0.5:
		return false
	var x: float = hit.x * g.flag # 0 at the opening's middle, -w/2 at the pole
	return x < -z.w * 0.5 and x >= -z.w * 1.5

## Where the step a -> b crosses the plane of `xf` going toward -Z (in its
## local space), or null.
static func _plane_hit(xf: Transform3D, a: Vector3, b: Vector3) -> Variant:
	var inv: Transform3D = xf.affine_inverse()
	var la: Vector3 = inv * a
	var lb: Vector3 = inv * b
	if not (la.z > 0.0 and lb.z <= 0.0):
		return null
	return la.lerp(lb, la.z / (la.z - lb.z))

func _passed() -> void:
	_missed_gate = -1
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
			_count_stat(0)
			_play("go")
			if ui and ui.has_method("close_race_results"):
				ui.close_race_results() # the next race is on
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

## The last lap is in: the finish card, the track's top 5 (per drone),
## back to waiting at START. A new track record = faster than every race
## on this track by any drone.
func _finish() -> void:
	var total: float = 0.0
	for l in _race_laps:
		total += l
	var board: Array = _board()
	var prev_best: float = float(board[0][0]) if not board.is_empty() else -1.0
	var record_before: float = -1.0
	var all_boards: Dictionary = boards(map_id, track) if map_id != "" else {_key(): board}
	for id in all_boards:
		for e in all_boards[id]:
			if record_before < 0.0 or float(e[0]) < record_before:
				record_before = float(e[0])
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
	cfg.set_value(_section(), _key(), board)
	_save_cfg(cfg, BOARD_PATH)
	_count_stat(1)
	var record: bool = record_before < 0.0 or total < record_before
	_play("record" if record else "finish")
	if ui and ui.has_method("show_race_finish"):
		var tl: Array = track_list(map_id) if map_id != "" else []
		var tr: Dictionary = tl[track - 1] if track <= tl.size() else {}
		ui.show_race_finish({"track": tr.get("name", "Race"), "level": tr.get("level", "easy"),
			"drone": Drone.PROFILES.get(_key(), Drone.PROFILES["seeker3"]).display.name,
			"total": total, "prev_best": prev_best, "laps": _race_laps.duplicate(), "top": board.slice(0, 3),
			"you": rank if rank < 3 else -1, "record": record, "new_best": not record and prev_best >= 0.0 and total < prev_best})
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
	return cfg.get_value(_section(), _key(), [])

## The track's top-5 races for the menu: {drone id: [[total, best lap, date], ...]}.
static func boards(p_map_id: String, p_track: int = 1) -> Dictionary:
	migrate_saves()
	var out := {}
	var cfg := ConfigFile.new()
	var sec: String = section(p_map_id, p_track)
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
	_missed_gate = -1
	_place_marker()

func current_lap_time() -> float:
	return _time - _lap_start if _lap_start >= 0.0 else 0.0

var _pb_flash: float = 0.0

func _update_hud() -> void:
	if ui == null or not ui.has_method("set_race_hud"):
		return
	var best: String = _fmt(_best) if _best >= 0.0 else ""
	var d := {"laps": LAPS, "best": best}
	if _pb_flash > 0.0:
		_pb_flash -= get_physics_process_delta_time()
		d.msg = "NEW BEST LAP  %s" % best
		d.msg_good = true
	if _lap_start < 0.0:
		d.wait = true
		ui.set_race_hud(d)
		return
	d.merge({"lap": _lap, "time": _fmt(current_lap_time()), "gate": (_next - 1 + _gates.size()) % _gates.size() + 1, "gates": _gates.size()})
	if _delta_t > 0.0:
		d.delta = _delta_text
		d.delta_good = _delta_text.begins_with("-")
	if _missed_gate >= 0:
		d.msg = "MISSED GATE %d - go back   %s" % [_missed_gate + 1, _way_to(_gates[_missed_gate])]
		d.msg_good = false
	ui.set_race_hud(d)

## Which way to turn for a gate, from the drone's heading: "<<< LEFT",
## "AHEAD", "RIGHT >>>", "BEHIND YOU".
func _way_to(g: Dictionary) -> String:
	var to: Vector3 = (g.xf.origin - drone.global_position) * Vector3(1, 0, 1)
	var fwd: Vector3 = -drone.global_transform.basis.z * Vector3(1, 0, 1)
	if to.length() < 0.5 or fwd.length() < 0.01:
		return "AHEAD"
	var a: float = rad_to_deg(fwd.signed_angle_to(to, Vector3.UP)) # + = to the left
	if absf(a) < 25.0:
		return "AHEAD"
	if absf(a) > 140.0:
		return "BEHIND YOU"
	return "<<< LEFT" if a > 0.0 else "RIGHT >>>"

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
	"record": [[1046.0, 0.1], [1318.0, 0.1], [1568.0, 0.1], [2093.0, 0.14], [1568.0, 0.08], [2093.0, 0.36]],
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
		if g.has("pole"): # a turn flag: on top of the pole
			lb.position = to_local(g.pole + Vector3(0, 4.2, 0))
			add_child(lb)
			continue
		var top: Vector3 = g.xf.origin + (up * (g.h * 0.5 + PANEL + 0.45 * sc) if absf(up.y) > 0.5 else Vector3(0, 0.9 * sc, 0) + g.xf.basis.y * (g.h * 0.5 + PANEL))
		lb.position = to_local(top)
		add_child(lb)

## Four glowing bars just inside the next opening, plus a bobbing
## chevron above it - visible from across the field. The bars are
## one-sided: green seen from the entry side, red from the wrong side
## (like the gates' direction rings).
func _build_marker() -> void:
	_marker = Node3D.new()
	_marker.name = "NextGateMarker"
	add_child(_marker)
	var mat := Geo.glow_mat(Color(0.2, 1.0, 0.45), 3.0)
	var red := Geo.glow_mat(Color(1.0, 0.12, 0.08), 3.0)
	for i in range(8):
		var mi := MeshInstance3D.new()
		mi.mesh = QuadMesh.new()
		mi.material_override = mat if i < 4 else red
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.set_meta("keep_material", true) # one-sided: keep the culling
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
	if _flag_decal:
		(_flag_decal.material_override as ShaderMaterial).set_shader_parameter("active", float(_next) if g.has("flag") else -1.0)
	for i in range(8): # a flag: its ground marks light up instead of the frame
		_marker.get_child(i).visible = not g.has("flag")
	var w: float = g.w
	var h: float = g.h
	var t: float = 0.08
	var bars: Array = [[Vector3(0, h * 0.5 - t * 0.5, 0), Vector2(w, t)], [Vector3(0, -h * 0.5 + t * 0.5, 0), Vector2(w, t)],
		[Vector3(-w * 0.5 + t * 0.5, 0, 0), Vector2(t, h)], [Vector3(w * 0.5 - t * 0.5, 0, 0), Vector2(t, h)]]
	for i in range(8):
		var mi: MeshInstance3D = _marker.get_child(i)
		var b: Array = bars[i % 4]
		# Green faces +Z (the entry side), red faces -Z (turned round).
		mi.position = b[0] + Vector3(0, 0, 0.02 if i < 4 else -0.02)
		mi.rotation = Vector3(0, 0 if i < 4 else PI, 0)
		(mi.mesh as QuadMesh).size = b[1]
	var arrow: Node3D = _marker.get_node("Arrow")
	# Scaled with the gate: a 60 cm whoop gate gets a small arrow.
	var sc: float = clampf(w / GATE, 0.3, 1.0)
	arrow.scale = Vector3.ONE * sc
	arrow.position = Vector3(0, h * 0.5 + 0.9 * sc, 0)

func _process(_delta: float) -> void:
	_update_line()
	if _marker:
		var arrow: Node3D = _marker.get_node("Arrow")
		if not _gates.is_empty():
			arrow.position.y = _gates[_next].h * 0.5 + (0.9 + sin(Time.get_ticks_msec() * 0.004) * 0.15) * arrow.scale.y

## The racing line: a thin see-through tube through every opening in
## lap order, each stretch a Hermite curve along the gates' pass
## directions (the harder the turn, the longer the tangents - a reversal
## becomes a half loop, so a split-S ladder draws its loops). One mesh,
## unshaded, half transparent, fading out near the camera. Only the part
## ahead is drawn: every vertex carries its distance along the lap (UV.x)
## and the shader draws only the next few gates' worth ahead of the
## drone (_update_line). (Step 7 adds its settings; on by default for now.)
const LINE_STEP: float = 0.4
const LINE_R: float = 0.05
const LINE_SIDES: int = 6
var _line: MeshInstance3D
var _line_pts := PackedVector3Array()   # world points along the lap
var _line_arc := PackedFloat32Array()   # distance along the lap at each point
var _line_seg := PackedInt32Array()     # first point of each gate's stretch (gate i -> i+1), + the end
## A track's shape for the menu, without loading its map: the gates are
## built into a throwaway Geo (nothing drawn) and the racing line run
## through them. {"pts": PackedVector2Array (x, z), "gates": Array of
## [Vector2 position, Vector2 direction], "length": metres along the line}.
static var _shapes: Dictionary = {}
static func track_shape(p_map_id: String, p_track: int) -> Dictionary:
	var key: String = "%s#%d" % [p_map_id, p_track]
	if _shapes.has(key):
		return _shapes[key]
	var tl: Array = track_list(p_map_id)
	if p_track < 1 or p_track > tl.size():
		return {}
	var rc := RaceCourse.new()
	var g := Geo.new()
	add_materials(g)
	for c: Array in tl[p_track - 1].calls:
		if c[0] in ["box", "flag"]:
			continue
		rc.callv({"start": "start_gate", "gate": "gate", "sized": "gate_sized", "dive": "dive_gate", "hurdle": "hurdle",
			"turn": "turn_flag", "hanging": "hanging_gate", "ladder": "ladder"}[c[0]], [g] + c.slice(1))
	var lp: Dictionary = line_path(rc._gates)
	var pts := PackedVector2Array()
	var length: float = 0.0
	var p3: PackedVector3Array = lp.pts
	for i in range(p3.size()):
		pts.append(Vector2(p3[i].x, p3[i].z))
		if i > 0:
			length += p3[i].distance_to(p3[i - 1])
	var gs: Array = []
	for gd in rc._gates:
		var f: Vector3 = -gd.xf.basis.z
		gs.append([Vector2(gd.xf.origin.x, gd.xf.origin.z), Vector2(f.x, f.z)])
	rc.free()
	_shapes[key] = {"pts": pts, "gates": gs, "length": length}
	return _shapes[key]

## The racing line's points through `gates` (world space) and the first
## point of each gate's stretch (+ the end): {"pts", "seg"}. Also used
## for the menu's track sketches (track_shape).
static func line_path(gates: Array) -> Dictionary:
	var pts := PackedVector3Array()
	var seg := PackedInt32Array()
	var n: int = gates.size()
	for i in range(n):
		seg.append(pts.size())
		var a: Dictionary = gates[i]
		var b: Dictionary = gates[(i + 1) % n]
		var p0: Vector3 = a.xf.origin
		var p1: Vector3 = b.xf.origin
		var d0: Vector3 = -a.xf.basis.z.normalized()
		var d1: Vector3 = -b.xf.basis.z.normalized()
		var l: float = p0.distance_to(p1)
		var x: float = 1.0 - d0.dot(d1)
		var k: float = 1.0 - 0.16 * x + 0.33 * x * x # 1 straight, ~1.17 a quarter turn, 2 a half loop
		var t0: Vector3 = d0 * l * k
		var t1: Vector3 = d1 * l * k
		var floor_y: float = minf(p0.y, p1.y) - 0.3
		var steps: int = maxi(int(l * (1.0 + x) / LINE_STEP), 2)
		for j in range(steps):
			var t: float = float(j) / steps
			var t2: float = t * t
			var t3: float = t2 * t
			var p: Vector3 = (2 * t3 - 3 * t2 + 1) * p0 + (t3 - 2 * t2 + t) * t0 + (-2 * t3 + 3 * t2) * p1 + (t3 - t2) * t1
			p.y = maxf(p.y, floor_y)
			if j == 0 or p.distance_to(pts[pts.size() - 1]) >= LINE_STEP:
				pts.append(p)
	pts.append(pts[0]) # closed: back into START
	seg.append(pts.size() - 1)
	return {"pts": pts, "seg": seg}

func _build_line() -> void:
	var lp: Dictionary = line_path(_gates)
	var pts: PackedVector3Array = lp.pts
	_line_seg = lp.seg
	_line_pts = pts
	_line_arc.resize(pts.size())
	_line_arc[0] = 0.0
	for i in range(1, pts.size()):
		_line_arc[i] = _line_arc[i - 1] + pts[i].distance_to(pts[i - 1])
	# Tube rings along the curve; the ring's frame is carried along
	# (parallel transport), so it never flips on a dive or a loop.
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var nrms := PackedVector3Array()
	var idx := PackedInt32Array()
	var nrm: Vector3 = Vector3.UP
	for i in range(pts.size()):
		var tan: Vector3 = (pts[mini(i + 1, pts.size() - 1)] - pts[maxi(i - 1, 0)]).normalized()
		nrm = (nrm - tan * nrm.dot(tan))
		if nrm.length() < 0.01:
			nrm = tan.cross(Vector3.RIGHT)
		nrm = nrm.normalized()
		var bin: Vector3 = tan.cross(nrm)
		var c: Vector3 = to_local(pts[i])
		for k in range(LINE_SIDES):
			var a: float = TAU * k / LINE_SIDES
			verts.append(c)
			nrms.append(nrm * cos(a) + bin * sin(a))
			uvs.append(Vector2(_line_arc[i], 0.0))
		if i > 0:
			var r0: int = (i - 1) * LINE_SIDES
			var r1: int = i * LINE_SIDES
			for k in range(LINE_SIDES):
				var k2: int = (k + 1) % LINE_SIDES
				idx.append_array([r0 + k, r1 + k, r1 + k2, r0 + k, r1 + k2, r0 + k2])
	var arr: Array = []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_TEX_UV] = uvs
	arr[Mesh.ARRAY_NORMAL] = nrms
	arr[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	# Every ring sits on its centre point: the visible tube is wider than
	# the mesh bounds, so grow them or it gets culled at the screen edge.
	mesh.custom_aabb = mesh.get_aabb().grow(5.0)
	_line = MeshInstance3D.new()
	_line.name = "RacingLine"
	_line.mesh = mesh
	_line.material_override = _line_mat()
	_line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_line.set_meta("keep_material", true)
	_line.set_meta("dynamic", true) # its cut moves: keep it out of the shadow capture
	add_child(_line)
	set_line_colour(Settings.race_line_colour())
	_update_line()

func set_line_colour(c: Color) -> void:
	if _line:
		(_line.material_override as ShaderMaterial).set_shader_parameter("colour", c)

## Show only the way ahead: from the drone's nearest point on the stretch
## being flown through the next gate, and on through more gates (max
## LINE_GATES) while it is shorter than Settings.race_line_target(), fading
## out over LINE_FADE metres past the last one - parts of the lap further
## on (crossings, overlaps) stay hidden. Heading for START (waiting, after
## a reset) it is the same rule: START and the gates after it.
const LINE_FADE: float = 6.0
const LINE_GATES: int = 3
var _line_last: int = 0 # the last gate the line reaches (for the self-test)
func _update_line() -> void:
	if _line == null or _line_seg.is_empty() or drone == null:
		return
	var n: int = _gates.size()
	var s: int = (_next - 1 + n) % n # the stretch being flown: gate s -> _next
	var a: int = _line_seg[s]
	var b: int = _line_seg[s + 1]
	var pos: Vector3 = drone.global_position
	var best: int = a
	var bd: float = INF
	for i in range(a, b + 1):
		var d: float = _line_pts[i].distance_squared_to(pos)
		if d < bd:
			bd = d
			best = i
	var lap: float = _line_arc[_line_arc.size() - 1]
	var cut: float = _line_arc[best]
	var span: float = _line_arc[b] - cut # to the next gate, always
	var target: float = Settings.race_line_target()
	var g: int = _next
	for k in range(1, mini(LINE_GATES, n)):
		if span >= target:
			break
		g = (g + 1) % n
		span = fposmod(_line_arc[_line_seg[g]] - cut, lap)
		if g == 0:
			span = lap - cut # START closes the lap (arc 0 = arc lap)
	_line_last = g
	var m := _line.material_override as ShaderMaterial
	m.set_shader_parameter("cut", cut)
	m.set_shader_parameter("span", span)
	m.set_shader_parameter("lap", lap)

## Half see-through, self-lit (reads in every camera look), both faces
## (the winding of a tube seen from inside a loop doesn't matter), fading
## out within a few metres of the camera so it never fills the view, in
## over a metre ahead of the cut and out over LINE_FADE past its end. The
## vertices are the line's centre points with the ring direction as
## NORMAL: the radius is LINE_R, but never under ~1.2 pixels, so a far stretch stays one unbroken line
## instead of breaking into dashes.
static func _line_mat() -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
uniform vec3 colour : source_color = vec3(1.0, 0.5, 0.0);
uniform float cut = 0.0;
uniform float span = 1e9;
uniform float lap = 1e9;
uniform float fade = %s;
uniform float radius = %s;
void vertex() {
	float d = length((MODELVIEW_MATRIX * vec4(VERTEX, 1.0)).xyz);
	float px = 2.0 / (PROJECTION_MATRIX[1][1] * VIEWPORT_SIZE.y); // metres per pixel at 1 m
	VERTEX += NORMAL * max(radius, d * px * 1.2);
}
void fragment() {
	float r = UV.x - cut; // distance ahead of the drone, round the lap
	if (r < 0.0) r += lap;
	float ahead = smoothstep(0.0, 1.0, r) * (1.0 - smoothstep(span, span + fade, r));
	ALBEDO = colour;
	ALPHA = 0.55 * smoothstep(1.5, 5.0, -VERTEX.z) * ahead;
}
""" % [LINE_FADE, LINE_R]
	var m := ShaderMaterial.new()
	m.shader = sh
	return m

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
	cfg.set_value(_section(), _key() + "_pos", _ghost_pos)
	cfg.set_value(_section(), _key() + "_q", _ghost_rot)
	if cfg.has_section_key(_section(), _key() + "_rot"):
		cfg.erase_section_key(_section(), _key() + "_rot")
	_save_cfg(cfg, GHOST_PATH)

## (Ghosts saved before 2026-10-04 kept Euler angles at 20 Hz under
## "_rot" - converted on load.)
func _load_ghost() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(GHOST_PATH) != OK:
		return
	var sec: String = _section()
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

## Records are kept per map, track and drone (the drone is the key in
## the section), under the track's stable id - not its place in the list,
## so reordering the tracks keeps every record with its track:
## "race_field#club_loop", and "race_field#club_loop@3" once that
## layout has been redesigned twice (its "rev") - a fresh record table
## instead of comparing against laps flown on the old layout.
static func section(p_map_id: String, p_track: int = 1) -> String:
	var r: int = 1
	var id: String = str(p_track)
	var tl: Array = track_list(p_map_id)
	if p_track >= 1 and p_track <= tl.size():
		r = int(tl[p_track - 1].get("rev", 1))
		id = str(tl[p_track - 1].get("id", id))
	return "%s#%s" % [p_map_id, id] + ("@%d" % r if r > 1 else "")

func _section() -> String:
	return section(map_id, track)

## A race map's tracks ({"name", "level", "calls", "rev"?}), read from its
## scene's script without adding it to the tree (cached).
static var _track_lists: Dictionary = {}
static func track_list(p_map_id: String) -> Array:
	if _track_lists.has(p_map_id):
		return _track_lists[p_map_id]
	var out: Array = []
	for m in MapCatalog.MAPS:
		if m.id == p_map_id and m.get("race", false):
			var n: Node = (load(m.scene) as PackedScene).instantiate()
			if n.has_method("tracks"):
				out = n.tracks()
			n.free()
	_track_lists[p_map_id] = out
	return out

# --- saves: version 2 (tracks) -----------------------------------------------
#
# Before the tracks (0.10.x) the records were kept per map ("race_field",
# or "race_field@2" after a redesign - MapCatalog "track") and drone, a
# race was 3 laps. Version 2: per map + track number ("race_field#1").
# Version 3: per map + track id ("race_field#club_loop" - the tracks were
# reordered by difficulty). Once, at the first race-map load:
# - 1 -> 2: best laps, their splits and the lap ghosts of the current
#   layout move to track 1 (the same course); the boards (3-lap race
#   totals, not comparable) and stale layouts are dropped. The file is
#   copied to <file>.bak first.
# - 2 -> 3: each "map#n" moves to the id of the track that was number n
#   (V2_IDS); tracks redesigned since ("") start fresh. A version-2 file is
#   copied to <file>.v2.bak first (.bak keeps the version-1 originals).
const SAVE_VERSION: int = 3
static var STATS_PATH: String = save_path("race_stats.cfg")
## Which track each version-2 number was, per map ("" = redesigned since).
const V2_IDS: Dictionary = {
	"race_field": ["club_loop", "meadow_sprint", "bale_run", "", "", ""],
	"race_arena": ["league_night"],
	"office": ["after_hours"],
}

static var _migrated: bool = false
static func migrate_saves() -> void:
	if _migrated:
		return
	_migrated = true
	for path: String in [RECORDS_PATH, GHOST_PATH, BOARD_PATH, STATS_PATH]:
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			continue
		var ver: int = _save_version(cfg)
		if ver >= SAVE_VERSION:
			continue
		if ver < 2:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
			var v2 := ConfigFile.new()
			if path != BOARD_PATH:
				for m in MapCatalog.MAPS:
					if not m.get("race", false):
						continue
					var old: String = "%s@%d" % [m.id, int(m.track)] if int(m.get("track", 1)) > 1 else m.id
					if cfg.has_section(old):
						for k in cfg.get_section_keys(old):
							v2.set_value("%s#1" % m.id, k, cfg.get_value(old, k))
			cfg = v2
		else:
			DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".v2.bak"))
		var out := ConfigFile.new()
		for sec: String in cfg.get_sections():
			var parts: PackedStringArray = sec.split("#")
			if parts.size() != 2 or not parts[1].is_valid_int() or not V2_IDS.has(parts[0]):
				continue
			var ids: Array = V2_IDS[parts[0]]
			var n: int = int(parts[1])
			if n < 1 or n > ids.size() or ids[n - 1] == "":
				continue
			for k in cfg.get_section_keys(sec):
				out.set_value("%s#%s" % [parts[0], ids[n - 1]], k, cfg.get_value(sec, k))
		out.set_value("meta", "version", SAVE_VERSION)
		out.save(path)

## A save file's version: its mark, or - for files written without one
## (the stats file, records first saved after the migration ran) - read
## from its sections: "map#1" is version 2, "map#club_loop" version 3.
static func _save_version(cfg: ConfigFile) -> int:
	if cfg.has_section_key("meta", "version"):
		return int(cfg.get_value("meta", "version"))
	var ver: int = 1
	for sec: String in cfg.get_sections():
		var parts: PackedStringArray = sec.split("#")
		if parts.size() == 2:
			if not parts[1].split("@")[0].is_valid_int():
				return SAVE_VERSION
			ver = 2
	return ver

## Saves a race file with the current version mark.
static func _save_cfg(cfg: ConfigFile, path: String) -> void:
	cfg.set_value("meta", "version", SAVE_VERSION)
	cfg.save(path)

## Races started / finished per drone on a track: {drone: [started, finished]}.
static func stats(p_map_id: String, p_track: int = 1) -> Dictionary:
	migrate_saves()
	var out := {}
	var cfg := ConfigFile.new()
	var sec: String = section(p_map_id, p_track)
	if cfg.load(STATS_PATH) != OK or not cfg.has_section(sec):
		return out
	for k in cfg.get_section_keys(sec):
		out[k] = cfg.get_value(sec, k)
	return out

## i = 0: a race started, 1: a race finished.
func _count_stat(i: int) -> void:
	var cfg := ConfigFile.new()
	cfg.load(STATS_PATH)
	var v: Array = cfg.get_value(_section(), _key(), [0, 0])
	v[i] = int(v[i]) + 1
	cfg.set_value(_section(), _key(), v)
	_save_cfg(cfg, STATS_PATH)

func _key() -> String:
	return Settings.selected_drone

func _load_best() -> float:
	var cfg := ConfigFile.new()
	if cfg.load(RECORDS_PATH) != OK:
		return -1.0
	_best_splits = cfg.get_value(_section(), _key() + "_splits", [])
	return cfg.get_value(_section(), _key(), -1.0)

func _save_best() -> void:
	var cfg := ConfigFile.new()
	cfg.load(RECORDS_PATH)
	cfg.set_value(_section(), _key(), _best)
	cfg.set_value(_section(), _key() + "_splits", _splits.duplicate())
	cfg.set_value(_section(), _key() + "_date", Time.get_date_string_from_system())
	_save_cfg(cfg, RECORDS_PATH)

## Personal bests of a map for the menu: {drone id: [seconds, date]}.
static func records(p_map_id: String, p_track: int = 1) -> Dictionary:
	migrate_saves()
	var out := {}
	var cfg := ConfigFile.new()
	var sec: String = section(p_map_id, p_track)
	if cfg.load(RECORDS_PATH) != OK or not cfg.has_section(sec):
		return out
	for k in cfg.get_section_keys(sec):
		if not k.ends_with("_date") and not k.ends_with("_splits"):
			out[k] = [float(cfg.get_value(sec, k)), str(cfg.get_value(sec, k + "_date", ""))]
	return out
