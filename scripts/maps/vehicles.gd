class_name Vehicles
extends RefCounted

## Vehicles for the generated maps, shaped like the real thing: every
## body is a real side silhouette (Geo.prism) - a car's bumper, bonnet,
## raked windscreen, roof, rear window, boot and wheel arches in one
## outline - with a glass greenhouse, roof skin, pillars, mirrors,
## grille, bumpers, number plates and lights on top. Lorries are
## European cab-overs with chassis, fuel tanks, fifth wheel, side skirts
## and landing legs; buses and trams have window bands and doors; rail
## vehicles have bogies, buffers, underframe equipment and window rows.
## Plus the site machines (excavator, tipper, mixer, crane truck...).
## All batched through Geo, collidable, lit like everything else.
## Real sizes: family car ~4.7 x 1.8 x 1.45 m, a semi 16.5 m, a 12 m bus,
## a 19 m locomotive, a 26 m coach, standard gauge.

const PAINTS := [Color(0.72, 0.1, 0.1), Color(0.12, 0.22, 0.42), Color(0.86, 0.86, 0.87), Color(0.1, 0.1, 0.11),
	Color(0.45, 0.47, 0.5), Color(0.64, 0.66, 0.68), Color(0.18, 0.36, 0.24), Color(0.85, 0.66, 0.18), Color(0.35, 0.18, 0.12),
	Color(0.92, 0.92, 0.9), Color(0.25, 0.28, 0.33), Color(0.2, 0.45, 0.7)]

static func ensure_materials(geo: Geo) -> void:
	if geo.has_material("veh_glass"):
		return
	geo.add_material("veh_glass", Geo.flat_mat(Color(0.1, 0.13, 0.17), 0.1, 0.5))
	geo.add_material("veh_tyre", Geo.flat_mat(Color(0.07, 0.07, 0.075), 0.9))
	geo.add_material("veh_rim", Geo.flat_mat(Color(0.7, 0.72, 0.74), 0.3, 0.7))
	geo.add_material("veh_head", Geo.glow_mat(Color(1.0, 0.97, 0.85), 1.0))
	geo.add_material("veh_tail", Geo.glow_mat(Color(0.9, 0.1, 0.08), 1.0))
	geo.add_material("veh_amber", Geo.glow_mat(Color(1.0, 0.6, 0.1), 1.0))
	geo.add_material("veh_black", Geo.flat_mat(Color(0.11, 0.11, 0.12)))
	geo.add_material("veh_plate", Geo.flat_mat(Color(0.95, 0.95, 0.92)))
	geo.add_material("veh_steel", Geo.flat_mat(Color(0.42, 0.43, 0.45), 0.4, 0.6))
	geo.add_material("veh_chrome", Geo.flat_mat(Color(0.75, 0.76, 0.78), 0.2, 0.9))
	geo.add_material("veh_rust", Geo.tex_mat(MapTextures.get_tex("rust"), Color.WHITE, 3.0))
	geo.add_material("veh_trailer", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.95, 0.95, 0.95), 2.0))
	for i in range(PAINTS.size()):
		geo.add_material("veh_paint%d" % i, Geo.flat_mat(PAINTS[i], 0.35, 0.3))
	geo.add_material("train_white", Geo.flat_mat(Color(0.93, 0.93, 0.94), 0.4, 0.2))
	geo.add_material("train_red", Geo.flat_mat(Color(0.78, 0.08, 0.1), 0.4, 0.2))
	geo.add_material("train_grey", Geo.flat_mat(Color(0.3, 0.31, 0.33), 0.5, 0.4))
	geo.add_material("train_roof", Geo.flat_mat(Color(0.52, 0.53, 0.55), 0.5, 0.4))
	geo.add_material("train_loco", Geo.flat_mat(Color(0.72, 0.12, 0.1), 0.4, 0.3))
	geo.add_material("train_blue", Geo.flat_mat(Color(0.12, 0.25, 0.5), 0.4, 0.3))
	geo.add_material("train_brown", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.45, 0.27, 0.19), 2.0))
	geo.add_material("train_tank", Geo.flat_mat(Color(0.18, 0.18, 0.19), 0.5, 0.4))
	geo.add_material("train_tank_w", Geo.flat_mat(Color(0.8, 0.81, 0.82), 0.5, 0.4))
	geo.add_material("train_hopper", Geo.tex_mat(MapTextures.get_tex("paint_rust"), Color(0.95, 0.95, 0.9), 3.0))
	geo.add_material("site_yellow", Geo.flat_mat(Color(0.95, 0.68, 0.08), 0.5, 0.2))
	geo.add_material("site_orange", Geo.flat_mat(Color(0.92, 0.42, 0.08), 0.5, 0.2))
	geo.add_material("site_grey", Geo.flat_mat(Color(0.6, 0.6, 0.6), 0.5, 0.2))
	geo.add_material("boat_white", Geo.flat_mat(Color(0.94, 0.94, 0.92)))
	geo.add_material("boat_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color.WHITE, 1.0))

static func random_paint(rng: RandomNumberGenerator) -> String:
	# Real car colours: mostly white, black, grey and silver.
	var r: float = rng.randf()
	if r < 0.22:
		return "veh_paint9"
	if r < 0.4:
		return "veh_paint3"
	if r < 0.55:
		return "veh_paint4"
	if r < 0.67:
		return "veh_paint5"
	return "veh_paint%d" % (rng.randi() % PAINTS.size())

static func _bx(geo: Geo, xf: Transform3D, c: Vector3, size: Vector3, mat: String, collide: bool = false, shadow: bool = false) -> void:
	geo.box_xf(xf * Transform3D(Basis(), c), size, mat, collide, shadow)

## A wheel: tyre, rim, hub. local = centre in xf's frame, axle along x.
static func _wheel(geo: Geo, xf: Transform3D, local: Vector3, r: float, w: float, collide: bool = true) -> void:
	var c: Vector3 = xf * local
	var ax: Vector3 = xf.basis.x.normalized() * (w * 0.5)
	var side: float = signf(local.x)
	# Only the outer face gets a cap (the inner one faces the car), and
	# rim and hub are discs, not 1 cm thick cylinders: a third fewer
	# vertices per car (Harbour parks ~2,900 of them).
	geo.cap_mask = 2 if side > 0.0 else 1
	geo.cylinder(c - ax, c + ax, r, "veh_tyre", 14, collide, true, false)
	geo.cap_mask = 3
	# Rim and hub stand ~1 cm proud: discs at their outer faces.
	geo.disc(c + ax * side * 1.08, ax * side, r * 0.62, "veh_rim", 12)
	geo.disc(c + ax * side * 1.16, ax * side, r * 0.2, "veh_steel", 8)
	if detail_v2: # five spokes, darker between (2026-10-14)
		var n: Vector3 = ax.normalized() * side
		var up: Vector3 = xf.basis.y.normalized()
		for k in range(5):
			var a: float = TAU * k / 5.0
			var d: Vector3 = up.rotated(n, a)
			geo.box_xf(Transform3D(Basis.looking_at(d, n), c + ax * side * 1.12 + d * r * 0.38), Vector3(r * 0.13, 0.012, r * 0.36), "veh_chrome", false, false)

## Dimensions per kind: L, W, roof, belt, bonnet front height, bonnet
## length, windscreen run, roof length, rear window run, wheel radius,
## front overhang, rear overhang.
const CAR_SPECS := {
	"sedan": [4.7, 1.82, 1.45, 0.93, 0.78, 1.3, 0.78, 1.3, 0.62, 0.32, 0.92, 1.0],
	"taxi": [4.7, 1.82, 1.45, 0.93, 0.78, 1.3, 0.78, 1.3, 0.62, 0.32, 0.92, 1.0],
	"hatch": [4.1, 1.78, 1.48, 0.92, 0.8, 0.98, 0.72, 1.55, 0.3, 0.31, 0.82, 0.66],
	"estate": [4.8, 1.84, 1.48, 0.93, 0.78, 1.25, 0.78, 2.05, 0.28, 0.32, 0.92, 0.98],
	"suv": [4.7, 1.9, 1.74, 1.08, 0.98, 1.12, 0.72, 1.9, 0.34, 0.37, 0.92, 0.98],
	"van": [5.3, 2.0, 2.4, 1.05, 1.0, 0.72, 0.78, 3.7, 0.0, 0.33, 0.82, 1.05],
	"pickup": [5.3, 1.92, 1.82, 1.12, 1.0, 1.42, 0.72, 1.15, 0.2, 0.38, 0.95, 1.25],
}

## The extra detail of _car_detail (2026-10-14, on; SH_CARS_OLD=1 for the old cars).
static var detail_v2: bool = not OS.has_environment("SH_CARS_OLD") # (approved 2026-10-14; SH_CARS_OLD shows the old cars)

## The things that make a car read as a car up close, each touching the
## body: black sills and arch liners, door seams and handles, a
## daytime-running strip in each headlight, tail lights wrapping round
## the corners, roof rails (estate, SUV), a shark-fin antenna, the
## exhaust; the rims get five spokes. Cheap boxes - Fleet instances them.
static func _car_detail(geo: Geo, xf: Transform3D, kind: String, s: Array, mat: String, zf: float, zr: float, zws: float, zrf: float, zrr: float, fa: float, ra: float, R: float, clear: float) -> void:
	var W: float = s[1]
	var H: float = s[2]
	var belt: float = s[3]
	var hw: float = W * 0.5
	for sx in [-1.0, 1.0]:
		# Sill between the arches.
		_bx(geo, xf, Vector3(sx * (hw - 0.01), clear + 0.07, (fa + ra) * 0.5), Vector3(0.04, 0.12, ra - fa - 2.0 * R), "veh_black")
		# Arch liners: a dark lip round each wheel arch.
		for axle in [fa, ra]:
			for k in range(7):
				var a: float = PI * (k + 0.5) / 7.0
				var q := Vector3(sx * (hw - 0.005), (s[9] - 0.01) + (R + 0.02) * sin(a), axle + (R + 0.02) * cos(a))
				var bx := Basis(Vector3.RIGHT, -a + PI * 0.5)
				geo.box_xf(xf * Transform3D(bx, q), Vector3(0.03, 0.05, R * PI / 7.0 + 0.02), "veh_black", false, false)
		if kind != "van":
			# Door seams (front door's back edge, rear door's) and handles.
			var doors: Array = [zrf + (zrr - zrf) * 0.45] if kind in ["sedan", "taxi", "estate", "suv", "hatch"] else [zrf + (zrr - zrf) * 0.95]
			doors.push_front(zws + 0.05)
			for dz in doors:
				_bx(geo, xf, Vector3(sx * (hw + 0.004), (belt + clear) * 0.5 + 0.08, dz), Vector3(0.01, belt - clear - 0.1, 0.012), "veh_black")
			for dz in doors.slice(1):
				_bx(geo, xf, Vector3(sx * (hw + 0.012), belt - 0.1, dz - 0.25), Vector3(0.02, 0.03, 0.14), "veh_chrome")
	# Headlights: a DRL strip under each; tail lights round the corners.
	for sx in [-1.0, 1.0]:
		_bx(geo, xf, Vector3(sx * (hw - 0.3), s[4] - 0.17, zf + 0.05), Vector3(0.34, 0.025, 0.05), "veh_head")
		_bx(geo, xf, Vector3(sx * (hw - 0.025), belt - 0.14, zr - 0.12), Vector3(0.06, 0.12, 0.22), "veh_tail")
	if kind in ["estate", "suv"]:
		for sx in [-1.0, 1.0]:
			_bx(geo, xf, Vector3(sx * (W * 0.5 - 0.22), H + 0.08, (zrf + zrr) * 0.5), Vector3(0.04, 0.04, zrr - zrf - 0.1), "veh_black")
			for dz in [zrf + 0.1, zrr - 0.1]:
				_bx(geo, xf, Vector3(sx * (W * 0.5 - 0.22), H + 0.04, dz), Vector3(0.04, 0.06, 0.05), "veh_black")
	if kind != "van":
		var fin: Vector3 = Vector3(0, H + 0.04, zrr - 0.15)
		geo.frustum(xf * Transform3D(Basis(), fin), Vector3(0.06, 0.07, 0.16), 0.02, 0.06, 0.04, "veh_black", false, false)
	geo.cylinder(xf * Vector3(-W * 0.3, clear + 0.08, zr - 0.05), xf * Vector3(-W * 0.3, clear + 0.08, zr + 0.05), 0.035, "veh_chrome", 8, false)

## A car at p (ground), heading along local -z (yaw). kind: "sedan",
## "hatch", "estate", "suv", "van", "pickup", "taxi"; wreck = rusted,
## sunk on flat tyres, glass gone.
static func car(geo: Geo, p: Vector3, yaw: float, paint: String, kind: String = "sedan", wreck: bool = false) -> void:
	ensure_materials(geo)
	var s: Array = CAR_SPECS.get(kind, CAR_SPECS.sedan)
	var L: float = s[0]
	var W: float = s[1]
	var H: float = s[2]
	var belt: float = s[3]
	var wr: float = s[9]
	var clear: float = wr * 0.7
	if wreck:
		p.y -= 0.08
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var mat: String = "veh_rust" if wreck else paint
	var zf: float = -L * 0.5
	var zr: float = L * 0.5
	var zws: float = zf + s[5]
	var zrf: float = zws + s[6]
	var zrr: float = zrf + s[7]
	var zrb: float = minf(zrr + s[8], zr - 0.02)
	var fa: float = zf + s[10]
	var ra: float = zr - s[11]
	var R: float = wr + 0.07
	var cy: float = wr - 0.01
	# Lower body silhouette: nose, bonnet, belt, boot, tail, then the
	# underside back to the front through both wheel arches.
	var pts: Array = [Vector2(zf + 0.12, clear + 0.06), Vector2(zf, 0.46), Vector2(zf + 0.05, s[4]), Vector2(zws, belt)]
	if zrb < zr - 0.2:
		pts.append_array([Vector2(zrb, belt), Vector2(zr - 0.08, belt - 0.03), Vector2(zr, belt - 0.2)])
	else:
		pts.append(Vector2(zr - 0.02, belt))
	pts.append_array([Vector2(zr, 0.5), Vector2(zr - 0.12, clear + 0.06)])
	for axle in [ra, fa]:
		pts.append(Vector2(axle + R, clear))
		for k in range(9):
			var a: float = PI * k / 8.0
			pts.append(Vector2(axle + R * cos(a), cy + R * sin(a)))
		pts.append(Vector2(axle - R, clear))
	geo.prism(xf, pts, W, mat)
	# Greenhouse (glass) on the belt line, narrower (tumblehome), and
	# the roof skin over it.
	var gw: float = W - 0.16
	var glass: String = "veh_black" if wreck else "veh_glass"
	var cab_end: float = zrr
	if kind == "van":
		cab_end = zrf + 0.6
		geo.prism(xf, [Vector2(zws + 0.02, belt), Vector2(zrf, H), Vector2(cab_end, H), Vector2(cab_end, belt)], gw, glass, true, false)
		geo.prism(xf, [Vector2(cab_end, belt), Vector2(cab_end, H), Vector2(zr - 0.02, H), Vector2(zr - 0.02, belt)], W - 0.04, mat)
		geo.prism(xf, [Vector2(zrf + 0.04, H - 0.04), Vector2(zr - 0.02, H - 0.04), Vector2(zr - 0.06, H + 0.05), Vector2(zrf + 0.12, H + 0.05)], W - 0.08, mat, false, false)
	elif kind == "pickup":
		cab_end = zrr + 0.12
		geo.prism(xf, [Vector2(zws + 0.02, belt), Vector2(zrf, H), Vector2(zrr, H), Vector2(cab_end, belt)], gw, glass, true, false)
		geo.prism(xf, [Vector2(zrf + 0.04, H - 0.04), Vector2(zrr - 0.02, H - 0.04), Vector2(zrr - 0.06, H + 0.05), Vector2(zrf + 0.12, H + 0.05)], gw - 0.04, mat, false, false)
		# The load bed: side walls and tailgate round an open floor.
		for sx in [-1.0, 1.0]:
			_bx(geo, xf, Vector3(sx * (W * 0.5 - 0.05), belt + 0.22, (cab_end + zr) * 0.5 + 0.05), Vector3(0.1, 0.44, zr - cab_end - 0.1), mat, true)
		_bx(geo, xf, Vector3(0, belt + 0.22, zr - 0.06), Vector3(W - 0.1, 0.44, 0.1), mat, true)
	else:
		geo.prism(xf, [Vector2(zws + 0.02, belt), Vector2(zrf, H), Vector2(zrr, H), Vector2(zrb, belt)], gw, glass, true, false)
		geo.prism(xf, [Vector2(zrf + 0.04, H - 0.04), Vector2(zrr - 0.02, H - 0.04), Vector2(zrr - 0.08, H + 0.05), Vector2(zrf + 0.12, H + 0.05)], gw - 0.04, mat, false, false)
	# Pillars (A, B, C) in body colour over the glass.
	var px: float = gw * 0.5 + 0.005
	for sx in [-1.0, 1.0]:
		geo.beam(xf * Vector3(sx * px, belt, zws + 0.05), xf * Vector3(sx * (px - 0.03), H - 0.02, zrf + 0.02), Vector2(0.07, 0.06), mat, false, false)
		if kind != "van":
			var zb: float = zrf + (cab_end - zrf) * (0.45 if kind != "pickup" else 0.98)
			geo.beam(xf * Vector3(sx * px, belt, zb), xf * Vector3(sx * (px - 0.02), H - 0.02, zb - 0.04), Vector2(0.1, 0.08), mat, false, false)
		if kind != "van" and kind != "pickup":
			geo.beam(xf * Vector3(sx * px, belt, zrb - 0.08), xf * Vector3(sx * (px - 0.03), H - 0.02, zrr - 0.04), Vector2(0.14 if kind != "sedan" and kind != "taxi" else 0.08, 0.07), mat, false, false)
		# Door mirror on its arm out of the door's front corner (2026-10-14:
		# the housing stood a centimetre off the door, nothing holding it).
		_bx(geo, xf, Vector3(sx * (W * 0.5 + 0.04), belt + 0.06, zws + 0.22), Vector3(0.1, 0.04, 0.06), "veh_black")
		_bx(geo, xf, Vector3(sx * (W * 0.5 + 0.13), belt + 0.13, zws + 0.2), Vector3(0.16, 0.13, 0.1), mat)
	# Front and rear: bumpers, grille, lights, number plates.
	_bx(geo, xf, Vector3(0, 0.42, zf + 0.03), Vector3(W - 0.04, 0.17, 0.12), "veh_black")
	_bx(geo, xf, Vector3(0, 0.44, zr - 0.03), Vector3(W - 0.04, 0.17, 0.12), "veh_black")
	if not wreck:
		_bx(geo, xf, Vector3(0, 0.62, zf + 0.02), Vector3(W * 0.42, 0.14, 0.06), "veh_black")
		_bx(geo, xf, Vector3(0, 0.43, zf - 0.035), Vector3(0.52, 0.11, 0.02), "veh_plate")
		_bx(geo, xf, Vector3(0, 0.62, zr + 0.01), Vector3(0.52, 0.11, 0.02), "veh_plate")
		for sx in [-1.0, 1.0]:
			_bx(geo, xf, Vector3(sx * (W * 0.5 - 0.3), s[4] - 0.1, zf + 0.06), Vector3(0.38, 0.1, 0.06), "veh_head")
			_bx(geo, xf, Vector3(sx * (W * 0.5 - 0.22), belt - 0.14, zr - 0.0), Vector3(0.34, 0.12, 0.05), "veh_tail")
	if kind == "taxi":
		_bx(geo, xf, Vector3(0, H + 0.12, (zrf + zrr) * 0.5), Vector3(0.62, 0.17, 0.22), "veh_amber")
	if detail_v2 and not wreck:
		_car_detail(geo, xf, kind, s, mat, zf, zr, zws, zrf, zrr, fa, ra, R, clear)
	for sx in [-1.0, 1.0]:
		for az in [fa, ra]:
			_wheel(geo, xf, Vector3(sx * (W * 0.5 - 0.13), wr * (0.85 if wreck else 1.0), az), wr, 0.22)

## Articulated lorry (European cab-over tractor + 13.6 m trailer).
## trailer: a container material ("c_...") puts a 40 ft box on a
## skeletal chassis; anything else is the curtain/box body's material.
static func semi(geo: Geo, p: Vector3, yaw: float, paint: String, trailer: String) -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	_tractor(geo, xf, paint)
	var container: bool = trailer.begins_with("c_")
	if container:
		for sx in [-0.5, 0.5]:
			_bx(geo, xf, Vector3(sx, 1.12, 1.5), Vector3(0.22, 0.36, 13.2), "veh_black", true, true)
		for k in range(7):
			_bx(geo, xf, Vector3(0, 1.2, -4.5 + k * 2.0), Vector3(2.3, 0.14, 0.18), "veh_black")
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 1.3 + 1.295, 1.9)), Vector3(2.44, 2.59, 12.19), trailer)
	else:
		_bx(geo, xf, Vector3(0, 1.25, 1.5), Vector3(2.5, 0.3, 13.6), "veh_black", true, true)
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 2.78, 1.5)), Vector3(2.55, 2.76, 13.6), trailer)
		_bx(geo, xf, Vector3(0, 2.78, 8.31), Vector3(0.04, 2.6, 0.02), "veh_black")
		for sx in [-1.0, 1.0]:
			_bx(geo, xf, Vector3(sx * 1.2, 0.82, -0.3), Vector3(0.05, 0.55, 7.8), paint)
	for sx in [-1.0, 1.0]:
		_bx(geo, xf, Vector3(sx * 0.9, 0.62, -2.9), Vector3(0.12, 1.0, 0.12), "veh_steel")
		_bx(geo, xf, Vector3(sx * 0.9, 0.1, -2.9), Vector3(0.3, 0.06, 0.3), "veh_steel")
		_bx(geo, xf, Vector3(sx * 1.0, 1.0, 8.28), Vector3(0.36, 0.14, 0.05), "veh_tail")
		for z in [5.05, 6.35, 7.65]:
			_wheel(geo, xf, Vector3(sx * 1.02, 0.5, z), 0.5, 0.38)
	_bx(geo, xf, Vector3(0, 0.82, 8.2), Vector3(2.44, 0.12, 0.12), "veh_black") # underrun bar

## Cab-over tractor unit, front at local z -8.4.
static func _tractor(geo: Geo, xf: Transform3D, paint: String) -> void:
	var y0: float = 1.05
	geo.prism(xf, [Vector2(-8.4, y0), Vector2(-8.45, 2.15), Vector2(-6.1, 2.15), Vector2(-6.1, y0)], 2.45, paint)
	geo.prism(xf, [Vector2(-8.45, 2.15), Vector2(-8.38, 3.25), Vector2(-7.35, 3.25), Vector2(-7.35, 2.15)], 2.42, "veh_glass")
	geo.prism(xf, [Vector2(-7.35, 2.15), Vector2(-7.35, 3.25), Vector2(-6.1, 3.25), Vector2(-6.1, 2.15)], 2.45, paint)
	geo.prism(xf, [Vector2(-8.38, 3.25), Vector2(-8.3, 3.75), Vector2(-8.05, 3.97), Vector2(-6.1, 3.97), Vector2(-6.1, 3.25)], 2.45, paint)
	geo.frustum(xf * Transform3D(Basis(), Vector3(0, 4.32, -6.9)), Vector3(2.35, 0.7, 1.6), 2.3, 0.9, 0.35, paint)
	_bx(geo, xf, Vector3(0, 1.7, -8.44), Vector3(1.7, 0.65, 0.06), "veh_black") # grille
	_bx(geo, xf, Vector3(0, 0.86, -8.33), Vector3(2.5, 0.42, 0.3), "veh_black", true) # bumper
	_bx(geo, xf, Vector3(0, 3.3, -8.52), Vector3(2.3, 0.07, 0.34), paint) # sun visor
	_bx(geo, xf, Vector3(0, 0.62, -8.49), Vector3(0.52, 0.11, 0.02), "veh_plate")
	for sx in [-1.0, 1.0]:
		_bx(geo, xf, Vector3(sx * 0.88, 1.12, -8.5), Vector3(0.42, 0.16, 0.05), "veh_head")
		_bx(geo, xf, Vector3(sx * 1.27, 2.7, -7.9), Vector3(0.03, 0.9, 0.9), "veh_black") # door window line
		geo.beam(xf * Vector3(sx * 1.22, 3.05, -8.1), xf * Vector3(sx * 1.5, 3.05, -8.3), Vector2(0.05, 0.05), "veh_black", false, false)
		_bx(geo, xf, Vector3(sx * 1.52, 2.7, -8.3), Vector3(0.1, 0.6, 0.16), "veh_black") # mirror
		_bx(geo, xf, Vector3(sx * 1.13, 0.66, -7.6), Vector3(0.22, 0.55, 0.7), "veh_black") # steps
		_bx(geo, xf, Vector3(sx * 1.08, 1.25, -4.85), Vector3(0.3, 0.1, 1.3), paint) # mudguard
		_wheel(geo, xf, Vector3(sx * 1.02, 0.52, -7.55), 0.52, 0.34)
		_wheel(geo, xf, Vector3(sx * 0.92, 0.52, -4.85), 0.52, 0.55)
	_bx(geo, xf, Vector3(0, 0.9, -5.9), Vector3(0.95, 0.34, 5.0), "veh_black", true)
	geo.cylinder(xf * Vector3(1.1, 0.82, -5.9), xf * Vector3(1.1, 0.82, -4.4 - 0.2), 0.34, "veh_chrome", 12, false, true, false)
	geo.cylinder(xf * Vector3(-1.0, 0.8, -5.9), xf * Vector3(-1.0, 0.8, -5.3), 0.24, "veh_steel", 10, false, true, false)
	_bx(geo, xf, Vector3(0, 1.15, -4.4), Vector3(1.7, 0.18, 1.2), "veh_black")
	geo.cylinder(xf * Vector3(-0.95, 1.3, -5.98), xf * Vector3(-0.95, 4.1, -5.98), 0.08, "veh_chrome", 8, false, true, false)

## Rigid 7.5 t delivery lorry: small cab-over, box body.
static func box_truck(geo: Geo, p: Vector3, yaw: float, paint: String) -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	geo.prism(xf, [Vector2(-3.7, 0.75), Vector2(-3.75, 1.55), Vector2(-2.1, 1.55), Vector2(-2.1, 0.75)], 2.3, paint)
	geo.prism(xf, [Vector2(-3.75, 1.55), Vector2(-3.62, 2.4), Vector2(-2.9, 2.4), Vector2(-2.9, 1.55)], 2.27, "veh_glass")
	geo.prism(xf, [Vector2(-2.9, 1.55), Vector2(-2.9, 2.4), Vector2(-2.1, 2.4), Vector2(-2.1, 1.55)], 2.3, paint)
	geo.prism(xf, [Vector2(-3.62, 2.4), Vector2(-3.45, 2.75), Vector2(-2.1, 2.75), Vector2(-2.1, 2.4)], 2.3, paint)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 2.3, 0.85)), Vector3(2.45, 2.6, 5.8), "veh_trailer")
	_bx(geo, xf, Vector3(0, 0.8, 0.0), Vector3(0.9, 0.3, 7.0), "veh_black", true)
	_bx(geo, xf, Vector3(0, 0.62, -3.72), Vector3(2.3, 0.3, 0.2), "veh_black", true)
	for sx in [-1.0, 1.0]:
		_bx(geo, xf, Vector3(sx * 0.8, 1.0, -3.77), Vector3(0.35, 0.14, 0.04), "veh_head")
		_bx(geo, xf, Vector3(sx * 1.0, 1.0, 3.76), Vector3(0.3, 0.12, 0.04), "veh_tail")
		_bx(geo, xf, Vector3(sx * 1.33, 2.0, -3.5), Vector3(0.08, 0.45, 0.12), "veh_black")
		_wheel(geo, xf, Vector3(sx * 0.98, 0.45, -2.8), 0.45, 0.3)
		_wheel(geo, xf, Vector3(sx * 0.9, 0.45, 1.9), 0.45, 0.5)

## City bus, 12 m: window band, glazed front, doors on the right.
static func bus(geo: Geo, p: Vector3, yaw: float, paint: String) -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	geo.prism(xf, [Vector2(-5.95, 0.35), Vector2(-6.0, 1.05), Vector2(6.0, 1.05), Vector2(5.95, 0.35)], 2.55, paint)
	geo.prism(xf, [Vector2(-6.0, 1.05), Vector2(-5.92, 2.75), Vector2(5.9, 2.75), Vector2(6.0, 1.05)], 2.5, "veh_glass")
	geo.prism(xf, [Vector2(-5.92, 2.75), Vector2(-5.8, 3.1), Vector2(5.8, 3.1), Vector2(5.9, 2.75)], 2.55, paint)
	# Pillars between the side windows, window sill band.
	for k in range(9):
		var z: float = -4.4 + k * 1.3
		for sx in [-1.0, 1.0]:
			_bx(geo, xf, Vector3(sx * 1.265, 1.95, z), Vector3(0.03, 1.7, 0.12), paint)
	for sx in [-1.0, 1.0]:
		_bx(geo, xf, Vector3(sx * 1.27, 1.3, 0), Vector3(0.03, 0.5, 11.6), paint)
	for dz in [-4.9, 0.4]:
		_bx(geo, xf, Vector3(1.27, 1.6, dz), Vector3(0.03, 2.3, 1.2), "veh_black") # doors
	_bx(geo, xf, Vector3(0, 2.55, -5.98), Vector3(1.6, 0.25, 0.05), "veh_amber") # destination
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 3.3, 1.5)), Vector3(1.8, 0.4, 3.0), "veh_black", false, false) # roof unit
	for sx in [-1.0, 1.0]:
		_bx(geo, xf, Vector3(sx * 0.95, 0.65, -6.0), Vector3(0.3, 0.14, 0.05), "veh_head")
		_bx(geo, xf, Vector3(sx * 1.05, 0.75, 6.0), Vector3(0.2, 0.3, 0.05), "veh_tail")
		for sz in [-3.3, 2.9]:
			_wheel(geo, xf, Vector3(sx * 1.05, 0.5, sz), 0.5, 0.32)

## Low-floor tram, 30 m in three sections, pantograph.
static func tram(geo: Geo, p: Vector3, yaw: float) -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	for k in range(3):
		var z: float = -10.2 + k * 10.2
		var z0: float = z - 4.9
		var z1: float = z + 4.9
		var nose0: float = 0.5 if k == 0 else 0.0
		var nose1: float = 0.5 if k == 2 else 0.0
		geo.prism(xf, [Vector2(z0 + nose0 * 0.3, 0.35), Vector2(z0, 1.1), Vector2(z1, 1.1), Vector2(z1 - nose1 * 0.3, 0.35)], 2.4, "train_red")
		geo.prism(xf, [Vector2(z0, 1.1), Vector2(z0 + nose0, 2.9), Vector2(z1 - nose1, 2.9), Vector2(z1, 1.1)], 2.36, "veh_glass")
		geo.prism(xf, [Vector2(z0 + nose0, 2.9), Vector2(z0 + nose0 * 1.4, 3.3), Vector2(z1 - nose1 * 1.4, 3.3), Vector2(z1 - nose1, 2.9)], 2.4, "train_white")
		for j in range(4):
			for sx in [-1.0, 1.0]:
				_bx(geo, xf, Vector3(sx * 1.19, 2.0, z0 + 1.2 + j * 2.5), Vector3(0.03, 1.8, 0.2), "train_white")
		_bx(geo, xf, Vector3(0, 3.5, z), Vector3(1.6, 0.35, 3.0), "train_grey")
		# Low-floor bogie behind its skirts: the body stands on it, not on air.
		_bx(geo, xf, Vector3(0, 0.21, z), Vector3(2.1, 0.42, 3.4), "train_grey")
	geo.beam(xf * Vector3(0, 3.7, -1), xf * Vector3(0, 4.8, 0.3), Vector2(0.06, 0.06), "veh_steel", false)
	geo.beam(xf * Vector3(0, 4.8, 0.3), xf * Vector3(0, 3.7, 1.5), Vector2(0.06, 0.06), "veh_steel", false)
	_bx(geo, xf, Vector3(0, 4.82, 0.3), Vector3(1.4, 0.05, 0.2), "veh_steel")

# --- rail -----------------------------------------------------------------------

const RAIL_LENGTH := {"loco": 19.0, "ice_head": 21.0, "ice_tail": 21.0, "ice": 25.5, "tank": 15.0, "box": 16.5, "hopper": 13.0, "flat": 19.6, "flat_empty": 19.6,
	"torpedo": 26.0, "shunter": 11.0, "coach": 26.4}

## Rail vehicle standing with its first end at x on a track along world
## x (rail top at y). See rail_xf. Returns the length.
static func rail(geo: Geo, x: float, y: float, z: float, kind: String, rng: RandomNumberGenerator, container_mats: Array = []) -> float:
	var L: float = RAIL_LENGTH[kind]
	rail_xf(geo, Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(x + L * 0.5, y, z)), kind, rng, container_mats)
	return L

## A body section `z0..z1` along the vehicle, cross-section `sec`
## (Vector2(x across, y)) - coach roofs, tank shells, loco bodies.
static func _long(geo: Geo, b: Transform3D, z0: float, z1: float, sec: Array, mat: String, collide: bool = true) -> void:
	geo.prism(b * Transform3D(Basis(Vector3.UP, PI * 0.5), Vector3(0, 0, (z0 + z1) * 0.5)), sec, z1 - z0, mat, collide, collide)

const ROOF_SEC := [Vector2(-1.47, 3.3), Vector2(1.47, 3.3), Vector2(1.47, 3.5), Vector2(1.2, 3.98), Vector2(0.6, 4.18), Vector2(-0.6, 4.18), Vector2(-1.2, 3.98), Vector2(-1.47, 3.5)]

## Side window row between z0 and z1: glass panes with body-colour
## pillars between, as one band (so nothing sits on top of anything).
static func _windows(geo: Geo, b: Transform3D, z0: float, z1: float, y0: float, y1: float, pane: float, pillar: float, mat: String) -> void:
	var z: float = z0
	var glass: bool = false
	while z < z1 - 0.01:
		var l: float = minf((pane if glass else pillar), z1 - z)
		_bx(geo, b, Vector3(0, (y0 + y1) * 0.5, z + l * 0.5), Vector3(2.95, y1 - y0, l), "veh_glass" if glass else mat, true, false)
		z += l
		glass = not glass

## Rail vehicle with its centre at b.origin (on the rail top), local -z
## = its front (the way it faces along the track): "loco", "shunter",
## "ice_head" (nose at the front), "ice_tail" (nose at the back), "ice",
## "coach", "tank", "box", "hopper", "flat", "flat_empty", "torpedo".
static func rail_xf(geo: Geo, b: Transform3D, kind: String, rng: RandomNumberGenerator, container_mats: Array = []) -> float:
	ensure_materials(geo)
	var L: float = RAIL_LENGTH[kind]
	# Bogies: frame, springs, two wheelsets; buffers at the ends.
	var bogie: float = L * 0.5 - (3.0 if kind != "shunter" else 2.6)
	for bz in [-bogie, bogie]:
		_bx(geo, b, Vector3(0, 0.78, bz), Vector3(2.1, 0.42, 3.0), "veh_black", true, false)
		for sx in [-1.0, 1.0]:
			_bx(geo, b, Vector3(sx * 1.08, 0.62, bz), Vector3(0.12, 0.34, 2.6), "train_grey")
			for az in [-0.95, 0.95]:
				geo.cylinder(b * Vector3(sx * 0.8, 0.46, bz + az), b * Vector3(sx * 0.68, 0.46, bz + az), 0.46, "veh_steel", 12, false, true, false)
				geo.cylinder(b * Vector3(sx * 1.14, 0.46, bz + az), b * Vector3(sx * 1.2, 0.46, bz + az), 0.14, "veh_black", 8, false, true, false)
	if not kind.begins_with("ice") and kind != "coach":
		for ez in [-L * 0.5, L * 0.5]:
			_bx(geo, b, Vector3(0, 1.05, ez - signf(ez) * 0.1), Vector3(2.7, 0.35, 0.2), "veh_black")
			for sx in [-0.88, 0.88]:
				geo.cylinder(b * Vector3(sx, 1.05, ez), b * Vector3(sx, 1.05, ez + signf(ez) * 0.4), 0.12, "veh_steel", 8, false, true, false)
				geo.cylinder(b * Vector3(sx, 1.05, ez + signf(ez) * 0.4), b * Vector3(sx, 1.05, ez + signf(ez) * 0.46), 0.2, "veh_steel", 10, false, true, false)
	match kind:
		"loco":
			_bx(geo, b, Vector3(0, 1.22, 0), Vector3(2.9, 0.35, L - 0.6), "veh_black", true)
			var zc: float = L * 0.5 - 0.3
			# Body in three bands: lower (red), window band (cab glass at
			# both ends, grilles between), roof. Sloped cab fronts.
			_long(geo, b, -zc + 0.25, zc - 0.25, [Vector2(-1.47, 1.4), Vector2(1.47, 1.4), Vector2(1.47, 2.6), Vector2(-1.47, 2.6)], "train_loco")
			for ez in [-1.0, 1.0]:
				var tip: float = ez * zc
				geo.prism(b, [Vector2(tip, 1.4), Vector2(tip, 2.6), Vector2(tip - ez * 0.25, 2.6), Vector2(tip - ez * 0.25, 1.4)], 2.94, "train_loco")
				geo.prism(b, [Vector2(tip - ez * 0.0, 2.6), Vector2(tip - ez * 0.55, 3.55), Vector2(tip - ez * 1.9, 3.55), Vector2(tip - ez * 1.9, 2.6)], 2.9, "veh_glass")
				_bx(geo, b, Vector3(0, 2.0, tip + ez * 0.02), Vector3(0.9, 0.5, 0.04), "train_white", false, false)
				for sx in [-0.75, 0.75]:
					_bx(geo, b, Vector3(sx, 1.75, tip + ez * 0.03), Vector3(0.25, 0.15, 0.04), "veh_head")
			_long(geo, b, -zc + 1.9, zc - 1.9, [Vector2(-1.47, 2.6), Vector2(1.47, 2.6), Vector2(1.47, 3.55), Vector2(-1.47, 3.55)], "train_loco")
			for k in range(5):
				for sx in [-1.0, 1.0]:
					_bx(geo, b, Vector3(sx * 1.475, 3.05, -4.8 + k * 2.4), Vector3(0.03, 0.7, 1.6), "train_grey")
			_long(geo, b, -zc + 0.5, zc - 0.5, [Vector2(-1.47, 3.55), Vector2(1.47, 3.55), Vector2(1.2, 4.05), Vector2(-1.2, 4.05)], "train_roof")
			for sx in [-1.0, 1.0]:
				_bx(geo, b, Vector3(sx * 1.48, 1.9, 0), Vector3(0.03, 0.14, L - 3.0), "train_white")
			_bx(geo, b, Vector3(0, 0.95, 0), Vector3(1.8, 0.6, 6.0), "veh_black") # transformer
			for pz in [-4.0, 4.0]:
				geo.beam(b * Vector3(0, 4.1, pz), b * Vector3(0, 5.2, pz + 1.4), Vector2(0.07, 0.07), "veh_steel", false)
				geo.beam(b * Vector3(0, 5.2, pz + 1.4), b * Vector3(0, 4.1, pz + 2.6), Vector2(0.07, 0.07), "veh_steel", false)
				_bx(geo, b, Vector3(0, 5.23, pz + 1.4), Vector3(1.8, 0.05, 0.25), "veh_steel")
		"shunter":
			_bx(geo, b, Vector3(0, 1.2, 0), Vector3(2.8, 0.3, L - 0.4), "veh_black", true)
			_bx(geo, b, Vector3(0, 2.3, -1.6), Vector3(2.0, 1.9, L - 4.6), "site_yellow", true, true)
			geo.prism(b, [Vector2(L * 0.5 - 3.4, 1.35), Vector2(L * 0.5 - 3.4, 4.1), Vector2(L * 0.5 - 0.5, 4.1), Vector2(L * 0.5 - 0.5, 1.35)], 2.8, "site_yellow")
			_bx(geo, b, Vector3(0, 3.4, L * 0.5 - 1.95), Vector3(2.82, 0.9, 2.2), "veh_glass")
			_bx(geo, b, Vector3(0, 4.15, L * 0.5 - 1.95), Vector3(3.0, 0.12, 3.2), "veh_black")
			geo.cylinder(b * Vector3(0.5, 3.2, -3.0), b * Vector3(0.5, 3.9, -3.0), 0.1, "veh_black", 8, false)
		"ice_head", "ice_tail":
			# sn: which local-z end carries the nose (-1 = the front).
			var sn: float = -1.0 if kind == "ice_head" else 1.0
			var zb: float = sn * (L * 0.5 - 5.0)
			var za: float = -sn * L * 0.5
			var lo: float = minf(za, zb)
			var hi: float = maxf(za, zb)
			_long(geo, b, lo, hi, [Vector2(-1.47, 1.15), Vector2(1.47, 1.15), Vector2(1.47, 2.45), Vector2(-1.47, 2.45)], "train_white")
			_windows(geo, b, lo + 0.6, hi - 0.6, 2.45, 3.3, 1.8, 0.45, "train_white")
			_long(geo, b, lo, hi, ROOF_SEC, "train_white")
			_bx(geo, b, Vector3(0, 1.75, (lo + hi) * 0.5), Vector3(3.0, 0.28, hi - lo - 0.04), "train_red", false, false) # (3 cm proud of the body, 2 cm short at the ends: flush, it flickered)
			# The nose: a wedge from the full body section to a low tip.
			var zt: float = sn * (L * 0.5)
			var pts: Array = []
			for i in range(8):
				var tip: bool = ((i & 4) != 0) == (sn > 0.0)
				var hw: float = (0.55 if tip else 1.47) * (1.0 if i & 1 else -1.0)
				var yy: float = 0.9 if not (i & 2) else (1.75 if tip else 4.15)
				pts.append(b * Vector3(hw, yy, zt if tip else zb))
			geo.hexa(pts, "train_white")
			var wf: Vector3 = b * Vector3(0, 3.35, zb + sn * 1.35)
			geo.box_xf(Transform3D(b.basis * Basis(Vector3.RIGHT, -sn * 0.62), wf), Vector3(2.0, 0.06, 1.7), "veh_glass", false, false)
			for sx in [-0.6, 0.6]:
				_bx(geo, b, Vector3(sx * 0.9, 1.6, zt - sn * 0.35), Vector3(0.3, 0.1, 0.3), "veh_head")
			geo.beam(b * Vector3(0, 4.2, -sn * 2.0), b * Vector3(0, 5.2, -sn * 0.8), Vector2(0.07, 0.07), "veh_steel", false)
			_bx(geo, b, Vector3(0, 5.22, -sn * 0.8), Vector3(1.8, 0.05, 0.25), "veh_steel")
		"ice", "coach":
			var h: float = L * 0.5
			var body: String = "train_white" if kind == "ice" else "train_blue"
			_long(geo, b, -h, h, [Vector2(-1.47, 1.15), Vector2(1.47, 1.15), Vector2(1.47, 2.45), Vector2(-1.47, 2.45)], body)
			_bx(geo, b, Vector3(0, 1.75, 0), Vector3(3.0, 0.28, L - 0.04), "train_red" if kind == "ice" else "train_white", false, false)
			_windows(geo, b, -h + 2.6, h - 2.6, 2.45, 3.3, 1.9, 0.5, body)
			for ez in [-1.0, 1.0]:
				_bx(geo, b, Vector3(0, 2.875, ez * (h - 1.3)), Vector3(2.95, 0.85, 2.6), body, true, false)
				for sx in [-1.0, 1.0]:
					_bx(geo, b, Vector3(sx * 1.495, 2.2, ez * (h - 1.5)), Vector3(0.07, 2.0, 1.2), "train_grey")
			_long(geo, b, -h, h, ROOF_SEC, "train_roof" if kind == "coach" else "train_white")
			_bx(geo, b, Vector3(0, 0.95, 0), Vector3(2.2, 0.5, L - 9.0), "veh_black")
			for ez in [-1.0, 1.0]:
				_bx(geo, b, Vector3(0, 2.6, ez * (h + 0.3)), Vector3(2.2, 2.8, 0.6), "veh_black") # gangway
		"tank":
			_bx(geo, b, Vector3(0, 1.2, 0), Vector3(2.7, 0.3, L), "veh_black", true)
			var m: String = "train_tank" if rng.randf() < 0.6 else "train_tank_w"
			geo.cylinder(b * Vector3(0, 2.8, -L * 0.5 + 1.2), b * Vector3(0, 2.8, L * 0.5 - 1.2), 1.45, m, 18)
			for ez in [-1.0, 1.0]:
				geo.cone(b * Vector3(0, 2.8, ez * (L * 0.5 - 1.2)), b * Vector3(0, 2.8, ez * (L * 0.5 - 0.7)), 1.45, 0.9, m, 18)
				_bx(geo, b, Vector3(1.0, 2.6, ez * (L * 0.5 - 0.5)), Vector3(0.4, 2.8, 0.06), "veh_black") # ladder
			geo.cylinder(b * Vector3(0, 4.2, 0), b * Vector3(0, 4.6, 0), 0.5, m, 10)
			_bx(geo, b, Vector3(0, 4.3, 0), Vector3(1.0, 0.05, L - 4.0), "veh_steel")
			for sx in [-1.0, 1.0]:
				_bx(geo, b, Vector3(sx * 0.6, 4.35, 0), Vector3(0.04, 0.9, L - 4.0), "veh_steel")
		"box":
			_bx(geo, b, Vector3(0, 1.2, 0), Vector3(2.8, 0.3, L), "veh_black", true)
			geo.box_xf(b * Transform3D(Basis(), Vector3(0, 2.95, 0)), Vector3(2.9, 3.2, L), "train_brown")
			for k in range(6):
				for sx in [-1.0, 1.0]:
					_bx(geo, b, Vector3(sx * 1.47, 2.95, -L * 0.5 + 1.5 + k * (L - 3.0) / 5.0), Vector3(0.05, 3.2, 0.12), "veh_black")
			for sx in [-1.0, 1.0]:
				_bx(geo, b, Vector3(sx * 1.49, 2.9, 0), Vector3(0.08, 2.8, 4.0), "train_grey") # sliding door
			_long(geo, b, -L * 0.5, L * 0.5, [Vector2(-1.45, 4.55), Vector2(1.45, 4.55), Vector2(1.0, 4.85), Vector2(-1.0, 4.85)], "train_brown")
		"hopper":
			_bx(geo, b, Vector3(0, 1.2, 0), Vector3(2.6, 0.3, L), "veh_black", true)
			_long(geo, b, -L * 0.5 + 0.4, L * 0.5 - 0.4, [Vector2(-1.5, 2.2), Vector2(-0.4, 1.4), Vector2(0.4, 1.4), Vector2(1.5, 2.2), Vector2(1.5, 4.0), Vector2(-1.5, 4.0)], "train_hopper")
			for k in range(4):
				_bx(geo, b, Vector3(0, 1.1, -L * 0.5 + 2.2 + k * (L - 4.4) / 3.0), Vector3(1.0, 0.6, 1.0), "train_grey")
			for k in range(5):
				for sx in [-1.0, 1.0]:
					_bx(geo, b, Vector3(sx * 1.52, 3.1, -L * 0.5 + 1.2 + k * (L - 2.4) / 4.0), Vector3(0.06, 1.8, 0.14), "veh_black")
		"flat", "flat_empty":
			_bx(geo, b, Vector3(0, 1.25, 0), Vector3(2.8, 0.3, L), "veh_black", true, true)
			for sx in [-1.0, 1.0]:
				_bx(geo, b, Vector3(sx * 1.28, 1.0, 0), Vector3(0.2, 0.3, L - 1.0), "train_grey") # (2 cm in from the frame's side: flush, it flickered)
			if kind == "flat" and not container_mats.is_empty():
				var n: int = rng.randi_range(1, 2)
				for i in range(n):
					var cz: float = 0.0 if n == 1 else (-3.08 if i == 0 else 3.08)
					geo.box_xf(b * Transform3D(Basis(), Vector3(0, 1.4 + 1.295, cz)), Vector3(2.44, 2.59, 12.19 if n == 1 else 6.06), container_mats[rng.randi() % container_mats.size()])
		"torpedo":
			# Torpedo ladle car: a refractory-lined vessel carrying hot
			# metal from the blast furnace, on two big bogie groups.
			for ez in [-1.0, 1.0]:
				_bx(geo, b, Vector3(0, 1.5, ez * 9.0), Vector3(2.8, 0.8, 5.0), "veh_black", true)
			var prof: Array = [Vector2(0.4, 0), Vector2(1.3, 1.8), Vector2(1.8, 5.0), Vector2(1.9, 8.0), Vector2(1.8, 11.0), Vector2(1.3, 14.2), Vector2(0.4, 16.0)]
			var shell: String = "veh_rust"
			var a: Vector3 = b * Vector3(0, 3.6, -8.0)
			var c: Vector3 = b * Vector3(0, 3.6, 8.0)
			for i in range(prof.size() - 1):
				var p0: Vector2 = prof[i]
				var p1: Vector2 = prof[i + 1]
				geo.cone(a.lerp(c, p0.y / 16.0), a.lerp(c, p1.y / 16.0), p0.x, p1.x, shell, 16)
			_bx(geo, b, Vector3(0, 5.6, 0), Vector3(1.4, 0.4, 1.4), "veh_black")
	if trains_v2:
		_train_detail(geo, b, kind, L, bogie)
	return L

## The extra detail of _train_detail (2026-10-14, on; SH_TRAINS_OLD=1 for the old trains).
static var trains_v2: bool = not OS.has_environment("SH_TRAINS_OLD") # (approved 2026-10-14; SH_TRAINS_OLD shows the old trains)

## A ladder on a flat face whose outward normal is along z (end walls):
## two uprights and rungs, 7 cm deep, resting on the face at z = zf (sn
## = which way is out). x0 = centre across, y0..y1 = bottom/top.
static func _end_ladder(geo: Geo, b: Transform3D, x0: float, y0: float, y1: float, zf: float, sn: float) -> void:
	var zc: float = zf + sn * 0.035
	for dx in [-0.17, 0.17]:
		_bx(geo, b, Vector3(x0 + dx, (y0 + y1) * 0.5, zc), Vector3(0.04, y1 - y0, 0.07), "veh_steel")
	var y: float = y0 + 0.2
	while y < y1 - 0.05:
		_bx(geo, b, Vector3(x0, y, zc), Vector3(0.34, 0.035, 0.07), "veh_steel")
		y += 0.28

## Window frames and rubber seals over a _windows band (same loop, so
## the panes line up): a dark strip along the top and bottom and an edge
## strip each side of every pane, all 5 cm thick on the 2.95 m body
## (3 cm proud of the glass: flush, it flickered).
static func _window_frames(geo: Geo, b: Transform3D, z0: float, z1: float, y0: float, y1: float, pane: float, pillar: float) -> void:
	var z: float = z0
	var glass: bool = false
	for sx in [-1.0, 1.0]:
		_bx(geo, b, Vector3(sx * 1.5, y0 + 0.04, (z0 + z1) * 0.5), Vector3(0.05, 0.08, z1 - z0), "veh_black")
		_bx(geo, b, Vector3(sx * 1.5, y1 - 0.04, (z0 + z1) * 0.5), Vector3(0.05, 0.08, z1 - z0), "veh_black")
	while z < z1 - 0.01:
		var l: float = minf((pane if glass else pillar), z1 - z)
		if glass:
			for sx in [-1.0, 1.0]:
				for ze in [z + 0.02, z + l - 0.02]:
					_bx(geo, b, Vector3(sx * 1.5, (y0 + y1) * 0.5, ze), Vector3(0.05, y1 - y0, 0.05), "veh_black")
		z += l
		glass = not glass

## Bogie details, brake hoses and couplings, roof boxes, lamps, ladders,
## handrails (2026-10-14). Every piece overlaps the body or
## a neighbour (nothing floats); overlays stand 3-5 cm proud of the
## surface they sit on (flush ones flickered on the cars).
static func _train_detail(geo: Geo, b: Transform3D, kind: String, L: float, bogie: float) -> void:
	var h: float = L * 0.5
	var electric: bool = kind == "loco" or kind.begins_with("ice")
	# --- bogies: axles, brake discs, coil springs, axle boxes, damper ---
	for bz in [-bogie, bogie]:
		for az in [-0.95, 0.95]:
			geo.cylinder(b * Vector3(-0.74, 0.46, bz + az), b * Vector3(0.74, 0.46, bz + az), 0.07, "veh_steel", 8, false, true, false)
			for sx in [-0.4, 0.4]:
				geo.cylinder(b * Vector3(sx - 0.015, 0.46, bz + az), b * Vector3(sx + 0.015, 0.46, bz + az), 0.3, "veh_chrome", 12, false, true, false)
		for sx in [-1.0, 1.0]:
			for az in [-0.95, 0.95]:
				# Axle box housing around the existing journal cap, spring on top.
				_bx(geo, b, Vector3(sx * 1.25, 0.46, bz + az), Vector3(0.12, 0.3, 0.3), "veh_steel")
				geo.cylinder(b * Vector3(sx * 1.22, 0.58, bz + az), b * Vector3(sx * 1.22, 0.86, bz + az), 0.1, "veh_steel", 8, false, true, false)
				for k in range(3):
					var yk: float = 0.62 + 0.09 * k
					geo.cylinder(b * Vector3(sx * 1.22, yk, bz + az), b * Vector3(sx * 1.22, yk + 0.025, bz + az), 0.125, "veh_chrome", 8, false, true, false)
			# Yaw damper between the two springs, along the side beam.
			geo.cylinder(b * Vector3(sx * 1.18, 0.72, bz - 0.4), b * Vector3(sx * 1.18, 0.72, bz + 0.4), 0.05, "veh_chrome", 6, false, true, false)
	# --- ends: couplings and brake hoses ---
	var ends: Array = [-1.0, 1.0]
	if kind == "ice_head":
		ends = [1.0]
	elif kind == "ice_tail":
		ends = [-1.0]
	for ez in ends:
		if electric or kind == "coach":
			if kind == "coach" or kind == "ice":
				# Centre coupler (Scharfenberg-style cone) under the gangway.
				geo.cone(b * Vector3(0, 1.0, ez * (h - 0.1)), b * Vector3(0, 1.0, ez * (h + 0.55)), 0.16, 0.1, "veh_steel", 8, false, false)
				for sx in [-0.35, 0.35]:
					geo.cylinder(b * Vector3(sx, 1.2, ez * h), b * Vector3(sx, 0.85, ez * (h + 0.3)), 0.03, "veh_black", 6, false, true, false)
			else:
				geo.cone(b * Vector3(0, 1.0, ez * (h - 0.1)), b * Vector3(0, 1.0, ez * (h + 0.55)), 0.16, 0.1, "veh_steel", 8, false, false)
		else:
			# Hook + screw coupling between the buffers, red/black air hoses.
			_bx(geo, b, Vector3(0, 0.95, ez * (h + 0.1)), Vector3(0.14, 0.16, 0.5), "veh_steel")
			geo.cylinder(b * Vector3(0, 0.95, ez * (h + 0.3)), b * Vector3(0, 0.7, ez * (h + 0.3)), 0.035, "veh_steel", 6, false, true, false)
			geo.cylinder(b * Vector3(0, 0.7, ez * (h + 0.1)), b * Vector3(0, 0.7, ez * (h + 0.42)), 0.055, "veh_chrome", 8, false, true, false)
			for sx in [-0.4, 0.4]:
				var hose: String = "train_red" if sx < 0.0 else "veh_black"
				geo.cylinder(b * Vector3(sx, 1.0, ez * (h + 0.0)), b * Vector3(sx, 0.72, ez * (h + 0.3)), 0.035, hose, 6, false, true, false)
				_bx(geo, b, Vector3(sx, 0.7, ez * (h + 0.32)), Vector3(0.08, 0.08, 0.08), "veh_steel")
	# --- per kind ---
	match kind:
		"loco":
			var zc: float = h - 0.3
			for pz in [-4.0, 4.0]:
				# Pantograph: insulators, contact strips on the head.
				for sx in [-0.5, 0.5]:
					geo.cylinder(b * Vector3(sx, 4.0, pz), b * Vector3(sx, 4.32, pz), 0.07, "train_white", 8, false, true, false)
				geo.beam(b * Vector3(0.18, 4.1, pz + 0.05), b * Vector3(0.18, 5.2, pz + 1.4), Vector2(0.04, 0.04), "veh_steel", false, false)
				geo.beam(b * Vector3(-0.18, 4.1, pz + 0.05), b * Vector3(-0.18, 5.2, pz + 1.4), Vector2(0.04, 0.04), "veh_steel", false, false)
				for dz in [-0.07, 0.07]:
					_bx(geo, b, Vector3(0, 5.28, pz + 1.4 + dz), Vector3(1.7, 0.05, 0.05), "veh_black")
			# Roof: resistor grid box and a vent between the pantographs.
			_bx(geo, b, Vector3(0, 4.17, 0), Vector3(1.6, 0.25, 2.6), "train_roof")
			for k in range(5):
				_bx(geo, b, Vector3(0, 4.31, -1.0 + k * 0.5), Vector3(1.4, 0.04, 0.08), "veh_black")
			for ez in [-1.0, 1.0]:
				var tip: float = ez * zc
				# Windscreen wipers on the sloped cab glass (slope: 0.55 m
				# along z for 0.95 m up; 4 cm out of the glass).
				for wx in [-0.9, -0.1]:
					var ta: Vector3 = _loco_slope(tip, ez, wx, 0.1)
					var tb: Vector3 = _loco_slope(tip, ez, wx + 0.55, 0.62)
					geo.beam(b * ta, b * tb, Vector2(0.03, 0.03), "veh_black", false, false)
					_bx(geo, b, ta, Vector3(0.1, 0.1, 0.1), "veh_black")
				for wx in [0.9]:
					_bx(geo, b, _loco_slope(tip, ez, wx, 0.1), Vector3(0.1, 0.1, 0.1), "veh_black")
				# Cab glass frame: a dark strip along the top edge of the glass.
				_bx(geo, b, Vector3(0, 3.58, tip - ez * 0.85), Vector3(2.9, 0.06, 0.1), "veh_black")
				# Lamps: top lamp, red tail lamps, number plate; buffer beam.
				_bx(geo, b, Vector3(0, 3.62, tip - ez * 0.9), Vector3(0.3, 0.14, 0.12), "veh_head")
				for sx in [-1.1, 1.1]:
					_bx(geo, b, Vector3(sx, 1.75, tip + ez * 0.02), Vector3(0.2, 0.12, 0.08), "veh_tail")
				_bx(geo, b, Vector3(0, 1.55, tip + ez * 0.02), Vector3(0.5, 0.14, 0.08), "veh_plate")
				# Cab door on the side, outline + handrail + step.
				var dz: float = ez * (zc - 1.0)
				_door_outline(geo, b, dz, 1.5, 2.55, 0.9, 1.47)
				# Handrail beside the door
				_side_rail(geo, b, dz + ez * 0.62, 1.6, 2.5, 1.47)
		"shunter":
			var zf: float = -h + 0.7 # hood front face z = -L/2+... (hood is L-4.6 long about z=-1.6)
			zf = -1.6 - (L - 4.6) * 0.5
			for sx in [-0.6, 0.6]:
				_bx(geo, b, Vector3(sx, 1.9, zf - 0.02), Vector3(0.2, 0.14, 0.08), "veh_head")
			# Cab windows (the old glass box was buried in the cab): front, sides, back.
			var zcab: float = L * 0.5 - 1.95
			_bx(geo, b, Vector3(0, 3.4, h - 3.4), Vector3(2.0, 0.9, 0.06), "veh_glass")
			_bx(geo, b, Vector3(0, 3.4, h - 0.5), Vector3(2.0, 0.9, 0.06), "veh_glass")
			for sx in [-1.0, 1.0]:
				_bx(geo, b, Vector3(sx * 1.4, 3.4, zcab), Vector3(0.06, 0.9, 2.0), "veh_glass")
				_bx(geo, b, Vector3(sx * 1.43, 3.88, zcab), Vector3(0.05, 0.06, 2.1), "veh_black")
				_bx(geo, b, Vector3(sx * 1.43, 2.92, zcab), Vector3(0.05, 0.06, 2.1), "veh_black")
			geo.beam(b * Vector3(-0.6, 3.0, h - 3.4 - 0.04), b * Vector3(0.3, 3.75, h - 3.4 - 0.04), Vector2(0.03, 0.03), "veh_black", false, false)
			# Rear lamps, beacon, handrails along the hood.
			for sx in [-0.9, 0.9]:
				_bx(geo, b, Vector3(sx, 1.9, h - 0.5 + 0.02), Vector3(0.2, 0.14, 0.08), "veh_tail")
			geo.cylinder(b * Vector3(0.9, 4.15, h - 1.5), b * Vector3(0.9, 4.45, h - 1.5), 0.1, "veh_amber", 8, false, true, false)
			for sx in [-1.0, 1.0]:
				for pz in [zf + 0.3, -1.6, 1.4]:
					_bx(geo, b, Vector3(sx * 1.3, 1.7, pz), Vector3(0.04, 0.7, 0.04), "veh_steel")
				_bx(geo, b, Vector3(sx * 1.3, 2.05, (zf + 1.4) * 0.5), Vector3(0.04, 0.04, 1.4 - zf), "veh_steel")
			_door_outline(geo, b, h - 1.95, 1.5, 3.2, 1.0, 1.4)
		"ice_head", "ice_tail":
			var sn: float = -1.0 if kind == "ice_head" else 1.0
			var zb: float = sn * (h - 5.0)
			var za: float = -sn * h
			var lo: float = minf(za, zb)
			var hi: float = maxf(za, zb)
			_window_frames(geo, b, lo + 0.6, hi - 0.6, 2.45, 3.3, 1.8, 0.45)
			# Door on each side at the passenger end, with handrails.
			var dz: float = za + (-sn) * 0.0
			dz = (za + (1.4 if za < zb else -1.4))
			_door_outline(geo, b, dz, 1.3, 3.25, 1.1, 1.47)
			_roof_boxes(geo, b, lo + 3.0, hi - 3.0)
			# Pantograph contact strips (the head's pantograph exists).
			for dzz in [-0.07, 0.07]:
				_bx(geo, b, Vector3(0, 5.28, -sn * 0.8 + dzz), Vector3(1.7, 0.05, 0.05), "veh_black")
			# Red tail marker: a strip across the nose tip.
			var zt: float = sn * h
			for sx in [-0.3, 0.3]:
				_bx(geo, b, Vector3(sx, 1.35, zt - sn * 0.02), Vector3(0.25, 0.1, 0.1), "veh_tail")
		"ice", "coach":
			_window_frames(geo, b, -h + 2.6, h - 2.6, 2.45, 3.3, 1.9, 0.5)
			_roof_boxes(geo, b, -h + 3.0, h - 3.0)
			for ez in [-1.0, 1.0]:
				var dz: float = ez * (h - 1.5)
				_door_outline(geo, b, dz, 1.2, 3.2, 1.2, 1.495)
				# Steps below the door, handrails each side.
				for sx in [-1.0, 1.0]:
					_bx(geo, b, Vector3(sx * 1.45, 1.12, dz), Vector3(0.3, 0.1, 0.9), "veh_black")
					for zo in [-0.75, 0.75]:
						_side_rail_side(geo, b, sx, dz + zo, 1.35, 3.1, 1.495)
			# Underfloor boxes (battery, air, tanks) below the underframe.
			for k in range(-2, 3):
				for sx in [-0.8, 0.8]:
					if (k + (1 if sx > 0.0 else 0)) % 2 != 0 and k != 0:
						_bx(geo, b, Vector3(sx, 0.62, k * 3.2), Vector3(0.7, 0.4, 2.0), "train_grey")
			_bx(geo, b, Vector3(0, 0.5, 0), Vector3(1.0, 0.3, 2.5), "veh_steel")
		"tank":
			# Straps round the tank (2 cm bigger than the shell), saddle ribs.
			for zz in [-L * 0.5 + 2.0, -3.0, 3.0, L * 0.5 - 2.0]:
				geo.cylinder(b * Vector3(0, 2.8, zz - 0.04), b * Vector3(0, 2.8, zz + 0.04), 1.49, "veh_black", 18, false, true, false)
			# Side ladders from the frame to the walkway level.
			for ez in [-1.0, 1.0]:
				_side_ladder(geo, b, ez * (h - 2.6), 1.2, 2.9)
			# Dome: bolted lid with a ring, safety valve.
			geo.cylinder(b * Vector3(0, 4.58, 0), b * Vector3(0, 4.66, 0), 0.55, "veh_steel", 10, false, true, false)
			geo.cylinder(b * Vector3(0.0, 4.6, 0), b * Vector3(0.0, 4.95, 0), 0.12, "veh_steel", 8, false, true, false)
			_under_air(geo, b, h)
			for ez in [-1.0, 1.0]:
				_end_ladder_frame(geo, b, ez * h)
		"box":
			for sx in [-1.0, 1.0]:
				# Door rail above and below the sliding door (5 cm proud), handle, rooflight.
				_bx(geo, b, Vector3(sx * 1.5, 4.42, 0), Vector3(0.1, 0.06, 6.0), "veh_black")
				_bx(geo, b, Vector3(sx * 1.54, 2.9, 1.9), Vector3(0.06, 0.8, 0.06), "veh_steel")
				_bx(geo, b, Vector3(sx * 1.5, 1.5, 0), Vector3(0.1, 0.06, 6.0), "veh_black")
				_bx(geo, b, Vector3(sx * 1.47, 4.45, -L * 0.5 + 0.9), Vector3(0.05, 0.14, 0.8), "veh_black") # vent slot
				_bx(geo, b, Vector3(sx * 1.47, 4.45, L * 0.5 - 0.9), Vector3(0.05, 0.14, 0.8), "veh_black")
			for ez in [-1.0, 1.0]:
				_end_ladder(geo, b, -ez * 1.0, 1.3, 4.6, ez * h, ez)
				# Hand brake wheel on a post at the other corner.
				_bx(geo, b, Vector3(ez * 1.0, 3.0, ez * (h + 0.04)), Vector3(0.05, 0.05, 0.08), "veh_black")
			geo.cylinder(b * Vector3(1.0, 3.0, -h - 0.03), b * Vector3(1.0, 3.0, -h - 0.09), 0.2, "veh_black", 10, false, true, false)
			_under_air(geo, b, h)
		"hopper":
			var zw: float = h - 0.4
			for ez in [-1.0, 1.0]:
				_end_ladder(geo, b, -ez * 0.9, 2.3, 4.0, ez * zw, ez)
				# End platform with handrail on the top rim.
				_bx(geo, b, Vector3(0, 3.95, ez * (zw + 0.25)), Vector3(2.8, 0.05, 0.5), "veh_steel")
				_bx(geo, b, Vector3(0, 4.45, ez * (zw + 0.48)), Vector3(2.8, 0.04, 0.04), "veh_steel")
				for sx in [-1.35, 0.0, 1.35]:
					_bx(geo, b, Vector3(sx, 4.2, ez * (zw + 0.48)), Vector3(0.04, 0.55, 0.04), "veh_steel")
			# Top rim, hatches over the four outlets.
			for sx in [-1.0, 1.0]:
				_bx(geo, b, Vector3(sx * 1.5, 4.0, 0), Vector3(0.1, 0.1, L - 0.8), "veh_steel")
			for k in range(4):
				var hz: float = -L * 0.5 + 2.2 + k * (L - 4.4) / 3.0
				_bx(geo, b, Vector3(0, 4.03, hz), Vector3(0.9, 0.08, 0.9), "veh_steel")
				_bx(geo, b, Vector3(0, 4.1, hz), Vector3(0.3, 0.06, 0.3), "veh_black")
				_bx(geo, b, Vector3(0.0, 1.0, hz), Vector3(1.2, 0.08, 1.2), "veh_steel")
		"flat", "flat_empty":
			# Stakes along both sides of the deck, container twist locks.
			for sx in [-1.0, 1.0]:
				for k in range(8):
					_bx(geo, b, Vector3(sx * 1.38, 1.9, -h + 1.4 + k * (L - 2.8) / 7.0), Vector3(0.06, 1.0, 0.06), "veh_black")
			for ez in [-1.0, 1.0]:
				for sx in [-1.1, 1.1]:
					_bx(geo, b, Vector3(sx, 1.46, ez * (h - 0.4)), Vector3(0.16, 0.12, 0.2), "veh_steel")
			# Hand brake: post and wheel at one end.
			_bx(geo, b, Vector3(1.25, 1.8, -h + 0.3), Vector3(0.05, 0.9, 0.05), "veh_black")
			geo.cylinder(b * Vector3(1.25, 2.25, -h + 0.3), b * Vector3(1.25, 2.28, -h + 0.3), 0.2, "veh_black", 10, false, true, false)
			_end_ladder_frame(geo, b, -h)
			_end_ladder_frame(geo, b, h)
			_under_air(geo, b, h)
		"torpedo":
			for ez in [-1.0, 1.0]:
				for sx in [-1.0, 1.0]:
					_bx(geo, b, Vector3(sx * 1.2, 2.0, ez * 9.0), Vector3(0.06, 0.9, 0.06), "veh_steel") # stanchions
					_bx(geo, b, Vector3(sx * 1.2, 1.9, ez * 6.6), Vector3(0.06, 0.6, 0.06), "veh_steel")
				_bx(geo, b, Vector3(-1.2, 2.3, ez * 7.8), Vector3(0.04, 0.04, 2.6), "veh_steel")
				_bx(geo, b, Vector3(1.2, 2.3, ez * 7.8), Vector3(0.04, 0.04, 2.6), "veh_steel")

## A point on the loco's sloped cab glass (x across, t 0..1 up the slope),
## 4 cm out of the glass.
static func _loco_slope(tip: float, ez: float, x: float, t: float) -> Vector3:
	return Vector3(x, 2.6 + 0.95 * t + 0.02, tip - ez * 0.55 * t + ez * 0.035)

## Door outline on both sides of a coach/loco: four dark strips round
## a door (centre dz, y0..y1, width w), proud of the body face at
## |x| = xs by 4 cm (3 cm proud: flush, it flickered).
static func _door_outline(geo: Geo, b: Transform3D, dz: float, y0: float, y1: float, w: float, xs: float) -> void:
	var yc: float = (y0 + y1) * 0.5
	for sx in [-1.0, 1.0]:
		var x: float = sx * (xs + 0.02)
		_bx(geo, b, Vector3(x, y0 + 0.02, dz), Vector3(0.05, 0.05, w + 0.1), "veh_black")
		_bx(geo, b, Vector3(x, y1 - 0.02, dz), Vector3(0.05, 0.05, w + 0.1), "veh_black")
		_bx(geo, b, Vector3(x, yc, dz - w * 0.5), Vector3(0.05, y1 - y0, 0.05), "veh_black")
		_bx(geo, b, Vector3(x, yc, dz + w * 0.5), Vector3(0.05, y1 - y0, 0.05), "veh_black")
		_bx(geo, b, Vector3(x, yc, dz), Vector3(0.05, 0.04, w - 0.05), "veh_black") # seam (centre of a double door)

## Vertical chrome handrail on both sides at z, with stubs into the body.
static func _side_rail(geo: Geo, b: Transform3D, z: float, y0: float, y1: float, xs: float) -> void:
	for sx in [-1.0, 1.0]:
		_side_rail_side(geo, b, sx, z, y0, y1, xs)

static func _side_rail_side(geo: Geo, b: Transform3D, sx: float, z: float, y0: float, y1: float, xs: float) -> void:
	var xr: float = xs + 0.09
	geo.cylinder(b * Vector3(sx * xr, y0, z), b * Vector3(sx * xr, y1, z), 0.022, "veh_chrome", 6, false, true, false)
	for y in [y0 + 0.05, y1 - 0.05]:
		geo.cylinder(b * Vector3(sx * (xs - 0.02), y, z), b * Vector3(sx * xr, y, z), 0.018, "veh_chrome", 6, false, true, false)

## Roof equipment on the (flat, 1.2 m wide) roof top at y 4.18: AC
## units and a vent row, between z0 and z1.
static func _roof_boxes(geo: Geo, b: Transform3D, z0: float, z1: float) -> void:
	var n: int = maxi(2, int((z1 - z0) / 6.0))
	for k in range(n):
		var zc: float = z0 + (k + 0.5) * (z1 - z0) / n
		_bx(geo, b, Vector3(0, 4.3, zc), Vector3(1.0, 0.24, 2.4), "train_roof")
		for j in range(4):
			_bx(geo, b, Vector3(0, 4.43, zc - 0.9 + j * 0.6), Vector3(0.8, 0.04, 0.1), "veh_black")

## Wagon side ladder at z, from the frame (y0) to y1 on the tank flank:
## two uprights 1.55 m out, brackets at both ends reaching the shell/frame.
static func _side_ladder(geo: Geo, b: Transform3D, z: float, y0: float, y1: float) -> void:
	for sx in [-1.0, 1.0]:
		for dz in [-0.2, 0.2]:
			_bx(geo, b, Vector3(sx * 1.56, (y0 + y1) * 0.5, z + dz), Vector3(0.04, y1 - y0, 0.04), "veh_steel")
			_bx(geo, b, Vector3(sx * 1.45, y0 + 0.1, z + dz), Vector3(0.24, 0.05, 0.05), "veh_steel") # bracket to the frame
			_bx(geo, b, Vector3(sx * 1.48, 2.75, z + dz), Vector3(0.2, 0.05, 0.05), "veh_steel") # bracket to the shell (widest point)
		var y: float = y0 + 0.35
		while y < y1 - 0.1:
			_bx(geo, b, Vector3(sx * 1.56, y, z), Vector3(0.04, 0.035, 0.4), "veh_steel")
			y += 0.3

## Frame end: a small step and a grab rail on the headstock, both sides.
static func _end_ladder_frame(geo: Geo, b: Transform3D, zf: float) -> void:
	var sn: float = signf(zf)
	for sx in [-1.0, 1.0]:
		_bx(geo, b, Vector3(sx * 1.25, 1.55, zf - sn * 0.05), Vector3(0.05, 0.4, 0.05), "veh_steel")
		_bx(geo, b, Vector3(sx * 1.25, 1.13, zf + sn * 0.12), Vector3(0.4, 0.05, 0.3), "veh_steel")

## Brake cylinder, air reservoir and the pipe joining them, hung under
## the frame's centre (the frame bottom is at y 1.05).
static func _under_air(geo: Geo, b: Transform3D, h: float) -> void:
	geo.cylinder(b * Vector3(-0.6, 0.93, -1.2), b * Vector3(-0.6, 0.93, 1.2), 0.22, "veh_steel", 10, false, true, false)
	geo.cylinder(b * Vector3(0.6, 0.95, -0.7), b * Vector3(0.6, 0.95, 0.7), 0.17, "veh_black", 10, false, true, false)
	geo.cylinder(b * Vector3(0.0, 1.0, -0.7), b * Vector3(0.0, 1.0, 0.7), 0.04, "veh_chrome", 6, false, true, false)
	_bx(geo, b, Vector3(0.0, 1.0, 0.0), Vector3(1.4, 0.06, 0.06), "veh_chrome")

## A whole train from x0 along x.
static func train(geo: Geo, x0: float, y: float, z: float, kinds: Array, rng: RandomNumberGenerator, container_mats: Array = []) -> void:
	var x: float = x0
	for k in kinds:
		x += rail(geo, x, y, z, k, rng, container_mats) + 0.9

# --- site machines -----------------------------------------------------------------

## Tracked excavator (~22 t): undercarriage, turning house with cab,
## boom, stick and bucket. yaw = house heading; reach = boom pose 0..1.
static func excavator(geo: Geo, p: Vector3, yaw: float, reach: float = 0.5, mat: String = "site_yellow") -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	for sx in [-1.0, 1.0]:
		geo.prism(xf * Transform3D(Basis(), Vector3(sx * 1.2, 0, 0)), [Vector2(-2.3, 0.0), Vector2(-2.7, 0.45), Vector2(-2.3, 0.95), Vector2(2.3, 0.95), Vector2(2.7, 0.45), Vector2(2.3, 0.0)], 0.6, "veh_black")
	_bx(geo, xf, Vector3(0, 1.15, 0), Vector3(1.8, 0.5, 2.2), "veh_black", true)
	var h: Transform3D = xf
	geo.box_xf(h * Transform3D(Basis(), Vector3(0, 1.9, 0.6)), Vector3(2.6, 1.1, 3.2), mat)
	geo.frustum(h * Transform3D(Basis(), Vector3(0, 2.1, 2.1)), Vector3(2.6, 1.5, 0.9), 2.5, 0.8, 0.0, "veh_black") # counterweight
	geo.box_xf(h * Transform3D(Basis(), Vector3(-0.75, 2.9, -0.5)), Vector3(1.0, 1.6, 1.4), "veh_glass")
	_bx(geo, h, Vector3(-0.75, 3.72, -0.5), Vector3(1.05, 0.08, 1.45), mat)
	var root: Vector3 = h * Vector3(0.35, 2.2, -0.9)
	var elbow: Vector3 = h * Vector3(0.35, 5.2 - reach * 1.5, -3.2 - reach * 1.5)
	var wrist: Vector3 = h * Vector3(0.35, 1.2 + (1.0 - reach) * 1.5, -5.4 - reach * 1.5)
	geo.beam(root, elbow, Vector2(0.55, 0.8), mat)
	geo.beam(elbow, wrist, Vector2(0.4, 0.55), mat)
	geo.beam(h * Vector3(0.35, 2.4, -1.3), elbow.lerp(root, 0.35), Vector2(0.16, 0.16), "veh_chrome", false)
	geo.box_xf(Transform3D(xf.basis, wrist + Vector3(0, -0.4, 0)), Vector3(1.1, 0.9, 1.0), "veh_steel")

## Road tipper (4-axle, 32 t) with a load of spoil.
static func tipper(geo: Geo, p: Vector3, yaw: float, paint: String, load_mat: String = "") -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	geo.prism(xf, [Vector2(-5.0, 1.0), Vector2(-5.05, 2.1), Vector2(-3.0, 2.1), Vector2(-3.0, 1.0)], 2.45, paint)
	geo.prism(xf, [Vector2(-5.05, 2.1), Vector2(-4.95, 3.1), Vector2(-4.0, 3.1), Vector2(-4.0, 2.1)], 2.42, "veh_glass")
	geo.prism(xf, [Vector2(-4.0, 2.1), Vector2(-4.0, 3.1), Vector2(-3.0, 3.1), Vector2(-3.0, 2.1)], 2.45, paint)
	geo.prism(xf, [Vector2(-4.95, 3.1), Vector2(-4.7, 3.45), Vector2(-3.0, 3.45), Vector2(-3.0, 3.1)], 2.45, paint)
	_bx(geo, xf, Vector3(0, 0.95, 0.2), Vector3(0.95, 0.35, 9.4), "veh_black", true)
	_bx(geo, xf, Vector3(0, 0.85, -5.0), Vector3(2.45, 0.45, 0.3), "veh_black", true)
	# Tipper body: sloping floor, tapered sides.
	geo.prism(xf, [Vector2(-2.8, 1.35), Vector2(-2.9, 2.9), Vector2(4.4, 2.9), Vector2(4.5, 1.35)], 2.5, "site_grey")
	if load_mat != "":
		geo.frustum(xf * Transform3D(Basis(), Vector3(0, 3.2, 0.8)), Vector3(2.3, 0.7, 7.0), 1.2, 5.0, 0.0, load_mat, false)
	for sx in [-1.0, 1.0]:
		_bx(geo, xf, Vector3(sx * 0.85, 1.4, -5.07), Vector3(0.35, 0.14, 0.04), "veh_head")
		for z in [-4.2, -2.9, 2.0, 3.35]:
			_wheel(geo, xf, Vector3(sx * 1.0, 0.52, z), 0.52, 0.42)

## Truck mixer with its drum (turned to the rear, like on the road).
static func mixer(geo: Geo, p: Vector3, yaw: float, paint: String) -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	geo.prism(xf, [Vector2(-4.4, 1.0), Vector2(-4.45, 2.1), Vector2(-2.6, 2.1), Vector2(-2.6, 1.0)], 2.45, paint)
	geo.prism(xf, [Vector2(-4.45, 2.1), Vector2(-4.35, 3.05), Vector2(-3.45, 3.05), Vector2(-3.45, 2.1)], 2.42, "veh_glass")
	geo.prism(xf, [Vector2(-3.45, 2.1), Vector2(-3.45, 3.05), Vector2(-2.6, 3.05), Vector2(-2.6, 2.1)], 2.45, paint)
	geo.prism(xf, [Vector2(-4.35, 3.05), Vector2(-4.1, 3.35), Vector2(-2.6, 3.35), Vector2(-2.6, 3.05)], 2.45, paint)
	_bx(geo, xf, Vector3(0, 0.95, 0.4), Vector3(0.95, 0.35, 8.4), "veh_black", true)
	var a: Vector3 = xf * Vector3(0, 2.3, -2.2)
	var c: Vector3 = xf * Vector3(0, 3.4, 3.8)
	var prof: Array = [Vector2(0.9, 0.0), Vector2(1.2, 0.12), Vector2(1.2, 0.55), Vector2(0.6, 1.0)]
	for i in range(prof.size() - 1):
		geo.cone(a.lerp(c, prof[i].y), a.lerp(c, prof[i + 1].y), prof[i].x, prof[i + 1].x, "site_orange" if i != 1 else "veh_plate", 16)
	_bx(geo, xf, Vector3(0, 3.6, 4.2), Vector3(0.9, 0.5, 0.9), "veh_steel") # hopper
	for sx in [-1.0, 1.0]:
		for z in [-3.7, 1.4, 2.7]:
			_wheel(geo, xf, Vector3(sx * 1.0, 0.52, z), 0.52, 0.42)

## Wheel loader: articulated body, big bucket.
static func wheel_loader(geo: Geo, p: Vector3, yaw: float, mat: String = "site_yellow") -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	geo.prism(xf, [Vector2(0.4, 0.9), Vector2(0.4, 2.3), Vector2(3.6, 2.1), Vector2(3.8, 0.9)], 2.4, mat)
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 3.0, 0.9)), Vector3(1.6, 1.8, 1.6), "veh_glass")
	_bx(geo, xf, Vector3(0, 3.95, 0.9), Vector3(1.8, 0.1, 1.8), mat)
	_bx(geo, xf, Vector3(0, 1.55, -1.4), Vector3(1.9, 1.3, 2.4), mat, true, true)
	for sx in [-0.6, 0.6]:
		geo.beam(xf * Vector3(sx, 2.1, -1.2), xf * Vector3(sx, 1.2, -3.6), Vector2(0.25, 0.4), mat)
	geo.prism(xf * Transform3D(Basis(), Vector3(0, 0, -3.9)), [Vector2(-0.6, 0.3), Vector2(0.4, 0.2), Vector2(0.5, 1.5), Vector2(-0.3, 1.6)], 3.0, "veh_steel")
	for sx in [-1.0, 1.0]:
		for z in [-1.7, 2.3]:
			_wheel(geo, xf, Vector3(sx * 1.25, 0.8, z), 0.8, 0.6)

## Mobile crane on its truck carrier, boom raised toward local -z.
static func mobile_crane(geo: Geo, p: Vector3, yaw: float, boom_len: float = 30.0, elev_deg: float = 55.0) -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	_bx(geo, xf, Vector3(0, 1.3, 0), Vector3(2.7, 1.0, 12.0), "site_yellow", true, true)
	geo.prism(xf, [Vector2(-6.0, 1.8), Vector2(-6.05, 3.1), Vector2(-4.4, 3.1), Vector2(-4.4, 1.8)], 1.2, "site_yellow")
	_bx(geo, xf, Vector3(-0.65, 2.6, -5.3), Vector3(1.22, 0.7, 1.4), "veh_glass")
	for sx in [-1.0, 1.0]:
		for z in [-4.5, -3.0, 2.0, 3.5, 5.0]:
			_wheel(geo, xf, Vector3(sx * 1.15, 0.6, z), 0.6, 0.5)
		for z in [-3.8, 4.4]:
			geo.beam(xf * Vector3(sx * 1.3, 1.1, z), xf * Vector3(sx * 3.6, 0.8, z), Vector2(0.35, 0.35), "site_yellow")
			_bx(geo, xf, Vector3(sx * 3.6, 0.2, z), Vector3(0.9, 0.2, 0.9), "veh_black", true)
	_bx(geo, xf, Vector3(0, 2.4, 2.4), Vector3(2.4, 1.2, 4.0), "site_yellow", true, true)
	var root: Vector3 = xf * Vector3(0, 3.2, 2.8)
	var dir: Vector3 = xf.basis * Vector3(0, sin(deg_to_rad(elev_deg)), -cos(deg_to_rad(elev_deg)))
	var tip: Vector3 = root + dir * boom_len
	geo.beam(root, root + dir * boom_len * 0.55, Vector2(1.0, 1.1), "site_yellow")
	geo.beam(root + dir * boom_len * 0.5, tip, Vector2(0.7, 0.8), "site_yellow")
	geo.beam(tip, Vector3(tip.x, maxf(p.y + 4.0, tip.y - boom_len * 0.5), tip.z), Vector2(0.05, 0.05), "veh_black", false, false)

static func boat(geo: Geo, p: Vector3, yaw: float, sail: bool) -> void:
	ensure_materials(geo)
	var xf := Transform3D(Basis(Vector3.UP, yaw), p)
	var L: float = 9.0 if sail else 7.0
	var pts: Array = []
	for i in range(8):
		var top: bool = i & 2
		var bow: bool = (i & 4) == 0
		var hw: float = (0.25 if bow else 1.4) * (1.0 if i & 1 else -1.0) * (1.0 if top else 0.55)
		pts.append(xf * Vector3(hw * (0.2 if bow and top else 1.0) if bow else hw, (0.9 if top else -0.4), -L * 0.5 if bow else L * 0.5))
	geo.hexa(pts, "boat_white")
	geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 0.92, 1.0)), Vector3(2.2, 0.05, L * 0.55), "boat_wood", false, false)
	if sail:
		geo.cylinder(xf * Vector3(0, 0.9, -0.5), xf * Vector3(0, 12.0, -0.5), 0.08, "veh_steel", 6, false)
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 1.8, 0.8)), Vector3(0.12, 0.12, 3.0), "veh_steel", false, false)
	else:
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 1.4, 0.4)), Vector3(2.0, 1.0, 2.2), "boat_white")
		geo.box_xf(xf * Transform3D(Basis(), Vector3(0, 1.55, -0.72)), Vector3(1.9, 0.6, 0.05), "veh_glass", false, false)
