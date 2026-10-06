class_name UpdatesScreen
extends RefCounted

## The menu's Updates screen: installed and latest version, Check now,
## Download (opens the release page), the "Check for updates" switch, and
## "What's new" (the notes of the version being run - shipped in
## Changelog, so it works offline - and, when newer, of the latest release).

var screen: Control
var _updater: Updater
var _installed: Label
var _latest: Label
var _status: Label
var _download: Button
var _check: Button
var _notes: VBoxContainer

func build(root: Control, updater: Updater, on_back: Callable) -> Control:
	_updater = updater
	var parts: Array = UIKit.screen_card(root, "Updates", "", 860, on_back, 900)
	screen = parts[0]
	var c: VBoxContainer = parts[1]
	c.add_theme_constant_override("separation", 8)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 4)
	c.add_child(grid)
	grid.add_child(_dim("Installed version"))
	_installed = Label.new()
	grid.add_child(_installed)
	grid.add_child(_dim("Latest release"))
	_latest = Label.new()
	grid.add_child(_latest)
	_status = Label.new()
	_status.theme_type_variation = "Small"
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_status)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	_check = UIKit.button("Check now", "", 48)
	_check.custom_minimum_size.x = 170
	_check.set_meta("default_focus", true)
	_check.pressed.connect(func():
		_updater.check_now()
		refresh())
	row.add_child(_check)
	_download = UIKit.button("Download", "PrimaryButton", 48)
	_download.custom_minimum_size.x = 170
	_download.pressed.connect(func(): OS.shell_open(Updater.latest.get("url", Updater.RELEASES_PAGE) if not Updater.latest.is_empty() else Updater.RELEASES_PAGE))
	row.add_child(_download)

	UIKit.toggle(c, "Check for updates when the game starts", Settings.check_updates, func(v: bool): Settings.check_updates = v)
	var hint := Label.new()
	hint.theme_type_variation = "Small"
	hint.text = "One small request to GitHub, at most once a day. You can keep playing any older version - nothing here forces an update."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(hint)
	c.add_child(HSeparator.new())
	_notes = VBoxContainer.new()
	_notes.add_theme_constant_override("separation", 6)
	c.add_child(_notes)
	_updater.finished.connect(refresh)
	return screen

func _dim(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.theme_type_variation = "Muted"
	return l

## Called every time the screen opens and when a check finishes.
func refresh() -> void:
	if screen == null:
		return
	var cur: String = Updater.current_version()
	_installed.text = cur
	var newer: bool = Updater.newer_available()
	if Updater.latest.is_empty():
		_latest.text = "unknown"
	else:
		_latest.text = Updater.latest.version + ("   (newer - available to download)" if newer else "   (you are up to date)")
	_latest.add_theme_color_override("font_color", UIKit.ACCENT if newer else UIKit.TEXT)
	match Updater.status:
		"checking":
			_status.text = "Checking..."
		"offline":
			_status.text = "Could not reach GitHub - no problem, just keep flying. Try again later."
		_:
			_status.text = ""
	_check.disabled = Updater.status == "checking"
	_download.text = "Download %s" % Updater.latest.version if newer else "Releases page"
	_download.theme_type_variation = "PrimaryButton" if newer else ""
	for ch in _notes.get_children():
		ch.queue_free()
	if newer and Updater.latest.body != "":
		var h := Label.new()
		h.text = "WHAT'S NEW IN %s" % Updater.latest.version
		h.add_theme_font_override("font", UIKit.oswald())
		h.add_theme_color_override("font_color", UIKit.LINK)
		_notes.add_child(h)
		Updater.add_notes(_notes, Updater.latest.body)
		UIKit.gap(_notes, 10)
	var local: String = Changelog.notes_for(cur)
	var h2 := Label.new()
	h2.text = "WHAT'S NEW IN %s (INSTALLED)" % cur
	h2.add_theme_font_override("font", UIKit.oswald())
	h2.add_theme_color_override("font_color", UIKit.LINK)
	_notes.add_child(h2)
	if local == "":
		var none := Label.new()
		none.text = "No notes for this build."
		none.theme_type_variation = "Muted"
		_notes.add_child(none)
	else:
		Updater.add_notes(_notes, local)
	Updater.mark_seen()
