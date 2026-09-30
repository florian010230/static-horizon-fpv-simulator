extends CanvasLayer

## HUD (armed state, throttle, FPS, key hints) plus a live tuning panel for
## the drone's PID gains and FPV camera angle, toggled with O. Built in code
## rather than hand-laid-out in a .tscn since it's all data-driven sliders.

var _drone: Drone
var _root: Control
var _hud_label: Label
var _debug_label: Label
var _tuning_panel: PanelContainer
var _crosshair: Control
var _border_label: Label
var _border_blink_t: float = 0.0
var _panel_visible: bool = false ## O toggles; hidden by default (it covers a third of the view)
var _prev_toggle_key: bool = false

func _ready() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_crosshair = Control.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_crosshair.draw.connect(_draw_crosshair)
	_root.add_child(_crosshair)

	_hud_label = Label.new()
	_hud_label.position = Vector2(16, 16)
	_hud_label.add_theme_font_size_override("font_size", 16)
	_root.add_child(_hud_label)

	_debug_label = Label.new()
	_debug_label.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_debug_label.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_debug_label.position = Vector2(-260, 16)
	_debug_label.add_theme_font_size_override("font_size", 14)
	_root.add_child(_debug_label)

	# See WorldBorder (world_border.gd) - every map's play area is meant to
	## read as endless rather than visibly walled off, so this is the only
	# feedback a pilot gets before flying far enough to reset the map.
	_border_label = Label.new()
	_border_label.text = "WARNING: LEAVING FLIGHT AREA - TURN BACK"
	_border_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_border_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_border_label.position = Vector2(0, 70)
	_border_label.add_theme_font_size_override("font_size", 24)
	_border_label.add_theme_color_override("font_color", Color(1.0, 0.25, 0.2))
	_border_label.visible = false
	_root.add_child(_border_label)

var pause_menu: PauseMenu

# --- OSD ----------------------------------------------------------------------
# Betaflight-style on-screen display: white monospaced text with a black
# outline in the corners of the FPV picture, the way it looks in real
# goggles. Left: battery; right: flight time; bottom centre: throttle,
# speed, altitude; top centre: flight mode; centre: warnings.
var _osd: Control
var _osd_labels: Dictionary = {}
var _osd_warn_t: float = 0.0

func _osd_label(key: String, preset: int, pos: Vector2, align: int, size: int = 26) -> void:
	var l := Label.new()
	l.set_anchors_preset(preset)
	l.position = pos
	l.horizontal_alignment = align
	l.add_theme_font_override("font", _osd_font())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 7)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if align == HORIZONTAL_ALIGNMENT_CENTER:
		l.grow_horizontal = Control.GROW_DIRECTION_BOTH
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		l.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	l.grow_vertical = Control.GROW_DIRECTION_BEGIN if preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM] else Control.GROW_DIRECTION_END
	_osd.add_child(l)
	_osd_labels[key] = l

static var _mono: Font
static func _osd_font() -> Font:
	if _mono == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["Menlo", "Consolas", "DejaVu Sans Mono", "Liberation Mono", "monospace"])
		f.font_weight = 700
		_mono = f
	return _mono

var _video: ColorRect

func _build_osd() -> void:
	# The analog look goes under the OSD: in real goggles the OSD text is
	# overlaid on the (noisy) picture, so it stays crisp.
	_video = ColorRect.new()
	_video.set_anchors_preset(Control.PRESET_FULL_RECT)
	_video.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vm := ShaderMaterial.new()
	vm.shader = preload("res://shaders/analog_video.gdshader")
	_video.material = vm
	_root.add_child(_video)
	_root.move_child(_video, 0)
	_osd = Control.new()
	_osd.set_anchors_preset(Control.PRESET_FULL_RECT)
	_osd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_osd)
	# Battery group top left under the status line (only with the battery
	# simulation on); throttle and altitude at the right, mid-height.
	_osd_label("bat", Control.PRESET_TOP_LEFT, Vector2(16, 52), HORIZONTAL_ALIGNMENT_LEFT, 24)
	_osd_label("mah", Control.PRESET_TOP_LEFT, Vector2(16, 84), HORIZONTAL_ALIGNMENT_LEFT, 20)
	_osd_label("time", Control.PRESET_TOP_LEFT, Vector2(16, 112), HORIZONTAL_ALIGNMENT_LEFT, 20)
	_osd_label("thr", Control.PRESET_CENTER_RIGHT, Vector2(-48, -20), HORIZONTAL_ALIGNMENT_RIGHT, 24)
	_osd_label("alt", Control.PRESET_CENTER_RIGHT, Vector2(-48, 14), HORIZONTAL_ALIGNMENT_RIGHT, 24)
	_osd_label("warn", Control.PRESET_CENTER, Vector2(0, 70), HORIZONTAL_ALIGNMENT_CENTER, 30)

func _update_osd(delta: float) -> void:
	if _osd == null:
		_build_osd()
	var vs: float = Settings.VIDEO_EFFECT_STRENGTH[clampi(Settings.video_effect, 0, 2)]
	_video.visible = vs > 0.0
	(_video.material as ShaderMaterial).set_shader_parameter("strength", vs)
	_osd.visible = _drone != null
	if not _osd.visible:
		return
	var b: Battery = _drone.battery
	var t: int = int(_drone.flight_time)
	var bat_on: bool = Settings.battery_enabled
	var osd_on: bool = Settings.osd_enabled
	_osd_labels.bat.text = "%.1fV  %.2fV" % [b.pack_v(), b.cell_v]
	_osd_labels.mah.text = "%dmAh" % int(b.used_mah)
	_osd_labels.time.text = "%02d:%02d" % [t / 60, t % 60]
	for k in ["bat", "mah", "time"]:
		_osd_labels[k].visible = bat_on
	_osd_labels.thr.text = "THR %d%%" % int(round(InputManager.get_throttle() * 100.0))
	_osd_labels.alt.text = "ALT %dm" % maxi(0, int(round(_drone.global_position.y - _drone._spawn_transform.origin.y)))
	_osd_labels.thr.visible = osd_on
	_osd_labels.alt.visible = osd_on
	var warn: String = "LOW BATTERY" if bat_on and InputManager.armed and b.is_low() else ""
	_osd_warn_t += delta
	_osd_labels.warn.text = warn
	_osd_labels.warn.modulate.a = 0.35 + 0.65 * absf(sin(_osd_warn_t * 5.0))
	_osd_labels.bat.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if b.is_low() else Color.WHITE)

func set_drone(drone: Drone) -> void:
	_drone = drone
	_build_tuning_panel()
	_crosshair.queue_redraw()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(drone)

func _process(delta: float) -> void:
	_handle_toggle()
	_update_hud()
	_update_osd(delta)
	if _tuning_panel:
		_tuning_panel.visible = _panel_visible
	_debug_label.visible = _panel_visible
	if _panel_visible:
		_debug_label.text = InputManager.raw_axes_debug_text()
	_crosshair.visible = Settings.crosshair_enabled
	if _border_label.visible:
		_border_blink_t += delta
		_border_label.modulate.a = 0.4 + 0.6 * absf(sin(_border_blink_t * 6.0))

func set_border_warning(active: bool) -> void:
	_border_label.visible = active

## Race maps: lap/timer readout, top centre (see RaceCourse). "" hides it.
var _race_label: Label
func set_race_info(text: String) -> void:
	if _race_label == null:
		_race_label = Label.new()
		_race_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
		_race_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_race_label.position.y = 120
		_race_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_race_label.add_theme_font_override("font", UIKit.oswald())
		_race_label.add_theme_font_size_override("font_size", 30)
		_race_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
		_race_label.add_theme_constant_override("outline_size", 6)
		_root.add_child(_race_label)
	_race_label.text = text
	_race_label.visible = text != ""

func _draw_crosshair() -> void:
	var center: Vector2 = _crosshair.size / 2.0
	var color := Color(1, 1, 1, 0.75)
	var gap := 6.0
	var length := 10.0
	var thickness := 2.0
	_crosshair.draw_line(center + Vector2(0, -gap - length), center + Vector2(0, -gap), color, thickness)
	_crosshair.draw_line(center + Vector2(0, gap), center + Vector2(0, gap + length), color, thickness)
	_crosshair.draw_line(center + Vector2(-gap - length, 0), center + Vector2(-gap, 0), color, thickness)
	_crosshair.draw_line(center + Vector2(gap, 0), center + Vector2(gap + length, 0), color, thickness)
	_crosshair.draw_circle(center, 1.5, color)

func _handle_toggle() -> void:
	var key := Input.is_key_pressed(KEY_O)
	if key and not _prev_toggle_key:
		_panel_visible = not _panel_visible
	_prev_toggle_key = key
	# Esc opens the in-game pause menu (PauseMenu handles it).

## One status line, top left: armed state (with why it won't arm, or
## the crash-recovery countdown), mode, throttle, FPS. Everything else
## is in the OSD or the pause menu.
func _update_hud() -> void:
	var armed_text := "ARMED" if InputManager.armed else "DISARMED"
	var arm_hint: String = InputManager.arm_hint()
	if arm_hint != "":
		armed_text = "DISARMED (%s)" % arm_hint
	if _drone and _drone.stuck_time > 0.4:
		armed_text += " - CRASHED, turning upright in %.1f s" % maxf(Drone.RECOVER_TIME - _drone.stuck_time, 0.0)
	var mode_text := "ANGLE" if InputManager.self_level else "ACRO"
	_hud_label.text = "%s     %s     Throttle %d%%     FPS %d" % [armed_text, mode_text, int(round(InputManager.get_throttle() * 100.0)), Engine.get_frames_per_second()]

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

	_add_slider(vbox, "Center Sensitivity", 10.0, 200.0, 5.0, _drone.center_sensitivity_deg, func(v: float): _drone.center_sensitivity_deg = v)
	_add_slider(vbox, "Max Rate", 100.0, 1200.0, 10.0, _drone.max_rate_deg, func(v: float): _drone.max_rate_deg = v)
	_add_slider(vbox, "Max Angle (self-level)", 10.0, 60.0, 1.0, _drone.max_angle_deg, func(v: float): _drone.max_angle_deg = v)
	_add_slider(vbox, "Angle P Gain", 2.0, 15.0, 0.5, _drone.angle_p_gain, func(v: float): _drone.angle_p_gain = v)
	_add_slider(vbox, "Roll P", 0.0, 100.0, 1.0, _drone.roll_p, func(v: float): _drone.roll_p = v)
	_add_slider(vbox, "Roll I", 0.0, 200.0, 1.0, _drone.roll_i, func(v: float): _drone.roll_i = v)
	_add_slider(vbox, "Roll D", 0.0, 2.0, 0.05, _drone.roll_d, func(v: float): _drone.roll_d = v)
	_add_slider(vbox, "Pitch P", 0.0, 100.0, 1.0, _drone.pitch_p, func(v: float): _drone.pitch_p = v)
	_add_slider(vbox, "Pitch I", 0.0, 200.0, 1.0, _drone.pitch_i, func(v: float): _drone.pitch_i = v)
	_add_slider(vbox, "Pitch D", 0.0, 2.0, 0.05, _drone.pitch_d, func(v: float): _drone.pitch_d = v)
	_add_slider(vbox, "Yaw P", 0.0, 100.0, 1.0, _drone.yaw_p, func(v: float): _drone.yaw_p = v)
	_add_slider(vbox, "Yaw I", 0.0, 200.0, 1.0, _drone.yaw_i, func(v: float): _drone.yaw_i = v)
	_add_slider(vbox, "Yaw D", 0.0, 2.0, 0.05, _drone.yaw_d, func(v: float): _drone.yaw_d = v)
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
