class_name PauseMenu
extends CanvasLayer

## In-game menu: Esc while flying pauses the game (the whole scene tree -
## physics, drone, timers) and opens this card: camera angle and FOV
## (applied live to the frozen view behind the menu), switching drone,
## resetting it, Settings, and back to the main menu. Settings is the
## same SettingsScreens component the main menu uses; closed from here,
## it comes back to this card, not to the home screen.
##
## Runs with PROCESS_MODE_ALWAYS so it keeps working while the tree is
## paused.


var _drone: Drone
var _root: Control
var _card: Control
var _settings: SettingsScreens
var _drone_name: Label
var _drone_tags: Label
var _drone_locked: bool = false

func setup(drone: Drone) -> void:
	_drone = drone
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	# The school only allows the whoop (see main3.gd).
	var scene: Node = get_tree().current_scene
	_drone_locked = scene != null and MapCatalog.forced_drone(scene.scene_file_path) != ""

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.theme()
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(UIKit.BG, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	_card = _build_card()
	_settings = SettingsScreens.new()
	_root.add_child(_settings)
	_settings.closed.connect(_on_settings_closed)
	visible = false

func is_open() -> bool:
	return visible

func open() -> void:
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	visible = true
	_card.visible = true
	_refresh_drone_label()

func resume() -> void:
	_settings.visible = false
	visible = false
	get_tree().paused = false

func _unhandled_input(event: InputEvent) -> void:
	if not event.is_action_pressed("ui_cancel") or _drone == null:
		return
	# (While Settings is open it handles Esc itself, before this.)
	get_viewport().set_input_as_handled()
	if visible:
		resume()
	else:
		open()

func _build_card() -> Control:
	# Header: Main menu (Continue and Esc already resume - a "Back" there
	# was a third way to do the same thing).
	var parts: Array = UIKit.screen_card(_root, "Paused", "", 700, _to_main_menu, 760, "‹  Main menu", "Esc to continue")
	var content: VBoxContainer = parts[1]

	var cont := UIKit.button("Continue", "PrimaryButton", 60)
	cont.pressed.connect(resume)
	content.add_child(cont)
	UIKit.gap(content, 6)

	UIKit.section(content, "Camera")
	UIKit.slider(content, "Camera angle", 0.0, 60.0, 1.0, _drone.camera_angle_deg, func(v: float):
		Settings.camera_angle_deg = v
		_drone.camera_angle_deg = v
		_drone._apply_camera_settings(), "°")
	UIKit.slider(content, "Field of view (FOV)", 60.0, 140.0, 1.0, _drone.camera_fov_deg, func(v: float):
		Settings.camera_fov_deg = v
		_drone.camera_fov_deg = v
		_drone._apply_camera_settings(), "°")
	UIKit.gap(content, 6)

	UIKit.section(content, "Drone")
	var picker := HBoxContainer.new()
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	content.add_child(picker)
	var prev := UIKit.button("‹", "GhostButton", 56)
	prev.custom_minimum_size = Vector2(56, 56)
	prev.add_theme_font_size_override("font_size", 44)
	prev.set_meta("find_text", "pause_prev_drone")
	prev.pressed.connect(func(): _cycle_drone(-1))
	picker.add_child(prev)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.add_child(info)
	_drone_name = Label.new()
	_drone_name.theme_type_variation = "Heading"
	_drone_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_drone_name)
	_drone_tags = Label.new()
	_drone_tags.add_theme_color_override("font_color", UIKit.LINK)
	_drone_tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	info.add_child(_drone_tags)
	var next := UIKit.button("›", "GhostButton", 56)
	next.custom_minimum_size = Vector2(56, 56)
	next.add_theme_font_size_override("font_size", 44)
	next.set_meta("find_text", "pause_next_drone")
	next.pressed.connect(func(): _cycle_drone(1))
	picker.add_child(next)
	prev.disabled = _drone_locked
	next.disabled = _drone_locked
	UIKit.gap(content, 6)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	content.add_child(row)
	for spec in [["Reset drone", _reset_drone], ["Change map", _change_map], ["Settings", _open_settings]]:
		var b := UIKit.button(spec[0], "", 54)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		row.add_child(b)
	# The key hints live here now (the in-flight HUD is one status line).
	UIKit.gap(content, 4)
	var keys := Label.new()
	keys.text = "Enter arm/disarm   L acro/angle   R reset   V line of sight   O tuning panel   Esc pause\nKeyboard: A/D roll   W/S pitch   Q/E yaw   Shift/Ctrl throttle"
	keys.theme_type_variation = "Small"
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(keys)
	return parts[0]

func _refresh_drone_label() -> void:
	var d: Dictionary = Drone.PROFILES.get(Settings.selected_drone, Drone.PROFILES["seeker3"]).display
	_drone_name.text = d.name
	_drone_tags.text = ("This map is %s only" % d.name) if _drone_locked else Settings.spec_tags(d.tags)

## Swaps the frame in place (mass, thrust, drag, collision, model - see
## Drone.apply_profile) and puts it back on the spawn point, disarmed.
func _cycle_drone(step: int) -> void:
	if _drone_locked:
		return
	var order: Array[String] = Drone.PROFILE_ORDER
	var i: int = maxi(order.find(Settings.selected_drone), 0)
	Settings.selected_drone = order[posmod(i + step, order.size())]
	_drone.apply_profile(Settings.selected_drone)
	_drone.reset_to_spawn()
	InputManager.armed = false
	Settings.apply_graphics_settings() # camera clip distance + drone shadow size
	_refresh_drone_label()

func _reset_drone() -> void:
	_drone.reset_to_spawn()
	InputManager.armed = false
	resume()

func _open_settings() -> void:
	_card.visible = false
	_settings.open()

func _on_settings_closed() -> void:
	# Apply whatever changed: quality, shadows, performance mode, view
	# distance. (Rates are read live from Settings by the drone.)
	Settings.apply_graphics_settings()
	_card.visible = true

func _change_map() -> void:
	get_tree().paused = false
	MainMenu.start_screen = "map"
	SceneLoader.goto("res://scenes/MainMenu.tscn", "Choose a map")

func _to_main_menu() -> void:
	get_tree().paused = false
	SceneLoader.goto("res://scenes/MainMenu.tscn", "Main menu")
