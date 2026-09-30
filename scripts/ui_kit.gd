class_name UIKit
extends RefCounted

## The shared look and building blocks of every menu screen - the main
## menu, the in-game pause menu, and the Settings/Calibration screens
## both of them open. Colors are the companion website's dark theme
## (css/style.css, [data-theme="dark"]); see main_menu.gd for the
## design notes.

const BG := Color("#101216")
const BOX := Color("#1f2226")
const BOX_HOVER := Color("#272b31")
const BORDER := Color("#3c4550")
const TEXT := Color("#f5f6f7")
const MUTED := Color("#c1c9d1")
const MUTED_LIGHT := Color("#a8b0b8")
const ACCENT := Color("#8fb3ff")
const LINK := Color("#3ea6ff")
const LOGO_SKY := Color("#1f6fe0")
const LOGO_GROUND := Color("#e8551a")
const LOGO_INK := Color("#ffffff")

const CARD_WIDTH: float = 1180.0

static var _oswald_font: FontFile
static var _oswald: FontVariation
static var _theme: Theme

static func oswald() -> FontVariation:
	if _oswald == null:
		_oswald_font = load("res://fonts/Oswald-SemiBold.ttf")
		_oswald = FontVariation.new()
		_oswald.base_font = _oswald_font
	return _oswald

static func oswald_font() -> FontFile:
	oswald()
	return _oswald_font

## One theme instance shared by every screen (building it draws a few
## small icon images - no need to do that more than once).
static func theme() -> Theme:
	if _theme == null:
		_theme = make_theme()
	return _theme

static func box(bg: Color, border: Color, radius: int, border_w: int = 1, pad := Vector4(20, 12, 20, 12)) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	sb.content_margin_left = pad.x
	sb.content_margin_top = pad.y
	sb.content_margin_right = pad.z
	sb.content_margin_bottom = pad.w
	sb.anti_aliasing = true
	return sb

static func make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 22
	t.set_color("font_color", "Label", TEXT)

	# Default buttons: website "box" surfaces with a thin border that
	# lights up in the accent color on hover/focus.
	t.set_font("font", "Button", oswald())
	t.set_font_size("font_size", "Button", 24)
	for state in ["font_color", "font_focus_color"]:
		t.set_color(state, "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_stylebox("normal", "Button", box(BOX, BORDER, 12))
	t.set_stylebox("hover", "Button", box(BOX_HOVER, ACCENT, 12))
	t.set_stylebox("pressed", "Button", box(BG, ACCENT, 12))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), LINK, 12, 2))
	t.set_stylebox("disabled", "Button", box(BOX, BORDER, 12))

	# Primary: the brand's sky blue, filled.
	t.set_type_variation("PrimaryButton", "Button")
	t.set_stylebox("normal", "PrimaryButton", box(LOGO_SKY, LOGO_SKY, 12))
	t.set_stylebox("hover", "PrimaryButton", box(LOGO_SKY.lightened(0.15), ACCENT, 12))
	t.set_stylebox("pressed", "PrimaryButton", box(LOGO_SKY.darkened(0.2), LOGO_SKY, 12))
	t.set_color("font_color", "PrimaryButton", Color.WHITE)
	t.set_color("font_hover_color", "PrimaryButton", Color.WHITE)

	# Ghost: text only, for Quit/Back.
	t.set_type_variation("GhostButton", "Button")
	var clear := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 12, 0)
	t.set_stylebox("normal", "GhostButton", clear)
	t.set_stylebox("hover", "GhostButton", box(Color(1, 1, 1, 0.05), Color(0, 0, 0, 0), 12, 0))
	t.set_stylebox("pressed", "GhostButton", clear)
	t.set_color("font_color", "GhostButton", MUTED)
	t.set_color("font_hover_color", "GhostButton", TEXT)

	# Option cards (drone/map choice) are big buttons too.
	t.set_type_variation("CardButton", "Button")
	# (No shadow: they sit inside a card, and the scroll area would clip it.)
	t.set_stylebox("normal", "CardButton", card_box(BORDER, BOX_HOVER.darkened(0.08), 1, false))
	t.set_stylebox("hover", "CardButton", card_box(ACCENT, BOX_HOVER, 1, false))
	t.set_stylebox("pressed", "CardButton", card_box(LINK, BG, 1, false))
	t.set_stylebox("focus", "CardButton", card_box(LINK, Color(0, 0, 0, 0), 2, false))

	t.set_type_variation("Card", "PanelContainer")
	t.set_stylebox("panel", "Card", card_box(BORDER))

	t.set_type_variation("Title", "Label")
	t.set_font("font", "Title", oswald())
	t.set_font_size("font_size", "Title", 40)
	t.set_type_variation("Heading", "Label")
	t.set_font("font", "Heading", oswald())
	t.set_font_size("font_size", "Heading", 26)
	t.set_color("font_color", "Heading", TEXT)
	t.set_type_variation("Muted", "Label")
	t.set_color("font_color", "Muted", MUTED)
	t.set_font_size("font_size", "Muted", 19)
	t.set_type_variation("Small", "Label")
	t.set_color("font_color", "Small", MUTED_LIGHT)
	t.set_font_size("font_size", "Small", 16)

	# Toggle switches and sliders in the site's link blue.
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", Color.WHITE)
	t.set_color("font_pressed_color", "CheckButton", TEXT)
	t.set_color("font_hover_pressed_color", "CheckButton", Color.WHITE)
	var row_pad := Vector4(0, 6, 0, 6)
	t.set_stylebox("normal", "CheckButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0, row_pad))
	t.set_stylebox("hover", "CheckButton", box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 8, 0, row_pad))
	t.set_stylebox("pressed", "CheckButton", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 8, 0, row_pad))
	t.set_stylebox("hover_pressed", "CheckButton", box(Color(1, 1, 1, 0.04), Color(0, 0, 0, 0), 8, 0, row_pad))
	t.set_stylebox("focus", "CheckButton", StyleBoxEmpty.new())
	t.set_icon("checked", "CheckButton", switch_icon(true))
	t.set_icon("unchecked", "CheckButton", switch_icon(false))

	var track_pad := Vector4(0, 4, 0, 4)
	t.set_stylebox("slider", "HSlider", box(BORDER, BORDER, 4, 0, track_pad))
	t.set_stylebox("grabber_area", "HSlider", box(LINK, LINK, 4, 0, track_pad))
	t.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, ACCENT, 4, 0, track_pad))
	t.set_icon("grabber", "HSlider", dot_icon(22, TEXT))
	t.set_icon("grabber_highlight", "HSlider", dot_icon(24, Color.WHITE))
	t.set_stylebox("focus", "HSlider", StyleBoxEmpty.new())

	var sep := StyleBoxLine.new()
	sep.color = BORDER
	sep.thickness = 1
	t.set_stylebox("separator", "HSeparator", sep)
	t.set_constant("separation", "HSeparator", 18)
	return t

static func card_box(border: Color, bg: Color = BOX, border_w: int = 1, shadow: bool = true) -> StyleBoxFlat:
	var sb := box(bg, border, 16, border_w, Vector4(28, 24, 28, 24))
	if shadow:
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 18
		sb.shadow_offset = Vector2(0, 8)
	return sb

## Toggle switch drawn into a small image (no image assets anywhere in
## this project): a pill track with a round knob, blue when on.
static func switch_icon(on: bool) -> ImageTexture:
	var w := 56
	var h := 30
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var track: Color = LOGO_SKY if on else BORDER
	var r: float = h * 0.5
	var knob_x: float = (w - r) if on else r
	for y in range(h):
		for x in range(w):
			var p := Vector2(x + 0.5, y + 0.5)
			var cx: float = clampf(p.x, r, w - r)
			if Vector2(p.x - cx, p.y - r).length() <= r:
				img.set_pixel(x, y, track)
			if Vector2(p.x - knob_x, p.y - r).length() <= r - 3.5:
				img.set_pixel(x, y, Color.WHITE)
	return ImageTexture.create_from_image(img)

static func dot_icon(d: int, color: Color) -> ImageTexture:
	var img := Image.create(d, d, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var r: float = d * 0.5
	for y in range(d):
		for x in range(d):
			var dist: float = Vector2(x + 0.5 - r, y + 0.5 - r).length()
			if dist <= r - 1.0:
				img.set_pixel(x, y, color)
			elif dist <= r:
				img.set_pixel(x, y, Color(color, r - dist))
	return ImageTexture.create_from_image(img)

static func eyebrow(text: String) -> Control:
	var wrap := HBoxContainer.new()
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", box(BOX, BORDER, 999, 1, Vector4(14, 5, 14, 5)))
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", LINK)
	pill.add_child(l)
	wrap.add_child(pill)
	return wrap

static func button(text: String, variation: String, height: float) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, height)
	if variation != "":
		b.theme_type_variation = variation
	return b

static func gap(parent: Control, h: float) -> void:
	var s := Control.new()
	s.custom_minimum_size = Vector2(0, h)
	parent.add_child(s)

static func section(parent: Control, text: String) -> void:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", oswald())
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", LINK)
	parent.add_child(l)

static func toggle(parent: Control, label_text: String, initial: bool, on_change: Callable) -> CheckButton:
	var cb := CheckButton.new()
	cb.text = label_text
	cb.button_pressed = initial
	cb.toggled.connect(func(v: bool): on_change.call(v))
	parent.add_child(cb)
	return cb

## Label + value on one line, a full-width slider under it. Returns the
## value label.
static func slider(parent: Control, label_text: String, min_v: float, max_v: float, step: float, initial: float, on_change: Callable, suffix: String = "") -> Label:
	var head := HBoxContainer.new()
	parent.add_child(head)
	var lbl := Label.new()
	lbl.text = label_text
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(lbl)
	var value_lbl := Label.new()
	value_lbl.text = str(snapped(initial, step)) + suffix
	value_lbl.add_theme_color_override("font_color", ACCENT)
	head.add_child(value_lbl)

	var s := HSlider.new()
	s.min_value = min_v
	s.max_value = max_v
	s.step = step
	s.value = initial
	s.custom_minimum_size = Vector2(0, 30)
	parent.add_child(s)
	s.value_changed.connect(func(v: float):
		value_lbl.text = str(snapped(v, step)) + suffix
		on_change.call(v)
	)
	return value_lbl

## A fixed-size card screen: header (Back + title + "Esc to go back")
## outside the scroll area, so it can never be pushed off-screen by
## whatever the content grows to - the old Settings screen was a plain
## column taller than the window, with its Back button below the edge.
## Returns [screen root, content box].
static func screen_card(root: Control, title: String, subtitle: String, height: float, on_back: Callable, width: float = CARD_WIDTH) -> Array:
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(center)

	var card := PanelContainer.new()
	card.theme_type_variation = "Card"
	card.custom_minimum_size = Vector2(width, height)
	center.add_child(card)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	card.add_child(outer)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 16)
	outer.add_child(header)
	var back := button("‹  Back", "GhostButton", 48)
	back.custom_minimum_size = Vector2(130, 48)
	back.pressed.connect(on_back)
	header.add_child(back)
	var t := Label.new()
	t.text = title
	t.theme_type_variation = "Title"
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(t)
	var esc := Label.new()
	esc.text = "Esc to go back"
	esc.theme_type_variation = "Small"
	header.add_child(esc)

	if subtitle != "":
		var sub := Label.new()
		sub.text = subtitle
		sub.theme_type_variation = "Muted"
		outer.add_child(sub)
	outer.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	outer.add_child(scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 14)
	scroll.add_child(content)
	return [center, content]
