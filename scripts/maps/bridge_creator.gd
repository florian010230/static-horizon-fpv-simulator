class_name BridgeCreator
extends RefCounted

## Creator: a road bridge over a river, along the road's own deck points
## (so it follows a gentle curve with the road). Styles, by span and
## seed: "beam" (concrete deck on abutments, piers in the river on
## longer spans), "arch" (a stone arch springing from the banks), "truss"
## (a steel through-truss - fly through its diagonals). The body is
## solid; the road surface itself is RoadCreator's. Now and then a
## shopping trolley lies in the water underneath.
##
##   BridgeCreator.build(geo, deck_pts, road_width, water_y, river_half, ground, rng, opts)
##     -> {"style": String, "views": [[name, eye, target], ...], "trolley": bool}
## deck_pts: road surface points from one bank to the other (y = road
## level); ground: Callable(x, z) -> ground height (the abutments reach it).
## opts: "style" to force one (labs: env SH_BRIDGE); "river_dir" (unit, ground plane) for the
## preview cameras under the bridge.
## Real numbers: deck slab ~1 m (beam), arch crown ~1 m below the road,
## parapets 0.9-1 m, a through-truss 4.5-6 m tall.

const TROLLEY_CHANCE: float = 0.12

static func build(geo: Geo, deck: Array[Vector3], road_width: float, water_y: float, river_half: float, ground: Callable, rng: RandomNumberGenerator, opts: Dictionary = {}) -> Dictionary:
	if not geo.has_material("br_concrete"):
		geo.add_material("br_concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.08, 1.08, 1.05), 4.0))
		geo.add_material("br_stone", Geo.tex_mat(MapTextures.get_tex("rock"), Color(0.95, 0.9, 0.82), 2.5))
		geo.add_material("br_steel", Geo.flat_mat(Color.WHITE, 0.5, 0.4))
	var L: float = 0.0
	for i in range(1, deck.size()):
		L += deck[i].distance_to(deck[i - 1])
	var style: String = opts.get("style", OS.get_environment("SH_BRIDGE"))
	if style == "":
		var pick: Array = ["beam", "arch"] if L < 26.0 else ["beam", "arch", "truss", "truss"]
		style = pick[rng.randi() % pick.size()]
	var hw: float = road_width * 0.5 + 0.9
	if OS.has_environment("SH_PERF"):
		var g0: float = ground.call(deck[0].x, deck[0].z)
		var g1: float = ground.call(deck[-1].x, deck[-1].z)
		print("BRIDGE %s L=%.1f pts=%d deck %.2f..%.2f water %.2f ground at ends %.2f / %.2f, river half %.1f" % [style, L, deck.size(), deck[0].y, deck[-1].y, water_y, g0, g1, river_half])
	var mat: String = "br_stone" if style == "arch" else "br_concrete"
	# Where along the deck the channel is: the arch / the open span spans it.
	var open_half: float = river_half + TerrainCreator.BANK + 1.0
	var mid: float = L * 0.5
	var rows_top: Array = []
	var rows_l: Array = []
	var rows_r: Array = []
	var rows_bot: Array = []
	var centres: Array = []
	var d: float = 0.0
	for i in range(deck.size()):
		if i > 0:
			d += deck[i].distance_to(deck[i - 1])
		var tan: Vector3 = Route._tangent(deck, i)
		var right := Vector3(-tan.z, 0, tan.x)
		var c: Vector3 = deck[i]
		var top: float = c.y - 0.02
		var g: float = minf(ground.call(c.x, c.z), top) - 0.4
		var bot: float = g
		var u: float = (d - (mid - open_half)) / (2.0 * open_half) # 0..1 across the open span
		if style == "arch":
			if u > 0.0 and u < 1.0:
				var crown: float = top - 1.1
				var foot: float = water_y + 0.2
				bot = maxf(g, foot + (crown - foot) * sqrt(maxf(1.0 - (2.0 * u - 1.0) * (2.0 * u - 1.0), 0.0)))
		elif d > 2.5 and d < L - 2.5:
			bot = top - (0.8 if style == "truss" else 1.0)
		bot = minf(bot, top - 0.6)
		var lt: Vector3 = Vector3(c.x, top, c.z) - right * hw
		var rt: Vector3 = Vector3(c.x, top, c.z) + right * hw
		var lb: Vector3 = Vector3(lt.x, bot, lt.z)
		var rb: Vector3 = Vector3(rt.x, bot, rt.z)
		rows_top.append(PackedVector3Array([lt, rt]))
		rows_l.append(PackedVector3Array([lt, lb]))
		rows_r.append(PackedVector3Array([rt, rb]))
		rows_bot.append(PackedVector3Array([lb, rb]))
		centres.append(Vector3(c.x, (top + bot) * 0.5, c.z))
	geo.strip(rows_top, mat, true)
	geo.strip(rows_l, mat, true, centres)
	geo.strip(rows_r, mat, true, centres)
	geo.strip(rows_bot, mat, true, centres)
	for e in [0, deck.size() - 1]:
		var inward: Vector3 = (deck[1] - deck[0]) if e == 0 else (deck[e - 1] - deck[e])
		var cc: Vector3 = centres[e] + inward.normalized() * 1.0
		geo.strip([rows_top[e], rows_bot[e]], mat, true, [cc, cc])
	# Parapets (the truss has its own sides).
	if style != "truss":
		var ph: float = 0.85 if style == "arch" else 0.95
		var pw: float = 0.4 if style == "arch" else 0.3
		for s in [-1.0, 1.0]:
			var pp: Array[Vector3] = Route.offset_pts(deck, s * (hw - pw * 0.5))
			geo.sweep(pp, [Vector2(pw * 0.5, -0.05), Vector2(pw * 0.5, ph), Vector2(-pw * 0.5, ph), Vector2(-pw * 0.5, -0.05)], mat, true, true, false)
	else:
		_truss(geo, deck, hw, rng)
	# Piers in the river under a long beam bridge.
	if style == "beam" and L > 24.0:
		for f in ([0.5] if L < 40.0 else [0.36, 0.64]):
			var s: Array = Route.from_pts(deck).sample(L * f)
			var p: Vector3 = s[0]
			var t: Vector3 = s[1]
			var yaw: float = atan2(-t.x, -t.z)
			var bottom: float = water_y - 1.6
			geo.box(Vector3(p.x, (p.y - 1.0 + bottom) * 0.5, p.z), Vector3(hw * 1.6, p.y - 1.0 - bottom, 1.4), "br_concrete", yaw + PI * 0.5)
	# Views: under it along the river, and over it on the road.
	var ms: Array = Route.from_pts(deck).sample(mid)
	var mp: Vector3 = ms[0]
	var mt: Vector3 = ms[1]
	# Along the river (it need not cross square-on).
	var across: Vector3 = opts.get("river_dir", Vector3(-mt.z, 0, mt.x))
	var under := Vector3(mp.x, water_y, mp.z)
	var views: Array = [
		["bridge_" + style, under + across * 16.0 + Vector3(0, 1.5, 0), under + Vector3(0, 1.4, 0)],
		["bridge_" + style + "_side", under + across * 20.0 + mt * 16.0 + Vector3(0, 7.0, 0), under + Vector3(0, 2.5, 0)],
		["bridge_" + style + "_top", under + Vector3(0, 45.0, 0) + across * 2.0, under],
	]
	var trolley: bool = rng.randf() < TROLLEY_CHANCE or OS.has_environment("SH_TROLLEY")
	if trolley:
		var tp: Vector3 = under + across * rng.randf_range(-3.0, 3.0) + mt * (river_half - 1.2) * (-1.0 if rng.randf() < 0.5 else 1.0)
		_trolley(geo, Transform3D(Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.FORWARD, 1.35), tp + Vector3(0, 0.05, 0)))
		views.append(["trolley", tp + across * 5.0 + Vector3(0, 1.2, 0), tp])
	return {"style": style, "views": views, "trolley": trolley}

## A steel through-truss on both sides of the deck: bottom chord on the
## deck edge, top chord 5 m up, verticals and alternating diagonals
## every ~4.5 m, inclined end posts, cross bracing overhead.
static func _truss(geo: Geo, deck: Array[Vector3], hw: float, rng: RandomNumberGenerator) -> void:
	var paint: Color = [Color(0.3, 0.42, 0.36), Color(0.55, 0.22, 0.16), Color(0.45, 0.48, 0.52)][rng.randi() % 3]
	geo.tint = paint
	var route: Route = Route.from_pts(deck)
	var L: float = route.length()
	var panels: int = maxi(3, int(round(L / 4.5)))
	var H: float = 5.0
	var sides: Array = []
	for s in [-1.0, 1.0]:
		var lo: Array[Vector3] = []
		var hi: Array[Vector3] = []
		for k in range(panels + 1):
			var smp: Array = route.sample(L * k / panels)
			var t: Vector3 = smp[1]
			var right := Vector3(-t.z, 0, t.x)
			var p: Vector3 = (smp[0] as Vector3) + right * s * (hw - 0.15)
			lo.append(p + Vector3(0, 0.1, 0))
			hi.append(p + Vector3(0, H, 0))
		sides.append([lo, hi])
		var th := Vector2(0.28, 0.32)
		for k in range(panels):
			geo.beam(lo[k], lo[k + 1], th, "br_steel")
			if k >= 1 and k < panels - 1:
				geo.beam(hi[k], hi[k + 1], th, "br_steel")
			if k >= 1:
				geo.beam(lo[k], hi[k], Vector2(0.2, 0.2), "br_steel")
		# Inclined end posts and diagonals (Pratt: leaning toward the middle).
		geo.beam(lo[0], hi[1], th, "br_steel")
		geo.beam(lo[panels], hi[panels - 1], th, "br_steel")
		for k in range(1, panels - 1):
			if k < panels / 2:
				geo.beam(hi[k], lo[k + 1], Vector2(0.16, 0.16), "br_steel")
			else:
				geo.beam(lo[k], hi[k + 1], Vector2(0.16, 0.16), "br_steel")
		# Railing inside.
		geo.beam(lo[0] + Vector3(0, 1.0, 0), lo[panels] + Vector3(0, 1.0, 0), Vector2(0.08, 0.08), "br_steel", false)
	# Overhead cross beams at every top panel point.
	for k in range(1, panels):
		geo.beam(sides[0][1][k], sides[1][1][k], Vector2(0.22, 0.26), "br_steel")
	geo.tint = Color.WHITE

## A shopping trolley lying on its side in the shallows.
static func _trolley(geo: Geo, f: Transform3D) -> void:
	geo.tint = Color(0.75, 0.77, 0.8)
	var w: float = 0.28
	var l: float = 0.45
	var corners: Array[Vector3] = [Vector3(-w, 0.35, -l), Vector3(w, 0.35, -l), Vector3(w, 0.35, l), Vector3(-w, 0.35, l)]
	var tops: Array[Vector3] = [Vector3(-w - 0.04, 0.95, -l - 0.1), Vector3(w + 0.04, 0.95, -l - 0.1), Vector3(w + 0.04, 0.95, l + 0.05), Vector3(-w - 0.04, 0.95, l + 0.05)]
	for i in range(4):
		var j: int = (i + 1) % 4
		geo.beam(f * corners[i], f * corners[j], Vector2(0.02, 0.02), "br_steel", false)
		geo.beam(f * tops[i], f * tops[j], Vector2(0.025, 0.025), "br_steel", false)
		geo.beam(f * corners[i], f * tops[i], Vector2(0.02, 0.02), "br_steel", false)
	# Wire mesh: a few bars per side.
	for k in range(1, 5):
		var a: float = k / 5.0
		geo.beam(f * corners[0].lerp(corners[1], a), f * tops[0].lerp(tops[1], a), Vector2(0.01, 0.01), "br_steel", false)
		geo.beam(f * corners[2].lerp(corners[3], a), f * tops[2].lerp(tops[3], a), Vector2(0.01, 0.01), "br_steel", false)
		geo.beam(f * corners[1].lerp(corners[2], a), f * tops[1].lerp(tops[2], a), Vector2(0.01, 0.01), "br_steel", false)
		geo.beam(f * corners[3].lerp(corners[0], a), f * tops[3].lerp(tops[0], a), Vector2(0.01, 0.01), "br_steel", false)
	# Handle, chassis, wheels.
	geo.beam(f * Vector3(-w - 0.05, 1.0, -l - 0.18), f * Vector3(w + 0.05, 1.0, -l - 0.18), Vector2(0.035, 0.035), "br_steel", false)
	geo.beam(f * Vector3(0, 0.15, -l), f * Vector3(0, 0.15, l), Vector2(0.03, 0.03), "br_steel", false)
	geo.tint = Color(0.1, 0.1, 0.1)
	for c in [Vector3(-w, 0.06, -l), Vector3(w, 0.06, -l), Vector3(-w, 0.06, l), Vector3(w, 0.06, l)]:
		geo.cylinder(f * (c + Vector3(-0.02, 0, 0)), f * (c + Vector3(0.02, 0, 0)), 0.06, "br_steel", 8, false)
	geo.tint = Color.WHITE
