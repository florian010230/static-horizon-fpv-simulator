class_name SunGlare
extends ColorRect

## Sun glare (shaders/sun_glare.gdshader): a full-screen additive pass,
## only drawn while the sun is in or near the camera's view and not
## hidden behind something (one ray toward the sun per frame, faded so
## the flare blooms and dies smoothly, like a real lens). Outdoor maps
## with a Sun only. Made by LooksFx under the camera look.

var _sun: DirectionalLight3D
var _mat: ShaderMaterial
var _vis: float = 0.0
var _ray_t: float = 0.0
var _clear: bool = true

func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = preload("res://shaders/sun_glare.gdshader")
	material = _mat
	visible = false

func setup(sun: DirectionalLight3D) -> void:
	_sun = sun
	_mat.set_shader_parameter("tint", sun.light_color.lerp(Color(1.0, 0.75, 0.5), 0.35 * (1.0 - clampf(sun.global_transform.basis.z.y, 0.0, 1.0))))

func _process(delta: float) -> void:
	var cam: Camera3D = get_viewport().get_camera_3d()
	if _sun == null or not is_instance_valid(_sun) or cam == null:
		visible = false
		return
	var to_sun: Vector3 = _sun.global_transform.basis.z.normalized()
	var fwd: Vector3 = -cam.global_transform.basis.z
	var ang: float = acos(clampf(fwd.dot(to_sun), -1.0, 1.0))
	var half: float = deg_to_rad(cam.fov) * 0.5 * maxf(get_viewport_rect().size.aspect(), 1.0)
	# Strongest with the sun in frame, still a veil just outside it.
	var aim: float = 1.0 - smoothstep(half * 0.6, half + 0.4, ang)
	_ray_t -= delta
	if aim > 0.0 and _ray_t <= 0.0:
		_ray_t = 0.05
		var q := PhysicsRayQueryParameters3D.create(cam.global_position, cam.global_position + to_sun * 3000.0)
		var drone := get_tree().current_scene.get_node_or_null("Drone") as CollisionObject3D
		if drone:
			q.exclude = [drone.get_rid()]
		_clear = cam.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	var target: float = aim * (1.0 if _clear else 0.0)
	_vis = lerpf(_vis, target, 1.0 - exp(-delta / 0.12))
	visible = _vis > 0.01
	if not visible:
		return
	var sun_uv: Vector2
	if not cam.is_position_behind(cam.global_position + to_sun * 100.0):
		sun_uv = cam.unproject_position(cam.global_position + to_sun * 100.0) / get_viewport_rect().size
	else:
		# Sun behind the camera (a fast turn while the glare still fades):
		# keep it off-screen on the side the sun went. It used to jump to
		# the middle of the screen and fade out there.
		var v: Vector3 = cam.global_transform.basis.inverse() * to_sun
		var side := Vector2(v.x, -v.y)
		sun_uv = Vector2(0.5, 0.5) + (side.normalized() if side.length() > 0.001 else Vector2(0.0, -1.0)) * 2.0
	_mat.set_shader_parameter("sun_uv", sun_uv)
	_mat.set_shader_parameter("strength", _vis)
	_mat.set_shader_parameter("aspect", get_viewport_rect().size.aspect())
