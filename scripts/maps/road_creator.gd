class_name RoadCreator
extends RefCounted

## Creator: a country road across the land - through the points the map
## gives, corners rounded (no kinks), on a smooth grade the land is cut
## and filled to (cuttings through crests, embankments over hollows),
## and a bridge wherever it meets a river: the road climbs to deck
## height at a legal gradient, the river keeps its channel underneath,
## and BridgeCreator builds the bridge.
##
##   land.set_extent(rect)                       # first: roads run on past it
##   var main := RoadCreator.plan(land, start, heading, [Vector2(...), ...], 6.5)
##   var side := RoadCreator.branch(land, main, Vector2(x, z), 1.0, [...], 5.5, {"end": "turning"})
##   land.build(...)
##   main.draw(geo, roads, rng); side.draw(geo, roads, rng)
##
## Roads meet at junctions: a branch starts square-on at the edge of the
## road it leaves, at that road's level, through a mouth with rounded
## corners and a give-way line. A road ends at a junction, a turning
## circle ("end": "turning"), or runs on past the detailed terrain over
## the horizon ring into the haze (the default) - never just stops.
## Plan after the rivers (it asks the land for them), before land.build().
## Real numbers: country roads 5.5-7 m wide, curves R >= 60 m, gradients
## up to 7-8 %, bridge decks 4-5 m above water, kerb radius at a minor
## junction 6-10 m.

const MAX_GRADE: float = 0.07
const CLEARANCE: float = 4.5 ## deck surface above the water
const STEP: float = 6.0
const FILLET: float = 7.0 ## corner radius at a junction mouth

var land: TerrainCreator
var line: LandLine
var width: float
var end_style: String = "on"
var opts: Dictionary = {}
## [first point index, last point index, river LandLine, crossing point, river direction]
var bridges: Array = []
## Set on a branch: [road it leaves, index on it, side (+1 right / -1 left)]
var junction: Array = []
## On a road others branch off: [distance along it, side, half width of the mouth]
var mouths: Array = []

## start: where the road begins (y used when opts.start_y is set);
## heading: its first direction in degrees (Route convention).
## opts: start_y, radius (corners, 70), lead (straight start, 40),
## end ("on" | "turning"), verge (gravel shoulder width, 1), hold
## ([[Vector2 centre, y, radius], ...]: levels held there), bridge
## (style for the bridges on it, else BridgeCreator picks).
static func plan(t: TerrainCreator, start: Vector3, heading: float, waypoints: Array, road_width: float = 6.5, o: Dictionary = {}) -> RoadCreator:
	var r := RoadCreator.new()
	r.land = t
	r.width = road_width
	r.opts = o
	r.end_style = o.get("end", "on")
	var corners: Array[Vector3] = [start, start + Route.dir_of(heading) * o.get("lead", 40.0)]
	for p in waypoints:
		corners.append(Vector3(p.x, 0, p.y))
	var pts: Array[Vector3] = LandLine.smooth_path(corners, o.get("radius", 70.0), STEP)
	r._grade(pts)
	t.add_road(r.line)
	return r

## A road leaving `main` square-on at the point of it nearest `at`, on
## its `side` (+1 = right of main's direction of travel, -1 = left).
static func branch(t: TerrainCreator, main: RoadCreator, at: Vector2, side: float, waypoints: Array, road_width: float = 5.5, o: Dictionary = {}) -> RoadCreator:
	var mp: Array[Vector3] = main.line.pts
	var idx: int = 1
	var best: float = INF
	for i in range(1, mp.size() - 1):
		var d: float = Vector2(mp[i].x, mp[i].z).distance_to(at)
		if d < best:
			best = d
			idx = i
	var tan: Vector3 = Route._tangent(mp, idx)
	var out: Vector3 = Vector3(-tan.z, 0, tan.x) * side
	var start: Vector3 = mp[idx] + out * (main.line.half + FILLET)
	var oo: Dictionary = o.duplicate()
	oo["start_y"] = mp[idx].y
	var r := plan(t, start, rad_to_deg(atan2(out.z, out.x)), waypoints, road_width, oo)
	r.junction = [main, idx, side]
	main.mouths.append([Route.from_pts(mp.slice(0, idx + 1)).length(), side, road_width * 0.5 + FILLET])
	return r

## The road's levels: the ground smoothed into a grade, pinned at the
## start (junction), over rivers (bridges) and - past the detailed
## terrain - onto the horizon ring; gradient-limited both ways.
func _grade(pts: Array[Vector3]) -> void:
	var t: TerrainCreator = land
	var n: int = pts.size()
	var rect: Rect2 = t._rect
	var has_rect: bool = rect.size.x > 0.0
	var g := PackedFloat32Array()
	g.resize(n)
	var fixed := PackedByteArray()
	fixed.resize(n)
	fixed.fill(0)
	for i in range(n):
		var q := Vector2(pts[i].x, pts[i].z)
		if has_rect and not rect.has_point(q):
			# Out on the horizon ring: lie on it (it is too coarse to cut).
			g[i] = t.far_ground(q.x, q.y)
			fixed[i] = 1
		else:
			g[i] = t.staged(q.x, q.y, TerrainCreator.FLATS)
	var y := PackedFloat32Array()
	y.resize(n)
	for i in range(n):
		if fixed[i] == 1:
			y[i] = g[i]
			continue
		var acc: float = 0.0
		var c: int = 0
		for k in range(maxi(i - 7, 0), mini(i + 8, n)):
			if fixed[k] == 0:
				acc += g[k]
				c += 1
		y[i] = acc / maxi(c, 1)
	if opts.has("start_y"):
		for i in range(mini(4, n)):
			y[i] = opts.start_y
			fixed[i] = 1
	# Held levels ([centre (x, z), y, radius]): e.g. at a works gate, so
	# the road meets the yard's level rather than the ground's.
	for h: Array in opts.get("hold", []):
		for i in range(n):
			if fixed[i] == 0 and Vector2(pts[i].x, pts[i].z).distance_to(h[0]) < h[2]:
				y[i] = h[1]
				fixed[i] = 1
	# Rivers: a bridge span over each crossing, its deck held at
	# CLEARANCE above the water.
	for rv: LandLine in t.rivers:
		for i in range(n - 1):
			var hit: Array = rv.crossing(Vector2(pts[i].x, pts[i].z), Vector2(pts[i + 1].x, pts[i + 1].z))
			if hit.is_empty():
				continue
			var rp: Vector3 = hit[0]
			var rdir: Vector3 = rv.pts[hit[1] + 1] - rv.pts[hit[1]]
			rdir.y = 0.0
			var sin_a: float = absf(Route._tangent(pts, i).cross(rdir.normalized()).y)
			# Bank to bank plus a margin, longer when the river crosses skew.
			var half_span: float = (rv.half + TerrainCreator.BANK + 5.0) / maxf(sin_a, 0.6)
			var deck: float = rp.y + CLEARANCE
			var a: int = i
			var b: int = i + 1
			# Distances in the ground plane (the points have no height yet).
			var rp2 := Vector2(rp.x, rp.z)
			while a > 0 and Vector2(pts[a].x, pts[a].z).distance_to(rp2) < half_span:
				a -= 1
			while b < n - 1 and Vector2(pts[b].x, pts[b].z).distance_to(rp2) < half_span:
				b += 1
			for k in range(a, b + 1):
				y[k] = deck
				fixed[k] = 1
			bridges.append([a, b, rv, rp, rdir.normalized()])
	# Gradient limit, both ways (fixed points pull their neighbours).
	for _pass in range(2):
		for i in range(1, n):
			if fixed[i] == 0:
				var ds: float = Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
				y[i] = clampf(y[i], y[i - 1] - MAX_GRADE * ds, y[i - 1] + MAX_GRADE * ds)
		for i in range(n - 2, -1, -1):
			if fixed[i] == 0:
				var ds: float = Vector2(pts[i].x - pts[i + 1].x, pts[i].z - pts[i + 1].z).length()
				y[i] = clampf(y[i], y[i + 1] - MAX_GRADE * ds, y[i + 1] + MAX_GRADE * ds)
	# Round off the grade changes (vertical curves), not the fixed bits.
	var sm := y.duplicate()
	for i in range(n):
		if fixed[i] == 1:
			continue
		var acc: float = 0.0
		var c: int = 0
		for k in range(maxi(i - 2, 0), mini(i + 3, n)):
			acc += y[k]
			c += 1
		sm[i] = acc / c
	for i in range(n):
		pts[i].y = sm[i]
	line = LandLine.make("road", pts, width * 0.5, t.road_bed() + TerrainCreator.ROAD_SLOPE + 1.0)
	for br: Array in bridges:
		for k in range(br[0], br[1]):
			line.bridge[k] = 1
	# Out on the horizon ring the road lies on the ground: nothing to carve.
	if has_rect:
		for k in range(n - 1):
			if not rect.has_point(Vector2(pts[k].x, pts[k].z)) and not rect.has_point(Vector2(pts[k + 1].x, pts[k + 1].z)):
				line.bridge[k] = 1

## Distance along the road to the point of it nearest p (x, z).
func dist_at(p: Vector2) -> float:
	var pts: Array[Vector3] = line.pts
	var best: float = INF
	var at_d: float = 0.0
	var acc: float = 0.0
	for i in range(pts.size() - 1):
		var a := Vector2(pts[i].x, pts[i].z)
		var b := Vector2(pts[i + 1].x, pts[i + 1].z)
		var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
		var d: float = q.distance_to(p)
		if d < best:
			best = d
			at_d = acc + a.distance_to(q)
		acc += a.distance_to(b)
	return at_d

## Level of the road at the point of it nearest p, its direction there,
## and the distance from its centre line - or [] when far from it.
func at(p: Vector2) -> Array:
	var n: Array = line.nearest(p)
	if n.is_empty():
		return []
	return [n[1], Route._tangent(line.pts, n[2]), n[0]]

## Carriageway, markings and verges along the whole road (on into the
## haze where it runs on), the junction mouth, the turning circle, the
## bridges. Returns {"views": [...], "bridges": [style, ...]}.
func draw(geo: Geo, roads: Roads, rng: RandomNumberGenerator) -> Dictionary:
	var pts: Array[Vector3] = line.pts
	var views: Array = []
	var styles: Array = []
	# Edge lines are drawn here (not by Roads.road): they break at every
	# junction mouth instead of running straight across it.
	var ro: Dictionary = {"centre": "dash", "edge_lines": false, "verge": opts.get("verge", 1.0)}
	var edge_lines: bool = width >= 6.0
	if width < 6.0:
		ro["centre"] = "none" # a narrow village lane has no centre line
	var route: Route = Route.from_pts(pts)
	if end_style == "turning":
		# Stop where the turning circle takes over (edge to edge: two
		# overlapping asphalt surfaces would flicker).
		var L: float = route.length()
		route = Route.from_pts(route.slice(0, L - width * 1.4 + 0.2))
	# Markings, verges and the rest only where the land is detailed; out
	# in the haze just the carriageway (a dash at 1 km is never seen,
	# and markings are built one by one).
	var cw: Array[Vector3] = route.pts
	var near: Rect2 = land._rect.grow(60.0)
	var i_in: int = 0
	while i_in < cw.size() - 1 and not near.has_point(Vector2(cw[i_in].x, cw[i_in].z)):
		i_in += 1
	var i_out: int = cw.size() - 1
	while i_out > i_in and not near.has_point(Vector2(cw[i_out].x, cw[i_out].z)):
		i_out -= 1
	# Verge and edge lines go on (one strip each, cheap - stopping them
	# left a hard end); only the centre dashes, built one by one, stop.
	var plain: Dictionary = {"centre": "none", "edge_lines": edge_lines, "verge": opts.get("verge", 1.0)}
	if i_in > 0:
		roads.road(Route.from_pts(cw.slice(0, i_in + 1)), width, plain)
	if i_out > i_in:
		var inner: Route = Route.from_pts(cw.slice(i_in, i_out + 1))
		roads.road(inner, width, ro)
		if edge_lines:
			var d0: float = Route.from_pts(cw.slice(0, i_in + 1)).length() if i_in > 0 else 0.0
			_edge_lines(roads, inner, d0)
	if i_out < cw.size() - 1:
		roads.road(Route.from_pts(cw.slice(i_out, cw.size())), width, plain)
	if not junction.is_empty():
		_mouth(geo, roads)
	if end_style == "turning":
		var e: Vector3 = pts[-1]
		var circ: Array[Vector3] = []
		# Each rim point at the road's level nearest it, as the land's bed
		# is (a flat circle at the end of a sloping lane sank under the bed
		# on its uphill side and the land poked through its rim).
		var lv := func(q: Vector3) -> float:
			var nn: Array = line.nearest(Vector2(q.x, q.z))
			return nn[1] if not nn.is_empty() else e.y
		for k in range(24):
			var a: float = TAU * k / 24.0
			var q: Vector3 = e + Vector3(cos(a) * width * 1.4, 0, sin(a) * width * 1.4)
			q.y = lv.call(q) + Roads.SURF
			circ.append(q)
		geo.polygon(circ, "rd_asphalt")
		# A gravel verge round it, like the road's own.
		var ring: Array = []
		var rr: float = width * 1.4
		for k in range(25):
			var a: float = TAU * k / 24.0
			var dv := Vector3(cos(a), 0, sin(a))
			var r0: Vector3 = e + dv * (rr - 0.05)
			var r1: Vector3 = e + dv * (rr + opts.get("verge", 1.0))
			r0.y = lv.call(r0) + Roads.SURF - 0.01
			r1.y = lv.call(r1) + Roads.SURF - 0.02
			ring.append(PackedVector3Array([r0, r1]))
		geo.strip(ring, "rd_verge", false)
	for br: Array in bridges:
		var deck: Array[Vector3] = []
		for k in range(br[0], br[1] + 1):
			deck.append(pts[k])
		var rv: LandLine = br[2]
		var rp: Vector3 = br[3]
		var bo: Dictionary = {"river_dir": br[4]}
		if opts.has("bridge"):
			bo["style"] = opts.bridge # the map's choice: "beam", "arch", "truss"
		var info: Dictionary = BridgeCreator.build(geo, deck, width, rp.y, rv.half, land.ground, rng, bo)
		styles.append(info.style)
		views.append_array(info.views)
	return {"views": views, "bridges": styles}

## Edge lines on both sides of `r` (which starts `d0` m along the road),
## broken where a branch leaves on that side.
func _edge_lines(roads: Roads, r: Route, d0: float) -> void:
	var L: float = r.length()
	for side in [-1.0, 1.0]:
		var cuts: Array = []
		for m: Array in mouths:
			if m[1] == side:
				cuts.append([m[0] - d0 - m[2], m[0] - d0 + m[2]])
		cuts.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var from: float = 0.0
		for c: Array in cuts + [[L, L]]:
			var to: float = minf(c[0], L)
			if to - from > 1.0:
				roads.line(r.slice(from, to), side * (width * 0.5 - 0.3), 0.15, "rd_line")
			from = maxf(from, c[1])

## The mouth where this branch leaves its main road: asphalt from the
## main road's edge to the branch's start, corners rounded to FILLET,
## and a dashed give-way line across the branch.
func _mouth(geo: Geo, roads: Roads) -> void:
	var main: RoadCreator = junction[0]
	var idx: int = junction[1]
	var side: float = junction[2]
	var mp: Array[Vector3] = main.line.pts
	var c: Vector3 = mp[idx]
	var t: Vector3 = Route._tangent(mp, idx)
	var nrm: Vector3 = Vector3(-t.z, 0, t.x) * side
	var edge: Vector3 = c + nrm * main.line.half
	var bh: float = width * 0.5
	var r: float = FILLET
	# Heights: the main road's own level along its edge (it may slope),
	# blending to the branch's start level across the mouth.
	var main_route: Route = Route.from_pts(mp)
	var d_idx: float = Route.from_pts(mp.slice(0, idx + 1)).length()
	var y_start: float = line.pts[0].y
	var r_m: float = FILLET
	var loc := func(u: float, v: float) -> Vector3:
		var q: Vector3 = edge + t * u + nrm * v
		var ym: float = (main_route.sample(d_idx + u)[0] as Vector3).y
		q.y = lerpf(ym, y_start, clampf(v / r_m, 0.0, 1.0)) + Roads.SURF
		return q
	var poly: Array[Vector3] = [loc.call(-(bh + r), -0.2), loc.call(bh + r, -0.2)]
	for k in range(1, 8):
		var a: float = deg_to_rad(-90.0 - 90.0 * k / 8.0)
		poly.append(loc.call(bh + r + r * cos(a), r + r * sin(a)))
	poly.append(loc.call(bh, r))
	poly.append(loc.call(-bh, r))
	for k in range(1, 8):
		var a: float = deg_to_rad(-90.0 * k / 8.0)
		poly.append(loc.call(-(bh + r) + r * cos(a), r + r * sin(a)))
	geo.polygon(poly, "rd_asphalt")
	# Give-way line: short dashes across the branch, just inside it.
	var gl: Array[Vector3] = [loc.call(-bh + 0.3, r + 0.9), loc.call(bh - 0.3, r + 0.9)]
	gl[0].y = y_start
	gl[1].y = y_start
	roads.dashes(gl, 0.0, 0.5, 0.5, 0.3, "rd_line")

## Glitch check (self-test): points on a line's surface - a road's
## carriageway, a railway's formation - where the terrain comes up
## through it (more than `tol` over the surface), inside `rect`, off its
## bridges. Samples every segment's middle at the centre and near both
## edges. Returns [[Vector3 point, how far the ground pokes up], ...].
static func buried(land: TerrainCreator, l: LandLine, rect: Rect2, tol: float = 0.05) -> Array:
	var out: Array = []
	for i in range(l.pts.size() - 1):
		if l.bridge[i] == 1:
			continue
		var a: Vector3 = l.pts[i]
		var b: Vector3 = l.pts[i + 1]
		var m: Vector3 = (a + b) * 0.5
		if not rect.has_point(Vector2(m.x, m.z)):
			continue
		var t: Vector3 = (b - a)
		t.y = 0.0
		if t.length() < 0.01:
			continue
		var side: Vector3 = Vector3(-t.z, 0, t.x).normalized()
		for f in [-0.85, 0.0, 0.85]:
			var q: Vector3 = m + side * l.half * f
			var up: float = land.ground(q.x, q.z) - m.y
			if up > tol:
				out.append([q, snappedf(up, 0.01)])
	return out
