extends AudioStreamPlayer

## Procedurally synthesized motor whine (no audio asset needed): 4
## slightly detuned sawtooth oscillators (one per motor, since real
## motors never spin in perfect sync - that mismatch is what gives a
## quad its characteristic buzz) plus a slow tremolo (prop-blade flutter)
## and a touch of noise. Pitch and volume follow throttle.

@export var min_freq: float = 180.0
@export var max_freq: float = 780.0
@export var min_volume_db: float = -42.0
@export var max_volume_db: float = -10.0

const MIX_RATE: float = 22050.0
const DETUNE: Array[float] = [1.0, 1.013, 0.991, 1.026]
const TREMOLO_HZ: float = 11.0

var _playback: AudioStreamGeneratorPlayback
var _phases: Array[float] = [0.0, 0.0, 0.0, 0.0]
var _tremolo_phase: float = 0.0

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
	var base_freq: float = lerp(min_freq, max_freq, level)
	volume_db = lerp(min_volume_db, max_volume_db, level)

	var frames: int = _playback.get_frames_available()
	for i in range(frames):
		var mix: float = 0.0
		for m in range(4):
			_phases[m] = fmod(_phases[m] + base_freq * DETUNE[m] / MIX_RATE, 1.0)
			mix += _saw(_phases[m])
		mix *= 0.25

		_tremolo_phase = fmod(_tremolo_phase + TREMOLO_HZ / MIX_RATE, 1.0)
		var tremolo: float = 1.0 - 0.06 * (0.5 + 0.5 * sin(_tremolo_phase * TAU))
		mix *= tremolo

		mix += randf_range(-0.025, 0.025)
		mix = clamp(mix, -1.0, 1.0)
		_playback.push_frame(Vector2(mix, mix))

func _saw(phase: float) -> float:
	return 2.0 * phase - 1.0
