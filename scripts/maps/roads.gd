class_name Roads
extends RefCounted

## Road builder for the generated maps (Route + Geo.sweep): carriageway,
## lane markings, kerbs and pavements that follow curves; junctions
## that roads end at (a road never just stops - it meets a junction, a
## car park, a gate, or runs out past the map edge into the haze);
## street lamps, parked cars and traffic along the lanes; elevated
## roads on piers. And grid() lays out a whole city street network.
##
## Surfaces are Geo ground layers (road 2, markings 3, pavement 1) so
## they never flicker against the ground or each other.

const KERB: float = 0.14
const SURF: float = 0.03 ## road surface above the route (ground) height

var geo: Geo
var rng: RandomNumberGenerator
var fleet: Fleet ## cars go here (MultiMesh) when set, else into the Geo

func _init(g: Geo, r: RandomNumberGenerator, f: Fleet = null) -> void:
	geo = g
	rng = r
	fleet = f
	Vehicles.ensure_materials(geo)
	if geo.has_material("rd_asphalt"):
		return
	geo.add_material("rd_asphalt", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 2, 0.3))
	geo.add_material("rd_asphalt_old", Geo.ground_mat(MapTextures.get_tex("cracked_asphalt"), Color.WHITE, 7.0, 2, 0.35))
	geo.add_material("rd_line", Geo.ground_flat(Color(0.88, 0.88, 0.84), 3))
	geo.add_material("rd_line_y", Geo.ground_flat(Color(0.9, 0.72, 0.15), 3))
	geo.add_material("rd_walk", Geo.ground_mat(MapTextures.get_tex("paving_slabs"), Color.WHITE, 3.0, 1, 0.25))
	geo.add_material("rd_kerb", Geo.flat_mat(Color(0.62, 0.62, 0.6)))
	geo.add_material("rd_verge", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color.WHITE, 3.0, 1, 0.3))
	geo.add_material("rd_deck", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.1, 1.1, 1.08), 4.0))
	geo.add_material("rd_steel", Geo.flat_mat(Color(0.45, 0.47, 0.5), 0.5, 0.5))
	geo.add_material("rd_barrier", Geo.flat_mat(Color(0.7, 0.72, 0.74), 0.4, 0.6))
	geo.add_material("rd_lamp", Geo.glow_mat(Color(1.0, 0.92, 0.75), 0.8))
	geo.add_material("rd_sign_blue", Geo.flat_mat(Color(0.1, 0.3, 0.65)))
	geo.add_material("rd_sign_green", Geo.flat_mat(Color(0.1, 0.45, 0.25)))

## A road along `route` (its points = ground height), `width` metres of
## carriageway. opt keys:
##   lanes: lanes per direction (1)      centre: "dash" | "solid" | "none"
##   edge_lines: bool                    walk: pavement width (0 = none;
##   verge: gravel shoulder width          then kerbs too)
##   lamps: spacing (0 = none)           old: cracked asphalt
##   oneway: bool (no centre line, lane lines only)
##   detail: metres from the start with lamps and markings (default all)
##     - a street running out of the map into the haze needs neither
##     past a few hundred metres.
func road(route: Route, width: float, opt: Dictionary = {}) -> void:
	var full: Array[Vector3] = route.pts
	var L_all: float = route.length()
	var detail: float = minf(opt.get("detail", L_all), L_all)
	var pts: Array[Vector3] = full if detail >= L_all - 0.01 else route.slice(0, detail)
	var w: float = width * 0.5
	var mat: String = "rd_asphalt_old" if opt.get("old", false) else "rd_asphalt"
	# Carriageway, with a skirt down to the ground on each side so it
	# never floats over dips in the terrain between points.
	geo.sweep(full, [Vector2(w + 0.25, -0.4), Vector2(w, SURF), Vector2(-w, SURF), Vector2(-w - 0.25, -0.4)], mat, false, true, false)
	var lanes: int = opt.get("lanes", 1)
	var centre: String = opt.get("centre", "dash")
	if opt.get("oneway", false):
		for k in range(1, lanes):
			dashes(pts, -w + width * k / lanes, 3.0, 6.0, 0.12, "rd_line")
	else:
		if centre == "dash":
			dashes(pts, 0.0, 3.0, 6.0, 0.12, "rd_line")
		elif centre == "solid":
			line(pts, 0.0, 0.12, "rd_line")
		elif centre == "double":
			line(pts, -0.12, 0.1, "rd_line")
			line(pts, 0.12, 0.1, "rd_line")
		for k in range(1, lanes):
			var o: float = w * k / lanes
			dashes(pts, o, 3.0, 6.0, 0.12, "rd_line")
			dashes(pts, -o, 3.0, 6.0, 0.12, "rd_line")
	if opt.get("edge_lines", false):
		line(pts, w - 0.3, 0.15, "rd_line")
		line(pts, -w + 0.3, 0.15, "rd_line")
	var walk: float = opt.get("walk", 0.0)
	if walk > 0.0:
		for s in [-1.0, 1.0]:
			pavement(route, s, w, walk)
	var verge: float = opt.get("verge", 0.0)
	if verge > 0.0:
		for s in [-1.0, 1.0]:
			var vp: Array[Vector3] = Route.offset_pts(pts, s * (w + verge * 0.5))
			geo.sweep(vp, [Vector2(verge * 0.5 + 0.3, -0.3), Vector2(verge * 0.5, SURF - 0.01), Vector2(-verge * 0.5, SURF - 0.01), Vector2(-verge * 0.5 - 0.3, -0.3)], "rd_verge", false, false, false)
	var lamp_every: float = opt.get("lamps", 0.0)
	if lamp_every > 0.0:
		var L: float = detail
		var d: float = lamp_every * 0.5
		var side: float = 1.0
		while d < L:
			var s: Array = route.sample(d)
			var t: Vector3 = s[1]
			var right := Vector3(-t.z, 0.0, t.x)
			var off: float = w + (walk - 0.5 if walk > 0.0 else maxf(verge, 0.8))
			lamp(s[0] + right * side * off + Vector3(0, KERB if walk > 0.0 else 0.0, 0), -right * side)
			if opt.get("lamps_both", false):
				lamp(s[0] - right * side * off + Vector3(0, KERB if walk > 0.0 else 0.0, 0), right * side)
			else:
				side = -side
			d += lamp_every

## Kerb + pavement on one side (s = +1 right, -1 left).
func pavement(route: Route, s: float, road_half: float, walk: float) -> void:
	var c: float = road_half + walk * 0.5
	var pp: Array[Vector3] = Route.offset_pts(route.pts, s * c)
	var a: float = -walk * 0.5 * s # the kerb (road side), in the pavement's own frame
	var b: float = walk * 0.5 * s
	# Faces point away from the pavement's middle: kerb toward the road.
	geo.sweep(pp, [Vector2(a, SURF - 0.1), Vector2(a, KERB)], "rd_kerb", false, true, false, 0.0, false, false, Vector2(0, 0))
	geo.sweep(pp, [Vector2(b, KERB), Vector2(b, -0.3)], "rd_kerb", false, false, false, 0.0, false, false, Vector2(0, 0))
	geo.sweep(pp, [Vector2(walk * 0.5, KERB), Vector2(-walk * 0.5, KERB)], "rd_walk", false, true, false)

## Solid line `o` metres right of the route.
func line(pts: Array[Vector3], o: float, width: float, mat: String) -> void:
	var lp: Array[Vector3] = Route.offset_pts(pts, o)
	geo.sweep(lp, [Vector2(width * 0.5, SURF), Vector2(-width * 0.5, SURF)], mat, false, false, false)

## Dashed line: `dash` m of paint every `dash + gap` m.
func dashes(pts: Array[Vector3], o: float, dash: float, gap: float, width: float, mat: String) -> void:
	var r := Route.new()
	r.pts = Route.offset_pts(pts, o)
	var L: float = r.length()
	var d: float = gap * 0.5
	while d + dash < L:
		geo.sweep(r.slice(d, d + dash), [Vector2(width * 0.5, SURF), Vector2(-width * 0.5, SURF)], mat, false, false, false)
		d += dash + gap

## A junction: a rectangle of road surface at c (ground), size x by z,
## zebra crossings on the sides listed in `zebra` ("n","s","e","w"),
## raised pavement corners of `walk` width.
func junction(c: Vector3, size: Vector2, zebra: Array = [], walk: float = 0.0, old: bool = false) -> void:
	var r := Route.from(c - Vector3(size.x * 0.5, 0, 0), 0.0).straight(size.x, size.x)
	geo.sweep(r.pts, [Vector2(size.y * 0.5 + 0.25, -0.4), Vector2(size.y * 0.5, SURF), Vector2(-size.y * 0.5, SURF), Vector2(-size.y * 0.5 - 0.25, -0.4)], "rd_asphalt_old" if old else "rd_asphalt", false, true, false)
	for side in zebra:
		var n: Vector3 = {"n": Vector3(0, 0, -1), "s": Vector3(0, 0, 1), "e": Vector3(1, 0, 0), "w": Vector3(-1, 0, 0)}[side]
		var across: Vector3 = Vector3(n.z, 0, n.x).abs()
		var half: float = size.x * 0.5 if across.x > 0.5 else size.y * 0.5
		var edge: Vector3 = c + n * ((size.y if absf(n.z) > 0.5 else size.x) * 0.5 - 2.0)
		var k: float = -half + 0.8
		while k < half - 0.8:
			var p: Vector3 = edge + across * k
			var a := Route.from(p - n * 1.5, rad_to_deg(atan2(n.z, n.x))).straight(3.0, 3.0)
			geo.sweep(a.pts, [Vector2(0.25, SURF), Vector2(-0.25, SURF)], "rd_line", false, false, false)
			k += 1.0
	if walk > 0.0:
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				var q: Vector3 = c + Vector3(sx * (size.x * 0.5 + walk * 0.5), 0, sz * (size.y * 0.5 + walk * 0.5))
				geo.box(q + Vector3(0, KERB * 0.5 - 0.15, 0), Vector3(walk, KERB + 0.3, walk), "rd_walk", 0.0, true, false)

## Street lamp at p (its foot), the arm reaching toward `toward`.
func lamp(p: Vector3, toward: Vector3) -> void:
	geo.cylinder(p, p + Vector3(0, 8.0, 0), 0.09, "rd_steel", 6, true, true, false)
	var arm: Vector3 = p + Vector3(0, 8.0, 0) + toward.normalized() * 1.6
	geo.beam(p + Vector3(0, 7.6, 0), arm, Vector2(0.07, 0.07), "rd_steel", false, false)
	geo.box(arm + Vector3(0, -0.08, 0), Vector3(0.35, 0.12, 0.7), "rd_lamp", atan2(-toward.x, -toward.z), false, false)

## Parked cars along `o` metres right of the route (facing along it).
func parked(route: Route, o: float, chance: float = 0.6, kinds: Array = ["sedan", "hatch", "suv", "hatch", "van", "estate"], from_d: float = 4.0, to_d: float = -1.0) -> void:
	var L: float = route.length() - 4.0 if to_d < 0.0 else to_d
	var d: float = from_d
	while d < L:
		if rng.randf() < chance:
			var s: Array = route.sample(d)
			var t: Vector3 = s[1]
			var right := Vector3(-t.z, 0.0, t.x)
			_car(s[0] + right * o + Vector3(0, SURF, 0), atan2(-t.x, -t.z), kinds[rng.randi() % kinds.size()])
		d += 5.9

func _car(p: Vector3, yaw: float, kind: String) -> void:
	if fleet:
		fleet.car(p, yaw, Fleet.random_paint(rng), kind)
	else:
		Vehicles.car(geo, p, yaw, Vehicles.random_paint(rng), kind)

## Moving traffic: vehicles in the lanes of both directions (right-hand
## traffic), `per_km` per lane and direction.
func traffic(route: Route, width: float, lanes: int = 1, per_km: float = 20.0, trucks: float = 0.15, container_mats: Array = [], oneway: bool = false) -> void:
	var L: float = route.length()
	var lane_w: float = width * 0.5 / lanes if not oneway else width / lanes
	for dir in ([1.0] if oneway else [1.0, -1.0]):
		for k in range(lanes):
			var o: float = (lane_w * (k + 0.5)) * dir if not oneway else -width * 0.5 + lane_w * (k + 0.5)
			var n: int = int(L / 1000.0 * per_km)
			for i in range(n):
				var d: float = rng.randf_range(10.0, L - 10.0)
				var s: Array = route.sample(d)
				var t: Vector3 = s[1] * dir
				var right := Vector3(-s[1].z, 0.0, s[1].x)
				var p: Vector3 = s[0] + right * o + Vector3(0, SURF, 0)
				var yaw: float = atan2(-t.x, -t.z)
				var roll: float = rng.randf()
				if roll < trucks and not container_mats.is_empty():
					Vehicles.semi(geo, p, yaw, Vehicles.random_paint(rng), container_mats[rng.randi() % container_mats.size()])
				elif roll < trucks * 1.6:
					Vehicles.box_truck(geo, p, yaw, Vehicles.random_paint(rng))
				else:
					_car(p, yaw, ["sedan", "hatch", "suv", "estate", "van", "sedan"][rng.randi() % 6])

## Elevated road on `route` (its points at deck height): deck box,
## parapets, piers down to `ground` every `span` m. Draw the road on
## the same route afterwards with road().
func viaduct(route: Route, width: float, span: float = 32.0, ground: Callable = Callable()) -> void:
	var w: float = width * 0.5 + 0.6
	geo.sweep(route.pts, [Vector2(w, 0.0), Vector2(w, -1.3), Vector2(w - 1.5, -1.9), Vector2(-w + 1.5, -1.9), Vector2(-w, -1.3), Vector2(-w, 0.0)], "rd_deck", true, true, true)
	for s in [-1.0, 1.0]:
		var pp: Array[Vector3] = Route.offset_pts(route.pts, s * (w - 0.25))
		geo.sweep(pp, [Vector2(0.25, 0.0), Vector2(0.25, 1.0), Vector2(-0.25, 1.0), Vector2(-0.25, 0.0)], "rd_deck", true, true, false)
		var rail: Array[Vector3] = Route.offset_pts(route.pts, s * (w - 0.25))
		for i in range(rail.size()):
			rail[i].y += 1.25
		geo.sweep(rail, [Vector2(0.05, -0.1), Vector2(0.05, 0.1), Vector2(-0.05, 0.1), Vector2(-0.05, -0.1)], "rd_barrier", true, false, false)
	var L: float = route.length()
	var d: float = span * 0.5
	while d < L:
		var s: Array = route.sample(d)
		var top: Vector3 = s[0] + Vector3(0, -1.9, 0)
		var gy: float = ground.call(top.x, top.z) if ground.is_valid() else 0.0
		if top.y - gy > 1.0:
			var t: Vector3 = s[1]
			var yaw: float = atan2(-t.x, -t.z)
			geo.box(Vector3(top.x, (top.y + gy) * 0.5 - 0.3, top.z), Vector3(width * 0.45, top.y - gy + 0.6, 1.8), "rd_deck", yaw)
			geo.box(top + Vector3(0, -0.5, 0), Vector3(width * 0.8, 1.0, 2.4), "rd_deck", yaw)
		d += span

## A city street network. xs: x of streets running north-south, zs: z
## of streets running east-west (sorted), inside `area`; widths are the
## carriageway widths. Junctions at every crossing, road pieces between,
## pavements everywhere; streets on the listed edges ("n","s","e","w")
## run on out of the map for `extend` m (into the haze).
## Returns the blocks between the streets (inside the pavements).
func grid(xs: Array, zs: Array, x_width: Array, z_width: Array, walk: float, y: float, extend: Dictionary = {}, opt: Dictionary = {}) -> Array[Rect2]:
	var blocks: Array[Rect2] = []
	for i in range(xs.size()):
		for j in range(zs.size()):
			junction(Vector3(xs[i], y, zs[j]), Vector2(x_width[i], z_width[j]), ["n", "s", "e", "w"] if opt.get("zebra", true) else [], walk)
	# North-south streets between junctions (and beyond the ends).
	for i in range(xs.size()):
		var wx: float = x_width[i]
		for j in range(zs.size() - 1):
			var z0: float = zs[j] + z_width[j] * 0.5
			var z1: float = zs[j + 1] - z_width[j + 1] * 0.5
			var r := Route.from(Vector3(xs[i], y, z0), 90.0).straight(z1 - z0, 12.0)
			_street(r, wx, walk, opt)
		if extend.has("n"):
			var r := Route.from(Vector3(xs[i], y, zs[0] - z_width[0] * 0.5), -90.0).straight(extend.n, 20.0)
			_street(r, wx, walk, opt)
		if extend.has("s"):
			var r := Route.from(Vector3(xs[i], y, zs[-1] + z_width[-1] * 0.5), 90.0).straight(extend.s, 20.0)
			_street(r, wx, walk, opt)
	for j in range(zs.size()):
		var wz: float = z_width[j]
		for i in range(xs.size() - 1):
			var x0: float = xs[i] + x_width[i] * 0.5
			var x1: float = xs[i + 1] - x_width[i + 1] * 0.5
			var r := Route.from(Vector3(x0, y, zs[j]), 0.0).straight(x1 - x0, 12.0)
			_street(r, wz, walk, opt)
		if extend.has("w"):
			var r := Route.from(Vector3(xs[0] - x_width[0] * 0.5, y, zs[j]), 180.0).straight(extend.w, 20.0)
			_street(r, wz, walk, opt)
		if extend.has("e"):
			var r := Route.from(Vector3(xs[-1] + x_width[-1] * 0.5, y, zs[j]), 0.0).straight(extend.e, 20.0)
			_street(r, wz, walk, opt)
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var x0: float = xs[i] + x_width[i] * 0.5 + walk
			var x1: float = xs[i + 1] - x_width[i + 1] * 0.5 - walk
			var z0: float = zs[j] + z_width[j] * 0.5 + walk
			var z1: float = zs[j + 1] - z_width[j + 1] * 0.5 - walk
			blocks.append(Rect2(x0, z0, x1 - x0, z1 - z0))
	return blocks

func _street(r: Route, width: float, walk: float, opt: Dictionary) -> void:
	var lanes: int = 2 if width >= 13.0 else 1
	var detail: float = opt.get("detail", 450.0)
	road(r, width, {"walk": walk, "lanes": lanes, "centre": "solid" if lanes > 1 else "dash", "lamps": opt.get("lamps", 30.0), "detail": detail})
	var near: Route = r if r.length() <= detail else Route.from_pts(r.slice(0.0, detail))
	if opt.get("parking", true) and near.length() > 14.0:
		for s in [-1.0, 1.0]:
			parked(near, s * (width * 0.5 - 1.2), opt.get("park_chance", 0.45), ["sedan", "hatch", "suv", "hatch", "van", "estate"], 5.0, near.length() - 5.0)
	if opt.get("traffic", 0.0) > 0.0:
		traffic(near, width - 4.8 if opt.get("parking", true) else width, lanes, opt.traffic)
