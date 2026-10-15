class_name CampusKit
extends RefCounted

## Shared pieces for the Construction Site campus (construction_site.gd,
## campus_towers.gd, campus_offices.gd, campus_big.gd): materials, site
## roads that record their lanes, scaffolds, pallets, racks, portaloos,
## containers, tower cranes with their hanging loads, hoists, stair
## flights. Everything is drawn through Geo; one kit per map build.

const PIT := Rect2(-150, 68, 68, 36) ## the foundation pit (terrain lowered)
const PIT_DEPTH: float = 8.0

var geo: Geo
var rng: RandomNumberGenerator
var map: BuiltMap
var fleet: Fleet

func _init(m: BuiltMap, r: RandomNumberGenerator, f: Fleet) -> void:
	map = m
	geo = m.geo
	rng = r
	fleet = f

# --- materials -------------------------------------------------------------------------

static func add_materials(geo: Geo) -> void:
	geo.add_material("ground", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 8.0, 0, 0.45))
	geo.add_material("site", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(1.62, 1.57, 1.48), 4.0, 1, 0.5))
	geo.add_material("bank", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(0.82, 0.7, 0.55), 4.0, 1, 0.5))
	geo.add_material("weeds", Geo.ground_mat(MapTextures.get_tex("meadow"), Color(1.0, 1.02, 0.85), 6.0, 3, 0.45))
	geo.add_material("stone", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(2.3, 2.27, 2.2), 2.5, 3, 0.3))
	geo.add_material("haul", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(2.1, 1.98, 1.75), 3.0, 2, 0.4))
	geo.add_material("ruts", Geo.ground_flat(Color(0.5, 0.43, 0.35), 3))
	geo.add_material("mudpatch", Geo.ground_mat(MapTextures.get_tex("gravel_verge"), Color(0.62, 0.5, 0.38), 2.0, 3, 0.2))
	geo.add_material("puddle", Geo.ground_flat(Color(0.3, 0.36, 0.42), 4))
	geo.add_material("pad", Geo.ground_mat(MapTextures.get_tex("concrete_slab"), Color(1.0, 1.0, 0.97), 8.0, 2, 0.2))
	geo.add_material("mud", Geo.tex_mat(MapTextures.get_tex("gravel_verge"), Color(0.75, 0.65, 0.52), 4.0))
	geo.add_material("concrete", Geo.tex_mat(MapTextures.get_tex("formwork"), Color.WHITE, 2.5))
	geo.add_material("concrete_old", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.1, 1.1, 1.08), 4.0))
	geo.add_material("crane", Geo.flat_mat(Color(0.95, 0.72, 0.08)))
	geo.add_material("crane_red", Geo.flat_mat(Color(0.78, 0.16, 0.12)))
	geo.add_material("steel", Geo.flat_mat(Color(0.38, 0.4, 0.43), 0.5, 0.5))
	geo.add_material("steel_red", Geo.flat_mat(Color(0.55, 0.22, 0.16), 0.6, 0.3))
	geo.add_material("steel_primer", Geo.flat_mat(Color(0.47, 0.49, 0.5), 0.6, 0.3))
	geo.add_material("steel_blue", Geo.flat_mat(Color(0.2, 0.32, 0.5), 0.6, 0.3))
	geo.add_material("rebar", Geo.tex_mat(MapTextures.get_tex("rust"), Color(0.9, 0.8, 0.75), 2.0))
	geo.add_material("sheet_pile", Geo.tex_mat(MapTextures.get_tex("corrugated_rust"), Color(0.8, 0.8, 0.8), 1.5))
	geo.add_material("screen", Geo.flat_mat(Color(0.74, 0.2, 0.15)))
	geo.add_material("screen_rib", Geo.flat_mat(Color(0.3, 0.31, 0.33), 0.5, 0.4))
	geo.add_material("glass_panel", Geo.tex_mat(MapTextures.get_tex("curtain_wall"), Color(1.05, 1.08, 1.12), 3.0))
	geo.add_material("net", Geo.flat_mat(Color(0.95, 0.8, 0.1)))
	geo.add_material("sheeting", Geo.flat_mat(Color(0.62, 0.7, 0.76), 0.9))
	geo.add_material("sheeting_dark", Geo.flat_mat(Color(0.5, 0.57, 0.63), 0.9))
	geo.add_material("tape", Geo.flat_mat(Color(0.9, 0.22, 0.14)))
	geo.add_material("tape_w", Geo.flat_mat(Color(0.94, 0.94, 0.92)))
	geo.add_material("hoarding", Geo.flat_mat(Color(0.2, 0.36, 0.55)))
	geo.add_material("hoarding_w", Geo.flat_mat(Color(0.9, 0.9, 0.88)))
	geo.add_material("banner_a", Geo.flat_mat(Color(0.95, 0.72, 0.08)))
	geo.add_material("banner_b", Geo.flat_mat(Color(0.12, 0.2, 0.3)))
	geo.add_material("banner_c", Geo.flat_mat(Color(0.82, 0.2, 0.14)))
	geo.add_material("cabin", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.92, 0.92, 0.9), 2.4))
	geo.add_material("cabin_blue", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.3, 0.45, 0.7), 2.4))
	geo.add_material("loo_blue", Geo.flat_mat(Color(0.18, 0.4, 0.78), 0.5))
	geo.add_material("loo_white", Geo.flat_mat(Color(0.93, 0.93, 0.9), 0.5))
	geo.add_material("wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color.WHITE, 1.0))
	geo.add_material("sand", Geo.tex_mat(MapTextures.get_tex("sand"), Color.WHITE, 3.0))
	geo.add_material("gravel_pile", Geo.tex_mat(MapTextures.get_tex("ballast"), Color.WHITE, 2.0))
	geo.add_material("dark", Geo.flat_mat(Color(0.12, 0.12, 0.13)))
	geo.add_material("brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.15, 1.0, 0.95), 3.0))
	geo.add_material("water_wash", Geo.flat_mat(Color(0.28, 0.4, 0.46), 0.2))
	geo.add_material("lamp", Geo.glow_mat(Color(1.0, 0.95, 0.8), 1.2))
	geo.add_material("lamp_amber", Geo.glow_mat(Color(1.0, 0.6, 0.1), 1.6))
	geo.add_material("sign_green", Geo.flat_mat(Color(0.1, 0.45, 0.25)))
	geo.add_material("wreath", Geo.flat_mat(Color(0.2, 0.5, 0.22)))
	# Inside the buildings (flat colours, tinted per room; the light is baked).
	geo.add_material("off_wall", Geo.flat_mat(Color(0.93, 0.92, 0.88), 0.9))
	geo.add_material("off_floor", Geo.flat_mat(Color(0.58, 0.6, 0.64), 0.9))
	geo.add_material("off_slab", Geo.tex_mat(MapTextures.get_tex("concrete_slab"), Color(1.0, 1.0, 0.98), 5.0))
	geo.add_material("off_ceil", Geo.flat_mat(Color(0.95, 0.95, 0.93), 0.9))
	geo.add_material("stud", Geo.flat_mat(Color(0.74, 0.76, 0.78), 0.5, 0.5))
	geo.add_material("board", Geo.flat_mat(Color(0.82, 0.82, 0.78), 0.9))
	geo.add_material("desk", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.15, 1.05, 0.95), 1.2))
	geo.add_material("chair", Geo.flat_mat(Color(0.18, 0.2, 0.26), 0.8))
	geo.add_material("screen_on", Geo.glow_mat(Color(0.5, 0.75, 0.95), 0.9))
	geo.add_material("white_goods", Geo.flat_mat(Color(0.88, 0.89, 0.9), 0.4, 0.3))
	geo.add_material("tile", Geo.flat_mat(Color(0.78, 0.84, 0.86), 0.5))
	geo.add_material("tunnel", Geo.flat_mat(Color(0.09, 0.09, 0.1), 0.9))
	geo.add_material("rack_blue", Geo.flat_mat(Color(0.12, 0.28, 0.6), 0.6, 0.2))
	geo.add_material("rack_orange", Geo.flat_mat(Color(0.9, 0.4, 0.08), 0.6, 0.2))
	geo.add_material("carton", Geo.flat_mat(Color(0.66, 0.5, 0.33), 0.9))
	geo.add_material("wrap", Geo.flat_mat(Color(0.8, 0.84, 0.86), 0.3))
	geo.add_material("marking_y", Geo.ground_flat(Color(0.95, 0.8, 0.15), 4))
	geo.add_material("marking_w", Geo.ground_flat(Color(0.92, 0.92, 0.9), 4))
	geo.add_material("gar_slab", Geo.tex_mat(MapTextures.get_tex("concrete_slab"), Color(0.98, 0.98, 0.95), 4.0))
	geo.add_material("off_ext", Geo.tex_mat(MapTextures.get_tex("concrete_slab"), Color(1.0, 0.99, 0.95), 4.0))
	geo.add_material("off_clad", Geo.flat_mat(Color(0.86, 0.87, 0.9), 0.7))
	geo.add_material("off_trim", Geo.flat_mat(Color(0.25, 0.3, 0.36), 0.6))
	for m in ["off_wall", "off_floor", "off_slab", "off_ceil", "stud", "board", "desk", "chair", "screen_on", "white_goods", "tile", "gar_slab"]:
		geo.material(m).set_meta("no_shadow", true)
	Vehicles.ensure_materials(geo)
	YardProps._materials(geo)
	SignCreator.ensure_materials(geo)
	StreetKit.ensure_materials(geo)
	IndustryCreator.ensure_materials(geo)

# --- frames and small helpers ----------------------------------------------------------------

## A box in a frame's local coordinates (x along, y up, z out).
func bf(f: Transform3D, c: Vector3, size: Vector3, mat: String, collide: bool = true, shadow: bool = true) -> void:
	geo.box_xf(f * Transform3D(Basis(), c), size, mat, collide, shadow)

## A frame whose local +z points `out` (from the point c on the ground).
static func out_frame(c: Vector3, out: Vector3) -> Transform3D:
	return Transform3D(Basis.looking_at(-out, Vector3.UP), c)

## Rect minus rects (grid split on the holes' edges).
static func rect_minus(r: Rect2, holes: Array) -> Array[Rect2]:
	var xs: Array[float] = [r.position.x, r.end.x]
	var zs: Array[float] = [r.position.y, r.end.y]
	for h: Rect2 in holes:
		xs.append_array([clampf(h.position.x, r.position.x, r.end.x), clampf(h.end.x, r.position.x, r.end.x)])
		zs.append_array([clampf(h.position.y, r.position.y, r.end.y), clampf(h.end.y, r.position.y, r.end.y)])
	xs.sort()
	zs.sort()
	var out: Array[Rect2] = []
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var c := Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			if c.size.x < 0.01 or c.size.y < 0.01:
				continue
			var inside: bool = false
			for h: Rect2 in holes:
				if h.has_point(c.get_center()):
					inside = true
			if not inside:
				out.append(c)
	return out

## Merges the cells of rect_minus into fewer boxes (strips along x).
static func rect_minus_merged(r: Rect2, holes: Array) -> Array[Rect2]:
	var cells: Array[Rect2] = rect_minus(r, holes)
	var out: Array[Rect2] = []
	for c in cells:
		var merged: bool = false
		for k in range(out.size()):
			var o: Rect2 = out[k]
			if absf(o.position.y - c.position.y) < 0.001 and absf(o.size.y - c.size.y) < 0.001 and absf(o.end.x - c.position.x) < 0.001:
				out[k] = Rect2(o.position, Vector2(o.size.x + c.size.x, o.size.y))
				merged = true
				break
		if not merged:
			out.append(c)
	return out

## A floor slab (top at y, thickness th) with rectangular holes, as boxes.
## Local to the world position `o` (x, z added), rects in (x, z) metres.
func slab_holes(rect: Rect2, y_top: float, th: float, holes: Array, mat: String, collide: bool = true) -> void:
	for pr in rect_minus_merged(rect, holes):
		geo.box(Vector3(pr.get_center().x, y_top - th * 0.5, pr.get_center().y), Vector3(pr.size.x, th, pr.size.y), mat, 0.0, collide)

## A rectangle of gravel/paved road (never overlapping another of the same
## layer) that also records its lane. mat "haul" (layer 2) or "pad".
func haul(r: Rect2, mat: String = "haul") -> void:
	geo.slab(r, 0.0, 1.0, mat, false)
	var half: float = minf(r.size.x, r.size.y) * 0.5
	if r.size.x >= r.size.y:
		geo._lane(Vector2(r.position.x + half, r.get_center().y), Vector2(r.end.x - half, r.get_center().y), half)
		geo._lane(Vector2(r.position.x, r.get_center().y), Vector2(r.end.x, r.get_center().y), half * 0.98)
	else:
		geo._lane(Vector2(r.get_center().x, r.position.y + half), Vector2(r.get_center().x, r.end.y - half), half)
		geo._lane(Vector2(r.get_center().x, r.position.y), Vector2(r.get_center().x, r.end.y), half * 0.98)

## A wall with openings in world coordinates: axis "x" runs along world x at
## z = c (from a0 to a1), axis "z" along world z at x = c. Holes are
## Rect2(along, y, width, height) with `along` the world x (or z).
func wall(axis: String, c: float, a0: float, a1: float, y0: float, y1: float, th: float, holes: Array, mat: String, collide: bool = true) -> void:
	var xf := Transform3D(Basis(), Vector3(0, 0, c)) if axis == "x" else Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(c, 0, 0))
	BuildKit.wall(geo, xf, a0, a1, y0, y1, th, holes, mat, NAN, collide)

# --- scaffold, tape, sheeting -----------------------------------------------------------------

func tape(a: Vector3, b: Vector3) -> void:
	var L: float = a.distance_to(b)
	var n: int = maxi(1, int(L / 4.0))
	for k in range(n + 1):
		var p: Vector3 = a.lerp(b, float(k) / n)
		geo.cylinder(p, p + Vector3(0, 1.15, 0), 0.03, "steel", 5, true, false, false)
	for h in [1.05, 0.8]:
		geo.beam(a + Vector3(0, h, 0), b + Vector3(0, h, 0), Vector2(0.07, 0.012), "tape" if h > 0.9 else "tape_w", false, false)

## Façade scaffold along a wall: standards every 2.5 m, ledgers and boards
## on each 2 m lift, diagonal braces; open to fly along. o is the middle of
## the inner line at the ground.
func scaffold(o: Vector3, length: float, lifts: int, along_z: bool, out_sign: float = 1.0) -> void:
	var n: int = int(length / 2.5)
	var ax: Vector3 = Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var out: Vector3 = (Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)) * out_sign
	var a: Vector3 = o - ax * length * 0.5
	for i in range(n + 1):
		for k in [0.0, 1.0]:
			var b: Vector3 = a + ax * i * 2.5 + out * k * 1.1
			geo.cylinder(b, b + Vector3(0, lifts * 2.0 + 1.0, 0), 0.03, "steel", 4, true, false, false)
	for l in range(1, lifts + 1):
		var y: float = l * 2.0
		for k in [0.0, 1.0]:
			geo.beam(a + out * k * 1.1 + Vector3(0, y, 0), a + ax * n * 2.5 + out * k * 1.1 + Vector3(0, y, 0), Vector2(0.05, 0.05), "steel", false, false)
		geo.box(a + ax * n * 1.25 + out * 0.55 + Vector3(0, y - 0.03, 0), (Vector3(1.0, 0.05, n * 2.5) if along_z else Vector3(n * 2.5, 0.05, 1.0)), "wood", 0.0, true, false)
	for i in range(0, n, 2):
		geo.beam(a + ax * i * 2.5 + out * 1.1, a + ax * (i + 2) * 2.5 + out * 1.1 + Vector3(0, lifts * 2.0, 0), Vector2(0.05, 0.05), "steel", false, false)

## Façade sheeting outside a scaffold's outer standards.
func sheeting(o: Vector3, length: float, lifts: int, along_z: bool, out_sign: float, skip: float) -> void:
	var n: int = int(length / 2.5)
	var ax: Vector3 = Vector3(0, 0, 1) if along_z else Vector3(1, 0, 0)
	var out: Vector3 = (Vector3(1, 0, 0) if along_z else Vector3(0, 0, 1)) * out_sign
	var a: Vector3 = o - ax * length * 0.5
	var cols: int = int(n * 2.5 / 5.0)
	for c in range(cols):
		for r in range(lifts / 2):
			if rng.randf() < skip:
				continue
			var cen: Vector3 = a + ax * (c * 5.0 + 2.5) + out * 1.15 + Vector3(0, r * 4.0 + 2.2, 0)
			geo.box(cen, Vector3(0.04, 3.9, 4.9) if along_z else Vector3(4.9, 3.9, 0.04), "sheeting" if rng.randf() < 0.75 else "sheeting_dark")

## A free-standing scaffold passage: two rows of frames, boards on top at
## `h`, braced; you can fly along it. Along x from p, length L, width 2.4.
func scaffold_passage(p: Vector3, L: float, h: float, yaw: float) -> void:
	var f := Transform3D(Basis(Vector3.UP, yaw), p)
	var n: int = int(L / 2.5)
	for i in range(n + 1):
		for s in [-1.2, 1.2]:
			bf(f, Vector3(i * 2.5, h * 0.5, s), Vector3(0.08, h, 0.08), "steel")
		bf(f, Vector3(i * 2.5, h, 0.0), Vector3(0.07, 0.07, 2.4), "steel")
	for s in [-1.2, 1.2]:
		bf(f, Vector3(n * 1.25, h - 0.03, s), Vector3(n * 2.5, 0.07, 0.07), "steel")
		bf(f, Vector3(n * 1.25, 1.0, s), Vector3(n * 2.5, 0.05, 0.05), "steel")
		for i in range(0, n, 2):
			geo.beam(f * Vector3(i * 2.5, 0.0, s), f * Vector3((i + 2) * 2.5, h, s), Vector2(0.05, 0.05), "steel", false, false)
	bf(f, Vector3(n * 1.25, h + 0.03, 0.0), Vector3(n * 2.5, 0.05, 2.4), "wood")

# --- yard goods -------------------------------------------------------------------------------

func pallet(p: Vector3, yaw: float, h: float, mat: String) -> void:
	geo.box(p + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), "wood", yaw)
	if h > 0.01:
		geo.box(p + Vector3(0, 0.14 + h * 0.5, 0), Vector3(1.15, h, 0.9), mat, yaw)

## Plasterboard / brick pallets standing in the bays of a floor at height y.
func floor_pallets(o: Vector3, w: float, d: float, y: float, avoid: Rect2, count: int) -> void:
	for i in range(count):
		var c := Vector2(rng.randf_range(-w * 0.5 + 3.0, w * 0.5 - 3.0), rng.randf_range(-d * 0.5 + 3.0, d * 0.5 - 3.0))
		if avoid.grow(2.0).has_point(c):
			continue
		var yaw: float = rng.randf_range(-0.4, 0.4)
		pallet(o + Vector3(c.x, y, c.y), yaw, rng.randf_range(0.5, 1.1), "hoarding_w" if rng.randf() < 0.6 else "concrete_old")

## Steel props (Baustützen) in a row under/over a floor.
func props(p: Vector3, along: Vector3, n: int, spacing: float, h: float) -> void:
	for k in range(n):
		var q: Vector3 = p + along * spacing * k
		geo.cylinder(q, q + Vector3(0, h, 0), 0.05, "crane", 6, true, false, false)

func rebar_rack(p: Vector3, yaw: float, layers: int) -> void:
	var f := Transform3D(Basis(Vector3.UP, yaw), p)
	for s in [-2.2, 0.0, 2.2]:
		bf(f, Vector3(0, 0.075, s), Vector3(1.8, 0.15, 0.2), "wood")
	for l in range(layers):
		var cnt: int = 4 - l
		for k in range(cnt):
			bf(f, Vector3((k - (cnt - 1) * 0.5) * 0.46, 0.15 + 0.12 + l * 0.24, 0), Vector3(0.44, 0.24, 6.0), "rebar")

func panel_rack(p: Vector3, yaw: float, n: int, mat: String) -> void:
	var f := Transform3D(Basis(Vector3.UP, yaw), p)
	bf(f, Vector3(0, 0.075, 0), Vector3(2.4, 0.15, 1.4), "steel")
	for sx in [-1.15, 1.15]:
		for sz in [-0.65, 0.65]:
			bf(f, Vector3(sx, 1.05, sz), Vector3(0.1, 1.9, 0.1), "steel")
	for k in range(n):
		bf(f, Vector3((k - (n - 1) * 0.5) * 0.17, 1.4, 0), Vector3(0.12, 2.5, 1.2), mat)
	bf(f, Vector3(-1.15, 1.95, 0), Vector3(0.1, 0.1, 1.4), "steel")
	bf(f, Vector3(1.15, 1.95, 0), Vector3(0.1, 0.1, 1.4), "steel")

func shed(p: Vector3, yaw: float, w: float, d: float, h: float, mat: String) -> void:
	var f := Transform3D(Basis(Vector3.UP, yaw), p)
	for ix in range(int(w / 6.0) + 1):
		for sz in [-1.0, 1.0]:
			var x: float = -w * 0.5 + ix * w / int(w / 6.0)
			bf(f, Vector3(x, h * 0.5, sz * (d * 0.5 - 0.15)), Vector3(0.25, h, 0.25), "steel")
	bf(f, Vector3(0, h + 0.1, 0), Vector3(w + 1.0, 0.2, d + 1.0), mat)
	bf(f, Vector3(0, h - 0.1, 0), Vector3(w, 0.2, 0.3), "steel")

## A skip (Mulde) of rubble.
func skip(p: Vector3, yaw: float) -> void:
	geo.frustum(Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.75, 0)), Vector3(1.8, 1.5, 2.6), 2.0, 3.8, 0.0, "crane_red")

## A container (20 ft), floor at p.y.
func container(p: Vector3, yaw: float, mat: String) -> void:
	geo.box(p + Vector3(0, 1.3, 0), Vector3(6.06, 2.59, 2.44), mat, yaw)

## Stacked pipes (concrete) on end blocks, along local z.
func pipe_stack(p: Vector3, yaw: float, rows: int, length: float, r: float) -> void:
	var f := Transform3D(Basis(Vector3.UP, yaw), p)
	for s in [-length * 0.35, length * 0.35]:
		bf(f, Vector3(0, 0.1, s), Vector3((rows + 1) * r * 2.0, 0.2, 0.3), "wood")
	for row in range(rows):
		for j in range(rows - row):
			var x: float = (j - (rows - row - 1) * 0.5) * (r * 2.0 + 0.04)
			var a: Vector3 = f * Vector3(x, 0.2 + r + row * r * 1.75, -length * 0.5)
			var b: Vector3 = f * Vector3(x, 0.2 + r + row * r * 1.75, length * 0.5)
			geo.pipe(a, b, r, 0.08, "concrete_old", 12)

## A portaloo: blue box, white roof, 1.25 m square; the door open.
func portaloo(p: Vector3, yaw: float, toilet: bool) -> void:
	var f := Transform3D(Basis(Vector3.UP, yaw), p)
	bf(f, Vector3(0, 0.06, 0), Vector3(1.2, 0.12, 1.2), "loo_white")
	bf(f, Vector3(0, 1.2, -0.625), Vector3(1.3, 2.2, 0.05), "loo_blue")
	for s in [-1.0, 1.0]:
		bf(f, Vector3(s * 0.625, 1.2, 0), Vector3(0.05, 2.2, 1.3), "loo_blue")
		bf(f, Vector3(s * 0.51, 1.2, 0.625), Vector3(0.23, 2.2, 0.05), "loo_blue")
	bf(f, Vector3(0, 2.35, 0), Vector3(1.4, 0.1, 1.4), "loo_white")
	bf(f, Vector3(0, 2.15, 0.625), Vector3(0.8, 0.2, 0.05), "loo_blue")
	var hinge := Vector3(0.4, 1.2, 0.65)
	bf(f * Transform3D(Basis(Vector3.UP, deg_to_rad(105.0)), hinge), Vector3(-0.4, 0.0, 0.0), Vector3(0.8, 2.1, 0.05), "loo_blue")
	if toilet:
		ToiletCreator.build(geo, f * Transform3D(Basis(), Vector3(0, 0.12, -0.6)), rng, {"paper": true})

## The wheel-wash: a raised steel trough with water, two ramps, spray bars.
func wheel_wash(p: Vector3) -> void:
	for s in [-1.0, 1.0]:
		geo.box(p + Vector3(s * 2.45, 0.15, 0), Vector3(0.7, 0.3, 12.0), "concrete_old")
		geo.box(p + Vector3(0, 0.15, s * 5.8), Vector3(4.2, 0.3, 0.4), "concrete_old")
	geo.box(p + Vector3(0, 0.12, 0), Vector3(4.2, 0.24, 11.2), "water_wash")
	for x in [-1.4, 0.0, 1.4]:
		geo.box(p + Vector3(x, 0.27, 0), Vector3(0.3, 0.06, 11.0), "dark", 0.0, false, false)
	for s in [-1.0, 1.0]:
		geo.box(p + Vector3(s * 2.65, 0.5, 0), Vector3(0.3, 0.4, 11.6), "steel")
		for z in [-3.0, 0.0, 3.0]:
			geo.cylinder(p + Vector3(s * 2.65, 0.7, z), p + Vector3(s * 2.65, 1.5, z), 0.05, "steel", 6)
			geo.beam(p + Vector3(s * 2.65, 1.45, z), p + Vector3(s * 1.5, 0.9, z), Vector2(0.05, 0.05), "steel", false, false)
	for s in [-1.0, 1.0]:
		var ang: float = atan2(0.3, 2.4) * s
		geo.box_xf(Transform3D(Basis(Vector3.RIGHT, ang), p + Vector3(0, 0.15, s * 7.2)), Vector3(5.6, 0.12, 2.43), "concrete_old")
	geo.box(p + Vector3(4.3, 0.55, 4.0), Vector3(1.2, 1.1, 0.9), "steel_red")

# --- stairs -------------------------------------------------------------------------------------

## A dog-leg stair in a well: o = the well's north-west corner (inner
## faces) at the ground storey's floor, w x d inside, entered at the
## SOUTH end (or the north end with `north`). Per storey: a flight up to a
## half landing at the far end, a flight back to the entry end, where the
## arrival landing carries the next floor's level. Landings span the full
## width (they touch the walls). The slab above must leave the flights'
## footprint open (see stair_hole).
func _stair_dims(d: float, fh: float) -> Array:
	var land: float = 1.3 if d >= 6.0 else 1.0
	var run: float = minf(d - land - 1.0, fh * 0.5 / 0.18 * 0.28)
	return [land, run]

func stair_well(o: Vector3, w: float, d: float, fh: float, storeys: int, mat: String = "concrete", north: bool = false) -> void:
	var fw: float = (w - 0.7) * 0.5
	var x1: float = o.x + 0.2 + fw * 0.5
	var x2: float = o.x + w - 0.2 - fw * 0.5
	var dims: Array = _stair_dims(d, fh)
	var land: float = dims[0]
	var run: float = dims[1]
	# v = distance from the far end; z of a point v from the far end:
	var far_z: float = (o.z + d) if north else o.z
	var sg: float = -1.0 if north else 1.0
	var z_hi: float = far_z + sg * land
	var z_lo: float = z_hi + sg * run
	var z_wall: float = (o.z) if north else (o.z + d)
	for s in range(storeys):
		var y0: float = o.y + s * fh
		var yh: float = y0 + fh * 0.5
		geo.beam(Vector3(x1, y0 + 0.02, z_lo), Vector3(x1, yh - 0.1, z_hi), Vector2(fw, 0.28), mat)
		geo.box(Vector3(o.x + w * 0.5, yh - 0.1, far_z + sg * land * 0.5), Vector3(w, 0.2, land), mat)
		geo.beam(Vector3(x2, yh - 0.1, z_hi), Vector3(x2, y0 + fh - 0.1, z_lo), Vector2(fw, 0.28), mat)
		# The arrival landing at the next floor's level, up to the entry wall.
		geo.box(Vector3(o.x + w * 0.5, y0 + fh - 0.1, (z_lo + z_wall) * 0.5), Vector3(w, 0.2, absf(z_wall - z_lo)), mat)

## The part of a slab over a stair_well that stays open: the far end to
## the flights' entry end (x, z rect).
func stair_hole(o: Vector3, w: float, d: float, fh: float, north: bool = false) -> Rect2:
	var dims: Array = _stair_dims(d, fh)
	var depth: float = dims[0] + dims[1]
	if north:
		return Rect2(o.x, o.z + d - depth, w, depth)
	return Rect2(o.x, o.z, w, depth)

# --- cranes ----------------------------------------------------------------------------------------

## The lattice mast of a tower crane: four chords, ring frames and zigzag
## bracing (the bracing without collision, like a real lattice's gaps).
func crane_mast(base: Vector3, height: float, step: float = 4.5) -> void:
	var s: float = 1.0
	geo.box(base + Vector3(0, 0.7, 0), Vector3(7, 1.4, 7), "concrete_old")
	var corners: Array[Vector3] = [Vector3(-s, 0, -s), Vector3(s, 0, -s), Vector3(s, 0, s), Vector3(-s, 0, s)]
	for c in corners:
		geo.beam(base + c + Vector3(0, 1.4, 0), base + c + Vector3(0, height, 0), Vector2(0.2, 0.2), "crane")
	var y: float = 1.4
	var flip: bool = false
	while y + step <= height:
		for k in range(4):
			var c0: Vector3 = corners[k]
			var c1: Vector3 = corners[(k + 1) % 4]
			var y0: float = y if not flip else y + step
			var y1: float = y + step if not flip else y
			geo.beam(base + c0 + Vector3(0, y0, 0), base + c1 + Vector3(0, y1, 0), Vector2(0.09, 0.09), "crane", false, false)
			geo.beam(base + c0 + Vector3(0, y, 0), base + c1 + Vector3(0, y, 0), Vector2(0.09, 0.09), "crane", false, false)
		flip = not flip
		y += step

## A flat-top tower crane with tie struts and a hanging load.
##   ties: [[y, target point Vector3, spread]] - two struts from the mast to the target (±spread along the line)
##   load: "gnome" | "rebar" | "beam" | "bucket" | "panel"; tx: trolley position (0..1 of the jib);
##   drop: hook depth under the jib (m).
func crane(base: Vector3, height: float, jib: float, yaw_deg: float, load: String, tx_frac: float, drop: float, ties: Array = []) -> void:
	crane_mast(base, height)
	var top: Vector3 = base + Vector3(0, height, 0)
	var b := Basis(Vector3.UP, deg_to_rad(-yaw_deg))
	for t: Array in ties:
		var y: float = t[0]
		var target: Vector3 = t[1]
		var along: Vector3 = Vector3((target - base).z, 0, -(target - base).x).normalized() * float(t[2])
		for sgn in [-1.0, 1.0]:
			var mast_pt: Vector3 = base + Vector3(0, y, 0) + Vector3((target - base).x, 0, (target - base).z).normalized() * 1.0 + along.normalized() * sgn * 1.0
			geo.beam(mast_pt, target + along * sgn + Vector3(0, y - target.y, 0), Vector2(0.28, 0.28), "steel")
	geo.box_xf(Transform3D(b, top + Vector3(0, 1.0, 0)), Vector3(3.0, 2.0, 3.0), "crane")
	geo.box_xf(Transform3D(b, top + b * Vector3(1.8, 1.8, 1.0)), Vector3(1.6, 2.2, 2.0), "cabin")
	geo.box_xf(Transform3D(b, top + b * Vector3(2.62, 1.9, 1.0)), Vector3(0.05, 1.3, 1.6), "dark", false, false)
	# Tower head (apex) with the pendant ropes to the jib and counter-jib.
	var apex: Vector3 = top + Vector3(0, 11.0, 0)
	for sx in [-1.0, 1.0]:
		geo.beam(top + b * Vector3(sx * 0.0, 2.0, sx * 1.2), apex, Vector2(0.22, 0.22), "crane", false, false)
	geo.box_xf(Transform3D(b, apex + Vector3(0, 0.3, 0)), Vector3(0.9, 0.6, 0.9), "crane_red")
	# Jib: triangular lattice, 1.6 m wide, 1.8 m deep, along local +x.
	var jy: float = 2.2
	for side in [-0.8, 0.8]:
		geo.beam(top + b * Vector3(0, jy, side), top + b * Vector3(jib, jy, side), Vector2(0.14, 0.14), "crane")
	geo.beam(top + b * Vector3(0, jy + 1.8, 0), top + b * Vector3(jib - 1.0, jy + 1.8, 0), Vector2(0.14, 0.14), "crane")
	var x: float = 0.0
	while x < jib - 2.0:
		for side in [-0.8, 0.8]:
			geo.beam(top + b * Vector3(x, jy, side), top + b * Vector3(x + 2.0, jy + 1.8, 0), Vector2(0.07, 0.07), "crane", false, false)
			geo.beam(top + b * Vector3(x + 2.0, jy + 1.8, 0), top + b * Vector3(x + 4.0, jy, side), Vector2(0.07, 0.07), "crane", false, false)
		x += 4.0
	var cj: float = jib * 0.33
	for side in [-1.0, 1.0]:
		geo.beam(top + b * Vector3(0, jy, side), top + b * Vector3(-cj, jy, side), Vector2(0.2, 0.3), "crane")
	geo.box_xf(Transform3D(b, top + b * Vector3(-cj * 0.5, jy + 0.1, 0)), Vector3(cj, 0.1, 1.8), "steel", false, false)
	for k in range(4):
		geo.box_xf(Transform3D(b, top + b * Vector3(-cj + 1.2 + k * 0.9, jy - 1.0, 0)), Vector3(0.8, 2.4, 2.4), "concrete_old")
	geo.box_xf(Transform3D(b, top + b * Vector3(-cj * 0.4, jy + 0.7, 0)), Vector3(2.5, 1.2, 1.6), "steel")
	# Pendant ropes (apex to the jib at 0.35 L and the counter-jib's end).
	geo.beam(apex, top + b * Vector3(jib * 0.35, jy + 1.8, 0), Vector2(0.04, 0.04), "dark", false, false)
	geo.beam(apex, top + b * Vector3(jib * 0.75, jy + 1.8, 0), Vector2(0.04, 0.04), "dark", false, false)
	geo.beam(apex, top + b * Vector3(-cj, jy + 0.3, 0), Vector2(0.04, 0.04), "dark", false, false)
	# Trolley, hoist rope, hook and the load.
	var trolley: Vector3 = top + b * Vector3(jib * tx_frac, jy - 0.3, 0)
	geo.box(trolley, Vector3(1.2, 0.5, 1.4), "crane_red")
	var hook_y: float = maxf(base.y + 8.0, trolley.y - drop)
	var hook := Vector3(trolley.x, hook_y, trolley.z)
	geo.beam(trolley, hook, Vector2(0.04, 0.04), "dark", false, false)
	geo.box(hook + Vector3(0, -0.3, 0), Vector3(0.5, 0.6, 0.3), "crane_red", 0.0, false, false)
	var hk: Vector3 = hook + Vector3(0, -0.6, 0)
	match load:
		"gnome":
			# A pallet (1.2 x 0.8 m) on four slings, a gnome standing on it.
			var py: float = hook_y - 2.15
			geo.tint = Color(0.8, 0.68, 0.5)
			geo.box(Vector3(hook.x, py - 0.075, hook.z), Vector3(1.2, 0.15, 0.8), "rebar", 0.0, true, false)
			geo.tint = Color.WHITE
			for cx in [-1.0, 1.0]:
				for cz in [-0.7, 0.7]:
					geo.beam(hk, Vector3(hook.x + cx * 0.58, py, hook.z + cz * 0.38), Vector2(0.03, 0.03), "dark", false, false)
			EggProps.gnome(geo, Vector3(hook.x, py, hook.z), -0.6, 1.0)
			if OS.has_environment("SH_EGG"):
				print("EGG gnome on the crane hook at ", Vector3(hook.x, py, hook.z))
		"beam":
			# A 12 m steel I-beam on two slings (a V from the hook).
			var by: float = hook_y - 4.6
			var ax: Vector3 = b * Vector3(1, 0, 0) # hangs along the jib
			var bm := Transform3D(Basis.looking_at(ax, Vector3.UP), Vector3(hook.x, by, hook.z))
			geo.box_xf(bm, Vector3(0.45, 0.5, 12.0), "steel_red")
			for e in [-4.5, 4.5]:
				geo.beam(hk, bm * Vector3(0, 0.25, e), Vector2(0.04, 0.04), "dark", false, false)
		"bucket":
			var cy: float = hook_y - 4.2
			geo.cone(Vector3(hook.x, cy, hook.z), Vector3(hook.x, cy + 2.6, hook.z), 0.5, 1.15, "crane_red", 12)
			for k in range(4):
				var a: float = TAU * k / 4.0 + 0.4
				geo.beam(hk, Vector3(hook.x + cos(a) * 1.1, cy + 2.6, hook.z + sin(a) * 1.1), Vector2(0.04, 0.04), "dark", false, false)
		"panel":
			var py: float = hook_y - 3.4
			geo.box_xf(Transform3D(b, Vector3(hook.x, py, hook.z)), Vector3(0.3, 2.4, 3.0), "glass_panel")
			for e in [-1.2, 1.2]:
				geo.beam(hk, b * Vector3(0, 0, e) + Vector3(hook.x, py + 1.2, hook.z), Vector2(0.04, 0.04), "dark", false, false)
		_:
			geo.box(Vector3(hook.x, hook_y - 2.8, hook.z), Vector3(2.2, 1.3, 1.6), "rebar")
			for cx in [-1.0, 1.0]:
				for cz in [-0.7, 0.7]:
					geo.beam(hk, Vector3(hook.x + cx, hook_y - 2.15, hook.z + cz), Vector2(0.03, 0.03), "dark", false, false)

# --- hoists -------------------------------------------------------------------------------------------

## A rack-and-pinion site hoist: lattice mast (1 x 1 m), ties back to the
## building face at `tie_to` (the face point at ground height, direction
## from the mast given by `tie_dir`), the cage part way up.
func hoist(base: Vector3, height: float, tie_dir: Vector3, tie_len: float, cage_y: float = 9.0) -> void:
	geo.box(base + Vector3(0, 0.15, 0), Vector3(2.4, 0.3, 2.4), "steel")
	var ch: Array[Vector3] = [Vector3(-0.5, 0, -0.5), Vector3(0.5, 0, -0.5), Vector3(0.5, 0, 0.5), Vector3(-0.5, 0, 0.5)]
	for c in ch:
		geo.beam(base + c + Vector3(0, 0.3, 0), base + c + Vector3(0, height, 0), Vector2(0.1, 0.1), "crane")
	var y: float = 0.3
	var flip: bool = false
	while y + 3.0 <= height:
		for k in range(4):
			var c0: Vector3 = ch[k]
			var c1: Vector3 = ch[(k + 1) % 4]
			geo.beam(base + c0 + Vector3(0, y if not flip else y + 3.0, 0), base + c1 + Vector3(0, y + 3.0 if not flip else y, 0), Vector2(0.06, 0.06), "crane", false, false)
		flip = not flip
		y += 3.0
	var t: float = 3.6
	while t < height - 1.0:
		geo.beam(base + Vector3(0, t, 0), base + tie_dir * tie_len + Vector3(0, t, 0), Vector2(0.12, 0.12), "steel", false, false)
		t += 7.2
	var side: Vector3 = Vector3(-tie_dir.z, 0, tie_dir.x)
	var yaw: float = atan2(tie_dir.x, tie_dir.z)
	var cage: Vector3 = base + Vector3(0, cage_y, 0) + tie_dir * -1.6
	geo.box(cage + Vector3(0, 1.4, 0), Vector3(1.5, 2.8, 2.4), "cabin_blue", yaw)
	geo.box(cage + Vector3(0, 2.85, 0), Vector3(1.6, 0.1, 2.5), "steel", yaw)
	geo.box(cage + side * 0.0 + tie_dir * 0.78 + Vector3(0, 1.0, 0), Vector3(1.6, 1.4, 0.04), "dark", yaw, false, false)
