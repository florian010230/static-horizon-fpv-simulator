class_name RiverCreator
extends RefCounted

## Creator: a river across the land - meandering between the points the
## map gives, always flowing downhill (the water level can only fall
## along it; where the land rises in the way, the river cuts its own
## valley through it), with mud banks, reeds, and now and then a
## rubber-duck race drifting down it.
##
##   var river := RiverCreator.plan(land, [Vector2(...), ...], width)  # before land.build()
##   ... RoadCreator.plan() sees it and bridges it ...
##   land.build(...)
##   river.draw(geo, visible_rect, rng)
##
## The channel is carved by TerrainCreator (LandLine "river"); the
## banks are drawn here as their own surfaces, finer than the terrain
## grid (8 m) could show them, landing on the terrain at their outer edge.
## Real numbers: a lowland river 8-14 m wide, 1-2 m deep, falling
## 0.3-1 m per km.

const MIN_FALL: float = 0.0005 ## per metre: the river always moves on
const REEDS_EVERY: float = 22.0
const DUCK_RACE_CHANCE: float = 0.05
## Grass bank from the bank top out to here (m past the water's edge):
## past the terrain's carved strip, so its outer edge lands on plain ground.
const GRASS_OUT: float = 16.0
## The grass bank's points stand at least this far over the ground.
const GRASS_LIFT: float = 0.06

var land: TerrainCreator
var line: LandLine
var width: float

## pts: the river's course from upstream to downstream (it may run on
## past the map; it is carved all the way and drawn where asked).
static func plan(t: TerrainCreator, course: Array, river_width: float = 10.0, opts: Dictionary = {}) -> RiverCreator:
	var r := RiverCreator.new()
	r.land = t
	r.width = river_width
	var noise := FastNoiseLite.new()
	noise.seed = opts.get("seed", 1)
	noise.frequency = 1.0 / opts.get("meander_length", 220.0)
	var amp: float = opts.get("meander", river_width * 4.0)
	# The course every 20 m, pushed sideways by noise: meanders.
	var base: Array[Vector3] = []
	for i in range(course.size()):
		base.append(Vector3(course[i].x, 0, course[i].y))
	var dense: Array[Vector3] = LandLine.smooth_path(base, 80.0, 20.0)
	var s: float = 0.0
	for i in range(dense.size()):
		if i > 0:
			s += dense[i].distance_to(dense[i - 1])
		var tan: Vector3 = Route._tangent(dense, i)
		var side := Vector3(-tan.z, 0, tan.x)
		dense[i] += side * noise.get_noise_1d(s) * amp
	var pts: Array[Vector3] = LandLine.smooth_path(dense, 30.0, 6.0)
	# Water level: never above the ground (minus a metre), never rising.
	var lv := PackedFloat32Array()
	lv.resize(pts.size())
	var cap := PackedFloat32Array() # the highest the water may be: a metre under the ground
	cap.resize(pts.size())
	for i in range(pts.size()):
		cap[i] = t.staged(pts[i].x, pts[i].z, TerrainCreator.NATURAL) - 1.0
		lv[i] = cap[i] if i == 0 else minf(cap[i], lv[i - 1] - MIN_FALL * pts[i].distance_to(pts[i - 1]))
	# Smooth the steps out (pools and drops become an even fall), then
	# make sure it still only falls.
	for _pass in range(3):
		var sm := lv.duplicate()
		for i in range(pts.size()):
			var acc: float = 0.0
			var n: int = 0
			for k in range(maxi(i - 6, 0), mini(i + 7, pts.size())):
				acc += lv[k]
				n += 1
			sm[i] = acc / n
		lv = sm
	# Smoothing averages a pool with the higher water upstream: cap it
	# again under the ground (else the water stands above the land in a
	# hollow), then make sure it still only falls.
	for i in range(pts.size()):
		lv[i] = minf(lv[i], cap[i])
		if i > 0:
			lv[i] = minf(lv[i], lv[i - 1] - MIN_FALL * pts[i].distance_to(pts[i - 1]))
	for i in range(pts.size()):
		pts[i].y = lv[i]
	r.line = LandLine.make("river", pts, river_width * 0.5, TerrainCreator.BANK + 2.0 + opts.get("valley", 70.0))
	r.line.depth = opts.get("depth", 1.5)
	r.line.valley = opts.get("valley", 70.0)
	t.add_river(r.line)
	return r

## Water, banks and reeds where the river runs inside `rect`; the
## surprises. Returns {"views": [[name, eye, target], ...], "ducks": bool}.
func draw(geo: Geo, rect: Rect2, rng: RandomNumberGenerator) -> Dictionary:
	if not geo.has_material("rv_water"):
		geo.add_material("rv_water", Geo.water_mat(Color(0.12, 0.3, 0.28), 0.86))
		geo.add_material("rv_mud", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(0.78, 0.68, 0.55), 2.5, 1, 0.3))
		geo.add_material("rv_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 1, 0.45))
		geo.add_material("rvd_reed", Geo.flat_mat(Color(0.42, 0.5, 0.22)))
		# Only the reeds drop out at a distance - water and banks are the
		# river itself (culling them too left a bare trench from afar).
		geo.detail_prefixes.append("rvd_")
	var pts: Array[Vector3] = line.pts
	var views: Array = []
	var w: float = line.half
	var run: Array[int] = []
	for i in range(pts.size()):
		if rect.has_point(Vector2(pts[i].x, pts[i].z)):
			run.append(i)
	if run.size() < 2:
		return {"views": views, "ducks": false}
	var i0: int = run[0]
	var i1: int = run[-1]
	var seg: Array[Vector3] = []
	for i in range(i0, i1 + 1):
		seg.append(pts[i])
	# Lit like the terrain round it (not the default near-ground AO).
	geo.light_fn = func(n: Vector3, p: Vector3) -> Color: return geo.shade(n, p.y + 50.0)
	geo.sweep(seg, [Vector2(w + 1.3, 0.0), Vector2(-w - 1.3, 0.0)], "rv_water", false, false, false)
	# Past the detailed land the river runs on into the haze, at its own
	# level - the horizon ring is kept under it (TerrainCreator._far_natural).
	for tail: Array in [range(i0, -1, -1), range(i1, pts.size())]:
		var out: Array[Vector3] = []
		for i: int in tail:
			var q: Vector3 = pts[i]
			if out.size() > 0 and Vector2(q.x, q.z).distance_to(Vector2(pts[i0].x, pts[i0].z)) > 2500.0 and Vector2(q.x, q.z).distance_to(Vector2(pts[i1].x, pts[i1].z)) > 2500.0:
				break
			# At its own level: the ring is kept under it along its course.
			out.append(q)
		if out.size() > 1:
			geo.sweep(out, [Vector2(w + 1.3, 0.0), Vector2(-w - 1.3, 0.0)], "rv_water", false, false, false)
	for side in [-1.0, 1.0]:
		var mud: Array = []
		var grass: Array = []
		for k in range(seg.size()):
			var tan: Vector3 = Route._tangent(seg, k)
			var right: Vector3 = Vector3(-tan.z, 0, tan.x) * side
			var c: Vector3 = seg[k]
			var wy: float = c.y
			var top: Vector3 = c + right * (w + TerrainCreator.BANK) + Vector3(0, 0.45, 0)
			mud.append(PackedVector3Array([c + right * (w + 0.3) + Vector3(0, -0.3, 0), c + right * (w + 1.5) + Vector3(0, 0.12, 0), top]))
			# The grass bank, from the bank's top straight out to the ground
			# GRASS_OUT past the water: in rows half a river step apart, twelve
			# points across, each lifted clear of the ground under it (a valley
			# side bulging over the straight line, and the 8 m terrain grid's
			# triangles between two rows, rose through it).
			for h in ([0.0, 0.5] if k < seg.size() - 1 else [0.0]):
				var ch: Vector3 = seg[k].lerp(seg[k + 1], h) if h > 0.0 else c
				var th: Vector3 = Route._tangent(seg, k).lerp(Route._tangent(seg, k + 1), h).normalized() if h > 0.0 else tan
				var rh: Vector3 = Vector3(-th.z, 0, th.x) * side
				var t0: Vector3 = ch + rh * (w + TerrainCreator.BANK) + Vector3(0, 0.45, 0)
				var out: Vector3 = ch + rh * (w + GRASS_OUT)
				out.y = land.ground(out.x, out.z) + GRASS_LIFT
				var row := PackedVector3Array()
				for f in range(13):
					var q: Vector3 = t0.lerp(out, f / 12.0)
					if f > 0:
						q.y = maxf(q.y, land.ground(q.x, q.z) + GRASS_LIFT)
					row.append(q)
				grass.append(row)
		var tint_light := func(n: Vector3, p: Vector3) -> Color: return land.tint(geo, n, p)
		geo.light_fn = func(n: Vector3, p: Vector3) -> Color: return geo.shade(n, p.y + 50.0) * Color(1.05, 1.0, 0.9)
		geo.strip(mud, "rv_mud")
		geo.light_fn = tint_light
		geo.strip(grass, "rv_grass")
	geo.light_fn = Callable()
	# Reeds in clumps on the banks.
	var acc: float = 0.0
	for k in range(1, seg.size()):
		acc += seg[k].distance_to(seg[k - 1])
		if acc < REEDS_EVERY:
			continue
		acc = 0.0
		if rng.randf() < 0.45:
			continue
		var tan: Vector3 = Route._tangent(seg, k)
		var right: Vector3 = Vector3(-tan.z, 0, tan.x) * (-1.0 if rng.randf() < 0.5 else 1.0)
		var c: Vector3 = seg[k] + right * (w + rng.randf_range(0.9, 1.6)) + tan * rng.randf_range(-3, 3)
		for _r in range(rng.randi_range(8, 16)):
			var p: Vector3 = c + Vector3(rng.randf_range(-1.2, 1.2), -0.1, rng.randf_range(-1.2, 1.2))
			geo.tint = Color(1, 1, 1) * rng.randf_range(0.8, 1.15)
			geo.cone(p, p + Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(1.2, 2.0), rng.randf_range(-0.2, 0.2)), 0.04, 0.005, "rvd_reed", 4, false)
		geo.tint = Color.WHITE
	views.append(["river", seg[seg.size() / 2] + Vector3(0, 6, 0) + Route._tangent(seg, seg.size() / 2) * -25.0, seg[seg.size() / 2]])
	# Surprise: a rubber-duck race - a few dozen ducks strung out downstream.
	var ducks: bool = rng.randf() < DUCK_RACE_CHANCE or OS.has_environment("SH_DUCKS")
	if ducks:
		ToiletCreator.ensure_materials(geo)
		var tc := ToiletCreator.new()
		tc.geo = geo
		tc.rng = rng
		tc.t = Transform3D(Basis.from_scale(Vector3.ONE * 2.2), Vector3.ZERO)
		var k0: int = rng.randi_range(seg.size() / 4, seg.size() / 2)
		for d in range(rng.randi_range(25, 45)):
			var k: int = mini(k0 + d / 3 + rng.randi_range(0, 2), seg.size() - 1)
			var tan: Vector3 = Route._tangent(seg, k)
			var right := Vector3(-tan.z, 0, tan.x)
			var p: Vector3 = seg[k] + right * rng.randf_range(-w * 0.6, w * 0.6) + Vector3(0, -0.01, 0)
			# ToiletCreator draws in its frame t (scaled up 2.2x here): the duck's
			# frame is given in unscaled units.
			tc._duck(Transform3D(Basis(Vector3.UP, atan2(tan.x, tan.z) + rng.randf_range(-0.6, 0.6)), p / 2.2))
		var at: Vector3 = seg[mini(k0 + 6, seg.size() - 1)]
		views.append(["duck_race", at + Vector3(0, 3.5, 0) + Route._tangent(seg, k0) * -10.0, at])
	return {"views": views, "ducks": ducks}
