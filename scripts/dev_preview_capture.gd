extends Node

## Dev tool, not part of the shipped game: renders a few real frames and
## saves screenshots to the project root, so the project can be visually
## previewed without a screen-sharing/remote-desktop setup. Godot's
## --headless mode never initializes a real GPU context, so there is no
## way to get an actual rendered image without a normal windowed run -
## this script automates that run.
##
## Usage: godot --path . -- --dev-preview
## (needs a real display; run it un-headless, exactly like playing the
## game normally - takes about 6 seconds, then quits itself). Registered
## as a permanent autoload but does nothing at all unless that flag is
## present, so it's always available without costing anything normally.

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--dev-preview"):
		return
	call_deferred("_go")

func _go() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(1.0).timeout
	_shot("preview_menu.png")

	get_tree().change_scene_to_file("res://scenes/Main.tscn")
	await get_tree().create_timer(2.0).timeout
	_shot("preview_gameplay.png")

	var drone: RigidBody3D = get_tree().root.find_child("Drone", true, false)
	if drone:
		drone.gravity_scale = 0.0
		drone.linear_velocity = Vector3.ZERO
		drone.angular_velocity = Vector3.ZERO
		drone.global_transform.origin = Vector3(20, 160, 30)
		drone.rotation = Vector3(deg_to_rad(-90), 0, 0)
		InputManager.armed = false
	await get_tree().create_timer(0.3).timeout
	_shot("preview_topdown.png")

	get_tree().quit()

func _shot(filename: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://previews/%s" % filename)
	print("SCREENSHOT_SAVED: previews/", filename)
