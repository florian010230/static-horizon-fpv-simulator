extends BuiltMap

## Dev lab for TreeCreator (not in the menu): every species in its
## VARIANTS shapes in a row, then one tree per surprise. Shoot it with
## `godot --path . -- --dev-preview lab TreeLab`.

const GAP: float = 9.0
var _views: Array = []

func map_env() -> Dictionary:
	return {"sun_rot": Vector3(-48, -35, 0), "shadow_region": Rect2(-20, -20, 90, 170), "clouds": 0.6}

func border() -> Array:
	return [600.0, 800.0, 200.0, 300.0]

func build() -> void:
	geo.add_material("lab_grass", Geo.ground_mat(MapTextures.get_tex("meadow"), Color.WHITE, 6.0, 0, 0.45))
	geo.slab(Rect2(-3000, -3000, 6000, 6000), 0.0, 0.4, "lab_grass")
	var trees: Array = []
	var t0: int = Time.get_ticks_msec()
	for si in range(TreeCreator.SPECIES.size()):
		var sp: String = TreeCreator.SPECIES[si]
		var z: float = si * GAP * 2.4
		for v in range(TreeCreator.VARIANTS):
			# Seeds picked per variant: the lab wants each shape once.
			trees.append([Vector3(v * GAP, 0, z), sp, _seed_for(sp, v), "none"])
		_views.append([sp, Vector3(GAP, 4.0, z + 15.0), Vector3(GAP, 4.0, z), sp])
	var ez: float = TreeCreator.SPECIES.size() * GAP * 2.4 + 4.0
	var ex: Array = [["birdhouse", "maple"], ["swing", "maple"], ["kite", "birch"], ["drone", "maple"], ["drone", "spruce"]]
	for i in range(ex.size()):
		trees.append([Vector3(i * GAP * 1.2, 0, ez), ex[i][1], 3 + i, ex[i][0]])
	var info: Dictionary = TreeCreator.plant(self, geo, trees)
	if OS.has_environment("SH_PERF"):
		print("LAB trees: %d planted in %d ms" % [info.kept, Time.get_ticks_msec() - t0])
	for i in range(info.extras.size()):
		var e: Array = info.extras[i]
		_views.append(["extra%d_%s" % [i, e[0]], e[2], e[1], "surprises"])
	# Close-ups: apples and hydrangea flowers must sit on the leaves.
	var az: float = 1 * GAP * 2.4
	_views.append(["apple_close", Vector3(GAP, 3.4, az + 5.5), Vector3(GAP, 3.0, az), "close-ups"])
	var bz: float = 4 * GAP * 2.4
	_views.append(["bush_close", Vector3(0, 1.8, bz + 2.8), Vector3(0, 0.8, bz), "close-ups"])
	_views.append(["all", Vector3(-20, 18, 150), Vector3(10, 2, 60), "overview"])

## The first seed (from 1) whose tree draws variant v.
func _seed_for(_sp: String, v: int) -> int:
	for s in range(1, 200):
		var rng := RandomNumberGenerator.new()
		rng.seed = s
		if rng.randi() % TreeCreator.VARIANTS == v:
			return s
	return v

func after_build() -> void:
	if not OS.has_environment("SH_PERF"):
		return
	var verts: int = 0
	for mm in find_children("*", "MultiMeshInstance3D", true, false):
		var m: MultiMesh = (mm as MultiMeshInstance3D).multimesh
		verts += m.mesh.surface_get_array_len(0) * m.instance_count
	print("LAB tree vertices drawn near: %d" % verts)

func preview_views() -> Array:
	return _views
