class_name WorldBorder
extends RefCounted

## Shared boundary check for every map. The play area is meant to read as
## endless (distant backdrop hills/sky, or just a big room) rather than
## visibly walled off, so there's no solid collision fence anymore - past
## warning_radius/warning_height a HUD warning kicks in, and past
## reset_radius/reset_height the current map reloads from scratch, same
## idea as an FPV radio losing link range far from the pilot. Call
## check() once per frame from each map's _process() with its own
## drone/UI/radii - horizontal distance is measured from world (0,0),
## which every map's play area is centered on.

static func check(drone: Node3D, ui: Node, warning_radius: float, reset_radius: float, warning_height: float, reset_height: float, tree: SceneTree, centre: Vector2 = Vector2.ZERO) -> void:
	if drone == null:
		return
	var origin: Vector3 = drone.global_transform.origin
	var horiz_dist: float = (Vector2(origin.x, origin.z) - centre).length()
	var beyond: bool = horiz_dist > reset_radius or origin.y > reset_height
	if beyond:
		SceneLoader.reload("Out of range - restarting")
		return
	var warning: bool = horiz_dist > warning_radius or origin.y > warning_height
	if ui and ui.has_method("set_border_warning"):
		ui.set_border_warning(warning)

## Same idea for a map that isn't open ground around the origin: an
## axis-aligned box (the school's own footprint). Inside a fully enclosed
## building you can't normally leave it at all - this only catches the
## drone if it ever clips out, instead of the old circle around (0,0),
## which didn't even match where the school stands.
static func check_box(drone: Node3D, ui: Node, box_min: Vector3, box_max: Vector3, reset_margin: float, tree: SceneTree) -> void:
	if drone == null:
		return
	var p: Vector3 = drone.global_transform.origin
	var outer_min: Vector3 = box_min - Vector3.ONE * reset_margin
	var outer_max: Vector3 = box_max + Vector3.ONE * reset_margin
	if p.x < outer_min.x or p.y < outer_min.y or p.z < outer_min.z or p.x > outer_max.x or p.y > outer_max.y or p.z > outer_max.z:
		SceneLoader.reload("Out of range - restarting")
		return
	var outside: bool = p.x < box_min.x or p.y < box_min.y or p.z < box_min.z or p.x > box_max.x or p.y > box_max.y or p.z > box_max.z
	if ui and ui.has_method("set_border_warning"):
		ui.set_border_warning(outside)
