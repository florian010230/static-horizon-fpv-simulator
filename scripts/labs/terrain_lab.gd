extends BuiltMap

## Dev lab for TerrainCreator (not in the menu): one landscape per run,
## style SH_TERRAIN ("rolling" default, "hills", "valley"), seed SH_SEED -
## a levelled plot with two closed houses for scale, a street running
## off into the fog, a pond and woods. Shoot it with
## `SH_TERRAIN=hills godot --path . -- --dev-preview lab TerrainLab`.

const SIZE: float = 1200.0
var land: TerrainCreator
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-40, -35, 0), "shadow_region": Rect2(-200, -200, 400, 400), "clouds": 0.6}

func border() -> Array:
	return [900.0, 1100.0, 300.0, 400.0]

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func build() -> void:
	var style: String = OS.get_environment("SH_TERRAIN") if OS.has_environment("SH_TERRAIN") else "rolling"
	var seed_value: int = int(OS.get_environment("SH_SEED")) if OS.has_environment("SH_SEED") else 1
	var t0: int = Time.get_ticks_msec()
	land = TerrainCreator.make(seed_value, style)
	land.flat_rect(Rect2(-45, -30, 90, 40), 0.0)
	land.flat_line(Vector2(-3000, 16), Vector2(3000, 16), 4.0, 0.0)
	land.pond(Vector2(170, -140), 24.0)
	# A river across the north, a road from the plot over it.
	var tp: int = Time.get_ticks_msec()
	land.set_extent(Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE), 8.0)
	var river := RiverCreator.plan(land, [Vector2(-1500, -230), Vector2(0, -260), Vector2(1500, -330)], 11.0, {"seed": seed_value})
	var tq: int = Time.get_ticks_msec()
	var road := RoadCreator.plan(land, Vector3(60, 0, 12.4), -90.0, [Vector2(80, -200), Vector2(20, -420), Vector2(-60, -900)], 6.5, {"start_y": 0.0})
	var rect := Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)
	var tb: int = Time.get_ticks_msec()
	land.build(self, geo, rect, 8.0)
	var tc: int = Time.get_ticks_msec()
	var rng0 := RandomNumberGenerator.new()
	rng0.seed = seed_value
	var shown: Rect2 = rect.grow(-30.0)
	var rinfo: Dictionary = river.draw(geo, shown, rng0)
	var td: int = Time.get_ticks_msec()
	var dinfo: Dictionary = road.draw(geo, Roads.new(geo, rng0), rng0)
	if OS.has_environment("SH_PERF"):
		print("LAB plan river %d ms, plan road %d ms, land.build %d ms, draw river %d ms, draw road+bridge %d ms" % [tq - tp, tb - tq, tc - tb, td - tc, Time.get_ticks_msec() - td])
	var g0 := "%s seed %d" % [style, seed_value]
	for v: Array in rinfo.views + dinfo.views:
		_views.append([v[0], v[1], v[2], "river and road"])
	if OS.has_environment("SH_PERF"):
		print("LAB bridges %s, duck race %s" % [dinfo.bridges, rinfo.ducks])
	var t1: int = Time.get_ticks_msec()
	geo.add_material("lab_road", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 2, 0.3))
	geo.slab(Rect2(-3000, 12.5, 6000, 7), 0.06, 0.1, "lab_road")
	HouseCreator.build(geo, Vector3(-20, 0, -12), 0.0, 2, {"interior": false, "path_to": 12.5})
	HouseCreator.build(geo, Vector3(20, 0, -12), 0.0, 3, {"interior": false, "path_to": 12.5})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var trees: Array = land.woods(rng, rect.grow(-100.0))
	var t2: int = Time.get_ticks_msec()
	var info: Dictionary = TreeCreator.plant(self, geo, trees)
	if OS.has_environment("SH_PERF"):
		print("LAB terrain %d ms, woods picked %d ms, trees %d of %d planted %d ms" % [t1 - t0, t2 - t1, info.kept, trees.size(), Time.get_ticks_msec() - t2])
	var g := "%s seed %d" % [style, seed_value]
	_views.append(["aerial", Vector3(-260, 140, 330), Vector3(0, 0, -60), g])
	_views.append(["high", Vector3(0, 320, 420), Vector3(0, 0, -120), g])
	_views.append(["street", Vector3(-80, 4, 16), Vector3(60, 3, 0), g])
	_views.append(["from_plot", Vector3(0, 3, -20), Vector3(0, 6, -200), g])
	_views.append(["pond", Vector3(170 - 55, land.height(115, -100) + 6, -100), Vector3(170, land.height(170, -140), -140), g])
	_views.append(["low_east", Vector3(260, land.height(260, 60) + 8, 60), Vector3(0, 4, -40), g])

func preview_views() -> Array:
	return _views
