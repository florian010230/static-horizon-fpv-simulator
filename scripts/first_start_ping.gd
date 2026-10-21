class_name FirstStartPing
extends Node

## The opt-in first-start counter: ONE HTTPS POST {version, platform},
## no ID, no personal data, sent only if the player clicked "Yes, count
## me" on the first-run card or switched it on in Settings
## (Settings.count_first_start). Body {"v", "os"}. The flag
## Settings.first_start_pinged is set only after the server answered
## 204, so an offline first start tries again on the next start - and
## once it went through, never again (shared across versions). Never in
## tests. The Worker "statichorizon-ping" (website) counts per
## version/platform and stores no IPs.

## The website's Worker (replies 204 ok, 400 bad input, 429 cap, 503 not
## configured). Empty = nothing is sent.
const ENDPOINT: String = "https://statichorizon-ping.florian-chri-schmidt.workers.dev/"
const TIMEOUT_SECONDS: float = 5.0

var _http: HTTPRequest
## One try per game start at most (the menu is rebuilt after every flight).
static var _tried_this_run: bool = false

static func wanted() -> bool:
	return allowed_by_player() and not _tried_this_run and not Updater.is_test_run()

## The player's side: card answered with Yes (or switched on), not counted yet.
static func allowed_by_player() -> bool:
	return ENDPOINT != "" and Settings.first_run_done and Settings.count_first_start \
		and not Settings.first_start_pinged

static func payload() -> String:
	return JSON.stringify({"v": Updater.current_version(), "os": platform()})

## "windows" / "macos" / "linux" (ChromeOS runs the Linux build).
static func platform() -> String:
	match OS.get_name():
		"Windows": return "windows"
		"macOS": return "macos"
		_: return "linux"

func send_if_wanted() -> void:
	if not wanted() or _http != null:
		return
	_tried_this_run = true
	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SECONDS
	add_child(_http)
	_http.request_completed.connect(func(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray):
		if result == HTTPRequest.RESULT_SUCCESS and code == 204:
			Settings.first_start_pinged = true # (Settings saves it within a second)
		_http.queue_free()
		_http = null)
	if _http.request(ENDPOINT, ["Content-Type: application/json", "User-Agent: StaticHorizonFPV/" + Updater.current_version()], HTTPClient.METHOD_POST, payload()) != OK:
		_http.queue_free()
		_http = null
