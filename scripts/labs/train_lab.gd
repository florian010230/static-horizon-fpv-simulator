extends BuiltMap

## Dev lab for Vehicles.rail (not in the menu): each rail vehicle kind in
## a row on a straight track, three-quarter close-ups and bogie close-ups.
## SH_TRAINS_OLD=1 shows the trains before the 2026-10-14 detail. `godot --path . -- --dev-preview lab TrainLab`.

const KINDS: Array[String] = ["loco", "shunter", "ice_head", "ice", "coach", "tank", "box", "hopper", "flat", "flat_empty", "torpedo"]
const GAP: float = 3.0
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-50, -30, 0), "shadow_region": Rect2(-20, -30, 340, 60), "clouds": 0.6}

func border() -> Array:
	return [400.0, 600.0, 100.0, 150.0]

func build() -> void:
	Vehicles.ensure_materials(geo)
	geo.add_material("lab_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.add_material("lab_ballast", Geo.ground_mat(MapTextures.get_tex("ballast"), Color(0.8, 0.8, 0.8), 3.0, 1, 0.1))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "lab_grass")
	var total: float = 0.0
	for k in KINDS:
		total += Vehicles.RAIL_LENGTH[k] + GAP
	geo.slab(Rect2(-6, -2.4, total + 12.0, 4.8), 0.1, 0.1, "lab_ballast")
	geo.add_material("lab_rail", Geo.flat_mat(Color(0.35, 0.34, 0.33), 0.4, 0.6))
	for rz in [-0.72, 0.72]:
		geo.box(Vector3(total * 0.5, 0.17, rz), Vector3(total + 12.0, 0.14, 0.08), "lab_rail", 0.0, false, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var x: float = 0.0
	var i: int = 0
	for k in KINDS:
		var L: float = Vehicles.rail(geo, x, 0.2, 0.0, k, rng, [])
		var cx: float = x + L * 0.5
		_views.append(["%02d_%s_34" % [i, k], Vector3(x + L * 0.5 + 9.0, 3.6, -9.5), Vector3(cx, 2.2, 0), k])
		_views.append(["%02d_%s_34b" % [i, k], Vector3(x + L * 0.5 - 8.0, 3.8, 9.5), Vector3(cx, 2.2, 0), k])
		var bz: float = L * 0.5 - (2.6 if k == "shunter" else 3.0)
		_views.append(["%02d_%s_bogie" % [i, k], Vector3(cx + bz + 0.5, 0.9, -4.0), Vector3(cx + bz, 0.9, 0), k])
		_views.append(["%02d_%s_end" % [i, k], Vector3(x - 3.2, 2.0, -3.4), Vector3(x, 1.5, 0), k])
		x += L + GAP
		i += 1
	_views.push_front(["overview", Vector3(total * 0.5, 14.0, -50.0), Vector3(total * 0.5, 2.0, 0), "overview"])
	_views.push_front(["overview2", Vector3(60.0, 9.0, -30.0), Vector3(60.0, 2.0, 0), "overview"])

func preview_views() -> Array:
	return _views
