class_name HollowBuilding
extends StaticBody3D

## Generic hollow rectangular building: floor, ceiling, and four walls,
## each wall punched with any number of doors (open) and windows (glazed,
## with a real collidable pane), optionally split into storeys by
## intermediate floor slabs with a stairwell hole, plus an optional
## interior partition. The one reusable primitive behind every fly-into
## structure: village houses, the factory halls, and every room of the
## school.
##
## Looks are driven by two style names instead of flat colors - see
## BuildingStyles for what each one means. The point of this is
## orientation: before, floor, walls and ceiling were one flat color
## (or one texture on every face), so with shadows off there was
## nothing to tell a ceiling from a wall at a glance. Now every face
## gets a role - floor, ceiling, interior wall, exterior wall, roof,
## trim, glass - with its own material, and vertex colors bake in fake
## ambient occlusion (darker where walls meet floor and ceiling) plus
## painted wall bands (skirting boards, a school's painted lower wall,
## a gym's wood impact panelling) that always sit at the bottom of the
## wall - the same cues a real room gives you about which way is down.
##
## All faces are merged into one ArrayMesh with one surface per role
## (a handful of draw calls per building instead of one per box), while
## every box still gets its own BoxShape3D so collision is exact.

@export_group("Size")
@export var size: Vector3 = Vector3(9.0, 7.0, 9.0)
@export var wall_thickness: float = 0.4
## 1 = one tall hollow volume. >1 adds (storeys - 1) intermediate floor
## slabs, evenly spaced, each with a stairwell hole (see stair_hole).
@export_range(1, 4) var storeys: int = 1
## Stairwell hole in each intermediate slab: (x, z, width_x, depth_z),
## center in building-local coordinates.
@export var stair_hole: Vector4 = Vector4(-2.8, -2.3, 2.4, 3.2)

## Legacy single centered opening per wall (width 0 = none). Kept so
## older scenes keep working; new content uses the arrays below.
## bottom/top are local heights measured up from the floor.
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

## Each entry is Vector4(offset along the wall from its center, width,
## bottom, top). Front/back walls run along local X (offset = x),
## left/right along local Z (offset = z). "doors" are open holes you can
## fly through; "windows" get a glass pane with collision, like a real
## closed window.
@export_group("Doors and Windows")
@export var front_doors: PackedVector4Array = PackedVector4Array()
@export var front_windows: PackedVector4Array = PackedVector4Array()
@export var back_doors: PackedVector4Array = PackedVector4Array()
@export var back_windows: PackedVector4Array = PackedVector4Array()
@export var left_doors: PackedVector4Array = PackedVector4Array()
@export var left_windows: PackedVector4Array = PackedVector4Array()
@export var right_doors: PackedVector4Array = PackedVector4Array()
@export var right_windows: PackedVector4Array = PackedVector4Array()

@export_group("Interior Partition (splits the interior along Z)")
@export var has_partition: bool = false
@export var partition_local_z: float = 0.0
@export var partition_gap_width: float = 2.2
## Top of the partition's doorway; 0 = full height (the old behavior).
@export var partition_gap_top: float = 0.0
@export var partition_gap_offset: float = 0.0

@export_group("Appearance")
## See BuildingStyles.INTERIOR / EXTERIOR for the available names.
@export var interior_style: String = "house"
@export var exterior_style: String = "siding"
## Multiplies the exterior facade color - lets a row of houses share one
## style but not one paint color.
@export var exterior_tint: Color = Color(1, 1, 1)
## Color of the peaked "Roof" child (if the scene has one), so houses can
## vary roof tiles too. Alpha 0 = leave the roof's own material alone.
@export var roof_color: Color = Color(0, 0, 0, 0)
## Legacy flat colors - only used by the "plain" interior style.
@export var wall_color: Color = Color(0.7, 0.52, 0.38)
@export var floor_color: Color = Color(0.5, 0.47, 0.42)
@export var add_floor: bool = true
@export var add_ceiling: bool = true

enum Role { INT_WALL, EXT_WALL, FLOOR, CEIL, ROOF, TRIM, GLASS, GLASS_OUT }

const AO_REACH: float = 0.7 ## meters over which a wall/floor corner darkens
const PLINTH_H: float = 0.5 ## darker base band on every facade

var _tools: Dictionary = {} # Role -> SurfaceTool
var _int_style: Dictionary
var _ext_style: Dictionary
var _storey_h: float

func _ready() -> void:
	_build()

func _build() -> void:
	_int_style = BuildingStyles.interior(interior_style, wall_color, floor_color)
	_ext_style = BuildingStyles.exterior(exterior_style)
	_storey_h = size.y / float(storeys)
	for r in Role.values():
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		_tools[r] = st

	var hx: float = size.x * 0.5
	var hy: float = size.y
	var hz: float = size.z * 0.5
	var t: float = wall_thickness

	if add_floor:
		_box(Vector3(0, -t * 0.5, 0), Vector3(size.x + t, t, size.z + t),
			{Vector3.UP: Role.FLOOR, Vector3.DOWN: Role.TRIM}, Role.TRIM, "floor")
	if add_ceiling:
		_box(Vector3(0, hy + t * 0.5, 0), Vector3(size.x + t, t, size.z + t),
			{Vector3.UP: Role.ROOF, Vector3.DOWN: Role.CEIL}, Role.EXT_WALL, "ceiling")

	for k in range(1, storeys):
		_add_slab(k * _storey_h)

	# Front/back walls run the full outer width (covering the corners);
	# left/right fit between them - so no coplanar faces and no corner
	# notches.
	_add_wall(Vector3(0, 0, -hz), size.x + t, hy, t, true, Vector3.FORWARD,
		_openings(front_width, front_bottom, front_top, front_doors, front_windows))
	_add_wall(Vector3(0, 0, hz), size.x + t, hy, t, true, Vector3.BACK,
		_openings(back_width, back_bottom, back_top, back_doors, back_windows))
	_add_wall(Vector3(-hx, 0, 0), size.z - t, hy, t, false, Vector3.LEFT,
		_openings(left_width, left_bottom, left_top, left_doors, left_windows))
	_add_wall(Vector3(hx, 0, 0), size.z - t, hy, t, false, Vector3.RIGHT,
		_openings(right_width, right_bottom, right_top, right_doors, right_windows))

	if has_partition:
		var gap_top: float = partition_gap_top if partition_gap_top > 0.0 else hy
		var gap: Array = [{"c": partition_gap_offset, "w": partition_gap_width, "b": 0.0, "t": gap_top, "glazed": false}]
		_add_wall(Vector3(0, 0, partition_local_z), size.x - t, hy, t * 0.6, true, Vector3.ZERO, gap)

	var mesh := ArrayMesh.new()
	for r in Role.values():
		var st: SurfaceTool = _tools[r]
		var arrays: Array = st.commit_to_arrays()
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null or arrays[Mesh.ARRAY_VERTEX].is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material_for(r))
	var mi := MeshInstance3D.new()
	mi.name = "BuildingMesh"
	mi.mesh = mesh
	add_child(mi)

	if roof_color.a > 0.0 and has_node("Roof/MeshInstance3D"):
		var roof_mi: MeshInstance3D = get_node("Roof/MeshInstance3D")
		var mat := StandardMaterial3D.new()
		mat.albedo_color = roof_color
		mat.albedo_texture = BuildingStyles.texture("roof_tiles")
		mat.uv1_scale = Vector3(3, 3, 1)
		roof_mi.set_surface_override_material(0, mat)

func _material_for(r: int) -> Material:
	match r:
		Role.INT_WALL: return BuildingStyles.material(_int_style, "wall")
		Role.FLOOR: return BuildingStyles.material(_int_style, "floor", size)
		Role.CEIL: return BuildingStyles.material(_int_style, "ceil")
		Role.EXT_WALL: return BuildingStyles.material(_ext_style, "wall")
		Role.ROOF: return BuildingStyles.material(_ext_style, "roof")
		Role.GLASS: return BuildingStyles.glass_material()
		Role.GLASS_OUT: return BuildingStyles.glass_outside_material()
	return BuildingStyles.trim_material()

func _openings(w: float, b: float, tp: float, doors: PackedVector4Array, windows: PackedVector4Array) -> Array:
	var list: Array = []
	if w > 0.0 and tp > b:
		list.append({"c": 0.0, "w": w, "b": b, "t": tp, "glazed": false})
	for d in doors:
		list.append({"c": d.x, "w": d.y, "b": d.z, "t": d.w, "glazed": false})
	for d in windows:
		list.append({"c": d.x, "w": d.y, "b": d.z, "t": d.w, "glazed": true})
	list.sort_custom(func(a, b2): return a.c < b2.c)
	return list

## `center` is the wall's centerline at floor level. `outward` is the
## exterior side's normal (ZERO for an interior partition - both faces
## count as interior then).
func _add_wall(center: Vector3, span: float, height: float, thickness: float, along_x: bool, outward: Vector3, openings: Array) -> void:
	# Split the wall into vertical columns at every opening edge; in each
	# column, the solid parts are [0, height] minus the openings that
	# cover that column. (The first version assumed one opening per
	# column: a window stacked above another one got filled in by the
	# other's sill/lintel pieces, so every stacked window was solid wall.)
	var half: float = span * 0.5
	var cuts: Array[float] = [-half, half]
	var clipped: Array = []
	for o in openings:
		var l: float = maxf(o.c - o.w * 0.5, -half)
		var r: float = minf(o.c + o.w * 0.5, half)
		if r <= l:
			continue
		clipped.append({"l": l, "r": r, "b": o.b, "t": minf(o.t, height), "glazed": o.glazed})
		cuts.append(l)
		cuts.append(r)
	cuts.sort()
	var runs: Array = [] # [a0, a1, solid intervals] - adjacent equal columns merged
	for i in range(cuts.size() - 1):
		var a0: float = cuts[i]
		var a1: float = cuts[i + 1]
		if a1 - a0 < 0.001:
			continue
		var mid: float = (a0 + a1) * 0.5
		var holes: Array = []
		for o in clipped:
			if o.l <= mid and mid <= o.r:
				holes.append([o.b, o.t])
		holes.sort_custom(func(x, y): return x[0] < y[0])
		var solid: Array = []
		var y: float = 0.0
		for hole in holes:
			if hole[0] > y + 0.001:
				solid.append([y, hole[0]])
			y = maxf(y, hole[1])
		if y < height - 0.001:
			solid.append([y, height])
		if runs.size() > 0 and runs[-1][2] == solid and absf(runs[-1][1] - a0) < 0.001:
			runs[-1][1] = a1
		else:
			runs.append([a0, a1, solid])
	for run in runs:
		for piece in run[2]:
			_wall_piece(center, along_x, run[0], run[1], piece[0], piece[1], thickness, outward, run[0] <= -half + 0.001, run[1] >= half - 0.001)
	for o in clipped:
		if o.glazed:
			_glass(center, along_x, o.l, o.r, o.b, o.t, outward)
		if outward != Vector3.ZERO:
			_window_details(center, along_x, o.l, o.r, o.b, o.t, thickness, outward, o.glazed, height)

## One solid box of wall between a0..a1 along the wall and y0..y1 up it.
## Its ends are facade corners (EXT_WALL) when they're the wall's own
## ends, and door/window reveals (TRIM) otherwise.
func _wall_piece(center: Vector3, along_x: bool, a0: float, a1: float, y0: float, y1: float, thickness: float, outward: Vector3, starts_at_end: bool, ends_at_end: bool) -> void:
	var len_a: float = a1 - a0
	var mid: float = (a0 + a1) * 0.5
	var c: Vector3 = center + (Vector3(mid, (y0 + y1) * 0.5, 0) if along_x else Vector3(0, (y0 + y1) * 0.5, mid))
	var box_size: Vector3 = Vector3(len_a, y1 - y0, thickness) if along_x else Vector3(thickness, y1 - y0, len_a)
	var roles: Dictionary = {}
	var normal_axis: Vector3 = Vector3.BACK if along_x else Vector3.RIGHT
	if outward == Vector3.ZERO:
		roles[normal_axis] = Role.INT_WALL
		roles[-normal_axis] = Role.INT_WALL
	else:
		roles[outward] = Role.EXT_WALL
		roles[-outward] = Role.INT_WALL
	var along_axis: Vector3 = Vector3.RIGHT if along_x else Vector3.BACK
	var outer_end: int = Role.EXT_WALL if outward != Vector3.ZERO else Role.INT_WALL
	roles[-along_axis] = outer_end if starts_at_end else Role.TRIM
	roles[along_axis] = outer_end if ends_at_end else Role.TRIM
	_box(c, box_size, roles, Role.TRIM, "wall")

## A window sill sticking out below each glazed window, and a window
## cross (mullion + transom) in wider ones - frames make a hole in a wall
## read as a window. Visual only (no collision boxes: the glass pane
## already stops the drone).
func _window_details(center: Vector3, along_x: bool, a0: float, a1: float, y0: float, y1: float, thickness: float, outward: Vector3, glazed: bool, wall_height: float) -> void:
	var mid: float = (a0 + a1) * 0.5
	var w: float = a1 - a0
	var along: Vector3 = Vector3.RIGHT if along_x else Vector3.BACK
	var base: Vector3 = center + along * mid
	# White frame on the facade around every window and door (not around
	# huge hall gates reaching the eaves).
	if y1 < wall_height - 0.2 and w < 4.0:
		var face: Vector3 = outward * (thickness * 0.5 + 0.02)
		var fw: float = 0.08
		var side_size: Vector3 = Vector3(fw, y1 - y0 + fw, 0.05) if along_x else Vector3(0.05, y1 - y0 + fw, fw)
		for sgn in [-1.0, 1.0]:
			_box(base + along * sgn * (w * 0.5 + fw * 0.5) + Vector3(0, (y0 + y1) * 0.5, 0) + face, side_size, {}, Role.TRIM, "detail", false)
		var top_size: Vector3 = Vector3(w + fw * 2.0, fw, 0.05) if along_x else Vector3(0.05, fw, w + fw * 2.0)
		_box(base + Vector3(0, y1 + fw * 0.5, 0) + face, top_size, {}, Role.TRIM, "detail", false)
	if not glazed:
		return
	if y0 > 0.05:
		var sill_size: Vector3 = Vector3(w + 0.16, 0.06, thickness + 0.14) if along_x else Vector3(thickness + 0.14, 0.06, w + 0.16)
		_box(base + Vector3(0, y0 - 0.03, 0) + outward * 0.07, sill_size, {}, Role.TRIM, "detail", false)
	if w >= 0.9:
		var bar_v: Vector3 = Vector3(0.06, y1 - y0, 0.06) if along_x else Vector3(0.06, y1 - y0, 0.06)
		_box(base + Vector3(0, (y0 + y1) * 0.5, 0), bar_v, {}, Role.TRIM, "detail", false)
	if y1 - y0 >= 1.0:
		var bar_h: Vector3 = Vector3(w, 0.06, 0.06) if along_x else Vector3(0.06, 0.06, w)
		_box(base + Vector3(0, y0 + (y1 - y0) * 0.62, 0), bar_h, {}, Role.TRIM, "detail", false)

## The pane's outer face is darker and more opaque than its inner face:
## from outside in daylight a real window reads dark (the interior is
## dimmer than the street), from inside it's see-through. With one
## material both ways, windows looked like more wall from outside.
func _glass(center: Vector3, along_x: bool, a0: float, a1: float, y0: float, y1: float, outward: Vector3) -> void:
	var mid: float = (a0 + a1) * 0.5
	var c: Vector3 = center + (Vector3(mid, (y0 + y1) * 0.5, 0) if along_x else Vector3(0, (y0 + y1) * 0.5, mid))
	var pane: Vector3 = Vector3(a1 - a0, y1 - y0, 0.03) if along_x else Vector3(0.03, y1 - y0, a1 - a0)
	var roles: Dictionary = {}
	if outward != Vector3.ZERO:
		roles[outward] = Role.GLASS_OUT
	_box(c, pane, roles, Role.GLASS, "glass")

## Intermediate floor slab at height y, with the stairwell hole cut out
## as four boxes around it.
func _add_slab(y: float) -> void:
	var t: float = wall_thickness * 0.75
	var x0: float = -size.x * 0.5
	var x1: float = size.x * 0.5
	var z0: float = -size.z * 0.5
	var z1: float = size.z * 0.5
	var hx0: float = clampf(stair_hole.x - stair_hole.z * 0.5, x0, x1)
	var hx1: float = clampf(stair_hole.x + stair_hole.z * 0.5, x0, x1)
	var hz0: float = clampf(stair_hole.y - stair_hole.w * 0.5, z0, z1)
	var hz1: float = clampf(stair_hole.y + stair_hole.w * 0.5, z0, z1)
	var roles := {Vector3.UP: Role.FLOOR, Vector3.DOWN: Role.CEIL}
	var cy: float = y - t * 0.5
	var pieces: Array = [
		[x0, x1, z0, hz0], [x0, x1, hz1, z1],
		[x0, hx0, hz0, hz1], [hx1, x1, hz0, hz1],
	]
	for p in pieces:
		if p[1] - p[0] > 0.01 and p[3] - p[2] > 0.01:
			_box(Vector3((p[0] + p[1]) * 0.5, cy, (p[2] + p[3]) * 0.5), Vector3(p[1] - p[0], t, p[3] - p[2]), roles, Role.TRIM, "slab")

## Emits one box: collision shape plus up to six faces, each routed to
## the SurfaceTool of its role (faces not in `roles` get `default_role`).
## `kind` tells the face emitter how to subdivide for AO/bands.
func _box(c: Vector3, s: Vector3, roles: Dictionary, default_role: int, kind: String, collide: bool = true) -> void:
	if collide:
		var shape := BoxShape3D.new()
		shape.size = s
		var cs := CollisionShape3D.new()
		cs.shape = shape
		cs.position = c
		add_child(cs)

	var h: Vector3 = s * 0.5
	for n: Vector3 in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.BACK, Vector3.FORWARD]:
		var role: int = roles.get(n, default_role)
		if (role == Role.GLASS or role == Role.GLASS_OUT) and kind != "glass":
			continue
		if n.y != 0.0:
			var y: float = c.y + h.y * n.y
			_horizontal_face(c.x - h.x, c.x + h.x, c.z - h.z, c.z + h.z, y, n.y > 0.0, role, kind)
		else:
			_vertical_face(c, h, n, role)

func _vertical_face(c: Vector3, h: Vector3, n: Vector3, role: int) -> void:
	# Face plane and its horizontal extent (u axis runs along the face).
	var along_x: bool = n.x == 0.0
	var plane: Vector3 = c + Vector3(h.x * n.x, 0, h.z * n.z)
	var u0: float = (c.x - h.x) if along_x else (c.z - h.z)
	var u1: float = (c.x + h.x) if along_x else (c.z + h.z)
	var y0: float = c.y - h.y
	var y1: float = c.y + h.y

	var cuts: Array[float] = [y0, y1]
	if role == Role.INT_WALL:
		var k0: int = int(floor(y0 / _storey_h))
		var k1: int = int(ceil(y1 / _storey_h))
		for k in range(k0, k1 + 1):
			var base: float = k * _storey_h
			cuts.append(base)
			cuts.append(base + AO_REACH)
			cuts.append(base + _storey_h - AO_REACH)
			for band in _int_style.bands:
				cuts.append(base + float(band[0]))
	elif role == Role.EXT_WALL:
		cuts.append(PLINTH_H)
	cuts = cuts.filter(func(v): return v >= y0 - 0.0001 and v <= y1 + 0.0001)
	cuts.sort()

	var st: SurfaceTool = _tools[role]
	for i in range(cuts.size() - 1):
		var ya: float = cuts[i]
		var yb: float = cuts[i + 1]
		if yb - ya < 0.001:
			continue
		var mid: float = (ya + yb) * 0.5
		var ca: Color = _wall_color(role, ya, mid) * _baked_light(role, n)
		var cb: Color = _wall_color(role, yb, mid) * _baked_light(role, n)
		ca.a = 1.0
		cb.a = 1.0
		var p00: Vector3 = _face_point(plane, along_x, u0, ya)
		var p10: Vector3 = _face_point(plane, along_x, u1, ya)
		var p11: Vector3 = _face_point(plane, along_x, u1, yb)
		var p01: Vector3 = _face_point(plane, along_x, u0, yb)
		var uv_scale: Vector2 = _uv_tile(role)
		var t00 := Vector2(u0 / uv_scale.x, -ya / uv_scale.y)
		var t10 := Vector2(u1 / uv_scale.x, -ya / uv_scale.y)
		var t11 := Vector2(u1 / uv_scale.x, -yb / uv_scale.y)
		var t01 := Vector2(u0 / uv_scale.x, -yb / uv_scale.y)
		_quad(st, [p00, p10, p11, p01], [t00, t10, t11, t01], [ca, ca, cb, cb], n)

func _face_point(plane: Vector3, along_x: bool, u: float, y: float) -> Vector3:
	return Vector3(u, y, plane.z) if along_x else Vector3(plane.x, y, u)

## Band color (by height within the storey) times fake AO (by distance
## to the storey's floor/ceiling) for interior walls; plinth for facades.
func _wall_color(role: int, y: float, band_y: float) -> Color:
	if role == Role.INT_WALL:
		var local_band: float = fposmod(band_y, _storey_h)
		var col: Color = _int_style.bands[-1][1]
		for band in _int_style.bands:
			if local_band < float(band[0]):
				col = band[1]
				break
		var ly: float = y - floor(band_y / _storey_h) * _storey_h
		var ao: float = 1.0
		if ly < AO_REACH:
			ao = lerpf(_int_style.ao_floor, 1.0, ly / AO_REACH)
		elif ly > _storey_h - AO_REACH:
			ao = lerpf(1.0, _int_style.ao_ceil, (ly - (_storey_h - AO_REACH)) / AO_REACH)
		return Color(col.r * ao, col.g * ao, col.b * ao)
	if role == Role.EXT_WALL:
		var tint: Color = exterior_tint * _ext_style.color
		return tint * 0.62 if band_y < PLINTH_H else tint
	return Color.WHITE

## Interior surfaces are unshaded (see BuildingStyles.material), so
## their lighting is baked in here instead: each wall direction gets its
## own brightness, like a room lit from its windows on one side, so two
## walls meeting in a corner never merge into one flat plane; the floor
## sits in the middle and the ceiling is clearly the darkest surface
## (apart from its glowing lamps) - the same order of brightness a real
## room shows. Without this, rooms were lit only by the sky's bluish
## ambient light (no sun reaches in, shadows or not) and every interior
## surface came out the same blue-gray.
const INTERIOR_LIGHT := {
	Vector3.RIGHT: 1.0, Vector3.LEFT: 0.8, Vector3.BACK: 0.92, Vector3.FORWARD: 0.86,
	Vector3.UP: 0.9, Vector3.DOWN: 0.7,
}

func _baked_light(role: int, n: Vector3) -> float:
	if role == Role.INT_WALL or role == Role.FLOOR or role == Role.CEIL:
		# The face normal points *into* the room for interior faces.
		return INTERIOR_LIGHT.get(n, 1.0)
	return 1.0

func _uv_tile(role: int) -> Vector2:
	match role:
		Role.INT_WALL: return _int_style.wall_tile
		Role.EXT_WALL: return _ext_style.wall_tile
	return Vector2(1, 1)

## Floors and ceilings are cut into a grid whose outer ring (AO_REACH
## wide, measured from the inner face of the walls) darkens toward the
## walls - reads as the soft contact shadow a real room has in its
## corners, and makes the floor/wall edge unmistakable.
func _horizontal_face(x0: float, x1: float, z0: float, z1: float, y: float, up: bool, role: int, kind: String) -> void:
	var st: SurfaceTool = _tools[role]
	var n: Vector3 = Vector3.UP if up else Vector3.DOWN
	var col: Color = _int_style.floor_color if role == Role.FLOOR else (_int_style.ceil_color if role == Role.CEIL else Color.WHITE)
	var ring: bool = (kind == "floor" and role == Role.FLOOR) or (kind == "ceiling" and role == Role.CEIL)
	var edge_ao: float = _int_style.ao_floor if role == Role.FLOOR else _int_style.ao_ceil
	var xs: Array[float] = [x0, x1]
	var zs: Array[float] = [z0, z1]
	var xa: Array[float] = [1.0, 1.0]
	var za: Array[float] = [1.0, 1.0]
	if ring:
		var t: float = wall_thickness
		var ix0: float = -size.x * 0.5 + t * 0.5
		var ix1: float = size.x * 0.5 - t * 0.5
		var iz0: float = -size.z * 0.5 + t * 0.5
		var iz1: float = size.z * 0.5 - t * 0.5
		var r: float = minf(AO_REACH, minf(ix1 - ix0, iz1 - iz0) * 0.25)
		xs = [x0, ix0, ix0 + r, ix1 - r, ix1, x1]
		zs = [z0, iz0, iz0 + r, iz1 - r, iz1, z1]
		xa = [edge_ao, edge_ao, 1.0, 1.0, edge_ao, edge_ao]
		za = [edge_ao, edge_ao, 1.0, 1.0, edge_ao, edge_ao]
	var stretch: bool = role == Role.FLOOR and _int_style.get("floor_stretch", false)
	var tile: Vector2 = _int_style.floor_tile if role == Role.FLOOR else (_int_style.ceil_tile if role == Role.CEIL else _ext_style.roof_tile)
	for i in range(xs.size() - 1):
		for j in range(zs.size() - 1):
			var ax0: float = xs[i]
			var ax1: float = xs[i + 1]
			var az0: float = zs[j]
			var az1: float = zs[j + 1]
			if ax1 - ax0 < 0.0005 or az1 - az0 < 0.0005:
				continue
			var pts: Array = [Vector3(ax0, y, az0), Vector3(ax1, y, az0), Vector3(ax1, y, az1), Vector3(ax0, y, az1)]
			var aos: Array = [xa[i] * za[j], xa[i + 1] * za[j], xa[i + 1] * za[j + 1], xa[i] * za[j + 1]]
			var uvs: Array = []
			var cols: Array = []
			for k in range(4):
				var p: Vector3 = pts[k]
				if stretch:
					uvs.append(Vector2((p.x + size.x * 0.5) / size.x, (p.z + size.z * 0.5) / size.z))
				else:
					uvs.append(Vector2(p.x / tile.x, p.z / tile.y))
				var a: float = aos[k] * _baked_light(role, n)
				cols.append(Color(col.r * a, col.g * a, col.b * a))
			if not up:
				pts.reverse()
				uvs.reverse()
				cols.reverse()
			_quad(st, pts, uvs, cols, n)

## Winding: Godot treats clockwise (seen from the front) as front-facing.
## Rather than hand-deriving the order for each of six face directions
## (easy to get backwards), flip the triangle order whenever its
## geometric normal disagrees with the intended one.
func _quad(st: SurfaceTool, p: Array, uv: Array, col: Array, n: Vector3) -> void:
	var order: Array[int] = [0, 1, 2, 0, 2, 3]
	var geo_n: Vector3 = (p[1] - p[0]).cross(p[2] - p[0])
	if geo_n.dot(n) > 0.0:
		order = [0, 2, 1, 0, 3, 2]
	for i in order:
		st.set_normal(n)
		st.set_uv(uv[i])
		st.set_color(col[i])
		st.add_vertex(p[i])
