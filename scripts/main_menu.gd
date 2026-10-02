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
const BACK_TARGET := {"mode": "main", "map": "mode", "about": "main"}
const WEBSITE := "https://statichorizonfpv.com/"

var _settings: SettingsScreens

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
	Engine.max_fps = MENU_FPS

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
	_screens["about"] = _build_about_screen(root)
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
	Engine.max_fps = Settings.max_fps

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
	var sky_c := Vector2(w * 0.22, -h * 0.25)
	var ground_c := Vector2(w * 0.85, h * 1.35)
	for y in range(h):
		for x in range(w):
			var p := Vector2(x, y)
			var sky: float = clampf(1.0 - p.distance_to(sky_c) / (w * 0.6), 0.0, 1.0)
			var ground: float = clampf(1.0 - p.distance_to(ground_c) / (w * 0.55), 0.0, 1.0)
			var c: Color = UIKit.BG.lerp(UIKit.LOGO_SKY, sky * sky * 0.22).lerp(UIKit.LOGO_GROUND, ground * ground * 0.16)
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

# --- Main screen -------------------------------------------------------------

func _build_main_screen(root: Control) -> Control:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 80)
	center.add_child(row)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(600, 0)
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 14)
	row.add_child(left)

	left.add_child(UIKit.eyebrow("FREE  ·  OPEN SOURCE  ·  FPV SIMULATOR"))

	var brand := HBoxContainer.new()
	brand.add_theme_constant_override("separation", 18)
	left.add_child(brand)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(96, 96)
	logo.draw.connect(func(): _draw_logo(logo))
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
	left.add_child(subtitle)

	UIKit.gap(left, 18)
	var play := UIKit.button("Play", "PrimaryButton", 68)
	play.pressed.connect(func(): _show("mode"))
	play.set_meta("default_focus", true)
	left.add_child(play)
	var settings := UIKit.button("Settings", "", 60)
	settings.pressed.connect(func(): _show("settings"))
	left.add_child(settings)
	var about := UIKit.button("About", "", 52)
	about.pressed.connect(func(): _show("about"))
	left.add_child(about)
	var quit := UIKit.button("Quit", "GhostButton", 52)
	quit.pressed.connect(func(): get_tree().quit())
	left.add_child(quit)

	UIKit.gap(left, 10)
	var hint := Label.new()
	hint.text = "Radio in USB joystick mode, or keyboard: W/A/S/D, Q/E, Shift/Ctrl"
	hint.theme_type_variation = "Small"
	left.add_child(hint)

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	# Fixed width: switching drones must not resize the card (and shift
	# the whole screen) just because one description is longer.
	card.custom_minimum_size = Vector2(620, 0)
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
	_refresh_preview_labels()
	return center

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

## The real logo mark from the companion website project (images/favicon.svg
## and index.html's .hz-instrument-icon): an artificial horizon - the
## instrument that tells a pilot which way is up when everything else is
## spinning. A circle split sky/ground by a horizon line, an outer ring,
## a center dot, and two flanking "wing" dashes, same as a real attitude
## indicator, drawn with primitives in the dark-mode brand colors.
func _draw_logo(c: Control) -> void:
	var center: Vector2 = c.size * 0.5
	var r: float = min(c.size.x, c.size.y) * 0.5 - 3.0
	c.draw_circle(center, r, UIKit.LOGO_SKY)
	var ground_points := PackedVector2Array()
	var steps := 24
	for i in range(steps + 1):
		var a: float = PI * float(i) / float(steps) # 0..PI sweeps the lower half in screen space
		ground_points.append(center + Vector2(cos(a), sin(a)) * r)
	c.draw_colored_polygon(ground_points, UIKit.LOGO_GROUND)
	c.draw_arc(center, r, 0.0, TAU, 48, UIKit.LOGO_INK, 2.0, true)
	c.draw_line(center - Vector2(r - 2.0, 0), center + Vector2(r - 2.0, 0), UIKit.LOGO_INK, 1.8)
	c.draw_circle(center, 3.2, UIKit.LOGO_INK)
	var wing_len: float = r * 0.42
	var wing_gap: float = r * 0.3
	c.draw_line(center - Vector2(wing_gap + wing_len, 0), center - Vector2(wing_gap, 0), UIKit.LOGO_INK, 4.5)
	c.draw_line(center + Vector2(wing_gap, 0), center + Vector2(wing_gap + wing_len, 0), UIKit.LOGO_INK, 4.5)

## A tiny display-piece 3D scene rendered into a small viewport - whichever
## drone is currently selected (Settings.selected_drone), slowly
## turning. Only rendered while the main screen (its card) is visible. Kept deliberately small and simple (one
## light, a WorldEnvironment, a dozen primitives, no shadows) so it costs
## next to nothing next to the rest of this deliberately-flat 2D menu.
func _build_drone_preview(parent: Control) -> void:
	var container := SubViewportContainer.new()
	container.stretch = true
	container.custom_minimum_size = Vector2(360, 340)
	container.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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

func _refresh_preview_labels() -> void:
	var d: Dictionary = _drone_info(Settings.selected_drone)
	_preview_name.text = d.name
	_preview_tags.text = Settings.spec_tags(d.tags)
	_preview_text.text = d.text

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
	var parts: Array = UIKit.screen_card(root, "About", "", 760, func(): _show("main"))
	var content: VBoxContainer = parts[1]
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 18)
	content.add_child(head)
	var logo := Control.new()
	logo.custom_minimum_size = Vector2(72, 72)
	logo.draw.connect(func(): _draw_logo(logo))
	head.add_child(logo)
	var name_box := VBoxContainer.new()
	head.add_child(name_box)
	var name_label := Label.new()
	name_label.text = "Static Horizon FPV Simulator"
	name_label.theme_type_variation = "Title"
	name_box.add_child(name_label)
	var version := Label.new()
	version.text = "Version %s  ·  free and open source (MIT licence)" % ProjectSettings.get_setting("application/config/version", "dev")
	version.theme_type_variation = "Muted"
	name_box.add_child(version)

	var intro := Label.new()
	intro.text = "A free FPV drone simulator that runs on weak hardware and flies with your radio over USB. Twelve maps for freestyle and racing, three quads whose mass, thrust and drag are taken from real ones, and a flight controller modelled on Betaflight - a simulation, so close but never quite the real thing."
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
	var site := UIKit.button("Visit statichorizonfpv.com", "PrimaryButton", 56)
	site.pressed.connect(func(): OS.shell_open(WEBSITE))
	content.add_child(site)
	return parts[0]

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
		card.pressed.connect(func(): SceneLoader.goto(scene, map_name))
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

func _records_text(map_id: String) -> String:
	var r: Dictionary = RaceCourse.records(map_id)
	var bd: Dictionary = RaceCourse.boards(map_id)
	if r.is_empty() and bd.is_empty():
		return "No lap yet - set your first personal best"
	var lines: Array[String] = ["Personal best  (lap / 3-lap race)"]
	for id in Drone.PROFILE_ORDER:
		if r.has(id) or bd.has(id):
			var lap: String = RaceCourse._fmt(r[id][0]) if r.has(id) else "--"
			var race: String = RaceCourse._fmt(bd[id][0][0]) if bd.has(id) and not bd[id].is_empty() else "--"
			lines.append("%s   %s  /  %s" % [Drone.PROFILES[id].display.name, lap, race])
	return "\n".join(lines)

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
