extends Node
## Owns the fixed-rate sim clock. Each tick it will call SimStep.step(state, intent)
## and forward the events through Events (wired up in Sprint 1).

const TICK_RATE_HZ: int = 10
const ASSIST_TICK_RATE_HZ: int = 6

var running: bool = false
var tick: int = 0
## Fraction of the next tick already elapsed, for view interpolation (0..1).
var alpha: float = 0.0

var _accumulator: float = 0.0


func tick_rate() -> int:
	return ASSIST_TICK_RATE_HZ if Settings.assist_mode else TICK_RATE_HZ


func start() -> void:
	tick = 0
	_accumulator = 0.0
	running = true


func stop() -> void:
	running = false


func _process(delta: float) -> void:
	if not running:
		return
	var step_time: float = 1.0 / tick_rate()
	_accumulator += delta
	# Cap catch-up so a long hitch doesn't run dozens of ticks in one frame.
	_accumulator = minf(_accumulator, step_time * 5.0)
	while _accumulator >= step_time:
		_accumulator -= step_time
		_advance()
	alpha = _accumulator / step_time


func _advance() -> void:
	tick += 1
	Events.sim_ticked.emit(tick)
