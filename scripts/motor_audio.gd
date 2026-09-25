extends AudioStreamPlayer

## Procedurally synthesized motor whine (no audio asset needed): two
## slightly detuned sawtooth oscillators plus a touch of noise, with
## pitch and volume driven by throttle. Silent-ish when disarmed.

@export var min_freq: float = 150.0
@export var max_freq: float = 520.0
@export var min_volume_db: float = -40.0
@export var max_volume_db: float = -8.0

const MIX_RATE: float = 22050.0

var _playback: AudioStreamGeneratorPlayback
var _phase_a: float = 0.0
var _phase_b: float = 0.0

func _ready() -> void:
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = MIX_RATE
	gen.buffer_length = 0.1
	stream = gen
	play()
	_playback = get_stream_playback()

func _exit_tree() -> void:
	_playback = null

func _process(_delta: float) -> void:
	if _playback == null:
		return

	var level: float = InputManager.get_throttle() if InputManager.armed else 0.0
	var freq_a: float = lerp(min_freq, max_freq, level)
	var freq_b: float = freq_a * 1.5 + 6.0
	volume_db = lerp(min_volume_db, max_volume_db, level)

	var frames: int = _playback.get_frames_available()
	for i in range(frames):
		_phase_a = fmod(_phase_a + freq_a / MIX_RATE, 1.0)
		_phase_b = fmod(_phase_b + freq_b / MIX_RATE, 1.0)
		var sample: float = (_saw(_phase_a) + _saw(_phase_b)) * 0.5
		sample += randf_range(-0.05, 0.05)
		sample = clamp(sample, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))

func _saw(phase: float) -> float:
	return 2.0 * phase - 1.0
