class_name MapCache
extends RefCounted

## Load cache for the generated maps. A map is the same every load (its
## creators draw from fixed seeds), so the finished result of build() -
## Geo's batched meshes and collision, the terrain, trees, rocks, cars,
## flowers, labels: every node the build added under the map - is saved
## once as a binary scene in user://mapcache and instantiated next time
## instead of building again (the map's script state that is needed
## after the build travels along, see BuiltMap.cache_state).
##
## On for every generated map unless it says no (BuiltMap.cacheable()): a map whose build leaves
## anything behind that can't be saved as nodes (signals, node references
## kept in script variables, scripts on generated nodes) must not say
## yes. The cache throws itself away when anything that could change the
## result changes: the file name carries a hash of every script, shader
## and map scene source (exported builds carry no source - the game's
## version instead, as MapTextures does), the graphics quality (tree
## draw distances are set at build time) and the engine version.
##
## Not used (always built fresh) when a dev check needs the build itself:
## SH_FLOAT, SH_IDS, SH_GNOMES, SH_ROADCHECK, SH_PLOTCHECK, SH_NOCACHE
## and the self-test (--selftest; its floating check needs Geo's records).

const DIR := "user://mapcache"
const NO_CACHE_VARS: Array[String] = ["SH_NOCACHE", "SH_FLOAT", "SH_IDS", "SH_GNOMES", "SH_ROADCHECK", "SH_PLOTCHECK", "SH_PIECE_VIEWS", "SH_SURFCHECK"]
## The self-test's cache check (SH_SELFTEST_ONLY=cache) turns it on.
static var force: bool = false
static var _src_key: String = ""

static func enabled(map: BuiltMap) -> bool:
	if not map.cacheable():
		return false
	for v in NO_CACHE_VARS:
		if OS.has_environment(v):
			return false
	return force or not OS.get_cmdline_user_args().has("--selftest")

## user://mapcache/<scene>-<key>.scn (and <same>-shadow.png, WorldShading).
static func path(map: Node, suffix: String = ".scn") -> String:
	return "%s/%s-%s%s" % [DIR, _map_name(map), key(), suffix]

static func _map_name(map: Node) -> String:
	return map.scene_file_path.get_file().get_basename() if map.scene_file_path != "" else String(map.name)

static func key() -> String:
	return "%s-q%d" % [_sources_key(), clampi(Settings.graphics_quality, 0, 2)]

## Hash of every source that can change what a map builds (all of
## scripts/, shaders/ and scenes/maps/), the engine version; or, in an
## exported build (no sources), the game's version.
static func _sources_key() -> String:
	if _src_key != "":
		return _src_key
	var files: Array = []
	for d in ["res://scripts", "res://shaders", "res://scenes/maps"]:
		_collect(d, files)
	files.sort()
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	var n_src: int = 0
	for f: String in files:
		var b: PackedByteArray = FileAccess.get_file_as_bytes(f)
		if b.is_empty():
			continue
		n_src += 1
		ctx.update(f.to_utf8_buffer())
		ctx.update(b)
	ctx.update(str(Engine.get_version_info().hex).to_utf8_buffer())
	if n_src == 0 or not files.any(func(f: String) -> bool: return f.ends_with(".gd")):
		_src_key = "v" + str(ProjectSettings.get_setting("application/config/version", "0")).replace(".", "_")
	else:
		_src_key = ctx.finish().hex_encode().substr(0, 12)
	return _src_key

static func _collect(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd") or f.ends_with(".gdshader") or f.ends_with(".gdshaderinc") or f.ends_with(".tscn"):
			out.append(dir.path_join(f))
	for s in d.get_directories():
		_collect(dir.path_join(s), out)

## Puts the cached build under `map`; returns its saved script state, or
## null when there is no valid cache (then build as usual).
static func restore(map: BuiltMap) -> Variant:
	var p: String = path(map)
	if not FileAccess.file_exists(p):
		return null
	var ps := ResourceLoader.load(p, "PackedScene", ResourceLoader.CACHE_MODE_IGNORE) as PackedScene
	if ps == null:
		return null
	var holder: Node = ps.instantiate()
	if holder == null:
		return null
	var state: Dictionary = holder.get_meta("state", {})
	# Moved over before they enter the tree: one enter-tree per node.
	for c in holder.get_children():
		holder.remove_child(c)
		_own(c, null)
		map.add_child(c)
	holder.free()
	return state

## Saves every child of `map` not in `keep` (what existed before the
## build: Drone, UI, environment, sun) plus `state`. Call right after the
## build, before WorldShading converts the materials. Returns the file
## size in bytes (0 = failed).
static func save(map: BuiltMap, keep: Array, state: Dictionary) -> int:
	var holder := Node3D.new()
	holder.name = "MapCache"
	var moved: Array = []
	for c in map.get_children():
		if not keep.has(c):
			moved.append(c)
	for c: Node in moved:
		map.remove_child(c)
		holder.add_child(c)
		_own(c, holder)
	holder.set_meta("state", state)
	var ps := PackedScene.new()
	var err: int = ps.pack(holder)
	for c: Node in moved:
		holder.remove_child(c)
		_own(c, null)
		map.add_child(c)
	holder.free()
	if err != OK:
		push_warning("MapCache: could not pack %s (%d)" % [map.name, err])
		return 0
	DirAccess.make_dir_recursive_absolute(DIR)
	_sweep(map)
	var p: String = path(map)
	err = ResourceSaver.save(ps, p, ResourceSaver.FLAG_COMPRESS)
	if err != OK:
		push_warning("MapCache: could not save %s (%d)" % [p, err])
		return 0
	var f := FileAccess.open(p, FileAccess.READ)
	return f.get_length() if f else 0

## Every node below n belongs to `owner` (PackedScene saves only owned nodes).
static func _own(n: Node, owner: Node) -> void:
	n.owner = owner
	for c in n.get_children():
		_own(c, owner)

## Older caches of this map (other sources, other quality) go.
static func _sweep(map: Node) -> void:
	var d := DirAccess.open(DIR)
	if d == null:
		return
	var pre: String = _map_name(map) + "-"
	for f in d.get_files():
		if f.begins_with(pre):
			d.remove(f)

## Dev check (SH_MAPHASH=1, printed once the map is up): a hash over
## every mesh's vertices and colours, every MultiMesh buffer, every
## collision shape and label under the map, in tree order - equal for a
## fresh build and its cached load, and for two fresh builds (a map
## that isn't deterministic can't be cached).
static func fingerprint(map: Node) -> String:
	var parts: Dictionary = {"mesh": 0, "multimesh": 0, "shape": 0, "label": 0}
	var counts: Dictionary = {"mesh": 0, "multimesh": 0, "shape": 0, "label": 0}
	var stack: Array = [map]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Drone or n is CanvasLayer:
			continue
		var h: int = 0
		var kind: String = ""
		if n is MeshInstance3D and (n as MeshInstance3D).mesh is ArrayMesh:
			var m: ArrayMesh = (n as MeshInstance3D).mesh
			kind = "mesh"
			for s in range(m.get_surface_count()):
				var a: Array = m.surface_get_arrays(s)
				h = hash([h, a[Mesh.ARRAY_VERTEX], a[Mesh.ARRAY_COLOR], (n as Node3D).global_transform])
		elif n is MultiMeshInstance3D and (n as MultiMeshInstance3D).multimesh:
			kind = "multimesh"
			h = hash([(n as MultiMeshInstance3D).multimesh.buffer, (n as Node3D).global_transform])
		elif n is CollisionShape3D and (n as CollisionShape3D).shape:
			kind = "shape"
			var sh: Shape3D = (n as CollisionShape3D).shape
			var d: Variant = sh.get_faces() if sh is ConcavePolygonShape3D else (sh.points if sh is ConvexPolygonShape3D else (sh.map_data if sh is HeightMapShape3D else [sh.get_class(), sh.get("size"), sh.get("radius"), sh.get("height")]))
			h = hash([d, (n as Node3D).global_transform])
		elif n is Label3D:
			kind = "label"
			h = hash([(n as Label3D).text, (n as Node3D).global_transform])
		if kind != "":
			parts[kind] = hash([parts[kind], h])
			counts[kind] += 1
		var ch: Array = n.get_children()
		ch.reverse()
		stack.append_array(ch)
	var out: String = ""
	for k: String in parts:
		out += "%s %d %08x  " % [k, counts[k], parts[k] & 0xffffffff]
	return out
