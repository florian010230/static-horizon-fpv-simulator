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

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if _calibration_screen.visible:
		_show_settings()
	else:
		close()

func _build_settings() -> Control:
	var parts: Array = UIKit.screen_card(self, "Settings", "", 820, close, 1440)
	# Three tabs (it outgrew one screen): Display, Flight, Radio - each a
	# page of two columns.
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
	for title in ["Display", "Flight", "Radio"]:
		var page := HBoxContainer.new()
		page.name = title
		page.add_theme_constant_override("separation", 56)
		tabs.add_child(page)
		var cols_of_page: Array = []
		for k in range(2):
			var col := VBoxContainer.new()
			col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			col.add_theme_constant_override("separation", 10)
			page.add_child(col)
			cols_of_page.append(col)
		pages.append(cols_of_page)
	var left: VBoxContainer = pages[0][0]
	var left2: VBoxContainer = pages[0][1]
	var right: VBoxContainer = pages[1][0]
	var phys: VBoxContainer = pages[1][1]
	var third: VBoxContainer = pages[2][0]
	_radio_help(pages[2][1])
	UIKit.gap(left, 12)
	UIKit.gap(left2, 12)
	UIKit.gap(right, 12)
	UIKit.gap(phys, 12)
	UIKit.gap(third, 12)
	UIKit.section(left, "Display")
	UIKit.toggle(left, "Fullscreen", Settings.is_fullscreen(), func(v: bool): Settings.set_fullscreen(v))
	UIKit.toggle(left, "Crosshair", Settings.crosshair_enabled, func(v: bool): Settings.crosshair_enabled = v)
	UIKit.toggle(left, "OSD (throttle, altitude, speed, time)", Settings.osd_enabled, func(v: bool): Settings.osd_enabled = v)
	_segmented(left, "Units", ["Metric (km/h, m)", "Imperial (mph, ft)"], Settings.units, func(i: int): Settings.units = i)
	_segmented(left, "Analog video look", ["Off", "Light", "Strong"], Settings.video_effect, func(i: int): Settings.video_effect = i)
	UIKit.toggle(left, "Shadows (costs performance)", Settings.shadows_enabled, func(v: bool): Settings.shadows_enabled = v)
	UIKit.section(left2, "Performance")
	_add_quality_picker(left2)
	UIKit.gap(left2, 6)
	var fps_initial: float = clamp(Settings.max_fps if Settings.max_fps > 0 else FPS_MAX, FPS_MIN, FPS_MAX)
	_fps_value_label = UIKit.slider(left2, "Max FPS", FPS_MIN, FPS_MAX, 5, fps_initial, func(v: float):
		# Stored now, applied when a map loads - the menu itself stays
		# capped at MENU_FPS (see _ready).
		Settings.max_fps = 0 if int(v) >= FPS_MAX else int(v)
		_fps_value_label.text = _fps_label_text(int(v))
	)
	_fps_value_label.text = _fps_label_text(int(fps_initial))


	UIKit.section(right, "Acro Rates")
	UIKit.slider(right, "Center Sensitivity", 10.0, 200.0, 5.0, Settings.rate_center_sensitivity_deg, func(v: float):
		Settings.rate_center_sensitivity_deg = v
		if _rate_curve:
			_rate_curve.queue_redraw()
	)
	UIKit.slider(right, "Max Rate", 100.0, 1200.0, 10.0, Settings.rate_max_deg, func(v: float):
		Settings.rate_max_deg = v
		if _rate_curve:
			_rate_curve.queue_redraw()
	)
	UIKit.slider(right, "Expo", 0.0, 1.0, 0.01, Settings.rate_expo, func(v: float):
		Settings.rate_expo = v
		if _rate_curve:
			_rate_curve.queue_redraw()
	)
	_build_rate_curve(right)
	UIKit.section(phys, "Physics")
	UIKit.toggle(phys, "Performance mode (240 Hz physics)", Settings.performance_mode, func(v: bool): Settings.performance_mode = v)
	UIKit.toggle(phys, "Battery simulation (drain, sag, OSD)", Settings.battery_enabled, func(v: bool): Settings.battery_enabled = v)
	UIKit.gap(phys, 8)
	_segmented(phys, "Wind (outdoor maps)", ["Off", "Light", "Gusty"], Settings.wind_level, func(i: int): Settings.wind_level = i)
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

## Low / Medium / High as a segmented control - see
## Settings.graphics_quality for what each level changes.
func _add_quality_picker(parent: Control) -> void:
	var l := Label.new()
	l.text = "Graphics quality"
	parent.add_child(l)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	parent.add_child(row)
	var group := ButtonGroup.new()
	for i in range(Settings.QUALITY_NAMES.size()):
		var b := UIKit.button(Settings.QUALITY_NAMES[i], "", 48)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = i == Settings.graphics_quality
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.add_theme_stylebox_override("pressed", UIKit.box(UIKit.LOGO_SKY, UIKit.LOGO_SKY, 12))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		var q: int = i
		b.pressed.connect(func(): Settings.graphics_quality = q)
		row.add_child(b)
	var hint := Label.new()
	hint.text = "Low for older laptops and integrated graphics."
	hint.theme_type_variation = "Small"
	parent.add_child(hint)

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

## Styled after Betaflight Configurator's own "Rates Preview" graph (PID
## Tuning -> Rate Profile Settings): a dark plot with a curve from stick
## input to output rate. Computed with the exact same formula as
## Drone._actual_rate(), so it isn't just decorative - it's what the
## selected rates will actually fly like.
func _build_rate_curve(parent: Control) -> void:
	var label := Label.new()
	label.text = "Rate curve preview"
	label.theme_type_variation = "Small"
	parent.add_child(label)
	_rate_curve = Control.new()
	_rate_curve.custom_minimum_size = Vector2(0, 230)
	_rate_curve.draw.connect(func(): _draw_rate_curve(_rate_curve))
	parent.add_child(_rate_curve)

func _draw_rate_curve(c: Control) -> void:
	var w: float = c.size.x
	var h: float = c.size.y
	c.draw_style_box(UIKit.box(UIKit.BG, UIKit.BORDER, 12), Rect2(0, 0, w, h))

	var pad_left := 50.0
	var pad_bottom := 28.0
	var pad_top := 18.0
	var pad_right := 18.0
	var plot_pos := Vector2(pad_left, pad_top)
	var plot_size := Vector2(w - pad_left - pad_right, h - pad_top - pad_bottom)
	var plot_end: Vector2 = plot_pos + plot_size

	for i in range(1, 4):
		var gx: float = plot_pos.x + plot_size.x * i / 4.0
		var gy: float = plot_pos.y + plot_size.y * i / 4.0
		c.draw_line(Vector2(gx, plot_pos.y), Vector2(gx, plot_end.y), Color(1, 1, 1, 0.05), 1.0)
		c.draw_line(Vector2(plot_pos.x, gy), Vector2(plot_end.x, gy), Color(1, 1, 1, 0.05), 1.0)
	c.draw_line(Vector2(plot_pos.x, plot_pos.y), Vector2(plot_pos.x, plot_end.y), UIKit.BORDER, 1.0)
	c.draw_line(Vector2(plot_pos.x, plot_end.y), Vector2(plot_end.x, plot_end.y), UIKit.BORDER, 1.0)

	var center_sens: float = Settings.rate_center_sensitivity_deg
	var max_rate: float = Settings.rate_max_deg
	var points := PackedVector2Array()
	var n := 48
	for i in range(n + 1):
		var stick: float = float(i) / float(n)
		var deg: float = Drone.actual_rate_deg(stick, center_sens, max_rate, Settings.rate_expo)
		var x: float = plot_pos.x + stick * plot_size.x
		var y: float = plot_end.y - clamp(deg / max_rate, 0.0, 1.0) * plot_size.y
		points.append(Vector2(x, y))
	c.draw_polyline(points, UIKit.LOGO_GROUND, 3.0, true)

	var font: Font = ThemeDB.fallback_font
	c.draw_string(font, Vector2(8, pad_top + 8), "%d" % int(max_rate), HORIZONTAL_ALIGNMENT_LEFT, pad_left - 10, 14, UIKit.MUTED_LIGHT)
	c.draw_string(font, Vector2(8, plot_end.y + 4), "0", HORIZONTAL_ALIGNMENT_LEFT, pad_left - 10, 14, UIKit.MUTED_LIGHT)
	c.draw_string(font, Vector2(plot_end.x - 90, plot_end.y + 22), "100% stick", HORIZONTAL_ALIGNMENT_RIGHT, 90, 14, UIKit.MUTED_LIGHT)
	c.draw_string(font, Vector2(plot_pos.x, plot_end.y + 22), "deg/s", HORIZONTAL_ALIGNMENT_LEFT, 60, 14, UIKit.MUTED_LIGHT)

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
## Steps: REST(-1), sticks (0..3), ARM (4), TEST (5).
const STEP_ARM: int = 4
const STEP_TEST: int = 5
const HOLD_TIME: float = 0.7
const HOLD_DEFLECTION: float = 0.7
const STEP_NAMES: Array[String] = ["Rest", "Roll", "Pitch", "Yaw", "Throttle", "Arm", "Test"]

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
	restart.pressed.connect(func(): _start_calibration(_arm_only))
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
	_calibration_assigned_axes.clear()
	_hold_axis = -1
	_hold_time = 0.0
	_show_calibration()
	if arm_only:
		_enter_arm_step()
	else:
		_calibration_step = -1
	_update_calibration_step()

func _enter_arm_step() -> void:
	_calibration_step = STEP_ARM
	_arm_candidate = {}
	_arm_base_axes.clear()
	_arm_base_buttons.clear()
	for i in range(InputManager.AXES):
		_arm_base_axes.append(InputManager.joy_axis(i) if InputManager.has_joystick() else 0.0)
	for b in range(InputManager.BUTTONS):
		_arm_base_buttons.append(InputManager.joy_button(b) if InputManager.has_joystick() else false)

func _stick_axes() -> Array[int]:
	return [InputManager.axis_roll, InputManager.axis_pitch, InputManager.axis_yaw, InputManager.axis_throttle]

func _update_calibration_step() -> void:
	for c in _cal_progress.get_children():
		c.queue_free()
	var first: int = STEP_ARM if _arm_only else -1
	for st in range(first, STEP_TEST + 1):
		var pill := PanelContainer.new()
		var done: bool = st < _calibration_step
		var cur: bool = st == _calibration_step
		var bg: Color = UIKit.LOGO_SKY if done else (UIKit.LOGO_GROUND if cur else UIKit.BG)
		pill.add_theme_stylebox_override("panel", UIKit.box(bg, bg if (done or cur) else UIKit.BORDER, 999, 1, Vector4(14, 4, 14, 4)))
		var l := Label.new()
		l.text = "%d  %s" % [st - first + 1, STEP_NAMES[st + 1]]
		l.add_theme_font_size_override("font_size", 15)
		l.add_theme_color_override("font_color", Color.WHITE if (done or cur) else UIKit.MUTED_LIGHT)
		pill.add_child(l)
		_cal_progress.add_child(pill)
	_cal_skip.visible = _calibration_step == STEP_ARM
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
	else:
		_cal_title.text = "All set - try it"
		_cal_hint.text = "This is exactly what the sim reads now. Flip the arm switch to check it. Saved - it stays calibrated after a restart."

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

## Arm step: anything that changes from its state when the step began -
## a button, or an axis that isn't one of the four sticks - is the
## candidate; flipping it back confirms it (and tells a real switch from
## a stick being bumped).
func _process_arm_step() -> void:
	if _arm_candidate.is_empty():
		for b in range(InputManager.BUTTONS):
			if InputManager.joy_button(b) != _arm_base_buttons[b]:
				_arm_candidate = {"source": "button", "index": b, "off": _arm_base_buttons[b]}
				break
		if _arm_candidate.is_empty():
			var exclude := _stick_axes()
			for i in range(InputManager.AXES):
				if i in exclude:
					continue
				var v: float = InputManager.joy_axis(i)
				if absf(v - _arm_base_axes[i]) > 0.5:
					_arm_candidate = {"source": "axis", "index": i, "off": _arm_base_axes[i], "on": v}
					break
		if not _arm_candidate.is_empty():
			_cal_title.text = "Got it - now flip it back OFF"
			_cal_hint.text = "Detected %s." % _candidate_name()
		return
	if _arm_candidate.source == "button":
		if InputManager.joy_button(_arm_candidate.index) == _arm_candidate.off:
			# A button that reads pressed with the switch OFF is simply an
			# inverted switch.
			InputManager.arm_button_on_when_pressed = not _arm_candidate.off
			InputManager.arm_source = "button"
			InputManager.arm_button_index = _arm_candidate.index
			_finish_arm_step()
	else:
		var v: float = InputManager.joy_axis(_arm_candidate.index)
		if absf(v - _arm_candidate.off) < 0.25:
			InputManager.arm_source = "axis"
			InputManager.arm_axis = _arm_candidate.index
			InputManager.arm_axis_off_value = _arm_candidate.off
			InputManager.arm_axis_on_value = _arm_candidate.on
			_finish_arm_step()
		elif absf(v - _arm_candidate.off) > absf(_arm_candidate.on - _arm_candidate.off):
			_arm_candidate.on = v # a 3-position switch still travelling

func _candidate_name() -> String:
	return ("button %d" if _arm_candidate.source == "button" else "switch on axis %d") % _arm_candidate.index

func _finish_arm_step() -> void:
	InputManager.save_calibration()
	# Don't let the fresh assignment arm the drone on the next flip-on in
	# the menu: the next reading re-latches the switch state.
	InputManager._arm_switch_seen = false
	_calibration_step = STEP_TEST
	_update_calibration_step()

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
		var is_arm: bool = _calibration_step == STEP_ARM and not _arm_candidate.is_empty() and _arm_candidate.source == "axis" and _arm_candidate.index == i
		var label: String = "Axis %d" % i
		if names.has(i):
			label += "  " + names[i]
		var col: Color = UIKit.LOGO_GROUND if (held or is_arm) else (UIKit.ACCENT if names.has(i) else UIKit.MUTED_LIGHT)
		c.draw_string(font, Vector2(24, y + 7), label, HORIZONTAL_ALIGNMENT_LEFT, bar_x - 30, 18, col)
		var track := Rect2(bar_x, y - 7, bar_w, 14)
		c.draw_rect(track, Color(1, 1, 1, 0.06))
		var cx: float = bar_x + bar_w * 0.5
		var px: float = bar_x + (raw + 1.0) * 0.5 * bar_w
		c.draw_rect(Rect2(minf(cx, px), y - 7, absf(px - cx), 14), col if (held or is_arm or names.has(i)) else Color(UIKit.MUTED_LIGHT, 0.5))
		var rx: float = bar_x + (rest + 1.0) * 0.5 * bar_w
		c.draw_line(Vector2(rx, y - 11), Vector2(rx, y + 11), Color.WHITE, 2.0)
		c.draw_string(font, Vector2(bar_x + bar_w + 12, y + 7), "%+.2f" % raw, HORIZONTAL_ALIGNMENT_LEFT, 70, 16, UIKit.MUTED_LIGHT)
		if held:
			var f: float = clampf(_hold_time / HOLD_TIME, 0.0, 1.0)
			c.draw_rect(Rect2(bar_x, y + 9, bar_w * f, 4), UIKit.LOGO_GROUND)
	if _calibration_step == STEP_ARM:
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
