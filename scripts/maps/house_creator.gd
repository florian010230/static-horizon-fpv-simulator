class_name HouseCreator
extends RefCounted

## Creator: a detached family house, a different one for every seed -
## the kind found on any German residential street. One or two storeys
## on a plinth, gable or hip roof (dormers, chimney, gutters,
## downpipes), plaster in a pastel tint or clinker brick, windows with
## frames, sills, surrounds, folding shutters or roller blinds, a front
## door with canopy and steps, a terrace with an open patio door, an
## optional garage or carport. Inside: hall (with stairs on two-storey
## houses), kitchen, living/dining, bath/WC, bedrooms - furnished, a
## wall colour per room, every inner door open, so a drone can fly in
## through the patio door or an open window and through the whole house.
##
##   var info: Dictionary = HouseCreator.build(geo, pos, yaw, seed, opts)
##   info.views   [[name, eye, target], ...] world-space camera spots
##                (outside, the way in, every room) for dev previews
##   info.size    Vector2(width, depth) of the main body
## opts: "mirror" (1.0 / -1.0), "brick" (true = clinker, not plaster),
##       "interior" (default true; false = closed house, far cheaper -
##       for houses nobody flies into: every window shows a painted room
##       niche, so from outside it looks as lived-in as the others), "storeys" (1/2),
##       "roof" ("gable"/"hip"), "garage" ("none"/"garage"/"carport"),
##       "path_to" (local z where the front path ends, default D/2 + 5).
##
## Local frame: origin on the ground in the middle of the house, the
## street front faces +z, the hall is on the +x side. Half the seeds
## are mirrored - the whole frame, so every detail mirrors with it (Geo
## orders each triangle from its face normal, so that is safe).

## Maps open 1 house in 5 (the rest are closed shells - the interior
## costs most of a house's load time): `HouseCreator.accessible(i)`.
const OPEN_EVERY: int = 5

static func accessible(index: int) -> bool:
	return index % OPEN_EVERY == 0

const T: float = 0.3 ## exterior wall
const P: float = 0.12 ## partition
const SK: float = 0.015 ## interior paint/tile skin on every wall
const FL: float = 0.45 ## ground floor level (top of the plinth)
const H: float = 2.8 ## storey height, floor to floor
const CH: float = 2.5 ## clear room height
const STEPS: int = 15
const TREAD: float = 0.235

const PLASTER := [Color(0.97, 0.96, 0.92), Color(0.96, 0.9, 0.76), Color(0.97, 0.88, 0.64), Color(0.84, 0.85, 0.84),
	Color(0.94, 0.8, 0.7), Color(0.84, 0.9, 0.8), Color(0.8, 0.85, 0.9), Color(0.93, 0.93, 0.88)]
const ROOFS := [Color(1.0, 0.92, 0.9), Color(0.72, 0.56, 0.46), Color(0.42, 0.44, 0.48), Color(0.8, 0.55, 0.48), Color(0.3, 0.3, 0.32)]
const TRIMS := [Color(0.97, 0.97, 0.96), Color(0.97, 0.97, 0.96), Color(0.26, 0.28, 0.3), Color(0.5, 0.36, 0.24)]
const SHUTTERS := [Color(0.25, 0.42, 0.3), Color(0.45, 0.3, 0.2), Color(0.55, 0.58, 0.6), Color(0.3, 0.42, 0.55), Color(0.92, 0.92, 0.9)]
const DOORS := [Color(0.25, 0.27, 0.3), Color(0.5, 0.14, 0.12), Color(0.18, 0.32, 0.25), Color(0.2, 0.3, 0.5), Color(0.55, 0.38, 0.22)]
const WALLS := [Color(0.97, 0.96, 0.93), Color(0.97, 0.96, 0.93), Color(0.88, 0.92, 0.96), Color(0.9, 0.95, 0.88),
	Color(0.98, 0.92, 0.84), Color(0.92, 0.92, 0.92), Color(0.98, 0.88, 0.88), Color(0.86, 0.9, 0.86)]
const FABRICS := [Color(0.35, 0.4, 0.5), Color(0.55, 0.55, 0.55), Color(0.62, 0.5, 0.38), Color(0.3, 0.45, 0.38),
	Color(0.7, 0.66, 0.6), Color(0.5, 0.25, 0.25), Color(0.25, 0.3, 0.42)]
const FRONTS := [Color(0.96, 0.96, 0.95), Color(0.3, 0.32, 0.34), Color(0.62, 0.7, 0.6), Color(0.85, 0.8, 0.7), Color(0.4, 0.5, 0.62)]

var geo: Geo
var rng := RandomNumberGenerator.new()
var toilets: Array = [] ## what swims in each toilet ("none" mostly)
var xf: Transform3D ## house-local -> world
var base: Vector3
var interior: bool = true
var W: float
var D: float
var storeys: int
var wall_top: float
var roof_kind: String
var pitch: float
var X0: float
var X1: float
var Z0: float
var Z1: float
var hx0: float ## hall, x range
var hx1: float
var zc: float ## cross wall (centre line)
var z_top: float ## where the stairs arrive (z)
var rooms: Array = [] ## Dictionary per room
var parts: Array = [] ## partitions: [storey, axis, c, a0, a1]
var ops: Array = [] ## openings (Dictionary each)
var views: Array = []
var facade_tint: Color
var plaster: bool
var brick_ground: bool
var trim: Color
var shutter_style: String
var shutter_tint: Color
var door_tint: Color
var roof_tint: Color
var garage: String
var gside: float
var hole := Rect2()

static func ensure_materials(g: Geo) -> void:
	if g.has_material("hc_plaster"):
		return
	g.add_material("hc_plaster", Geo.tex_mat(_tex(ProceduralTextures.plaster_image(64, 0.86, 1.0, 5)), Color.WHITE, 2.0))
	g.add_material("hc_brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.45, 1.02, 0.88), 2.4))
	g.add_material("hc_plinth", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.66, 0.66, 0.64), 3.0))
	g.add_material("hc_roof", Geo.tex_mat(MapTextures.get_tex("roof_tiles"), Color.WHITE, 2.0))
	g.add_material("hc_trim", Geo.flat_mat(Color.WHITE, 0.6))
	g.add_material("hc_glass_dark", Geo.flat_mat(Color(0.2, 0.25, 0.3), 0.2, 0.3))
	g.add_material("hc_terrace", Geo.tex_mat(MapTextures.get_tex("paving_slabs"), Color(0.86, 0.82, 0.76), 1.6))
	g.add_material("hc_paving", Geo.ground_mat(MapTextures.get_tex("paving_slabs"), Color(0.86, 0.84, 0.8), 1.6, 2, 0.2)) # (layer 2: over a farmyard's gravel)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.62, 0.74, 0.8, 0.28)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.vertex_color_use_as_albedo = true
	g.add_material("hc_glass", glass)
	# Interior and small things ("hcd_"): drawn only within Geo's detail range.
	g.add_material("hcd_paint", Geo.tex_mat(_tex(ProceduralTextures.plaster_image(64, 0.93, 1.0, 9)), Color.WHITE, 1.5))
	g.add_material("hcd_tiles", Geo.tex_mat(_tex(_tiles_image(4, 0.97)), Color.WHITE, 0.8))
	g.add_material("hcd_parquet", Geo.tex_mat(_tex(ProceduralTextures.planks_image(256)), Color(1.45, 1.38, 1.3), 2.4))
	g.add_material("hcd_floor_tiles", Geo.tex_mat(_tex(_tiles_image(2, 0.9)), Color.WHITE, 1.2))
	g.add_material("hcd_ceiling", Geo.flat_mat(Color(0.98, 0.98, 0.96)))
	g.add_material("hcd_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.3, 1.22, 1.1), 1.0))
	g.add_material("hcd_paint_furn", Geo.flat_mat(Color.WHITE, 0.5))
	g.add_material("hcd_fabric", Geo.tex_mat(MapTextures.get_tex("fabric"), Color.WHITE, 0.4))
	g.add_material("hcd_steel", Geo.flat_mat(Color(0.72, 0.74, 0.76), 0.3, 0.6))
	g.add_material("hcd_black", Geo.flat_mat(Color(0.07, 0.07, 0.08), 0.3))
	g.add_material("hcd_plant", Geo.flat_mat(Color(0.2, 0.42, 0.18)))
	g.add_material("hcd_concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(0.8, 0.8, 0.78), 3.0))
	for m in ["hcd_paint", "hcd_tiles", "hcd_parquet", "hcd_floor_tiles", "hcd_ceiling", "hcd_wood",
			"hcd_paint_furn", "hcd_fabric", "hcd_steel", "hcd_black", "hcd_plant", "hcd_concrete"]:
		g.material(m).set_meta("no_shadow", true)
	if not g.detail_prefixes.has("hcd_"):
		g.detail_prefixes.append("hcd_")

## Square tiles with grout lines, n x n per texture, a little tone variation.
static func _tiles_image(n: int, tone: float) -> Image:
	var size: int = 128
	var img := Image.create(size, size, false, Image.FORMAT_RGB8)
	var r := RandomNumberGenerator.new()
	r.seed = 77 + n
	var step: int = size / n
	for ty in range(n):
		for tx in range(n):
			var v: float = tone * r.randf_range(0.95, 1.02)
			img.fill_rect(Rect2i(tx * step, ty * step, step, step), Color(v, v, v * 0.99))
	for k in range(n):
		img.fill_rect(Rect2i(k * step, 0, 2, size), Color(0.62, 0.62, 0.6))
		img.fill_rect(Rect2i(0, k * step, size, 2), Color(0.62, 0.62, 0.6))
	return img

static func _tex(img: Image) -> Texture2D:
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func build(g: Geo, pos: Vector3, yaw: float, seed_value: int, opts: Dictionary = {}) -> Dictionary:
	var h := HouseCreator.new()
	h._run(g, pos, yaw, seed_value, opts)
	return {"views": h.views, "size": Vector2(h.W, h.D), "toilets": h.toilets,
		"gate": h.gate_at, "drive": h.drive_at, "xf": h.xf}

## The whole plot (Grundstueck) a village hands over: the house set back
## from the street, then GardenCreator's fences (gates where the path
## and the driveway meet the street) and garden.
## plot: {"frame": Transform3D - origin at the middle of the plot's
##        street edge, +z toward the street, x along it; "width", "depth"}
## Returns build()'s dict plus "trees" (TreeCreator entries) and the
## garden's views.
static func build_plot(g: Geo, plot: Dictionary, seed_value: int, opts: Dictionary = {}) -> Dictionary:
	var f: Transform3D = plot.frame
	var setback: float = opts.get("setback", PLOT_SETBACK)
	var centre: Vector3 = f * Vector3(0, 0, -(setback + 5.4))
	var fz: Vector3 = f.basis.z
	var o: Dictionary = opts.duplicate()
	o["path_to"] = setback + 5.4
	var info: Dictionary = build(g, centre, atan2(fz.x, fz.z), seed_value, o)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value * 31 + 7
	var garden: Dictionary = GardenCreator.build(g, plot, info, rng, opts)
	info["trees"] = garden.trees
	info.views.append_array(garden.views)
	return info

## House front (door face) to the plot's street edge, in build_plot.
const PLOT_SETBACK: float = 7.0
## Where the front path and the driveway reach the street (world), for
## the plot's gates; Vector3.INF when there is none.
var gate_at: Vector3 = Vector3.INF
var path_end: float = 0.0
var drive_at: Vector3 = Vector3.INF

func _run(g: Geo, pos: Vector3, yaw: float, seed_value: int, opts: Dictionary) -> void:
	geo = g
	ensure_materials(geo)
	rng.seed = seed_value
	base = pos
	interior = opts.get("interior", true)
	pins = opts
	# Pinned options (opts) still draw their number: see Pieces.
	var mirror: float = opts.get("mirror", -1.0 if rng.randf() < 0.5 else 1.0)
	xf = Transform3D(Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(mirror, 1, 1)), pos)
	storeys = opts.get("storeys", 1 if rng.randf() < 0.3 else 2)
	W = snappedf(rng.randf_range(9.2, 12.2), 0.1)
	D = snappedf(rng.randf_range(9.3, 10.6), 0.1)
	roof_kind = opts.get("roof", "hip" if rng.randf() < 0.3 else "gable")
	pitch = deg_to_rad(rng.randf_range(24.0, 30.0) if roof_kind == "hip" else rng.randf_range(34.0, 46.0))
	wall_top = FL + storeys * H
	garage = opts.get("garage", ["none", "none", "garage", "carport"][rng.randi() % 4])
	gside = -1.0 if rng.randf() < 0.5 else 1.0
	_style()
	# A house stands on its own level plot and sets its own occlusion
	# levels (_ao, from its base): the terrain's ground hook would count
	# from the ground instead (wrong upstairs) and costs a call per vertex.
	var saved: Array = [geo.ao_ground_y, geo.ao_height, geo.ao_min, geo.tint, geo.ground_fn]
	geo.ground_fn = Callable()
	_plan()
	_plan_windows()
	_ao(0.0, 2.2)
	_prep_light()
	_shell()
	_roof()
	path_end = opts.get("path_to", D * 0.5 + 5.0)
	_front_door_extras(path_end)
	_terrace()
	_garage()
	if interior:
		_floors()
		_stairs()
		for o in ops:
			if not o.ext:
				_inner_door(o)
		_furnish()
	_make_views()
	geo.ao_ground_y = saved[0]
	geo.ao_height = saved[1]
	geo.ao_min = saved[2]
	geo.tint = saved[3]
	geo.ground_fn = saved[4]

var pins: Dictionary = {}

func _style() -> void:
	# Every number is drawn whatever the pins say (see Pieces).
	plaster = not pins.get("brick", rng.randf() >= 0.72)
	var bg: bool = rng.randf() < 0.15
	brick_ground = plaster and bg
	var ft: Color = PLASTER[rng.randi() % PLASTER.size()]
	facade_tint = ft if plaster else Color.WHITE
	trim = TRIMS[rng.randi() % TRIMS.size()]
	shutter_style = ["none", "shutters", "rollers", "rollers"][rng.randi() % 4]
	shutter_tint = SHUTTERS[rng.randi() % SHUTTERS.size()]
	door_tint = DOORS[rng.randi() % DOORS.size()]
	roof_tint = ROOFS[rng.randi() % ROOFS.size()]

# --- drawing helpers (house-local coordinates) -----------------------------------

## Boxes standing on the house's base level (plinth, steps, paths, bins)
## reach down into the real ground (Geo.box_on): the plot is level, but
## its edge, where the path and the drive meet the street, may not be.
func _box(c: Vector3, s: Vector3, mat: String, collide: bool = true) -> void:
	geo.box_on(xf * Transform3D(Basis(), c), s, mat, base.y, collide)

func _boxt(t: Transform3D, s: Vector3, mat: String, collide: bool = true) -> void:
	geo.box_on(xf * t, s, mat, base.y, collide)

## Paving (the path, the driveway) on the plot, x = its middle, from z0
## to z1, w wide, 6 cm thick. Where the real ground under it stands
## higher than the plot - the front of a plot beside a sloping street,
## where the 8 m terrain grid's triangles from the road's bed rise into
## it - it is laid in 1.5 m pieces, each lifted clear of the ground.
func _paving(x: float, z0: float, z1: float, w: float) -> void:
	var n: int = maxi(1, ceili((z1 - z0) / 1.5))
	var L: float = (z1 - z0) / n
	var tops: Array[float] = []
	var lifted: bool = false
	for k in range(n):
		var top: float = 0.06
		if geo.floor_fn.is_valid():
			for u in [-0.5, 0.0, 0.5]:
				for v in [0.0, 0.5, 1.0]:
					var q: Vector3 = xf * Vector3(x + u * w, 0, z0 + (k + v) * L)
					var g: float = geo.floor_fn.call(q.x, q.z)
					if g > -1e5 and g - base.y + 0.04 > top:
						top = g - base.y + 0.04
						lifted = true
		tops.append(top)
	if not lifted:
		_box(Vector3(x, 0.03, (z0 + z1) * 0.5), Vector3(w, 0.06, z1 - z0), "hc_paving", false)
		return
	for k in range(n):
		_box(Vector3(x, tops[k] * 0.5, z0 + (k + 0.5) * L), Vector3(w, tops[k], L), "hc_paving", false)

## Box in a sub-frame t (furniture, openings): c and s in t's coordinates.
func _fb(t: Transform3D, c: Vector3, s: Vector3, mat: String, collide: bool = true) -> void:
	geo.box_on(xf * t * Transform3D(Basis(), c), s, mat, base.y, collide)

func _cyl(t: Transform3D, a: Vector3, b: Vector3, r: float, mat: String, sides: int = 10, collide: bool = true) -> void:
	geo.cylinder(xf * t * a, xf * t * b, r, mat, sides, collide)

func _cone(t: Transform3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: String, sides: int = 12, collide: bool = false) -> void:
	geo.cone(xf * t * a, xf * t * b, r0, r1, mat, sides, collide)

func _beam(a: Vector3, b: Vector3, th: Vector2, mat: String, collide: bool = true) -> void:
	geo.beam(xf * a, xf * b, th, mat, collide)

func _tint(c: Color) -> void:
	geo.tint = c

## Baked ambient occlusion: darkening toward local height y over h metres.
func _ao(y: float, h: float, ao_min: float = 0.55) -> void:
	geo.ao_ground_y = base.y + y
	geo.ao_height = h
	geo.ao_min = ao_min

# --- plan ------------------------------------------------------------------------

func _room(kind: String, s: int, r: Rect2) -> Dictionary:
	var wall: String = "hcd_tiles" if kind in ["bath", "wc"] else "hcd_paint"
	var tint: Color = Color(0.95, 0.96, 0.97) if wall == "hcd_tiles" else WALLS[rng.randi() % WALLS.size()]
	if kind == "kids":
		tint = [Color(0.85, 0.92, 0.98), Color(0.98, 0.9, 0.9), Color(0.92, 0.97, 0.86)][rng.randi() % 3]
	var floor_mat: String = "hcd_floor_tiles" if kind in ["bath", "wc", "kitchen"] else "hcd_parquet"
	var ft: Color = Color(rng.randf_range(0.85, 1.05), rng.randf_range(0.82, 1.0), rng.randf_range(0.8, 0.95))
	if floor_mat == "hcd_floor_tiles":
		var g: float = rng.randf_range(0.7, 1.0)
		ft = Color(g, g * 0.98, g * rng.randf_range(0.9, 0.97))
	elif rng.randf() < 0.35:
		ft = Color(0.62, 0.55, 0.5)
	var rm := {"kind": kind, "s": s, "r": r, "fy": FL + s * H, "tint": tint, "wall": wall,
		"floor": floor_mat, "floor_tint": ft, "ops": [], "used": [], "door": Vector2.ZERO, "door_in": Vector2.ZERO}
	rooms.append(rm)
	return rm

func _plan() -> void:
	X0 = -W * 0.5 + T
	X1 = W * 0.5 - T
	Z0 = -D * 0.5 + T
	Z1 = D * 0.5 - T
	var two: bool = storeys == 2
	var fd: float = clampf(D * 0.5 - 0.1, 4.65, 5.2) if two else rng.randf_range(3.6, 4.4)
	zc = Z1 - fd - P * 0.5
	var zf0: float = zc + P * 0.5
	var zb1: float = zc - P * 0.5
	var hw: float = 2.4 if two else 2.0
	var wi: float = X1 - X0
	var rw: float = clampf((wi - hw - 2.0 * P) * 0.36, 1.8, 3.0)
	hx1 = X1 - rw - P
	hx0 = hx1 - hw
	var xl: float = hx0 - P * 0.5
	var xr: float = hx1 + P * 0.5
	var xb: float = (hx0 + hx1) * 0.5
	z_top = Z1 - STEPS * TREAD
	var kit := Rect2(X0, zf0, hx0 - P - X0, fd)
	var hall := Rect2(hx0, zf0, hw, fd)
	var right := Rect2(hx1 + P, zf0, X1 - hx1 - P, fd)
	var back_l := Rect2(X0, Z0, xb - P * 0.5 - X0, zb1 - Z0)
	var back_r := Rect2(xb + P * 0.5, Z0, X1 - xb - P * 0.5, zb1 - Z0)
	var door_z: float = (zf0 + z_top) * 0.5 if two else zf0 + fd * 0.5
	for s in range(storeys):
		parts.append([s, "x", zc, X0, X1])
		parts.append([s, "z", xl, zf0, Z1])
		parts.append([s, "z", xr, zf0, Z1])
	if two:
		hole = Rect2(hx0, z_top, 1.0, Z1 - z_top)
		var k := _room("kitchen", 0, kit)
		var h0 := _room("hall", 0, hall)
		h0.used.append(hole)
		var wc := _room("wc", 0, right)
		var lv := _room("living", 0, Rect2(X0, Z0, X1 - X0, zb1 - Z0))
		_door(0, "z", xl, door_z, 0.85, k, h0)
		_door(0, "z", xr, zf0 + fd * 0.6, 0.8, wc, h0)
		_door(0, "x", zc, (hx0 + hx1) * 0.5, 1.0, lv, h0)
		if rng.randf() < 0.6:
			_door(0, "x", zc, (X0 + hx0 - P) * 0.5, 1.0, lv, k, false)
		var bath := _room("bath", 1, kit)
		var h1 := _room("hall", 1, hall)
		h1.used.append(hole)
		var st := _room("study" if rng.randf() < 0.5 else "kids", 1, right)
		var lr := _room("bed", 1, back_l)
		var rr := _room("kids", 1, back_r)
		parts.append([1, "z", xb, Z0, zb1])
		_door(1, "z", xl, door_z, 0.8, bath, h1)
		_door(1, "z", xr, zf0 + fd * 0.6, 0.8, st, h1)
		_door(1, "x", zc, (hx0 + xb - P * 0.5) * 0.5, 0.8, lr, h1)
		_door(1, "x", zc, (xb + P * 0.5 + hx1) * 0.5, 0.8, rr, h1)
	else:
		var k := _room("kitchen", 0, kit)
		var h0 := _room("hall", 0, hall)
		var bath := _room("bath", 0, right)
		var lr := _room("living", 0, back_l)
		var rr := _room("bed", 0, back_r)
		parts.append([0, "z", xb, Z0, zb1])
		_door(0, "z", xl, door_z, 0.85, k, h0)
		_door(0, "z", xr, door_z, 0.8, bath, h0)
		_door(0, "x", zc, (hx0 + xb - P * 0.5) * 0.5, 0.9, lr, h0)
		_door(0, "x", zc, (xb + P * 0.5 + hx1) * 0.5, 0.8, rr, h0)

## An inner door at u along the partition (axis, c), swinging into room
## `into`; `from` is the room on the other side.
func _door(s: int, axis: String, c: float, u: float, w: float, into: Dictionary, from: Dictionary, leaf: bool = true) -> void:
	var r: Rect2 = into.r
	var sgn: float
	if axis == "x":
		sgn = 1.0 if r.get_center().y > c else -1.0
	else:
		sgn = 1.0 if r.get_center().x > c else -1.0
	var fy: float = FL + s * H
	var o := {"s": s, "axis": axis, "c": c, "u0": u - w * 0.5, "u1": u + w * 0.5, "v0": fy - 0.02, "v1": fy + 2.05,
		"kind": "door" if leaf else "pass", "ext": false, "out": sgn, "open": true, "into": into}
	ops.append(o)
	var pt: Vector2 = Vector2(u, c) if axis == "x" else Vector2(c, u)
	var into_dir: Vector2 = Vector2(0, sgn) if axis == "x" else Vector2(sgn, 0)
	for rm: Dictionary in [into, from]:
		var sd: float = 1.0 if rm == into else -1.0
		_block(rm, axis, o.u0, o.u1, true, c)
		# Keep the swing (and the way through) clear of furniture.
		var a: Vector2 = pt + into_dir * sd * P * 0.5
		var b: Vector2 = pt + into_dir * sd * (P * 0.5 + w + 0.1)
		var keep := Rect2(a, Vector2.ZERO).expand(b)
		keep = keep.grow_individual(w * 0.5 if axis == "x" else 0.0, w * 0.5 if axis == "z" else 0.0, w * 0.5 if axis == "x" else 0.0, w * 0.5 if axis == "z" else 0.0)
		rm.used.append(keep)
		if rm.door == Vector2.ZERO or rm.kind == "hall":
			rm.door = a
			rm.door_in = into_dir * sd

## Marks a wall interval of room rm as taken (tall: floor to ceiling;
## else only above window-sill height).
func _block(rm: Dictionary, axis: String, u0: float, u1: float, tall: bool, c: float) -> void:
	var r: Rect2 = rm.r
	var side: String
	if axis == "x":
		side = "n" if absf(r.position.y - c) < 0.5 else "s"
	else:
		side = "w" if absf(r.position.x - c) < 0.5 else "e"
	rm.ops.append([side, u0, u1, tall])

func _exterior_sides(rm: Dictionary) -> Array:
	var r: Rect2 = rm.r
	var out: Array = []
	if absf(r.end.y - Z1) < 0.01:
		out.append(["x", D * 0.5 - T * 0.5, 1.0, r.position.x, r.end.x, "s"])
	if absf(r.position.y - Z0) < 0.01:
		out.append(["x", -D * 0.5 + T * 0.5, -1.0, r.position.x, r.end.x, "n"])
	if absf(r.end.x - X1) < 0.01:
		out.append(["z", W * 0.5 - T * 0.5, 1.0, r.position.y, r.end.y, "e"])
	if absf(r.position.x - X0) < 0.01:
		out.append(["z", -W * 0.5 + T * 0.5, -1.0, r.position.y, r.end.y, "w"])
	return out

func _ext_op(rm: Dictionary, side: Array, u: float, w: float, v0: float, v1: float, kind: String) -> Dictionary:
	var o := {"s": rm.s, "axis": side[0], "c": side[1], "u0": u - w * 0.5, "u1": u + w * 0.5, "v0": v0, "v1": v1,
		"kind": kind, "ext": true, "out": side[2], "open": kind == "patio", "room": rm}
	ops.append(o)
	rm.ops.append([side[5], o.u0, o.u1, kind in ["front", "patio"] or v0 < rm.fy + 0.8])
	if kind in ["front", "patio"]:
		var um: float = (o.u0 + o.u1) * 0.5
		var inner: float = side[1] - side[2] * T * 0.5
		if side[0] == "x":
			rm.used.append(Rect2(Vector2(o.u0 - 0.1, inner), Vector2.ZERO).expand(Vector2(o.u1 + 0.1, inner - side[2] * 1.3)))
		else:
			rm.used.append(Rect2(Vector2(inner, o.u0 - 0.1), Vector2.ZERO).expand(Vector2(inner - side[2] * 1.3, o.u1 + 0.1)))
		rm.door = Vector2(um, inner) if side[0] == "x" else Vector2(inner, um)
		rm.door_in = Vector2(0, -side[2]) if side[0] == "x" else Vector2(-side[2], 0)
	return o

func _plan_windows() -> void:
	var open_candidates: Array = []
	for rm: Dictionary in rooms:
		var fy: float = rm.fy
		var kind: String = rm.kind
		var sides: Array = _exterior_sides(rm)
		var count: int = 0
		for si in range(sides.size()):
			var sd: Array = sides[si]
			var a0: float = sd[3] + 0.45
			var a1: float = sd[4] - 0.45
			var front: bool = sd[5] == "s"
			var back: bool = sd[5] == "n"
			if kind == "hall":
				if not front:
					continue
				if rm.s == 0:
					var dx: float = (hx0 + 1.0 + hx1) * 0.5 if storeys == 2 else (hx0 + hx1) * 0.5
					var fdoor := _ext_op(rm, sd, dx, 1.0, FL - 0.02, FL + 2.15, "front")
					fdoor.open = rng.randf() < 0.3
				else:
					_ext_op(rm, sd, (hx0 + hx1) * 0.5, 1.0, fy + 0.9, fy + 2.2, "window")
				count += 1
				continue
			# Side walls: not every room gets a window there; none behind the garage.
			if sd[0] == "z":
				var chance: float = {"kitchen": 0.5, "living": 0.85, "bed": 0.6, "kids": 0.6, "study": 0.5, "bath": 0.3, "wc": 0.3}.get(kind, 0.4)
				if rng.randf() > chance or (garage != "none" and rm.s == 0 and sd[2] == gside):
					continue
			var v0: float = fy + 0.9
			var v1: float = fy + 2.2
			var wmin: float = 0.9
			var wmax: float = 1.5
			var wk: String = "window"
			if kind in ["bath", "wc"]:
				v0 = fy + 1.35
				v1 = fy + 2.1
				wmin = 0.55
				wmax = 0.8
				wk = "small"
			elif kind == "kitchen":
				v0 = fy + 1.05
			if kind == "living" and back:
				# Patio door, windows in what is left either side.
				var pw: float = rng.randf_range(1.6, 2.0)
				var pu: float = lerpf(a0 + pw * 0.5, a1 - pw * 0.5, rng.randf_range(0.25, 0.75))
				_ext_op(rm, sd, pu, pw, fy - 0.02, fy + 2.15, "patio")
				count += 1
				count += _fill(rm, sd, a0, pu - pw * 0.5 - 0.6, v0, v1, wmin, wmax, wk, open_candidates)
				count += _fill(rm, sd, pu + pw * 0.5 + 0.6, a1, v0, v1, wmin, wmax, wk, open_candidates)
				continue
			count += _fill(rm, sd, a0, a1, v0, v1, wmin, wmax, wk, open_candidates)
		if count == 0 and not sides.is_empty():
			var sd: Array = sides[0]
			_fill(rm, sd, sd[3] + 0.45, sd[4] - 0.45, fy + 0.9, fy + 2.2, 0.9, 1.2, "window", open_candidates)
	# One window (sometimes two) stands open - a way in from outside.
	# (Shuffled with the house's own rng: Array.shuffle() uses the global
	# one, seeded anew every run - the house came out different on every
	# load.)
	for k in range(open_candidates.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, k)
		var sw: Variant = open_candidates[k]
		open_candidates[k] = open_candidates[j]
		open_candidates[j] = sw
	var n_open: int = 2 if rng.randf() < 0.3 else 1
	for o in open_candidates.slice(0, n_open):
		o.open = true
		o.kind = "window"

func _fill(rm: Dictionary, sd: Array, a0: float, a1: float, v0: float, v1: float, wmin: float, wmax: float, kind: String, open_candidates: Array) -> int:
	var L: float = a1 - a0
	if L < wmin:
		return 0
	var n: int = clampi(int((L + 0.9) / 2.9), 1, 3)
	var w: float = clampf((L - (n - 1) * 0.9) / n, wmin, wmax)
	if kind == "window":
		w = snappedf(rng.randf_range(maxf(wmin, w - 0.3), w), 0.05)
	for i in range(n):
		var u: float = a0 + L * (i + 0.5) / n
		var o := _ext_op(rm, sd, u, w, v0, v1, kind)
		var upper: bool = rm.s == storeys - 1
		if kind == "window" and w >= 1.0 and upper and rm.kind in ["bed", "kids", "study", "living"]:
			open_candidates.append(o)
	return n

# --- shell -----------------------------------------------------------------------

## Solid wall rectangles (u along the wall, v height) around openings.
func _rects(a0: float, a1: float, y0: float, y1: float, holes: Array) -> Array:
	var out: Array = []
	holes.sort_custom(func(p: Array, q: Array) -> bool: return p[0] < q[0])
	var u: float = a0
	for o: Array in holes:
		var u0: float = maxf(o[0], a0)
		var u1: float = minf(o[1], a1)
		if u1 <= u0:
			continue
		if u0 > u:
			out.append(Rect2(u, y0, u0 - u, y1 - y0))
		if o[2] > y0:
			out.append(Rect2(u0, y0, u1 - u0, minf(o[2], y1) - y0))
		if o[3] < y1:
			out.append(Rect2(u0, maxf(o[3], y0), u1 - u0, y1 - maxf(o[3], y0)))
		u = maxf(u, u1)
	if u < a1:
		out.append(Rect2(u, y0, a1 - u, y1 - y0))
	return out

func _wall_box(axis: String, c: float, th: float, r: Rect2, mat: String) -> void:
	if r.size.x < 0.005 or r.size.y < 0.005:
		return
	var mu: float = r.position.x + r.size.x * 0.5
	var mv: float = r.position.y + r.size.y * 0.5
	if axis == "x":
		_box(Vector3(mu, mv, c), Vector3(r.size.x, r.size.y, th), mat)
	else:
		_box(Vector3(c, mv, mu), Vector3(th, r.size.y, r.size.x), mat)

func _holes(s: int, axis: String, c: float) -> Array:
	var out: Array = []
	for o in ops:
		if o.s == s and o.axis == axis and absf(o.c - c) < 0.01:
			out.append([o.u0, o.u1, o.v0, o.v1])
	return out

## Paint/tile skins of the rooms on one face of a wall.
func _skins(s: int, axis: String, face: float, sign: float, rects: Array) -> void:
	for rm: Dictionary in rooms:
		if rm.s != s:
			continue
		var r: Rect2 = rm.r
		var edge: float
		var ra: float
		var rb: float
		if axis == "x":
			edge = r.position.y if sign > 0 else r.end.y
			ra = r.position.x
			rb = r.end.x
		else:
			edge = r.position.x if sign > 0 else r.end.x
			ra = r.position.y
			rb = r.end.y
		if absf(edge - face) > 0.01:
			continue
		_tint(rm.tint)
		_lit(rm)
		for q: Rect2 in rects:
			var u0: float = maxf(q.position.x, ra)
			var u1: float = minf(q.end.x, rb)
			var v0: float = maxf(q.position.y, rm.fy)
			var v1: float = minf(q.end.y, rm.fy + CH)
			if u1 - u0 > 0.005 and v1 - v0 > 0.005:
				_vface(axis, face + sign * SK, sign, u0, u1, v0, v1, rm.wall)
	_lit({})
	_tint(Color.WHITE)

func _shell() -> void:
	var walls: Array = [
		["x", D * 0.5 - T * 0.5, 1.0, -W * 0.5, W * 0.5],
		["x", -D * 0.5 + T * 0.5, -1.0, -W * 0.5, W * 0.5],
		["z", W * 0.5 - T * 0.5, 1.0, -D * 0.5 + T, D * 0.5 - T],
		["z", -W * 0.5 + T * 0.5, -1.0, -D * 0.5 + T, D * 0.5 - T]]
	for s in range(storeys):
		var y0: float = 0.0 if s == 0 else FL + s * H
		var y1: float = FL + (s + 1) * H
		var brick: bool = not plaster or (brick_ground and s == 0)
		for wl: Array in walls:
			var rects: Array = _rects(wl[3], wl[4], y0, y1, _holes(s, wl[0], wl[1]))
			_tint(Color.WHITE if brick else facade_tint)
			for q: Rect2 in rects:
				_wall_box(wl[0], wl[1], T, q, "hc_brick" if brick else "hc_plaster")
			_tint(Color.WHITE)
			if interior:
				_ao(FL + s * H, 1.4, 0.72)
				_skins(s, wl[0], wl[1] - wl[2] * T * 0.5, -wl[2], rects)
				_ao(0.0, 2.2)
	# Plinth band, proud of the wall.
	_tint(Color.WHITE)
	for sd in [-1.0, 1.0]:
		_box(Vector3(0, FL * 0.5 - 0.05, sd * (D * 0.5 + 0.02)), Vector3(W + 0.08, FL + 0.1, 0.04), "hc_plinth")
		_box(Vector3(sd * (W * 0.5 + 0.02), FL * 0.5 - 0.05, 0), Vector3(0.04, FL + 0.1, D), "hc_plinth")
	if interior:
		for pt: Array in parts:
			var s: int = pt[0]
			var fy: float = FL + s * H
			var rects: Array = _rects(pt[3], pt[4], fy - 0.02, fy + CH, _holes(s, pt[1], pt[2]))
			_tint(Color(0.96, 0.96, 0.95))
			_lit(_room_beside(s, pt[1], pt[2]))
			for q: Rect2 in rects:
				_wall_box(pt[1], pt[2], P - 0.002, q, "hcd_paint")
			_lit({})
			_skins(s, pt[1], pt[2] + P * 0.5, 1.0, rects)
			_skins(s, pt[1], pt[2] - P * 0.5, -1.0, rects)
		_ao(0.0, 2.2)
	for o in ops:
		if o.ext:
			_ext_opening(o)

## Frame of an opening: origin at the bottom middle on the wall face
## (outer face for exterior openings, the swing side for inner doors),
## x across, y up, +z out of the wall (outside / into the swing room).
func _op_xf(o: Dictionary) -> Transform3D:
	var half: float = (T if o.ext else P) * 0.5
	var um: float = (o.u0 + o.u1) * 0.5
	var out: float = o.out
	if o.axis == "x":
		return Transform3D(Basis(Vector3.UP, 0.0 if out > 0 else PI), Vector3(um, o.v0, o.c + out * half))
	return Transform3D(Basis(Vector3.UP, PI * 0.5 if out > 0 else -PI * 0.5), Vector3(o.c + out * half, o.v0, um))

func _ext_opening(o: Dictionary) -> void:
	var t: Transform3D = _op_xf(o)
	var w: float = o.u1 - o.u0
	var h: float = o.v1 - o.v0
	var fw: float = 0.07
	var zf: float = -0.12
	var door: bool = o.kind in ["front", "patio"]
	var glass: String = "hc_glass"
	if not interior:
		_niche(t, w, h, door)
	_tint(trim)
	# Outer frame.
	_fb(t, Vector3(-w * 0.5 + fw * 0.5, h * 0.5, zf), Vector3(fw, h, 0.08), "hc_trim")
	_fb(t, Vector3(w * 0.5 - fw * 0.5, h * 0.5, zf), Vector3(fw, h, 0.08), "hc_trim")
	_fb(t, Vector3(0, h - fw * 0.5, zf), Vector3(w, fw, 0.08), "hc_trim")
	if not door:
		_fb(t, Vector3(0, fw * 0.5, zf), Vector3(w, fw, 0.08), "hc_trim")
	var iw: float = w - 2.0 * fw
	var y0: float = 0.0 if door else fw
	var ih: float = h - fw - y0
	if o.kind == "front":
		_front_leaf(t, iw, ih, zf, o.open)
	else:
		var leaves: int = 2 if iw >= 1.0 else 1
		var lw: float = iw / leaves
		for i in range(leaves):
			var lx: float = -iw * 0.5 + lw * i
			var opened: bool = o.open and i == 0 and interior
			var ang: float = deg_to_rad(rng.randf_range(70.0, 95.0)) if opened else 0.0
			# Hinge on the leaf's outer edge; opens inward (toward -z).
			var hinge_x: float = lx if i == 0 else lx + lw
			var dir: float = 1.0 if i == 0 else -1.0
			var lt: Transform3D = t * Transform3D(Basis(Vector3.UP, ang * dir), Vector3(hinge_x, y0, zf - 0.03))
			_sash(lt, dir, lw, ih, glass)
	_tint(Color.WHITE)
	if not door:
		# Sill outside, window board inside.
		_tint(Color(0.82, 0.82, 0.8))
		_fb(t, Vector3(0, -0.02, 0.05), Vector3(w + 0.1, 0.04, 0.2), "hc_trim")
		_tint(Color.WHITE)
		if interior:
			_tint(Color(0.95, 0.94, 0.92))
			_fb(t, Vector3(0, -0.015, -T - 0.07), Vector3(w + 0.08, 0.03, 0.2), "hcd_paint_furn")
			_tint(Color.WHITE)
	if plaster and o.kind != "patio" and not (brick_ground and o.s == 0):
		# Stucco surround, a shade lighter than the wall.
		_tint(facade_tint.lightened(0.35))
		var sw: float = 0.12
		_fb(t, Vector3(-w * 0.5 - sw * 0.5, h * 0.5, 0.015), Vector3(sw, h + (0.0 if door else 2.0 * sw), 0.03), "hc_plaster")
		_fb(t, Vector3(w * 0.5 + sw * 0.5, h * 0.5, 0.015), Vector3(sw, h + (0.0 if door else 2.0 * sw), 0.03), "hc_plaster")
		_fb(t, Vector3(0, h + sw * 0.5, 0.015), Vector3(w + 2.0 * sw, sw, 0.03), "hc_plaster")
		_tint(Color.WHITE)
	elif not plaster or (brick_ground and o.s == 0):
		# Brick soldier course over the opening.
		_fb(t, Vector3(0, h + 0.12, 0.01), Vector3(w + 0.2, 0.24, 0.02), "hc_brick")
	if o.kind in ["window", "small"]:
		_shutters(o, t, w, h)

## Closed houses (no interior): behind each pane a shallow painted room
## niche - back wall, sides, curtains, now and then a plant on the sill -
## so the glass shows a lived-in room from outside for a few boxes.
## Shell materials ("hc_"), so the niche never drops out at distance and
## leaves a see-through window.
func _niche(t: Transform3D, w: float, h: float, door: bool) -> void:
	var dep: float = 0.9 if door else 0.55
	var z0: float = -T
	var zc: float = z0 - dep * 0.5
	var wall: Color = (_pick(WALLS) as Color) * 0.62
	var y0: float = 0.0 if door else -0.05
	var y1: float = h + 0.05
	var hw: float = w * 0.5 + 0.05
	_tint(wall)
	_fb(t, Vector3(0, (y0 + y1) * 0.5, z0 - dep), Vector3(w + 0.1, y1 - y0, 0.04), "hc_trim", false)
	_tint(wall * 0.8)
	for sd in [-1.0, 1.0]:
		_fb(t, Vector3(sd * hw, (y0 + y1) * 0.5, zc), Vector3(0.04, y1 - y0, dep), "hc_trim", false)
	_tint(wall * 0.7)
	_fb(t, Vector3(0, y1, zc), Vector3(w + 0.1, 0.04, dep), "hc_trim", false)
	_tint(Color(0.55, 0.42, 0.3) if door else wall * 0.9)
	_fb(t, Vector3(0, y0, zc), Vector3(w + 0.1, 0.04, dep), "hc_trim", false)
	if rng.randf() < 0.75:
		# Curtains drawn to the sides, a hand's width behind the glass.
		var cw: float = w * rng.randf_range(0.14, 0.3)
		_tint((_pick(FABRICS) as Color).lightened(0.15))
		for sd in [-1.0, 1.0]:
			_fb(t, Vector3(sd * (w * 0.5 - cw * 0.5), (y0 + y1) * 0.5 + 0.05, z0 - 0.1), Vector3(cw, y1 - y0 - 0.1, 0.05), "hc_trim", false)
	if not door and rng.randf() < 0.3:
		var px: float = rng.randf_range(-w * 0.3, w * 0.3)
		_tint(Color(0.7, 0.4, 0.28))
		_cyl(t, Vector3(px, -0.02, z0 - 0.15), Vector3(px, 0.14, z0 - 0.15), 0.08, "hc_trim", 8, false)
		_tint(Color(0.3, 0.5, 0.22))
		_cone(t, Vector3(px, 0.14, z0 - 0.15), Vector3(px, rng.randf_range(0.35, 0.55), z0 - 0.15), 0.14, 0.03, "hc_trim", 7)
	_tint(Color.WHITE)

## A window sash (frame + glass) hinged at the frame origin, extending
## along dir * x.
func _sash(lt: Transform3D, dir: float, lw: float, ih: float, glass: String) -> void:
	var sf: float = 0.055
	var cx: float = dir * lw * 0.5
	_fb(lt, Vector3(dir * sf * 0.5, ih * 0.5, 0), Vector3(sf, ih, 0.06), "hc_trim")
	_fb(lt, Vector3(dir * (lw - sf * 0.5), ih * 0.5, 0), Vector3(sf, ih, 0.06), "hc_trim")
	_fb(lt, Vector3(cx, sf * 0.5, 0), Vector3(lw, sf, 0.06), "hc_trim")
	_fb(lt, Vector3(cx, ih - sf * 0.5, 0), Vector3(lw, sf, 0.06), "hc_trim")
	_fb(lt, Vector3(cx, ih * 0.5, 0), Vector3(lw - 2.0 * sf, ih - 2.0 * sf, 0.016), glass)
	# Handle.
	_tint(Color(0.8, 0.8, 0.8))
	_fb(lt, Vector3(dir * (lw - sf * 0.5), ih * 0.5, -0.05), Vector3(0.02, 0.14, 0.03), "hc_trim", false)
	_tint(trim)

func _front_leaf(t: Transform3D, iw: float, ih: float, zf: float, opened: bool) -> void:
	var ang: float = deg_to_rad(80.0) if opened and interior else 0.0
	var lt: Transform3D = t * Transform3D(Basis(Vector3.UP, ang), Vector3(-iw * 0.5, 0.0, zf - 0.02))
	_tint(door_tint)
	_fb(lt, Vector3(iw * 0.5, ih * 0.5, 0), Vector3(iw, ih, 0.06), "hc_trim")
	_tint(Color.WHITE)
	# Glass strip and handle bar.
	for sd in [-1.0, 1.0]:
		_fb(lt, Vector3(iw * 0.32, ih * 0.55, sd * 0.032), Vector3(0.14, ih * 0.6, 0.006), "hc_glass_dark", false)
	_tint(Color(0.8, 0.8, 0.82))
	_fb(lt, Vector3(iw * 0.82, 1.05, 0.06), Vector3(0.03, 0.8, 0.03), "hc_trim", false)
	_tint(Color.WHITE)

func _shutters(o: Dictionary, t: Transform3D, w: float, h: float) -> void:
	if shutter_style == "rollers":
		# Roller blind: guide rails and a part-lowered curtain (never on an open window).
		var drop: float = 0.0
		var r: float = rng.randf()
		if not o.open:
			drop = 0.0 if r < 0.45 else (1.0 if r > 0.9 else rng.randf_range(0.15, 0.6))
		_tint(shutter_tint.darkened(0.1))
		_fb(t, Vector3(0, h - 0.08, -0.05), Vector3(w, 0.16, 0.06), "hc_trim")
		if drop > 0.0:
			var dh: float = (h - 0.16) * drop
			_fb(t, Vector3(0, h - 0.16 - dh * 0.5, -0.05), Vector3(w - 0.02, dh, 0.025), "hc_trim")
		_tint(Color.WHITE)
		return
	if shutter_style != "shutters" or o.kind == "small":
		return
	# Folding shutters: only where they fit beside the window.
	var pw: float = w * 0.5
	for o2 in ops:
		if o2 == o or o2.s != o.s or o2.axis != o.axis or absf(o2.c - o.c) > 0.01:
			continue
		if o2.u1 > o.u0 - pw - 0.1 and o2.u0 < o.u1 + pw + 0.1:
			return
	var lim: float = W * 0.5 if o.axis == "x" else D * 0.5
	if o.u0 - pw < -lim + 0.15 or o.u1 + pw > lim - 0.15:
		return
	_tint(shutter_tint)
	for sd in [-1.0, 1.0]:
		var cx: float = sd * (w * 0.5 + 0.06 + pw * 0.5)
		_fb(t, Vector3(cx, h * 0.5, 0.03), Vector3(pw, h, 0.035), "hc_trim")
		_tint(shutter_tint.darkened(0.25))
		var n: int = int(h / 0.12)
		for k in range(1, n):
			_fb(t, Vector3(cx, k * h / n, 0.052), Vector3(pw - 0.1, 0.025, 0.012), "hc_trim", false)
		_tint(shutter_tint)
	_tint(Color.WHITE)

# --- roof ------------------------------------------------------------------------

func _roof() -> void:
	var tn: float = tan(pitch)
	var ov: float = 0.45 if roof_kind == "hip" else 0.5
	var ye: float = wall_top - ov * tn
	var rise: float = D * 0.5 * tn
	_ao(0.0, 2.2)
	if roof_kind == "hip":
		var rl: float = maxf(W - D, 0.4)
		var top: float = ye + (D * 0.5 + ov) * tn
		var c: Array = []
		for i in range(8):
			var px: float = (rl * 0.5 if i & 2 else W * 0.5 + ov) * (1.0 if i & 1 else -1.0)
			var py: float = top if i & 2 else ye
			var pz: float = 0.0 if i & 2 else (D * 0.5 + ov) * (1.0 if i & 4 else -1.0)
			c.append(xf * Vector3(px, py, pz))
		_tint(roof_tint)
		geo.hexa(c, "hc_roof")
		_tint(trim)
		_box(Vector3(0, ye - 0.02, 0), Vector3(W + 2.0 * ov, 0.04, D + 2.0 * ov), "hc_trim")
		_tint(Color(0.35, 0.36, 0.38))
		for sd in [-1.0, 1.0]:
			_box(Vector3(0, ye - 0.08, sd * (D * 0.5 + ov + 0.05)), Vector3(W + 2.0 * ov + 0.2, 0.12, 0.12), "hc_trim", false)
			_box(Vector3(sd * (W * 0.5 + ov + 0.05), ye - 0.08, 0), Vector3(0.12, 0.12, D + 2.0 * ov), "hc_trim", false)
		_tint(Color.WHITE)
		_downpipes(ye, ov)
		_chimney(top, 0.0)
		return
	var gov: float = 0.35
	var rt: float = 0.22
	var ridge: float = wall_top + rise
	_tint(roof_tint)
	for sd in [-1.0, 1.0]:
		var b := Basis(Vector3.RIGHT, sd * pitch)
		var mid := Vector3(0, (ridge + ye) * 0.5, sd * (D * 0.5 + ov) * 0.5)
		var L: float = (D * 0.5 + ov) / cos(pitch)
		_boxt(Transform3D(b, mid + b.y * rt * 0.5), Vector3(W + 2.0 * gov, rt, L), "hc_roof")
	_tint(roof_tint.darkened(0.2))
	_box(Vector3(0, ridge + rt / cos(pitch) - 0.02, 0), Vector3(W + 2.0 * gov, 0.16, 0.34), "hc_roof")
	# Gable triangles.
	var brick: bool = not plaster
	_tint(Color.WHITE if brick else facade_tint)
	for sd in [-1.0, 1.0]:
		var gt := Transform3D(Basis(), Vector3(sd * (W * 0.5 - T * 0.5), wall_top, 0))
		geo.prism(xf * gt, [Vector2(-D * 0.5, 0), Vector2(D * 0.5, 0), Vector2(0, rise)], T, "hc_brick" if brick else "hc_plaster")
	# Fascia, soffit, verge boards; gutters.
	_tint(trim)
	for sd in [-1.0, 1.0]:
		_box(Vector3(0, ye + 0.08, sd * (D * 0.5 + ov + 0.02)), Vector3(W + 2.0 * gov, 0.22, 0.04), "hc_trim")
		_box(Vector3(0, ye + 0.015, sd * (D * 0.5 + ov * 0.5)), Vector3(W + 2.0 * gov, 0.03, ov), "hc_trim", false)
		for sz in [-1.0, 1.0]:
			_beam(Vector3(sd * (W * 0.5 + gov + 0.02), ye + 0.12, sz * (D * 0.5 + ov)), Vector3(sd * (W * 0.5 + gov + 0.02), ridge + 0.12, 0), Vector2(0.04, 0.24), "hc_trim", false)
	_tint(Color(0.35, 0.36, 0.38))
	for sd in [-1.0, 1.0]:
		_box(Vector3(0, ye - 0.06, sd * (D * 0.5 + ov + 0.1)), Vector3(W + 2.0 * gov, 0.12, 0.13), "hc_trim", false)
	_tint(Color.WHITE)
	_downpipes(ye, ov)
	_chimney(ridge + rt, -1.0)
	# Dormers on the street side.
	if rng.randf() < (0.7 if storeys == 1 else 0.25) and pitch > deg_to_rad(36.0):
		var n: int = 2 if W > 11.0 and rng.randf() < 0.5 else 1
		for i in range(n):
			var dx: float = 0.0 if n == 1 else (i - 0.5) * W * 0.45
			_dormer(dx, tn, ov)

func _downpipes(ye: float, ov: float) -> void:
	_tint(Color(0.35, 0.36, 0.38))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var x: float = sx * (W * 0.5 - 0.25)
			var z: float = sz * (D * 0.5 + 0.08)
			_beam(Vector3(x, ye - 0.08, sz * (D * 0.5 + ov + 0.1)), Vector3(x, ye - 0.3, z), Vector2(0.08, 0.08), "hc_trim", false)
			_cyl(Transform3D(), Vector3(x, 0.1, z), Vector3(x, ye - 0.3, z), 0.045, "hc_trim", 8, false)
	_tint(Color.WHITE)

func _chimney(top: float, z_side: float) -> void:
	if rng.randf() > 0.75:
		return
	var cx: float = rng.randf_range(-W * 0.25, W * 0.25)
	var cz: float = z_side * rng.randf_range(0.3, 0.9)
	var y0: float = wall_top - 0.2
	var y1: float = top + 0.7
	_tint(Color.WHITE if not plaster or rng.randf() < 0.5 else facade_tint)
	_box(Vector3(cx, (y0 + y1) * 0.5, cz), Vector3(0.56, y1 - y0, 0.56), "hc_brick" if not plaster or rng.randf() < 0.6 else "hc_plaster")
	_tint(Color(0.7, 0.7, 0.68))
	_box(Vector3(cx, y1 + 0.05, cz), Vector3(0.68, 0.1, 0.68), "hc_plinth")
	_tint(Color.WHITE)

func _dormer(dx: float, tn: float, ov: float) -> void:
	var dw: float = 1.9
	var zf: float = D * 0.5 - 1.0
	var yb: float = wall_top + (D * 0.5 - zf) * tn
	var hgt: float = 1.45
	var depth: float = (hgt + 0.3) / tn
	_tint(Color.WHITE if not plaster else facade_tint)
	_box(Vector3(dx, yb - 0.1 + (hgt + 0.1) * 0.5, zf - depth * 0.5), Vector3(dw, hgt + 0.1, depth), "hc_brick" if not plaster else "hc_plaster")
	_tint(roof_tint)
	_boxt(Transform3D(Basis(Vector3.RIGHT, 0.08), Vector3(dx, yb + hgt + 0.08, zf - depth * 0.5 + 0.1)), Vector3(dw + 0.3, 0.14, depth + 0.3), "hc_roof")
	_tint(trim)
	var t := Transform3D(Basis(), Vector3(dx, yb + 0.25, zf))
	_fb(t, Vector3(0, 0.5, 0.02), Vector3(1.15, 1.0, 0.04), "hc_trim")
	_tint(Color.WHITE)
	_fb(t, Vector3(0, 0.5, 0.045), Vector3(1.0, 0.85, 0.02), "hc_glass_dark")
	_tint(trim)
	_fb(t, Vector3(0, 0.5, 0.06), Vector3(0.05, 0.85, 0.02), "hc_trim", false)
	_tint(Color.WHITE)

# --- outside -----------------------------------------------------------------------

func _front_door_extras(path_to: float) -> void:
	var fdoor: Dictionary = {}
	for o in ops:
		if o.kind == "front":
			fdoor = o
	if fdoor.is_empty():
		return
	var t: Transform3D = _op_xf(fdoor)
	var w: float = fdoor.u1 - fdoor.u0
	# Steps up to the door, canopy, lamp, house number.
	_tint(Color(0.8, 0.8, 0.78))
	_fb(t, Vector3(0, -FL * 0.5 + 0.01, 0.55), Vector3(w + 0.9, FL + 0.02, 1.1), "hc_plinth")
	_fb(t, Vector3(0, -FL * 0.5 - 0.07, 1.25), Vector3(w + 0.9, FL - 0.15, 0.3), "hc_plinth")
	_fb(t, Vector3(0, -FL * 0.5 - 0.15, 1.55), Vector3(w + 0.9, FL - 0.3, 0.3), "hc_plinth")
	_tint(trim)
	_fb(t, Vector3(0, 2.45, 0.55), Vector3(w + 0.9, 0.1, 1.1), "hc_trim")
	for sd in [-1.0, 1.0]:
		_beam(t * Vector3(sd * (w * 0.5 + 0.3), 2.0, 0.0), t * Vector3(sd * (w * 0.5 + 0.3), 2.4, 0.9), Vector2(0.05, 0.05), "hc_trim", false)
	_tint(Color(0.15, 0.15, 0.16))
	_fb(t, Vector3(w * 0.5 + 0.35, 1.8, 0.06), Vector3(0.14, 0.24, 0.12), "hc_trim", false)
	_fb(t, Vector3(-w * 0.5 - 0.35, 1.6, 0.01), Vector3(0.22, 0.16, 0.02), "hc_trim", false)
	_tint(Color.WHITE)
	# Path to the street.
	var p0: Vector3 = t * Vector3(0, 0, 1.7)
	gate_at = xf * Vector3(p0.x, 0, path_to)
	if path_to > p0.z + 0.3:
		_paving(p0.x, p0.z, path_to, 1.3)
	# Mailbox.
	_tint(door_tint.lightened(0.2))
	_box(Vector3(p0.x + 1.0, 0.55, path_to - 0.6), Vector3(0.06, 1.1, 0.06), "hc_trim")
	_box(Vector3(p0.x + 1.0, 1.15, path_to - 0.6), Vector3(0.35, 0.3, 0.2), "hc_trim")
	_tint(Color.WHITE)

func _terrace() -> void:
	var patio: Dictionary = {}
	for o in ops:
		if o.kind == "patio":
			patio = o
	if patio.is_empty():
		return
	var pu: float = (patio.u0 + patio.u1) * 0.5
	var tw: float = clampf(rng.randf_range(4.0, 5.5), 3.0, W)
	var tx: float = clampf(pu, -W * 0.5 + tw * 0.5, W * 0.5 - tw * 0.5)
	var td: float = rng.randf_range(3.0, 3.8)
	var ty: float = FL - 0.17
	var zb: float = -D * 0.5
	_box(Vector3(tx, ty * 0.5, zb - td * 0.5), Vector3(tw, ty, td), "hc_terrace")
	# Garden table, chairs and a parasol.
	var off: float = 1.6 if pu < tx else -1.6
	var c := Vector3(clampf(pu + off, tx - tw * 0.5 + 1.0, tx + tw * 0.5 - 1.0), ty, zb - td * 0.55)
	if absf(c.x - pu) < 1.4:
		c.z = zb - td + 1.0
	var tt := Transform3D(Basis(), c)
	_tint(Color(0.92, 0.92, 0.9))
	_cyl(tt, Vector3(0, 0, 0), Vector3(0, 0.72, 0), 0.05, "hc_trim", 8)
	_cyl(tt, Vector3(0, 0.7, 0), Vector3(0, 0.74, 0), 0.5, "hc_trim", 16)
	for i in range(4):
		var a: float = i * PI * 0.5 + 0.4
		_chair(tt * Transform3D(Basis(Vector3.UP, a + PI), Vector3(sin(a), 0, cos(a)) * 0.8), Color(0.9, 0.9, 0.88), "hc_trim")
	_tint(Color(0.6, 0.6, 0.6))
	_cyl(tt, Vector3(0, 0.74, 0), Vector3(0, 2.3, 0), 0.025, "hc_trim", 6)
	_tint([Color(0.85, 0.82, 0.72), Color(0.7, 0.2, 0.18), Color(0.25, 0.4, 0.6), Color(0.3, 0.5, 0.35)][rng.randi() % 4])
	_cone(tt, Vector3(0, 1.95, 0), Vector3(0, 2.4, 0), 1.3, 0.05, "hc_trim", 8)
	_tint(Color.WHITE)

func _garage() -> void:
	if garage == "none":
		return
	var gw: float = 3.3
	var gd: float = 6.4
	var gh: float = 2.8
	var x: float = gside * (W * 0.5 + gw * 0.5)
	var z: float = D * 0.5 + 0.3 - gd * 0.5
	if garage == "garage":
		var brick: bool = not plaster or brick_ground
		_tint(Color.WHITE if brick else facade_tint)
		_box(Vector3(x, gh * 0.5, z), Vector3(gw, gh, gd), "hc_brick" if brick else "hc_plaster")
		_tint(trim)
		_box(Vector3(x, gh + 0.1, z), Vector3(gw + 0.2, 0.2, gd + 0.2), "hc_trim")
		# Sectional door with its grooves.
		_tint(door_tint if rng.randf() < 0.5 else Color(0.85, 0.85, 0.84))
		_box(Vector3(x, 1.05, z + gd * 0.5 + 0.02), Vector3(2.5, 2.1, 0.04), "hc_trim")
		_tint(Color(0.4, 0.4, 0.4))
		for k in range(1, 4):
			_box(Vector3(x, k * 0.525, z + gd * 0.5 + 0.045), Vector3(2.5, 0.02, 0.01), "hc_trim", false)
		_tint(Color.WHITE)
	else:
		_tint(trim)
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				_box(Vector3(x + sx * (gw * 0.5 - 0.1), 1.25, z + sz * (gd * 0.5 - 0.15)), Vector3(0.12, 2.5, 0.12), "hc_trim")
		_box(Vector3(x, 2.6, z), Vector3(gw + 0.2, 0.2, gd + 0.2), "hc_trim")
		_tint(Color.WHITE)
		var paint: String = Vehicles.random_paint(rng)
		var fwd: Vector3 = xf.basis * Vector3(0, 0, 1)
		Vehicles.car(geo, xf * Vector3(x, 0.0, z), atan2(fwd.x, fwd.z), paint, ["sedan", "hatch", "suv"][rng.randi() % 3])
	# Driveway out to the street (on a plot: to its street edge).
	var drive_end: float = maxf(D * 0.5 + 5.3, path_end)
	_paving(x, D * 0.5 + 0.3, drive_end, gw)
	drive_at = xf * Vector3(x, 0, drive_end)

# --- inside ------------------------------------------------------------------------

func _floors() -> void:
	var wi: Rect2 = Rect2(X0, Z0, X1 - X0, Z1 - Z0)
	_ao(0.0, 2.2)
	_box(Vector3(0, (FL - 0.02) * 0.5, 0), Vector3(X1 - X0, FL - 0.02, Z1 - Z0), "hcd_concrete")
	for s in range(1, storeys + 1):
		var y0: float = FL + (s - 1) * H + CH
		var y1: float = FL + s * H - 0.02 if s < storeys else wall_top
		var pieces: Array = [wi]
		if s < storeys and hole.has_area():
			pieces = [Rect2(X0, Z0, hole.position.x - X0, Z1 - Z0), Rect2(hole.end.x, Z0, X1 - hole.end.x, Z1 - Z0),
				Rect2(hole.position.x, Z0, hole.size.x, hole.position.y - Z0)]
		# (The slab's underside sits 1 cm above the rooms' lit ceilings.)
		_ao(-10.0, 1.0)
		_lit(_hall_room(0))
		for q: Rect2 in pieces:
			_box(Vector3(q.get_center().x, (y0 + 0.01 + y1) * 0.5, q.get_center().y), Vector3(q.size.x, y1 - y0 - 0.01, q.size.y), "hcd_ceiling")
		_lit({})
	for rm: Dictionary in rooms:
		var r: Rect2 = rm.r
		_lit(rm)
		var pieces: Array = [r]
		var stairwell: bool = rm.kind == "hall" and hole.has_area()
		if stairwell:
			pieces = [Rect2(hole.end.x, r.position.y, r.end.x - hole.end.x, r.size.y),
				Rect2(r.position.x, r.position.y, hole.size.x, hole.position.y - r.position.y)]
		_tint(rm.floor_tint)
		for q: Rect2 in (pieces if rm.s == 1 and stairwell else [r]):
			_hface(q, rm.fy, 1.0, rm.floor)
		_tint(Color(0.98, 0.98, 0.96))
		for q: Rect2 in (pieces if rm.s == 0 and stairwell else [r]):
			_hface(q, rm.fy + CH, -1.0, "hcd_ceiling")
		_tint(Color.WHITE)
		_pendant(rm)
		_lit({})
	_ao(0.0, 2.2)

func _stairs() -> void:
	if not hole.has_area():
		return
	var rise: float = H / STEPS
	_lit(_hall_room(0))
	_tint(Color(0.95, 0.9, 0.85))
	for i in range(STEPS):
		var top: float = FL + (i + 1) * rise
		var za: float = Z1 - i * TREAD
		_box(Vector3(hole.position.x + 0.5, (FL + top) * 0.5, za - TREAD * 0.5), Vector3(1.0, top - FL, TREAD), "hcd_wood")
	_tint(Color.WHITE)
	var rx: float = hole.end.x - 0.03
	_tint(Color(0.3, 0.3, 0.32))
	_beam(Vector3(rx, FL + rise + 0.9, Z1 - TREAD * 0.5), Vector3(rx, FL + H + 0.9, z_top), Vector2(0.05, 0.05), "hcd_steel")
	_box(Vector3(rx, FL + rise + 0.45, Z1 - TREAD * 0.5), Vector3(0.05, 0.9, 0.05), "hcd_steel")
	# Upper floor: railing round the open side of the stairwell.
	var fy: float = FL + H
	var z: float = z_top + 0.03
	while z < Z1:
		_box(Vector3(rx + 0.02, fy + 0.47, z), Vector3(0.04, 0.94, 0.04), "hcd_steel")
		z += 0.12
	_box(Vector3(rx + 0.02, fy + 0.96, (z_top + Z1) * 0.5), Vector3(0.06, 0.05, Z1 - z_top), "hcd_steel")
	_lit({})
	_tint(Color.WHITE)

func _inner_door(o: Dictionary) -> void:
	var t: Transform3D = _op_xf(o)
	var w: float = o.u1 - o.u0
	var h: float = o.v1 - o.v0
	_lit(o.into)
	_tint(Color(0.97, 0.97, 0.96))
	# Casings both sides and the threshold.
	for z in [SK + 0.01, -P - SK - 0.01]:
		_fb(t, Vector3(-w * 0.5 - 0.035, h * 0.5, z), Vector3(0.07, h, 0.02), "hcd_paint_furn", false)
		_fb(t, Vector3(w * 0.5 + 0.035, h * 0.5, z), Vector3(0.07, h, 0.02), "hcd_paint_furn", false)
		_fb(t, Vector3(0, h + 0.035, z), Vector3(w + 0.14, 0.07, 0.02), "hcd_paint_furn", false)
	_tint(Color(0.85, 0.75, 0.6))
	_fb(t, Vector3(0, 0.01, -P * 0.5), Vector3(w, 0.02, P), "hcd_wood")
	if o.kind == "door":
		var ang: float = deg_to_rad(rng.randf_range(75.0, 100.0))
		var lt: Transform3D = t * Transform3D(Basis(Vector3.UP, -ang), Vector3(-w * 0.5 + 0.02, 0.02, 0.025))
		var lw: float = w - 0.04
		_tint(Color(0.97, 0.97, 0.96) if rng.randf() < 0.7 else Color(0.85, 0.72, 0.55))
		_fb(lt, Vector3(lw * 0.5, (h - 0.04) * 0.5, 0), Vector3(lw, h - 0.04, 0.04), "hcd_paint_furn")
		_tint(Color(0.75, 0.75, 0.78))
		for sd in [-1.0, 1.0]:
			_fb(lt, Vector3(lw - 0.12, 1.02, sd * 0.04), Vector3(0.12, 0.02, 0.03), "hcd_steel", false)
	_tint(Color.WHITE)
	_lit({})

func _pendant(rm: Dictionary) -> void:
	var c: Vector2 = rm.r.get_center()
	var top: float = rm.fy + CH
	_tint(Color(0.2, 0.2, 0.2))
	_cyl(Transform3D(), Vector3(c.x, top - 0.6, c.y), Vector3(c.x, top, c.y), 0.008, "hcd_black", 4, false)
	_tint([Color(0.95, 0.95, 0.92), Color(0.2, 0.22, 0.24), Color(0.85, 0.7, 0.4)][rng.randi() % 3])
	_cone(Transform3D(), Vector3(c.x, top - 0.82, c.y), Vector3(c.x, top - 0.6, c.y), 0.26, 0.06, "hcd_paint_furn", 12)
	_tint(Color.WHITE)

# --- interior light ---------------------------------------------------------------------
# Baked per vertex while a room's surfaces and furniture are drawn
# (Geo.light_fn), so it costs nothing per frame:
#  - a soft indoor base, stronger the more window a room has;
#  - daylight from each of the room's windows and glass doors, as an
#    area light: bright beside the glass, fading into the room;
#  - sun patches: where a ray toward the sun leaves through a window
#    opening (tested at both wall faces, so reveals narrow it);
#  - the ceiling lamp, warm, close round it;
#  - darkening into corners and room edges, and under furniture.
# Big surfaces are split into ~0.4 m cells (Geo.quad_grid) so the light
# can change across them.

const DAY := Color(0.95, 0.98, 1.04)
const SUN := Color(1.0, 0.93, 0.8)
const LAMP := Color(1.0, 0.8, 0.55)
var _inv: Transform3D
var _sun_l: Vector3

func _prep_light() -> void:
	_inv = xf.affine_inverse()
	_sun_l = (_inv.basis * -geo.sun_dir).normalized()
	for rm: Dictionary in rooms:
		rm.wins = []
		var glass: float = 0.0
		for o in ops:
			if not o.ext or o.room != rm:
				continue
			var t: Transform3D = _op_xf(o)
			var w: float = o.u1 - o.u0
			var h: float = o.v1 - o.v0
			var weight: float = 0.25 if o.kind == "front" and not o.open else 1.0
			var inward: Vector3 = -t.basis.z
			var c: Vector3 = t.origin + inward * T + Vector3(0, h * 0.5, 0)
			rm.wins.append([c, inward, w * h * weight, o.axis, o.c - o.out * T * 0.5, o.c + o.out * T * 0.5, o.u0, o.u1, o.v0, o.v1])
			glass += w * h * weight
		rm.base = 0.36 + clampf(glass / maxf(rm.r.get_area(), 1.0), 0.0, 0.25) * 0.8

func _lit(rm: Dictionary) -> void:
	geo.light_fn = Callable() if rm.is_empty() or OS.has_environment("SH_FLATLIGHT") else _room_light.bind(rm)

func _hall_room(s: int) -> Dictionary:
	for rm: Dictionary in rooms:
		if rm.kind == "hall" and rm.s == s:
			return rm
	return {}

func _room_beside(s: int, axis: String, c: float) -> Dictionary:
	for rm: Dictionary in rooms:
		if rm.s != s:
			continue
		var r: Rect2 = rm.r
		if axis == "x" and absf(r.position.y - (c + P * 0.5)) < 0.01:
			return rm
		if axis == "z" and absf(r.position.x - (c + P * 0.5)) < 0.01:
			return rm
	return _hall_room(s)

static func _edge(d: float) -> float:
	return lerpf(0.6, 1.0, smoothstep(0.0, 0.7, d))

func _room_light(n_w: Vector3, p_w: Vector3, rm: Dictionary) -> Color:
	var p: Vector3 = _inv * p_w
	var n: Vector3 = (_inv.basis * n_w).normalized()
	var r: Rect2 = rm.r
	var fy: float = rm.fy
	# Corners and edges: distance to the room's walls, floor and ceiling,
	# along the axes the surface does not face.
	var dx: float = minf(p.x - r.position.x, r.end.x - p.x)
	var dz: float = minf(p.z - r.position.y, r.end.y - p.z)
	var dy: float = minf(p.y - fy, fy + CH - p.y)
	var ao: float = lerpf(1.0, _edge(dx), 1.0 - absf(n.x)) * lerpf(1.0, _edge(dz), 1.0 - absf(n.z)) * lerpf(1.0, _edge(dy), 1.0 - absf(n.y))
	var day: float = 0.0
	var sun: float = 0.0
	var ns: float = n.dot(_sun_l)
	for w: Array in rm.wins:
		var d: Vector3 = (w[0] as Vector3) - p
		var dist2: float = d.length_squared()
		var l: Vector3 = d / sqrt(maxf(dist2, 1e-6))
		day += w[2] * maxf(n.dot(l), 0.0) * maxf((w[1] as Vector3).dot(-l), 0.0) / (dist2 + w[2] * 0.4)
		if ns > 0.0 and sun == 0.0 and _through(p, w):
			sun = ns
	var lamp_p := Vector3(r.get_center().x, fy + CH - 0.75, r.get_center().y)
	var ld: Vector3 = lamp_p - p
	var lamp: float = maxf(n.dot(ld.normalized()), 0.0) * 0.22 / (1.0 + 0.5 * ld.length_squared())
	var c: Color = DAY * (rm.base + 0.42 * day) + SUN * (0.6 * sun) + LAMP * lamp
	c *= ao
	return Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0))

## Does a ray from p toward the sun leave through opening w?
func _through(p: Vector3, w: Array) -> bool:
	for plane: float in [w[4], w[5]]:
		var along: float = _sun_l.z if w[3] == "x" else _sun_l.x
		if absf(along) < 1e-4:
			return false
		var k: float = (plane - (p.z if w[3] == "x" else p.x)) / along
		if k <= 0.0:
			return false
		var q: Vector3 = p + _sun_l * k
		var u: float = q.x if w[3] == "x" else q.z
		if u < w[6] or u > w[7] or q.y < w[8] or q.y > w[9]:
			return false
	return true

## A lit wall face (local): along axis at plane coordinate pc, facing sign.
func _vface(axis: String, pc: float, sign: float, u0: float, u1: float, v0: float, v1: float, mat: String) -> void:
	var o: Vector3
	var u: Vector3
	var n: Vector3
	if axis == "x":
		o = Vector3(u0, v0, pc)
		u = Vector3(u1 - u0, 0, 0)
		n = Vector3(0, 0, sign)
	else:
		o = Vector3(pc, v0, u0)
		u = Vector3(0, 0, u1 - u0)
		n = Vector3(sign, 0, 0)
	geo.quad_grid(xf * o, xf.basis * u, xf.basis * Vector3(0, v1 - v0, 0), (xf.basis * n).normalized(), mat, _cell(0.5))

## A lit floor (up = 1) or ceiling (up = -1) over rect r (local) at height y.
func _hface(r: Rect2, y: float, up: float, mat: String) -> void:
	geo.quad_grid(xf * Vector3(r.position.x, y, r.position.y), xf.basis * Vector3(r.size.x, 0, 0), xf.basis * Vector3(0, 0, r.size.y), (xf.basis * Vector3(0, up, 0)).normalized(), mat, _cell(0.4 if up > 0.0 else 0.8))

## Light cell size (floors fine for the sun patches, ceilings coarse).
func _cell(c: float) -> float:
	return 100.0 if OS.has_environment("SH_FLATLIGHT") else c

# --- furniture placement ------------------------------------------------------------

## Frame on a room's wall: origin on the wall surface at floor level in
## the middle of that side, +z into the room, x along the wall.
func _side(rm: Dictionary, side: String) -> Array:
	var r: Rect2 = rm.r
	var fy: float = rm.fy
	var c: Vector2 = r.get_center()
	match side:
		"n":
			return [Transform3D(Basis(), Vector3(c.x, fy, r.position.y + SK)), r.size.x]
		"s":
			return [Transform3D(Basis(Vector3.UP, PI), Vector3(c.x, fy, r.end.y - SK)), r.size.x]
		"w":
			return [Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(r.position.x + SK, fy, c.y)), r.size.y]
	return [Transform3D(Basis(Vector3.UP, -PI * 0.5), Vector3(r.end.x - SK, fy, c.y)), r.size.y]

func _foot(t: Transform3D, w: float, d: float) -> Rect2:
	var a: Vector3 = t * Vector3(-w * 0.5, 0, 0)
	var r := Rect2(Vector2(a.x, a.z), Vector2.ZERO)
	for q: Vector3 in [Vector3(w * 0.5, 0, 0), Vector3(-w * 0.5, 0, d), Vector3(w * 0.5, 0, d)]:
		var p: Vector3 = t * q
		r = r.expand(Vector2(p.x, p.z))
	return r

## Free spot for a w x d piece against a side of the room (pref: -1..1
## along the wall). Returns its frame or null; the spot is then taken.
func _spot(rm: Dictionary, sides: Array, w: float, d: float, tall: bool, pref: float = 0.0) -> Variant:
	for side: String in sides:
		var f: Array = _side(rm, side)
		var t: Transform3D = f[0]
		var half: float = f[1] * 0.5 - w * 0.5 - 0.04
		if half < 0.0:
			continue
		var blocked: Array = []
		for o: Array in rm.ops:
			if o[0] != side or (not tall and not o[3]):
				continue
			var a: float = _u(t, side, o[1])
			var b: float = _u(t, side, o[2])
			blocked.append([minf(a, b) - 0.06, maxf(a, b) + 0.06])
		var best: Variant = null
		var best_d: float = INF
		var u: float = -half
		while u <= half + 0.001:
			var ok: bool = true
			for bl: Array in blocked:
				if u + w * 0.5 > bl[0] and u - w * 0.5 < bl[1]:
					ok = false
					break
			if ok:
				var ft: Transform3D = t * Transform3D(Basis(), Vector3(u, 0, 0))
				var fr: Rect2 = _foot(ft, w, d).grow(-0.01)
				for k: Rect2 in rm.used:
					if fr.intersects(k):
						ok = false
						break
				if ok and absf(u - pref * half) < best_d:
					best = ft
					best_d = absf(u - pref * half)
			u += 0.05
		if best != null:
			rm.used.append(_foot(best, w, d))
			return best
	return null

func _u(t: Transform3D, side: String, c: float) -> float:
	if side in ["n", "s"]:
		return (c - t.origin.x) * t.basis.x.x
	return (c - t.origin.z) * t.basis.x.z

## A free spot in the open floor (centre c, size), taken if free.
func _take(rm: Dictionary, c: Vector2, size: Vector2) -> bool:
	var fr := Rect2(c - size * 0.5, size)
	if not rm.r.grow(-0.05).encloses(fr):
		return false
	for k: Rect2 in rm.used:
		if fr.intersects(k):
			return false
	rm.used.append(fr)
	return true

func _furnish() -> void:
	for rm: Dictionary in rooms:
		_lit(rm)
		match rm.kind:
			"living":
				_living(rm)
			"kitchen":
				_kitchen(rm)
			"hall":
				_hall(rm)
			"bath", "wc":
				_bath(rm)
			"bed":
				_bedroom(rm, true)
			"kids":
				_bedroom(rm, false)
			"study":
				_study(rm)
		_tint(Color.WHITE)
	_lit({})

func _pick(arr: Array) -> Variant:
	return arr[rng.randi() % arr.size()]

func _living(rm: Dictionary) -> void:
	var r: Rect2 = rm.r
	var sofa_col: Color = _pick(FABRICS)
	var wood: Color = Color(rng.randf_range(0.7, 1.05), rng.randf_range(0.65, 0.95), rng.randf_range(0.6, 0.85))
	# Dining table toward the kitchen end when the room is big enough.
	if r.size.x * r.size.y > 20.0:
		var dc := Vector2(lerpf(r.position.x, r.end.x, 0.22), r.get_center().y)
		if _take(rm, dc, Vector2(2.4, 2.1)):
			_dining(Transform3D(Basis(), Vector3(dc.x, rm.fy, dc.y)), wood, rng.randi_range(4, 6))
	var sofa_w: float = clampf(r.size.x * 0.35, 1.8, 2.6)
	var sofa: Variant = _spot(rm, ["n", "e", "w"], sofa_w, 0.95, false, 0.5)
	if sofa != null:
		var st: Transform3D = sofa
		_sofa(st, sofa_w, sofa_col)
		var ct: Transform3D = st * Transform3D(Basis(), Vector3(0, 0, 1.45))
		var cp: Vector3 = ct.origin
		if _take(rm, Vector2(cp.x, cp.z), Vector2(1.1, 1.1)):
			_tint(Color(0.55, 0.5, 0.45).lerp(sofa_col, 0.3))
			_fb(ct, Vector3(0, 0.008, 0), Vector3(2.0, 0.016, 1.5), "hcd_fabric", false)
			_tint(wood)
			_table(ct, Vector2(1.0, 0.6), 0.42, "hcd_wood")
		var lamp: Transform3D = st * Transform3D(Basis(), Vector3(sofa_w * 0.5 + 0.3, 0, 0.3))
		if _take(rm, Vector2(lamp.origin.x, lamp.origin.z), Vector2(0.4, 0.4)):
			_floor_lamp(lamp)
		# TV facing the sofa if the opposite wall is free.
		var opp: String = {"n": "s", "e": "w", "w": "e"}[_side_of(rm, st)]
		var tv: Variant = _spot(rm, [opp], 1.8, 0.45, true, _pref(rm, opp, st.origin, 1.8))
		if tv != null:
			_tv(tv, wood)
	var shelf: Variant = _spot(rm, ["e", "w", "s", "n"], 1.0, 0.36, true, -0.6)
	if shelf != null:
		_shelf(shelf, wood)
	for i in range(2):
		var pl: Variant = _spot(rm, ["n", "s", "e", "w"], 0.45, 0.45, false, -1.0 if i == 0 else 1.0)
		if pl != null:
			_plant(pl)

## The pref value (for _spot) that puts a w-wide piece on `side` level with point p.
func _pref(rm: Dictionary, side: String, p: Vector3, w: float) -> float:
	var f: Array = _side(rm, side)
	var t: Transform3D = f[0]
	var half: float = maxf(f[1] * 0.5 - w * 0.5 - 0.04, 0.01)
	return clampf(_u(t, side, p.x if side in ["n", "s"] else p.z) / half, -1.0, 1.0)

func _side_of(_rm: Dictionary, t: Transform3D) -> String:
	var z: Vector3 = t.basis.z
	if z.z > 0.5:
		return "n"
	if z.z < -0.5:
		return "s"
	return "w" if z.x > 0.5 else "e"

func _kitchen(rm: Dictionary) -> void:
	var front: Color = _pick(FRONTS)
	var run: Variant = null
	var run_w: float = 0.0
	for w in [3.6, 3.0, 2.4, 1.8]:
		run = _spot(rm, ["w", "e", "s", "n"], w, 0.62, false, 0.0)
		if run != null:
			run_w = w
			break
	if run != null:
		_counter(run, run_w, front, rm)
	var fr: Variant = _spot(rm, ["n", "s", "w", "e"], 0.62, 0.66, true, 1.0)
	if fr != null:
		var t: Transform3D = fr
		_tint(front)
		_fb(t, Vector3(0, 1.0, 0.33), Vector3(0.6, 2.0, 0.64), "hcd_paint_furn")
		_tint(Color(0.3, 0.3, 0.3))
		_fb(t, Vector3(0, 1.2, 0.655), Vector3(0.58, 0.01, 0.01), "hcd_black", false)
		_fb(t, Vector3(0.24, 1.45, 0.67), Vector3(0.02, 0.4, 0.03), "hcd_steel", false)
	var c: Vector2 = rm.r.get_center()
	if rm.r.get_area() > 10.0 and _take(rm, c, Vector2(1.6, 1.5)):
		var tt := Transform3D(Basis(), Vector3(c.x, rm.fy, c.y))
		_tint(Color(0.95, 0.94, 0.9))
		_table(tt, Vector2(0.9, 0.7), 0.75, "hcd_paint_furn")
		for sd in [-1.0, 1.0]:
			_chair(tt * Transform3D(Basis(Vector3.UP, PI if sd > 0 else 0.0), Vector3(0, 0, sd * 0.55)), Color(0.8, 0.7, 0.55), "hcd_wood")

func _hall(rm: Dictionary) -> void:
	var c: Variant = _spot(rm, ["w", "e", "n", "s"], 1.0, 0.35, false, 0.0)
	if c != null:
		var t: Transform3D = c
		_tint(Color(0.95, 0.95, 0.93))
		_fb(t, Vector3(0, 0.45, 0.175), Vector3(1.0, 0.9, 0.35), "hcd_paint_furn")
		_tint(Color(0.85, 0.92, 0.95))
		_fb(t, Vector3(0, 1.5, 0.02), Vector3(0.6, 0.9, 0.02), "hcd_steel", false)
	var hook: Variant = _spot(rm, ["e", "w", "n", "s"], 0.9, 0.3, true, 0.5)
	if hook != null:
		var t: Transform3D = hook
		_tint(Color(0.6, 0.45, 0.3))
		_fb(t, Vector3(0, 1.7, 0.03), Vector3(0.9, 0.12, 0.04), "hcd_wood", false)
		for k in range(4):
			_tint(_pick(FABRICS))
			_fb(t, Vector3(-0.3 + k * 0.2, 1.3, 0.12), Vector3(0.16, 0.7, 0.14), "hcd_fabric", false)
	var pl: Variant = _spot(rm, ["n", "s", "e", "w"], 0.45, 0.45, false, -1.0)
	if pl != null:
		_plant(pl)

func _bath(rm: Dictionary) -> void:
	var white := Color(0.97, 0.97, 0.97)
	if rm.kind == "bath":
		var tub: Variant = _spot(rm, ["n", "s", "w", "e"], 1.7, 0.75, false, -1.0)
		if tub != null:
			var t: Transform3D = tub
			_tint(white)
			_fb(t, Vector3(0, 0.27, 0.375), Vector3(1.7, 0.54, 0.75), "hcd_paint_furn")
			_tint(Color(0.55, 0.7, 0.8))
			_fb(t, Vector3(0, 0.5, 0.375), Vector3(1.5, 0.05, 0.55), "hcd_paint_furn", false)
			_tint(Color(0.8, 0.8, 0.82))
			_cyl(t, Vector3(-0.7, 0.55, 0.05), Vector3(-0.7, 0.7, 0.05), 0.02, "hcd_steel", 6, false)
		var sh: Variant = _spot(rm, ["e", "w", "s", "n"], 0.9, 0.9, true, 1.0)
		if sh != null:
			var t: Transform3D = sh
			_tint(white)
			_fb(t, Vector3(0, 0.04, 0.45), Vector3(0.9, 0.08, 0.9), "hcd_paint_furn")
			_tint(Color.WHITE)
			_fb(t, Vector3(0.44, 1.05, 0.45), Vector3(0.012, 1.9, 0.9), "hc_glass")
			_fb(t, Vector3(0, 1.05, 0.895), Vector3(0.9, 1.9, 0.012), "hc_glass")
			_tint(Color(0.8, 0.8, 0.82))
			_cyl(t, Vector3(0, 1.9, 0.05), Vector3(0, 1.9, 0.25), 0.03, "hcd_steel", 6, false)
	# The toilet itself is ToiletCreator's (sometimes something swims in
	# it). Its own rng, so the rest of the house keeps its draws; the
	# frame is un-mirrored so the flush lever stays on the left.
	var wc: Variant = _spot(rm, ["n", "s", "e", "w"], 1.0, 0.75, false, 0.6)
	if wc != null:
		var t: Transform3D = wc
		var trng := RandomNumberGenerator.new()
		trng.seed = rng.randi()
		var frame: Transform3D = xf * t
		frame.basis = frame.basis * Basis.from_scale(Vector3(signf(xf.basis.determinant()), 1, 1))
		var info: Dictionary = ToiletCreator.build(geo, frame, trng)
		toilets.append(info.floater)
		# A look into the bowl, from standing height in front of it.
		views.append(["toilet_%s_%s" % [rm.kind, info.floater], frame * Vector3(0, 1.2, 0.95), frame * Vector3(0, 0.3, 0.42)])
	var bs: Variant = _spot(rm, ["n", "s", "e", "w"], 0.7, 0.48, false, -0.3)
	if bs != null:
		var t: Transform3D = bs
		_tint(_pick(FRONTS))
		_fb(t, Vector3(0, 0.55, 0.24), Vector3(0.7, 0.4, 0.46), "hcd_paint_furn")
		_tint(white)
		_fb(t, Vector3(0, 0.8, 0.25), Vector3(0.62, 0.1, 0.46), "hcd_paint_furn")
		_tint(Color(0.85, 0.92, 0.95))
		_fb(t, Vector3(0, 1.5, 0.015), Vector3(0.6, 0.75, 0.02), "hcd_steel", false)

func _bedroom(rm: Dictionary, double: bool) -> void:
	var bw: float = 1.8 if double else 1.0
	var total: float = bw + (0.95 if double else 0.5)
	var bed: Variant = _spot(rm, ["n", "w", "e", "s"], total, 2.15, false, 0.0)
	if bed != null:
		var t: Transform3D = bed
		var wood: Color = Color(rng.randf_range(0.7, 1.05), rng.randf_range(0.65, 0.95), rng.randf_range(0.6, 0.85))
		var bx: float = 0.0 if double else -0.25
		_tint(wood)
		_fb(t, Vector3(bx, 0.17, 1.05), Vector3(bw + 0.08, 0.3, 2.1), "hcd_wood")
		_fb(t, Vector3(bx, 0.5, 0.04), Vector3(bw + 0.08, 0.95, 0.06), "hcd_wood")
		_tint(Color(0.96, 0.96, 0.95))
		_fb(t, Vector3(bx, 0.4, 1.06), Vector3(bw - 0.04, 0.18, 2.0), "hcd_fabric")
		_tint(_pick(FABRICS).lightened(0.25))
		_fb(t, Vector3(bx, 0.52, 1.35), Vector3(bw, 0.1, 1.45), "hcd_fabric", false)
		_tint(Color(0.97, 0.97, 0.97))
		for k in range(2 if double else 1):
			var px: float = bx + (0.0 if not double else (k - 0.5) * 0.85)
			_fb(t, Vector3(px, 0.56, 0.3), Vector3(0.65 if double else 0.7, 0.13, 0.4), "hcd_fabric", false)
		_tint(wood)
		for sd in ([-1.0, 1.0] if double else [1.0]):
			var nx: float = bx + sd * (bw * 0.5 + 0.27)
			_fb(t, Vector3(nx, 0.25, 0.22), Vector3(0.42, 0.5, 0.4), "hcd_wood")
			_tint(Color(0.95, 0.9, 0.75))
			_cone(t, Vector3(nx, 0.62, 0.2), Vector3(nx, 0.8, 0.2), 0.12, 0.08, "hcd_paint_furn", 8)
			_cyl(t, Vector3(nx, 0.5, 0.2), Vector3(nx, 0.62, 0.2), 0.02, "hcd_black", 6, false)
			_tint(wood)
		var rt: Transform3D = t * Transform3D(Basis(), Vector3(bx, 0, 2.5))
		_tint(_pick(FABRICS).lightened(0.15))
		_fb(rt, Vector3(0, 0.008, 0), Vector3(bw + 0.6, 0.016, 1.0), "hcd_fabric", false)
	var ww: float = 2.0 if double else 1.2
	var wr: Variant = _spot(rm, ["e", "w", "s", "n"], ww, 0.6, true, 0.0)
	if wr == null:
		ww = 1.0
		wr = _spot(rm, ["e", "w", "s", "n"], ww, 0.6, true, 0.0)
	if wr != null:
		var t: Transform3D = wr
		var col: Color = _pick(FRONTS)
		_tint(col)
		_fb(t, Vector3(0, 1.08, 0.3), Vector3(ww, 2.16, 0.6), "hcd_paint_furn")
		_tint(col.darkened(0.3))
		var n: int = maxi(2, int(ww / 0.5))
		for k in range(1, n):
			_fb(t, Vector3(-ww * 0.5 + k * ww / n, 1.08, 0.605), Vector3(0.01, 2.1, 0.01), "hcd_paint_furn", false)
		_tint(Color(0.8, 0.8, 0.82))
		for k in range(n):
			_fb(t, Vector3(-ww * 0.5 + (k + 0.5) * ww / n + 0.18 * (1 if k % 2 == 0 else -1), 1.1, 0.62), Vector3(0.02, 0.3, 0.02), "hcd_steel", false)
	if not double:
		var dk: Variant = _spot(rm, ["n", "s", "e", "w"], 1.2, 1.1, false, 0.5)
		if dk != null:
			_desk(dk)
		var toys: Variant = _spot(rm, ["s", "e", "w", "n"], 0.8, 0.4, true, -0.5)
		if toys != null:
			_shelf(toys, Color(0.95, 0.95, 0.95), 0.8)

func _study(rm: Dictionary) -> void:
	var dk: Variant = _spot(rm, ["n", "s", "e", "w"], 1.4, 1.1, false, 0.0)
	if dk != null:
		_desk(dk)
	for i in range(2):
		var sh: Variant = _spot(rm, ["e", "w", "s", "n"], 0.9, 0.36, true, -0.5)
		if sh != null:
			_shelf(sh, Color(0.9, 0.85, 0.75))
	var sofa: Variant = _spot(rm, ["s", "n", "e", "w"], 1.6, 0.9, false, 0.0)
	if sofa != null:
		_sofa(sofa, 1.6, _pick(FABRICS))
	var pl: Variant = _spot(rm, ["n", "s", "e", "w"], 0.45, 0.45, false, 1.0)
	if pl != null:
		_plant(pl)

# --- furniture pieces (frame: origin at the wall, +z into the room) -------------------

func _table(t: Transform3D, top: Vector2, h: float, mat: String) -> void:
	_fb(t, Vector3(0, h - 0.02, 0), Vector3(top.x, 0.04, top.y), mat)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_fb(t, Vector3(sx * (top.x * 0.5 - 0.05), (h - 0.04) * 0.5, sz * (top.y * 0.5 - 0.05)), Vector3(0.05, h - 0.04, 0.05), mat)

## Chair at t, its back toward -z (sitter faces +z).
func _chair(t: Transform3D, col: Color, mat: String) -> void:
	_tint(col)
	_fb(t, Vector3(0, 0.45, 0), Vector3(0.44, 0.04, 0.42), mat)
	_fb(t, Vector3(0, 0.7, -0.2), Vector3(0.44, 0.48, 0.03), mat)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			_fb(t, Vector3(sx * 0.19, 0.22, sz * 0.18), Vector3(0.035, 0.44, 0.035), mat, false)

func _dining(t: Transform3D, wood: Color, chairs: int) -> void:
	var L: float = 1.6 if chairs > 4 else 1.3
	_tint(wood)
	_table(t, Vector2(L, 0.9), 0.75, "hcd_wood")
	var ccol: Color = wood if rng.randf() < 0.5 else _pick(FRONTS)
	var per: int = 3 if chairs > 4 else 2
	for sd in [-1.0, 1.0]:
		for k in range(per):
			var x: float = (k - (per - 1) * 0.5) * (L / per)
			_chair(t * Transform3D(Basis(Vector3.UP, 0.0 if sd < 0 else PI), Vector3(x, 0, sd * 0.62)), ccol, "hcd_wood")
	_tint(Color.WHITE)

func _sofa(t: Transform3D, w: float, col: Color) -> void:
	_tint(col)
	_fb(t, Vector3(0, 0.22, 0.48), Vector3(w, 0.44, 0.9), "hcd_fabric")
	_fb(t, Vector3(0, 0.6, 0.12), Vector3(w, 0.5, 0.22), "hcd_fabric")
	for sd in [-1.0, 1.0]:
		_fb(t, Vector3(sd * (w * 0.5 - 0.1), 0.55, 0.5), Vector3(0.2, 0.25, 0.86), "hcd_fabric")
	_tint(col.lightened(0.12))
	var n: int = 2 if w < 2.2 else 3
	var cw: float = (w - 0.4) / n
	for k in range(n):
		_fb(t, Vector3(-w * 0.5 + 0.2 + cw * (k + 0.5), 0.5, 0.52), Vector3(cw - 0.03, 0.12, 0.7), "hcd_fabric", false)
		_fb(t, Vector3(-w * 0.5 + 0.2 + cw * (k + 0.5), 0.75, 0.3), Vector3(cw - 0.06, 0.4, 0.12), "hcd_fabric", false)
	_tint(Color.WHITE)

func _tv(t: Transform3D, wood: Color) -> void:
	_tint(wood)
	_fb(t, Vector3(0, 0.22, 0.22), Vector3(1.8, 0.44, 0.44), "hcd_wood")
	_tint(Color.WHITE)
	_fb(t, Vector3(0, 0.47, 0.2), Vector3(0.3, 0.06, 0.18), "hcd_black")
	_fb(t, Vector3(0, 0.88, 0.2), Vector3(1.3, 0.76, 0.05), "hcd_black")

func _shelf(t: Transform3D, wood: Color, w: float = 1.0) -> void:
	var h: float = 2.0 if w >= 1.0 else 1.2
	_tint(wood)
	for sd in [-1.0, 1.0]:
		_fb(t, Vector3(sd * (w * 0.5 - 0.015), h * 0.5, 0.18), Vector3(0.03, h, 0.36), "hcd_wood")
	_fb(t, Vector3(0, h * 0.5, 0.01), Vector3(w, h, 0.02), "hcd_wood")
	var levels: int = int(h / 0.38)
	for k in range(levels + 1):
		_fb(t, Vector3(0, 0.02 + k * (h - 0.04) / levels, 0.18), Vector3(w - 0.06, 0.025, 0.34), "hcd_wood")
	# Books.
	for k in range(levels):
		var y: float = 0.035 + k * (h - 0.04) / levels
		var x: float = -w * 0.5 + 0.05
		while x < w * 0.5 - 0.1:
			var bw: float = rng.randf_range(0.025, 0.06)
			if rng.randf() < 0.15:
				x += 0.1
				continue
			var bh: float = rng.randf_range(0.18, 0.3)
			_tint(Color.from_hsv(rng.randf(), rng.randf_range(0.2, 0.7), rng.randf_range(0.35, 0.85)))
			_fb(t, Vector3(x + bw * 0.5, y + bh * 0.5, 0.2), Vector3(bw, bh, 0.22), "hcd_paint_furn", false)
			x += bw + 0.003
	_tint(Color.WHITE)

func _counter(t: Transform3D, w: float, front: Color, rm: Dictionary) -> void:
	_tint(front)
	_fb(t, Vector3(0, 0.47, 0.3), Vector3(w, 0.76, 0.58), "hcd_paint_furn")
	_tint(Color(0.2, 0.2, 0.2))
	_fb(t, Vector3(0, 0.05, 0.25), Vector3(w, 0.1, 0.5), "hcd_black")
	_tint(front.darkened(0.25))
	var n: int = int(w / 0.6)
	for k in range(1, n):
		_fb(t, Vector3(-w * 0.5 + k * 0.6, 0.47, 0.592), Vector3(0.008, 0.74, 0.008), "hcd_paint_furn", false)
	_tint(Color(0.75, 0.75, 0.78))
	for k in range(n):
		_fb(t, Vector3(-w * 0.5 + (k + 0.5) * 0.6, 0.78, 0.6), Vector3(0.3, 0.02, 0.02), "hcd_steel", false)
	_tint(_pick([Color(0.25, 0.25, 0.26), Color(0.85, 0.82, 0.76), Color(0.75, 0.6, 0.45)]))
	_fb(t, Vector3(0, 0.88, 0.31), Vector3(w + 0.02, 0.04, 0.62), "hcd_wood" if rng.randf() < 0.4 else "hcd_paint_furn")
	_tint(Color.WHITE)
	# Hob and sink.
	var hob_i: int = int(n / 3.0)
	var sink_i: int = mini(hob_i + 2, n - 1)
	if sink_i == hob_i:
		sink_i = maxi(hob_i - 1, 0)
	var hx: float = -w * 0.5 + (hob_i + 0.5) * 0.6
	var sx: float = -w * 0.5 + (sink_i + 0.5) * 0.6
	_fb(t, Vector3(hx, 0.905, 0.32), Vector3(0.58, 0.01, 0.5), "hcd_black", false)
	_fb(t, Vector3(sx, 0.905, 0.32), Vector3(0.5, 0.01, 0.4), "hcd_steel", false)
	_cyl(t, Vector3(sx, 0.9, 0.08), Vector3(sx, 1.15, 0.08), 0.015, "hcd_steel", 6, false)
	_fb(t, Vector3(sx, 1.15, 0.15), Vector3(0.03, 0.03, 0.16), "hcd_steel", false)
	# Wall cabinets wherever no window is behind them; a hood over the hob.
	var side: String = _side_of(rm, t)
	var blocked: Array = []
	for o: Array in rm.ops:
		if o[0] == side:
			var a: float = _u(t, side, o[1])
			var b: float = _u(t, side, o[2])
			blocked.append([minf(a, b) - 0.05, maxf(a, b) + 0.05])
	for k in range(n):
		var u0: float = -w * 0.5 + k * 0.6
		var free: bool = true
		for bl: Array in blocked:
			if u0 + 0.6 > bl[0] and u0 < bl[1]:
				free = false
		if not free:
			continue
		var uc: float = u0 + 0.3
		if absf(uc - hx) < 0.1:
			_tint(Color(0.6, 0.6, 0.62))
			_fb(t, Vector3(hx, 1.6, 0.25), Vector3(0.6, 0.12, 0.5), "hcd_steel")
			_fb(t, Vector3(hx, 1.95, 0.12), Vector3(0.25, 0.6, 0.25), "hcd_steel")
		else:
			_tint(front)
			_fb(t, Vector3(uc, 1.8, 0.18), Vector3(0.59, 0.7, 0.35), "hcd_paint_furn")
	_tint(Color.WHITE)

func _desk(t: Transform3D) -> void:
	_tint(Color(0.95, 0.95, 0.94))
	_table(t * Transform3D(Basis(), Vector3(0, 0, 0.35)), Vector2(1.2, 0.65), 0.75, "hcd_paint_furn")
	_tint(Color.WHITE)
	_fb(t, Vector3(0.1, 1.0, 0.2), Vector3(0.6, 0.38, 0.03), "hcd_black")
	_fb(t, Vector3(0.1, 0.78, 0.22), Vector3(0.2, 0.04, 0.15), "hcd_black", false)
	var ct: Transform3D = t * Transform3D(Basis(Vector3.UP, PI + rng.randf_range(-0.4, 0.4)), Vector3(0, 0, 0.95))
	_tint(Color(0.2, 0.2, 0.22))
	_cyl(ct, Vector3(0, 0.05, 0), Vector3(0, 0.45, 0), 0.03, "hcd_black", 6)
	_fb(ct, Vector3(0, 0.03, 0), Vector3(0.55, 0.04, 0.55), "hcd_black", false)
	_tint(_pick(FABRICS))
	_fb(ct, Vector3(0, 0.48, 0), Vector3(0.48, 0.08, 0.46), "hcd_fabric")
	_fb(ct, Vector3(0, 0.82, -0.22), Vector3(0.46, 0.55, 0.06), "hcd_fabric")
	_tint(Color.WHITE)

func _floor_lamp(t: Transform3D) -> void:
	_tint(Color(0.2, 0.2, 0.2))
	_cyl(t, Vector3(0, 0, 0), Vector3(0, 0.03, 0), 0.15, "hcd_black", 10)
	_cyl(t, Vector3(0, 0.03, 0), Vector3(0, 1.45, 0), 0.015, "hcd_black", 6)
	_tint(Color(0.96, 0.93, 0.82))
	_cone(t, Vector3(0, 1.4, 0), Vector3(0, 1.65, 0), 0.22, 0.16, "hcd_paint_furn", 12)
	_tint(Color.WHITE)

func _plant(t: Transform3D) -> void:
	var p := Vector3(0, 0, 0.22)
	_tint(_pick([Color(0.75, 0.42, 0.3), Color(0.92, 0.92, 0.9), Color(0.3, 0.3, 0.32)]))
	_cyl(t, p, p + Vector3(0, 0.38, 0), 0.17, "hcd_paint_furn", 10)
	_tint(Color(rng.randf_range(0.8, 1.1), rng.randf_range(0.9, 1.15), rng.randf_range(0.8, 1.0)))
	var h: float = rng.randf_range(0.6, 1.3)
	_cone(t, p + Vector3(0, 0.35, 0), p + Vector3(0, 0.35 + h, 0), 0.32, 0.05, "hcd_plant", 7)
	_cone(t, p + Vector3(0, 0.5 + h * 0.3, 0), p + Vector3(0, 0.6 + h, 0), 0.25, 0.02, "hcd_plant", 6)
	_tint(Color.WHITE)

# --- preview cameras ----------------------------------------------------------------

func _make_views() -> void:
	var toilet_views: Array = views.duplicate() # added while furnishing; they go last
	views.clear()
	var v := func(vname: String, eye: Vector3, at: Vector3) -> void:
		views.append([vname, xf * eye, xf * at])
	v.call("front", Vector3(W * 0.55, 3.2, D * 0.5 + 12.0), Vector3(0, 3.0, 0))
	v.call("back", Vector3(-W * 0.5, 3.6, -D * 0.5 - 11.0), Vector3(0, 2.6, -D * 0.5))
	v.call("aerial", Vector3(-W * 0.9, wall_top + 12.0, D * 0.5 + 12.0), Vector3(0, wall_top * 0.5, 0))
	var n_in: int = 0
	for o in ops:
		if o.ext and o.open and o.kind in ["patio", "window"]:
			var t: Transform3D = _op_xf(o)
			var h: float = o.v1 - o.v0
			n_in += 1
			v.call("way_in%d_%s" % [n_in, o.room.kind], t * Vector3(0, h * 0.45, 4.2), t * Vector3(0, h * 0.4, -3.0))
	if not interior:
		return
	var seen: Dictionary = {}
	for rm: Dictionary in rooms:
		var vname: String = rm.kind + ("_up" if rm.s > 0 and rm.kind == "hall" else "")
		if seen.has(vname):
			vname += "2"
		seen[vname] = true
		var d: Vector2 = rm.door
		var din: Vector2 = rm.door_in
		var r: Rect2 = rm.r
		var eye2: Vector2 = d + din * 0.9
		eye2 = Vector2(clampf(eye2.x, r.position.x + 0.25, r.end.x - 0.25), clampf(eye2.y, r.position.y + 0.25, r.end.y - 0.25))
		var c: Vector2 = r.get_center()
		var at2: Vector2 = c + (c - eye2) * 0.6 if (c - eye2).length() > 0.5 else eye2 + din * 3.0
		v.call(vname, Vector3(eye2.x, rm.fy + 1.6, eye2.y), Vector3(at2.x, rm.fy + 0.8, at2.y))
	views.append_array(toilet_views)
