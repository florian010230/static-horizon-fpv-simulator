extends Node

## The game was called "Static Horizon FPV Sim" up to 0.10.0 and is
## "Static Horizon FPV Simulator" since 0.10.1. Godot names the user://
## folder after the project, so the rename gave every player a new, empty
## folder: settings, radio calibration, records, race ghosts and found
## gnomes would all have been gone after the update. This autoload runs
## first (before InputManager and Settings read anything) and, once,
## copies the old folder's files across. The map and texture caches are
## left behind - they rebuild themselves.

const OLD_NAME: String = "Static Horizon FPV Sim"
const SKIP: Array[String] = ["mapcache", "texcache", "shader_cache", "vulkan", "logs", "objectdb_snapshots"]
const DONE_MARK: String = "user://.migrated_from_fpv_sim"

func _init() -> void:
	var new_dir: String = OS.get_user_data_dir()
	var old_dir: String = new_dir.get_base_dir().path_join(OLD_NAME)
	if old_dir == new_dir or FileAccess.file_exists(DONE_MARK) or not DirAccess.dir_exists_absolute(old_dir):
		return
	var copied: int = _copy_dir(old_dir, new_dir)
	var f := FileAccess.open(DONE_MARK, FileAccess.WRITE)
	if f:
		f.store_string("copied %d files from %s\n" % [copied, old_dir])
	print("User data: copied %d files from %s" % [copied, old_dir])

## Copies files that don't exist in `to` yet (never overwrites).
func _copy_dir(from: String, to: String) -> int:
	var n: int = 0
	DirAccess.make_dir_recursive_absolute(to)
	var d := DirAccess.open(from)
	if d == null:
		return 0
	for file in d.get_files():
		var dst: String = to.path_join(file)
		if not FileAccess.file_exists(dst) and DirAccess.copy_absolute(from.path_join(file), dst) == OK:
			n += 1
	for sub in d.get_directories():
		if not SKIP.has(sub):
			n += _copy_dir(from.path_join(sub), to.path_join(sub))
	return n
