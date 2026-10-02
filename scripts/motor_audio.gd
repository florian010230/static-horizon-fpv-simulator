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
##     series - the "prop" sound. Tones at the blade-pass frequency and
##     its harmonics dominate a quadcopter's spectrum up to several kHz
##     ("An Examination of Quadcopter Drone Noise Using Computational
##     Aeroacoustics", NASA AMS 2021, nas.nasa.gov/assets/nas/pdf/ams/
##     2021/AMS_20211014_Kelecy.pdf; also acentech.com/resources/
##     drone-noise-a-new-challenge-in-acoustics).
##   - motor whine + PWM buzz: rotation rate x motor pole pairs
##     (brushless motors have 6-7 pole pairs) plus odd harmonics from the
##     ESC's switching. The ESC's actual PWM carrier (8-48 kHz; BLHeli_32
##     defaults to 24 kHz, blog.uavmodel.com/blheli_32-esc-configuration-
##     motor-timing-pwm-frequency-demag-compensation-and-temperature-
##     protection-2026-guide) is above this sim's 22050 Hz mix rate's
##     useful range, so what's modeled is the audible sideband it really
##     produces: a pole-pair-rate whine with square-wave-ish odd
##     harmonics riding on it, loudest on 1S whoops (lower PWM headroom,
##     per the same source) and faint on 6S fives.
##   - a low rotation-rate rumble and broadband prop wash, strongest on
##     big 5" props; wash is broadband turbulence that rises sharply with
##     throttle and spikes further on fast rpm changes - punch-outs and
##     chops push a lot of extra air very quickly.
##   Static Whoop: 1S, 0802 ~25,000 KV -> ~66,000 rpm loaded, 3-blade
##   41 mm props -> screams,
##     brighter/thinner timbre, little wash (halfchrome.com/cinewhoop-
##     toothpick-twig-five-inch-what-the-fpv-heck; tattuworld.com/
##     resources/what-is-a-tiny-whoop-drone).
##   3-inch:      4S, ~35,000 rpm, tri-blades -> sharp buzz.
##   5-inch:      6S, ~28,000 rpm, tri-blades -> deeper, more wash.
##
## Four slightly detuned, slowly rpm-wandering motors give the natural,
## evolving beating of a real quad (brushless cogging/load ripple, not a
## perfectly steady rpm). Rendering is still done ONCE per class at
## startup and cached - real-time per-sample synthesis in GDScript would
## cost real CPU on weak hardware - but two loops are rendered now
## instead of one: a longer tonal loop (blade-pass + whine/buzz +
## rumble) and a separate broadband wash/noise loop, mixed on their own
## AudioStreamPlayer children so wash volume can follow rpm and its
## derivative independently of the tone. A shared audio bus with a
## low-pass filter whose cutoff tracks rpm makes the sound duller at
## idle and brighter/more aggressive at high throttle, the way a loaded
## motor's harmonic content really shifts up - without having to render
## a third "bright" loop. (Single-player sim: the bus is shared by
## design, so two simultaneous drones would fight over one filter - not
## a concern here.)
## Silent while disarmed - props don't spin then.

const MIX_RATE: int = 22050
const LOOP_SECONDS: float = 1.0 ## long enough for sub-Hz rpm wander to sound slow, not mechanical
const REF_RPM_FRACTION: float = 0.5
const IDLE_RPM_FRACTION: float = 0.18 ## armed idle (Betaflight's idle keeps props turning)
## (2026-10-02, flight feedback: armed at 0% throttle the props still spin
## - airmode / dynamic idle - so idle is clearly audible now, db_min only
## ~8 dB under full; the wash layer was too loud on throttle-ups and is
## ~8 dB quieter with a smaller punch spike.)

const SOUNDS := {
	"whoop": {"max_rot_hz": 1100.0, "blades": 3, "pole_pairs": 6, "blade_amp": 0.32, "whine_amp": 0.55, "buzz_amp": 0.12, "rumble_amp": 0.05, "tilt": 0.85, "noise_lp": 0.55, "wander_depth": 0.006, "lp_idle_hz": 2600.0, "lp_full_hz": 9500.0, "db_min": -17.0, "db_max": -9.0, "wash_db_min": -50.0, "wash_db_max": -31.0},
	"seeker3": {"max_rot_hz": 580.0, "blades": 3, "pole_pairs": 7, "blade_amp": 0.5, "whine_amp": 0.28, "buzz_amp": 0.18, "rumble_amp": 0.12, "tilt": 1.0, "noise_lp": 0.3, "wander_depth": 0.004, "lp_idle_hz": 1800.0, "lp_full_hz": 8500.0, "db_min": -15.0, "db_max": -7.0, "wash_db_min": -46.0, "wash_db_max": -24.0},
	"race": {"max_rot_hz": 640.0, "blades": 3, "pole_pairs": 7, "blade_amp": 0.55, "whine_amp": 0.24, "buzz_amp": 0.14, "rumble_amp": 0.22, "tilt": 1.1, "noise_lp": 0.12, "wander_depth": 0.0025, "lp_idle_hz": 1300.0, "lp_full_hz": 7500.0, "db_min": -13.0, "db_max": -4.0, "wash_db_min": -42.0, "wash_db_max": -18.0},
	"five": {"max_rot_hz": 470.0, "blades": 3, "pole_pairs": 7, "blade_amp": 0.55, "whine_amp": 0.18, "buzz_amp": 0.10, "rumble_amp": 0.3, "tilt": 1.25, "noise_lp": 0.08, "wander_depth": 0.0025, "lp_idle_hz": 1100.0, "lp_full_hz": 6000.0, "db_min": -13.0, "db_max": -5.0, "wash_db_min": -42.0, "wash_db_max": -17.0},
}
const DETUNE: Array[float] = [1.0, 1.012, 0.992, 1.024]
## Per-motor rpm-wander LFO: whole cycles over the loop (keeps the loop
## click-free, see _build_loop) but different per motor so the beating
## between motors drifts instead of repeating in lock-step.
const WANDER_CYCLES: Array[int] = [1, 2, 3, 5]
const WANDER_PHASE: Array[float] = [0.0, 1.3, 2.6, 4.1]

const BUS_NAME := "MotorLPF"
static var _lpf: AudioEffectLowPassFilter = null
static var _cache: Dictionary = {}

var _profile: String = ""
var _pitch: float = 1.0
var _wash: AudioStreamPlayer = null
var _prev_rpm: float = IDLE_RPM_FRACTION
var _wash_env: float = 0.0

func set_profile(profile_name: String) -> void:
	if profile_name == _profile:
		return
	_profile = profile_name if SOUNDS.has(profile_name) else "seeker3"
	_ensure_bus()
	if _wash == null:
		_wash = get_node_or_null("Wash")
		if _wash == null:
			_wash = AudioStreamPlayer.new()
			_wash.name = "Wash"
			add_child(_wash)
	bus = BUS_NAME
	_wash.bus = BUS_NAME
	if not _cache.has(_profile):
		_cache[_profile] = _build_loop(SOUNDS[_profile])
	var loops: Dictionary = _cache[_profile]
	stream = loops.tone
	_wash.stream = loops.noise
	play()
	_wash.play()

func _process(delta: float) -> void:
	if _profile == "":
		return
	var drone := get_parent() as Drone
	if drone == null or not InputManager.armed:
		volume_db = -80.0
		if _wash:
			_wash.volume_db = -80.0
		return
	var rpm: float = maxf(drone.rpm_fraction, IDLE_RPM_FRACTION)
	var target_pitch: float = rpm / REF_RPM_FRACTION
	# Motors spool up/down quickly, but not instantly.
	_pitch = lerpf(_pitch, target_pitch, 1.0 - exp(-delta * 25.0))
	pitch_scale = clampf(_pitch, 0.2, 3.0)
	var s: Dictionary = SOUNDS[_profile]
	var k: float = clampf((rpm - IDLE_RPM_FRACTION) / (1.0 - IDLE_RPM_FRACTION), 0.0, 1.0)
	volume_db = lerpf(s.db_min, s.db_max, k)
	# Brightness follows rpm: a loaded motor's harmonic content really
	# shifts up under throttle, duller/softer at idle - see file header.
	if _lpf:
		_lpf.cutoff_hz = lerpf(s.lp_idle_hz, s.lp_full_hz, k)
	if _wash:
		_wash.pitch_scale = clampf(0.85 + 0.3 * _pitch, 0.5, 2.0)
		# Prop wash: broadband, rises with rpm, and spikes further on
		# fast rpm changes (punch-outs / throttle chops push a lot of
		# extra air very quickly, independent of the steady rpm level).
		var d_rpm: float = (rpm - _prev_rpm) / maxf(delta, 0.0001)
		_wash_env = lerpf(_wash_env, absf(d_rpm), 1.0 - exp(-delta * 6.0))
		var spike_db: float = clampf(_wash_env * 3.0, 0.0, 3.0)
		_wash.volume_db = lerpf(s.wash_db_min, s.wash_db_max, k) + spike_db
	_prev_rpm = rpm

static func _ensure_bus() -> void:
	if _lpf != null:
		return
	var idx: int = AudioServer.get_bus_index(BUS_NAME)
	if idx == -1:
		idx = AudioServer.bus_count
		AudioServer.add_bus(idx)
		AudioServer.set_bus_name(idx, BUS_NAME)
		AudioServer.set_bus_send(idx, "Master")
	if AudioServer.get_bus_effect_count(idx) > 0:
		_lpf = AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter
	if _lpf == null:
		_lpf = AudioEffectLowPassFilter.new()
		_lpf.cutoff_hz = 8000.0
		AudioServer.add_bus_effect(idx, _lpf)

static func _build_loop(s: Dictionary) -> Dictionary:
	var n: int = int(MIX_RATE * LOOP_SECONDS)
	var rot: float = s.max_rot_hz * REF_RPM_FRACTION
	var step: float = 1.0 / LOOP_SECONDS ## smallest frequency step that completes whole cycles in the loop
	# Hoist everything that doesn't vary per-sample out of the hot loop -
	# this render runs once per class at startup but still has to stay
	# cheap (see file header); pow() in particular is far costlier than a
	# plain divide, so the spectral-tilt coefficients are precomputed once
	# per class instead of once per sample.
	var blades: float = s.blades
	var pole_pairs: float = s.pole_pairs
	var blade_amp: float = s.blade_amp
	var whine_amp: float = s.whine_amp
	var buzz_amp: float = s.buzz_amp
	var rumble_amp: float = s.rumble_amp
	var wander_depth: float = s.wander_depth
	var blade_coeff: Array[float] = []
	for h in range(1, 6):
		blade_coeff.append(blade_amp / pow(float(h), s.tilt))
	var tone := PackedFloat32Array()
	tone.resize(n)
	for m in range(4):
		var base_r: float = roundf(rot * DETUNE[m] / step) * step
		var wander_w: float = TAU * WANDER_CYCLES[m] / LOOP_SECONDS
		var wander_ph: float = WANDER_PHASE[m]
		var phase: float = 0.0
		for i in range(n):
			var t: float = float(i) / MIX_RATE
			# Slow rpm wander (brushless cogging / load ripple), an
			# integer number of cycles over the loop so it integrates to
			# zero net phase shift and the loop point stays click-free
			# even though the instantaneous frequency isn't constant.
			var wobble: float = 1.0 + wander_depth * sin(wander_w * t + wander_ph)
			phase += TAU * base_r * wobble / MIX_RATE
			var blade_phase: float = phase * blades
			var whine_phase: float = phase * pole_pairs
			var v: float = 0.0
			# Blade-pass buzz: harmonics of a sawtooth, spectral tilt
			# per class (brighter classes keep more high-harmonic energy).
			v += blade_coeff[0] * sin(blade_phase) + blade_coeff[1] * sin(blade_phase * 2.0) + blade_coeff[2] * sin(blade_phase * 3.0) + blade_coeff[3] * sin(blade_phase * 4.0) + blade_coeff[4] * sin(blade_phase * 5.0)
			# Motor whine (pole-pair rate) plus the ESC/commutation buzz
			# as its 3rd-harmonic, odd-harmonic edge - see file header.
			v += whine_amp * (sin(whine_phase) + 0.3 * sin(whine_phase * 2.0)) + buzz_amp * sin(whine_phase * 3.0)
			v += rumble_amp * sin(phase)
			tone[i] += v * 0.25
	var noise := PackedFloat32Array()
	noise.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var noise_lp: float = 0.0
	for i in range(n):
		# Prop wash: low-passed noise, darker the bigger the props.
		noise_lp = lerpf(noise_lp, rng.randf_range(-1.0, 1.0), s.noise_lp)
		noise[i] = noise_lp
	return {"tone": _to_wav(tone), "noise": _to_wav(noise)}

static func _to_wav(buf: PackedFloat32Array) -> AudioStreamWAV:
	var n: int = buf.size()
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
