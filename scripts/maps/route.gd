class_name Route
extends RefCounted

## A path on the map built like a surveyor would lay out a railway or a
## road: straights and circular curves, each piece starting where the
## last one ended and in its direction - so there are never kinks, and a
## train could really run along a rail route. Headings are in degrees in
## the ground plane: 0 = +x, 90 = +z (south; north is -z), and a positive
## curve angle turns toward larger headings.
##
## The result is a list of points (`pts`, a few metres apart on curves)
## that Geo.sweep() extrudes into rails, ballast, roads or pipes.
## `ground` (optional Callable(x, z) -> float) sets each point's height,
## so a route can follow a terrain.

var pts: Array[Vector3] = []
var heading: float = 0.0 ## degrees, at the end of the route
var ground: Callable

static func from(p: Vector3, heading_deg: float, ground_fn: Callable = Callable()) -> Route:
	var r := Route.new()
	r.ground = ground_fn
	r.heading = heading_deg
	r.pts.append(r._y(p))
	return r

## A route through given points (e.g. one track of a double line made
## with offset_pts); the heading is taken from the last segment.
static func from_pts(p: Array[Vector3]) -> Route:
	var r := Route.new()
	r.pts = p.duplicate()
	var d: Vector3 = p[-1] - p[-2]
	r.heading = rad_to_deg(atan2(d.z, d.x))
	return r

## Distance along the route where it first crosses x = `x` (for routes
## running roughly along x), or -1.
func dist_at_x(x: float) -> float:
	var acc: float = 0.0
	for i in range(1, pts.size()):
		var a: Vector3 = pts[i - 1]
		var b: Vector3 = pts[i]
		var seg: float = a.distance_to(b)
		if (a.x - x) * (b.x - x) <= 0.0 and absf(b.x - a.x) > 0.0001:
			return acc + seg * (x - a.x) / (b.x - a.x)
		acc += seg
	return -1.0

static func dir_of(heading_deg: float) -> Vector3:
	var h: float = deg_to_rad(heading_deg)
	return Vector3(cos(h), 0.0, sin(h))

func end() -> Vector3:
	return pts[-1]

func dir() -> Vector3:
	return dir_of(heading)

func _y(p: Vector3) -> Vector3:
	if ground.is_valid():
		p.y = ground.call(p.x, p.z)
	return p

## Straight ahead for `length` metres (points every `step` m).
func straight(length: float, step: float = 12.0) -> Route:
	var n: int = maxi(1, ceili(length / step))
	var a: Vector3 = pts[-1]
	var d: Vector3 = dir()
	for i in range(1, n + 1):
		var p: Vector3 = a + d * (length * i / n)
		p.y = a.y
		pts.append(_y(p))
	return self

## Circular curve of `radius`, turning by `angle_deg` (sign = side).
func arc(radius: float, angle_deg: float, step: float = 4.0) -> Route:
	var a: Vector3 = pts[-1]
	var h0: float = deg_to_rad(heading)
	var s: float = signf(angle_deg)
	# Centre of the curve: to the side we turn toward.
	var c: Vector3 = a + dir_of(heading + 90.0 * s) * radius
	var total: float = deg_to_rad(absf(angle_deg))
	var n: int = maxi(2, ceili(total * radius / step))
	for i in range(1, n + 1):
		var t: float = h0 + s * total * i / n
		# Point on the circle whose tangent heading is t.
		var p: Vector3 = c - dir_of(rad_to_deg(t) + 90.0 * s) * radius
		p.y = a.y
		pts.append(_y(p))
	heading += angle_deg
	return self

## Straight on to a point (sets the heading) - use only where the new
## direction equals the current one, or for things that may kink
## (a pipe run, a fence); rails and roads use straight()/arc().
func to(p: Vector3, step: float = 12.0) -> Route:
	var a: Vector3 = pts[-1]
	var d: Vector3 = p - a
	d.y = 0.0
	if d.length() < 0.01:
		return self
	heading = rad_to_deg(atan2(d.z, d.x))
	var n: int = maxi(1, ceili(d.length() / step))
	for i in range(1, n + 1):
		pts.append(_y(a.lerp(p, float(i) / n)) if ground.is_valid() else a.lerp(p, float(i) / n))
	return self

## Gradually climb/descend to height y over the route's last `length`
## metres (for ramps and bridges): re-heights the tail of the points.
func ramp_tail(length: float, y: float) -> Route:
	var d: float = 0.0
	var start_y: float = 0.0
	var i: int = pts.size() - 1
	while i > 0 and d < length:
		d += Vector2(pts[i].x - pts[i - 1].x, pts[i].z - pts[i - 1].z).length()
		i -= 1
	start_y = pts[i].y
	var acc: float = 0.0
	for k in range(i + 1, pts.size()):
		acc += Vector2(pts[k].x - pts[k - 1].x, pts[k].z - pts[k - 1].z).length()
		var t: float = clampf(acc / maxf(d, 0.01), 0.0, 1.0)
		pts[k].y = lerpf(start_y, y, t * t * (3.0 - 2.0 * t))
	return self

## Everything at one height.
func at_height(y: float) -> Route:
	for i in range(pts.size()):
		pts[i].y = y
	return self

func raise(dy: float) -> Route:
	for i in range(pts.size()):
		pts[i].y += dy
	return self

func length() -> float:
	var l: float = 0.0
	for i in range(1, pts.size()):
		l += pts[i].distance_to(pts[i - 1])
	return l

## Position and unit direction at distance d along the route.
func sample(d: float) -> Array:
	d = clampf(d, 0.0, length())
	var acc: float = 0.0
	for i in range(1, pts.size()):
		var seg: float = pts[i].distance_to(pts[i - 1])
		if acc + seg >= d or i == pts.size() - 1:
			var t: float = clampf((d - acc) / maxf(seg, 0.0001), 0.0, 1.0)
			return [pts[i - 1].lerp(pts[i], t), (pts[i] - pts[i - 1]).normalized()]
		acc += seg
	return [pts[-1], Vector3.RIGHT]

## The part of the route between distances d0 and d1.
func slice(d0: float, d1: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.append(sample(d0)[0])
	var acc: float = 0.0
	for i in range(1, pts.size()):
		acc += pts[i].distance_to(pts[i - 1])
		if acc > d0 + 0.01 and acc < d1 - 0.01:
			out.append(pts[i])
	out.append(sample(d1)[0])
	return out

## Points shifted sideways by `o` metres (+ = to the right of travel,
## i.e. toward heading + 90) - parallel tracks, kerbs, lane lines.
func offset(o: float) -> Array[Vector3]:
	return Route.offset_pts(pts, o)

static func offset_pts(p: Array[Vector3], o: float) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for i in range(p.size()):
		var t: Vector3 = _tangent(p, i)
		var side := Vector3(-t.z, 0.0, t.x).normalized()
		out.append(p[i] + side * o)
	return out

static func _tangent(p: Array[Vector3], i: int) -> Vector3:
	var a: Vector3 = p[maxi(i - 1, 0)]
	var b: Vector3 = p[mini(i + 1, p.size() - 1)]
	var t: Vector3 = b - a
	t.y = 0.0
	return t.normalized() if t.length() > 0.0001 else Vector3.RIGHT

## A copy of this route starting where this one ends (to branch off).
func fork() -> Route:
	var r := Route.new()
	r.ground = ground
	r.heading = heading
	r.pts.append(pts[-1])
	return r

## Route that starts at distance d on this one, with its direction.
func fork_at(d: float) -> Route:
	var s: Array = sample(d)
	var v: Vector3 = s[1]
	var r := Route.new()
	r.ground = ground
	r.heading = rad_to_deg(atan2(v.z, v.x))
	r.pts.append(s[0])
	return r

func reversed() -> Route:
	var r := Route.new()
	r.ground = ground
	r.pts = pts.duplicate()
	r.pts.reverse()
	var d: Vector3 = r.pts[-1] - r.pts[-2] if r.pts.size() > 1 else Vector3.RIGHT
	r.heading = rad_to_deg(atan2(d.z, d.x))
	return r

## Polyline with every corner rounded into an arc of radius `r` (pipes
## and conveyors that turn corners in 3D, even vertically).
static func rounded(corners: Array, r: float, seg: int = 6) -> Array[Vector3]:
	var out: Array[Vector3] = []
	out.append(corners[0])
	for i in range(1, corners.size() - 1):
		var p: Vector3 = corners[i]
		var a: Vector3 = (corners[i - 1] - p)
		var b: Vector3 = (corners[i + 1] - p)
		var la: float = a.length()
		var lb: float = b.length()
		a /= la
		b /= lb
		var ang: float = a.angle_to(b)
		if ang > PI - 0.01:
			out.append(p)
			continue
		var cut: float = minf(r / tan(ang * 0.5), minf(la, lb) * 0.45)
		var p0: Vector3 = p + a * cut
		var p1: Vector3 = p + b * cut
		# Quadratic Bezier through the corner - close to a circular arc.
		for k in range(seg + 1):
			var t: float = float(k) / seg
			out.append(p0.lerp(p, t).lerp(p.lerp(p1, t), t))
	out.append(corners[-1])
	return out
