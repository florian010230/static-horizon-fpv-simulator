class_name VillageKit
extends RefCounted

## Helpers for a designed village. The map decides the layout - where
## the roads run (RoadCreator), which stretches of them get houses,
## where the green is; the kit does the work along it: rectangular plots
## (Grundstuecke) square to a road, kept clear of every road, river,
## pond and each other and levelled to the road; each built by
## HouseCreator.build_plot (house, fences, garden; 1 in 5 open inside);
## street lamps; a village green with a lime tree, benches and a maypole.
##
##   var plots: Array = []
##   VillageKit.plots_along(land, main, 40.0, 260.0, 1.0, plots)   # before land.build()
##   land.build(...)
##   var info := VillageKit.build_plots(geo, plots, first_seed)     # info.trees -> TreeCreator
##   VillageKit.lamps(roads, main, 40.0, 260.0)
##   trees += VillageKit.green(geo, Vector3(x, level, z))
##
## A plot: {"frame": Transform3D (origin mid street edge, +z to the street,
## x along it), "width", "depth", "box" (for overlap checks)}.
## Real numbers: plots ~22-26 m wide and ~30-40 m deep, lamps every ~35 m.

const PLOT_W: float = 24.0
const PLOT_GAP: float = 2.0 ## between neighbouring plots' fences
const PLOT_D: float = 34.0
const VERGE_STRIP: float = 1.5 ## grass between the road's verge and the front fence

## Plots along `road` from d0 to d1 m (along its line), on `side` (+1 =
## right of its direction, -1 = left), one every PLOT_W, added to
## `plots` (pass the same array for every call - plots never overlap).
## A spot that would touch a road, water or another plot is skipped.
## Call before land.build(): each plot levels its ground to the road.
static func plots_along(land: TerrainCreator, road: RoadCreator, d0: float, d1: float, side: float, plots: Array, opts: Dictionary = {}) -> int:
	var w_plot: float = opts.get("width", PLOT_W)
	var depth: float = opts.get("depth", PLOT_D)
	var route: Route = Route.from_pts(road.line.pts)
	var added: int = 0
	var d: float = d0 + w_plot * 0.5
	while d <= d1 - w_plot * 0.5 + 0.01:
		var smp: Array = route.sample(d)
		d += w_plot
		var p: Vector3 = smp[0]
		var tan: Vector3 = smp[1]
		var out: Vector3 = Vector3(-tan.z, 0, tan.x) * side # away from the road
		# The plot lies at the level of the ground under the road: the road's
		# bed reaches past the verge into the plot's first grid row (8 m),
		# and a plot set any higher sloped down to it there - under the
		# front steps, the driveway, the garage (a kerb-high step showed as
		# a gap under them).
		var level: float = p.y - TerrainCreator.ROAD_SINK
		var front: Vector3 = p + out * (road.line.half + 1.0 + VERGE_STRIP)
		front.y = level
		var zdir: Vector3 = -out # the plot frame's +z faces the street
		var frame := Transform3D(Basis(Vector3.UP, atan2(zdir.x, zdir.z)), front)
		var w: float = w_plot - PLOT_GAP
		var c3: Vector3 = frame * Vector3(0, 0, -depth * 0.5)
		var c := Vector2(c3.x, c3.z)
		var ax := Vector2(frame.basis.x.x, frame.basis.x.z).normalized()
		var box: Array = [c, ax, w * 0.5, depth * 0.5]
		if not _clear(land, box, frame, w, depth, plots):
			continue
		# Level ground: the plot, plus a grid cell's diagonal round its sides
		# and back (so no terrain triangle lifts its edge on a slope), only a
		# metre toward the street (the road's own bed is there).
		var m: float = land.road_bed()
		var c_ext3: Vector3 = frame * Vector3(0, 0, -depth * 0.5 - (m - 1.0) * 0.5)
		land.flat_plot(Vector2(c_ext3.x, c_ext3.z), ax, w * 0.5 + m, depth * 0.5 + (m + 1.0) * 0.5, level, 6.0, [c, w * 0.5, depth * 0.5])
		plots.append({"frame": frame, "width": w, "depth": depth, "box": box})
		added += 1
	return added

static func _clear(land: TerrainCreator, box: Array, frame: Transform3D, w: float, depth: float, plots: Array) -> bool:
	for pl: Dictionary in plots:
		if _obb_overlap(box, pl.box, 0.5):
			return false
	for u in [-0.5, -0.25, 0.0, 0.25, 0.5]:
		for v in [-1.0, -0.75, -0.5, -0.25, -0.03]:
			var q3: Vector3 = frame * Vector3(u * w, 0, v * depth)
			var q := Vector2(q3.x, q3.z)
			for l: LandLine in land.roads:
				var n: Array = l.nearest(q)
				if not n.is_empty() and n[0] < l.half + 1.2:
					return false
			if land.in_pond(q.x, q.y, 4.0):
				return false
			for rv: LandLine in land.rivers:
				var n: Array = rv.nearest(q)
				if not n.is_empty() and n[0] < rv.half + TerrainCreator.BANK + 6.0:
					return false
			for k: Array in land._clear:
				if k.size() > 2 and k[2] == "keep_plots_out" and q.distance_to(k[0]) < k[1]:
					return false
	return true

## Oriented rectangles [centre, x axis, half x, half z] overlap (with margin)?
static func _obb_overlap(a: Array, b: Array, margin: float) -> bool:
	for box: Array in [a, b]:
		var ax: Vector2 = box[1]
		for axis: Vector2 in [ax, Vector2(-ax.y, ax.x)]:
			var ca: float = (a[0] as Vector2).dot(axis)
			var cb: float = (b[0] as Vector2).dot(axis)
			var ea: float = absf(axis.dot(a[1])) * a[2] + absf(axis.dot(Vector2(-a[1].y, a[1].x))) * a[3]
			var eb: float = absf(axis.dot(b[1])) * b[2] + absf(axis.dot(Vector2(-b[1].y, b[1].x))) * b[3]
			if absf(ca - cb) > ea + eb + margin:
				return false
	return true

## Houses, fences and gardens on every plot (HouseCreator.build_plot),
## seeds first_seed.., every fifth one open inside. Returns {"trees",
## "views", "open"}.
static func build_plots(geo: Geo, plots: Array, first_seed: int) -> Dictionary:
	var trees: Array = []
	var views: Array = []
	var n_open: int = 0
	for i in range(plots.size()):
		var open: bool = HouseCreator.accessible(i)
		n_open += 1 if open else 0
		var info: Dictionary = HouseCreator.build_plot(geo, plots[i], first_seed + i, {"interior": open})
		if open and n_open == 1:
			for v: Array in info.views:
				if v[0] in ["front", "back"] or String(v[0]).begins_with("way_in1"):
					views.append(["house_" + v[0], v[1], v[2]])
		for v: Array in info.views:
			if String(v[0]).begins_with("gnome"):
				views.append(v)
		trees.append_array(info.trees)
	return {"trees": trees, "views": views, "open": n_open}

## Street lamps along `road` from d0 to d1, alternating sides.
static func lamps(roads: Roads, road: RoadCreator, d0: float, d1: float, every: float = 34.0) -> void:
	var route: Route = Route.from_pts(road.line.pts)
	var d: float = d0
	var side: float = 1.0
	while d <= d1:
		var smp: Array = route.sample(d)
		var p: Vector3 = smp[0]
		var t: Vector3 = smp[1]
		var right: Vector3 = Vector3(-t.z, 0, t.x) * side
		var foot: Vector3 = p + right * (road.line.half + 1.5)
		foot.y = p.y
		if road.land != null: # into the verge where it falls away
			foot.y = minf(p.y, road.land.ground(foot.x, foot.z)) - Geo.SINK
		roads.lamp(foot, -right)
		side = -side
		d += every

## A village green at g (on level ground the map has made): a big lime
## tree, three benches round it, a blue-and-white maypole. Returns the
## tree for TreeCreator.plant.
static func green(geo: Geo, g: Vector3) -> Array:
	if not geo.has_material("vl_wood"):
		geo.add_material("vl_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.1, 1.0, 0.9), 1.2))
		geo.add_material("vl_paint", Geo.flat_mat(Color.WHITE, 0.6))
	for k in range(3):
		var a: float = TAU * k / 3.0 + 0.4
		var b: Vector3 = g + Vector3(cos(a), 0, sin(a)) * 9.5
		var yaw: float = atan2(cos(a), sin(a))
		geo.box(b + Vector3(0, 0.45, 0), Vector3(1.8, 0.06, 0.45), "vl_wood", yaw)
		geo.box(b + Vector3(0, 0.75, 0) + Vector3(cos(a), 0, sin(a)) * 0.22, Vector3(1.8, 0.4, 0.06), "vl_wood", yaw)
		for sx in [-0.8, 0.8]:
			geo.box(b + Vector3(0, 0.22, 0) + Vector3(sin(a), 0, -cos(a)) * sx, Vector3(0.08, 0.44, 0.45), "vl_wood", yaw)
	var mp: Vector3 = g + Vector3(-6, 0, 4)
	geo.tint = Color(0.95, 0.95, 0.95)
	geo.cylinder(mp, mp + Vector3(0, 18, 0), 0.16, "vl_paint", 10)
	geo.tint = Color(0.15, 0.35, 0.75)
	for k in range(9):
		var y: float = 1.0 + k * 1.8
		geo.cylinder(mp + Vector3(0, y, 0), mp + Vector3(0, y + 0.7, 0), 0.165, "vl_paint", 10, false)
	geo.tint = Color(0.2, 0.45, 0.18)
	geo.cylinder(mp + Vector3(0, 13.5, 0), mp + Vector3(0, 13.8, 0), 1.3, "vl_paint", 16, false)
	geo.cone(mp + Vector3(0, 17.2, 0), mp + Vector3(0, 19.6, 0), 0.9, 0.05, "vl_paint", 8, false)
	geo.tint = Color.WHITE
	return [[g + Vector3(4, 0, -3), "maple", 77, "none"]]
