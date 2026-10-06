class_name RailCreator
extends RefCounted

## Creator: a railway across the land, the way RoadCreator lays a road -
## through the points the map gives, curves of railway radii (no kinks),
## on a much gentler grade than a road. The land is cut and filled to it
## (embankments over hollows, cuttings through crests); where the line
## runs high over a valley it crosses on a stone arch viaduct instead -
## roads and rivers pass under its arches, the land under it is left
## alone. It runs on past the detailed terrain over the horizon ring
## into the haze, like a road.
##
##   land.set_extent(rect)
##   var rail := RailCreator.plan(land, start, heading, [Vector2(...), ...], {"hold": [[Vector2(x, z), y, r]]})
##   ... roads, plots ...
##   land.build(...)
##   rail.draw(geo, Rails.new(geo), rng) -> {"views", "route"}
##
## The line is a LandLine of kind "rail" in land.roads (plots, woods,
## rocks keep off it; TerrainCreator ignores its viaduct segments when
## it shapes the ground, so a road under the arches keeps its own bed).
## Plan it after the rivers, before or after the roads.
## Real numbers: main-line gradients up to 1.25 % (12.5 per mille),
## curve radii 300 m+ (here 350 by default); masonry viaducts (19th
## century) spans of 10-20 m with semicircular arches, piers about a
## sixth of the span, a parapet ~1 m; a single-track formation is ~7 m
## wide at the top.

const MAX_GRADE: float = 0.0125
const STEP: float = 6.0
const HALF: float = 3.4 ## formation half width (and the viaduct deck's)
const VIADUCT_MIN: float = 6.0 ## line this far above the natural ground: viaduct, not embankment
const SPAN: float = 15.0 ## viaduct arch spacing
const PIER: float = 2.6 ## pier thickness along the line
const CLEARANCE: float = 5.0 ## formation over a river's water at least

var land: TerrainCreator
var line: LandLine
var opts: Dictionary = {}
## Viaducts: [first point index, last point index] each.
var viaducts: Array = []
## After draw(): every viaduct pier's foot [middle at ground level, along-line direction].
var piers: Array = []

## start: where the line begins (often out in the haze); heading in
## degrees (Route convention); waypoints: Vector2 (x, z) corners.
## opts: radius (curves, 350), lead (straight start, 60), hold: list of
## [Vector2 point, formation level, radius] - the line is held at that
## level near the point (a viaduct's height, a station), viaduct: false
## to never build one (embankments only).
static func plan(t: TerrainCreator, start: Vector3, heading: float, waypoints: Array, o: Dictionary = {}) -> RailCreator:
	var r := RailCreator.new()
	r.land = t
	r.opts = o
	var corners: Array[Vector3] = [start, start + Route.dir_of(heading) * o.get("lead", 60.0)]
	for p in waypoints:
		corners.append(Vector3(p.x, 0, p.y))
	var pts: Array[Vector3] = LandLine.smooth_path(corners, o.get("radius", 350.0), STEP)
	r._grade(pts)
	t.add_road(r.line)
	return r

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
			g[i] = t.far_ground(q.x, q.y)
			fixed[i] = 1
		else:
			g[i] = t.staged(q.x, q.y, TerrainCreator.PONDS)
	# A long smoothing window (a railway doesn't follow the small hills).
	var y := PackedFloat32Array()
	y.resize(n)
	for i in range(n):
		if fixed[i] == 1:
			y[i] = g[i]
			continue
		var acc: float = 0.0
		var c: int = 0
		for k in range(maxi(i - 14, 0), mini(i + 15, n)):
			if fixed[k] == 0:
				acc += g[k]
				c += 1
		y[i] = acc / maxi(c, 1)
	for h: Array in opts.get("hold", []):
		for i in range(n):
			if fixed[i] == 0 and Vector2(pts[i].x, pts[i].z).distance_to(h[0]) < h[2]:
				y[i] = h[1]
				fixed[i] = 1
	# Rivers: the formation clears the water.
	for rv: LandLine in t.rivers:
		for i in range(n - 1):
			var hit: Array = rv.crossing(Vector2(pts[i].x, pts[i].z), Vector2(pts[i + 1].x, pts[i + 1].z))
			if hit.is_empty():
				continue
			var deck: float = (hit[0] as Vector3).y + CLEARANCE
			for k in range(maxi(i - 3, 0), mini(i + 5, n)):
				if y[k] < deck:
					y[k] = deck
					fixed[k] = 1
	for _pass in range(2):
		for i in range(1, n):
			if fixed[i] == 0:
				var ds: float = Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
				y[i] = clampf(y[i], y[i - 1] - MAX_GRADE * ds, y[i - 1] + MAX_GRADE * ds)
		for i in range(n - 2, -1, -1):
			if fixed[i] == 0:
				var ds: float = Vector2(pts[i].x - pts[i + 1].x, pts[i].z - pts[i + 1].z).length()
				y[i] = clampf(y[i], y[i + 1] - MAX_GRADE * ds, y[i + 1] + MAX_GRADE * ds)
	var sm := y.duplicate()
	for i in range(n):
		if fixed[i] == 1:
			continue
		var acc: float = 0.0
		var c: int = 0
		for k in range(maxi(i - 3, 0), mini(i + 4, n)):
			acc += y[k]
			c += 1
		sm[i] = acc / c
	for i in range(n):
		pts[i].y = sm[i]
	line = LandLine.make("rail", pts, HALF, t.road_bed() + TerrainCreator.ROAD_SLOPE + 1.0)
	# Viaducts: wherever the line runs VIADUCT_MIN over the natural ground
	# (both ends of a segment), joined into runs; short runs are left as
	# embankment (a viaduct needs a couple of arches to be one).
	if opts.get("viaduct", true):
		var run: int = -1
		for k in range(n):
			var hi: bool = k < n - 1 and (not has_rect or (rect.has_point(Vector2(pts[k].x, pts[k].z)) and rect.has_point(Vector2(pts[k + 1].x, pts[k + 1].z))))
			hi = hi and pts[k].y - g[k] > VIADUCT_MIN and pts[k + 1].y - g[k + 1] > VIADUCT_MIN
			if hi and run < 0:
				run = k
			elif not hi and run >= 0:
				if k - run >= 4:
					viaducts.append([run, k])
				run = -1
		for v: Array in viaducts:
			for k in range(v[0], v[1]):
				line.bridge[k] = 1
	# Out on the horizon ring the line lies on the ground: nothing to carve.
	if has_rect:
		for k in range(n - 1):
			if not rect.has_point(Vector2(pts[k].x, pts[k].z)) and not rect.has_point(Vector2(pts[k + 1].x, pts[k + 1].z)):
				line.bridge[k] = 1

## Distance along the line to the point of it nearest p (x, z).
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

## The formation as a Route (y = formation level: the ground under the
## ballast) - for trains and signals: rails.train(rail.route(), d, ...).
func route() -> Route:
	var p: Array[Vector3] = []
	for q in line.pts:
		p.append(q + Vector3(0, -0.06, 0))
	return Route.from_pts(p)

## Track along the whole line, and the viaducts. Returns {"views",
## "route"}.
func draw(geo: Geo, rails: Rails, rng: RandomNumberGenerator) -> Dictionary:
	_materials(geo)
	var r: Route = route()
	rails.track(r, 0, true)
	var views: Array = []
	for v: Array in viaducts:
		views.append_array(_viaduct(geo, v[0], v[1], rng))
	return {"views": views, "route": r}

static func _materials(geo: Geo) -> void:
	if geo.has_material("rc_stone"):
		return
	geo.add_material("rc_stone", Geo.tex_mat(MapTextures.get_tex("rock"), Color(0.98, 0.9, 0.8), 2.2))
	geo.add_material("rc_dressed", Geo.tex_mat(MapTextures.get_tex("rock"), Color(1.12, 1.06, 0.96), 1.4))

## A masonry viaduct along points i0..i1: walls down to semicircular
## arches between piers (solid strips, like BridgeCreator's arch),
## piers stepped out a little, a cornice and parapets, abutments where
## it meets the embankment. Pier places avoid roads and the river
## channel when they can (the phase of the spans is chosen for that).
func _viaduct(geo: Geo, i0: int, i1: int, _rng: RandomNumberGenerator) -> Array:
	var pts: Array[Vector3] = line.pts
	# Reach a little into the embankment at both ends (the abutments).
	var a: int = maxi(i0 - 1, 0)
	var b: int = mini(i1 + 1, pts.size() - 1)
	var deck: Array[Vector3] = []
	for k in range(a, b + 1):
		deck.append(pts[k] + Vector3(0, -0.08, 0))
	var dr: Route = Route.from_pts(deck)
	var L: float = dr.length()
	var abut: float = STEP * 1.2 # solid at both ends
	var free: float = L - 2.0 * abut
	var n_sp: int = maxi(1, int(round(free / SPAN)))
	var sp: float = free / n_sp
	# Pier positions (distances along the deck); choose the phase that
	# keeps them off roads and out of water.
	var best_piers: Array = []
	var best_bad: float = INF
	for shift in range(0, 9):
		var off: float = (shift - 4) * sp * 0.08
		var cand: Array = []
		var bad: float = 0.0
		for k in range(1, n_sp):
			var d: float = abut + k * sp + off
			cand.append(d)
			var q: Vector3 = dr.sample(d)[0]
			for l: LandLine in land.roads:
				if l == line:
					continue
				var nn: Array = l.nearest(Vector2(q.x, q.z))
				if not nn.is_empty() and nn[0] < l.half + PIER + 1.5:
					bad += 10.0
			for rv: LandLine in land.rivers:
				var nn: Array = rv.nearest(Vector2(q.x, q.z))
				if not nn.is_empty() and nn[0] < rv.half + 1.0:
					bad += 1.0
		bad += absf(off) * 0.01
		if bad < best_bad:
			best_bad = bad
			best_piers = cand
	var stops: Array = [abut - PIER * 0.5] + best_piers + [L - abut + PIER * 0.5]
	var hw: float = HALF
	var top_rows: Array = []
	var rows_l: Array = []
	var rows_r: Array = []
	var rows_bot: Array = []
	var centres: Array = []
	var samples: int = int(ceil(L / 0.75))
	for si in range(samples + 1):
		var d: float = L * si / samples
		var smp: Array = dr.sample(d)
		var c: Vector3 = smp[0]
		var tan: Vector3 = smp[1]
		var right := Vector3(-tan.z, 0, tan.x)
		var top: float = c.y
		var gnd: float = minf(land.ground(c.x, c.z), land.ground(c.x - right.x * hw, c.z - right.z * hw))
		gnd = minf(gnd, land.ground(c.x + right.x * hw, c.z + right.z * hw)) - 0.5
		var bot: float = gnd
		for k in range(stops.size() - 1):
			var s0: float = stops[k] + PIER * 0.5
			var s1: float = stops[k + 1] - PIER * 0.5
			if d > s0 and d < s1:
				var rad: float = (s1 - s0) * 0.5
				var spring: float = top - 1.3 - rad
				var u: float = (d - s0) / (s1 - s0) * 2.0 - 1.0
				bot = maxf(gnd, spring + rad * sqrt(maxf(1.0 - u * u, 0.0)))
		bot = minf(bot, top - 0.9)
		var lt: Vector3 = Vector3(c.x, top, c.z) - right * hw
		var rt: Vector3 = Vector3(c.x, top, c.z) + right * hw
		var lb: Vector3 = Vector3(lt.x, bot, lt.z)
		var rb: Vector3 = Vector3(rt.x, bot, rt.z)
		top_rows.append(PackedVector3Array([lt, rt]))
		rows_l.append(PackedVector3Array([lt, lb]))
		rows_r.append(PackedVector3Array([rt, rb]))
		rows_bot.append(PackedVector3Array([lb, rb]))
		centres.append(Vector3(c.x, (top + bot) * 0.5, c.z))
	geo.strip(top_rows, "rc_stone", true)
	geo.strip(rows_l, "rc_stone", true, centres)
	geo.strip(rows_r, "rc_stone", true, centres)
	geo.strip(rows_bot, "rc_stone", true, centres)
	for e in [0, samples]:
		var inward: Vector3 = (deck[1] - deck[0]) if e == 0 else (deck[-2] - deck[-1])
		var cc: Vector3 = centres[e] + inward.normalized() * 1.0
		geo.strip([top_rows[e], rows_bot[e]], "rc_stone", true, [cc, cc])
	# Piers stepped out each side, from below the ground to the springing.
	var views: Array = []
	for k in range(1, stops.size() - 1):
		var d: float = stops[k]
		var smp: Array = dr.sample(d)
		var c: Vector3 = smp[0]
		var tan: Vector3 = smp[1]
		var yaw: float = atan2(tan.x, tan.z)
		var left_span: float = (stops[k] - stops[k - 1] - PIER) * 0.5
		var spring: float = c.y - 1.3 - left_span
		var foot: float = geo.sunk([c + Vector3(-tan.z, 0, tan.x) * (hw + 0.5), c - Vector3(-tan.z, 0, tan.x) * (hw + 0.5), c + tan * PIER * 0.5, c - tan * PIER * 0.5], land.ground(c.x, c.z)) - 0.3
		piers.append([Vector3(c.x, land.ground(c.x, c.z), c.z), tan])
		if spring - foot > 1.0:
			geo.box(Vector3(c.x, (spring + foot) * 0.5, c.z), Vector3(hw * 2.0 + 0.8, spring - foot, PIER + 0.4), "rc_dressed", yaw)
			# The impost: a band where the arches spring.
			geo.box(Vector3(c.x, spring + 0.2, c.z), Vector3(hw * 2.0 + 0.9, 0.4, PIER + 0.5), "rc_dressed", yaw, false)
		if k == stops.size() / 2:
			var under: Vector3 = c - tan * (left_span + PIER * 0.5)
			under.y = foot + 3.0
			views.append(["viaduct_under", under + Vector3(-tan.z, 0, tan.x) * 22.0, under + Vector3(0, 1.0, 0)])
	# Cornice and parapets.
	var corn: Array[Vector3] = []
	for q in deck:
		corn.append(q + Vector3(0, -0.35, 0))
	for s in [-1.0, 1.0]:
		var cp: Array[Vector3] = Route.offset_pts(corn, s * (hw + 0.12))
		geo.sweep(cp, [Vector2(0.18, -0.2), Vector2(0.18, 0.2), Vector2(-0.18, 0.2), Vector2(-0.18, -0.2)], "rc_dressed", true, false, false)
		var pp: Array[Vector3] = Route.offset_pts(deck, s * (hw - 0.25))
		geo.sweep(pp, [Vector2(0.25, -0.05), Vector2(0.25, 1.0), Vector2(-0.25, 1.0), Vector2(-0.25, -0.05)], "rc_dressed", true, true, false)
	var mid: Array = dr.sample(L * 0.5)
	var mc: Vector3 = mid[0]
	var mt: Vector3 = mid[1]
	var side := Vector3(-mt.z, 0, mt.x)
	views.append(["viaduct", mc + side * 70.0 + mt * 30.0 + Vector3(0, -6.0, 0), mc + Vector3(0, -8.0, 0)])
	views.append(["viaduct_deck", mc - mt * 40.0 + Vector3(0, 7.5, 0) + side * 9.0, mc + mt * 20.0 + Vector3(0, 1.0, 0)])
	return views
