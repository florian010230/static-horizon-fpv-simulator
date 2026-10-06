class_name AchievementsScreen
extends RefCounted

## The menu's Achievements screen (a small, secondary entry): the simple
## achievements from Achievements and the gnomes found per map.

var screen: Control
var _body: VBoxContainer

func build(root: Control, on_back: Callable) -> Control:
	var parts: Array = UIKit.screen_card(root, "Achievements", "", 860, on_back, 900)
	screen = parts[0]
	_body = parts[1]
	_body.add_theme_constant_override("separation", 6)
	return screen

func refresh() -> void:
	for ch in _body.get_children():
		ch.queue_free()
	UIKit.section(_body, "Achievements")
	var list: Array = Achievements.list()
	var done: int = 0
	for a in list:
		if a.done:
			done += 1
		_row(a.name, a.text, a.progress, a.done)
	UIKit.gap(_body, 12)
	UIKit.section(_body, "Garden gnomes")
	var hint := Label.new()
	hint.text = "Garden gnomes hide on the maps. Fly through or close to one to find it."
	hint.theme_type_variation = "Small"
	_body.add_child(hint)
	var any: bool = false
	for m in MapCatalog.available():
		var t: int = MapCatalog.gnome_total(m.id)
		if t <= 0:
			continue
		any = true
		var f: int = Collectibles.found_count(m.id)
		_row(m.name, "", "%d/%d" % [f, t], f >= t)
	if not any:
		var l := Label.new()
		l.text = "No gnomes in this build yet."
		l.theme_type_variation = "Muted"
		_body.add_child(l)

func _row(title: String, text: String, progress: String, done: bool) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	_body.add_child(row)
	var dot := Control.new()
	dot.custom_minimum_size = Vector2(22, 30)
	dot.draw.connect(func():
		var c: Vector2 = Vector2(11, 15)
		if done:
			dot.draw_circle(c, 8, UIKit.LOGO_SKY)
			dot.draw_polyline(PackedVector2Array([Vector2(6.5, 15), Vector2(10, 18.5), Vector2(16, 11.5)]), Color.WHITE, 2.2, true)
		else:
			dot.draw_arc(c, 7.5, 0, TAU, 24, UIKit.BORDER, 2.0, true))
	row.add_child(dot)
	var t := Label.new()
	t.text = title
	t.add_theme_color_override("font_color", UIKit.TEXT if done else UIKit.MUTED)
	t.custom_minimum_size.x = 320
	row.add_child(t)
	var d := Label.new()
	d.text = text
	d.theme_type_variation = "Small"
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(d)
	if progress != "":
		var p := Label.new()
		p.text = progress
		p.add_theme_color_override("font_color", UIKit.ACCENT if done else UIKit.MUTED_LIGHT)
		row.add_child(p)
