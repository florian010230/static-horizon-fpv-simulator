class_name Bird
extends Node3D

## Easter egg (2026-10-14, Village): a small bird sits on the church roof's
## ridge. Come within ALERT metres and it flaps its wings and flies off in
## a curve, up and away from the drone, then is gone for good (freed). A
## runtime node, not map geometry: meta "dynamic" keeps it out of the
## static shadow map. It only looks at the drone's distance, one check per
## frame, and sleeps (no work but that check) until then.

const ALERT: float = 6.0
const FLIGHT_TIME: float = 7.0

var drone: Node3D
var _t: float = -1.0
var _heading: Vector3 = Vector3.FORWARD
var _turn: float = 0.5
var _left: Node3D
var _right: Node3D

func _init() -> void:
	set_meta("dynamic", true)
	name = "Bird"
	_build()

func _box(parent: Node3D, pos: Vector3, size: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)

## Sparrow-sized: ~15 cm long, facing -z. Origin = under the feet.
func _build() -> void:
	var brown := Color(0.42, 0.33, 0.26)
	var dark := Color(0.28, 0.22, 0.18)
	_box(self, Vector3(0, 0.05, 0), Vector3(0.07, 0.065, 0.13), brown)
	_box(self, Vector3(0, 0.085, -0.075), Vector3(0.055, 0.055, 0.055), dark)
	_box(self, Vector3(0, 0.08, -0.108), Vector3(0.012, 0.012, 0.025), Color(0.9, 0.6, 0.15))
	_box(self, Vector3(0, 0.05, 0.105), Vector3(0.04, 0.012, 0.09), dark)
	_box(self, Vector3(-0.015, 0.012, 0), Vector3(0.006, 0.024, 0.006), Color(0.8, 0.5, 0.4))
	_box(self, Vector3(0.015, 0.012, 0), Vector3(0.006, 0.024, 0.006), Color(0.8, 0.5, 0.4))
	_left = Node3D.new()
	_right = Node3D.new()
	_left.position = Vector3(-0.036, 0.07, 0.0)
	_right.position = Vector3(0.036, 0.07, 0.0)
	add_child(_left)
	add_child(_right)
	_box(_left, Vector3(-0.07, 0, 0.0), Vector3(0.14, 0.008, 0.075), dark)
	_box(_right, Vector3(0.07, 0, 0.0), Vector3(0.14, 0.008, 0.075), dark)
	_fold(0.0)

## Wing angle: 0 = folded against the body, 1 = flat out, -0.6 = up.
func _fold(open: float) -> void:
	var a: float = lerpf(1.35, 0.0, open)
	_left.rotation.z = a
	_right.rotation.z = -a

func _process(delta: float) -> void:
	if _t < 0.0:
		if drone == null or not is_instance_valid(drone) or not is_inside_tree():
			return
		var away: Vector3 = global_position - drone.global_position
		if away.length() < ALERT:
			away.y = 0.0
			_heading = away.normalized() if away.length() > 0.01 else Vector3.RIGHT
			_turn = 0.55 if fmod(absf(global_position.x), 2.0) < 1.0 else -0.55
			_t = 0.0
		return
	_t += delta
	var flap: float = sin(_t * 42.0)
	_fold(0.5 + 0.9 * flap if _t < FLIGHT_TIME - 1.0 else 0.2)
	_heading = _heading.rotated(Vector3.UP, _turn * delta)
	var speed: float = minf(3.0 + _t * 3.0, 8.5)
	var climb: float = 3.0 * (1.0 - smoothstep(0.0, 4.0, _t)) + 0.8
	global_position += _heading * speed * delta + Vector3(0, climb * delta, 0)
	rotation.y = atan2(-_heading.x, -_heading.z)
	rotation.x = -0.25
	if _t > FLIGHT_TIME:
		queue_free()
