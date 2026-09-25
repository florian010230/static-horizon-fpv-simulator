extends CanvasLayer

## The real entry point (see project.godot run/main_scene) - a proper
## menu outside gameplay, matching what every real FPV sim ships with,
## rather than dropping straight into flying. Built in code, same
## approach as ui.gd, deliberately just flat 2D UI (no 3D background)
## so it's essentially free to render.

func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.09, 0.1, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

	var panel := VBoxContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-150, -180)
	panel.custom_minimum_size = Vector2(300, 0)
	panel.add_theme_constant_override("separation", 10)
	root.add_child(panel)

	var title := Label.new()
	title.text = "Static Horizon FPV Sim"
	title.add_theme_font_size_override("font_size", 26)
	panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Free, open-source FPV flight sim"
	panel.add_child(subtitle)

	_spacer(panel, 20)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(0, 40)
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	panel.add_child(play_btn)

	_spacer(panel, 16)

	var options_label := Label.new()
	options_label.text = "Options"
	options_label.add_theme_font_size_override("font_size", 18)
	panel.add_child(options_label)

	_add_check(panel, "Fullscreen", Settings.is_fullscreen(), func(v: bool): Settings.set_fullscreen(v))
	_add_check(panel, "Crosshair", Settings.crosshair_enabled, func(v: bool): Settings.crosshair_enabled = v)
	_add_check(panel, "Shadows (costs performance)", Settings.shadows_enabled, func(v: bool): Settings.shadows_enabled = v)

	_spacer(panel, 16)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(0, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	panel.add_child(quit_btn)

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
