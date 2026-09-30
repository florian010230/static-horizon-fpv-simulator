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

var _root: Control
var _title: Label
var _bar: ProgressBar
var _tip: Label
var _path: String = ""
var _loading: bool = false

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
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(640, 0)
	box.add_theme_constant_override("separation", 18)
	center.add_child(box)
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
	_bar.value = 0.0
	_root.modulate.a = 1.0
	_root.visible = true
	_set_muted(true)
	get_tree().paused = false
	# Let the card actually appear before the heavy work starts.
	await get_tree().process_frame
	await get_tree().process_frame
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
		_bar.value = (progress[0] if progress.size() > 0 else 0.0) * 70.0
		await get_tree().process_frame
	_bar.value = 75.0
	await get_tree().process_frame
	var packed: PackedScene = ResourceLoader.load_threaded_get(path)
	get_tree().change_scene_to_packed(packed) # the new scene's _ready builds the map here
	await get_tree().process_frame
	_bar.value = 90.0
	# Keep covering the first rendered frames: that's where shader
	# compilation for the new materials stutters.
	# (--headless draws nothing, so frame_post_draw never fires there -
	# it used to leave the loader stuck "busy" and ignore the next goto.)
	var headless: bool = DisplayServer.get_name() == "headless"
	for i in range(MIN_VISIBLE_FRAMES):
		if headless:
			await get_tree().process_frame
		else:
			await RenderingServer.frame_post_draw
	_bar.value = 100.0
	_finish()

func _finish() -> void:
	_set_muted(false)
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, 0.25)
	await tw.finished
	_root.visible = false
	_loading = false

func _set_muted(muted: bool) -> void:
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)
