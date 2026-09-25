extends CanvasLayer

## HUD (armed state, throttle, FPS, key hints) plus a live tuning panel for
## the drone's PID gains and FPV camera angle, toggled with O. Built in code
## rather than hand-laid-out in a .tscn since it's all data-driven sliders.

var _drone: Drone
var _root: Control
var _hud_label: Label
var _debug_label: Label
var _tuning_panel: PanelContainer
var _panel_visible: bool = true
var _prev_toggle_key: bool = false

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_hud_label = Label.new()
	_hud_label.position = Vector2(16, 16)
	_hud_label.add_theme_font_size_override("font_size", 16)
	_root.add_child(_hud_label)

	_debug_label = Label.new()
	_debug_label.position = Vector2(16, 430)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_root.add_child(_debug_label)

func set_drone(drone: Drone) -> void:
	_drone = drone
	_build_tuning_panel()

func _process(_delta: float) -> void:
	_handle_toggle()
	_update_hud()
	if _tuning_panel:
		_tuning_panel.visible = _panel_visible
	_debug_label.visible = _panel_visible
	if _panel_visible:
		_debug_label.text = InputManager.raw_axes_debug_text()

func _handle_toggle() -> void:
	var key := Input.is_key_pressed(KEY_O)
	if key and not _prev_toggle_key:
		_panel_visible = not _panel_visible
	_prev_toggle_key = key
	if Input.is_action_just_pressed("ui_cancel"):
		get_tree().quit()

func _update_hud() -> void:
	var armed_text := "ARMED" if InputManager.armed else "DISARMED"
	var throttle_pct := int(round(InputManager.get_throttle() * 100.0))
	var fps := Engine.get_frames_per_second()
	_hud_label.text = "%s   Throttle: %d%%   FPS: %d\n[Enter] Arm/Disarm   [R] Reset   [O] Tuning panel   [Esc] Quit\nKeyboard: A/D roll, W/S pitch, Q/E yaw, Shift/Ctrl throttle" % [armed_text, throttle_pct, fps]

func _build_tuning_panel() -> void:
	_tuning_panel = PanelContainer.new()
	_tuning_panel.position = Vector2(16, 100)
	_tuning_panel.custom_minimum_size = Vector2(300, 0)
	_root.add_child(_tuning_panel)

	var vbox := VBoxContainer.new()
	_tuning_panel.add_child(vbox)

	var title := Label.new()
	title.text = "PID & Camera Tuning (O to hide)"
	vbox.add_child(title)

	_add_slider(vbox, "Roll/Pitch Rate", 30.0, 800.0, 5.0, _drone.max_roll_pitch_rate_deg, func(v: float): _drone.max_roll_pitch_rate_deg = v)
	_add_slider(vbox, "Yaw Rate", 30.0, 500.0, 5.0, _drone.max_yaw_rate_deg, func(v: float): _drone.max_yaw_rate_deg = v)
	_add_slider(vbox, "Roll P", 0.0, 0.5, 0.002, _drone.roll_p, func(v: float): _drone.roll_p = v)
	_add_slider(vbox, "Roll I", 0.0, 0.2, 0.001, _drone.roll_i, func(v: float): _drone.roll_i = v)
	_add_slider(vbox, "Roll D", 0.0, 0.05, 0.0005, _drone.roll_d, func(v: float): _drone.roll_d = v)
	_add_slider(vbox, "Pitch P", 0.0, 0.5, 0.002, _drone.pitch_p, func(v: float): _drone.pitch_p = v)
	_add_slider(vbox, "Pitch I", 0.0, 0.2, 0.001, _drone.pitch_i, func(v: float): _drone.pitch_i = v)
	_add_slider(vbox, "Pitch D", 0.0, 0.05, 0.0005, _drone.pitch_d, func(v: float): _drone.pitch_d = v)
	_add_slider(vbox, "Yaw P", 0.0, 0.5, 0.002, _drone.yaw_p, func(v: float): _drone.yaw_p = v)
	_add_slider(vbox, "Yaw I", 0.0, 0.2, 0.001, _drone.yaw_i, func(v: float): _drone.yaw_i = v)
	_add_slider(vbox, "Yaw D", 0.0, 0.05, 0.0005, _drone.yaw_d, func(v: float): _drone.yaw_d = v)
	_add_slider(vbox, "Camera Angle", 0.0, 90.0, 1.0, _drone.camera_angle_deg, func(v: float): _drone.camera_angle_deg = v)
	_add_slider(vbox, "Camera FOV", 50.0, 150.0, 1.0, _drone.camera_fov_deg, func(v: float): _drone.camera_fov_deg = v)
	_add_slider(vbox, "Throttle Curve", 0.5, 3.0, 0.05, _drone.throttle_curve, func(v: float): _drone.throttle_curve = v)

func _add_slider(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, step: float, initial: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(90, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(140, 0)
	row.add_child(slider)

	var value_lbl := Label.new()
	value_lbl.text = str(snapped(initial, step))
	value_lbl.custom_minimum_size = Vector2(50, 0)
	row.add_child(value_lbl)

	slider.value_changed.connect(func(v: float):
		on_change.call(v)
		value_lbl.text = str(snapped(v, step))
	)
