class_name HollowBuilding
extends StaticBody3D

## Generic hollow rectangular building: floor, ceiling, and four walls,
## each independently punched with a single rectangular opening (a door
## or window - width 0 leaves that wall solid). Reused for both the
## small houses (one door + one window + an interior partition, i.e.
## separate rooms) and the second map's big fly-through factory
## buildings (openings on opposite walls, no partition, no interior
## wall needed). One StaticBody3D holds every wall segment's
## CollisionShape3D as sibling children - no need for a separate
## physics body per segment since none of them ever move relative to
## each other.

@export_group("Size")
@export var size: Vector3 = Vector3(9.0, 7.0, 9.0)
@export var wall_thickness: float = 0.4

## Each opening's width is measured along the wall it's cut into; 0
## leaves that wall solid. bottom/top are local heights measured up from
## the floor (0 = floor level, so bottom 0 means the opening reaches the
## floor, e.g. a door).
@export_group("Front Opening (-Z wall)")
@export var front_width: float = 0.0
@export var front_bottom: float = 0.0
@export var front_top: float = 0.0
@export_group("Back Opening (+Z wall)")
@export var back_width: float = 0.0
@export var back_bottom: float = 0.0
@export var back_top: float = 0.0
@export_group("Left Opening (-X wall)")
@export var left_width: float = 0.0
@export var left_bottom: float = 0.0
@export var left_top: float = 0.0
@export_group("Right Opening (+X wall)")
@export var right_width: float = 0.0
@export var right_bottom: float = 0.0
@export var right_top: float = 0.0

@export_group("Interior Partition (splits the interior along Z, full height)")
@export var has_partition: bool = false
@export var partition_local_z: float = 0.0
@export var partition_gap_width: float = 2.2

@export_group("Appearance")
@export var wall_color: Color = Color(0.7, 0.52, 0.38)
@export var floor_color: Color = Color(0.5, 0.47, 0.42)
@export var add_floor: bool = true
@export var add_ceiling: bool = true

func _ready() -> void:
	_build()

func _build() -> void:
	var hx: float = size.x * 0.5
	var hy: float = size.y
	var hz: float = size.z * 0.5
	var t: float = wall_thickness

	if add_floor:
		_add_box(Vector3(0, -t * 0.5, 0), Vector3(size.x, t, size.z), floor_color)
	if add_ceiling:
		_add_box(Vector3(0, hy + t * 0.5, 0), Vector3(size.x, t, size.z), floor_color)

	# Front/back walls run along X, thin along Z; left/right run along Z,
	# thin along X.
	_add_wall(Vector3(0, 0, -hz), size.x, hy, t, true, front_width, front_bottom, front_top)
	_add_wall(Vector3(0, 0, hz), size.x, hy, t, true, back_width, back_bottom, back_top)
	_add_wall(Vector3(-hx, 0, 0), size.z, hy, t, false, left_width, left_bottom, left_top)
	_add_wall(Vector3(hx, 0, 0), size.z, hy, t, false, right_width, right_bottom, right_top)

	if has_partition:
		_add_wall(Vector3(0, 0, partition_local_z), size.x, hy, t, true, partition_gap_width, 0.0, hy)

## `center` is the wall's centerline at floor level (y=0 local - height
## gets added on top per segment). `along_x` is true for walls that run
## along X (front/back/partition), false for walls that run along Z
## (left/right).
func _add_wall(center: Vector3, span: float, height: float, thickness: float, along_x: bool, opening_width: float, opening_bottom: float, opening_top: float) -> void:
	if opening_width <= 0.0 or opening_top <= opening_bottom:
		var full_size: Vector3 = Vector3(span, height, thickness) if along_x else Vector3(thickness, height, span)
		_add_box(center + Vector3(0, height * 0.5, 0), full_size, wall_color)
		return

	var side_len: float = (span - opening_width) * 0.5
	var offset: float = (opening_width + side_len) * 0.5
	var side_size: Vector3 = Vector3(side_len, height, thickness) if along_x else Vector3(thickness, height, side_len)
	var side_a_center: Vector3 = center + (Vector3(-offset, height * 0.5, 0) if along_x else Vector3(0, height * 0.5, -offset))
	var side_b_center: Vector3 = center + (Vector3(offset, height * 0.5, 0) if along_x else Vector3(0, height * 0.5, offset))
	_add_box(side_a_center, side_size, wall_color)
	_add_box(side_b_center, side_size, wall_color)

	if opening_bottom > 0.0:
		var sill_size: Vector3 = Vector3(opening_width, opening_bottom, thickness) if along_x else Vector3(thickness, opening_bottom, opening_width)
		_add_box(center + Vector3(0, opening_bottom * 0.5, 0), sill_size, wall_color)
	if opening_top < height:
		var lintel_h: float = height - opening_top
		var lintel_size: Vector3 = Vector3(opening_width, lintel_h, thickness) if along_x else Vector3(thickness, lintel_h, opening_width)
		_add_box(center + Vector3(0, opening_top + lintel_h * 0.5, 0), lintel_size, wall_color)

func _add_box(center: Vector3, box_size: Vector3, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = box_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = center
	mi.set_surface_override_material(0, mat)
	add_child(mi)

	var shape := BoxShape3D.new()
	shape.size = box_size
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.position = center
	add_child(cs)
