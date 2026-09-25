class_name PIDController
extends RefCounted

## Minimal rate-mode PID controller, used for the drone's roll/pitch/yaw
## rate loops (mirrors how a real flight controller's acro/rate mode works:
## the stick sets a target angular RATE, not a target angle).

var kp: float = 0.0
var ki: float = 0.0
var kd: float = 0.0
var integral_limit: float = 10.0

var _integral: float = 0.0
var _prev_error: float = 0.0

func update(error: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	_integral = clamp(_integral + error * delta, -integral_limit, integral_limit)
	var derivative: float = (error - _prev_error) / delta
	_prev_error = error
	return kp * error + ki * _integral + kd * derivative

func reset() -> void:
	_integral = 0.0
	_prev_error = 0.0
