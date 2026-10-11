extends RefCounted

## Race mode's screen parts, built for ui.gd: the finish card and the slim
## race bar at the bottom. Same family as the menus (UIKit palette, Oswald)
## on dark see-through panels, so the world stays visible around them. No
## animation: the card simply appears.

const PANEL_BG := Color(0.045, 0.06, 0.085, 0.86)
const GOOD := Color(0.45, 1.0, 0.55)
const BAD := Color(1.0, 0.47, 0.4)
const MEDALS: Array[Color] = [UIKit.GOLD, UIKit.SILVER, UIKit.BRONZE]
const CUT: float = 30.0

static func label(text: String, size: int, colour: Color = UIKit.TEXT, osw: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	if osw:
		l.add_theme_font_override("font", UIKit.oswald())
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", colour)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

## Small caps heading: upper case, spaced, muted.
static func caps(text: String, colour: Color = UIKit.MUTED_LIGHT, size: int = 14) -> Label:
	var l := label(text.to_upper(), size, colour)
	var f := FontVariation.new()
	f.base_font = UIKit.oswald_font()
	f.spacing_glyph = 2
	l.add_theme_font_override("font", f)
	return l

## The finish card. d: track, level, drone, total, prev_best (-1: first
## finish), laps (Array), top (up to 3 of [total, best lap, date]), you
## (your race's place in top, -1 if not in it), record (new track record:
## fastest race on this track by any drone), new_best (your best with this
## drone, not a track record), close_hint. style "slash": the top 3 as
## rows; "podium": as three tiles, 2-1-3.
static func finish_card(d: Dictionary, style: String = "slash") -> Control:
	var accent: Color = UIKit.GOLD if d.record else UIKit.ACCENT
	var card := MarginContainer.new()
	card.name = "FinishCard"
	card.theme = UIKit.theme()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.custom_minimum_size = Vector2(500 if style == "slash" else 520, 0)
	card.add_theme_constant_override("margin_left", 34)
	card.add_theme_constant_override("margin_right", 30)
	card.add_theme_constant_override("margin_top", 22)
	card.add_theme_constant_override("margin_bottom", 18)
	# A dark panel with the top right corner cut off, a thin accent edge
	# down the left and along the cut.
	card.draw.connect(func():
		var w: float = card.size.x
		var h: float = card.size.y
		var poly := PackedVector2Array([Vector2(0, 0), Vector2(w - CUT, 0), Vector2(w, CUT), Vector2(w, h), Vector2(0, h)])
		card.draw_colored_polygon(poly, PANEL_BG)
		var edge := poly.duplicate()
		edge.append(poly[0])
		card.draw_polyline(edge, Color(1, 1, 1, 0.09), 1.5, true)
		card.draw_rect(Rect2(0, 0, 5, h), accent)
		card.draw_line(Vector2(w - CUT, 0), Vector2(w, CUT), accent, 3.0, true))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	card.add_child(box)
	var centre: bool = style == "podium"
	if d.record:
		var banner := PanelContainer.new()
		banner.add_theme_stylebox_override("panel", UIKit.box(UIKit.GOLD, UIKit.GOLD, 4, 0, Vector4(14, 4, 14, 4)))
		var bl := caps("New track record", Color(0.1, 0.08, 0.02), 24)
		bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		banner.add_child(bl)
		box.add_child(banner)
		UIKit.gap(box, 6)
	# Head: FINISH, the track and its difficulty, the drone.
	var eyebrow := HBoxContainer.new()
	eyebrow.add_child(caps("Finish", accent))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	eyebrow.add_child(sp)
	eyebrow.add_child(caps(d.drone, UIKit.MUTED_LIGHT))
	box.add_child(eyebrow)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 12)
	if centre:
		head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_child(label(d.track, 30))
	head.add_child(UIKit.level_badge(d.level, 13))
	box.add_child(head)
	# The time, big; NEW BEST and the delta to your best beside it.
	var trow := HBoxContainer.new()
	trow.add_theme_constant_override("separation", 16)
	if centre:
		trow.alignment = BoxContainer.ALIGNMENT_CENTER
	var tl := label(RaceCourse._fmt(d.total), 76, UIKit.GOLD if d.record else UIKit.TEXT)
	tl.name = "Time"
	tl.add_theme_constant_override("line_spacing", -12)
	trow.add_child(tl)
	var side := VBoxContainer.new()
	side.alignment = BoxContainer.ALIGNMENT_CENTER
	side.add_theme_constant_override("separation", 4)
	if d.new_best:
		var nb := UIKit.pill("NEW BEST", GOOD, 15, true)
		nb.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		side.add_child(nb)
	var pb: float = d.prev_best
	if pb < 0.0:
		side.add_child(label("First finish here", 18, UIKit.MUTED))
	else:
		var dl: float = d.total - pb
		side.add_child(label("%s%.2f" % ["+" if dl >= 0.0 else "-", absf(dl)], 26, BAD if dl > 0.0 else GOOD))
		side.add_child(caps("vs your best", UIKit.MUTED_LIGHT, 12))
	trow.add_child(side)
	box.add_child(trow)
	# The laps, small; the faster one brighter.
	var laps := HBoxContainer.new()
	laps.add_theme_constant_override("separation", 22)
	if centre:
		laps.alignment = BoxContainer.ALIGNMENT_CENTER
	var lap_t: Array = d.laps
	for i in range(lap_t.size()):
		var fast: bool = lap_t[i] == lap_t.min() and lap_t.size() > 1
		var lr := HBoxContainer.new()
		lr.add_theme_constant_override("separation", 6)
		lr.add_child(caps("Lap %d" % (i + 1), UIKit.MUTED_LIGHT, 13))
		lr.add_child(label(RaceCourse._fmt(lap_t[i]), 18, UIKit.TEXT if fast else UIKit.MUTED))
		laps.add_child(lr)
	box.add_child(laps)
	UIKit.gap(box, 8)
	var rule := ColorRect.new()
	rule.color = Color(1, 1, 1, 0.1)
	rule.custom_minimum_size = Vector2(0, 1)
	box.add_child(rule)
	UIKit.gap(box, 4)
	var top_head := caps("Your top 3  ·  this track", UIKit.MUTED_LIGHT, 13)
	if centre:
		top_head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(top_head)
	var top: Array = d.top
	if style == "podium":
		box.add_child(_podium(top, int(d.you), accent))
	else:
		for i in range(top.size()):
			box.add_child(_row(i, top[i], i == int(d.you), accent))
	if int(d.you) < 0:
		var nr := label("This race isn't in your top 3", 15, UIKit.MUTED_LIGHT, false)
		if centre:
			nr.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		box.add_child(nr)
	UIKit.gap(box, 8)
	var hint := label(d.close_hint, 13, UIKit.MUTED_LIGHT, false)
	hint.name = "Hint"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER if centre else HORIZONTAL_ALIGNMENT_LEFT
	box.add_child(hint)
	return card

## A place number on a medal-coloured disc.
static func _medal(i: int, size: float) -> Control:
	var m := Control.new()
	m.custom_minimum_size = Vector2(size, size)
	m.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.draw.connect(func():
		var c: Vector2 = m.size * 0.5
		m.draw_circle(c, size * 0.5, MEDALS[i])
		var f: Font = UIKit.oswald()
		var fs: int = int(size * 0.62)
		var tw: float = f.get_string_size(str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		m.draw_string(f, Vector2(c.x - tw * 0.5, c.y + fs * 0.36), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(0.08, 0.08, 0.09)))
	return m

static func _row(i: int, e: Array, you: bool, accent: Color) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIKit.box(Color(accent, 0.16) if you else Color(1, 1, 1, 0.0), Color(accent, 0.5) if you else Color(0, 0, 0, 0), 6, 1, Vector4(8, 3, 10, 3)))
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 12)
	p.add_child(r)
	r.add_child(_medal(i, 26))
	r.add_child(label(RaceCourse._fmt(e[0]), 24, UIKit.TEXT if you or i == 0 else UIKit.MUTED))
	if you:
		r.add_child(UIKit.pill("YOU", accent, 12, true))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(sp)
	var dt := label(str(e[2]), 14, UIKit.MUTED_LIGHT, false)
	dt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(dt)
	return p

## Three tiles, second - first - third, the winner's a little taller.
static func _podium(top: Array, you: int, accent: Color) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)
	for i in [1, 0, 2]:
		var tile := PanelContainer.new()
		tile.custom_minimum_size = Vector2(138, 112 if i == 0 else 94)
		tile.size_flags_vertical = Control.SIZE_SHRINK_END
		var sb := UIKit.box(Color(accent, 0.18) if i == you else Color(1, 1, 1, 0.05), Color(accent, 0.6) if i == you else Color(1, 1, 1, 0.08), 6, 1, Vector4(8, 8, 8, 8))
		sb.border_width_top = 4
		sb.border_color = MEDALS[i] if i != you else accent
		tile.add_theme_stylebox_override("panel", sb)
		var v := VBoxContainer.new()
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_theme_constant_override("separation", 0)
		tile.add_child(v)
		var place := caps(["1st", "2nd", "3rd"][i], MEDALS[i], 15)
		place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(place)
		var has: bool = i < top.size()
		var t := label(RaceCourse._fmt(top[i][0]) if has else "--", 24, UIKit.TEXT if has else UIKit.MUTED_LIGHT)
		t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(t)
		var sub := label(("YOU" if i == you else str(top[i][2])) if has else "", 13, accent if i == you else UIKit.MUTED_LIGHT, i == you)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		v.add_child(sub)
		row.add_child(tile)
	return row
