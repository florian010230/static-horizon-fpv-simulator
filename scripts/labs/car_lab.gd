extends BuiltMap

## Dev lab for Vehicles.car (not in the menu): every kind side by side
## on a car park, close-ups front-three-quarter and rear. SH_CARS=1 shows
## the 2026-10-14 detail. `godot --path . -- --dev-preview lab CarLab`.

const KINDS: Array[String] = ["sedan", "hatch", "estate", "suv", "van", "pickup", "taxi"]
const SPACING: float = 3.4
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-50, -30, 0), "shadow_region": Rect2(-10, -10, 40, 30), "clouds": 0.6}

func border() -> Array:
	return [200.0, 300.0, 100.0, 150.0]

func build() -> void:
	Vehicles.ensure_materials(geo)
	geo.add_material("lab_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.add_material("lab_road", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color(0.8, 0.8, 0.8), 4.0, 2, 0.1))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "lab_grass")
	geo.slab(Rect2(-4, -6, SPACING * KINDS.size() + 6, 12), 0.03, 0.1, "lab_road")
	var paints: Array[String] = ["veh_paint0", "veh_paint9", "veh_paint1", "veh_paint4", "veh_paint2", "veh_paint6", "veh_paint7"]
	for i in range(KINDS.size()):
		var x: float = i * SPACING
		Vehicles.car(geo, Vector3(x, 0.03, 0), 0.0, paints[i], KINDS[i])
		_views.append(["%d_%s_front" % [i, KINDS[i]], Vector3(x + 3.2, 1.6, -4.6), Vector3(x, 0.7, -0.6), KINDS[i]])
		_views.append(["%d_%s_rear" % [i, KINDS[i]], Vector3(x - 2.8, 1.4, 4.4), Vector3(x, 0.7, 0.8), KINDS[i]])
	_views.push_front(["overview", Vector3(SPACING * 3.0, 4.5, -12.0), Vector3(SPACING * 3.0, 0.6, 0), "overview"])

func preview_views() -> Array:
	return _views
