class_name DroneFrameBuilder
extends RefCounted

## Builds a recognizable quad frame (center stack, 4 arms, 4 motor bells,
## 4 prop discs, optional prop guards) out of primitive meshes only - no
## external model files, matching the rest of the project. Shared between
## the real flying Drone (drone.gd) and the main menu's decorative preview
## stand-in, so both drones get the same non-brick look from one place
## instead of two hand-maintained copies.
##
## profile keys: arm_length, body_radius, body_height, arm_thickness,
## motor_radius, motor_height, prop_radius, has_prop_guards, frame_color,
## optionally motor_color/prop_color/guard_color.

static func build(parent: Node3D, profile: Dictionary) -> void:
	var arm_length: float = profile.arm_length
	var frame_color: Color = profile.frame_color
	var motor_color: Color = profile.get("motor_color", Color(0.08, 0.08, 0.08))
	var prop_color: Color = profile.get("prop_color", Color(0.85, 0.85, 0.88, 0.35))
	var guard_color: Color = profile.get("guard_color", Color(0.88, 0.88, 0.9, 0.55))

	_add_cylinder(parent, Vector3.ZERO, profile.body_radius, profile.body_height, frame_color, false, "Body")
	_add_camera_pod(parent, profile.body_radius, profile.body_height)
	_add_antenna(parent, profile.body_radius, arm_length)

	var motor_positions: Array[Vector3] = [
		Vector3(arm_length, 0.0, -arm_length),
		Vector3(-arm_length, 0.0, -arm_length),
		Vector3(arm_length, 0.0, arm_length),
		Vector3(-arm_length, 0.0, arm_length),
	]
	var names := ["FR", "FL", "BR", "BL"]
	for i in range(4):
		var to: Vector3 = motor_positions[i]
		_add_arm(parent, to, profile.arm_thickness, frame_color, "Arm%s" % names[i])
		_add_cylinder(parent, to + Vector3(0, profile.motor_height * 0.5, 0), profile.motor_radius, profile.motor_height, motor_color, false, "Motor%s" % names[i])
		_add_cylinder(parent, to + Vector3(0, profile.motor_height + 0.002, 0), profile.prop_radius, 0.003, prop_color, true, "Prop%s" % names[i])
		if profile.has_prop_guards:
			_add_torus(parent, to + Vector3(0, profile.motor_height * 0.5, 0), profile.prop_radius + 0.003, 0.0025, guard_color, "Guard%s" % names[i])

## A box whose long axis (local Z) is pointed at `to` via Basis.looking_at()
## instead of a hand-derived rotation matrix - this project has been burned
## before by hand-derived basis math for horizontal members (see the factory
## map's connecting pipes). Basis.looking_at() takes a direction, not a
## world position, so - unlike look_at_from_position(), which operates in
## global space and silently misplaces the arm the moment its parent has
## any rotation of its own (e.g. the tilted menu preview, or the drone
## itself mid-flight) - this stays correct in the parent's local space no
## matter how that parent is oriented.
static func _add_arm(parent: Node3D, to: Vector3, thickness: float, color: Color, node_name: String) -> void:
	var mid: Vector3 = to * 0.5
	var mesh := BoxMesh.new()
	mesh.size = Vector3(thickness, thickness, to.length())
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mi.set_surface_override_material(0, mat)
	mi.name = node_name
	mi.transform = Transform3D(Basis.looking_at(to.normalized(), Vector3.UP), mid)
	parent.add_child(mi)

static func _add_cylinder(parent: Node3D, pos: Vector3, radius: float, height: float, color: Color, transparent: bool, node_name: String) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 10
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if transparent:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.set_surface_override_material(0, mat)
	mi.name = node_name
	parent.add_child(mi)
	return mi

## A forward-tilted camera pod with a dark lens - every real FPV quad has
## one, and its absence was a big part of what read as "just a brick"
## even after arms and motors were added.
static func _add_camera_pod(parent: Node3D, body_radius: float, body_height: float) -> void:
	var pod_radius: float = body_radius * 0.4
	var pod: MeshInstance3D = _add_cylinder(parent, Vector3(0, body_height * 0.4, -body_radius * 0.75), pod_radius, pod_radius * 1.5, Color(0.1, 0.1, 0.11), false, "CameraPod")
	pod.rotation_degrees = Vector3(65, 0, 0)
	var lens: MeshInstance3D = _add_cylinder(parent, Vector3(0, body_height * 0.4, -body_radius * 1.05), pod_radius * 0.5, pod_radius * 0.4, Color(0.05, 0.12, 0.16), false, "CameraLens")
	lens.rotation_degrees = Vector3(65, 0, 0)

## A thin VTX whip antenna sticking up and back - the other detail (along
## with the camera pod) that most separates a real quad's silhouette from
## a plain body-plus-motors shape.
static func _add_antenna(parent: Node3D, body_radius: float, arm_length: float) -> void:
	var length: float = arm_length * 1.5
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.0015
	mesh.bottom_radius = 0.0035
	mesh.height = length
	mesh.radial_segments = 6
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.08)
	mi.set_surface_override_material(0, mat)
	mi.name = "Antenna"
	mi.position = Vector3(0, length * 0.42, body_radius * 0.6)
	mi.rotation_degrees = Vector3(-22, 0, 0)
	parent.add_child(mi)

static func _add_torus(parent: Node3D, pos: Vector3, radius: float, tube_radius: float, color: Color, node_name: String) -> void:
	var mesh := TorusMesh.new()
	mesh.inner_radius = radius - tube_radius
	mesh.outer_radius = radius + tube_radius
	mesh.rings = 12
	mesh.ring_segments = 8
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.set_surface_override_material(0, mat)
	mi.name = node_name
	parent.add_child(mi)
