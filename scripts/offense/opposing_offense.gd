class_name OpposingOffense
extends Node
## Deterministic reads: lead open receivers, avoid occupied lanes, otherwise run.

signal decision_made(decision: String)

@export var maximum_read_seconds: float = 1.4
@export var minimum_separation: float = 28.0
@export var minimum_lane_clearance: float = 17.0

var elapsed_ticks: int = 0
var last_decision: String = ""
@onready var director: Node2D = get_parent()


func reset() -> void:
	elapsed_ticks = 0
	last_decision = ""


func _physics_process(_delta: float) -> void:
	if not director.is_ai_offense() or director.rules.phase != MatchRules.Phase.LIVE_PLAY:
		return
	elapsed_ticks += 1
	var holder: FlagPlayer = director.ball.holder
	if holder == null:
		director.quarterback.ai_direction = Vector2.ZERO
		return
	if holder != director.quarterback:
		_run_carrier(holder)
		return
	var elapsed: float = float(elapsed_ticks) / Engine.physics_ticks_per_second
	if elapsed < director.selected_play().ai_read_delay:
		# Small dropback buys time without retreating indefinitely.
		holder.ai_direction = Vector2(-director.rules.attack_direction() * 0.25, 0)
		return
	var target: FlagPlayer = best_receiver()
	if target != null and director.request_ai_throw(lead_target(target)):
		_decide("PASS " + target.role_name)
		holder.ai_direction = Vector2.ZERO
	elif elapsed >= maximum_read_seconds:
		_decide("SCRAMBLE")
		_run_carrier(holder)
	else:
		holder.ai_direction = Vector2.ZERO


func best_receiver() -> FlagPlayer:
	var best: FlagPlayer = null
	var best_score: float = -INF
	var qb: FlagPlayer = director.quarterback
	for receiver: FlagPlayer in director.receivers:
		var aim: Vector2 = lead_target(receiver)
		var distance: float = qb.global_position.distance_to(aim)
		if distance > director.ball.max_range or distance < 12.0:
			continue
		var separation: float = INF
		var lane_clearance: float = INF
		if director.defense_enabled:
			for defender: FlagPlayer in director.defenders:
				separation = minf(separation, defender.global_position.distance_to(aim))
				var closest: Vector2 = Geometry2D.get_closest_point_to_segment(defender.global_position, qb.global_position, aim)
				lane_clearance = minf(lane_clearance, closest.distance_to(defender.global_position))
		if separation < minimum_separation or lane_clearance < minimum_lane_clearance:
			continue
		var progress: float = (aim.x - qb.global_position.x) * director.rules.attack_direction()
		var score: float = minf(separation, 180.0) + minf(lane_clearance, 80.0) + progress * 0.15 - distance * 0.05
		if score > best_score:
			best_score = score
			best = receiver
	return best


func lead_target(receiver: FlagPlayer) -> Vector2:
	var qb: FlagPlayer = director.quarterback
	var aim: Vector2 = receiver.global_position
	# Iterate the flight time because leading changes the throw distance.
	for iteration: int in range(4):
		var flight_time: float = qb.global_position.distance_to(aim) / director.ball.flight_speed
		aim = receiver.global_position + receiver.velocity * flight_time
	return FootballField.clamp_athlete(aim)


func _run_carrier(carrier: FlagPlayer) -> void:
	var direction: int = director.rules.attack_direction()
	var best_y: float = carrier.global_position.y
	var best_score: float = -INF
	for lane_y: float in [75.0, 125.0, 180.0, 235.0, 285.0]:
		var point: Vector2 = Vector2(carrier.global_position.x + direction * 85, lane_y)
		var clearance: float = 200.0
		if director.defense_enabled:
			for defender: FlagPlayer in director.defenders:
				clearance = minf(clearance, point.distance_to(defender.global_position))
		var score: float = clearance - absf(lane_y - carrier.global_position.y) * 0.4
		if score > best_score:
			best_score = score
			best_y = lane_y
	carrier.ai_direction = Vector2(direction, clampf((best_y - carrier.global_position.y) / 65.0, -0.8, 0.8)).normalized()


func _decide(decision: String) -> void:
	if last_decision != decision:
		last_decision = decision
		decision_made.emit(decision)
