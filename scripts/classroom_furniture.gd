class_name ClassroomFurniture
extends StaticBody3D

## Rows of two-person school desks with their chairs, generated at
## runtime. Every desk top, every desk frame and every chair is one
## MultiMesh instance (a handful of draw calls for a whole classroom
## instead of a few hundred nodes - this project targets integrated
## graphics), while each desk+chair pair still gets a real collision
## box, so a whoop clipping a desk actually hits it.
##
## Sizes from the usual German school furniture (DIN EN 1729, size 6-7
## for upper grades): desk 1.30 x 0.55 m at 0.76 m height, chair seat
## at 0.46 m. Local -X is the front of the room (where the board is):
## students face -X.

@export var rows: int = 4
@export var columns: int = 3
@export var row_spacing: float = 1.6
@export var column_spacing: float = 2.1
@export var desk_color: Color = Color(0.78, 0.62, 0.42)
@export var frame_color: Color = Color(0.25, 0.3, 0.36)
@export var chair_color: Color = Color(0.2, 0.45, 0.62)

const DESK := Vector3(0.55, 0.04, 1.3)
const DESK_H: float = 0.76
const SEAT_H: float = 0.46

func _ready() -> void:
	var tops: Array[Transform3D] = []
	var frames: Array[Transform3D] = []
	var seats: Array[Transform3D] = []
	var backs: Array[Transform3D] = []
	var chair_legs: Array[Transform3D] = []
	var x0: float = -(rows - 1) * row_spacing * 0.5
	var z0: float = -(columns - 1) * column_spacing * 0.5
	for r in range(rows):
		for c in range(columns):
			var x: float = x0 + r * row_spacing
			var z: float = z0 + c * column_spacing
			tops.append(Transform3D(Basis(), Vector3(x, DESK_H, z)))
			frames.append(Transform3D(Basis(), Vector3(x, DESK_H * 0.5, z)))
			for side in [-0.33, 0.33]:
				seats.append(Transform3D(Basis(), Vector3(x + 0.5, SEAT_H, z + side)))
				backs.append(Transform3D(Basis(), Vector3(x + 0.72, SEAT_H + 0.25, z + side)))
				chair_legs.append(Transform3D(Basis(), Vector3(x + 0.5, SEAT_H * 0.5, z + side)))
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.0, DESK_H + 0.02, DESK.z)
			var cs := CollisionShape3D.new()
			cs.shape = shape
			cs.position = Vector3(x + 0.25, (DESK_H + 0.02) * 0.5, z)
			add_child(cs)
	_multimesh(_box(DESK), desk_color, tops)
	# Frame: a slab under the top standing in for legs + modesty panel.
	_multimesh(_box(Vector3(0.05, DESK_H - 0.04, DESK.z - 0.1)), frame_color, frames)
	_multimesh(_box(Vector3(0.4, 0.03, 0.42)), chair_color, seats)
	_multimesh(_box(Vector3(0.03, 0.35, 0.42)), chair_color, backs)
	_multimesh(_box(Vector3(0.36, SEAT_H, 0.03)), frame_color, chair_legs)

func _box(s: Vector3) -> BoxMesh:
	var m := BoxMesh.new()
	m.size = s
	return m

func _multimesh(mesh: Mesh, color: Color, xforms: Array[Transform3D]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xforms.size()
	for i in range(xforms.size()):
		mm.set_instance_transform(i, xforms[i])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.6
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	add_child(mmi)
