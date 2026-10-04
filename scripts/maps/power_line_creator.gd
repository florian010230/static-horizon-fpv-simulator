class_name PowerLineCreator
extends RefCounted

## Creator: an overhead power line along a course the map lays out by
## hand (corner points, like a road's) - wooden poles for the village
## supply or steel lattice pylons for a high-voltage line across the
## valley. Masts stand at every corner and evenly between, stepping
## aside off roads and water; the wires sag between them as real ones
## do. Wires and masts are solid: threading between the conductors is
## the challenge.
##
##   PowerLineCreator.build(geo, land, course, kind, opts) -> {"views": [...]}
## course: Vector2 corners (x, z); kind: "poles" | "pylons".
## opts: span (m between masts), end_into (a Vector3 the last wire runs
## to - a barn wall - instead of ending at the last pole).
## Real numbers: 20 kV wooden poles ~10 m tall, spans 40-60 m, sag
## ~0.5 m; 110/220 kV lattice towers 30-45 m, spans 250-350 m, sag 6-9 m.

const KINDS := {
	"poles": {"span": 45.0, "sag": 0.55, "wire": 0.03},
	"pylons": {"span": 290.0, "sag": 7.5, "wire": 0.06},
}

static func ensure_materials(g: Geo) -> void:
	if g.has_material("pl_wire"):
		return
	g.add_material("pl_wire", Geo.flat_mat(Color(0.16, 0.16, 0.17), 0.5, 0.5))
	g.add_material("pl_pole", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.55, 0.45, 0.36), 1.5))
	g.add_material("pl_steel", Geo.flat_mat(Color(0.55, 0.58, 0.6), 0.5, 0.5))
	g.add_material("pl_concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.9, 0.9, 0.88), 3.0))
	g.add_material("pld_glass", Geo.flat_mat(Color(0.75, 0.82, 0.78), 0.2, 0.2))
	g.detail_prefixes.append("pld_")

static func build(g: Geo, land: TerrainCreator, course: Array, kind: String, opts: Dictionary = {}) -> Dictionary:
	ensure_materials(g)
	var spec: Dictionary = KINDS[kind]
	var span: float = opts.get("span", spec.span)
	# Mast positions: every corner, and evenly between.
	var spots: Array = []
	for i in range(course.size() - 1):
		var a: Vector2 = course[i]
		var b: Vector2 = course[i + 1]
		var n: int = maxi(1, roundi(a.distance_to(b) / span))
		for k in range(n):
			spots.append(a.lerp(b, float(k) / n))
	spots.append(course[course.size() - 1])
	# Off roads, rivers and anything standing there: step along the line.
	for i in range(spots.size()):
		var q: Vector2 = spots[i]
		var dir: Vector2 = ((spots[mini(i + 1, spots.size() - 1)] as Vector2) - (spots[maxi(i - 1, 0)] as Vector2)).normalized()
		for tries in range(10):
			var bad: bool = land.on_line(q.x, q.y, 4.0 if kind == "pylons" else 1.5) or g.blocked(q, 1.0, _ground(land, q) + 0.2, _ground(land, q) + 6.0)
			if not bad:
				break
			q = (spots[i] as Vector2) + dir * (3.0 + tries * 3.0) * (1.0 if tries % 2 == 0 else -1.0)
		spots[i] = q
	# Each mast: turned to the bisector of the line through it.
	var attach: Array = [] # per mast: Array of Vector3 (one per wire)
	for i in range(spots.size()):
		var q: Vector2 = spots[i]
		var d_in: Vector2 = (q - (spots[i - 1] as Vector2)).normalized() if i > 0 else ((spots[1] as Vector2) - q).normalized()
		var d_out: Vector2 = ((spots[i + 1] as Vector2) - q).normalized() if i < spots.size() - 1 else d_in
		var along: Vector2 = (d_in + d_out).normalized()
		var p := Vector3(q.x, _ground(land, q), q.y)
		var yaw: float = atan2(along.x, along.y) # local +z along the line
		var turn: float = absf(d_in.angle_to(d_out))
		if kind == "poles":
			attach.append(_pole(g, land, p, yaw, turn, d_in, d_out))
		else:
			attach.append(_pylon(g, p, yaw))
	# Wires between neighbouring masts.
	var wires: int = (attach[0] as Array).size()
	for i in range(spots.size() - 1):
		for w in range(wires):
			_wire(g, attach[i][w], attach[i + 1][w], spec.sag * pow((attach[i][w] as Vector3).distance_to(attach[i + 1][w]) / span, 2.0), spec.wire)
	if opts.has("end_into"):
		var e: Vector3 = opts.end_into
		for w in range(mini(wires, 2)):
			_wire(g, attach[spots.size() - 1][w], e + Vector3(0, 0, (w - 0.5) * 0.4), 0.3, spec.wire)
	var views: Array = []
	if spots.size() > 2:
		var m: Vector2 = spots[spots.size() / 2]
		var nx: Vector2 = spots[spots.size() / 2 + 1]
		var side: Vector2 = Vector2(-(nx - m).y, (nx - m).x).normalized()
		var h: float = 9.0 if kind == "poles" else 26.0
		var eye: Vector2 = m.lerp(nx, 0.5) + side * (12.0 if kind == "poles" else 40.0)
		views.append(["line_" + kind, Vector3(eye.x, _ground(land, eye) + h * 0.6, eye.y), Vector3(m.x, _ground(land, m) + h * 0.8, m.y)])
		# Close to one mast, looking up past it along the wires.
		var near: Vector2 = m + side * (4.0 if kind == "poles" else 14.0) - (nx - m).normalized() * (6.0 if kind == "poles" else 22.0)
		views.append(["mast_" + kind, Vector3(near.x, _ground(land, near) + h * 0.35, near.y), Vector3(m.x, _ground(land, m) + h * 0.75, m.y)])
	return {"views": views}

static func _ground(land: TerrainCreator, q: Vector2) -> float:
	return land.visible_ground(q.x, q.y)

## A wooden pole with a crossarm and three insulators; at a corner a
## stay wire to the ground on the outside of the turn. Returns the
## three wire points.
static func _pole(g: Geo, land: TerrainCreator, p: Vector3, yaw: float, turn: float, d_in: Vector2, d_out: Vector2) -> Array:
	var h: float = 9.6
	var foot: float = g.sunk([p], p.y) - 1.0
	g.cone(Vector3(p.x, foot, p.z), p + Vector3(0, h, 0), 0.16, 0.12, "pl_pole", 8)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, h - 0.6, 0)), Vector3(1.9, 0.12, 0.12), "pl_pole")
	var pts: Array = []
	for x in [-0.85, 0.85]:
		var base: Vector3 = xf * Vector3(x, h - 0.54, 0)
		g.cylinder(base, base + Vector3(0, 0.22, 0), 0.05, "pld_glass", 8, false)
		pts.append(base + Vector3(0, 0.22, 0))
	var top: Vector3 = p + Vector3(0, h, 0)
	g.cylinder(top, top + Vector3(0, 0.22, 0), 0.05, "pld_glass", 8, false)
	pts.insert(1, top + Vector3(0, 0.22, 0))
	if turn > 0.25:
		# The stay: from near the top out to the ground, away from the bend.
		var out: Vector2 = (d_in - d_out).normalized()
		var anchor := Vector2(p.x, p.z) + out * 6.5
		var ay: float = land.visible_ground(anchor.x, anchor.y) - 0.3
		g.beam(p + Vector3(0, h - 1.0, 0), Vector3(anchor.x, ay, anchor.y), Vector2(0.025, 0.025), "pl_wire")
	return pts

## A steel lattice tower (four legs tapering in, cross-braced faces, two
## crossarms and an earth-wire peak). Returns the seven wire points:
## three each side, then the earth wire.
static func _pylon(g: Geo, p: Vector3, yaw: float) -> Array:
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var H: float = 36.0
	var levels: Array = [0.0, 6.0, 11.5, 16.5, 21.0, 25.0, 29.0, 33.0] # section breaks
	var half_at := func(y: float) -> float:
		return lerpf(3.4, 0.9, pow(clampf(y / 25.0, 0.0, 1.0), 0.8)) if y < 25.0 else 0.9
	var lowest: float = INF
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var q: Vector3 = xf * Vector3(sx * half_at.call(0.0), 0, sz * half_at.call(0.0))
			lowest = minf(lowest, g.sunk([q], p.y))
	var c := func(sx: float, sz: float, y: float) -> Vector3:
		var hw: float = half_at.call(y)
		return xf * Vector3(sx * hw, y, sz * hw)
	# Concrete feet, the legs.
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var f: Vector3 = c.call(sx, sz, 0.0)
			g.box(Vector3(f.x, (lowest + p.y + 0.4) * 0.5 - 0.2, f.z), Vector3(0.9, p.y + 0.4 - lowest + 0.4, 0.9), "pl_concrete", yaw)
			for k in range(levels.size() - 1):
				g.beam(c.call(sx, sz, levels[k] + (0.3 if k == 0 else 0.0)), c.call(sx, sz, levels[k + 1]), Vector2(0.22, 0.22), "pl_steel")
			g.beam(c.call(sx, sz, levels[-1]), xf * Vector3(0, H, 0), Vector2(0.18, 0.18), "pl_steel")
	# Faces: a ring at each break and an X in each section.
	var faces: Array = [[Vector2(-1, -1), Vector2(1, -1)], [Vector2(1, -1), Vector2(1, 1)], [Vector2(1, 1), Vector2(-1, 1)], [Vector2(-1, 1), Vector2(-1, -1)]]
	for k in range(1, levels.size()):
		for f: Array in faces:
			var a: Vector2 = f[0]
			var b: Vector2 = f[1]
			g.beam(c.call(a.x, a.y, levels[k]), c.call(b.x, b.y, levels[k]), Vector2(0.12, 0.12), "pl_steel")
			g.beam(c.call(a.x, a.y, levels[k - 1] + 0.3), c.call(b.x, b.y, levels[k]), Vector2(0.08, 0.08), "pl_steel", true, false)
			g.beam(c.call(b.x, b.y, levels[k - 1] + 0.3), c.call(a.x, a.y, levels[k]), Vector2(0.08, 0.08), "pl_steel", true, false)
	# Crossarms across the line (local x): lower one wide, upper narrower.
	var pts: Array = [[], []]
	for arm: Array in [[21.0, 9.0], [29.0, 6.5]]:
		var y: float = arm[0]
		var reach: float = arm[1]
		for s in [-1.0, 1.0]:
			var tip: Vector3 = xf * Vector3(s * reach, y, 0)
			for sz in [-1.0, 1.0]:
				g.beam(c.call(s, sz, y), tip, Vector2(0.14, 0.14), "pl_steel")
				g.beam(c.call(s, sz, y - 2.5), tip, Vector2(0.09, 0.09), "pl_steel", true, false)
			# Insulator strings hanging from the arm: two on the wide arm.
			var hang: Array = [reach, reach * 0.55] if arm[1] > 8.0 else [reach]
			for r: float in hang:
				var top: Vector3 = xf * Vector3(s * r, y, 0)
				var bottom: Vector3 = top + Vector3(0, -2.6, 0)
				g.cylinder(top, bottom, 0.14, "pld_glass", 8, false)
				pts[0 if s < 0.0 else 1].append(bottom)
	var out: Array = []
	out.append_array(pts[0])
	out.append_array(pts[1])
	out.append(xf * Vector3(0, H, 0))
	return out

## One wire from a to b, hanging in a parabola `sag` deep at its middle.
static func _wire(g: Geo, a: Vector3, b: Vector3, sag: float, thick: float) -> void:
	var n: int = clampi(int(a.distance_to(b) / 8.0), 4, 24)
	var prev: Vector3 = a
	for k in range(1, n + 1):
		var t: float = float(k) / n
		var q: Vector3 = a.lerp(b, t) - Vector3(0, sag * 4.0 * t * (1.0 - t), 0)
		g.beam(prev, q, Vector2(thick, thick), "pl_wire", true, false)
		prev = q
