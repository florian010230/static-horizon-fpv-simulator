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

@export_group("Arm switch")
## What arms the drone on the radio: "button" (a switch EdgeTX reports as
## a joystick button - pressed while the switch is up) or "axis" (a
## switch mapped to its own channel, which USB joystick mode reports as
## an axis jumping between two values). Assigned in the calibration
## wizard or Settings -> Assign arm switch.
@export_enum("button", "axis") var arm_source: String = "button"
@export var arm_axis: int = -1
@export var arm_axis_off_value: float = -1.0
@export var arm_axis_on_value: float = 1.0
## true (default, like Betaflight's ARM mode on an AUX switch): armed
## exactly while the switch is on. false: every press toggles arm, for a
## momentary button.
@export var arm_is_switch: bool = true
## false for a radio that reports its switch as a button held down while
## the switch is OFF (seen with some EdgeTX mixer setups).
@export var arm_button_on_when_pressed: bool = true

## Three more optional radio controls, same shape as the arm switch
## above but every one of them starts unassigned ("" source, -1 index):
## until the pilot assigns one in Settings -> Radio, behaviour is
## unchanged (flight mode only toggles with L, reset is only KEY_R, the
## line-of-sight toggle is only KEY_V). See _control_on()/_control_name()/
## _clear_control(), which implement all three (and the calibration
## wizard's capture step for all three) from one generalized
## field-name-prefix pattern instead of three near-duplicate copies.
@export_group("Mode switch (optional)")
## Like Betaflight's ANGLE mode on an AUX switch: while assigned, the
## switch's raw position sets self_level directly every frame (not a
## toggle) - see _handle_level_toggle().
@export var mode_source: String = ""
@export var mode_axis: int = -1
@export var mode_axis_off_value: float = -1.0
@export var mode_axis_on_value: float = 1.0
@export var mode_button_index: int = -1
@export var mode_button_on_when_pressed: bool = true

@export_group("Reset control (optional)")
## reset_key_pressed() is level-based (true while active), same as the
## keyboard's KEY_R - not edge-triggered.
@export var reset_source: String = ""
@export var reset_axis: int = -1
@export var reset_axis_off_value: float = -1.0
@export var reset_axis_on_value: float = 1.0
@export var reset_button_index: int = -1
@export var reset_button_on_when_pressed: bool = true

@export_group("Line-of-sight toggle (optional)")
## los_toggle_pressed() is edge-triggered (true only the frame it goes
## from off to on), same as a single KEY_V tap.
@export var los_source: String = ""
@export var los_axis: int = -1
@export var los_axis_off_value: float = -1.0
@export var los_axis_on_value: float = 1.0
@export var los_button_index: int = -1
@export var los_button_on_when_pressed: bool = true

@export_group("Restart map (optional)")
## restart_pressed() is edge-triggered: flipping the switch (or pressing
## the button) reloads the map from the start - race, timer, drone.
@export var restart_source: String = ""
@export var restart_axis: int = -1
@export var restart_axis_off_value: float = -1.0
@export var restart_axis_on_value: float = 1.0
@export var restart_button_index: int = -1
@export var restart_button_on_when_pressed: bool = true

@export_group("Calibration")
@export var invert_roll: bool = false
@export var invert_pitch: bool = false
@export var invert_yaw: bool = false
@export var invert_throttle: bool = false
## Small, and rescaled (see _shape_stick) - real gimbals are measured
## against their own calibrated rest position now, so this only has to
## swallow sensor noise, not a whole off-center offset.
@export var deadzone: float = 0.03
@export var throttle_is_centered: bool = true ## true: raw axis is -1..1 (remapped to 0..1). false: raw axis already 0..1.
## A real FC refuses to arm unless throttle reads near zero, specifically
## to avoid the drone surprise-spinning-up if the (non-centering)
## throttle stick was left somewhere other than idle.
@export var arm_throttle_safety_threshold: float = 0.08

## Where each raw axis sits with the sticks untouched, captured by the
## calibration wizard's first step. Real gimbals rarely rest at exactly
## 0.000 over USB - a few percent off is normal - and every bit of that
## offset past the deadzone used to go straight into the flight
## controller as a constant small stick command: the drone slowly
## rolling/pitching/yawing "on its own" with the sticks centered.
var axis_rest: Array[float] = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
## Throttle end points, also measured by the wizard (rest = low, then
## held at max) - covers radios whose throttle axis is -1..1, 0..1, or
## doesn't quite reach either end, without guessing.
var throttle_calibrated: bool = false
var throttle_raw_low: float = -1.0
var throttle_raw_high: float = 1.0

## Everything Godot can report for a joystick: 10 axes (JoyAxis.MAX) and
## 128 buttons. EdgeTX/OpenTX radios send 8 channels as axes by default
## and can map up to 24+ switches to buttons; some radios (TBS Tango,
## Jumper, DJI) number theirs differently - scanning all of them means
## no radio has a channel the wizard can't see.
const AXES: int = 10
const BUTTONS: int = 128

## "" = pick automatically (the first controller that actually sends
## data); otherwise the name of the controller chosen in Settings.
## Stored by name, since device numbers change between launches.
var preferred_device_name: String = ""

const KEYBOARD_THROTTLE_RATE: float = 0.6 # units/sec while Shift/Ctrl held
const CALIBRATION_PATH: String = "user://input_calibration.cfg"

## The field-name prefixes of the three optional controls and the
## per-control field suffixes, used to save/load/read/clear all three
## with one small loop instead of three near-identical blocks (see
## save_calibration(), load_calibration(), _control_on()).
const OPTIONAL_CONTROLS: Array[String] = ["mode", "reset", "los", "restart"]
const CONTROL_FIELDS: Array[String] = ["_source", "_axis", "_axis_off_value", "_axis_on_value", "_button_index", "_button_on_when_pressed"]

var armed: bool = false
## Dev/test hook only: when set to a Dictionary with roll/pitch/yaw/
## throttle, the stick getters return those values instead of real
## input. Used by throwaway physics calibration tests (top speed, drag);
## the end-to-end --selftest deliberately does NOT use it and goes
## through real (injected) input events instead. Always null in play.
var test_override = null
## Dev/test hook: a virtual radio, {"axes": [8 floats], "buttons": [16
## bools]}. When set it stands in for the OS joypad read and nothing
## else - activity detection, calibration, arm switch and stick shaping
## all run exactly as for real hardware. Lets --selftest drive the
## calibration wizard and the arm switch on machines with no radio.
var test_joy = null
var self_level: bool = false ## Acro by default. Toggle with L.

var _prev_arm_key: bool = false
var _prev_arm_button: bool = false
## Latched after the radio's first reading so a switch that is already
## ON when a map loads (or when the radio wakes up) doesn't arm straight
## away - it has to be flipped off and on again, exactly like
## Betaflight's "arm switch on at boot" safety.
var _arm_switch_seen: bool = false
## Set when the switch went on while arming wasn't allowed (throttle up):
## stays disarmed until the switch is cycled.
var arm_blocked: bool = false
var _prev_level_key: bool = false
var _prev_los_on: bool = false ## edge state for los_toggle_pressed()
var _prev_restart_on: bool = true ## starts "on": a switch already up at load must be flipped again
var _kb_throttle: float = 0.0

## A radio only takes over from the keyboard once it has actually sent
## data. A connected-but-silent radio (switched off while still plugged
## in, not in joystick mode, or macOS not yet granting input access)
## enumerates fine but reports exactly 0.000 on every axis - and a
## centered throttle channel reading 0.0 means 50% throttle. That both
## blocked arming ("lower throttle to arm") and switched the keyboard
## off, so the drone couldn't take off at all, in any map. Found by
## reading the real RadioMaster Pocket through this code.
var _joy_active: bool = false

func _ready() -> void:
	load_calibration()
	Input.joy_connection_changed.connect(func(_device: int, _connected: bool):
		_joy_active = false
		_arm_switch_seen = false)

func _process(delta: float) -> void:
	_select_device()
	_detect_joy_activity()
	_handle_arm_toggle()
	_handle_level_toggle()
	if not _joy_connected():
		_update_keyboard_throttle(delta)

func _detect_joy_activity() -> void:
	if _joy_active or not _joy_present():
		return
	for i in range(AXES):
		if absf(joy_axis(i)) > 0.01:
			_joy_active = true
			return
	for b in range(BUTTONS):
		if joy_button(b):
			_joy_active = true
			return

## Several controllers plugged in (a radio plus a gamepad, or a radio
## that enumerates twice): use the chosen one, else stay on the current
## one once it's sending, else switch to whichever one moves first.
func _select_device() -> void:
	if test_joy != null:
		return
	var pads: Array[int] = Input.get_connected_joypads()
	if pads.is_empty():
		return
	if preferred_device_name != "":
		for d in pads:
			if Input.get_joy_name(d) == preferred_device_name:
				if d != joystick_device:
					_use_device(d)
				return
	if pads.has(joystick_device) and _joy_active:
		return
	for d in pads:
		if d != joystick_device and _device_moving(d):
			_use_device(d)
			return
	if not pads.has(joystick_device):
		_use_device(pads[0])

func _use_device(d: int) -> void:
	joystick_device = d
	_joy_active = false
	_arm_switch_seen = false

func _device_moving(d: int) -> bool:
	for i in range(AXES):
		if absf(Input.get_joy_axis(d, i)) > 0.01:
			return true
	for b in range(32):
		if Input.is_joy_button_pressed(d, b):
			return true
	return false

## Names of every connected controller, for the Settings picker.
func device_names() -> Array[String]:
	var out: Array[String] = []
	for d in Input.get_connected_joypads():
		out.append(Input.get_joy_name(d))
	return out

## Plugged in (enumerated by the OS), whether or not it sends anything.
func _joy_present() -> bool:
	return test_joy != null or Input.get_connected_joypads().has(joystick_device)

## Raw reads of the radio - every read in this file goes through these.
func joy_axis(i: int) -> float:
	if test_joy != null:
		return test_joy["axes"][i] if i < test_joy["axes"].size() else 0.0
	return Input.get_joy_axis(joystick_device, i)

func joy_button(i: int) -> bool:
	if test_joy != null:
		return test_joy["buttons"][i] if i < test_joy["buttons"].size() else false
	return Input.is_joy_button_pressed(joystick_device, i)

func joy_name() -> String:
	return "Virtual test radio" if test_joy != null else Input.get_joy_name(joystick_device)

## The radio is actually flying the drone: present AND has sent data.
func _joy_connected() -> bool:
	return _joy_present() and _joy_active

## "none", "silent" (plugged in, no data yet) or "active".
func radio_status() -> String:
	if not _joy_present():
		return "none"
	return "active" if _joy_active else "silent"

## Same check, exposed publicly for the menu's calibration wizard - the
## leading underscore above is this file's own convention for "internal",
## not a real access restriction, but callers outside this script should
## still go through the public name.
func has_joystick() -> bool:
	return _joy_present()

## Calibration helper: of the connected joystick's axes (excluding any
## already assigned to another channel this calibration pass), returns
## whichever currently reads furthest from center - this is how the
## wizard figures out "which raw axis is the user moving right now"
## without them needing to know Godot's own axis numbering. Empty if no
## joystick is connected or nothing is currently deflected.
##
## Measured relative to the captured rest position (capture_rest()), not
## raw zero - otherwise a throttle stick resting at raw -1.0 looks exactly
## as "deflected" as the roll stick being held fully right, and whichever
## axis number came first won.
func strongest_axis(exclude: Array[int] = [], min_deflection: float = 0.5) -> Dictionary:
	if not _joy_present():
		return {}
	var best_axis := -1
	var best_val := 0.0
	for i in range(AXES):
		if i in exclude:
			continue
		var v: float = joy_axis(i) - axis_rest[i]
		if absf(v) > absf(best_val):
			best_val = v
			best_axis = i
	if best_axis == -1 or absf(best_val) < min_deflection:
		return {}
	return {"axis": best_axis, "value": best_val, "raw": joy_axis(best_axis)}

## Calibration helper: records every axis's current raw value as its
## rest position. Called with the sticks centered and throttle low.
func capture_rest() -> void:
	if not _joy_present():
		return
	for i in range(AXES):
		axis_rest[i] = joy_axis(i)

## Calibration helper: the first currently-pressed joystick button, or -1
## - used to let the pilot assign their own arm switch instead of
## guessing button 0 matches their radio.
func pressed_button() -> int:
	if not _joy_present():
		return -1
	for i in range(BUTTONS):
		if joy_button(i):
			return i
	return -1

## Calibration persists across restarts (a real radio's channel mapping
## doesn't change flight to flight) - everything else in Settings resets
## on launch, but re-doing radio calibration every session would be a
## real annoyance for the one thing about this sim that depends on the
## pilot's own specific hardware.
func save_calibration() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("radio", "axis_roll", axis_roll)
	cfg.set_value("radio", "axis_pitch", axis_pitch)
	cfg.set_value("radio", "axis_throttle", axis_throttle)
	cfg.set_value("radio", "axis_yaw", axis_yaw)
	cfg.set_value("radio", "invert_roll", invert_roll)
	cfg.set_value("radio", "invert_pitch", invert_pitch)
	cfg.set_value("radio", "invert_yaw", invert_yaw)
	cfg.set_value("radio", "invert_throttle", invert_throttle)
	cfg.set_value("radio", "arm_button_index", arm_button_index)
	cfg.set_value("radio", "arm_source", arm_source)
	cfg.set_value("radio", "preferred_device_name", preferred_device_name)
	cfg.set_value("radio", "deadzone", deadzone)
	cfg.set_value("radio", "arm_axis", arm_axis)
	cfg.set_value("radio", "arm_axis_off_value", arm_axis_off_value)
	cfg.set_value("radio", "arm_axis_on_value", arm_axis_on_value)
	cfg.set_value("radio", "arm_is_switch", arm_is_switch)
	cfg.set_value("radio", "arm_button_on_when_pressed", arm_button_on_when_pressed)
	cfg.set_value("radio", "axis_rest", axis_rest)
	cfg.set_value("radio", "throttle_calibrated", throttle_calibrated)
	cfg.set_value("radio", "throttle_raw_low", throttle_raw_low)
	cfg.set_value("radio", "throttle_raw_high", throttle_raw_high)
	for p in OPTIONAL_CONTROLS:
		for suf in CONTROL_FIELDS:
			cfg.set_value("radio", p + suf, get(p + suf))
	cfg.save(CALIBRATION_PATH)

func load_calibration() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(CALIBRATION_PATH) != OK:
		return
	axis_roll = cfg.get_value("radio", "axis_roll", axis_roll)
	axis_pitch = cfg.get_value("radio", "axis_pitch", axis_pitch)
	axis_throttle = cfg.get_value("radio", "axis_throttle", axis_throttle)
	axis_yaw = cfg.get_value("radio", "axis_yaw", axis_yaw)
	invert_roll = cfg.get_value("radio", "invert_roll", invert_roll)
	invert_pitch = cfg.get_value("radio", "invert_pitch", invert_pitch)
	invert_yaw = cfg.get_value("radio", "invert_yaw", invert_yaw)
	invert_throttle = cfg.get_value("radio", "invert_throttle", invert_throttle)
	arm_button_index = cfg.get_value("radio", "arm_button_index", arm_button_index)
	arm_source = cfg.get_value("radio", "arm_source", arm_source)
	preferred_device_name = cfg.get_value("radio", "preferred_device_name", preferred_device_name)
	deadzone = cfg.get_value("radio", "deadzone", deadzone)
	arm_axis = cfg.get_value("radio", "arm_axis", arm_axis)
	arm_axis_off_value = cfg.get_value("radio", "arm_axis_off_value", arm_axis_off_value)
	arm_axis_on_value = cfg.get_value("radio", "arm_axis_on_value", arm_axis_on_value)
	arm_is_switch = cfg.get_value("radio", "arm_is_switch", arm_is_switch)
	arm_button_on_when_pressed = cfg.get_value("radio", "arm_button_on_when_pressed", arm_button_on_when_pressed)
	var rest: Array = cfg.get_value("radio", "axis_rest", [])
	for i in range(mini(rest.size(), axis_rest.size())):
		axis_rest[i] = float(rest[i])
	throttle_calibrated = cfg.get_value("radio", "throttle_calibrated", throttle_calibrated)
	throttle_raw_low = cfg.get_value("radio", "throttle_raw_low", throttle_raw_low)
	throttle_raw_high = cfg.get_value("radio", "throttle_raw_high", throttle_raw_high)
	for p in OPTIONAL_CONTROLS:
		for suf in CONTROL_FIELDS:
			set(p + suf, cfg.get_value("radio", p + suf, get(p + suf)))

## Raw axis -> -1..1 stick: measured from the axis's calibrated rest
## point (each side scaled separately so full deflection still reads
## exactly +/-1 even with an off-center rest), then a *rescaled* deadzone
## - output ramps up from 0 at the deadzone edge instead of jumping
## straight to the deadzone value.
func _shape_stick(axis: int) -> float:
	var raw: float = joy_axis(axis)
	var rest: float = axis_rest[axis] if axis >= 0 and axis < axis_rest.size() else 0.0
	var v: float = raw - rest
	v = v / maxf(1.0 - rest, 0.01) if v > 0.0 else v / maxf(1.0 + rest, 0.01)
	var mag: float = absf(v)
	if mag < deadzone:
		return 0.0
	return signf(v) * clampf((mag - deadzone) / (1.0 - deadzone), 0.0, 1.0)

func can_arm() -> bool:
	return get_throttle() <= arm_throttle_safety_threshold

## Enter always toggles. The radio's arm control is edge-triggered in
## both modes: switch mode arms on the OFF->ON flip and disarms on ON->OFF
## (so a keyboard disarm with the switch still on stays disarmed until the
## switch is cycled), button mode toggles on each press.
func _handle_arm_toggle() -> void:
	var key_pressed := Input.is_key_pressed(KEY_ENTER)
	if key_pressed and not _prev_arm_key:
		if armed:
			armed = false
		elif can_arm():
			armed = true
	_prev_arm_key = key_pressed

	if not _joy_connected():
		_arm_switch_seen = false
		return
	var on: bool = arm_switch_on()
	if not _arm_switch_seen:
		_arm_switch_seen = true
		_prev_arm_button = on
		arm_blocked = on and not armed and arm_is_switch
		return
	if arm_is_switch:
		if on and not _prev_arm_button:
			if can_arm():
				armed = true
				arm_blocked = false
			else:
				arm_blocked = true
		elif not on and _prev_arm_button:
			armed = false
			arm_blocked = false
	elif on and not _prev_arm_button:
		if armed:
			armed = false
		elif can_arm():
			armed = true
	_prev_arm_button = on

## Every map load (and world-border reset) starts disarmed, and an arm
## switch that's still ON from before has to be cycled first.
func new_flight() -> void:
	armed = false
	arm_blocked = false
	_arm_switch_seen = false

## Raw state of the assigned arm switch/button right now.
func arm_switch_on() -> bool:
	if not _joy_present():
		return false
	if arm_source == "axis" and arm_axis >= 0:
		var raw: float = joy_axis(arm_axis)
		return absf(raw - arm_axis_on_value) < absf(raw - arm_axis_off_value)
	return joy_button(arm_button_index) == arm_button_on_when_pressed

## Why the drone is disarmed, for the HUD ("" if nothing's in the way).
func arm_hint() -> String:
	if armed:
		return ""
	if _joy_connected() and arm_is_switch and arm_switch_on():
		return "flip the arm switch off, then on" if can_arm() else "lower throttle, then flip the arm switch off and on"
	if not can_arm():
		return "lower throttle to arm"
	return ""

## Human-readable name of the arm control, for the HUD and Settings.
func arm_control_name() -> String:
	if arm_source == "axis" and arm_axis >= 0:
		return "switch on channel axis %d" % arm_axis
	return "button %d" % arm_button_index

## Generalized version of arm_switch_on(), for the three optional
## controls (mode/reset/los): reads whichever of the "<prefix>_*" fields
## is currently assigned. Unassigned (source "") always reads false, so
## every caller below falls back to keyboard-only behaviour exactly as
## before this feature existed.
func _control_on(prefix: String) -> bool:
	if not _joy_present():
		return false
	var source: String = get(prefix + "_source")
	if source == "axis":
		var axis: int = get(prefix + "_axis")
		if axis < 0:
			return false
		var raw: float = joy_axis(axis)
		var on_value: float = get(prefix + "_axis_on_value")
		var off_value: float = get(prefix + "_axis_off_value")
		return absf(raw - on_value) < absf(raw - off_value)
	if source == "button":
		var idx: int = get(prefix + "_button_index")
		if idx < 0:
			return false
		return joy_button(idx) == bool(get(prefix + "_button_on_when_pressed"))
	return false

## Human-readable name of an optional control's assignment, or
## "not assigned" - same shape as arm_control_name() above.
func _control_name(prefix: String) -> String:
	var source: String = get(prefix + "_source")
	if source == "axis":
		return "switch on axis %d" % int(get(prefix + "_axis"))
	if source == "button":
		return "button %d" % int(get(prefix + "_button_index"))
	return "not assigned"

## Wipes one optional control back to "not assigned" (keyboard only),
## without touching ARM or the other two.
func _clear_control(prefix: String) -> void:
	set(prefix + "_source", "")
	set(prefix + "_axis", -1)
	set(prefix + "_button_index", -1)
	save_calibration()

func mode_control_name() -> String:
	return _control_name("mode")

func clear_mode_control() -> void:
	_clear_control("mode")

func reset_control_name() -> String:
	return _control_name("reset")

func clear_reset_control() -> void:
	_clear_control("reset")

func los_control_name() -> String:
	return _control_name("los")

func clear_los_control() -> void:
	_clear_control("los")

func restart_control_name() -> String:
	return _control_name("restart")

func clear_restart_control() -> void:
	_clear_control("restart")

## True the frame the assigned restart control goes from off to on.
func restart_pressed() -> bool:
	var on: bool = _control_on("restart")
	var edge: bool = on and not _prev_restart_on
	_prev_restart_on = on
	return edge

func _handle_level_toggle() -> void:
	var key_pressed := Input.is_key_pressed(KEY_L)
	if key_pressed and not _prev_level_key:
		self_level = not self_level
	_prev_level_key = key_pressed
	# A mode switch, once assigned, is authoritative every frame (like a
	# real FC's AUX-mapped ANGLE mode) - L still works, but is only
	# "the last word" when no mode switch is assigned.
	if mode_source != "" and _joy_connected():
		self_level = _control_on("mode")

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

## Sign convention for every stick getter below: +1 = roll right, pitch
## forward (nose down), yaw right, full throttle - on the keyboard and,
## after invert_*, on a radio too. Drone converts that to body-axis
## rotations itself. (Before this was pinned down, the keyboard and the
## flight model each had their own convention and the invert flags
## papered over the difference - which is how the calibration wizard,
## which assumed this convention, ended up reversing every axis, and how
## Angle mode's roll ended up reversed relative to Acro's.)
func get_roll() -> float:
	if test_override != null: return test_override["roll"]
	if _joy_connected():
		var v: float = _shape_stick(axis_roll)
		return -v if invert_roll else v
	return _key_axis(KEY_A, KEY_D)

func get_pitch() -> float:
	if test_override != null: return test_override["pitch"]
	if _joy_connected():
		var v: float = _shape_stick(axis_pitch)
		return -v if invert_pitch else v
	return _key_axis(KEY_S, KEY_W)

func get_yaw() -> float:
	if test_override != null: return test_override["yaw"]
	if _joy_connected():
		var v: float = _shape_stick(axis_yaw)
		return -v if invert_yaw else v
	return _key_axis(KEY_Q, KEY_E)

func get_throttle() -> float:
	if test_override != null: return test_override["throttle"]
	if _joy_connected():
		var v: float
		var raw: float = joy_axis(axis_throttle)
		if throttle_calibrated and absf(throttle_raw_high - throttle_raw_low) > 0.2:
			v = (raw - throttle_raw_low) / (throttle_raw_high - throttle_raw_low)
		else:
			v = (raw + 1.0) / 2.0 if throttle_is_centered else raw
		v = clamp(v, 0.0, 1.0)
		return (1.0 - v) if invert_throttle else v
	return _kb_throttle

## Level-based, like the keyboard: true while R is held OR the assigned
## reset control (button held / switch on) is active. Polled every
## physics frame by drone.gd, which presumably debounces on its own.
func reset_key_pressed() -> bool:
	return Input.is_key_pressed(KEY_R) or _control_on("reset")

## Edge-triggered: true only on the frame KEY_V or the assigned
## line-of-sight control goes from off to on. Intended to be polled
## once a frame (e.g. by ui.gd, which currently reads KEY_V directly -
## this is the API for it to switch to).
func los_toggle_pressed() -> bool:
	var on: bool = Input.is_key_pressed(KEY_V) or _control_on("los")
	var pressed_edge: bool = on and not _prev_los_on
	_prev_los_on = on
	return pressed_edge

func raw_axes_debug_text() -> String:
	if not _joy_present():
		return "No joystick detected - using keyboard fallback."
	var dev_name: String = joy_name()
	var lines: Array[String] = ["Device %d: %s" % [joystick_device, dev_name]]
	for i in range(AXES):
		lines.append("  axis %d: %.3f" % [i, joy_axis(i)])
	return "\n".join(lines)
