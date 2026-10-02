class_name WorldBorder
extends RefCounted

## Shared boundary check for every map. The play area is meant to read as
## endless (distant backdrop hills/sky, or just a big room) rather than
## visibly walled off, so there's no solid collision fence - past
## warning_radius/warning_height a HUD warning kicks in and the whole
## border appears (a glowing grid, see shaders/border.gdshader); past
## reset_radius/reset_height the drone is put back at its spawn point
## at once, same idea as an FPV radio losing link range far from the
## pilot. Call check() once per frame from each map's
## _process() with its own drone/UI/radii.

const FADE_SPEED: float = 4.0
## The last border checked (for the dev preview's border test).
static var last: Dictionary = {}
## Off for the dev preview's map pictures (cameras far out and high up).
static var disabled: bool = false

static func check(drone: Node3D, ui: Node, warning_radius: float, reset_radius: float, warning_height: float, reset_height: float, tree: SceneTree, centre: Vector2 = Vector2.ZERO) -> void:
	if drone == null or disabled:
		return
	last = {"kind": "circle", "r": warning_radius, "h": warning_height, "c": centre}
	var origin: Vector3 = drone.global_transform.origin
	var horiz_dist: float = (Vector2(origin.x, origin.z) - centre).length()
	var beyond: bool = horiz_dist > reset_radius or origin.y > reset_height
	if beyond:
		_out_of_range(drone, ui)
		return
	var warning: bool = horiz_dist > warning_radius or origin.y > warning_height
	if ui and ui.has_method("set_border_warning"):
		ui.set_border_warning(warning)
	_show(drone, warning, func(root: Node3D) -> Node3D:
		return _circle_border(root, warning_radius, warning_height, centre))

## Same idea for a map that isn't open ground around the origin: an
## axis-aligned box (the school's own footprint). Inside a fully enclosed
## building you can't normally leave it at all - this only catches the
## drone if it ever clips out (or flies out of an office window). The
## reset margin must be several metres: with 1 m the warning - and the
## border - showed for a split second before the reset.
static func check_box(drone: Node3D, ui: Node, box_min: Vector3, box_max: Vector3, reset_margin: float, tree: SceneTree) -> void:
	if drone == null or disabled:
		return
	last = {"kind": "box", "min": box_min, "max": box_max, "margin": reset_margin}
	var p: Vector3 = drone.global_transform.origin
	var outer_min: Vector3 = box_min - Vector3.ONE * reset_margin
	var outer_max: Vector3 = box_max + Vector3.ONE * reset_margin
	if p.x < outer_min.x or p.y < outer_min.y or p.z < outer_min.z or p.x > outer_max.x or p.y > outer_max.y or p.z > outer_max.z:
		_out_of_range(drone, ui)
		return
	var outside: bool = p.x < box_min.x or p.y < box_min.y or p.z < box_min.z or p.x > box_max.x or p.y > box_max.y or p.z > box_max.z
	if ui and ui.has_method("set_border_warning"):
		ui.set_border_warning(outside)
	_show(drone, outside, func(root: Node3D) -> Node3D:
		var mi := MeshInstance3D.new()
		var box := BoxMesh.new()
		# 1 m outside the box: on it, the building's own walls hid it.
		box.size = box_max - box_min + Vector3.ONE * 2.0
		mi.mesh = box
		mi.position = (box_min + box_max) * 0.5
		root.add_child(mi)
		return mi)

## Past the reset line: back to the spawn point at once, like pressing R
## (it used to reload the whole map behind the loading screen).
static func _out_of_range(drone: Node3D, ui: Node) -> void:
	if drone.has_method("reset_to_spawn"):
		drone.reset_to_spawn()
		if ui and ui.has_method("flash_message"):
			ui.flash_message("OUT OF RANGE - BACK TO START")
	else:
		SceneLoader.reload("Out of range - restarting")

## Fades the border in/out, building it the first time it's needed.
static func _show(drone: Node3D, on: bool, make: Callable) -> void:
	var root: Node3D = drone.get_parent() as Node3D
	if root == null:
		return
	var border: Node3D = root.get_node_or_null("FlightBorder") as Node3D
	if border == null:
		if not on:
			return
		border = make.call(root)
		border.name = "FlightBorder"
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://shaders/border.gdshader")
		border.set_meta("mat", mat)
		for mi in [border] + border.get_children():
			if mi is MeshInstance3D:
				mi.material_override = mat
				mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				mi.set_meta("keep_material", true)
		border.set_meta("dynamic", true)
	var m: ShaderMaterial = border.get_meta("mat")
	var s: float = border.get_meta("strength", 0.0)
	s = move_toward(s, 1.0 if on else 0.0, FADE_SPEED * drone.get_process_delta_time())
	border.set_meta("strength", s)
	m.set_shader_parameter("strength", s)
	m.set_shader_parameter("drone_pos", drone.global_position)
	border.visible = s > 0.0

## A wall at the warning radius and a ceiling at the warning height.
static func _circle_border(root: Node3D, r: float, h: float, centre: Vector2) -> Node3D:
	var holder := MeshInstance3D.new()
	var wall := CylinderMesh.new()
	wall.top_radius = r
	wall.bottom_radius = r
	wall.height = h + 60.0
	wall.radial_segments = maxi(64, int(r / 6.0))
	wall.cap_top = false
	wall.cap_bottom = false
	holder.mesh = wall
	holder.position = Vector3(centre.x, (h + 60.0) * 0.5 - 30.0, centre.y)
	root.add_child(holder)
	var roof := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.01
	disc.radial_segments = wall.radial_segments
	roof.mesh = disc
	roof.position = Vector3(0, h - holder.position.y, 0)
	holder.add_child(roof)
	return holder
