extends BuiltMap

## Dev lab for FarmCreator and FieldCreator (not in the menu): a
## farmstead on its level yard, and south of it one field of each crop
## on the gently rolling land (hedges on some edges), a tractor on the
## stubble. Seed SH_SEED (default 1). Shoot it with
## `godot --path . -- --dev-preview lab FarmLab`.

const SIZE: float = 900.0
const FIELD: float = 70.0
var land: TerrainCreator
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-46, -35, 0), "shadow_region": Rect2(-300, -60, 600, 200), "clouds": 0.6}

func border() -> Array:
	return [700.0, 900.0, 200.0, 300.0]

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func build() -> void:
	var seed0: int = int(OS.get_environment("SH_SEED")) if OS.has_environment("SH_SEED") else 1
	land = TerrainCreator.make(seed0, "gentle")
	var rect := Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)
	land.set_extent(rect)
	land.flat_rect(Rect2(-50, -40, 100, 80), 0.0)
	var farm: Dictionary = FarmCreator.plan(land, Vector2.ZERO, Vector2(64, 48), 1.0)
	var crops: Array = FieldCreator.CROPS.keys()
	var fields: Array = []
	for i in range(crops.size()):
		var x0: float = -crops.size() * (FIELD + 12.0) * 0.5 + i * (FIELD + 12.0)
		var cs: Array = [Vector2(x0, 60), Vector2(x0 + FIELD, 62), Vector2(x0 + FIELD + 2, 60 + FIELD), Vector2(x0 - 1, 58 + FIELD)]
		land.keep_clear_poly(FieldCreator.poly(cs))
		fields.append([crops[i], cs])
	land.build(self, geo, rect)
	var t0: int = Time.get_ticks_msec()
	farm["chickens"] = 1 # the lab always shows the rare surprise
	var fv: Dictionary = FarmCreator.build(geo, land, farm, seed0)
	var trees: Array = fv.trees
	for v: Array in fv.views:
		var g: String = "barn" if String(v[0]).begins_with("barn") else "farm"
		_views.append([v[0], v[1], v[2], g])
	var barn: Vector3 = fv.barn
	var L: float = FarmCreator.BARN_L
	_views.append(["barn_from_west", barn + Vector3(-L * 0.5 - 1.0, 2.2, 0.0), barn + Vector3(L * 0.5, 2.0, 0.0), "barn"])
	_views.append(["barn_loft", barn + Vector3(L * 0.5 - 9.0, 2.0, 0.0), barn + Vector3(L * 0.5 - 2.0, 3.6, -3.0), "barn"])
	_views.append(["barn_roof_inside", barn + Vector3(-4.0, 2.5, 2.0), barn + Vector3(2.0, 9.0, -2.0), "barn"])
	_views.append(["barn_out_east", barn + Vector3(L * 0.5 + 16.0, 3.0, 0.5), barn + Vector3(-L * 0.5, 2.5, 0.0), "barn"])
	var r := RandomNumberGenerator.new()
	r.seed = seed0
	for fd: Array in fields:
		var info: Dictionary = FieldCreator.build(geo, land, fd[1], fd[0], r, {"hedges": [2] if fd[0] != "meadow" else [1, 2]})
		trees.append_array(info.trees)
		for v: Array in info.views:
			var n: String = v[0]
			var g: String = "fields" if n.begins_with("field_") else ("inside crops" if n.begins_with("in_") or n.begins_with("skim_") else "bales")
			_views.append([n, v[1], v[2], g])
	var tq: Vector2 = (fields[4][1][0] as Vector2) + Vector2(30, 20)
	FarmCreator.tractor(geo, Vector3(tq.x, land.ground(tq.x, tq.y) + 0.02, tq.y), 0.4, "fm_red", true, r)
	_views.append(["tractor_field", Vector3(tq.x - 9, land.ground(tq.x, tq.y) + 3.5, tq.y + 9), Vector3(tq.x, land.ground(tq.x, tq.y) + 1.0, tq.y), "farm"])
	TreeCreator.plant(self, geo, trees)
	_views.append(["overview", Vector3(0, 90, -120), Vector3(0, 0, 70), "fields"])
	if OS.has_environment("SH_PERF"):
		print("LAB farm + %d fields in %d ms" % [fields.size(), Time.get_ticks_msec() - t0])

func preview_views() -> Array:
	return _views
