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

var video: FpvVideo

func _build_osd() -> void:
	# The camera look (and lens) goes under the OSD: in real goggles the
	# OSD text is overlaid on the (noisy) picture, so it stays crisp.
	video = FpvVideo.new()
	video.setup(self)
	_root.add_child(video)
	_root.move_child(video, 0)
	# Stick overlay: both gimbals at the bottom centre, as the radio reads
	# them (Mode 2: throttle/yaw left, pitch/roll right).
	_sticks = Control.new()
	_sticks.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_sticks.custom_minimum_size = Vector2(300, 130)
	_sticks.position = Vector2(-150, -150)
	_sticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sticks.draw.connect(_draw_sticks)
	_root.add_child(_sticks)
	_osd = Control.new()
	_osd.set_anchors_preset(Control.PRESET_FULL_RECT)
	_osd.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_osd)
	# Battery group top left under the status line (only with the battery
	# simulation on); throttle and altitude at the right, mid-height.
	_osd_label("bat", Control.PRESET_TOP_LEFT, Vector2(16, 52), HORIZONTAL_ALIGNMENT_LEFT, 24)
	_osd_label("mah", Control.PRESET_TOP_LEFT, Vector2(16, 84), HORIZONTAL_ALIGNMENT_LEFT, 20)
	_osd_label("thr", Control.PRESET_CENTER_RIGHT, Vector2(-48, -70), HORIZONTAL_ALIGNMENT_RIGHT, 24)
	_osd_label("alt", Control.PRESET_CENTER_RIGHT, Vector2(-48, -36), HORIZONTAL_ALIGNMENT_RIGHT, 24)
	_osd_label("spd", Control.PRESET_CENTER_RIGHT, Vector2(-48, -2), HORIZONTAL_ALIGNMENT_RIGHT, 24)
	_osd_label("time", Control.PRESET_CENTER_RIGHT, Vector2(-48, 32), HORIZONTAL_ALIGNMENT_RIGHT, 24)
	_osd_label("lq", Control.PRESET_CENTER_RIGHT, Vector2(-48, 66), HORIZONTAL_ALIGNMENT_RIGHT, 24)
	_osd_label("warn", Control.PRESET_CENTER, Vector2(0, 70), HORIZONTAL_ALIGNMENT_CENTER, 30)

func _update_osd(delta: float) -> void:
	if _osd == null:
		_build_osd()
	_sticks.visible = Settings.stick_overlay and _drone != null
	if _sticks.visible:
		_sticks.queue_redraw()
	_osd.visible = _drone != null and not (replay != null and replay.active)
	if not _osd.visible:
		return
	var b: Battery = _drone.battery
	var t: int = int(_drone.flight_time)
	var bat_on: bool = Settings.battery_enabled
	var osd_on: bool = Settings.osd_enabled
	_osd_labels.bat.text = "%.1fV  %.2fV/cell" % [b.pack_v(), b.cell_v]
	_osd_labels.mah.text = "%dmAh" % int(b.used_mah)
	_osd_labels.time.text = "%02d:%02d" % [t / 60, t % 60]
	for k in ["bat", "mah"]:
		_osd_labels[k].visible = bat_on
	_osd_labels.thr.text = "THR %d%%" % int(round(InputManager.get_throttle() * 100.0))
	_osd_labels.alt.text = "ALT " + Settings.height_text(maxf(0.0, _drone.global_position.y - _drone._spawn_transform.origin.y))
	_osd_labels.spd.text = "SPD " + Settings.speed_text(_drone.linear_velocity.length())
	for k in ["thr", "alt", "spd", "time"]:
		_osd_labels[k].visible = osd_on
	# Video link quality (FpvVideo) - not on the Clean camera.
	_osd_labels.lq.visible = osd_on and video.link_quality >= 0
	_osd_labels.lq.text = "LQ %d" % video.link_quality
	_osd_labels.lq.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if video.link_quality < 40 else Color.WHITE)
	# Betaflight's warnings (see Battery): LOW BATTERY under 3.5 V per cell,
	# LAND NOW under 3.3 V, then the pack is flat. Also shown disarmed
	# once the pack is empty - R fits a fresh one.
	var warn: String = b.warning() if bat_on and (InputManager.armed or b.is_empty()) else ""
	if warn == "BATTERY EMPTY":
		warn += "\nR = fresh pack"
	if warn == "" and Settings.prop_damage and _drone.prop_damage_flash > 0.0:
		warn = "PROP DAMAGED"
	_osd_warn_t += delta
	_osd_labels.warn.text = warn
	_osd_labels.warn.modulate.a = 0.35 + 0.65 * absf(sin(_osd_warn_t * 5.0))
	_osd_labels.bat.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3) if b.is_low() else Color.WHITE)

var _sticks: Control
var replay: Replay

func _draw_sticks() -> void:
	var box: float = 120.0
	var gimbals: Array = [[Vector2(0, 0), InputManager.get_yaw(), InputManager.get_throttle() * 2.0 - 1.0],
		[Vector2(180, 0), InputManager.get_roll(), InputManager.get_pitch()]]
	for g in gimbals:
		var o: Vector2 = g[0]
		_sticks.draw_rect(Rect2(o, Vector2(box, box)), Color(0, 0, 0, 0.35))
		_sticks.draw_rect(Rect2(o, Vector2(box, box)), Color(1, 1, 1, 0.55), false, 2.0)
		_sticks.draw_line(o + Vector2(box * 0.5, 6), o + Vector2(box * 0.5, box - 6), Color(1, 1, 1, 0.25), 1.0)
		_sticks.draw_line(o + Vector2(6, box * 0.5), o + Vector2(box - 6, box * 0.5), Color(1, 1, 1, 0.25), 1.0)
		var dot: Vector2 = o + Vector2(box * 0.5 + clampf(g[1], -1.0, 1.0) * (box * 0.5 - 8.0), box * 0.5 - clampf(g[2], -1.0, 1.0) * (box * 0.5 - 8.0))
		_sticks.draw_circle(dot, 8.0, Color(1.0, 0.55, 0.2))

## Line-of-sight view (V): the camera stands where the pilot would - at
## the spawn point, eye height - and follows the quad, like flying LOS
## at the field. V again back to FPV.
var _los_cam: Camera3D
var _los_key_down: bool = false

func _update_los() -> void:
	# The radio's restart switch (Settings -> Radio): the map from the start.
	if InputManager.restart_pressed() and not SceneLoader.is_loading():
		SceneLoader.reload("Restarting")
		return
	# V or the radio control assigned in Settings -> Radio (edge-triggered).
	var pressed: bool = InputManager.los_toggle_pressed()
	if pressed and _drone:
		toggle_los()
	if _los_cam and _drone and _los_cam.global_position.distance_to(_drone.global_position) > 0.5:
		_los_cam.look_at(_drone.global_position, Vector3.UP)

func toggle_los() -> void:
		if _los_cam == null:
			_los_cam = Camera3D.new()
			_los_cam.fov = 60.0
			_los_cam.far = Settings.view_distance
			_drone.get_parent().add_child(_los_cam)
			_los_cam.global_position = _drone._spawn_transform.origin + Vector3(0, 1.7, 0) + _drone._spawn_transform.basis.z * 3.0
			_los_cam.current = true
		else:
			_los_cam.queue_free()
			_los_cam = null
			_drone.get_node("CameraMount/Camera3D").current = true

func _exit_tree() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func set_drone(drone: Drone) -> void:
	_drone = drone
	_build_tuning_panel()
	_crosshair.queue_redraw()
	pause_menu = PauseMenu.new()
	add_child(pause_menu)
	pause_menu.setup(drone)
	# DVR: always recording, P plays back (see Replay).
	replay = Replay.new()
	replay.name = "Replay"
	add_child(replay)
	replay.setup(drone, self)

var _flight_noted: bool = false

func _process(delta: float) -> void:
	_handle_toggle()
	if not _flight_noted and InputManager.armed:
		_flight_noted = true
		var cur: Node = get_tree().current_scene
		Achievements.note_flight(MapCatalog.for_scene(cur.scene_file_path).get("id", "") if cur else "")
	# No mouse cursor over the FPV view; it comes back in the pause menu
	# (which pauses this node) and with the tuning panel open.
	var want: Input.MouseMode = Input.MOUSE_MODE_VISIBLE if _panel_visible else Input.MOUSE_MODE_HIDDEN
	if Input.mouse_mode != want:
		Input.mouse_mode = want
	_update_hud()
	_update_los()
	_update_osd(delta)
	if _tuning_panel:
		_tuning_panel.visible = _panel_visible
	_debug_label.visible = _panel_visible
	if _panel_visible:
		_debug_label.text = InputManager.raw_axes_debug_text()
	var replaying: bool = replay != null and replay.active
	_crosshair.visible = Settings.crosshair_enabled and _los_cam == null and not replaying
	if _border_label.visible:
		_border_blink_t += delta
		_border_label.modulate.a = 0.4 + 0.6 * absf(sin(_border_blink_t * 6.0))

# The OS can show the cursor again behind Godot's back (macOS: switching
# apps, the Dock, a notification) while Input.mouse_mode still says
# HIDDEN - then _process never hides it again. So hide it anew when the
# window gets focus back or the mouse moves during a flight (at most twice
# a second).
var _rehide_t: int = 0
func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN or what == NOTIFICATION_WM_MOUSE_ENTER or what == NOTIFICATION_WM_WINDOW_FOCUS_IN:
		_rehide_cursor()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Time.get_ticks_msec() - _rehide_t > 500:
		_rehide_cursor()

func _rehide_cursor() -> void:
	if _panel_visible or get_tree().paused or Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
		return
	_rehide_t = Time.get_ticks_msec()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Input.mouse_mode = Input.MOUSE_MODE_HIDDEN

func set_border_warning(active: bool) -> void:
	_border_label.visible = active

## Race maps: lap/timer readout, top centre (see RaceCourse). "" hides it.
## A short message in the middle of the screen (fades after 2.5 s).
var _flash: Label
func flash_message(text: String) -> void:
	if _flash == null:
		_flash = Label.new()
		_flash.set_anchors_preset(Control.PRESET_CENTER)
		_flash.grow_horizontal = Control.GROW_DIRECTION_BOTH
		_flash.grow_vertical = Control.GROW_DIRECTION_BOTH
		_flash.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_flash.add_theme_font_override("font", UIKit.oswald())
		_flash.add_theme_font_size_override("font_size", 40)
		_flash.add_theme_color_override("font_color", Color(1.0, 0.45, 0.2))
		_flash.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
		_flash.add_theme_constant_override("outline_size", 8)
		_root.add_child(_flash)
	_flash.text = text
	_flash.modulate.a = 1.0
	_flash.visible = true
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_property(_flash, "modulate:a", 0.0, 0.9)

var _race_label: Label
## good/bad tint the line (split ahead of / behind the best lap, missed gate).
func set_race_info(text: String, good: bool = false, bad: bool = false) -> void:
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
	_race_label.add_theme_color_override("font_color", Color(0.45, 1.0, 0.5) if good else (Color(1.0, 0.42, 0.35) if bad else Color.WHITE))

## The race's results card (RaceCourse._finish): title and lines, shown
## for a few seconds over the flight view.
var _results: PanelContainer
func show_race_results(title: String, lines: Array[String]) -> void:
	if _results:
		_results.queue_free()
	_results = PanelContainer.new()
	_results.theme = UIKit.theme()
	_results.theme_type_variation = "Card"
	_results.set_anchors_preset(Control.PRESET_CENTER)
	_results.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_results.grow_vertical = Control.GROW_DIRECTION_BOTH
	_results.custom_minimum_size = Vector2(460, 0)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	_results.add_child(box)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "Title"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(t)
	for l in lines:
		var lb := Label.new()
		lb.text = l
		lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		if l.begins_with("TOTAL") or l.begins_with("NEW TRACK"):
			lb.add_theme_color_override("font_color", UIKit.ACCENT)
			lb.add_theme_font_size_override("font_size", 26)
		box.add_child(lb)
	_root.add_child(_results)
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(_results, "modulate:a", 0.0, 1.0)
	tw.tween_callback(_results.queue_free)

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
