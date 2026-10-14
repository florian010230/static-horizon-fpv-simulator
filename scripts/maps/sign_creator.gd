class_name SignCreator
extends RefCounted

## Road signs (2026-10-14, user: "better and more street signs"), the
## German ones (StVO / VzKat) at their real sizes (Groesse 2: triangle
## 900 mm, round, octagon and square 600 mm), each a plate in layers - a
## grey back, the coloured face, the inner field, the symbol, the text
## (Label3D, flat on the plate - TextCheck) - on a 60 mm galvanised post
## with clamps. Several signs can share a post, top to bottom.
##   SignCreator.post(geo, foot, yaw, [["give_way"], ["speed", "30"]])
## yaw: the way the faces look (toward the traffic they speak to).
## Kinds: give_way (205), stop (206), priority (306), speed (274, text =
## the limit), no_entry (267), dead_end (357), crossing (350), parking
## (314), danger (101), no_drones (a drone-ban plate: the round ban
## sign over a quad, text = the line under it), direction (yellow arrow board: text = place,
## "km" in text2), street (a street-name plate: text).

const BOTTOM: float = 2.1 ## lower edge of the lowest sign over the ground
const GAP: float = 0.06
const LAYER: float = 0.008 ## each layer this far in front of the last

static func ensure_materials(g: Geo) -> void:
	if g.has_material("sg_red"):
		return
	g.add_material("sg_red", Geo.flat_mat(Color(0.78, 0.1, 0.1), 0.5))
	g.add_material("sg_white", Geo.flat_mat(Color(0.96, 0.96, 0.94), 0.5))
	g.add_material("sg_blue", Geo.flat_mat(Color(0.08, 0.3, 0.62), 0.5))
	g.add_material("sg_yellow", Geo.flat_mat(Color(0.98, 0.78, 0.05), 0.5))
	g.add_material("sg_black", Geo.flat_mat(Color(0.06, 0.06, 0.06), 0.6))
	g.add_material("sg_back", Geo.flat_mat(Color(0.58, 0.6, 0.62), 0.4, 0.5))
	g.add_material("sg_steel", Geo.flat_mat(Color(0.66, 0.68, 0.7), 0.4, 0.6))
	g.detail_prefixes.append("sg_")

## Height of each kind's plate (m), for stacking.
static func height_of(kind: String) -> float:
	match kind:
		"give_way", "danger": return 0.78
		"priority": return 0.85
		"direction": return 0.32
		"no_drones": return 0.78
		"street": return 0.17
	return 0.6

static func post(g: Geo, foot: Vector3, yaw: float, signs: Array, bottom: float = BOTTOM) -> void:
	ensure_materials(g)
	g.begin_object("sign")
	var total: float = 0.0
	for s: Array in signs:
		total += height_of(s[0]) + GAP
	var top: float = bottom + total
	var y0: float = g.sunk([foot], foot.y)
	g.cylinder(Vector3(foot.x, y0 - 0.3, foot.z), foot + Vector3(0, top + 0.05, 0), 0.03, "sg_steel", 8)
	g.cylinder(foot + Vector3(0, top + 0.05, 0), foot + Vector3(0, top + 0.08, 0), 0.034, "sg_black", 8) # cap
	var basis := Basis(Vector3.UP, yaw)
	var y: float = top
	for s: Array in signs:
		var h: float = height_of(s[0])
		var c: Vector3 = foot + Vector3(0, y - h * 0.5, 0) + basis * Vector3(0, 0, 0.045)
		# Two clamps from the post to the plate's back.
		for dy in [-h * 0.25, h * 0.25]:
			g.box_xf(Transform3D(basis, foot + Vector3(0, y - h * 0.5 + dy, 0) + basis * Vector3(0, 0, 0.02)), Vector3(0.09, 0.04, 0.05), "sg_steel")
		_face(g, Transform3D(basis, c), s)
		y -= h + GAP
	g.end_object()

static func _circle(r: float, n: int = 28, a0: float = 0.0) -> Array:
	var out: Array = []
	for k in range(n):
		var a: float = a0 + TAU * k / n
		out.append(Vector2(cos(a), sin(a)) * r)
	return out

static func _scaled(pts: Array, f: float) -> Array:
	return pts.map(func(q: Vector2) -> Vector2: return q * f)

static func _rect(w: float, h: float) -> Array:
	return [Vector2(-w * 0.5, -h * 0.5), Vector2(w * 0.5, -h * 0.5), Vector2(w * 0.5, h * 0.5), Vector2(-w * 0.5, h * 0.5)]

## One sign's layers on a plate centred at xf (+Z toward the traffic).
static func _face(g: Geo, xf: Transform3D, s: Array) -> void:
	var kind: String = s[0]
	var text: String = s[1] if s.size() > 1 else ""
	var L := func(k: int) -> Transform3D: return xf * Transform3D(Basis(), Vector3(0, 0, LAYER * k))
	match kind:
		"give_way", "danger":
			var down: bool = kind == "give_way"
			var tri: Array = [Vector2(-0.45, 0.26), Vector2(0.45, 0.26), Vector2(0, -0.52)] if down else [Vector2(-0.45, -0.26), Vector2(0, 0.52), Vector2(0.45, -0.26)]
			g.plate(L.call(0), tri, "sg_red", "sg_back")
			g.plate(L.call(1), _scaled(tri, 0.7), "sg_white")
			if not down:
				StreetKit._label(g, "!", L.call(3) * Transform3D(Basis(), Vector3(0, -0.07, 0)), 0.0085, Color(0.06, 0.06, 0.06))
		"stop":
			var oct: Array = _circle(0.325, 8, PI / 8.0)
			g.plate(L.call(0), oct, "sg_white", "sg_back")
			g.plate(L.call(1), _scaled(oct, 0.93), "sg_red")
			StreetKit._label(g, "STOP", L.call(3), 0.0042, Color(0.97, 0.97, 0.97), 0.42)
		"priority":
			var dia: Array = [Vector2(0, 0.424), Vector2(0.424, 0), Vector2(0, -0.424), Vector2(-0.424, 0)]
			g.plate(L.call(0), dia, "sg_white", "sg_back")
			g.plate(L.call(1), _scaled(dia, 0.62), "sg_yellow")
		"speed":
			g.plate(L.call(0), _circle(0.3), "sg_red", "sg_back")
			g.plate(L.call(1), _circle(0.235), "sg_white")
			StreetKit._label(g, text, L.call(3), 0.0058, Color(0.06, 0.06, 0.06), 0.36)
		"no_entry":
			g.plate(L.call(0), _circle(0.3), "sg_red", "sg_back")
			g.plate(L.call(1), _rect(0.42, 0.1), "sg_white")
		"dead_end":
			g.plate(L.call(0), _rect(0.6, 0.6), "sg_white", "sg_back")
			g.plate(L.call(1), _rect(0.56, 0.56), "sg_blue")
			g.plate(L.call(2), [Vector2(-0.06, -0.24), Vector2(0.06, -0.24), Vector2(0.06, 0.1), Vector2(-0.06, 0.1)], "sg_white")
			g.plate(L.call(2), _rect(0.34, 0.1).map(func(q: Vector2) -> Vector2: return q + Vector2(0, 0.15)), "sg_red")
		"crossing":
			g.plate(L.call(0), _rect(0.6, 0.6), "sg_white", "sg_back")
			g.plate(L.call(1), _rect(0.56, 0.56), "sg_blue")
			var tri2: Array = [Vector2(-0.24, -0.2), Vector2(0, 0.24), Vector2(0.24, -0.2)]
			g.plate(L.call(2), tri2, "sg_white")
			# The walker: head, body, a stride; the zebra under his feet.
			g.plate(L.call(3), _circle(0.022, 12).map(func(q: Vector2) -> Vector2: return q + Vector2(0.01, 0.08)), "sg_black")
			g.plate(L.call(3), [Vector2(-0.012, 0.05), Vector2(0.03, 0.05), Vector2(0.01, -0.06), Vector2(-0.025, -0.06)], "sg_black")
			g.plate(L.call(3), [Vector2(-0.025, -0.06), Vector2(0.0, -0.06), Vector2(-0.06, -0.13), Vector2(-0.08, -0.12)], "sg_black")
			g.plate(L.call(3), [Vector2(-0.005, -0.06), Vector2(0.015, -0.06), Vector2(0.06, -0.13), Vector2(0.04, -0.135)], "sg_black")
			for k in range(4):
				g.plate(L.call(3), _rect(0.04, 0.025).map(func(q: Vector2) -> Vector2: return q + Vector2(-0.105 + k * 0.07, -0.165)), "sg_black")
		"parking":
			g.plate(L.call(0), _rect(0.6, 0.6), "sg_white", "sg_back")
			g.plate(L.call(1), _rect(0.56, 0.56), "sg_blue")
			StreetKit._label(g, "P", L.call(3), 0.0075, Color(0.97, 0.97, 0.97), 0.4)
		"direction":
			var arrow: Array = [Vector2(-0.6, -0.15), Vector2(0.45, -0.15), Vector2(0.6, 0.0), Vector2(0.45, 0.15), Vector2(-0.6, 0.15)]
			g.plate(L.call(0), arrow, "sg_black", "sg_back")
			g.plate(L.call(1), _scaled(arrow, 0.94), "sg_yellow")
			var km: String = s[2] if s.size() > 2 else ""
			StreetKit._label(g, text, L.call(3) * Transform3D(Basis(), Vector3(-0.12, 0, 0)), 0.0034, Color(0.06, 0.06, 0.06), 0.72)
			if km != "":
				StreetKit._label(g, km, L.call(3) * Transform3D(Basis(), Vector3(0.38, 0, 0)), 0.0028, Color(0.06, 0.06, 0.06), 0.18)
		"no_drones":
			# White plate, the round ban sign in its top part, a black quad
			# seen from above crossed out in red, the words underneath.
			g.plate(L.call(0), _rect(0.6, 0.78), "sg_white", "sg_back")
			var c := Vector2(0, 0.1)
			g.plate(L.call(1), _circle(0.25).map(func(q: Vector2) -> Vector2: return q + c), "sg_red")
			g.plate(L.call(2), _circle(0.2).map(func(q: Vector2) -> Vector2: return q + c), "sg_white")
			for k in range(2):
				var a: float = PI * 0.25 + k * PI * 0.5
				var d := Vector2(cos(a), sin(a))
				var n2 := Vector2(-d.y, d.x)
				g.plate(L.call(3), [c - d * 0.13 - n2 * 0.012, c + d * 0.13 - n2 * 0.012, c + d * 0.13 + n2 * 0.012, c - d * 0.13 + n2 * 0.012], "sg_black")
				for e in [-1.0, 1.0]:
					g.plate(L.call(3), _circle(0.045, 14).map(func(q: Vector2) -> Vector2: return q + c + d * e * 0.13), "sg_black")
			g.plate(L.call(3), _rect(0.06, 0.06).map(func(q: Vector2) -> Vector2: return q + c), "sg_black")
			var bd := Vector2(cos(PI * 0.75), sin(PI * 0.75))
			var bn := Vector2(-bd.y, bd.x)
			g.plate(L.call(4), [c - bd * 0.2 - bn * 0.022, c + bd * 0.2 - bn * 0.022, c + bd * 0.2 + bn * 0.022, c - bd * 0.2 + bn * 0.022], "sg_red")
			StreetKit._label(g, text, L.call(1) * Transform3D(Basis(), Vector3(0, -0.27, 0)), 0.0028, Color(0.06, 0.06, 0.06), 0.52)
		"street":
			g.plate(L.call(0), _rect(0.7, 0.17), "sg_black", "sg_back")
			g.plate(L.call(1), _rect(0.67, 0.14), "sg_white")
			StreetKit._label(g, text, L.call(3), 0.0024, Color(0.06, 0.06, 0.06), 0.62)
