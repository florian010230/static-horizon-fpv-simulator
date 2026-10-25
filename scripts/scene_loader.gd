extends CanvasLayer

## Loading screen for every scene change into or out of a map. Before
## this, picking a map just froze the menu while textures, buildings and
## shadows were generated, the first frames stuttered through shader
## compilation, and the motor sound (already playing) stuttered into
## audible beeps. Now: a full-screen card (map name, progress bar, an
## FPV tip) covers all of that - the scene file loads on a background
## thread, all audio is muted until the new scene has actually rendered
## a few frames, then the card fades out.
##
## 2026-10-25: the card names each stage (bottom right) and the bar moves
## by stage, not 75 % then a long stop; the map's picture sits behind it
## and the tips change every few seconds. Before the card goes, every
## visible mesh is drawn once from above in WARM_GROUPS steps (hidden
## under the card), so shaders compile here and not as jerks the first
## time a house or tree comes into view (Village: 130 ms frames in the
## first lap, none in the second).
##
## Autoload. Use SceneLoader.goto(path, title) instead of
## get_tree().change_scene_to_file().

const TIPS: Array[String] = [
	"Arm with Enter (or your arm switch) - throttle must be low.",
	"Press L to switch between Acro and Angle (self-level) mode.",
	"Esc pauses the game: camera angle, FOV and drone are in there.",
	"R puts the drone back on its spawn point.",
	"A crashed drone lying upside down flips itself back after two seconds.",
	"Low on frames? Settings -> Graphics quality -> Low.",
	"Calibrate your radio once in Settings - it's remembered.",
	"Your drone's shadow on the ground is the best height cue when landing.",
]
const MIN_VISIBLE_FRAMES: int = 6
const WARM_GROUPS: int = 6
## The look round: points WARM_STEP apart, WARM_GRID each way from the spawn.
const WARM_GRID: int = 2
const WARM_STEP: float = 200.0
const TIP_SECONDS: float = 6.0

var _root: Control
var _title: Label
var _bar: ProgressBar
var _tip: Label
var _stage_lbl: Label
var _pic: TextureRect
var _spinner: Control
var _tip_t: float = 0.0
var _path: String = ""
var _loading: bool = false
var _lt: Array = [] # SH_LOADTIME: stage times

func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	_root.visible = false

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.theme = UIKit.theme()
	add_child(_root)
	var bg := ColorRect.new()
	bg.color = UIKit.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(bg)
	# The map's menu picture, full screen and only lightly darkened; the
	# card sits on its own dark panel so the text stays readable.
	_pic = TextureRect.new()
	_pic.set_anchors_preset(Control.PRESET_FULL_RECT)
	_pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_pic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# The pictures are 1024x512 (menu cards): stretched over a Retina
	# screen they showed their pixels, so they are softly blurred - a
	# camera-style background behind the sharp card (_soft_picture, once
	# per load - a blur shader would cost every loading frame).
	_pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_root.add_child(_pic)
	var shade := ColorRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0, 0, 0, 0.12)
	_root.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.BG, 0.82), Color(UIKit.BORDER, 0.6), 14, 1, Vector4(40, 32, 40, 32)))
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 18)
	panel.add_child(box)
	box.add_child(UIKit.eyebrow("STATIC HORIZON FPV SIMULATOR"))
	_title = Label.new()
	_title.theme_type_variation = "Title"
	box.add_child(_title)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(0, 10)
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", UIKit.box(UIKit.BORDER, UIKit.BORDER, 5, 0, Vector4.ZERO))
	_bar.add_theme_stylebox_override("fill", UIKit.box(UIKit.LINK, UIKit.LINK, 5, 0, Vector4.ZERO))
	box.add_child(_bar)
	_tip = Label.new()
	_tip.theme_type_variation = "Muted"
	_tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_tip)
	# What the loader is doing, bottom right on a small dark pill.
	var pill := PanelContainer.new()
	pill.add_theme_stylebox_override("panel", UIKit.box(Color(UIKit.BG, 0.82), Color(UIKit.BORDER, 0.6), 10, 1, Vector4(16, 8, 16, 8)))
	pill.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	pill.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	pill.grow_vertical = Control.GROW_DIRECTION_BEGIN
	pill.offset_right = -32
	pill.offset_bottom = -26
	_root.add_child(pill)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	pill.add_child(row)
	_spinner = HorizonSpinner.new()
	_spinner.custom_minimum_size = Vector2(26, 26)
	row.add_child(_spinner)
	_stage_lbl = Label.new()
	_stage_lbl.theme_type_variation = "Muted"
	_stage_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(_stage_lbl)

func _process(delta: float) -> void:
	if not _root.visible:
		return
	_tip_t += delta
	if _tip_t > TIP_SECONDS:
		_tip_t = 0.0
		_tip.text = TIPS[(TIPS.find(_tip.text) + 1) % TIPS.size()]

## A soft blur, no visible pixels: halved twice (each halving averages
## 2x2 pixels - one big shrink only samples and stayed blocky), then
## doubled back up the same way (~16 ms).
static func _soft_picture(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var img: Image = tex.get_image()
	if img == null:
		return tex
	img.decompress()
	for k in range(2):
		img.resize(maxi(img.get_width() / 2, 1), maxi(img.get_height() / 2, 1), Image.INTERPOLATE_BILINEAR)
	for k in range(2):
		img.resize(img.get_width() * 2, img.get_height() * 2, Image.INTERPOLATE_BILINEAR)
	return ImageTexture.create_from_image(img)

## Shows what the loader is doing and moves the bar; waits until that is
## on screen (the next step may hold the main thread for seconds).
func _stage(text: String, value: float) -> void:
	_stage_lbl.text = text
	_bar.value = maxf(_bar.value, value)
	await _drawn_frame()

## The next drawn frame - or 0.3 s, whichever comes first: a window
## behind others (or minimised) draws nothing on macOS, and a loader
## waiting for frame_post_draw then never finished.
var _drawn: int = 0
func _drawn_frame() -> void:
	if DisplayServer.get_name() == "headless":
		await get_tree().process_frame
		return
	if not RenderingServer.frame_post_draw.is_connected(_count_drawn):
		RenderingServer.frame_post_draw.connect(_count_drawn)
	var goal: int = _drawn + 1
	var t0: int = Time.get_ticks_msec()
	while _drawn < goal and Time.get_ticks_msec() - t0 < 300:
		await get_tree().process_frame

func _count_drawn() -> void:
	_drawn += 1

func is_loading() -> bool:
	return _loading

func reload(title: String = "") -> void:
	var scene: Node = get_tree().current_scene
	if scene:
		goto(scene.scene_file_path, title)

func goto(path: String, title: String = "") -> void:
	if _loading:
		return
	_loading = true
	_path = path
	_title.text = title if title != "" else "Loading"
	_tip.text = TIPS[randi() % TIPS.size()]
	_tip_t = 0.0
	_pic.texture = null
	for m in MapCatalog.MAPS:
		if m.scene == path and ResourceLoader.exists("res://images/maps/%s.jpg" % m.id):
			_pic.texture = _soft_picture(load("res://images/maps/%s.jpg" % m.id))
	_stage_lbl.text = "Loading files"
	_bar.value = 0.0
	_root.modulate.a = 1.0
	_root.visible = true
	_set_muted(true)
	get_tree().paused = false
	# Let the card actually appear before the heavy work starts.
	await get_tree().process_frame
	await get_tree().process_frame
	_lt = [Time.get_ticks_msec()]
	ResourceLoader.load_threaded_request(path)
	while true:
		var progress: Array = []
		var status := ResourceLoader.load_threaded_get_status(path, progress)
		if status == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if status == ResourceLoader.THREAD_LOAD_FAILED or status == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			push_error("SceneLoader: failed to load " + path)
			_finish()
			return
		_bar.value = (progress[0] if progress.size() > 0 else 0.0) * 15.0
		await get_tree().process_frame
	_lt.append(Time.get_ticks_msec())
	await _stage("Building the map (the first load after an update takes longest)", 15.0)
	var packed: PackedScene = ResourceLoader.load_threaded_get(path)
	get_tree().change_scene_to_packed(packed) # the new scene's _ready builds the map here
	# (the swap happens at the end of this frame; wait until the map is built)
	while get_tree().current_scene == null or not get_tree().current_scene.is_node_ready():
		await get_tree().process_frame
	_lt.append(Time.get_ticks_msec())
	await _stage("Drawing the first frames", 55.0)
	# Keep covering the first rendered frames: that's where shader
	# compilation for the new materials stutters.
	# (--headless draws nothing, so frame_post_draw never fires there -
	# it used to leave the loader stuck "busy" and ignore the next goto.)
	var headless: bool = DisplayServer.get_name() == "headless"
	for i in range(MIN_VISIBLE_FRAMES):
		if headless:
			await get_tree().process_frame
		else:
			await _drawn_frame()
	# The sun's shadow map is rendered with every material swapped for a
	# depth shader: stay up until that is over and the real materials have
	# been drawn once (at most ~5 s, never stuck).
	_lt.append(Time.get_ticks_msec())
	if not headless and WorldShading.capturing > 0:
		await _stage("Rendering the sun's shadows", 62.0)
		var n: int = 0
		while WorldShading.capturing > 0 and n < 300:
			await _drawn_frame()
			n += 1
		await _drawn_frame()
	if not headless:
		await _warm_shaders(get_tree().current_scene)
	# And until frames come quickly again: the first ones stall while the
	# GPU driver compiles shaders, and one of those was seen drawn half
	# done (untextured, banded ground) as the card faded (at most ~2 s).
	_lt.append(Time.get_ticks_msec())
	if not headless:
		await _stage("Almost ready", 96.0)
		var quick: int = 0
		var t: int = Time.get_ticks_msec()
		for k in range(120):
			await _drawn_frame()
			var now: int = Time.get_ticks_msec()
			quick = quick + 1 if now - t < 100 else 0
			t = now
			if quick >= 2:
				break
	_lt.append(Time.get_ticks_msec())
	if OS.has_environment("SH_LOADTIME"):
		var names: Array = ["scene file", "map build", "first frames", "shadows + shaders", "until smooth"]
		var parts: Array = []
		for i in range(1, _lt.size()):
			parts.append("%s %d ms" % [names[i - 1], _lt[i] - _lt[i - 1]])
		print("LOADSCREEN %s: %d ms total - %s" % [path.get_file(), _lt[-1] - _lt[0], ", ".join(parts)])
	_bar.value = 100.0
	_finish()

## Shaders compiled under the card, not as jerks in flight: the GPU
## driver compiles a shader the first time it draws it (Village: 130 ms
## frames the first time a spot came into view, none the second time).
## Two passes: every visible mesh once from straight above (an
## orthographic camera over the whole map, no draw distance, in
## WARM_GROUPS frames picked by render layer), then a look round through
## the drone's own camera - the top-down pass alone left the Village
## jerks, so they depend on the view, not only on the material. Ranges,
## layers, camera and drone are put back exactly.
func _warm_shaders(scene: Node) -> void:
	if not scene is Node3D:
		return
	if OS.get_environment("SH_WARM_TOP") != "0":
		await _warm_top(scene as Node3D)
	if OS.get_environment("SH_WARM_LOOK") != "0":
		await _warm_look(scene)

func _warm_top(scene: Node3D) -> void:
	var prev_cam: Camera3D = get_viewport().get_camera_3d()
	var insts: Array = []
	var box := AABB()
	for n in scene.find_children("*", "GeometryInstance3D", true, false):
		var gi := n as GeometryInstance3D
		if not gi.is_visible_in_tree():
			continue
		var ab: AABB = gi.global_transform * gi.get_aabb()
		box = ab if insts.is_empty() else box.merge(ab)
		insts.append([gi, gi.layers, gi.visibility_range_begin, gi.visibility_range_end])
	if insts.is_empty():
		return
	const WARM_LAYER: int = 1 << 18
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = maxf(box.size.x, box.size.z) * 1.05
	cam.near = 1.0
	cam.far = box.size.y + 400.0
	cam.cull_mask = WARM_LAYER
	scene.add_child(cam)
	cam.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5), box.get_center() + Vector3(0, box.size.y * 0.5 + 200.0, 0))
	cam.current = true
	for e in insts:
		(e[0] as GeometryInstance3D).visibility_range_begin = 0.0
		(e[0] as GeometryInstance3D).visibility_range_end = 0.0
	for g in range(WARM_GROUPS):
		for i in range(insts.size()):
			if is_instance_valid(insts[i][0]):
				(insts[i][0] as GeometryInstance3D).layers = WARM_LAYER if i % WARM_GROUPS == g else 0
		await _stage("Preparing shaders %d/%d" % [g + 1, WARM_GROUPS], 65.0 + 15.0 * g / WARM_GROUPS)
		await _drawn_frame()
	for e in insts:
		if is_instance_valid(e[0]):
			var gi := e[0] as GeometryInstance3D
			gi.layers = e[1]
			gi.visibility_range_begin = e[2]
			gi.visibility_range_end = e[3]
	cam.queue_free()
	if is_instance_valid(prev_cam):
		prev_cam.current = true

## 20 m up over a grid round the spawn, three ways at each point with a
## wide lens (a 300 m grid missed a spot 100 m from the spawn: things only
## compile once seen up close). Once per map per game start - the driver
## keeps what it compiled.
static var _warmed: Dictionary = {}
func _warm_look(scene: Node) -> void:
	var dr := scene.get_node_or_null("Drone") as RigidBody3D
	var cam: Camera3D = get_viewport().get_camera_3d()
	if dr == null or cam == null or _warmed.has(scene.scene_file_path):
		return
	_warmed[scene.scene_file_path] = true
	var fov0: float = cam.fov
	cam.fov = 120.0
	var xf0: Transform3D = dr.global_transform
	var froze: bool = dr.freeze
	dr.freeze = true
	var pts: Array = []
	for gx in range(-WARM_GRID, WARM_GRID + 1):
		for gz in range(-WARM_GRID, WARM_GRID + 1):
			pts.append(xf0.origin + Vector3(gx * WARM_STEP, 20.0, gz * WARM_STEP))
	for pi in range(pts.size()):
		await _stage("Preparing shaders: a look round the map %d/%d" % [pi + 1, pts.size()], 80.0 + 15.0 * pi / pts.size())
		for k in range(3):
			dr.global_transform = Transform3D(Basis(Vector3.UP, k * TAU / 3.0), pts[pi])
			dr.reset_physics_interpolation()
			await _drawn_frame()
	dr.global_transform = xf0
	dr.reset_physics_interpolation()
	dr.freeze = froze
	cam.fov = fov0

func _finish() -> void:
	_set_muted(false)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.25)
	await tw.finished
	_root.visible = false
	_loading = false

func _set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)

## The loading symbol: the logo's artificial horizon (sky blue over ground
## orange, white ring and wing bar) banking gently from side to side like
## a drone, with a blue arc running round it. It moves whenever a frame
## is drawn - it stands still while a load step holds the main thread.
class HorizonSpinner extends Control:
	const SKY := Color("#2172e0")
	const GROUND := Color("#e8581c")
	var _t: float = 0.0

	func _process(delta: float) -> void:
		# At most a 30 fps step per frame: while loading, frames come
		# unevenly (some take 100 ms+), and following the real time made the
		# symbol jump; capped, a slow frame just moves it a little slower.
		_t += minf(delta, 1.0 / 30.0)
		queue_redraw()

	func _draw() -> void:
		var c: Vector2 = size * 0.5
		var r: float = minf(size.x, size.y) * 0.5 - 3.5
		var bank: float = sin(_t * 1.7) * 0.38
		draw_circle(c, r, GROUND)
		var sky := PackedVector2Array()
		for k in range(33):
			var a: float = bank + PI + PI * k / 32.0
			sky.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(sky, SKY)
		var along := Vector2(cos(bank), sin(bank))
		draw_line(c - along * r, c + along * r, Color.WHITE, 1.5, true)
		draw_line(c - along * r * 0.72, c - along * r * 0.2, Color.WHITE, 2.0, true)
		draw_line(c + along * r * 0.2, c + along * r * 0.72, Color.WHITE, 2.0, true)
		draw_circle(c, r * 0.13, Color.WHITE)
		draw_arc(c, r, 0.0, TAU, 48, Color.WHITE, 1.5, true)
		var spin: float = _t * 4.2
		draw_arc(c, r + 2.5, spin, spin + 1.7, 24, UIKit.LINK, 1.5, true)
