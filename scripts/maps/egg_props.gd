class_name EggProps
extends RefCounted

## Small hand-built figures for the Easter eggs (2026-10-14, map_design.md
## "Surprises catalogue"): a tiny whoop, a 5-inch quad, a garden gnome, a
## tent, a campfire, a camp chair, goggles, a sticky note. All of them
## are tiny, non-colliding where they are under a hand's width, drawn
## through one flat material (colour by Geo.tint) and two glow ones, and
## they have no random numbers of their own: the same map seed gives the
## same egg.

static func ensure(g: Geo) -> void:
	if g.has_material("egg_flat"):
		return
	g.add_material("egg_flat", Geo.flat_mat(Color.WHITE, 0.6))
	g.add_material("egg_led", Geo.glow_mat(Color(1.0, 0.1, 0.06), 2.2))
	g.add_material("egg_fire", Geo.glow_mat(Color(1.0, 0.5, 0.1), 2.6))
	g.detail_prefixes.append("egg_")

static func _b(g: Geo, xf: Transform3D, local: Vector3, size: Vector3, col: Color, collide: bool = false, mat: String = "egg_flat") -> void:
	g.tint = col
	g.box_xf(xf * Transform3D(Basis(), local), size, mat, collide, false)
	g.tint = Color.WHITE

## An 8 cm ducted brushless whoop: four duct rings, a flight stack, a
## battery on top, a camera, and a red LED (a low-battery warning).
## xf: origin = the bottom of the ducts, y up, nose toward -z.
static func whoop(g: Geo, xf: Transform3D, led: bool = true, bright: bool = false) -> void:
	ensure(g)
	var d: float = 0.0225
	var h: float = 0.018
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * d, 0.0, sz * d)
			g.tint = Color(0.92, 0.92, 0.9) if bright else Color(0.1, 0.1, 0.11)
			g.pipe(xf * (c + Vector3(0, 0.001, 0)), xf * (c + Vector3(0, h, 0)), 0.019, 0.0035, "egg_flat", 10, false, false)
			g.tint = Color(0.75, 0.76, 0.78)
			g.box_xf(xf * Transform3D(Basis(Vector3.UP, 0.6 + sx * 0.5 + sz * 0.9), c + Vector3(0, 0.012, 0)), Vector3(0.031, 0.001, 0.004), "egg_flat", false, false)
			g.tint = Color(0.8, 0.5, 0.15)
			g.box_xf(xf * Transform3D(Basis(), c + Vector3(0, 0.0085, 0)), Vector3(0.008, 0.007, 0.008), "egg_flat", false, false)
			g.tint = Color(0.12, 0.12, 0.13)
			g.beam(xf * Vector3(0, 0.009, 0), xf * (c + Vector3(0, 0.009, 0)), Vector2(0.006, 0.003), "egg_flat", false, false)
	g.tint = Color.WHITE
	_b(g, xf, Vector3(0, 0.0105, 0), Vector3(0.024, 0.011, 0.032), Color(0.1, 0.12, 0.1))
	_b(g, xf, Vector3(0, 0.0215, 0.0), Vector3(0.022, 0.01, 0.03), Color(0.2, 0.34, 0.62))
	_b(g, xf, Vector3(0, 0.014, -0.019), Vector3(0.011, 0.009, 0.009), Color(0.05, 0.05, 0.06))
	if led:
		var ls: float = 0.01 if bright else 0.006
		_b(g, xf, Vector3(0, 0.0185, 0.0175), Vector3(ls, ls * 0.7, ls), Color.WHITE, false, "egg_led")

## A 5-inch freestyle quad lying on its battery (a lost one): X frame,
## four motors with props, battery, camera, antenna, a blinking-LED
## stand-in. xf: origin = the bottom of the battery, nose toward -z.
static func quad5(g: Geo, xf: Transform3D) -> void:
	ensure(g)
	var a: float = 0.0795
	var dark := Color(0.1, 0.1, 0.11)
	_b(g, xf, Vector3(0, 0.015, 0.0), Vector3(0.034, 0.03, 0.1), Color(0.22, 0.24, 0.3))
	_b(g, xf, Vector3(0, 0.034, 0.0), Vector3(0.036, 0.008, 0.07), dark)
	_b(g, xf, Vector3(0, 0.045, 0.0), Vector3(0.03, 0.014, 0.05), Color(0.15, 0.17, 0.16))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var c := Vector3(sx * a, 0.036, sz * a)
			g.tint = dark
			g.beam(xf * Vector3(sx * 0.012, 0.036, sz * 0.012), xf * c, Vector2(0.012, 0.004), "egg_flat", false, false)
			g.tint = Color(0.7, 0.45, 0.15)
			g.cylinder(xf * (c + Vector3(0, -0.004, 0)), xf * (c + Vector3(0, 0.02, 0)), 0.014, "egg_flat", 8, false, true, false)
			g.tint = Color(0.8, 0.8, 0.82)
			g.box_xf(xf * Transform3D(Basis(Vector3.UP, 0.5 + sx * 0.7 + sz * 0.3), c + Vector3(0, 0.024, 0)), Vector3(0.127, 0.002, 0.012), "egg_flat", false, false)
	g.tint = Color.WHITE
	_b(g, xf, Vector3(0, 0.05, -0.055), Vector3(0.028, 0.026, 0.024), dark)
	g.tint = Color(0.05, 0.1, 0.2)
	g.cylinder(xf * Vector3(0, 0.05, -0.067), xf * Vector3(0, 0.05, -0.072), 0.008, "egg_flat", 8, false, true, false)
	g.tint = Color.WHITE
	g.beam(xf * Vector3(0, 0.05, 0.03), xf * Vector3(0.02, 0.07, 0.12), Vector2(0.003, 0.003), "egg_flat", false, false)
	_b(g, xf, Vector3(0, 0.054, 0.02), Vector3(0.006, 0.004, 0.006), Color.WHITE, false, "egg_led")

## A garden gnome from primitives (not the collectible): blue coat, red
## cone hat, white beard. base = under the boots, yaw = the way he faces,
## s = scale (1.0 = 0.9 m).
static func gnome(g: Geo, base: Vector3, yaw: float, s: float = 1.0) -> void:
	ensure(g)
	var xf := Transform3D(Basis(Vector3.UP, yaw), base)
	g.tint = Color(0.35, 0.22, 0.12)
	for sx in [-1.0, 1.0]:
		g.box_xf(xf * Transform3D(Basis(), Vector3(sx * 0.07, 0.035, -0.02) * s), Vector3(0.1, 0.07, 0.17) * s, "egg_flat", true, false)
	g.tint = Color(0.15, 0.32, 0.72)
	g.cone(xf * (Vector3(0, 0.06, 0) * s), xf * (Vector3(0, 0.47, 0) * s), 0.17 * s, 0.1 * s, "egg_flat", 10, true, false)
	g.tint = Color(0.9, 0.7, 0.6)
	g.cylinder(xf * (Vector3(0, 0.46, 0) * s), xf * (Vector3(0, 0.56, 0) * s), 0.075 * s, "egg_flat", 10, true, true, false)
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.52, -0.085) * s), Vector3(0.04, 0.045, 0.04) * s, "egg_flat", false, false)
	g.tint = Color(0.97, 0.97, 0.95)
	g.cone(xf * (Vector3(0, 0.5, -0.055) * s), xf * (Vector3(0, 0.2, -0.085) * s), 0.085 * s, 0.015 * s, "egg_flat", 10, false, false)
	g.tint = Color(0.82, 0.12, 0.1)
	g.cone(xf * (Vector3(0, 0.55, 0) * s), xf * (Vector3(0, 0.9, 0.02) * s), 0.095 * s, 0.0 * s, "egg_flat", 10, true, false)
	g.tint = Color(0.9, 0.7, 0.6)
	for sx in [-1.0, 1.0]:
		g.beam(xf * (Vector3(sx * 0.15, 0.4, 0) * s), xf * (Vector3(sx * 0.17, 0.27, -0.1) * s), Vector2(0.05, 0.05) * s, "egg_flat", false, false)
	g.tint = Color.WHITE

## A small tent (1.2 m long along local x, 0.9 m wide, 0.75 m high); the
## door is the +x gable.
static func tent(g: Geo, xf: Transform3D) -> void:
	ensure(g)
	g.tint = Color(0.88, 0.45, 0.12)
	g.prism(xf, [Vector2(-0.45, 0.0), Vector2(0.0, 0.75), Vector2(0.45, 0.0)], 1.2, "egg_flat", true, false)
	# The door: a dark triangle 1.2 cm proud of the +x gable.
	g.tint = Color(0.16, 0.12, 0.1)
	var n: Vector3 = xf.basis.x.normalized()
	g.plate(Transform3D(Basis.looking_at(-n, xf.basis.y), xf * Vector3(0.612, 0.0, 0.0)), [Vector2(-0.2, 0.0), Vector2(0.2, 0.0), Vector2(0.0, 0.52)], "egg_flat")
	g.tint = Color.WHITE

## A fire: a ring of stones, three logs, an orange glow and a flame.
static func campfire(g: Geo, c: Vector3) -> void:
	ensure(g)
	g.tint = Color(0.5, 0.5, 0.52)
	for k in range(9):
		var a: float = TAU * k / 9.0
		g.box_xf(Transform3D(Basis(Vector3.UP, -a), c + Vector3(cos(a) * 0.24, 0.035, sin(a) * 0.24)), Vector3(0.09, 0.07, 0.07), "egg_flat", false, false)
	g.tint = Color(0.3, 0.18, 0.1)
	for k in range(3):
		var a: float = TAU * k / 3.0 + 0.4
		g.cylinder(c + Vector3(cos(a) * 0.17, 0.03, sin(a) * 0.17), c + Vector3(-cos(a) * 0.04, 0.12, -sin(a) * 0.04), 0.03, "egg_flat", 6, false, true, false)
	g.tint = Color.WHITE
	g.box_xf(Transform3D(Basis(Vector3.UP, 0.4), c + Vector3(0, 0.07, 0)), Vector3(0.13, 0.08, 0.13), "egg_fire", false, false)
	g.cone(c + Vector3(0, 0.1, 0), c + Vector3(0, 0.34, 0), 0.075, 0.0, "egg_fire", 7, false, false)

## A folding camp chair (0.45 m wide), facing -z of xf.
static func camp_chair(g: Geo, xf: Transform3D) -> void:
	ensure(g)
	g.tint = Color(0.15, 0.3, 0.55)
	g.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.4, 0)), Vector3(0.44, 0.03, 0.36), "egg_flat", false, false)
	g.box_xf(xf * Transform3D(Basis(Vector3.RIGHT, 0.2), Vector3(0, 0.62, 0.2)), Vector3(0.44, 0.3, 0.02), "egg_flat", false, false)
	g.tint = Color(0.2, 0.2, 0.22)
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			g.beam(xf * Vector3(sx * 0.2, 0.0, sz * 0.15), xf * Vector3(sx * 0.2, 0.4, sz * 0.15), Vector2(0.025, 0.025), "egg_flat", false, false)
	g.tint = Color.WHITE

## FPV goggles standing on a surface: a dark box with two round lenses
## on its -z face, foam above them, a strap behind. origin = bottom.
static func goggles(g: Geo, xf: Transform3D) -> void:
	ensure(g)
	_b(g, xf, Vector3(0, 0.04, 0.0), Vector3(0.19, 0.08, 0.09), Color(0.22, 0.23, 0.26))
	_b(g, xf, Vector3(0, 0.04, 0.0455), Vector3(0.17, 0.03, 0.002), Color(1.0, 1.0, 1.0))
	for sx in [-1.0, 1.0]:
		g.tint = Color(0.12, 0.13, 0.15)
		g.cylinder(xf * Vector3(sx * 0.045, 0.04, -0.045), xf * Vector3(sx * 0.045, 0.04, -0.068), 0.03, "egg_flat", 12, false, true, false)
		g.tint = Color(0.4, 0.8, 1.1)
		g.disc(xf * Vector3(sx * 0.045, 0.04, -0.0695), xf.basis * Vector3(0, 0, -1), 0.022, "egg_flat", 12)
	g.tint = Color.WHITE
	_b(g, xf, Vector3(0, 0.04, 0.0775), Vector3(0.2, 0.03, 0.065), Color(0.3, 0.3, 0.32))

## A drone backpack: grey body, an orange stripe, two straps.
static func backpack(g: Geo, xf: Transform3D) -> void:
	ensure(g)
	_b(g, xf, Vector3(0, 0.07, 0), Vector3(0.3, 0.14, 0.22), Color(0.22, 0.23, 0.26), true)
	_b(g, xf, Vector3(0, 0.1425, 0), Vector3(0.3, 0.005, 0.04), Color(0.95, 0.5, 0.1))
	for sx in [-1.0, 1.0]:
		_b(g, xf, Vector3(sx * 0.1, 0.1425, 0), Vector3(0.025, 0.005, 0.23), Color(0.1, 0.1, 0.11))
	_b(g, xf, Vector3(0, 0.05, -0.1125), Vector3(0.12, 0.07, 0.005), Color(0.95, 0.5, 0.1))
