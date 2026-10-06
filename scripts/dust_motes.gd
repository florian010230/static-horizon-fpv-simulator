class_name DustMotes
extends MultiMeshInstance3D

## Light dust motes in the air of indoor and abandoned maps
## (shaders/dust_motes.gdshader): one draw call, all motion in the vertex
## shader. Count by graphics quality; none on Low.

const COUNT: Array[int] = [0, 220, 420]

func _init(quality: int = 1) -> void:
	name = "DustMotes"
	set_meta("dynamic", true)
	var quad := QuadMesh.new()
	quad.size = Vector2(1, 1)
	var m := ShaderMaterial.new()
	m.shader = preload("res://shaders/dust_motes.gdshader")
	quad.material = m
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = quad
	var n: int = COUNT[clampi(quality, 0, 2)]
	mm.instance_count = n
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for i in range(n):
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(rng.randf(), rng.randf(), rng.randf()) * 14.0))
	multimesh = mm
	# Drawn round the camera wherever it is: never culled.
	custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
