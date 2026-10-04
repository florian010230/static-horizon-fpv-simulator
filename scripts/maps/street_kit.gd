class_name StreetKit
extends RefCounted

## Street furniture: the small things that make a village look lived in.
## Each is a static call the map (or another creator) makes where it
## wants one; sizes are the real German ones.
##
##   StreetKit.give_way(geo, branch)            a sign where a branch meets its main road
##   StreetKit.town_sign(geo, road, d, name)    yellow place-name board, facing traffic at d
##   StreetKit.bus_stop(geo, road, d, side, name)   shelter, bench, the "H" sign, a bin
##   StreetKit.post_box(geo, p, yaw)            yellow letter box on a post
##   StreetKit.bin(geo, p, yaw)                 litter bin on a post
##   StreetKit.wheelie_bins(geo, p, yaw, n, rng)   household bins side by side
##   StreetKit.notice_board(geo, p, yaw)        village notice board with a little roof
## Road-side things stand beyond the verge, on the real ground (Geo.sunk).
## Text (place names, the bus stop's H) is a Label3D - the project's font,
## added when the geo commits.

const SIGN_H: float = 2.1 ## bottom edge of a road sign over the ground

static func ensure_materials(g: Geo) -> void:
	if g.has_material("sk_paint"):
		return
	g.add_material("sk_paint", Geo.flat_mat(Color.WHITE, 0.5))
	g.add_material("sk_steel", Geo.flat_mat(Color(0.62, 0.64, 0.66), 0.4, 0.6))
	g.add_material("sk_glass", Geo.flat_mat(Color(0.55, 0.65, 0.7), 0.1, 0.3))
	g.add_material("sk_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(0.85, 0.7, 0.55), 1.2))
	g.detail_prefixes.append("sk_")

## Labels to add when the geo commits: [text, transform, pixel size, colour].
static func _label(g: Geo, text: String, xf: Transform3D, px: float, col: Color) -> void:
	if not g.has_meta("sk_labels"):
		var list: Array = []
		g.set_meta("sk_labels", list)
		g.on_commit.append(func(holder: Node3D) -> void:
			for e: Array in list:
				var lb := Label3D.new()
				lb.text = e[0]
				lb.font = UIKit.oswald_font()
				lb.font_size = 64
				lb.outline_size = 0
				lb.modulate = e[3]
				lb.pixel_size = e[2]
				lb.transform = e[1]
				lb.double_sided = false
				lb.visibility_range_end = Geo.DETAIL_RANGE
				lb.set_meta("geo_detail", true)
				holder.add_child(lb)
			g.remove_meta("sk_labels"))
	(g.get_meta("sk_labels") as Array).append([text, xf, px, col])

## A post from the ground at p (x, z of p; its foot reaching into the
## real ground) up to height top over p.y.
static func _post(g: Geo, p: Vector3, top: float, r: float = 0.04, mat: String = "sk_steel") -> void:
	var foot: float = g.sunk([p], p.y)
	g.cylinder(Vector3(p.x, foot, p.z), p + Vector3(0, top, 0), r, mat, 8)

## Where a road's side is, d m along it: [ground point beyond the verge,
## direction of travel, right].
static func _roadside(road: RoadCreator, d: float, side: float, extra: float = 0.0) -> Array:
	var r: Route = Route.from_pts(road.line.pts)
	var s: Array = r.sample(clampf(d, 0.0, r.length()))
	var p: Vector3 = s[0]
	var t: Vector3 = s[1]
	var right := Vector3(-t.z, 0, t.x)
	var q: Vector3 = p + right * side * (road.line.half + road.opts.get("verge", 1.0) + 0.8 + extra)
	q.y = road.land.ground(q.x, q.z) if road.land != null else p.y
	return [q, t, right]

## The give-way sign (a red-rimmed white triangle, point down) on the
## right of a branch, just before its give-way line.
static func give_way(g: Geo, branch: RoadCreator) -> void:
	ensure_materials(g)
	var pts: Array[Vector3] = branch.line.pts
	var t0: Vector3 = (pts[1] - pts[0]).normalized() # away from the main road
	var drive: Vector3 = -t0 # a driver coming to the junction
	var right := Vector3(-drive.z, 0, drive.x)
	var p: Vector3 = pts[0] + t0 * 2.0 + right * (branch.line.half + branch.opts.get("verge", 1.0) + 0.6)
	p.y = branch.land.ground(p.x, p.z)
	_post(g, p, SIGN_H + 0.95, 0.04)
	# The plate faces the driver (+t0); a triangle point down, 0.9 m a side.
	var yaw: float = atan2(t0.x, t0.z)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, SIGN_H + 0.5, 0) + t0 * 0.06)
	g.tint = Color(0.8, 0.08, 0.08)
	g.prism(xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), [Vector2(-0.48, 0.28), Vector2(0.48, 0.28), Vector2(0, -0.55)], 0.03, "sk_paint", false)
	g.tint = Color(0.96, 0.96, 0.95)
	# (In the turned frame the extrusion axis x points away from the driver.)
	g.prism(xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(-0.025, 0, 0)), [Vector2(-0.33, 0.2), Vector2(0.33, 0.2), Vector2(0, -0.37)], 0.03, "sk_paint", false)
	g.tint = Color.WHITE

## The yellow place-name board (Ortstafel) at d along the road, on the
## right of traffic driving in `dir` (+1 along the road, -1 against it):
## black border, the name, the district below it in small letters.
static func town_sign(g: Geo, road: RoadCreator, d: float, dir: float, town: String, district: String = "") -> Array:
	ensure_materials(g)
	var rs: Array = _roadside(road, d, dir, 0.4)
	var p: Vector3 = rs[0]
	var t: Vector3 = (rs[1] as Vector3) * dir
	var right := Vector3(-t.z, 0, t.x)
	# Two posts; the board faces the oncoming driver (-t).
	for k in [-0.55, 0.55]:
		var q: Vector3 = p + right * k
		q.y = road.land.ground(q.x, q.z)
		_post(g, q, SIGN_H + 0.75, 0.035)
	var yaw: float = atan2(-t.x, -t.z)
	var b := Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, SIGN_H + 0.4, 0))
	g.tint = Color(1.0, 0.82, 0.05)
	g.box_xf(b, Vector3(1.6, 0.8, 0.04), "sk_paint", false)
	g.tint = Color(0.06, 0.06, 0.06)
	for e: Array in [[Vector3(0, 0.33, 0.025), Vector3(1.5, 0.03, 0.01)], [Vector3(0, -0.33, 0.025), Vector3(1.5, 0.03, 0.01)],
			[Vector3(-0.73, 0, 0.025), Vector3(0.03, 0.69, 0.01)], [Vector3(0.73, 0, 0.025), Vector3(0.03, 0.69, 0.01)]]:
		g.box_xf(b * Transform3D(Basis(), e[0]), e[1], "sk_paint", false)
	g.tint = Color.WHITE
	_label(g, town, b * Transform3D(Basis(), Vector3(0, 0.06 if district != "" else 0.0, 0.035)), 0.0075, Color(0.05, 0.05, 0.05))
	if district != "":
		_label(g, district, b * Transform3D(Basis(), Vector3(0, -0.2, 0.035)), 0.0032, Color(0.05, 0.05, 0.05))
	return [["town_sign", b * Vector3(-1.5, 0.0, 9.0), b.origin]]

## A bus stop at d along the road on `side`: a lay-by of paving, a glass
## shelter with a bench, the green-and-yellow H sign with the stop's
## name, and a litter bin.
static func bus_stop(g: Geo, road: RoadCreator, d: float, side: float, stop_name: String) -> Array:
	ensure_materials(g)
	var rs: Array = _roadside(road, d, side, 1.6)
	var p: Vector3 = rs[0]
	var t: Vector3 = rs[1]
	var out: Vector3 = (rs[2] as Vector3) * side # away from the road
	var yaw: float = atan2(-out.x, -out.z) # local +z toward the road
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	# Paving under it all, down into the ground on a slope.
	g.tint = Color(0.75, 0.74, 0.72)
	g.box_on(xf * Transform3D(Basis(), Vector3(0, 0.06, 0.4)), Vector3(6.0, 0.12, 3.4), "sk_paint", p.y)
	# The shelter: back and side glass in steel frames, a roof.
	g.tint = Color.WHITE
	for k in [-1.0, 1.0]:
		for z in [-0.75, 0.75]:
			g.box_xf(xf * Transform3D(Basis(), Vector3(k * 1.6, 1.25, z)), Vector3(0.08, 2.3, 0.08), "sk_steel")
		g.box_xf(xf * Transform3D(Basis(), Vector3(k * 1.6, 1.3, 0.0)), Vector3(0.03, 1.9, 1.4), "sk_glass")
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 1.3, -0.75)), Vector3(3.15, 1.9, 0.03), "sk_glass")
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 2.45, 0.0)), Vector3(3.5, 0.1, 1.8), "sk_steel")
	g.tint = Color(0.2, 0.45, 0.25)
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 2.36, 0.88)), Vector3(3.5, 0.18, 0.04), "sk_paint", false)
	# Bench inside.
	g.tint = Color.WHITE
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.46, -0.45)), Vector3(2.4, 0.06, 0.4), "sk_wood")
	for k in [-1.0, 1.0]:
		g.box_xf(xf * Transform3D(Basis(), Vector3(k * 1.0, 0.23, -0.45)), Vector3(0.06, 0.46, 0.35), "sk_steel")
	# The H sign: a green-rimmed yellow disc on a post at the kerb end.
	var sp: Vector3 = xf * Vector3(2.4, 0, 1.3)
	sp.y = p.y
	_post(g, sp, 2.9, 0.04)
	var sx := Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), sp + Vector3(0, 2.6, 0))
	g.tint = Color(0.1, 0.5, 0.25)
	g.cylinder(sx * Vector3(0, 0, -0.02), sx * Vector3(0, 0, 0.02), 0.3, "sk_paint", 20, false)
	g.tint = Color(1.0, 0.85, 0.1)
	g.cylinder(sx * Vector3(0, 0, -0.03), sx * Vector3(0, 0, 0.03), 0.25, "sk_paint", 20, false)
	g.tint = Color.WHITE
	for s in [1.0, -1.0]:
		var face := Transform3D(Basis(Vector3.UP, yaw + PI * 0.5 + (0.0 if s > 0.0 else PI)), sp + Vector3(0, 2.6, 0))
		_label(g, "H", face * Transform3D(Basis(), Vector3(0, 0, 0.035)), 0.006, Color(0.1, 0.45, 0.22))
	g.tint = Color.WHITE
	g.box(sp + Vector3(0, 2.1, 0), Vector3(0.6, 0.22, 0.04), "sk_paint", yaw + PI * 0.5, false)
	_label(g, stop_name, Transform3D(Basis(Vector3.UP, yaw + PI * 0.5), sp + Vector3(0, 2.1, 0)) * Transform3D(Basis(), Vector3(0, 0, 0.025)), 0.0022, Color(0.1, 0.1, 0.1))
	bin(g, xf * Vector3(-2.3, 0, 0.9), yaw)
	return [["bus_stop", xf * Vector3(-1.0, 1.7, 5.0), xf * Vector3(0, 1.2, 0)]]

## The yellow letter box (Briefkasten) on its post.
static func post_box(g: Geo, p: Vector3, yaw: float) -> void:
	ensure_materials(g)
	_post(g, p, 0.9, 0.05)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 1.15, 0))
	g.tint = Color(1.0, 0.8, 0.05)
	g.box_xf(xf, Vector3(0.42, 0.55, 0.3), "sk_paint")
	g.cylinder(xf * Vector3(0, 0.27, -0.15), xf * Vector3(0, 0.27, 0.15), 0.21, "sk_paint", 12)
	g.tint = Color(0.08, 0.08, 0.08)
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.12, 0.155)), Vector3(0.26, 0.03, 0.01), "sk_paint", false) # the slot
	g.tint = Color(0.15, 0.25, 0.65)
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, -0.1, 0.155)), Vector3(0.2, 0.12, 0.01), "sk_paint", false) # emptying times
	g.tint = Color.WHITE

## A litter bin hung on a post.
static func bin(g: Geo, p: Vector3, yaw: float) -> void:
	ensure_materials(g)
	_post(g, p, 1.0, 0.035)
	var c: Vector3 = p + Vector3(0, 0.7, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 0.2
	g.tint = Color(0.15, 0.35, 0.2)
	g.cylinder(c + Vector3(0, -0.3, 0), c + Vector3(0, 0.25, 0), 0.2, "sk_paint", 10)
	g.tint = Color.WHITE

## Household bins side by side (black rest, blue paper, brown compost,
## yellow lid for packaging), lids shut, wheels to the back.
static func wheelie_bins(g: Geo, p: Vector3, yaw: float, n: int, rng: RandomNumberGenerator) -> void:
	ensure_materials(g)
	var lids: Array = [Color(0.12, 0.12, 0.13), Color(0.15, 0.3, 0.7), Color(0.45, 0.28, 0.15), Color(0.95, 0.8, 0.1)]
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	for k in range(n):
		var c: Vector3 = Vector3((k - (n - 1) * 0.5) * 0.65, 0, 0)
		g.tint = Color(0.22, 0.23, 0.24) if rng.randf() < 0.7 else Color(0.3, 0.32, 0.3)
		g.box_on(xf * Transform3D(Basis(), c + Vector3(0, 0.5, 0)), Vector3(0.58, 1.0, 0.72), "sk_paint", p.y)
		g.tint = lids[(k + rng.randi()) % lids.size()]
		g.box_xf(xf * Transform3D(Basis(), c + Vector3(0, 1.03, 0.02)), Vector3(0.62, 0.06, 0.78), "sk_paint", false)
	g.tint = Color.WHITE

## The village notice board: a framed board under a little roof on two
## posts.
static func notice_board(g: Geo, p: Vector3, yaw: float) -> void:
	ensure_materials(g)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	for k in [-0.7, 0.7]:
		var q: Vector3 = xf * Vector3(k, 0, 0)
		q.y = p.y
		_post(g, q, 2.1, 0.06, "sk_wood")
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 1.35, 0)), Vector3(1.5, 1.0, 0.06), "sk_wood")
	g.tint = Color(0.92, 0.9, 0.82)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(p)
	for k in range(5): # notices pinned to it
		g.box_xf(xf * Transform3D(Basis(), Vector3(rng.randf_range(-0.5, 0.5), rng.randf_range(1.05, 1.65), 0.035)), Vector3(0.21, 0.29, 0.005), "sk_paint", false)
		g.tint = [Color(0.92, 0.9, 0.82), Color(0.95, 0.75, 0.6), Color(0.7, 0.85, 0.95)][rng.randi() % 3]
	g.tint = Color(0.45, 0.28, 0.2)
	for s in [-1.0, 1.0]:
		g.box_xf(xf * Transform3D(Basis(Vector3.RIGHT, s * 0.5), Vector3(0, 2.05, s * 0.2)), Vector3(1.8, 0.05, 0.5), "sk_paint")
	g.tint = Color.WHITE
