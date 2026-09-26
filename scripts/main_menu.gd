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
var _map_panel: VBoxContainer
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
	_build_map_panel(root)
	_settings_panel.visible = false
	_map_panel.visible = false

func _build_main_panel(root: Control) -> void:
	_main_panel = VBoxContainer.new()
	_main_panel.set_anchors_preset(Control.PRESET_CENTER)
	_main_panel.position = Vector2(-150, -220)
	_main_panel.custom_minimum_size = Vector2(300, 0)
	_main_panel.alignment = BoxContainer.ALIGNMENT_CENTER
	_main_panel.add_theme_constant_override("separation", 10)
	root.add_child(_main_panel)

	_build_drone_preview(_main_panel)
	_build_logo(_main_panel)

	var title := Label.new()
	title.text = "Static Horizon FPV Sim"
	title.add_theme_font_size_override("font_size", 26)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_panel.add_child(title)

	var subtitle := Label.new()
	subtitle.text = "Free, open-source FPV flight sim"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_main_panel.add_child(subtitle)

	_spacer(_main_panel, 20)

	var play_btn := Button.new()
	play_btn.text = "Play"
	play_btn.custom_minimum_size = Vector2(0, 40)
	play_btn.pressed.connect(func():
		_main_panel.visible = false
		_map_panel.visible = true
	)
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

## A tiny display-piece 3D scene rendered into a small viewport - the
## current drone model, hanging off a wall hook, slowly turning. Kept
## deliberately small and simple (one light, a dozen boxes, no shadows)
## so it costs next to nothing next to the rest of this deliberately-flat
## 2D menu.
func _build_drone_preview(parent: VBoxContainer) -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(180, 180)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	parent.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(180, 180)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)

	var scene_root := Node3D.new()
	viewport.add_child(scene_root)

	# The sub-scene has no sky/world of its own, so without an explicit
	# ambient term everything not directly facing the one light reads as
	# near-black - a flat ambient fill keeps the model readable from
	# every angle as it spins.
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.7, 0.72)
	env.ambient_light_energy = 1.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	scene_root.add_child(world_env)

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -35, 0)
	light.light_energy = 1.3
	light.shadow_enabled = false
	scene_root.add_child(light)

	var cam := Camera3D.new()
	cam.position = Vector3(0, -0.02, 0.42)
	cam.fov = 45.0
	cam.current = true
	scene_root.add_child(cam)

	# Hook: a short wall mount plus an upward-curling tip, approximated
	# with two angled boxes - just enough to read as "a hook".
	var hook := Node3D.new()
	hook.position = Vector3(0, 0.16, 0)
	scene_root.add_child(hook)
	_preview_box(hook, Vector3(0, 0.05, 0), Vector3(0.018, 0.1, 0.018), Color(0.55, 0.56, 0.6))
	var tip := _preview_box(hook, Vector3(0.02, -0.005, 0), Vector3(0.07, 0.018, 0.018), Color(0.55, 0.56, 0.6))
	tip.rotation_degrees = Vector3(0, 0, -35)

	# The drone itself, dangling below the hook tip at a slight tilt.
	var drone_visual := Node3D.new()
	drone_visual.position = Vector3(0.01, -0.09, 0)
	drone_visual.rotation_degrees = Vector3(0, 25, 14)
	scene_root.add_child(drone_visual)
	_preview_box(drone_visual, Vector3.ZERO, Vector3(0.12, 0.035, 0.12), Color(0.85, 0.12, 0.12))
	for corner in [Vector3(0.06, 0.012, -0.06), Vector3(-0.06, 0.012, -0.06), Vector3(0.06, 0.012, 0.06), Vector3(-0.06, 0.012, 0.06)]:
		_preview_box(drone_visual, corner, Vector3(0.02, 0.03, 0.02), Color(0.08, 0.08, 0.08))

	var tween := create_tween().set_loops()
	tween.tween_property(drone_visual, "rotation:y", drone_visual.rotation.y + TAU, 9.0).as_relative()

func _preview_box(parent: Node3D, pos: Vector3, box_size: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.set_surface_override_material(0, mat)
	parent.add_child(mi)
	return mi

## A small procedurally-drawn wordmark - a horizon line with a
## quadcopter silhouette rising above it - instead of an external image
## asset, matching the rest of the project staying dependency-free.
func _build_logo(parent: VBoxContainer) -> void:
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(160, 40)
	logo.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	logo.draw.connect(func(): _draw_logo(logo))
	parent.add_child(logo)

func _draw_logo(c: Control) -> void:
	var w: float = c.custom_minimum_size.x
	var mid := Vector2(w * 0.5, 26)
	var sky := Color(0.4, 0.65, 0.9)
	var ground := Color(0.3, 0.24, 0.18)
	c.draw_rect(Rect2(0, 14, w, 12), ground)
	c.draw_line(Vector2(0, 26), Vector2(w, 26), sky, 2.0)
	var arm := 16.0
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var tip: Vector2 = mid + Vector2(d.x, d.y * 0.5) * arm
		c.draw_line(mid, tip, Color(0.9, 0.9, 0.92), 2.0)
		c.draw_circle(tip, 2.5, Color(0.85, 0.12, 0.12))
	c.draw_circle(mid, 4.0, Color(0.9, 0.9, 0.92))

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

	var rates_title := Label.new()
	rates_title.text = "Acro Rates"
	_settings_panel.add_child(rates_title)

	_add_labeled_slider(_settings_panel, "Center Sensitivity", 10.0, 200.0, 5.0, Settings.rate_center_sensitivity_deg, func(v: float): Settings.rate_center_sensitivity_deg = v)
	_add_labeled_slider(_settings_panel, "Max Rate", 100.0, 1200.0, 10.0, Settings.rate_max_deg, func(v: float): Settings.rate_max_deg = v)

	_spacer(_settings_panel, 16)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(func():
		_settings_panel.visible = false
		_main_panel.visible = true
	)
	_settings_panel.add_child(back_btn)

func _build_map_panel(root: Control) -> void:
	_map_panel = VBoxContainer.new()
	_map_panel.set_anchors_preset(Control.PRESET_CENTER)
	_map_panel.position = Vector2(-150, -100)
	_map_panel.custom_minimum_size = Vector2(300, 0)
	_map_panel.add_theme_constant_override("separation", 10)
	root.add_child(_map_panel)

	var title := Label.new()
	title.text = "Choose a Map"
	title.add_theme_font_size_override("font_size", 22)
	_map_panel.add_child(title)

	_spacer(_map_panel, 8)

	var village_btn := Button.new()
	village_btn.text = "Village"
	village_btn.custom_minimum_size = Vector2(0, 40)
	village_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main.tscn"))
	_map_panel.add_child(village_btn)

	_spacer(_map_panel, 10)

	var factory_btn := Button.new()
	factory_btn.text = "Factory"
	factory_btn.custom_minimum_size = Vector2(0, 40)
	factory_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/Main2.tscn"))
	_map_panel.add_child(factory_btn)

	_spacer(_map_panel, 16)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(0, 40)
	back_btn.pressed.connect(func():
		_map_panel.visible = false
		_main_panel.visible = true
	)
	_map_panel.add_child(back_btn)

func _add_labeled_slider(parent: VBoxContainer, label_text: String, min_v: float, max_v: float, step: float, initial: float, on_change: Callable) -> void:
	var row := HBoxContainer.new()
	parent.add_child(row)

	var lbl := Label.new()
	lbl.text = label_text
	lbl.custom_minimum_size = Vector2(140, 0)
	row.add_child(lbl)

	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.step = step
	slider.value = initial
	slider.custom_minimum_size = Vector2(100, 0)
	row.add_child(slider)

	var value_lbl := Label.new()
	value_lbl.custom_minimum_size = Vector2(50, 0)
	value_lbl.text = str(snapped(initial, step))
	row.add_child(value_lbl)

	slider.value_changed.connect(func(v: float):
		on_change.call(v)
		value_lbl.text = str(snapped(v, step))
	)

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
