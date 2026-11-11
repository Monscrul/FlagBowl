class_name MatchRules
extends RefCounted
## Authoritative, deterministic rules model. No nodes, wall-clock time, or input.

signal changed
signal phase_changed(previous: Phase, current: Phase)

enum Phase { PRE_SNAP, LIVE_PLAY, DEAD_BALL, POSSESSION_CHANGE, GAME_OVER }
enum Result { FLAG_PULL, OUT_OF_BOUNDS, INCOMPLETE, INTERCEPTION, TOUCHDOWN, TIME_LIMIT }

const MAX_DOWNS: int = 4
const START_YARDS: float = 10.0
const TOUCHDOWN_POINTS: int = 6
const MAX_LIVE_SECONDS: int = 20

var phase: Phase = Phase.PRE_SNAP
var offense: int = 0
var scores: Array[int] = [0, 0]
var down: int = 1
var midfield_earned: bool = false
var line_of_scrimmage: float = FootballField.world_x_from_progress(START_YARDS, 1)
var ticks_remaining: int = 0
var ticks_per_second: int = 60
var last_result: String = ""
var pending_possession: bool = false
var _next_spot: float = 0.0
var live_ticks: int = 0


func start_game(duration_seconds: int = 300, tick_rate: int = 60) -> void:
	offense = 0
	scores = [0, 0]
	down = 1
	midfield_earned = false
	line_of_scrimmage = FootballField.world_x_from_progress(START_YARDS, 1)
	ticks_per_second = maxi(1, tick_rate)
	ticks_remaining = maxi(0, duration_seconds) * ticks_per_second
	last_result = ""
	pending_possession = false
	live_ticks = 0
	_set_phase(Phase.PRE_SNAP if ticks_remaining > 0 else Phase.GAME_OVER)
	changed.emit()


func attack_direction() -> int:
	return 1 if offense == 0 else -1


func target_x() -> float:
	return FootballField.world_x_from_progress(50.0, attack_direction()) if midfield_earned else FootballField.MIDFIELD


func yards_to_target() -> float:
	return maxf(0.0, (target_x() - line_of_scrimmage) * attack_direction() / FootballField.YARD_SIZE)


func seconds_remaining() -> int:
	return ceili(float(ticks_remaining) / ticks_per_second)


func snap() -> bool:
	if phase != Phase.PRE_SNAP or ticks_remaining <= 0:
		return false
	last_result = ""
	live_ticks = 0
	_set_phase(Phase.LIVE_PLAY)
	changed.emit()
	return true


func tick(carrier_spot: Vector2 = Vector2(INF, INF)) -> void:
	if phase != Phase.LIVE_PLAY:
		return
	ticks_remaining = maxi(0, ticks_remaining - 1)
	live_ticks += 1
	# Zero is a horn, not a mid-play cancellation: the live play may finish.
	# The live-play cap also runs after the horn so that a final play cannot stall.
	if live_ticks >= MAX_LIVE_SECONDS * ticks_per_second:
		if carrier_spot.is_finite():
			finish_play(Result.TIME_LIMIT, carrier_spot)
		else:
			finish_play(Result.INCOMPLETE, Vector2(line_of_scrimmage, FootballField.CENTER_Y))
		return
	changed.emit()


func is_touchdown(point: Vector2) -> bool:
	if phase != Phase.LIVE_PLAY:
		return false
	# Sideline takes priority at an exact end-zone corner.
	if FootballField.carrier_out_of_bounds(point):
		return false
	return FootballField.progress_yards(point.x, attack_direction()) >= FootballField.PLAYING_YARDS


func finish_play(result: Result, spot: Vector2) -> bool:
	if phase != Phase.LIVE_PLAY or not is_finite(spot.x) or not is_finite(spot.y):
		return false
	var direction: int = attack_direction()
	var progress: float = FootballField.progress_yards(spot.x, direction)
	if result in [Result.FLAG_PULL, Result.TIME_LIMIT] and is_touchdown(spot):
		result = Result.TOUCHDOWN
	# A requested score must actually reach the opponent goal in bounds.
	if result == Result.TOUCHDOWN and not is_touchdown(spot):
		return false
	pending_possession = false
	match result:
		Result.TOUCHDOWN:
			scores[offense] += TOUCHDOWN_POINTS
			last_result = "TOUCHDOWN +6"
			_queue_change(FootballField.world_x_from_progress(START_YARDS, -direction))
		Result.INTERCEPTION:
			last_result = "INTERCEPTION / TURNOVER"
			var new_progress: float = FootballField.progress_yards(spot.x, -direction)
			var turnover_spot: float = clampf(spot.x, FootballField.GOAL_LEFT + 1, FootballField.GOAL_RIGHT - 1)
			if new_progress <= 0.0:
				turnover_spot = FootballField.world_x_from_progress(START_YARDS, -direction)
			_queue_change(turnover_spot)
		_:
			last_result = "PLAY LIMIT / DEAD BALL" if result == Result.TIME_LIMIT else ["FLAG PULLED", "OUT OF BOUNDS", "INCOMPLETE / DROP"][result]
			if result != Result.INCOMPLETE:
				line_of_scrimmage = clampf(spot.x, FootballField.GOAL_LEFT + 1, FootballField.GOAL_RIGHT - 1)
			if result != Result.INCOMPLETE and progress <= 0.0:
				# Custom own-end-zone turnover; no safety points in this prototype.
				last_result = "OWN END ZONE / TURNOVER"
				_queue_change(FootballField.world_x_from_progress(START_YARDS, -direction))
			elif result != Result.INCOMPLETE and not midfield_earned and progress >= 25.0:
				midfield_earned = true
				down = 1
				last_result += " / FIRST DOWN"
			elif down >= MAX_DOWNS:
				last_result = "TURNOVER ON DOWNS"
				_queue_change(line_of_scrimmage)
			else:
				down += 1
	_set_phase(Phase.GAME_OVER if ticks_remaining == 0 else Phase.DEAD_BALL)
	if phase == Phase.GAME_OVER:
		pending_possession = false
	changed.emit()
	return true


func advance() -> bool:
	if phase == Phase.DEAD_BALL:
		if pending_possession:
			offense = 1 - offense
			line_of_scrimmage = _next_spot
			down = 1
			midfield_earned = FootballField.progress_yards(line_of_scrimmage, attack_direction()) >= 25.0
			pending_possession = false
			_set_phase(Phase.POSSESSION_CHANGE)
		else:
			_set_phase(Phase.PRE_SNAP)
	elif phase == Phase.POSSESSION_CHANGE:
		_set_phase(Phase.PRE_SNAP)
	else:
		return false
	changed.emit()
	return true


func _queue_change(spot: float) -> void:
	pending_possession = true
	_next_spot = spot


func _set_phase(next: Phase) -> void:
	if phase == next:
		return
	var previous: Phase = phase
	phase = next
	phase_changed.emit(previous, phase)
