class_name StreetLampCreator
extends RefCounted

## Street lamps (2026-10-14, user: "1-2 or more good models, then use
## them everywhere"). Three kinds, each one piece from the footing up -
## every part touching the next, all solid (a drone hits the arm and the
## head, not just the mast):
##   "led"     - modern road light: galvanised conical mast 8 m, a slim
##               arm tilted up 5 degrees, a flat LED head (the common
##               German road luminaire of the 2010s/20s, ~0.6 m long).
##   "whip"    - the classic Peitschenmast: one tapering tube 9 m tall
##               that bends over in an arc to the head - main roads.
##   "village" - Mastaufsatzleuchte: a 4.5 m anthracite post (RAL 7016)
##               with a cast foot and a four-sided lantern - residential
##               streets, squares, paths.
## Heights follow DIN EN 13201 practice: 4-6 m residential, 8-10 m main
## roads.
##   StreetLampCreator.build(geo, foot, toward, kind)
## `foot` on the ground (the footing reaches into it, Geo.sunk), `toward`
## the direction the light reaches out over the road.

const KINDS: Array[String] = ["led", "whip", "village"]

static func ensure_materials(g: Geo) -> void:
	if g.has_material("sl_steel"):
		return
	g.add_material("sl_steel", Geo.flat_mat(Color(0.62, 0.64, 0.66), 0.45, 0.6))
	g.add_material("sl_dark", Geo.flat_mat(Color(0.22, 0.24, 0.26), 0.5, 0.4))
	g.add_material("sl_concrete", Geo.flat_mat(Color(0.6, 0.6, 0.58), 0.9))
	g.add_material("sl_led", Geo.flat_mat(Color(0.95, 0.96, 0.92), 0.2))
	g.add_material("sl_glass", Geo.flat_mat(Color(0.98, 0.93, 0.78), 0.1))
	g.detail_prefixes.append("sl_")

static func build(g: Geo, foot: Vector3, toward: Vector3, kind: String = "led") -> void:
	ensure_materials(g)
	var t: Vector3 = Vector3(toward.x, 0, toward.z).normalized()
	if t.length() < 0.5:
		t = Vector3.FORWARD
	# (Not a layout object: its arm reaches over the road on purpose.)
	match kind:
		"whip":
			_whip(g, foot, t)
		"village":
			_village(g, foot, t)
		_:
			_led(g, foot, t)

## The footing: a concrete collar round the mast, down into the ground.
static func _footing(g: Geo, foot: Vector3, r: float) -> float:
	var y0: float = g.sunk([foot], foot.y)
	# (Its top stands clear of the ground: flush, it flickered - 2026-10-14.)
	var top: float = maxf(foot.y, y0 + Geo.SINK) + 0.12
	g.cylinder(Vector3(foot.x, y0 - 0.2, foot.z), Vector3(foot.x, top, foot.z), r, "sl_concrete", 10)
	return top

static func _led(g: Geo, foot: Vector3, t: Vector3) -> void:
	var y: float = _footing(g, foot, 0.22)
	var H: float = 8.0
	# Base flange and the mast's door panel, then the conical mast.
	g.cylinder(Vector3(foot.x, y, foot.z), Vector3(foot.x, y + 0.25, foot.z), 0.16, "sl_steel", 10)
	g.cone(Vector3(foot.x, y + 0.25, foot.z), Vector3(foot.x, foot.y + H, foot.z), 0.11, 0.055, "sl_steel", 10)
	g.box(Vector3(foot.x, y + 0.9, foot.z) - t * 0.1, Vector3(0.08, 0.35, 0.04), "sl_steel", atan2(t.x, t.z))
	# The arm: from just under the top, out 1.8 m and up 5 degrees.
	var a0: Vector3 = foot + Vector3(0, H - 0.15, 0)
	var a1: Vector3 = a0 + t * 1.8 + Vector3(0, 1.8 * tan(deg_to_rad(5.0)), 0)
	g.cylinder(a0, a1, 0.04, "sl_steel", 8)
	# The head: a flat body sloping with the arm, the LED panel under it.
	var yaw: float = atan2(t.x, t.z)
	var hc: Vector3 = a1 + t * 0.28 - Vector3(0, 0.02, 0)
	g.box_xf(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -deg_to_rad(5.0)), hc), Vector3(0.3, 0.09, 0.66), "sl_steel")
	g.box_xf(Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, -deg_to_rad(5.0)), hc - Vector3(0, 0.05, 0)), Vector3(0.24, 0.02, 0.52), "sl_led")

static func _whip(g: Geo, foot: Vector3, t: Vector3) -> void:
	var y: float = _footing(g, foot, 0.24)
	var H: float = 9.0
	var R: float = 1.6 # the bend's radius
	g.cylinder(Vector3(foot.x, y, foot.z), Vector3(foot.x, y + 0.3, foot.z), 0.17, "sl_steel", 10)
	# Straight up to where the bend starts, tapering...
	var top: Vector3 = foot + Vector3(0, H - R, 0)
	g.cone(Vector3(foot.x, y + 0.3, foot.z), top, 0.12, 0.07, "sl_steel", 10)
	# ...then a quarter circle over toward the road, in short pieces.
	var prev: Vector3 = top
	var n: int = 8
	for k in range(1, n + 1):
		var a: float = PI * 0.5 * k / n
		var q: Vector3 = top + t * (R - R * cos(a)) + Vector3(0, R * sin(a), 0)
		g.cylinder(prev, q, 0.065, "sl_steel", 8)
		prev = q
	# A short straight to the head, dipping a little.
	var end: Vector3 = prev + t * 0.6 - Vector3(0, 0.05, 0)
	g.cylinder(prev, end, 0.06, "sl_steel", 8)
	var yaw: float = atan2(t.x, t.z)
	var hc: Vector3 = end + t * 0.32 - Vector3(0, 0.03, 0)
	g.box_xf(Transform3D(Basis(Vector3.UP, yaw), hc), Vector3(0.34, 0.12, 0.72), "sl_steel")
	g.box_xf(Transform3D(Basis(Vector3.UP, yaw), hc - Vector3(0, 0.065, 0)), Vector3(0.26, 0.02, 0.56), "sl_led")

static func _village(g: Geo, foot: Vector3, t: Vector3) -> void:
	var y: float = _footing(g, foot, 0.2)
	var H: float = 4.5
	var yaw: float = atan2(t.x, t.z)
	# A cast foot (wider, stepped), the post, a collar under the lantern.
	g.cone(Vector3(foot.x, y, foot.z), Vector3(foot.x, y + 0.7, foot.z), 0.17, 0.08, "sl_dark", 10)
	g.cylinder(Vector3(foot.x, y + 0.7, foot.z), Vector3(foot.x, foot.y + H - 0.1, foot.z), 0.06, "sl_dark", 10)
	g.cylinder(Vector3(foot.x, foot.y + H - 0.1, foot.z), Vector3(foot.x, foot.y + H, foot.z), 0.11, "sl_dark", 10)
	# The lantern: glass widening upward, a dark frame at each corner, a
	# hipped cap and a finial.
	var b: Vector3 = foot + Vector3(0, H, 0)
	var rot := Basis(Vector3.UP, yaw + PI * 0.25)
	g.frustum(Transform3D(rot, b + Vector3(0, 0.3, 0)), Vector3(0.24, 0.6, 0.24), 0.4, 0.4, 0.0, "sl_glass")
	for k in range(4):
		var c: Vector3 = rot * Vector3((1.0 if k & 1 else -1.0), 0, (1.0 if k & 2 else -1.0))
		g.beam(b + c * 0.12, b + c * 0.2 + Vector3(0, 0.6, 0), Vector2(0.03, 0.03), "sl_dark")
	g.box_xf(Transform3D(rot, b + Vector3(0, 0.62, 0)), Vector3(0.46, 0.05, 0.46), "sl_dark")
	g.frustum(Transform3D(rot, b + Vector3(0, 0.75, 0)), Vector3(0.46, 0.22, 0.46), 0.08, 0.08, 0.0, "sl_dark")
	g.cylinder(b + Vector3(0, 0.86, 0), b + Vector3(0, 1.0, 0), 0.025, "sl_dark", 6)
