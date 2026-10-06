class_name BuildKit
extends RefCounted

## Small building helpers for hand-laid landmarks in the generated maps
## (a church, a ruin, a gatehouse): walls with openings, gables, pitched
## roof planes - all through Geo, in a local frame the caller gives.
##
## Frame convention for wall(): the wall runs along the frame's local x
## from x0 to x1, its middle plane at local z = 0, thickness along z,
## from local y0 up to y1. Openings are Rect2(x, y, w, h) in those wall
## coordinates (x along, y up); they may share x ranges (storeys).

## A wall with rectangular openings, as boxes: full-height piers between
## the openings, a sill piece under and a lintel piece over each. With
## `level` set, pieces reaching down to it are sunk into the real ground
## (Geo.box_on).
static func wall(g: Geo, xf: Transform3D, x0: float, x1: float, y0: float, y1: float, th: float, holes: Array, mat: String, level: float = NAN, collide: bool = true) -> void:
	# Columns between every opening's side; in each column, solid runs
	# between the openings that cover it. Neighbouring columns with the
	# same openings are merged.
	var xs: Array = [x0, x1]
	for h: Rect2 in holes:
		for x in [h.position.x, h.end.x]:
			if x > x0 and x < x1:
				xs.append(x)
	xs.sort()
	var cols: Array = [] # [xa, xb, holes covering]
	for k in range(xs.size() - 1):
		var xa: float = xs[k]
		var xb: float = xs[k + 1]
		if xb - xa < 0.005:
			continue
		var xm: float = (xa + xb) * 0.5
		var cover: Array = []
		for h: Rect2 in holes:
			if xm > h.position.x and xm < h.end.x:
				cover.append(h)
		if not cols.is_empty() and cols[-1][2] == cover:
			cols[-1][1] = xb
		else:
			cols.append([xa, xb, cover])
	for c: Array in cols:
		var cover: Array = c[2]
		cover.sort_custom(func(a: Rect2, b: Rect2) -> bool: return a.position.y < b.position.y)
		var y: float = y0
		for h: Rect2 in cover:
			var hy0: float = clampf(h.position.y, y0, y1)
			if hy0 - y > 0.01:
				_piece(g, xf, Vector3((c[0] + c[1]) * 0.5, (y + hy0) * 0.5, 0), Vector3(c[1] - c[0], hy0 - y, th), mat, level, collide)
			y = maxf(y, clampf(h.end.y, y0, y1))
		if y1 - y > 0.01:
			_piece(g, xf, Vector3((c[0] + c[1]) * 0.5, (y + y1) * 0.5, 0), Vector3(c[1] - c[0], y1 - y, th), mat, level, collide)

static func _piece(g: Geo, xf: Transform3D, c: Vector3, s: Vector3, mat: String, level: float, collide: bool) -> void:
	if is_nan(level):
		g.box_xf(xf * Transform3D(Basis(), c), s, mat, collide)
	else:
		g.box_on(xf * Transform3D(Basis(), c), s, mat, level, collide)

## A gable triangle on top of a wall: base from x0 to x1 at y0, apex h
## higher over the middle, thickness th (same frame as wall()).
static func gable(g: Geo, xf: Transform3D, x0: float, x1: float, y0: float, h: float, th: float, mat: String) -> void:
	g.prism(xf * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3.ZERO), [Vector2(x0, y0), Vector2(x1, y0), Vector2((x0 + x1) * 0.5, y0 + h)], th, mat)

## A pitched roof over a rectangle: ridge along local z (length L incl.
## overhang), eaves at y_eaves on both sides x = +-half_w, pitch in
## radians, slab thickness th, overhang ov past the walls. `skip`: which
## side to leave out (0 none, -1 / +1) - a ruin's fallen-in slope.
static func roof(g: Geo, xf: Transform3D, half_w: float, L: float, y_eaves: float, pitch: float, th: float, ov: float, mat: String, skip: int = 0) -> float:
	var run: float = half_w + ov
	var rise: float = half_w * tan(pitch)
	var slope: float = run / cos(pitch)
	for s in [-1, 1]:
		if s == skip:
			continue
		# Centre of the slab: halfway from the ridge to the eave's edge.
		var c := Vector3(s * run * 0.5, y_eaves + rise - run * 0.5 * tan(pitch) + th * 0.5, 0)
		g.box_xf(xf * Transform3D(Basis(Vector3.FORWARD, s * pitch), c), Vector3(slope + 0.05, th, L), mat)
	return y_eaves + rise
