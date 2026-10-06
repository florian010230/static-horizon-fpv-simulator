class_name SurfaceCheck
extends RefCounted

## Glitch check for a generated map's ground surfaces (self-test, and
## `SH_SURFCHECK=1` while a map loads), from the meshes Geo committed
## (meta "geo_mat" / "geo_layer") and the terrain as it really is (the
## heights of its HeightMapShape3D - the mesh splits its cells the same
## way). Judged inside the flight area only:
##
## - **poke**: terrain above a road/paving/plot surface (a ground layer
##   >= 1) - the hillside showing through the asphalt.
## - **float**: a ground-layer surface more than FLOAT_GAP over the
##   terrain under it with nothing solid in between - a road edge or a
##   yard hanging in the air (the road's skirt hides 0.4 m; bridges and
##   decks stand on piers, which count as support; anything over
##   FLOAT_MAX is a bridge or a deck by intent).
## - **stack**: two upward faces of different materials within
##   STACK_GAP of each other that the depth buffer can't separate (the
##   same ground layer, or plain materials, incl. the terrain itself) -
##   they flicker against each other at a distance.
##
## Returns {"poke": [...], "float": [...], "stack": [...]} with entries
## [position, what, by how much], plus "tris" and "ms".

const POKE: float = 0.03
const FLOAT_GAP: float = 0.45
const FLOAT_MAX: float = 3.0
const STACK_GAP: float = 0.035
const BUCKET: float = 4.0
## Surfaces laid on purpose over ground their creator lowered under them
## (pond shores, river banks: the terrain is kept below; field canopies
## stand at the crop's height) - only their poking counts.
const DRAPED: Array[String] = ["tr_", "rv_", "fd_"]
## Never judged as hanging: a track's ballast bed is a raised bank with
## its own sloped shoulders down to the ground.
const RAISED: Array[String] = ["rw_ballast", "rw_bed", "ballast"]
## Never judged as stacked: tumbled rubble (its tilted blocks overlap at
## random; nobody sees that flicker in a heap).
const LOOSE: Array[String] = ["rubble"]
## Faces smaller than this (m²) aren't checked against each other.
const STACK_AREA: float = 0.25

static func run(map: BuiltMap, pad: float = 30.0) -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var b: Array = map.border()
	var centre: Vector2 = b[4] if b.size() > 4 else Vector2.ZERO
	var radius: float = b[1] + pad
	var grids: Array = _terrain_grids(map)
	# Upward faces of every Geo batch in the flight area:
	# [a, b, c (Vector3), material name, effective layer, sample points]
	var faces: Array = []
	for mi: MeshInstance3D in _batches(map):
		var mat: String = mi.get_meta("geo_mat", "")
		var layer: int = mi.get_meta("geo_layer", -1)
		var arr: Array = mi.mesh.surface_get_arrays(0)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var nr: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var xf: Transform3D = mi.global_transform
		var count: int = idx.size() / 3 if not idx.is_empty() else v.size() / 3
		for t in range(count):
			var i0: int = idx[t * 3] if not idx.is_empty() else t * 3
			var i1: int = idx[t * 3 + 1] if not idx.is_empty() else t * 3 + 1
			var i2: int = idx[t * 3 + 2] if not idx.is_empty() else t * 3 + 2
			if nr.size() > i0 and nr[i0].y < 0.94:
				continue # not facing up
			var p0: Vector3 = xf * v[i0]
			var p1: Vector3 = xf * v[i1]
			var p2: Vector3 = xf * v[i2]
			var n: Vector3 = (p1 - p0).cross(p2 - p0)
			if n.length_squared() < 1e-8 or absf(n.normalized().y) < 0.94:
				continue
			var c: Vector3 = (p0 + p1 + p2) / 3.0
			if Vector2(c.x, c.z).distance_to(centre) > radius:
				continue
			faces.append([p0, p1, p2, mat, maxi(layer, 0)])
	var out := {"poke": [], "float": [], "stack": [], "tris": faces.size()}
	var t1: int = Time.get_ticks_msec()
	# Against the terrain.
	var cand: Array = [] # float candidates, judged once every face is bucketed
	var land: Variant = map.get("land")
	if not grids.is_empty():
		for f: Array in faces:
			for s: Vector3 in _samples(f):
				var h: float = _terrain_at(grids, s.x, s.z)
				if is_nan(h):
					continue
				if f[4] >= 1:
					if h > s.y + POKE and not (_draped(f[3]) and _by_road(land, s)):
						out.poke.append([s, f[3], snappedf(h - s.y, 0.01)])
						break
					var gap: float = s.y - h
					if gap > FLOAT_GAP and not _draped(f[3]) and not _pre(f[3], RAISED) and gap < FLOAT_MAX and not map.geo.solid_below(Vector2(s.x, s.z), h + 0.05, s.y - 0.02):
						cand.append([s, f[3], snappedf(gap, 0.01), h])
						break
				elif absf(s.y - h) < STACK_GAP and _level(grids, s.x, s.z):
					out.stack.append([s, f[3] + " / terrain", snappedf(s.y - h, 0.001)])
					break
	var t2: int = Time.get_ticks_msec()
	# Against each other: faces bucketed by their bounding box, each face's
	# samples looked up in the others.
	# Only faces big enough to show from a distance (small furniture
	# parts are seen up close, where a centimetre is plenty).
	var ylo := PackedFloat32Array()
	var yhi := PackedFloat32Array()
	var big := PackedByteArray()
	ylo.resize(faces.size())
	yhi.resize(faces.size())
	big.resize(faces.size())
	var grid: Dictionary = {}
	for fi in range(faces.size()):
		var f: Array = faces[fi]
		ylo[fi] = minf(minf(f[0].y, f[1].y), f[2].y)
		yhi[fi] = maxf(maxf(f[0].y, f[1].y), f[2].y)
		big[fi] = 1 if ((f[1] - f[0]) as Vector3).cross(f[2] - f[0]).length() * 0.5 >= STACK_AREA else 0
		if big[fi] == 0:
			continue
		var lo := Vector2(minf(minf(f[0].x, f[1].x), f[2].x), minf(minf(f[0].z, f[1].z), f[2].z))
		var hi := Vector2(maxf(maxf(f[0].x, f[1].x), f[2].x), maxf(maxf(f[0].z, f[1].z), f[2].z))
		for gx in range(floori(lo.x / BUCKET), floori(hi.x / BUCKET) + 1):
			for gz in range(floori(lo.y / BUCKET), floori(hi.y / BUCKET) + 1):
				var k := Vector2i(gx, gz)
				if not grid.has(k):
					grid[k] = []
				grid[k].append(fi)
	# A float candidate is fine when another face lies between it and the
	# ground (it rests on something drawn: a yard, a bridge's body), or a
	# road's bridge span is there.
	for e: Array in cand:
		var s: Vector3 = e[0]
		var held: bool = false
		for fj: int in grid.get(Vector2i(floori(s.x / BUCKET), floori(s.z / BUCKET)), []):
			if ylo[fj] > s.y - 0.02 or yhi[fj] < e[3] + 0.05:
				continue
			var y: float = _y_in(faces[fj], s)
			if not is_nan(y) and y < s.y - 0.02 and y > e[3] + 0.05:
				held = true
				break
		if not held and land is TerrainCreator:
			for l: LandLine in (land as TerrainCreator).roads:
				var n: Array = l.nearest(Vector2(s.x, s.z))
				if not n.is_empty() and n[0] < l.half + 4.0 and (l.bridge[mini(n[2], l.bridge.size() - 1)] == 1 or l.bridge[maxi(n[2] - 1, 0)] == 1 or l.bridge[mini(n[2] + 1, l.bridge.size() - 1)] == 1):
					held = true
					break
		if not held:
			out.float.append(e.slice(0, 3))
	var seen: Dictionary = {}
	for fi in range(faces.size()):
		if big[fi] == 0:
			continue
		var f: Array = faces[fi]
		var s: Vector3 = (f[0] + f[1] + f[2]) / 3.0
		var mat: String = f[3]
		var lay: int = f[4]
		for fj: int in grid.get(Vector2i(floori(s.x / BUCKET), floori(s.z / BUCKET)), []):
			if fj == fi or ylo[fj] > s.y + STACK_GAP or yhi[fj] < s.y - STACK_GAP:
				continue
			var g: Array = faces[fj]
			if g[3] == mat or g[4] != lay or _pre(mat, LOOSE) or _pre(g[3], LOOSE):
				continue # same material (one surface), or ground layers apart
			var y: float = _y_in(g, s)
			if is_nan(y) or absf(y - s.y) >= STACK_GAP:
				continue
			var key: String = "%s|%s|%d|%d" % [mat, g[3], floori(s.x / 16.0), floori(s.z / 16.0)] if mat < g[3] else "%s|%s|%d|%d" % [g[3], mat, floori(s.x / 16.0), floori(s.z / 16.0)]
			if seen.has(key):
				break
			seen[key] = true
			out.stack.append([s, "%s / %s" % [mat, g[3]], snappedf(y - s.y, 0.001)])
			break
	out["ms"] = Time.get_ticks_msec() - t0
	out["parts"] = [t1 - t0, t2 - t1, Time.get_ticks_msec() - t2]
	return out

## One line per kind for a log, with the first few of each.
static func report(name: String, r: Dictionary, n: int = 8) -> String:
	var s: String = "SURFCHECK %s: %d upward faces, %d ms %s; poke %d, float %d, stack %d" % [name, r.tris, r.ms, r.get("parts", []), r.poke.size(), r.float.size(), r.stack.size()]
	for kind in ["poke", "float", "stack"]:
		var by: Dictionary = {}
		for e: Array in r[kind]:
			by[e[1]] = by.get(e[1], 0) + 1
		if not by.is_empty():
			s += "\n  %s by surface: %s" % [kind, by]
		for k in range(mini(n, r[kind].size())):
			s += "\n  %s %s" % [kind, r[kind][k]]
	return s

## Is the terrain nearly level here (under 3 % - else a surface meeting it
## crosses it along a line, a water's edge, rather than lying on it)?
static func _level(grids: Array, x: float, z: float) -> bool:
	var gx: float = _terrain_at(grids, x + 1.0, z) - _terrain_at(grids, x - 1.0, z)
	var gz: float = _terrain_at(grids, x, z + 1.0) - _terrain_at(grids, x, z - 1.0)
	return absf(gx) < 0.06 and absf(gz) < 0.06

## Under a road's earthworks (its bed and cut/fill slope): a river bank
## buried by the approach to a bridge is covered, not showing through.
static func _by_road(land: Variant, s: Vector3) -> bool:
	if not land is TerrainCreator:
		return false
	var t: TerrainCreator = land
	for l: LandLine in t.roads:
		var n: Array = l.nearest(Vector2(s.x, s.z))
		if not n.is_empty() and n[0] < l.half + t.road_bed() + TerrainCreator.ROAD_SLOPE:
			return true
	return false

## Known findings per map (scene name -> {kind: allowed count}) that the
## self-test tolerates for now - each one listed in notes/r2-maps.md.
const KNOWN := {
	# The works road's turning circle stands ~2.9 m over the industrial
	# yard's levelled ground (IndustryCreator.plan levels below the road's
	# grade); river banks poking at three spots away from the roads.
	"TestValley": {"poke": 12, "float": 8, "stack": 2},
	# Not redesigned yet (Round 2 maps track) - listed in notes/r2-maps.md:
	"Harbour": {"stack": 20}, # platform edges 1 cm over the platforms, road lines on rail grooves
	"ConstructionSite": {"stack": 3}, # crane decks on steel
	"Office": {"stack": 1}, # a car's glass and roof
}

## Self-test verdict: "" when fine, else what's wrong.
static func verdict(name: String, r: Dictionary) -> String:
	var k: Dictionary = KNOWN.get(name, {})
	var bad: Array = []
	for kind in ["poke", "float", "stack"]:
		if r[kind].size() > k.get(kind, 0):
			bad.append("%s %d (allowed %d): %s" % [kind, r[kind].size(), k.get(kind, 0), str(r[kind].slice(0, 3))])
	return "; ".join(bad)

static func _pre(mat: String, list: Array[String]) -> bool:
	for pre in list:
		if mat.begins_with(pre):
			return true
	return false

static func _draped(mat: String) -> bool:
	for pre in DRAPED:
		if mat.begins_with(pre):
			return true
	return false

static func _batches(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is MeshInstance3D and c.has_meta("geo_mat") and (c as MeshInstance3D).mesh != null:
			out.append(c)
		out.append_array(_batches(c))
	return out

## The centroid, and for a face bigger than a few square metres points
## halfway to each corner too.
static func _samples(f: Array) -> Array:
	var c: Vector3 = (f[0] + f[1] + f[2]) / 3.0
	var area: float = ((f[1] - f[0]) as Vector3).cross(f[2] - f[0]).length() * 0.5
	if area < 4.0:
		return [c]
	return [c, (c + f[0]) * 0.5, (c + f[1]) * 0.5, (c + f[2]) * 0.5]

## Height of face f at the (x, z) of p, NAN when p is outside it.
static func _y_in(f: Array, p: Vector3) -> float:
	var a: Vector3 = f[0]
	var b: Vector3 = f[1]
	var c: Vector3 = f[2]
	var v0 := Vector2(b.x - a.x, b.z - a.z)
	var v1 := Vector2(c.x - a.x, c.z - a.z)
	var v2 := Vector2(p.x - a.x, p.z - a.z)
	var den: float = v0.x * v1.y - v1.x * v0.y
	if absf(den) < 1e-9:
		return NAN
	var u: float = (v2.x * v1.y - v1.x * v2.y) / den
	var w: float = (v0.x * v2.y - v2.x * v0.y) / den
	if u < 0.01 or w < 0.01 or u + w > 0.99:
		return NAN # (edges excluded: neighbours meeting there aren't stacked)
	return a.y + (b.y - a.y) * u + (c.y - a.y) * w

## Every collision heightfield under the map: [x0, z0, spacing, nx, nz, heights].
static func _terrain_grids(map: Node) -> Array:
	var out: Array = []
	for body in map.find_children("TerrainCollision", "StaticBody3D", true, false):
		for cs in body.get_children():
			if cs is CollisionShape3D and cs.shape is HeightMapShape3D:
				var hm: HeightMapShape3D = cs.shape
				var s: float = cs.scale.x
				var bp: Vector3 = (body as Node3D).global_position
				out.append([bp.x - (hm.map_width - 1) * s * 0.5, bp.z - (hm.map_depth - 1) * s * 0.5, s, hm.map_width, hm.map_depth, hm.map_data])
	return out

## Terrain height at (x, z) as the mesh/collision has it (cells split
## along the 10-01 diagonal), NAN off every grid.
static func _terrain_at(grids: Array, x: float, z: float) -> float:
	for g: Array in grids:
		var s: float = g[2]
		var fx: float = (x - g[0]) / s
		var fz: float = (z - g[1]) / s
		if fx < 0.0 or fz < 0.0 or fx >= g[3] - 1 or fz >= g[4] - 1:
			continue
		var ix: int = int(fx)
		var iz: int = int(fz)
		var u: float = fx - ix
		var v: float = fz - iz
		var d: PackedFloat32Array = g[5]
		var i: int = iz * g[3] + ix
		var h10: float = d[i + 1] * s
		var h01: float = d[i + g[3]] * s
		if u + v <= 1.0:
			var h00: float = d[i] * s
			return h00 + (h10 - h00) * u + (h01 - h00) * v
		var h11: float = d[i + g[3] + 1] * s
		return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)
	return NAN
