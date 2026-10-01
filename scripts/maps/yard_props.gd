class_name YardProps
extends RefCounted

## The clutter that makes a work site look worked in: pallets of bricks
## and cement, stacks of concrete pipes, rebar bundles, skips, cable
## reels, IBC tanks, site cabins (some stacked), portaloos, rows of
## concrete barriers. Scattered over a rectangle, each piece only where
## it fits - clear of everything already built and of roads and tracks
## (Geo's footprints), so nothing ends up inside anything.

const KINDS: Array[String] = ["pallets", "pallets", "pipes", "rebar", "skip", "reel", "ibc", "cabin", "cabin", "loo", "barriers"]

static func _materials(geo: Geo) -> void:
	if geo.has_material("yard_wood"):
		return
	geo.add_material("yard_wood", Geo.tex_mat(MapTextures.get_tex("wood"), Color(1.1, 1.0, 0.85), 1.0))
	geo.add_material("yard_brick", Geo.tex_mat(MapTextures.get_tex("dark_brick"), Color(1.25, 1.0, 0.9), 1.0))
	geo.add_material("yard_concrete", Geo.tex_mat(MapTextures.get_tex("old_concrete"), Color(1.1, 1.1, 1.08), 2.0))
	geo.add_material("yard_rust", Geo.tex_mat(MapTextures.get_tex("rust"), Color.WHITE, 2.0))
	geo.add_material("yard_yellow", Geo.flat_mat(Color(0.92, 0.66, 0.1)))
	geo.add_material("yard_orange", Geo.flat_mat(Color(0.85, 0.36, 0.1)))
	geo.add_material("yard_white", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.95, 0.95, 0.93), 2.4))
	geo.add_material("yard_blue", Geo.tex_mat(MapTextures.get_tex("corrugated_plain"), Color(0.3, 0.45, 0.72), 2.4))
	geo.add_material("yard_dark", Geo.flat_mat(Color(0.12, 0.12, 0.13)))
	geo.add_material("yard_plastic", Geo.flat_mat(Color(0.9, 0.9, 0.86)))
	geo.add_material("yard_green", Geo.flat_mat(Color(0.18, 0.45, 0.25)))

## Up to `count` pieces on `area` (ground height y), not in `exclude`.
## rusty = abandoned (the steel mill): rust instead of fresh paint.
static func scatter(geo: Geo, area: Rect2, y: float, count: int, rng: RandomNumberGenerator, exclude: Array = [], rusty: bool = false) -> int:
	_materials(geo)
	var placed: int = 0
	var tries: int = 0
	while placed < count and tries < count * 12:
		tries += 1
		var kind: String = KINDS[rng.randi() % KINDS.size()]
		var p := Vector3(rng.randf_range(area.position.x, area.end.x), y, rng.randf_range(area.position.y, area.end.y))
		var yaw: float = rng.randi_range(0, 3) * PI * 0.5 + rng.randf_range(-0.15, 0.15)
		var r: float = {"pallets": 3.0, "pipes": 3.5, "rebar": 3.6, "skip": 2.4, "reel": 1.6, "ibc": 1.0, "cabin": 3.5, "loo": 0.9, "barriers": 4.5}[kind]
		var q := Vector2(p.x, p.z)
		var skip: bool = false
		for e in exclude:
			if (e as Rect2).grow(r).has_point(q):
				skip = true
				break
		if skip or geo.blocked(q, r, y + 0.1, y + 6.0) or geo.on_lane(q, r):
			continue
		_piece(geo, kind, p, yaw, rng, rusty)
		placed += 1
	return placed

static func _piece(geo: Geo, kind: String, p: Vector3, yaw: float, rng: RandomNumberGenerator, rusty: bool) -> void:
	var b := Basis(Vector3.UP, yaw)
	var at := func(local: Vector3) -> Vector3: return p + b * local
	match kind:
		"pallets":
			var n: int = rng.randi_range(2, 5)
			for i in range(n):
				var c: Vector3 = at.call(Vector3((i - n * 0.5) * 1.35, 0, 0))
				geo.box(c + Vector3(0, 0.07, 0), Vector3(1.2, 0.14, 1.0), "yard_wood", yaw)
				var h: float = rng.randf_range(0.6, 1.2)
				geo.box(c + Vector3(0, 0.14 + h * 0.5, 0), Vector3(1.1, h, 0.9), "yard_brick" if rng.randf() < 0.6 else "yard_plastic", yaw)
		"pipes":
			var rows: Array = [3, 2, 1] if rng.randf() < 0.6 else [2, 1]
			var rr: float = 0.55
			for row in range(rows.size()):
				for k in range(rows[row]):
					var off: float = (k - (rows[row] - 1) * 0.5) * rr * 2.05
					var c2: Vector3 = at.call(Vector3(off, rr + row * rr * 1.75, 0))
					geo.pipe(c2 + b * Vector3(0, 0, -1.25), c2 + b * Vector3(0, 0, 1.25), rr, 0.1, "yard_concrete", 12)
		"rebar":
			for k in range(rng.randi_range(2, 4)):
				geo.box(at.call(Vector3(0, 0.2 + k * 0.32, (k % 2) * 0.2)), Vector3(0.7, 0.3, 6.0), "yard_rust", yaw)
			for s in [-2.0, 2.0]:
				geo.box(at.call(Vector3(0, 0.05, s)), Vector3(1.0, 0.1, 0.2), "yard_wood", yaw)
		"skip":
			geo.frustum(Transform3D(b, p + Vector3(0, 0.75, 0)), Vector3(1.8, 1.5, 2.6), 2.0, 3.8, 0.0, "yard_orange" if not rusty else "yard_rust")
		"reel":
			var c3: Vector3 = p + Vector3(0, 1.2, 0)
			for s in [-0.55, 0.55]:
				geo.cylinder(c3 + b * Vector3(s, 0, 0), c3 + b * Vector3(s + 0.08 * signf(s), 0, 0), 1.2, "yard_wood", 14)
			geo.cylinder(c3 + b * Vector3(-0.55, 0, 0), c3 + b * Vector3(0.55, 0, 0), 0.8, "yard_dark", 12)
		"ibc":
			geo.box(p + Vector3(0, 0.08, 0), Vector3(1.2, 0.16, 1.0), "yard_dark", yaw)
			geo.box(p + Vector3(0, 0.66, 0), Vector3(1.1, 1.0, 0.95), "yard_plastic", yaw)
		"cabin":
			var levels: int = 2 if rng.randf() < 0.35 else 1
			for lv in range(levels):
				var mat: String = "yard_rust" if rusty else ("yard_blue" if (lv + rng.randi()) % 2 == 0 else "yard_white")
				geo.box(p + Vector3(0, 1.3 + lv * 2.65, 0), Vector3(6.0, 2.6, 2.45), mat, yaw)
				geo.box(at.call(Vector3(0.6, 1.55 + lv * 2.65, 1.24)), Vector3(3.2, 0.9, 0.04), "yard_dark", yaw, false)
		"loo":
			for k in range(rng.randi_range(1, 3)):
				geo.box(at.call(Vector3(k * 1.25, 1.15, 0)), Vector3(1.1, 2.3, 1.15), "yard_blue" if not rusty else "yard_green", yaw)
		"barriers":
			for k in range(4):
				geo.frustum(Transform3D(b, at.call(Vector3((k - 1.5) * 2.05, 0.4, 0))), Vector3(2.0, 0.8, 0.6), 2.0, 0.2, 0.0, "yard_concrete")
