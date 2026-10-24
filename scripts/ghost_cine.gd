class_name GhostCine
extends Node
## Ghost lap renderer and checker (dev tool, 2026-10-22): turns the pilot's
## recorded race ghosts into clean 1080p60 trailer frames, and checks a
## ghost lap for collisions and jerks.
##   SH_GHOST_FILE=<abs path to race_ghosts.cfg> SH_CINE_OUT=<frames dir> \
##   godot --path . --fixed-fps 60 -- --dev-preview ghostcam --map=race_field
##       --track=harvest_hell --drone=race [--speed=0.6] [--from=0] [--to=0]
##       [--cam=fpv|chase] [--check]
## --check prints one GHOSTCHECK line per ghost (--track=all: every valid
## ghost of the map) and renders nothing. The ghost file is only READ
## (ConfigFile.load); under --dev-preview nothing is saved to the real files.
## Frames: SH_CINE_OUT/00000.jpg ..., then ffmpeg (see cine.gd). SH_CINE_SS
## = supersampling of the 1920x1080 view (default 2).

## Ghosts whose track layout still matches: map -> track id -> drones.
const VALID: Dictionary = {
	"race_field": {
		"meadow_sprint": ["seeker3", "race", "whoop"],
		"bale_run": ["seeker3", "race", "five"],
		"club_loop": ["race"], "shed_run": ["race"],
		"tower_line": ["race"], "harvest_hell": ["race"],
	},
	"race_arena": {
		"warm_up": ["race"], "pit_lane": ["race"],
		"league_night": ["whoop", "seeker3", "race"],
		"spotlight": ["race"], "gallery_run": ["race", "five"], "night_shift": ["race"],
	},
	"office": {
		"after_hours": ["whoop"], "coffee_run": ["whoop"],
		"server_sprint": ["whoop"], "overtime": ["whoop"],
	},
}

var tree: SceneTree
var cfg := ConfigFile.new()

static func arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.get_slice("=", 1)
	return def

func run(p_tree: SceneTree) -> void:
	tree = p_tree
	if OS.get_cmdline_user_args().has("--segments"):
		await _segments(OS.get_environment("SH_TAKES_DIR"))
		return
	if OS.has_environment("SH_TAKE_FILE") and OS.get_cmdline_user_args().has("--audio"):
		_audio(OS.get_environment("SH_TAKE_FILE"), arg("wav", ""))
		return
	if OS.has_environment("SH_TAKE_FILE"):
		await _render("", "", "")
		return
	var path: String = OS.get_environment("SH_GHOST_FILE")
	if path == "" or cfg.load(path) != OK:
		push_error("ghostcam: SH_GHOST_FILE missing or unreadable: " + path)
		return
	if arg("posestats", "") != "":
		_pose_stats(arg("posestats", ""), arg("drone", "race"))
		return
	var map_id: String = arg("map", "race_field")
	var jobs: Array = [] # [track id, drone]
	var want: String = arg("track", "all")
	var valid: Dictionary = VALID.get(map_id, {})
	for tid in valid:
		if want != "all" and want != tid:
			continue
		for d in valid[tid]:
			if arg("drone", "") == "" or arg("drone", "") == d:
				jobs.append([tid, d])
	if want != "all" and jobs.is_empty():
		jobs.append([want, arg("drone", "race")]) # (not in the valid list: still try)
	var check: bool = OS.get_cmdline_user_args().has("--check")
	for j in jobs:
		if check:
			await _check(map_id, j[0], j[1])
		else:
			await _render(map_id, j[0], j[1])
			break

## Loads the map with that track and drone in race mode. Returns the
## ghost {pos, rot, section} or an empty dict.
func _load(map_id: String, track_id: String, drone_id: String) -> Dictionary:
	if OS.has_environment("SH_TAKE_FILE"):
		return await _load_take(OS.get_environment("SH_TAKE_FILE"))
	var m: Dictionary = {}
	for mm in MapCatalog.MAPS:
		if mm.id == map_id:
			m = mm
	if m.is_empty():
		push_error("ghostcam: no map " + map_id)
		return {}
	var idx: int = 0
	var tl: Array = RaceCourse.track_list(map_id)
	for i in range(tl.size()):
		if str(tl[i].get("id", "")) == track_id:
			idx = i + 1
	if idx == 0:
		push_error("ghostcam: no track " + track_id)
		return {}
	var sec: String = RaceCourse.section(map_id, idx)
	var pos: PackedVector3Array = cfg.get_value(sec, drone_id + "_pos", PackedVector3Array())
	var rot: PackedVector4Array = cfg.get_value(sec, drone_id + "_q", PackedVector4Array())
	if pos.size() < 2 or rot.size() != pos.size():
		push_error("ghostcam: no ghost in [%s] for %s" % [sec, drone_id])
		return {}
	Settings.game_mode = Settings.MODE_RACE
	Settings.race_track = idx
	Settings.selected_drone = drone_id
	Settings.graphics_quality = 2
	Settings.camera_angle_deg = float(arg("uptilt", "40")) if drone_id == "race" else Settings.camera_angle_deg
	Settings.race_ghost = false
	Settings.osd_enabled = false
	Settings.keyboard_help = false
	Settings.race_line_hue = int(arg("linehue", "30")) if OS.get_cmdline_user_args().has("--line") else -1
	tree.change_scene_to_file(m.scene)
	for _k in range(30):
		await tree.physics_frame
	await tree.create_timer(2.0).timeout
	return {"pos": pos, "rot": rot, "section": sec}

## SH_TAKE_FILE=<a --record-all take (TakeRecorder)>: its map, track and
## drone, its poses at its own rate.
func _load_take(path: String) -> Dictionary:
	var tk := ConfigFile.new()
	if tk.load(path) != OK:
		push_error("ghostcam: take unreadable: " + path)
		return {}
	var drone_id: String = tk.get_value("take", "drone", "race")
	Settings.game_mode = Settings.MODE_RACE if tk.get_value("take", "race", false) else Settings.MODE_FREESTYLE
	Settings.race_track = int(tk.get_value("take", "track", 1))
	Settings.selected_drone = drone_id
	Settings.graphics_quality = 2
	Settings.camera_angle_deg = float(arg("uptilt", "40")) if drone_id == "race" else Settings.camera_angle_deg
	Settings.race_ghost = false
	Settings.osd_enabled = false
	Settings.keyboard_help = false
	Settings.race_line_hue = int(arg("linehue", "30")) if OS.get_cmdline_user_args().has("--line") else -1
	tree.change_scene_to_file(tk.get_value("take", "scene"))
	for _k in range(30):
		await tree.physics_frame
	await tree.create_timer(2.0).timeout
	return {"pos": tk.get_value("take", "pos"), "rot": tk.get_value("take", "q"), "section": path.get_file(), "hz": float(tk.get_value("take", "hz", 60.0))}

func _drone() -> Drone:
	return Autopilot._find_drone(tree.current_scene)

## The pose at sample f (fractional). Position: Catmull-Rom through the
## samples (a straight lerp kinks at every 30 Hz sample). Rotation: the
## smoothed samples (_smooth_rot), spherical cubic between them.
static func _pose(g: Dictionary, f: float) -> Transform3D:
	var pos: PackedVector3Array = g.pos
	var rot: Array = g.get("rot_s", [])
	var n: int = pos.size()
	var i: int = clampi(int(f), 0, n - 2)
	var t: float = clampf(f - i, 0.0, 1.0)
	var i0: int = maxi(i - 1, 0)
	var i3: int = mini(i + 2, n - 1)
	var p: Vector3 = pos[i].cubic_interpolate(pos[i + 1], pos[i0], pos[i3], t)
	if rot.is_empty():
		var a: Vector4 = g.rot[i]
		var b: Vector4 = g.rot[i + 1]
		return Transform3D(Basis(Quaternion(a.x, a.y, a.z, a.w).slerp(Quaternion(b.x, b.y, b.z, b.w), t)), p)
	var q: Quaternion = (rot[i] as Quaternion).spherical_cubic_interpolate(rot[i + 1], rot[i0], rot[i3], t)
	return Transform3D(Basis(q.normalized()), p)

## Zero-phase Gaussian smoothing of the recorded rotations (sigma in
## samples; --smooth=, default 1.5 = 50 ms at 30 Hz): takes out the
## frame's PID shake that reads as a jerky camera, without the lag a
## one-sided filter would add.
static func _smooth_rot(g: Dictionary, sigma: float) -> void:
	var raw: PackedVector4Array = g.rot
	var qs: Array = []
	for v in raw:
		var q := Quaternion(v.x, v.y, v.z, v.w).normalized()
		# One hemisphere along the whole run (a flip crosses it: checking
		# against the window's middle instead averaged a flip to garbage).
		if not qs.is_empty() and (qs[qs.size() - 1] as Quaternion).dot(q) < 0.0:
			q = -q
		qs.append(q)
	var out: Array = []
	var r: int = ceili(sigma * 3.0)
	for i in range(qs.size()):
		var c: Quaternion = qs[i]
		var acc := Vector4.ZERO
		for k in range(-r, r + 1):
			var j: int = clampi(i + k, 0, qs.size() - 1)
			var q: Quaternion = qs[j]
			var w: float = exp(-0.5 * k * k / maxf(sigma * sigma, 0.0001))
			acc += Vector4(q.x, q.y, q.z, q.w) * w
		acc = acc.normalized()
		out.append(Quaternion(acc.x, acc.y, acc.z, acc.w))
	g["rot_s"] = out

func _check(map_id: String, track_id: String, drone_id: String) -> void:
	var g: Dictionary = await _load(map_id, track_id, drone_id)
	var dr: Drone = _drone()
	if g.is_empty() or dr == null:
		return
	dr.freeze = true
	var space: PhysicsDirectSpaceState3D = dr.get_world_3d().direct_space_state
	var sph := SphereShape3D.new()
	sph.radius = 0.06 if drone_id == "whoop" else 0.12
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.shape = sph
	qp.exclude = [dr.get_rid()]
	qp.collide_with_areas = false
	qp.collide_with_bodies = true
	var hits: int = 0
	var first_hit: float = -1.0
	var min_clear: float = 99.0
	var max_rate: float = 0.0
	var max_jump: float = 0.0
	var pos: PackedVector3Array = g.pos
	var rot: PackedVector4Array = g.rot
	for i in range(pos.size()):
		var tf := Transform3D(Basis.IDENTITY, pos[i])
		qp.transform = tf
		var hit: bool = not space.intersect_shape(qp, 1).is_empty()
		if hit:
			hits += 1
			if first_hit < 0.0:
				first_hit = i / RaceCourse.GHOST_HZ
		else:
			# clearance: how far the sphere can move before it touches
			var cl: Array = space.cast_motion(_motion(qp, Vector3.DOWN * 3.0)) # (down only: cheap, ground-near clearance)
			var c: float = 3.0 * cl[0]
			for dv in [Vector3.UP, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
				c = minf(c, 3.0 * space.cast_motion(_motion(qp, dv * 3.0))[0])
			min_clear = minf(min_clear, c)
		if i > 0:
			max_jump = maxf(max_jump, pos[i].distance_to(pos[i - 1]))
			var a: Vector4 = rot[i - 1]
			var b: Vector4 = rot[i]
			var ang: float = Quaternion(a.x, a.y, a.z, a.w).angle_to(Quaternion(b.x, b.y, b.z, b.w))
			max_rate = maxf(max_rate, rad_to_deg(ang) * RaceCourse.GHOST_HZ)
	print("GHOSTCHECK %s %s hits=%d first_hit_t=%.2f min_clear=%.2f max_rate=%.0f max_jump=%.2f len=%.1fs" % [g.section, drone_id, hits, first_hit, min_clear, max_rate, max_jump, pos.size() / RaceCourse.GHOST_HZ])

func _motion(qp: PhysicsShapeQueryParameters3D, m: Vector3) -> PhysicsShapeQueryParameters3D:
	var p := PhysicsShapeQueryParameters3D.new()
	p.shape = qp.shape
	p.transform = qp.transform
	p.exclude = qp.exclude
	p.collide_with_areas = false
	p.motion = m
	return p

func _render(map_id: String, track_id: String, drone_id: String) -> void:
	var g: Dictionary = await _load(map_id, track_id, drone_id)
	var dr: Drone = _drone()
	if g.is_empty() or dr == null:
		return
	var sc: Node = tree.current_scene
	var src_cam: Camera3D = tree.root.get_viewport().get_camera_3d()
	var ui: Node = sc.get_node_or_null("UI")
	if ui:
		ui.set("visible", false)
	dr.freeze = true
	var hz: float = g.get("hz", RaceCourse.GHOST_HZ)
	# Stabilisation (per clip on the command line, noted in CLIPS-INDEX):
	# --smooth=<rotation sigma, 30 Hz samples> (default 2.5 = 83 ms),
	# --level=<0..1 share of roll taken out> (0.35), --csmooth=<camera
	# path smoothing, frames> (6), --uptilt=<deg> or auto (35..55 so the view sits near
	# the horizon on the clip's typical pitch).
	if float(arg("smooth", "2.5")) > 0.0:
		_smooth_rot(g, float(arg("smooth", "2.5")) * hz / RaceCourse.GHOST_HZ) # (the same time at any rate)
	var level: float = float(arg("level", "0.35"))
	var pos: PackedVector3Array = g.pos
	var lap_len: float = (pos.size() - 1) / hz
	var t0: float = float(arg("from", "0"))
	var t1: float = float(arg("to", "0"))
	if t1 <= 0.0 or t1 > lap_len:
		t1 = lap_len
	var speed: float = float(arg("speed", "1.0"))
	var chase: bool = arg("cam", "fpv") == "chase"
	var ss: float = float(OS.get_environment("SH_CINE_SS")) if OS.has_environment("SH_CINE_SS") else 2.0
	var vp := SubViewport.new()
	vp.size = Vector2i(roundi(1920 * ss), roundi(1080 * ss))
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.msaa_3d = tree.root.msaa_3d
	vp.world_3d = tree.root.world_3d
	sc.add_child(vp)
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.current = true
	tree.root.disable_3d = true
	var dir: String = OS.get_environment("SH_CINE_OUT") if OS.has_environment("SH_CINE_OUT") else ProjectSettings.globalize_path("user://cine")
	DirAccess.make_dir_recursive_absolute(dir)
	var frames: int = int((t1 - t0) / speed * 60.0)
	var chase_pos := Vector3.ZERO
	var chase_look := Vector3.ZERO
	var uptilt: float = deg_to_rad(Settings.camera_angle_deg)
	if arg("uptilt", "") == "auto":
		var pitches: Array = []
		for f in range(0, frames, 6):
			var b: Basis = _pose(g, (t0 + f * speed / 60.0) * hz).basis
			pitches.append(asin(clampf(-b.z.normalized().y, -1.0, 1.0)))
		pitches.sort()
		var med: float = pitches[pitches.size() / 2] if not pitches.is_empty() else 0.0
		# (Fast race laps pitch the body 55-75 deg: 5" race pilots fly
		# 45-60 deg uptilt for that. --tiltmax= caps it.)
		uptilt = clampf(deg_to_rad(-8.0) - med, deg_to_rad(float(arg("tiltmin", "35"))), deg_to_rad(float(arg("tiltmax", "55"))))
	elif arg("uptilt", "") != "":
		uptilt = deg_to_rad(float(arg("uptilt", "40")))
	# The FPV camera for every frame: body x uptilt, roll partly levelled
	# (less so when looking steeply up or down, where "level" has no
	# meaning), then smoothed over the whole clip forward and backward
	# (--csmooth frames, default 6 = 100 ms): no lag, no snaps. Until
	# 2026-10-22 a per-frame turn cap did this and snapped when it let go.
	var cams: Array = []
	var csig: float = float(arg("csmooth", "6"))
	for f in range(frames):
		var b: Basis = _pose(g, (t0 + f * speed / 60.0) * hz).basis
		var cb: Basis = (b * Basis(Vector3.RIGHT, uptilt)).orthonormalized()
		var fwd: Vector3 = -cb.z
		var lv: float = level * clampf((0.9 - absf(fwd.y)) / 0.4, 0.0, 1.0)
		if lv > 0.0:
			var flat_up: Vector3 = (Vector3.UP - fwd * fwd.dot(Vector3.UP)).normalized()
			cb = Basis.looking_at(fwd, cb.y.slerp(flat_up, lv).normalized())
		cams.append(cb.get_rotation_quaternion())
	if csig > 0.0 and not cams.is_empty():
		var sm: Dictionary = {"rot": PackedVector4Array()}
		for q: Quaternion in cams:
			sm.rot.append(Vector4(q.x, q.y, q.z, q.w))
		_smooth_rot(sm, csig)
		cams = sm.rot_s
	var stat_turn: float = 0.0
	var stat_change: float = 0.0
	var prev_turn: float = 0.0
	for f in range(1, cams.size()):
		var turn: float = rad_to_deg((cams[f - 1] as Quaternion).angle_to(cams[f]))
		stat_turn = maxf(stat_turn, turn)
		if f > 1:
			stat_change = maxf(stat_change, absf(turn - prev_turn))
		prev_turn = turn
	if OS.get_cmdline_user_args().has("--statsonly"):
		print("GHOSTCAM stats uptilt=%.0f smooth=%s level=%.2f csmooth=%s max_turn=%.2f deg/frame max_turn_change=%.2f deg/frame%s" % [rad_to_deg(uptilt), arg("smooth", "2.5"), level, arg("csmooth", "6"), stat_turn, stat_change, "  SPIKE" if stat_change > 0.13 else ""])
		return
	# f < 0: the first view settles (shader compiles) before frames are kept.
	# (macOS draws nothing for a window behind another fullscreen one.)
	DisplayServer.window_move_to_foreground()
	for f in range(-30, frames):
		var t: float = t0 + maxf(f, 0) * speed / 60.0
		var tf: Transform3D = _pose(g, t * hz)
		dr.global_transform = tf
		dr.linear_velocity = Vector3.ZERO
		dr.angular_velocity = Vector3.ZERO
		if f == -30 and OS.get_cmdline_user_args().has("--line"):
			_sync_course(g, hz, t0, dr)
		if chase:
			var want: Vector3 = tf.origin + tf.basis.z * 2.5 + Vector3.UP * 0.8
			if f <= -30:
				chase_pos = want
				chase_look = tf.origin
			var k: float = 1.0 - exp(-5.0 / 60.0)
			chase_pos = chase_pos.lerp(want, k)
			chase_look = chase_look.lerp(tf.origin, 1.0 - exp(-12.0 / 60.0))
			cam.global_transform = Transform3D(Basis.looking_at(chase_look - chase_pos, Vector3.UP), chase_pos)
			cam.fov = 80.0
			cam.cull_mask = 0xFFFFF | (1 << 19) | (src_cam.cull_mask if src_cam else 0)
		else:
			var q: Quaternion = cams[maxi(f, 0)]
			cam.global_transform = Transform3D(Basis(q), src_cam.global_position)
			cam.fov = src_cam.fov
			cam.cull_mask = src_cam.cull_mask
		cam.near = src_cam.near
		cam.far = src_cam.far
		cam.keep_aspect = src_cam.keep_aspect
		cam.environment = src_cam.environment
		cam.attributes = src_cam.attributes
		await RenderingServer.frame_post_draw
		if f >= 0:
			vp.get_texture().get_image().save_jpg(dir.path_join("%05d.jpg" % f), 0.92)
	print("GHOSTCAM stats uptilt=%.0f smooth=%s level=%.2f csmooth=%s max_turn=%.2f deg/frame max_turn_change=%.2f deg/frame%s" % [rad_to_deg(uptilt), arg("smooth", "2.5"), level, arg("csmooth", "6"), stat_turn, stat_change, "  SPIKE" if stat_change > 0.13 else ""])
	print("GHOSTCAM done %d frames in %s (lap %.1fs, %.1f..%.1fs, speed %.2f)" % [frames, dir, lap_len, t0, t1, speed])

## --audio --wav=<out.wav> (with SH_TAKE_FILE, --from/--to; headless is
## fine, no map is loaded): the motor sound of a take clip, in sync with
## its video (frame 0 = --from, game time). Takes hold no stick or rpm,
## so the thrust comes from the motion: T = (m (a + g) - body drag) along
## the drone's up axis, rpm = sqrt(T / max thrust) as in Drone. Then the
## game's own motor sound (motor_audio.gd: the same loops, pitch, volume,
## prop wash and rpm low-pass) is mixed offline at 48 kHz.
const AUDIO_RATE: int = 48000
func _audio(path: String, out: String) -> void:
	var tk := ConfigFile.new()
	if tk.load(path) != OK or out == "":
		push_error("ghostcam --audio: take unreadable or no --wav=")
		return
	var pos: PackedVector3Array = tk.get_value("take", "pos")
	var raw: PackedVector4Array = tk.get_value("take", "q")
	var hz: float = float(tk.get_value("take", "hz", 60.0))
	var drone_id: String = tk.get_value("take", "drone", "race")
	var prof: Dictionary = Drone.PROFILES.get(drone_id, Drone.PROFILES["seeker3"])
	var mass: float = prof.mass
	var tmax: float = 4.0 * float(prof.max_motor_thrust_n)
	var cd: float = prof.drag_coefficient
	var n: int = pos.size()
	# Velocity and acceleration, smoothed (50 ms) - a raw second difference
	# of 60 Hz positions is mostly noise.
	var sp := PackedVector3Array()
	sp.resize(n)
	var sig: float = 0.05 * hz
	var rad: int = int(ceil(sig * 3.0))
	for i in range(n):
		var acc := Vector3.ZERO
		var w: float = 0.0
		for k in range(-rad, rad + 1):
			var j: int = clampi(i + k, 0, n - 1)
			var wk: float = exp(-0.5 * k * k / (sig * sig))
			acc += pos[j] * wk
			w += wk
		sp[i] = acc / w
	var t0: float = float(arg("from", "0"))
	var t1: float = float(arg("to", "0"))
	if t1 <= 0.0 or t1 > (n - 1) / hz:
		t1 = (n - 1) / hz
	var MA = load("res://scripts/motor_audio.gd")
	var s: Dictionary = MA.SOUNDS.get(drone_id, MA.SOUNDS["seeker3"])
	var loops: Dictionary = MA._build_loop(s)
	var tone: PackedFloat32Array = _wav_floats(loops.tone)
	var noise: PackedFloat32Array = _wav_floats(loops.noise)
	# Control values per 1/60 s, as MotorAudio._process would set them,
	# from 1 s before the clip (the spool-up state carries in).
	var dt: float = 1.0 / 60.0
	var pitch: float = 1.0
	var prev_rpm: float = MA.IDLE_RPM_FRACTION
	var wash_env: float = 0.0
	var ctl: Array = [] # [pitch, tone gain, wash pitch, wash gain, cutoff hz]
	var tt: float = maxf(t0 - 1.0, 1.0 / hz)
	var first: int = -1
	while tt <= t1 + dt:
		if first < 0 and tt >= t0 - 0.0001:
			first = ctl.size()
		var fi: float = clampf(tt * hz, 1.0, n - 2.0)
		var i: int = int(fi)
		var v: Vector3 = (sp[i + 1] - sp[i - 1]) * hz * 0.5
		var a: Vector3 = (sp[i + 1] - 2.0 * sp[i] + sp[i - 1]) * hz * hz
		var q := Quaternion(raw[i].x, raw[i].y, raw[i].z, raw[i].w).normalized()
		var up: Vector3 = Basis(q).y
		var drag: Vector3 = -v * v.length() * cd
		var thrust: float = maxf((mass * (a + Vector3(0, 9.8, 0)) - drag).dot(up), 0.0)
		var rpm: float = maxf(sqrt(clampf(thrust / tmax, 0.0, 1.0)), MA.IDLE_RPM_FRACTION)
		pitch = lerpf(pitch, rpm / MA.REF_RPM_FRACTION, 1.0 - exp(-dt * 25.0))
		var k: float = clampf((rpm - MA.IDLE_RPM_FRACTION) / (1.0 - MA.IDLE_RPM_FRACTION), 0.0, 1.0)
		wash_env = lerpf(wash_env, absf((rpm - prev_rpm) / dt), 1.0 - exp(-dt * 6.0))
		prev_rpm = rpm
		ctl.append([clampf(pitch, 0.2, 3.0), db_to_linear(lerpf(s.db_min, s.db_max, k)),
			clampf(0.85 + 0.3 * pitch, 0.5, 2.0), db_to_linear(lerpf(s.wash_db_min, s.wash_db_max, k) + clampf(wash_env * 3.0, 0.0, 3.0)),
			lerpf(s.lp_idle_hz, s.lp_full_hz, k)])
		tt += dt
	# Mix: loops read at their 22050 Hz rate times pitch, a two-pole
	# low-pass at the rpm cutoff (the MotorLPF bus).
	var total: int = int((t1 - t0) * AUDIO_RATE)
	var outb := PackedByteArray()
	outb.resize(total * 2)
	var step: float = float(MA.MIX_RATE) / AUDIO_RATE
	var ph_t: float = 0.0
	var ph_n: float = 0.0
	var l1: float = 0.0
	var l2: float = 0.0
	var tn: int = tone.size()
	var nn: int = noise.size()
	var peak: float = 0.0
	# (Run the filter state over the lead-in second too.)
	var start_s: int = -int((first) * dt * AUDIO_RATE)
	for si in range(start_s, total):
		var cf: float = clampf(float(first) + si / (dt * AUDIO_RATE), 0.0, ctl.size() - 1.001)
		var c0: Array = ctl[int(cf)]
		var c1: Array = ctl[int(cf) + 1]
		var f: float = cf - int(cf)
		ph_t = fmod(ph_t + step * lerpf(c0[0], c1[0], f), tn)
		ph_n = fmod(ph_n + step * lerpf(c0[2], c1[2], f), nn)
		var it: int = int(ph_t)
		var tv: float = lerpf(tone[it], tone[(it + 1) % tn], ph_t - it)
		var inn: int = int(ph_n)
		var nv: float = lerpf(noise[inn], noise[(inn + 1) % nn], ph_n - inn)
		var x: float = tv * lerpf(c0[1], c1[1], f) + nv * lerpf(c0[3], c1[3], f)
		var al: float = 1.0 - exp(-TAU * lerpf(c0[4], c1[4], f) / AUDIO_RATE)
		l1 += al * (x - l1)
		l2 += al * (l1 - l2)
		if si >= 0:
			peak = maxf(peak, absf(l2))
			outb.encode_s16(si * 2, int(clampf(l2, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.data = outb
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = AUDIO_RATE
	wav.stereo = false
	wav.save_to_wav(out)
	print("GHOSTCAM audio %s %.2f s, %s, peak %.2f" % [out.get_file(), total / float(AUDIO_RATE), drone_id, peak])

static func _wav_floats(w: AudioStreamWAV) -> PackedFloat32Array:
	var d: PackedByteArray = w.data
	var f := PackedFloat32Array()
	f.resize(d.size() / 2)
	for i in range(f.size()):
		f[i] = d.decode_s16(i * 2) / 32768.0
	return f

## --line: the racing line on. The race course follows the replayed
## drone, but a clip starting mid-lap would start it at the START gate:
## run the course's own gate logic over the poses up to the clip's start
## first, so the line (and marker) point at the right next gates.
## Use it in a test copy only - a lap completed this way is saved.
func _sync_course(g: Dictionary, hz: float, t0: float, dr: Drone) -> void:
	var rc: RaceCourse = Autopilot._find_course(tree.current_scene)
	if rc == null or rc._gates.is_empty():
		return
	var pos: PackedVector3Array = g.pos
	var keep: Transform3D = dr.global_transform
	rc._reset_run()
	rc._prev_pos = pos[0]
	for i in range(1, mini(int(t0 * hz) + 1, pos.size())):
		dr.global_position = pos[i]
		rc._physics_process(1.0 / hz)
	dr.global_transform = keep
	rc._prev_pos = keep.origin
	print("GHOSTCAM line: next gate %d at %.1f s (lap %d)" % [rc._next, t0, rc._lap])

## --posestats=<map#track[@rev]>: how the camera would turn frame by frame
## at 60 fps (--from/--to, --smooth) - the largest turn per frame and the
## largest change of that turn (the jerk a viewer sees), no map loaded.
func _pose_stats(sec: String, drone_id: String) -> void:
	var g: Dictionary = {"pos": cfg.get_value(sec, drone_id + "_pos"), "rot": cfg.get_value(sec, drone_id + "_q")}
	var sm: float = float(arg("smooth", "1.5"))
	if sm > 0.0:
		_smooth_rot(g, sm)
	var t0: float = float(arg("from", "0"))
	var t1: float = float(arg("to", "5"))
	var prev: Transform3D = _pose(g, t0 * RaceCourse.GHOST_HZ)
	var prev_ang: float = 0.0
	var max_ang: float = 0.0
	var max_jerk: float = 0.0
	var max_dv: float = 0.0
	var prev_step := Vector3.ZERO
	var n: int = int((t1 - t0) * 60.0)
	for f in range(1, n):
		var tf: Transform3D = _pose(g, (t0 + f / 60.0) * RaceCourse.GHOST_HZ)
		var ang: float = rad_to_deg(prev.basis.get_rotation_quaternion().angle_to(tf.basis.get_rotation_quaternion()))
		var step: Vector3 = tf.origin - prev.origin
		if f > 1:
			max_jerk = maxf(max_jerk, absf(ang - prev_ang))
			max_dv = maxf(max_dv, (step - prev_step).length() * 60.0)
		max_ang = maxf(max_ang, ang)
		prev_ang = ang
		prev_step = step
		prev = tf
	print("POSESTATS %s %s smooth=%.1f max_turn=%.2f deg/frame max_turn_change=%.2f deg/frame max_speed_change=%.2f m/s per frame" % [sec, drone_id, sm, max_ang, max_jerk, max_dv])

## --segments (SH_TAKES_DIR = a folder of --record-all takes, headless is
## fine): cuts every take into clean stretches of at least SEG_MIN s - no
## contact, no reset jump, nothing within 0.5 s before / 1.5 s after a
## contact (the crash and the wobble after it), not hovering, no wild
## spin - and scores them for a trailer. One SEG line per stretch.
const SEG_MIN: float = 4.0
func _segments(dir: String) -> void:
	var files: Array = Array(DirAccess.get_files_at(dir)).filter(func(f: String) -> bool: return f.ends_with(".cfg"))
	files.sort()
	var groups: Dictionary = {} # one map load per scene + track + mode
	for f: String in files:
		var tk := ConfigFile.new()
		if tk.load(dir.path_join(f)) != OK:
			continue
		var key: String = "%s|%d|%s" % [tk.get_value("take", "scene"), int(tk.get_value("take", "track", 1)), str(tk.get_value("take", "race", false))]
		if not groups.has(key):
			groups[key] = []
		groups[key].append(f)
	for key: String in groups:
		var parts: PackedStringArray = key.split("|")
		Settings.game_mode = Settings.MODE_RACE if parts[2] == "true" else Settings.MODE_FREESTYLE
		Settings.race_track = int(parts[1])
		tree.change_scene_to_file(parts[0])
		for _k in range(30):
			await tree.physics_frame
		await tree.create_timer(2.0).timeout
		var dr: Drone = _drone()
		if dr == null:
			push_error("segments: no drone in " + parts[0])
			continue
		dr.freeze = true
		dr.global_position += Vector3(0, 5000, 0) # (out of the way of the queries)
		await tree.physics_frame
		var rc: RaceCourse = Autopilot._find_course(tree.current_scene)
		for f: String in groups[key]:
			_segment_take(dir.path_join(f), dr, rc)
	tree.quit()

func _segment_take(path: String, dr: Drone, rc: RaceCourse) -> void:
	var tk := ConfigFile.new()
	tk.load(path)
	var pos: PackedVector3Array = tk.get_value("take", "pos")
	var raw: PackedVector4Array = tk.get_value("take", "q")
	var hz: float = float(tk.get_value("take", "hz", 60.0))
	var drone_id: String = tk.get_value("take", "drone", "race")
	var uptilt: float = deg_to_rad(40.0 if drone_id == "race" else 25.0)
	var space: PhysicsDirectSpaceState3D = dr.get_world_3d().direct_space_state
	var sh := SphereShape3D.new()
	var qp := PhysicsShapeQueryParameters3D.new()
	qp.shape = sh
	qp.exclude = [dr.get_rid()]
	qp.collide_with_areas = false
	var n: int = pos.size()
	var hit := PackedByteArray()
	hit.resize(n)
	var bad := PackedByteArray()
	bad.resize(n)
	var near := PackedByteArray()
	near.resize(n)
	var gate := PackedByteArray()
	gate.resize(n)
	var view := PackedByteArray()
	view.resize(n)
	var hits: int = 0
	for i in range(n):
		var p: Vector3 = pos[i]
		sh.radius = 0.06 if drone_id == "whoop" else 0.12
		qp.transform = Transform3D(Basis(), p)
		var contact: bool = not space.intersect_shape(qp, 1).is_empty()
		var jump: bool = i > 0 and p.distance_to(pos[i - 1]) * hz > 60.0
		if contact or jump:
			hit[i] = 1
			hits += 1
		var q := Quaternion(raw[i].x, raw[i].y, raw[i].z, raw[i].w).normalized()
		var spd: float = p.distance_to(pos[i - 1]) * hz if i > 0 else 0.0
		var rate: float = 0.0
		if i > 0:
			var q0 := Quaternion(raw[i - 1].x, raw[i - 1].y, raw[i - 1].z, raw[i - 1].w).normalized()
			rate = rad_to_deg(q0.angle_to(q)) * hz
		if spd < 3.0 or rate > 1500.0:
			bad[i] = 1
		var fwd: Vector3 = Basis(q) * (Basis(Vector3.RIGHT, uptilt) * Vector3.FORWARD)
		view[i] = 1 if fwd.y > -0.5 else 0 # (looking less than 30 deg down)
		if i % 3 == 0 and not contact:
			sh.radius = 0.6
			if not space.intersect_shape(qp, 1).is_empty():
				var rq := PhysicsRayQueryParameters3D.create(p, p + Vector3.DOWN * 0.7, 0xFFFFFFFF, [dr.get_rid()])
				if space.intersect_ray(rq).is_empty(): # (skimming the ground isn't a near miss)
					near[i] = 1
		if rc and i > 0:
			for gi in range(rc._gates.size()):
				var g: Dictionary = rc._gates[gi]
				if rc._crossed(g, pos[i - 1], p):
					gate[i] = 1
				elif not g.has("flag"):
					# Past a gate's plane close beside its opening: a miss.
					var h: Variant = rc._plane_hit(g.xf, pos[i - 1], p)
					if h != null and absf(h.y) <= g.h * 0.5 + 2.0 and absf(h.x) > g.w * 0.5 and absf(h.x) <= g.w * 0.5 + 4.0:
						print("MISS %s t=%.1f gate=%d beside=%.1fm" % [path.get_file(), i / hz, gi, absf(h.x) - g.w * 0.5])
	# Around every contact: 0.5 s before, 1.5 s after.
	for i in range(n):
		if hit[i]:
			for k in range(maxi(0, i - int(0.5 * hz)), mini(n, i + int(1.5 * hz))):
				bad[k] = 1
	print("TAKE %s len=%.1fs contacts=%d drone=%s" % [path.get_file(), n / hz, hits, drone_id])
	var i0: int = -1
	for i in range(n + 1):
		var ok: bool = i < n and not bad[i]
		if ok and i0 < 0:
			i0 = i
		elif not ok and i0 >= 0:
			if (i - i0) / hz >= SEG_MIN:
				_segment_line(path.get_file(), pos, near, gate, view, i0, i, hz)
			i0 = -1

func _segment_line(file: String, pos: PackedVector3Array, near: PackedByteArray, gate: PackedByteArray, view: PackedByteArray, a: int, b: int, hz: float) -> void:
	var dist: float = 0.0
	var vmax: float = 0.0
	var ymin: float = INF
	var ymax: float = -INF
	var dive: float = 0.0
	var nears: int = 0
	var gates: int = 0
	var views: int = 0
	for i in range(a, b):
		if i > a:
			var d: float = pos[i].distance_to(pos[i - 1])
			dist += d
			vmax = maxf(vmax, d * hz)
			dive = maxf(dive, (pos[i - 1].y - pos[i].y) * hz)
		ymin = minf(ymin, pos[i].y)
		ymax = maxf(ymax, pos[i].y)
		if near[i] and (i < 3 or not near[i - 3]):
			nears += 1
		gates += gate[i]
		views += view[i]
	var dur: float = (b - a) / hz
	var spd: float = dist / dur
	var vf: float = float(views) / (b - a)
	var score: float = spd / 10.0 + nears * 1.5 + (ymax - ymin) / 5.0 + dive / 10.0 + gates * 0.5 / dur * 5.0 + vf * 3.0
	print("SEG %s %.1f-%.1f dur=%.1f spd=%.1f vmax=%.1f near=%d dh=%.1f dive=%.1f gates=%d view=%.2f score=%.1f" % [file, a / hz, b / hz, dur, spd, vmax, nears, ymax - ymin, dive, gates, vf, score])

