extends BuiltMap

## Dev lab for SignCreator (not in the menu): every kind of road sign on
## its own post, and two shared posts, along a strip of road.
## `godot --path . -- --dev-preview lab SignLab`.

const SPACING: float = 2.6
const CASES: Array = [
	[["give_way"]], [["stop"]], [["priority"]], [["speed", "30"]], [["speed", "50"]], [["no_entry"]],
	[["dead_end"]], [["crossing"]], [["parking"]], [["danger"]],
	[["direction", "Holderbach", "3 km"]], [["give_way"], ["street", "Kirchgasse"]], [["priority"], ["speed", "70"]],
]
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-50, -150, 0), "shadow_region": Rect2(-10, -10, 50, 30), "clouds": 0.6}

func border() -> Array:
	return [200.0, 300.0, 100.0, 150.0]

func build() -> void:
	geo.add_material("lab_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.add_material("lab_road", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color(0.8, 0.8, 0.8), 4.0, 2, 0.1))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "lab_grass")
	geo.slab(Rect2(-4, 1.0, SPACING * CASES.size() + 6, 7), 0.03, 0.1, "lab_road")
	for i in range(CASES.size()):
		var x: float = i * SPACING
		SignCreator.post(geo, Vector3(x, 0, 0), 0.0, CASES[i])
		var top: float = 2.1
		for s: Array in CASES[i]:
			top += SignCreator.height_of(s[0]) + SignCreator.GAP
		_views.append(["%02d_%s" % [i, CASES[i][0][0]], Vector3(x + 0.6, top - 0.3, 2.4), Vector3(x, top - 0.55, 0), CASES[i][0][0]])
	_views.push_front(["overview", Vector3(SPACING * CASES.size() * 0.5, 3.0, 13.0), Vector3(SPACING * CASES.size() * 0.5, 2.4, 0), "overview"])
	_views.push_front(["road_view", Vector3(-6, 1.6, 5.0), Vector3(12, 2.5, 0.5), "overview"])

func preview_views() -> Array:
	return _views
