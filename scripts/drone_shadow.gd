class_name DroneShadow
extends MeshInstance3D

## A soft shadow under the drone, cast along the real sun direction onto
## whatever is below (grass, a roof, a table) - found with one raycast
## per frame. The world's static sun shadows (WorldShading) can't show a
## moving drone, and in FPV the most useful shadow of all:
## it's how a pilot judges height when landing or skimming the ground.
## Fades out with height; hidden when nothing is within reach.

const MAX_DISTANCE: float = 40.0
const SHADOW_ALPHA: float = 0.6

var drone: RigidBody3D
var sun: DirectionalLight3D
var _mat := StandardMaterial3D.new()

static var _blob: ImageTexture

## A soft round blob (radial falloff) rather than a hard-edged disc -
## small shadows under a real quad have no sharp outline.
static func _blob_texture() -> ImageTexture:
	if _blob == null:
		var n := 64
		var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
		for y in range(n):
			for x in range(n):
				var d: float = Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
				var a: float = clampf(1.0 - d, 0.0, 1.0)
				img.set_pixel(x, y, Color(0, 0, 0, a * a * (3.0 - 2.0 * a)))
		img.generate_mipmaps()
		_blob = ImageTexture.create_from_image(img)
	return _blob

func setup(d: RigidBody3D, s: DirectionalLight3D, span: float) -> void:
	drone = d
	sun = s
	var quad := PlaneMesh.new()
	quad.size = Vector2(span, span) * 1.5
	mesh = quad
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.albedo_texture = _blob_texture()
	_mat.albedo_color = Color(1, 1, 1, SHADOW_ALPHA)
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	top_level = true

func _process(_delta: float) -> void:
	if drone == null or sun == null:
		return
	var dir: Vector3 = -sun.global_transform.basis.z
	# The interpolated position - the same one the camera renders from
	# (physics interpolation is on), so the shadow doesn't lag or jitter
	# against the view between physics steps.
	var from: Vector3 = drone.get_global_transform_interpolated().origin
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * MAX_DISTANCE)
	query.exclude = [drone.get_rid()]
	var hit: Dictionary = drone.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		visible = false
		return
	visible = true
	var n: Vector3 = hit.normal
	global_transform = Transform3D(Basis(Quaternion(Vector3.UP, n)), hit.position + n * 0.01)
	var dist: float = from.distance_to(hit.position)
	var a: float = clampf(1.0 - dist / MAX_DISTANCE, 0.0, 1.0)
	_mat.albedo_color = Color(1, 1, 1, SHADOW_ALPHA * a)
	scale = Vector3.ONE * (1.0 + dist * 0.02) # a little softer/larger higher up
