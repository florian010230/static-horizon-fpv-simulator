class_name LandLine
extends RefCounted

## A line on the land - a river or a road - as TerrainCreator carves it
## and other creators query it: points at their level (y = water surface
## for a river, road surface for a road), a half width, and per segment
## a flag where the line is lifted off the ground (a bridge: the land
## under it is left alone). Segments are bucketed on a grid so "nearest
## line to this point" stays cheap for every terrain vertex.

var kind: String ## "river" or "road"
var pts: Array[Vector3] = []
var half: float = 3.0
## How far from the edge the line still shapes the land (valley, cut/fill).
var reach: float = 40.0
## Rivers: channel depth below the water; how wide the valley floor is.
var depth: float = 1.4
var valley: float = 60.0
var bridge := PackedByteArray() ## per segment: 1 = in the air
var _cell: float = 64.0
var _buckets: Dictionary = {}

static func make(line_kind: String, points: Array[Vector3], half_width: float, reach_m: float) -> LandLine:
	var l := LandLine.new()
	l.kind = line_kind
	l.pts = points
	l.half = half_width
	l.reach = reach_m
	l.bridge.resize(maxi(points.size() - 1, 0))
	l.bridge.fill(0)
	l._index()
	return l

## (Re)builds the buckets - call after changing pts.
func _index() -> void:
	_buckets.clear()
	_cell = maxf(half + reach, 32.0)
	for i in range(pts.size() - 1):
		var a: Vector3 = pts[i]
		var b: Vector3 = pts[i + 1]
		for gx in range(floori(minf(a.x, b.x) / _cell), floori(maxf(a.x, b.x) / _cell) + 1):
			for gz in range(floori(minf(a.z, b.z) / _cell), floori(maxf(a.z, b.z) / _cell) + 1):
				var k := Vector2i(gx, gz)
				if not _buckets.has(k):
					_buckets[k] = PackedInt32Array()
				_buckets[k].append(i)

## Nearest point of the line to p (x, z) within its reach:
## [distance from the centre line, level there, segment, t along it],
## or [] when p is out of reach.
func nearest(p: Vector2) -> Array:
	var cx: int = floori(p.x / _cell)
	var cz: int = floori(p.y / _cell)
	var best: float = half + reach
	var out: Array = []
	for gx in range(cx - 1, cx + 2):
		for gz in range(cz - 1, cz + 2):
			var list: Variant = _buckets.get(Vector2i(gx, gz))
			if list == null:
				continue
			for i: int in list:
				var a := Vector2(pts[i].x, pts[i].z)
				var b := Vector2(pts[i + 1].x, pts[i + 1].z)
				var q: Vector2 = Geometry2D.get_closest_point_to_segment(p, a, b)
				var d: float = q.distance_to(p)
				if d < best:
					best = d
					var ab: float = a.distance_to(b)
					var t: float = q.distance_to(a) / ab if ab > 0.001 else 0.0
					out = [d, lerpf(pts[i].y, pts[i + 1].y, t), i, t]
	return out

## Lowest level of the line within `r` m of p (any distance, not just
## its reach), or INF.
func lowest_within(p: Vector2, r: float) -> float:
	var lo: float = INF
	var k: int = ceili(r / _cell)
	var cx: int = floori(p.x / _cell)
	var cz: int = floori(p.y / _cell)
	for gx in range(cx - k, cx + k + 1):
		for gz in range(cz - k, cz + k + 1):
			var list: Variant = _buckets.get(Vector2i(gx, gz))
			if list == null:
				continue
			for i: int in list:
				var a := Vector2(pts[i].x, pts[i].z)
				if a.distance_to(p) < r:
					lo = minf(lo, pts[i].y)
	return lo

## Where this line's centre crosses segment a-b (x, z), as
## [point on this line (with level), index along this line] - or [].
func crossing(a: Vector2, b: Vector2) -> Array:
	for i in range(pts.size() - 1):
		var c := Vector2(pts[i].x, pts[i].z)
		var d := Vector2(pts[i + 1].x, pts[i + 1].z)
		var x: Variant = Geometry2D.segment_intersects_segment(a, b, c, d)
		if x != null:
			var hit: Vector2 = x
			var t: float = hit.distance_to(c) / maxf(c.distance_to(d), 0.001)
			return [Vector3(hit.x, lerpf(pts[i].y, pts[i + 1].y, t), hit.y), i]
	return []

func length() -> float:
	var l: float = 0.0
	for i in range(1, pts.size()):
		l += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
	return l

## Evenly spaced points (every `step` m) along a polyline in the plane,
## corners rounded to radius `r` first - the shape both rivers and
## roads start from (no kinks).
static func smooth_path(corners: Array[Vector3], r: float, step: float) -> Array[Vector3]:
	var round_pts: Array[Vector3] = corners if corners.size() < 3 else Route.rounded(corners, r, 10)
	var out: Array[Vector3] = []
	out.append(round_pts[0])
	var carry: float = 0.0
	for i in range(1, round_pts.size()):
		var a: Vector3 = round_pts[i - 1]
		var b: Vector3 = round_pts[i]
		var seg: float = Vector2(b.x - a.x, b.z - a.z).length()
		var d: float = step - carry
		while d <= seg:
			out.append(a.lerp(b, d / seg))
			d += step
		carry = seg - (d - step)
	if out[-1].distance_to(round_pts[-1]) > step * 0.3:
		out.append(round_pts[-1])
	return out
