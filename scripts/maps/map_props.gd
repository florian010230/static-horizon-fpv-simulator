class_name MapProps
extends RefCounted

## Small shared props for the generated maps: houses and whole little
## towns (streets of gabled houses with windows, a church), so every map
## that needs a settlement builds it the same way. Adds its materials to
## the Geo if the map hasn't.

static func ensure_materials(geo: Geo) -> void:
	if geo.has_material("prop_plaster"):
		return
	geo.add_material("prop_plaster", Geo.flat_mat(Color(0.86, 0.8, 0.7)))
	geo.add_material("prop_plaster2", Geo.flat_mat(Color(0.78, 0.74, 0.66)))
	geo.add_material("prop_brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.1, 1.05, 1.0), 3.0))
	geo.add_material("prop_roof", Geo.flat_mat(Color(0.52, 0.22, 0.16)))
	geo.add_material("prop_roof_dark", Geo.flat_mat(Color(0.28, 0.27, 0.28)))
	geo.add_material("prop_window", Geo.flat_mat(Color(0.14, 0.17, 0.2)))
	geo.add_material("prop_road", Geo.tex_mat(MapTextures.get_tex("cracked_asphalt"), Color.WHITE, 8.0))

## A two-storey gabled house standing at p (ground), turned by yaw.
static func house(geo: Geo, p: Vector3, yaw: float, w: float, d: float, wall: String, roof: String) -> void:
	var b := Basis(Vector3.UP, yaw)
	var h: float = 6.2
	geo.box_xf(Transform3D(b, p + Vector3(0, h * 0.5 - 0.5, 0)), Vector3(w, h + 1.0, d), wall)
	for s in [-1.0, 1.0]:
		var xf := Transform3D(b * Basis(Vector3.RIGHT, s * 0.62), p + b * Vector3(0, h + 1.35, s * d * 0.26))
		geo.box_xf(xf, Vector3(w + 0.6, 0.22, d * 0.6), roof)
	for fy in [1.5, 4.4]:
		for fx in [-w * 0.3, w * 0.3]:
			for side in [-1.0, 1.0]:
				geo.box_xf(Transform3D(b, p + b * Vector3(fx, fy, side * (d * 0.5 + 0.02))), Vector3(1.2, 1.3, 0.05), "prop_window", false, false)

## A small town on flat ground: a grid of streets in `area`, houses
## along them, a church in the middle. ground(x, z) gives the height.
static func town(geo: Geo, area: Rect2, ground: Callable, rng: RandomNumberGenerator, brick: bool = false) -> void:
	ensure_materials(geo)
	var c: Vector2 = area.get_center()
	var street_z: Array[float] = []
	var z: float = area.position.y + 12.0
	while z < area.end.y - 10.0:
		street_z.append(z)
		z += 34.0
	for sz in street_z:
		geo.slab(Rect2(area.position.x, sz - 3.5, area.size.x, 7), ground.call(c.x, sz) + 0.08, 0.3, "prop_road", false)
		var x: float = area.position.x + 8.0
		while x < area.end.x - 8.0:
			for side in [-1.0, 1.0]:
				if rng.randf() < 0.85 and Vector2(x, sz + side * 11.0).distance_to(c) > 20.0:
					var hp := Vector3(x, 0, sz + side * 11.0)
					hp.y = ground.call(hp.x, hp.z)
					var wall: String = "prop_brick" if brick and rng.randf() < 0.7 else ("prop_plaster" if rng.randf() < 0.5 else "prop_plaster2")
					house(geo, hp, 0.0, rng.randf_range(8, 11), 8.5, wall, "prop_roof" if rng.randf() < 0.7 else "prop_roof_dark")
			x += 14.0
	# Church at the centre, on its own little square.
	var cp := Vector3(c.x, ground.call(c.x, c.y), c.y)
	geo.box(cp + Vector3(0, 5, 0), Vector3(10, 11, 22), "prop_plaster")
	for s in [-1.0, 1.0]:
		geo.box_xf(Transform3D(Basis(Vector3.FORWARD, s * 0.75), cp + Vector3(s * 2.6, 12.0, 0)), Vector3(7.4, 0.3, 22.6), "prop_roof_dark")
	geo.box(cp + Vector3(0, 12, -12), Vector3(5, 24, 5), "prop_plaster")
	geo.cone(cp + Vector3(0, 24, -12), cp + Vector3(0, 33, -12), 3.6, 0.05, "prop_roof_dark", 4)
