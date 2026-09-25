extends Node

## Autoloaded singleton (see scenes/InputManager.tscn). Reads an FPV radio
## (RadioMaster Pocket or anything else in USB "Joystick" mode) through
## Godot's joypad API, with a keyboard fallback so the sim is usable with
## no hardware plugged in. Select the InputManager node in
## scenes/InputManager.tscn to calibrate axis_* / invert_* in the Inspector.

@export_group("Radio channel mapping")
@export var joystick_device: int = 0
@export var axis_roll: int = 0
@export var axis_pitch: int = 1
@export var axis_throttle: int = 2
@export var axis_yaw: int = 3
@export var arm_button_index: int = 0

@export_group("Calibration")
@export var invert_roll: bool = false
@export var invert_pitch: bool = false
@export var invert_yaw: bool = false
@export var invert_throttle: bool = false
@export var deadzone: float = 0.06
@export var throttle_is_centered: bool = true ## true: raw axis is -1..1 (remapped to 0..1). false: raw axis already 0..1.
## A real FC refuses to arm unless throttle reads near zero, specifically
## to avoid the drone surprise-spinning-up if the (non-centering)
## throttle stick was left somewhere other than idle.
@export var arm_throttle_safety_threshold: float = 0.08

const KEYBOARD_THROTTLE_RATE: float = 0.6 # units/sec while Shift/Ctrl held

var armed: bool = false
var self_level: bool = true ## Angle (self-level) mode by default, like a real FC's beginner setting. Toggle with L.

var _prev_arm_key: bool = false
var _prev_arm_button: bool = false
var _prev_level_key: bool = false
var _kb_throttle: float = 0.0

func _process(delta: float) -> void:
	_handle_arm_toggle()
	_handle_level_toggle()
	if not _joy_connected():
		_update_keyboard_throttle(delta)

func _joy_connected() -> bool:
	return Input.get_connected_joypads().has(joystick_device)

func _apply_deadzone(v: float) -> float:
	return 0.0 if absf(v) < deadzone else v

func can_arm() -> bool:
	return get_throttle() <= arm_throttle_safety_threshold

func _handle_arm_toggle() -> void:
	var key_pressed := Input.is_key_pressed(KEY_ENTER)
	var button_pressed := _joy_connected() and Input.is_joy_button_pressed(joystick_device, arm_button_index)
	if (key_pressed and not _prev_arm_key) or (button_pressed and not _prev_arm_button):
		if armed:
			armed = false
		elif can_arm():
			armed = true
	_prev_arm_key = key_pressed
	_prev_arm_button = button_pressed

func _handle_level_toggle() -> void:
	var key_pressed := Input.is_key_pressed(KEY_L)
	if key_pressed and not _prev_level_key:
		self_level = not self_level
	_prev_level_key = key_pressed

func _update_keyboard_throttle(delta: float) -> void:
	if Input.is_key_pressed(KEY_SHIFT):
		_kb_throttle = clamp(_kb_throttle + KEYBOARD_THROTTLE_RATE * delta, 0.0, 1.0)
	elif Input.is_key_pressed(KEY_CTRL):
		_kb_throttle = clamp(_kb_throttle - KEYBOARD_THROTTLE_RATE * delta, 0.0, 1.0)

func _key_axis(neg: Key, pos: Key) -> float:
	var v := 0.0
	if Input.is_key_pressed(neg):
		v -= 1.0
	if Input.is_key_pressed(pos):
		v += 1.0
	return v

func get_roll() -> float:
	var v: float
	if _joy_connected():
		v = _apply_deadzone(Input.get_joy_axis(joystick_device, axis_roll))
	else:
		v = _key_axis(KEY_A, KEY_D)
	return -v if invert_roll else v

func get_pitch() -> float:
	var v: float
	if _joy_connected():
		v = _apply_deadzone(Input.get_joy_axis(joystick_device, axis_pitch))
	else:
		v = _key_axis(KEY_S, KEY_W)
	return -v if invert_pitch else v

func get_yaw() -> float:
	var v: float
	if _joy_connected():
		v = _apply_deadzone(Input.get_joy_axis(joystick_device, axis_yaw))
	else:
		v = _key_axis(KEY_Q, KEY_E)
	return -v if invert_yaw else v

func get_throttle() -> float:
	var v: float
	if _joy_connected():
		var raw: float = Input.get_joy_axis(joystick_device, axis_throttle)
		v = (raw + 1.0) / 2.0 if throttle_is_centered else raw
		v = clamp(v, 0.0, 1.0)
	else:
		v = _kb_throttle
	return (1.0 - v) if invert_throttle else v

func reset_key_pressed() -> bool:
	return Input.is_key_pressed(KEY_R)

func raw_axes_debug_text() -> String:
	if not _joy_connected():
		return "No joystick detected - using keyboard fallback."
	var dev_name: String = Input.get_joy_name(joystick_device)
	var lines: Array[String] = ["Device %d: %s" % [joystick_device, dev_name]]
	for i in range(8):
		lines.append("  axis %d: %.3f" % [i, Input.get_joy_axis(joystick_device, i)])
	return "\n".join(lines)
