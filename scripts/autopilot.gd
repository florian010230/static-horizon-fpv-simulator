class_name Autopilot
extends Node
## Trailer autopilot (dev tool, 2026-10-21): flies a race track like a
## human pilot, so a new version can be filmed without flying it by hand.
##   godot --path . --fixed-fps 60 --write-movie <new dir>/lap.avi -- --dev-preview autopilot
##       [--map=race_field] [--track=1] [--laps=1] [--seed=1] [--skill=0.8] [--tilt=50] [--uptilt=35] [--drone=race] [--line] [--osd]
## tools/autopilot_record.sh makes the new folder and runs that. Only
## under --dev-preview (so records, ghosts and settings go to the test
## files, never the pilot's) - nothing of it is reachable from the menu.
##
## No physics cheats: it only sets the four sticks through InputManager
## (test_override - the values a calibrated radio would give), in Acro,
## with the pilot's own rates and throttle curve; the drone flies itself.
## How it flies: it follows the game's racing line (RaceCourse.line_path
## + clear_path, pushed clear of obstacles) with a carrot ahead of it,
## turns that into a wanted acceleration, then into a wanted attitude
## (thrust up the acceleration, nose along the flight path) and body
## rates, and inverts the rate curve to get the sticks.
## What makes it look human (all scaled by skill 0..1, varied by seed):
## - reaction delay 150..100 ms: it steers by where the drone was that
##   long ago (with partial prediction, as pilots do);
## - sticks low-pass filtered and rate limited (thumbs have mass);
## - a line error that wanders a little, different every lap, never
##   dead centre through a gate;
## - throttle with a little jitter; now and then a small correction blip.
## It never crashes on purpose. If it gets stuck (a clip), it waits, then
## resets the drone like a pilot pressing R.

const DT_HIST: int = 40 # state history frames (at 120 Hz, a third of a second)

var tree: SceneTree
var rc: RaceCourse
var drone: Drone
var skill: float = 0.8
## Most tilt from level, degrees (--tilt=): 50 keeps the view on the
## horizon but turns and brakes gently; 70 is a racer's (faster, banks
## hard - on small tracks the view fills with ground in every turn).
var max_tilt_deg: float = 50.0
var seed_value: int = 1
var laps: int = 1
var pts := PackedVector3Array()
var arc := PackedFloat32Array()
var total: float = 0.0
var rng := RandomNumberGenerator.new()

var _i: int = 0 # nearest line point
var _hist: Array = [] # [pos, vel] per physics frame, newest last
var _stick := Vector4.ZERO # roll, pitch, yaw, throttle as sent
var _raw_q: Array = [] # inner stick delay (a few frames)
var _spd_i: float = 0.0
var _blip := Vector2.ZERO
var _blip_t: float = 0.0
var _jit: float = 0.0
var _stuck: float = 0.0
var _phase := PackedFloat32Array()
var _last_seen: float = -1.0
var _t: float = 0.0
var _gate_s := PackedFloat32Array() # distance along the lap of each gate
var done: bool = false
var lap_times: Array = []
var resets: int = 0

## Command line: "--key=value" after --dev-preview autopilot.
static func arg(key: String, def: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--" + key + "="):
			return a.get_slice("=", 1)
	return def

## The dev-preview entry: load the map in race mode, fly, quit.
func run(p_tree: SceneTree) -> void:
	tree = p_tree
	var map_id: String = arg("map", "race_field")
	var m: Dictionary = {}
	for mm in MapCatalog.MAPS:
		if mm.id == map_id:
			m = mm
	if m.is_empty():
		push_error("autopilot: no map " + map_id)
		tree.quit(1)
		return
	Settings.game_mode = Settings.MODE_RACE
	Settings.race_track = int(arg("track", "1"))
	var forced: String = m.get("drone", "any")
	Settings.selected_drone = forced if forced != "any" else arg("drone", "race")
	Settings.graphics_quality = int(arg("quality", "2"))
	Settings.camera_angle_deg = float(arg("uptilt", "35")) # a 5" racer's uptilt (default 25 is freestyle)
	Settings.race_ghost = false # (the test runs' ghost would fly along)
	Settings.osd_enabled = OS.get_cmdline_user_args().has("--osd") # (no THR/ALT/SPD in footage; --osd keeps it)
	Settings.keyboard_help = false # (no keyboard guide in the footage; not saved under --dev-preview)
	if not OS.get_cmdline_user_args().has("--line"):
		Settings.race_line_hue = -1 # clean footage: no racing-line tube
	tree.change_scene_to_file(m.scene)
	for _k in range(30):
		await tree.physics_frame
	max_tilt_deg = float(arg("tilt", "50"))
	if OS.has_environment("SH_AP_SHOTS"):
		_timed_shots(map_id, OS.get_environment("SH_AP_SHOTS").split(","))
	var ok: bool = await fly(tree, int(arg("laps", "1")), float(arg("skill", "0.8")), int(arg("seed", "1")))
	print("AUTOPILOT %s: laps %s, resets %d" % ["done" if ok else "FAILED", str(lap_times), resets])
	for _k in range(90): # a moment on the results / after the line
		await tree.process_frame
	tree.quit(0 if ok else 1)

## SH_AP_SHOTS="4,9,14": screenshots that many seconds into the flight
## (previews/, or SH_SHOT_DIR) - in-flight race shots with the real HUD.
func _timed_shots(map_id: String, at: PackedStringArray) -> void:
	var t0: int = Time.get_ticks_msec()
	for s in at:
		while (Time.get_ticks_msec() - t0) / 1000.0 < float(s):
			await tree.process_frame
		var ui: Node = tree.current_scene.find_child("UI", true, false)
		if ui and ui.get("_hud_label") and ui._hud_label.visible:
			ui._hud_label.visible = false # (no ARMED/FPS status line on website shots)
			await tree.process_frame
			await tree.process_frame
		tree.root.get_node("DevPreviewCapture")._shot("race_%s_t%s_%ss.png" % [map_id, arg("track", "1"), s])

## Flies `n` laps on the current scene's race course. True when they
## were all completed (also the self-test's lap check).
func fly(p_tree: SceneTree, n: int, p_skill: float, p_seed: int) -> bool:
	tree = p_tree
	laps = n
	skill = clampf(p_skill, 0.0, 1.0)
	seed_value = p_seed
	rng.seed = p_seed
	rc = _find_course(tree.current_scene)
	drone = _find_drone(tree.current_scene)
	if rc == null or drone == null or rc._gates.is_empty():
		push_error("autopilot: no race course / drone in this scene")
		return false
	var lp: Dictionary = RaceCourse.line_path(rc._gates)
	if not OS.has_environment("SH_AP_NOHOP"):
		_hops(lp)
	if arg("miss", "") != "":
		_miss(lp, int(arg("miss", "")))
	pts = RaceCourse.clear_path(lp.pts, lp.seg, drone.get_world_3d().direct_space_state, [drone.get_rid()], 0.15 if rc._gates.any(func(g: Dictionary) -> bool: return g.w < 1.0) else RaceCourse.LINE_CLEAR)
	arc.resize(pts.size())
	arc[0] = 0.0
	for k in range(1, pts.size()):
		arc[k] = arc[k - 1] + pts[k].distance_to(pts[k - 1])
	total = arc[arc.size() - 1]
	_gate_s.clear()
	var sg: PackedInt32Array = lp.seg
	for g in range(rc._gates.size()):
		_gate_s.append(arc[mini(sg[g], arc.size() - 1)])
	if OS.has_environment("SH_AP_LOG"):
		var ys: Array = []
		for k in range(0, pts.size(), 8):
			ys.append(snappedf(pts[k].y, 0.1))
		print("AP line y every 8 pts: ", ys)
	_new_lap_line()
	process_physics_priority = -100 # before the drone reads the sticks
	tree.current_scene.add_child(self)
	drone.was_reset.connect(func() -> void:
		_i = 0
		_hist.clear())
	InputManager.self_level = false
	InputManager.test_override = {"roll": 0.0, "pitch": 0.0, "yaw": 0.0, "throttle": 0.0}
	InputManager.armed = true
	var limit: float = 20.0 + total / 5.0 * n # generous: a stuck run ends
	while not done and _t < limit:
		await tree.physics_frame
	InputManager.test_override = null
	InputManager.armed = false
	return done

static func _find_course(n: Node) -> RaceCourse:
	if n is RaceCourse:
		return n
	for c in n.get_children():
		var r: RaceCourse = _find_course(c)
		if r:
			return r
	return null

static func _find_drone(n: Node) -> Drone:
	if n is Drone:
		return n
	for c in n.get_children():
		var r: Drone = _find_drone(c)
		if r:
			return r
	return null

## Pilots don't skim the grass between gates: on each stretch longer
## than 34 m the line rises in a smooth hump (1..3.5 m, by the seed),
## back down to the gate heights at both ends. Done before clear_path, so
## a hump into a roof or a branch is pushed clear like the rest.
func _hops(lp: Dictionary) -> void:
	var p3: PackedVector3Array = lp.pts
	var seg: PackedInt32Array = lp.seg
	for g in range(seg.size() - 1):
		var a: int = seg[g]
		var b: int = seg[g + 1]
		var length: float = 0.0
		for k in range(a + 1, b + 1):
			length += p3[k].distance_to(p3[k - 1])
		if length < 34.0:
			continue
		var h: float = rng.randf_range(1.0, 3.5) * clampf((length - 34.0) / 25.0, 0.4, 1.0)
		var run: float = 0.0
		for k in range(a + 1, b):
			run += p3[k].distance_to(p3[k - 1])
			# Level for the last 9 m into a gate and the first 9 m out
			# (lined up at gate height), ramping over the next 8 m.
			var w: float = smoothstep(9.0, 17.0, run) * smoothstep(9.0, 17.0, length - run)
			p3[k].y += h * w
	lp.pts = p3

## --miss=<gate> (1-based, trailer shot): the line swings 2.8 m to the
## side of that gate and back, a clear miss past the frame and its feet,
## so the game's missed-gate message shows. Every lap - a filming run
## ends after it anyway.
func _miss(lp: Dictionary, gate: int) -> void:
	var p3: PackedVector3Array = lp.pts
	var seg: PackedInt32Array = lp.seg
	if gate < 1 or gate >= seg.size():
		return
	var c: int = seg[gate]
	var g: Dictionary = rc._gates[gate]
	var side: Vector3 = (g.xf.basis.x as Vector3)
	side.y = 0.0
	side = side.normalized()
	var d := PackedFloat32Array()
	d.resize(p3.size())
	for k in range(p3.size()):
		d[k] = 0.0
	for k in range(c + 1, p3.size()):
		d[k] = d[k - 1] + p3[k].distance_to(p3[k - 1])
	for k in range(c - 1, -1, -1):
		d[k] = d[k + 1] + p3[k].distance_to(p3[k + 1])
	for k in range(p3.size()):
		# Full offset within 3 m of the gate, eased out over 14 m.
		p3[k] += side * 2.8 * (1.0 - smoothstep(3.0, 17.0, d[k]))
	lp.pts = p3

## A fresh wander for the line error each lap (a pilot never flies the
## same line twice).
func _new_lap_line() -> void:
	_phase.resize(6)
	for k in range(6):
		_phase[k] = rng.randf() * TAU

## The line error at distance s along the lap: sideways/up, metres. Kept
## inside the gate openings (it shrinks near each gate, never to zero).
func _wander(s: float, tan: Vector3) -> Vector3:
	var amp: float = lerpf(0.45, 0.12, skill)
	var side: Vector3 = tan.cross(Vector3.UP).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	var up: Vector3 = side.cross(tan).normalized()
	var a: float = sin(s * 0.11 + _phase[0]) * 0.6 + sin(s * 0.047 + _phase[1]) * 0.4
	var b: float = sin(s * 0.09 + _phase[2]) * 0.6 + sin(s * 0.031 + _phase[3]) * 0.4
	# Near a gate opening the error stays within its middle (the frame
	# is 1.52 m; the drone needs room).
	var near: float = INF
	for g: Dictionary in rc._gates:
		near = minf(near, (g.xf.origin as Vector3).distance_to(_at(s)))
	var gate_k: float = clampf(near / 6.0, 0.0, 1.0)
	var lim: float = lerpf(minf(amp, 0.22 if rc._gates[0].w >= 1.0 else 0.08), amp, gate_k)
	return side * a * lim + up * b * lim * 0.6

func _at(s: float) -> Vector3:
	s = fposmod(s, total)
	var lo: int = 0
	var hi: int = arc.size() - 1
	while hi - lo > 1:
		var mid: int = (lo + hi) / 2
		if arc[mid] <= s:
			lo = mid
		else:
			hi = mid
	var t: float = (s - arc[lo]) / maxf(arc[hi] - arc[lo], 0.001)
	return pts[lo].lerp(pts[hi], t)

func _tangent(s: float) -> Vector3:
	return (_at(s + 1.0) - _at(s - 1.0)).normalized()

## Nearest line point, searched a little behind and ahead of the last
## one (the line crosses itself on some tracks).
func _track(p: Vector3) -> void:
	var best: float = INF
	var bi: int = _i
	var n: int = pts.size()
	for d in range(-10, 60):
		var k: int = posmod(_i + d, n)
		var e: float = pts[k].distance_squared_to(p)
		if e < best:
			best = e
			bi = k
	if bi < _i - n / 2: # wrapped past START
		pass
	_i = bi

func _physics_process(dt: float) -> void:
	if drone == null or done:
		return
	_t += dt
	var p: Vector3 = drone.global_position
	var v: Vector3 = drone.linear_velocity
	_hist.append([p, v])
	if _hist.size() > DT_HIST:
		_hist.pop_front()
	# Laps: the race course's own count.
	# (Counted by its last-lap time: a finished race clears its lap list.)
	if rc._last_lap > 0.0 and rc._last_lap != _last_seen:
		_last_seen = rc._last_lap
		lap_times.append(snappedf(rc._last_lap, 0.01))
		_new_lap_line()
		if lap_times.size() >= laps:
			done = true
			return
	# Perception: where the drone was a reaction time ago, carried
	# forward by part of that time (prediction).
	var delay: float = lerpf(0.15, 0.10, skill)
	var k_back: int = clampi(int(round(delay / dt)), 0, _hist.size() - 1)
	var seen: Array = _hist[_hist.size() - 1 - k_back]
	var pp: Vector3 = seen[0] + seen[1] * delay # (a pilot leads by what the quad does in that time)
	var vv: Vector3 = seen[1]
	_track(pp)
	var s: float = arc[_i]
	var speed: float = vv.length()
	# Speed plan: as fast as the skill allows, slower before a turn
	# (looks along the line, braking distance included).
	var vmax: float = lerpf(12.0, 36.0, skill) if not OS.has_environment("SH_AP_VMAX") else float(OS.get_environment("SH_AP_VMAX")) # (36 m/s = 130 km/h on a straight)
	var g_tan: float = 9.81 * tan(deg_to_rad(max_tilt_deg)) # what that tilt can push sideways
	var a_lat: float = g_tan * lerpf(0.4, 0.7, skill)
	var a_brake: float = g_tan * lerpf(0.4, 0.62, skill)
	var v_plan: float = vmax
	var t0: Vector3 = _tangent(s)
	for d in [4.0, 8.0, 12.0, 18.0, 26.0, 36.0, 50.0, 66.0]:
		var ta: Vector3 = _tangent(s + d - 2.0)
		var tb: Vector3 = _tangent(s + d + 2.0)
		var ang: float = ta.angle_to(tb)
		var vc: float = vmax if ang < 0.01 else sqrt(a_lat * 4.0 / ang)
		v_plan = minf(v_plan, sqrt(vc * vc + 2.0 * a_brake * maxf(d - 4.0, 0.0)))
	# Into a gate at a speed that leaves room to be precise (a pilot
	# lines it up, then lets go again).
	var v_gate: float = lerpf(9.0, 17.0, skill)
	for gs in _gate_s:
		var dg: float = fposmod(gs - s, total)
		if dg < 40.0:
			v_plan = minf(v_plan, sqrt(v_gate * v_gate + 2.0 * a_brake * maxf(dg - 3.0, 0.0)))
	if _t < 1.5:
		v_plan = minf(v_plan, 3.0 + _t * 4.0) # lift off first
	# Carrot a little ahead on the line, with the wandering error, plus a
	# pull back onto the line where it drifted off (cross-track) - a
	# carrot alone cuts corners into whatever stands inside them.
	var look: float = 1.5 + speed * lerpf(0.34, 0.26, skill)
	var c: Vector3 = _at(s + look) + _wander(s + look, _tangent(s + look))
	var here: Vector3 = _at(s) + _wander(s, t0)
	var lat: Vector3 = here - pp
	lat -= t0 * lat.dot(t0)
	var vd: Vector3 = (c - pp).normalized() * v_plan + lat * lerpf(0.8, 1.3, skill)
	vd.y = clampf(vd.y, -5.0, 5.0) # climb and sink like a pilot, not a rocket
	var acc: Vector3 = (vd - vv) * lerpf(1.8, 2.4, skill)
	# Integral: the props lose thrust with airspeed and drag grows - a
	# pilot just pushes harder until the speed comes.
	# Only along the way it flies (sideways or up it would overshoot).
	var dir: Vector3 = vd.normalized()
	_spd_i = clampf(_spd_i + (vd.length() - vv.dot(dir)) * dt * 0.9, -3.0, 9.0)
	acc += dir * _spd_i
	var a_max: float = g_tan
	# Height first: the horizontal push is limited on its own, so a climb
	# is never scaled away by it.
	var ah := Vector2(acc.x, acc.z).limit_length(a_max)
	acc = Vector3(ah.x, clampf(acc.y, -9.0, 14.0), ah.y)
	var f: Vector3 = acc + Vector3(0, 9.81, 0)
	f.y = maxf(f.y, 2.0) # never ask for upside down
	var up_d: Vector3 = f.normalized()
	# Tilt at most max_tilt_deg from level.
	var max_tilt: float = deg_to_rad(max_tilt_deg)
	if up_d.angle_to(Vector3.UP) > max_tilt:
		var hz := Vector3(up_d.x, 0, up_d.z).normalized()
		up_d = (Vector3.UP * cos(max_tilt) + hz * sin(max_tilt)).normalized()
	# Nose along where it flies (or where the line goes, when slow).
	var head: Vector3 = vd if vd.length() > 1.0 else t0
	head = (head - up_d * head.dot(up_d))
	if head.length() < 0.01:
		head = -drone.global_transform.basis.z
	var want := Basis.looking_at(head.normalized(), up_d)
	var b: Basis = drone.global_transform.basis.orthonormalized()
	# Attitude error in body axes -> body rates.
	var err: Quaternion = (b.inverse() * want).get_rotation_quaternion()
	if err.w < 0.0:
		err = -err
	var ang_e: float = 2.0 * acos(clampf(err.w, -1.0, 1.0))
	var axis := Vector3(err.x, err.y, err.z)
	var w_body: Vector3 = Vector3.ZERO if axis.length() < 1e-5 else axis.normalized() * ang_e * lerpf(7.0, 10.0, skill)
	w_body.y *= 0.6 # yaw follows, roll and pitch lead
	var roll: float = _inv_rate(0, -w_body.z)
	var pitch: float = _inv_rate(1, -w_body.x)
	var yaw: float = _inv_rate(2, -w_body.y)
	# Throttle: the thrust wanted along the drone's own up axis.
	var along: float = maxf(b.y.dot(up_d), 0.3)
	var frac: float = drone.mass * f.length() / along / (4.0 * drone.max_motor_thrust_n)
	var thr_in: float = pow(clampf(frac, 0.0, 1.0), 1.0 / maxf(drone.throttle_curve, 0.01))
	var thr: float = _inv_throttle(thr_in)
	# Human: a small jitter on the throttle, now and then a blip.
	_jit = lerpf(_jit, rng.randf_range(-1.0, 1.0), 0.05)
	thr = clampf(thr + _jit * lerpf(0.025, 0.01, skill), 0.0, 1.0)
	_blip_t -= dt
	if _blip_t <= 0.0:
		_blip = Vector2.ZERO
		if rng.randf() < dt * lerpf(0.6, 0.15, skill):
			_blip = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * lerpf(0.12, 0.05, skill)
			_blip_t = rng.randf_range(0.08, 0.15)
	roll += _blip.x
	pitch += _blip.y
	# Thumbs: a couple of frames of nerve delay, low-pass, rate limit.
	_raw_q.append(Vector4(roll, pitch, yaw, thr))
	var raw: Vector4 = _raw_q.pop_front() if _raw_q.size() > 3 else _raw_q[0]
	var tau: float = lerpf(0.05, 0.025, skill)
	var lp: Vector4 = _stick.lerp(raw, 1.0 - exp(-dt / tau))
	var max_step: float = lerpf(9.0, 16.0, skill) * dt
	var d4: Vector4 = lp - _stick
	_stick += Vector4(clampf(d4.x, -max_step, max_step), clampf(d4.y, -max_step, max_step), clampf(d4.z, -max_step, max_step), clampf(d4.w, -max_step, max_step))
	_stick = Vector4(clampf(_stick.x, -1, 1), clampf(_stick.y, -1, 1), clampf(_stick.z, -1, 1), clampf(_stick.w, 0, 1))
	InputManager.test_override = {"roll": _stick.x, "pitch": _stick.y, "yaw": _stick.z, "throttle": _stick.w}
	if OS.has_environment("SH_AP_LOG") and int(_t * 120.0) % 30 == 0:
		print("AP t %.1f s %.0f/%.0f v %.1f plan %.1f vd %.1f acc %s tilt %.0f want %.0f thr %.2f frac %.2f next %d off %.2f p %s" % [_t, s, total, v.length(), v_plan, vd.length(), str(acc.snapped(Vector3.ONE * 0.1)), rad_to_deg(b.y.angle_to(Vector3.UP)), rad_to_deg(up_d.angle_to(Vector3.UP)), _stick.w, frac, rc._next, pts[_i].distance_to(p), str(p.snapped(Vector3.ONE * 0.1))])
	# Stuck (a clip into something): give it a moment, then reset like R.
	if _t > 3.0 and v.length() < 0.4:
		_stuck += dt
		if _stuck > 2.5:
			_stuck = 0.0
			resets += 1
			drone.reset_to_spawn()
	else:
		_stuck = 0.0

## Stick for a wanted rate (rad/s) on an axis: the pilot's rate curve
## inverted (bisection - it is monotonic).
func _inv_rate(axis: int, rate: float) -> float:
	var want: float = rad_to_deg(rate)
	var vals = Settings.rate_values(axis)
	var lo: float = -1.0
	var hi: float = 1.0
	if want >= Rates.rate_deg(Settings.rates_type, vals, 1.0):
		return 1.0
	if want <= Rates.rate_deg(Settings.rates_type, vals, -1.0):
		return -1.0
	for _k in range(18):
		var mid: float = (lo + hi) * 0.5
		if Rates.rate_deg(Settings.rates_type, vals, mid) < want:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5

## Stick for a wanted throttle after the pilot's MID/EXPO curve.
func _inv_throttle(want: float) -> float:
	var lo: float = 0.0
	var hi: float = 1.0
	for _k in range(16):
		var mid: float = (lo + hi) * 0.5
		if Settings.throttle_curve(mid) < want:
			lo = mid
		else:
			hi = mid
	return (lo + hi) * 0.5
