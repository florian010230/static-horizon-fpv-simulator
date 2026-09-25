extends Node3D

@onready var _drone: Drone = $Drone
@onready var _ui: CanvasLayer = $UI

func _ready() -> void:
	if _ui.has_method("set_drone"):
		_ui.set_drone(_drone)
