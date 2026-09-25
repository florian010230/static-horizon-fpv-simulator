class_name PIDController
extends RefCounted

## Minimal rate-mode PID controller, used for the drone's roll/pitch/yaw
## rate loops (mirrors how a real flight controller's acro/rate mode works:
## the stick sets a target angular RATE, not a target angle).

var kp: float = 0.0
var ki: float = 0.0
var kd: float = 0.0
var integral_limit: float = 10.0

## A raw (error - prev_error) / delta derivative amplifies any frame-to-
## frame noise - real flight controllers always low-pass filter the
## D-term for exactly this reason (Betaflight's "D-term filtering").
## Without it, even a modest D gain can flip sign every physics step and
## oscillate rather than damp. 0 = no filtering, 1 = fully smoothed
## (ignores new samples); this is a simple one-pole EMA filter.
var d_filter_alpha: float = 0.25

var _integral: float = 0.0
var _prev_error: float = 0.0
var _filtered_derivative: float = 0.0

func update(error: float, delta: float) -> float:
	if delta <= 0.0:
		return 0.0
	_integral = clamp(_integral + error * delta, -integral_limit, integral_limit)
	var raw_derivative: float = (error - _prev_error) / delta
	_filtered_derivative = lerp(_filtered_derivative, raw_derivative, d_filter_alpha)
	_prev_error = error
	return kp * error + ki * _integral + kd * _filtered_derivative

func reset() -> void:
	_integral = 0.0
	_prev_error = 0.0
	_filtered_derivative = 0.0
