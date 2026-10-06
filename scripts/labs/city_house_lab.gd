extends BuiltMap

## Dev lab for CityHouseCreator (not in the menu): two straight streets
## on level ground. Street 1: a row of each style alone (altbau on one
## side, fifties on the other) - one house per lot, every lot its own
## seed, so each picture is one house. Street 2: a modern row and a
## mixed row through build_row, as the maps use it. Forced variants: an
## archway and a shop on the first lots. Seeds SH_SEED.. (default 1).
## Shoot it with `godot --path . -- --dev-preview lab CityHouseLab`
## (one contact sheet per group: the styles, row, backs, details).

const SIZE: float = 600.0
const ROW_LEN: float = 100.0
const STREET2_Z: float = -110.0
var land: TerrainCreator
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-46, -35, 0), "shadow_region": Rect2(-40, -170, 200, 220), "clouds": 0.6}

func border() -> Array:
	return [600.0, 800.0, 200.0, 300.0]

func _height(x: float, z: float) -> float:
	return land.ground(x, z)

func build() -> void:
	var seed0: int = int(OS.get_environment("SH_SEED")) if OS.has_environment("SH_SEED") else 1
	land = TerrainCreator.make(seed0, "gentle")
	var rect := Rect2(-SIZE * 0.5, -SIZE * 0.5, SIZE, SIZE)
	land.set_extent(rect)
	land.flat_rect(Rect2(-60, -170, 240, 230), 0.0)
	var st1 := RoadCreator.plan(land, Vector3(-3000, 0, 0), 0.0, [Vector2(3000, 0)], 6.5, {"start_y": 0.0})
	var st2 := RoadCreator.plan(land, Vector3(-3000, 0, STREET2_Z), 0.0, [Vector2(3000, STREET2_Z)], 6.5, {"start_y": 0.0})
	var d0: float = st1.dist_at(Vector2(0, 0))
	var e0: float = st2.dist_at(Vector2(0, STREET2_Z))
	var rows: Array = [
		["altbau", CityHouseCreator.plan_row(land, st1, d0, d0 + ROW_LEN, -1.0, {"seed": seed0, "styles": {"altbau": 1.0}})],
		["fifties", CityHouseCreator.plan_row(land, st1, d0, d0 + ROW_LEN, 1.0, {"seed": seed0 + 1, "styles": {"fifties": 1.0}})],
		["modern", CityHouseCreator.plan_row(land, st2, e0, e0 + ROW_LEN, 1.0, {"seed": seed0 + 2, "styles": {"modern": 1.0}})],
	]
	var mixed: Array = CityHouseCreator.plan_row(land, st2, e0, e0 + ROW_LEN, -1.0, {"seed": seed0 + 3})
	land.build(self, geo, rect)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed0
	var roads := Roads.new(geo, rng)
	for rd: RoadCreator in [st1, st2]:
		rd.draw(geo, roads, rng)
		var r: Route = Route.from_pts(rd.line.pts)
		var dd: float = rd.dist_at(Vector2(0, rd.line.pts[0].z))
		for sd in [-1.0, 1.0]:
			roads.pavement(Route.from_pts(r.slice(dd - 4.0, dd + ROW_LEN + 4.0)), sd, rd.line.half, CityHouseCreator.WALK)
	var t0: int = Time.get_ticks_msec()
	var trees: Array = []
	var n: int = 0
	for row: Array in rows:
		var st: String = row[0]
		var lots: Array = row[1]
		for i in range(lots.size()):
			var lot: Dictionary = lots[i]
			var r := RandomNumberGenerator.new()
			r.seed = seed0 * 1000 + n
			n += 1
			var o: Dictionary = {"yard": lot.yard, "open_sides": CityHouseCreator.open_sides(lots, i)}
			if i == 0:
				o.merge({"shop": true, "arch": true})
			elif i == 1:
				o.merge({"shop": true})
			elif i == 2:
				o.merge({"shop": false})
			var info: Dictionary = CityHouseCreator.build(geo, lot.frame, lot.width, lot.depth, st, r, o)
			trees.append_array(info.trees)
			var f: Transform3D = lot.frame
			var w: float = lot.width
			_views.append(["%s_%d" % [st, i], f * Vector3(-w * 0.45, 5.0, 9.0), f * Vector3(w * 0.1, 7.5, 0.0), st])
			_views.append(["%s_%d_back" % [st, i], f * Vector3(0.0, 11.0, -lot.depth - lot.yard - 2.0), f * Vector3(-w * 0.1, 1.0, -lot.depth), "backs"])
			for v: Array in info.views:
				if v[0] == "archway":
					_views.append(["%s_%d_archway" % [st, i], v[1], v[2], "details"])
			if i == 1:
				_views.append(["%s_shop_close" % st, f * Vector3(-w * 0.2, 2.2, 6.0), f * Vector3(w * 0.1, 2.0, 0.0), "details"])
			if i == 2:
				_views.append(["%s_roof" % st, f * Vector3(-w * 0.6, 28.0, 6.0), f * Vector3(0, 14.0, -lot.depth * 0.5), "details"])
				_views.append(["%s_upper" % st, f * Vector3(-w * 0.4, 9.0, 5.0), f * Vector3(w * 0.1, 9.0, 0.0), "details"])
	var info2: Dictionary = CityHouseCreator.build_row(geo, mixed, seed0 + 7)
	trees.append_array(info2.trees)
	TreeCreator.plant(self, geo, trees)
	for v: Array in info2.views:
		_views.append(["row_" + v[0], v[1], v[2], "row"])
	if OS.has_environment("SH_PERF"):
		print("LAB town houses: %d in %d ms" % [n + mixed.size(), Time.get_ticks_msec() - t0])
	_views.append(["street1", Vector3(-20, 5, -4), Vector3(ROW_LEN, 4, 1), "row"])
	_views.append(["street2", Vector3(-20, 5, STREET2_Z + 4), Vector3(ROW_LEN, 4, STREET2_Z - 1), "row"])
	var last: Dictionary = rows[0][1][rows[0][1].size() - 1]
	var lf: Transform3D = last.frame
	_views.append(["row_end", lf * Vector3(last.width * 0.5 + 14.0, 6.0, 8.0), lf * Vector3(last.width * 0.5, 7.0, -last.depth * 0.5), "row"])
	_views.append(["aerial", Vector3(-60, 70, 60), Vector3(ROW_LEN * 0.5, 0, STREET2_Z * 0.5), "row"])
	_views.append(["between_backs", Vector3(-10, 14, STREET2_Z * 0.5), Vector3(ROW_LEN, 2, STREET2_Z * 0.5), "backs"])

func preview_views() -> Array:
	return _views
