class_name Drone
extends RigidBody3D

## Simplified quadcopter (X-frame) flight model with both Angle
## (self-level, default) and Acro flight modes - toggle with L via
## InputManager.self_level.
##
## Both modes ultimately drive the same inner-loop rate PID per axis; they
## only differ in how the target rate is produced (see _actual_rate() for
## Acro's Betaflight-style curve, and the self_level branch below for
## Angle mode's outer attitude loop). PID outputs are mixed into 4 virtual
## motor thrusts (roll/pitch) plus a direct reaction torque (yaw - a
## spinning prop's drag torque can't be produced by a purely vertical
## thrust force, so it's modelled directly).

## Sized to match a real 3" freestyle quad (DeepSpace Seeker3: ~245g
## flying weight, ~60mm motor arm) rather than a 5" frame. Thrust set
## for a thrust-to-weight ratio of ~7:1 (total thrust = 7 * weight),
## typical for a high-KV 4S 3" freestyle build - "rips" with instant,
## crisp throttle response rather than a lazy 5" cruiser feel.
##
## These are the Seeker3 defaults; see PROFILES / apply_profile() below
## for how a second frame (a tiny whoop) overrides all of Frame/drag/PID
## with its own real-world-grounded numbers, plus a different visual
## model, when Settings.selected_drone == "whoop".
@export_group("Frame")
@export var arm_length: float = 0.06
@export var max_motor_thrust_n: float = 4.2

## Real air resistance is roughly quadratic in speed (F = k * v^2), not
## RigidBody3D's default linear_damp - linear damping barely slows a
## quad like this down at all, so top speed just kept climbing well
## past anything real (verified: >470 km/h and still rising after 10s
## simulated at max thrust before this was added). Calibrated so a
## drone in a steady, level-altitude dive at max thrust settles near
## the DeepSpace Seeker3's real claimed top speed of 150 km/h (41.7 m/s):
## k = (max thrust's horizontal component once vertical thrust exactly
## cancels gravity - minus what linear rotor drag already takes at that
## speed, see rotor_drag_planar) / target_speed^2. Re-derived when rotor
## drag was added (0.009 -> 0.00807) and again when rotor drag started
## scaling with rotor speed (-> 0.00562, since props at full throttle
## drag ~2.6x their hover value); re-verified headless both times: a
## level full-throttle dive settles at 41.7 m/s.
@export var drag_coefficient: float = 0.00562

## Betaflight's real default "Actual Rates" (since BF 4.3): Center
## Sensitivity 70 deg/s, Max Rate 670 deg/s, same on roll/pitch/yaw.
## The curve is soft near center and steep at full deflection - a flat
## linear mapping (what this used to be) is objectively twitchier.
## (Acro rates: Settings.rates_type / rates_roll... - see Rates.)

## Angle (self-level) mode: sticks command a target tilt angle instead
## of a rotation rate, and an outer P-loop corrects back to it - this is
## what every real flight controller defaults beginners to, since pure
## acro has no attitude reference and just keeps whatever tilt it drifts
## to. Toggle with L; yaw is always rate-controlled, even in angle mode,
## same as a real FC.
@export_group("Angle Mode")
@export_range(10.0, 60.0, 1.0) var max_angle_deg: float = 45.0
@export_range(2.0, 15.0, 0.5) var angle_p_gain: float = 11.0

## Rate-loop gains in *normalized* units: P is angular acceleration
## (rad/s^2) commanded per rad/s of rate error, I per rad of accumulated
## error, D per rad/s^2 of error change. The PID output is multiplied by
## the frame's real inertia to get a torque (see _physics_process), so
## the same numbers mean the same "feel" on any frame. The previous
## gains were raw newtons of thrust difference, which forced every frame
## to carry completely different numbers (the whoop's 0.00036 couldn't
## even be shown by the tuning panel's 0.002-step sliders - it read as
## 0.0, and touching the slider multiplied the gain ~5x).
##
## P = 30 puts the rate loop's bandwidth at ~30 rad/s (a ~33 ms time
## constant) - the order of a well-tuned Betaflight quad's gyro-tracking
## lag, and 4x snappier than the old ~110 ms. I sits well below that
## (integrator zero at ~1.7 rad/s) so it only trims steady disturbances.
@export_group("PID Roll")
@export var roll_p: float = 30.0
@export var roll_i: float = 50.0
@export var roll_d: float = 0.4

@export_group("PID Pitch")
@export var pitch_p: float = 30.0
@export var pitch_i: float = 50.0
@export var pitch_d: float = 0.4

@export_group("PID Yaw")
@export var yaw_p: float = 20.0
@export var yaw_i: float = 20.0
@export var yaw_d: float = 0.0

## Real rotor drag (blade flapping + induced drag): a spinning prop
## moving edgewise through the air gets pushed back roughly in
## proportion to speed - linear, not quadratic. This is what makes a real
## quad visibly bleed off speed once it's levelled out; quadratic drag
## alone is nearly zero at low speed, so before this the drone kept
## sliding (and at hover throttle, kept climbing) for many seconds with
## the sticks centered. Mass-normalized coefficient, applied in the
## rotor plane (body X/Z): Faessler, Franchi & Scaramuzza, "Differential
## Flatness of Quadrotor Dynamics Subject to Rotor Drag" (IEEE RA-L 2018)
## identified dx = 0.49-0.54 s^-1 and dy = 0.24-0.39 s^-1 on a real
## quadrotor - 0.4 sits in the middle of that range. The axial term
## (along the thrust axis) isn't identified there; it's a smaller
## assumed value standing in for the prop-inflow effect (thrust drops as
## the drone climbs into its own airflow), which is what stops a real
## quad's climb once the throttle comes back to hover.
## Both are the values at hover; the effect scales with rotor speed
## (blade flapping / H-force grow with how fast the props turn, and
## rotor speed ~ sqrt(thrust)), so idling props barely drag and stopped
## (disarmed) props don't at all. Before this scaling, the full hover
## value also applied after a throttle chop, braking every fall.
@export_group("Rotor Drag (1/s, mass-normalized)")
@export var rotor_drag_planar: float = 0.4
@export var rotor_drag_axial: float = 0.25

## Betaflight's Airmode: once active, the mixer keeps full PID authority
## even at zero throttle (shifting all four motors up together instead of
## clipping the ones that would go below idle), so the quad still holds
## attitude during a throttle-off dive or flip. Like Betaflight's
## airmode_start_throttle_percent (default 25), it only engages after
## the throttle has been raised past that point once since arming -
## otherwise an armed quad sitting on the ground would twitch around on
## PID reactions to ground contact.
@export_group("Mixer")
@export var airmode_start_throttle: float = 0.25
## Real ESCs never let an armed motor fully stop (Betaflight's
## dshot_idle_value, default 5.5% motor output - spinning, but making
## very little thrust). Expressed here directly as a fraction of max
## thrust: static thrust grows roughly with the square of motor output,
## so 5.5% output is ~0.3% thrust. (It was 1% - 7% of the Seeker3's
## weight across four motors - which made throttle-chop falls soft.)
@export var idle_thrust_fraction: float = 0.003

@export_group("Camera")
@export_range(0.0, 90.0, 0.5) var camera_angle_deg: float = 25.0
@export_range(50.0, 150.0, 1.0) var camera_fov_deg: float = 80.0

@export_group("Throttle")
## >1 softens low-stick response (more resolution around hover) and
## sharpens the top end; 1.0 is linear.
@export_range(0.5, 3.0, 0.05) var throttle_curve: float = 1.6

# Motor order: front-right, front-left, back-right, back-left.
const ROLL_MIX: Array[float] = [1.0, -1.0, 1.0, -1.0]
const PITCH_MIX: Array[float] = [1.0, 1.0, -1.0, -1.0]

## Two real frames, not just two skins: every number below (mass, arm
## length, thrust, drag, PID) is re-derived for whichever is selected,
## the same way the Seeker3's own numbers were originally grounded in its
## real specs (see the Frame/drag_coefficient docs above).
##
## Tiny whoop numbers, researched rather than guessed: sub-75mm class
## whoops run 18-28g without battery, a 1S (3.7V) pack, and 0802-1002
## brushless motors around 19-25kKV turning 40mm props - built for
## agility and indoor safety, explicitly not speed (sources: Tattu's and
## FPV Drone Guide's tiny-whoop explainers, 2026). No source gives a
## single top-speed number since whoops aren't marketed on it, so this
## targets a conservative, commonly-quoted ballpark for the class
## (~40 km/h / 11.1 m/s in open air) rather than a specific product's
## claim. TWR ~3:1 (total thrust = 3 * weight) - enough headroom for
## flips and punch-outs, well short of a freestyle quad's ~7:1.
## drag_coefficient derived with the same formula used for the Seeker3
## (rotor drag included).
## Both frames now share the same normalized PID gains (see roll_p's
## docs); what differs is the real inertia they're multiplied by.
## Inertia comes from a point-mass estimate rather than the old auto-
## computed solid sphere: four motors (~12g each on the Seeker3, ~2g on
## a whoop) at the motor-to-center distance, plus the battery/stack mass
## near the center - yaw (Y) is roughly double roll/pitch since every
## motor contributes on both horizontal axes. yaw_torque_per_newton is
## the prop's drag-torque-to-thrust ratio (a typical 0.01-0.02 m for
## small props), which caps how hard the motors can actually yaw the
## frame instead of treating yaw torque as unlimited.
## Menu order.
const PROFILE_ORDER: Array[String] = ["seeker3", "five", "race", "whoop"]

const PROFILES: Dictionary = {
	"seeker3": {
		"mass": 0.245,
		"arm_length": 0.06,
		"max_motor_thrust_n": 4.2,
		"drag_coefficient": 0.00562,
		"inertia": Vector3(5.5e-4, 9.5e-4, 5.5e-4),
		"yaw_torque_per_newton": 0.015,
		"collision_radius": 0.08,
		"camera_near": 0.05, "camera_far": 2000.0,
		"display": {"name": "Static Three", "tags": ["3 inch", "150 km/h", "245 g"],
			"text": "3-inch freestyle quad - fast, seven times more thrust than weight."},
		"visual": {
			"body_radius": 0.035, "body_height": 0.02,
			"arm_thickness": 0.012,
			"motor_radius": 0.014, "motor_height": 0.022,
			"prop_radius": 0.045,
			"has_prop_guards": false,
			"frame_color": Color(0.85, 0.12, 0.12),
		},
	},
	# The classic 5-inch freestyle size. Typical build, not one specific
	# product: ~650 g take-off weight on a 6S pack, 2306-class motors
	# making ~1.5 kgf (14.7 N) each on 5" props - a thrust-to-weight
	# ratio of ~9:1 - on a ~225 mm (motor-to-motor diagonal) frame, so
	# arm_length (half the square's side) = 0.08 m. Top speed target
	# 210 km/h (58.3 m/s); drag_coefficient from the same formula as
	# the others (max thrust's horizontal part at level flight, minus
	# rotor drag at that speed, over v^2). Inertia: point-mass estimate
	# (four ~35 g motors at the arms, a ~200 g battery on top).
	"five": {
		"mass": 0.65,
		"arm_length": 0.08,
		"max_motor_thrust_n": 14.7,
		"drag_coefficient": 0.00866,
		"motor_tau": 0.025,
		"inertia": Vector3(1.3e-3, 2.3e-3, 1.3e-3),
		"yaw_torque_per_newton": 0.012,
		"collision_radius": 0.1,
		"camera_near": 0.05, "camera_far": 2000.0,
		"display": {"name": "Static Five", "tags": ["5 inch", "210 km/h", "650 g"],
			"text": "5-inch freestyle quad - big props, big speed, nine times more thrust than weight."},
		"visual": {
			"body_radius": 0.045, "body_height": 0.03,
			"arm_thickness": 0.016,
			"motor_radius": 0.016, "motor_height": 0.02,
			"prop_radius": 0.0635,
			"has_prop_guards": false,
			"frame_color": Color(0.95, 0.45, 0.08),
		},
	},
	# Static Race (2026-10-02): a 5" race build, not a specific product.
	# Sources: oscarliang.com/table-prop-motor-lipo-weight (race 5" dry
	# 250-300 g vs freestyle 300-450 g), 6S 1000-1300 mAh packs ~150-180 g
	# (intofpv.com) -> 440 g all-up; 2207 motors ~1950 KV on 6S with 5.1"
	# tri-blades; race builds run 8:1-12:1 thrust-to-weight
	# (x-teamrc.com) -> 11:1 = 11.9 N per motor (bench tables give up to
	# ~19 N at full power, dronehitech.com F60 Pro IV test); 225 mm
	# wheelbase. Top speed 170 km/h is an ESTIMATE (a league racer was
	# measured at ~137 km/h, drl.io; tuned race builds go faster) - the
	# drag coefficient was set by flying it to that speed in a physics
	# test (full throttle, level, 40 m/s+ in acro). Battery slung under
	# the frame, low top plate, bright colour for spotting at speed.
	"race": {
		"mass": 0.44,
		"arm_length": 0.08,
		"max_motor_thrust_n": 11.9,
		"drag_coefficient": 0.0132,
		"motor_tau": 0.022,
		"inertia": Vector3(1.0e-3, 1.8e-3, 1.0e-3),
		"yaw_torque_per_newton": 0.012,
		"collision_radius": 0.095,
		"camera_near": 0.05, "camera_far": 2000.0,
		"display": {"name": "Static Race", "tags": ["5 inch", "170 km/h", "440 g"],
			"text": "5-inch race quad - light, low and brutal: eleven times more thrust than weight."},
		"visual": {
			"body_radius": 0.04, "body_height": 0.024,
			"arm_thickness": 0.014,
			"motor_radius": 0.016, "motor_height": 0.02,
			"prop_radius": 0.0648,
			"has_prop_guards": false,
			"race": true,
			"frame_color": Color(0.55, 0.9, 0.1),
		},
	},
	# Static Whoop (2026-10-02): modelled on a current 75 mm brushless
	# ducted whoop (sources: the maker's product page - 75 mm wheelbase,
	# 20.2-21.3 g dry, 0802 motors 22000-28000 KV, GF 1614 3-blade props,
	# 1S 480 mAh BT2.0, ~7 min; oscarliang.com's review of the previous
	# generation - "incredibly nimble", hovers well under half throttle).
	# Numbers: all-up weight 32 g (21 g + a ~11.5 g 1S 480 mAh pack -
	# estimate, no source states it); thrust-to-weight ~7:1 (one secondary
	# source) -> 0.55 N per motor; motor offset 75 / 2 / sqrt(2) = 26.5 mm;
	# props 41 mm. No measured top speed exists anywhere - 70 km/h is an
	# ESTIMATE for a light 75 mm brushless whoop; drag_coefficient from the
	# same formula as the others: (sqrt(T^2 - (mg)^2) - 0.4 * m * v) / v^2
	# with T = 2.2 N, m = 0.032 kg, v = 19.4 m/s. Inertia: four ~2.3 g
	# motors at 26.5 mm plus ducts/frame (~8 g at ~30 mm) and the pack.
	"whoop": {
		"mass": 0.032,
		"arm_length": 0.0265,
		"max_motor_thrust_n": 0.55,
		"drag_coefficient": 0.00489,
		"motor_tau": 0.015,
		"inertia": Vector3(1.05e-5, 2.0e-5, 1.05e-5),
		"yaw_torque_per_newton": 0.012,
		"collision_radius": 0.034,
		"camera_near": 0.012, "camera_far": 400.0,
		"display": {"name": "Static Whoop", "tags": ["75 mm", "70 km/h", "32 g"],
			"text": "75 mm brushless ducted whoop - light and snappy, seven times more thrust than weight."},
		"visual": {
			"body_radius": 0.013, "body_height": 0.009,
			"arm_thickness": 0.004,
			"motor_radius": 0.005, "motor_height": 0.008,
			"prop_radius": 0.0205,
			"has_prop_guards": true,
			"frame_color": Color(0.11, 0.11, 0.12),
			"prop_color": Color(1.0, 0.45, 0.1, 0.8),
			"bell_color": Color(0.85, 0.15, 0.12),
		},
	},
}

## Pure safety ceilings, well above anything normal flight ever produces
## (top speed is ~41.7 m/s, acro's max rate tops out around 11.7
## rad/s) - they only ever engage right after a hard collision. Measured
## empirically (headless tumbling-impact test) that a corner hit could
## momentarily spike angular velocity to ~39 rad/s (2234 deg/s), which
## reads as the drone "going haywire" after a crash even though nothing
## was actually clipping through geometry.
const MAX_LINEAR_SPEED: float = 75.0 ## above the Static Five's 58.3 m/s top speed
const MAX_ANGULAR_SPEED: float = 20.0

var motor_positions: Array[Vector3] = []
var yaw_torque_per_newton: float = 0.015

## Betaflight's I-term relax (iterm_relax_cutoff, default 15 Hz; threshold
## ~40 deg/s in its default "RP" mode): while the setpoint is changing
## fast (a flick, a flip), the rate error is *expected* to be large - it's
## lag, not a disturbance - so the I-term mostly stops accumulating.
## Without this the integrator winds up during every flick and then
## keeps pushing after the stick is centered: reproduced headless (a
## 0.4 s roll flick in acro kept rolling the quad from 43 to 53 degrees
## over the next two seconds with the stick at exactly zero).
const ITERM_RELAX_CUTOFF_HZ: float = 15.0
const ITERM_RELAX_THRESHOLD: float = 0.7 # rad/s, ~40 deg/s

var _setpoint_lp := Vector3.ZERO
var _airmode_active: bool = false
var _last_total_thrust: float = 0.0
## Average motor speed as a fraction of max (rpm ~ sqrt(thrust)), for
## the motor sound. 0 while disarmed.
var rpm_fraction: float = 0.0

## Prop strike: a prop touching a wall/ceiling/object can't move air, so
## it makes (almost) no thrust while touching, and needs a moment to spin
## back up afterwards. This is what makes a real quad bounce off, tip
## away from and fall down a wall instead of being pinned to it by its
## own thrust - reproduced headless before this existed: flown into a
## wall the drone stopped dead (no bounce) and stayed glued to it,
## creeping *upward*; punched into a ceiling it stuck there motionless.
const PROP_STRIKE_THRUST: float = 0.05
const PROP_SPINUP_TIME: float = 0.25 ## s after contact ends
var _prop_blocked: Array[float] = [0.0, 0.0, 0.0, 0.0] # remaining block time per motor
var _in_contact: bool = false
var _prop_centers: Array[Vector3] = [] # local, set by _build_collision
var _prop_radius: float = 0.04

## Prop damage (Settings.prop_damage, off by default): a hard hit chips
## or bends a prop. prop_health is each prop's thrust left (1 = intact).
## See _strike() for what counts as hard, _physics_process for the
## effects (less thrust on that motor, a yaw pull from its missing drag
## torque, vibration the PID has to fight, a shaking camera). Reset
## (R) fits new props.
var prop_health: Array[float] = [1.0, 1.0, 1.0, 1.0]
## Seconds left of the OSD's "PROP DAMAGED" note after a new hit.
var prop_damage_flash: float = 0.0
## Prop spin per motor, Betaflight's default "props in" (seen from above:
## front right and back left counter-clockwise, the others clockwise);
## +1 = counter-clockwise = +Y. A prop's drag torque turns the frame the
## other way, so a weaker prop leaves a pull in its own spin direction.
const PROP_SPIN: Array[float] = [1.0, -1.0, -1.0, 1.0]
## Impact speed (m/s, along the contact normal) from which a hit damages
## a prop; guards/ducts take the first knocks. Damage per m/s above it,
## at most PROP_HIT_MAX per hit, never below PROP_HEALTH_MIN: a chipped
## prop flies on, worse - not punishing, a bad crash or two is noticeable.
const PROP_HIT_SPEED: float = 3.0
const PROP_HIT_SPEED_GUARDED: float = 5.5
const PROP_HIT_PER_MPS: float = 0.05
const PROP_HIT_MAX: float = 0.2
const PROP_HEALTH_MIN: float = 0.6
var _hit_cool: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _hit_now: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _vel_hist: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO, Vector3.ZERO, Vector3.ZERO] # last steps, newest last
var _prev_ang_vel := Vector3.ZERO
var _guarded: bool = false
var _vib_noise := FastNoiseLite.new()
var _vib_t: float = 0.0

## Collision shape layout (see _build_collision): index 0 body, 1 nose
## (camera), 2..5 one sphere per prop, in motor order.
const SHAPE_PROP_FIRST: int = 2

const OWN_MODEL_LAYER: int = 1 << 19 ## render layer 20, see _rebuild_visual

var _roll_pid := PIDController.new()
var _pitch_pid := PIDController.new()
var _yaw_pid := PIDController.new()

var _spawn_transform: Transform3D

## Crash recovery: a quad lying on its back or side can't take off again
## (all thrust goes sideways or into the ground). Real pilots use
## Betaflight's "turtle mode" for that; here, after lying still like that
## for RECOVER_TIME, the drone is simply turned upright where it lies,
## keeping its heading. `stuck_time` is public for the HUD countdown.
const RECOVER_TIME: float = 2.0
const RECOVER_MAX_UP_Y: float = 0.5 ## tilted more than 60 degrees
var stuck_time: float = 0.0

## The pack (see Battery) and time flown since spawn/reset, for the OSD.
var battery := Battery.new()
var flight_time: float = 0.0

@onready var _camera_mount: Node3D = $CameraMount
@onready var _camera: Camera3D = $CameraMount/Camera3D

func _ready() -> void:
	camera_angle_deg = Settings.camera_angle_deg
	camera_fov_deg = Settings.camera_fov_deg
	InputManager.new_flight()
	# Indoor whoop maps force their drone (see MapCatalog).
	var map_info: Dictionary = MapCatalog.for_scene(owner.scene_file_path if owner else "")
	_indoor = map_info.get("indoor", false)
	_wind_noise.seed = hash(map_info.get("id", "x"))
	_wind_dir = Vector3.FORWARD.rotated(Vector3.UP, float(absi(_wind_noise.seed) % 360) * PI / 180.0)
	var forced: String = MapCatalog.forced_drone(owner.scene_file_path if owner else "")
	if forced != "":
		Settings.selected_drone = forced
	apply_profile(Settings.selected_drone)
	_spawn_transform = global_transform
	_apply_camera_settings()

## Switches this drone to a different real frame: mass, arm length,
## thrust, drag, PID gains, collision size, and visual model all change
## together (see PROFILES above). Falls back to "seeker3" for an unknown
## name rather than erroring, since this always runs once at startup off
## a value Settings itself controls.
func apply_profile(profile_name: String) -> void:
	var p: Dictionary = PROFILES.get(profile_name, PROFILES["seeker3"])
	battery.setup(profile_name)
	mass = p.mass
	arm_length = p.arm_length
	max_motor_thrust_n = p.max_motor_thrust_n
	drag_coefficient = p.drag_coefficient
	motor_tau = p.get("motor_tau", 0.02)
	inertia = p.inertia
	yaw_torque_per_newton = p.yaw_torque_per_newton
	motor_positions = [
		Vector3(arm_length, 0.0, -arm_length),  # front right
		Vector3(-arm_length, 0.0, -arm_length), # front left
		Vector3(arm_length, 0.0, arm_length),   # back right
		Vector3(-arm_length, 0.0, arm_length),  # back left
	]

	_guarded = p.visual.get("has_prop_guards", false)
	_build_collision(p)
	_rebuild_visual(p.visual)
	var sound := get_node_or_null("MotorSound")
	if sound:
		sound.set_profile(profile_name if PROFILES.has(profile_name) else "seeker3")

## The drone's real outline as a compound of spheres: the body, one
## sphere per prop disc, and a "nose" sphere centered on the FPV camera.
## It used to be one sphere around the body - the camera sat *outside*
## it (9 cm forward), so touching a wall nose-first put the camera 1 cm
## inside the wall and the pilot saw straight through it (measured
## headless: drone center at z=-11.72, wall face at -11.80, camera at
## -11.81). Now the camera is always at least its near-plane distance
## away from anything it can touch. Spheres, not boxes: no thin axis to
## tunnel through at speed (see README, Performance). Each prop sphere
## is its own shape so a contact tells which prop hit (prop strike).
func _build_collision(p: Dictionary) -> void:
	for child in get_children():
		if child is CollisionShape3D:
			child.free()
	var v: Dictionary = p.visual
	var near: float = p.camera_near
	var cam_pos := Vector3(0, v.body_height * 0.6, -v.body_radius * 1.05)
	var prop_r: float = v.prop_radius + (0.004 if v.has_prop_guards else 0.0)
	var shapes: Array = [
		[Vector3(0, v.body_height * 0.5, 0), v.body_radius * 1.15],
		[cam_pos, near * 1.4],
	]
	_prop_centers.clear()
	_prop_radius = prop_r
	for m in motor_positions:
		_prop_centers.append(m + Vector3(0, v.motor_height + 0.002, 0))
		shapes.append([_prop_centers[-1], prop_r])
	for sdef in shapes:
		var sphere := SphereShape3D.new()
		sphere.radius = sdef[1]
		var cs := CollisionShape3D.new()
		cs.shape = sphere
		cs.position = sdef[0]
		add_child(cs)
	# A flat skid under the frame at the lowest sphere's bottom, so the
	# quad sits level on the ground like on a real bottom plate. Without
	# it the camera's nose sphere (big enough to keep the near plane out
	# of walls) was the lowest point, and the Static Three rested tipped
	# 22 degrees onto its nose and rear props - at spawn and after every
	# landing. Added last, so the prop shape indices stay put.
	var lowest: float = 0.0
	for sdef in shapes:
		lowest = minf(lowest, sdef[0].y - sdef[1])
	var skid := BoxShape3D.new()
	skid.size = Vector3(arm_length * 2.0, 0.01, arm_length * 2.0)
	var skid_cs := CollisionShape3D.new()
	skid_cs.shape = skid
	skid_cs.position = Vector3(0, lowest + 0.005, 0)
	add_child(skid_cs)
	# Mass is centered on the frame, not wherever the shapes' volume
	# happens to be (the nose sphere would pull it forward).
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	center_of_mass = Vector3.ZERO
	if _camera_mount:
		_camera_mount.position = cam_pos
	if _camera:
		_camera.near = near
		_camera.far = p.camera_far
		_camera.set_meta("profile_far", p.camera_far) # Settings caps it at the render distance

## The visual frame is fully rebuilt from primitives (DroneFrameBuilder)
## rather than kept as hand-authored nodes in Drone.tscn, so the same
## scene/script can represent either real frame - see drone_frame_builder.gd.
func _rebuild_visual(visual: Dictionary) -> void:
	for child in get_children():
		if child is MeshInstance3D:
			child.free()
	var build_profile: Dictionary = visual.duplicate()
	build_profile["arm_length"] = arm_length
	DroneFrameBuilder.build(self, build_profile)
	# The drone's own model lives on its own render layer, which the FPV
	# camera doesn't draw: with the camera at the real camera pod, the
	# translucent prop discs would otherwise cover a big part of the
	# picture. (Other cameras - the menu preview - still see it.)
	for child in get_children():
		if child is MeshInstance3D:
			(child as MeshInstance3D).layers = OWN_MODEL_LAYER
	if _camera:
		_camera.cull_mask = 0xFFFFF & ~OWN_MODEL_LAYER

## (Contacts come from max_contacts_reported alone - contact_monitor is
## deliberately off: it only drives the body_entered/exited signals,
## which nothing here uses, and measured it tripled the cost of a
## physics step in the school map.)
##
## Reads this step's contacts: a contact on a prop sphere blocks that
## prop; anything pressing on the drone from the side the props blow
## away from (a ceiling above an upright quad) blocks all of them. A
## contact below (landing on the floor) blocks nothing.
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	_in_contact = state.get_contact_count() > 0
	var up: Vector3 = state.transform.basis.y
	for i in range(state.get_contact_count()):
		var shape_idx: int = state.get_contact_local_shape(i)
		var rel: Vector3 = state.get_contact_local_position(i) - state.transform.origin
		if shape_idx >= SHAPE_PROP_FIRST and shape_idx < SHAPE_PROP_FIRST + 4:
			# Only an obstacle at the prop disc or above it is in the
			# prop's way. Something *under* the disc is the ground the
			# quad is sitting on (a whoop rests on its prop guards) - the
			# props spin freely there. Without this check a whoop on the
			# floor had all four props "blocked" and could never lift off
			# (reproduced headless: y stayed at 0.012 at 60% throttle).
			var m: int = shape_idx - SHAPE_PROP_FIRST
			var center: Vector3 = state.transform * _prop_centers[m]
			var below: float = (state.get_contact_local_position(i) - center).dot(up)
			if below > -_prop_radius * 0.3:
				_prop_blocked[m] = PROP_SPINUP_TIME
		elif rel.dot(up) > 0.0:
			for m in range(4):
				_prop_blocked[m] = PROP_SPINUP_TIME
		if Settings.prop_damage:
			_strike(state, i, shape_idx)
	# One crash = one hit per prop (the worst contact of this step); then a
	# short cool-down while it bounces and scrapes along.
	for m in range(4):
		if _hit_now[m] >= 0.01 and _hit_cool[m] <= 0.0:
			prop_health[m] = maxf(prop_health[m] - _hit_now[m], PROP_HEALTH_MIN)
			prop_damage_flash = 2.5
			_hit_cool[m] = 0.5
		_hit_now[m] = 0.0
	_vel_hist.pop_front()
	_vel_hist.append(state.linear_velocity)
	_prev_ang_vel = state.angular_velocity

## A hit on anything: how fast the touching point was moving into the
## obstacle over the last few steps (by the time a contact is reported
## the solver has already eaten most of the speed - measured: an 11 m/s
## crash read 4 m/s one step back), and which prop is nearest to it. A prop takes a hit through its own
## sphere, or through the frame at speed (a crash lands on the props).
func _strike(state: PhysicsDirectBodyState3D, i: int, shape_idx: int) -> void:
	var at: Vector3 = state.get_contact_local_position(i)
	var r: Vector3 = at - state.transform.origin
	var n: Vector3 = state.get_contact_local_normal(i)
	var other: Vector3 = state.get_contact_collider_velocity_at_position(i)
	var impact: float = 0.0
	for v in _vel_hist:
		impact = maxf(impact, -(v + _prev_ang_vel.cross(r) - other).dot(n))
	var limit: float = PROP_HIT_SPEED_GUARDED if _guarded else PROP_HIT_SPEED
	if shape_idx < SHAPE_PROP_FIRST or shape_idx >= SHAPE_PROP_FIRST + 4:
		limit *= 1.6 # the frame took it; the props catch only part of it
	if impact <= limit:
		return
	var local: Vector3 = state.transform.basis.inverse() * r
	var m: int = 0
	for k in range(1, 4):
		if local.distance_to(_prop_centers[k]) < local.distance_to(_prop_centers[m]):
			m = k
	if shape_idx >= SHAPE_PROP_FIRST and shape_idx < SHAPE_PROP_FIRST + 4:
		m = shape_idx - SHAPE_PROP_FIRST
	# A spinning prop shatters, a stopped one mostly survives.
	var spin: float = 0.3 + 0.7 * rpm_fraction if InputManager.armed else 0.25
	_hit_now[m] = maxf(_hit_now[m], minf((impact - limit) * PROP_HIT_PER_MPS, PROP_HIT_MAX) * spin)

func _physics_process(delta: float) -> void:
	if linear_velocity.length() > MAX_LINEAR_SPEED:
		linear_velocity = linear_velocity.normalized() * MAX_LINEAR_SPEED
	if angular_velocity.length() > MAX_ANGULAR_SPEED:
		angular_velocity = angular_velocity.normalized() * MAX_ANGULAR_SPEED

	_roll_pid.kp = roll_p
	_roll_pid.ki = roll_i
	_roll_pid.kd = roll_d
	_pitch_pid.kp = pitch_p
	_pitch_pid.ki = pitch_i
	_pitch_pid.kd = pitch_d
	_yaw_pid.kp = yaw_p
	_yaw_pid.ki = yaw_i
	_yaw_pid.kd = yaw_d

	_apply_camera_settings()
	_update_wind(delta)
	_apply_drag()
	prop_damage_flash = maxf(prop_damage_flash - delta, 0.0)
	for m in range(4):
		_hit_cool[m] = maxf(_hit_cool[m] - delta, 0.0)
	_update_flip_recovery(delta)
	battery.step(delta, _last_total_thrust / (4.0 * max_motor_thrust_n), InputManager.armed)
	if InputManager.armed:
		flight_time += delta

	# Reset once when R or the radio's reset control turns ON - not every
	# frame while it stays on: a reset on a two-position switch is left in
	# the ON position, and the drone sat pinned to the spawn until the
	# switch was flipped back (the user thought it was broken, 2026-10-06).
	var reset_on: bool = InputManager.reset_key_pressed()
	var reset_edge: bool = reset_on and not _reset_was_on
	_reset_was_on = reset_on
	if reset_edge:
		reset_to_spawn()
		return

	if not InputManager.armed:
		_reset_controller()
		_motor_cmd = [0.0, 0.0, 0.0, 0.0]
		_last_total_thrust = 0.0
		rpm_fraction = 0.0
		return

	for m in range(4):
		_prop_blocked[m] = maxf(_prop_blocked[m] - delta, 0.0)
	if _in_contact:
		# Pressed against something, rate error is the obstacle's doing,
		# not a disturbance to integrate away - don't wind up into it.
		_roll_pid.reset_integral()
		_pitch_pid.reset_integral()
		_yaw_pid.reset_integral()

	var roll_in: float = InputManager.get_roll()
	var pitch_in: float = InputManager.get_pitch()
	var yaw_in: float = InputManager.get_yaw()
	var throttle_in: float = Settings.throttle_curve(InputManager.get_throttle())

	var desired_roll_rate: float
	var desired_pitch_rate: float
	if InputManager.self_level:
		var rates: Vector2 = _compute_self_level_rates(roll_in, pitch_in)
		desired_roll_rate = rates.x
		desired_pitch_rate = rates.y
	else:
		# Sticks read +1 = right/forward (see InputManager); in body axes
		# a right roll is a rotation about -Z, a nose-down (forward)
		# pitch about -X, and a right yaw about -Y.
		desired_roll_rate = -_actual_rate(0, roll_in)
		desired_pitch_rate = -_actual_rate(1, pitch_in)
	var desired_yaw_rate: float = -_actual_rate(2, yaw_in)

	if throttle_in >= airmode_start_throttle:
		_airmode_active = true

	# I-term relax: fraction of normal I accumulation allowed this step,
	# per axis, from how fast each setpoint is currently moving.
	var setpoint := Vector3(desired_pitch_rate, desired_yaw_rate, desired_roll_rate)
	_setpoint_lp = _setpoint_lp.lerp(setpoint, 1.0 - exp(-TAU * ITERM_RELAX_CUTOFF_HZ * delta))
	var sp_hp: Vector3 = (setpoint - _setpoint_lp).abs()
	var relax := Vector3(
		clampf(1.0 - sp_hp.x / ITERM_RELAX_THRESHOLD, 0.0, 1.0),
		clampf(1.0 - sp_hp.y / ITERM_RELAX_THRESHOLD, 0.0, 1.0),
		clampf(1.0 - sp_hp.z / ITERM_RELAX_THRESHOLD, 0.0, 1.0))
	if not _airmode_active:
		# Betaflight also holds the I-term at zero until airmode is
		# active - sitting armed on the ground must not wind it up.
		relax = Vector3.ZERO
		_roll_pid.reset_integral()
		_pitch_pid.reset_integral()
		_yaw_pid.reset_integral()

	# Angular velocity in the drone's own body frame (roll = about local Z,
	# pitch = about local X, yaw = about local Y, since -Z is "forward").
	var local_ang_vel: Vector3 = global_transform.basis.inverse() * angular_velocity

	# Normalized PID outputs are angular accelerations; times the real
	# inertia they become the torque each axis needs.
	var roll_torque: float = _roll_pid.update(desired_roll_rate - local_ang_vel.z, delta, relax.z) * inertia.z
	var pitch_torque: float = _pitch_pid.update(desired_pitch_rate - local_ang_vel.x, delta, relax.x) * inertia.x
	var yaw_torque: float = _yaw_pid.update(desired_yaw_rate - local_ang_vel.y, delta, relax.y) * inertia.y

	# Motors sit at +/-arm_length on both axes, so four motors produce
	# 4 * arm_length * delta of torque per newton of per-motor difference.
	var roll_out: float = roll_torque / (4.0 * arm_length)
	var pitch_out: float = pitch_torque / (4.0 * arm_length)

	var throttle_shaped: float = pow(throttle_in, throttle_curve)
	var base_thrust: float = throttle_shaped * max_motor_thrust_n
	var idle: float = idle_thrust_fraction * max_motor_thrust_n
	var thrusts: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var lo: float = INF
	var hi: float = -INF
	for i in range(4):
		thrusts[i] = base_thrust + roll_out * ROLL_MIX[i] + pitch_out * PITCH_MIX[i]
		lo = minf(lo, thrusts[i])
		hi = maxf(hi, thrusts[i])
	if _airmode_active:
		# Airmode: shift all four together so the roll/pitch *difference*
		# survives instead of being clipped away at either end - attitude
		# control wins over exact collective thrust, same as Betaflight.
		if hi - lo > max_motor_thrust_n - idle:
			var scale: float = (max_motor_thrust_n - idle) / (hi - lo)
			for i in range(4):
				thrusts[i] = base_thrust + (thrusts[i] - base_thrust) * scale
			lo = base_thrust + (lo - base_thrust) * scale
			hi = base_thrust + (hi - base_thrust) * scale
		if lo < idle:
			for i in range(4):
				thrusts[i] += idle - lo
		elif hi > max_motor_thrust_n:
			for i in range(4):
				thrusts[i] -= hi - max_motor_thrust_n

	var up_global: Vector3 = global_transform.basis.y
	var sag: float = battery.thrust_factor() if Settings.battery_enabled else 1.0
	var aero: float = _prop_wash(delta, up_global) * _ground_effect(up_global)
	var total_thrust: float = 0.0
	var k_motor: float = 1.0 - exp(-delta / maxf(motor_tau, 0.001))
	for i in range(4):
		# Motors don't change speed instantly: each one follows its command
		# with a first-order lag (motor_tau, see PROFILES).
		_motor_cmd[i] = lerpf(_motor_cmd[i], clampf(thrusts[i], idle, max_motor_thrust_n), k_motor)
		var thrust: float = _motor_cmd[i] * sag * aero
		if Settings.prop_damage:
			thrust *= prop_health[i]
		if _prop_blocked[i] > 0.0:
			# Recovering linearly over the spin-up time once free again.
			thrust *= lerpf(1.0, PROP_STRIKE_THRUST, _prop_blocked[i] / PROP_SPINUP_TIME)
		total_thrust += thrust
		var offset: Vector3 = global_transform.basis * motor_positions[i]
		apply_force(up_global * thrust, offset)

	# Yaw comes from the props' own drag torque (two props speeding up,
	# the other two slowing) - capped at what that can really produce
	# rather than unlimited.
	var max_yaw_torque: float = yaw_torque_per_newton * 2.0 * max_motor_thrust_n
	apply_torque(up_global * clampf(yaw_torque, -max_yaw_torque, max_yaw_torque))
	_last_total_thrust = total_thrust
	rpm_fraction = sqrt(clampf(total_thrust / (4.0 * max_motor_thrust_n), 0.0, 1.0))
	if Settings.prop_damage:
		_damaged_props(delta, up_global)

## A damaged prop: its missing drag torque leaves a yaw pull in its spin
## direction (the yaw PID holds it, the I-term trims it out), and the
## imbalance shakes the frame. The real shake is once per revolution
## (300-500 Hz on a 3"), far above the physics rate - what reaches the
## flight is the part the gyro filters let through, here a ~20 Hz random
## roll/pitch torque growing with the damage and the rpm.
func _damaged_props(delta: float, up: Vector3) -> void:
	var loss: float = 0.0
	var yaw: float = 0.0
	for i in range(4):
		var l: float = 1.0 - prop_health[i]
		loss += l
		yaw += PROP_SPIN[i] * yaw_torque_per_newton * _motor_cmd[i] * l
	if loss <= 0.0:
		return
	apply_torque(up * yaw)
	_vib_t += delta
	var amp: float = loss * 0.15 * max_motor_thrust_n * arm_length * rpm_fraction
	apply_torque(global_transform.basis * Vector3(
		_vib_noise.get_noise_2d(_vib_t * 2000.0, 3.0) * amp, 0.0,
		_vib_noise.get_noise_2d(_vib_t * 2000.0, 9.0) * amp))

## Camera shake from damaged props ("jello" in the FPV feed): a small,
## fast wobble of the camera on its mount, with the rpm.
func _process(_delta: float) -> void:
	if _camera == null:
		return
	var loss: float = 0.0
	if Settings.prop_damage and InputManager.armed:
		for h in prop_health:
			loss += 1.0 - h
	if loss <= 0.0:
		if _camera.rotation != Vector3.ZERO:
			_camera.rotation = Vector3.ZERO
		return
	var a: float = loss * 0.05 * rpm_fraction
	var t: float = Time.get_ticks_msec() * 0.001
	_camera.rotation = Vector3(_vib_noise.get_noise_2d(t * 3000.0, 21.0) * a, _vib_noise.get_noise_2d(t * 3000.0, 27.0) * a, 0.0)

## Motor response: real props take a moment to change speed - roughly
## 15 ms on a whoop's tiny props up to ~25 ms on 5" props (time constant
## of a brushless motor + prop under Betaflight's dynamic idle / RPM
## filtering; measured step responses in the 15-40 ms range are typical
## in blackbox logs). Set per frame in PROFILES ("motor_tau").
var motor_tau: float = 0.02
var _motor_cmd: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _wash_noise := FastNoiseLite.new()
var _wash_t: float = 0.0
var _ground_ray_t: float = 0.0
var _ground_h: float = 100.0

## Prop wash: descending fast along the thrust axis puts the props into
## their own downwash (toward vortex ring state) - the familiar shake on
## a dive-and-catch, and lift that's lost until you're through it. From
## 1.5 m/s of descent along the props' axis, growing to full at 6 m/s,
## scaled by how hard the motors push: random roll/pitch torque (~8 Hz)
## and up to 20% less thrust. Returns the thrust factor.
func _prop_wash(delta: float, up: Vector3) -> float:
	var v_axial: float = linear_velocity.dot(up)
	var load: float = clampf(_last_total_thrust / (4.0 * max_motor_thrust_n), 0.0, 1.0)
	var w: float = smoothstep(1.5, 6.0, -v_axial) * clampf(load * 2.5, 0.0, 1.0)
	if w <= 0.0 or not Settings.prop_wash:
		return 1.0
	_wash_t += delta
	# (FastNoiseLite's default frequency is 0.01: x800 -> ~8 Hz.)
	var n1: float = _wash_noise.get_noise_2d(_wash_t * 800.0, 1.0)
	var n2: float = _wash_noise.get_noise_2d(_wash_t * 800.0, 7.0)
	var amp: float = w * 0.12 * max_motor_thrust_n * arm_length
	apply_torque(global_transform.basis * Vector3(n2 * amp, 0.0, n1 * amp))
	return 1.0 - 0.2 * w

## Ground effect: within about one prop diameter of the ground the props
## get extra lift (the cushion under a low hover) - up to 12% right at
## the ground, fading out by two prop diameters. One raycast every few
## frames is plenty.
func _ground_effect(up: Vector3) -> float:
	_ground_ray_t -= get_physics_process_delta_time()
	if _ground_ray_t <= 0.0:
		_ground_ray_t = 0.05
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position - up * 1.0)
		q.exclude = [get_rid()]
		var hit: Dictionary = get_world_3d().direct_space_state.intersect_ray(q)
		_ground_h = global_position.distance_to(hit.position) if hit else 100.0
	var d: float = _prop_radius * 2.0
	return 1.0 + 0.12 * (1.0 - smoothstep(0.0, 2.0 * d, _ground_h))

## Quadratic body drag (dominant at speed) plus linear rotor drag
## (dominant slow - see rotor_drag_planar's docs), both applied at the
## center of mass.
func _apply_drag() -> void:
	# Drag acts on airspeed, so wind is just moving air (see _wind()).
	var air: Vector3 = linear_velocity - wind_velocity
	var speed_sq: float = air.length_squared()
	if speed_sq > 0.0001:
		apply_central_force(-air.normalized() * drag_coefficient * speed_sq)
	var b: Basis = global_transform.basis
	var v_local: Vector3 = b.inverse() * air
	var rotor_speed_ratio: float = sqrt(clampf(_last_total_thrust / (mass * 9.8), 0.0, 16.0))
	var rotor_drag_local := Vector3(
		-rotor_drag_planar * v_local.x,
		-rotor_drag_axial * v_local.y,
		-rotor_drag_planar * v_local.z) * mass * rotor_speed_ratio
	apply_central_force(b * rotor_drag_local)

## Wind (Settings.wind_level) on outdoor maps, as moving air the drag
## model sees (see _apply_drag) - never a raw force. Indoor maps: none.
##
## Built like the wind engineers' standard model of the lowest few
## hundred metres:
## - Mean speed (Settings.WIND_SPEEDS: 3 / 6 / 10 m/s at 10 m - Beaufort
##   2, 4 and 5) over height above ground by the log law
##   u(z) = u10 * ln(z / z0) / ln(10 / z0), z0 = 0.1 m (open country with
##   hedges and houses): ~0.5x at 1 m, 1.3x at 50 m.
## - Turbulence intensity Iu = 1 / ln(z / z0) (Eurocode EN 1991-1-4,
##   4.4: ~22% at 10 m, ~33% at 2 m); lateral 0.75 Iu, vertical 0.5 Iu
##   (the usual ratios, e.g. ESDU 85020). The turbulence is "frozen"
##   (Taylor): a 3D noise field that drifts with the wind over the map,
##   so flying through it upwind feels choppier than drifting with it.
## - Gusts: a slow swell of the mean speed (10-20 s), peaks ~1.4x the
##   mean - a typical gust factor over open land.
## - Shelter: under a roof or a tree (a ray up hits something) almost
##   still; in the lee of a building, wall or tree line (a ray upwind hits
##   it close) much weaker. Rays 10 times a second, smoothed.
const WIND_Z0: float = 0.1
const WIND_TURB_SCALE: float = 25.0 ## m, size of the turbulent eddies
var _indoor: bool = false
var _wind_noise := FastNoiseLite.new()
var _wind_t: float = 0.0
var _wind_dir: Vector3 = Vector3(1, 0, 0.3).normalized()
var _shelter: float = 1.0
var _shelter_target: float = 1.0
var _wind_agl: float = 10.0
var _wind_ray_t: float = 0.0
## The wind at the drone this step (for the OSD/tests).
var wind_velocity := Vector3.ZERO

func _update_wind(delta: float) -> void:
	if Settings.wind_level <= 0 or _indoor:
		wind_velocity = Vector3.ZERO
		return
	_wind_t += delta
	_wind_ray_t -= delta
	if _wind_ray_t <= 0.0:
		_wind_ray_t = 0.1
		var space: PhysicsDirectSpaceState3D = get_world_3d().direct_space_state
		var p: Vector3 = global_position
		var down: Dictionary = _ray(space, p, p + Vector3.DOWN * 80.0)
		_wind_agl = p.distance_to(down.position) if down else 80.0
		var shelter: float = 1.0
		if _ray(space, p, p + Vector3.UP * 30.0):
			shelter = 0.12 # roof, bridge, tree crown overhead
		var up_wind: Dictionary = _ray(space, p, p - _wind_dir * 20.0)
		if up_wind:
			shelter = minf(shelter, lerpf(0.35, 1.0, p.distance_to(up_wind.position) / 20.0))
		_shelter_target = shelter
	_shelter = lerpf(_shelter, _shelter_target, 1.0 - exp(-delta / 0.4))
	wind_velocity = _wind()

func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b)
	q.exclude = [get_rid()]
	return space.intersect_ray(q)

func _wind() -> Vector3:
	var level: int = clampi(Settings.wind_level, 0, Settings.WIND_SPEEDS.size() - 1)
	if level <= 0 or _indoor:
		return Vector3.ZERO
	var z: float = clampf(_wind_agl, 0.3, 120.0)
	var lnz: float = log(maxf(z, WIND_Z0 * 3.0) / WIND_Z0)
	var u: float = Settings.WIND_SPEEDS[level] * lnz / log(10.0 / WIND_Z0)
	var iu: float = clampf(1.0 / lnz, 0.12, 0.45)
	# Slow gusts and a direction that wanders +-15 degrees.
	var gust: float = maxf(_wind_noise.get_noise_2d(_wind_t * 6.0, 50.0), -0.3) * 0.8
	var dir: Vector3 = _wind_dir.rotated(Vector3.UP, _wind_noise.get_noise_2d(_wind_t * 2.0, 80.0) * 0.5)
	var side: Vector3 = dir.cross(Vector3.UP)
	# Frozen turbulence drifting downwind. (FastNoiseLite's default fractal
	# noise has a standard deviation of ~0.23, measured: /0.23 makes it ~1.)
	var q: Vector3 = (global_position - dir * u * _wind_t) * (100.0 / WIND_TURB_SCALE)
	var tu: float = _wind_noise.get_noise_3d(q.x, q.y, q.z) / 0.23
	var tv: float = _wind_noise.get_noise_3d(q.x + 500.0, q.y, q.z) / 0.23
	var tw: float = _wind_noise.get_noise_3d(q.x, q.y + 500.0, q.z) / 0.23
	var sigma: float = u * iu
	var w: Vector3 = dir * (u * (1.0 + gust) + tu * sigma) + side * tv * sigma * 0.75 + Vector3.UP * tw * sigma * 0.5
	return w * _shelter

func _reset_controller() -> void:
	_roll_pid.reset()
	_pitch_pid.reset()
	_yaw_pid.reset()
	_setpoint_lp = Vector3.ZERO
	_airmode_active = false

## The pilot's Betaflight rates (Settings -> Rates, see Rates): stick
## -1..1 on axis 0 roll / 1 pitch / 2 yaw to a target rate in rad/s.
func _actual_rate(axis: int, stick: float) -> float:
	return deg_to_rad(Rates.rate_deg(Settings.rates_type, Settings.rate_values(axis), stick))

## Betaflight's "Actual Rates" (src/main/fc/rc.c, applyActualRates):
## expof = |x| * (x^5 * expo + x * (1 - expo)),
## rate  = x * center + max(0, max - center) * expof.
## With Betaflight's default expo 0.54 this is within ~2% of the plain
## cubic curve the sim used before, so the feel didn't change - but now
## a pilot can enter the exact three numbers from their own quad.
static func actual_rate_deg(stick: float, center: float, max_rate: float, expo: float) -> float:
	var a: float = absf(stick)
	var expof: float = a * (pow(stick, 5.0) * expo + stick * (1.0 - expo))
	return stick * center + maxf(0.0, max_rate - center) * expof

## Angle mode's outer attitude loop, robust to ANY orientation including
## upside-down. Extracting separate roll/pitch angles with asin() (the
## old approach) has a blind spot: asin(sin(x)) folds anything past 90
## degrees back down, so a drone tilted 170 degrees (nearly inverted)
## reads as only 10 degrees off - the controller then applies a tiny
## correction when it needs a huge one, and as the true angle keeps
## changing the reading swings non-monotonically, which is what read as
## "it can spin" after a hard crash tumbles it upside-down. Verified
## empirically (frame-by-frame headless test) that recovery from a
## near-inverted start swung angular velocity up to ~500 deg/s before
## settling under the old method.
##
## This instead compares the body's up vector to a target up vector
## (built from stick input in the drone's current heading frame) via
## cross/dot product - well-defined for any angle except the exact
## 180-degree singularity every attitude representation has.
func _compute_self_level_rates(roll_in: float, pitch_in: float) -> Vector2:
	var world_up := Vector3.UP
	var current_up: Vector3 = global_transform.basis.y

	var fwd_h: Vector3 = -global_transform.basis.z
	fwd_h.y = 0.0
	if fwd_h.length_squared() < 0.0001:
		fwd_h = -global_transform.basis.x
		fwd_h.y = 0.0
	fwd_h = fwd_h.normalized()
	var right_h: Vector3 = fwd_h.cross(world_up)

	# +roll_in tilts the up vector toward right_h; +pitch_in (forward)
	# tilts it toward fwd_h, so the negated pitch angle below.
	var target_roll_angle: float = roll_in * deg_to_rad(max_angle_deg)
	var target_pitch_angle: float = -pitch_in * deg_to_rad(max_angle_deg)

	# Rodrigues' rotation formula, simplified since the rotation axes
	# here are always perpendicular to the vector being rotated.
	var target_up: Vector3 = world_up * cos(target_pitch_angle) + right_h.cross(world_up) * sin(target_pitch_angle)
	target_up = target_up * cos(target_roll_angle) + fwd_h.cross(target_up) * sin(target_roll_angle)

	var error_axis: Vector3 = current_up.cross(target_up)
	var error_axis_len: float = error_axis.length()
	var error_angle: float = asin(clamp(error_axis_len, -1.0, 1.0))
	if current_up.dot(target_up) < 0.0:
		error_angle = PI - error_angle # more than 90 degrees off - unfold asin's reflection
	if error_axis_len > 0.0001:
		error_axis /= error_axis_len
	else:
		error_axis = fwd_h # current/target exactly aligned or exactly opposite - pick an arbitrary recovery axis

	var max_rate_rad: float = deg_to_rad(maxf(Rates.max_deg(Settings.rates_type, Settings.rate_values(0)), 200.0))
	var correction: Vector3 = error_axis * error_angle * angle_p_gain
	var correction_local: Vector3 = global_transform.basis.inverse() * correction
	return Vector2(
		clamp(correction_local.z, -max_rate_rad, max_rate_rad),
		clamp(correction_local.x, -max_rate_rad, max_rate_rad)
	)

func _apply_camera_settings() -> void:
	if _camera_mount == null:
		return
	var rot: Vector3 = _camera_mount.rotation_degrees
	rot.x = camera_angle_deg
	_camera_mount.rotation_degrees = rot
	if _camera:
		_camera.fov = camera_fov_deg

func _update_flip_recovery(delta: float) -> void:
	var stuck: bool = global_transform.basis.y.y < RECOVER_MAX_UP_Y \
		and linear_velocity.length() < 0.6 and angular_velocity.length() < 1.5 \
		and (_in_contact or linear_velocity.length() < 0.05)
	stuck_time = stuck_time + delta if stuck else 0.0
	if stuck_time >= RECOVER_TIME:
		stuck_time = 0.0
		flip_upright()

## Upright where it lies, same heading, lifted just clear of whatever it
## was lying on, motionless. Stays armed - the pilot can fly straight off.
func flip_upright() -> void:
	var b: Basis = global_transform.basis
	var fwd: Vector3 = -b.z
	fwd.y = 0.0
	if fwd.length() < 0.2:
		# Nose pointing straight up or down: the belly/back gives the heading.
		fwd = b.y * signf(-b.z.y)
		fwd.y = 0.0
	if fwd.length() < 0.01:
		fwd = Vector3.FORWARD
	var t := Transform3D(Basis.looking_at(fwd.normalized(), Vector3.UP), global_position + Vector3.UP * 0.12)
	global_transform = t
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	reset_physics_interpolation()
	_reset_controller()

var _reset_was_on: bool = false

func reset_to_spawn() -> void:
	battery.reset()
	prop_health = [1.0, 1.0, 1.0, 1.0]
	prop_damage_flash = 0.0
	flight_time = 0.0
	global_transform = _spawn_transform
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	# A teleport: don't let physics interpolation smear the camera from
	# the old position to the new one over a frame.
	reset_physics_interpolation()
	_reset_controller()
