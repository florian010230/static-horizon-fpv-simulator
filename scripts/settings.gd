extends Node

## Autoloaded singleton holding options that need to survive scene
## changes (menu <-> gameplay): crosshair, fullscreen, shadow quality.

var crosshair_enabled: bool = true
var shadows_enabled: bool = false ## Off by default - shadow rendering is one of the more expensive things a weak GPU does.
var max_fps: int = 60 ## 0 means uncapped ("Unlimited" in the menu slider).

## Acro's "Actual Rates" curve (see Drone.center_sensitivity_deg /
## max_rate_deg) - exposed here so a player can set their preferred feel
## once from the menu instead of re-tuning it every flight. The in-game
## "O" debug panel still live-edits the drone's own fields directly for
## quick A/B testing mid-flight; these are just what a freshly spawned
## drone starts from.
var rate_center_sensitivity_deg: float = 70.0
var rate_max_deg: float = 670.0

func _ready() -> void:
	Engine.max_fps = max_fps

func set_max_fps(v: int) -> void:
	max_fps = v
	Engine.max_fps = v

func apply_shadow_setting() -> void:
	var sun := get_tree().root.find_child("Sun", true, false)
	if sun and sun is DirectionalLight3D:
		sun.shadow_enabled = shadows_enabled

func set_fullscreen(v: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
