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
	# Betaflight Actual Rates: ends exact, and default expo ~ the old cubic.
	var full: float = Drone.actual_rate_deg(1.0, 70.0, 670.0, 0.54)
	var half: float = Drone.actual_rate_deg(0.5, 70.0, 670.0, 0.54)
	var cubic_half: float = 70.0 * 0.5 + 600.0 * 0.125
	_check(is_equal_approx(full, 670.0) and Drone.actual_rate_deg(0.0, 70.0, 670.0, 0.54) == 0.0 and absf(half - cubic_half) < 3.0 and Drone.actual_rate_deg(-1.0, 70.0, 670.0, 0.54) < -669.0, "rates: Betaflight Actual formula", "half stick %.1f vs cubic %.1f deg/s" % [half, cubic_half])
	await _test_menu_flow()
	await _test_calibration_and_arm_switch()
	var cases: Array = [
		["res://scenes/Main.tscn", "seeker3"],
		["res://scenes/Main.tscn", "five"],
		["res://scenes/Main.tscn", "whoop"],
		["res://scenes/Main2.tscn", "seeker3"],
		["res://scenes/Main2.tscn", "five"],
		["res://scenes/Main2.tscn", "whoop"],
		["res://scenes/Main3.tscn", "whoop"],
		["res://scenes/Main3.tscn", "seeker3"], # the school must force the whoop anyway
		["res://scenes/maps/Playground.tscn", "five"], # forced to the whoop too
		["res://scenes/maps/RaceField.tscn", "five"],
		["res://scenes/maps/SteelMill.tscn", "seeker3"],
		["res://scenes/maps/RaceArena.tscn", "seeker3"],
		["res://scenes/maps/Office.tscn", "seeker3"], # forced to the whoop
		["res://scenes/maps/ParkingGarage.tscn", "five"],
		["res://scenes/maps/Quarry.tscn", "five"],
		["res://scenes/maps/Harbour.tscn", "seeker3"],
		["res://scenes/maps/MountainLake.tscn", "five"],
	]
	for c in cases:
		await _test_map(c[0], c[1], false)
	await _test_race()
	Settings.performance_mode = true
	await _test_map("res://scenes/Main2.tscn", "seeker3", true)
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
	await _tap(KEY_ESCAPE)
	await _wait(0.2)
	_check(menu._screens["main"].visible and not menu._screens["about"].visible, "menu: Esc in About goes back home")
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
	var village: Button = _find_button(menu, "Village")
	if village:
		village.pressed.emit()
	await get_tree().process_frame
	_check(SceneLoader.is_loading(), "menu: map load goes through the loading screen")
	await _wait(2.5)
	var scene: Node = get_tree().current_scene
	_check(scene != null and scene.scene_file_path == "res://scenes/Main.tscn", "menu: Play -> Village loads the map")
	_check(Engine.max_fps == Settings.max_fps, "menu: FPS cap restored in game", "max_fps=%d" % Engine.max_fps)

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
		var hold: float = 0.75 if Settings.selected_drone == "five" else (0.95 if map.ends_with("Office.tscn") else 1.4)
		await _wait(hold)
		_key(KEY_SHIFT, false)
		await _wait(1.2)
		var climbed: float = d.global_position.y - rest_y
		_check(climbed > 1.0, tag + ": takes off (keyboard)", "climbed %.2f m, throttle %.2f" % [climbed, InputManager.get_throttle()])
		_check(d.battery.used_mah > 0.1 and d.battery.cell_v < 4.2 and d.flight_time > 1.0, tag + ": battery drains and flight timer runs", "%.1f mAh, %.2f V/cell, %.1f s" % [d.battery.used_mah, d.battery.cell_v, d.flight_time])
		var osd: Dictionary = get_tree().current_scene.get_node("UI")._osd_labels
		_check(osd.has("time") and osd.time.text.begins_with("00:0") and osd.thr.visible and osd.bat.visible == Settings.battery_enabled, tag + ": OSD shows the flight (battery group only when enabled)", osd.time.text if osd.has("time") else "no OSD")
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
	_check(d.global_position.distance_to(d._spawn_transform.origin) < 0.2, tag + ": R resets to spawn")

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
	get_tree().change_scene_to_file("res://scenes/Main.tscn")
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
	Settings.selected_drone = "five"
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
	_check(course._ghost_pos.size() > 3, "race: best lap recorded as a ghost", "%d samples" % course._ghost_pos.size())
	# Skipping a gate must not count: straight from gate 1 back to start.
	var lap_before: int = course._lap
	for p in [course._gates[1].xf * Vector3(0, 0, 2.0), course._gates[1].xf * Vector3(0, 0, -2.0), course._gates[0].xf * Vector3(0, 0, 2.0), course._gates[0].xf * Vector3(0, 0, -2.0)]:
		while pos.distance_to(p) > 0.01:
			pos = pos.move_toward(p, 2.5)
			d.global_position = pos
			await get_tree().physics_frame
	_check(course._lap == lap_before, "race: cutting the course doesn't complete a lap")
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
