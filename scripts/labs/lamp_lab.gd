extends BuiltMap

## Dev lab for StreetLampCreator (not in the menu): today's lamp (Roads.lamp
## before 2026-10-14) and the three new kinds in a row along a strip of
## road, with close-ups. `godot --path . -- --dev-preview lab LampLab`.

const SPACING: float = 9.0
const CASES: Array[String] = ["old", "led", "whip", "village"]
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-50, -30, 0), "shadow_region": Rect2(-20, -20, 60, 40), "clouds": 0.6}

func border() -> Array:
	return [200.0, 300.0, 100.0, 150.0]

func build() -> void:
	geo.add_material("lab_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.add_material("lab_road", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color(0.8, 0.8, 0.8), 4.0, 2, 0.1))
	geo.add_material("lab_steel", Geo.flat_mat(Color(0.45, 0.47, 0.5), 0.5, 0.5))
	geo.add_material("lab_lamp", Geo.flat_mat(Color(0.9, 0.9, 0.85)))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "lab_grass")
	geo.slab(Rect2(-10, 1.5, SPACING * CASES.size() + 10, 7), 0.03, 0.1, "lab_road")
	for i in range(CASES.size()):
		var x: float = i * SPACING
		var foot := Vector3(x, 0.0, 0.0)
		var toward := Vector3(0, 0, 1)
		if CASES[i] == "old":
			geo.cylinder(foot, foot + Vector3(0, 8.0, 0), 0.09, "lab_steel", 6)
			var arm: Vector3 = foot + Vector3(0, 8.0, 0) + toward * 1.6
			geo.beam(foot + Vector3(0, 7.6, 0), arm, Vector2(0.07, 0.07), "lab_steel")
			geo.box(arm + Vector3(0, -0.08, 0), Vector3(0.35, 0.12, 0.7), "lab_lamp", 0.0, false, false)
		else:
			StreetLampCreator.build(geo, foot, toward, CASES[i])
		var top: float = 4.8 if CASES[i] == "village" else 8.5
		_views.append(["%d_%s" % [i, CASES[i]], Vector3(x + 4.5, top * 0.55, 6.5), Vector3(x, top * 0.5, 0.3), CASES[i]])
		_views.append(["%d_%s_head" % [i, CASES[i]], Vector3(x + 1.8, top + 0.6, 3.2), Vector3(x, top - 0.3, 0.9), CASES[i]])
	_views.push_front(["overview", Vector3(SPACING * 1.5, 5.0, 22.0), Vector3(SPACING * 1.5, 3.5, 0), "overview"])

func preview_views() -> Array:
	return _views
