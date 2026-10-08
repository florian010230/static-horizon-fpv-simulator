extends Node

## Dev tool, not part of the shipped game: renders a few real frames and
## saves screenshots to the project root, so the project can be visually
## previewed without a screen-sharing/remote-desktop setup. Godot's
## --headless mode never initializes a real GPU context, so there is no
## way to get an actual rendered image without a normal windowed run -
## this script automates that run.
##
## Usage: godot --path . -- --dev-preview
## (needs a real display; run it un-headless, exactly like playing the
## game normally - takes about 6 seconds, then quits itself). Registered
## as a permanent autoload but does nothing at all unless that flag is
## present, so it's always available without costing anything normally.

func _ready() -> void:
	if not OS.get_cmdline_user_args().has("--dev-preview"):
		return
	call_deferred("_go")

## Optional section names after the flag limit the run to those parts,
## e.g. `godot --path . -- --dev-preview village school` - much faster
## when iterating on one map. No names = everything.
func _wants(section: String) -> bool:
	var args := OS.get_cmdline_user_args()
	var sections: Array = ["menu", "village", "factory", "school", "borders", "thumbs", "gnome"]
	for m in MapCatalog.MAPS:
		sections.append(m.id)
	# ("shadows" is a modifier, not a section.)
	for a in args:
		if a in sections:
			return a == section or args.has(section)
	return true

## `-- --dev-preview borders`: every map, the drone parked just outside
## its flight area - the border must show (prints BORDER ok/FAIL).
func _border_shots() -> void:
	var scenes: Array = ["res://scenes/Main3.tscn"]
	for m in MapCatalog.MAPS:
		if not scenes.has(m.scene):
			scenes.append(m.scene)
	for sc in scenes:
		WorldBorder.last = {}
		get_tree().change_scene_to_file(sc)
		await get_tree().create_timer(2.5).timeout
		var root: Node = get_tree().current_scene
		if root == null:
			print("BORDER FAIL %s: scene did not load" % sc.get_file())
			continue
		var drone := root.find_child("Drone", true, false) as RigidBody3D
		var b: Dictionary = WorldBorder.last
		if drone == null or b.is_empty():
			print("BORDER FAIL %s: no border check running" % sc.get_file())
			continue
		drone.freeze = true
		InputManager.armed = false
		var p: Vector3
		var look: Vector3
		if b.kind == "circle":
			var c: Vector2 = b.c
			p = Vector3(c.x + b.r + 6.0, 0, c.y + 8.0)
			var hit: Dictionary = drone.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(p.x, 900, p.z), Vector3(p.x, -200, p.z)))
			p.y = (hit.position.y if hit else 0.0) + 6.0
			look = p + Vector3(-14, -1, 10)
		else:
			var mn: Vector3 = b.min
			var mx: Vector3 = b.max
			p = Vector3(mx.x + b.margin * 0.4, (mn.y + mx.y) * 0.5, (mn.z + mx.z) * 0.5)
			look = p + Vector3(-5, 0, 3)
		drone.global_position = p
		drone.look_at(look, Vector3.UP)
		drone.reset_physics_interpolation()
		await get_tree().create_timer(1.2).timeout
		if not is_instance_valid(root) or root != get_tree().current_scene:
			print("BORDER FAIL %s: the map reset (drone placed past the reset line)" % sc.get_file())
			continue
		var fb := root.get_node_or_null("FlightBorder") as Node3D
		if fb == null:
			fb = drone.get_parent().get_node_or_null("FlightBorder") as Node3D
		var ok: bool = fb != null and fb.visible and float(fb.get_meta("strength", 0.0)) > 0.9
		print("BORDER %s %s: %s" % ["ok" if ok else "FAIL", sc.get_file(), "visible" if ok else ("missing" if fb == null else "strength %.2f visible %s" % [fb.get_meta("strength", 0.0), fb.visible])])
		_shot("preview_border_%s.png" % sc.get_file().get_basename().to_lower())

## The map choice's preview pictures (images/maps/<id>.jpg): one wide
## aerial view per map showing all of it, rendered on High without the
## HUD. `-- --dev-preview thumbs <map id>` - one map per run: in one
## long run over all maps, later maps sometimes rendered half-empty.
const HERO := {
	"village": [Vector3(170, 42, 60), Vector3(20, 4, -90)],
	"factory": [Vector3(150, 48, 115), Vector3(-25, 6, -15)],
	"school": [Vector3(-19, 3.5, 9), Vector3(10, 1.5, -2)],
	"steelmill": [Vector3(-330, 125, 230), Vector3(10, 10, 10)],
	"playground": [Vector3(-40, 26, 48), Vector3(0, 0, -2)],
	"race_field": [Vector3(22, 9, 46), Vector3(-18, 1, -12)],
	"race_arena": [Vector3(-54, 12, 25), Vector3(15, 0, -5)],
	"office": [Vector3(-17, 2.75, 10.5), Vector3(5, 0.5, -6)],
	"garage": [Vector3(-60, 40, 70), Vector3(0, 6, 0)],
	"construction": [Vector3(220, 140, 230), Vector3(20, 20, -20)],
	"harbour": [Vector3(-480, 260, 300), Vector3(-120, 0, -380)],
	"mountain_lake": [Vector3(0, 160, 420), Vector3(0, 20, -100)],
	"test_valley": [Vector3(250, 55, 190), Vector3(20, 0, 0)],
}

func _thumb_shots() -> void:
	Settings.graphics_quality = 2
	Settings.view_distance = 2400.0
	Settings.osd_enabled = false
	Settings.crosshair_enabled = false
	Settings.camera_angle_deg = 0.0 # aim the camera where the drone looks
	WorldBorder.disabled = true
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://images/maps"))
	var args := OS.get_cmdline_user_args()
	for m in MapCatalog.MAPS:
		if not HERO.has(m.id) or (args.size() > 2 and not args.has(m.id)):
			continue
		get_tree().change_scene_to_file(m.scene)
		await get_tree().create_timer(3.0).timeout
		var root: Node = get_tree().current_scene
		var drone := root.find_child("Drone", true, false) as RigidBody3D
		var ui := root.find_child("UI", true, false) as CanvasLayer
		if ui:
			ui.visible = false
		drone.freeze = true
		drone.global_position = HERO[m.id][0]
		drone.look_at(HERO[m.id][1], Vector3.UP)
		drone.reset_physics_interpolation()
		# Clearer air for an aerial view: the haze starts further out.
		var we := root.get_node_or_null("WorldEnvironment") as WorldEnvironment
		if we and we.environment and we.environment.has_meta("depth_fog"):
			we.environment.set_meta("depth_fog", maxf(we.environment.get_meta("depth_fog"), 700.0))
			WorldShading.fit_fog(we.environment, get_viewport().get_camera_3d().far)
		await get_tree().create_timer(1.5).timeout
		var img := get_viewport().get_texture().get_image()
		var w: int = img.get_width()
		var h: int = int(w / 2.0)
		img = img.get_region(Rect2i(0, (img.get_height() - h) / 2, w, h))
		img.resize(1024, 512, Image.INTERPOLATE_LANCZOS)
		img.save_jpg(ProjectSettings.globalize_path("res://images/maps/%s.jpg" % m.id), 0.9)
		print("THUMB ", m.id)

## The website's drone pictures: `-- --dev-preview drones` - the menu's
## own drone preview, stopped with the drone's front-right toward the
## camera, rendered at 2x and saved as previews/drone_<id>.png (680x450).
func _drone_shots() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(1.0).timeout
	var menu: Node = get_tree().current_scene
	for t in get_tree().get_processed_tweens():
		t.kill()
	var root3d: Node3D = menu.get("_preview_drone_root")
	var vp: SubViewport = root3d.get_viewport()
	# The menu's container stretches the viewport to its own 360x340 -
	# switch that off, or the 680x450 picture comes out stretched.
	(vp.get_parent() as SubViewportContainer).stretch = false
	vp.size = Vector2i(1360, 900)
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var before: String = Settings.selected_drone
	for id in ["seeker3", "five", "race", "whoop"]:
		Settings.selected_drone = id
		menu.call("_build_preview_drone", root3d)
		# The drone's front-right (local +x, -z) toward the camera (+z).
		root3d.rotation.y = deg_to_rad(-135.0)
		await get_tree().create_timer(0.6).timeout
		var img: Image = vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		print("DRONE render ", img.get_size())
		var out := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_RGBA8)
		out.fill(UIKit.BOX)
		out.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), Vector2i.ZERO)
		# Frame the drone itself: its bounding box (pixels the render
		# drew) plus a margin, at the picture's 680:450 shape.
		var used: Rect2i = img.get_used_rect()
		var c: Vector2 = Vector2(used.get_center())
		var w: float = maxf(used.size.x, used.size.y * 680.0 / 450.0) * 1.18
		var h: float = w * 450.0 / 680.0
		var rect := Rect2i(int(c.x - w / 2.0), int(c.y - h / 2.0), int(w), int(h)).intersection(Rect2i(Vector2i.ZERO, out.get_size()))
		out = out.get_region(rect)
		out.resize(680, 450, Image.INTERPOLATE_LANCZOS)
		out.save_png(ProjectSettings.globalize_path("res://previews/drone_%s.png" % id))
		print("DRONE ", id)
	Settings.selected_drone = before

## `-- --dev-preview ceiling [map ids]`: from just under each outdoor
## map's height limit, four views (N/E/S/W, 25 deg down) - to check how
## the map's edges look from up there. previews/ceiling_<map>_<dir>.jpg.
func _ceiling_shots() -> void:
	Settings.osd_enabled = false
	Settings.crosshair_enabled = false
	Settings.camera_angle_deg = 0.0
	WorldBorder.disabled = true
	var args := OS.get_cmdline_user_args()
	for m in MapCatalog.MAPS:
		if m.get("indoor", false) or m.get("dev", false) or (args.size() > 2 and not args.has(m.id)):
			continue
		get_tree().change_scene_to_file(m.scene)
		await get_tree().create_timer(4.0).timeout
		var root: Node = get_tree().current_scene
		var drone := root.find_child("Drone", true, false) as RigidBody3D
		var ui := root.find_child("UI", true, false) as CanvasLayer
		if ui:
			ui.visible = false
		if drone == null or not root.has_method("border"):
			continue
		drone.freeze = true
		var b: Array = root.border()
		var c: Vector2 = b[4] if b.size() > 4 else Vector2.ZERO
		var p := Vector3(c.x, float(b[2]) - 10.0, c.y)
		for dir in [["n", Vector3(0, 0, -1)], ["e", Vector3(1, 0, 0)], ["s", Vector3(0, 0, 1)], ["w", Vector3(-1, 0, 0)]]:
			var d: Vector3 = (dir[1] as Vector3) * cos(deg_to_rad(25.0)) + Vector3.DOWN * sin(deg_to_rad(25.0))
			drone.global_position = p
			drone.look_at(p + d, Vector3.UP)
			drone.reset_physics_interpolation()
			await get_tree().create_timer(1.2).timeout
			var img := get_viewport().get_texture().get_image()
			img.resize(960, int(960.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
			img.save_jpg(ProjectSettings.globalize_path("res://previews/ceiling_%s_%s.jpg" % [m.id, dir[0]]), 0.85)
		print("CEILING ", m.id, " fog ", RenderingServer.global_shader_parameter_get("sh_fog"), " haze ", RenderingServer.global_shader_parameter_get("sh_haze_h"), " far ", get_viewport().get_camera_3d().far)

## Pictures for the website: `-- --dev-preview beauty [map ids]` - from
## the map's hero spot and its own preview views, the camera turned toward
## the sun (low sun, glare and lit haze make the best pictures), High
## quality, no HUD. previews/beauty_<map>_<n>.jpg, 1920 wide.
func _beauty_shots() -> void:
	Settings.graphics_quality = 2
	Settings.view_distance = 2400.0
	Settings.osd_enabled = false
	Settings.crosshair_enabled = false
	Settings.camera_angle_deg = 0.0
	Settings.lens_fisheye = 0
	Settings.camera_look = 0
	WorldBorder.disabled = true
	var args := OS.get_cmdline_user_args()
	for m in MapCatalog.MAPS:
		if m.get("indoor", false) or m.get("dev", false) or (args.size() > 2 and not args.has(m.id)):
			continue
		get_tree().change_scene_to_file(m.scene)
		await get_tree().create_timer(4.0).timeout
		var root: Node = get_tree().current_scene
		var drone := root.find_child("Drone", true, false) as RigidBody3D
		var ui := root.find_child("UI", true, false) as CanvasLayer
		if ui:
			ui.visible = false
		var sun := root.find_child("Sun", true, false) as DirectionalLight3D
		if drone == null or sun == null:
			continue
		drone.freeze = true
		var to_sun: Vector3 = sun.global_transform.basis.z.normalized()
		# Spots: [position, the thing the view was made for (or null)].
		var spots: Array = []
		if HERO.has(m.id):
			spots.append([HERO[m.id][0], HERO[m.id][1]])
		spots.append([drone.global_position + Vector3(0, 3, 0), null])
		if root.has_method("preview_views"):
			for v in root.preview_views():
				if v.size() >= 3 and v[1] is Vector3 and v[2] is Vector3:
					spots.append([v[1], v[2]])
		var cam := get_viewport().get_camera_3d()
		var half_v: float = deg_to_rad(cam.fov * 0.5) if cam else 0.6
		var elev: float = asin(clampf(to_sun.y, -1.0, 1.0))
		# Sun in the upper third of the frame - for a high sun, at most a
		# little upward look (sun at the top edge; the ground still fills
		# most of the picture).
		var pitch: float = minf(elev - half_v * 0.45, deg_to_rad(8.0))
		var sun_yaw: float = atan2(to_sun.x, to_sun.z)
		var n: int = 0
		for sp in spots.slice(0, 14):
			var p: Vector3 = sp[0]
			# Turn from the sun toward the view's subject by up to 30
			# degrees, so the subject stands against the light with the
			# sun near the edge of the frame; views facing away from the
			# sun turn round to face it.
			var yaw: float = sun_yaw
			if sp[1] != null:
				var to_t: Vector3 = (sp[1] as Vector3) - p
				var d: float = wrapf(atan2(to_t.x, to_t.z) - sun_yaw, -PI, PI)
				if absf(d) < deg_to_rad(80.0):
					yaw = sun_yaw + clampf(d, -deg_to_rad(30.0), deg_to_rad(30.0))
			var dir := Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch))
			drone.global_position = p
			drone.look_at(p + dir, Vector3.UP)
			drone.reset_physics_interpolation()
			await get_tree().create_timer(1.2).timeout
			var img := get_viewport().get_texture().get_image()
			img.resize(1920, int(1920.0 * img.get_height() / img.get_width()), Image.INTERPOLATE_LANCZOS)
			img.save_jpg(ProjectSettings.globalize_path("res://previews/beauty_%s_%02d.jpg" % [m.id, n]), 0.92)
			n += 1
		print("BEAUTY %s: %d" % [m.id, n])

## `-- --dev-preview floatcheck`: the hand-made maps (scene files, not
## Geo): every mesh whose box starts above the ground and touches no
## other mesh's box is listed - something floating in the air.
func _float_check() -> void:
	for sc in ["res://scenes/Main3.tscn"]: # (Main/Main2 - the old village/factory - are generated maps now)
		get_tree().change_scene_to_file(sc)
		await get_tree().create_timer(1.5).timeout
		var boxes: Array = []
		_collect_boxes(get_tree().current_scene, boxes)
		var n: int = 0
		for i in range(boxes.size()):
			var a: AABB = boxes[i][0]
			if a.position.y < 0.9 or a.size.length() < 0.05:
				continue
			var touch: bool = false
			for j in range(boxes.size()):
				if i != j and a.grow(0.12).intersects(boxes[j][0]):
					touch = true
					break
			if not touch:
				n += 1
				print("  floating %s %s y=%.2f" % [sc.get_file(), boxes[i][1], a.position.y])
		print("FLOATCHECK %s: %d" % [sc.get_file(), n])

func _collect_boxes(n: Node, out: Array) -> void:
	if n is Drone or n is CanvasLayer:
		return
	if n is MeshInstance3D and (n as MeshInstance3D).mesh and (n as Node3D).is_visible_in_tree():
		var mi := n as MeshInstance3D
		out.append([mi.global_transform * mi.get_aabb(), mi.get_path()])
	for c in n.get_children():
		_collect_boxes(c, out)

func _go() -> void:
	# `-- --dev-preview shadows ...` renders everything with shadows on.
	if OS.get_cmdline_user_args().has("shadows"):
		Settings.shadows_enabled = true
	if OS.get_cmdline_user_args().has("floatcheck"):
		await _float_check()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("thumbs"):
		await _thumb_shots()
		get_tree().quit()
	if OS.get_cmdline_user_args().has("drones"):
		await _drone_shots()
		get_tree().quit()
	if OS.get_cmdline_user_args().has("ceiling"):
		await _ceiling_shots()
		get_tree().quit()
	if OS.get_cmdline_user_args().has("beauty"):
		await _beauty_shots()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("borders"):
		await _border_shots()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("lab"):
		await _lab_shots()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("cpuprof"):
		await _cpu_prof()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("perfdetail"):
		await _perf_detail()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("perf"):
		await _perf_run()
		get_tree().quit()
		return
	if OS.get_cmdline_user_args().has("flight"):
		await _flight_shots()
	if OS.get_cmdline_user_args().has("looks"):
		await _looks_shots()
		get_tree().quit()
		return
	if _wants("menu"):
		await _menu_shots()
	if _wants("gnome"):
		await _gnome_shots()
	if _wants("school"):
		await _map_shots("res://scenes/Main3.tscn", "school", [
			["gym", Vector3(-19, 3.5, 9), Vector3(10, 1.5, -2)],
			["gym_goal", Vector3(-12, 1.6, 3), Vector3(-21, 0.9, 0)],
			["gym_wallbars", Vector3(4, 2.2, 2), Vector3(-2, 1.4, -13)],
			["foyer", Vector3(-12, 1.8, 22.5), Vector3(-12, 1.2, 10)],
			["corridor", Vector3(-17, 1.7, 25.9), Vector3(45, 1.3, 25.9)],
			["classroom", Vector3(15.5, 1.8, 35), Vector3(8, 0.9, 30)],
			["outside", Vector3(80, 8, 40), Vector3(20, 3, 15)],
		])
	# Generated maps name their own views (BuiltMap.preview_views()).
	for m in MapCatalog.available():
		if m.id == "school" or not _wants(m.id):
			continue
		await _map_shots(m.scene, m.id, [], false)
	get_tree().quit()

## The garden gnome up close, new and found (Collectibles).
func _gnome_shots() -> void:
	Collectibles.reset()
	Settings.selected_drone = "whoop"
	get_tree().change_scene_to_file("res://scenes/maps/Playground.tscn")
	await get_tree().create_timer(2.0).timeout
	var drone: RigidBody3D = get_tree().root.find_child("Drone", true, false)
	var g: Node3D = get_tree().current_scene.get_node("Gnome_0")
	drone.freeze = true
	drone.global_position = g.global_position + Vector3(0.5, 0.3, 0.9)
	drone.look_at(g.global_position + Vector3(0, 0.18, 0), Vector3.UP)
	await get_tree().create_timer(0.5).timeout
	_shot("preview_gnome_new.png")
	g.get_node("Pickup").body_entered.emit(drone)
	await get_tree().create_timer(0.2).timeout
	_shot("preview_gnome_pop.png")
	await get_tree().create_timer(1.0).timeout
	_shot("preview_gnome_found.png")
	Collectibles.reset()
	get_tree().quit()

func _menu_shots() -> void:
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(1.0).timeout
	_shot("preview_menu.png")

	var settings_btn: Button = _find_button(get_tree().current_scene, "Settings")
	if settings_btn:
		settings_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_settings.png")
	var st: SettingsScreens = get_tree().current_scene.get("_settings")
	for t in range(1, SettingsScreens.TAB_NAMES.size()):
		st.settings_tabs.current_tab = t
		await get_tree().create_timer(0.3).timeout
		_shot("preview_settings_%s.png" % SettingsScreens.TAB_NAMES[t].to_lower().replace(" & ", "_"))
	st.settings_tabs.current_tab = 0

	# The calibration wizard, fed by a virtual radio (never completes a
	# step that saves, so the real calibration file is left alone).
	var menu: Node = get_tree().current_scene
	var ss: SettingsScreens = menu.get("_settings")
	var axes: Array = [0.0, 0.0, -1.0, 0.0, 0.0, -1.0, 0.0, 0.0]
	var buttons: Array = []
	buttons.resize(16)
	buttons.fill(false)
	var saved := {}
	for f in ["axis_roll", "axis_pitch", "axis_yaw", "axis_throttle", "invert_roll", "invert_pitch", "invert_yaw", "axis_rest"]:
		saved[f] = InputManager.get(f).duplicate() if f == "axis_rest" else InputManager.get(f)
	InputManager.test_joy = {"axes": axes, "buttons": buttons}
	ss._start_calibration(false)
	await get_tree().create_timer(0.3).timeout
	_shot("preview_calibration.png")
	InputManager.capture_rest()
	ss._calibration_step = 0
	ss._update_calibration_step()
	axes[0] = 0.92
	ss._hold_time = 0.0
	await get_tree().create_timer(0.4).timeout
	_shot("preview_calibration_hold.png")
	axes[0] = 0.0
	ss._hold_axis = -1
	ss._enter_arm_step()
	ss._update_calibration_step()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_calibration_arm.png")
	ss._calibration_step = ss.STEP_TEST
	ss._update_calibration_step()
	axes[0] = 0.5
	axes[1] = -0.4
	axes[2] = 0.2
	await get_tree().create_timer(0.3).timeout
	_shot("preview_calibration_test.png")
	InputManager.test_joy = null
	InputManager._joy_active = false
	for f in saved:
		InputManager.set(f, saved[f])

	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(0.5).timeout
	_find_button(get_tree().current_scene._screens["main"], "About").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_about.png")
	_find_button(get_tree().current_scene._screens["about"], "Licences").pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_licences.png")

	# Updates (a pretend newer release) and Achievements (some progress).
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(0.5).timeout
	Collectibles.reset()
	Collectibles.mark_found("playground", 0)
	Achievements.note_flight("village")
	# A pretend release one minor version above this build (example notes).
	var cur: PackedStringArray = Updater.current_version().split(".")
	var fake: String = "%s.%d.0" % [cur[0], int(cur[1]) + 1] if cur.size() >= 2 else "9.9.9"
	Updater.latest = {"version": fake, "tag": "v" + fake, "url": Updater.RELEASES_PAGE, "checked": 0,
		"body": "## Fixes\n- The **Static Race** no longer drifts at idle.\n- Gnomes are now easier to find.\n\n## New\n- A quieter menu with an Updates screen."}
	var mn: Node = get_tree().current_scene
	mn._refresh_update_hint()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_menu_update.png")
	_find_button(mn._screens["main"], "Updates").pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_updates.png")
	mn._show("achievements")
	await get_tree().create_timer(0.3).timeout
	_shot("preview_achievements.png")
	Updater.latest = {}
	Collectibles.reset()

	# Reload fresh rather than clicking "Back"/"Cancel" - all panels
	# (drone/settings/map/calibration) exist in the tree at once (just
	# hidden), so a text search for either is ambiguous about which one
	# it'd hit.
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(0.5).timeout
	var next_btn: Button = _find_button(get_tree().current_scene, "next_drone")
	if next_btn:
		next_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_menu_five.png")
	if next_btn:
		next_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_menu_race.png")
	if next_btn:
		next_btn.pressed.emit()
	await get_tree().create_timer(0.5).timeout
	_shot("preview_menu_whoop.png")
	if next_btn:
		next_btn.pressed.emit() # back to the default drone

	var play_btn: Button = _find_button(get_tree().current_scene, "Play")
	if play_btn:
		play_btn.pressed.emit()
	await get_tree().create_timer(0.3).timeout
	_shot("preview_mode_choice.png")
	var menu_node: Node = get_tree().current_scene
	_find_button(menu_node._screens["mode"], "Race").pressed.emit()
	await get_tree().create_timer(0.4).timeout
	_shot("preview_map_choice_race.png")
	Settings.game_mode = Settings.MODE_FREESTYLE
	menu_node._show("map")
	await get_tree().create_timer(0.4).timeout
	_shot("preview_map_choice.png")
	SceneLoader.goto("res://scenes/maps/Factory.tscn", "Factory")
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	_shot("preview_loading.png")
	while SceneLoader.is_loading():
		await get_tree().process_frame

## Loads a map, grabs one shot from the spawn point, then parks the
## (frozen, disarmed) drone at each [name, position, look-at target] and
## grabs another. Aiming with look_at() rather than hand-typed rotation
## angles - the FPV camera itself adds its own upward tilt on top.
func _map_shots(scene: String, prefix: String, views: Array, pause_shots: bool = true) -> void:
	# Race tracks are shown in Race mode (gate numbers, next-gate marker).
	Settings.game_mode = Settings.MODE_RACE if MapCatalog.is_race(MapCatalog.for_scene(scene)) else Settings.MODE_FREESTYLE
	get_tree().change_scene_to_file(scene)
	await get_tree().create_timer(2.0).timeout
	_shot("preview_%s_spawn.png" % prefix)
	if prefix == "playground":
		Settings.camera_look = 1
		await get_tree().create_timer(0.4).timeout
		_shot("preview_%s_analog_video.png" % prefix)
		Settings.camera_look = 0
	# Settled frame rate at the spawn view - the HUD's own FPS readout in
	# the later shots is skewed by each teleport.
	await get_tree().create_timer(3.0).timeout
	print("SPAWN_FPS %s: %d" % [prefix, Engine.get_frames_per_second()])
	var drone: RigidBody3D = get_tree().root.find_child("Drone", true, false)
	if drone == null:
		return
	drone.freeze = true
	InputManager.armed = false
	# The O-key tuning panel covers a third of every shot otherwise.
	var ui: Node = get_tree().root.find_child("UI", true, false)
	if ui and "_panel_visible" in ui:
		ui._panel_visible = false
	if views.is_empty() and get_tree().current_scene.has_method("preview_views"):
		var sc: Node = get_tree().current_scene
		views = sc.views() if sc is BuiltMap else sc.preview_views()
	if OS.has_environment("SH_VIEWS"): # (as in the labs: name prefixes)
		var keep: PackedStringArray = OS.get_environment("SH_VIEWS").split(",")
		views = views.filter(func(v: Array) -> bool: return Array(keep).any(func(k: String) -> bool: return String(v[0]).begins_with(k)))
	for v in views:
		drone.global_position = v[1]
		var target: Vector3 = v[2]
		if absf((target - v[1]).normalized().y) > 0.99:
			drone.look_at(target, Vector3.FORWARD)
		else:
			drone.look_at(target, Vector3.UP)
		drone.reset_physics_interpolation()
		await get_tree().create_timer(0.4).timeout
		await _drawn_frames(2) # (a busy machine: stale frames otherwise, see _lab_shots)
		_shot("preview_%s_%s.png" % [prefix, v[0]])
	# Pilot aids on one view: stick overlay and strong fisheye; then the
	# line-of-sight camera.
	if prefix == "race_field" and ui:
		Settings.stick_overlay = true
		Settings.lens_fisheye = 2
		await get_tree().create_timer(0.5).timeout
		_shot("preview_%s_aids.png" % prefix)
		Settings.stick_overlay = false
		Settings.lens_fisheye = 0
		drone.global_position = drone._spawn_transform.origin + Vector3(6, 4, -12)
		drone.reset_physics_interpolation()
		ui.toggle_los()
		await get_tree().create_timer(0.5).timeout
		_shot("preview_%s_los.png" % prefix)
		ui.toggle_los()
		# Replay: a recorded swoop past the start gate, chase camera.
		var rp: Replay = ui.replay
		rp._pos.clear()
		rp._rot.clear()
		for k in range(90):
			var tt: float = k / 30.0
			rp._pos.append(Vector3(-20 + tt * 12.0, 2.0 + sin(tt) * 1.5, 30 + sin(tt * 1.3) * 4.0))
			rp._rot.append(Basis(Vector3.UP, -PI * 0.5 + sin(tt) * 0.3).get_rotation_quaternion())
		rp.start()
		rp._t = 1.5
		for k in range(20):
			rp._place()
		await get_tree().create_timer(0.5).timeout
		_shot("preview_%s_replay.png" % prefix)
		rp.stop()
	# The flight-area border, which shows while the HUD warns.
	var sc: Node = get_tree().current_scene
	if sc.has_method("border") and not sc.has_method("check_border_box"):
		var b: Array = sc.border()
		var c: Vector2 = b[4] if b.size() > 4 else Vector2.ZERO
		var p := Vector3(c.x + b[0] + 4.0, 10.0, c.y + 6.0)
		drone.global_position = p
		drone.look_at(p + Vector3(-12, -1, 9), Vector3.UP)
		drone.reset_physics_interpolation()
		await get_tree().create_timer(0.8).timeout
		_shot("preview_%s_border.png" % prefix)
	# The in-game pause menu over the last view, and its Settings.
	if pause_shots and ui and "pause_menu" in ui and ui.pause_menu:
		ui.pause_menu.open()
		await get_tree().create_timer(0.4).timeout
		_shot("preview_%s_pause.png" % prefix)
		ui.pause_menu._open_settings()
		await get_tree().create_timer(0.4).timeout
		_shot("preview_%s_pause_settings.png" % prefix)
		ui.pause_menu.resume()

## `-- --dev-preview lab <Scene>`: a creator lab (scenes/labs/<Scene>.tscn,
## default HouseLab) shot from every camera in its preview_views()
## ([name, eye, target, group]) into SH_SHOT_DIR (default previews/lab):
## a PNG per view, a contact sheet per group (sheet_<group>.png, views
## in order, 4 across - one picture to check a whole house) and an
## index.html to browse them (arrow keys step through).
func _lab_shots() -> void:
	var args := OS.get_cmdline_user_args()
	var i: int = args.find("lab")
	var scene_name: String = args[i + 1] if i + 1 < args.size() else "HouseLab"
	var out: String = OS.get_environment("SH_SHOT_DIR") if OS.has_environment("SH_SHOT_DIR") else ProjectSettings.globalize_path("res://previews/lab")
	DirAccess.make_dir_recursive_absolute(out)
	Settings.graphics_quality = 2
	Settings.osd_enabled = false
	Settings.crosshair_enabled = false
	Settings.camera_angle_deg = 0.0
	Settings.camera_fov_deg = float(OS.get_environment("SH_FOV")) if OS.has_environment("SH_FOV") else 95.0
	WorldBorder.disabled = true
	var path: String = "res://scenes/labs/%s.tscn" % scene_name
	if not ResourceLoader.exists(path):
		path = "res://scenes/maps/%s.tscn" % scene_name # a whole map works too
	get_tree().change_scene_to_file(path)
	await get_tree().create_timer(2.5).timeout
	var root: Node = get_tree().current_scene
	var drone := root.find_child("Drone", true, false) as RigidBody3D
	drone.freeze = true
	InputManager.armed = false
	var ui: Node = root.find_child("UI", true, false)
	if ui is CanvasLayer:
		ui.visible = false
	var groups: Dictionary = {}
	var order: Array = []
	# SH_VIEWS="a,b": only the views whose names start with one of these;
	# a map's piece views (SH_PIECE_VIEWS, see Pieces) go first.
	var views: Array = (root.get_meta("piece_views", []) as Array) + root.preview_views()
	# SH_EYES="name@x,y,z@tx,ty,tz;...": extra views of your own.
	if OS.has_environment("SH_EYES"):
		for e: String in OS.get_environment("SH_EYES").split(";"):
			var f: PackedStringArray = e.split("@")
			var a: PackedFloat64Array = f[1].split_floats(",")
			var b: PackedFloat64Array = f[2].split_floats(",")
			views.push_front([f[0], Vector3(a[0], a[1], a[2]), Vector3(b[0], b[1], b[2]), "eyes"])
	if OS.has_environment("SH_VIEWS"):
		var keep: PackedStringArray = OS.get_environment("SH_VIEWS").split(",")
		views = views.filter(func(v: Array) -> bool:
			for k in keep:
				if String(v[0]).begins_with(k):
					return true
			return false)
	for v: Array in views:
		drone.global_position = v[1]
		var target: Vector3 = v[2]
		drone.look_at(target, Vector3.FORWARD if absf((target - v[1]).normalized().y) > 0.99 else Vector3.UP)
		drone.reset_physics_interpolation()
		await get_tree().create_timer(float(OS.get_environment("SH_SHOT_WAIT")) if OS.has_environment("SH_SHOT_WAIT") else 0.4).timeout # (longer on a busy machine: stale frames)
		# And two frames really drawn: while another fullscreen Godot (a
		# second lab run) holds the screen, macOS stops drawing this one,
		# and the picture would be the previous view's. Waits a while for
		# a turn, then asks for the screen.
		await _drawn_frames(2)
		var img := get_viewport().get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		img.save_png(out.path_join(v[0] + ".png"))
		var g: String = v[3] if v.size() > 3 else "views"
		if not groups.has(g):
			groups[g] = []
			order.append(g)
		var th: Image = img.duplicate()
		th.resize(480, 270, Image.INTERPOLATE_BILINEAR)
		groups[g].append([v[0], th])
	var body: String = ""
	for g: String in order:
		var items: Array = groups[g]
		var cols: int = 4
		var rows: int = ceili(items.size() / float(cols))
		var sheet := Image.create(cols * 480, rows * 270, false, Image.FORMAT_RGB8)
		var names: Array = []
		for k in range(items.size()):
			sheet.blit_rect(items[k][1], Rect2i(0, 0, 480, 270), Vector2i((k % cols) * 480, (k / cols) * 270))
			names.append(items[k][0])
		var sheet_name: String = "sheet_%s.png" % g.replace(" ", "_")
		sheet.save_png(out.path_join(sheet_name))
		print("LAB SHEET %s: %s" % [sheet_name, ", ".join(names)])
		body += "<h2>%s</h2><div class=grid>" % g
		for n: String in names:
			body += "<figure><img src='%s.png' loading=lazy><figcaption>%s</figcaption></figure>" % [n, n]
		body += "</div>"
	var html: String = """<!doctype html><meta charset=utf-8><title>%s</title>
<style>body{background:#111418;color:#d8dde3;font:14px system-ui,sans-serif;margin:16px}
h1{font-size:20px}h2{font-size:16px;margin:28px 0 8px;color:#9fb3c8}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(360px,1fr));gap:10px}
figure{margin:0;cursor:zoom-in}img{width:100%%;display:block;border-radius:4px}
figcaption{padding:4px 2px;color:#8a96a3}
#lb{position:fixed;inset:0;background:#000d;display:none;align-items:center;justify-content:center;flex-direction:column}
#lb img{max-width:96vw;max-height:90vh;width:auto}#lb div{margin-top:8px}</style>
<h1>%s - %s</h1><p>Click a picture to enlarge; arrow keys step, Esc closes. Reload after a new run.</p>%s
<div id=lb><img><div></div></div>
<script>const figs=[...document.querySelectorAll('figure')];let cur=-1;const lb=document.getElementById('lb');
function show(i){cur=(i+figs.length)%%figs.length;lb.querySelector('img').src=figs[cur].querySelector('img').src;
lb.querySelector('div').textContent=figs[cur].textContent;lb.style.display='flex'}
figs.forEach((f,i)=>f.onclick=()=>show(i));lb.onclick=()=>{lb.style.display='none';cur=-1};
onkeydown=e=>{if(cur<0)return;if(e.key=='ArrowRight')show(cur+1);if(e.key=='ArrowLeft')show(cur-1);if(e.key=='Escape')lb.onclick()}</script>""" % [scene_name, scene_name, Time.get_datetime_string_from_system(), body]
	var f := FileAccess.open(out.path_join("index.html"), FileAccess.WRITE)
	f.store_string(html)
	f.close()
	print("LAB DONE: ", out.path_join("index.html"))

## `-- --dev-preview looks`: the look of the world and the FPV feed, for
## shader work (camera looks, close-up surfaces, sky). Shots go to
## SH_SHOT_DIR (default previews/looks) as <map>_<view>[_c<look>q<q>].png.
##   SH_LOOKS_MAPS="village,harbour"  which maps (MapCatalog ids)
##   SH_LOOKS_CAMS="0,1,2,3"          camera looks (Settings.camera_look)
##   SH_LOOKS_Q="1,0.4,0.1"           forced signal quality (FpvVideo.force_quality)
##   SH_VIEWS="spawn,sun"             only these views
##   SH_QUALITY=0..2                  graphics quality (default 2)
## `-- --dev-preview looks perf`: no shots - the settled frame rate at the
## spawn of each map on Low, Medium and High (LOOKSPERF lines).
const LOOKS_EYES := {
	"village": [["street", Vector3(-62, 1.2, 70), Vector3(40, 0.5, 70)], ["grass", Vector3(10, 0.6, 20), Vector3(30, 0.2, 35)],
		["wall", Vector3(-10.5, 1.6, 64), Vector3(-15, 1.0, 72)]],
	"factory": [["hall", Vector3(0, 5, -20), Vector3(0, 3, -45)], ["yard", Vector3(0, 1.2, 70), Vector3(0, 0.5, 30)]],
	"school": [["gym", Vector3(-19, 3.5, 9), Vector3(10, 1.5, -2)], ["corridor", Vector3(-17, 1.7, 25.9), Vector3(45, 1.3, 25.9)]],
	"harbour": [["cranes", Vector3(70, 22, 40), Vector3(200, 30, -10)], ["stacks", Vector3(60, 2, -117), Vector3(260, 1, -117)]],
	"steelmill": [],
	"mountain_lake": [],
	"race_arena": [["start", Vector3(-40, 1.3, 20), Vector3(0, 1.3, 20)], ["scaffold", Vector3(35, 10, -22), Vector3(0, 8, -22)]],
	"test_valley": [],
}

func _looks_shots() -> void:
	var args := OS.get_cmdline_user_args()
	var perf: bool = args.has("perf")
	var out: String = OS.get_environment("SH_SHOT_DIR") if OS.has_environment("SH_SHOT_DIR") else ProjectSettings.globalize_path("res://previews/looks")
	DirAccess.make_dir_recursive_absolute(out)
	var ids: Array = LOOKS_EYES.keys()
	if OS.has_environment("SH_LOOKS_MAPS"):
		ids = Array(OS.get_environment("SH_LOOKS_MAPS").split(","))
	var cams: Array = [0]
	if OS.has_environment("SH_LOOKS_CAMS"):
		cams = Array(OS.get_environment("SH_LOOKS_CAMS").split_floats(",")).map(func(v: float) -> int: return int(v))
	var qs: Array = [-1.0]
	if OS.has_environment("SH_LOOKS_Q"):
		qs = Array(OS.get_environment("SH_LOOKS_Q").split_floats(","))
	Settings.osd_enabled = not perf
	Settings.crosshair_enabled = false
	Settings.camera_angle_deg = float(OS.get_environment("SH_CAM_ANGLE")) if OS.has_environment("SH_CAM_ANGLE") else 10.0
	WorldBorder.disabled = true
	var qualities: Array = [0, 1, 2] if perf else [int(OS.get_environment("SH_QUALITY")) if OS.has_environment("SH_QUALITY") else 2]
	for q: int in qualities:
		Settings.graphics_quality = q
		for id: String in ids:
			var info: Dictionary = {}
			for m in MapCatalog.MAPS:
				if m.id == id:
					info = m
			if info.is_empty():
				print("LOOKS no map ", id)
				continue
			Settings.game_mode = Settings.MODE_FREESTYLE
			var forced: String = info.get("drone", "any")
			Settings.selected_drone = forced if forced != "any" else "seeker3"
			get_tree().change_scene_to_file(info.scene)
			await get_tree().create_timer(2.5).timeout
			var root: Node = get_tree().current_scene
			var drone := root.find_child("Drone", true, false) as Drone
			if drone == null:
				continue
			drone.freeze = true
			InputManager.armed = false
			var ui: Node = root.find_child("UI", true, false)
			if ui and "_panel_visible" in ui:
				ui._panel_visible = false
			var spawn: Vector3 = drone._spawn_transform.origin
			var fwd: Vector3 = -drone._spawn_transform.basis.z
			# The grass capture runs a moment after the map loads.
			var gt: Node = root.get_node_or_null("GrassTufts")
			for k in range(100):
				if gt == null or not is_instance_valid(gt) or gt.has_meta("ready"):
					break
				await get_tree().create_timer(0.2).timeout
			if perf:
				Engine.max_fps = 0
				DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
				drone.global_position = spawn + Vector3(0, 1.5, 0)
				drone.look_at(spawn + Vector3(0, 1.0, 0) + fwd * 20.0, Vector3.UP)
				drone.reset_physics_interpolation()
				await get_tree().create_timer(2.0).timeout
				# Off/on twice, interleaved: the machine's load drifts.
				var sums: Array = [0.0, 0.0]
				for ab: int in [0, 1, 0, 1]:
					_looks_features(ab == 1)
					await get_tree().create_timer(0.7).timeout
					var f0: int = Engine.get_frames_drawn()
					var t0: int = Time.get_ticks_msec()
					await get_tree().create_timer(2.5).timeout
					sums[ab] += (Engine.get_frames_drawn() - f0) * 1000.0 / maxf(Time.get_ticks_msec() - t0, 1.0) * 0.5
				print("LOOKSPERF %s %s off %.1f on %.1f fps (draws %d)" % [Settings.QUALITY_NAMES[q], id, sums[0], sums[1], RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)])
				continue
			var views: Array = [["spawn", spawn + Vector3(0, 1.5, 0), spawn + Vector3(0, 1.0, 0) + fwd * 20.0]]
			var sun := root.find_child("Sun", true, false) as DirectionalLight3D
			if sun:
				var to_sun: Vector3 = sun.global_transform.basis.z
				var flat := Vector3(to_sun.x, 0, to_sun.z).normalized()
				views.append(["sun", spawn + Vector3(0, 3, 0), spawn + Vector3(0, 3, 0) + flat * 30.0 + Vector3(0, 30.0 * clampf(to_sun.y / maxf(Vector2(to_sun.x, to_sun.z).length(), 0.01), 0.0, 1.0) * 0.6, 0)])
				views.append(["away", spawn + Vector3(0, 3, 0), spawn + Vector3(0, 2.5, 0) - flat * 30.0])
			views.append(["low", spawn + Vector3(0, 0.35, 0) + fwd * 2.0, spawn + fwd * 8.0])
			views.append_array(LOOKS_EYES.get(id, []))
			if root.has_method("preview_views"):
				var pv: Array = root.preview_views()
				for k in range(mini(pv.size(), 3)):
					views.append(pv[k])
			if OS.has_environment("SH_EYES"):
				for e: String in OS.get_environment("SH_EYES").split(";"):
					var f: PackedStringArray = e.split("@")
					var a: PackedFloat64Array = f[1].split_floats(",")
					var b: PackedFloat64Array = f[2].split_floats(",")
					views.append([f[0], Vector3(a[0], a[1], a[2]), Vector3(b[0], b[1], b[2])])
			if OS.has_environment("SH_VIEWS"):
				var keep: PackedStringArray = OS.get_environment("SH_VIEWS").split(",")
				views = views.filter(func(v: Array) -> bool: return keep.has(String(v[0])))
			for v: Array in views:
				drone.global_position = v[1]
				var target: Vector3 = v[2]
				drone.look_at(target, Vector3.FORWARD if absf((target - v[1]).normalized().y) > 0.99 else Vector3.UP)
				drone.reset_physics_interpolation()
				for ab: int in ([0, 1] if OS.has_environment("SH_LOOKS_AB") else [1]):
					_looks_features(ab == 1)
					for c: int in cams:
						for qq: float in qs:
							Settings.camera_look = c
							FpvVideo.force_quality = qq
							await get_tree().create_timer(0.5).timeout
							await _drawn_frames(2)
							var img := get_viewport().get_texture().get_image()
							img.convert(Image.FORMAT_RGB8)
							var suffix: String = "" if (cams.size() == 1 and qs.size() == 1) else "_c%dq%d" % [c, int(round(qq * 100.0))]
							if ab == 0:
								suffix += "_off"
							img.save_png(out.path_join("%s_%s%s.png" % [id, v[0], suffix]))
							print("LOOKS SHOT %s_%s%s" % [id, v[0], suffix])
	print("LOOKS DONE ", out)

## SH_LOOKS_AB: the looks track's world features off (false) / on, for
## before/after shots and frame-rate comparisons in one run.
func _looks_features(on: bool) -> void:
	var sc: Node = get_tree().current_scene
	# SH_PERF_CAM=n: the "on" state also uses camera look n (its pass).
	if OS.has_environment("SH_PERF_CAM"):
		Settings.camera_look = int(OS.get_environment("SH_PERF_CAM")) if on else 0
	if on:
		WorldShading.set_detail(Settings.graphics_quality)
	else:
		RenderingServer.global_shader_parameter_set("sh_detail", Vector4(0, 1, 0, 0))
	for n in ["GrassTufts", "UI/SunGlare"]:
		var node: Node = sc.find_child(n.get_file(), true, false) if sc else null
		if node:
			node.set_meta("looks_off", not on)
			node.set_process(on)
			node.set("visible", on)

var _draws: int = 0

func _count_draw() -> void:
	_draws += 1

func _drawn_frames(n: int) -> void:
	if not RenderingServer.frame_post_draw.is_connected(_count_draw):
		RenderingServer.frame_post_draw.connect(_count_draw)
	var goal: int = _draws + n
	var t0: int = Time.get_ticks_msec()
	while _draws < goal:
		await get_tree().process_frame
		# Ask for the screen every 8 s (other Godot windows may take it back).
		if Time.get_ticks_msec() - t0 > 8000:
			t0 = Time.get_ticks_msec()
			DisplayServer.window_move_to_foreground()

## `-- --dev-preview perf <map id>`: loads one map the way the game does
## and prints one PERFROW line: time to the first flyable frame (from
## engine start), whether it came from the map cache, then per graphics
## quality (switched live, Low/Medium/High) the FPS at spawn (uncapped,
## no vsync, 3 s average), draw calls, primitives, Godot's static memory
## and the process RSS. Run it twice for cold / cached (delete
## user://mapcache or SH_NOCACHE=1 for cold). Used for the Round 2
## performance table (notes/r2-flight.md).
func _perf_run() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[args.find("perf") + 1] if args.find("perf") + 1 < args.size() else "village"
	var m: Dictionary = {}
	for mm in MapCatalog.MAPS:
		if mm.id == id:
			m = mm
	Settings.selected_drone = m.drone if m.get("drone", "any") != "any" else "seeker3"
	Settings.graphics_quality = 1
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	DisplayServer.window_move_to_foreground()
	var t0: int = Time.get_ticks_msec()
	get_tree().change_scene_to_file(m.scene)
	for k in range(4):
		await get_tree().process_frame
	await _drawn_frames(3)
	var ready_ms: int = Time.get_ticks_msec()
	var sc: Node = get_tree().current_scene
	var cached: bool = sc is BuiltMap and (sc as BuiltMap).from_cache
	var line: String = "PERFROW %s ready=%d ms (load %d ms) cache=%s" % [id, ready_ms, ready_ms - t0, cached]
	await get_tree().create_timer(2.0).timeout
	for q in range(3):
		Settings.graphics_quality = q
		Settings.apply_graphics_settings()
		Engine.max_fps = 0
		DisplayServer.window_move_to_foreground()
		await get_tree().create_timer(1.5).timeout
		# (A window covered by another one draws nothing on macOS - other
		# tracks' windows come and go - so up to three tries.)
		var fps: float = 0.0
		for attempt in range(3):
			var f0: int = Engine.get_frames_drawn()
			var tq: int = Time.get_ticks_msec()
			await get_tree().create_timer(3.0).timeout
			fps = (Engine.get_frames_drawn() - f0) * 1000.0 / maxf(Time.get_ticks_msec() - tq, 1)
			if fps > 1.0:
				break
			DisplayServer.window_move_to_foreground()
		var out: Array = []
		OS.execute("ps", ["-o", "rss=", "-p", str(OS.get_process_id())], out)
		var rss: float = float(str(out[0]).strip_edges()) / 1024.0 if not out.is_empty() else -1.0
		line += " | %s fps=%.0f draws=%d prims=%dk static=%dMB rss=%dMB" % [Settings.QUALITY_NAMES[q], fps,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000,
			OS.get_static_memory_usage() / 1048576, int(rss)]
	print(line)

## `-- --dev-preview perfdetail <map id>`: where a frame goes on Low with
## a weak machine's settings (fullscreen, light fisheye, no shadows):
## FPS, process / physics CPU ms, GPU ms, draw calls - for the base and
## with one thing changed at a time. Prints PERFD lines.
func _perf_detail() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[args.find("perfdetail") + 1] if args.find("perfdetail") + 1 < args.size() else "village"
	var m: Dictionary = {}
	for mm in MapCatalog.MAPS:
		if mm.id == id:
			m = mm
	Settings.selected_drone = m.drone if m.get("drone", "any") != "any" else OS.get_environment("SH_PERFD_DRONE") if OS.has_environment("SH_PERFD_DRONE") else "whoop"
	Settings.graphics_quality = int(OS.get_environment("SH_PERFD_Q")) if OS.has_environment("SH_PERFD_Q") else 0
	Settings.shadows_enabled = false
	Settings.lens_fisheye = 1
	Settings.camera_look = 0
	Settings.set_fullscreen(true)
	get_tree().change_scene_to_file(m.scene)
	for k in range(4):
		await get_tree().process_frame
	await _drawn_frames(3)
	await get_tree().create_timer(3.0).timeout
	Settings.set_max_fps(0)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var vp_rid: RID = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(vp_rid, true)
	var sc: Node = get_tree().current_scene
	var sz: Vector2i = DisplayServer.window_get_size()
	print("PERFD window %dx%d scale %.2f mode %d" % [sz.x, sz.y, get_viewport().scaling_3d_scale, get_tree().root.content_scale_mode])
	if OS.has_environment("SH_PERFD_SPAWN"):
		_shot("spawn_whoop_%s.png" % id)
		var cam4: Camera3D = get_viewport().get_camera_3d()
		var dr: Node3D = sc.get_node("Drone")
		dr.freeze = true
		for k in range(4):
			dr.global_transform = Transform3D(Basis(Vector3.UP, k * PI * 0.5) * Basis(Vector3.RIGHT, -0.35), dr.global_position + Vector3(0, 1.5 if k == 0 else 0.0, 0))
			await get_tree().create_timer(0.5).timeout
			_shot("spawn_whoop_%s_%d.png" % [id, k])
		return
	if OS.has_environment("SH_PERFD_NEAR"):
		var cam3: Camera3D = get_viewport().get_camera_3d()
		print("PERFD cam ", cam3.get_path(), " pos ", cam3.global_position, " near ", cam3.near, " far ", cam3.far, " mask ", cam3.cull_mask)
		for vi in sc.find_children("*", "VisualInstance3D", true, false):
			var v3 := vi as VisualInstance3D
			if not v3.is_visible_in_tree() or (v3.layers & cam3.cull_mask) == 0:
				continue
			var ab: AABB = v3.global_transform * v3.get_aabb()
			var cp: Vector3 = cam3.global_position
			var cl := Vector3(clampf(cp.x, ab.position.x, ab.end.x), clampf(cp.y, ab.position.y, ab.end.y), clampf(cp.z, ab.position.z, ab.end.z))
			var over: bool = ab.position.y > cp.y and ab.position.y < cp.y + 0.4 and cp.x > ab.position.x and cp.x < ab.end.x and cp.z > ab.position.z and cp.z < ab.end.z
			if over:
				print("PERFD OVER ", v3.get_path(), " aabb ", ab)
		return
	print("PERFD screen scale %.2f max %.2f size %s dpi %d win %s" % [DisplayServer.screen_get_scale(), DisplayServer.screen_get_max_scale(), DisplayServer.screen_get_size(), DisplayServer.screen_get_dpi(), DisplayServer.window_get_size()])
	if OS.has_environment("SH_PERFD_HOLD"):
		print("PERFD hold pid %d" % OS.get_process_id())
		await get_tree().create_timer(float(OS.get_environment("SH_PERFD_HOLD"))).timeout
		return
	var variants: Array = [
		["base", func(): pass, func(): pass],
		["no fisheye", func(): Settings.lens_fisheye = 0, func(): Settings.lens_fisheye = 1],
		["scale 0.35", func(): get_viewport().scaling_3d_scale = 0.35, func(): get_viewport().scaling_3d_scale = Settings.render_scale(Settings.graphics_quality)],
		["medium", func(): _set_q(1), func(): _set_q(0)],
		["high", func(): _set_q(2), func(): _set_q(0)],
		["no UI", func(): sc.get_node("UI").visible = false, func(): sc.get_node("UI").visible = true],
		["no generated", func(): _child_vis(sc, "Generated", false), func(): _child_vis(sc, "Generated", true)],
		["no terrain", func(): _child_vis(sc, "Terrain", false), func(): _child_vis(sc, "Terrain", true)],
		["no sky", func(): _sky(sc, false), func(): _sky(sc, true)],
		["no trees", func(): _set_trees(sc, false), func(): _set_trees(sc, true)],
		["far 300", func(): get_viewport().get_camera_3d().far = 300.0, func(): Settings.apply_graphics_settings()],
		["no glare", func(): _ui_part(sc, "SunGlare", false), func(): _ui_part(sc, "SunGlare", true)],
		["no HUD text", func(): _hud_text(sc, false), func(): _hud_text(sc, true)],
		["no sky", func(): _sky(sc, false), func(): _sky(sc, true)],
		["no 3D", func(): _world3d(sc, false), func(): _world3d(sc, true)],
		["no 3D no UI", func(): _world3d(sc, false); sc.get_node("UI").visible = false, func(): _world3d(sc, true); sc.get_node("UI").visible = true],
		["base again", func(): pass, func(): pass],
	]
	var only: PackedStringArray = OS.get_environment("SH_PERFD_ONLY").split(",") if OS.has_environment("SH_PERFD_ONLY") else PackedStringArray()
	for v in variants:
		if not only.is_empty() and not only.has(v[0]):
			continue
		(v[1] as Callable).call()
		DisplayServer.window_move_to_foreground()
		await get_tree().create_timer(1.5).timeout
		var f0: int = Engine.get_frames_drawn()
		var t0: int = Time.get_ticks_msec()
		var proc: float = 0.0
		var phys: float = 0.0
		var gpu: float = 0.0
		var cpu_r: float = 0.0
		var n: int = 0
		while Time.get_ticks_msec() - t0 < 3000:
			await get_tree().process_frame
			proc += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
			phys += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
			gpu += RenderingServer.viewport_get_measured_render_time_gpu(vp_rid)
			cpu_r += RenderingServer.viewport_get_measured_render_time_cpu(vp_rid) + RenderingServer.get_frame_setup_time_cpu()
			n += 1
		var fps: float = (Engine.get_frames_drawn() - f0) * 1000.0 / maxf(Time.get_ticks_msec() - t0, 1)
		print("PERFD %s %-11s fps=%5.1f frame=%5.1fms process=%5.2fms physics=%5.2fms render_cpu=%5.2fms gpu=%5.2fms draws=%d prims=%dk" % [id, v[0], fps,
			1000.0 / maxf(fps, 0.1), proc / n, phys / n, cpu_r / n, gpu / n,
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME) / 1000])
		if v[0] in ["base", "no UI"]:
			_shot("perfd_%s.png" % v[0].replace(" ", "_"))
		(v[2] as Callable).call()

## `--headless -- --dev-preview cpuprof <map id>`: the CPU side alone
## (no GPU in headless): the drone hovering, frames per second uncapped,
## then with one per-frame part switched off at a time. Prints CPUP lines.
func _cpu_prof() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[args.find("cpuprof") + 1] if args.find("cpuprof") + 1 < args.size() else "village"
	var m: Dictionary = {}
	for mm in MapCatalog.MAPS:
		if mm.id == id:
			m = mm
	Settings.selected_drone = m.drone if m.get("drone", "any") != "any" else "whoop"
	Settings.graphics_quality = 0
	get_tree().change_scene_to_file(m.scene)
	await get_tree().create_timer(3.0).timeout
	Engine.max_fps = 0
	OS.low_processor_usage_mode = false
	OS.low_processor_usage_mode_sleep_usec = 0
	var sc: Node = get_tree().current_scene
	var d: Drone = sc.get_node("Drone")
	InputManager.armed = true
	InputManager.test_override = {"roll": 0.0, "pitch": 0.0, "yaw": 0.0, "throttle": 0.6}
	await get_tree().create_timer(1.0).timeout
	InputManager.test_override.throttle = 0.42
	var groups := {
		"drone _process": [d],
		"ui": [sc.get_node("UI")],
		"map _process": [sc],
		"settings": [Settings],
		"input": [InputManager],
	}
	for n in sc.find_children("*", "", true, false):
		var cls: String = ""
		var scr: Script = n.get_script()
		if scr and scr.get_global_name() != "":
			cls = scr.get_global_name()
		if cls in ["FpvVideo", "SunGlare", "Replay", "MotorAudio", "DroneShadow", "RaceCourse", "GrassTufts"]:
			if not groups.has(cls):
				groups[cls] = []
			groups[cls].append(n)
	# Physics per step: at 45 fps, sum the physics time over 3 s.
	Engine.max_fps = 45
	var steps0: int = Engine.get_physics_frames()
	var tp: float = 0.0
	var t0p: int = Time.get_ticks_msec()
	while Time.get_ticks_msec() - t0p < 3000:
		await get_tree().process_frame
		tp += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var nsteps: int = Engine.get_physics_frames() - steps0
	print("CPUP %s physics: %d steps in 3 s, %.2f ms per frame at 45 fps" % [id, nsteps, tp / 135.0])
	Engine.max_fps = 0
	var base: float = await _cpu_fps()
	print("CPUP %s base fps=%.0f (%.2f ms)" % [id, base, 1000.0 / base])
	for g in groups:
		for n in groups[g]:
			n.set_process(false)
		var f: float = await _cpu_fps()
		print("CPUP %s without %-16s fps=%.0f  saves %.2f ms" % [id, g, f, 1000.0 / base - 1000.0 / f])
		for n in groups[g]:
			n.set_process(true)
	# Physics: the whole 120 Hz step (drone, collisions, race gates).
	d.set_physics_process(false)
	var f2: float = await _cpu_fps()
	print("CPUP %s without drone physics script fps=%.0f  saves %.2f ms" % [id, f2, 1000.0 / base - 1000.0 / f2])
	d.set_physics_process(true)
	Engine.physics_ticks_per_second = 30
	var f3: float = await _cpu_fps()
	print("CPUP %s physics at 30 Hz fps=%.0f  saves %.2f ms" % [id, f3, 1000.0 / base - 1000.0 / f3])
	Engine.physics_ticks_per_second = 120
	InputManager.test_override = {}

func _cpu_fps() -> float:
	await get_tree().create_timer(0.5).timeout
	var f0: int = Engine.get_process_frames()
	var t0: int = Time.get_ticks_usec()
	await get_tree().create_timer(3.0).timeout
	return (Engine.get_process_frames() - f0) * 1e6 / float(Time.get_ticks_usec() - t0)

func _ui_part(sc: Node, n: String, on: bool) -> void:
	var r: Control = sc.get_node("UI")._root
	var c: Node = r.get_node_or_null(n)
	if c:
		c.set_process(on)
		(c as CanvasItem).visible = on

func _hud_text(sc: Node, on: bool) -> void:
	var r: Control = sc.get_node("UI")._root
	for c in r.get_children():
		if c is CanvasItem and not (c is FpvVideo or c is SunGlare):
			(c as CanvasItem).visible = on

var _sky_mode: int = 0
func _sky(sc: Node, on: bool) -> void:
	var we := sc.get_node_or_null("WorldEnvironment") as WorldEnvironment
	if we == null:
		return
	if not on:
		_sky_mode = we.environment.background_mode
		we.environment.background_mode = Environment.BG_COLOR
	else:
		we.environment.background_mode = _sky_mode

func _world3d(sc: Node, on: bool) -> void:
	for c in sc.get_children():
		if c is Node3D and c.name != "Drone":
			(c as Node3D).visible = on
	_sky(sc, on)

func _set_q(q: int) -> void:
	Settings.graphics_quality = q
	Settings.apply_graphics_settings()
	Settings.set_max_fps(0)

func _child_vis(sc: Node, n: String, on: bool) -> void:
	for c in sc.get_children():
		if c is Node3D and String(c.name).begins_with(n):
			(c as Node3D).visible = on

func _set_trees(n: Node, on: bool) -> void:
	if n is MultiMeshInstance3D or (n is MeshInstance3D and n.get_parent() and n.get_parent().name == "Forest"):
		(n as Node3D).visible = on
	for c in n.get_children():
		_set_trees(c, on)

## `-- --dev-preview flight`: the realism OSD (battery low, prop
## damage), the race ghost in front of the FPV camera, the Flight tab.
func _flight_shots() -> void:
	Settings.selected_drone = "seeker3"
	Settings.game_mode = Settings.MODE_RACE
	Settings.battery_enabled = true
	Settings.prop_damage = true
	Settings.race_ghost = true
	get_tree().change_scene_to_file("res://scenes/maps/RaceField.tscn")
	await get_tree().create_timer(3.0).timeout
	var sc: Node = get_tree().current_scene
	var d: Drone = sc.get_node("Drone")
	InputManager.armed = true
	InputManager.test_override = {"roll": 0.0, "pitch": 0.0, "yaw": 0.0, "throttle": 0.5}
	await get_tree().create_timer(0.8).timeout
	InputManager.test_override.throttle = 0.36
	d.battery.used_mah = d.battery.capacity_mah * 0.965
	await get_tree().create_timer(5.0).timeout
	await _drawn_frames(3)
	_shot("flight_osd_low_battery.png")
	d.battery.used_mah = d.battery.capacity_mah * 1.01
	await get_tree().create_timer(0.6).timeout
	await _drawn_frames(3)
	_shot("flight_osd_empty.png")
	d.reset_to_spawn()
	d.prop_health = [0.7, 1.0, 1.0, 1.0]
	d.prop_damage_flash = 2.0
	InputManager.test_override.throttle = 0.6
	await get_tree().create_timer(0.7).timeout
	await _drawn_frames(3)
	_shot("flight_osd_prop_damaged.png")
	# The ghost: a recorded "lap" that hangs 3 m ahead of the camera,
	# drifting sideways - the course is told a lap is running.
	var course: RaceCourse = sc.course
	d.freeze = true
	await get_tree().create_timer(0.3).timeout
	var cam: Camera3D = get_viewport().get_camera_3d()
	var cb: Basis = cam.global_transform.basis
	var fwd: Vector3 = -cb.z
	var pos := PackedVector3Array()
	var rot := PackedVector4Array()
	for i in range(300):
		pos.append(cam.global_position + fwd * 1.6 + cb.x * (0.25 + 0.001 * i) - cb.y * 0.05)
		var q: Quaternion = (d.global_transform.basis * Basis(Vector3.FORWARD, 0.4)).get_rotation_quaternion()
		rot.append(Vector4(q.x, q.y, q.z, q.w))
	course._ghost_pos = pos
	course._ghost_rot = rot
	course._lap_start = course._time
	course._lap = 1
	await get_tree().create_timer(1.5).timeout
	await _drawn_frames(3)
	_shot("flight_ghost.png")
	InputManager.test_override = null
	InputManager.armed = false
	Settings.battery_enabled = false
	Settings.prop_damage = false
	get_tree().change_scene_to_file("res://scenes/MainMenu.tscn")
	await get_tree().create_timer(2.5).timeout
	var settings_btn: Button = _find_button(get_tree().current_scene, "Settings")
	if settings_btn:
		settings_btn.pressed.emit()
	await get_tree().create_timer(1.0).timeout
	var st: SettingsScreens = get_tree().current_scene.get("_settings")
	st.settings_tabs.current_tab = SettingsScreens.TAB_NAMES.find("Flight")
	await get_tree().create_timer(0.4).timeout
	_shot("flight_settings.png")

func _shot(filename: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://previews/%s" % filename)
	print("SCREENSHOT_SAVED: previews/", filename)

func _find_button(node: Node, text: String) -> Button:
	if node == null:
		return null
	if node is Button and (node.text.contains(text) or str(node.get_meta("find_text", "")).contains(text)):
		return node
	for child in node.get_children():
		var found := _find_button(child, text)
		if found:
			return found
	return null
