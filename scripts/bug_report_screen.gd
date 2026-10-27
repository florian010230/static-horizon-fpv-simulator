class_name BugReportScreen
extends RefCounted

## "Report a bug" (main menu corner and pause menu, user 2026-10-27): the
## player types what happened, and Send posts it with the game info shown
## underneath to the website's report worker, which mails it to us and
## keeps it in a D1 table. Nothing is sent before Send; the info list
## shows exactly what goes out, the reply address is optional. Never
## sends in --selftest/--dev-preview. Anything but 204 (offline, worker
## not set up, rate limit) shows a friendly line and the fallbacks: copy
## the text, write an email, or open a GitHub issue - no retry loop.

## Set when the website's worker exists (contract from the website
## session, 2026-10-27: POST JSON, header X-SH-Key, 204 = stored).
const REPORT_URL: String = ""
## Only keeps random bots out (the source is public, so is this).
const REPORT_KEY: String = ""
const EMAIL: String = "static.horizon.fpv@web.de"
const ISSUES_URL: String = "https://github.com/" + Updater.REPO + "/issues/new"
const MAX_TEXT: int = 4000
const TIMEOUT_SECONDS: float = 10.0

var screen: Control
var _text: TextEdit
var _email: LineEdit
var _info_lbl: Label
var _status: Label
var _send: Button
var _http: HTTPRequest
var _info: Dictionary = {}
var _with_info: CheckButton
## Sent even with the game info switched off.
const ALWAYS: Array[String] = ["v", "os"]

func build(root: Control, on_back: Callable) -> Control:
	var parts: Array = UIKit.screen_card(root, "Report a bug", "What went wrong? A sentence or two is enough.", 760, on_back, 860)
	screen = parts[0]
	var c: VBoxContainer = parts[1]
	_text = TextEdit.new()
	_text.placeholder_text = "e.g. On Steel Mill the drone fell through the floor of the big hall after a crash."
	_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_text.custom_minimum_size = Vector2(0, 140)
	_text.text_changed.connect(_on_text_changed)
	c.add_child(_text)
	var mail_row := HBoxContainer.new()
	mail_row.add_theme_constant_override("separation", 12)
	c.add_child(mail_row)
	var ml := Label.new()
	ml.text = "Your email (optional, only if you want an answer)"
	ml.theme_type_variation = "Small"
	mail_row.add_child(ml)
	_email = LineEdit.new()
	_email.max_length = 200
	_email.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mail_row.add_child(_email)
	# The game info is the player's choice: on by default, one switch off
	# (user, 2026-10-27). Version and system always go - the worker needs
	# them, and they say nothing about the player.
	_with_info = UIKit.toggle(c, "Send game info with the report (helps me find the bug)", true, func(_v: bool): _show_info())
	_info_lbl = Label.new()
	_info_lbl.theme_type_variation = "Small"
	_info_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	c.add_child(_info_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	c.add_child(row)
	_send = UIKit.button("Send", "PrimaryButton", 54)
	_send.custom_minimum_size.x = 180
	_send.pressed.connect(_on_send)
	row.add_child(_send)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)
	UIKit.section(c, "Other ways")
	var other := HBoxContainer.new()
	other.add_theme_constant_override("separation", 12)
	c.add_child(other)
	for spec in [["Copy report", _copy], ["Write an email", _mailto], ["GitHub issue", func(): OS.shell_open(ISSUES_URL)]]:
		var b := UIKit.button(spec[0], "", 46)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(spec[1])
		other.add_child(b)
	var note := Label.new()
	note.text = "Email: %s. GitHub issues are public and need an account." % EMAIL
	note.theme_type_variation = "Small"
	c.add_child(note)
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	_http.request_completed.connect(_on_done)
	screen.add_child(_http)
	return screen

## Called each time the screen opens: fresh game info, the text kept
## (a half-written report survives a look at the map).
func refresh() -> void:
	_info = collect_info()
	_show_info()
	_status.text = ""
	_send.disabled = _text.text.strip_edges() == ""

## What goes out with the report, as the player sees it.
func _show_info() -> void:
	var lines: Array[String] = []
	for k in _sent_info():
		lines.append("%s: %s" % [k, str(_info[k])])
	_info_lbl.text = ("Sent with it:   " if _with_info.button_pressed else "Only the game version and system are sent:   ") + "   ".join(lines)

func _sent_info() -> Dictionary:
	var out: Dictionary = {}
	for k in ["v", "os", "gpu", "map", "drone", "quality", "fps", "radio", "extra"]:
		if _info.has(k) and str(_info[k]) != "" and (_with_info.button_pressed or ALWAYS.has(k)):
			out[k] = _info[k]
	return out

## Version, system and where the player is - nothing personal.
static func collect_info() -> Dictionary:
	var scene: Node = Engine.get_main_loop().current_scene if Engine.get_main_loop() is SceneTree else null
	var m: Dictionary = MapCatalog.for_scene(scene.scene_file_path) if scene else {}
	var forced: String = MapCatalog.forced_drone(scene.scene_file_path) if scene else ""
	var os_name: String = {"Windows": "windows", "macOS": "macos", "Linux": "linux"}.get(OS.get_name(), OS.get_name().to_lower())
	var info: Dictionary = {
		"v": Updater.current_version(),
		"os": os_name,
		"gpu": RenderingServer.get_video_adapter_name().left(100),
		"map": m.get("id", "menu"),
		"drone": forced if forced != "" else Settings.selected_drone,
		"quality": Settings.QUALITY_NAMES[clampi(Settings.graphics_quality, 0, 2)],
		"radio": Input.get_joy_name(InputManager.joystick_device).left(60) if InputManager._joy_present() else "none",
		"extra": "window %s, render %.2f, look %d, fps limit %d, low-res %s" % [DisplayServer.window_get_size(), Settings.render_scale(Settings.graphics_quality), Settings.camera_look, Settings.max_fps, Settings.low_res_window],
	}
	if not m.is_empty():
		info["fps"] = int(round(Engine.get_frames_per_second()))
	return info

func _on_text_changed() -> void:
	if _text.text.length() > MAX_TEXT:
		_text.text = _text.text.left(MAX_TEXT)
		_text.set_caret_column(_text.get_line(_text.get_line_count() - 1).length())
		_text.set_caret_line(_text.get_line_count() - 1)
	_send.disabled = _text.text.strip_edges() == ""

func _on_send() -> void:
	if REPORT_URL == "" or Updater.is_test_run():
		_fail("Sending isn't available in this version. Please use one of the other ways below.")
		return
	var body: Dictionary = _sent_info()
	body["text"] = _text.text.strip_edges()
	body["email"] = _email.text.strip_edges()
	_send.disabled = true
	_status.text = "Sending..."
	_status.remove_theme_color_override("font_color")
	if _http.request(REPORT_URL, ["Content-Type: application/json", "X-SH-Key: " + REPORT_KEY, "User-Agent: StaticHorizonFPV/" + Updater.current_version()], HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		_fail("Couldn't send. Please try again later or use one of the other ways below.")

func _on_done(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and code == 204:
		_status.text = "Sent - thank you! I read every report."
		_status.add_theme_color_override("font_color", UIKit.ACCENT)
		_text.text = ""
		return
	if code == 429:
		_fail("Too many reports right now - please try again in a few minutes.")
	else:
		_fail("Couldn't send (%s). Please try again later or use one of the other ways below." % (str(code) if code > 0 else "no connection"))

func _fail(msg: String) -> void:
	_status.text = msg
	_status.add_theme_color_override("font_color", Color("#ffb86b"))
	_send.disabled = _text.text.strip_edges() == ""

## The report as plain text (clipboard / email body).
func _plain() -> String:
	var lines: Array[String] = [_text.text.strip_edges(), ""]
	var sent: Dictionary = _sent_info()
	for k in sent:
		lines.append("%s: %s" % [k, str(sent[k])])
	return "\n".join(lines)

func _copy() -> void:
	DisplayServer.clipboard_set(_plain())
	_status.text = "Copied - paste it into an email to %s." % EMAIL
	_status.remove_theme_color_override("font_color")

func _mailto() -> void:
	OS.shell_open("mailto:%s?subject=%s&body=%s" % [EMAIL, ("Static Horizon FPV %s bug" % Updater.current_version()).uri_encode(), _plain().uri_encode()])
