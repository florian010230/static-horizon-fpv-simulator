class_name MainMenu
extends CanvasLayer

## The real entry point (see project.godot run/main_scene) - a proper
## menu outside gameplay, matching what every real FPV sim ships with,
## rather than dropping straight into flying. Built entirely in code (no
## hand-laid-out UI in the .tscn), deliberately flat 2D apart from the
## small drone-preview viewport, so it's essentially free to render.
##
## Look: the companion website's dark theme (css/style.css,
## [data-theme="dark"]) - the same background, card, border, text and
## link colors, 16 px rounded cards with a soft shadow, pill-shaped
## "eyebrow" labels, the Oswald wordmark and the artificial-horizon
## logo in its sky-blue/ground-orange brand colors.
##
## Layout rule learned the hard way: every sub-screen is a fixed-size
## card whose header row (with Back) is always visible, and whose content
## scrolls if it ever outgrows the card. The old Settings screen was a
## plain column taller than the window - its Back button sat below the
## bottom edge, so there was no visible way out.

const MENU_FPS: int = 30

## The maps themselves live in MapCatalog (scripts/map_catalog.gd).

## Where Back / Esc goes from each screen.
const BACK_TARGET := {"mode": "main", "map": "mode", "tracks": "map", "about": "main", "licences": "about", "updates": "main", "achievements": "main"}
const WEBSITE := "https://statichorizonfpv.com/"

var _settings: SettingsScreens
var _updater: Updater
var _updates: UpdatesScreen
var _achievements: AchievementsScreen
var _update_hint: Button

var _screens: Dictionary = {}
var _current: String = "main"

var _preview_drone_root: Node3D
var _preview_name: Label
var _preview_tags: Label
var _preview_text: Label

## Which screen opens first - the pause menu's "Change map" sets "map".
static var start_screen: String = "main"

func _ready() -> void:
	# The menu doesn't need 60+ FPS for one slowly turning preview - and
	# a menu left open should not spin up a laptop's fans (it did: GPU at
	# ~50% just sitting here, measured). Settings.max_fps comes back the
	# moment a map loads.
	Settings.apply_fps_cap(MENU_FPS)

	var bg := TextureRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.texture = _background_texture()
	add_child(bg)
	var horizon := Control.new()
	horizon.set_anchors_preset(Control.PRESET_FULL_RECT)
	horizon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	horizon.draw.connect(func(): _draw_horizon(horizon))
	horizon.resized.connect(func(): horizon.queue_redraw())
	add_child(horizon)

	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.theme = UIKit.theme()
	add_child(root)

	_screens["main"] = _build_main_screen(root)
	_screens["mode"] = _build_mode_screen(root)
	_screens["map"] = _build_map_screen(root)
	_screens["tracks"] = _build_tracks_screen(root)
	_screens["about"] = _build_about_screen(root)
	_screens["licences"] = _build_licences_screen(root)
	_updater = Updater.new()
	add_child(_updater)
	_updates = UpdatesScreen.new()
	_screens["updates"] = _updates.build(root, _updater, func(): _show("main"))
	_achievements = AchievementsScreen.new()
	_screens["achievements"] = _achievements.build(root, func(): _show("main"))
	_updater.finished.connect(_refresh_update_hint)
	Updater.note_launch()
	_refresh_update_hint()
	_updater.check_on_start()
	# Settings is a shared component (also opened from the in-game pause
	# menu); from here, closing it returns to the home screen.
	_settings = SettingsScreens.new()
	root.add_child(_settings)
	_settings.closed.connect(func():
		_refresh_preview_labels() # units may have changed
		_show("main"))
	_show(start_screen)
	start_screen = "main"

func _exit_tree() -> void:
	Settings.apply_fps_cap(Settings.max_fps)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and BACK_TARGET.has(_current):
		_show(BACK_TARGET[_current])
		get_viewport().set_input_as_handled()

func _show(screen: String) -> void:
	for key in _screens:
		_screens[key].visible = key == screen
	_current = screen
	if screen == "settings":
		_settings.open()
	if screen == "map":
		_refresh_maps()
	if screen == "updates":
		_updates.refresh()
	if screen == "licences":
		_fill_licences()
	if screen == "achievements":
		_achievements.refresh()
	if screen == "main":
		_refresh_update_hint()
	# Keyboard / gamepad: something is always focused, so arrows + Enter
	# work everywhere without the mouse.
	var first: Control = _first_focusable(_screens.get(screen))
	if first:
		(func(): if first.is_inside_tree() and first.is_visible_in_tree(): first.grab_focus()).call_deferred()

func _first_focusable(n: Node) -> Control:
	if n == null:
		return null
	if n is Button and (n as Button).visible and not (n as Button).disabled and (n as Button).focus_mode != Control.FOCUS_NONE and n.has_meta("default_focus"):
		return n
	for c in n.get_children():
		var f: Control = _first_focusable(c)
		if f:
			return f
	return null

## Backdrop: the site's near-black, a soft sky-blue glow up top and a
## ground-orange glow at the bottom - the logo's own two halves.
## Computed ONCE into a small image and stretched (linear filtering
## makes it a smooth gradient): the first version drew 36 huge
## translucent circles instead, which the GPU re-blended over the whole
## 2880x1800 screen every single frame - measured at ~50% GPU load with
## nothing but the menu open.
func _background_texture() -> ImageTexture:
	var w := 160
	var h := 90
	var img := Image.create(w, h, false, Image.FORMAT_RGB8)
	# (2026-10-12, the user's pick "B": darker, small glows at the very top
	# and bottom edges - the earlier big glows were too much.)
	var base := Color("#0b0f15")
	for y in range(h):
		for x in range(w):
			var p := Vector2(x / float(w) - 0.5, y / float(h))
			var sky: float = clampf(1.0 - Vector2(p.x / 0.7, (p.y + 0.06) / 0.30).length(), 0.0, 1.0)
			var ground: float = clampf(1.0 - Vector2(p.x / 0.7, (1.06 - p.y) / 0.30).length(), 0.0, 1.0)
			var c: Color = base.lerp(Color("#4f8fe6"), sky * 0.20).lerp(Color("#e8763a"), ground * 0.17)
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)

## A faint artificial-horizon line with pitch-ladder ticks - a handful
## of thin lines, drawn once (redrawn only on resize).
func _draw_horizon(c: Control) -> void:
	var s: Vector2 = c.size
	var hy: float = s.y * 0.62
	c.draw_line(Vector2(0, hy), Vector2(s.x, hy), Color(1, 1, 1, 0.05), 1.5)
	for k in range(-3, 4):
		if k == 0:
			continue
		var y: float = hy + k * 46.0
		var half: float = 70.0 if k % 2 == 0 else 38.0
		c.draw_line(Vector2(s.x * 0.5 - half, y), Vector2(s.x * 0.5 + half, y), Color(1, 1, 1, 0.025), 1.0)

## The quiet update line: a newer release, or (once) what's new after an
## update. Nothing at all otherwise.
func _refresh_update_hint() -> void:
	if _update_hint == null:
		return
	if Updater.newer_available():
		_update_hint.text = "Version %s available  ›" % Updater.latest.version
		_update_hint.visible = true
	elif Updater.show_whats_new_hint():
		_update_hint.text = "What's new in %s  ›" % Updater.current_version()
		_update_hint.visible = true
	else:
		_update_hint.visible = false

## The main screen's corners: a small Settings button bottom left; the
## version, the quiet "new version" / "what's new" hint and a small
## Updates button bottom right.
func _build_corners(screen: Control) -> void:
	var settings := UIKit.button("Settings", "MainChip", 40)
	settings.add_theme_font_size_override("font_size", 19)
	settings.custom_minimum_size.x = 130
	settings.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	settings.grow_vertical = Control.GROW_DIRECTION_BEGIN
	settings.offset_left = 28
	settings.offset_bottom = -22
	settings.pressed.connect(func(): _show("settings"))
	screen.add_child(settings)
	var corner := HBoxContainer.new()
	corner.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	corner.offset_right = -28
	corner.offset_bottom = -22
	corner.alignment = BoxContainer.ALIGNMENT_END
	corner.add_theme_constant_override("separation", 14)
	screen.add_child(corner)
	_update_hint = UIKit.button("", "GhostButton", 40)
	_update_hint.add_theme_font_size_override("font_size", 17)
	_update_hint.add_theme_color_override("font_color", UIKit.ACCENT)
	_update_hint.visible = false
	_update_hint.pressed.connect(func(): _show("updates"))
	corner.add_child(_update_hint)
	var version := Label.new()
	version.text = "Version %s" % Updater.current_version()
	version.theme_type_variation = "Small"
	version.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	corner.add_child(version)
	var upd := UIKit.button("Updates", "MainChip", 40)
	upd.add_theme_font_size_override("font_size", 19)
	upd.custom_minimum_size.x = 110
	upd.pressed.connect(func(): _show("updates"))
	corner.add_child(upd)

# --- Main screen -------------------------------------------------------------

func _build_main_screen(root: Control) -> Control:
	var screen := Control.new()
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(screen)
	# Two halves filling the screen (2026-10-12, the user's pick): brand,
	# text and buttons on the left, a tall drone window on the right.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side: Array in [["margin_left", 90], ["margin_right", 70], ["margin_top", 56], ["margin_bottom", 92]]:
		margin.add_theme_constant_override(side[0], side[1])
	screen.add_child(margin)
	_build_corners(screen)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 70)
	margin.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(600, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.0
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 14)
	row.add_child(left)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UIKit.box(Color(0, 0, 0, 0), Color(0.5, 0.69, 1.0, 0.55), 999, 1, Vector4(14, 4, 14, 4)))
	badge.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var badge_l := Label.new()
	badge_l.text = "FREE  ·  SOURCE ON GITHUB"
	badge_l.add_theme_font_override("font", UIKit.oswald())
	badge_l.add_theme_font_size_override("font_size", 15)
	badge_l.add_theme_color_override("font_color", Color("#9cc2ff"))
	badge.add_child(badge_l)
	left.add_child(badge)
	UIKit.gap(left, 12)

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 20)
	left.add_child(brand)
	# The original logo (assets/brand master = res://icon.png), not redrawn.
	var logo := TextureRect.new()
	logo.name = "Logo"
	logo.texture = load("res://icon.png")
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(104, 104)
	brand.add_child(logo)
	var heading := Control.new()
	heading.custom_minimum_size = Vector2(480, 96)
	heading.draw.connect(func(): _draw_heading(heading))
	brand.add_child(heading)

	var subtitle := Label.new()
	subtitle.text = "Practise FPV with your own radio and your own Betaflight rates. Freestyle through a derelict steelworks, chase cranes in a port city, race league gates against your best lap."
	subtitle.theme_type_variation = "Muted"
	subtitle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	subtitle.custom_minimum_size = Vector2(560, 0)
	UIKit.gap(left, 12)
	left.add_child(subtitle)

	UIKit.gap(left, 22)
	var play := UIKit.button("Play", "MainPlay", 72)
	play.add_theme_font_size_override("font_size", 28)
	play.pressed.connect(func(): _show("mode"))
	play.set_meta("default_focus", true)
	left.add_child(play)
	# One column of full-width rows under Play: Achievements, About, and
	# Quit as a big plain text button (no card, as in the earlier menus).
	# Settings sits in the bottom-left corner, Updates and the version in
	# the bottom-right one (see _build_corners).
	for entry in [["Achievements", func(): _show("achievements")],
			["About", func(): _show("about")]]:
		var b := UIKit.button(entry[0], "MainButton", 58)
		b.pressed.connect(entry[1])
		left.add_child(b)
	var quit := UIKit.button("Quit", "MainButton", 58)
	quit.pressed.connect(func(): get_tree().quit())
	left.add_child(quit)

	UIKit.gap(left, 10)
	var hint := Label.new()
	hint.text = "Radio in USB joystick mode, or keyboard: W/A/S/D, Q/E, Shift/Ctrl"
	hint.theme_type_variation = "Small"
	left.add_child(hint)

	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", CutBox.make(Color(0.047, 0.063, 0.086, 0.86), UIKit.LOGO_SKY, Color(1, 1, 1, 0.09), Vector4(30, 20, 26, 20), 26.0))
	# A share of the width, not its content: switching drones must not
	# resize the card just because one description is longer.
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_SHRINK_CENTER # (full height was too big, 2026-10-12)
	card.size_flags_stretch_ratio = 0.85
	row.add_child(card)
	var card_box := VBoxContainer.new()
	card_box.add_theme_constant_override("separation", 8)
	card.add_child(card_box)
	var preview_label := Label.new()
	preview_label.text = "YOUR DRONE"
	preview_label.theme_type_variation = "Small"
	card_box.add_child(preview_label)
	# The drone is chosen right here with the arrows either side of the
	# preview (no separate "Choose Your Drone" screen anymore).
	var picker := HBoxContainer.new()
	picker.add_theme_constant_override("separation", 4)
	picker.alignment = BoxContainer.ALIGNMENT_CENTER
	picker.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_box.add_child(picker)
	var prev_btn := _arrow_button("‹", -1)
	prev_btn.set_meta("find_text", "prev_drone")
	picker.add_child(prev_btn)
	_build_drone_preview(picker)
	var next_btn := _arrow_button("›", 1)
	next_btn.set_meta("find_text", "next_drone")
	picker.add_child(next_btn)
	_preview_name = Label.new()
	_preview_name.theme_type_variation = "Heading"
	_preview_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(_preview_name)
	_preview_tags = Label.new()
	_preview_tags.add_theme_color_override("font_color", UIKit.LINK)
	_preview_tags.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	card_box.add_child(_preview_tags)
	_preview_text = Label.new()
	_preview_text.theme_type_variation = "Small"
	_preview_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_preview_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_preview_text.custom_minimum_size = Vector2(0, 44)
	card_box.add_child(_preview_text)
	# Spec bars (2026-10-12): speed, punch (thrust to weight), weight - from
	# the real drone numbers, one scale for all four drones.
	_spec_grid = GridContainer.new()
	_spec_grid.name = "SpecBars"
	_spec_grid.columns = 3
	_spec_grid.add_theme_constant_override("h_separation", 16)
	_spec_grid.add_theme_constant_override("v_separation", 8)
	card_box.add_child(_spec_grid)
	for st: String in ["Speed", "Punch", "Weight"]:
		var l := Label.new()
		l.text = st.to_upper()
		l.add_theme_font_override("font", UIKit.oswald())
		l.add_theme_font_size_override("font_size", 17)
		l.add_theme_color_override("font_color", UIKit.MUTED_LIGHT)
		_spec_grid.add_child(l)
		var bar := ProgressBar.new()
		bar.name = st
		bar.show_percentage = false
		bar.max_value = 1.0
		bar.step = 0.0
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("background", UIKit.box(Color(1, 1, 1, 0.08), Color(0, 0, 0, 0), 5, 0, Vector4.ZERO))
		bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.LOGO_SKY, Color(0, 0, 0, 0), 5, 0, Vector4.ZERO))
		_spec_grid.add_child(bar)
		var v := Label.new()
		v.name = st + "Value"
		v.custom_minimum_size = Vector2(110, 0)
		v.add_theme_font_size_override("font_size", 18)
		_spec_grid.add_child(v)
	_refresh_preview_labels()
	return screen

## The site's real brand wordmark treatment (css/style.css, ".brand
## span"): Oswald at weight 600, uppercase, letter-spaced, skewed -10
## degrees. Control has no built-in skew, so this is drawn by hand with a
## sheared transform matrix, two lines stacked.
func _draw_heading(c: Control) -> void:
	var font_var := FontVariation.new()
	font_var.base_font = UIKit.oswald_font()
	font_var.set_spacing(TextServer.SPACING_GLYPH, 3)
	var shear := -0.18 # ~ -10 degrees, matches the site's transform: skewX(-10deg)
	var xform := Transform2D(Vector2(1, 0), Vector2(shear, 1), Vector2.ZERO)
	c.draw_set_transform_matrix(xform)
	c.draw_string(font_var, xform.affine_inverse() * Vector2(8, 46), "STATIC HORIZON", HORIZONTAL_ALIGNMENT_LEFT, -1, 44, UIKit.TEXT)
	c.draw_string(font_var, xform.affine_inverse() * Vector2(8, 90), "FPV", HORIZONTAL_ALIGNMENT_LEFT, -1, 40, UIKit.LINK)
	var fpv_w: float = font_var.get_string_size("FPV", HORIZONTAL_ALIGNMENT_LEFT, -1, 40).x
	c.draw_string(font_var, xform.affine_inverse() * Vector2(8 + fpv_w + 14, 90), "SIMULATOR", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, UIKit.MUTED)
	c.draw_set_transform_matrix(Transform2D.IDENTITY)

## A tiny display-piece 3D scene rendered into a small viewport - whichever
## drone is currently selected (Settings.selected_drone), slowly
## turning. Only rendered while the main screen (its card) is visible. Kept deliberately small and simple (one
## light, a WorldEnvironment, a dozen primitives, no shadows) so it costs
## next to nothing next to the rest of this deliberately-flat 2D menu.
func _build_drone_preview(parent: Control) -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(360, 340)
	container.size_flags_horizontal = Control.SIZE_EXPAND_FILL # the bigger drone window (2026-10-12)
	container.custom_minimum_size = Vector2(420, 330)
	parent.add_child(container)

	var viewport := SubViewport.new()
	viewport.size = Vector2i(360, 340)
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
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

	# Looking slightly down at the drone, which turns in place in the
	# middle of the card. (It used to hang from a little wall hook, but
	# at this size the hook read as a gray thing floating above it.)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 0.2, 0.34) # from above-front: the frame's plates and arms read
	cam.fov = 40.0
	cam.current = true
	scene_root.add_child(cam)
	cam.look_at(Vector3(0, 0.005, 0))

	_preview_drone_root = Node3D.new()
	scene_root.add_child(_preview_drone_root)
	_build_preview_drone(_preview_drone_root)

	var tween := create_tween().set_loops()
	tween.tween_property(_preview_drone_root, "rotation:y", _preview_drone_root.rotation.y + TAU, 9.0).as_relative()

## Reuses the exact same procedural frame the real flying drone uses (see
## drone_frame_builder.gd), so the preview always matches whichever drone
## is actually selected. Rebuilt whenever the drone choice changes.
func _build_preview_drone(parent: Node3D) -> void:
	for child in parent.get_children():
		child.free()
	var p: Dictionary = Drone.PROFILES.get(Settings.selected_drone, Drone.PROFILES["seeker3"])
	var visual: Dictionary = p.visual.duplicate()
	visual["arm_length"] = p.arm_length
	DroneFrameBuilder.build(parent, visual)
	# Both frames fill the card the same way: a 25 g whoop is under half
	# the size of the Static Three and would otherwise be a speck.
	var span: float = 2.0 * (p.arm_length * sqrt(2.0) + p.visual.prop_radius)
	parent.scale = Vector3.ONE * (0.26 / span)

## Names/tags/descriptions live with the flight data (Drone.PROFILES,
## "display") so the menu, the pause menu and the drone can't disagree.
func _drone_info(id: String) -> Dictionary:
	return Drone.PROFILES.get(id, Drone.PROFILES["seeker3"]).display

var _spec_grid: GridContainer
const SPEC_MAX := {"speed": 220.0, "punch": 12.0, "weight": 0.7} ## km/h, thrust:weight, kg - the bars' full length
func _refresh_preview_labels() -> void:
	var d: Dictionary = _drone_info(Settings.selected_drone)
	_preview_name.text = d.name
	_preview_tags.text = Settings.spec_tags(d.tags)
	_preview_text.text = d.text
	if _spec_grid:
		var st: Dictionary = spec_values(Settings.selected_drone)
		(_spec_grid.get_node("Speed") as ProgressBar).value = st.speed / SPEC_MAX.speed
		(_spec_grid.get_node("Punch") as ProgressBar).value = st.punch / SPEC_MAX.punch
		(_spec_grid.get_node("Weight") as ProgressBar).value = st.weight / SPEC_MAX.weight
		(_spec_grid.get_node("SpeedValue") as Label).text = Settings.spec_tag(d.tags[1]) # (km/h or mph, as set)
		(_spec_grid.get_node("PunchValue") as Label).text = "%d : 1" % roundi(st.punch)
		(_spec_grid.get_node("WeightValue") as Label).text = Settings.spec_tag(d.tags[2])

## A drone's numbers for the spec bars: top speed (km/h, the profile's
## own figure), thrust to weight (4 motors' max thrust / weight), mass (kg).
static func spec_values(id: String) -> Dictionary:
	var p: Dictionary = Drone.PROFILES.get(id, Drone.PROFILES["seeker3"])
	var speed: float = float(String(p.display.tags[1]).to_float())
	return {"speed": speed, "punch": 4.0 * float(p.max_motor_thrust_n) / (float(p.mass) * 9.81), "weight": float(p.mass)}

func _arrow_button(glyph: String, step: int) -> Button:
	var b := UIKit.button(glyph, "GhostButton", 72)
	b.custom_minimum_size = Vector2(56, 72)
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	b.add_theme_font_size_override("font_size", 48)
	b.pressed.connect(func(): _cycle_drone(step))
	return b

func _cycle_drone(step: int) -> void:
	var order: Array[String] = Drone.PROFILE_ORDER
	var idx: int = maxi(order.find(Settings.selected_drone), 0)
	Settings.selected_drone = order[posmod(idx + step, order.size())]
	_build_preview_drone(_preview_drone_root)
	_refresh_preview_labels()

# --- Sub-screens: one fixed card each, header always visible ----------------

## A big clickable card: optional colored top stripe, title, tag line,
## description, call to action.
func _option_card(title: String, tags: String, text: String, stripe: Color, action: String) -> Button:
	var b := Button.new()
	b.theme_type_variation = "CardButton"
	b.custom_minimum_size = Vector2(0, 330)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("find_text", title)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 28
	box.offset_top = 22
	box.offset_right = -28
	box.offset_bottom = -22
	box.add_theme_constant_override("separation", 12)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(box)
	var labels: Array[Control] = []
	if stripe.a > 0.0:
		var bar := ColorRect.new()
		bar.color = stripe
		bar.custom_minimum_size = Vector2(0, 6)
		box.add_child(bar)
		labels.append(bar)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "Title"
	t.add_theme_font_size_override("font_size", 34)
	box.add_child(t)
	var tg := Label.new()
	tg.text = tags
	tg.add_theme_color_override("font_color", UIKit.LINK)
	tg.add_theme_font_size_override("font_size", 18)
	box.add_child(tg)
	var d := Label.new()
	d.text = text
	d.theme_type_variation = "Muted"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(d)
	var a := Label.new()
	a.text = action + "  ›"
	a.add_theme_font_override("font", UIKit.oswald())
	a.add_theme_font_size_override("font_size", 22)
	a.add_theme_color_override("font_color", UIKit.ACCENT)
	box.add_child(a)
	labels.append_array([t, tg, d, a])
	for l in labels:
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return b

func _build_about_screen(root: Control) -> Control:
	var parts: Array = UIKit.screen_card(root, "About", "", 800, func(): _show("main"))
	var content: VBoxContainer = parts[1]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	content.add_child(head)
	var logo := TextureRect.new()
	logo.texture = load("res://icon.png") # the original logo
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(76, 76)
	head.add_child(logo)
	var name_box := VBoxContainer.new()
	head.add_child(name_box)
	var name_label := Label.new()
	name_label.text = "Static Horizon FPV Simulator"
	name_label.theme_type_variation = "Title"
	name_box.add_child(name_label)
	var version := Label.new()
	version.text = "Version %s  ·  free, source on GitHub (PolyForm Noncommercial licence)" % ProjectSettings.get_setting("application/config/version", "dev")
	version.theme_type_variation = "Muted"
	name_box.add_child(version)

	var intro := Label.new()
	var n_maps: int = MapCatalog.MAPS.filter(func(m: Dictionary) -> bool: return not m.get("dev", false)).size()
	var words: Array = ["", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine", "Ten", "Eleven", "Twelve", "Thirteen", "Fourteen", "Fifteen"]
	var maps_word: String = words[n_maps] if n_maps < words.size() else str(n_maps)
	intro.text = "A free FPV drone simulator that runs on weak hardware and flies with your radio over USB. " + maps_word + " maps for freestyle and racing, four quads whose mass, thrust and drag are taken from real ones, and a flight controller modelled on Betaflight - a simulation, so close but never quite the real thing."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(intro)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 48)
	content.add_child(cols)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(left)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(right)
	_about_section(left, "How it's made", [
		"No image or sound files: every texture, motor sound, drone model and shadow is generated in code.",
		"Flight model grounded in real data: Betaflight's rate curve, airmode and I-term relax; rotor drag measured by Faessler, Franchi & Scaramuzza (2018); real drone masses, thrust and top speeds.",
		"Tested end to end by an automated self-test that plays the game like a pilot does.",
	])
	_about_section(right, "Controls", [
		"Radio: USB Joystick mode - calibrate once in Settings, arm with any switch you assign.",
		"Keyboard: A/D roll, W/S pitch, Q/E yaw, Shift/Ctrl throttle.",
		"Enter arm/disarm  ·  L acro/angle  ·  R reset  ·  Esc pause menu. Crashed on your back? It flips upright after 2 s.",
	])
	_about_section(right, "Credits", [
		"Godot Engine 4 (MIT licence) - godotengine.org",
		"Oswald typeface (SIL Open Font License)",
	])
	UIKit.gap(content, 6)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 12)
	content.add_child(buttons)
	var site := UIKit.button("Visit statichorizonfpv.com", "PrimaryButton", 56)
	site.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	site.pressed.connect(func(): OS.shell_open(WEBSITE))
	buttons.add_child(site)
	var lic := UIKit.button("Licences", "", 56)
	lic.custom_minimum_size.x = 180
	lic.pressed.connect(func(): _show("licences"))
	buttons.add_child(lic)
	return parts[0]

## The licence texts the game ships under, and those of the engine and
## everything in it (Godot's MIT licence asks for its notice to be
## included with the game). Filled when the screen is first opened.
var _licences_text: RichTextLabel

func _build_licences_screen(root: Control) -> Control:
	var parts: Array = UIKit.screen_card(root, "Licences", "", 760, func(): _show("about"))
	var content: VBoxContainer = parts[1]
	_licences_text = RichTextLabel.new()
	_licences_text.fit_content = true
	_licences_text.selection_enabled = true
	_licences_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_licences_text.add_theme_font_size_override("normal_font_size", 15)
	content.add_child(_licences_text)
	return parts[0]

func _fill_licences() -> void:
	if _licences_text.text != "":
		return
	var t := "STATIC HORIZON FPV SIMULATOR\n"
	t += "PolyForm Noncommercial License 1.0.0 - free to use, study, change and share for non-commercial purposes. Full text: https://polyformproject.org/licenses/noncommercial/1.0.0\n\n"
	t += "OSWALD TYPEFACE\nCopyright The Oswald Project Authors. SIL Open Font License 1.1 (text below).\n\n"
	t += "GODOT ENGINE\n" + Engine.get_license_text() + "\n\n"
	t += "THIRD-PARTY COMPONENTS IN THE GODOT ENGINE\n"
	for c in Engine.get_copyright_info():
		t += "\n" + str(c.name) + "\n"
		for p in c.parts:
			for cr in p.copyright:
				t += "  (c) " + str(cr) + "\n"
			t += "  Licence: " + str(p.license) + "\n"
	var li: Dictionary = Engine.get_license_info()
	for k in li:
		t += "\n\n" + str(k) + "\n" + str(li[k])
	_licences_text.text = t

func _about_section(parent: Control, title: String, lines: Array) -> void:
	UIKit.gap(parent, 8)
	UIKit.section(parent, title)
	for line in lines:
		var l := Label.new()
		l.text = "·  " + line
		l.theme_type_variation = "Muted"
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		parent.add_child(l)

## Freestyle or Race - the first choice after Play.
func _build_mode_screen(root: Control) -> Control:
	var parts: Array = UIKit.screen_card(root, "Choose a Mode", "", 500, func(): _show("main"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts[1].add_child(row)
	var free := _option_card("Freestyle", "EVERY MAP  ·  NO TIMER", "Fly where you like: a derelict steelworks, a port city at sunset, a construction site, mountains, a car park. The race tracks are open too - without the clock.", UIKit.LOGO_GROUND, "Choose a map")
	free.set_meta("default_focus", true)
	free.pressed.connect(func():
		Settings.game_mode = Settings.MODE_FREESTYLE
		_show("map"))
	row.add_child(free)
	var race := _option_card("Race", "RACE TRACKS  ·  LAP TIMER  ·  PERSONAL BESTS", "Timed laps through the gates, a ghost of your best lap to chase, and your personal best per track and drone - saved, so it's waiting next time.", UIKit.LOGO_SKY, "Choose a track")
	race.pressed.connect(func():
		Settings.game_mode = Settings.MODE_RACE
		_show("map"))
	row.add_child(race)
	return parts[0]

var _map_grid: GridContainer
var _map_title: Label
var _map_tier: String = "All"
var _map_filters: HBoxContainer

func _build_map_screen(root: Control) -> Control:
	var parts: Array = UIKit.screen_card(root, "Choose a Map", "", 860, func(): _show("mode"), 1480)
	_map_title = _find_label(parts[0], "Choose a Map")
	var content: VBoxContainer = parts[1]
	# Filter by performance tier - so a pilot on a weak laptop can see at
	# a glance what will run well.
	var filters := HBoxContainer.new()
	_map_filters = filters
	filters.add_theme_constant_override("separation", 8)
	content.add_child(filters)
	var group := ButtonGroup.new()
	var grid := GridContainer.new()
	_map_grid = grid
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	for f in ["All", "Low", "Medium", "High"]:
		var b := UIKit.button(f if f == "All" else f + " performance", "", 44)
		b.toggle_mode = true
		b.button_group = group
		b.button_pressed = f == "All"
		b.add_theme_stylebox_override("pressed", UIKit.box(UIKit.LOGO_SKY, UIKit.LOGO_SKY, 12))
		b.add_theme_color_override("font_pressed_color", Color.WHITE)
		var tier: String = f
		b.pressed.connect(func():
			_map_tier = tier
			_refresh_maps())
		filters.add_child(b)
	var hint := Label.new()
	hint.theme_type_variation = "Small"
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	hint.text = "Your graphics setting suits %s maps" % MapCatalog.recommended_tier()
	filters.add_child(hint)
	UIKit.gap(content, 4)
	content.add_child(grid)
	for m in MapCatalog.available():
		var card := _map_card(m)
		grid.add_child(card)
		var scene: String = m.scene
		var map_name: String = m.name
		card.pressed.connect(func():
			# Race mode: a race map opens its track list first; freestyle
			# flies track 1's gates (as obstacles).
			if Settings.game_mode == Settings.MODE_RACE and MapCatalog.is_race(m):
				_open_tracks(m)
				return
			Settings.race_track = 1
			SceneLoader.goto(scene, map_name))
	return parts[0]

## Shows the maps of the current mode (Race: race tracks only, with the
## pilot's personal bests) and tier filter.
func _refresh_maps() -> void:
	var race: bool = Settings.game_mode == Settings.MODE_RACE
	if _map_title:
		_map_title.text = "Race - Choose a Track" if race else "Freestyle - Choose a Map"
	var first: bool = true
	for card in _map_grid.get_children():
		var m: Dictionary = card.get_meta("map")
		card.visible = (not race or MapCatalog.is_race(m)) and (_map_tier == "All" or m.tier == _map_tier)
		card.remove_meta("default_focus")
		if card.visible and first:
			card.set_meta("default_focus", true)
			first = false
		var rec: Label = card.get_meta("record_label")
		rec.visible = race
		if race:
			rec.text = _records_text(m.id)

## The map card's race line: how many of its tracks have a personal best.
func _records_text(map_id: String) -> String:
	var tl: Array = RaceCourse.track_list(map_id)
	var done: int = 0
	for t in range(1, tl.size() + 1):
		if not RaceCourse.records(map_id, t).is_empty():
			done += 1
	if done == 0:
		return "%d tracks - no lap yet" % tl.size()
	return "%d tracks - personal best on %d" % [tl.size(), done]

# --- the track list (Race mode) -----------------------------------------------

var _tracks_grid: GridContainer
var _tracks_title: Label

func _build_tracks_screen(root: Control) -> Control:
	var parts: Array = UIKit.screen_card(root, "Choose a Track", "", 860, func(): _show("map"), 1480)
	_tracks_title = _find_label(parts[0], "Choose a Track")
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	grid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parts[1].add_child(grid)
	_tracks_grid = grid
	return parts[0]

## A race map's tracks: one card each - name, difficulty badge, a
## top-down sketch, gates / lap length / laps, and your best with the
## selected drone. Pressing one flies that track.
func _open_tracks(m: Dictionary) -> void:
	_tracks_title.text = "%s - Choose a Track" % m.name
	for c in _tracks_grid.get_children():
		c.queue_free()
	var tl: Array = RaceCourse.track_list(m.id)
	for i in range(tl.size()):
		var card := _track_card(m, i + 1, tl[i])
		_tracks_grid.add_child(card)
		if i == 0:
			card.set_meta("default_focus", true)
	_show("tracks")

func _track_card(m: Dictionary, t: int, tr: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "CardButton"
	b.custom_minimum_size = Vector2(440, 250)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("find_text", "track %d" % t)
	# The selected card: a bright edge, clear at a glance.
	var sel := UIKit.card_box(UIKit.LINK, UIKit.BOX_HOVER, 3)
	b.add_theme_stylebox_override("focus", sel)
	var pad := MarginContainer.new()
	pad.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		pad.add_theme_constant_override("margin_" + side, 18)
	b.add_child(pad)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	pad.add_child(box)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	box.add_child(head)
	var n := Label.new()
	n.text = tr.name
	n.theme_type_variation = "Title"
	n.add_theme_font_size_override("font_size", 26)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(n)
	head.add_child(UIKit.level_badge(tr.get("level", "easy"), 15))
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(body)
	var shape: Dictionary = RaceCourse.track_shape(m.id, t)
	body.add_child(_track_sketch(shape))
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(info)
	var facts := Label.new()
	facts.theme_type_variation = "Small"
	facts.add_theme_color_override("font_color", UIKit.MUTED)
	facts.text = "%d gates\n≈ %d m a lap\n%d laps" % [RaceCourse.gate_count(tr.calls), int(roundf(float(shape.get("length", 0.0)) / 10.0) * 10), RaceCourse.LAPS]
	info.add_child(facts)
	var gap := Control.new()
	gap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	info.add_child(gap)
	var me: String = Settings.selected_drone
	var bd: Dictionary = RaceCourse.boards(m.id, t)
	var r: Dictionary = RaceCourse.records(m.id, t)
	var st: Array = RaceCourse.stats(m.id, t).get(me, [0, 0])
	var who := Label.new()
	who.text = "YOUR BEST  ·  %s" % Drone.PROFILES[me].display.name.to_upper()
	who.add_theme_font_size_override("font_size", 12)
	who.add_theme_color_override("font_color", UIKit.MUTED_LIGHT)
	info.add_child(who)
	var best := Label.new()
	best.add_theme_font_override("font", UIKit.oswald())
	var race_best: bool = bd.has(me) and not bd[me].is_empty()
	if race_best:
		best.text = RaceCourse._fmt(bd[me][0][0])
		best.add_theme_font_size_override("font_size", 30)
		best.add_theme_color_override("font_color", UIKit.TEXT)
	else:
		best.text = "Not flown yet"
		best.add_theme_font_size_override("font_size", 22)
		best.add_theme_color_override("font_color", UIKit.MUTED_LIGHT)
	info.add_child(best)
	var more: Array[String] = []
	if r.has(me):
		more.append("Best lap %s" % RaceCourse._fmt(r[me][0]))
	if int(st[1]) > 0:
		more.append("%d %s" % [int(st[1]), "finish" if int(st[1]) == 1 else "finishes"])
	if not more.is_empty():
		var ml := Label.new()
		ml.theme_type_variation = "Small"
		ml.add_theme_color_override("font_color", UIKit.MUTED)
		ml.text = "  ·  ".join(more)
		info.add_child(ml)
	for c in [pad, box, head, n, body, info, facts, gap, who, best]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fit := func() -> void:
		b.custom_minimum_size.y = maxf(250.0, pad.get_combined_minimum_size().y + 4.0)
	pad.minimum_size_changed.connect(fit)
	var scene: String = m.scene
	var label: String = "%s - %s" % [m.name, tr.name]
	b.pressed.connect(func():
		Settings.race_track = t
		SceneLoader.goto(scene, label))
	return b

## A track from above: the racing line, a tick across it at every gate,
## START as a chequered square with an arrow the way the lap goes.
func _track_sketch(shape: Dictionary) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(190, 140)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(func():
		c.draw_rect(Rect2(Vector2.ZERO, c.size), Color(1, 1, 1, 0.04))
		if shape.is_empty():
			return
		var pts: PackedVector2Array = shape.pts
		var lo := Vector2(INF, INF)
		var hi := Vector2(-INF, -INF)
		for p in pts:
			lo = lo.min(p)
			hi = hi.max(p)
		var pad: float = 14.0
		var sc: float = minf((c.size.x - 2 * pad) / maxf(hi.x - lo.x, 1.0), (c.size.y - 2 * pad) / maxf(hi.y - lo.y, 1.0))
		var off: Vector2 = (c.size - (hi - lo) * sc) * 0.5
		var to := func(p: Vector2) -> Vector2: return off + (p - lo) * sc
		var line := PackedVector2Array()
		for p in pts:
			line.append(to.call(p))
		c.draw_polyline(line, Color(UIKit.ACCENT, 0.9), 2.0, true)
		var gs: Array = shape.gates
		for i in range(gs.size()):
			var at: Vector2 = to.call(gs[i][0])
			var d: Vector2 = gs[i][1]
			if d.length() < 0.3: # a dive gate: a dot
				c.draw_circle(at, 2.5, UIKit.TEXT)
				continue
			var n: Vector2 = d.normalized().orthogonal() * 5.0
			c.draw_line(at - n, at + n, UIKit.TEXT, 2.0, true)
		# START: chequered, and an arrow along the way through it.
		var s: Vector2 = to.call(gs[0][0])
		var f: Vector2 = (gs[0][1] as Vector2).normalized()
		for k in range(4):
			var q: Vector2 = Vector2(k % 2, k / 2) * 4.0 - Vector2(4, 4)
			c.draw_rect(Rect2(s + q, Vector2(4, 4)), Color.WHITE if (k == 0 or k == 3) else Color(0.1, 0.1, 0.1))
		var tip: Vector2 = s + f * 16.0
		c.draw_line(s + f * 6.0, tip, UIKit.GOLD, 2.0, true)
		c.draw_colored_polygon(PackedVector2Array([tip + f * 5.0, tip + f.orthogonal() * 4.0, tip - f.orthogonal() * 4.0]), UIKit.GOLD))
	return c

func _find_label(n: Node, text: String) -> Label:
	if n is Label and (n as Label).text == text:
		return n
	for c in n.get_children():
		var f: Label = _find_label(c, text)
		if f:
			return f
	return null

## One map: its preview picture, name, tier badge + tags, text, and (in
## Race mode) the pilot's personal bests.
func _map_card(m: Dictionary) -> Button:
	var b := Button.new()
	b.theme_type_variation = "CardButton"
	b.custom_minimum_size = Vector2(440, 380)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.set_meta("find_text", m.name)
	b.set_meta("tier", m.tier)
	b.set_meta("map", m)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 2
	box.offset_top = 2
	box.offset_right = -2
	box.offset_bottom = -16
	box.add_theme_constant_override("separation", 8)
	b.add_child(box)
	var pic := TextureRect.new()
	pic.custom_minimum_size = Vector2(0, 210)
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var path: String = "res://images/maps/%s.jpg" % m.id
	if ResourceLoader.exists(path):
		pic.texture = load(path)
	box.add_child(pic)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	var pad := MarginContainer.new()
	pad.add_theme_constant_override("margin_left", 20)
	pad.add_theme_constant_override("margin_right", 20)
	pad.size_flags_vertical = Control.SIZE_EXPAND_FILL
	pad.add_child(inner)
	box.add_child(pad)
	var bar := ColorRect.new()
	bar.color = m.color
	bar.custom_minimum_size = Vector2(0, 4)
	box.add_child(bar)
	box.move_child(bar, 1)
	var t := Label.new()
	t.text = m.name
	t.theme_type_variation = "Title"
	t.add_theme_font_size_override("font_size", 26)
	inner.add_child(t)
	# Tags wrap onto a second line rather than run off the card's edge.
	var tags := HFlowContainer.new()
	tags.add_theme_constant_override("h_separation", 8)
	tags.add_theme_constant_override("v_separation", 6)
	inner.add_child(tags)
	var tier_color: Color = MapCatalog.TIER_COLORS[m.tier]
	tags.add_child(_pill(m.tier + " performance", tier_color))
	tags.add_child(_pill("Indoor" if m.get("indoor", false) else "Outdoor", UIKit.MUTED_LIGHT))
	if MapCatalog.is_race(m):
		tags.add_child(_pill("Race track", UIKit.LINK))
	if m.drone != "any":
		tags.add_child(_pill(Drone.PROFILES[m.drone].display.name + " only", UIKit.MUTED_LIGHT))
	var d := Label.new()
	d.text = m.text
	d.theme_type_variation = "Small"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.size_flags_vertical = Control.SIZE_EXPAND_FILL
	inner.add_child(d)
	var rec := Label.new()
	rec.add_theme_color_override("font_color", UIKit.ACCENT)
	rec.add_theme_font_size_override("font_size", 16)
	rec.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inner.add_child(rec)
	b.set_meta("record_label", rec)
	for c in [box, pic, pad, inner, bar, t, tags, d, rec]:
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A Button doesn't grow with its children: size the card to whatever
	# its content needs (wrapped text, the personal-best lines), so
	# nothing is ever cut off at the bottom - the grid row then takes the
	# tallest card's height.
	var fit := func() -> void:
		b.custom_minimum_size.y = maxf(380.0, box.get_combined_minimum_size().y + 20.0)
	box.minimum_size_changed.connect(fit)
	box.resized.connect(fit)
	return b

func _pill(text: String, color: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(color, 0.16), color, 999, 1, Vector4(10, 2, 10, 2)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p
