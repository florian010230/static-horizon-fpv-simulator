extends Node

## Dev tool, not part of the shipped game: renders a few real frames and
## saves screenshots to the project root, so the project can be visually
## previewed without a screen-sharing/remote-desktop setup. Godot's
## --headless mode never initializes a real GPU context, so there is no
## way to get an actual rendered image without a normal windowed run -
## this script automates that run.
##
## Usage: godot --path . -- --dev-preview
## (needs a real display; run it un-headless, exactly like playing the
## game normally - takes about 6 seconds, then quits itself). Registered
## as a permanent autoload but does nothing at all unless that flag is
## present, so it's always available without costing anything normally.

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--dev-preview"):
		return
	call_deferred("_go")

## Optional section names after the flag limit the run to those parts,
## e.g. `godot --path . -- --dev-preview village school` - much faster
## when iterating on one map. No names = everything.
func _wants(section: String) -> bool:
	var args := OS.get_cmdline_user_args()
	var sections: Array = ["menu", "village", "factory", "school"]
	for m in MapCatalog.MAPS:
		sections.append(m.id)
	# ("shadows" is a modifier, not a section.)
	for a in args:
		if a in sections:
			return a == section or args.has(section)
	return true

func _go() -> void:
	# `-- --dev-preview shadows ...` renders everything with shadows on.
	if OS.get_cmdline_user_args().has("shadows"):
		Settings.shadows_enabled = true
	if _wants("menu"):
		await _menu_shots()
	if _wants("village"):
		await _map_shots("res://scenes/Main.tscn", "village", [
			["topdown", Vector3(20, 160, 10), Vector3(20.1, 0, 9.9)],
			["main_street", Vector3(-62, 5, 70), Vector3(40, 3, 70)],
			["street_east", Vector3(95, 7, 66), Vector3(140, 6, 90)],
			["house_inside", Vector3(-12, 1.8, 80), Vector3(-25, 1.2, 80)],
			["house_living", Vector3(-11.5, 1.9, 78.2), Vector3(-17, 0.3, 82.5)],
			["house_kitchen", Vector3(-19, 2.0, 84.5), Vector3(-12, 0.5, 86.5)],
			["house_bedroom", Vector3(-18.5, 5.8, 78.3), Vector3(-12.6, 3.6, 79.5)],
			["house_front", Vector3(-15, 4, 66), Vector3(-15, 4, 82)],
			["house_upstairs", Vector3(-12, 5.2, 80.5), Vector3(-25, 4.6, 80)],
			["church_inside", Vector3(135, 3.0, 104), Vector3(135, 2.0, 88)],
			["club_field", Vector3(10, 6, 20), Vector3(40, 0, 40)],
			["underpass", Vector3(-40, 3.2, -25), Vector3(-40, 2.4, -80)],
			["railway", Vector3(-10, 14, -30), Vector3(-60, 6, -60)],
			["farm", Vector3(-40, 14, -78), Vector3(-30, 2, -118)],
			# Same spot, four compass directions - for checking that the
			# lighting doesn't go dark looking one way (toward the sun).
			["dir_n", Vector3(0, 6, 30), Vector3(0, 3, 0)],
			["dir_e", Vector3(0, 6, 30), Vector3(30, 3, 30)],
			["dir_s", Vector3(0, 6, 30), Vector3(0, 3, 60)],
			["dir_w", Vector3(0, 6, 30), Vector3(-30, 3, 30)],
			["shadows_top", Vector3(30, 60, 95), Vector3(30.1, 0, 94.9)],
		])
	if _wants("factory"):
		await _map_shots("res://scenes/Main2.tscn", "factory", [
			["topdown", Vector3(25, 160, 0), Vector3(25.1, 0, -0.1)],
			["entrance", Vector3(0, 3, 70), Vector3(0, 2, 20)],
			["hall_inside", Vector3(0, 5, -20), Vector3(0, 3, -45)],
			["rail_dock", Vector3(80, 8, 5), Vector3(62, 2, -30)],
			["tank_farm", Vector3(95, 10, -10), Vector3(85, 5, -45)],
			["overview", Vector3(-40, 30, 70), Vector3(30, 5, -10)],
		])
	if _wants("school"):
		await _map_shots("res://scenes/Main3.tscn", "school", [
			["gym", Vector3(-19, 3.5, 9), Vector3(10, 1.5, -2)],
			["gym_goal", Vector3(-12, 1.6, 3), Vector3(-21, 0.9, 0)],
			["gym_wallbars", Vector3(4, 2.2, 2), Vector3(-2, 1.4, -13)],
			["foyer", Vector3(-12, 1.8, 22.5), Vector3(-12, 1.2, 10)],
			["corridor", Vector3(-17, 1.7, 25.9), Vector3(45, 1.3, 25.9)],
			["classroom", Vector3(15.5, 1.8, 35), Vector3(8, 0.9, 30)],
			["outside", Vector3(80, 8, 40), Vector3(20, 3, 15)],
		])
	# Generated maps name their own views (BuiltMap.preview_views()).
	for m in MapCatalog.available():
		if m.id in ["village", "factory", "school"] or not _wants(m.id):
			continue
		await _map_shots(m.scene, m.id, [], false)
	get_tree().quit()

func _menu_shots() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(1.0).timeout
	_shot("preview_menu.png")

	var settings_btn: Button = _find_button(get_tree().current_scene, "Settings")
	if settings_btn:
		settings_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_settings.png")
	var st: SettingsScreens = get_tree().current_scene.get("_settings")
	for t in [1, 2]:
		st.settings_tabs.current_tab = t
		await get_tree().create_timer(0.3).timeout
		_shot("preview_settings_%s.png" % ["display", "flight", "radio"][t])
	st.settings_tabs.current_tab = 0

	# The calibration wizard, fed by a virtual radio (never completes a
	# step that saves, so the real calibration file is left alone).
	var menu: Node = get_tree().current_scene
	var ss: SettingsScreens = menu.get("_settings")
	var axes: Array = [0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0]
	var buttons: Array = []
	buttons.resize(16)
	buttons.fill(false)
	var saved := {}
	for f in ["axis_roll", "axis_pitch", "axis_yaw", "axis_throttle", "invert_roll", "invert_pitch", "invert_yaw", "axis_rest"]:
		saved[f] = InputManager.get(f).duplicate() if f == "axis_rest" else InputManager.get(f)
	InputManager.test_joy = {"axes": axes, "buttons": buttons}
	ss._start_calibration(false)
	await get_tree().create_timer(0.3).timeout
	_shot("preview_calibration.png")
	InputManager.capture_rest()
	ss._calibration_step = 0
	ss._update_calibration_step()
	axes[0] = 0.92
	ss._hold_time = 0.0
	await get_tree().create_timer(0.4).timeout
	_shot("preview_calibration_hold.png")
	axes[0] = 0.0
	ss._hold_axis = -1
	ss._enter_arm_step()
	ss._update_calibration_step()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_calibration_arm.png")
	ss._calibration_step = ss.STEP_TEST
	ss._update_calibration_step()
	axes[0] = 0.5
	axes[1] = -0.4
	axes[2] = 0.2
	await get_tree().create_timer(0.3).timeout
	_shot("preview_calibration_test.png")
	InputManager.test_joy = null
	InputManager._joy_active = false
	for f in saved:
		InputManager.set(f, saved[f])

	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(0.5).timeout
	_find_button(get_tree().current_scene._screens["main"], "About").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_about.png")

	# Reload fresh rather than clicking "Back"/"Cancel" - all panels
	# (drone/settings/map/calibration) exist in the tree at once (just
	# hidden), so a text search for either is ambiguous about which one
	# it'd hit.
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(0.5).timeout
	var next_btn: Button = _find_button(get_tree().current_scene, "next_drone")
	if next_btn:
		next_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_menu_five.png")
	if next_btn:
		next_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_menu_whoop.png")
	if next_btn:
		next_btn.pressed.emit() # back to the default drone

	var play_btn: Button = _find_button(get_tree().current_scene, "Play")
	if play_btn:
		play_btn.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_map_choice.png")
	SceneLoader.goto("res://scenes/Main2.tscn", "Factory")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_shot("preview_loading.png")
	while SceneLoader.is_loading():
		await get_tree().process_frame

## Loads a map, grabs one shot from the spawn point, then parks the
## (frozen, disarmed) drone at each [name, position, look-at target] and
## grabs another. Aiming with look_at() rather than hand-typed rotation
## angles - the FPV camera itself adds its own upward tilt on top.
func _map_shots(scene: String, prefix: String, views: Array, pause_shots: bool = true) -> void:
	get_tree().change_scene_to_file(scene)
	await get_tree().create_timer(2.0).timeout
	_shot("preview_%s_spawn.png" % prefix)
	if prefix == "playground":
		Settings.video_effect = 2
		await get_tree().create_timer(0.4).timeout
		_shot("preview_%s_analog_video.png" % prefix)
		Settings.video_effect = 0
	# Settled frame rate at the spawn view - the HUD's own FPS readout in
	# the later shots is skewed by each teleport.
	await get_tree().create_timer(3.0).timeout
	print("SPAWN_FPS %s: %d" % [prefix, Engine.get_frames_per_second()])
	var drone: RigidBody3D = get_tree().root.find_child("Drone", true, false)
	if drone == null:
		return
	drone.freeze = true
	InputManager.armed = false
	# The O-key tuning panel covers a third of every shot otherwise.
	var ui: Node = get_tree().root.find_child("UI", true, false)
	if ui and "_panel_visible" in ui:
		ui._panel_visible = false
	if views.is_empty() and get_tree().current_scene.has_method("preview_views"):
		views = get_tree().current_scene.preview_views()
	for v in views:
		drone.global_position = v[1]
		var target: Vector3 = v[2]
		if absf((target - v[1]).normalized().y) > 0.99:
			drone.look_at(target, Vector3.FORWARD)
		else:
			drone.look_at(target, Vector3.UP)
		drone.reset_physics_interpolation()
		await get_tree().create_timer(0.4).timeout
		_shot("preview_%s_%s.png" % [prefix, v[0]])
	# The in-game pause menu over the last view, and its Settings.
	if pause_shots and ui and "pause_menu" in ui and ui.pause_menu:
		ui.pause_menu.open()
		await get_tree().create_timer(0.4).timeout
		_shot("preview_%s_pause.png" % prefix)
		ui.pause_menu._open_settings()
		await get_tree().create_timer(0.4).timeout
		_shot("preview_%s_pause_settings.png" % prefix)
		ui.pause_menu.resume()

func _shot(filename: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://previews/%s" % filename)
	print("SCREENSHOT_SAVED: previews/", filename)

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
