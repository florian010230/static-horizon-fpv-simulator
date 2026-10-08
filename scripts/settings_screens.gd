class_name SettingsScreens
extends Control

## The Settings screen and its Calibrate Radio sub-screen, as one
## component both the main menu and the in-game pause menu open. It
## doesn't know where it was opened from: it just emits `closed` on
## Back/Esc and the caller shows whatever it came from - the home
## screen from the main menu, the pause menu from in-game.

signal closed

const FPS_MIN: int = 50
const FPS_MAX: int = 250 ## top of the slider means uncapped, not literally 250

## Each step asks the pilot to hold a stick at the extreme that should
## read as "positive" in this sim's own convention (right/forward/right/
## max - see InputManager's stick getters), so the sampled raw axis's
## sign alone tells the wizard whether that channel needs inverting - no
## need to ask a separate "does this feel backwards?" question afterward.
const CALIBRATION_STEPS: Array[Dictionary] = [
	{"label": "ROLL", "prompt": "Move ROLL fully RIGHT and hold it", "axis_field": "axis_roll", "invert_field": "invert_roll"},
	{"label": "PITCH", "prompt": "Push PITCH fully FORWARD (away from you) and hold it", "axis_field": "axis_pitch", "invert_field": "invert_pitch"},
	{"label": "YAW", "prompt": "Move YAW fully RIGHT and hold it", "axis_field": "axis_yaw", "invert_field": "invert_yaw"},
	{"label": "THROTTLE", "prompt": "Push THROTTLE fully UP and hold it", "axis_field": "axis_throttle", "invert_field": "invert_throttle"},
]

var _settings_screen: Control
var settings_tabs: TabContainer
var _device_picker: OptionButton
var _calibration_screen: Control
var _fps_value_label: Label
var _rate_curve: Control
var _radio_status: Label
var _calibration_step: int = 0
var _calibration_assigned_axes: Array[int] = []

func _ready() -> void:
	# (set_anchors_preset alone keeps the zero offsets of a fresh
	# Control - zero size, so the cards sat in the top-left corner.)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UIKit.theme()
	_settings_screen = _build_settings()
	_calibration_screen = _build_calibration()
	visible = false

func open() -> void:
	visible = true
	_refresh_devices()
	_show_settings()

func close() -> void:
	visible = false
	closed.emit()

func _show_settings() -> void:
	_settings_screen.visible = true
	_calibration_screen.visible = false

func _show_calibration() -> void:
	_settings_screen.visible = false
	_calibration_screen.visible = true

func _process(_delta: float) -> void:
	if not visible:
		return
	if _calibration_screen.visible:
		_process_calibration(_delta)
	elif _radio_status:
		_radio_status.text = _radio_status_text()
		_arm_hint_label.text = "Arm: %s, or Enter on the keyboard" % InputManager.arm_control_name()
		_refresh_assign_info()

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _calibration_screen.visible:
		_show_settings()
	else:
		close()

const CAMERA_HINTS: Array[String] = [
	"A perfect picture, no video link.",
	"Soft, colourful, noisy; fades into snow behind walls and far away. LQ in the OSD.",
	"Sharp HD with a little delay; blocky and frozen when the link gets weak. LQ in the OSD.",
	"Clean 720p, almost no delay; breaks up suddenly at the edge of range. LQ in the OSD.",
]
const TAB_NAMES: Array[String] = ["Graphics", "Camera & HUD", "Flight", "Rates", "Radio"]
const QUALITY_HINTS: Array[String] = [
	"Low: reduced resolution (on big and Retina screens the whole picture is drawn smaller and scaled up), small objects only drawn nearby. For older laptops and integrated graphics.",
	"Medium: reduced resolution on big and Retina screens, most details. For most laptops.",
	"High: full screen resolution, every detail, longest tree distance. For gaming PCs."]

func _build_settings() -> Control:
	var parts: Array = UIKit.screen_card(self, "Settings", "", 860, close, 1440)
	# One tab per topic, each a page of two columns (Rates: one wide
	# page). Every option has a one-line explanation under it.
	var tabs := TabContainer.new()
	settings_tabs = tabs
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	tabs.add_theme_stylebox_override("tab_selected", UIKit.box(UIKit.LOGO_SKY, UIKit.LOGO_SKY, 10, 1, Vector4(22, 8, 22, 8)))
	tabs.add_theme_stylebox_override("tab_unselected", UIKit.box(UIKit.BG, UIKit.BORDER, 10, 1, Vector4(22, 8, 22, 8)))
	tabs.add_theme_stylebox_override("tab_hovered", UIKit.box(UIKit.BOX_HOVER, UIKit.BORDER, 10, 1, Vector4(22, 8, 22, 8)))
	tabs.add_theme_font_override("font", UIKit.oswald())
	tabs.add_theme_font_size_override("font_size", 22)
	tabs.add_theme_color_override("font_selected_color", Color.WHITE)
	tabs.add_theme_color_override("font_unselected_color", UIKit.MUTED_LIGHT)
	tabs.add_theme_constant_override("side_margin", 0)
	parts[1].add_child(tabs)
	var pages: Array = []
	for title in TAB_NAMES:
		var page := HBoxContainer.new()
		page.name = title
		page.add_theme_constant_override("separation", 56)
		tabs.add_child(page)
		var cols_of_page: Array = []
		for k in range(1 if title == "Rates" else 2):
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 8)
			page.add_child(col)
			UIKit.gap(col, 10)
			cols_of_page.append(col)
		pages.append(cols_of_page)

	# Graphics
	var g1: VBoxContainer = pages[0][0]
	var g2: VBoxContainer = pages[0][1]
	UIKit.section(g1, "Quality")
	var quality_hint := _hint_label()
	_segmented(g1, "Graphics quality", Settings.QUALITY_NAMES, Settings.graphics_quality, func(i: int):
		Settings.graphics_quality = i
		quality_hint.text = QUALITY_HINTS[i])
	quality_hint.text = QUALITY_HINTS[clampi(Settings.graphics_quality, 0, 2)]
	g1.add_child(quality_hint)
	UIKit.gap(g1, 6)
	UIKit.slider(g1, "Render distance", Settings.VIEW_DISTANCE_MIN, Settings.VIEW_DISTANCE_MAX, 100.0, Settings.view_distance, func(v: float): Settings.view_distance = v, " m")
	_hint(g1, "How far the world is drawn before it fades into the haze. Shorter = more FPS.")
	UIKit.gap(g1, 6)
	UIKit.toggle(g1, "Sun shadows", Settings.shadows_enabled, func(v: bool): Settings.shadows_enabled = v)
	_hint(g1, "Real shadows from every building, tree and crane. Cheap - computed once per map.")
	UIKit.section(g2, "Screen")
	UIKit.toggle(g2, "Fullscreen", Settings.is_fullscreen(), func(v: bool): Settings.set_fullscreen(v))
	UIKit.gap(g2, 6)
	var fps_initial: float = clamp(Settings.max_fps if Settings.max_fps > 0 else FPS_MAX, FPS_MIN, FPS_MAX)
	_fps_value_label = UIKit.slider(g2, "Frame rate limit", FPS_MIN, FPS_MAX, 5, fps_initial, func(v: float):
		# The main menu stays capped at MENU_FPS and applies this when a
		# map loads; from the pause menu it applies at once.
		Settings.max_fps = 0 if int(v) >= FPS_MAX else int(v)
		var cur: Node = get_tree().current_scene
		if cur and not (cur is MainMenu):
			Settings.apply_fps_cap(Settings.max_fps)
		_fps_value_label.text = _fps_label_text(int(v))
	)
	_fps_value_label.text = _fps_label_text(int(fps_initial))
	_hint(g2, "Caps the FPS to save battery and heat. Far right = unlimited.")

	# Camera & HUD
	var c1: VBoxContainer = pages[1][0]
	var c2: VBoxContainer = pages[1][1]
	UIKit.section(c1, "FPV camera")
	UIKit.slider(c1, "Camera angle", 0.0, 60.0, 1.0, Settings.camera_angle_deg, func(v: float): Settings.camera_angle_deg = v, " deg")
	_hint(c1, "Uptilt. Freestyle 25-40 deg, racing 35-50, cinematic 10-20.")
	UIKit.slider(c1, "Field of view", 60.0, 140.0, 1.0, Settings.camera_fov_deg, func(v: float): Settings.camera_fov_deg = v, " deg")
	_hint(c1, "Wider shows more but makes speed look faster. Real FPV cams: ~120-150 deg diagonal.")
	UIKit.gap(c1, 6)
	_segmented(c1, "Lens", ["Flat", "Light fisheye", "Strong fisheye"], Settings.lens_fisheye, func(i: int): Settings.lens_fisheye = i)
	_hint(c1, "The barrel distortion of a real wide FPV lens: straight lines bend toward the edges. Costs a few FPS - Flat on a slow computer.")
	UIKit.gap(c1, 6)
	var cam_hint := _hint_label()
	_segmented(c1, "Camera", FpvVideo.LOOK_NAMES, Settings.camera_look, func(i: int):
		Settings.camera_look = i
		cam_hint.text = CAMERA_HINTS[i])
	cam_hint.text = CAMERA_HINTS[clampi(Settings.camera_look, 0, 3)]
	c1.add_child(cam_hint)
	UIKit.section(c2, "On screen")
	UIKit.toggle(c2, "OSD (throttle, altitude, speed, time)", Settings.osd_enabled, func(v: bool): Settings.osd_enabled = v)
	UIKit.toggle(c2, "Crosshair", Settings.crosshair_enabled, func(v: bool): Settings.crosshair_enabled = v)
	UIKit.toggle(c2, "Stick overlay", Settings.stick_overlay, func(v: bool): Settings.stick_overlay = v)
	_hint(c2, "Both sticks live at the bottom of the screen - see what your thumbs really do.")
	UIKit.gap(c2, 6)
	_segmented(c2, "Units", ["Metric (km/h, m)", "Imperial (mph, ft)"], Settings.units, func(i: int): Settings.units = i)

	# Flight
	var f1: VBoxContainer = pages[2][0]
	var f2: VBoxContainer = pages[2][1]
	UIKit.section(f1, "Realism")
	UIKit.toggle(f1, "Battery simulation", Settings.battery_enabled, func(v: bool): Settings.battery_enabled = v)
	_hint(f1, "A real pack per drone: it drains, sags under load and loses punch. The OSD shows volts and mAh, LOW BATTERY at 3.5 V per cell. R fits a fresh pack.")
	UIKit.toggle(f1, "Prop damage", Settings.prop_damage, func(v: bool): Settings.prop_damage = v)
	_hint(f1, "Hard crashes chip props: less thrust on that motor, vibration, a slight pull. R fits new props.")
	UIKit.gap(f1, 6)
	_segmented(f1, "Wind (outdoor maps)", Settings.WIND_NAMES, Settings.wind_level, func(i: int): Settings.wind_level = i)
	_hint(f1, "3 / 6 / 10 m/s at 10 m height, with gusts and turbulence. Calmer near the ground and in the lee of buildings.")
	UIKit.toggle(f1, "Prop wash", Settings.prop_wash, func(v: bool): Settings.prop_wash = v)
	_hint(f1, "Shaking and lost lift when you dive into your own downwash. Off: a clean catch every time.")
	UIKit.section(f2, "Race mode")
	UIKit.toggle(f2, "Ghost of your best lap", Settings.race_ghost, func(v: bool): Settings.race_ghost = v)
	UIKit.gap(f2, 6)
	UIKit.section(f2, "Physics")
	UIKit.toggle(f2, "Performance mode (240 Hz physics)", Settings.performance_mode, func(v: bool): Settings.performance_mode = v)
	_hint(f2, "A slightly crisper flight controller. Costs CPU - for strong PCs.")

	# Rates
	_build_rates(pages[3][0])

	# Radio
	var third: VBoxContainer = pages[4][0]
	_radio_help(pages[4][1])
	UIKit.section(third, "Radio")
	_radio_status = Label.new()
	_radio_status.theme_type_variation = "Muted"
	_radio_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_radio_status.text = _radio_status_text()
	third.add_child(_radio_status)
	var radio_row := VBoxContainer.new()
	radio_row.add_theme_constant_override("separation", 10)
	third.add_child(radio_row)
	var calibrate_btn := UIKit.button("Calibrate Radio", "PrimaryButton", 52)
	calibrate_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	calibrate_btn.pressed.connect(func(): _start_calibration(false))
	radio_row.add_child(calibrate_btn)
	var arm_btn := UIKit.button("Assign Arm Switch", "", 52)
	arm_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	arm_btn.pressed.connect(func(): _start_calibration(true))
	radio_row.add_child(arm_btn)
	_arm_hint_label = Label.new()
	_arm_hint_label.theme_type_variation = "Small"
	_arm_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	third.add_child(_arm_hint_label)
	UIKit.toggle(third, "Arm is a switch (off: each press toggles)", InputManager.arm_is_switch, func(v: bool):
		InputManager.arm_is_switch = v
		InputManager.save_calibration())

	UIKit.gap(third, 10)
	UIKit.section(third, "Other controls (optional)")
	_hint(third, "Assign a switch or button for any of these, or leave it unassigned and use the keyboard only.")
	_assign_row(third, "Assign Mode Switch", "mode", Callable(InputManager, "mode_control_name"), Callable(InputManager, "clear_mode_control"))
	_assign_row(third, "Assign Reset Button", "reset", Callable(InputManager, "reset_control_name"), Callable(InputManager, "clear_reset_control"))
	_assign_row(third, "Assign Line-of-Sight Button", "los", Callable(InputManager, "los_control_name"), Callable(InputManager, "clear_los_control"))
	_assign_row(third, "Assign Restart Switch", "restart", Callable(InputManager, "restart_control_name"), Callable(InputManager, "clear_restart_control"))
	_hint(third, "For everyday flying, use Reset: it puts the drone back, starts the race fresh and fits a new pack and props, all in an instant. Restart reloads the whole map (a few seconds) - only needed if something gets stuck.")

	UIKit.gap(third, 10)
	UIKit.section(third, "Controller")
	_device_picker = OptionButton.new()
	_device_picker.custom_minimum_size = Vector2(0, 44)
	_device_picker.item_selected.connect(func(i: int):
		InputManager.preferred_device_name = "" if i == 0 else _device_picker.get_item_text(i).trim_suffix(" (not connected)")
		InputManager.save_calibration())
	third.add_child(_device_picker)
	_refresh_devices()
	Input.joy_connection_changed.connect(func(_d: int, _c: bool): _refresh_devices())
	UIKit.slider(third, "Stick deadzone", 0.0, 10.0, 0.5, InputManager.deadzone * 100.0, func(v: float):
		InputManager.deadzone = v / 100.0
		InputManager.save_calibration(), " %")

	return parts[0]

func _hint_label() -> Label:
	var l := Label.new()
	l.theme_type_variation = "Small"
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", UIKit.MUTED_LIGHT)
	return l

func _hint(parent: Control, text: String) -> void:
	var l := _hint_label()
	l.text = text
	parent.add_child(l)

## One row in the Radio tab for an optional assignable control (mode/
## reset/los): an "Assign ..." button that runs the generalized capture
## step of the calibration wizard for `target`, a Clear button, and a
## line showing what's currently assigned - refreshed every frame the
## Settings screen is visible (see _process()).
func _assign_row(parent: Control, button_label: String, target: String, name_fn: Callable, clear_fn: Callable) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	parent.add_child(row)
	var btn := UIKit.button(button_label, "", 52)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(func(): _start_capture(target))
	row.add_child(btn)
	var clear_btn := UIKit.button("Clear", "GhostButton", 52)
	clear_btn.custom_minimum_size = Vector2(90, 52)
	clear_btn.pressed.connect(func():
		clear_fn.call()
		_refresh_assign_info())
	row.add_child(clear_btn)
	var info := _hint_label()
	parent.add_child(info)
	_assign_info.append({"label": info, "display": CAPTURE_LABELS[target], "name_fn": name_fn})
	_refresh_assign_info()

func _refresh_assign_info() -> void:
	for info in _assign_info:
		var label: Label = info.label
		label.text = "%s: %s" % [info.display, info.name_fn.call()]

# --- Rates (like Betaflight Configurator's PID Tuning -> Rates) ---------------

var _rate_rows: Array = [] # per axis: [SpinBox x3, max label]
var _rate_header: Array[Label] = []
var _rate_type_buttons: Array[Button] = []
var _rate_updating: bool = false

func _build_rates(parent: VBoxContainer) -> void:
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 40)
	parent.add_child(top)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	top.add_child(left)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(560, 0)
	right.add_theme_constant_override("separation", 8)
	top.add_child(right)

	_hint(left, "Same numbers as Betaflight Configurator -> PID Tuning -> Rates: copy them from your own quad and it flies the same here.")
	UIKit.gap(left, 4)
	var type_label := Label.new()
	type_label.text = "Rates type"
	left.add_child(type_label)
	var type_row := HBoxContainer.new()
	type_row.add_theme_constant_override("separation", 8)
	left.add_child(type_row)
	var group := ButtonGroup.new()
	for i in range(Rates.TYPE_NAMES.size()):
		var b := UIKit.button(Rates.TYPE_NAMES[i], "", 44)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == Settings.rates_type
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed", UIKit.box(UIKit.LOGO_SKY, UIKit.LOGO_SKY, 12))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		var t: int = i
		b.pressed.connect(func(): _set_rates_type(t))
		type_row.add_child(b)
		_rate_type_buttons.append(b)
	UIKit.gap(left, 8)

	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	left.add_child(grid)
	grid.add_child(Control.new())
	for k in range(3):
		var h := Label.new()
		h.theme_type_variation = "Small"
		h.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(h)
		_rate_header.append(h)
	var mh := Label.new()
	mh.text = "Max deg/s"
	mh.theme_type_variation = "Small"
	mh.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	grid.add_child(mh)
	for axis in range(3):
		var name_l := Label.new()
		name_l.text = Rates.AXIS_NAMES[axis]
		name_l.add_theme_color_override("font_color", AXIS_COLORS[axis])
		name_l.custom_minimum_size = Vector2(70, 0)
		grid.add_child(name_l)
		var row: Array = []
		for k in range(3):
			var sb := SpinBox.new()
			sb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			sb.custom_minimum_size = Vector2(130, 44)
			sb.alignment = HORIZONTAL_ALIGNMENT_CENTER
			sb.select_all_on_focus = true
			var ax: int = axis
			var col: int = k
			sb.value_changed.connect(func(v: float): _on_rate_value(ax, col, v))
			grid.add_child(sb)
			row.append(sb)
		var max_l := Label.new()
		max_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		max_l.custom_minimum_size = Vector2(110, 0)
		max_l.add_theme_color_override("font_color", UIKit.ACCENT)
		grid.add_child(max_l)
		row.append(max_l)
		_rate_rows.append(row)
	UIKit.gap(left, 10)
	var preset_row := HBoxContainer.new()
	preset_row.add_theme_constant_override("separation", 10)
	left.add_child(preset_row)
	var pl := Label.new()
	pl.text = "Presets"
	preset_row.add_child(pl)
	for pr in Rates.PRESETS:
		var b := UIKit.button(pr[0], "", 40)
		b.add_theme_font_size_override("font_size", 18)
		var preset: Array = pr
		b.pressed.connect(func():
			Settings.rates_type = preset[1]
			Settings.rates_roll = preset[2].duplicate()
			Settings.rates_pitch = preset[2].duplicate()
			Settings.rates_yaw = preset[3].duplicate()
			_refresh_rates())
		preset_row.add_child(b)
	var link := CheckButton.new()
	link.text = "Pitch follows roll"
	link.button_pressed = Settings.rates_roll == Settings.rates_pitch
	link.set_meta("rates_link", true)
	left.add_child(link)
	_rate_link = link
	_hint(left, "Tip: with \"Pitch follows roll\" on, editing roll sets pitch too, like most pilots fly.")

	UIKit.gap(left, 6)
	var thr_row := HBoxContainer.new()
	thr_row.add_theme_constant_override("separation", 30)
	left.add_child(thr_row)
	for spec in [["Throttle MID", "throttle_mid"], ["Throttle EXPO", "throttle_expo"]]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		thr_row.add_child(col)
		var field: String = spec[1]
		UIKit.slider(col, spec[0], 0.0, 1.0, 0.01, Settings.get(field), func(v: float): Settings.set(field, v))
	_hint(left, "Betaflight's throttle curve: EXPO flattens the throttle around MID for smoother hovering. Defaults 0.50 / 0.00.")

	var gl := Label.new()
	gl.text = "Rates preview - stick deflection to rotation rate"
	gl.theme_type_variation = "Small"
	right.add_child(gl)
	_rate_curve = Control.new()
	_rate_curve.custom_minimum_size = Vector2(0, 420)
	_rate_curve.draw.connect(func(): _draw_rate_curve(_rate_curve))
	right.add_child(_rate_curve)
	_refresh_rates()

var _rate_link: CheckButton
const AXIS_COLORS: Array[Color] = [Color("#e8551a"), Color("#3fae5a"), Color("#3ea6ff")]

func _set_rates_type(t: int) -> void:
	if t == Settings.rates_type:
		return
	for axis in range(3):
		Settings.set_rate_values(axis, Rates.convert(Settings.rates_type, Settings.rate_values(axis), t))
	Settings.rates_type = t
	_refresh_rates()

func _refresh_rates() -> void:
	_rate_updating = true
	var cols: Array = Rates.COLUMNS[Settings.rates_type]
	for k in range(3):
		_rate_header[k].text = cols[k][0]
	for i in range(_rate_type_buttons.size()):
		_rate_type_buttons[i].set_pressed_no_signal(i == Settings.rates_type)
	for axis in range(3):
		var v: Array = Settings.rate_values(axis)
		for k in range(3):
			var sb: SpinBox = _rate_rows[axis][k]
			sb.min_value = cols[k][1]
			sb.max_value = cols[k][2]
			sb.step = cols[k][3]
			sb.value = v[k]
		(_rate_rows[axis][3] as Label).text = "%d" % int(round(Rates.max_deg(Settings.rates_type, v)))
	_rate_updating = false
	if _rate_curve:
		_rate_curve.queue_redraw()

func _on_rate_value(axis: int, col: int, v: float) -> void:
	if _rate_updating:
		return
	var vals: Array = Settings.rate_values(axis).duplicate()
	vals[col] = v
	Settings.set_rate_values(axis, vals)
	if axis == 0 and _rate_link and _rate_link.button_pressed:
		Settings.set_rate_values(1, vals.duplicate())
	_refresh_rates()

## Radio tab, right column: how to connect, per radio family.
func _radio_help(parent: VBoxContainer) -> void:
	UIKit.gap(parent, 12)
	UIKit.section(parent, "Connecting your radio")
	for line in [
		"EdgeTX / OpenTX (RadioMaster, Jumper, FrSky, BetaFPV LiteRadio): plug in USB, choose \"USB Joystick (HID)\".",
		"TBS Tango / Mambo (FreedomTX or EdgeTX): same - USB, joystick mode.",
		"DJI FPV Remote Controller 2: connect by USB-C, it appears as a game controller.",
		"Gamepads (Xbox, PlayStation) work too - calibrate them the same way.",
		"Several controllers plugged in? The first one that moves is used, or pick one under Controller.",
		"Then Calibrate Radio once - it's remembered."]:
		var l := Label.new()
		l.text = "·  " + line
		l.theme_type_variation = "Muted"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(l)

## A row of mutually exclusive buttons with a label above.
func _segmented(parent: Control, label: String, options: Array, current: int, on_pick: Callable) -> void:
	var l := Label.new()
	l.text = label
	parent.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var group := ButtonGroup.new()
	for i in range(options.size()):
		var b := UIKit.button(options[i], "", 40)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == current
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed", UIKit.box(UIKit.LOGO_SKY, UIKit.LOGO_SKY, 12))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		var idx: int = i
		b.pressed.connect(func(): on_pick.call(idx))
		row.add_child(b)

## "Automatic" plus every connected controller by name.
func _refresh_devices() -> void:
	if _device_picker == null:
		return
	_device_picker.clear()
	_device_picker.add_item("Automatic - the first controller that moves")
	var names: Array[String] = InputManager.device_names()
	for n in names:
		_device_picker.add_item(n)
	var pref: String = InputManager.preferred_device_name
	if pref != "" and not names.has(pref):
		_device_picker.add_item(pref + " (not connected)")
	_device_picker.select(0)
	for i in range(1, _device_picker.item_count):
		if _device_picker.get_item_text(i).begins_with(pref) and pref != "":
			_device_picker.select(i)

func _radio_status_text() -> String:
	match InputManager.radio_status():
		"active":
			return "Connected: %s" % InputManager.joy_name()
		"silent":
			return "%s is plugged in but not sending data - switch it on / choose USB Joystick mode. Flying with the keyboard meanwhile." % InputManager.joy_name()
	return "No radio detected - flying with the keyboard. Plug in your radio in USB joystick mode."

func _fps_label_text(v: int) -> String:
	return "Unlimited" if v >= FPS_MAX else str(v)

## Styled after Betaflight Configurator's own rates preview: a dark
## plot from stick deflection to rotation rate, one curve per axis
## (roll orange, pitch green, yaw blue), computed with the same Rates
## functions the drone flies with.
func _draw_rate_curve(c: Control) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	c.draw_style_box(UIKit.box(UIKit.BG, UIKit.BORDER, 12), Rect2(0, 0, w, h))
	var pad_left := 56.0
	var pad_bottom := 30.0
	var pad_top := 18.0
	var pad_right := 18.0
	var plot_pos := Vector2(pad_left, pad_top)
	var plot_size := Vector2(w - pad_left - pad_right, h - pad_top - pad_bottom)
	var plot_end: Vector2 = plot_pos + plot_size
	var top: float = 200.0
	for axis in range(3):
		top = maxf(top, Rates.max_deg(Settings.rates_type, Settings.rate_values(axis)))
	top = ceilf(top / 200.0) * 200.0
	var font: Font = ThemeDB.fallback_font
	for i in range(0, int(top) + 1, 200):
		var gy: float = plot_end.y - plot_size.y * i / top
		c.draw_line(Vector2(plot_pos.x, gy), Vector2(plot_end.x, gy), Color(1, 1, 1, 0.06), 1.0)
		c.draw_string(font, Vector2(6, gy + 5), "%d" % i, HORIZONTAL_ALIGNMENT_RIGHT, pad_left - 12, 14, UIKit.MUTED_LIGHT)
	for i in range(1, 4):
		var gx: float = plot_pos.x + plot_size.x * i / 4.0
		c.draw_line(Vector2(gx, plot_pos.y), Vector2(gx, plot_end.y), Color(1, 1, 1, 0.06), 1.0)
	c.draw_line(Vector2(plot_pos.x, plot_end.y), Vector2(plot_end.x, plot_end.y), UIKit.BORDER, 1.0)
	c.draw_line(Vector2(plot_pos.x, plot_pos.y), Vector2(plot_pos.x, plot_end.y), UIKit.BORDER, 1.0)
	for axis in [2, 1, 0]:
		var points := PackedVector2Array()
		for i in range(65):
			var stick: float = i / 64.0
			var deg: float = Rates.rate_deg(Settings.rates_type, Settings.rate_values(axis), stick)
			points.append(Vector2(plot_pos.x + stick * plot_size.x, plot_end.y - clampf(deg / top, 0.0, 1.0) * plot_size.y))
		c.draw_polyline(points, AXIS_COLORS[axis], 3.0, true)
	c.draw_string(font, Vector2(plot_pos.x, plot_end.y + 22), "0% stick", HORIZONTAL_ALIGNMENT_LEFT, 90, 14, UIKit.MUTED_LIGHT)
	c.draw_string(font, Vector2(plot_end.x - 120, plot_end.y + 22), "100% stick", HORIZONTAL_ALIGNMENT_RIGHT, 120, 14, UIKit.MUTED_LIGHT)
	c.draw_string(font, Vector2(plot_pos.x + 10, plot_pos.y + 16), "deg/s", HORIZONTAL_ALIGNMENT_LEFT, 80, 14, UIKit.MUTED_LIGHT)

# --- Radio calibration wizard ------------------------------------------------

## A guided wizard with a live view of the radio. First it records where
## every stick rests; then each stick step asks the pilot to hold one
## channel at the extreme that should read "positive" here, and the
## wizard works out both which raw axis that is AND whether it needs
## inverting from the sampled sign alone (see CALIBRATION_STEPS). Stick
## steps accept themselves once a stick has been held out for HOLD_TIME -
## no reaching for the mouse with both hands on the radio. Then the arm
## switch (flip on, flip off), then a test view that shows the sticks
## and the arm switch exactly as the sim now reads them.
##
## Steps: REST(-1), sticks (0..3), ARM (4), TEST (5). STEP_CAPTURE (6) is
## a separate, single-step flow (not part of the REST->sticks->Arm->Test
## sequence): it's where the Radio tab's "Assign Mode/Reset/Line-of-Sight"
## buttons land, sharing the arm step's own "something changed from
## baseline, now flip it back off" detection (see _detect_candidate()/
## _confirm_candidate(), used by both _process_arm_step() and
## _process_capture_step()).
const STEP_ARM: int = 4
const STEP_TEST: int = 5
const STEP_CAPTURE: int = 6
const HOLD_TIME: float = 0.7
const HOLD_DEFLECTION: float = 0.7
const STEP_NAMES: Array[String] = ["Rest", "Roll", "Pitch", "Yaw", "Throttle", "Arm", "Test"]
## Display names for the three optional controls, keyed the same way as
## InputManager's "<prefix>_*" fields - used for both the wizard's
## STEP_CAPTURE prompt and the Radio tab's assigned-control lines.
const CAPTURE_LABELS: Dictionary = {
	"mode": "Flight Mode",
	"reset": "Reset",
	"los": "Line-of-Sight",
	"restart": "Restart Map",
}

var _cal_title: Label
var _cal_hint: Label
var _cal_viz: Control
var _cal_next: Button
var _cal_skip: Button
var _cal_progress: HBoxContainer
var _hold_axis: int = -1
var _hold_time: float = 0.0
var _arm_only: bool = false
var _arm_base_axes: Array[float] = []
var _arm_base_buttons: Array[bool] = []
var _arm_candidate: Dictionary = {} ## detected control, waiting for "flip back off"
var _arm_hint_label: Label
## Which optional control (if any) a standalone "Assign ..." button in
## the Radio tab is currently capturing ("" when not in that flow - the
## full Calibrate Radio sequence and the arm-only re-assign both leave
## this "", and keep using _arm_only/_arm_candidate as before).
var _capture_only: String = ""
var _capture_target: String = ""
var _capture_base_axes: Array[float] = []
var _capture_base_buttons: Array[bool] = []
var _capture_candidate: Dictionary = {}
## [{"label": Label, "display": String, "name_fn": Callable}] - one per
## optional control's line in the Radio tab, refreshed every frame the
## Settings screen is visible (see _process()).
var _assign_info: Array = []

func _build_calibration() -> Control:
	var parts: Array = UIKit.screen_card(self, "Calibrate Radio", "", 760, _show_settings, 980)
	var content: VBoxContainer = parts[1]
	content.add_theme_constant_override("separation", 10)
	_cal_progress = HBoxContainer.new()
	_cal_progress.add_theme_constant_override("separation", 8)
	content.add_child(_cal_progress)
	_cal_title = Label.new()
	_cal_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cal_title.add_theme_font_override("font", UIKit.oswald())
	_cal_title.add_theme_font_size_override("font_size", 30)
	content.add_child(_cal_title)
	_cal_hint = Label.new()
	_cal_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_cal_hint.theme_type_variation = "Muted"
	_cal_hint.custom_minimum_size = Vector2(0, 52)
	content.add_child(_cal_hint)
	_cal_viz = Control.new()
	_cal_viz.custom_minimum_size = Vector2(0, 360)
	_cal_viz.draw.connect(_draw_calibration)
	content.add_child(_cal_viz)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	content.add_child(row)
	var restart := UIKit.button("Start over", "GhostButton", 56)
	restart.custom_minimum_size = Vector2(170, 56)
	restart.pressed.connect(_restart_current)
	row.add_child(restart)
	_cal_skip = UIKit.button("Skip (keep current)", "GhostButton", 56)
	_cal_skip.custom_minimum_size = Vector2(230, 56)
	_cal_skip.pressed.connect(_skip_arm_step)
	row.add_child(_cal_skip)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	_cal_next = UIKit.button("Next", "PrimaryButton", 56)
	_cal_next.custom_minimum_size = Vector2(220, 56)
	_cal_next.pressed.connect(_on_calibration_next)
	row.add_child(_cal_next)
	return parts[0]

## arm_only: Settings -> "Assign arm switch" - just the ARM step (and the
## test view), the stick calibration stays as it is.
func _start_calibration(arm_only: bool = false) -> void:
	_arm_only = arm_only
	_capture_only = ""
	_calibration_assigned_axes.clear()
	_hold_axis = -1
	_hold_time = 0.0
	_show_calibration()
	if arm_only:
		_enter_arm_step()
	else:
		_calibration_step = -1
	_update_calibration_step()

## Settings -> "Assign Mode/Reset/Line-of-Sight ...": the same
## single-step, no-sticks flow as arm_only above, generalized to any of
## the three optional controls (see InputManager's "<prefix>_*" fields).
func _start_capture(target: String) -> void:
	_arm_only = false
	_capture_only = target
	_calibration_assigned_axes.clear()
	_hold_axis = -1
	_hold_time = 0.0
	_show_calibration()
	_enter_capture_step(target)
	_update_calibration_step()

## "Start over" in the wizard: redo whichever flow is currently active.
func _restart_current() -> void:
	if _capture_only != "":
		_start_capture(_capture_only)
	else:
		_start_calibration(_arm_only)

func _enter_arm_step() -> void:
	_calibration_step = STEP_ARM
	_arm_candidate = {}
	_arm_base_axes.clear()
	_arm_base_buttons.clear()
	for i in range(InputManager.AXES):
		_arm_base_axes.append(InputManager.joy_axis(i) if InputManager.has_joystick() else 0.0)
	for b in range(InputManager.BUTTONS):
		_arm_base_buttons.append(InputManager.joy_button(b) if InputManager.has_joystick() else false)

func _enter_capture_step(target: String) -> void:
	_calibration_step = STEP_CAPTURE
	_capture_target = target
	_capture_candidate = {}
	_capture_base_axes.clear()
	_capture_base_buttons.clear()
	for i in range(InputManager.AXES):
		_capture_base_axes.append(InputManager.joy_axis(i) if InputManager.has_joystick() else 0.0)
	for b in range(InputManager.BUTTONS):
		_capture_base_buttons.append(InputManager.joy_button(b) if InputManager.has_joystick() else false)

func _stick_axes() -> Array[int]:
	return [InputManager.axis_roll, InputManager.axis_pitch, InputManager.axis_yaw, InputManager.axis_throttle]

func _pill(text: String, done: bool, cur: bool) -> PanelContainer:
	var pill := PanelContainer.new()
	var bg: Color = UIKit.LOGO_SKY if done else (UIKit.LOGO_GROUND if cur else UIKit.BG)
	pill.add_theme_stylebox_override("panel", UIKit.box(bg, bg if (done or cur) else UIKit.BORDER, 999, 1, Vector4(14, 4, 14, 4)))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", Color.WHITE if (done or cur) else UIKit.MUTED_LIGHT)
	pill.add_child(l)
	return pill

func _update_calibration_step() -> void:
	for c in _cal_progress.get_children():
		c.queue_free()
	if _capture_only != "":
		# Standalone "Assign Mode/Reset/Line-of-Sight": just two pills,
		# the capture itself and the shared test view.
		_cal_progress.add_child(_pill("1  %s" % CAPTURE_LABELS[_capture_only], _calibration_step == STEP_TEST, _calibration_step == STEP_CAPTURE))
		_cal_progress.add_child(_pill("2  Test", false, _calibration_step == STEP_TEST))
	else:
		var first: int = STEP_ARM if _arm_only else -1
		for st in range(first, STEP_TEST + 1):
			_cal_progress.add_child(_pill("%d  %s" % [st - first + 1, STEP_NAMES[st + 1]], st < _calibration_step, st == _calibration_step))
	_cal_skip.visible = _calibration_step == STEP_ARM or _calibration_step == STEP_CAPTURE
	_cal_next.visible = _calibration_step < 0 or _calibration_step == STEP_TEST or not InputManager.has_joystick()
	_cal_next.text = "Done" if _calibration_step == STEP_TEST else "Next"
	if not InputManager.has_joystick():
		_cal_title.text = "No radio detected"
		_cal_hint.text = "Plug in your radio and set it to USB Joystick mode (EdgeTX: choose \"USB Joystick (HID)\" when connecting), then press Next."
		return
	if _calibration_step < 0:
		_cal_title.text = "Let go of the sticks, throttle fully down"
		_cal_hint.text = "Roll, pitch and yaw spring back to center; pull the throttle all the way down. Put all switches in their OFF position. Then press Next."
	elif _calibration_step < CALIBRATION_STEPS.size():
		var step: Dictionary = CALIBRATION_STEPS[_calibration_step]
		_cal_title.text = step.prompt
		_cal_hint.text = "The wizard finds the channel on its own - keep it there until the bar fills."
	elif _calibration_step == STEP_ARM:
		_cal_title.text = "Flip the switch you want to ARM with"
		_cal_hint.text = "Any switch or button on the radio. Currently: %s. Enter on the keyboard always works too." % InputManager.arm_control_name()
	elif _calibration_step == STEP_CAPTURE:
		_cal_title.text = "Flip the switch you want for %s" % CAPTURE_LABELS[_capture_only]
		_cal_hint.text = "Any switch or button on the radio (or press Esc to skip). Currently: %s." % _current_capture_name()
	else:
		_cal_title.text = "All set - try it"
		_cal_hint.text = "This is exactly what the sim reads now. Flip the arm switch to check it. Saved - it stays calibrated after a restart."

## The current assignment of whichever optional control the Radio tab's
## "Assign ..." button is capturing - used for the STEP_CAPTURE hint
## above.
func _current_capture_name() -> String:
	match _capture_only:
		"mode": return InputManager.mode_control_name()
		"reset": return InputManager.reset_control_name()
		"los": return InputManager.los_control_name()
		"restart": return InputManager.restart_control_name()
	return "not assigned"

func _process_calibration(delta: float) -> void:
	_cal_viz.queue_redraw()
	if not InputManager.has_joystick():
		return
	if _calibration_step >= 0 and _calibration_step < CALIBRATION_STEPS.size():
		var sample: Dictionary = InputManager.strongest_axis(_calibration_assigned_axes, HOLD_DEFLECTION)
		if sample.is_empty():
			_hold_axis = -1
			_hold_time = 0.0
			return
		if sample.axis != _hold_axis:
			_hold_axis = sample.axis
			_hold_time = 0.0
		_hold_time += delta
		if _hold_time >= HOLD_TIME:
			_accept_stick(sample)
	elif _calibration_step == STEP_ARM:
		_process_arm_step()
	elif _calibration_step == STEP_CAPTURE:
		_process_capture_step()

func _accept_stick(sample: Dictionary) -> void:
	var step: Dictionary = CALIBRATION_STEPS[_calibration_step]
	_calibration_assigned_axes.append(sample.axis)
	InputManager.set(step.axis_field, sample.axis)
	if step.axis_field == "axis_throttle":
		# Throttle gets real end points instead of an invert flag: its
		# rest reading (captured with the stick down) is the low end,
		# this held reading the high end - direction included.
		InputManager.throttle_raw_low = InputManager.axis_rest[sample.axis]
		InputManager.throttle_raw_high = sample.raw
		InputManager.throttle_calibrated = true
		InputManager.invert_throttle = false
	else:
		InputManager.set(step.invert_field, sample.value < 0.0)
	_hold_axis = -1
	_hold_time = 0.0
	if _calibration_step + 1 == STEP_ARM:
		_enter_arm_step()
	else:
		_calibration_step += 1
	_update_calibration_step()

## Shared by the arm step and the generalized capture step: anything
## that changes from its state when the step began - a button, or an
## axis that isn't one of the four sticks - is the candidate; the
## caller then waits for it to flip back off to confirm it (and tell a
## real switch from a stick being bumped). Empty while nothing's
## changed yet.
func _detect_candidate(base_axes: Array[float], base_buttons: Array[bool]) -> Dictionary:
	for b in range(InputManager.BUTTONS):
		if InputManager.joy_button(b) != base_buttons[b]:
			return {"source": "button", "index": b, "off": base_buttons[b]}
	var exclude := _stick_axes()
	for i in range(InputManager.AXES):
		if i in exclude:
			continue
		var v: float = InputManager.joy_axis(i)
		if absf(v - base_axes[i]) > 0.5:
			return {"source": "axis", "index": i, "off": base_axes[i], "on": v}
	return {}

## Checks a candidate dict (as returned by _detect_candidate) against
## the radio right now: "" while still waiting for the flip-back-off,
## else "button" or "axis" once confirmed. For an axis, `candidate` is
## mutated in place to track a still-travelling 3-position switch.
func _confirm_candidate(candidate: Dictionary) -> String:
	if candidate.source == "button":
		return "button" if InputManager.joy_button(candidate.index) == candidate.off else ""
	var v: float = InputManager.joy_axis(candidate.index)
	if absf(v - candidate.off) < 0.25:
		return "axis"
	if absf(v - candidate.off) > absf(candidate.on - candidate.off):
		candidate.on = v
	return ""

func _candidate_name(candidate: Dictionary) -> String:
	return ("button %d" if candidate.source == "button" else "switch on axis %d") % candidate.index

## Arm step: see _detect_candidate()/_confirm_candidate() above.
func _process_arm_step() -> void:
	if _arm_candidate.is_empty():
		_arm_candidate = _detect_candidate(_arm_base_axes, _arm_base_buttons)
		if not _arm_candidate.is_empty():
			_cal_title.text = "Got it - now flip it back OFF"
			_cal_hint.text = "Detected %s." % _candidate_name(_arm_candidate)
		return
	var confirmed := _confirm_candidate(_arm_candidate)
	if confirmed == "button":
		# A button that reads pressed with the switch OFF is simply an
		# inverted switch.
		InputManager.arm_button_on_when_pressed = not _arm_candidate.off
		InputManager.arm_source = "button"
		InputManager.arm_button_index = _arm_candidate.index
		_finish_arm_step()
	elif confirmed == "axis":
		InputManager.arm_source = "axis"
		InputManager.arm_axis = _arm_candidate.index
		InputManager.arm_axis_off_value = _arm_candidate.off
		InputManager.arm_axis_on_value = _arm_candidate.on
		_finish_arm_step()

## The generalized version of _process_arm_step(), for the Radio tab's
## "Assign Mode/Reset/Line-of-Sight" buttons - same detection, writing
## to InputManager's "<_capture_target>_*" fields instead of arm_*.
func _process_capture_step() -> void:
	if _capture_candidate.is_empty():
		_capture_candidate = _detect_candidate(_capture_base_axes, _capture_base_buttons)
		if not _capture_candidate.is_empty():
			_cal_title.text = "Got it - now flip it back OFF"
			_cal_hint.text = "Detected %s." % _candidate_name(_capture_candidate)
		return
	var confirmed := _confirm_candidate(_capture_candidate)
	if confirmed == "button":
		InputManager.set(_capture_target + "_source", "button")
		InputManager.set(_capture_target + "_button_index", _capture_candidate.index)
		InputManager.set(_capture_target + "_button_on_when_pressed", not _capture_candidate.off)
		_finish_capture_step()
	elif confirmed == "axis":
		InputManager.set(_capture_target + "_source", "axis")
		InputManager.set(_capture_target + "_axis", _capture_candidate.index)
		InputManager.set(_capture_target + "_axis_off_value", _capture_candidate.off)
		InputManager.set(_capture_target + "_axis_on_value", _capture_candidate.on)
		_finish_capture_step()

func _finish_arm_step() -> void:
	InputManager.save_calibration()
	# Don't let the fresh assignment arm the drone on the next flip-on in
	# the menu: the next reading re-latches the switch state.
	InputManager._arm_switch_seen = false
	_calibration_step = STEP_TEST
	_update_calibration_step()

func _finish_capture_step() -> void:
	InputManager.save_calibration()
	_calibration_step = STEP_TEST
	_update_calibration_step()

## Shared by the arm step's and the capture step's "Skip" button - both
## just keep whatever was already assigned and move to the test view.
func _skip_arm_step() -> void:
	InputManager.save_calibration()
	_calibration_step = STEP_TEST
	_update_calibration_step()

func _on_calibration_next() -> void:
	if not InputManager.has_joystick():
		_update_calibration_step()
		return
	if _calibration_step < 0:
		InputManager.capture_rest()
		_calibration_step = 0
		_update_calibration_step()
	elif _calibration_step == STEP_TEST:
		_show_settings()

## The live view: every raw axis as a bar (rest point marked, assigned
## channels labelled, the one being held highlighted and filling up), and
## - on the test step - the two gimbals and the arm switch as the sim
## reads them.
func _draw_calibration() -> void:
	var c: Control = _cal_viz
	var w: float = c.size.x
	var h: float = c.size.y
	c.draw_style_box(UIKit.box(UIKit.BG, UIKit.BORDER, 12), Rect2(0, 0, w, h))
	var font: Font = UIKit.oswald()
	if not InputManager.has_joystick():
		c.draw_string(font, Vector2(0, h * 0.5 + 8), "Waiting for a radio...", HORIZONTAL_ALIGNMENT_CENTER, w, 22, UIKit.MUTED_LIGHT)
		return
	if _calibration_step == STEP_TEST:
		_draw_test_view(c, font, w, h)
		return
	var names := {}
	if _calibration_step >= 0:
		names[InputManager.axis_roll if _calibration_step > 0 else -9] = "ROLL"
		names[InputManager.axis_pitch if _calibration_step > 1 else -9] = "PITCH"
		names[InputManager.axis_yaw if _calibration_step > 2 else -9] = "YAW"
		names[InputManager.axis_throttle if _calibration_step > 3 else -9] = "THROTTLE"
	var top: float = 22.0
	var row_h: float = (h - 2.0 * top - 16.0) / float(InputManager.AXES)
	var bar_x: float = 190.0
	var bar_w: float = w - bar_x - 90.0
	for i in range(InputManager.AXES):
		var y: float = top + i * row_h + row_h * 0.5
		var raw: float = InputManager.joy_axis(i)
		var rest: float = InputManager.axis_rest[i] if _calibration_step >= 0 else 0.0
		var held: bool = i == _hold_axis
		# Highlights the axis a "flip the switch" step (arm, or the
		## generalized mode/reset/los capture) is currently watching.
		var is_candidate: bool = (_calibration_step == STEP_ARM and not _arm_candidate.is_empty() and _arm_candidate.source == "axis" and _arm_candidate.index == i) \
			or (_calibration_step == STEP_CAPTURE and not _capture_candidate.is_empty() and _capture_candidate.source == "axis" and _capture_candidate.index == i)
		var label: String = "Axis %d" % i
		if names.has(i):
			label += "  " + names[i]
		var col: Color = UIKit.LOGO_GROUND if (held or is_candidate) else (UIKit.ACCENT if names.has(i) else UIKit.MUTED_LIGHT)
		c.draw_string(font, Vector2(24, y + 7), label, HORIZONTAL_ALIGNMENT_LEFT, bar_x - 30, 18, col)
		var track := Rect2(bar_x, y - 7, bar_w, 14)
		c.draw_rect(track, Color(1, 1, 1, 0.06))
		var cx: float = bar_x + bar_w * 0.5
		var px: float = bar_x + (raw + 1.0) * 0.5 * bar_w
		c.draw_rect(Rect2(minf(cx, px), y - 7, absf(px - cx), 14), col if (held or is_candidate or names.has(i)) else Color(UIKit.MUTED_LIGHT, 0.5))
		var rx: float = bar_x + (rest + 1.0) * 0.5 * bar_w
		c.draw_line(Vector2(rx, y - 11), Vector2(rx, y + 11), Color.WHITE, 2.0)
		c.draw_string(font, Vector2(bar_x + bar_w + 12, y + 7), "%+.2f" % raw, HORIZONTAL_ALIGNMENT_LEFT, 70, 16, UIKit.MUTED_LIGHT)
		if held:
			var f: float = clampf(_hold_time / HOLD_TIME, 0.0, 1.0)
			c.draw_rect(Rect2(bar_x, y + 9, bar_w * f, 4), UIKit.LOGO_GROUND)
	if _calibration_step == STEP_ARM or _calibration_step == STEP_CAPTURE:
		var btns: Array[String] = []
		for b in range(InputManager.BUTTONS):
			if InputManager.joy_button(b):
				btns.append(str(b))
		c.draw_string(font, Vector2(24, h - 6), "Buttons pressed: " + (", ".join(btns) if btns.size() > 0 else "none"), HORIZONTAL_ALIGNMENT_LEFT, w - 48, 16, UIKit.LOGO_GROUND if btns.size() > 0 else UIKit.MUTED_LIGHT)

func _draw_test_view(c: Control, font: Font, w: float, h: float) -> void:
	# Mode 2: left gimbal = yaw (x) / throttle (y), right = roll / pitch.
	var size: float = minf(h - 70.0, 240.0)
	var gap_x: float = (w - 2.0 * size - 200.0) / 4.0
	var left := Rect2(gap_x, 24, size, size)
	var right := Rect2(gap_x * 2.0 + size, 24, size, size)
	_draw_gimbal(c, font, left, InputManager.get_yaw(), InputManager.get_throttle() * 2.0 - 1.0, "YAW / THROTTLE %d%%" % int(round(InputManager.get_throttle() * 100.0)))
	_draw_gimbal(c, font, right, InputManager.get_roll(), InputManager.get_pitch(), "ROLL / PITCH")
	var on: bool = InputManager.arm_switch_on()
	var ax: float = gap_x * 3.0 + size * 2.0
	var pill := Rect2(ax, 24 + size * 0.5 - 40, 200, 80)
	c.draw_style_box(UIKit.box(UIKit.LOGO_GROUND if on else UIKit.BOX, UIKit.LOGO_GROUND if on else UIKit.BORDER, 16), pill)
	c.draw_string(font, Vector2(ax, pill.position.y + 50), "ARM ON" if on else "ARM OFF", HORIZONTAL_ALIGNMENT_CENTER, 200, 28, Color.WHITE)
	c.draw_string(font, Vector2(ax, pill.end.y + 26), InputManager.arm_control_name(), HORIZONTAL_ALIGNMENT_CENTER, 200, 14, UIKit.MUTED_LIGHT)

func _draw_gimbal(c: Control, font: Font, r: Rect2, x: float, y: float, label: String) -> void:
	c.draw_style_box(UIKit.box(UIKit.BOX, UIKit.BORDER, 16), r)
	var ctr: Vector2 = r.get_center()
	c.draw_line(Vector2(r.position.x + 12, ctr.y), Vector2(r.end.x - 12, ctr.y), Color(1, 1, 1, 0.08), 1.0)
	c.draw_line(Vector2(ctr.x, r.position.y + 12), Vector2(ctr.x, r.end.y - 12), Color(1, 1, 1, 0.08), 1.0)
	var half: float = r.size.x * 0.5 - 20.0
	var p: Vector2 = ctr + Vector2(clampf(x, -1, 1), -clampf(y, -1, 1)) * half
	c.draw_line(ctr, p, Color(UIKit.LOGO_SKY, 0.7), 3.0)
	c.draw_circle(p, 13.0, UIKit.LOGO_SKY)
	c.draw_circle(p, 5.0, Color.WHITE)
	c.draw_string(font, Vector2(r.position.x, r.end.y + 26), label, HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, UIKit.MUTED_LIGHT)
