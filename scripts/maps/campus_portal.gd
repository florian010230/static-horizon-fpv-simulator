class_name CampusPortal
extends RefCounted

## A tunnel portal for the campus roads: a concrete face in the hillside
## with the road's opening, flared wing walls, and a short dark tube
## behind it (lit, closed at the back - the road is not drawn into it).

var k: CampusKit
var geo: Geo

func _init(kit: CampusKit) -> void:
	k = kit
	geo = kit.geo

## p: the road's centre at the face (ground level), out: the horizontal
## direction the road leaves in, road_w: its width, tube_len: the tube.
func portal(p: Vector3, out: Vector3, road_w: float, tube_len: float) -> void:
	out.y = 0.0
	out = out.normalized()
	var f := CampusKit.out_frame(p, out)
	var half: float = road_w * 0.5 + 1.1
	var clear: float = 5.6
	var wall_w: float = 28.0
	var wall_h: float = 7.6
	var th: float = 1.6
	# The face, with the road's opening and a header band.
	geo.tint = Color(0.95, 0.95, 0.92)
	BuildKit.wall(geo, f * Transform3D(Basis(), Vector3(0, 0, -th * 0.5)), -wall_w * 0.5, wall_w * 0.5, -0.7, wall_h, th, [Rect2(-half, 0.0, half * 2.0, clear)], "concrete_old")
	geo.tint = Color(0.8, 0.8, 0.78)
	k.bf(f, Vector3(0, wall_h + 0.2, -th * 0.5 + 0.15), Vector3(wall_w + 0.8, 0.5, th + 0.5), "concrete_old")
	geo.tint = Color.WHITE
	# Hazard bands each side of the opening (yellow/black, as painted on a real portal).
	for s in [-1.0, 1.0]:
		for j in range(6):
			geo.tint = Color(0.95, 0.78, 0.1) if j % 2 == 0 else Color(0.1, 0.1, 0.1)
			k.bf(f, Vector3(s * (half + 0.35), 0.5 + j * 1.0, 0.03), Vector3(0.5, 1.0, 0.06), "concrete_old", false, false)
	geo.tint = Color.WHITE
	# Flared wing walls (retaining walls sloping down into the cutting).
	for s in [-1.0, 1.0]:
		var wf: Transform3D = f * Transform3D(Basis(Vector3.UP, s * 0.38), Vector3(s * (wall_w * 0.5 - 0.4), 0, 0))
		geo.prism(wf, [Vector2(-th, -0.7), Vector2(12.0, -0.7), Vector2(12.0, 0.8), Vector2(-th * 0.0, wall_h - 0.5)], 0.9, "concrete_old")
	# The tube behind the face: side walls, roof, floor, back wall.
	var L: float = tube_len - th
	var cz: float = -th - L * 0.5
	var w_in: float = half
	geo.tint = Color(0.5, 0.5, 0.52)
	for s in [-1.0, 1.0]:
		k.bf(f, Vector3(s * (w_in + 0.4), clear * 0.5 - 0.2, cz), Vector3(0.8, clear + 0.6, L), "tunnel")
	k.bf(f, Vector3(0, clear + 0.3, cz), Vector3(w_in * 2.0 + 2.0, 0.6, L), "tunnel")
	k.bf(f, Vector3(0, -0.28, cz), Vector3(w_in * 2.0 + 0.4, 0.6, L), "tunnel")
	k.bf(f, Vector3(0, clear * 0.5, -th - L - 0.3), Vector3(w_in * 2.0 + 2.0, clear + 0.6, 0.6), "tunnel")
	geo.tint = Color.WHITE
	# Lamps along the roof.
	var n: int = int(L / 7.0)
	for i in range(n):
		k.bf(f, Vector3(0, clear - 0.12, -th - 3.0 - i * 7.0), Vector3(0.3, 0.1, 1.4), "lamp", false, false)
	# Kerb line and a side rail inside.
	for s in [-1.0, 1.0]:
		geo.tint = Color(0.6, 0.6, 0.62)
		k.bf(f, Vector3(s * (w_in - 0.2), 0.12, cz), Vector3(0.4, 0.24, L), "tunnel", false, false)
	geo.tint = Color.WHITE
