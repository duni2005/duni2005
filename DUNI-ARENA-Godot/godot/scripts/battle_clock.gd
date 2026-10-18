class_name BattleClock
extends RefCounted
## UI real time and simulation time are separate. No Engine.time_scale writes.
enum State { NORMAL, TURNING_SLOWDOWN, TURNING_PAUSED, TRANSCENDENCE_AIM, TRANSCENDENCE_CAST, STOPPED }
var state: State = State.NORMAL
var elapsed: float = 0.0
var simulation_delta: float = 0.0
var real_elapsed: float = 0.0
var slowdown_elapsed: float = 0.0
var slowdown_duration: float = 2.0
var speed: float = 1.0
var stopped: bool:
	get: return state == State.STOPPED

func set_speed(value: float) -> bool:
	if state != State.NORMAL or value not in [1.0, 2.0, 4.0]:
		return false
	speed = value
	return true

func begin_slowdown(duration: float = 2.0) -> bool:
	if state != State.NORMAL or not is_finite(duration) or duration <= 0:
		return false
	slowdown_duration = duration
	state = State.TURNING_SLOWDOWN
	slowdown_elapsed = 0.0
	return true

func progress_slowdown(real_delta: float, duration: float) -> float:
	if state != State.TURNING_SLOWDOWN or not is_finite(real_delta) or real_delta <= 0:
		return 0.0
	slowdown_elapsed += real_delta
	if slowdown_elapsed >= duration:
		state = State.TURNING_PAUSED
		return slowdown_elapsed - duration
	return 0.0

func turning_scale() -> float:
	if state == State.TURNING_SLOWDOWN:
		return maxf(0.035, 1.0 - slowdown_elapsed / slowdown_duration)
	return 0.0 if state in [State.TURNING_PAUSED, State.TRANSCENDENCE_AIM, State.TRANSCENDENCE_CAST, State.STOPPED] else 1.0

func is_turning_paused() -> bool:
	return state == State.TURNING_PAUSED

func resume() -> bool:
	if state != State.TURNING_PAUSED:
		return false
	state = State.NORMAL
	simulation_delta = 0.0
	return true

func advance(real_delta: float, simulation_real_delta: float = -1.0) -> float:
	if stopped or not is_finite(real_delta) or real_delta <= 0.0:
		simulation_delta = 0.0
		return 0.0
	real_elapsed += real_delta
	simulation_delta = (simulation_real_delta if simulation_real_delta >= 0 else real_delta) * speed * turning_scale()
	elapsed += simulation_delta
	return simulation_delta

func stop() -> void:
	state = State.STOPPED
	simulation_delta = 0.0
