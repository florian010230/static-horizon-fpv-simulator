class_name GrassTufts
extends Node3D

## Grass tufts and pebbles round the drone on grass ground
## (shaders/grass_tufts.gdshader): two MultiMeshes whose instances the
## vertex shader wraps round the camera. What is grass, how high the
## ground is and its colour come from a top-down capture of the map,
## rendered once at load (two small renders, read back to textures).
## Medium and High only; none on Low, in --headless or without grass
## ground (generated terrain = Geo.ground_mat layer 0; the hand-made
## maps' "Ground" plate).

const RADIUS: Array[float] = [0.0, 13.0, 19.0]
const PER_M2: float = 3.2
const RES: Array[int] = [0, 1024, 1024]
const MAX_HALF: float = 700.0
const CAM_Y: float = 700.0
const CAM_FAR: float = 1400.0

var quality: int = 1
var _region: Rect2

func _init(q: int = 1) -> void:
	name = "GrassTufts"
	quality = clampi(q, 0, 2)
	set_meta("dynamic", true)

func _ready() -> void:
	if quality == 0 or DisplayServer.get_name() == "headless":
		return
	_build.call_deferred()

static func is_grass(gi: GeometryInstance3D) -> bool:
	if gi.get_parent() and gi.get_parent().name == "Ground" and gi is MeshInstance3D:
		return true
	if gi is MeshInstance3D and (gi as MeshInstance3D).mesh:
		var mi := gi as MeshInstance3D
		var m: Material = mi.get_surface_override_material(0) if mi.get_surface_override_material(0) else mi.mesh.surface_get_material(0)
		if m is ShaderMaterial and (m as ShaderMaterial).shader and (m as ShaderMaterial).shader.resource_path.ends_with("geo_layer.gdshader"):
			return float((m as ShaderMaterial).get_shader_parameter("pull")) == 0.0 and bool((m as ShaderMaterial).get_shader_parameter("use_tex"))
	return false

func _build() -> void:
	var scene: Node3D = get_parent() as Node3D
	var drone := scene.get_node_or_null("Drone") as Node3D
	if drone == null:
		return
	# Let the sun shadow capture (WorldShading) finish first: it swaps
	# every material too.
	for k in range(6):
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var half: float = 260.0
	if scene.has_method("border"):
		half = minf(float(scene.border()[1]), MAX_HALF)
	var c := Vector2(drone.global_position.x, drone.global_position.z)
	if scene.has_method("border") and scene.border().size() > 4:
		c = scene.border()[4]
	_region = Rect2(c - Vector2(half, half), Vector2(half, half) * 2.0)
	var grass_nodes: Array = []
	_collect(scene, grass_nodes)
	if grass_nodes.is_empty():
		return
	var t0: int = Time.get_ticks_msec()
	var res: int = RES[quality]
	var vp := SubViewport.new()
	vp.size = Vector2i(res, res)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = half * 2.0
	cam.near = 1.0
	cam.far = CAM_FAR
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.BLACK
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	vp.add_child(cam)
	scene.add_child(vp)
	cam.global_transform = Transform3D(Basis.looking_at(Vector3.DOWN, Vector3.FORWARD), Vector3(c.x, CAM_Y, c.y))
	cam.current = true
	# Pass 1: height + grass mask.
	var gmat := ShaderMaterial.new()
	gmat.shader = load("res://shaders/grass_capture.gdshader")
	gmat.set_shader_parameter("grass", 1.0)
	var omat := ShaderMaterial.new()
	omat.shader = gmat.shader
	var saved: Array = []
	_prepare(scene, saved, gmat, omat)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var himg: Image = vp.get_texture().get_image()
	# Pass 2: the ground's own colour (materials back, no haze).
	for s in saved:
		if s.size() == 4 and is_instance_valid(s[0]):
			(s[0] as GeometryInstance3D).material_override = s[1]
	RenderingServer.global_shader_parameter_set("sh_fog", Vector4(0, 1, 0, 0))
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var cimg: Image = vp.get_texture().get_image()
	_restore(saved)
	vp.queue_free()
	# Fog back as the map set it.
	var we := scene.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we and we.environment and we.environment.has_meta("sh_fog"):
		RenderingServer.global_shader_parameter_set("sh_fog", we.environment.get_meta("sh_fog"))
		var vcam: Camera3D = get_viewport().get_camera_3d()
		if vcam:
			WorldShading.fit_fog(we.environment, vcam.far)
	himg.convert(Image.FORMAT_RGB8)
	cimg.convert(Image.FORMAT_RGB8)
	var htex := ImageTexture.create_from_image(himg)
	var ctex := ImageTexture.create_from_image(cimg)
	_make_tufts(htex, ctex)
	set_meta("ready", true)
	if OS.has_environment("SH_LOADTIME"):
		print("LOAD grass capture %d ms (%d px, %d m)" % [Time.get_ticks_msec() - t0, res, int(half * 2.0)])

func _collect(n: Node, out: Array) -> void:
	if n is Drone or n is CanvasLayer or n is SubViewport:
		return
	if n is GeometryInstance3D and is_grass(n as GeometryInstance3D) and (n as Node3D).is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_collect(ch, out)

func _prepare(n: Node, saved: Array, gmat: Material, omat: Material) -> void:
	if n is CanvasLayer or n is SubViewport or n == self:
		return
	if n is Drone or n.has_meta("dynamic") or n.name == "DroneShadow" or n.name == "FlightBorder" or _is_tree(n):
		if n is Node3D and (n as Node3D).visible:
			(n as Node3D).visible = false
			saved.append([n])
		return
	if n is GeometryInstance3D and not (n is Label3D or n is Sprite3D):
		var gi := n as GeometryInstance3D
		saved.append([gi, gi.material_override, gi.visibility_range_begin, gi.visibility_range_end])
		gi.material_override = gmat if is_grass(gi) else omat
		gi.visibility_range_begin = 0.0
		gi.visibility_range_end = 0.0
	for ch in n.get_children():
		_prepare(ch, saved, gmat, omat)

## Trees and flowers (MultiMesh): the grass under them still counts.
func _is_tree(n: Node) -> bool:
	if not (n is MultiMeshInstance3D) or (n as MultiMeshInstance3D).multimesh == null or (n as MultiMeshInstance3D).multimesh.mesh == null:
		return false
	var m: Material = (n as MultiMeshInstance3D).multimesh.mesh.surface_get_material(0)
	return m is ShaderMaterial and (m as ShaderMaterial).shader != null and ((m as ShaderMaterial).shader.resource_path.ends_with("tree.gdshader") or (m as ShaderMaterial).shader.resource_path.ends_with("flower.gdshader"))

func _restore(saved: Array) -> void:
	for s in saved:
		if not is_instance_valid(s[0]):
			continue
		if s.size() == 1:
			(s[0] as Node3D).visible = true
		else:
			var gi := s[0] as GeometryInstance3D
			gi.material_override = s[1]
			gi.visibility_range_begin = s[2]
			gi.visibility_range_end = s[3]

func _make_tufts(htex: Texture2D, ctex: Texture2D) -> void:
	var r: float = RADIUS[quality]
	var span: float = r * 2.0
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/grass_tufts.gdshader")
	mat.set_shader_parameter("hmap", htex)
	mat.set_shader_parameter("cmap", ctex)
	mat.set_shader_parameter("region", Vector4(_region.position.x, _region.position.y, _region.size.x, 0))
	mat.set_shader_parameter("radius", r)
	mat.set_shader_parameter("cap", Vector2(CAM_Y, CAM_FAR))
	var smat: ShaderMaterial = mat.duplicate()
	smat.set_shader_parameter("stones", true)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1234
	var n: int = int(span * span * PER_M2)
	_add_mm(_tuft_mesh(), mat, n, span, rng, 0.7, 1.4)
	_add_mm(_stone_mesh(), smat, n / 14, span, rng, 0.5, 1.6)

func _add_mm(mesh: Mesh, mat: Material, n: int, span: float, rng: RandomNumberGenerator, s0: float, s1: float) -> void:
	mesh.surface_set_material(0, mat)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = n
	for i in range(n):
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(s0, s1))
		mm.set_instance_transform(i, Transform3D(b, Vector3(rng.randf() * span, 0.0, rng.randf() * span)))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.custom_aabb = AABB(Vector3(-1e5, -1e5, -1e5), Vector3(2e5, 2e5, 2e5))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("keep_material", true)
	add_child(mi)

## A tuft: seven thin blades leaning out (vertex alpha 0 base .. 1 tip).
static func _tuft_mesh() -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 9
	for k in range(7):
		var ang: float = k * TAU / 7.0 + rng.randf() * 0.6
		var dir := Vector3(cos(ang), 0, sin(ang))
		var side := Vector3(-dir.z, 0, dir.x)
		var h: float = rng.randf_range(0.1, 0.24)
		var w: float = rng.randf_range(0.012, 0.02)
		var root: Vector3 = dir * rng.randf_range(0.0, 0.04)
		var tip: Vector3 = root + dir * rng.randf_range(0.03, 0.09) + Vector3(0, h, 0)
		st.set_normal(Vector3.UP)
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(root - side * w)
		st.set_color(Color(1, 1, 1, 0.0))
		st.add_vertex(root + side * w)
		st.set_color(Color(1, 1, 1, 1.0))
		st.add_vertex(tip)
	return st.commit()

## A pebble: a squashed low-poly lump.
static func _stone_mesh() -> ArrayMesh:
	var sm := SphereMesh.new()
	sm.radius = 0.035
	sm.height = 0.04
	sm.radial_segments = 6
	sm.rings = 3
	var st := SurfaceTool.new()
	st.create_from(sm, 0)
	var mesh := st.commit()
	return mesh
