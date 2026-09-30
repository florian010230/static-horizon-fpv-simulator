class_name HouseInterior
extends StaticBody3D

## Furniture, a staircase and a stair railing for SmallHouse (the village
## houses and the farmhouse), so flying in through a window lands you in
## a home rather than an empty box. Laid out for SmallHouse's 9 x 9 m,
## two-storey plan (local coordinates, floor at y=0, upper floor at 3.5):
##
##   ground floor  front: living room - sofa, coffee table, rug, TV
##                 back:  kitchen - counter, fridge, dining table, chairs
##   upper floor   front: bedroom - bed, nightstand, wardrobe
##                 back:  study - desk, chair, shelf
##
## Kept clear: the front door, both open windows (the ways in), the
## partition doorway and the stairwell. Everything is merged into one
## mesh (one draw call per house); every piece is a real collision box.
## Interior-style unshaded with a little baked face shading, matching
## HollowBuilding's rooms. Fabric/wood colors vary per house.

const UPPER: float = 3.5
const FABRICS: Array[Color] = [Color(0.34, 0.44, 0.6), Color(0.62, 0.3, 0.25), Color(0.42, 0.5, 0.34), Color(0.5, 0.5, 0.54), Color(0.72, 0.6, 0.36)]
const WOODS: Array[Color] = [Color(0.56, 0.38, 0.22), Color(0.7, 0.55, 0.36), Color(0.4, 0.27, 0.17)]
const FACE_LIGHT := {Vector3.UP: 1.0, Vector3.DOWN: 0.55, Vector3.RIGHT: 0.9, Vector3.LEFT: 0.72, Vector3.BACK: 0.84, Vector3.FORWARD: 0.78}

var _st := SurfaceTool.new()

func _ready() -> void:
	var seed_pos: Vector3 = global_position
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector2i(int(seed_pos.x * 10.0), int(seed_pos.z * 10.0)))
	var fabric: Color = FABRICS[rng.randi() % FABRICS.size()]
	var fabric2: Color = FABRICS[rng.randi() % FABRICS.size()]
	var wood: Color = WOODS[rng.randi() % WOODS.size()]
	var white := Color(0.92, 0.92, 0.9)
	var dark := Color(0.12, 0.12, 0.14)
	_st.begin(Mesh.PRIMITIVE_TRIANGLES)

	# --- Staircase under the stairwell hole, rising toward the front wall.
	for i in range(10):
		var h: float = (i + 1) * 0.35
		_piece(Vector3(-3.3, h * 0.5, -1.05 - i * 0.3), Vector3(0.9, h, 0.3), wood.lightened(0.1))
	# Railing (balustrade) around the hole upstairs, open on the stair side.
	_piece(Vector3(-1.37, UPPER + 0.45, -2.2), Vector3(0.06, 0.9, 3.4), white)
	_piece(Vector3(-2.6, UPPER + 0.45, -0.47), Vector3(2.4, 0.9, 0.06), white)

	# --- Living room (front, ground floor).
	_piece(Vector3(-0.5, 0.01, -0.5), Vector3(2.8, 0.02, 1.9), fabric2.lightened(0.25), false)
	_piece(Vector3(-0.5, 0.225, 0.95), Vector3(2.2, 0.45, 0.7), fabric)            # sofa seat
	_piece(Vector3(-0.5, 0.7, 1.24), Vector3(2.2, 0.5, 0.14), fabric.darkened(0.1)) # back
	_piece(Vector3(-1.53, 0.35, 0.95), Vector3(0.14, 0.7, 0.7), fabric.darkened(0.1))
	_piece(Vector3(0.53, 0.35, 0.95), Vector3(0.14, 0.7, 0.7), fabric.darkened(0.1))
	_piece(Vector3(-0.5, 0.2, -0.5), Vector3(1.0, 0.4, 0.55), wood)                 # coffee table
	_piece(Vector3(-0.2, 0.25, -4.05), Vector3(1.6, 0.5, 0.4), wood)                # TV sideboard
	_piece(Vector3(-0.2, 0.85, -4.12), Vector3(1.1, 0.65, 0.05), dark)             # TV
	_piece(Vector3(3.7, 0.25, 1.0), Vector3(0.4, 0.5, 0.4), Color(0.6, 0.4, 0.3))   # plant pot
	_piece(Vector3(3.7, 0.85, 1.0), Vector3(0.6, 0.7, 0.6), Color(0.25, 0.5, 0.25))  # plant

	# --- Kitchen (back, ground floor).
	_piece(Vector3(-2.0, 0.45, 3.95), Vector3(4.6, 0.9, 0.6), white)               # counter
	_piece(Vector3(-2.0, 0.92, 3.95), Vector3(4.62, 0.04, 0.64), wood.darkened(0.25))
	_piece(Vector3(-3.95, 0.9, 2.2), Vector3(0.6, 1.8, 0.6), white.darkened(0.05))   # fridge
	_piece(Vector3(2.2, 0.74, 2.9), Vector3(1.4, 0.05, 0.9), wood)                  # table top
	_piece(Vector3(2.2, 0.36, 2.9), Vector3(0.12, 0.72, 0.12), wood.darkened(0.2))
	for c in [Vector3(1.75, 0, 2.2), Vector3(2.65, 0, 2.2), Vector3(1.75, 0, 3.6), Vector3(2.65, 0, 3.6)]:
		_piece(c + Vector3(0, 0.23, 0), Vector3(0.42, 0.46, 0.42), wood.lightened(0.05))
		var back_z: float = -0.19 if c.z < 2.9 else 0.19
		_piece(c + Vector3(0, 0.7, back_z), Vector3(0.42, 0.5, 0.05), wood.lightened(0.05))

	# --- Bedroom (front, upper floor).
	_piece(Vector3(2.4, UPPER + 0.2, -2.9), Vector3(1.6, 0.4, 2.1), wood)           # bed frame
	_piece(Vector3(2.4, UPPER + 0.47, -2.85), Vector3(1.5, 0.15, 2.0), white)       # mattress
	_piece(Vector3(2.4, UPPER + 0.6, -3.65), Vector3(1.2, 0.12, 0.4), white.darkened(0.08))
	_piece(Vector3(2.4, UPPER + 0.52, -2.35), Vector3(1.52, 0.1, 1.2), fabric2)      # duvet
	_piece(Vector3(2.4, UPPER + 0.5, -4.02), Vector3(1.6, 1.0, 0.08), wood.darkened(0.15))
	_piece(Vector3(3.65, UPPER + 0.25, -3.7), Vector3(0.45, 0.5, 0.45), wood)       # nightstand
	_piece(Vector3(-0.3, UPPER + 1.05, 1.15), Vector3(1.6, 2.1, 0.6), wood.lightened(0.15)) # wardrobe

	# --- Study (back, upper floor).
	_piece(Vector3(-2.4, UPPER + 0.375, 3.95), Vector3(1.3, 0.75, 0.6), wood)       # desk
	_piece(Vector3(-2.4, UPPER + 0.23, 3.25), Vector3(0.45, 0.46, 0.45), fabric)    # chair
	_piece(Vector3(-2.4, UPPER + 0.7, 3.02), Vector3(0.45, 0.5, 0.05), fabric)
	_piece(Vector3(-4.1, UPPER + 0.9, 2.4), Vector3(0.35, 1.8, 0.9), wood.darkened(0.1)) # shelf

	var mesh: ArrayMesh = _st.commit()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)

## One box: colored faces into the shared mesh, plus a collision box.
func _piece(center: Vector3, size: Vector3, color: Color, collide: bool = true) -> void:
	if collide:
		var shape := BoxShape3D.new()
		shape.size = size
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = center
		add_child(cs)
	var h: Vector3 = size * 0.5
	for n: Vector3 in FACE_LIGHT:
		var col: Color = color * FACE_LIGHT[n]
		col.a = 1.0
		# Four corners of the face, built from the normal: the two axes
		# perpendicular to it span the face.
		var u: Vector3 = Vector3(n.y, n.z, n.x).abs()
		var v: Vector3 = n.cross(u)
		var c: Vector3 = center + n * h
		var hu: float = (u * h).length()
		var hv: float = (v.abs() * h).length()
		var p: Array = [c - u * hu - v * hv, c + u * hu - v * hv, c + u * hu + v * hv, c - u * hu + v * hv]
		var order: Array[int] = [0, 1, 2, 0, 2, 3]
		if (p[1] - p[0]).cross(p[2] - p[0]).dot(n) > 0.0:
			order = [0, 2, 1, 0, 3, 2]
		for i in order:
			_st.set_color(col)
			_st.set_normal(n)
			_st.add_vertex(p[i])
