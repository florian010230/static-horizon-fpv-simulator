extends BuiltMap

## Dev lab for HouseCreator (not in the menu): a street of generated
## houses, seeds SH_SEED.. (default 1), and preview cameras round and
## inside each. Shoot it with `godot --path . -- --dev-preview lab HouseLab`
## (pictures + contact sheets + index.html in SH_SHOT_DIR).

const COUNT: int = 4
const SPACING: float = 28.0
const STREET_Z: float = 13.0
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-48, -35, 0), "shadow_region": Rect2(-40, -60, COUNT * SPACING + 40, 120), "clouds": 0.7}

func border() -> Array:
	return [600.0, 800.0, 200.0, 300.0]

func build() -> void:
	geo.add_material("lab_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.add_material("lab_road", Geo.ground_mat(MapTextures.get_tex("asphalt"), Color.WHITE, 7.0, 2, 0.3))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "lab_grass")
	geo.slab(Rect2(-80, STREET_Z, COUNT * SPACING + 160, 7), 0.06, 0.1, "lab_road")
	var t0: int = Time.get_ticks_msec()
	var seed0: int = int(OS.get_environment("SH_SEED")) if OS.has_environment("SH_SEED") else 1
	for i in range(COUNT):
		var p := Vector3(i * SPACING, 0, 0)
		var info: Dictionary = HouseCreator.build(geo, p, 0.0, seed0 + i, {"path_to": STREET_Z})
		for v: Array in info.views:
			_views.append(["s%d_%s" % [seed0 + i, v[0]], v[1], v[2], "seed %d" % (seed0 + i)])
	if OS.has_environment("SH_PERF"):
		print("LAB build %d ms for %d houses" % [Time.get_ticks_msec() - t0, COUNT])
	_views.push_front(["street", Vector3(-25, 9, 30), Vector3(COUNT * SPACING * 0.5, 2, 0), "street"])

func after_build() -> void:
	if not OS.has_environment("SH_PERF"):
		return
	var verts: int = 0
	var draws: int = 0
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m: Mesh = (mi as MeshInstance3D).mesh
		if m == null:
			continue
		for i in range(m.get_surface_count()):
			verts += m.surface_get_array_len(i)
			draws += 1
	print("LAB meshes: %d surfaces, %d vertices" % [draws, verts])

func preview_views() -> Array:
	return _views
