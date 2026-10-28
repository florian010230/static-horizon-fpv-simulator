# (No class_name: an in-game update pack can't add global classes -
# users preload this file. 2026-10-27, 0.11.1.)
extends RefCounted

## "Report a bug" (main menu corner, user 2026-10-27; not in the pause menu since 2026-10-28): the
## player types what happened, and Send posts it with the game info shown
## underneath to the website's report worker, which mails it to us and
## keeps it in a D1 table. Nothing is sent before Send; the info list
## shows exactly what goes out, the reply address is optional. Never
## sends in --selftest/--dev-preview. Anything but 204 (offline, worker
## not set up, rate limit) shows a friendly line and the fallbacks: copy
## the text, write an email, or open a GitHub issue - no retry loop.

## The website's report worker (contract from the website session,
## 2026-10-27/28: POST JSON, header X-SH-Key, 204 = stored; 429 with JSON
## {"error": "wait"|"limit"|"full", "retry_after_seconds": n} and a
## Retry-After header).
const REPORT_URL: String = "https://statichorizon-report.florian-chri-schmidt.workers.dev/"
## The key only keeps random bots out. It is not in git: tools copy it
## into secrets/ (gitignored) and the export ships it (include_filter).
## No key file (a fresh checkout) = no Send button.
const KEY_PATH: String = "res://secrets/report_key.txt"
## The last server cooldown, kept so a restart doesn't skip it.
const STATE_PATH: String = "user://bug_report.cfg"
## After a report the worker wants at least a minute before the next.
const MIN_GAP_SECONDS: int = 60
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
var _key: String = ""
## The line the countdown is added to while the next report has to wait.
var _countdown_base: String = ""
var _sending: bool = false
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
	# No key (a fresh checkout): no Send button rather than one that only
	# says "not available".
	_key = FileAccess.get_file_as_string(KEY_PATH).strip_edges() if FileAccess.file_exists(KEY_PATH) else ""
	_send.visible = _can_send()
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_status)
	UIKit.section(c, "Other ways" if _can_send() else "Send it")
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
	var tick := Timer.new()
	tick.wait_time = 1.0
	tick.autostart = true
	tick.timeout.connect(_tick)
	screen.add_child(tick)
	return screen

## Called each time the screen opens: fresh game info, the text kept
## (a half-written report survives a look at the map).
func refresh() -> void:
	_info = collect_info()
	_show_info()
	_status.text = ""
	_countdown_base = ""
	_update_send()
	if _can_send() and _wait_left() > 0:
		_countdown_base = "Thank you for your last report!"
		_tick()

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
	_update_send()

## Send is off only while a report is on its way or the next one has to
## wait; the countdown turns it back on (user, 2026-10-28: it stayed grey
## after the countdown until something new was typed).
func _update_send() -> void:
	_send.disabled = _sending or (_can_send() and _wait_left() > 0)

func _can_send() -> bool:
	return REPORT_URL != "" and _key != ""

func _on_send() -> void:
	if _text.text.strip_edges() == "":
		_fail("Write what happened first, then press Send.")
		return
	if not _can_send() or Updater.is_test_run():
		_fail("Sending isn't available in this version. Please use one of the other ways below.")
		return
	var left: int = _wait_left()
	if left > 0:
		_fail("Please wait %s before the next report." % _duration(left))
		return
	var body: Dictionary = _sent_info()
	body["text"] = _text.text.strip_edges()
	body["email"] = _email.text.strip_edges()
	_sending = true
	_send.disabled = true
	_status.text = "Sending..."
	_status.remove_theme_color_override("font_color")
	if _http.request(REPORT_URL, ["Content-Type: application/json", "X-SH-Key: " + _key, "User-Agent: StaticHorizonFPV/" + Updater.current_version()], HTTPClient.METHOD_POST, JSON.stringify(body)) != OK:
		_fail("Couldn't send. Please try again later or use one of the other ways below.")

func _on_done(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	_sending = false
	handle_reply(code if result == HTTPRequest.RESULT_SUCCESS else 0, headers, body.get_string_from_utf8())

## The worker's answer -> the line the player sees (and the local
## cooldown). Public for the self-test (mock replies, nothing sent).
func handle_reply(code: int, headers: PackedStringArray, text: String) -> void:
	if code == 204:
		# (Also when the same text was already sent today.)
		_set_wait(MIN_GAP_SECONDS)
		_status.text = "Sent - thank you!"
		_status.add_theme_color_override("font_color", UIKit.ACCENT)
		_text.text = ""
		_update_send()
		_countdown_base = _status.text
		_tick()
		return
	if code == 429:
		var j: Variant = JSON.parse_string(text) if text.strip_edges().begins_with("{") else null
		var d: Dictionary = j if j is Dictionary else {}
		var secs: int = int(d.get("retry_after_seconds", _retry_after(headers)))
		_set_wait(secs)
		match str(d.get("error", "wait")):
			"limit":
				_fail("%s. Or use one of the other ways below." % str(d.get("message", "Daily limit reached, try again tomorrow")).trim_suffix("."))
			"full":
				_fail("The report inbox is full for today. Please use one of the other ways below - thank you!")
			_:
				_fail("Please wait %s before the next report." % _duration(secs))
		return
	_fail("Couldn't send (%s). Please try again later or use one of the other ways below." % (str(code) if code > 0 else "no connection"))

## Once a second: "(next report in 0:42)" after the line, until it may go
## (user, 2026-10-28).
func _tick() -> void:
	if not screen.is_visible_in_tree():
		return
	_update_send()
	if _countdown_base == "":
		return
	var left: int = _wait_left()
	if left > 0:
		_status.text = "%s (next report in %d:%02d)" % [_countdown_base, left / 60, left % 60]
	else:
		_status.text = _countdown_base
		_countdown_base = ""

func _retry_after(headers: PackedStringArray) -> int:
	for h in headers:
		if h.to_lower().begins_with("retry-after:"):
			return int(h.get_slice(":", 1).strip_edges())
	return MIN_GAP_SECONDS

## Seconds until the next report may go (0: now).
func _wait_left() -> int:
	var cfg := ConfigFile.new()
	if cfg.load(STATE_PATH) != OK:
		return 0
	return maxi(int(cfg.get_value("report", "wait_until", 0)) - int(Time.get_unix_time_from_system()), 0)

func _set_wait(secs: int) -> void:
	if Updater.is_test_run():
		return # (never touches the player's file in tests)
	var cfg := ConfigFile.new()
	cfg.set_value("report", "wait_until", int(Time.get_unix_time_from_system()) + maxi(secs, 0))
	cfg.save(STATE_PATH)

static func _duration(secs: int) -> String:
	if secs < 90:
		return "%d seconds" % maxi(secs, 1)
	if secs < 90 * 60:
		return "%d minutes" % int(ceil(secs / 60.0))
	return "%d hours" % int(ceil(secs / 3600.0))

func _fail(msg: String) -> void:
	_countdown_base = ""
	_status.text = msg
	_status.add_theme_color_override("font_color", Color("#ffb86b"))
	_sending = false
	_update_send()

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
