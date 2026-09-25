extends AudioStreamPlayer

## Procedurally synthesized motor whine, no audio asset needed: 4 detuned
## sawtooth oscillators (one per motor - real motors never spin in
## perfect sync, that mismatch is what gives a quad its buzz), a slow
## tremolo for prop-flutter character, and a touch of noise.
##
## This is pre-rendered ONCE into a short looping buffer at startup
## rather than synthesized sample-by-sample every frame: continuous
## real-time synthesis in GDScript (an interpreted language) at audio
## sample rate is a real, measurable CPU cost, which directly fights the
## weak-hardware target. Pitch/volume then follow throttle live via
## pitch_scale/volume_db, both cheap native properties.

@export var min_freq: float = 180.0
@export var max_freq: float = 780.0
@export var min_volume_db: float = -42.0
@export var max_volume_db: float = -10.0

const MIX_RATE: int = 22050
const LOOP_SECONDS: float = 1.5
const DETUNE: Array[float] = [1.0, 1.013, 0.991, 1.026]
const TREMOLO_HZ: float = 11.0

func _ready() -> void:
	stream = _build_loop()
	play()

func _process(_delta: float) -> void:
	var level: float = InputManager.get_throttle() if InputManager.armed else 0.0
	var base_freq: float = lerp(min_freq, max_freq, level)
	pitch_scale = base_freq / min_freq
	volume_db = lerp(min_volume_db, max_volume_db, level)

func _build_loop() -> AudioStreamWAV:
	var num_samples: int = int(MIX_RATE * LOOP_SECONDS)
	var bytes := PackedByteArray()
	bytes.resize(num_samples * 2)

	var phases: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var tremolo_phase: float = 0.0
	var rng := RandomNumberGenerator.new()
	rng.seed = 7

	for i in range(num_samples):
		var mix: float = 0.0
		for m in range(4):
			phases[m] = fmod(phases[m] + min_freq * DETUNE[m] / MIX_RATE, 1.0)
			mix += 2.0 * phases[m] - 1.0
		mix *= 0.25

		tremolo_phase = fmod(tremolo_phase + TREMOLO_HZ / MIX_RATE, 1.0)
		var tremolo: float = 1.0 - 0.06 * (0.5 + 0.5 * sin(tremolo_phase * TAU))
		mix *= tremolo

		mix += rng.randf_range(-0.025, 0.025)
		mix = clamp(mix, -1.0, 1.0)
		bytes.encode_s16(i * 2, int(mix * 32767.0))

	var wav := AudioStreamWAV.new()
	wav.data = bytes
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.stereo = false
	wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wav.loop_begin = 0
	wav.loop_end = num_samples
	return wav
