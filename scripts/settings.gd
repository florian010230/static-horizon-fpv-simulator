extends Node

## Autoloaded singleton holding options that need to survive scene
## changes (menu <-> gameplay): crosshair, fullscreen, shadow quality.

var crosshair_enabled: bool = true
var shadows_enabled: bool = false ## Off by default - shadow rendering is one of the more expensive things a weak GPU does.

func apply_shadow_setting() -> void:
	var sun := get_tree().root.find_child("Sun", true, false)
	if sun and sun is DirectionalLight3D:
		sun.shadow_enabled = shadows_enabled

func set_fullscreen(v: bool) -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if v else DisplayServer.WINDOW_MODE_WINDOWED)

func is_fullscreen() -> bool:
	return DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
