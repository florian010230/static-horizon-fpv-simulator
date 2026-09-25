class_name Drone
extends RigidBody3D

## Simplified quadcopter (X-frame) acro/rate-mode flight model.
##
## Sticks set a target ANGULAR RATE per axis (like Betaflight acro mode),
## a PID loop per axis drives the actual rate towards that target, and the
## PID outputs are mixed into 4 virtual motor thrusts (roll/pitch) plus a
## direct reaction torque (yaw - a spinning prop's drag torque can't be
## produced by a purely vertical thrust force, so it's modelled directly).

@export_group("Frame")
@export var arm_length: float = 0.11
@export var max_motor_thrust_n: float = 6.0

@export_group("Rates (deg/s)")
@export var max_roll_pitch_rate_deg: float = 300.0
@export var max_yaw_rate_deg: float = 180.0

@export_group("PID Roll")
@export var roll_p: float = 0.06
@export var roll_i: float = 0.02
@export var roll_d: float = 0.004

@export_group("PID Pitch")
@export var pitch_p: float = 0.06
@export var pitch_i: float = 0.02
@export var pitch_d: float = 0.004

@export_group("PID Yaw")
@export var yaw_p: float = 0.08
@export var yaw_i: float = 0.01
@export var yaw_d: float = 0.0

@export_group("Camera")
@export_range(0.0, 90.0, 0.5) var camera_angle_deg: float = 25.0

# Motor order: front-right, front-left, back-right, back-left.
const ROLL_MIX: Array[float] = [1.0, -1.0, 1.0, -1.0]
const PITCH_MIX: Array[float] = [1.0, 1.0, -1.0, -1.0]

var motor_positions: Array[Vector3] = []

var _roll_pid := PIDController.new()
var _pitch_pid := PIDController.new()
var _yaw_pid := PIDController.new()

var _spawn_transform: Transform3D

@onready var _camera_mount: Node3D = $CameraMount

func _ready() -> void:
	_spawn_transform = global_transform
	motor_positions = [
		Vector3(arm_length, 0.0, -arm_length),  # front right
		Vector3(-arm_length, 0.0, -arm_length), # front left
		Vector3(arm_length, 0.0, arm_length),   # back right
		Vector3(-arm_length, 0.0, arm_length),  # back left
	]
	_apply_camera_angle()

func _physics_process(delta: float) -> void:
	_roll_pid.kp = roll_p
	_roll_pid.ki = roll_i
	_roll_pid.kd = roll_d
	_pitch_pid.kp = pitch_p
	_pitch_pid.ki = pitch_i
	_pitch_pid.kd = pitch_d
	_yaw_pid.kp = yaw_p
	_yaw_pid.ki = yaw_i
	_yaw_pid.kd = yaw_d

	_apply_camera_angle()

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

	var desired_roll_rate: float = roll_in * deg_to_rad(max_roll_pitch_rate_deg)
	var desired_pitch_rate: float = pitch_in * deg_to_rad(max_roll_pitch_rate_deg)
	var desired_yaw_rate: float = yaw_in * deg_to_rad(max_yaw_rate_deg)

	# Angular velocity in the drone's own body frame (roll = about local Z,
	# pitch = about local X, yaw = about local Y, since -Z is "forward").
	var local_ang_vel: Vector3 = global_transform.basis.inverse() * angular_velocity

	var roll_out: float = _roll_pid.update(desired_roll_rate - local_ang_vel.z, delta)
	var pitch_out: float = _pitch_pid.update(desired_pitch_rate - local_ang_vel.x, delta)
	var yaw_out: float = _yaw_pid.update(desired_yaw_rate - local_ang_vel.y, delta)

	var throttle_force_total: float = throttle_in * max_motor_thrust_n * 4.0
	var up_global: Vector3 = global_transform.basis.y

	for i in range(4):
		var thrust: float = throttle_force_total / 4.0
		thrust += roll_out * ROLL_MIX[i]
		thrust += pitch_out * PITCH_MIX[i]
		thrust = clamp(thrust, 0.0, max_motor_thrust_n)
		var offset: Vector3 = global_transform.basis * motor_positions[i]
		apply_force(up_global * thrust, offset)

	apply_torque(up_global * yaw_out)

func _apply_camera_angle() -> void:
	if _camera_mount == null:
		return
	var rot: Vector3 = _camera_mount.rotation_degrees
	rot.x = -camera_angle_deg
	_camera_mount.rotation_degrees = rot

func reset_to_spawn() -> void:
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	_roll_pid.reset()
	_pitch_pid.reset()
	_yaw_pid.reset()
