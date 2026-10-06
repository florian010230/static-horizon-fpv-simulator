class_name Collectibles
extends RefCounted

## The collectible game: garden gnomes hidden on the maps. Fly the drone
## through or near one to find it; progress is kept per map id + index in
## user://collectibles.cfg and shown on the menu's Achievements screen.
##
## Maps place their gnomes from after_build() with
##   Collectibles.gnome(self, "map_id", index, Transform3D(basis, position))
## (index 0.. per map, stable - it is the save key; position = the
## gnome's feet on the ground) and declare how many they have in
## MapCatalog ("gnomes": n).
##
## The gnome is NOT part of a map's Geo (no collision, not in the
## floating check or the map cache): one MeshInstance3D with a single
## vertex-colour surface, lit by baked colours like the rest of the game,
## plus an Area3D. A found gnome stays and is drawn faded (grey-green).

const HEIGHT: float = 0.35
const PICKUP_RADIUS: float = 0.45 ## m, from the gnome's middle: through it or close by

## Where progress lives. The self-test and --dev-preview use their own
## file, so they never touch the pilot's.
static func path() -> String:
	var args := OS.get_cmdline_user_args()
	return "user://collectibles_test.cfg" if (args.has("--selftest") or args.has("--dev-preview")) else "user://collectibles.cfg"

static func _load() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(path())
	return cfg

static func is_found(map_id: String, index: int) -> bool:
	return _load().get_value("gnomes", "%s/%d" % [map_id, index], false)

static func found_count(map_id: String) -> int:
	var cfg := _load()
	var n: int = 0
	if cfg.has_section("gnomes"):
		for k in cfg.get_section_keys("gnomes"):
			if k.begins_with(map_id + "/") and cfg.get_value("gnomes", k, false):
				n += 1
	return n

static func found_total() -> int:
	var cfg := _load()
	var n: int = 0
	if cfg.has_section("gnomes"):
		for k in cfg.get_section_keys("gnomes"):
			if cfg.get_value("gnomes", k, false):
				n += 1
	return n

static func mark_found(map_id: String, index: int) -> void:
	var cfg := _load()
	cfg.set_value("gnomes", "%s/%d" % [map_id, index], true)
	cfg.save(path())

## Dev/test: forget everything.
static func reset() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(path()))

# --- placing a gnome -------------------------------------------------------

static func gnome(root: Node3D, map_id: String, index: int, xf: Transform3D) -> void:
	var found: bool = is_found(map_id, index)
	var node := Node3D.new()
	node.name = "Gnome_%d" % index
	node.transform = xf
	node.set_meta("gnome", [map_id, index])
	var mi := MeshInstance3D.new()
	mi.name = "Model"
	mi.mesh = _mesh(root, found)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mi)
	var area := Area3D.new()
	area.name = "Pickup"
	area.monitoring = true
	area.monitorable = false
	var cs := CollisionShape3D.new()
	var sph := SphereShape3D.new()
	sph.radius = PICKUP_RADIUS
	cs.shape = sph
	cs.position = Vector3(0, HEIGHT * 0.55, 0)
	area.add_child(cs)
	node.add_child(area)
	root.add_child(node)
	area.body_entered.connect(func(body: Node3D):
		if body is Drone and not node.get_meta("collected", false):
			_collect(root, node, mi, map_id, index))
	if found:
		node.set_meta("collected", true)

static func _collect(root: Node3D, node: Node3D, mi: MeshInstance3D, map_id: String, index: int) -> void:
	if is_found(map_id, index):
		node.set_meta("collected", true)
		return
	node.set_meta("collected", true)
	mark_found(map_id, index)
	mi.mesh = _mesh(root, true)
	var n: int = found_count(map_id)
	var total: int = MapCatalog.gnome_total(map_id)
	var ui: Node = root.get_node_or_null("UI")
	if ui and ui.has_method("flash_message"):
		ui.flash_message("Gnome found  %d/%d" % [n, total] if total > 0 else "Gnome found  %d" % n)
	_play_blip(root)
	_pop(root, node)
	# A hop for the gnome itself.
	var tw := node.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.25, 0.8, 1.25), 0.06)
	tw.tween_property(mi, "scale", Vector3(0.9, 1.25, 0.9), 0.1)
	tw.tween_property(mi, "scale", Vector3.ONE, 0.2)

## A little burst of sparkles: tiny unshaded spheres flying outwards,
## shrinking away.
static func _pop(root: Node3D, node: Node3D) -> void:
	var m := SphereMesh.new()
	m.radius = 0.02
	m.height = 0.04
	m.radial_segments = 6
	m.rings = 3
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.85, 0.25)
	m.material = mat
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in range(10):
		var s := MeshInstance3D.new()
		s.mesh = m
		s.set_meta("keep_material", true)
		s.set_meta("dynamic", true)
		s.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		s.position = Vector3(0, HEIGHT * 0.6, 0)
		node.add_child(s)
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.3, 1.4), rng.randf_range(-1, 1)).normalized()
		var tw := s.create_tween().set_parallel(true)
		tw.tween_property(s, "position", s.position + dir * rng.randf_range(0.25, 0.5), 0.55).set_ease(Tween.EASE_OUT)
		tw.tween_property(s, "scale", Vector3.ZERO, 0.55).set_delay(0.15)
		tw.chain().tween_callback(s.queue_free)

static var _blip: AudioStreamWAV

static func _play_blip(root: Node) -> void:
	if _blip == null:
		var rate: int = 22050
		var data := PackedByteArray()
		for note in [[1175.0, 0.07], [1568.0, 0.07], [2093.0, 0.16]]:
			var n: int = int(rate * note[1])
			for i in range(n):
				var env: float = minf(1.0, minf(i / 150.0, (n - i) / 500.0))
				var v: float = sin(TAU * note[0] * i / rate) * 0.55 + sin(TAU * note[0] * 2.0 * i / rate) * 0.12
				var q: int = int(clampf(v * env, -1.0, 1.0) * 30000.0)
				data.append(q & 0xFF)
				data.append((q >> 8) & 0xFF)
		_blip = AudioStreamWAV.new()
		_blip.format = AudioStreamWAV.FORMAT_16_BITS
		_blip.mix_rate = rate
		_blip.data = data
	var p := AudioStreamPlayer.new()
	p.stream = _blip
	p.volume_db = -10.0
	root.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

# --- the model -----------------------------------------------------------------

## One surface, vertex colours with a fake light baked in (the engine sun
## does nothing on the dev machine, see CLAUDE.md), shared per map by
## meta. found = the faded variant.
static func _mesh(root: Node3D, found: bool) -> ArrayMesh:
	var key: String = "gnome_mesh_found" if found else "gnome_mesh"
	if root.has_meta(key):
		return root.get_meta(key)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var red := Color(0.84, 0.13, 0.11)
	var blue := Color(0.16, 0.38, 0.78)
	var skin := Color(0.96, 0.74, 0.62)
	var white := Color(0.97, 0.97, 0.95)
	var boot := Color(0.30, 0.18, 0.1)
	var belt := Color(0.22, 0.14, 0.08)
	var grass := Color(0.32, 0.55, 0.24)
	# base tuft, boots, tunic + belt, mittens
	_part(st, _cyl(0.11, 0.09, 0.03), Vector3(0, 0.015, 0), grass, found)
	_part(st, _ball(0.035, 0.028), Vector3(-0.04, 0.05, 0.015), boot, found)
	_part(st, _ball(0.035, 0.028), Vector3(0.04, 0.05, 0.015), boot, found)
	_part(st, _cyl(0.1, 0.068, 0.13), Vector3(0, 0.095, 0), blue, found)
	_part(st, _cyl(0.089, 0.089, 0.018), Vector3(0, 0.105, 0), belt, found)
	_part(st, _ball(0.026, 0.026), Vector3(-0.098, 0.115, 0.012), skin, found)
	_part(st, _ball(0.026, 0.026), Vector3(0.098, 0.115, 0.012), skin, found)
	# head, nose, beard, hat
	_part(st, _ball(0.052, 0.05), Vector3(0, 0.188, 0), skin, found)
	_part(st, _ball(0.02, 0.018), Vector3(0, 0.185, 0.05), Color(0.94, 0.5, 0.45), found)
	_part(st, _cyl(0.0, 0.058, 0.13), Vector3(0, 0.125, 0.035), white, found)
	_part(st, _cyl(0.062, 0.066, 0.016), Vector3(0, 0.222, 0), red.darkened(0.12), found)
	_part(st, _cyl(0.0, 0.062, 0.125), Vector3(0, 0.29, 0), red, found)
	var mesh: ArrayMesh = st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	root.set_meta(key, mesh)
	return mesh

static func _cyl(top_r: float, bottom_r: float, h: float) -> Mesh:
	var m := CylinderMesh.new()
	m.top_radius = top_r
	m.bottom_radius = bottom_r
	m.height = h
	m.radial_segments = 14
	m.rings = 1
	return m

static func _ball(rx: float, ry: float) -> Mesh:
	var m := SphereMesh.new()
	m.radius = rx
	m.height = ry * 2.0
	m.radial_segments = 14
	m.rings = 8
	return m

## Adds a primitive at a position with a flat colour and a fake light
## (top brighter, sides darker, plus a warm key from the front).
static func _part(st: SurfaceTool, m: Mesh, pos: Vector3, col: Color, found: bool) -> void:
	var arr: Array = m.get_mesh_arrays()
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var norms: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	if found:
		var g: float = col.get_luminance()
		col = col.lerp(Color(g * 0.9, g * 1.0, g * 0.92), 0.85).darkened(0.2)
	for i in idx:
		var n: Vector3 = norms[i]
		var l: float = clampf(0.62 + 0.3 * n.y + 0.14 * n.z, 0.45, 1.1)
		st.set_color(Color(col.r * l, col.g * l, col.b * l))
		st.set_normal(n)
		st.add_vertex(verts[i] + pos)
