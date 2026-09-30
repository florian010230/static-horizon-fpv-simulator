class_name FakeShadows
extends RefCounted

## Sun shadows that work on every GPU. Godot's own shadow maps render
## nothing at all on some machines - verified on the dev machine (Intel
## Iris 6100, macOS, Compatibility and Vulkan renderers): screenshots
## with shadows on and off were pixel-for-pixel identical.
##
## So, once per map load: every object's real outline - all of its mesh
## vertices, projected along the sun direction onto the ground - becomes
## a convex polygon (a gable-roofed house throws a gable-shaped shadow, a
## tree cone a pointed one), all polygons are painted into one top-down
## mask image (overlaps merge instead of stacking darker), the image is
## softened a little (a penumbra), and every ground-level surface -
## grass, roads, sidewalks, paving - samples it in its shader
## (shaders/ground_shadowed.gdshader). No extra geometry above the ground:
## an earlier version drew shadow meshes a few cm above the grass, which
## flickered against it at a distance (depth-buffer precision), and
## missed roads and sidewalks entirely.

const RES: int = 2048
const STRENGTH: float = 0.5 ## how much a shadow darkens the ground
const MIN_HEIGHT: float = 0.6
const MAX_FOOTPRINT: float = 1500.0 ## m² - hills, the ground itself: skipped
const FLAT_MAX: float = 0.45 ## thinner than this near the ground = a ground surface
const SHADER := preload("res://shaders/ground_shadowed.gdshader")
## For Geo's unshaded, light-baked surfaces: same shadow, keeps the
## baked light (vertex color) instead of relying on engine lighting.
const SHADER_BAKED := preload("res://shaders/ground_shadowed_baked.gdshader")

## Builds the mask and converts the ground surfaces under `root`. Stores
## the converted materials on the root (meta "ground_materials") so
## set_enabled() can switch the shadows on/off later without a rebuild.
static func build(root: Node3D, sun: DirectionalLight3D, ground_y: float, region: Rect2 = Rect2(-250, -250, 500, 500)) -> void:
	var light_dir: Vector3 = -sun.global_transform.basis.z
	var shift: Vector2 = Vector2(light_dir.x, light_dir.z) / maxf(-light_dir.y, 0.05)

	var img := Image.create(RES, RES, false, Image.FORMAT_L8)
	img.fill(Color.BLACK)
	var groups: Array = []
	_collect(root, groups)
	# Generated maps (Geo) hand over one outline per primitive instead.
	groups.append_array(root.get_meta("shadow_groups", []))
	for points in groups:
		var projected := PackedVector2Array()
		var top: float = -INF
		for p: Vector3 in points:
			top = maxf(top, p.y)
			var h: float = maxf(p.y - ground_y, 0.0)
			projected.append(Vector2(p.x, p.z) + shift * h)
		if top - ground_y < MIN_HEIGHT:
			continue
		var hull := Geometry2D.convex_hull(projected)
		_fill_convex(img, hull, region)
	# Penumbra: shrink with a proper filter, grow back smoothly.
	img.resize(RES / 4, RES / 4, Image.INTERPOLATE_LANCZOS)
	img.resize(RES, RES, Image.INTERPOLATE_BILINEAR)
	var mask := ImageTexture.create_from_image(img)

	var mats: Array[ShaderMaterial] = []
	_convert_ground(root, ground_y, mask, region, mats)
	root.set_meta("ground_materials", mats)

static func set_enabled(root: Node, enabled: bool) -> void:
	for m: ShaderMaterial in root.get_meta("ground_materials", []):
		m.set_shader_parameter("shadow_strength", STRENGTH if enabled else 0.0)

## One point set per building (walls + roof together), otherwise one per
## mesh - so a gate's posts and bar cast separate thin shadows, not one
## solid block.
static func _collect(node: Node, out: Array) -> void:
	if node is Drone or node is CanvasLayer:
		return
	if node is HollowBuilding:
		var pts := PackedVector3Array()
		for mi in _meshes_under(node):
			pts.append_array(_world_points(mi))
		if pts.size() > 0 and _footprint_ok(pts):
			out.append(pts)
		return
	if node is MeshInstance3D and node.visible and (node as MeshInstance3D).mesh != null and not node.has_meta("geo_batch"):
		var pts := _world_points(node)
		if pts.size() > 0 and _footprint_ok(pts):
			out.append(pts)
	for child in node.get_children():
		_collect(child, out)

static func _world_points(mi: MeshInstance3D) -> PackedVector3Array:
	var faces: PackedVector3Array = mi.mesh.get_faces()
	var xf: Transform3D = mi.global_transform
	var out := PackedVector3Array()
	# Every 3rd vertex is plenty for a hull (each triangle shares its
	# corners with neighbours), and keeps big building meshes quick.
	for i in range(0, faces.size(), 1 if faces.size() < 600 else 3):
		out.append(xf * faces[i])
	return out

static func _footprint_ok(pts: PackedVector3Array) -> bool:
	var mn := Vector2(INF, INF)
	var mx := Vector2(-INF, -INF)
	for p in pts:
		mn = Vector2(minf(mn.x, p.x), minf(mn.y, p.z))
		mx = Vector2(maxf(mx.x, p.x), maxf(mx.y, p.z))
	return (mx.x - mn.x) * (mx.y - mn.y) < MAX_FOOTPRINT

static func _meshes_under(node: Node) -> Array[MeshInstance3D]:
	var list: Array[MeshInstance3D] = []
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		list.append(node)
	for child in node.get_children():
		list.append_array(_meshes_under(child))
	return list

## Scanline fill of a convex polygon into the mask (fill_rect per row -
## far faster than per-pixel writes in GDScript).
static func _fill_convex(img: Image, poly: PackedVector2Array, region: Rect2) -> void:
	if poly.size() < 3:
		return
	var px := PackedVector2Array()
	for p in poly:
		px.append((p - region.position) / region.size * RES)
	var y0: int = RES
	var y1: int = -1
	for p in px:
		y0 = mini(y0, int(floor(p.y)))
		y1 = maxi(y1, int(ceil(p.y)))
	y0 = maxi(y0, 0)
	y1 = mini(y1, RES - 1)
	for y in range(y0, y1 + 1):
		var yc: float = y + 0.5
		var xa: float = INF
		var xb: float = -INF
		for i in range(px.size()):
			var a: Vector2 = px[i]
			var b: Vector2 = px[(i + 1) % px.size()]
			if (a.y <= yc and b.y > yc) or (b.y <= yc and a.y > yc):
				var x: float = a.x + (yc - a.y) / (b.y - a.y) * (b.x - a.x)
				xa = minf(xa, x)
				xb = maxf(xb, x)
		if xb < xa:
			continue
		var ix0: int = clampi(int(round(xa)), 0, RES - 1)
		var ix1: int = clampi(int(round(xb)), 0, RES - 1)
		if ix1 >= ix0:
			img.fill_rect(Rect2i(ix0, y, ix1 - ix0 + 1, 1), Color.WHITE)

## Every flat surface lying on the ground gets the shadow-receiving
## shader, keeping its own texture and color.
static func _convert_ground(node: Node, ground_y: float, mask: Texture2D, region: Rect2, mats: Array[ShaderMaterial]) -> void:
	if node is Drone or node is CanvasLayer:
		return
	if node is MeshInstance3D and (node as MeshInstance3D).mesh != null:
		var mi := node as MeshInstance3D
		var box: AABB = mi.global_transform * mi.get_aabb()
		if box.size.y <= FLAT_MAX and box.end.y <= ground_y + FLAT_MAX:
			var src: Material = mi.get_surface_override_material(0) if mi.get_surface_override_material_count() > 0 else null
			if src == null:
				src = mi.mesh.surface_get_material(0)
			if src is ShaderMaterial and (src as ShaderMaterial).shader != null and (src as ShaderMaterial).shader.resource_path.ends_with("geo_layer.gdshader"):
				# Geo's ground layers take the mask themselves (keeping
				# their depth layering and texture variation).
				if not mats.has(src):
					var gm := src as ShaderMaterial
					gm.set_shader_parameter("shadow_mask", mask)
					gm.set_shader_parameter("mask_origin", region.position)
					gm.set_shader_parameter("mask_size", region.size)
					gm.set_shader_parameter("shadow_strength", STRENGTH)
					mats.append(gm)
			elif src is StandardMaterial3D:
				var sm := _shader_from(src as StandardMaterial3D, mask, region)
				mi.set_surface_override_material(0, sm)
				mats.append(sm)
	for child in node.get_children():
		_convert_ground(child, ground_y, mask, region, mats)

static var _white: ImageTexture

static func _shader_from(src: StandardMaterial3D, mask: Texture2D, region: Rect2) -> ShaderMaterial:
	if _white == null:
		var w := Image.create(1, 1, false, Image.FORMAT_RGB8)
		w.fill(Color.WHITE)
		_white = ImageTexture.create_from_image(w)
	var sm := ShaderMaterial.new()
	sm.shader = SHADER_BAKED if src.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED else SHADER
	sm.set_shader_parameter("albedo_tex", src.albedo_texture if src.albedo_texture else _white)
	sm.set_shader_parameter("albedo_color", src.albedo_color)
	var tile: float = 6.0
	if src.uv1_triplanar and src.uv1_world_triplanar and src.uv1_scale.x > 0.0:
		tile = 1.0 / src.uv1_scale.x
	sm.set_shader_parameter("tile", tile)
	sm.set_shader_parameter("roughness", src.roughness)
	sm.set_shader_parameter("shadow_mask", mask)
	sm.set_shader_parameter("mask_origin", region.position)
	sm.set_shader_parameter("mask_size", region.size)
	sm.set_shader_parameter("shadow_strength", STRENGTH)
	return sm
