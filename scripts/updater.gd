class_name Updater
extends Node

## Quiet update check. On the menu's start (if "Check for updates" is on)
## one request asks GitHub for the latest release; the answer is cached in
## user:// so it asks at most about once a day. Offline, a timeout or any
## other error is silent. A newer release only shows as a small line in the
## main menu and on the Updates screen - never a popup, and the old version
## keeps working. Never touches the network in --selftest/--dev-preview.

signal finished

const REPO := "florian010230/static-horizon-fpv-simulator"
const API_LATEST := "https://api.github.com/repos/" + REPO + "/releases/latest"
const RELEASES_PAGE := "https://github.com/" + REPO + "/releases"
const MAX_AGE_SECONDS: int = 20 * 3600
const TIMEOUT_SECONDS: float = 6.0

## The newest known release: {version, tag, url, body, checked} or {}.
static var latest: Dictionary = {}
## "" (never asked) / "checking" / "ok" / "offline"
static var status: String = ""
static var _asked_this_run: bool = false
static var _cache_loaded: bool = false

var _http: HTTPRequest

static func is_test_run() -> bool:
	var args := OS.get_cmdline_user_args()
	return args.has("--selftest") or args.has("--dev-preview")

static func cache_path() -> String:
	return "user://update_cache_test.cfg" if is_test_run() else "user://update_cache.cfg"

static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0.0.0"))

## "v0.9.1", "0.10.0-beta" -> [0, 9, 1]
static func parse_version(v: String) -> Array[int]:
	var s: String = v.strip_edges().trim_prefix("v").trim_prefix("V")
	s = s.split("-")[0].split("+")[0]
	var out: Array[int] = []
	for part in s.split("."):
		out.append(int(part) if part.is_valid_int() else 0)
	while out.size() < 3:
		out.append(0)
	return out

## True when a is a newer version than b (compared number by number, so
## 0.10.0 > 0.9.0).
static func is_newer(a: String, b: String) -> bool:
	var pa: Array[int] = parse_version(a)
	var pb: Array[int] = parse_version(b)
	for i in range(maxi(pa.size(), pb.size())):
		var x: int = pa[i] if i < pa.size() else 0
		var y: int = pb[i] if i < pb.size() else 0
		if x != y:
			return x > y
	return false

static func newer_available() -> bool:
	_load_cache()
	return not latest.is_empty() and is_newer(latest.version, current_version())

static func _load_cache() -> void:
	if _cache_loaded:
		return
	_cache_loaded = true
	var cfg := ConfigFile.new()
	if cfg.load(cache_path()) != OK or not cfg.has_section("latest"):
		return
	latest = {"version": str(cfg.get_value("latest", "version", "")), "tag": str(cfg.get_value("latest", "tag", "")),
		"url": str(cfg.get_value("latest", "url", RELEASES_PAGE)), "body": str(cfg.get_value("latest", "body", "")),
		"checked": int(cfg.get_value("latest", "checked", 0))}
	if latest.version == "":
		latest = {}

static func _save_cache() -> void:
	var cfg := ConfigFile.new()
	cfg.load(cache_path()) # keep "seen"
	for k in latest:
		cfg.set_value("latest", k, latest[k])
	cfg.save(cache_path())

## The release JSON from GitHub -> latest (and the cache). False if it
## isn't a release.
static func apply_response(code: int, body: String) -> bool:
	if code != 200:
		return false
	var data: Variant = JSON.parse_string(body)
	if typeof(data) != TYPE_DICTIONARY or not data.has("tag_name"):
		return false
	var tag: String = str(data.tag_name)
	latest = {"version": tag.trim_prefix("v").trim_prefix("V"), "tag": tag,
		"url": str(data.get("html_url", RELEASES_PAGE)), "body": str(data.get("body", "")),
		"checked": int(Time.get_unix_time_from_system())}
	_save_cache()
	return true

## The version whose "What's new" the player has been shown ("" on a
## fresh install, which then shows no hint).
static func seen_version() -> String:
	var cfg := ConfigFile.new()
	cfg.load(cache_path())
	return str(cfg.get_value("state", "seen", ""))

static func mark_seen() -> void:
	var cfg := ConfigFile.new()
	cfg.load(cache_path())
	cfg.set_value("state", "seen", current_version())
	cfg.save(cache_path())

## True the first time the game runs on a new version (not a fresh install).
static func show_whats_new_hint() -> bool:
	var seen: String = seen_version()
	return seen != "" and seen != current_version()

## A fresh install records the version right away, so only later updates
## show the hint.
static func note_launch() -> void:
	if seen_version() == "" and not is_test_run():
		mark_seen()

func _ready() -> void:
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	_http.request_completed.connect(_on_done)
	add_child(_http)

## At menu start: asks only if the setting is on, not already asked this
## run, and the cached answer is older than a day.
func check_on_start() -> void:
	_load_cache()
	if not Settings.check_updates or _asked_this_run or is_test_run():
		return
	if not latest.is_empty() and int(Time.get_unix_time_from_system()) - int(latest.get("checked", 0)) < MAX_AGE_SECONDS:
		status = "ok"
		return
	check_now()

## Also the "Check now" button.
func check_now() -> void:
	_asked_this_run = true
	if is_test_run():
		status = "offline"
		finished.emit()
		return
	status = "checking"
	var err: int = _http.request(API_LATEST, ["User-Agent: StaticHorizonFPV/" + current_version(), "Accept: application/vnd.github+json"])
	if err != OK:
		status = "offline"
		finished.emit()

func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result == HTTPRequest.RESULT_SUCCESS and apply_response(code, body.get_string_from_utf8()):
		status = "ok"
	else:
		status = "offline" # silent: the screen just says it could not check
	finished.emit()

# --- release notes: GitHub markdown -> simple labels ------------------------

## Builds the notes into `parent`: # headings, - / * bullets, paragraphs.
## Inline markup (bold, code, links) is flattened to plain text.
static func add_notes(parent: Control, md: String) -> void:
	for raw in md.replace("\r", "").split("\n"):
		var line: String = raw.strip_edges()
		if line == "":
			continue
		var l := Label.new()
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if line.begins_with("#"):
			l.text = _plain(line.lstrip("#").strip_edges())
			l.theme_type_variation = "Heading"
			parent.add_child(l)
		elif line.begins_with("- ") or line.begins_with("* "):
			l.text = "·  " + _plain(line.substr(2))
			l.theme_type_variation = "Muted"
			parent.add_child(l)
		else:
			l.text = _plain(line)
			l.theme_type_variation = "Muted"
			parent.add_child(l)

static func _plain(s: String) -> String:
	var re := RegEx.new()
	re.compile("\\[([^\\]]*)\\]\\([^)]*\\)")
	s = re.sub(s, "$1", true)
	return s.replace("**", "").replace("__", "").replace("`", "")
