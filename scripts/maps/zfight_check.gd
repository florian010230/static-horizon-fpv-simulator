class_name ZFightCheck
extends RefCounted

## Z-fighting (2026-10-14, the user saw flickering textures): two faces
## of different pieces facing the same way, in (nearly) the same plane,
## overlapping, and looking different (material or tint) - the depth
## buffer can't decide which is in front, so they flicker as you fly.
## Works on the faces Geo records when Geo.record_faces is on (SH_ZFIGHT=1
## while a map builds, or SH_SELFTEST_ONLY=zfight). Ground layers are
## SurfaceCheck's job and not recorded.
##   ZFightCheck.run(geo, centre, radius) -> [[position, "mat a / mat b", gap m, area m2], ...]

const GAP: float = 0.015 ## faces closer than this flicker (at a few hundred metres)
const HARD_GAP: float = 0.004 ## ...and closer than this, at any distance
const MIN_AREA: float = 0.01 ## m2 of overlap worth reporting
const FAR_AREA: float = 0.5 ## a 4-15 mm layer counts only this big and outside:
## inside rooms (and on small parts) it is seen from close by, where the
## depth buffer separates a centimetre easily.
const INSIDE: Array[String] = ["hcd_", "vgi_", "chd_", "veh_", "tag"]
const CELL: float = 8.0

static func run(geo: Geo, centre: Vector2 = Vector2.ZERO, radius: float = INF) -> Array:
	var nf: int = geo.face_n.size()
	var nrm := PackedVector3Array()
	nrm.resize(nf)
	var dist := PackedFloat32Array()
	dist.resize(nf)
	var buckets: Dictionary = {} # [normal key, plane slot, cell] -> PackedInt32Array
	for i in range(nf):
		var a: Vector3 = geo.face_pts[i * 4]
		var b: Vector3 = geo.face_pts[i * 4 + 1]
		var c: Vector3 = geo.face_pts[i * 4 + 2]
		var d: Vector3 = geo.face_pts[i * 4 + 3]
		var cr: Vector3 = (b - a).cross(c - a) + (c - a).cross(d - a)
		if cr.length_squared() < 1e-6:
			continue
		var n: Vector3 = cr.normalized()
		if n.dot(geo.face_n[i]) < 0.0:
			n = -n
		var lo: Vector3 = a.min(b).min(c).min(d)
		var hi: Vector3 = a.max(b).max(c).max(d)
		if Vector2((lo.x + hi.x) * 0.5, (lo.z + hi.z) * 0.5).distance_to(centre) > radius:
			continue
		nrm[i] = n
		dist[i] = n.dot(a)
		var nk := Vector3i(roundi(n.x * 20.0), roundi(n.y * 20.0), roundi(n.z * 20.0))
		var slot: int = floori(dist[i] / GAP)
		var x0: int = floori(lo.x / CELL)
		var x1: int = floori(hi.x / CELL)
		var z0: int = floori(lo.z / CELL)
		var z1: int = floori(hi.z / CELL)
		if (x1 - x0 + 1) * (z1 - z0 + 1) > 400:
			continue # (huge faces: far slabs, not where pieces meet)
		for cx in range(x0, x1 + 1):
			for cz in range(z0, z1 + 1):
				var key: Array = [nk, slot, cx, cz]
				if not buckets.has(key):
					buckets[key] = PackedInt32Array()
				buckets[key].append(i)
	var out: Array = []
	var seen: Dictionary = {}
	for key: Array in buckets:
		var own: PackedInt32Array = buckets[key]
		var nb: PackedInt32Array = buckets.get([key[0], key[1] + 1, key[2], key[3]], PackedInt32Array())
		for ii in range(own.size()):
			var i: int = own[ii]
			var others: PackedInt32Array = own.slice(ii + 1)
			others.append_array(nb)
			for j in others:
				if geo.face_piece[i] == geo.face_piece[j]:
					continue
				if absf(dist[i] - dist[j]) >= GAP or nrm[i].dot(nrm[j]) < 0.999:
					continue
				if geo.face_mat[i] == geo.face_mat[j] and _same(geo.face_tint[i], geo.face_tint[j]):
					continue # looks the same: a flicker nobody sees
				var pk: int = mini(i, j) * 4194304 + maxi(i, j)
				if seen.has(pk):
					continue
				seen[pk] = true
				var r: Array = _overlap(geo, i, j, nrm[i])
				var gap: float = absf(dist[i] - dist[j])
				if gap >= HARD_GAP and (r[0] < FAR_AREA or _inside(geo.face_mat_names[geo.face_mat[i]]) or _inside(geo.face_mat_names[geo.face_mat[j]])):
					continue
				if r[0] >= MIN_AREA and geo.filled_at(r[1] + nrm[i] * 0.03):
					continue # inside something else: nobody sees it
				if nrm[i].y < -0.5 and geo.floor_fn.is_valid() and r[1].y < float(geo.floor_fn.call(r[1].x, r[1].z)) + 0.02:
					continue # facing down into the ground (Geo.box_on sinks feet into it)
				if nrm[i].y < -0.5 and geo.support_at(r[1] + nrm[i] * 0.03):
					continue # facing down into a slab (a hall floor on the quay)
				if r[0] >= MIN_AREA:
					out.append([r[1], "%s / %s" % [geo.face_mat_names[geo.face_mat[i]], geo.face_mat_names[geo.face_mat[j]]], absf(dist[i] - dist[j]), r[0]])
	out.sort_custom(func(p: Array, q: Array) -> bool: return p[3] > q[3])
	return out

static func _inside(m: String) -> bool:
	for pre in INSIDE:
		if m.begins_with(pre):
			return true
	return false

static func _same(a: Color, b: Color) -> bool:
	return absf(a.r - b.r) < 0.03 and absf(a.g - b.g) < 0.03 and absf(a.b - b.b) < 0.03

## Overlap area of two faces projected onto their plane, and its centre.
static func _overlap(geo: Geo, i: int, j: int, n: Vector3) -> Array:
	var u: Vector3 = n.cross(Vector3.UP if absf(n.y) < 0.9 else Vector3.RIGHT).normalized()
	var v: Vector3 = n.cross(u)
	var pa := PackedVector2Array()
	var pb := PackedVector2Array()
	for k in range(4):
		var p: Vector3 = geo.face_pts[i * 4 + k]
		var q: Vector3 = geo.face_pts[j * 4 + k]
		if k < 3 or p != geo.face_pts[i * 4 + 2]:
			pa.append(Vector2(p.dot(u), p.dot(v)))
		if k < 3 or q != geo.face_pts[j * 4 + 2]:
			pb.append(Vector2(q.dot(u), q.dot(v)))
	if Geometry2D.is_polygon_clockwise(pa):
		pa.reverse()
	if Geometry2D.is_polygon_clockwise(pb):
		pb.reverse()
	var area: float = 0.0
	var cen := Vector2.ZERO
	for poly: PackedVector2Array in Geometry2D.intersect_polygons(pa, pb):
		var a2: float = 0.0
		for k in range(poly.size()):
			a2 += poly[k].cross(poly[(k + 1) % poly.size()])
		a2 = absf(a2) * 0.5
		area += a2
		var c2 := Vector2.ZERO
		for p in poly:
			c2 += p
		cen += c2 / poly.size() * a2
	if area <= 0.0:
		return [0.0, Vector3.ZERO]
	cen /= area
	var pos: Vector3 = u * cen.x + v * cen.y + n * n.dot(geo.face_pts[i * 4])
	return [area, pos]
