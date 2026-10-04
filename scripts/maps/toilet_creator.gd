class_name ToiletCreator
extends RefCounted

## Creator: an American two-piece toilet - elongated bowl with the big
## water surface US bowls have, tank with lid and the flush lever on the
## front left, seat and lid (down, up, or seat left up), bolt caps,
## shut-off valve and supply hose, a paper roll on the wall (over or
## under, depending on the household). Mostly the water is just water;
## sometimes something swims in it for the player to find: a rubber
## duck, a battleship, a swan, a message in a bottle.
##
##   ToiletCreator.build(geo, t, rng, opts) -> {"floater": String, "water": Vector3}
## t: world frame - origin on the floor at the wall behind the toilet,
## +z out into the room, y up.
## opts: "floater": "random" (default: something in 1 of 5 toilets),
##       "none" or one of FLOATERS; "lid": "random"/"closed"/"open"/
##       "seat_up"; "paper": true.
##
## Sizes from US elongated two-piece toilets: rim 0.40 m high, bowl
## ~36 x 48 cm, front of the bowl ~0.72 m from the wall, tank top
## ~0.78 m; water spot ~27 x 35 cm.

## Picked at random. ("shark" - a fin - still exists, but only on request
## via opts: left out of the random draw on 2026-10-02.)
const FLOATERS := ["duck", "battleship", "swan", "bottle"]
const FLOATER_CHANCE: float = 0.2

const BZ: float = 0.5 ## bowl centre, out from the wall
const K: float = 1.3 ## bowl elongation (front-back / side-side)
const RIM: float = 0.405
const WL: float = 0.31 ## water level
## Hinges sit on the back of the rim, clear of the tank (front face at
## 0.215): a raised seat/lid stands just in front of it.
const HINGE_Z: float = 0.272
const PORCELAIN := Color(1.14, 1.14, 1.12)

var geo: Geo
var rng: RandomNumberGenerator
var t: Transform3D

static func ensure_materials(g: Geo) -> void:
	if g.has_material("tc_paint"):
		return
	g.add_material("tc_paint", Geo.flat_mat(Color.WHITE, 0.25))
	g.add_material("tc_chrome", Geo.flat_mat(Color(0.8, 0.82, 0.85), 0.2, 0.8))
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.55, 0.78, 0.9, 0.5)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	water.vertex_color_use_as_albedo = true
	g.add_material("tc_water", water)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.35, 0.65, 0.4, 0.45)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	glass.vertex_color_use_as_albedo = true
	g.add_material("tc_glass", glass)
	# Toilets stand indoors: the sun's shadow map would darken them twice
	# (HouseCreator lights its rooms itself).
	for m in ["tc_paint", "tc_chrome", "tc_water", "tc_glass"]:
		g.material(m).set_meta("no_shadow", true)
	if not g.detail_prefixes.has("tc_"):
		g.detail_prefixes.append("tc_")

static func build(g: Geo, frame: Transform3D, r: RandomNumberGenerator, opts: Dictionary = {}) -> Dictionary:
	var tc := ToiletCreator.new()
	tc.geo = g
	tc.rng = r
	tc.t = frame
	ensure_materials(g)
	return tc._build(opts)

func _build(opts: Dictionary) -> Dictionary:
	var floater: String = opts.get("floater", "random")
	if floater == "random":
		floater = FLOATERS[rng.randi() % FLOATERS.size()] if rng.randf() < FLOATER_CHANCE else "none"
	var lid: String = opts.get("lid", "random")
	if lid == "random":
		var x: float = rng.randf()
		lid = "closed" if x < 0.35 else ("seat_up" if x > 0.85 else "open")
	if floater != "none" and lid == "closed":
		lid = "open"
	var saved: Color = geo.tint
	_bowl()
	_tank()
	_seat(lid)
	_plumbing()
	if opts.get("paper", true):
		_paper()
	var wc := Vector3(rng.randf_range(-0.02, 0.02), WL, BZ + rng.randf_range(-0.03, 0.04))
	var ft: Transform3D = Transform3D(Basis(Vector3.UP, rng.randf_range(-PI, PI)), wc)
	match floater:
		"duck":
			_duck(ft)
		"battleship":
			_battleship(ft)
		"swan":
			_swan(ft)
		"shark":
			_shark(ft)
		"bottle":
			_bottle(ft)
	geo.tint = saved
	return {"floater": floater, "water": t * Vector3(0, WL, BZ), "lid": lid}

# --- helpers (toilet-local) ----------------------------------------------------------

func _box(c: Vector3, s: Vector3, col: Color, collide: bool = true, mat: String = "tc_paint") -> void:
	geo.tint = col
	geo.box_xf(t * Transform3D(Basis(), c), s, mat, collide)

func _boxt(lt: Transform3D, c: Vector3, s: Vector3, col: Color, collide: bool = false, mat: String = "tc_paint") -> void:
	geo.tint = col
	geo.box_xf(t * lt * Transform3D(Basis(), c), s, mat, collide)

func _cyl(a: Vector3, b: Vector3, r: float, col: Color, mat: String = "tc_paint", sides: int = 10, collide: bool = false) -> void:
	geo.tint = col
	geo.cylinder(t * a, t * b, r, mat, sides, collide)

func _lathe(lt: Transform3D, profile: Array, col: Color, closed: bool = false, mat: String = "tc_paint", sides: int = 24, collide: bool = false) -> void:
	geo.tint = col
	geo.lathe_xf(t * lt, profile, mat, sides, closed, collide)

## Ellipsoid: radius r scaled by s, centred at c in frame lt.
func _blob(lt: Transform3D, c: Vector3, r: float, s: Vector3, col: Color, sides: int = 12) -> void:
	var prof: Array = []
	for i in range(9):
		var a: float = PI * i / 8.0
		prof.append(Vector2(r * sin(a), -r * cos(a)))
	_lathe(lt * Transform3D(Basis.from_scale(s), c), prof, col, false, "tc_paint", sides)

# --- the toilet ------------------------------------------------------------------------

func _bowl() -> void:
	var bt := Transform3D(Basis.from_scale(Vector3(1, 1, K)), Vector3(0, 0, BZ))
	# Outside from the foot up, over the rim, down the inside to the trap.
	_lathe(bt, [Vector2(0.115, 0.0), Vector2(0.118, 0.08), Vector2(0.135, 0.2), Vector2(0.16, 0.29),
		Vector2(0.178, 0.35), Vector2(0.184, 0.39), Vector2(0.176, RIM), Vector2(0.15, RIM + 0.004),
		Vector2(0.145, 0.385), Vector2(0.14, 0.35), Vector2(0.136, WL), Vector2(0.105, 0.25),
		Vector2(0.055, 0.2), Vector2(0.0, 0.19)], PORCELAIN, false, "tc_paint", 32, true)
	# Water: the big flat spot of a US bowl.
	_lathe(bt, [Vector2(0.138, WL), Vector2(0.0, WL)], Color.WHITE, false, "tc_water", 32)
	# Body behind the bowl, carrying the tank.
	_box(Vector3(0, 0.2, 0.19), Vector3(0.24, 0.4, 0.23), PORCELAIN)
	_box(Vector3(0, 0.03, BZ - 0.02), Vector3(0.25, 0.06, 0.34), PORCELAIN)
	# Bolt caps either side of the foot.
	for sx in [-1.0, 1.0]:
		geo.tint = PORCELAIN
		geo.cone(t * Vector3(sx * 0.14, 0.0, BZ - 0.06), t * Vector3(sx * 0.14, 0.05, BZ - 0.06), 0.022, 0.012, "tc_paint", 8, false)

func _tank() -> void:
	_box(Vector3(0, 0.6, 0.11), Vector3(0.5, 0.36, 0.19), PORCELAIN)
	_box(Vector3(0, 0.795, 0.11), Vector3(0.52, 0.03, 0.21), PORCELAIN)
	_box(Vector3(0, 0.42, 0.13), Vector3(0.26, 0.04, 0.14), PORCELAIN)
	# Flush lever, front left as you face it.
	var ch := Color(1, 1, 1)
	_cyl(Vector3(-0.19, 0.71, 0.205), Vector3(-0.19, 0.71, 0.22), 0.018, ch, "tc_chrome", 12)
	_cyl(Vector3(-0.19, 0.71, 0.22), Vector3(-0.19, 0.71, 0.235), 0.007, ch, "tc_chrome", 6)
	geo.tint = ch
	geo.beam(t * Vector3(-0.19, 0.71, 0.235), t * Vector3(-0.11, 0.7, 0.24), Vector2(0.012, 0.018), "tc_chrome", false)

func _seat(lid: String) -> void:
	var seat_col: Color = PORCELAIN if rng.randf() < 0.8 else Color(0.62, 0.45, 0.3)
	# Raised: tipped back 1 degree past upright, resting against the tank.
	var seat_ang: float = deg_to_rad(-91.0) if lid == "seat_up" else 0.0
	var lid_ang: float = 0.0 if lid == "closed" else deg_to_rad(-91.0)
	var ring: Array = [Vector2(0.184, 0.0), Vector2(0.184, 0.024), Vector2(0.138, 0.024), Vector2(0.138, 0.0)]
	var disc: Array = [Vector2(0.19, 0.0), Vector2(0.19, 0.022), Vector2(0.0, 0.022), Vector2(0.0, 0.0)]
	var hinge := Vector3(0, RIM + 0.005, HINGE_Z)
	var st := Transform3D(Basis(Vector3.RIGHT, seat_ang), hinge) * Transform3D(Basis.from_scale(Vector3(1, 1, K)), Vector3(0, 0, BZ - HINGE_Z))
	_lathe(st, ring, seat_col, true, "tc_paint", 32, true)
	var lt := Transform3D(Basis(Vector3.RIGHT, lid_ang), hinge) * Transform3D(Basis(), Vector3(0, 0.025, 0)) * Transform3D(Basis.from_scale(Vector3(1, 1, K)), Vector3(0, 0, BZ - HINGE_Z))
	_lathe(lt, disc, seat_col, true, "tc_paint", 32, true)
	for sx in [-1.0, 1.0]:
		_cyl(Vector3(sx * 0.07, RIM + 0.015, HINGE_Z - 0.02), Vector3(sx * 0.07, RIM + 0.015, HINGE_Z + 0.02), 0.012, Color.WHITE, "tc_chrome", 8)

func _plumbing() -> void:
	var ch := Color.WHITE
	_cyl(Vector3(-0.17, 0.2, 0.0), Vector3(-0.17, 0.2, 0.06), 0.012, ch, "tc_chrome")
	_cyl(Vector3(-0.17, 0.2, 0.06), Vector3(-0.17, 0.2, 0.085), 0.016, ch, "tc_chrome")
	_box(Vector3(-0.17, 0.2, 0.1), Vector3(0.05, 0.03, 0.01), ch, false, "tc_chrome")
	_cyl(Vector3(-0.17, 0.2, 0.06), Vector3(-0.15, 0.42, 0.09), 0.008, Color(0.85, 0.85, 0.85), "tc_chrome", 6)

func _paper() -> void:
	var x: float = 0.48 if rng.randf() < 0.6 else -0.48
	var ch := Color.WHITE
	_box(Vector3(x, 0.72, 0.012), Vector3(0.16, 0.06, 0.024), ch, false, "tc_chrome")
	_cyl(Vector3(x - 0.07, 0.68, 0.02), Vector3(x + 0.07, 0.68, 0.02), 0.006, ch, "tc_chrome", 6)
	var roll_c := Vector3(x, 0.66, 0.07)
	_cyl(roll_c - Vector3(0.05, 0, 0), roll_c + Vector3(0.05, 0, 0), 0.055, Color(0.98, 0.98, 0.97), "tc_paint", 14)
	# The loose end: over the top (the right way) or under.
	var over: bool = rng.randf() < 0.7
	if over:
		_box(roll_c + Vector3(0, -0.04, 0.056), Vector3(0.1, 0.1, 0.002), Color(0.98, 0.98, 0.97), false)
	else:
		_box(roll_c + Vector3(0, -0.04, -0.056), Vector3(0.1, 0.1, 0.002), Color(0.98, 0.98, 0.97), false)

# --- things in the water (frame: origin at the water surface, +z ahead) ----------------

func _duck(ft: Transform3D) -> void:
	var y := Color(1.0, 0.82, 0.08)
	_blob(ft, Vector3(0, 0.012, 0), 0.045, Vector3(0.95, 0.75, 1.3), y)
	_blob(ft, Vector3(0, 0.058, 0.032), 0.03, Vector3.ONE, y)
	geo.tint = y
	geo.cone(t * ft * Vector3(0, 0.02, -0.05), t * ft * Vector3(0, 0.05, -0.068), 0.02, 0.004, "tc_paint", 8, false)
	_boxt(ft, Vector3(0, 0.054, 0.066), Vector3(0.028, 0.008, 0.024), Color(1.0, 0.45, 0.05))
	_boxt(ft, Vector3(0, 0.047, 0.062), Vector3(0.022, 0.006, 0.018), Color(0.95, 0.38, 0.04))
	for sx in [-1.0, 1.0]:
		_boxt(ft, Vector3(sx * 0.02, 0.068, 0.048), Vector3(0.006, 0.01, 0.006), Color(0.05, 0.05, 0.05))
		_blob(ft, Vector3(sx * 0.036, 0.02, -0.005), 0.025, Vector3(0.35, 0.6, 1.0), y.darkened(0.06), 8)

func _battleship(ft: Transform3D) -> void:
	var hull := Color(0.68, 0.71, 0.74)
	var deck := Color(0.55, 0.5, 0.42)
	var lo: float = -0.012
	var hi: float = 0.016
	var c: Array = []
	# Midships: a hexa narrower at the keel.
	for i in range(8):
		var w: float = 0.027 if i & 2 else 0.02
		c.append(t * ft * Vector3(w * (1.0 if i & 1 else -1.0), hi if i & 2 else lo, 0.06 if i & 4 else -0.085))
	geo.tint = hull
	geo.hexa(c, "tc_paint", false)
	# Bow: pinched to a point; stern: tapered.
	c = []
	for i in range(8):
		var tip: bool = (i & 4) != 0
		var w: float = 0.0 if tip else (0.027 if i & 2 else 0.02)
		c.append(t * ft * Vector3(w * (1.0 if i & 1 else -1.0), (hi + 0.006 if tip else hi) if i & 2 else lo, 0.125 if tip else 0.06))
	geo.hexa(c, "tc_paint", false)
	c = []
	for i in range(8):
		var end: bool = not (i & 4)
		var w: float = (0.012 if end else 0.027) if i & 2 else (0.008 if end else 0.02)
		c.append(t * ft * Vector3(w * (1.0 if i & 1 else -1.0), hi if i & 2 else lo, -0.105 if end else -0.085))
	geo.hexa(c, "tc_paint", false)
	_boxt(ft, Vector3(0, hi + 0.001, -0.01), Vector3(0.05, 0.002, 0.14), deck)
	# Superstructure, bridge, funnel, mast.
	_boxt(ft, Vector3(0, hi + 0.01, -0.005), Vector3(0.028, 0.02, 0.06), hull.lightened(0.08))
	_boxt(ft, Vector3(0, hi + 0.026, 0.012), Vector3(0.02, 0.014, 0.018), hull.lightened(0.12))
	_boxt(ft, Vector3(0, hi + 0.03, 0.022), Vector3(0.018, 0.004, 0.002), Color(0.1, 0.12, 0.15))
	geo.tint = hull.darkened(0.1)
	geo.cylinder(t * ft * Vector3(0, hi + 0.02, -0.018), t * ft * Vector3(0, hi + 0.046, -0.022), 0.007, "tc_paint", 8, false)
	geo.tint = Color(0.15, 0.15, 0.15)
	geo.cylinder(t * ft * Vector3(0, hi + 0.046, -0.022), t * ft * Vector3(0, hi + 0.049, -0.0225), 0.0072, "tc_paint", 8, false)
	geo.tint = hull.darkened(0.2)
	geo.cylinder(t * ft * Vector3(0, hi + 0.03, 0.004), t * ft * Vector3(0, hi + 0.075, 0.004), 0.0015, "tc_paint", 4, false)
	geo.beam(t * ft * Vector3(-0.012, hi + 0.065, 0.004), t * ft * Vector3(0.012, hi + 0.065, 0.004), Vector2(0.002, 0.002), "tc_paint", false)
	_boxt(ft, Vector3(0.0, hi + 0.072, -0.004), Vector3(0.001, 0.008, 0.014), Color(0.85, 0.1, 0.1))
	# Gun turrets fore and aft, barrels pointing out.
	for tz in [[0.05, 1.0], [0.032, 1.0], [-0.06, -1.0]]:
		var z: float = tz[0]
		var dir: float = tz[1]
		var y0: float = hi + (0.006 if absf(z - 0.032) < 0.001 else 0.0)
		geo.tint = hull.lightened(0.05)
		geo.cylinder(t * ft * Vector3(0, y0, z), t * ft * Vector3(0, y0 + 0.009, z), 0.011, "tc_paint", 10, false)
		geo.tint = hull.darkened(0.15)
		for sx in [-0.004, 0.004]:
			geo.cylinder(t * ft * Vector3(sx, y0 + 0.005, z + dir * 0.008), t * ft * Vector3(sx, y0 + 0.006, z + dir * 0.038), 0.0016, "tc_paint", 5, false)

func _swan(ft: Transform3D) -> void:
	var w := Color(0.97, 0.97, 0.96)
	_blob(ft, Vector3(0, 0.012, -0.005), 0.05, Vector3(0.9, 0.7, 1.45), w)
	for sx in [-1.0, 1.0]:
		_blob(ft, Vector3(sx * 0.03, 0.03, -0.02), 0.04, Vector3(0.35, 0.55, 1.2), w.darkened(0.04), 10)
	geo.tint = w
	geo.cone(t * ft * Vector3(0, 0.02, -0.06), t * ft * Vector3(0, 0.05, -0.085), 0.022, 0.003, "tc_paint", 8, false)
	# The neck: an S-curve up from the breast.
	var path: Array[Vector3] = []
	for i in range(9):
		var s: float = i / 8.0
		var p := Vector3(0, 0.02 + s * 0.11, 0.055 + sin(s * PI * 1.5) * 0.022 - s * 0.01)
		path.append(t * ft * p)
	geo.tint = w
	geo.pipe_path(path, 0.009, "tc_paint", 0.0, 8, false, false)
	var head := Vector3(0, 0.13, 0.042)
	_blob(ft, head, 0.016, Vector3(0.85, 0.9, 1.25), w, 10)
	geo.tint = Color(1.0, 0.45, 0.1)
	geo.cone(t * ft * (head + Vector3(0, -0.002, 0.012)), t * ft * (head + Vector3(0, -0.008, 0.038)), 0.007, 0.0015, "tc_paint", 6, false)
	_boxt(ft, head + Vector3(0, 0.0, 0.014), Vector3(0.016, 0.01, 0.008), Color(0.08, 0.08, 0.08))

func _shark(ft: Transform3D) -> void:
	var grey := Color(0.36, 0.42, 0.48)
	geo.tint = grey
	geo.prism(t * ft, [Vector2(0.045, 0.0), Vector2(-0.01, 0.075), Vector2(-0.028, 0.068), Vector2(-0.035, 0.0)], 0.007, "tc_paint", false)
	# A bow wave round it.
	_lathe(Transform3D(Basis.from_scale(Vector3(0.6, 1, 1.0)), ft.origin + Vector3(0, 0.001, 0)),
		[Vector2(0.062, 0.0), Vector2(0.062, 0.002), Vector2(0.052, 0.002), Vector2(0.052, 0.0)], Color(0.9, 0.95, 1.0), true, "tc_paint", 20)

func _bottle(ft: Transform3D) -> void:
	# Lying on its side, half under: the lathe's axis turned along z.
	var lt: Transform3D = ft * Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.0, -0.06))
	_lathe(lt, [Vector2(0.0, 0.0), Vector2(0.026, 0.0), Vector2(0.027, 0.075), Vector2(0.02, 0.095),
		Vector2(0.009, 0.105), Vector2(0.009, 0.125), Vector2(0.0, 0.125)], Color.WHITE, false, "tc_glass", 14)
	var a: Vector3 = t * lt * Vector3(0, 0.12, 0)
	var b: Vector3 = t * lt * Vector3(0, 0.138, 0)
	geo.tint = Color(0.62, 0.45, 0.28)
	geo.cylinder(a, b, 0.0085, "tc_paint", 8, false)
	# The rolled letter inside, tied with a red string.
	geo.tint = Color(0.93, 0.88, 0.72)
	geo.cylinder(t * lt * Vector3(0, 0.012, 0), t * lt * Vector3(0, 0.07, 0), 0.012, "tc_paint", 8, false)
	geo.tint = Color(0.75, 0.1, 0.1)
	geo.cylinder(t * lt * Vector3(0, 0.038, 0), t * lt * Vector3(0, 0.044, 0), 0.0125, "tc_paint", 8, false)
