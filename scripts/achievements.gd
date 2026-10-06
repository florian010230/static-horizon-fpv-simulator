class_name Achievements
extends RefCounted

## A few simple achievements, worked out from data the game keeps anyway
## (personal bests, race boards, gnomes) plus two small flags kept next to
## the gnome progress (Collectibles.path()): first flight and the maps
## flown. Secondary feature - shown on the menu's Achievements screen.

static func _cfg() -> ConfigFile:
	var cfg := ConfigFile.new()
	cfg.load(Collectibles.path())
	return cfg

static func flag(name: String) -> bool:
	return _cfg().get_value("flags", name, false)

static func set_flag(name: String) -> void:
	var cfg := _cfg()
	if cfg.get_value("flags", name, false):
		return
	cfg.set_value("flags", name, true)
	cfg.save(Collectibles.path())

## Called from the HUD when the drone is armed on a map.
static func note_flight(map_id: String) -> void:
	var cfg := _cfg()
	var changed: bool = false
	if not cfg.get_value("flags", "first_flight", false):
		cfg.set_value("flags", "first_flight", true)
		changed = true
	if map_id != "" and not cfg.get_value("visited", map_id, false):
		cfg.set_value("visited", map_id, true)
		changed = true
	if changed:
		cfg.save(Collectibles.path())

static func visited_count() -> int:
	var cfg := _cfg()
	var n: int = 0
	for id in MapCatalog.map_ids():
		if cfg.get_value("visited", id, false):
			n += 1
	return n

static func _race_maps() -> Array[String]:
	var out: Array[String] = []
	for m in MapCatalog.available():
		if MapCatalog.is_race(m):
			out.append(m.id)
	return out

## [{id, name, text, done, progress: "2/3" or ""}]
static func list() -> Array:
	var out: Array = []
	var maps: Array[String] = MapCatalog.map_ids()
	out.append({"name": "First flight", "text": "Arm a drone on any map.", "done": flag("first_flight") or visited_count() > 0, "progress": ""})
	var explored: int = visited_count()
	out.append({"name": "Explorer", "text": "Fly on every map.", "done": explored >= maps.size(), "progress": "%d/%d" % [explored, maps.size()]})
	var race_maps: Array[String] = _race_maps()
	var finished: bool = false
	var pb_maps: int = 0
	for id in race_maps:
		if not RaceCourse.boards(id).is_empty():
			finished = true
		if not RaceCourse.records(id).is_empty():
			pb_maps += 1
	out.append({"name": "Race finished", "text": "Complete a three-lap race.", "done": finished, "progress": ""})
	out.append({"name": "Personal best everywhere", "text": "Set a lap time on every race track.", "done": pb_maps >= race_maps.size() and not race_maps.is_empty(), "progress": "%d/%d" % [pb_maps, race_maps.size()]})
	var total_found: int = Collectibles.found_total()
	out.append({"name": "Gnome spotter", "text": "Find your first garden gnome.", "done": total_found > 0, "progress": ""})
	var all_total: int = 0
	var full_maps: int = 0
	var gnome_maps: int = 0
	for id in maps:
		var t: int = MapCatalog.gnome_total(id)
		all_total += t
		if t > 0:
			gnome_maps += 1
			if Collectibles.found_count(id) >= t:
				full_maps += 1
	out.append({"name": "Map cleared", "text": "Find every gnome on one map.", "done": full_maps > 0, "progress": "%d/%d maps" % [full_maps, gnome_maps]})
	out.append({"name": "Gnome collector", "text": "Find every gnome in the game.", "done": all_total > 0 and total_found >= all_total, "progress": "%d/%d" % [total_found, all_total]})
	return out
