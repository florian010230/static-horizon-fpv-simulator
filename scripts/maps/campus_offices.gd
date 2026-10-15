class_name CampusOffices
extends RefCounted

## The small buildings of the campus, fitted out: Office A (3 floors, 24 x 14 m,
## everything finished), Office B (4 floors, 20 x 16 m - fitted, fitted,
## metal stud frames, bare slab with a scaffold and a hoist outside), Lab C
## (3 floors, open lab floors, an outside stair tower) and Canteen D (2
## floors, kitchen and dining hall). Rooms are tight, as on the House map:
## 0.9 m doorways, 1.4-1.6 m corridors. Each has stairs and a lift.
## The floor plans are the approved plan's numbers (plan x = east, plan y =
## south, origin at the building's north-west corner); the room rows are
## [x, y, w, h, label, kind, doors] and a door is [side n/s/e/w, offset].

const A_O := Vector3(136, 0, -118)
const B_O := Vector3(140, 0, -92)
const C_O := Vector3(138, 0, -66)
const D_O := Vector3(-40, 0, 6)

const A_CORE: Array = [
	[0.0, 0.0, 3.0, 6.2, "Stairs", "core", [["s", 1.0]]],
	[3.0, 0.0, 2.0, 3.8, "Riser", "tech", []],
	[3.0, 3.8, 2.0, 2.4, "Lift", "lift", [["s", 0.55]]]]

const A_FLOORS: Array = [
	[[5.0, 0.0, 2.5, 6.2, "WC", "wc", [["s", 0.8]]], [7.5, 0.0, 2.5, 6.2, "WC", "wc", [["s", 0.8]]],
	 [10.0, 0.0, 4.0, 6.2, "Kitchen", "kitchen", [["s", 1.5]]], [14.0, 0.0, 10.0, 6.2, "Meeting", "meet", [["s", 1.0], ["s", 8.0]]],
	 [0.0, 7.8, 6.0, 6.2, "Lobby", "lobby", [["n", 2.5]]], [6.0, 7.8, 4.0, 6.2, "Office", "office", [["n", 1.5]]],
	 [10.0, 7.8, 4.6, 6.2, "Office", "office", [["n", 1.5]]], [14.6, 7.8, 4.6, 6.2, "Office", "office", [["n", 1.5]]],
	 [19.2, 7.8, 4.8, 6.2, "Office", "office", [["n", 1.5]]]],
	[[5.0, 0.0, 3.0, 6.2, "WC", "wc", [["s", 1.0]]], [8.0, 0.0, 3.0, 6.2, "Kitchen", "kitchen", [["s", 1.0]]],
	 [11.0, 0.0, 3.25, 6.2, "Office", "office", [["s", 1.2]]], [14.25, 0.0, 3.25, 6.2, "Office", "office", [["s", 1.2]]],
	 [17.5, 0.0, 3.25, 6.2, "Office", "office", [["s", 1.2]]], [20.75, 0.0, 3.25, 6.2, "Office", "office", [["s", 1.2]]],
	 [0.0, 7.8, 6.0, 6.2, "Meeting", "meet", [["n", 4.0]]], [6.0, 7.8, 3.6, 6.2, "Office", "office", [["n", 1.3]]],
	 [9.6, 7.8, 3.6, 6.2, "Office", "office", [["n", 1.3]]], [13.2, 7.8, 3.6, 6.2, "Office", "office", [["n", 1.3]]],
	 [16.8, 7.8, 3.6, 6.2, "Office", "office", [["n", 1.3]]], [20.4, 7.8, 3.6, 6.2, "Office", "office", [["n", 1.3]]]],
	[[5.0, 0.0, 3.0, 6.2, "WC", "wc", [["s", 1.0]]], [8.0, 0.0, 2.5, 6.2, "Server", "tech", [["s", 0.8]]],
	 [10.5, 0.0, 3.4, 6.2, "Office", "office", [["s", 1.2]]], [13.9, 0.0, 3.4, 6.2, "Office", "office", [["s", 1.2]]],
	 [17.3, 0.0, 3.4, 6.2, "Office", "office", [["s", 1.2]]], [20.7, 0.0, 3.3, 6.2, "Office", "office", [["s", 1.2]]],
	 [0.0, 7.8, 6.0, 6.2, "Head office", "office", [["n", 4.0]]], [6.0, 7.8, 8.0, 6.2, "Board room", "meet", [["n", 1.0], ["n", 6.0]]],
	 [14.0, 7.8, 4.0, 6.2, "Lounge", "kitchen", [["n", 1.5]]], [18.0, 7.8, 3.0, 6.2, "Office", "office", [["n", 1.0]]],
	 [21.0, 7.8, 3.0, 6.2, "Office", "office", [["n", 1.0]]]]]

const B_CORE: Array = [
	[6.0, 6.0, 3.5, 4.0, "Stairs", "core", [["n", 1.2]]], [9.5, 6.0, 2.0, 2.2, "Lift", "lift", [["n", 0.55]]],
	[11.5, 6.0, 2.5, 4.0, "WC", "wc", [["s", 0.8]]], [9.5, 8.2, 2.0, 1.8, "Riser", "tech", [["s", 0.55]]]]

static func _b_ring(kind: String, l: Dictionary) -> Array:
	var kk := func(d: String) -> String: return kind if kind != "" else d
	return [
		[0.0, 0.0, 5.0, 4.6, l.get("n1", "Office"), kk.call("office"), [["s", 2.0]]], [5.0, 0.0, 5.0, 4.6, l.get("n2", "Office"), kk.call("office"), [["s", 2.0]]],
		[10.0, 0.0, 5.0, 4.6, l.get("n3", "Office"), kk.call("office"), [["s", 2.0]]], [15.0, 0.0, 5.0, 4.6, l.get("n4", "Office"), kk.call("office"), [["s", 1.0]]],
		[0.0, 4.6, 4.6, 6.8, l.get("w", "Meeting"), kk.call("meet"), [["e", 2.9]]], [15.4, 4.6, 4.6, 6.8, l.get("e", "Kitchen"), kk.call("kitchen"), [["w", 2.9]]],
		[0.0, 11.4, 5.0, 4.6, l.get("s1", "Office"), kk.call("office"), [["n", 2.0]]], [5.0, 11.4, 3.0, 4.6, l.get("s2", "Lobby"), kk.call("lobby"), [["n", 1.0]]],
		[8.0, 11.4, 4.0, 4.6, l.get("s3", "Entrance"), kk.call("lobby"), [["n", 1.5]]], [12.0, 11.4, 3.0, 4.6, l.get("s4", "Copy"), kk.call("tech"), [["n", 1.0]]],
		[15.0, 11.4, 5.0, 4.6, l.get("s5", "Office"), kk.call("office"), [["n", 1.0]]]]

var k: CampusKit
var geo: Geo
var rng := RandomNumberGenerator.new()

func _init(kit: CampusKit) -> void:
	k = kit
	geo = kit.geo
	rng.seed = 4711

func build_all() -> void:
	_office_a()
	_office_b()
	_lab_c()
	_canteen_d()

# --- plan helpers -----------------------------------------------------------------------------------

## Wall style of a room: 3 concrete (stairs, lift), 2 partition, 1 stud frame, 0 none.
func _prio(kind: String) -> int:
	match kind:
		"core", "lift", "tech", "wc":
			return 3 if kind != "wc" else 2
		"stud":
			return 1
		"shell":
			return 0
	return 2

func _edge(lines: Dictionary, axis: String, c: float, a0: float, a1: float, prio: int) -> void:
	var key: String = "%s|%.2f" % [axis, c]
	if not lines.has(key):
		lines[key] = {"axis": axis, "c": c, "edges": [], "doors": []}
	lines[key].edges.append([a0, a1, prio])

func _door(lines: Dictionary, axis: String, c: float, a0: float, a1: float) -> void:
	var key: String = "%s|%.2f" % [axis, c]
	if lines.has(key):
		lines[key].doors.append([a0, a1])

## The wall runs of a floor: [{axis, c, a0, a1, prio, doors}], rooms'
## shared edges merged into one wall, doorways collected, exterior edges left out.
func _runs(rooms: Array, W: float, D: float) -> Array:
	var lines: Dictionary = {}
	for r: Array in rooms:
		var p: int = _prio(r[5])
		if p == 0:
			continue
		var x: float = r[0]
		var y: float = r[1]
		var w: float = r[2]
		var h: float = r[3]
		if y > 0.01:
			_edge(lines, "x", y, x, x + w, p)
		if y + h < D - 0.01:
			_edge(lines, "x", y + h, x, x + w, p)
		if x > 0.01:
			_edge(lines, "z", x, y, y + h, p)
		if x + w < W - 0.01:
			_edge(lines, "z", x + w, y, y + h, p)
	for r: Array in rooms:
		var x: float = r[0]
		var y: float = r[1]
		var w: float = r[2]
		var h: float = r[3]
		for d: Array in r[6]:
			var off: float = d[1]
			match d[0]:
				"n":
					_door(lines, "x", y, x + off, x + off + 0.9)
				"s":
					_door(lines, "x", y + h, x + off, x + off + 0.9)
				"w":
					_door(lines, "z", x, y + off, y + off + 0.9)
				"e":
					_door(lines, "z", x + w, y + off, y + off + 0.9)
	var out: Array = []
	for key: String in lines:
		var ln: Dictionary = lines[key]
		var pts: Array = []
		for e: Array in ln.edges:
			pts.append(e[0])
			pts.append(e[1])
		pts.sort()
		var cur: Variant = null
		for i in range(pts.size() - 1):
			var a: float = pts[i]
			var b: float = pts[i + 1]
			if b - a < 0.005:
				continue
			var best: int = 0
			for e: Array in ln.edges:
				if e[0] <= a + 0.005 and e[1] >= b - 0.005:
					best = maxi(best, e[2])
			if cur != null and cur.prio == best and absf(cur.a1 - a) < 0.005:
				cur.a1 = b
			else:
				if cur != null and cur.prio > 0:
					out.append(cur)
				cur = {"axis": ln.axis, "c": ln.c, "a0": a, "a1": b, "prio": best, "doors": []}
		if cur != null and cur.prio > 0:
			out.append(cur)
	for run: Dictionary in out:
		var ln: Dictionary = lines["%s|%.2f" % [run.axis, run.c]]
		for d: Array in ln.doors:
			if d[1] > run.a0 + 0.01 and d[0] < run.a1 - 0.01:
				run.doors.append([maxf(d[0], run.a0), minf(d[1], run.a1)])
	return out

func _light(n: Vector3, p: Vector3) -> Color:
	var b: float = 0.66 + 0.2 * clampf(n.y, 0.0, 1.0) - 0.06 * clampf(-n.y, 0.0, 1.0)
	return Color(b * 1.02, b, b * 0.96)

## One floor's walls (partitions, concrete, studs).
func _draw_walls(o: Vector3, rooms: Array, W: float, D: float, yf: float, ch: float) -> void:
	for run: Dictionary in _runs(rooms, W, D):
		var a0: float = maxf(run.a0, 0.3)
		var a1: float = minf(run.a1, (W if run.axis == "x" else D) - 0.3)
		if a1 - a0 < 0.05:
			continue
		var base: float = o.x if run.axis == "x" else o.z
		var cw: float = (o.z + run.c) if run.axis == "x" else (o.x + run.c)
		var doors: Array = []
		for d: Array in run.doors:
			doors.append([base + maxf(d[0], a0), base + minf(d[1], a1)])
		if run.prio == 1:
			_studs(run.axis, cw, base + a0, base + a1, yf, ch, doors)
			continue
		var holes: Array = []
		for d: Array in doors:
			holes.append(Rect2(d[0], yf, d[1] - d[0], 2.1))
		var th: float = 0.2 if run.prio == 3 else 0.1
		k.wall(run.axis, cw, base + a0, base + a1, yf, yf + ch, th, holes, "off_slab" if run.prio == 3 else "off_wall")

## A metal stud frame: studs every 0.6 m, tracks top and bottom (the bottom
## one broken at the doorways), a short stud over each door.
func _studs(axis: String, c: float, a0: float, a1: float, yf: float, h: float, doors: Array) -> void:
	var n: int = int((a1 - a0) / 0.6)
	var along_x: bool = axis == "x"
	for i in range(n + 1):
		var t: float = a0 + 0.03 + i * (a1 - a0 - 0.06) / n
		var in_door: bool = false
		for d: Array in doors:
			if t > d[0] - 0.02 and t < d[1] + 0.02:
				in_door = true
		var hh: float = h - 2.1 if in_door else h
		var y0: float = yf + 2.1 if in_door else yf
		geo.box(Vector3(t, y0 + hh * 0.5, c) if along_x else Vector3(c, y0 + hh * 0.5, t), Vector3(0.05, hh, 0.1) if along_x else Vector3(0.1, hh, 0.05), "stud")
	geo.box(Vector3((a0 + a1) * 0.5, yf + h - 0.02, c) if along_x else Vector3(c, yf + h - 0.02, (a0 + a1) * 0.5), Vector3(a1 - a0, 0.04, 0.1) if along_x else Vector3(0.1, 0.04, a1 - a0), "stud")
	# bottom track in pieces
	var cuts: Array = doors.duplicate()
	cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var from: float = a0
	for d: Array in cuts + [[a1, a1]]:
		if d[0] - from > 0.05:
			geo.box(Vector3((from + d[0]) * 0.5, yf + 0.02, c) if along_x else Vector3(c, yf + 0.02, (from + d[0]) * 0.5), Vector3(d[0] - from, 0.04, 0.1) if along_x else Vector3(0.1, 0.04, d[0] - from), "stud")
		from = d[1]

func _bx(x: float, y0: float, z: float, sx: float, sy: float, sz: float, mat: String, col: Color = Color.WHITE, yaw: float = 0.0, collide: bool = true) -> void:
	geo.tint = col
	geo.box(Vector3(x, y0 + sy * 0.5, z), Vector3(sx, sy, sz), mat, yaw, collide, false)
	geo.tint = Color.WHITE

# --- furniture ------------------------------------------------------------------------------------------

func _desk(x: float, y0: float, z: float, along_x: bool, face: float) -> void:
	# A desk 1.6 x 0.75 with a monitor, a chair on the `face` side (+1/-1 across).
	var sx: float = 1.6 if along_x else 0.75
	var sz: float = 0.75 if along_x else 1.6
	_bx(x, y0 + 0.7, z, sx, 0.04, sz, "desk")
	for e in [-1.0, 1.0]:
		_bx(x + (e * 0.7 if along_x else 0.0), y0, z + (0.0 if along_x else e * 0.7), 0.05 if along_x else 0.7, 0.7, 0.7 if along_x else 0.05, "desk")
	_bx(x, y0 + 0.74, z, 0.55 if along_x else 0.08, 0.34, 0.08 if along_x else 0.55, "screen_on", Color(0.6, 0.65, 0.7), 0.0, false)
	var cx: float = x + (0.0 if along_x else face * 0.85)
	var cz: float = z + (face * 0.85 if along_x else 0.0)
	_bx(cx, y0 + 0.42, cz, 0.5, 0.05, 0.5, "chair")
	_bx(cx - (0.0 if along_x else face * 0.22), y0 + 0.47, cz - (face * 0.22 if along_x else 0.0), 0.5 if along_x else 0.05, 0.45, 0.05 if along_x else 0.5, "chair")
	_bx(cx, y0, cz, 0.07, 0.42, 0.07, "chair")

func _toilet_row(o: Vector3, r: Array, yf: float) -> void:
	# Stalls along the room's north wall, each with a toilet (ToiletCreator).
	var x0: float = o.x + r[0]
	var z0: float = o.z + maxf(r[1] + 0.1, 0.34)
	var n: int = maxi(1, int((r[2] - 0.2) / 0.95))
	var pw: float = (r[2] - 0.2) / n
	for i in range(n):
		var cx: float = x0 + 0.1 + pw * (i + 0.5)
		ToiletCreator.build(geo, Transform3D(Basis(), Vector3(cx, yf, z0)), rng, {})
		if i < n - 1:
			_bx(x0 + 0.1 + pw * (i + 1), yf + 0.2, z0 + 0.75, 0.04, 1.8, 1.5, "tile")
	# a washbasin by the door end
	_bx(x0 + r[2] * 0.5, yf, z0 + r[3] - 0.6, 1.2, 0.85, 0.45, "white_goods")

func _furnish(o: Vector3, r: Array, yf: float, ch: float, floor_idx: int) -> void:
	var x0: float = o.x + r[0]
	var z0: float = o.z + r[1]
	var w: float = r[2]
	var h: float = r[3]
	var cx: float = x0 + w * 0.5
	var cz: float = z0 + h * 0.5
	var kind: String = r[5]
	# The wall opposite the first door.
	var far := Vector2(0, 0)
	if not r[6].is_empty():
		match r[6][0][0]:
			"s":
				far = Vector2(0, -1)
			"n":
				far = Vector2(0, 1)
			"e":
				far = Vector2(-1, 0)
			"w":
				far = Vector2(1, 0)
	if kind in ["office", "meet", "kitchen", "lobby", "tech", "wc"]:
		geo.box(Vector3(cx, yf + ch - 0.06, cz), Vector3(0.9, 0.06, 0.3), "lamp", 0.0, false, false)
	match kind:
		"office":
			var nd: int = 2 if (w >= 4.4 and h >= 6.0) else 1
			for d in range(nd):
				var dz: float = (-0.0) if nd == 1 else (-1.2 + d * 2.4)
				if far.y != 0.0:
					# desk against the far wall (north/south), chair facing it
					var zz: float = (z0 + (0.5 if far.y < 0 else h - 0.5))
					var xx: float = cx + (0.0 if nd == 1 else (-1.2 + d * 2.4))
					_desk(xx, yf, zz, true, 1.0 if far.y < 0 else -1.0)
				else:
					var xx2: float = (x0 + (0.5 if far.x < 0 else w - 0.5))
					_desk(xx2, yf, cz, false, 1.0 if far.x < 0 else -1.0)
			# a cabinet in a corner
			_bx(x0 + 0.35, yf, z0 + 0.35 if far.y > 0 else z0 + h - 0.35, 0.5, 1.8, 0.8, "off_floor", Color(0.7, 0.75, 0.8))
		"meet":
			var along_x: bool = w >= h
			var L: float = (w if along_x else h) - 2.0
			var tw: float = 1.3
			_bx(cx, yf + 0.72, cz, L if along_x else tw, 0.05, tw if along_x else L, "desk")
			_bx(cx, yf, cz, (L if along_x else tw) - 0.6, 0.72, (tw if along_x else L) - 0.6, "desk", Color(0.6, 0.6, 0.6))
			var nch: int = maxi(2, int(L / 0.85))
			for i in range(nch):
				var t: float = -L * 0.5 + 0.45 + i * (L - 0.9) / maxi(nch - 1, 1)
				for s in [-1.0, 1.0]:
					var px: float = cx + (t if along_x else s * 1.0)
					var pz: float = cz + (s * 1.0 if along_x else t)
					_bx(px, yf, pz, 0.45, 0.45, 0.45, "chair")
					_bx(px, yf + 0.45, pz + (s * 0.2 if along_x else 0.0) * 1.0, 0.45 if along_x else 0.06, 0.45, 0.06 if along_x else 0.45, "chair")
			# a screen on the far end wall
			if along_x:
				_bx(x0 + 0.2, yf + 1.1, cz, 0.05, 1.0, 1.8, "screen_on", Color(0.5, 0.55, 0.6), 0.0, false)
			else:
				_bx(cx, yf + 1.1, z0 + 0.2, 1.8, 1.0, 0.05, "screen_on", Color(0.5, 0.55, 0.6), 0.0, false)
		"kitchen":
			_bx(cx, yf, z0 + (0.4 if far.y >= 0 else h - 0.4), w - 0.5, 0.9, 0.6, "white_goods")
			_bx(x0 + 0.4, yf, cz, 0.7, 1.9, 0.7, "white_goods", Color(0.9, 0.9, 0.95))
			_bx(cx, yf + 0.72, cz + 0.4, 1.2, 0.04, 0.8, "desk")
			_bx(cx, yf, cz + 0.4, 1.0, 0.72, 0.6, "desk", Color(0.5, 0.5, 0.5))
			for e in [-0.8, 0.8]:
				_bx(cx + e, yf, cz + 1.2, 0.4, 0.45, 0.4, "chair")
		"wc":
			_toilet_row(o, r, yf)
		"tech":
			var nr: int = maxi(1, int((w - 0.4) / 0.75))
			for i in range(mini(nr, 3)):
				_bx(x0 + 0.5 + i * 0.75, yf, z0 + 0.6, 0.6, 2.0, 0.9, "chair", Color(0.55, 0.58, 0.62))
				_bx(x0 + 0.5 + i * 0.75, yf + 1.4, z0 + 1.07, 0.5, 0.05, 0.02, "screen_on", Color(0.4, 1.0, 0.5), 0.0, false)
			_bx(x0 + w - 0.7, yf, z0 + h - 0.7, 0.9, 1.0, 0.7, "white_goods")
		"lobby":
			_bx(cx, yf, cz, 2.4, 1.05, 0.7, "desk", Color(0.9, 0.8, 0.7))
			_bx(cx - 1.05, yf, cz + 0.8, 0.7, 1.05, 1.6, "desk", Color(0.9, 0.8, 0.7))
			_bx(x0 + 0.6, yf, z0 + h - 0.6, 1.6, 0.45, 0.8, "chair")
			geo.cone(Vector3(x0 + w - 0.5, yf, z0 + 0.5), Vector3(x0 + w - 0.5, yf + 1.2, z0 + 0.5), 0.3, 0.1, "wreath", 8, false, false)

## Windows of a floor on the exterior walls: [axis, centre (world), width] per
## room touching the boundary. Returns holes per wall side as Rect2 lists.
func _windows(o: Vector3, rooms: Array, W: float, D: float, yf: float, extra: Array = []) -> Dictionary:
	var h: Dictionary = {"n": [], "s": [], "w": [], "e": []}
	for r: Array in rooms:
		var kind: String = r[5]
		if kind == "lift" or kind == "tech":
			continue
		var ww: float = clampf(minf(r[2], r[3]) - 0.9, 0.9, 1.6) if kind != "core" else 0.9
		if r[1] < 0.01:
			h.n.append(Rect2(o.x + r[0] + r[2] * 0.5 - ww * 0.5, yf + 0.9, ww, 1.3))
		if r[1] + r[3] > D - 0.01:
			h.s.append(Rect2(o.x + r[0] + r[2] * 0.5 - ww * 0.5, yf + 0.9, ww, 1.3))
		if r[0] < 0.01:
			h.w.append(Rect2(o.z + r[1] + r[3] * 0.5 - ww * 0.5, yf + 0.9, ww, 1.3))
		if r[0] + r[2] > W - 0.01:
			h.e.append(Rect2(o.z + r[1] + r[3] * 0.5 - ww * 0.5, yf + 0.9, ww, 1.3))
	for e: Array in extra:
		h[e[0]].append(Rect2(e[1] - e[2] * 0.5, yf + 0.9, e[2], 1.3))
	return h

# --- the generic fitted building (Office A and B) -----------------------------------------------------------

func _yf(f: int, fh: float) -> float:
	return 0.12 + f * fh

## Builds a plan-based building. stages[f]: "fitted", "stud" or "bare".
## stair: [x, y, w, d, north (entry at the north end)] in plan metres.
## ext_floors: how many floors have an outside wall (the rest are open).
func _plan_building(label: String, o: Vector3, W: float, D: float, fh: float, plans: Array, stages: Array, stair: Array, lift: Rect2,
		doors_out: Array, ext_floors: int, extra_win: Array) -> void:
	var n: int = plans.size()
	var ch: float = fh - 0.25
	var y_roof: float = _yf(n, fh)
	geo.begin_object(label)
	var holes_by_floor: Array = []
	# --- exterior wall (default light) and slabs
	var wins: Array = []
	for f in range(ext_floors):
		wins.append(_windows(o, plans[f], W, D, _yf(f, fh), extra_win))
	var top_wall: float = y_roof + 0.8 if ext_floors == n else _yf(ext_floors, fh) - 0.25
	for side in ["n", "s", "w", "e"]:
		var holes: Array = []
		for f in range(ext_floors):
			holes.append_array(wins[f][side])
		for d: Array in doors_out:
			if d[0] == side:
				var c: float = (o.x if side in ["n", "s"] else o.z) + d[1]
				holes.append(Rect2(c, _yf(0, fh), d[2], 2.2))
		match side:
			"n":
				k.wall("x", o.z + 0.15, o.x, o.x + W, -0.1, top_wall, 0.3, holes, "off_ext")
			"s":
				k.wall("x", o.z + D - 0.15, o.x, o.x + W, -0.1, top_wall, 0.3, holes, "off_ext")
			"w":
				k.wall("z", o.x + 0.15, o.z + 0.3, o.z + D - 0.3, -0.1, top_wall, 0.3, holes, "off_ext")
			"e":
				k.wall("z", o.x + W - 0.15, o.z + 0.3, o.z + D - 0.3, -0.1, top_wall, 0.3, holes, "off_ext")
	# Roof slab (outside light), a stair and lift opening, a parapet.
	var stair_o := Vector3(o.x + stair[0] + 0.1, 0.0, o.z + stair[1] + 0.1)
	var sw: float = stair[2] - 0.2
	var sd: float = stair[3] - 0.2
	var north: bool = stair[4]
	var shole: Rect2 = k.stair_hole(stair_o, sw, sd, fh, north)
	var lhole := Rect2(o.x + lift.position.x + 0.1, o.z + lift.position.y + 0.1, lift.size.x - 0.2, lift.size.y - 0.2)
	var inset: float = 0.3 if ext_floors == n else 0.0
	var plate := Rect2(o.x + inset, o.z + inset, W - inset * 2.0, D - inset * 2.0)
	k.slab_holes(plate, y_roof, 0.25, [shole, lhole], "off_slab")
	if ext_floors < n:
		# open top storeys: edge rails round the roof too
		pass
	# Slabs between the floors.
	for f in range(n + 1):
		if f == 0:
			geo.box(Vector3(o.x + W * 0.5, -0.04, o.z + D * 0.5), Vector3(W - 0.6, 0.32, D - 0.6), "off_slab")
		elif f < n:
			var ins: float = 0.3 if f <= ext_floors - 1 or (f < ext_floors) else 0.0
			var pl := Rect2(o.x + ins, o.z + ins, W - ins * 2.0, D - ins * 2.0)
			k.slab_holes(pl, _yf(f, fh), 0.25, [shole, lhole], "off_slab")
	# --- interiors in the baked room light
	geo.light_fn = Callable(self, "_light")
	for f in range(n):
		var yf: float = _yf(f, fh)
		var rooms: Array = A_CORE + plans[f] if label == "Office A" else B_CORE + plans[f]
		var stage: String = stages[f]
		if stage == "fitted":
			_draw_walls(o, rooms, W, D, yf, ch)
			for r: Array in rooms:
				_furnish(o, r, yf, ch, f)
		elif stage == "stud":
			# core and WC solid, the rest as metal stud frames
			_draw_walls(o, rooms, W, D, yf, ch)
			_stud_extras(o, yf)
		else:
			_draw_walls(o, B_CORE, W, D, yf, ch)
			_bare_extras(o, W, D, yf, ch, fh, f == n - 1)
	# Stair and lift.
	k.stair_well(Vector3(stair_o.x, 0.12, stair_o.z), sw, sd, fh, n, "off_slab", north)
	geo.light_fn = Callable()
	geo.end_object()

func _stud_extras(o: Vector3, yf: float) -> void:
	# plasterboard stacked here and there, a stepladder, tools
	for i in range(4):
		var px: float = o.x + 2.0 + i * 4.6
		var pz: float = o.z + 5.3 if i % 2 == 0 else o.z + 10.7
		k.pallet(Vector3(px, yf, pz), rng.randf_range(-0.2, 0.2), 0.5, "board")

func _bare_extras(o: Vector3, W: float, D: float, yf: float, ch: float, fh: float, top: bool) -> void:
	# Columns round the open slab, props under the roof slab, pallets of board, edge posts and a rail.
	for p in [Vector2(0.25, 0.25), Vector2(10.0, 0.25), Vector2(19.75, 0.25), Vector2(0.25, 8.0), Vector2(19.75, 8.0), Vector2(0.25, 15.75), Vector2(10.0, 15.75), Vector2(19.75, 15.75)]:
		geo.box(Vector3(o.x + p.x, yf + ch * 0.5, o.z + p.y), Vector3(0.4, ch, 0.4), "concrete")
	k.props(Vector3(o.x + 3.0, yf, o.z + 5.3), Vector3(1.5, 0, 0), 5, 1.0, ch)
	k.props(Vector3(o.x + 3.0, yf, o.z + 10.7), Vector3(1.5, 0, 0), 5, 1.0, ch)
	k.props(Vector3(o.x + 15.0, yf, o.z + 13.0), Vector3(0, 0, -1.2), 4, 1.0, ch)
	for i in range(5):
		k.pallet(Vector3(o.x + 3.0 + i * 3.0, yf, o.z + 13.5), rng.randf_range(-0.3, 0.3), rng.randf_range(0.6, 1.2), "board" if i % 2 == 0 else "hoarding_w")
	for side in range(4):
		var along_x: bool = side < 2
		var s: float = 1.0 if side % 2 == 0 else -1.0
		var pos: Vector3 = Vector3(o.x + W * 0.5, yf + 0.55, o.z + D * 0.5 + s * (D * 0.5 - 0.1)) if along_x else Vector3(o.x + W * 0.5 + s * (W * 0.5 - 0.1), yf + 0.55, o.z + D * 0.5)
		geo.box(pos, Vector3(W, 1.0, 0.05) if along_x else Vector3(0.05, 1.0, D), "net", 0.0, false, false)

# --- Office A -------------------------------------------------------------------------------------------------

func _office_a() -> void:
	var o: Vector3 = A_O
	_plan_building("Office A", o, 24.0, 14.0, 3.2, A_FLOORS, ["fitted", "fitted", "fitted"], [0.0, 0.0, 3.0, 6.2, false], Rect2(3.0, 3.8, 2.0, 2.4),
		[["s", 2.0, 1.8]], 3, [["w", o.z + 7.0, 1.2], ["e", o.z + 7.0, 1.2]])
	# Entrance: a canopy over the door and the number.
	geo.box(Vector3(o.x + 2.9, 3.0, o.z + 14.0 + 0.6), Vector3(3.2, 0.12, 1.4), "off_trim")
	for sx in [-1.5, 1.5]:
		geo.cylinder(Vector3(o.x + 2.9 + sx, 0, o.z + 14.0 + 1.2), Vector3(o.x + 2.9 + sx, 3.0, o.z + 14.0 + 1.2), 0.05, "steel", 6)
	StreetKit._label(geo, "A", CampusKit.out_frame(Vector3(o.x + 2.9, 3.6, o.z + 14.0 + 0.03), Vector3(0, 0, 1)), 0.012, Color(0.1, 0.1, 0.1), 0.6)
	# On the roof: air conditioning, a roof-edge scaffold by the east end.
	for i in range(3):
		geo.box(Vector3(o.x + 12.0 + i * 3.0, _yf(3, 3.2) + 0.6, o.z + 7.0), Vector3(2.0, 1.2, 1.4), "steel")
	k.map.register_entrance(Vector3(o.x + 2.9, 0.0, o.z + 14.0 + 0.7), "office A door")

# --- Office B -------------------------------------------------------------------------------------------------

func _office_b() -> void:
	var o: Vector3 = B_O
	var plans: Array = [
		_b_ring("", {"s2": "Reception", "s3": "Entrance", "s4": "Post"}), _b_ring("", {"s2": "Office", "s3": "Office", "s4": "Print"}),
		_b_ring("stud", {"s2": "", "s4": ""}),
		[[0.0, 0.0, 20.0, 4.6, "bare slab", "shell", []], [0.0, 4.6, 4.6, 6.8, "bare", "shell", []], [15.4, 4.6, 4.6, 6.8, "bare", "shell", []], [0.0, 11.4, 20.0, 4.6, "bare slab", "shell", []]]]
	_plan_building("Office B", o, 20.0, 16.0, 3.2, plans, ["fitted", "fitted", "stud", "bare"], [6.0, 6.0, 3.5, 4.0, true], Rect2(9.5, 6.0, 2.0, 2.2),
		[["s", 9.0, 1.8]], 3, [])
	# Scaffold with sheeting on the east face, the hoist beside it.
	k.scaffold(Vector3(o.x + 20.0 + 0.25, 0, o.z + 8.0), 16.0, 7, true, 1.0)
	k.sheeting(Vector3(o.x + 20.0 + 0.25, 0, o.z + 8.0), 16.0, 7, true, 1.0, 0.25)
	k.hoist(Vector3(o.x + 20.0 + 4.2, 0, o.z + 2.0), 14.5, Vector3(-1, 0, 0), 4.0, 5.5)
	k.map.register_entrance(Vector3(o.x + 9.9, 0.0, o.z + 16.0 + 0.7), "office B door")
	StreetKit._label(geo, "B", CampusKit.out_frame(Vector3(o.x + 9.9, 3.6, o.z + 16.0 + 0.03), Vector3(0, 0, 1)), 0.012, Color(0.1, 0.1, 0.1), 0.6)

# --- Lab C and Canteen D (open floors) -----------------------------------------------------------------------------

## A shell with ribbon windows on all sides and storeys, a door, slabs with
## a stair and a lift opening, a flat roof with parapet. Returns the stair
## well origin. Walls in the default light, floors and furniture in room light.
func _open_shell(label: String, o: Vector3, W: float, D: float, fh: float, n: int, doors: Array, ribbon: bool) -> void:
	var y_roof: float = _yf(n, fh)
	var ch: float = fh - 0.3
	for side in ["n", "s", "w", "e"]:
		var holes: Array = []
		var L: float = W if side in ["n", "s"] else D
		var base: float = o.x if side in ["n", "s"] else o.z
		for f in range(n):
			var yf: float = _yf(f, fh)
			var bays: int = int(L / 4.0)
			for b in range(bays):
				var cc: float = base + (b + 0.5) * L / bays
				var skip: bool = false
				for d: Array in doors:
					if d[0] == side and absf(cc - (base + d[1])) < d[2] * 0.5 + 1.6 and (f == 0 or d[3]):
						skip = true
				if not skip:
					holes.append(Rect2(cc - 1.2, yf + 0.95, 2.4, 1.7 if ribbon else 1.3))
		for d: Array in doors:
			if d[0] == side:
				for f in range(n if d[3] else 1):
					holes.append(Rect2(base + d[1] - d[2] * 0.5, _yf(f, fh), d[2], 2.3))
		match side:
			"n":
				k.wall("x", o.z + 0.15, o.x, o.x + W, -0.1, y_roof + 0.8, 0.3, holes, "off_ext")
			"s":
				k.wall("x", o.z + D - 0.15, o.x, o.x + W, -0.1, y_roof + 0.8, 0.3, holes, "off_ext")
			"w":
				k.wall("z", o.x + 0.15, o.z + 0.3, o.z + D - 0.3, -0.1, y_roof + 0.8, 0.3, holes, "off_ext")
			"e":
				k.wall("z", o.x + W - 0.15, o.z + 0.3, o.z + D - 0.3, -0.1, y_roof + 0.8, 0.3, holes, "off_ext")

func _lab_c() -> void:
	var o: Vector3 = C_O
	var W: float = 22.0
	var D: float = 18.0
	var fh: float = 3.6
	var n: int = 3
	geo.begin_object("Lab C")
	_open_shell("Lab C", o, W, D, fh, n, [["n", 11.0, 1.8, false], ["e", 12.7, 1.2, true]], true)
	# Stair well at the west end (south side), lift beside it; core walls.
	var st := Vector3(o.x + 0.45, 0.0, o.z + 0.45)
	var sw: float = 2.9
	var sd: float = 6.0
	var lift := Rect2(o.x + 3.65, o.z + 0.45, 2.4, 2.4)
	var shole: Rect2 = k.stair_hole(st, sw, sd, fh, false)
	var lhole: Rect2 = lift
	var inner := Rect2(o.x + 0.3, o.z + 0.3, W - 0.6, D - 0.6)
	k.slab_holes(inner, _yf(n, fh), 0.25, [shole, lhole], "off_slab")
	for f in range(1, n):
		k.slab_holes(inner, _yf(f, fh), 0.25, [shole, lhole], "off_slab")
	geo.box(Vector3(o.x + W * 0.5, -0.04, o.z + D * 0.5), Vector3(W - 0.6, 0.32, D - 0.6), "off_slab")
	geo.light_fn = Callable(self, "_light")
	var ch: float = fh - 0.3
	# core walls per floor: stair (west) and lift
	for f in range(n):
		var yf: float = _yf(f, fh)
		var sdoor: Array = [Rect2(st.x + 1.0, yf, 1.0, 2.1)]
		k.wall("x", st.z + sd + 0.15, st.x - 0.15, st.x + sw + 0.15, yf, yf + ch, 0.3, sdoor, "off_slab")
		k.wall("z", st.x + sw + 0.15, st.z, st.z + sd, yf, yf + ch, 0.3, [], "off_slab")
		k.wall("x", lift.end.y + 0.15, lift.position.x - 0.0, lift.end.x + 0.15, yf, yf + ch, 0.3, [Rect2(lift.position.x + 0.7, yf, 1.0, 2.1)], "off_slab")
		k.wall("z", lift.end.x + 0.15, lift.position.y, lift.end.y, yf, yf + ch, 0.3, [], "off_slab")
		# Benches in rows, fume cupboards along the south wall, a central shelf.
		for row in range(3):
			for col in range(3):
				var bx: float = o.x + 8.0 + col * 4.4
				var bz: float = o.z + 4.4 + row * 3.8
				_bx(bx, yf, bz, 3.4, 0.9, 1.1, "white_goods", Color(0.85, 0.88, 0.9))
				_bx(bx, yf + 0.9, bz, 3.5, 0.04, 1.2, "desk", Color(0.5, 0.55, 0.6))
				_bx(bx - 0.9, yf + 0.94, bz, 0.4, 0.5, 0.3, "chair")
				_bx(bx + 0.9, yf + 0.94, bz, 0.3, 0.25, 0.3, "screen_on", Color(0.7, 0.9, 1.0), 0.0, false)
		for i in range(5):
			_bx(o.x + 7.0 + i * 2.8, yf, o.z + D - 0.9, 2.2, 2.3, 0.8, "white_goods", Color(0.8, 0.85, 0.8))
		for i in range(8):
			geo.box(Vector3(o.x + 4.0 + i * 2.2, yf + ch - 0.06, o.z + D * 0.5), Vector3(1.0, 0.06, 0.3), "lamp", 0.0, false, false)
	k.stair_well(Vector3(st.x, 0.12, st.z), sw, sd, fh, n, "off_slab", false)
	geo.light_fn = Callable()
	# The outside stair tower on the east face: a steel stair zig-zagging up round a landing at each floor.
	var sx0: float = o.x + W + 0.1
	var sz0: float = o.z + 12.4
	for f in range(n):
		var y0: float = _yf(f, fh)
		var yh: float = y0 + fh * 0.5
		geo.beam(Vector3(sx0 + 0.6, y0 - 0.05, sz0 - 0.5), Vector3(sx0 + 0.6, yh - 0.05, sz0 - 3.5), Vector2(1.1, 0.12), "steel")
		geo.box(Vector3(sx0 + 1.0, yh - 0.05, sz0 - 3.8), Vector3(2.0, 0.1, 1.4), "steel")
		geo.beam(Vector3(sx0 + 1.5, yh - 0.05, sz0 - 3.5), Vector3(sx0 + 1.5, y0 + fh - 0.05, sz0 - 0.5), Vector2(1.1, 0.12), "steel")
		geo.box(Vector3(sx0 + 1.0, y0 + fh - 0.05, sz0 + 0.3), Vector3(2.0, 0.1, 1.6), "steel")
		for e in [-1.0, 1.0]:
			geo.cylinder(Vector3(sx0 + 1.0 + e * 0.95, y0, sz0 + 0.8), Vector3(sx0 + 1.0 + e * 0.95, y0 + fh, sz0 + 0.8), 0.05, "steel", 6)
	for f in range(n):
		geo.box(Vector3(sx0 + 1.0, _yf(f + 1, fh) + 0.55, sz0 + 1.05), Vector3(2.0, 0.05, 0.05), "tape", 0.0, false, false)
	geo.box(Vector3(sx0 + 1.0, 0.05, sz0 + 0.3), Vector3(2.0, 0.1, 1.6), "steel")
	# Roof deck: rail, AC units; a gnome? no - a vent stack.
	for i in range(3):
		geo.box(Vector3(o.x + 6.0 + i * 5.0, _yf(n, fh) + 0.5, o.z + 14.0), Vector3(2.4, 1.0, 1.6), "steel")
	StreetKit._label(geo, "Labor C", CampusKit.out_frame(Vector3(o.x + 11.0, _yf(n, fh) + 0.4, o.z - 0.03), Vector3(0, 0, -1)), 0.01, Color(0.1, 0.1, 0.1), 3.0)
	geo.end_object()
	k.map.register_entrance(Vector3(o.x + 11.0, 0.0, o.z - 0.8), "lab north door")
	k.map.register_entrance(Vector3(sx0 + 1.0, 0.0, sz0 + 1.6), "lab stair tower")

func _canteen_d() -> void:
	var o: Vector3 = D_O
	var W: float = 30.0
	var D: float = 18.0
	var fh: float = 4.0
	var n: int = 2
	geo.begin_object("Canteen D")
	_open_shell("Canteen D", o, W, D, fh, n, [["n", 15.0, 2.4, false]], true)
	var st := Vector3(o.x + 0.45, 0.0, o.z + 11.55)
	var sw: float = 2.9
	var sd: float = 6.0
	var lift := Rect2(o.x + 3.65, o.z + 15.0, 2.4, 2.4)
	var shole: Rect2 = k.stair_hole(st, sw, sd, fh, true)
	var inner := Rect2(o.x + 0.3, o.z + 0.3, W - 0.6, D - 0.6)
	k.slab_holes(inner, _yf(2, fh), 0.25, [shole, lift], "off_slab")
	k.slab_holes(inner, _yf(1, fh), 0.25, [shole, lift], "off_slab")
	geo.box(Vector3(o.x + W * 0.5, -0.04, o.z + D * 0.5), Vector3(W - 0.6, 0.32, D - 0.6), "off_slab")
	geo.light_fn = Callable(self, "_light")
	var ch: float = fh - 0.3
	for f in range(n):
		var yf: float = _yf(f, fh)
		# stair well walls (entry at the north end) and the lift
		k.wall("x", st.z - 0.15, st.x - 0.15, st.x + sw + 0.15, yf, yf + ch, 0.3, [Rect2(st.x + 1.0, yf, 1.0, 2.1)], "off_slab")
		k.wall("z", st.x + sw + 0.15, st.z, st.z + sd, yf, yf + ch, 0.3, [], "off_slab")
		k.wall("x", lift.position.y - 0.15, lift.position.x - 0.0, lift.end.x + 0.15, yf, yf + ch, 0.3, [Rect2(lift.position.x + 0.7, yf, 1.0, 2.1)], "off_slab")
		k.wall("z", lift.end.x + 0.15, lift.position.y, lift.end.y, yf, yf + ch, 0.3, [], "off_slab")
		# Dining hall: tables with four chairs in rows.
		for row in range(4):
			for col in range(6):
				var tx: float = o.x + 11.5 + col * 3.0
				var tz: float = o.z + 3.0 + row * 3.6
				_bx(tx, yf + 0.72, tz, 1.4, 0.05, 0.8, "desk")
				_bx(tx, yf, tz, 0.15, 0.72, 0.15, "desk")
				for sx in [-0.5, 0.5]:
					for sz in [-0.6, 0.6]:
						_bx(tx + sx, yf, tz + sz, 0.4, 0.45, 0.4, "chair")
		for i in range(7):
			geo.box(Vector3(o.x + 8.0 + i * 3.0, yf + ch - 0.06, o.z + D * 0.5), Vector3(1.2, 0.06, 0.3), "lamp", 0.0, false, false)
	# Kitchen at the west end of the ground floor: counters, a cooker island, serving line.
	var y0: float = _yf(0, fh)
	geo.light_fn = Callable(self, "_light")
	_bx(o.x + 7.0, y0, o.z + 6.0, 1.2, 0.9, 7.0, "white_goods")
	_bx(o.x + 7.0, y0 + 0.9, o.z + 6.0, 1.3, 0.1, 7.2, "stud")
	for i in range(4):
		_bx(o.x + 3.5, y0, o.z + 1.5 + i * 1.5, 2.2, 0.9, 1.0, "white_goods")
		_bx(o.x + 3.5, y0 + 0.9, o.z + 1.5 + i * 1.5, 2.3, 0.05, 1.1, "stud")
	for i in range(3):
		_bx(o.x + 9.0, y0, o.z + 3.0 + i * 1.6, 0.8, 1.7, 0.8, "white_goods", Color(0.9, 0.9, 0.95))
	geo.light_fn = Callable()
	k.stair_well(Vector3(st.x, 0.12, st.z), sw, sd, fh, n, "off_slab", true)
	for i in range(2):
		geo.box(Vector3(o.x + 10.0 + i * 8.0, _yf(n, fh) + 0.7, o.z + 4.0), Vector3(3.0, 1.4, 2.0), "steel")
	geo.cylinder(Vector3(o.x + 5.0, _yf(n, fh), o.z + 3.0), Vector3(o.x + 5.0, _yf(n, fh) + 6.0, o.z + 3.0), 0.5, "steel", 10)
	StreetKit._label(geo, "Kantine", CampusKit.out_frame(Vector3(o.x + 15.0, _yf(n, fh) + 0.4, o.z - 0.03), Vector3(0, 0, -1)), 0.01, Color(0.1, 0.1, 0.1), 5.0)
	geo.end_object()
	k.map.register_entrance(Vector3(o.x + 15.0, 0.0, o.z - 0.7), "canteen north door")
