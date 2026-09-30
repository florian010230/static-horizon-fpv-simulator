extends StaticBody3D

## A parked car: body color set per instance, so a row of them doesn't
## look copy-pasted. Length runs along local X.

@export var body_color: Color = Color(0.7, 0.1, 0.1)

func _ready() -> void:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = body_color
	mat.metallic = 0.3
	mat.roughness = 0.35
	($Body as MeshInstance3D).set_surface_override_material(0, mat)
