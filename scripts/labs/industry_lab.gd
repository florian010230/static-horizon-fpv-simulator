extends BuiltMap

## Dev lab for IndustryCreator (not in the menu): one estate on level
## ground with every piece - a sawtooth production hall (open door, fly
## in), a smaller gable-roofed hall, a tank farm, a pipe rack, a boiler
## house and chimney, silos with their conveyor gallery, the fence and
## gate. Seed SH_SEED (default 1). Shoot it with
## `godot --path . -- --dev-preview lab IndustryLab`.

const SIZE: float = 600.0
var land: TerrainCreator
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-46, -35, 0), "shadow_region": Rect2(-110, -110, 220, 220), "clouds": 0.6}

func border() -> Array:
	return [600.0, 800.0, 200.0, 300.0]

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func _v(group: String, list: Array) -> void:
	for v: Array in list:
		_views.append([v[0], v[1], v[2], group])

func build() -> void:
	var seed0: int = int(OS.get_environment("SH_SEED")) if OS.has_environment("SH_SEED") else 1
	land = TerrainCreator.make(seed0, "gentle")
	var rect := Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)
	land.set_extent(rect)
	land.flat_rect(Rect2(-100, -110, 200, 220), 0.0)
	var site: Dictionary = IndustryCreator.plan(land, Vector2.ZERO, Vector2(140, 170))
	land.build(self, geo, rect)
	var r := RandomNumberGenerator.new()
	r.seed = seed0
	var t0: int = Time.get_ticks_msec()
	var o := Vector3(0, site.y, 0)
	IndustryCreator.yard(geo, site)
	var ha := Transform3D(Basis(), o + Vector3(-30, 0, -20))
	_v("hall", IndustryCreator.hall(geo, ha, 56.0, 30.0, 10.0, r, {"docks": 3}))
	# Inside: down the length from the open door, from crane height, and
	# back toward the door.
	_views.append(["hall_inside_low", ha * Vector3(-7.5, 1.5, -26.0), ha * Vector3(-3.0, 2.0, 10.0), "hall inside"])
	_views.append(["hall_inside_high", ha * Vector3(0.0, 8.0, -25.0), ha * Vector3(0.0, 1.0, 5.0), "hall inside"])
	_views.append(["hall_inside_back", ha * Vector3(5.0, 3.0, 24.0), ha * Vector3(-7.5, 2.5, -28.0), "hall inside"])
	_views.append(["hall_inside_side", ha * Vector3(12.0, 2.5, 0.0), ha * Vector3(-14.0, 2.0, 2.0), "hall inside"])
	var hb := Transform3D(Basis(), o + Vector3(40, 0, -50))
	var vb: Array = IndustryCreator.hall(geo, hb, 36.0, 20.0, 8.0, r, {"docks": 2, "roof": "gable", "office": false})
	for v: Array in vb:
		_views.append(["gable_" + v[0], v[1], v[2], "hall"])
	IndustryCreator.tanks(geo, o + Vector3(45, 0, 22), 2, 2, r)
	_views.append(["tanks", o + Vector3(80, 14, 50), o + Vector3(45, 6, 22), "tanks and pipes"])
	_views.append(["tanks_low", o + Vector3(20, 3, 45), o + Vector3(45, 6, 22), "tanks and pipes"])
	IndustryCreator.pipe_rack(geo, land, [Vector2(-40, 40), Vector2(25, 40), Vector2(25, 5)], 5.5, site.y)
	_views.append(["pipe_rack", o + Vector3(-20, 4, 46), o + Vector3(25, 5, 40), "tanks and pipes"])
	_views.append(["pipe_under", o + Vector3(-30, 3.5, 40), o + Vector3(25, 4, 40), "tanks and pipes"])
	geo.box_on(Transform3D(Basis(), o + Vector3(-50, 3.5, 30)), Vector3(10, 7, 8), "in_brick", o.y)
	IndustryCreator.chimney(geo, o + Vector3(-55, 0, 45), 45.0)
	_views.append(["chimney", o + Vector3(-95, 12, 80), o + Vector3(-55, 25, 45), "chimney and silos"])
	_v("chimney and silos", IndustryCreator.silos(geo, o + Vector3(5, 0, 68), 3, r, o + Vector3(-30, 0, 70)))
	_v("fence", IndustryCreator.fence(geo, site, "e"))
	_views.append(["fence_corner", o + Vector3(85, 4, 100), o + Vector3(60, 2, 60), "fence"])
	_views.append(["estate", o + Vector3(120, 60, 130), o, "fence"])
	if OS.has_environment("SH_PERF"):
		print("LAB industry built in %d ms" % (Time.get_ticks_msec() - t0))

func preview_views() -> Array:
	return _views
