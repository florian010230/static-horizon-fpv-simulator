extends AudioStreamPlayer

## Procedurally synthesized motor sound, no audio asset needed, with its
## own character per drone class and a pitch that follows the motors'
## actual speed from the flight model (Drone.rpm_fraction - rpm grows
## with the square root of thrust), not just the throttle stick: flips,
## punch-outs and throttle chops are audible.
##
## Each class is synthesized from what really makes its sound (numbers
## are typical for the class, not one product):
##   - blade-pass tone: rotation rate x blade count, a buzzy harmonic
##     series - the "prop" sound;
##   - motor whine: rotation rate x motor pole pairs (brushless motors
##     have 6-7) - the high electric scream, loudest on whoops;
##   - a low rotation-rate rumble and broadband prop wash, strongest on
##     big 5" props.
##   Tiny Whoop: 1S, ~40,000 rpm loaded, 4-blade 40 mm props -> screams.
##   3-inch:      4S, ~35,000 rpm, tri-blades -> sharp buzz.
##   5-inch:      6S, ~28,000 rpm, tri-blades -> deeper, more wash.
##
## One loop is rendered ONCE per class at half rotation speed and cached
## (real-time synthesis in GDScript at audio rate would cost real CPU on
## weak hardware); pitch_scale then follows the live rpm, and four
## slightly detuned motors give the natural beating of a real quad.
## Silent while disarmed - props don't spin then.

const MIX_RATE: int = 22050
const LOOP_SECONDS: float = 0.5 ## integer Hz * 0.5 s isn't always whole cycles -> frequencies rounded to 2 Hz steps
const REF_RPM_FRACTION: float = 0.5
const IDLE_RPM_FRACTION: float = 0.18 ## armed idle (Betaflight's idle keeps props turning)

const SOUNDS := {
	"whoop": {"max_rot_hz": 660.0, "blades": 4, "pole_pairs": 6, "blade_amp": 0.32, "whine_amp": 0.55, "rumble_amp": 0.05, "noise_amp": 0.10, "noise_lp": 0.55, "db_min": -30.0, "db_max": -9.0},
	"seeker3": {"max_rot_hz": 580.0, "blades": 3, "pole_pairs": 7, "blade_amp": 0.5, "whine_amp": 0.28, "rumble_amp": 0.12, "noise_amp": 0.18, "noise_lp": 0.3, "db_min": -28.0, "db_max": -7.0},
	"five": {"max_rot_hz": 470.0, "blades": 3, "pole_pairs": 7, "blade_amp": 0.55, "whine_amp": 0.18, "rumble_amp": 0.3, "noise_amp": 0.35, "noise_lp": 0.08, "db_min": -26.0, "db_max": -5.0},
}
const DETUNE: Array[float] = [1.0, 1.012, 0.992, 1.024]

static var _cache: Dictionary = {}

var _profile: String = ""
var _pitch: float = 1.0

func set_profile(profile_name: String) -> void:
	if profile_name == _profile:
		return
	_profile = profile_name if SOUNDS.has(profile_name) else "seeker3"
	if not _cache.has(_profile):
		_cache[_profile] = _build_loop(SOUNDS[_profile])
	stream = _cache[_profile]
	play()

func _process(delta: float) -> void:
	if _profile == "":
		return
	var drone := get_parent() as Drone
	if drone == null or not InputManager.armed:
		volume_db = -80.0
		return
	var rpm: float = maxf(drone.rpm_fraction, IDLE_RPM_FRACTION)
	var target_pitch: float = rpm / REF_RPM_FRACTION
	# Motors spool up/down quickly, but not instantly.
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-delta * 25.0))
	pitch_scale = clampf(_pitch, 0.2, 3.0)
	var s: Dictionary = SOUNDS[_profile]
	volume_db = lerpf(s.db_min, s.db_max, clampf((rpm - IDLE_RPM_FRACTION) / (1.0 - IDLE_RPM_FRACTION), 0.0, 1.0))

static func _build_loop(s: Dictionary) -> AudioStreamWAV:
	var n: int = int(MIX_RATE * LOOP_SECONDS)
	var rot: float = s.max_rot_hz * REF_RPM_FRACTION
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var buf := PackedFloat32Array()
	buf.resize(n)
	var noise_lp: float = 0.0
	for m in range(4):
		# Whole cycles per loop (loop is 0.5 s -> multiples of 2 Hz), so
		# the loop point never clicks.
		var r: float = roundf(rot * DETUNE[m] / 2.0) * 2.0
		var blade: float = r * s.blades
		var whine: float = r * s.pole_pairs
		for i in range(n):
			var t: float = float(i) / MIX_RATE
			var v: float = 0.0
			# Blade-pass buzz: first harmonics of a sawtooth.
			for h in range(1, 6):
				v += s.blade_amp * sin(TAU * blade * h * t) / h
			v += s.whine_amp * (sin(TAU * whine * t) + 0.3 * sin(TAU * whine * 2.0 * t))
			v += s.rumble_amp * sin(TAU * r * t)
			buf[i] += v * 0.25
	for i in range(n):
		# Prop wash: low-passed noise, darker the bigger the props.
		noise_lp = lerpf(noise_lp, rng.randf_range(-1.0, 1.0), s.noise_lp)
		buf[i] += noise_lp * s.noise_amp
	var peak: float = 0.001
	for i in range(n):
		peak = maxf(peak, absf(buf[i]))
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in range(n):
		bytes.encode_s16(i * 2, int(clampf(buf[i] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.data = bytes
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = n
	return wav
