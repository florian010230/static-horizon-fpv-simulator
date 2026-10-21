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
	geo.add_material("gate_closed", Geo.flat_mat(Color(0.86, 0.13, 0.1), 0.7))
	# LED gates (Drone Racing League style): self-lit, bloom on High.
	for led in [["led_blue", Color(0.2, 0.55, 1.0)], ["led_orange", Color(1.0, 0.45, 0.1)], ["led_green", Color(0.2, 1.0, 0.4)], ["led_pink", Color(1.0, 0.25, 0.7)], ["led_white", Color(0.92, 0.96, 1.0)]]:
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
## `bottom` false: the frame sits on another one (a stack) - that one's top
## panel is this one's bottom, drawn once (twice, they flickered).
func _frame(geo: Geo, xf: Transform3D, w: float, h: float, mat: String, bottom: bool = true) -> void:
	var p: float = PANEL
	var d: float = 0.09
	var led: bool = mat.begins_with("led_")
	# (LED gates - Race Arena's - take the LED race style too, in their own colour.)
	var st: int = STYLE if (w > 1.0 and (not led or STYLE == 2)) else 0
	var pm: String = mat if not led else "gate_dark"
	if st == 2:
		pm = "gate_dark"
	elif st == 3:
		pm = "gate_trim"
	var pal: Dictionary = _pal_for(mat)
	for side in [[Vector3(0, h * 0.5 + p * 0.5, 0), Vector3(w + 2 * p, p, d)], [Vector3(0, -h * 0.5 - p * 0.5, 0), Vector3(w + 2 * p, p, d)],
			[Vector3(-w * 0.5 - p * 0.5, 0, 0), Vector3(p, h, d)], [Vector3(w * 0.5 + p * 0.5, 0, 0), Vector3(p, h, d)]]:
		if not bottom and side[0].y < -h * 0.5:
			continue
		geo.box_xf(xf * Transform3D(Basis(), side[0]), side[1], pm)
		if st > 0:
			continue # (flat panels: the printed skin goes on them)
		# The pillow: a slimmer, thicker strip down the panel's middle.
		var inner: Vector3 = side[1] * Vector3(0.82 if side[1].x > side[1].y else 0.55, 0.55 if side[1].x > side[1].y else 0.82, 1.6)
		geo.box_xf(xf * Transform3D(Basis(), side[0]), inner, pm, false, false)
	# Piping (or, on LED gates, the light strip) round the opening.
	var t: float = 0.035
	var pipe: String = "gate_trim" if not led else mat
	if st == 2:
		pipe = pal.led
	if st == 3:
		geo.tint = pal.main
	# (5 mm into the opening, so its inner face isn't flush with the panels')
	var ti: float = t + 0.01
	for e in [[Vector3(0, h * 0.5 + t * 0.5 - 0.005, 0), Vector3(w + 2 * t, ti, d * 1.25)], [Vector3(0, -h * 0.5 - t * 0.5 + 0.005, 0), Vector3(w + 2 * t, ti, d * 1.25)],
			[Vector3(-w * 0.5 - t * 0.5 + 0.005, 0, 0), Vector3(ti, h - 0.01, d * 1.25)], [Vector3(w * 0.5 + t * 0.5 - 0.005, 0, 0), Vector3(ti, h - 0.01, d * 1.25)]]:
		geo.box_xf(xf * Transform3D(Basis(), e[0]), e[1], pipe, false, false)
	geo.tint = Color.WHITE
	# Outer PVC frame.
	for e in [[Vector3(0, h * 0.5 + p, 0), Vector3(w + 2 * p + 0.05, 0.05, 0.05)], [Vector3(0, -h * 0.5 - p, 0), Vector3(w + 2 * p + 0.05, 0.05, 0.05)],
			[Vector3(-w * 0.5 - p, 0, 0), Vector3(0.05, h + 2 * p, 0.05)], [Vector3(w * 0.5 + p, 0, 0), Vector3(0.05, h + 2 * p, 0.05)]]:
		if not bottom and e[0].y < -h * 0.5:
			continue
		geo.box_xf(xf * Transform3D(Basis(), e[0]), e[1], "gate_pole", false, false)
	if st > 0:
		_skip_below = -INF if bottom else -h * 0.5 - 0.001
		_gate_skin(geo, xf, w, h, pal, st)
		_skip_below = -INF
	elif not led and w > 1.0:
		if OS.get_environment("SH_GATE_BRAND") != "0": # (the brand on the top panel; approved 2026-10-20, SH_GATE_BRAND=0 shows the plain bar)
			_brand(geo, xf * Transform3D(Basis(), Vector3(0, h * 0.5 + p * 0.5, 0)), w + 2 * p, p, d * 1.7)
		else:
			geo.box_xf(xf * Transform3D(Basis(), Vector3(0, h * 0.5 + p * 0.5, 0)), Vector3(w * 0.45, p * 0.6, d * 1.7), "gate_dark", false, false)

## The Static Horizon FPV banner on a gate's top panel (centre `xf`,
## panel `pw` wide, `ph` high, `th` thick): a dark band, on each face the
## round horizon mark (white ring, blue sky over orange ground, the white
## horizon bar - as icon.png) and the name beside it.
const BRAND_BLUE := Color(0.13, 0.45, 0.88)
const BRAND_ORANGE := Color(0.91, 0.34, 0.11)
func _brand(geo: Geo, xf: Transform3D, pw: float, ph: float, th: float) -> void:
	var bw: float = pw * 0.88
	var bh: float = ph * 0.78
	geo.box_xf(xf, Vector3(bw, bh, th), "gate_dark", false, false)
	var r: float = bh * 0.42
	for side in [1.0, -1.0]:
		var face := xf * Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0, 0, side * th * 0.5))
		var n: Vector3 = face.basis.z.normalized()
		var lc: Vector3 = face * Vector3(-bw * 0.5 + r + bh * 0.12, 0, 0)
		geo.tint = Color(0.97, 0.97, 0.97)
		geo.fan(lc + n * 0.004, n, r, 0.0, TAU, "gate_trim", 20)
		geo.tint = BRAND_BLUE
		geo.fan(lc + n * 0.008, n, r * 0.84, 0.0, PI, "gate_trim", 12)
		geo.tint = BRAND_ORANGE
		geo.fan(lc + n * 0.008, n, r * 0.84, PI, TAU, "gate_trim", 12)
		geo.tint = Color(0.97, 0.97, 0.97)
		geo.box_xf(Transform3D(face.basis, lc + n * 0.012), Vector3(r * 1.7, r * 0.16, 0.004), "gate_trim", false, false)
		geo.tint = Color.WHITE
		# The name in the rest of the band, as big as fits.
		var x0: float = -bw * 0.5 + 2.0 * r + bh * 0.24
		var x1: float = bw * 0.5 - bh * 0.12
		StreetKit._label(geo, "STATIC HORIZON FPV", face * Transform3D(Basis(), Vector3((x0 + x1) * 0.5, 0, 0.006)), bh * 0.62 / 64.0 * 1.3, Color(0.97, 0.97, 0.97), x1 - x0)

# --- gate styles (2026-10-14) ------------------------------------------------
# 1 Chevron, 2 LED race, 3 Pro banner. Gates and the turn flags share one
# design per style (_pal gives the colours of a gate colour). Everything is
# printed onto the flat panels as thin plates a few mm apart (LZ), in a few
# shared flat materials tinted per vertex.
# The user's pick: Pro banner outdoors, LED race indoors, Chevron in the
# Office (STYLE_BY_ID); otherwise only on request (SH_GATE_STYLE=1|2|3 forces one, 0 the plain old gates).
static var STYLE: int = 3
## An LED gate's colour family (its palette).
const LED_GATE: Dictionary = {"led_blue": "gate_a", "led_orange": "gate_b"}
const INDOOR_IDS: Array = ["garage"]
## Maps with their own pick: the Office whoop gates in Chevron (user, 2026-10-14).
const STYLE_BY_ID: Dictionary = {"office": 1} # (indoor, but not marked "indoor" in MapCatalog)

## Picks the style for the map about to be built (BuiltMap, before build()).
static func pick_style(map: Node) -> void:
	if OS.has_environment("SH_GATE_STYLE"):
		STYLE = int(OS.get_environment("SH_GATE_STYLE"))
		return
	var m: Dictionary = MapCatalog.for_scene(map.scene_file_path)
	if STYLE_BY_ID.has(m.get("id", "")):
		STYLE = STYLE_BY_ID[m.id]
		return
	STYLE = 2 if m.get("indoor", false) or INDOOR_IDS.has(m.get("id", "")) else 3
const LZ: Array = [0.005, 0.01, 0.015, 0.02] # (5 mm apart: 3.5 mm flickered)
const TZ: float = 0.0185
const INK_DARK := Color(0.06, 0.07, 0.09)
const INK_LIGHT := Color(0.97, 0.97, 0.97)

## A gate material's palette; an LED gate keeps its own light colour.
static func _pal_for(mat: String) -> Dictionary:
	var p: Dictionary = _pal(LED_GATE.get(mat, mat)).duplicate()
	if mat.begins_with("led_"):
		p.led = mat
	return p

static func _pal(mat: String) -> Dictionary:
	if mat == "gate_b":
		return {"main": BRAND_ORANGE, "c1": Color(0.97, 0.97, 0.97), "c2": Color(0.05, 0.05, 0.06), "led": "led_orange", "led2": "led_white"}
	if mat == "gate_dark":
		return {"main": Color(0.12, 0.12, 0.13), "c1": Color(0.97, 0.97, 0.97), "c2": Color(0.9, 0.1, 0.1), "led": "led_green", "led2": "led_white"}
	return {"main": BRAND_BLUE, "c1": Color(0.97, 0.97, 0.97), "c2": Color(1.0, 0.82, 0.08), "led": "led_blue", "led2": "led_white"}

## A flat plate (points in `face`'s XY plane, `z` out of it).
## Printed parts lying wholly below this (face y) are left out: the bottom
## panel of a stacked frame (_frame's `bottom`).
static var _skip_below: float = -INF

static func _pl(geo: Geo, face: Transform3D, z: float, pts: Array, col: Color, mat: String = "gate_trim") -> void:
	if _skip_below > -INF and pts.all(func(q: Vector2) -> bool: return q.y <= _skip_below):
		return
	geo.tint = col if not mat.begins_with("led_") else Color.WHITE
	geo.plate(face * Transform3D(Basis(), Vector3(0, 0, z)), pts, mat)
	geo.tint = Color.WHITE

static func _rc(geo: Geo, face: Transform3D, z: float, x0: float, y0: float, x1: float, y1: float, col: Color, mat: String = "gate_trim") -> void:
	_pl(geo, face, z, [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)], col, mat)

## Convex polygon `subj` cut to the convex, counter-clockwise `clip`.
static func _clip(subj: Array, clip: Array) -> Array:
	var out: Array = subj
	for i in range(clip.size()):
		var a: Vector2 = clip[i]
		var b: Vector2 = clip[(i + 1) % clip.size()]
		var inp: Array = out
		out = []
		if inp.is_empty():
			break
		for j in range(inp.size()):
			var c: Vector2 = inp[j]
			var d: Vector2 = inp[(j + 1) % inp.size()]
			var cin: float = (b - a).cross(c - a)
			var din: float = (b - a).cross(d - a)
			if cin >= 0.0:
				out.append(c)
			if (cin >= 0.0) != (din >= 0.0):
				out.append(c + (d - c) * (cin / (cin - din)))
	return out

static func _rect_pts(x0: float, y0: float, x1: float, y1: float) -> Array:
	return [Vector2(x0, y0), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]

## A diagonal band (sloped by `m`, `th` thick measured up) over x0..x1,
## starting at height c0 at x0, cut to the rectangle `r` (x0,y0,x1,y1).
static func _band(geo: Geo, face: Transform3D, z: float, x0: float, x1: float, c0: float, th: float, m: float, r: Array, col: Color, mat: String = "gate_trim") -> void:
	var dx: float = x1 - x0
	var poly: Array = [Vector2(x0, c0), Vector2(x1, c0 + m * dx), Vector2(x1, c0 + m * dx + th), Vector2(x0, c0 + th)]
	var cut: Array = _clip(poly, _rect_pts(r[0], r[1], r[2], r[3]))
	if cut.size() >= 3:
		_pl(geo, face, z, cut, col, mat)

static func _checker(geo: Geo, face: Transform3D, z: float, x0: float, y0: float, x1: float, y1: float, nx: int, ny: int, col: Color) -> void:
	for i in range(nx):
		for j in range(ny):
			if (i + j) % 2 == 0:
				_rc(geo, face, z, lerpf(x0, x1, float(i) / nx), lerpf(y0, y1, float(j) / ny), lerpf(x0, x1, float(i + 1) / nx), lerpf(y0, y1, float(j + 1) / ny), col)

## Text with a thin outline: the same text four times, 3 mm behind and
## nudged 4 mm each way, in `edge` (readable on any colour).
## `subj` clipped to the convex `clip`, both made counter-clockwise first.
static func _ccw_clip(subj: Array, clip: Array) -> Array:
	var a: Array = subj.duplicate()
	var b: Array = clip.duplicate()
	if _area(a) < 0.0:
		a.reverse()
	if _area(b) < 0.0:
		b.reverse()
	return _clip(a, b)

static func _area(pts: Array) -> float:
	var sum: float = 0.0
	for i in range(pts.size()):
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % pts.size()]
		sum += p.cross(q)
	return sum * 0.5

static func _label_edged(geo: Geo, text: String, xf: Transform3D, px: float, col: Color, edge: Color, max_w: float) -> void:
	for o in [Vector3(0.004, 0, 0), Vector3(-0.004, 0, 0), Vector3(0, 0.004, 0), Vector3(0, -0.004, 0)]:
		StreetKit._label(geo, text, xf * Transform3D(Basis(), o + Vector3(0, 0, -0.003)), px, edge, max_w)
	StreetKit._label(geo, text, xf, px, col, max_w)

## The Static Horizon mark (white ring, blue sky over orange ground, the
## horizon bar - as icon.png) with an outline disc behind it. `ink` is
## the ring and bar, `edge` the outline.
static func _mark(geo: Geo, face: Transform3D, c: Vector2, r: float, ink: Color, edge: Color, z0: float = LZ[0]) -> void:
	var n: Vector3 = face.basis.z.normalized()
	geo.tint = edge
	geo.fan(face * Vector3(c.x, c.y, z0), n, r * 1.1, 0.0, TAU, "gate_trim", 20)
	geo.tint = ink
	geo.fan(face * Vector3(c.x, c.y, z0 + 0.0035), n, r, 0.0, TAU, "gate_trim", 20)
	geo.tint = BRAND_BLUE
	geo.fan(face * Vector3(c.x, c.y, z0 + 0.007), n, r * 0.84, 0.0, PI, "gate_trim", 12)
	geo.tint = BRAND_ORANGE
	geo.fan(face * Vector3(c.x, c.y, z0 + 0.007), n, r * 0.84, PI, TAU, "gate_trim", 12)
	geo.tint = Color.WHITE
	_rc(geo, face, z0 + 0.0105, c.x - r * 0.85, c.y - r * 0.07, c.x + r * 0.85, c.y + r * 0.07, ink)

## Mark + name across x0..x1 (face coordinates), centred on yc, `bh` high.
static func _brand_face(geo: Geo, face: Transform3D, x0: float, x1: float, yc: float, bh: float, ink: Color, edge: Color, scale: float = 1.0) -> void:
	var r: float = bh * 0.44
	_mark(geo, face, Vector2(x0 + r * 1.1, yc), r, ink, edge)
	var t0: float = x0 + 2.0 * r * 1.1 + bh * 0.22
	var t1: float = x1 - bh * 0.05
	var px: float = bh * 0.62 / 64.0 * 1.3 * scale
	_label_edged(geo, "STATIC HORIZON FPV", face * Transform3D(Basis(), Vector3((t0 + t1) * 0.5, yc, TZ)), px, ink, edge, t1 - t0)

func _gate_skin(geo: Geo, xf: Transform3D, w: float, h: float, pal: Dictionary, st: int) -> void:
	var p: float = PANEL
	var X: float = w * 0.5 + p
	var xa: float = w * 0.5 + 0.045 # side panel columns xa..xb
	var xb: float = X - 0.02
	var ty0: float = h * 0.5 + 0.045 # top panel ty0..ty1 (bottom one mirrored)
	var ty1: float = h * 0.5 + p - 0.02
	var main: Color = pal.main
	var c1: Color = pal.c1
	var c2: Color = pal.c2
	var led: String = pal.led
	var led2: String = pal.led2
	for side in [1.0, -1.0]:
		var face := xf * Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0, 0, side * 0.045))
		if st == 1: # Chevron
			for sg in [-1.0, 1.0]:
				var cx: float = sg * (xa + xb) * 0.5
				var hw: float = (xb - xa) * 0.5
				for k in range(7):
					var y0: float = -h * 0.5 + 0.05 + k * 0.19
					var col: Color = c1 if k % 2 == 0 else c2
					_pl(geo, face, LZ[0], [Vector2(cx - hw, y0), Vector2(cx, y0 + hw * 0.9), Vector2(cx, y0 + hw * 0.9 + 0.085), Vector2(cx - hw, y0 + 0.085)], col)
					_pl(geo, face, LZ[0], [Vector2(cx, y0 + hw * 0.9), Vector2(cx + hw, y0), Vector2(cx + hw, y0 + 0.085), Vector2(cx, y0 + hw * 0.9 + 0.085)], col)
			# Race lines along the top panel, the name between them.
			_rc(geo, face, LZ[0], -X + 0.02, ty1 - 0.016, X - 0.02, ty1, c2)
			_rc(geo, face, LZ[0], -X + 0.02, ty0, X - 0.02, ty0 + 0.016, c1)
			_brand_face(geo, face, -X + 0.07, X - 0.07, (ty0 + ty1) * 0.5, ty1 - ty0 - 0.05, INK_LIGHT, INK_DARK)
			# The checkered band along the bottom panel.
			_rc(geo, face, LZ[0], -X + 0.02, -ty1, X - 0.02, -ty0, c1)
			_checker(geo, face, LZ[1], -X + 0.02, -ty1, X - 0.02, -ty0, 16, 2, INK_DARK)
		elif st == 2: # LED race
			var o: float = 0.012
			_rc(geo, face, LZ[0], -X + o, h * 0.5 + p - o - 0.02, X - o, h * 0.5 + p - o, Color.WHITE, led2)
			_rc(geo, face, LZ[0], -X + o, -h * 0.5 - p + o, X - o, -h * 0.5 - p + o + 0.03, Color.WHITE, led2)
			for sg in [-1.0, 1.0]:
				_rc(geo, face, LZ[0], sg * X - (o + 0.02 if sg > 0 else -o), -h * 0.5 - p + o + 0.02, sg * X - (o if sg > 0 else -o - 0.02), h * 0.5 + p - o - 0.03, Color.WHITE, led2)
				# Thin race lines slanting up the side panels.
				var r: Array = [minf(sg * xa, sg * xb), -h * 0.5, maxf(sg * xa, sg * xb), h * 0.5]
				for k in range(6):
					var x0: float = sg * xa
					var x1: float = sg * xb
					var poly: Array = [Vector2(x0, -h * 0.5 - 0.55 + k * 0.5), Vector2(x1, -h * 0.5 - 0.55 + k * 0.5 + 2.4 * (xb - xa) * sg * sg), Vector2(x1, -h * 0.5 - 0.55 + k * 0.5 + 2.4 * (xb - xa) + 0.05), Vector2(x0, -h * 0.5 - 0.55 + k * 0.5 + 0.03)]
					if sg < 0.0:
						poly.reverse()
					var cut: Array = _clip(poly, _rect_pts(r[0], r[1], r[2], r[3]))
					if cut.size() >= 3:
						_pl(geo, face, LZ[1], cut, Color.WHITE, led)
			# Running lights along the bottom panel.
			for k in range(9):
				var cxk: float = lerpf(-X + 0.2, X - 0.2, k / 8.0)
				_rc(geo, face, LZ[0], cxk - 0.07, -(ty0 + ty1) * 0.5 - 0.016, cxk + 0.07, -(ty0 + ty1) * 0.5 + 0.016, Color.WHITE, led if k % 2 == 0 else led2)
			_brand_face(geo, face, -X + 0.07, X - 0.07, (ty0 + ty1) * 0.5, ty1 - ty0 - 0.06, INK_LIGHT, INK_DARK)
		else: # Pro banner
			for sg in [-1.0, 1.0]:
				var r: Array = [minf(sg * xa, sg * xb), -h * 0.5, maxf(sg * xa, sg * xb), h * 0.5]
				for k in range(-1, 3):
					var base: float = -h * 0.5 - 0.7 + k * 0.9
					var m: float = 3.0
					# (a left column mirrors the right one)
					for e in [[0.0, 0.42, main], [0.5, 0.06, c2]]:
						var dy: float = base + e[0]
						var poly: Array = [Vector2(sg * xa, dy), Vector2(sg * xb, dy + m * (xb - xa)), Vector2(sg * xb, dy + m * (xb - xa) + e[1]), Vector2(sg * xa, dy + e[1])]
						if sg < 0.0:
							poly = [Vector2(sg * xa, dy), Vector2(sg * xb, dy + m * (xb - xa)), Vector2(sg * xb, dy + m * (xb - xa) + e[1]), Vector2(sg * xa, dy + e[1])]
						var cut: Array = _clip(poly if sg > 0.0 else [poly[3], poly[2], poly[1], poly[0]], _rect_pts(r[0], r[1], r[2], r[3]))
						if cut.size() >= 3:
							_pl(geo, face, LZ[0], cut, e[2])
				# Checkered corner pieces.
				_checker(geo, face, LZ[0], minf(sg * xa, sg * xb), ty0, maxf(sg * xa, sg * xb), ty1, 4, 4, INK_DARK)
				_checker(geo, face, LZ[0], minf(sg * xa, sg * xb), -ty1, maxf(sg * xa, sg * xb), -ty0, 4, 4, INK_DARK)
			# Name big across the top panel, a swoosh along the bottom one.
			_brand_face(geo, face, -xa + 0.03, xa - 0.03, (ty0 + ty1) * 0.5, ty1 - ty0, INK_DARK, INK_LIGHT, 1.1)
			var cy: float = -(ty0 + ty1) * 0.5
			_rc(geo, face, LZ[0], -xa + 0.03, cy - 0.055, xa - 0.03, cy + 0.01, main)
			_rc(geo, face, LZ[0], -xa + 0.03, cy + 0.04, xa - 0.03, cy + 0.058, c2)
			_rc(geo, face, LZ[0], -xa + 0.03, cy - 0.085, xa - 0.03, cy - 0.07, c2)

## The sail of a turn flag in the gate style (visual only, like the
## banner it replaces): a tall squared-off foot tapering to the tip along
## the pole at `pos`, flying toward `xdir` (+1/-1, local X after `yaw`),
## `k` the flag's scale. Same colours, stripes and logo as that style's gates.
func _style_sail(geo: Geo, pos: Vector3, yaw: float, xdir: float, k: float, mat: String) -> void:
	var pal: Dictionary = _pal(mat)
	var F := Transform3D(Basis(Vector3.UP, yaw), pos)
	var s: float = xdir
	# A feather flag (2026-10-14, user's reference photo): tall and narrow
	# (~1:4.3), a straight edge on the pole (the sleeve), the top curving
	# over from the pole top like a sail, the outer edge nearly straight,
	# the foot cut on a slant - lowest at the pole, rising to the tip.
	var W: float = 0.62 * k
	var x0: float = 0.03 * k * s
	var outline: Array = [Vector2(x0, 0.78 * k)]
	var arc_n: int = 8
	for i in range(arc_n + 1):
		var a: float = PI * 0.5 * i / arc_n
		outline.append(Vector2(x0 + s * W * sin(a), (3.0 + 0.62 * cos(a)) * k))
	for i in range(1, 6):
		var t: float = float(i) / 6.0
		# (a slight outward bulge on the outer edge)
		outline.append(Vector2(x0 + s * W * (1.0 - 0.07 * t + 0.05 * sin(PI * t)), lerpf(3.0, 1.05, t) * k))
	outline.append(Vector2(x0 + s * W * 0.93, 1.05 * k))
	outline.reverse() # (pole bottom -> foot tip -> up the outer edge -> over the top)
	outline.push_front(outline.pop_back())
	var slices: Array = []
	var n: int = 18
	for i in range(n):
		var ya: float = (0.7 + 3.0 * i / n) * k
		var yb: float = (0.7 + 3.0 * (i + 1) / n) * k
		var band: Array = [Vector2(x0, ya), Vector2(x0 + s * 1.2 * k, ya), Vector2(x0 + s * 1.2 * k, yb), Vector2(x0, yb)]
		slices.append(_ccw_clip(band, outline))
	slices = slices.filter(func(q: Array) -> bool: return q.size() >= 3)
	var base_col: Color = pal.main
	if STYLE == 2:
		base_col = Color(0.1, 0.1, 0.11)
	elif STYLE == 3:
		base_col = Color(0.95, 0.95, 0.93)
	var ink: Color = INK_DARK if STYLE == 3 else INK_LIGHT
	var edge: Color = INK_LIGHT if STYLE == 3 else INK_DARK
	for side in [1.0, -1.0]:
		var face := F * Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0, 0, side * 0.012 * k))
		# (face coordinates: x is mirrored on the back)
		var fx := func(pt: Vector2) -> Vector2: return Vector2(pt.x * side, pt.y)
		for q: Array in slices:
			_pl(geo, face, LZ[0] * 0.6, q.map(fx), base_col)
		var bands: Array = [] # [colour, material, polygon]
		if STYLE == 1:
			for j in range(-2, 12):
				var ya: float = (0.5 + j * 0.3) * k
				bands.append([pal.c1 if j % 2 == 0 else pal.c2, "gate_trim", [Vector2(0, ya), Vector2(s * 0.8 * k, ya + 0.9 * k), Vector2(s * 0.8 * k, ya + 1.03 * k), Vector2(0, ya + 0.13 * k)]])
		elif STYLE == 2:
			for j in range(4):
				var ya: float = (0.9 + j * 0.55) * k
				bands.append([Color.WHITE, pal.led, [Vector2(0, ya), Vector2(s * 0.8 * k, ya + 0.9 * k), Vector2(s * 0.8 * k, ya + 0.95 * k), Vector2(0, ya + 0.05 * k)]])
		else:
			bands.append([pal.main, "gate_trim", [Vector2(0, 1.7 * k), Vector2(s * 0.8 * k, 2.6 * k), Vector2(s * 0.8 * k, 3.2 * k), Vector2(0, 2.3 * k)]])
			bands.append([pal.c2, "gate_trim", [Vector2(0, 1.2 * k), Vector2(s * 0.8 * k, 2.1 * k), Vector2(s * 0.8 * k, 2.16 * k), Vector2(0, 1.26 * k)]])
		if STYLE != 2: # a checkered band low on the sail, like the gates'
			for ci in range(10):
				for cr in range(2):
					var cx: float = ci * 0.075 * k
					var cy: float = (1.22 + cr * 0.075) * k
					var blk: bool = (ci + cr) % 2 == 0
					bands.append([INK_DARK if blk else INK_LIGHT, "gate_trim", [Vector2(s * cx, cy), Vector2(s * (cx + 0.075 * k), cy), Vector2(s * (cx + 0.075 * k), cy + 0.075 * k), Vector2(s * cx, cy + 0.075 * k)]])
		for q: Array in slices:
			var cc: Array = q.map(fx)
			if (cc[1] - cc[0]).cross(cc[2] - cc[0]) < 0.0:
				cc.reverse()
			for b: Array in bands:
				var poly: Array = (b[2] as Array).map(fx)
				if (poly[1] - poly[0]).cross(poly[2] - poly[0]) < 0.0:
					poly.reverse()
				var cut: Array = _clip(poly, cc)
				if cut.size() >= 3:
					_pl(geo, face, LZ[1], cut, b[0], b[1])
		if STYLE == 2: # a lit edge round the sail, off the pole
			for i in range(1, outline.size() - 1):
				var e0: Vector2 = outline[i]
				var e1: Vector2 = outline[i + 1]
				var inw: Vector2 = Vector2(-s * 0.04 * k, 0)
				var lit: Array = [e0, e1, e1 + inw, e0 + inw].map(fx)
				if (lit[1] - lit[0]).cross(lit[2] - lit[0]) < 0.0:
					lit.reverse()
				_pl(geo, face, LZ[1], lit, Color.WHITE, pal.led2)
		# The sleeve on the pole.
		var sl: Array = [Vector2(x0, 0.78 * k), Vector2(x0 + s * 0.05 * k, 0.79 * k), Vector2(x0 + s * 0.05 * k, 3.6 * k), Vector2(x0, 3.62 * k)].map(fx)
		if (sl[1] - sl[0]).cross(sl[2] - sl[0]) < 0.0:
			sl.reverse()
		_pl(geo, face, LZ[1], sl, edge)
		if k >= 0.6: # (the little indoor flags carry colours only)
			_mark(geo, face, Vector2((x0 + s * 0.26 * k) * side, 1.75 * k), 0.13 * k, ink, edge, LZ[2])
			var lab := face * Transform3D(Basis(Vector3.BACK, PI * 0.5), Vector3(side * (x0 + s * 0.3 * k), 2.75 * k, TZ + 0.004))
			_label_edged(geo, "STATIC HORIZON FPV", lab, 0.0022 * k, ink, edge, 1.0 * k)

func _register(xf: Transform3D, w: float, h: float) -> void:
	_gates.append({"xf": xf, "w": w, "h": h})
	# Kept on the node too: a map loaded from the map cache gets this node
	# back without its script variables (see _ready).
	set_meta("gates", _gates)

## A racing-line waypoint after the last registered gate.
func _add_via(p: Vector3) -> void:
	var g: Dictionary = _gates[_gates.size() - 1]
	g["via"] = (g.get("via", []) as Array) + [p]

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
		_frame(geo, xf, GATE, GATE, mat if i % 2 == 0 else alt, i == 0)
		if i == through:
			_register(xf, GATE, GATE)
			_direction(geo, xf, GATE, GATE, 0.0625, 0.07)
		else:
			# Not this one: a red tape cross over the opening ("closed").
			for r in [PI * 0.25, -PI * 0.25]:
				geo.box_xf(xf * Transform3D(Basis(Vector3(0, 0, 1), r), Vector3.ZERO), Vector3(GATE * 1.38, 0.07, 0.02), "gate_closed", false)
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
## `size` < 1 m: a whoop ladder (thin frames like gate_sized, bottom
## opening 0.3 m up; ~0.9 m gaps fit under an office's 3 m ceiling).
func ladder(geo: Geo, pos: Vector3, yaw: float, gap: float = 3.5, mat: String = "gate_b", size: float = GATE) -> void:
	var basis := Basis(Vector3.UP, yaw)
	if size < 1.0:
		var bar: float = 0.05
		for i in [2, 1, 0]:
			gate_sized(geo, pos, yaw if i != 1 else yaw + PI, size, size, bar, 0.3 + i * gap, mat, false)
		var top_w: float = 0.3 + 2 * gap + size + 2 * bar
		for sx in [-1.0, 1.0]:
			var leg_w: Vector3 = pos + basis * Vector3(sx * (size * 0.5 + bar * 1.5), 0, 0)
			geo.box(leg_w + Vector3(0, top_w * 0.5, 0), Vector3(bar, top_w, bar), "gate_pole", yaw)
		_feet(geo, pos, basis, size * 0.5 + bar * 1.5)
		return
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
func gate_sized(geo: Geo, pos: Vector3, yaw: float, w: float, h: float, bar: float, lift: float = 0.0, mat: String = "gate_a", pole: bool = true) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var xf := Transform3D(basis, pos + Vector3(0, lift + bar + h * 0.5, 0))
	var d: float = bar * 0.5
	# Styled (2026-10-14, user: "cleaner, fit the design to the small frame"):
	# a plain frame, the design printed flat on its faces with clean margins,
	# the pass-direction ring a narrow band at the opening.
	#   LED race (2): black, a light strip in the gate's colour along the
	#   middle of the bar, a thin white light near the outer edge.
	#   Chevron (1): the gate's colour, hazard stripes up the sides, a
	#   checkered band along the bottom, a white race line along the top.
	var st: int = STYLE if STYLE in [1, 2] else 0
	var pal: Dictionary = _pal_for(mat)
	var fm: String = mat
	if st == 2:
		fm = "gate_dark"
	elif st == 1:
		fm = "gate_trim"
		geo.tint = pal.main
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, h * 0.5 + bar * 0.5, 0)), Vector3(w + 2 * bar, bar, d), fm)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - bar * 0.5, 0)), Vector3(w + 2 * bar, bar, d), fm)
	for sx in [-1.0, 1.0]:
		geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * (w * 0.5 + bar * 0.5), 0, 0)), Vector3(bar, h, d), fm)
	geo.tint = Color.WHITE
	if st > 0:
		var W: float = w * 0.5
		var H: float = h * 0.5
		var b0: float = bar * 0.36 # (the design's inner and outer margins)
		var b1: float = bar * 0.94
		for side in [1.0, -1.0]:
			var face := xf * Transform3D(Basis(Vector3.UP, 0.0 if side > 0.0 else PI), Vector3(0, 0, side * d * 0.5))
			if st == 2:
				for e: Array in [[bar * 0.42, bar * 0.58, pal.led], [bar * 0.84, bar * 0.92, pal.led2]]:
					var i0: float = e[0]
					var i1: float = e[1]
					_rc(geo, face, LZ[0], -W - i1, H + i0, W + i1, H + i1, Color.WHITE, e[2])
					_rc(geo, face, LZ[0], -W - i1, -H - i1, W + i1, -H - i0, Color.WHITE, e[2])
					for sg in [-1.0, 1.0]:
						_rc(geo, face, LZ[0], minf(sg * (W + i0), sg * (W + i1)), -H - i0, maxf(sg * (W + i0), sg * (W + i1)), H + i0, Color.WHITE, e[2])
			else:
				var per: float = bar * 0.75
				for sg in [-1.0, 1.0]:
					var xa: float = minf(sg * (W + b0), sg * (W + b1))
					var xb: float = maxf(sg * (W + b0), sg * (W + b1))
					var k: int = 0
					var c: float = -H - (xb - xa)
					while c < H:
						_band(geo, face, LZ[0], xa, xb, c, per * 0.5, sg, [xa, -H, xb, H], pal.c1 if k % 2 == 0 else pal.c2)
						c += per * 0.5
						k += 1
				_rc(geo, face, LZ[0], -W, -H - b1, W, -H - b0, pal.c1)
				_checker(geo, face, LZ[1], -W, -H - b1, W, -H - b0, int(round(w / ((b1 - b0) * 1.0))), 1, INK_DARK)
				_rc(geo, face, LZ[0], -W, H + bar * 0.55, W, H + bar * 0.75, pal.c1)
		_direction(geo, xf, w, h, d * 0.5 + LZ[2], bar * 0.28)
	else:
		# White piping round the opening (LED gates: their light strip).
		var t: float = bar * 0.18
		var pipe: String = "gate_trim" if not mat.begins_with("led_") else mat
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, h * 0.5 + t * 0.5, 0)), Vector3(w, t, d * 1.3), pipe, false, false)
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, -h * 0.5 - t * 0.5, 0)), Vector3(w, t, d * 1.3), pipe, false, false)
		for sx in [-1.0, 1.0]:
			geo.box_xf(xf * Transform3D(Basis(), Vector3(sx * (w * 0.5 + t * 0.5), 0, 0)), Vector3(t, h, d * 1.3), pipe, false, false)
		_direction(geo, xf, w, h, d * 0.65 + 0.006, maxf(bar * 0.7, 0.03))
	if lift > 0.0 and pole:
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
var _flags: Array[Dictionary] = [] # {pos, basis, s, colour, gate, k}
var _flag_decal: MeshInstance3D
## `k` scales the whole flag: 1 for 5" tracks, ~0.3 for whoops indoors
## (zone 2.4 x 3 m, pole 1.1 m).
func turn_flag(geo: Geo, pos: Vector3, yaw: float, side: String, mat: String = "gate_b", k: float = 1.0) -> void:
	var basis := Basis(Vector3.UP, yaw)
	var s: float = 1.0 if side == "right" else -1.0
	if STYLE > 0:
		# A feather flag's pole: a ground spike, a short collar, the pole up
		# the sleeve and bent over along the sail's top arc.
		var r: float = 0.022 * maxf(k, 0.5)
		geo.cylinder(pos - Vector3(0, 0.3 * k, 0), pos + Vector3(0, 3.62 * k, 0), r, "gate_pole", 6)
		geo.cylinder(pos, pos + Vector3(0, 0.12 * k, 0), 0.045 * k, "gate_base", 8)
		var out: Vector3 = basis * Vector3(-s, 0, 0)
		var prev: Vector3 = pos + Vector3(0, 3.62 * k, 0)
		for i in range(1, 9):
			var a: float = PI * 0.5 * i / 8.0
			var q: Vector3 = pos + out * ((0.03 + 0.62 * sin(a)) * k) + Vector3(0, (3.0 + 0.62 * cos(a)) * k, 0)
			geo.cylinder(prev, q, r * 0.7, "gate_pole", 6)
			prev = q
	else:
		geo.cylinder(pos, pos + Vector3(0, 3.7 * k, 0), 0.03 * maxf(k, 0.5), "gate_pole", 6)
		geo.cylinder(pos, pos + Vector3(0, 0.06 * k, 0), 0.25 * k, "gate_base", 10)
	var aim := Transform3D(basis, pos + basis * Vector3(s * (FLAG_AIM * 0.5 + 0.1) * k, 0, 0) + Vector3(0, (FLAG_AIM * 0.5 + 0.1) * k, 0))
	var zone := Transform3D(basis, pos + basis * Vector3(s * FLAG_W * 0.5 * k, 0, 0) + Vector3(0, FLAG_H * 0.5 * k, 0))
	_register(aim, FLAG_AIM * k, FLAG_AIM * k)
	_gates[_gates.size() - 1].merge({"zone": {"xf": zone, "w": FLAG_W * k, "h": FLAG_H * k}, "flag": s, "pole": pos, "k": k})
	_flags.append({"pos": pos, "basis": basis, "s": s, "colour": FLAG_COLOURS.get(mat, Color(0.93, 0.36, 0.1)), "gate": _gates.size() - 1, "k": k, "styled": STYLE > 0})
	if STYLE > 0:
		_style_sail(geo, pos, yaw, -s, k, mat)

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
		if f.get("styled", false):
			continue # (SH_GATE_STYLE: drawn as plates by _style_sail)
		var out: Vector3 = f.basis * Vector3(-f.s, 0, 0) # away from the pass
		var back: Vector3 = f.basis * Vector3(0, 0, 1)
		var base: int = bv.size()
		for r in range(ROWS + 1):
			var t: float = float(r) / ROWS
			var w: float = (0.72 * sin(PI * pow(t, 0.62)) + 0.04) * f.k
			var y: float = (3.62 - t * 2.75) * f.k
			for u in us:
				var x: float = u * w
				var p: Vector3 = f.pos + Vector3(0, y, 0) + out * (x + 0.03) + back * (0.16 * u * u * f.k)
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
	if bv.size() > 0:
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
	if bv.size() > 0:
		add_child(banners)
	else:
		banners.free()
	# Ground marks: one quad per flag, UV = metres across (+ = the pass
	# side) and ahead, UV2.x = its gate index.
	var gv := PackedVector3Array()
	var gu := PackedVector2Array()
	var g2 := PackedVector2Array()
	var gi := PackedInt32Array()
	for f in _flags:
		var base: int = gv.size()
		for c in [Vector2(-3.0, -3.0), Vector2(6.5, -3.0), Vector2(6.5, 3.0), Vector2(-3.0, 3.0)]:
			gv.append(to_local(f.pos + Vector3(0, 0.06 * f.k, 0) + f.basis * Vector3(f.s * c.x, 0, -c.y) * f.k))
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
	_flag_decal.set_meta("dynamic", true) # see-through ground marks: no shadow
	add_child(_flag_decal)

# --- tracks ------------------------------------------------------------------

## A race map's course, built at load time on top of the (cached) map:
## `tracks` is the map's list of {"name", "level", "calls"} (Settings
## .race_track picks one), `calls` the gate builders as data (see
## build_track). The gates get their own small Geo, committed under the
## course node - so one map cache serves every track. The gates cast
## shadows: the static shadow map is cached per track
## (Settings.apply_shadow_setting); only moving parts (marker, line,
## ghost, flag ground marks) are "dynamic". opts: "ao_height", "ao_min"
## for the gates' baked AO.
static func make(map: BuiltMap, tracks: Array, opts: Dictionary = {}) -> RaceCourse:
	pick_style(map) # (also when the map itself came from the map cache)
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
	return rc

## Builds a track from data: each call is [kind, args...] with kind one of
## "start" | "gate" | "sized" | "dive" | "hurdle" | "flag" | "turn" | "hanging" | "ladder"
## | "via" (a waypoint of the racing line toward the next gate, [kind, position])
## (the builders above, args in their order after geo) or "box" (a plain
## prop: centre, size, colour - e.g. the desk under a gate; its own flat
## material, since the map's are not there on a cached load).
func build_track(geo: Geo, calls: Array) -> void:
	var fn: Dictionary = {"start": "start_gate", "gate": "gate", "sized": "gate_sized", "dive": "dive_gate",
		"hurdle": "hurdle", "flag": "flag", "turn": "turn_flag", "hanging": "hanging_gate", "ladder": "ladder"}
	for c: Array in calls:
		var kind: String = c[0]
		if kind == "via": # a point the racing line passes on the way to the next gate (not a gate)
			_add_via(c[1])
			continue
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
# the missed gate is flown - the clock keeps running. With the competition
# rule on (Settings.race_strict, MultiGP style, off by default) a missed
# gate (or a flag passed on the wrong side) instead voids the lap: the
# course carries on from the gate flown, and at START the race starts
# over. At the finish: lap times, total, and the track's top-5 races (per
# drone).

const LAPS: int = 2
static var BOARD_PATH: String = save_path("race_board.cfg")
var _race_laps: Array[float] = []
var _splits: Array[float] = []      # this lap: time at each gate
var _best_splits: Array = []        # the best lap's
var _delta_text: String = ""
var _delta_t: float = 0.0
var _missed_gate: int = -1
var _void_gate: int = -1 ## competition rule: the gate missed this lap (-1: the lap counts)
var _void_msg: float = 0.0
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
		if Settings.race_strict:
			_void(_next)
			_passed() # the flag is behind you: on to the next gate, the lap is void
		else:
			if _missed_gate != _next:
				_play("miss")
			_missed_gate = _next # past the flag on the wrong side: go back round it
	elif _lap_start >= 0.0:
		for i in range(_gates.size()):
			# A flag's wide invisible opening only counts as the next gate:
			# flying through one elsewhere on the lap isn't skipping ahead.
			if i != _next and i != (_next - 1 + _gates.size()) % _gates.size() and not _gates[i].has("flag") and _crossed(_gates[i], _prev_pos, pos):
				if Settings.race_strict:
					_void(_next)
					_next = i # carry on from the gate flown
					_passed()
					break
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

## Competition rule: the lap is void (first missed gate is the one shown).
func _void(gate: int) -> void:
	if _void_gate < 0:
		_void_gate = gate
		_play("miss")

func _passed() -> void:
	_missed_gate = -1
	if _next == 0 and _lap_start >= 0.0 and _void_gate >= 0:
		# A void lap doesn't count: the race starts over from this pass.
		_void_gate = -1
		_void_msg = 2.5
		_race_laps.clear()
		_lap = 0
		_lap_start = -1.0
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
	_void_gate = -1
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
	elif _void_gate >= 0:
		d.msg = "MISSED GATE %d - this lap won't count" % (_void_gate + 1)
		d.msg_good = false
	if _void_msg > 0.0:
		_void_msg -= get_physics_process_delta_time()
		d.msg = "LAP NOT COUNTED - the race starts over"
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
			lb.position = to_local(g.pole + Vector3(0, 4.2 * float(g.get("k", 1.0)), 0))
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
	_marker.set_meta("dynamic", true) # it moves: no shadow
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
		if c[0] == "via":
			rc._add_via(c[1])
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
		var floor_y: float = minf(p0.y, p1.y) - 0.3
		var via: Array = a.get("via", [])
		if via.is_empty():
			var l: float = p0.distance_to(p1)
			var x: float = 1.0 - d0.dot(d1)
			var k: float = 1.0 - 0.16 * x + 0.33 * x * x # 1 straight, ~1.17 a quarter turn, 2 a half loop
			_hermite(pts, p0, d0 * l * k, p1, d1 * l * k, int(l * (1.0 + x) / LINE_STEP), floor_y, true)
			continue
		# Through the waypoints ("via" calls): Catmull-Rom tangents there,
		# the gates' own directions at the ends.
		var q: Array = [p0] + via + [p1]
		for m in range(q.size() - 1):
			var l: float = (q[m] as Vector3).distance_to(q[m + 1])
			var t0: Vector3 = d0 * l if m == 0 else ((q[m + 1] as Vector3) - q[m - 1]) * 0.5
			var t1: Vector3 = d1 * l if m == q.size() - 2 else ((q[m + 2] as Vector3) - q[m]) * 0.5
			_hermite(pts, q[m], t0, q[m + 1], t1, int(l * 1.5 / LINE_STEP), floor_y, m == 0)
	pts.append(pts[0]) # closed: back into START
	seg.append(pts.size() - 1)
	return {"pts": pts, "seg": seg}

## One Hermite piece p0 -> p1 (p1 itself left to the next piece), points
## LINE_STEP apart, never below floor_y; `at_gate`: p0 is a gate's opening
## (always kept - the stretch's first point, line_path's "seg").
static func _hermite(pts: PackedVector3Array, p0: Vector3, t0: Vector3, p1: Vector3, t1: Vector3, steps: int, floor_y: float, at_gate: bool) -> void:
	steps = maxi(steps, 2)
	for j in range(steps):
		var t: float = float(j) / steps
		var t2: float = t * t
		var t3: float = t2 * t
		var p: Vector3 = (2 * t3 - 3 * t2 + 1) * p0 + (t3 - 2 * t2 + t) * t0 + (-2 * t3 + 3 * t2) * p1 + (t3 - t2) * t1
		p.y = maxf(p.y, floor_y)
		if (j == 0 and at_gate) or p.distance_to(pts[pts.size() - 1]) >= LINE_STEP:
			pts.append(p)

## The racing line must not run through anything (2026-10-14): a ball of
## LINE_CLEAR round every point; where it touches something, the line is
## pushed the shortest way out (sideways or up, in rings round the line)
## and the push blended in over a few metres either side, the gate
## openings themselves staying put. A few rounds, as one push can meet
## something else.
const LINE_CLEAR: float = 0.3
const LINE_KEEP: int = 4 ## points next to each gate that never move
const LINE_BLEND: int = 14 ## points over which a push fades out (~5.6 m)
static func clear_path(pts: PackedVector3Array, seg: PackedInt32Array, space: PhysicsDirectSpaceState3D, exclude: Array, clear: float = LINE_CLEAR) -> PackedVector3Array:
	var n: int = pts.size()
	var fixed := PackedByteArray()
	fixed.resize(n)
	for b in seg:
		for k in range(-LINE_KEEP, LINE_KEEP + 1):
			fixed[clampi(b + k, 0, n - 1)] = 1
	var out: PackedVector3Array = pts.duplicate()
	for round_no in range(12):
		var bad: PackedInt32Array = blocked_points(space, out, clear, exclude, fixed)
		if bad.is_empty():
			break
		# Each blocked point's way out, then the strongest push near each point.
		var push: Dictionary = {}
		for i in bad:
			var t: Vector3 = (out[mini(i + 1, n - 1)] - out[maxi(i - 1, 0)]).normalized()
			var o: Vector3 = _way_out(space, out[i], t, exclude, clear)
			if o != Vector3.ZERO:
				push[i] = o
		if push.is_empty():
			break
		var add := PackedVector3Array()
		add.resize(n)
		var wbest := PackedFloat32Array()
		wbest.resize(n)
		# (Later rounds: shorter blends - a tight spot between two things
		# settles locally instead of the push swinging into the other.)
		var blend: int = LINE_BLEND if round_no < 6 else 5
		for i: int in push:
			for k in range(-blend, blend + 1):
				var j: int = i + k
				if j < 0 or j >= n or fixed[j] == 1:
					continue
				var w: float = 0.5 + 0.5 * cos(PI * absf(k) / (blend + 1))
				# (fading in from the fixed points by the gates too)
				var gate_d: int = LINE_BLEND
				for b in seg:
					gate_d = mini(gate_d, absi(j - b) - LINE_KEEP)
				w *= clampf(float(gate_d) / 6.0, 0.0, 1.0)
				if w > wbest[j]:
					wbest[j] = w
					add[j] = push[i] * w
		# Smoothed, so the line bends round things instead of stepping.
		for _pass in range(4 if round_no < 6 else 1):
			var sm: PackedVector3Array = add.duplicate()
			for j in range(1, n - 1):
				if fixed[j] == 0:
					sm[j] = (add[j - 1] + add[j] * 2.0 + add[j + 1]) * 0.25
			add = sm
		for j in range(n):
			out[j] += add[j] * 1.15 # (a little extra: the smoothing takes some off the peak)
	return out

## Points of `pts` (not marked in `skip`) whose ball of radius r touches
## a solid.
static func blocked_points(space: PhysicsDirectSpaceState3D, pts: PackedVector3Array, r: float, exclude: Array, skip: PackedByteArray = PackedByteArray()) -> PackedInt32Array:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = r
	q.shape = ball
	q.exclude = exclude
	var out := PackedInt32Array()
	for i in range(pts.size()):
		if i < skip.size() and skip[i] == 1:
			continue
		q.transform = Transform3D(Basis(), pts[i])
		if not space.intersect_shape(q, 1).is_empty():
			out.append(i)
	return out

## The cheapest free offset from p across the line's direction t: rings
## of growing radius round the line; going over costs half as much again
## as going round (a line climbing over every bale of a chicane is not
## how anyone flies it).
static func _way_out(space: PhysicsDirectSpaceState3D, p: Vector3, t: Vector3, exclude: Array, clear: float) -> Vector3:
	var q := PhysicsShapeQueryParameters3D.new()
	var ball := SphereShape3D.new()
	ball.radius = clear + 0.1
	q.shape = ball
	q.exclude = exclude
	var up: Vector3 = (Vector3.UP - t * t.y)
	if up.length() < 0.1:
		up = Vector3.FORWARD - t * t.z
	up = up.normalized()
	var side: Vector3 = t.cross(up).normalized()
	var cands: Array = [] # [cost, offset]
	for rad in [0.4, 0.8, 1.2, 1.8, 2.5, 3.5, 5.0, 7.0]:
		for k in range(16):
			var a: float = TAU * k / 16.0 # 0 = straight up
			var o: Vector3 = (up * cos(a) + side * sin(a)) * rad
			cands.append([rad * (1.0 + 0.5 * absf(cos(a))), o]) # (under: the floor is close)
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] < y[0])
	for c: Array in cands:
		q.transform = Transform3D(Basis(), p + (c[1] as Vector3))
		if space.intersect_shape(q, 1).is_empty():
			return c[1]
	return Vector3.ZERO

func _build_line() -> void:
	var lp: Dictionary = line_path(_gates)
	var small: bool = _gates.any(func(g: Dictionary) -> bool: return g.w < 1.0) # whoop gates indoors: a tighter ball
	var pts: PackedVector3Array = clear_path(lp.pts, lp.seg, get_world_3d().direct_space_state, [drone.get_rid()] if drone else [], 0.15 if small else LINE_CLEAR)
	if OS.has_environment("SH_LINE_RAW"): # dev: the line as it was before clear_path
		pts = lp.pts
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
