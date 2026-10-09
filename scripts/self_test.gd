extends Node

## Dev tool: an end-to-end self-test of the actual game, the way a pilot
## plays it - not the physics in isolation. Registered as an autoload but
## does nothing unless the game is started with:
##
##     godot --headless --path . -- --selftest
##
## Written after "the drone doesn't take off" turned out to be invisible
## to the physics-only tests: those set the throttle directly, while the
## real bug sat in the input path (a plugged-in radio sending no data
## read as 50% throttle, so the drone could never be armed). Everything
## here goes through InputManager exactly like real input: keypresses
## and radio stick/button events are injected with
## Input.parse_input_event().
##
## For every map and drone it checks: the drone settles at spawn (not
## falling through, not jittering, inside the flight area), arms, and
## climbs - with the keyboard, and with a (simulated) radio if one is
## plugged in - then that R resets it to spawn. Also the menu flow into
## a map, and performance mode. Prints one PASS/FAIL line per check and
## exits with code 1 if anything failed.

var _failures: int = 0
var _checks: int = 0

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--selftest"):
		return
	call_deferred("_run")

func _run() -> void:
	# A fresh install starts with the realism extras off: no wind, no
	# battery sag, no prop damage (the defaults in settings.gd).
	var fresh: Node = (load("res://scripts/settings.gd") as GDScript).new()
	_check(fresh.wind_level == 0 and not fresh.battery_enabled and not fresh.prop_damage, "settings: wind, battery sag and prop damage are off by default",
		"wind %d battery %s prop damage %s" % [fresh.wind_level, fresh.battery_enabled, fresh.prop_damage])
	fresh.free()
	Settings.units = 1
	var imp: bool = Settings.speed_text(10.0) == "22mph" and Settings.height_text(10.0) == "33ft" and Settings.spec_tag("150 km/h") == "93 mph"
	Settings.units = 0
	_check(imp and Settings.speed_text(10.0) == "36km/h", "units: metric and imperial conversions")
	# Betaflight Actual Rates: ends exact, and default expo ~ the old cubic.
	var full: float = Rates.rate_deg(Rates.ACTUAL, [70.0, 670.0, 0.54], 1.0)
	var half: float = Rates.rate_deg(Rates.ACTUAL, [70.0, 670.0, 0.54], 0.5)
	var cubic_half: float = 70.0 * 0.5 + 600.0 * 0.125
	_check(is_equal_approx(full, 670.0) and Rates.rate_deg(Rates.ACTUAL, [70.0, 670.0, 0.54], 0.0) == 0.0 and absf(half - cubic_half) < 3.0 and Rates.rate_deg(Rates.ACTUAL, [70.0, 670.0, 0.54], -1.0) < -669.0, "rates: Betaflight Actual formula", "half stick %.1f vs cubic %.1f deg/s" % [half, cubic_half])
	# The other Betaflight rate types at full stick (Configurator's numbers).
	var bf: float = Rates.rate_deg(Rates.BETAFLIGHT, [1.0, 0.7, 0.0], 1.0)
	var quick: float = Rates.rate_deg(Rates.QUICK, [1.0, 670.0, 0.0], 1.0)
	var kiss: float = Rates.rate_deg(Rates.KISS, [1.0, 0.7, 0.0], 1.0)
	_check(absf(bf - 666.7) < 1.0 and absf(quick - 670.0) < 1.0 and absf(kiss - 666.7) < 1.0 and absf(Rates.rate_deg(Rates.QUICK, [1.0, 670.0, 0.0], 0.05) - 10.0) < 1.0, "rates: Betaflight, Quick and KISS formulas", "BF %.1f Quick %.1f KISS %.1f" % [bf, quick, kiss])
	_check(is_equal_approx(Settings.throttle_curve(0.3), 0.3), "throttle: MID 0.5 / EXPO 0 leaves the throttle alone")
	Settings.throttle_expo = 1.0
	var te: float = Settings.throttle_curve(0.75)
	Settings.throttle_expo = 0.0
	_check(absf(te - 0.5625) < 0.001, "throttle: Betaflight EXPO curve", "%.4f" % te)
	# Dev aid: SH_SELFTEST_ONLY=menu,reset,realism,race,gnomes runs just those parts.
	if OS.has_environment("SH_SELFTEST_ONLY"):
		var only: PackedStringArray = OS.get_environment("SH_SELFTEST_ONLY").split(",")
		if only.has("menu"):
			await _test_menu_flow()
		if only.has("reset"):
			await _test_reset_switch()
		if only.has("realism"):
			await _test_realism()
		if only.has("race"):
			await _test_race()
		if only.has("video"):
			await _test_video_link()
		if only.has("gnomes"):
			await _test_collectibles()
		if only.has("cache"):
			await _test_map_cache()
		print("SELFTEST DONE: %d checks, %d failed" % [_checks, _failures])
		get_tree().quit(1 if _failures > 0 else 0)
		return
	await _test_menu_flow()
	_test_updater()
	await _test_collectibles()
	await _test_calibration_and_arm_switch()
	_test_creators()
	var cases: Array = [
		["res://scenes/maps/Village.tscn", "seeker3"],
		["res://scenes/maps/Village.tscn", "five"],
		["res://scenes/maps/Village.tscn", "whoop"],
		["res://scenes/maps/Factory.tscn", "seeker3"],
		["res://scenes/maps/Factory.tscn", "five"],
		["res://scenes/maps/Factory.tscn", "whoop"],
		["res://scenes/Main3.tscn", "whoop"],
		["res://scenes/Main3.tscn", "seeker3"], # the school must force the whoop anyway
		["res://scenes/maps/Playground.tscn", "five"], # forced to the whoop too
		["res://scenes/maps/RaceField.tscn", "five"],
		["res://scenes/maps/RaceField.tscn", "race"],
		["res://scenes/maps/Village.tscn", "race"],
		["res://scenes/maps/SteelMill.tscn", "seeker3"],
		["res://scenes/maps/RaceArena.tscn", "seeker3"],
		["res://scenes/maps/Office.tscn", "seeker3"], # forced to the whoop
		["res://scenes/maps/ParkingGarage.tscn", "five"],
		["res://scenes/maps/ConstructionSite.tscn", "five"],
		["res://scenes/maps/Harbour.tscn", "seeker3"],
		["res://scenes/maps/MountainLake.tscn", "five"],
		["res://scenes/maps/TestValley.tscn", "whoop"],
	]
	for c in cases:
		await _test_map(c[0], c[1], false)
	await _test_race()
	await _test_realism()
	await _test_video_link()
	await _test_reset_switch()
	Settings.performance_mode = true
	await _test_map("res://scenes/maps/Factory.tscn", "seeker3", true)
	await _test_map("res://scenes/Main3.tscn", "whoop", true)
	Settings.performance_mode = false
	await _tap(KEY_ESCAPE)
	await _wait(0.1)
	_find_button(get_tree().current_scene.get_node("UI").pause_menu, "Main menu").pressed.emit()
	for i in range(40):
		await _wait(0.1)
		if not SceneLoader.is_loading() and get_tree().current_scene and get_tree().current_scene.scene_file_path.ends_with("MainMenu.tscn"):
			break
	_check(get_tree().current_scene.scene_file_path == "res://scenes/MainMenu.tscn" and not get_tree().paused, "pause: Main menu button returns to the menu, unpaused")
	print("SELFTEST DONE: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## The creators with many seeds, level and on steep hills (CreatorCheck):
## nothing they build may float, every kind gets built.
func _test_creators() -> void:
	var r: Dictionary = CreatorCheck.run()
	_check(r.floating.is_empty(), "creators: nothing floats (town houses, industry, farm, fields; level and hills)", "%d floating: %s" % [r.floating.size(), str(r.floating.slice(0, 3))])
	_check(r.houses >= 50 and r.halls == 6 and r.crops == 2 * FieldCreator.CROPS.size(), "creators: every kind built", "%d houses, %d halls, %d fields in %d ms" % [r.houses, r.halls, r.crops, r.ms])

func _check(ok: bool, what: String, detail: String = "") -> void:
	_checks += 1
	if not ok:
		_failures += 1
	print("SELFTEST %s %s %s" % ["PASS" if ok else "FAIL", what, detail])

func _wait(s: float) -> void:
	await get_tree().create_timer(s).timeout

func _key(k: Key, pressed: bool) -> void:
	var e := InputEventKey.new()
	e.keycode = k
	e.physical_keycode = k
	e.pressed = pressed
	Input.parse_input_event(e)

func _tap(k: Key) -> void:
	_key(k, true)
	await get_tree().process_frame
	await get_tree().process_frame
	_key(k, false)
	await get_tree().process_frame

func _joy_axis(axis: int, value: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.device = InputManager.joystick_device
	e.axis = axis
	e.axis_value = value
	Input.parse_input_event(e)

func _drone() -> Drone:
	var scene: Node = get_tree().current_scene
	return scene.get_node_or_null("Drone") as Drone if scene else null

func _test_menu_flow() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await _wait(0.8)
	var menu: Node = get_tree().current_scene
	var next: Button = _find_button(menu, "next_drone")
	var before: String = Settings.selected_drone
	if next:
		next.pressed.emit()
	_check(next != null and Settings.selected_drone != before, "menu: arrow switches drone", "%s -> %s" % [before, Settings.selected_drone])
	if next:
		next.pressed.emit()
	var about_btn: Button = _find_button(menu._screens["main"], "About")
	about_btn.pressed.emit()
	await _wait(0.2)
	_check(menu._screens["about"].visible and not menu._screens["main"].visible, "menu: About opens")
	_find_button(menu._screens["about"], "Licences").pressed.emit()
	await _wait(0.2)
	var lic: String = menu.get("_licences_text").text
	_check(menu._screens["licences"].visible and lic.contains("Godot Engine contributors") and lic.contains("OFL-1.1") and lic.contains("PolyForm Noncommercial"),
		"menu: Licences lists the game's, the font's and the engine's licences", "%d chars" % lic.length())
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	_check(menu._screens["about"].visible, "menu: Esc in Licences goes back to About")
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	_check(menu._screens["main"].visible and not menu._screens["about"].visible, "menu: Esc in About goes back home")
	for scr in ["Updates", "Achievements"]:
		_find_button(menu._screens["main"], scr).pressed.emit()
		await _wait(0.2)
		_check(menu._screens[scr.to_lower()].visible and not menu._screens["main"].visible, "menu: %s opens" % scr)
		await _tap(KEY_ESCAPE)
		await _wait(0.2)
		_check(menu._screens["main"].visible and not menu._screens[scr.to_lower()].visible, "menu: Esc in %s goes back home" % scr)
	var settings_btn: Button = _find_button(menu, "Settings")
	settings_btn.pressed.emit()
	await _wait(0.2)
	var settings: Control = menu.get("_settings")
	_check(settings.visible and not menu._screens["main"].visible, "menu: Settings opens from home")
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	_check(not settings.visible and menu._screens["main"].visible, "menu: Esc in Settings goes back to the home screen")
	var play: Button = _find_button(menu, "Play")
	if play:
		play.pressed.emit()
	await _wait(0.2)
	_check(menu._screens["mode"].visible, "menu: Play asks for the mode first")
	_find_button(menu._screens["mode"], "Race").pressed.emit()
	await _wait(0.2)
	var race_cards: int = 0
	for c in menu._map_grid.get_children():
		if c.visible:
			race_cards += 1
	_check(race_cards == 3, "menu: Race mode lists the race tracks only", "%d cards" % race_cards)
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	_find_button(menu._screens["mode"], "Freestyle").pressed.emit()
	await _wait(0.2)
	var village: Button = _find_button(menu, "Village")
	if village:
		village.pressed.emit()
	await get_tree().process_frame
	_check(SceneLoader.is_loading(), "menu: map load goes through the loading screen")
	await _wait(2.5)
	var scene: Node = get_tree().current_scene
	_check(scene != null and scene.scene_file_path == "res://scenes/maps/Village.tscn", "menu: Play -> Village loads the map")
	_check(Engine.max_fps == Settings.max_fps, "menu: FPS cap restored in game", "max_fps=%d" % Engine.max_fps)
	# "Full screen resolution" off works through this override file.
	_check(ProjectSettings.get_setting("application/config/project_settings_override", "") == Settings.DISPLAY_OVERRIDE, "settings: the reduced-resolution file is the project's settings override")
	# Unlimited must also switch VSync off, or the screen's refresh rate
	# caps it anyway (60 FPS in 0.10.0). Headless has no real VSync.
	if DisplayServer.get_name() != "headless":
		var cap: int = Settings.max_fps
		Settings.set_max_fps(0)
		Settings.set_vsync(false)
		_check(Engine.max_fps == 0 and DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_DISABLED, "menu: VSync off really lets Unlimited past the refresh rate")
		Settings.set_vsync(true)
		_check(DisplayServer.window_get_vsync_mode() == DisplayServer.VSYNC_ENABLED, "menu: VSync back on")
		Settings.set_max_fps(cap)

## Version compare, GitHub's release JSON, the offline notes, markdown.
func _test_updater() -> void:
	_check(Updater.is_newer("v0.10.0", "0.9.0") and Updater.is_newer("1.0.0", "0.9.9") and not Updater.is_newer("v0.9.0", "0.9.0") and not Updater.is_newer("0.8.9", "0.9.0") and not Updater.is_newer("0.9.0-beta", "0.9.0"), "updater: semantic version compare")
	var saved: Dictionary = Updater.latest
	var ok: bool = Updater.apply_response(200, '{"tag_name": "v9.9.9", "html_url": "https://example.org/r", "body": "# Hi\\n- one"}')
	_check(ok and Updater.newer_available() and Updater.latest.version == "9.9.9" and Updater.latest.url == "https://example.org/r", "updater: parses a release and sees it is newer")
	_check(not Updater.apply_response(404, "{}") and not Updater.apply_response(200, "nonsense"), "updater: errors and junk are ignored")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Updater.cache_path()))
	Updater.latest = saved
	_check(Changelog.notes_for(Updater.current_version()) != "", "updater: the installed version has bundled release notes")
	var box := VBoxContainer.new()
	Updater.add_notes(box, "# Title\n- a **bold** [link](http://x)\ntext")
	_check(box.get_child_count() == 3 and (box.get_child(1) as Label).text == "·  a bold link", "updater: markdown notes become labels")
	box.free()

## A gnome is picked up by flying the drone into it, remembered, and
## counted on the Achievements screen.
func _test_collectibles() -> void:
	Collectibles.reset()
	_check(MapCatalog.gnome_total("playground") == 1 and Collectibles.found_count("playground") == 0, "gnomes: playground hides one, none found yet")
	Settings.selected_drone = "whoop"
	get_tree().change_scene_to_file("res://scenes/maps/Playground.tscn")
	await _wait(2.0)
	var sc: Node = get_tree().current_scene
	var g: Node3D = sc.get_node_or_null("Gnome_0")
	_check(g != null, "gnomes: the map places its gnome")
	if g == null:
		return
	var d: Drone = _drone()
	d.global_position = g.global_position + Vector3(2, 1, 0)
	await _wait(0.3)
	_check(Collectibles.found_count("playground") == 0, "gnomes: not found from a distance")
	d.global_position = g.global_position + Vector3(0, 0.2, 0)
	d.linear_velocity = Vector3.ZERO
	await _wait(0.5)
	_check(Collectibles.found_count("playground") == 1 and Collectibles.is_found("playground", 0), "gnomes: flying into the gnome collects it")
	var model := g.get_node("Model") as MeshInstance3D
	_check(model.mesh == sc.get_meta("gnome_mesh_found"), "gnomes: a found gnome turns grey")
	d.global_position = g.global_position + Vector3(3, 1, 0)
	await _wait(Collectibles.FADED_TIME + 0.5)
	_check(model.mesh == sc.get_meta("gnome_mesh"), "gnomes: ... and looks normal again after %d s" % int(Collectibles.FADED_TIME))
	var done: bool = false
	for a in Achievements.list():
		if a.name == "Map cleared":
			done = a.done
	_check(done, "achievements: all gnomes on a map")
	Collectibles.reset()

var _float_checked: Dictionary = {}

func _test_map(map: String, drone_id: String, perf: bool) -> void:
	var tag: String = "%s/%s%s" % [map.get_file().get_basename(), drone_id, " [performance]" if perf else ""]
	InputManager.armed = false
	InputManager.self_level = true
	Settings.selected_drone = drone_id
	get_tree().change_scene_to_file(map)
	await _wait(2.0)
	var d: Drone = _drone()
	if d == null:
		_check(false, tag + ": map loads with a drone")
		return
	var sc: Node = get_tree().current_scene
	if sc is BuiltMap and not _float_checked.has(map):
		_float_checked[map] = true
		var fl: Array = (sc as BuiltMap).floating_pieces()
		_check(fl.is_empty(), tag + ": nothing floats in the air", str(fl.slice(0, 3)))
		if sc.has_method("surface_glitches"):
			var sg: Array = sc.surface_glitches()
			_check(sg.is_empty(), tag + ": no terrain through roads or rails", "%d spots: %s" % [sg.size(), str(sg.slice(0, 3))])
		# Ground surfaces: no terrain through roads/paving, no road or yard
		# hanging over the land, nothing stacked close enough to flicker.
		var sr: Dictionary = SurfaceCheck.run(sc as BuiltMap)
		var sv: String = SurfaceCheck.verdict(sc.name, sr)
		_check(sv == "", tag + ": ground surfaces clean (no poke-through, hanging road edge or flicker)", sv if sv != "" else "%d faces, %d ms" % [sr.tris, sr.ms])
	var forced: String = MapCatalog.forced_drone(map)
	var expected_profile: String = forced if forced != "" else drone_id
	_check(Settings.selected_drone == expected_profile, tag + ": right drone profile", Settings.selected_drone)
	_check(Engine.physics_ticks_per_second == (240 if perf else 120), tag + ": physics rate", str(Engine.physics_ticks_per_second))
	_check(d.contact_monitor == perf, tag + ": contact monitor", str(d.contact_monitor))

	# Resting at spawn: settled, not sinking, no border warning.
	var y0: float = d.global_position.y
	await _wait(1.0)
	var settle_speed: float = d.linear_velocity.length()
	_check(settle_speed < 0.05 and absf(d.global_position.y - y0) < 0.02, tag + ": rests still at spawn", "v=%.3f dy=%.3f" % [settle_speed, d.global_position.y - y0])
	# (The whoop once dropped through a gap in Mountain Lake's pier.)
	_check(d.global_position.y > d._spawn_transform.origin.y - 0.5, tag + ": rests where it was set down, not fallen through", "%.2f below spawn" % (d._spawn_transform.origin.y - d.global_position.y))
	var ui: Node = get_tree().current_scene.get_node_or_null("UI")
	var warn: bool = ui != null and ui._border_label.visible
	_check(not warn, tag + ": spawn inside the flight area")

	Settings.wind_level = 2
	var wind: float = d._wind().length()
	Settings.wind_level = 0
	var indoor: bool = MapCatalog.for_scene(map).get("indoor", false)
	_check((wind == 0.0) if indoor else (wind > 1.0), tag + ": wind " + ("off indoors" if indoor else "blows outdoors"), "%.1f m/s" % wind)
	await _test_pause_menu(tag, d, map)

	# Keyboard: Enter to arm, hold Shift to raise throttle.
	var rest_y: float = d.global_position.y
	await _tap(KEY_ENTER)
	_check(InputManager.armed, tag + ": keyboard arms", "throttle=%.2f can_arm=%s" % [InputManager.get_throttle(), InputManager.can_arm()])
	if InputManager.radio_status() == "active":
		_check(false, tag + ": keyboard path", "a radio is actively sending - keyboard test skipped")
	else:
		_key(KEY_SHIFT, true)
		# The 5-inch has 9:1 thrust-to-weight: 84% throttle for the whole
		# steering test takes it past the 170 m altitude reset.
		# (The office has a 3 m ceiling: the usual climb pins the whoop
		# against it and W can't move it.)
		# The Static Whoop has ~7:1 thrust-to-weight too (since 2026-10-02):
		# indoors it'd go straight into the ceiling (school gym 8.5 m).
		var hold: float = 0.75 if Settings.selected_drone in ["five", "race"] else (0.95 if map.ends_with("Office.tscn") else 1.4)
		if Settings.selected_drone == "whoop" and (map.ends_with("Office.tscn") or map.ends_with("Main3.tscn")):
			hold = 0.7 if map.ends_with("Office.tscn") else 0.6
		await _wait(hold)
		_key(KEY_SHIFT, false)
		await _wait(1.2)
		var climbed: float = d.global_position.y - rest_y
		_check(climbed > 1.0, tag + ": takes off (keyboard)", "climbed %.2f m, throttle %.2f" % [climbed, InputManager.get_throttle()])
		_check(d.battery.used_mah > 0.1 and d.battery.cell_v < d.battery.rest_cell_v(1.0) and d.flight_time > 1.0, tag + ": battery drains and flight timer runs", "%.1f mAh, %.2f V/cell, %.1f s" % [d.battery.used_mah, d.battery.cell_v, d.flight_time])
		var osd: Dictionary = get_tree().current_scene.get_node("UI")._osd_labels
		_check(osd.has("time") and osd.time.text.begins_with("00:0") and osd.time.visible and osd.spd.text.ends_with("km/h") and osd.thr.visible and osd.bat.visible == Settings.battery_enabled, tag + ": OSD shows the flight (battery group only when enabled)", osd.time.text if osd.has("time") else "no OSD")
		# Steering, Angle mode: W forward, D right (relative to heading).
		var fwd: Vector3 = -d.global_transform.basis.z
		fwd.y = 0.0
		fwd = fwd.normalized()
		var right: Vector3 = fwd.cross(Vector3.UP)
		var p0: Vector3 = d.global_position
		_key(KEY_W, true)
		await _wait(0.6)
		_key(KEY_W, false)
		await _wait(0.4)
		var moved_fwd: float = (d.global_position - p0).dot(fwd)
		_check(moved_fwd > 0.3, tag + ": W flies forward", "%.2f m" % moved_fwd)
		p0 = d.global_position
		_key(KEY_D, true)
		await _wait(0.6)
		_key(KEY_D, false)
		await _wait(0.4)
		var moved_right: float = (d.global_position - p0).dot(right)
		_check(moved_right > 0.3, tag + ": D moves right", "%.2f m" % moved_right)
		# Throttle back down, disarm.
		_key(KEY_CTRL, true)
		await _wait(1.6)
		_key(KEY_CTRL, false)
	await _tap(KEY_ENTER)

	# R resets to spawn.
	_key(KEY_R, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_R, false)
	await _wait(0.3)
	_check(d.global_position.distance_to(d._spawn_transform.origin) < 0.2, tag + ": R resets to spawn", "%s vs spawn %s" % [d.global_position, d._spawn_transform.origin])

	# Crash recovery: dropped upside down, it has to end up upright on
	# its own within a few seconds.
	var flipped := d._spawn_transform
	flipped.basis = Basis(Vector3.FORWARD, PI) * flipped.basis
	flipped.origin += Vector3.UP * 0.3
	d.global_transform = flipped
	d.linear_velocity = Vector3.ZERO
	d.angular_velocity = Vector3.ZERO
	await _wait(1.0)
	var was_down: bool = d.global_transform.basis.y.y < 0.0
	await _wait(3.0)
	# (was_down false = it tumbled back onto its skid by itself - also fine)
	_check(d.global_transform.basis.y.y > 0.95, tag + ": ends upright after being dropped on its back", "up.y=%.2f, was on its back after 1 s: %s" % [d.global_transform.basis.y.y, was_down])
	d.reset_to_spawn()
	await _wait(0.5)

	# Simulated radio, through the real joystick path - only possible if
	# the OS has a joypad at the configured device index.
	if not Input.get_connected_joypads().has(InputManager.joystick_device):
		print("SELFTEST SKIP %s: radio path (no joypad connected)" % tag)
		return
	await _wait(0.5)
	rest_y = d.global_position.y
	_joy_axis(InputManager.axis_throttle, -1.0) # stick down: radio now "active"
	for a in [InputManager.axis_roll, InputManager.axis_pitch, InputManager.axis_yaw]:
		_joy_axis(a, 0.0)
	await _wait(0.2)
	_check(InputManager.radio_status() == "active" and InputManager.get_throttle() < 0.02, tag + ": radio active, throttle low", "status=%s thr=%.2f" % [InputManager.radio_status(), InputManager.get_throttle()])
	await _tap(KEY_ENTER)
	_check(InputManager.armed, tag + ": arms with radio throttle down")
	_joy_axis(InputManager.axis_throttle, 0.3) # 65%
	await _wait(2.0)
	var radio_climb: float = d.global_position.y - rest_y
	_check(radio_climb > 1.0, tag + ": takes off (radio)", "climbed %.2f m" % radio_climb)
	_joy_axis(InputManager.axis_throttle, -1.0)
	await _tap(KEY_ENTER)
	await _wait(0.2)
	# Put the simulated sticks back to the silent radio's 0.0 so the next
	# map starts on the keyboard again, like a switched-off radio would.
	for a in range(8):
		_joy_axis(a, 0.0)
	await get_tree().process_frame
	InputManager._joy_active = false

## The camera looks and the video link (FpvVideo): clean next to the
## pilot, worse far away and behind the village houses, the digital
## camera's latency through the held camera, back to the drone's own
## camera on Clean.
func _test_video_link() -> void:
	Settings.selected_drone = "seeker3"
	get_tree().change_scene_to_file("res://scenes/maps/Village.tscn") # (the generated village; the old Main.tscn is gone)
	await _wait(2.0)
	var d: Drone = _drone()
	var v: FpvVideo = get_tree().current_scene.get_node("UI").video
	d.freeze = true
	Settings.camera_look = 1
	d.global_position = d._spawn_transform.origin + Vector3(0, 2, 0)
	await _wait(0.8)
	var near_bad: float = v.badness
	_check(near_bad < 0.05 and v.visible and v.link_quality > 95, "video: analog clean next to the pilot", "bad %.2f LQ %d" % [near_bad, v.link_quality])
	d.global_position = Vector3(10, 2, -60) # behind the village houses west of the church square (~20 dB of walls: analog breaks up, digital holds)
	await _wait(1.5)
	_check(v._obstruction_target > 10.0 and v.badness > 0.3, "video: walls between drone and pilot weaken the analog link", "obstruction %.1f dB, bad %.2f" % [v._obstruction_target, v.badness])
	_check(FpvVideo.bad_for(2, v.margin_db) < v.badness, "video: digital holds on longer than analog", "margin %.1f dB, analog %.2f, digital %.2f" % [v.margin_db, v.badness, FpvVideo.bad_for(2, v.margin_db)])
	Settings.camera_look = 2
	await _wait(0.3)
	var cam: Camera3D = d.get_node("CameraMount/Camera3D")
	var vp_cam: Camera3D = get_viewport().get_camera_3d()
	_check(vp_cam != cam and vp_cam != null and vp_cam.name == "FpvHoldCam", "video: digital camera shows the delayed picture", str(vp_cam))
	Settings.camera_look = 0
	await _wait(0.2)
	_check(get_viewport().get_camera_3d() == cam and v.link_quality == -1, "video: Clean is the drone camera, no link model")
	# The video pass presents the 3D view: the window's own 3D is off, the
	# view's camera follows the window's current camera.
	_check(v.presenting and get_tree().root.disable_3d and v._view_cam.global_position.distance_to(cam.get_global_transform_interpolated().origin) < 0.01, "video: the 3D view is drawn through the video pass, from the current camera")
	# The world extras (LooksFx): glare and grass outdoors, none of them
	# on Low; no dust anywhere (removed in 0.10.1).
	var sc: Node = get_tree().current_scene
	var ui_root: Node = sc.get_node("UI")._root
	_check(ui_root.get_node_or_null("SunGlare") != null and sc.get_node_or_null("GrassTufts") != null and sc.get_node_or_null("DustMotes") == null, "looks: village has sun glare and grass tufts, no dust")
	# Trees switch to their stand-ins one by one (shader), never a whole
	# chunk at once, and the stand-ins are never cut by a range.
	var tree_bad: Array = []
	for n in sc.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		var tm: ShaderMaterial = null
		if gi is MultiMeshInstance3D and (gi as MultiMeshInstance3D).multimesh and (gi as MultiMeshInstance3D).multimesh.mesh:
			tm = (gi as MultiMeshInstance3D).multimesh.mesh.surface_get_material(0) as ShaderMaterial
		elif gi is MeshInstance3D and (gi as MeshInstance3D).mesh and (gi as MeshInstance3D).mesh.get_surface_count() > 0:
			tm = (gi as MeshInstance3D).mesh.surface_get_material(0) as ShaderMaterial
		if tm == null or tm.shader == null or not tm.shader.resource_path.ends_with("tree.gdshader"):
			continue
		if gi is MultiMeshInstance3D and gi.visibility_range_end > 0.0 and not (gi.material_override is ShaderMaterial and (gi.material_override as ShaderMaterial).get_shader_parameter("near_only")):
			tree_bad.append(str(gi.get_path()))
		elif gi is MeshInstance3D and gi.visibility_range_begin > 0.0:
			tree_bad.append(str(gi.get_path()))
	_check(tree_bad.is_empty(), "looks: trees are cut per tree, never per chunk", str(tree_bad.slice(0, 3)))
	var q: int = Settings.graphics_quality
	Settings.graphics_quality = 0
	Settings.apply_graphics_settings()
	_check(sc.get_node_or_null("GrassTufts") == null and WorldShading.DETAIL[0].x == 0.0, "looks: Low has no grass tufts and no surface detail")
	Settings.graphics_quality = q
	Settings.apply_graphics_settings()
	d.freeze = false
	d.reset_to_spawn()
	get_tree().change_scene_to_file("res://scenes/Main3.tscn")
	await _wait(2.0)
	sc = get_tree().current_scene
	_check(sc.get_node_or_null("DustMotes") == null and sc.get_node("UI")._root.get_node_or_null("SunGlare") == null and sc.get_node_or_null("GrassTufts") == null, "looks: the school has no dust, glare or grass")

func _test_pause_menu(tag: String, d: Drone, map: String) -> void:
	var pm: PauseMenu = get_tree().current_scene.get_node("UI").pause_menu
	await _tap(KEY_ESCAPE)
	await _wait(0.1)
	_check(get_tree().paused and pm.visible, tag + ": Esc pauses and opens the pause menu")
	# Settings from the pause menu, and back to the pause menu.
	var settings_btn: Button = _find_button(pm, "Settings")
	settings_btn.pressed.emit()
	await _wait(0.1)
	_check(pm._settings.visible and not pm._card.visible, tag + ": pause -> Settings opens")
	await _tap(KEY_ESCAPE)
	await _wait(0.1)
	_check(pm.visible and pm._card.visible and not pm._settings.visible and get_tree().paused, tag + ": Esc in Settings returns to the pause menu (still paused)")
	# Drone switch (locked in the school).
	var before: String = Settings.selected_drone
	var mass_before: float = d.mass
	_find_button(pm, "pause_next_drone").pressed.emit()
	await _wait(0.1)
	if MapCatalog.forced_drone(map) != "":
		_check(Settings.selected_drone == before and d.mass == mass_before, tag + ": drone locked in the school")
	else:
		_check(Settings.selected_drone != before and d.mass != mass_before, tag + ": pause menu switches drone", "%s -> %s" % [before, Settings.selected_drone])
		_find_button(pm, "pause_prev_drone").pressed.emit() # back to the tested drone
		await _wait(0.1)
		_check(Settings.selected_drone == before and is_equal_approx(d.mass, mass_before), tag + ": and back")
	await _tap(KEY_ESCAPE)
	await _wait(0.1)
	_check(not get_tree().paused and not pm.visible, tag + ": Esc resumes")
	await _wait(0.8) # let a re-built drone settle before the flight checks

func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node.text.contains(text) or str(node.get_meta("find_text", "")).contains(text)):
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found:
			return found
	return null

## The calibration wizard and the arm switch, driven by a virtual radio
## (InputManager.test_joy) - axis 0 roll, 1 pitch (forward reads
## negative, so it must come out inverted), 2 throttle, 3 yaw, 5 an arm
## switch on its own channel. The real calibration file is backed up and
## restored around it.
func _test_calibration_and_arm_switch() -> void:
	var cfg_path: String = InputManager.CALIBRATION_PATH
	var backup: String = FileAccess.get_file_as_string(cfg_path) if FileAccess.file_exists(cfg_path) else ""
	var axes: Array = [0.02, -0.03, -1.0, 0.01, 0.0, -1.0, 0.0, 0.0]
	var buttons: Array = []
	buttons.resize(16)
	buttons.fill(false)
	InputManager.test_joy = {"axes": axes, "buttons": buttons}
	InputManager._joy_active = false

	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await _wait(0.8)
	var menu: Node = get_tree().current_scene
	_find_button(menu._screens["main"], "Settings").pressed.emit()
	await _wait(0.2)
	var ss: SettingsScreens = menu.get("_settings")
	_find_button(ss, "Calibrate Radio").pressed.emit()
	await _wait(0.2)
	_check(ss._calibration_screen.visible and ss._calibration_step == -1, "calibration: opens on the REST step")
	ss._cal_next.pressed.emit()
	await _wait(0.1)
	_check(ss._calibration_step == 0 and is_equal_approx(InputManager.axis_rest[1], -0.03), "calibration: rest captured")
	# Each stick: hold it out, the step must accept by itself, then let go.
	for st in [[0, 1.0], [1, -1.0], [3, 1.0], [2, 1.0]]:
		var before: int = ss._calibration_step
		axes[st[0]] = st[1]
		await _wait(1.2)
		_check(ss._calibration_step == before + 1, "calibration: holding axis %d accepts the step by itself" % st[0], "step %d -> %d" % [before, ss._calibration_step])
		axes[st[0]] = [0.02, -0.03, -1.0, 0.01][st[0]]
		await _wait(0.2)
	_check(InputManager.axis_roll == 0 and InputManager.axis_pitch == 1 and InputManager.axis_yaw == 3 and InputManager.axis_throttle == 2, "calibration: channels mapped", "r%d p%d y%d t%d" % [InputManager.axis_roll, InputManager.axis_pitch, InputManager.axis_yaw, InputManager.axis_throttle])
	_check(not InputManager.invert_roll and InputManager.invert_pitch and not InputManager.invert_yaw, "calibration: directions detected")
	_check(ss._calibration_step == ss.STEP_ARM, "calibration: arm step reached")
	axes[5] = 1.0
	await _wait(0.2)
	_check(not ss._arm_candidate.is_empty() and ss._calibration_step == ss.STEP_ARM, "calibration: arm switch detected, waits for flip back")
	axes[5] = -1.0
	await _wait(0.2)
	_check(ss._calibration_step == ss.STEP_TEST and InputManager.arm_source == "axis" and InputManager.arm_axis == 5, "calibration: arm switch assigned", InputManager.arm_control_name())
	ss._cal_next.pressed.emit()
	await _wait(0.1)
	_check(ss._settings_screen.visible, "calibration: Done returns to Settings")
	# Settings -> Assign Arm Switch alone: a button this time.
	_find_button(ss, "Assign Arm Switch").pressed.emit()
	await _wait(0.2)
	buttons[4] = true
	await _wait(0.2)
	buttons[4] = false
	await _wait(0.2)
	_check(InputManager.arm_source == "button" and InputManager.arm_button_index == 4 and InputManager.axis_roll == 0, "calibration: Assign Arm Switch alone (button 4), sticks untouched")
	await _test_unusual_radio(ss)
	ss._cal_next.pressed.emit()
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	# Back to the axis switch for the flight part.
	InputManager.arm_source = "axis"

	Settings.selected_drone = "seeker3"
	axes[5] = 1.0 # switch left ON while the map loads
	get_tree().change_scene_to_file("res://scenes/maps/Village.tscn")
	await _wait(2.0)
	var d: Drone = _drone()
	_check(not InputManager.armed and InputManager.arm_hint().contains("arm switch"), "arm switch: ON at load doesn't arm", InputManager.arm_hint())
	axes[5] = -1.0
	await _wait(0.1)
	axes[5] = 1.0
	await _wait(0.1)
	_check(InputManager.armed, "arm switch: flipping off/on arms")
	var y0: float = d.global_position.y
	axes[2] = 0.3
	await _wait(1.5)
	_check(d.global_position.y - y0 > 1.0, "arm switch: takes off on the virtual radio", "climbed %.2f" % (d.global_position.y - y0))
	axes[5] = -1.0
	await _wait(0.1)
	_check(not InputManager.armed, "arm switch: flipping off disarms")
	axes[5] = 1.0 # throttle still up
	await _wait(0.1)
	_check(not InputManager.armed and InputManager.arm_blocked, "arm switch: refuses to arm with throttle up")
	axes[2] = -1.0
	await _wait(0.1)
	_check(not InputManager.armed, "arm switch: lowering throttle alone doesn't arm (needs a cycle)")
	axes[5] = -1.0
	await _wait(0.1)
	axes[5] = 1.0
	await _wait(0.1)
	_check(InputManager.armed, "arm switch: cycle with throttle low arms")
	axes[5] = -1.0
	await _wait(1.5)
	# A radio that hasn't moved since the game started reads 0.000 on every
	# axis (the OS only reports changes) - for this centred throttle
	# channel that's 50%. The first flip of the arm switch must still arm,
	# without pushing the throttle up and down first (the user had to).
	for i in range(axes.size()):
		axes[i] = 0.0
	InputManager._joy_active = false
	InputManager._forget_axes()
	get_tree().change_scene_to_file("res://scenes/maps/Village.tscn")
	await _wait(2.0)
	axes[5] = 1.0
	await _wait(0.1)
	_check(InputManager.armed and InputManager.get_throttle() == 0.0, "silent radio: the first arm-switch flip arms, no throttle wiggle", "armed %s, throttle %.2f, %s" % [InputManager.armed, InputManager.get_throttle(), InputManager.arm_hint()])
	axes[5] = -1.0
	await _wait(0.2)

	InputManager.test_joy = null
	InputManager._joy_active = false
	if backup != "":
		var f := FileAccess.open(cfg_path, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(cfg_path))
	# Back to the shipped defaults, then the pilot's own file on top.
	InputManager.arm_source = "button"
	InputManager.arm_button_index = 0
	InputManager.throttle_calibrated = false
	InputManager.invert_pitch = false
	InputManager.axis_throttle = 2
	InputManager.axis_yaw = 3
	for i in range(8):
		InputManager.axis_rest[i] = 0.0
	InputManager.load_calibration()
	InputManager.new_flight()

## A radio laid out unlike EdgeTX's default: 10 axes with the sticks on
## 6-9 in a scrambled order, throttle reading +1 at the bottom, and the
## arm switch on button 40 - past the old 8-axis / 16-button scan.
## Restores the mapping the flight part of the caller relies on.
func _test_unusual_radio(ss: SettingsScreens) -> void:
	var keep := {}
	for f in ["axis_roll", "axis_pitch", "axis_yaw", "axis_throttle", "invert_roll", "invert_pitch", "invert_yaw", "throttle_raw_low", "throttle_raw_high", "arm_source", "arm_axis", "arm_button_index", "arm_button_on_when_pressed"]:
		keep[f] = InputManager.get(f)
	var keep_rest: Array[float] = InputManager.axis_rest.duplicate()
	var keep_joy = InputManager.test_joy
	var rest: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.01, -0.02, 1.0, 0.0]
	var axes: Array = rest.duplicate()
	var buttons: Array = []
	buttons.resize(64)
	buttons.fill(false)
	InputManager.test_joy = {"axes": axes, "buttons": buttons}
	ss._cal_next.pressed.emit() # leave the previous test view
	await _wait(0.1)
	ss._start_calibration(false)
	await _wait(0.1)
	ss._cal_next.pressed.emit() # REST captured
	await _wait(0.1)
	# roll right = axis 7 going negative, pitch forward = axis 6 +,
	# yaw right = axis 9 +, throttle up = axis 8 going to -1.
	for st in [[7, -1.0], [6, 1.0], [9, 1.0], [8, -1.0]]:
		axes[st[0]] = st[1]
		await _wait(1.1)
		axes[st[0]] = rest[st[0]]
		await _wait(0.2)
	buttons[40] = true
	await _wait(0.2)
	buttons[40] = false
	await _wait(0.2)
	_check(InputManager.axis_roll == 7 and InputManager.axis_pitch == 6 and InputManager.axis_yaw == 9 and InputManager.axis_throttle == 8, "radio layouts: sticks found on axes 6-9", "r%d p%d y%d t%d" % [InputManager.axis_roll, InputManager.axis_pitch, InputManager.axis_yaw, InputManager.axis_throttle])
	_check(InputManager.invert_roll and not InputManager.invert_pitch and not InputManager.invert_yaw, "radio layouts: reversed roll channel detected")
	_check(InputManager.arm_source == "button" and InputManager.arm_button_index == 40, "radio layouts: arm on button 40")
	InputManager._joy_active = true
	axes[8] = 1.0
	await get_tree().process_frame
	var low: float = InputManager.get_throttle()
	axes[8] = -1.0
	await get_tree().process_frame
	var high: float = InputManager.get_throttle()
	_check(low < 0.02 and high > 0.98, "radio layouts: reversed throttle reads 0..1", "%.2f..%.2f" % [low, high])
	for f in keep:
		InputManager.set(f, keep[f])
	InputManager.axis_rest = keep_rest
	InputManager.test_joy = keep_joy

## A full lap of the race field: the drone (frozen, moved in small steps
## like fast flight) passes every gate opening in order, then the start
## again - lap timing must see each gate and complete the lap. The real
## records file is backed up and restored around it.
func _test_race() -> void:
	var rec: String = RaceCourse.RECORDS_PATH
	var backup: String = FileAccess.get_file_as_string(rec) if FileAccess.file_exists(rec) else ""
	var gh: String = RaceCourse.GHOST_PATH
	var gh_backup: String = FileAccess.get_file_as_string(gh) if FileAccess.file_exists(gh) else ""
	var bd: String = RaceCourse.BOARD_PATH
	var bd_backup: String = FileAccess.get_file_as_string(bd) if FileAccess.file_exists(bd) else ""
	Settings.selected_drone = "five"
	Settings.game_mode = Settings.MODE_RACE
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await _wait(2.0)
	var d: Drone = _drone()
	var course: RaceCourse = get_tree().current_scene.course
	d.freeze = true
	var pts: Array[Vector3] = []
	for g in course._gates + [course._gates[0]]:
		pts.append(g.xf * Vector3(0, 0, 2.0))
		pts.append(g.xf * Vector3(0, 0, -2.0))
	var pos: Vector3 = d.global_position
	for p in pts:
		while pos.distance_to(p) > 0.01:
			pos = pos.move_toward(p, 2.5) # 2.5 m per 120 Hz frame = 1080 km/h
			d.global_position = pos
			await get_tree().physics_frame
	await get_tree().physics_frame
	_check(course._lap == 2 and course._last_lap > 0.0, "race: a full lap through all %d gates is timed" % course._gates.size(), "lap %d, last %.2f s" % [course._lap, course._last_lap])
	_check(course._ghost_pos.size() > 3 and course._ghost_rot.size() == course._ghost_pos.size(), "race: best lap recorded as a ghost", "%d samples" % course._ghost_pos.size())
	# The next lap: the ghost (the drone's own see-through model) flies it.
	var gp: Vector3 = course._gates[1].xf * Vector3(0, 0, 3.0)
	for _k in range(3):
		pos = pos.move_toward(gp, 2.5)
		d.global_position = pos
		await get_tree().physics_frame
	var parts: int = course._ghost.get_child_count()
	_check(course._ghost.visible and parts >= 3, "race: the ghost flies along on the next lap", "visible %s, %d parts" % [course._ghost.visible, parts])
	Settings.race_ghost = false
	await get_tree().physics_frame
	_check(not course._ghost.visible, "race: the ghost setting hides it")
	Settings.race_ghost = true
	var cfg := ConfigFile.new()
	cfg.load(RaceCourse.GHOST_PATH)
	_check(cfg.has_section_key(RaceCourse.section("race_field"), "five_q"), "race: the ghost is saved per track + drone")
	# Two more laps finish the 3-lap race: results, a top-5 entry.
	for _l in range(RaceCourse.LAPS - 1):
		for p in pts.slice(2):
			while pos.distance_to(p) > 0.01:
				pos = pos.move_toward(p, 2.5)
				d.global_position = pos
				await get_tree().physics_frame
	await get_tree().physics_frame
	var b5: Dictionary = RaceCourse.boards("race_field")
	_check(b5.has("five") and not b5.five.is_empty() and course._lap == 0, "race: %d laps finish the race and enter the top 5" % RaceCourse.LAPS, str(b5.get("five", [])))
	# Skipping a gate must not count: through START (a new race starts),
	# gate 1, then straight back to START.
	for p in [course._gates[0].xf * Vector3(0, 0, 2.0), course._gates[0].xf * Vector3(0, 0, -2.0)]:
		while pos.distance_to(p) > 0.01:
			pos = pos.move_toward(p, 2.5)
			d.global_position = pos
			await get_tree().physics_frame
	var lap_before: int = course._lap
	for p in [course._gates[1].xf * Vector3(0, 0, 2.0), course._gates[1].xf * Vector3(0, 0, -2.0), course._gates[0].xf * Vector3(0, 0, 2.0), course._gates[0].xf * Vector3(0, 0, -2.0)]:
		while pos.distance_to(p) > 0.01:
			pos = pos.move_toward(p, 2.5)
			d.global_position = pos
			await get_tree().physics_frame
	_check(course._lap == lap_before, "race: cutting the course doesn't complete a lap")
	_check(RaceCourse.records("race_field").has("five"), "race: the personal best is saved for the menu")
	d.freeze = false
	if backup != "":
		var f := FileAccess.open(rec, FileAccess.WRITE)
		f.store_string(backup)
		f.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(rec))
	if gh_backup != "":
		var g := FileAccess.open(gh, FileAccess.WRITE)
		g.store_string(gh_backup)
		g.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(gh))
	if bd_backup != "":
		var bf := FileAccess.open(bd, FileAccess.WRITE)
		bf.store_string(bd_backup)
		bf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(bd))
	# Freestyle: the same map, no timing at all.
	Settings.game_mode = Settings.MODE_FREESTYLE
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await _wait(2.0)
	var fc: RaceCourse = get_tree().current_scene.course
	_check(not fc.is_physics_processing() and fc._marker == null, "freestyle: race maps fly without the timer")
	# Past the reset line: back to spawn at once, no map reload.
	Settings.game_mode = Settings.MODE_FREESTYLE
	var map_before: Node = get_tree().current_scene
	var rd: Drone = _drone()
	rd.global_position = Vector3(500, 5, 0)
	await get_tree().physics_frame
	await _wait(0.3)
	_check(get_tree().current_scene == map_before and _drone().global_position.distance_to(_drone()._spawn_transform.origin) < 1.0, "border: out of range resets the drone instantly (no reload)")
	# Replay: P plays the recording back, P again returns control exactly
	# where the drone was.
	var rd2: Drone = _drone()
	rd2.freeze = false
	await _wait(1.0)
	var rep: Replay = get_tree().current_scene.get_node("UI").replay
	var before: Transform3D = rd2.global_transform
	rep.start()
	await _wait(0.5)
	var cam_ok: bool = get_viewport().get_camera_3d() == rep._cam and rep.length() > 0.5
	rep.stop()
	await get_tree().physics_frame
	_check(cam_ok and rd2.global_position.distance_to(before.origin) < 0.5 and not rd2.freeze, "replay: plays the recording and hands back control where it left off", "length %.1f s" % rep.length())
	# Prop wash can be switched off: a fast descent under throttle then
	# costs no lift.
	var pw: Drone = _drone()
	Settings.prop_wash = false
	pw.linear_velocity = -pw.global_transform.basis.y * 8.0
	pw._last_total_thrust = 4.0 * pw.max_motor_thrust_n * 0.6
	var f_off: float = pw._prop_wash(1.0 / 120.0, pw.global_transform.basis.y)
	Settings.prop_wash = true
	var f_on: float = pw._prop_wash(1.0 / 120.0, pw.global_transform.basis.y)
	pw.linear_velocity = Vector3.ZERO
	_check(f_off == 1.0 and f_on < 0.95, "prop wash: on costs lift in a fast descent, off doesn't", "on %.2f off %.2f" % [f_on, f_off])
	# Restart switch (virtual radio): flipping it reloads the map.
	var keep_joy = InputManager.test_joy
	var keep_src: String = InputManager.restart_source
	var axes: Array = []
	for _i in range(8):
		axes.append(0.0)
	axes[6] = -1.0
	InputManager.test_joy = {"axes": axes, "buttons": [false, false, false, false]}
	InputManager.restart_source = "axis"
	InputManager.restart_axis = 6
	InputManager.restart_axis_off_value = -1.0
	InputManager.restart_axis_on_value = 1.0
	await _wait(0.2)
	var scene_before: Node = get_tree().current_scene
	InputManager.test_joy.axes[6] = 1.0
	await _wait(0.3)
	var reloading: bool = SceneLoader.is_loading() or get_tree().current_scene != scene_before
	InputManager.test_joy.axes[6] = -1.0
	await _wait(3.0)
	InputManager.restart_source = keep_src
	InputManager.test_joy = keep_joy
	InputManager._joy_active = false
	_check(reloading, "radio: the restart switch reloads the map")

## A reset switch on the radio (virtual radio, the user's Pocket layout:
## arm on axis 4, throttle on axis 2, reset on axis 7) must reset the
## drone and let it take off again - the user found it stuck on the
## ground after a switch reset, while R worked (2026-10-06).
func _test_reset_switch() -> void:
	var keep := {}
	for f in ["arm_source", "arm_axis", "arm_axis_on_value", "arm_axis_off_value", "arm_is_switch", "axis_throttle",
			"throttle_calibrated", "throttle_raw_low", "throttle_raw_high", "invert_throttle", "reset_source",
			"reset_axis", "reset_axis_on_value", "reset_axis_off_value", "axis_roll", "axis_pitch", "axis_yaw"]:
		keep[f] = InputManager.get(f)
	var keep_joy = InputManager.test_joy
	var axes: Array = [0.0, 0.0, -1.0, 0.0, -1.0, 0.0, 0.0, 1.0]
	InputManager.test_joy = {"axes": axes, "buttons": [false, false, false, false]}
	InputManager.axis_roll = 0
	InputManager.axis_pitch = 1
	InputManager.axis_throttle = 2
	InputManager.axis_yaw = 3
	InputManager.invert_throttle = false
	InputManager.throttle_calibrated = true
	InputManager.throttle_raw_low = -1.0
	InputManager.throttle_raw_high = 1.0
	InputManager.arm_source = "axis"
	InputManager.arm_axis = 4
	InputManager.arm_axis_on_value = 1.0
	InputManager.arm_axis_off_value = -1.0
	InputManager.arm_is_switch = true
	InputManager.reset_source = "axis"
	InputManager.reset_axis = 7
	InputManager.reset_axis_on_value = -1.0
	InputManager.reset_axis_off_value = 1.0
	InputManager._forget_axes()
	InputManager._joy_active = false
	Settings.game_mode = Settings.MODE_FREESTYLE
	InputManager.self_level = true
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await _wait(2.0)
	var d: Drone = _drone()
	var y0: float = d.global_position.y
	axes[4] = 1.0 # arm
	await _wait(0.3)
	axes[2] = 0.3 # 65 % throttle
	await _wait(1.0)
	var climbed1: float = d.global_position.y - y0
	# A two-position switch stays ON after the reset - the drone must
	# still fly (it used to be reset every frame while the switch was on).
	axes[7] = -1.0
	axes[2] = -1.0
	await _wait(0.5)
	var back: bool = d.global_position.distance_to(d._spawn_transform.origin) < 1.0
	var y1: float = d.global_position.y
	axes[2] = 0.3
	await _wait(1.2)
	var climbed2: float = d.global_position.y - y1
	_check(climbed1 > 1.0 and back and climbed2 > 1.0, "radio: the reset switch resets the drone once and it takes off again, switch still on",
		"first climb %.2f m, back at spawn %s, armed %s, climb after reset %.2f m" % [climbed1, back, InputManager.armed, climbed2])
	# A reset close to the spawn still voids a race run (the run used to
	# reset only when the drone jumped more than 8 m in one frame).
	Settings.game_mode = Settings.MODE_RACE
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await _wait(2.0)
	d = _drone()
	var course: RaceCourse = get_tree().current_scene.course
	d.global_position = d._spawn_transform.origin + Vector3(3, 1, 0)
	await get_tree().physics_frame
	course._next = 2
	course._lap = 1
	course._lap_start = course._time
	d.reset_to_spawn()
	await get_tree().physics_frame
	_check(course._next == 0 and course._lap_start < 0.0, "race: a reset near the start voids the run (gates back to the start)", "next gate %d" % course._next)
	Settings.game_mode = Settings.MODE_FREESTYLE
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await _wait(2.0)
	d = _drone()
	axes[2] = -1.0
	axes[4] = -1.0
	await _wait(0.2)
	axes[4] = 1.0
	await _wait(0.3)
	# Flipping it off and on again resets again.
	axes[2] = -1.0
	axes[7] = 1.0
	await _wait(0.2)
	axes[7] = -1.0
	await _wait(0.1)
	_check(d.global_position.distance_to(d._spawn_transform.origin) < 1.0, "radio: flipping the reset switch again resets again")
	axes[7] = 1.0
	axes[2] = -1.0
	axes[4] = -1.0
	await _wait(0.2)
	for f in keep:
		InputManager.set(f, keep[f])
	InputManager.test_joy = keep_joy
	InputManager._joy_active = false
	InputManager.armed = false

## The optional realism settings (battery sag, prop damage, wind) through
## the real input path: keyboard arm and throttle, R to reset.
func _test_realism() -> void:
	InputManager.armed = false
	InputManager.self_level = true
	Settings.selected_drone = "seeker3"
	Settings.game_mode = Settings.MODE_FREESTYLE
	Settings.battery_enabled = true
	Settings.prop_damage = true
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await _wait(2.0)
	var d: Drone = _drone()
	var osd: Dictionary = get_tree().current_scene.get_node("UI")._osd_labels
	var b: Battery = d.battery
	_check(b.cells == 4 and is_equal_approx(b.capacity_mah, 850.0) and b.cell_v > 4.15, "realism: Static Three carries a full 4S 850 mAh pack", "%dS %d mAh %.2f V/cell" % [b.cells, int(b.capacity_mah), b.cell_v])
	await _tap(KEY_ENTER)
	_key(KEY_SHIFT, true)
	await _wait(0.9)
	_key(KEY_SHIFT, false)
	await _wait(0.5)
	_check(osd.bat.visible and osd.bat.text.ends_with("V/cell") and b.current_a > 1.0 and absf(b.thrust_factor() - 1.0) < 0.03, "realism: battery OSD on, fresh pack = full thrust", "%s  %.1f A  k=%.3f" % [osd.bat.text, b.current_a, b.thrust_factor()])
	# Fast-forward the pack to 5% left: low voltage, less thrust, warning.
	b.used_mah = b.capacity_mah * 0.95
	await _wait(4.5)
	_check(b.thrust_factor() < 0.85 and osd.warn.text in ["LOW BATTERY", "LAND NOW"], "realism: a drained pack warns and loses thrust", "%.2f V/cell (filtered %.2f), k=%.2f, '%s', armed %s, y %.1f" % [b.cell_v, b.warn_v, b.thrust_factor(), osd.warn.text, InputManager.armed, d.global_position.y - d._spawn_transform.origin.y])
	b.used_mah = b.capacity_mah * 1.02
	await _wait(1.5)
	_check(osd.warn.text.begins_with("BATTERY EMPTY") and b.thrust_factor() < 0.4, "realism: an empty pack can't hold the quad up", "k=%.2f '%s'" % [b.thrust_factor(), osd.warn.text])
	# A crash: straight into the ground at ~12 m/s, motors running.
	_key(KEY_R, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_R, false)
	await _wait(0.2)
	_check(b.charge() > 0.99 and osd.warn.text == "", "realism: R fits a fresh pack", "%.3f '%s'" % [b.charge(), osd.warn.text])
	if not InputManager.armed:
		await _tap(KEY_ENTER)
	# (From low down: from higher up the 7:1 thrust brakes it first.)
	d.global_position = d._spawn_transform.origin + Vector3.UP * 1.2
	d.linear_velocity = Vector3(0, -12.0, 0)
	await _wait(0.5)
	var worst: float = d.prop_health.min()
	_check(worst < 0.95 and worst >= Drone.PROP_HEALTH_MIN, "realism: a hard crash damages props", "%s armed %s y %.2f v %s" % [d.prop_health, InputManager.armed, d.global_position.y - d._spawn_transform.origin.y, d.linear_velocity])
	_check(osd.warn.text == "PROP DAMAGED", "realism: OSD says PROP DAMAGED", osd.warn.text)
	_key(KEY_R, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_R, false)
	await _wait(0.2)
	_check(d.prop_health.min() == 1.0, "realism: R fits new props")
	Settings.prop_damage = false
	d.global_position = d._spawn_transform.origin + Vector3.UP * 1.2
	d.linear_velocity = Vector3(0, -12.0, 0)
	await _wait(0.5)
	_check(d.prop_health.min() == 1.0, "realism: no prop damage with the setting off")
	# Wind: blows outdoors (more up high), drifts the quad, off = still.
	Settings.wind_level = 3
	d.reset_to_spawn()
	await _wait(0.5)
	var low: float = d.wind_velocity.length()
	d.global_position = d._spawn_transform.origin + Vector3.UP * 30.0
	d.linear_velocity = Vector3.ZERO
	await _wait(0.5)
	var high: float = d.wind_velocity.length()
	_check(high > 6.0 and high > low, "realism: strong wind blows, stronger up high", "%.1f m/s near the ground, %.1f m/s at 30 m" % [low, high])
	Settings.wind_level = 0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(d.wind_velocity == Vector3.ZERO, "realism: wind off = still air")
	# Throttle back down before disarming (the next test arms again).
	_key(KEY_CTRL, true)
	await _wait(1.6)
	_key(KEY_CTRL, false)
	await _tap(KEY_ENTER)
	Settings.battery_enabled = false
	d.reset_to_spawn()
	await _wait(0.3)

## The map load cache (SH_SELFTEST_ONLY=cache - slow, every generated map
## built twice): a fresh build (which writes the cache) and the cached
## load must give the same map (MapCache.fingerprint), the same preview
## views, race gates, and a drone that rests at spawn. SH_CACHE_MAPS=a,b
## limits it to those map ids.
func _test_map_cache() -> void:
	MapCache.force = true
	var only: PackedStringArray = OS.get_environment("SH_CACHE_MAPS").split(",", false) if OS.has_environment("SH_CACHE_MAPS") else PackedStringArray()
	for m in MapCatalog.available():
		var ps := load(m.scene) as PackedScene
		if ps == null or not (only.is_empty() or only.has(m.id)):
			continue
		var probe: Node = ps.instantiate()
		var built: bool = probe is BuiltMap
		probe.free()
		if not built:
			continue
		var d := DirAccess.open(MapCache.DIR)
		if d:
			for f in d.get_files():
				if f.begins_with(m.scene.get_file().get_basename() + "-"):
					d.remove(f)
		var res: Array = []
		for pass_i in range(2):
			InputManager.armed = false
			Settings.selected_drone = "seeker3"
			get_tree().change_scene_to_file(m.scene)
			await _wait(2.5)
			var sc: BuiltMap = get_tree().current_scene as BuiltMap
			var dr: Drone = _drone()
			var y0: float = dr.global_position.y
			await _wait(1.0)
			var course: Variant = sc.get("course")
			res.append({"cache": sc.from_cache, "fp": MapCache.fingerprint(sc), "views": sc.views().size(),
				"gates": (course as RaceCourse)._gates.size() if course is RaceCourse else -1,
				"rest": absf(dr.global_position.y - y0) < 0.05 and dr.linear_velocity.length() < 0.1})
		var a: Dictionary = res[0]
		var b: Dictionary = res[1]
		_check(not a.cache and b.cache, "cache %s: second load comes from the cache" % m.id)
		_check(a.fp == b.fp, "cache %s: cached map identical to the fresh build" % m.id, b.fp if a.fp == b.fp else "%s vs %s" % [a.fp, b.fp])
		_check(a.views == b.views and a.gates == b.gates and b.rest, "cache %s: views, gates, drone at rest" % m.id, "views %d/%d gates %d/%d rest %s" % [a.views, b.views, a.gates, b.gates, b.rest])
	MapCache.force = false
