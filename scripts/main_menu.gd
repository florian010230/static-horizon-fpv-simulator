extends CanvasLayer

## The real entry point (see project.godot run/main_scene) - a proper
## menu outside gameplay, matching what every real FPV sim ships with,
## rather than dropping straight into flying. Built in code, same
## approach as ui.gd, deliberately just flat 2D UI (no 3D background)
## so it's essentially free to render.

const FPS_MIN: int = 50
const FPS_MAX: int = 250 ## top of the slider means uncapped, not literally 250

var _main_panel: VBoxContainer
var _settings_panel: VBoxContainer
var _fps_value_label: Label

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	_build_main_panel(root)
	_build_settings_panel(root)
	_settings_panel.visible = false

func _build_main_panel(root: Control) -> void:
	_main_panel = VBoxContainer.new()
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.position = Vector2(-150, -140)
	_main_panel.custom_minimum_size = Vector2(300, 0)
	_main_panel.add_theme_constant_override("separation", 10)
	root.add_child(_main_panel)

	var title := Label.new()
	title.text = "Static Horizon FPV Sim"
	title.add_theme_font_size_override("font_size", 26)
	_main_panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Free, open-source FPV flight sim"
	_main_panel.add_child(subtitle)

	_spacer(_main_panel, 20)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(0, 40)
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	_main_panel.add_child(play_btn)

	_spacer(_main_panel, 10)

	var settings_btn := Button.new()
	settings_btn.text = "Settings"
	settings_btn.custom_minimum_size = Vector2(0, 40)
	settings_btn.pressed.connect(func():
		_main_panel.visible = false
		_settings_panel.visible = true
	)
	_main_panel.add_child(settings_btn)

	_spacer(_main_panel, 10)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(0, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	_main_panel.add_child(quit_btn)

func _build_settings_panel(root: Control) -> void:
	_settings_panel = VBoxContainer.new()
	_settings_panel.set_anchors_preset(Control.PRESET_CENTER)
	_settings_panel.position = Vector2(-160, -140)
	_settings_panel.custom_minimum_size = Vector2(320, 0)
	_settings_panel.add_theme_constant_override("separation", 10)
	root.add_child(_settings_panel)

	var title := Label.new()
	title.text = "Settings"
	title.add_theme_font_size_override("font_size", 22)
	_settings_panel.add_child(title)

	_spacer(_settings_panel, 8)

	_add_check(_settings_panel, "Fullscreen", Settings.is_fullscreen(), func(v: bool): Settings.set_fullscreen(v))
	_add_check(_settings_panel, "Crosshair", Settings.crosshair_enabled, func(v: bool): Settings.crosshair_enabled = v)
	_add_check(_settings_panel, "Shadows (costs performance)", Settings.shadows_enabled, func(v: bool): Settings.shadows_enabled = v)

	_spacer(_settings_panel, 10)

	var fps_row := HBoxContainer.new()
	_settings_panel.add_child(fps_row)
	var fps_label := Label.new()
	fps_label.text = "Max FPS"
	fps_label.custom_minimum_size = Vector2(80, 0)
	fps_row.add_child(fps_label)

	var fps_slider := HSlider.new()
	fps_slider.min_value = FPS_MIN
	fps_slider.max_value = FPS_MAX
	fps_slider.step = 5
	fps_slider.value = clamp(Settings.max_fps if Settings.max_fps > 0 else FPS_MAX, FPS_MIN, FPS_MAX)
	fps_slider.custom_minimum_size = Vector2(150, 0)
	fps_row.add_child(fps_slider)

	_fps_value_label = Label.new()
	_fps_value_label.custom_minimum_size = Vector2(70, 0)
	_fps_value_label.text = _fps_label_text(int(fps_slider.value))
	fps_row.add_child(_fps_value_label)

	fps_slider.value_changed.connect(func(v: float):
		var fps: int = 0 if int(v) >= FPS_MAX else int(v)
		Settings.set_max_fps(fps)
		_fps_value_label.text = _fps_label_text(int(v))
	)

	_spacer(_settings_panel, 16)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(func():
		_settings_panel.visible = false
		_main_panel.visible = true
	)
	_settings_panel.add_child(back_btn)

func _fps_label_text(v: int) -> String:
	return "Unlimited" if v >= FPS_MAX else str(v)

func _spacer(parent: VBoxContainer, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

func _add_check(parent: VBoxContainer, label_text: String, initial: bool, on_change: Callable) -> void:
	var cb := CheckBox.new()
	cb.text = label_text
	cb.button_pressed = initial
	cb.toggled.connect(func(v: bool): on_change.call(v))
	parent.add_child(cb)
