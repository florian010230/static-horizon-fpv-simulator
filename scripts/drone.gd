class_name Drone
extends RigidBody3D

## Simplified quadcopter (X-frame) flight model with both Angle
## (self-level, default) and Acro flight modes - toggle with L via
## InputManager.self_level.
##
## Both modes ultimately drive the same inner-loop rate PID per axis; they
## only differ in how the target rate is produced (see _actual_rate() for
## Acro's Betaflight-style curve, and the self_level branch below for
## Angle mode's outer attitude loop). PID outputs are mixed into 4 virtual
## motor thrusts (roll/pitch) plus a direct reaction torque (yaw - a
## spinning prop's drag torque can't be produced by a purely vertical
## thrust force, so it's modelled directly).

## Sized to match a real 3" freestyle quad (DeepSpace Seeker3: ~245g
## flying weight, ~60mm motor arm) rather than a 5" frame. Thrust set
## for a thrust-to-weight ratio of ~7:1 (total thrust = 7 * weight),
## typical for a high-KV 4S 3" freestyle build - "rips" with instant,
## crisp throttle response rather than a lazy 5" cruiser feel.
@export_group("Frame")
@export var arm_length: float = 0.06
@export var max_motor_thrust_n: float = 4.2

## Real air resistance is roughly quadratic in speed (F = k * v^2), not
## RigidBody3D's default linear_damp - linear damping barely slows a
## quad like this down at all, so top speed just kept climbing well
## past anything real (verified: >470 km/h and still rising after 10s
## simulated at max thrust before this was added). Calibrated so a
## drone in a steady, level-altitude dive at max thrust settles near
## the DeepSpace Seeker3's real claimed top speed of 150 km/h (41.7 m/s):
## k = (max thrust's horizontal component once vertical thrust exactly
## cancels gravity) / target_speed^2.
@export var drag_coefficient: float = 0.009

## Betaflight's real default "Actual Rates" (since BF 4.3): Center
## Sensitivity 70 deg/s, Max Rate 670 deg/s, same on roll/pitch/yaw.
## The curve is soft near center and steep at full deflection - a flat
## linear mapping (what this used to be) is objectively twitchier.
@export_group("Acro Rates (deg/s)")
@export var center_sensitivity_deg: float = 70.0
@export var max_rate_deg: float = 670.0

## Angle (self-level) mode: sticks command a target tilt angle instead
## of a rotation rate, and an outer P-loop corrects back to it - this is
## what every real flight controller defaults beginners to, since pure
## acro has no attitude reference and just keeps whatever tilt it drifts
## to. Toggle with L; yaw is always rate-controlled, even in angle mode,
## same as a real FC.
@export_group("Angle Mode")
@export_range(10.0, 60.0, 1.0) var max_angle_deg: float = 45.0
@export_range(2.0, 15.0, 0.5) var angle_p_gain: float = 11.0

## Lower than they'd be for the old 5"-scale frame: a smaller, lighter
## body has proportionally much less rotational inertia, so the same PID
## output now produces a much bigger angular acceleration.
@export_group("PID Roll")
@export var roll_p: float = 0.024
@export var roll_i: float = 0.008
@export var roll_d: float = 0.0022

@export_group("PID Pitch")
@export var pitch_p: float = 0.024
@export var pitch_i: float = 0.008
@export var pitch_d: float = 0.0022

@export_group("PID Yaw")
@export var yaw_p: float = 0.016
@export var yaw_i: float = 0.0025
@export var yaw_d: float = 0.0

@export_group("Camera")
@export_range(0.0, 90.0, 0.5) var camera_angle_deg: float = 25.0
@export_range(50.0, 150.0, 1.0) var camera_fov_deg: float = 80.0

@export_group("Throttle")
## >1 softens low-stick response (more resolution around hover) and
## sharpens the top end; 1.0 is linear.
@export_range(0.5, 3.0, 0.05) var throttle_curve: float = 1.6

# Motor order: front-right, front-left, back-right, back-left.
const ROLL_MIX: Array[float] = [1.0, -1.0, 1.0, -1.0]
const PITCH_MIX: Array[float] = [1.0, 1.0, -1.0, -1.0]

## Pure safety ceilings, well above anything normal flight ever produces
## (top speed is ~41.7 m/s, acro's max_rate_deg tops out around 11.7
## rad/s) - they only ever engage right after a hard collision. Measured
## empirically (headless tumbling-impact test) that a corner hit could
## momentarily spike angular velocity to ~39 rad/s (2234 deg/s), which
## reads as the drone "going haywire" after a crash even though nothing
## was actually clipping through geometry.
const MAX_LINEAR_SPEED: float = 60.0
const MAX_ANGULAR_SPEED: float = 20.0

var motor_positions: Array[Vector3] = []

var _roll_pid := PIDController.new()
var _pitch_pid := PIDController.new()
var _yaw_pid := PIDController.new()

var _spawn_transform: Transform3D

@onready var _camera_mount: Node3D = $CameraMount
@onready var _camera: Camera3D = $CameraMount/Camera3D

func _ready() -> void:
	center_sensitivity_deg = Settings.rate_center_sensitivity_deg
	max_rate_deg = Settings.rate_max_deg
	_spawn_transform = global_transform
	motor_positions = [
		Vector3(arm_length, 0.0, -arm_length),  # front right
		Vector3(-arm_length, 0.0, -arm_length), # front left
		Vector3(arm_length, 0.0, arm_length),   # back right
		Vector3(-arm_length, 0.0, arm_length),  # back left
	]
	_apply_camera_settings()

func _physics_process(delta: float) -> void:
	if linear_velocity.length() > MAX_LINEAR_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_LINEAR_SPEED
	if angular_velocity.length() > MAX_ANGULAR_SPEED:
		angular_velocity = angular_velocity.normalized() * MAX_ANGULAR_SPEED

	_roll_pid.kp = roll_p
	_roll_pid.ki = roll_i
	_roll_pid.kd = roll_d
	_pitch_pid.kp = pitch_p
	_pitch_pid.ki = pitch_i
	_pitch_pid.kd = pitch_d
	_yaw_pid.kp = yaw_p
	_yaw_pid.ki = yaw_i
	_yaw_pid.kd = yaw_d

	_apply_camera_settings()

	var speed_sq: float = linear_velocity.length_squared()
	if speed_sq > 0.0001:
		apply_central_force(-linear_velocity.normalized() * drag_coefficient * speed_sq)

	if InputManager.reset_key_pressed():
		reset_to_spawn()
		return

	if not InputManager.armed:
		_roll_pid.reset()
		_pitch_pid.reset()
		_yaw_pid.reset()
		return

	var roll_in: float = InputManager.get_roll()
	var pitch_in: float = InputManager.get_pitch()
	var yaw_in: float = InputManager.get_yaw()
	var throttle_in: float = InputManager.get_throttle()

	var desired_roll_rate: float
	var desired_pitch_rate: float
	if InputManager.self_level:
		var rates: Vector2 = _compute_self_level_rates(roll_in, pitch_in)
		desired_roll_rate = rates.x
		desired_pitch_rate = rates.y
	else:
		desired_roll_rate = _actual_rate(roll_in)
		desired_pitch_rate = _actual_rate(pitch_in)
	var desired_yaw_rate: float = _actual_rate(yaw_in)

	# Angular velocity in the drone's own body frame (roll = about local Z,
	# pitch = about local X, yaw = about local Y, since -Z is "forward").
	var local_ang_vel: Vector3 = global_transform.basis.inverse() * angular_velocity

	var roll_out: float = _roll_pid.update(desired_roll_rate - local_ang_vel.z, delta)
	var pitch_out: float = _pitch_pid.update(desired_pitch_rate - local_ang_vel.x, delta)
	var yaw_out: float = _yaw_pid.update(desired_yaw_rate - local_ang_vel.y, delta)

	var throttle_shaped: float = pow(throttle_in, throttle_curve)
	var throttle_force_total: float = throttle_shaped * max_motor_thrust_n * 4.0
	var up_global: Vector3 = global_transform.basis.y

	for i in range(4):
		var thrust: float = throttle_force_total / 4.0
		thrust += roll_out * ROLL_MIX[i]
		thrust += pitch_out * PITCH_MIX[i]
		thrust = clamp(thrust, 0.0, max_motor_thrust_n)
		var offset: Vector3 = global_transform.basis * motor_positions[i]
		apply_force(up_global * thrust, offset)

	apply_torque(up_global * yaw_out)

## Betaflight-style Actual Rates curve: soft near center (slope =
## center_sensitivity_deg), steep at full stick (reaches max_rate_deg).
func _actual_rate(stick: float) -> float:
	var deg: float = center_sensitivity_deg * stick + (max_rate_deg - center_sensitivity_deg) * stick * stick * stick
	return deg_to_rad(deg)

## Angle mode's outer attitude loop, robust to ANY orientation including
## upside-down. Extracting separate roll/pitch angles with asin() (the
## old approach) has a blind spot: asin(sin(x)) folds anything past 90
## degrees back down, so a drone tilted 170 degrees (nearly inverted)
## reads as only 10 degrees off - the controller then applies a tiny
## correction when it needs a huge one, and as the true angle keeps
## changing the reading swings non-monotonically, which is what read as
## "it can spin" after a hard crash tumbles it upside-down. Verified
## empirically (frame-by-frame headless test) that recovery from a
## near-inverted start swung angular velocity up to ~500 deg/s before
## settling under the old method.
##
## This instead compares the body's up vector to a target up vector
## (built from stick input in the drone's current heading frame) via
## cross/dot product - well-defined for any angle except the exact
## 180-degree singularity every attitude representation has.
func _compute_self_level_rates(roll_in: float, pitch_in: float) -> Vector2:
	var world_up := Vector3.UP
	var current_up: Vector3 = global_transform.basis.y

	var fwd_h: Vector3 = -global_transform.basis.z
	fwd_h.y = 0.0
	if fwd_h.length_squared() < 0.0001:
		fwd_h = -global_transform.basis.x
		fwd_h.y = 0.0
	fwd_h = fwd_h.normalized()
	var right_h: Vector3 = fwd_h.cross(world_up)

	var target_roll_angle: float = roll_in * deg_to_rad(max_angle_deg)
	var target_pitch_angle: float = pitch_in * deg_to_rad(max_angle_deg)

	# Rodrigues' rotation formula, simplified since the rotation axes
	# here are always perpendicular to the vector being rotated.
	var target_up: Vector3 = world_up * cos(target_pitch_angle) + right_h.cross(world_up) * sin(target_pitch_angle)
	target_up = target_up * cos(target_roll_angle) + fwd_h.cross(target_up) * sin(target_roll_angle)

	var error_axis: Vector3 = current_up.cross(target_up)
	var error_axis_len: float = error_axis.length()
	var error_angle: float = asin(clamp(error_axis_len, -1.0, 1.0))
	if current_up.dot(target_up) < 0.0:
		error_angle = PI - error_angle # more than 90 degrees off - unfold asin's reflection
	if error_axis_len > 0.0001:
		error_axis /= error_axis_len
	else:
		error_axis = fwd_h # current/target exactly aligned or exactly opposite - pick an arbitrary recovery axis

	var max_rate_rad: float = deg_to_rad(max_rate_deg)
	var correction: Vector3 = error_axis * error_angle * angle_p_gain
	var correction_local: Vector3 = global_transform.basis.inverse() * correction
	return Vector2(
		clamp(correction_local.z, -max_rate_rad, max_rate_rad),
		clamp(correction_local.x, -max_rate_rad, max_rate_rad)
	)

func _apply_camera_settings() -> void:
	if _camera_mount == null:
		return
	var rot: Vector3 = _camera_mount.rotation_degrees
	rot.x = camera_angle_deg
	_camera_mount.rotation_degrees = rot
	if _camera:
		_camera.fov = camera_fov_deg

func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_roll_pid.reset()
	_pitch_pid.reset()
	_yaw_pid.reset()
