extends RefCounted
## Cinematic camera flights for the trailer:
##   godot --path . --fixed-fps 60 -- --dev-preview cine <shot>
## --fixed-fps steps the game (and shader TIME) by exactly 1/60 s per
## frame, however slow the machine renders, so High quality comes out
## smooth. The shot renders in its own SubViewport at SS x 1920x1080
## (default SS 2 = 4K, scaled down by ffmpeg for clean edges) - the
## window itself is limited to the screen. A camera (no drone, no HUD)
## flies a smoothed spline through the shot's points, looking where it
## goes (pitch limited) and banking into turns like a quad. The path is
## lifted to stay clear of the ground. Frames go to
## SH_CINE_OUT/<shot>/00000.jpg (default user://cine); then:
##   ffmpeg -framerate 60 -i %05d.jpg -vf scale=1920:1080:flags=lanczos
##       -c:v libx264 -crf 16 -pix_fmt yuv420p <shot>.mp4

## Per shot: map, speed (m/s), fov, clear (m above what's below),
## ray_up (the ground probe starts this far above the path - small for
## indoor shots so roofs and gate bars don't count as ground), pts.
const SHOTS: Dictionary = {
	# Low over the lake toward the waterfall, then up over its top.
	"lake_falls": {"map": "mountain_lake", "speed": 27.0, "fov": 78.0, "clear": 2.5, "ray_up": 300.0, "pts": [
		Vector3(-60, 4, -40), Vector3(0, 3, -36), Vector3(55, 4, -32), Vector3(90, 16, -30),
		Vector3(118, 48, -30), Vector3(150, 82, -32), Vector3(215, 100, -36), Vector3(250, 104, -38)]},
	# Camera style (no banking): low along the southern main line, under
	# the road bridge and through the station's train shed, turned a
	# little toward the train standing on the northern line.
	"harbour_station": {"map": "harbour", "speed": 16.0, "fov": 75.0, "clear": 2.0, "ray_up": 0.5, "bank": 0.0, "yaw_off": -32.0, "pts": [
		Vector3(-40, 3.5, -416.6), Vector3(-100, 2.6, -416.6), Vector3(-200, 2.6, -416.6), Vector3(-300, 2.6, -416.6),
		Vector3(-400, 2.6, -416.6), Vector3(-450, 3.0, -416.6)]},
	# Steel mill: in low from the east end, the length of the ore
	# bunkers, pull up and out over the west end.
	"steel_bunkers": {"map": "steelmill", "speed": 26.0, "fov": 80.0, "clear": 1.5, "ray_up": 0.5, "pts": [
		Vector3(175, 22, 0), Vector3(135, 10, 11), Vector3(95, 3.2, 11), Vector3(20, 3.0, 11), Vector3(-20, 3.0, 11),
		Vector3(-60, 3.0, 11), Vector3(-90, 3.5, -2), Vector3(-112, 8, -22), Vector3(-140, 18, -40),
		Vector3(-175, 30, -55)]},
	# Race Field: the course itself - "course" builds the points from the
	# map's real gates (in front of and behind each opening, flown toward
	# its -Z); dive gates and low hurdles are left out. "gates" picks
	# which (indices into the course, start = 0).
	"field_gates": {"map": "race_field", "speed": 16.0, "fov": 84.0, "clear": 0.6, "ray_up": 0.3, "bank": 0.6,
		"course": true, "gates": [0, 1, 2, 3, 6, 7, 8], "lead": 5.0, "smooth": 1},
	# --- "Horizons" trailer: camera style (bank 0), "look" = keep a
	# point in frame instead of looking along the path. ---
	"t_lake_dawn": {"map": "mountain_lake", "speed": 10.0, "fov": 70.0, "clear": 2.0, "bank": 0.0, "look": Vector3(48, 9, 18), "pts": [
		Vector3(-30, 3, -125), Vector3(0, 3, -85), Vector3(25, 3.5, -42)]},
	"t_village": {"map": "village", "speed": 13.0, "fov": 65.0, "clear": 3.0, "bank": 0.0, "look": Vector3(40, 12, -74), "pts": [
		Vector3(70, 34, 270), Vector3(62, 26, 200), Vector3(55, 20, 140)]},
	"t_belfry": {"map": "village", "speed": 7.0, "fov": 75.0, "clear": 1.0, "ray_up": 0.3, "bank": 0.0, "pts": [
		Vector3(-6, 27.4, -72.5), Vector3(18.7, 27.0, -72.5), Vector3(32.7, 27.0, -72.5), Vector3(46, 26.6, -72.5), Vector3(62, 24.5, -72.5)]},
	"t_viaduct": {"map": "village", "speed": 7.0, "fov": 72.0, "clear": 1.5, "ray_up": 0.5, "bank": 0.0, "pts": [
		Vector3(-188.5, -12, -262), Vector3(-189, -11.5, -300), Vector3(-189.5, -11, -334)]},
	"t_wheat": {"map": "village", "speed": 9.0, "fov": 72.0, "clear": 1.8, "ray_up": 0.3, "bank": 0.0, "pts": [
		Vector3(205, 2.6, 226), Vector3(227, 2.4, 247), Vector3(268, 3.0, 288)]},
	"t_steel": {"map": "steelmill", "speed": 14.0, "fov": 75.0, "clear": 1.5, "ray_up": 0.5, "bank": 0.0, "pts": [
		Vector3(150, 8, 9), Vector3(95, 3.2, 11), Vector3(20, 3.0, 11), Vector3(-20, 3.0, 11), Vector3(-50, 3.0, 11)]},
	"t_furnaces": {"map": "steelmill", "speed": 11.0, "fov": 65.0, "clear": 3.0, "bank": 0.0, "look": Vector3(-20, 16, 50), "pts": [
		Vector3(-150, 30, 150), Vector3(-90, 31, 156), Vector3(-30, 30, 152)]},
	"t_gates": {"map": "race_field", "speed": 13.0, "fov": 80.0, "clear": 0.6, "ray_up": 0.3, "bank": 0.0,
		"course": true, "gates": [0, 1, 2, 3], "lead": 5.0, "smooth": 1},
	"t_falls": {"map": "mountain_lake", "speed": 20.0, "fov": 75.0, "clear": 2.5, "bank": 0.0, "pts": [
		Vector3(30, 4, -33), Vector3(55, 4, -32), Vector3(90, 16, -30),
		Vector3(118, 48, -30), Vector3(150, 82, -32), Vector3(215, 100, -36), Vector3(250, 104, -38)]},
	"t_end": {"map": "mountain_lake", "speed": 16.0, "fov": 70.0, "clear": 3.0, "bank": 0.0, "look": Vector3(45, 6, 20), "pts": [
		Vector3(30, 9, -25), Vector3(12, 30, -95), Vector3(-15, 70, -170), Vector3(-30, 95, -215)]},
	"t_barn": {"map": "village", "speed": 6.0, "fov": 75.0, "clear": 1.2, "ray_up": 0.3, "bank": 0.0, "pts": [
		Vector3(92, 5.3, 237.6), Vector3(114, 5.1, 237.5), Vector3(136, 4.9, 237.2), Vector3(158, 4.7, 237), Vector3(172, 5.0, 237)]},
	# Across the T1-T2 walkway at floor 4 and on through T2's steel frame.
	"t_tower": {"map": "construction", "speed": 8.0, "fov": 78.0, "clear": 1.0, "ray_up": 0.3, "bank": 0.0, "pts": [
		Vector3(-114, 15.9, -100), Vector3(-100, 15.9, -100), Vector3(-85, 15.9, -100), Vector3(-70, 15.9, -100), Vector3(-55, 15.9, -100)]},
	# --- trailer v2: the same places with curves, height changes, arcs
	# and drifting views instead of straight lines. ---
	"v2_lake_dawn": {"map": "mountain_lake", "speed": 10.0, "fov": 70.0, "clear": 2.0, "look": Vector3(48, 9, 18), "pts": [
		Vector3(-62, 2.5, -112), Vector3(-30, 3.0, -96), Vector3(0, 4.0, -70), Vector3(18, 5.5, -40)]},
	"v2_village": {"map": "village", "speed": 12.0, "fov": 65.0, "clear": 3.0, "look": Vector3(40, 14, -74), "look_to": Vector3(40, 8, -74), "pts": [
		Vector3(130, 42, 235), Vector3(80, 30, 190), Vector3(35, 21, 150)]},
	"v2_belfry": {"map": "village", "speed": 7.0, "fov": 75.0, "clear": 1.0, "ray_up": 0.3, "pts": [
		Vector3(-18, 21, -48), Vector3(-2, 25, -64), Vector3(10, 26.9, -71.5), Vector3(20, 27.0, -72.5), Vector3(32.7, 27.0, -72.5),
		Vector3(45, 26.6, -72.5), Vector3(58, 24.5, -78), Vector3(72, 21, -92)]},
	"v2_viaduct": {"map": "village", "speed": 7.0, "fov": 72.0, "clear": 1.5, "ray_up": 0.5, "pts": [
		Vector3(-168, -9, -268), Vector3(-181, -11, -284), Vector3(-189, -11.5, -300), Vector3(-194, -11, -316), Vector3(-205, -8, -332)]},
	"v2_barn": {"map": "village", "speed": 6.0, "fov": 75.0, "clear": 1.2, "ray_up": 0.3, "pts": [
		Vector3(80, 6.4, 229), Vector3(97, 5.6, 235.6), Vector3(112, 5.1, 237.5), Vector3(136, 4.9, 237.2), Vector3(158, 4.7, 237),
		Vector3(170, 5.6, 242), Vector3(181, 7.5, 252)]},
	"v2_steel": {"map": "steelmill", "speed": 14.0, "fov": 75.0, "clear": 1.5, "ray_up": 0.5, "yaw_off": 0.0, "yaw_off_to": 16.0, "pts": [
		Vector3(172, 16, -6), Vector3(142, 8, 4), Vector3(110, 3.4, 11), Vector3(60, 3.0, 11), Vector3(20, 3.0, 11),
		Vector3(-20, 3.0, 11), Vector3(-50, 3.3, 11)]},
	"v2_furnaces": {"map": "steelmill", "speed": 11.0, "fov": 65.0, "clear": 3.0, "look": Vector3(-25, 16, 55), "look_to": Vector3(5, 16, 50), "pts": [
		Vector3(-125, 26, 125), Vector3(-75, 30, 150), Vector3(-15, 32, 158), Vector3(40, 29, 140)]},
	"v2_tower": {"map": "construction", "speed": 8.0, "fov": 78.0, "clear": 1.0, "ray_up": 0.3, "pts": [
		Vector3(-185, 12, -82), Vector3(-165, 15, -96), Vector3(-150, 15.9, -100), Vector3(-130, 15.9, -100), Vector3(-110, 15.9, -100),
		Vector3(-90, 15.9, -100), Vector3(-70, 15.9, -100), Vector3(-55, 17, -100), Vector3(-46, 23, -90), Vector3(-40, 32, -72)]},
	"v2_falls": {"map": "mountain_lake", "speed": 20.0, "fov": 75.0, "clear": 2.5, "yaw_off": -8.0, "yaw_off_to": 6.0, "pts": [
		Vector3(15, 4, -52), Vector3(55, 4.5, -38), Vector3(92, 16, -28),
		Vector3(118, 48, -30), Vector3(150, 82, -34), Vector3(210, 98, -44), Vector3(250, 104, -54)]},
	"v2_end": {"map": "mountain_lake", "speed": 16.0, "fov": 70.0, "clear": 3.0, "look": Vector3(45, 6, 20), "pts": [
		Vector3(55, 9, -22), Vector3(30, 26, -85), Vector3(-15, 60, -150), Vector3(-45, 92, -200)]},
	"v2_harbour": {"map": "harbour", "speed": 16.0, "fov": 75.0, "clear": 2.0, "ray_up": 0.5, "yaw_off": -10.0, "yaw_off_to": -34.0, "pts": [
		Vector3(-30, 6, -430), Vector3(-75, 3.6, -421), Vector3(-110, 2.8, -417), Vector3(-200, 2.6, -416.6), Vector3(-300, 2.8, -416.6),
		Vector3(-400, 3.2, -416.6), Vector3(-450, 4.0, -418)]},
}

const MAX_PITCH: float = 0.26

var tree: SceneTree

func run(p_tree: SceneTree, shot_id: String) -> void:
	tree = p_tree
	# "views:<map id>": print the map's preview views (named camera spots).
	var shot: Dictionary = SHOTS.get(shot_id, {})
	if shot_id.begins_with("views:"):
		shot = {"map": shot_id.substr(6), "pts": []}
		shot_id = "_views"
	if shot.is_empty():
		print("CINE unknown shot %s - have %s" % [shot_id, SHOTS.keys()])
		return
	var m: Dictionary = {}
	for mm in MapCatalog.MAPS:
		if mm.id == shot.map:
			m = mm
	Settings.selected_drone = m.drone if m.get("drone", "any") != "any" else "seeker3"
	Settings.graphics_quality = 2
	Settings.shadows_enabled = true
	Settings.lens_fisheye = 0
	Settings.camera_look = 0
	tree.change_scene_to_file(m.scene)
	for k in range(4):
		await tree.process_frame
	await tree.create_timer(2.0).timeout
	var sc: Node = tree.current_scene
	if shot_id == "_views":
		for v in sc.call("preview_views") if sc.has_method("preview_views") else []:
			print("CINE view %s %s -> %s" % [v[0], v[1], v[2]])
		return
	var ui: Node = sc.get_node_or_null("UI")
	if ui:
		ui.set("visible", false)
	var drone := sc.get_node_or_null("Drone") as RigidBody3D
	var src_cam: Camera3D = tree.root.get_viewport().get_camera_3d()
	var ss: float = float(OS.get_environment("SH_CINE_SS")) if OS.has_environment("SH_CINE_SS") else 2.0
	var vp := SubViewport.new()
	# SH_CINE_PORTRAIT=1: 1080x1920 for Shorts; the fov then sets the
	# width (a little narrower than the landscape height fov).
	var portrait: bool = OS.has_environment("SH_CINE_PORTRAIT")
	vp.size = Vector2i(roundi(1080 * ss), roundi(1920 * ss)) if portrait else Vector2i(roundi(1920 * ss), roundi(1080 * ss))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = tree.root.msaa_3d
	vp.world_3d = tree.root.world_3d
	sc.add_child(vp)
	var cam := Camera3D.new()
	cam.fov = shot.get("fov", 78.0)
	if portrait:
		cam.keep_aspect = Camera3D.KEEP_WIDTH
		cam.fov = shot.get("fov", 78.0) - 6.0
	cam.near = src_cam.near if src_cam else 0.05
	cam.far = src_cam.far if src_cam else 4000.0
	if src_cam:
		cam.environment = src_cam.environment
		cam.attributes = src_cam.attributes
	vp.add_child(cam)
	cam.current = true
	# The window's own 3D isn't needed while the shot renders off screen.
	tree.root.disable_3d = true
	if drone:
		drone.freeze = true
		drone.global_position += Vector3(0, -500, 0)
	if shot.get("course", false):
		shot = shot.duplicate()
		shot.pts = _course_pts(sc, shot)
	# SH_CINE_PTS="x,y,z;x,y,z;..." replaces the shot's points (trying routes).
	if OS.has_environment("SH_CINE_PTS"):
		var pts: Array = []
		for t in OS.get_environment("SH_CINE_PTS").split(";"):
			var c: PackedFloat64Array = t.split_floats(",")
			pts.append(Vector3(c[0], c[1], c[2]))
		shot = shot.duplicate()
		shot.pts = pts
	var path: PackedVector3Array = _path(shot.pts, shot.get("clear", 2.0), shot.get("ray_up", 300.0), shot.get("smooth", 3), sc)
	var lens: PackedFloat32Array = _lengths(path)
	# SH_CINE_CHECK=1: only report where the path runs into something.
	if OS.has_environment("SH_CINE_CHECK"):
		var space: PhysicsDirectSpaceState3D = cam.get_world_3d().direct_space_state
		for i in range(1, path.size()):
			for dirn in [[path[i - 1], path[i]], [path[i], path[i - 1]]]:
				var hit: Dictionary = space.intersect_ray(PhysicsRayQueryParameters3D.create(dirn[0], dirn[1]))
				if not hit.is_empty():
					print("CINE hit at %.0f m: %s (%s) path %s -> %s" % [lens[i], hit.position, hit.collider.get_parent().name if hit.collider else "?", path[i - 1], path[i]])
					break
		print("CINE check done, path %.0f m" % lens[lens.size() - 1])
	var check_only: bool = OS.has_environment("SH_CINE_CHECK")
	var dir: String = (OS.get_environment("SH_CINE_OUT") if OS.has_environment("SH_CINE_OUT") else ProjectSettings.globalize_path("user://cine")).path_join(shot_id + ("_v" if portrait else ""))
	if not check_only:
		DirAccess.make_dir_recursive_absolute(dir)
	# SH_CINE_RESUME=1 keeps the frames already written (a stopped render).
	var resume: bool = OS.has_environment("SH_CINE_RESUME")
	if not resume and not check_only:
		for f in DirAccess.get_files_at(dir):
			DirAccess.remove_absolute(dir.path_join(f))
	var total: float = lens[lens.size() - 1]
	# SH_CINE_SPEED scales the shot's speed (faster cuts for the Short).
	var speed_k: float = float(OS.get_environment("SH_CINE_SPEED")) if OS.has_environment("SH_CINE_SPEED") else 1.0
	var frames: int = int(total / (shot.get("speed", 25.0) * speed_k) * 60.0)
	var poses: Array[Transform3D] = _poses(shot, path, lens, frames)
	if check_only:
		_report_motion(poses)
		return
	# f < 0: the first view settles (shader compiles) before frames are kept.
	for f in range(-30, frames + 1):
		cam.global_transform = poses[maxi(f, 0)]
		var out: String = dir.path_join("%05d.jpg" % f)
		if resume and f >= 0 and FileAccess.file_exists(out) and FileAccess.get_file_as_bytes(out).size() > 1000:
			# Still step the frame: the clouds and water must move on as before.
			await RenderingServer.frame_post_draw
			continue
		await RenderingServer.frame_post_draw
		if f >= 0:
			vp.get_texture().get_image().save_jpg(out, 0.92)
	print("CINE done %d frames in %s" % [frames + 1, dir])

## The camera for every frame. Position: along the path, easing in and
## out. View: along the path (or at "look", moving to "look_to" over the
## shot), turned by "yaw_off" (to "yaw_off_to"), pitch limited - then
## smoothed with a zero-phase filter (forward and backward, ~SMOOTH_T),
## so it turns like a camera on a gimbal: no snaps, and no lag either.
const SMOOTH_T: float = 0.5

func _poses(shot: Dictionary, path: PackedVector3Array, lens: PackedFloat32Array, frames: int) -> Array[Transform3D]:
	var total: float = lens[lens.size() - 1]
	var pos: Array[Vector3] = []
	var dirs: Array[Vector3] = []
	var prev: Vector3 = (path[1] - path[0]).normalized()
	for f in range(frames + 1):
		var u: float = float(f) / frames
		var e: float = u * u * (3.0 - 2.0 * u) * 0.35 + u * 0.65
		var d: float = e * total
		var p: Vector3 = _at(path, lens, d)
		var fwd: Vector3 = (_at(path, lens, d + 10.0) - p).normalized()
		if shot.has("look"):
			var tgt: Vector3 = shot.look.lerp(shot.get("look_to", shot.look), u * u * (3.0 - 2.0 * u))
			fwd = (tgt - p).normalized()
		if fwd.length() < 0.5:
			fwd = prev
		var yo: float = lerpf(shot.get("yaw_off", 0.0), shot.get("yaw_off_to", shot.get("yaw_off", 0.0)), u * u * (3.0 - 2.0 * u))
		fwd = fwd.rotated(Vector3.UP, deg_to_rad(yo))
		var flat := Vector3(fwd.x, 0, fwd.z).normalized()
		var pitch: float = clampf(asin(clampf(fwd.y, -1.0, 1.0)), -MAX_PITCH, MAX_PITCH)
		fwd = (flat * cos(pitch) + Vector3.UP * sin(pitch)).normalized()
		prev = fwd
		pos.append(p)
		dirs.append(fwd)
	var k: float = 1.0 - exp(-1.0 / (60.0 * SMOOTH_T))
	for pass_i in range(2):
		for i in range(1, dirs.size()):
			dirs[i] = dirs[i - 1].lerp(dirs[i], k).normalized()
		for i in range(dirs.size() - 2, -1, -1):
			dirs[i] = dirs[i + 1].lerp(dirs[i], k).normalized()
	var out: Array[Transform3D] = []
	for i in range(dirs.size()):
		out.append(Transform3D(Basis.looking_at(dirs[i], Vector3.UP), pos[i]))
	return out

## Prints the camera's worst turning rate / turning acceleration / speed
## change - the "jerky footage" check. Limits: 35 deg/s, 45 deg/s^2, 4 m/s^2.
func _report_motion(poses: Array[Transform3D]) -> void:
	var w_max: float = 0.0
	var a_max: float = 0.0
	var acc_max: float = 0.0
	var at: Array = [0, 0, 0]
	var w_prev: float = 0.0
	var v_prev: float = -1.0
	for i in range(1, poses.size()):
		var f0: Vector3 = -poses[i - 1].basis.z
		var f1: Vector3 = -poses[i].basis.z
		var w: float = rad_to_deg(f0.angle_to(f1)) * 60.0
		var v: float = poses[i].origin.distance_to(poses[i - 1].origin) * 60.0
		if i > 1:
			var a: float = absf(w - w_prev) * 60.0
			if a > a_max:
				a_max = a
				at[1] = i
			var acc: float = absf(v - v_prev) * 60.0
			if acc > acc_max:
				acc_max = acc
				at[2] = i
		if w > w_max:
			w_max = w
			at[0] = i
		w_prev = w
		v_prev = v
	var ok: bool = w_max <= 35.0 and a_max <= 45.0 and acc_max <= 4.0
	print("CINE motion %s: turn %.0f deg/s (%.1fs), turn accel %.0f deg/s2 (%.1fs), speed change %.1f m/s2 (%.1fs), %.1f s" % [
		"ok" if ok else "JERKY", w_max, at[0] / 60.0, a_max, at[1] / 60.0, acc_max, at[2] / 60.0, poses.size() / 60.0])

## Points through the map's race gates: one `lead` m before and one
## after each chosen opening, plus a run-up before the first.
func _course_pts(sc: Node, shot: Dictionary) -> Array:
	var course: Node = sc.find_child("RaceCourse", true, false)
	var gates: Array = course.get_meta("gates", []) if course else []
	var lead: float = shot.get("lead", 5.0)
	var pts: Array = []
	for i in shot.get("gates", range(gates.size())):
		var xf: Transform3D = gates[i].xf
		var fwd: Vector3 = -xf.basis.z.normalized()
		if OS.has_environment("SH_CINE_CHECK"):
			print("CINE gate %d at %s fwd %s" % [i, xf.origin, fwd])
		if absf(fwd.y) > 0.5 or gates[i].h < 1.0:
			continue
		if pts.is_empty():
			pts.append(xf.origin - fwd * lead * 3.0 + Vector3(0, 0.5, 0))
		pts.append(xf.origin - fwd * lead)
		pts.append(xf.origin)
		pts.append(xf.origin + fwd * lead)
	print("CINE course: %d gates, %d points" % [gates.size(), pts.size()])
	return pts

## Dense Catmull-Rom samples through the points, each lifted to stay
## `clear` above whatever is below, then smoothed so lifts don't jolt.
func _path(pts: Array, clear: float, ray_up: float, smooth: int, sc: Node) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n: int = pts.size()
	for i in range(n - 1):
		var p0: Vector3 = pts[maxi(i - 1, 0)]
		var p1: Vector3 = pts[i]
		var p2: Vector3 = pts[i + 1]
		var p3: Vector3 = pts[mini(i + 2, n - 1)]
		var steps: int = maxi(int(p1.distance_to(p2) / 0.5), 4)
		# Centripetal Catmull-Rom (Barry-Goldman): no loops or overshoot
		# where the points are unevenly spaced (gate approaches).
		var t0: float = 0.0
		var t1: float = t0 + maxf(sqrt(p0.distance_to(p1)), 0.01)
		var t2: float = t1 + maxf(sqrt(p1.distance_to(p2)), 0.01)
		var t3: float = t2 + maxf(sqrt(p2.distance_to(p3)), 0.01)
		for s in range(steps):
			var t: float = lerpf(t1, t2, float(s) / steps)
			var a1: Vector3 = p0 * ((t1 - t) / (t1 - t0)) + p1 * ((t - t0) / (t1 - t0))
			var a2: Vector3 = p1 * ((t2 - t) / (t2 - t1)) + p2 * ((t - t1) / (t2 - t1))
			var a3: Vector3 = p2 * ((t3 - t) / (t3 - t2)) + p3 * ((t - t2) / (t3 - t2))
			var b1: Vector3 = a1 * ((t2 - t) / (t2 - t0)) + a2 * ((t - t0) / (t2 - t0))
			var b2: Vector3 = a2 * ((t3 - t) / (t3 - t1)) + a3 * ((t - t1) / (t3 - t1))
			out.append(b1 * ((t2 - t) / (t2 - t1)) + b2 * ((t - t1) / (t2 - t1)))
	out.append(pts[n - 1])
	var space: PhysicsDirectSpaceState3D = (sc as Node3D).get_world_3d().direct_space_state if sc is Node3D else tree.root.get_world_3d().direct_space_state
	for i in range(out.size()):
		var q := PhysicsRayQueryParameters3D.create(out[i] + Vector3(0, ray_up, 0), out[i] + Vector3(0, -300, 0))
		var hit: Dictionary = space.intersect_ray(q)
		if not hit.is_empty() and out[i].y < hit.position.y + clear:
			out[i].y = hit.position.y + clear
	for pass_i in range(smooth):
		var sm := out.duplicate()
		for i in range(1, out.size() - 1):
			# The window shrinks toward the ends (end points stay put), so
			# the path has no kink where smoothing would otherwise stop.
			var r: int = mini(4, mini(i, out.size() - 1 - i))
			var acc := Vector3()
			for k in range(-r, r + 1):
				acc += out[i + k]
			sm[i] = acc / float(2 * r + 1)
			sm[i].y = maxf(sm[i].y, out[i].y)
		out = sm
	return out

func _lengths(path: PackedVector3Array) -> PackedFloat32Array:
	var l := PackedFloat32Array([0.0])
	for i in range(1, path.size()):
		l.append(l[i - 1] + path[i].distance_to(path[i - 1]))
	return l

func _at(path: PackedVector3Array, lens: PackedFloat32Array, d: float) -> Vector3:
	if d >= lens[lens.size() - 1]:
		var last: Vector3 = path[path.size() - 1]
		return last + (last - path[path.size() - 2]).normalized() * (d - lens[lens.size() - 1])
	var i: int = lens.bsearch(d)
	i = clampi(i, 1, lens.size() - 1)
	var t: float = (d - lens[i - 1]) / maxf(lens[i] - lens[i - 1], 0.0001)
	return path[i - 1].lerp(path[i], t)
