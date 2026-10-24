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

## The pilot's real race saves must never change in a test run: the
## race tests write to user://selftest/ (RaceCourse.save_path), and this
## guard compares the real files' checksums before and after.
const REAL_RACE_SAVES: Array[String] = ["user://race_records.cfg", "user://race_ghosts.cfg", "user://race_board.cfg", "user://race_stats.cfg"]
var _real_saves: Dictionary = {}

func _race_saves_sums() -> Dictionary:
	var out := {}
	for base: String in REAL_RACE_SAVES:
		for p: String in [base, base + ".bak"]:
			out[p] = FileAccess.get_md5(p) if FileAccess.file_exists(p) else ""
	return out

func _check_race_saves() -> void:
	var now: Dictionary = _race_saves_sums()
	var changed: Array = _real_saves.keys().filter(func(k: String) -> bool: return now[k] != _real_saves[k])
	_check(changed.is_empty() and RaceCourse.RECORDS_PATH.begins_with("user://selftest/"), "saves: the pilot's real race files are untouched (tests use user://selftest/)", str(changed))

func _run() -> void:
	_real_saves = _race_saves_sums()
	for f in DirAccess.get_files_at("user://selftest"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://selftest/" + f))
	# A fresh install starts with the realism extras off: no wind, no
	# battery sag, no prop damage (the defaults in settings.gd).
	var fresh: Node = (load("res://scripts/settings.gd") as GDScript).new()
	_check(fresh.wind_level == 0 and not fresh.battery_enabled and not fresh.prop_damage, "settings: wind, battery sag and prop damage are off by default",
		"wind %d battery %s prop damage %s" % [fresh.wind_level, fresh.battery_enabled, fresh.prop_damage])
	_check(fresh.water_damage, "settings: water damage is on by default")
	_check(fresh.race_line_hue == 30, "settings: the racing line is on, orange, by default", str(fresh.race_line_hue))
	_check(fresh.race_line_length == 1, "settings: the racing line is Medium length by default", str(fresh.race_line_length))
	_check(not fresh.race_strict, "settings: the competition rule (missed gate voids the lap) is off by default")
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
	# Rate profiles: each keeps its own rates and throttle MID; a 3-position
	# radio switch picks them (virtual radio, nothing saved).
	var keep: Array = [Settings.rates_roll.duplicate(), Settings.throttle_mid, Settings.rate_profile, Settings.rate_profiles.duplicate(true)]
	Settings.rate_profiles = []
	Settings.rate_profile = 0
	Settings.rates_roll = [70.0, 500.0, 0.5]
	Settings.throttle_mid = 0.5
	Settings.select_rate_profile(1)
	Settings.rates_roll = [70.0, 900.0, 0.6]
	Settings.throttle_mid = 0.4
	Settings.select_rate_profile(0)
	var p1: bool = Settings.rates_roll[1] == 500.0 and is_equal_approx(Settings.throttle_mid, 0.5)
	Settings.select_rate_profile(1)
	var p2: bool = Settings.rates_roll[1] == 900.0 and is_equal_approx(Settings.throttle_mid, 0.4)
	_check(p1 and p2, "rates: profiles keep their own rates and throttle MID", "%s %s" % [p1, p2])
	var saved_joy = InputManager.test_joy
	var sw_axes: Array = [0.0, 0.0, -1.0, 0.0, 0.0, 0.0, -1.0, 0.0]
	InputManager.test_joy = {"axes": sw_axes, "buttons": []}
	InputManager._axis_seen[6] = 1
	InputManager.rates_source = "axis"
	InputManager.rates_axis = 6
	InputManager.rates_axis_off_value = -1.0
	InputManager.rates_axis_on_value = 1.0
	var picks: Array = []
	for v in [-1.0, 0.0, 1.0]:
		sw_axes[6] = v
		picks.append(InputManager.rate_switch_profile())
	_check(picks == [0, 1, 2], "rates: a 3-position switch picks profile 1/2/3", str(picks))
	InputManager.rates_source = ""
	InputManager.rates_axis = -1
	InputManager.test_joy = saved_joy
	InputManager._axis_seen[6] = 0
	Settings.rate_profiles = keep[3]
	Settings.rate_profile = keep[2]
	Settings.rates_roll = keep[0]
	Settings.throttle_mid = keep[1]
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
		if only.has("tracks"):
			await _test_tracks()
		if only.has("autopilot"):
			await _test_autopilot()
		if only.has("video"):
			await _test_video_link()
		if only.has("gnomes"):
			await _test_collectibles()
		if only.has("village"):
			await _test_village_course()
		if only.has("keyboard"):
			await _test_keyboard()
		if only.has("update"):
			_test_updater()
			_test_update_pack()
			_test_save_keeps_unknown_keys()
		if only.has("cache"):
			await _test_map_cache()
		if only.has("text"):
			await _test_text_all()
		if only.has("zfight"):
			await _test_zfight_all()
		if only.has("maps"): # the per-map checks for the maps in SH_TEXT_MAPS (default: Construction Site)
			var mnames: PackedStringArray = OS.get_environment("SH_TEXT_MAPS").split(",") if OS.has_environment("SH_TEXT_MAPS") else PackedStringArray(["ConstructionSite"])
			for mn in mnames:
				await _test_map("res://scenes/maps/%s.tscn" % mn, "five", false)
		if only.has("flow"):
			await _test_flow_all()
		if only.has("water"):
			await _test_water()
		_check_race_saves()
		print("SELFTEST DONE: %d checks, %d failed" % [_checks, _failures])
		get_tree().quit(1 if _failures > 0 else 0)
		return
	await _test_menu_flow()
	_test_updater()
	_test_update_pack()
	_test_save_keeps_unknown_keys()
	await _test_village_course()
	await _test_keyboard()
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
		if not ResourceLoader.exists(c[0]):
			continue # dev maps (Test Valley) are left out of release exports
		await _test_map(c[0], c[1], false)
	await _test_race()
	await _test_autopilot()
	await _test_tracks()
	await _test_realism()
	await _test_video_link()
	await _test_water()
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
	_check_race_saves()
	print("SELFTEST DONE: %d checks, %d failed" % [_checks, _failures])
	get_tree().quit(1 if _failures > 0 else 0)

## The creators with many seeds, level and on steep hills (CreatorCheck):
## nothing they build may float, every kind gets built.
func _test_creators() -> void:
	var r: Dictionary = CreatorCheck.run()
	_check(r.floating.is_empty(), "creators: nothing floats (town houses, industry, farm, fields; level and hills)", "%d floating: %s" % [r.floating.size(), str(r.floating.slice(0, 3))])
	_check(r.houses >= 50 and r.halls == 6 and r.crops == 2 * FieldCreator.CROPS.size(), "creators: every kind built", "%d houses, %d halls, %d fields in %d ms" % [r.houses, r.halls, r.crops, r.ms])

## The racing line's length rule (RaceCourse._update_line) checked
## from the outside: "" when it holds, else what broke.
func _line_rule(course: RaceCourse, lm: ShaderMaterial) -> String:
	var n: int = course._gates.size()
	var lap: float = lm.get_shader_parameter("lap")
	var cut: float = lm.get_shader_parameter("cut")
	var span: float = lm.get_shader_parameter("span")
	var to_gate := func(g: int) -> float:
		return fposmod(course._line_arc[course._line_seg[g]] - cut, lap)
	var shown: int = (course._line_last - course._next + n) % n + 1
	if not is_equal_approx(span, to_gate.call(course._line_last)):
		return " [span %.1f != gate %d at %.1f]" % [span, course._line_last, to_gate.call(course._line_last)]
	if shown > mini(RaceCourse.LINE_GATES, n):
		return " [%d gates]" % shown
	if shown < mini(RaceCourse.LINE_GATES, n) and span < Settings.race_line_target():
		return " [stopped short: %.1f m, %d gates]" % [span, shown]
	if shown > 1 and to_gate.call((course._line_last - 1 + n) % n) >= Settings.race_line_target():
		return " [one gate too many]"
	return ""

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
	# First-run card: never shown in tests; Continue sets the flag; the
	# first-start ping sends nothing in tests and its body is {v, os}.
	_check(menu._screens.has("firstrun") and not menu._screens["firstrun"].visible and menu._screens["main"].visible, "menu: first-run card built, skipped in tests")
	var frd: bool = Settings.first_run_done
	Settings.first_run_done = false
	menu._show("firstrun")
	var keep := [Settings.count_first_start, Settings.first_start_pinged]
	Settings.first_start_pinged = false
	Settings.count_first_start = true
	var before_click: bool = FirstStartPing.allowed_by_player()
	menu._finish_first_run(false)
	var after_no: bool = FirstStartPing.allowed_by_player() or Settings.count_first_start
	_check(Settings.first_run_done and menu._screens["main"].visible, "menu: first-run answer sets the flag and opens the menu")
	Settings.first_run_done = false
	menu._show("firstrun")
	menu._finish_first_run(true)
	var after_yes: bool = FirstStartPing.allowed_by_player()
	_check(not before_click and not after_no and after_yes, "first-start ping: nothing before a click, No = never, Yes = counted once", "%s %s %s" % [before_click, after_no, after_yes])
	Settings.count_first_start = keep[0]
	Settings.first_start_pinged = keep[1]
	Settings.first_run_done = frd
	var pj: Variant = JSON.parse_string(FirstStartPing.payload())
	_check(pj is Dictionary and pj.has("v") and pj.has("os") and pj.size() == 2 and not FirstStartPing.wanted(), "first-start ping: body {v, os} only, never sent in tests", FirstStartPing.payload())
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
	# Settings by topic (2026-10-12): six tabs, radio first; each setting in
	# its topic's tab (nothing lost in the move).
	var stabs: TabContainer = settings.settings_tabs
	var tab_ok: bool = stabs != null and stabs.get_tab_count() == 6
	var where: Dictionary = {"Radio": ["Calibrate Radio", "Assign Arm Switch", "Assign Mode Switch"], "Rates": ["Betaflight"], "Flying": ["Battery simulation", "Wind (outdoor maps)", "Performance mode (240 Hz physics)"],
		"Race": ["Competition rule", "Ghost of your best lap"], "Camera & screen": ["Camera angle", "Crosshair"], "Graphics": ["Graphics quality", "VSync"]}
	var missing: Array = []
	if tab_ok:
		for tname: String in where:
			var page: Node = stabs.get_child(SettingsScreens.TAB_NAMES.find(tname))
			for txt: String in where[tname]:
				if _find_button(page, txt) == null and _find_text(page, txt) == null:
					missing.append("%s/%s" % [tname, txt])
	_check(tab_ok and missing.is_empty() and stabs.get_tab_title(0) == "Radio", "settings: six tabs radio first, every setting in its topic", str(missing))
	# Every tab the same width, and the window one size whichever tab is
	# open (each page scrolls instead of pushing it).
	var sizes: Array = []
	var empty_tabs: Array = []
	if tab_ok:
		for i in range(stabs.get_tab_count()):
			stabs.current_tab = i
			await get_tree().process_frame
			await get_tree().process_frame
			sizes.append(stabs.size)
			var lit: int = settings._tab_buttons.filter(func(b: Button) -> bool: return b.button_pressed).size()
			if lit != 1 or not settings._tab_buttons[i].button_pressed:
				empty_tabs.append("lit:" + SettingsScreens.TAB_NAMES[i])
			var pg: Control = stabs.get_child(i) as Control
			if pg == null or not pg.is_visible_in_tree() or pg.size.y < 300.0 or (pg.get_child(0) as Control).size.y < 200.0:
				empty_tabs.append(SettingsScreens.TAB_NAMES[i])
		stabs.current_tab = 0
	_check(tab_ok and empty_tabs.is_empty(), "settings: every tab shows its settings (a page with real height)", str(empty_tabs))
	var widths: Array = settings._tab_buttons.map(func(b: Button) -> int: return roundi(b.size.x))
	_check(not sizes.is_empty() and sizes.all(func(v: Vector2) -> bool: return v == sizes[0]) and widths.all(func(w: int) -> bool: return absi(w - widths[0]) <= 1),
		"settings: tabs all one width, the window one size on every tab", "%s %s" % [str(widths), str(sizes)])
	# Every switch and slider on every tab does something: flipping it (a
	# slider to its other end) changes a setting, and flipping it back
	# restores it. (Fullscreen / Low-res window are left alone: they
	# resize the test window or ask for a restart.)
	var dead: Array = []
	var n_ctl: int = 0
	if tab_ok:
		for i in range(stabs.get_tab_count()):
			stabs.current_tab = i
			await get_tree().process_frame
			for ctl in stabs.get_child(i).find_children("*", "", true, false):
				if not (ctl is CheckButton or ctl is HSlider) or not (ctl as Control).is_visible_in_tree():
					continue
				var label: String = (ctl as CheckButton).text if ctl is CheckButton else str(ctl.get_parent().get_child(0).get("text")) if ctl.get_parent().get_child_count() > 0 else ctl.name
				if ctl is HSlider and ctl.get_parent() and ctl.get_parent().get_parent():
					var lbls: Array = ctl.get_parent().get_parent().find_children("*", "Label", true, false)
					if not lbls.is_empty():
						label = (lbls[0] as Label).text
				# Window modes restart the window; "Pitch follows roll" only links two sliders
				if label.contains("Fullscreen") or label.contains("Low-res") or ctl.has_meta("rates_link"):
					continue
				n_ctl += 1
				var snap0: String = _settings_snapshot()
				var v0: float = (ctl as HSlider).value if ctl is HSlider else 0.0
				if ctl is CheckButton:
					(ctl as CheckButton).button_pressed = not (ctl as CheckButton).button_pressed
				else:
					var sl := ctl as HSlider
					sl.value = sl.min_value if v0 > (sl.min_value + sl.max_value) * 0.5 else sl.max_value
				await get_tree().process_frame
				var changed: bool = _settings_snapshot() != snap0
				if ctl is CheckButton:
					(ctl as CheckButton).button_pressed = not (ctl as CheckButton).button_pressed
				else:
					(ctl as HSlider).value = v0
				await get_tree().process_frame
				if _settings_snapshot() != snap0:
					dead.append("%s/%s (not restored)" % [SettingsScreens.TAB_NAMES[i], label])
				if not changed:
					dead.append("%s/%s" % [SettingsScreens.TAB_NAMES[i], label])
		stabs.current_tab = 0
	_check(n_ctl >= 10 and dead.is_empty(), "settings: every switch and slider changes a setting", "%d controls, dead: %s" % [n_ctl, str(dead)])
	# Racing line: one slider, far left Off, then hues; orange by default.
	var line_sl := settings.find_child("RaceLineSlider", true, false) as HSlider
	var hue0: int = Settings.race_line_hue
	var line_ok: bool = line_sl != null and line_sl.value == hue0 / SettingsScreens.LINE_HUE_STEP + 1
	if line_sl:
		line_sl.value = 0
		line_ok = line_ok and not Settings.race_line_on()
		line_sl.value = 41
		line_ok = line_ok and Settings.race_line_hue == 200 and Settings.race_line_on()
		line_sl.value = hue0 / SettingsScreens.LINE_HUE_STEP + 1
	_check(line_ok and Settings.race_line_hue == hue0,
		"menu: racing line slider (Off, then the colour wheel)", "hue %d" % Settings.race_line_hue)
	var len0: int = Settings.race_line_length
	var long_btn: Button = _find_button(settings, "Long")
	var short_btn: Button = _find_button(settings, "Short")
	var len_ok: bool = long_btn != null and short_btn != null
	if len_ok:
		long_btn.pressed.emit()
		len_ok = Settings.race_line_length == 2
		short_btn.pressed.emit()
		len_ok = len_ok and Settings.race_line_length == 0
		Settings.race_line_length = len0
	_check(len_ok, "menu: racing line length Short / Medium / Long", str(Settings.race_line_length))
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	_check(not settings.visible and menu._screens["main"].visible, "menu: Esc in Settings goes back to the home screen")
	var play: Button = _find_button(menu, "Play")
	if play:
		play.pressed.emit()
	await _wait(0.2)
	_check(menu._screens["mode"].visible, "menu: Play asks for the mode first")
	# The menu's look (2026-10-12): the original logo image on the home
	# screen; a step bar over Mode with Drone clickable back, Mode current.
	var logo: TextureRect = menu._screens["main"].find_child("Logo", true, false) as TextureRect
	_check(logo != null and logo.texture != null, "menu: the home screen shows the original logo image")
	var sb: Node = menu._screens["main"].find_child("SpecBars", true, false)
	var sp_ok: bool = sb != null
	if sb:
		for n in ["Speed", "Punch", "Weight"]:
			var v: float = (sb.get_node(n) as ProgressBar).value
			sp_ok = sp_ok and v > 0.05 and v <= 1.0
	var whoop: Dictionary = menu.spec_values("whoop")
	var race: Dictionary = menu.spec_values("race")
	_check(sp_ok and race.speed > whoop.speed and race.weight > whoop.weight, "menu: the drone card's spec bars show the real numbers on one scale",
		"whoop %s race %s" % [whoop, race])
	# No step bar (the user, 2026-10-12): Back leads back step by step.
	_check(menu.find_child("StepBar", true, false) == null, "menu: no step bar on any screen")
	var mode_back: Button = _find_button(menu._screens["mode"], "Back")
	if mode_back:
		mode_back.pressed.emit()
		await _wait(0.2)
		_check(menu._screens["main"].visible, "menu: Back on the mode screen goes home")
		_find_button(menu, "Play").pressed.emit()
		await _wait(0.2)
	_find_button(menu._screens["mode"], "Race").pressed.emit()
	await _wait(0.2)
	var race_cards: int = 0
	for c in menu._map_grid.get_children():
		if c.visible:
			race_cards += 1
	_check(race_cards == 3, "menu: Race mode lists the race tracks only", "%d cards" % race_cards)
	# A race map opens its track list: six tracks, Esc back to the maps.
	_find_button(menu._screens["map"], "Race Field").pressed.emit()
	await _wait(0.2)
	var n_tracks: int = menu._tracks_grid.get_child_count()
	_check(menu._screens["tracks"].visible and n_tracks == 6, "menu: a race map opens its 6 tracks", "%d cards" % n_tracks)
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	_check(menu._screens["map"].visible, "menu: Esc in the track list goes back to the maps")
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
	# The window mode and "Low-res window" reach the engine through this
	# override file (read before the window opens).
	_check(ProjectSettings.get_setting("application/config/project_settings_override", "") == Settings.DISPLAY_OVERRIDE, "settings: the display file is the project's settings override")
	var lrw: bool = Settings.low_res_window
	var tmp: String = "user://selftest_display_override.cfg"
	var got: Array = []
	for on in [false, true]:
		Settings.low_res_window = on
		Settings.write_display_override(tmp)
		var oc := ConfigFile.new()
		oc.load(tmp)
		got.append([oc.get_value("display", "window/size/mode", -1), oc.get_value("display", "window/dpi/allow_hidpi", true)])
	Settings.low_res_window = lrw
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp))
	var want_mode: int = DisplayServer.WINDOW_MODE_FULLSCREEN if Settings.is_fullscreen() else DisplayServer.WINDOW_MODE_WINDOWED
	_check(got[0] == [want_mode, true] and got[1] == [want_mode, false], "settings: display file holds the window mode, and HiDPI off only with \"Low-res window\"", str(got))
	# Both window choices survive a restart: saved in settings.cfg too.
	var tmp_s: String = "user://selftest_settings.cfg"
	var lrw2: bool = Settings.low_res_window
	Settings.low_res_window = not lrw2
	Settings._save(tmp_s)
	Settings.low_res_window = lrw2
	var sc2 := ConfigFile.new()
	sc2.load(tmp_s)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(tmp_s))
	_check(sc2.get_value("settings", "low_res_window", lrw2) == (not lrw2) and sc2.get_value("settings", "fullscreen", null) == Settings.is_fullscreen(),
		"settings: \"Low-res window\" and fullscreen are saved with the settings", "%s %s" % [sc2.get_value("settings", "low_res_window", null), sc2.get_value("settings", "fullscreen", null)])
	_check(Settings.render_scale(2) == 1.0 and Settings.render_scale(0) == Settings.QUALITY_RENDER_SCALE[0], "settings: 3D scale per quality, unchanged at full resolution", "%.2f" % Settings.render_scale(0))
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
	ok = Updater.apply_response(200, '{"tag_name": "v9.9.9", "assets": [{"name": "update-manifest.json", "browser_download_url": "https://example.org/m"}, {"name": "x"}]}')
	_check(ok and Updater.latest.assets.get("update-manifest.json", "") == "https://example.org/m" and Updater.latest.assets.size() == 1 and not Updater.can_install(),
		"updater: keeps the release's file links, never installs in a test run")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Updater.cache_path()))
	Updater.latest = saved

## Signed update packs (UpdatePack) with throwaway keys made here, in
## user://selftest/update: a good pack installs and loads, a pack changed on
## disk is skipped for the older good one, and an unsigned, wrongly signed,
## changed, wrong-engine, too-old or full-download-only one never installs.
func _test_update_pack() -> void:
	var root: String = "user://selftest/update"
	_rm_tree(root)
	DirAccess.make_dir_recursive_absolute(root)
	var crypto := Crypto.new()
	var key: CryptoKey = crypto.generate_rsa(2048)
	var other: CryptoKey = crypto.generate_rsa(2048)
	var pub := CryptoKey.new()
	pub.load_from_string(key.save_to_string(true), true)
	var eng: String = UpdatePack.engine_version()
	var base: String = "1.0.0"
	# A pack with one file in it, and its manifest (fields in `extra` win).
	var make: Callable = func(v: String, extra: Dictionary = {}) -> Array:
		var src: String = root.path_join("marker_%s.txt" % v)
		var f := FileAccess.open(src, FileAccess.WRITE)
		f.store_string(v)
		f = null
		var tmp: String = root.path_join("dl_%s.part" % v)
		var pk := PCKPacker.new()
		pk.pck_start(tmp)
		pk.add_file("res://sh_selftest/pack_marker.txt", src)
		pk.flush()
		var pf := FileAccess.open(tmp, FileAccess.READ)
		var m: Dictionary = {"version": v, "engine": eng, "min_base": "0.0.0", "packs": {UpdatePack.platform(): {"file": "p.pck", "size": pf.get_length(), "sha256": UpdatePack.file_sha256(tmp)}}}
		m.merge(extra, true)
		return [JSON.stringify(m).to_utf8_buffer(), tmp]
	var sign: Callable = func(b: PackedByteArray, k: CryptoKey) -> PackedByteArray: return crypto.sign(HashingContext.HASH_SHA256, UpdatePack.sha256(b), k)
	var a: Array = make.call("1.1.0")
	var err1: String = UpdatePack.install(root, a[0], sign.call(a[0], key), a[1], pub, base, eng)
	var b: Array = make.call("1.2.0")
	var err2: String = UpdatePack.install(root, b[0], sign.call(b[0], key), b[1], pub, base, eng)
	var found: Dictionary = UpdatePack.find_loadable(root, pub, base, eng)
	_check(err1 == "" and err2 == "" and found.get("version", "") == "1.2.0" and not FileAccess.file_exists(b[1]), "update pack: signed packs install, the newest is used", "%s / %s / %s" % [err1, err2, found])
	# Change one byte of the installed 1.2.0 pack: skipped, 1.1.0 is used.
	var pck: String = root.path_join("1.2.0/game.pck")
	var bytes: PackedByteArray = FileAccess.get_file_as_bytes(pck)
	bytes[bytes.size() / 2] ^= 0xff
	var w := FileAccess.open(pck, FileAccess.WRITE)
	w.store_buffer(bytes)
	w = null
	found = UpdatePack.find_loadable(root, pub, base, eng)
	_check(found.get("version", "") == "1.1.0", "update pack: a tampered installed pack is ignored, the older good one kept", str(found))
	# Packs that must never install.
	var bad: Array = []
	var c: Array = make.call("1.3.0")
	bad.append(["unsigned", UpdatePack.install(root, c[0], PackedByteArray(), c[1], pub, base, eng)])
	c = make.call("1.3.0")
	bad.append(["bad signature", UpdatePack.install(root, c[0], sign.call(c[0], other), c[1], pub, base, eng)])
	c = make.call("1.3.0")
	var sig: PackedByteArray = sign.call(c[0], key)
	var changed: PackedByteArray = c[0].duplicate()
	changed[10] ^= 1
	bad.append(["bad signature", UpdatePack.install(root, changed, sig, c[1], pub, base, eng)])
	c = make.call("1.3.0", {"packs": {UpdatePack.platform(): {"file": "p.pck", "size": 1, "sha256": "00"}}})
	bad.append(["wrong size", UpdatePack.install(root, c[0], sign.call(c[0], key), c[1], pub, base, eng)])
	c = make.call("1.3.0", {"engine": "0.0.1"})
	bad.append(["other engine", UpdatePack.install(root, c[0], sign.call(c[0], key), c[1], pub, base, eng)])
	c = make.call("1.3.0", {"min_base": "1.3.0"})
	bad.append(["needs full download", UpdatePack.install(root, c[0], sign.call(c[0], key), c[1], pub, base, eng)])
	c = make.call("0.9.0")
	bad.append(["not newer", UpdatePack.install(root, c[0], sign.call(c[0], key), c[1], pub, base, eng)])
	c = make.call("1.3.0")
	bad.append(["no key", UpdatePack.install(root, c[0], sign.call(c[0], key), c[1], null, base, eng)])
	var wrong: Array = bad.filter(func(x: Array) -> bool: return x[0] != x[1])
	_check(wrong.is_empty() and UpdatePack.installed(root) == ["1.2.0", "1.1.0"] and not FileAccess.file_exists(c[1]),
		"update pack: unsigned, wrong key, changed manifest/pack, other engine, full-download-only, older and keyless packs are refused", str(wrong))
	# The good one really loads (into this test run only: one file under
	# res://sh_selftest/), and the startup loader stays off in tests.
	var loaded: bool = ProjectSettings.load_resource_pack(found.get("path", ""), true)
	_check(loaded and FileAccess.get_file_as_string("res://sh_selftest/pack_marker.txt") == "1.1.0" and UpdatePack.loaded.is_empty(),
		"update pack: a good pack loads; nothing is loaded at startup in a test run")
	# Installing a third version keeps only the newest two.
	c = make.call("1.4.0")
	var err4: String = UpdatePack.install(root, c[0], sign.call(c[0], key), c[1], pub, base, eng)
	_check(err4 == "" and UpdatePack.installed(root) == ["1.4.0", "1.2.0"], "update pack: keeps the newest two installed", str(UpdatePack.installed(root)))
	# A pack that crashed twice before the menu is skipped (1.2.0 was
	# tampered above, so nothing is left); clearing the count brings it back.
	var d14: String = root.path_join("1.4.0")
	UpdatePack._set_boot_failures(d14, UpdatePack.MAX_BOOT_FAILURES)
	var skipped: Dictionary = UpdatePack.find_loadable(root, pub, base, eng)
	DirAccess.remove_absolute(d14.path_join(UpdatePack.BOOT_FILE))
	var back: Dictionary = UpdatePack.find_loadable(root, pub, base, eng)
	_check(skipped.is_empty() and back.get("version", "") == "1.4.0", "update pack: a pack that failed to start twice is skipped", "%s / %s" % [skipped, back])
	_check(UpdatePack.valid_version("1.4.0") and UpdatePack.valid_version("0.11") and not UpdatePack.valid_version("../1.0") and not UpdatePack.valid_version("1.0/x") and not UpdatePack.valid_version(""),
		"update pack: the version must be digits and dots (it names a folder)")
	_rm_tree(root)

## A Village course (VillageCourse): idle until START is flown, then one
## lap with the marker, the best time saved (tests: user://selftest/), and
## a run that stalls ends by itself after the timeout.
func _test_village_course() -> void:
	var root := Node3D.new()
	get_tree().root.add_child(root)
	var d: Drone = (load("res://scenes/Drone.tscn") as PackedScene).instantiate()
	root.add_child(d)
	d.freeze = true
	d.global_position = Vector3(0, 1, 10)
	await get_tree().physics_frame
	DirAccess.remove_absolute(VillageCourse.BEST_PATH)
	var vc := VillageCourse.create(root, "club", [
		["start", Vector3(0, 0, 0), 0.0],
		["gate", Vector3(0, 0, -20), 0.0],
		["new", ["turn", Vector3(3, 0, -35), 0.0, "left"]],
		["opening", Vector3(0, 1.2, -50), PI, 2.0, 2.0],
	])
	d.global_position = Vector3(0, 1, -10)
	vc.start(d, null)
	await _fly_to(d, Vector3(0, 1.0, 5)) # back round: through START the right way
	var idle_ok: bool = vc.running # START was flown backwards first: not started
	await _fly_to(d, Vector3(0, 1.0, -5))
	var started: bool = vc.running and vc._next == 1 and vc._marker.visible
	await _fly_to(d, Vector3(0, 1.0, -25))
	await _fly_to(d, Vector3(0, 1.0, -40))
	await _fly_to(d, Vector3(-4, 1.2, -48))
	await _fly_to(d, Vector3(0, 1.2, -55))
	await _fly_to(d, Vector3(0, 1.2, -45)) # through the opening (it faces back)
	await _fly_to(d, Vector3(0, 1.2, 5))
	await _fly_to(d, Vector3(0, 1.0, -5)) # START again: the finish
	var best: float = VillageCourse.best_time("club")
	_check(not idle_ok and started and not vc.running and best > 0.0 and not vc._marker.visible,
		"village course: starts at START, one lap, best time saved, marker gone after", "%s %s %s %.2f" % [idle_ok, started, vc.running, best])
	await _fly_to(d, Vector3(0, 1.0, 5))
	await _fly_to(d, Vector3(0, 1.0, -5))
	var again: bool = vc.running
	vc._last_gate_t -= VillageCourse.TIMEOUT + 1.0
	await get_tree().physics_frame
	await get_tree().physics_frame
	_check(again and not vc.running, "village course: a stalled run ends by itself (timeout)")
	root.queue_free()
	DirAccess.remove_absolute(VillageCourse.BEST_PATH)

func _find_text(n: Node, text: String) -> Node:
	if n is Label and (n as Label).text == text:
		return n
	if n is Button and (n as Button).text == text:
		return n
	for c in n.get_children():
		var f: Node = _find_text(c, text)
		if f:
			return f
	return null

## Keyboard flying (2026-10-12): Angle by default without a radio, Acro
## once a radio sends (unless the pilot chose with L); held keys ramp the
## stick up to Settings.keyboard_strength instead of jumping to full.
func _test_keyboard() -> void:
	var saved_joy = InputManager.test_joy
	var saved_ov = InputManager.test_override
	InputManager.test_joy = null
	InputManager.test_override = null
	if InputManager._joy_connected():
		print("SELFTEST SKIP keyboard: a real radio is connected")
		InputManager.test_joy = saved_joy
		InputManager.test_override = saved_ov
		return
	var fresh: Node = (InputManager.get_script() as GDScript).new()
	var default_angle: bool = fresh.self_level
	fresh.free()
	var lvl0: bool = InputManager.self_level
	var user0: bool = InputManager._level_user_set
	InputManager._level_user_set = false
	InputManager.self_level = true
	InputManager.radio_found_mode()
	var radio_acro: bool = not InputManager.self_level
	InputManager._level_user_set = true
	InputManager.self_level = true
	InputManager.radio_found_mode()
	var kept: bool = InputManager.self_level
	InputManager.self_level = lvl0
	InputManager._level_user_set = user0
	_check(default_angle and radio_acro and kept, "keyboard: Angle by default without a radio; a radio switches to Acro unless the pilot chose")
	InputManager._kb_axes = Vector3.ZERO
	InputManager.update_keyboard_axes(0.05, Vector3(1, 0, 0)) # D held
	var r1: float = InputManager.get_roll()
	InputManager.update_keyboard_axes(0.4, Vector3(1, 0, 0))
	var r2: float = InputManager.get_roll()
	InputManager.update_keyboard_axes(0.5, Vector3.ZERO) # released
	var r3: float = InputManager.get_roll()
	_check(r1 > 0.0 and r1 < r2 * 0.5 and is_equal_approx(r2, Settings.keyboard_strength) and r3 == 0.0,
		"keyboard: a held key ramps the stick up to the keyboard strength, release brings it back", "%.2f %.2f %.2f" % [r1, r2, r3])
	InputManager.test_joy = saved_joy
	InputManager.test_override = saved_ov

func _fly_to(d: Node3D, to: Vector3) -> void:
	var pos: Vector3 = d.global_position
	while pos.distance_to(to) > 0.01:
		pos = pos.move_toward(to, 2.0)
		d.global_position = pos
		await get_tree().physics_frame

## Saves keep keys this version doesn't know: 0.10.1 dropped a newer
## version's race_line_hue from settings.cfg (DEV_TODO 0.11.0 (c)). Races
## records and ghosts are written by load-modify-save already.
func _test_save_keeps_unknown_keys() -> void:
	var path: String = "user://selftest/settings_keep.cfg"
	DirAccess.make_dir_recursive_absolute("user://selftest")
	var cfg := ConfigFile.new()
	cfg.set_value("settings", "from_the_future", 42)
	cfg.set_value("later_section", "x", "y")
	cfg.save(path)
	Settings._save(path)
	cfg = ConfigFile.new()
	cfg.load(path)
	_check(cfg.get_value("settings", "from_the_future", 0) == 42 and cfg.get_value("later_section", "x", "") == "y" and cfg.has_section_key("settings", "race_line_hue"),
		"saves: settings keep keys written by a newer version")
	DirAccess.remove_absolute(path)

func _rm_tree(dir: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		_rm_tree(dir.path_join(sub))
	DirAccess.remove_absolute(dir)

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
	Settings.selected_drone = "race"
	Achievements.note_flight("village")
	var names: Array = []
	var hangar: String = ""
	for a in Achievements.list():
		names.append(a.name)
		if a.name == "Hangar":
			hangar = a.progress
	_check(names.has("Race every map") and names.has("Hardest lines") and names.has("All-rounder") and int(hangar.split("/")[0]) >= 1 and hangar.ends_with("/%d" % Drone.PROFILE_ORDER.size()),
		"achievements: the harder ones are listed, a flight counts its drone", hangar)
	Collectibles.reset()

var _float_checked: Dictionary = {}
var _flown: Dictionary = {}
## Thin things a drone must not slip through (2026-10-14: ladders,
## cables, nets, fences had no hitboxes): per map, [what, from, to] - a
## ray through a gap in the drawn rods that must hit.
const THIN_PROBES: Dictionary = {
	"res://scenes/maps/RaceField.tscn": [["the safety net between its strands", Vector3(0, 1.65, 50), Vector3(0, 1.65, 54)]],
}

## SH_SELFTEST_ONLY=text: every map's text check, each problem listed
## (SH_TEXT_MAPS=Village,Factory for some maps only).
func _test_text_all() -> void:
	var names: PackedStringArray = ["Village", "Factory", "Main3", "Playground", "RaceField", "SteelMill", "RaceArena", "Office", "ParkingGarage", "ConstructionSite", "Harbour", "MountainLake", "TestValley"]
	if OS.has_environment("SH_TEXT_MAPS"):
		names = OS.get_environment("SH_TEXT_MAPS").split(",")
	for nm in names:
		var path: String = "res://scenes/Main3.tscn" if nm == "Main3" else "res://scenes/maps/%s.tscn" % nm
		get_tree().change_scene_to_file(path)
		await _wait(2.0)
		var tc: Array = TextCheck.run(get_tree().current_scene)
		for e: Array in tc:
			print("  TEXT %s: \"%s\" at (%.1f, %.1f, %.1f): %s" % [nm, e[0], e[1].x, e[1].y, e[1].z, e[2]])
		var sc2: Node = get_tree().current_scene
		_check(tc.is_empty(), nm + ": text lies flat on its wall or sign", "%d problems, %d labels, %d graffiti" % [tc.size(), sc2.find_children("*", "Label3D", true, false).size(), (sc2 as BuiltMap).decal_spots.size() if sc2 is BuiltMap else 0])

## Water behaves the same everywhere (2026-10-14): dropped onto it, the
## drone splashes, can't fly, and is back at its spawn after a moment -
## on Mountain Lake (its lake used to be solid) and the Harbour (its sea
## used to let you through).
func _test_water() -> void:
	for nm in ["MountainLake", "Harbour"]:
		Settings.selected_drone = "seeker3"
		get_tree().change_scene_to_file("res://scenes/maps/%s.tscn" % nm)
		await _wait(2.0)
		var sc: BuiltMap = get_tree().current_scene as BuiltMap
		var d: Drone = _drone()
		_check(sc._water.size() >= 3, nm + ": its water is known (surface triangles)", str(sc._water.size() / 3))
		if sc._water.size() < 3:
			continue
		# Nothing scattered (trees, flowers, bushes - MultiMesh instances)
		# stands with its foot under the water surface.
		var in_water: Array = []
		var n_inst: int = 0
		for mmi in sc.find_children("*", "MultiMeshInstance3D", true, false):
			var mm: MultiMesh = (mmi as MultiMeshInstance3D).multimesh
			if mm == null or mm.transform_format != MultiMesh.TRANSFORM_3D or (mmi as Node).has_meta("dynamic") or mmi is GrassTufts or (mmi as Node).get_parent() is GrassTufts:
				continue
			for i in range(mm.visible_instance_count if mm.visible_instance_count >= 0 else mm.instance_count):
				var o: Vector3 = ((mmi as Node3D).global_transform * mm.get_instance_transform(i)).origin
				n_inst += 1
				if sc.water_level(o + Vector3(0, 50, 0)) > o.y + 0.1:
					in_water.append("%s %s" % [(mmi as Node).name, str(o.round())])
		_check(n_inst > 0 and in_water.is_empty(), nm + ": no tree/flower stands in the water", "%d of %d: %s" % [in_water.size(), n_inst, str(in_water.slice(0, 4))])
		# The grass tufts' ground capture check (GrassTufts.capture_ok) tells
		# a real capture (grass flag exactly 0/1) from a stale frame.
		var good := Image.create(64, 64, false, Image.FORMAT_RGB8)
		good.fill(Color(0.3, 0.6, 1.0))
		good.fill_rect(Rect2i(0, 0, 32, 64), Color(0.2, 0.1, 0.0))
		var stale := Image.create(64, 64, false, Image.FORMAT_RGB8)
		for y in range(64):
			for x in range(64):
				stale.set_pixel(x, y, Color(0.4, 0.5, float(x + y) / 128.0))
		_check(GrassTufts.capture_ok(good) and not GrassTufts.capture_ok(stale), nm + ": grass capture check accepts a real capture, rejects a stale frame")
		# The water nearest the spawn: rings outward until one is over water.
		var spot := Vector3.INF
		var sp: Vector3 = d._spawn_transform.origin
		for r in range(4, 600, 4):
			for k in range(24):
				var q: Vector3 = sp + Vector3(cos(TAU * k / 24.0), 0, sin(TAU * k / 24.0)) * float(r)
				var lvl: float = sc.water_level(Vector3(q.x, sp.y + 200.0, q.z))
				if lvl != -INF:
					spot = Vector3(q.x, lvl, q.z)
					break
			if spot != Vector3.INF:
				break
		print("  WATER %s: spot %s, level there %.2f" % [nm, str(spot), sc.water_level(spot + Vector3(0, 1, 0)) if spot != Vector3.INF else -1.0])
		_check(spot != Vector3.INF, nm + ": a water spot to drop the drone on")
		if spot == Vector3.INF:
			continue
		var hit: Array = [false]
		var cb := func() -> void: hit[0] = true
		d.splashed.connect(cb)
		d.freeze = false
		d.global_position = spot + Vector3(0, 1.2, 0)
		d.linear_velocity = Vector3(0, -3, 0)
		d.reset_physics_interpolation()
		await _wait(0.8)
		_check(hit[0] and not InputManager.armed, nm + ": a drone that goes into the water splashes", "at %s, level %.2f" % [str(spot), sc.water_level(spot + Vector3(0, 1, 0))])
		await _wait(1.6)
		_check(d.global_position.distance_to(sp) < 1.5, nm + ": ...and is back at its spawn soon after", str(d.global_position))
		d.splashed.disconnect(cb)
		# Water damage off: through the water, still armed, slowed, no reset.
		Settings.water_damage = false
		hit[0] = false
		d.splashed.connect(cb)
		InputManager.armed = true
		d.global_position = spot + Vector3(0, 1.2, 0)
		d.linear_velocity = Vector3(4, -6, 0)
		d.reset_physics_interpolation()
		await _wait(0.6)
		var wet: bool = d._wet or d.global_position.y < spot.y
		_check(not hit[0] and InputManager.armed and d.global_position.distance_to(sp) > 3.0, nm + ": water damage off - the drone goes into the water and keeps flying (no splash-crash, no reset)",
			"splashed %s armed %s at %s" % [hit[0], InputManager.armed, str(d.global_position)])
		_check(wet and d.linear_velocity.length() < 6.0, nm + ": ...under the surface, slowed by the water", "wet %s speed %.1f" % [wet, d.linear_velocity.length()])
		d.splashed.disconnect(cb)
		Settings.water_damage = true
		InputManager.armed = false
		d.reset_to_spawn()
		await _wait(0.3)

## SH_SELFTEST_ONLY=flow: every generated map's dead ends listed
## (BuiltMap.dead_ends; SH_TEXT_MAPS picks maps).
func _test_flow_all() -> void:
	var names: PackedStringArray = ["Village", "Factory", "Playground", "RaceField", "SteelMill", "RaceArena", "Office", "ParkingGarage", "ConstructionSite", "Harbour", "MountainLake", "TestValley"]
	if OS.has_environment("SH_TEXT_MAPS"):
		names = OS.get_environment("SH_TEXT_MAPS").split(",")
	for nm in names:
		get_tree().change_scene_to_file("res://scenes/maps/%s.tscn" % nm)
		await _wait(2.0)
		var sc: BuiltMap = get_tree().current_scene as BuiltMap
		var de: Array = sc.dead_ends()
		for e: Array in de:
			print("  DEADEND %s: %s, open only at (%.1f, %.1f, %.1f), inner radius %.1f m" % [nm, e[0], e[1].x, e[1].y, e[1].z, e[2]])
		_check(de.is_empty(), nm + ": no dead ends (every hollow you can fly into has a way out)", "%d of %d hollows" % [de.size(), sc.geo.hollows.size()])

## SH_SELFTEST_ONLY=autopilot: the trailer autopilot (Autopilot) flies one
## lap of Race Field's first track through the real input path - a
## regression check for the flight model, rates and race timing: a
## change that makes it miss the lap, crash or get much slower shows here.
func _test_autopilot() -> void:
	var saved_drone: String = Settings.selected_drone
	var saved_track: int = Settings.race_track
	Settings.selected_drone = "race"
	Settings.game_mode = Settings.MODE_RACE
	Settings.race_track = 1
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await _wait(2.0)
	var ap := Autopilot.new()
	ap.max_tilt_deg = 70.0 # (race style: the lap time is the check)
	var ok: bool = await ap.fly(get_tree(), 1, 0.9, 1)
	_check(ok, "autopilot: one lap of Race Field track 1", "laps %s" % str(ap.lap_times))
	_check(ap.resets == 0, "autopilot: no reset on the way", "%d resets" % ap.resets)
	_check(ok and ap.lap_times[0] < 30.0, "autopilot: lap under 30 s (25 s in the self-test, 13 s with the dev Mac settings, 2026-10-21)", str(ap.lap_times))
	ap.queue_free()
	Settings.selected_drone = saved_drone
	Settings.race_track = saved_track
	Settings.game_mode = Settings.MODE_FREESTYLE

## SH_SELFTEST_ONLY=zfight: every generated map built with its faces
## recorded, the z-fight list printed (SH_TEXT_MAPS picks maps too).
func _test_zfight_all() -> void:
	var names: PackedStringArray = ["Village", "Factory", "Playground", "RaceField", "SteelMill", "RaceArena", "Office", "ParkingGarage", "ConstructionSite", "Harbour", "MountainLake", "TestValley"]
	if OS.has_environment("SH_TEXT_MAPS"):
		names = OS.get_environment("SH_TEXT_MAPS").split(",")
	Geo.record_faces = true
	for nm in names:
		get_tree().change_scene_to_file("res://scenes/maps/%s.tscn" % nm)
		await _wait(2.0)
		var sc: Node = get_tree().current_scene
		var zf: Array = (sc as BuiltMap).zfight if sc is BuiltMap else []
		_check(zf.is_empty(), nm + ": no flickering faces (z-fighting)", "%d spots" % zf.size())
		if sc is BuiltMap:
			var ld: Array = (sc as BuiltMap).loose_driveways()
			for e: Array in ld:
				print("  DRIVE %s: street end (%.1f, %.1f) is %.1f m from a road (house end %.1f, %.1f)" % [nm, e[0].x, e[0].z, (sc as BuiltMap).geo.lane_gap(Vector2(e[0].x, e[0].z)), e[1].x, e[1].z])
			_check(ld.is_empty(), nm + ": every driveway meets a road", "%d of %d" % [ld.size(), (sc as BuiltMap).geo.drive_ends.size()])
	Geo.record_faces = false

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
		var sgc: Array = (sc as BuiltMap).geo.sign_conflicts
		_check(sgc.is_empty(), tag + ": no sign post stands inside a drawn piece", str(sgc.slice(0, 3)))
		var lc: Array = (sc as BuiltMap).layout_conflicts()
		_check(lc.is_empty(), tag + ": layout makes sense (no building on a road or rail, none in another)", "%d: %s" % [lc.size(), str(lc.slice(0, 20 if OS.has_environment("SH_LAYOUT") else 4))])
		var de: Array = (sc as BuiltMap).dead_ends()
		_check(de.is_empty(), tag + ": no dead ends (every hollow you can fly into has a way out)", "%d: %s" % [de.size(), str(de.slice(0, 3))])
		var ce: Array = (sc as BuiltMap).cut_off_entrances()
		for e: Array in ce:
			print("  CUTOFF %s: %s at (%.1f, %.1f, %.1f) - %s" % [sc.name, e[0], e[1].x, e[1].y, e[1].z, e[2]])
		_check(ce.is_empty(), tag + ": nothing cut off (every entrance is on a road that reaches the gate)", "%d of %d: %s" % [ce.size(), (sc as BuiltMap).entrances.size(), str(ce.slice(0, 4).map(func(e: Array) -> String: return "%s %s" % [e[0], e[2]]))])
		var bl: Array = (sc as BuiltMap).blocked_lines()
		for e: Array in bl:
			print("  BLOCKED %s: %s stopped at (%.1f, %.1f, %.1f)" % [sc.name, e[0], e[1].x, e[1].y, e[1].z])
		_check(bl.is_empty(), tag + ": flyable lines stay clear (%d: shafts, tunnels, corridors, aisles)" % (sc as BuiltMap).clear_lines().size(), str(bl.slice(0, 4)))
		var ld: Array = (sc as BuiltMap).loose_driveways()
		_check(ld.is_empty(), tag + ": every driveway meets a road", "%d of %d: %s" % [ld.size(), (sc as BuiltMap).geo.drive_ends.size(), str(ld.slice(0, 3).map(func(e: Array) -> String: return "(%.0f, %.0f)" % [e[0].x, e[0].z]))])
		if sc.has_method("surface_glitches"):
			var sg: Array = sc.surface_glitches()
			_check(sg.is_empty(), tag + ": no terrain through roads or rails", "%d spots: %s" % [sg.size(), str(sg.slice(0, 3))])
		# Ground surfaces: no terrain through roads/paving, no road or yard
		# hanging over the land, nothing stacked close enough to flicker.
		var sr: Dictionary = SurfaceCheck.run(sc as BuiltMap)
		var sv: String = SurfaceCheck.verdict(sc.name, sr)
		_check(sv == "", tag + ": ground surfaces clean (no poke-through, hanging road edge or flicker)", sv if sv != "" else "%d faces, %d ms" % [sr.tris, sr.ms])
	if THIN_PROBES.has(map) and not _float_checked.has("thin " + map):
		_float_checked["thin " + map] = true
		var sp: PhysicsDirectSpaceState3D = (sc as Node3D).get_world_3d().direct_space_state
		for pr: Array in THIN_PROBES[map]:
			var rq := PhysicsRayQueryParameters3D.create(pr[1], pr[2])
			rq.exclude = [d.get_rid()]
			_check(not sp.intersect_ray(rq).is_empty(), tag + ": thin things are solid - " + pr[0])
	if not _float_checked.has("text " + map):
		_float_checked["text " + map] = true
		var tc: Array = TextCheck.run(sc)
		_check(tc.is_empty(), tag + ": text lies flat on its wall or sign", "%d: %s" % [tc.size(), str(tc.slice(0, 4))])
	var hud: Node = sc.find_child("UI", true, false)
	if hud and hud.has_method("_wanted_mouse_mode") and not _float_checked.has("cursor"):
		_float_checked["cursor"] = true
		_check(hud._wanted_mouse_mode() == Input.MOUSE_MODE_CONFINED_HIDDEN, tag + ": no mouse cursor while flying (hidden, kept in the window)")
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
		# (The Race Arena's roof is 22 m up: 1.4 s took the Static Three to
		# 21.8 m, pinned under the roof - the old "W flies forward" flake.)
		var hold: float = 0.75 if Settings.selected_drone in ["five", "race"] else (0.95 if map.ends_with("Office.tscn") or map.ends_with("RaceArena.tscn") else 1.4)
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

	# Each map flown for 5 s once (Angle mode: climb, then cruise
	# forward): the map runs on with a flying drone - no error, no NaN,
	# the drone still in the scene.
	if not _flown.has(map):
		_flown[map] = true
		var ov0 = InputManager.test_override
		var lvl0: bool = InputManager.self_level
		InputManager.self_level = true
		InputManager.armed = true
		InputManager.test_override = {"roll": 0.0, "pitch": 0.0, "yaw": 0.0, "throttle": 0.75}
		await _wait(1.5)
		InputManager.test_override = {"roll": 0.0, "pitch": 0.35, "yaw": 0.1, "throttle": 0.6}
		await _wait(3.5)
		var p5: Vector3 = d.global_position if is_instance_valid(d) else Vector3(NAN, NAN, NAN)
		_check(is_instance_valid(d) and get_tree().current_scene == sc and p5.is_finite() and p5.distance_to(d._spawn_transform.origin) > 3.0,
			tag + ": flies 5 s (climb + cruise) without trouble", "at %s, %.1f m from spawn" % [str(p5.round()), p5.distance_to(d._spawn_transform.origin) if p5.is_finite() else -1.0])
		InputManager.test_override = ov0
		InputManager.armed = false
		InputManager.self_level = lvl0
		if is_instance_valid(d):
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
	# A lost link freezes the LAST frame, never the start picture (2026-10-14:
	# HDZero showed the spawn view). Both digital looks, a fresh spot each.
	for look in [3, 2]:
		Settings.camera_look = look
		d.global_position += Vector3(-25, 6, 0)
		await _wait(0.8)
		v._freeze_t = 0.5
		await _wait(0.1)
		var hc: Camera3D = get_viewport().get_camera_3d()
		var off: float = hc.global_position.distance_to(cam.global_position) if hc else 999.0
		_check(hc != null and hc.name == "FpvHoldCam" and off < 1.0, "video: %s link loss holds the last frame" % FpvVideo.LOOK_NAMES[look], "%s, %.1f m from the drone camera" % [str(hc), off])
		await _wait(0.6)
	# LQ falls off over a range of margins, not 100-or-0.
	var lq_steps: Dictionary = {}
	for m in range(-12, 30):
		lq_steps[int(FpvVideo.lq_for(3, float(m)))] = true
	_check(lq_steps.size() > 15, "video: HDZero LQ falls off gradually", "%d distinct values" % lq_steps.size())
	Settings.camera_look = 0
	await _wait(0.2)
	_check(get_viewport().get_camera_3d() == cam and v.link_quality == -1, "video: Clean is the drone camera, no link model")
	# Clean without a lens at full 3D resolution: no video pass, the
	# window draws the 3D itself (below full resolution the pass scales).
	var fish0: int = Settings.lens_fisheye
	Settings.lens_fisheye = 0
	await _wait(0.2)
	var full_res: bool = Settings.render_scale(Settings.graphics_quality) >= 0.999
	_check(v.presenting != full_res and get_tree().root.disable_3d != full_res, "video: Clean without fisheye skips the video pass only at full 3D resolution", "full res %s, presenting %s" % [full_res, v.presenting])
	# With a lens the video pass presents the 3D view: the window's own 3D
	# is off, the view's camera follows the window's current camera.
	Settings.lens_fisheye = 1
	await _wait(0.2)
	_check(v.presenting and get_tree().root.disable_3d and v._view_cam.global_position.distance_to(cam.get_global_transform_interpolated().origin) < 0.01, "video: the 3D view is drawn through the video pass, from the current camera")
	Settings.lens_fisheye = fish0
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
	# FOV from the Settings screen: the drone's camera follows at once and
	# the pause menu's own FOV slider shows the same value.
	var fov0: float = Settings.camera_fov_deg
	var fov1: float = 117.0 if fov0 != 117.0 else 103.0
	var fov_slider: HSlider = null
	for sl in pm._settings.find_children("*", "HSlider", true, false):
		if is_equal_approx((sl as HSlider).value, fov0) and (sl as HSlider).max_value == 140.0:
			fov_slider = sl
	if fov_slider:
		fov_slider.value = fov1
	var synced: int = 0
	for sl in pm.find_children("*", "HSlider", true, false):
		if is_equal_approx((sl as HSlider).value, fov1):
			synced += 1
	_check(fov_slider != null and is_equal_approx(d._camera.fov, fov1) and synced >= 2, tag + ": FOV slider in Settings moves the camera and the pause menu's slider", "camera %.0f, sliders at %.0f: %d" % [d._camera.fov, fov1, synced])
	Settings.set_camera_fov(fov0)
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
## All saved settings and radio fields as one string (did a control
## change anything?).
func _settings_snapshot() -> String:
	var parts: PackedStringArray = []
	for obj: Object in [Settings, InputManager]:
		for pr in obj.get_property_list():
			if pr.usage & PROPERTY_USAGE_SCRIPT_VARIABLE and not String(pr.name).begins_with("_") and pr.type != TYPE_OBJECT:
				parts.append("%s=%s" % [pr.name, var_to_str(obj.get(pr.name))])
	return ";".join(parts)

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
	await _wait(0.4)
	_check(ss._calibration_step == ss.STEP_TEST and InputManager.arm_source == "axis" and InputManager.arm_axis == 5, "calibration: arm switch assigned", InputManager.arm_control_name())
	ss._cal_next.pressed.emit()
	await _wait(0.1)
	_check(ss._settings_screen.visible, "calibration: Done returns to Settings")
	# A real radio reports a channel only once it moves: an arm switch
	# untouched since the game started reads 0 (its OFF is really -1).
	# The user saw ARM stay OFF on the test card after such a calibration.
	axes[5] = 0.0
	InputManager._forget_axes()
	_find_button(ss, "Assign Arm Switch").pressed.emit()
	await _wait(0.2)
	axes[6] = 0.99997 # flip ON: the channel's first report
	await _wait(0.2)
	_check(not ss._arm_candidate.is_empty() and ss._calibration_step == ss.STEP_ARM, "calibration: unmoved arm channel detected on its first report")
	axes[6] = -1.0 # back OFF
	await _wait(0.4)
	_check(ss._calibration_step == ss.STEP_TEST and InputManager.arm_axis == 6 and is_equal_approx(InputManager.arm_axis_off_value, -1.0) and InputManager.arm_axis_on_value > 0.9,
		"calibration: unmoved arm channel stored with its measured OFF/ON", "axis %d off %.2f on %.2f" % [InputManager.arm_axis, InputManager.arm_axis_off_value, InputManager.arm_axis_on_value])
	var arm_off_reads: bool = InputManager.arm_switch_on()
	axes[6] = 0.99997
	await _wait(0.1)
	_check(not arm_off_reads and InputManager.arm_switch_on(), "calibration: test card reads ARM OFF and ARM ON for that switch")
	axes[6] = 0.0
	ss._cal_next.pressed.emit()
	await _wait(0.1)
	InputManager.arm_axis = 5
	InputManager.arm_axis_off_value = -1.0
	InputManager.arm_axis_on_value = 1.0
	axes[5] = -1.0
	await _wait(0.2)
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
	var st: String = RaceCourse.STATS_PATH
	var st_backup: String = FileAccess.get_file_as_string(st) if FileAccess.file_exists(st) else ""
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
	_check(cfg.has_section_key(RaceCourse.section("race_field", 1), "five_q"), "race: the ghost is saved per track + drone")
	# The remaining laps finish the race: results, a top-5 entry.
	for _l in range(RaceCourse.LAPS - 1):
		for p in pts.slice(2):
			while pos.distance_to(p) > 0.01:
				pos = pos.move_toward(p, 2.5)
				d.global_position = pos
				await get_tree().physics_frame
	await get_tree().physics_frame
	var b5: Dictionary = RaceCourse.boards("race_field")
	_check(b5.has("five") and not b5.five.is_empty() and course._lap == 0, "race: %d laps finish the race and enter the top 5" % RaceCourse.LAPS, str(b5.get("five", [])))
	# The results card stays until SPACE; it says so. The race line sits
	# at the bottom of the screen.
	var rui: Node = get_tree().current_scene.get_node("UI")
	var says_space: bool = false
	if rui.results_open():
		for l in rui._results.find_children("*", "Label", true, false):
			says_space = says_space or (l as Label).text.contains("SPACE  close")
	_check(rui.results_open() and says_space, "race: the finish card stays up and says SPACE closes it")
	var fcard: Control = rui._results.find_child("FinishCard", true, false) if rui.results_open() else null
	var ftime: Label = fcard.find_child("Time", true, false) if fcard else null
	_check(fcard != null and ftime != null and ftime.text.contains(":") and fcard.size.x < rui.get_viewport().get_visible_rect().size.x * 0.45,
		"race: the finish card shows the race time and leaves the world visible", "%s, %.0f px" % [ftime.text if ftime else "-", fcard.size.x if fcard else -1.0])
	_key(KEY_SPACE, true)
	await _wait(0.1)
	_key(KEY_SPACE, false)
	await get_tree().process_frame
	_check(not rui.results_open(), "race: SPACE closes the results card")
	_check(rui._race_bar != null and rui._race_bar.anchor_top == 1.0, "race: the race bar sits at the bottom of the screen")
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
	# ...and gate 2 stays missed - "go back" - until it is flown.
	_check(course._missed_gate == 2, "race: a skipped gate stays MISSED until flown", "missed %d" % course._missed_gate)
	for p in [course._gates[2].xf * Vector3(0, 0, 2.0), course._gates[2].xf * Vector3(0, 0, -2.0)]:
		while pos.distance_to(p) > 0.01:
			pos = pos.move_toward(p, 2.5)
			d.global_position = pos
			await get_tree().physics_frame
	_check(course._missed_gate == -1 and course._next == 3, "race: flying the missed gate clears it, the race goes on", "missed %d next %d" % [course._missed_gate, course._next])
	# Competition rule: skipping gate 3 voids the lap, the course carries on,
	# and at START the race starts over (no lap counted).
	Settings.race_strict = true
	var laps_before: int = course._race_laps.size()
	for gi in [4, 5, 0]:
		for p in [course._gates[gi].xf * Vector3(0, 0, 2.0), course._gates[gi].xf * Vector3(0, 0, -2.0)]:
			while pos.distance_to(p) > 0.01:
				pos = pos.move_toward(p, 2.5)
				d.global_position = pos
				await get_tree().physics_frame
		if gi == 4:
			_check(course._void_gate == 3 and course._missed_gate == -1 and course._next == 5, "race: competition rule - a missed gate voids the lap, no go back",
				"void %d missed %d next %d" % [course._void_gate, course._missed_gate, course._next])
	_check(course._race_laps.size() == 0 and laps_before >= 0 and course._lap == 1 and course._void_gate == -1 and course._lap_start >= 0.0,
		"race: competition rule - a void lap isn't counted, the race starts over at START", "laps %d lap %d" % [course._race_laps.size(), course._lap])
	Settings.race_strict = false
	_check(not RaceCourse.stats("race_field", 1).get("five", [0, 0]).is_empty() and int(RaceCourse.stats("race_field", 1).five[0]) >= 2 and int(RaceCourse.stats("race_field", 1).five[1]) >= 1,
		"race: races started / finished are counted", str(RaceCourse.stats("race_field", 1)))
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
	if st_backup != "":
		var sf := FileAccess.open(st, FileAccess.WRITE)
		sf.store_string(st_backup)
		sf.close()
	else:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(st))
	await _test_race_migration()
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
	# R must still reset while the switch stays ON (it did nothing, 2026-10-17).
	var away: float = d.global_position.distance_to(d._spawn_transform.origin)
	_key(KEY_R, true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	_key(KEY_R, false)
	await _wait(0.1)
	var back_r: float = d.global_position.distance_to(d._spawn_transform.origin)
	_check(away > 1.0 and back_r < 1.0, "radio: R resets while the reset switch stays on",
		"away %.2f m, after R %.2f m from spawn" % [away, back_r])
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

## Race map tracks (RaceCourse.make): every track of every race map builds
## its own gates at load time on top of ONE map cache - the first load
## writes the cache, the rest come from it, each with its own gate count
## and exactly one course.
func _test_tracks() -> void:
	MapCache.force = true
	Settings.game_mode = Settings.MODE_RACE
	for m in MapCatalog.MAPS:
		if not m.get("race", false):
			continue
		if OS.has_environment("SH_TRACK_MAPS") and not OS.get_environment("SH_TRACK_MAPS").split(",").has(m.id):
			continue
		for t in range(1, 7):
			Settings.race_track = t
			InputManager.armed = false
			get_tree().change_scene_to_file(m.scene)
			await _wait(1.5)
			var sc: BuiltMap = get_tree().current_scene as BuiltMap
			var course: RaceCourse = sc.get("course")
			var want: int = RaceCourse.gate_count(sc.tracks()[t - 1].calls)
			var n_courses: int = sc.get_children().filter(func(c: Node) -> bool: return c is RaceCourse).size()
			_check(course != null and course.track == t and course._gates.size() == want and n_courses == 1 and (t == 1 or sc.from_cache),
				"tracks: %s track %d builds its %d gates (cached map: %s)" % [m.id, t, want, sc.from_cache],
				"gates %d, courses %d" % [course._gates.size() if course else -1, n_courses])
			if course == null:
				continue
			# Every opening is clear (a ray through it hits nothing within 3 m
			# either side - 1.5 m for whoop gates indoors), and walking the gates in order times a lap.
			var space: PhysicsDirectSpaceState3D = sc.get_world_3d().direct_space_state
			var dr: Drone = _drone()
			dr.freeze = true
			var blocked: Array[int] = []
			for i in range(course._gates.size()):
				var g: Dictionary = course._gates[i]
				var rd: float = 3.0 if g.w >= 1.0 else 1.5
				var q := PhysicsRayQueryParameters3D.create(g.xf * Vector3(0, 0, rd), g.xf * Vector3(0, 0, -rd))
				q.exclude = [dr.get_rid()]
				if not space.intersect_ray(q).is_empty():
					blocked.append(i + 1)
			_check(blocked.is_empty(), "tracks: %s track %d - every gate opening is clear" % [m.id, t], "blocked: %s" % str(blocked))
			# The racing line runs through nothing (2026-10-14): every point
			# away from the gates has 10 cm of air round it.
			if course._line:
				var near := PackedByteArray()
				near.resize(course._line_pts.size())
				for sb in course._line_seg:
					for k in range(-RaceCourse.LINE_KEEP, RaceCourse.LINE_KEEP + 1):
						near[clampi(sb + k, 0, near.size() - 1)] = 1
				var lb: PackedInt32Array = RaceCourse.blocked_points(space, course._line_pts, 0.1, [dr.get_rid()], near)
				_check(lb.is_empty(), "tracks: %s track %d - the racing line runs through nothing" % [m.id, t], "%d points, first at %s" % [lb.size(), str(course._line_pts[lb[0]]) if not lb.is_empty() else ""])
				# ... nor between its points (0.4 m apart: a thin deck or panel
				# fits between two; the Gallery Run line went up through the
				# gallery deck that way): a ray along every stretch, both ways.
				var cut: Array = []
				var lp: PackedVector3Array = course._line_pts
				# Next to a gate too (2026-10-16: Server Sprint's line cut
				# through a rack beside a gate - those points were skipped);
				# only a hit on a gate's own frame is passed through.
				for i in range(1, lp.size()):
					var by_gate: bool = near[i] == 1 or near[i - 1] == 1
					for ab in [[lp[i - 1], lp[i]], [lp[i], lp[i - 1]]]:
						var from: Vector3 = ab[0]
						var hit: Dictionary = {}
						for _pass in range(6):
							var rq := PhysicsRayQueryParameters3D.create(from, ab[1])
							rq.exclude = [dr.get_rid()]
							hit = space.intersect_ray(rq)
							if hit.is_empty() or not (by_gate and _on_gate_frame(course, hit.position)):
								break
							from = (hit.position as Vector3) + ((ab[1] as Vector3) - from).normalized() * 0.03
							hit = {}
						if not hit.is_empty():
							cut.append("%s (stretch %s -> %s)" % [hit.position, ab[0], ab[1]])
							if OS.has_environment("SH_LINE_DEBUG"):
								var co: Object = hit.collider
								var ow: Object = (co as CollisionObject3D).shape_owner_get_owner((co as CollisionObject3D).shape_find_owner(hit.shape)) if co is CollisionObject3D else null
								var bm: Node = get_tree().current_scene
								if bm is BuiltMap:
									for o: Array in (bm as BuiltMap).geo._obs:
										var dd: Vector2 = Vector2(hit.position.x, hit.position.z) - (o[0] as Vector2)
										if absf(dd.dot(o[1])) < o[2].x + 0.05 and absf(dd.dot(Vector2(-o[1].y, o[1].x))) < o[2].y + 0.05 and hit.position.y > o[3] - 0.05 and hit.position.y < o[4] + 0.05:
											print("LINEOBS ", m.id, " ", hit.position, " ", o)
								print("LINEHIT ", co, " ", ow, " ", (ow as Node3D).global_transform if ow is Node3D else "", " ", (ow as CollisionShape3D).shape if ow is CollisionShape3D else "", " ", ((ow as CollisionShape3D).shape as BoxShape3D).size if ow is CollisionShape3D and (ow as CollisionShape3D).shape is BoxShape3D else "")
							break
				_check(cut.is_empty(), "tracks: %s track %d - no stretch of the racing line crosses anything" % [m.id, t], "%d stretches, first at %s" % [cut.size(), str(cut[0]) if not cut.is_empty() else ""])
			var pos: Vector3 = dr.global_position
			for g: Dictionary in course._gates + [course._gates[0]]:
				for p: Vector3 in [g.xf * Vector3(0, 0, 2.0), g.xf * Vector3(0, 0, -2.0)]:
					while pos.distance_to(p) > 0.01:
						pos = pos.move_toward(p, 2.5)
						dr.global_position = pos
						await get_tree().physics_frame
			await get_tree().physics_frame
			_check(course._last_lap > 0.0, "tracks: %s track %d - a lap through all gates in order is timed" % [m.id, t], "lap %.2f" % course._last_lap)
			# The racing line shows only what's ahead: just past START the
			# cut sits near the start of the lap and moves on with the drone;
			# it reaches the next gate and, while shorter than the target
			# length, up to 3 gates; after a reset the same from START.
			if course._line:
				var lm := course._line.material_override as ShaderMaterial
				course._update_line()
				var cut0: float = lm.get_shader_parameter("cut")
				var mid: Vector3 = course._line_pts[(course._line_seg[0] + course._line_seg[1]) / 2]
				dr.global_position = mid
				course._prev_pos = mid
				course._update_line()
				var cut1: float = lm.get_shader_parameter("cut")
				var cut_ok: bool = course._next == 1 and cut0 < 4.0 and cut1 > cut0 + 0.25 # (a whoop track's first stretch can be 4 m)
				var why: String = _line_rule(course, lm)
				var len0: int = Settings.race_line_length
				Settings.race_line_length = 0
				course._update_line()
				var short_gates: int = (course._line_last - course._next + course._gates.size()) % course._gates.size()
				Settings.race_line_length = 2
				course._update_line()
				var long_gates: int = (course._line_last - course._next + course._gates.size()) % course._gates.size()
				Settings.race_line_length = len0
				cut_ok = cut_ok and long_gates >= short_gates
				dr.global_position = mid + Vector3(0, 20, 0) # a jump: the run resets
				await get_tree().physics_frame
				await get_tree().physics_frame
				course._update_line()
				cut_ok = cut_ok and course._next == 0
				why += _line_rule(course, lm)
				_check(cut_ok and why == "", "tracks: %s track %d - racing line: hidden behind, next gate always, more while short (max 3), same after a reset" % [m.id, t],
					"cut %.1f -> %.1f, gates short %d long %d %s" % [cut0, cut1, short_gates + 1, long_gates + 1, why])
			# A turn flag counts like a gate: past it on the wrong side is a
			# missed gate (it stays next), round it on the right side counts.
			var fi: int = -1
			for i in range(course._gates.size()):
				if course._gates[i].has("flag"):
					fi = i
					break
			if fi >= 0:
				var fg: Dictionary = course._gates[fi]
				var zx: Transform3D = fg.zone.xf
				var wx: float = -float(fg.flag) * (fg.zone.w * 0.5 + 2.0)
				var low: float = -fg.zone.h * 0.5 + 2.0
				course._lap_start = course._time # racing again after the reset above
				course._lap = 1
				course._next = fi
				course._missed_gate = -1
				var steps: Array = [[zx * Vector3(wx, low, 1.0), zx * Vector3(wx, low, -1.0)], [fg.xf * Vector3(0, 0, 1.0), fg.xf * Vector3(0, 0, -1.0)]]
				var res: Array = []
				for st: Array in steps:
					dr.global_position = st[0]
					course._prev_pos = st[0]
					await get_tree().physics_frame
					dr.global_position = st[1]
					await get_tree().physics_frame
					res.append([course._next, course._missed_gate])
				_check(res[0] == [fi, fi] and res[1] == [(fi + 1) % course._gates.size(), -1],
					"tracks: %s track %d - turn flag %d: wrong side = missed, right side counts" % [m.id, t, fi], str(res))
			# The drone spawns on the ground a few metres before START,
			# facing through it.
			var g0: Dictionary = course._gates[0]
			var sp: Transform3D = dr._spawn_transform
			var to_gate: Vector3 = (g0.xf.origin - sp.origin) * Vector3(1, 0, 1)
			_check(to_gate.length() < 6.0 and (-sp.basis.z).dot(-g0.xf.basis.z) > 0.99 and to_gate.normalized().dot(-g0.xf.basis.z) > 0.99,
				"tracks: %s track %d - spawn in front of START, facing through it" % [m.id, t], "%.1f m" % to_gate.length())
			var ball := SphereShape3D.new()
			ball.radius = 0.3
			var sq := PhysicsShapeQueryParameters3D.new()
			sq.shape = ball
			sq.transform = Transform3D(Basis(), sp.origin + Vector3(0, 0.4, 0))
			sq.exclude = [dr.get_rid()]
			var los := PhysicsRayQueryParameters3D.create(sp.origin + Vector3(0, 0.4, 0), g0.xf * Vector3(0, 0, 0.5))
			los.exclude = [dr.get_rid()]
			_check(space.intersect_shape(sq).is_empty() and space.intersect_ray(los).is_empty(), "tracks: %s track %d - the spawn is free, START in clear view" % [m.id, t])
			# Split-S ladders: three openings straight above each other, flown
			# top, middle, bottom, the middle the other way round; each takes
			# only its own direction.
			for i in range(course._gates.size() - 2):
				var a: Dictionary = course._gates[i]
				var b: Dictionary = course._gates[i + 1]
				var c: Dictionary = course._gates[i + 2]
				if (a.xf.origin - c.xf.origin).length() < 1.0 or ((a.xf.origin - b.xf.origin) * Vector3(1, 0, 1)).length() > 0.1 or ((b.xf.origin - c.xf.origin) * Vector3(1, 0, 1)).length() > 0.1:
					continue
				var ok: bool = a.xf.origin.y > b.xf.origin.y and b.xf.origin.y > c.xf.origin.y and b.xf.origin.y - c.xf.origin.y >= (3.0 if a.w >= 1.0 else 0.8) # (whoop ladder: 0.9 m)
				for g: Dictionary in [a, b, c]:
					ok = ok and course._crossed(g, g.xf * Vector3(0, 0, 1), g.xf * Vector3(0, 0, -1)) and not course._crossed(g, g.xf * Vector3(0, 0, -1), g.xf * Vector3(0, 0, 1))
				ok = ok and a.xf.basis.z.dot(b.xf.basis.z) < -0.99 and a.xf.basis.z.dot(c.xf.basis.z) > 0.99
				_check(ok, "tracks: %s track %d - split-S ladder (gates %d-%d): top, middle, bottom, alternating, one way each" % [m.id, t, i + 1, i + 3])
	Settings.race_track = 1
	Settings.game_mode = Settings.MODE_FREESTYLE
	MapCache.force = false

## Saves from before the tracks (0.10.x): the best lap, splits and ghost
## of the current layout ("race_field@2") move to track 1, a stale layout
## ("race_field") and the 3-lap boards are dropped, a .bak is kept, the
## files say version 2. Runs on fixture files; the real ones are restored.
func _test_race_migration() -> void:
	var paths: Array[String] = [RaceCourse.RECORDS_PATH, RaceCourse.GHOST_PATH, RaceCourse.BOARD_PATH, RaceCourse.STATS_PATH]
	var keep: Dictionary = {}
	for p: String in paths + paths.map(func(x: String) -> String: return x + ".bak") + paths.map(func(x: String) -> String: return x + ".v2.bak"):
		keep[p] = FileAccess.get_file_as_string(p) if FileAccess.file_exists(p) else null
	var rec := ConfigFile.new()
	rec.set_value("race_field@2", "five", 30.5)
	rec.set_value("race_field@2", "five_date", "2026-10-01")
	rec.set_value("race_field", "five", 40.0)
	rec.save(RaceCourse.RECORDS_PATH)
	var gh := ConfigFile.new()
	gh.set_value("race_field@2", "five_pos", PackedVector3Array([Vector3.ONE]))
	gh.save(RaceCourse.GHOST_PATH)
	var bd := ConfigFile.new()
	bd.set_value("race_field@2", "five", [[95.0, 30.5, "2026-10-01"]])
	bd.save(RaceCourse.BOARD_PATH)
	RaceCourse._migrated = false
	RaceCourse.migrate_saves()
	var club: int = 1 + RaceCourse.track_list("race_field").map(func(x: Dictionary) -> String: return x.id).find("club_loop")
	# (Club Loop has since been redesigned, rev 2 with turn flags: the old
	# layout's records stay under its rev-1 key and rev 2 starts fresh.)
	var rc := ConfigFile.new()
	rc.load(RaceCourse.RECORDS_PATH)
	var r: float = float(rc.get_value("race_field#club_loop", "five", 0.0))
	var gc := ConfigFile.new()
	gc.load(RaceCourse.GHOST_PATH)
	_check(is_equal_approx(r, 30.5) and not rc.has_section("race_field") and not rc.has_section("race_field@2") and RaceCourse.records("race_field", club).is_empty(),
		"race saves: the best lap moves to the old course (Club Loop), stale layouts go, its redesign starts fresh", str(rc.get_sections()))
	_check(gc.has_section_key("race_field#club_loop", "five_pos"), "race saves: the lap ghost moves to the old course")
	_check(RaceCourse.boards("race_field", club).is_empty(), "race saves: old 3-lap race totals start fresh")
	_check(FileAccess.file_exists(RaceCourse.RECORDS_PATH + ".bak") and int(rc.get_value("meta", "version", 1)) == RaceCourse.SAVE_VERSION,
		"race saves: a .bak is kept and the file says version %d" % RaceCourse.SAVE_VERSION)
	# Version 2 (records per track number, before the reorder): each moves
	# to its track's id, redesigned tracks start fresh, the stats file (no
	# version mark) too, a .v2.bak is kept and the version-1 .bak stays.
	var bak1: String = FileAccess.get_file_as_string(RaceCourse.RECORDS_PATH + ".bak")
	var v2 := ConfigFile.new()
	v2.set_value("meta", "version", 2)
	v2.set_value("race_field#1", "five", 31.0)
	v2.set_value("race_field#2", "five", 12.0)
	v2.set_value("race_field#4", "five", 20.0)
	v2.set_value("race_arena#1", "five", 25.0)
	v2.save(RaceCourse.RECORDS_PATH)
	var st2 := ConfigFile.new()
	st2.set_value("race_field#1", "five", [3, 2])
	st2.save(RaceCourse.STATS_PATH)
	RaceCourse._migrated = false
	RaceCourse.migrate_saves()
	var ids: Array = RaceCourse.track_list("race_field").map(func(x: Dictionary) -> String: return x.id)
	var meadow: int = 1 + ids.find("meadow_sprint")
	var shed: int = 1 + ids.find("shed_run")
	var league: int = 1 + RaceCourse.track_list("race_arena").map(func(x: Dictionary) -> String: return x.id).find("league_night")
	rc = ConfigFile.new()
	rc.load(RaceCourse.RECORDS_PATH)
	_check(is_equal_approx(float(rc.get_value("race_field#club_loop", "five", 0.0)), 31.0) and is_equal_approx(float(RaceCourse.records("race_field", meadow).get("five", [0.0])[0]), 12.0)
		and RaceCourse.records("race_field", shed).is_empty() and RaceCourse.records("race_arena", league).has("five") and not rc.has_section("race_field#1"),
		"race saves: version 2 records follow their track (by id), redesigned tracks start fresh", str(rc.get_sections()))
	var sc2 := ConfigFile.new()
	sc2.load(RaceCourse.STATS_PATH)
	_check(sc2.get_value("race_field#club_loop", "five", []) == [3, 2], "race saves: race counts follow their track too", str(sc2.get_value("race_field#club_loop", "five", [])))
	_check(FileAccess.file_exists(RaceCourse.RECORDS_PATH + ".v2.bak") and FileAccess.get_file_as_string(RaceCourse.RECORDS_PATH + ".bak") == bak1,
		"race saves: a .v2.bak is kept, the version-1 .bak untouched")
	# A file saved without a version mark after the migration is not
	# migrated again (it would lose its tracks).
	var fresh := ConfigFile.new()
	fresh.set_value("race_field#club_loop", "five", 29.0)
	fresh.save(RaceCourse.RECORDS_PATH)
	RaceCourse._migrated = false
	RaceCourse.migrate_saves()
	rc = ConfigFile.new()
	rc.load(RaceCourse.RECORDS_PATH)
	_check(is_equal_approx(float(rc.get_value("race_field#club_loop", "five", 0.0)), 29.0), "race saves: an unmarked current file is left alone")
	for p: String in keep:
		if keep[p] == null:
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_string(keep[p])
			f.close()
	RaceCourse._migrated = false

## Is p on a gate's own frame or stand (a thin slab round the gate plane)?
func _on_gate_frame(course: RaceCourse, p: Vector3) -> bool:
	for g: Dictionary in course._gates:
		var l: Vector3 = (g.xf as Transform3D).affine_inverse() * p
		var w: float = float(g.w) * 0.5 + 0.35
		if absf(l.z) < 0.35 and absf(l.x) < w and absf(l.y) < float(g.get("h", g.w)) * 0.5 + 3.0: # (xf may be the opening's centre: stands below, hanging rods above)
			return true
	return false

