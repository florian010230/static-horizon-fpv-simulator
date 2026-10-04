extends BuiltMap

## Dev lab for ToiletCreator (not in the menu): a row of toilets against
## a tiled wall, one per floater (and the lid states), with close-up
## cameras. `godot --path . -- --dev-preview lab ToiletLab`.

const SPACING: float = 1.5
const CASES := [
	["none", "open"], ["duck", "open"], ["battleship", "open"], ["swan", "open"],
["bottle", "open"], ["none", "closed"], ["none", "seat_up"]]
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-55, -20, 0), "shadow_region": Rect2(-10, -10, 24, 20), "clouds": 0.8}

func border() -> Array:
	return [200.0, 300.0, 100.0, 150.0]

func build() -> void:
	geo.add_material("lab_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.add_material("lab_tiles", Geo.ground_mat(MapTextures.get_tex("paving_slabs"), Color(1.1, 1.1, 1.1), 0.6, 1, 0.0))
	geo.add_material("lab_wall", Geo.flat_mat(Color(0.75, 0.82, 0.86)))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "lab_grass")
	var w: float = CASES.size() * SPACING + 2.0
	geo.slab(Rect2(-1.5, -0.2, w, 2.5), 0.02, 0.1, "lab_tiles")
	geo.box(Vector3(w * 0.5 - 1.5, 1.25, -0.1), Vector3(w, 2.5, 0.2), "lab_wall")
	var rng := RandomNumberGenerator.new()
	rng.seed = int(OS.get_environment("SH_SEED")) if OS.has_environment("SH_SEED") else 1
	for i in range(CASES.size()):
		var c: Array = CASES[i]
		var x: float = i * SPACING
		var info: Dictionary = ToiletCreator.build(geo, Transform3D(Basis(), Vector3(x, 0.02, 0)), rng, {"floater": c[0], "lid": c[1]})
		var wtr: Vector3 = info.water
		var g: String = "%d %s %s" % [i, c[0], c[1]]
		var n: String = "t%d_%s_%s" % [i, c[0], c[1]]
		_views.append([n + "_front", Vector3(x + 0.6, 1.25, 1.7), Vector3(x, 0.45, 0.35), g])
		_views.append([n + "_bowl", Vector3(x + 0.02, 1.0, 0.95), wtr, g])
		_views.append([n + "_side", Vector3(x + 0.75, 0.75, 0.32), Vector3(x, 0.62, 0.24), g])
		_views.append([n + "_close", Vector3(x + 0.12, 0.62, 0.86), wtr + Vector3(0, 0.02, 0), g])
	_views.push_front(["overview", Vector3(CASES.size() * SPACING * 0.5 - 1.0, 2.0, 4.5), Vector3(CASES.size() * SPACING * 0.5 - 1.0, 0.4, 0), "overview"])

func preview_views() -> Array:
	return _views
