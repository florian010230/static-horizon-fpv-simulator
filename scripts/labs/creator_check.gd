class_name CreatorCheck
extends RefCounted

## Fast check of the creators (the self-test runs it; ~a few seconds):
## builds them with many seeds, off screen, once on level ground and once
## on steep hills - town houses of every style (both sides of a street,
## with their courtyards), halls with every roof, tanks, silos, a
## chimney, a pipe rack, a fence, a farmstead and a field of every crop
## with a tractor - and reports the pieces left floating (Geo.floating).
## Script errors show in the log. Returns {"floating": [...], "houses",
## "halls", "crops", "ms"}.

static func run() -> Dictionary:
	var t0: int = Time.get_ticks_msec()
	var out: Dictionary = {"floating": [], "houses": 0, "halls": 0, "crops": 0, "ms": 0}
	for style: String in ["gentle", "hills"]:
		var res: Dictionary = _one(style, 11 if style == "gentle" else 12)
		for f: Array in res.floating:
			out.floating.append([style] + f)
		for k: String in ["houses", "halls", "crops"]:
			out[k] += res[k]
	out.ms = Time.get_ticks_msec() - t0
	return out

static func _one(style: String, seed_value: int) -> Dictionary:
	var geo := Geo.new()
	var holder := Node3D.new() # the terrain's nodes land here, never shown
	var land: TerrainCreator = TerrainCreator.make(seed_value, style)
	var rect := Rect2(-200, -200, 400, 400)
	land.set_extent(rect)
	if style == "gentle":
		land.flat_rect(rect.grow(-20.0), 0.0)
	var road := RoadCreator.plan(land, Vector3(-260, 0, 0), 0.0, [Vector2(260, 0)], 6.5, {"start_y": land.height(-200, 0)})
	var d0: float = road.dist_at(Vector2(-190, 0))
	var d1: float = road.dist_at(Vector2(-80, 0))
	var d2: float = road.dist_at(Vector2(-25, 0))
	var d3: float = road.dist_at(Vector2(85, 0))
	var rows: Array = [
		CityHouseCreator.plan_row(land, road, d0, d1, -1.0, {"seed": seed_value, "styles": {"altbau": 1.0}}),
		CityHouseCreator.plan_row(land, road, d2, d3, -1.0, {"seed": seed_value + 1, "styles": {"fifties": 1.0}}),
		CityHouseCreator.plan_row(land, road, d0, d1, 1.0, {"seed": seed_value + 2, "styles": {"modern": 1.0}}),
		CityHouseCreator.plan_row(land, road, d2, d3, 1.0, {"seed": seed_value + 3}),
	]
	var site: Dictionary = IndustryCreator.plan(land, Vector2(-80, -115), Vector2(180, 100))
	var site2: Dictionary = IndustryCreator.plan(land, Vector2(95, -115), Vector2(140, 100))
	var farm: Dictionary = FarmCreator.plan(land, Vector2(-110, 120), Vector2(64, 48))
	var fields: Array = []
	var crops: Array = FieldCreator.CROPS.keys()
	for i in range(crops.size()):
		var x0: float = 5.0 + (i % 3) * 65.0
		var z0: float = 45.0 + (i / 3) * 70.0
		var cs: Array = [Vector2(x0, z0), Vector2(x0 + 55, z0 + 2), Vector2(x0 + 56, z0 + 57), Vector2(x0 - 1, z0 + 55)]
		land.keep_clear_poly(FieldCreator.poly(cs))
		fields.append([crops[i], cs])
	land.build(holder, geo, rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	road.draw(geo, Roads.new(geo, rng), rng)
	var houses: int = 0
	for row: Array in rows:
		CityHouseCreator.build_row(geo, row, seed_value * 7 + houses)
		houses += row.size()
	# Industry: three halls (sawtooth, gable, sawtooth without office) on
	# one site; tanks, pipes, silos, a chimney, the fence on the other.
	var o := Vector3(site.c.x, site.y, site.c.y)
	IndustryCreator.yard(geo, site)
	IndustryCreator.hall(geo, Transform3D(Basis(), o + Vector3(-50, 0, -5)), 56.0, 30.0, 10.0, rng, {"docks": 3})
	IndustryCreator.hall(geo, Transform3D(Basis(), o + Vector3(0, 0, 0)), 40.0, 20.0, 8.0, rng, {"roof": "gable", "office": false, "docks": 2})
	IndustryCreator.hall(geo, Transform3D(Basis(), o + Vector3(50, 0, -5)), 36.0, 24.0, 9.0, rng, {"office": false})
	IndustryCreator.fence(geo, site, "s")
	var o2 := Vector3(site2.c.x, site2.y, site2.c.y)
	IndustryCreator.yard(geo, site2)
	IndustryCreator.tanks(geo, o2 + Vector3(-35, 0, -20), 2, 2, rng)
	IndustryCreator.pipe_rack(geo, land, [Vector2(o2.x - 60, o2.z + 25), Vector2(o2.x + 10, o2.z + 25), Vector2(o2.x + 10, o2.z - 5)], 5.5, o2.y)
	IndustryCreator.silos(geo, o2 + Vector3(25, 0, -30), 3, rng, o2 + Vector3(40, 0, 10))
	IndustryCreator.chimney(geo, o2 + Vector3(55, 0, 35), 40.0)
	IndustryCreator.fence(geo, site2, "w")
	FarmCreator.build(geo, land, farm, seed_value)
	for fd: Array in fields:
		FieldCreator.build(geo, land, fd[1], fd[0], rng, {"hedges": [0]})
	# The tractor on a field, where a farmer would park one: the first
	# spot not steeper than 1 in 4 (on 1 in 2 its tyres would gape).
	var tq := Vector2(140, 150)
	for c: Vector2 in [Vector2(140, 150), Vector2(30, 70), Vector2(95, 70), Vector2(160, 75), Vector2(30, 140), Vector2(95, 140)]:
		if absf(land.ground(c.x + 3.0, c.y) - land.ground(c.x - 3.0, c.y)) < 1.5 and absf(land.ground(c.x, c.y + 3.0) - land.ground(c.x, c.y - 3.0)) < 1.5:
			tq = c
			break
	FarmCreator.tractor(geo, Vector3(tq.x, land.ground(tq.x, tq.y) + 0.02, tq.y), 0.4, "fm_green", true, rng)
	var fl: Array = geo.floating(land.ground, Vector2.ZERO, 400.0)
	holder.free()
	return {"floating": fl, "houses": houses, "halls": 3, "crops": fields.size()}
