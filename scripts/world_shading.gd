class_name WorldShading
extends RefCounted

## Every map's surfaces go through one shader family (shaders/world.gdshaderinc):
## the unshaded, light-baked look this project uses everywhere, plus
##  - real sun shadows: a static shadow map rendered once per map load
##    from the sun's direction (capture) - buildings shadow each other,
##    bridges shadow the road, cranes throw long shadows across walls.
##    Per frame it costs one to four texture reads per pixel. Godot's own
##    shadow maps render nothing on the dev machine's Intel GPU (see
##    CLAUDE.md), and FakeShadows only darkened the ground.
##  - a cheap distance fog replacing the Environment's: measured on the
##    dev machine (Harbour, High, Retina fullscreen) the engine fog with
##    aerial perspective plus glow cost ~45% of the frame rate.
## All parameters are global shader uniforms (project.godot), so turning
## shadows off or changing the view distance touches no material.

const STRENGTH: float = 1.0 ## how much of the sun a shadow takes away
const MAX_CASTER_HEIGHT: float = 220.0
## Shadow map size per graphics quality (Low, Medium, High).
const RES: Array[int] = [2048, 4096, 4096]

static var _shaders: Dictionary = {}
static var _depth_mat: ShaderMaterial
static var _empty: ImageTexture
static var _sun := Vector4(0, -1, 0, 0) # global_shader_parameter_get is editor-only

## Converts the scene's materials and sets the fog/light globals. Safe to
## call again (already converted materials are skipped).
static func setup(scene: Node, env: Environment) -> void:
	_set_fog_from(env)
	set_grade(env.get_meta("grade", Vector4(1.08, 1.12, 0.0, 0.0)) if env else Vector4(1.08, 1.12, 0.0, 0.0))
	var cache: Dictionary = {}
	_convert(scene, cache)

## The view distance changed: depth fog ends just before the far plane.
static func fit_fog(env: Environment, far: float) -> void:
	if env == null or not env.has_meta("depth_fog"):
		return
	var begin: float = minf(env.get_meta("depth_fog"), far * 0.4)
	RenderingServer.global_shader_parameter_set("sh_fog", Vector4(begin, far * 0.96, 0.0, 1.0))

## Colour grade for every world surface (world_common sh_grade_color):
## a touch more contrast and saturation than the flat baked look; maps
## can set their own (env meta "grade": Vector4(contrast, saturation,
## warmth, 0)).
static func set_grade(g: Vector4) -> void:
	RenderingServer.global_shader_parameter_set("sh_grade", g)

static func _set_fog_from(env: Environment) -> void:
	if env == null:
		RenderingServer.global_shader_parameter_set("sh_fog", Vector4(0, 1, 0, 0))
		return
	# The engine fog is replaced, not stacked: remember it, switch it off.
	if not env.has_meta("sh_fog"):
		var mode: float = 0.0
		if env.fog_enabled:
			mode = 1.0 if env.fog_mode == Environment.FOG_MODE_DEPTH else 2.0
		env.set_meta("sh_fog", Vector4(env.fog_depth_begin, env.fog_depth_end, env.fog_density, mode))
		env.set_meta("sh_fog_color", env.fog_light_color)
		env.fog_enabled = false
		env.glow_enabled = false
	RenderingServer.global_shader_parameter_set("sh_fog", env.get_meta("sh_fog"))
	RenderingServer.global_shader_parameter_set("sh_fog_color", env.get_meta("sh_fog_color"))

## Sun direction (light travel) and the baked light's parts (Geo.shade).
static func set_light(sun_dir: Vector3, ambient: float, sky: float, sun: float, tint: Color = Color.WHITE) -> void:
	RenderingServer.global_shader_parameter_set("sh_sun_color", tint)
	RenderingServer.global_shader_parameter_set("sh_light", Vector4(ambient, sky, sun, 0.0))
	var d: Vector3 = sun_dir.normalized()
	_sun = Vector4(d.x, d.y, d.z, _sun.w)
	RenderingServer.global_shader_parameter_set("sh_sun", _sun)

static func set_shadows(on: bool) -> void:
	_sun.w = STRENGTH if on else 0.0
	RenderingServer.global_shader_parameter_set("sh_sun", _sun)

static func clear_shadow_map() -> void:
	if _empty == null:
		var img := Image.create(1, 1, false, Image.FORMAT_RG8)
		img.fill(Color.WHITE)
		_empty = ImageTexture.create_from_image(img)
	RenderingServer.global_shader_parameter_set("sh_shadow_map", _empty)
	RenderingServer.global_shader_parameter_set("sh_shadow_r0", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("sh_shadow_r1", Vector4.ZERO)
	RenderingServer.global_shader_parameter_set("sh_shadow_r2", Vector4(0, 0, 0, 2))

# --- material conversion -------------------------------------------------------

static func _convert(node: Node, cache: Dictionary) -> void:
	# (DroneShadow fades its own material every frame - keep it.)
	if node is Drone or node is CanvasLayer or node is DroneShadow or node.has_meta("keep_material"):
		return
	if node is GeometryInstance3D:
		var gi := node as GeometryInstance3D
		if gi.material_override:
			gi.material_override = _converted(gi.material_override, cache)
		if node is MeshInstance3D and (node as MeshInstance3D).mesh:
			var mi := node as MeshInstance3D
			for i in range(mi.mesh.get_surface_count()):
				var m: Material = mi.get_surface_override_material(i)
				if m == null:
					m = mi.mesh.surface_get_material(i)
				var c: Material = _converted(m, cache)
				if c != m:
					mi.set_surface_override_material(i, c)
		elif node is MultiMeshInstance3D and (node as MultiMeshInstance3D).multimesh:
			var mesh: Mesh = (node as MultiMeshInstance3D).multimesh.mesh
			if mesh:
				for i in range(mesh.get_surface_count()):
					var m: Material = mesh.surface_get_material(i)
					var c: Material = _converted(m, cache)
					if c != m:
						mesh.surface_set_material(i, c)
	for child in node.get_children():
		_convert(child, cache)

static func _converted(m: Material, cache: Dictionary) -> Material:
	if m == null:
		return m
	if cache.has(m):
		return cache[m]
	var out: Material = m
	if m is StandardMaterial3D:
		out = _from_standard(m as StandardMaterial3D)
	cache[m] = out
	return out

## The unshaded StandardMaterial3D features this project uses; anything
## else (lit materials, billboards) is left as it is.
static func _from_standard(s: StandardMaterial3D) -> Material:
	var glow: bool = s.emission_enabled
	if s.shading_mode != BaseMaterial3D.SHADING_MODE_UNSHADED and not glow:
		return s
	if s.billboard_mode != BaseMaterial3D.BILLBOARD_DISABLED or s.no_depth_test:
		return s
	var blend: bool = s.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA or s.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_DEPTH_PRE_PASS
	var scissor: bool = s.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR or s.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_HASH
	var sm := ShaderMaterial.new()
	sm.shader = _shader(s.cull_mode, blend, scissor)
	sm.resource_name = s.resource_name
	sm.render_priority = s.render_priority
	sm.set_shader_parameter("albedo", s.albedo_color)
	sm.set_shader_parameter("use_vcol", s.vertex_color_use_as_albedo)
	sm.set_shader_parameter("alpha_cut", s.alpha_scissor_threshold)
	if s.albedo_texture:
		sm.set_shader_parameter("tex", s.albedo_texture)
		var mode: int = 1
		if s.uv1_triplanar:
			mode = 2 if s.uv1_world_triplanar else 3
		sm.set_shader_parameter("tex_mode", mode)
		sm.set_shader_parameter("uv_scale", s.uv1_scale)
		sm.set_shader_parameter("uv_offset", s.uv1_offset)
		sm.set_shader_parameter("tri_sharpness", s.uv1_triplanar_sharpness)
	if glow:
		var e: Color = s.emission * s.emission_energy_multiplier
		sm.set_shader_parameter("emission", Vector3(e.r, e.g, e.b))
		sm.set_shader_parameter("receive_shadow", false)
	if blend:
		sm.set_shader_parameter("receive_shadow", false)
	if s.resource_name.contains("water"):
		sm.set_shader_parameter("water", true)
	return sm

static func _shader(cull: int, blend: bool, scissor: bool) -> Shader:
	var key: String = "%d|%s|%s" % [cull, blend, scissor]
	if _shaders.has(key):
		return _shaders[key]
	var modes: Array[String] = ["unshaded", "fog_disabled", ["cull_back", "cull_front", "cull_disabled"][cull]]
	var defs: String = ""
	if blend:
		modes.append("blend_mix")
		modes.append("depth_draw_opaque")
		defs += "#define BLEND\n"
	if scissor:
		defs += "#define SCISSOR\n"
	var sh := Shader.new()
	sh.code = "shader_type spatial;\nrender_mode %s;\n%s#include \"res://shaders/world.gdshaderinc\"\n" % [", ".join(modes), defs]
	_shaders[key] = sh
	return sh

# --- the shadow map ------------------------------------------------------------

## Renders the static shadow map for `region` (x/z rectangle on the
## ground) and installs it. Awaitable; does nothing in --headless (no
## GPU). Hidden for the capture: the drone and nodes with meta
## "dynamic" (moving things - their shadow would stay behind).
static func capture(scene: Node3D, sun_dir: Vector3, region: Rect2, res: int) -> void:
	if DisplayServer.get_name() == "headless":
		return
	var fwd: Vector3 = sun_dir.normalized()
	var basis := Basis.looking_at(fwd, Vector3.UP if absf(fwd.y) < 0.99 else Vector3.FORWARD)
	var right: Vector3 = basis.x
	var up: Vector3 = basis.y
	var lo := Vector3(INF, INF, INF)
	var hi := Vector3(-INF, -INF, -INF)
	for cx in [region.position.x, region.end.x]:
		for cz in [region.position.y, region.end.y]:
			for cy in [-30.0, MAX_CASTER_HEIGHT]:
				var p := Vector3(cx, cy, cz)
				var l := Vector3(p.dot(right), p.dot(up), p.dot(fwd))
				lo = Vector3(minf(lo.x, l.x), minf(lo.y, l.y), minf(lo.z, l.z))
				hi = Vector3(maxf(hi.x, l.x), maxf(hi.y, l.y), maxf(hi.z, l.z))
	var size: float = maxf(hi.x - lo.x, hi.y - lo.y)
	var mid := Vector2((lo.x + hi.x) * 0.5, (lo.y + hi.y) * 0.5)
	var z0: float = lo.z - 400.0 # casters beyond the box's near side too
	var depth: float = hi.z - z0 + 50.0
	RenderingServer.global_shader_parameter_set("sh_shadow_r0", Vector4(right.x / size, right.y / size, right.z / size, 0.5 - mid.x / size))
	RenderingServer.global_shader_parameter_set("sh_shadow_r1", Vector4(-up.x / size, -up.y / size, -up.z / size, 0.5 + mid.y / size))
	RenderingServer.global_shader_parameter_set("sh_shadow_r2", Vector4(fwd.x / depth, fwd.y / depth, fwd.z / depth, -z0 / depth))
	var texel: float = size / res
	RenderingServer.global_shader_parameter_set("sh_shadow_info", Vector4(0.25 / depth + texel * 0.5 / depth, texel * 1.2, 1.0, 0.0))

	var vp := SubViewport.new()
	vp.size = Vector2i(res, res)
	vp.render_target_update_mode = SubViewport.UPDATE_DISABLED
	vp.msaa_3d = Viewport.MSAA_DISABLED
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = size
	cam.near = 1.0
	cam.far = depth + 10.0
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color.WHITE
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	cam.environment = env
	vp.add_child(cam)
	scene.add_child(vp)
	cam.global_transform = Transform3D(basis, right * mid.x + up * mid.y + fwd * (z0 - 1.0))
	cam.current = true

	if _depth_mat == null:
		_depth_mat = ShaderMaterial.new()
		_depth_mat.shader = load("res://shaders/shadow_depth.gdshader")
	var saved: Array = []
	_prepare(scene, saved)
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = vp.get_texture().get_image()
	for s in saved:
		var n: Node = s[0]
		if not is_instance_valid(n):
			continue
		if s.size() == 2:
			n.visible = true
		else:
			var gi := n as GeometryInstance3D
			gi.material_override = s[1]
			gi.visibility_range_begin = s[2]
			gi.visibility_range_end = s[3]
	vp.queue_free()
	img.convert(Image.FORMAT_RG8)
	RenderingServer.global_shader_parameter_set("sh_shadow_map", ImageTexture.create_from_image(img))

static func _prepare(node: Node, saved: Array) -> void:
	if node is CanvasLayer or node is SubViewport:
		return
	if node is Drone or node.has_meta("dynamic") or node.name == "DroneShadow":
		if node is Node3D and (node as Node3D).visible:
			(node as Node3D).visible = false
			saved.append([node, "hide"])
		return
	if node is GeometryInstance3D and not (node is Label3D or node is Sprite3D):
		var gi := node as GeometryInstance3D
		saved.append([gi, gi.material_override, gi.visibility_range_begin, gi.visibility_range_end])
		gi.material_override = _depth_mat
		gi.visibility_range_begin = 0.0
		gi.visibility_range_end = 0.0
	for child in node.get_children():
		_prepare(child, saved)
