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
	var drone: String = flown_drone(map_id)
	if drone != "" and not cfg.get_value("drones", drone, false):
		cfg.set_value("drones", drone, true)
		changed = true
	if changed:
		cfg.save(Collectibles.path())

## The drone flown on a map: the map's own if it forces one.
static func flown_drone(map_id: String) -> String:
	for m in MapCatalog.MAPS:
		if m.id == map_id and str(m.get("drone", "any")) != "any":
			return str(m.drone)
	return Settings.selected_drone

## The drones a map can be flown with.
static func _drones_for(map_id: String) -> Array[String]:
	for m in MapCatalog.MAPS:
		if m.id == map_id and str(m.get("drone", "any")) != "any":
			return [str(m.drone)]
	return Drone.PROFILE_ORDER

static func drones_flown() -> int:
	var cfg := _cfg()
	var n: int = 0
	for d in Drone.PROFILE_ORDER:
		if cfg.get_value("drones", d, false):
			n += 1
	return n

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
	var pb_tracks: int = 0
	var n_tracks: int = 0
	var raced_maps: int = 0 # a race finished on the map
	var hardest: int = 0 # a lap time on the map's last (hardest) track
	var combos: int = 0 # track x drone with a lap time
	var n_combos: int = 0
	for id in race_maps:
		var n: int = RaceCourse.track_list(id).size()
		var raced: bool = false
		for t in range(1, n + 1):
			n_tracks += 1
			if not RaceCourse.boards(id, t).is_empty():
				finished = true
				raced = true
			var rec: Dictionary = RaceCourse.records(id, t)
			if not rec.is_empty():
				pb_tracks += 1
				if t == n:
					hardest += 1
			var ds: Array[String] = _drones_for(id)
			for d in ds:
				n_combos += 1
				# (records are keyed by the menu's drone; a map that forces
				# its own drone counts any record)
				if rec.has(d) or (ds.size() == 1 and not rec.is_empty()):
					combos += 1
		if raced:
			raced_maps += 1
	out.append({"name": "Race finished", "text": "Complete a %d-lap race." % RaceCourse.LAPS, "done": finished, "progress": ""})
	out.append({"name": "Personal best everywhere", "text": "Set a lap time on every race track.", "done": pb_tracks >= n_tracks and n_tracks > 0, "progress": "%d/%d" % [pb_tracks, n_tracks]})
	out.append({"name": "Race every map", "text": "Finish a race on every race map.", "done": raced_maps >= race_maps.size() and race_maps.size() > 0, "progress": "%d/%d" % [raced_maps, race_maps.size()]})
	out.append({"name": "Hardest lines", "text": "Set a lap time on the hardest track of every race map.", "done": hardest >= race_maps.size() and race_maps.size() > 0, "progress": "%d/%d" % [hardest, race_maps.size()]})
	out.append({"name": "All-rounder", "text": "Set a lap time on every race track with every drone.", "done": combos >= n_combos and n_combos > 0, "progress": "%d/%d" % [combos, n_combos]})
	var flown: int = drones_flown()
	out.append({"name": "Hangar", "text": "Fly every drone.", "done": flown >= Drone.PROFILE_ORDER.size(), "progress": "%d/%d" % [flown, Drone.PROFILE_ORDER.size()]})
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
