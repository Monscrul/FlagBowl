class_name DefenderAI
extends Node
## Separate state handlers keep coverage, ball reactions, and pursuit independent.

signal flag_pull_requested(defender: FlagPlayer, carrier: FlagPlayer)

enum State { IDLE, MAN_COVERAGE, PURSUIT, INTERCEPT }

@export var coverage_offset: Vector2 = Vector2(30, 0)
@export var reaction_range: float = 145.0
@export var flag_pull_range: float = 18.0
@export var rush_delay: float = 0.0

var state: State = State.IDLE
var assignment: FlagPlayer
var director: Node2D
var elapsed: float = 0.0
@onready var runner: FlagPlayer = get_parent() as FlagPlayer


func reset() -> void:
	elapsed = 0.0
	state = State.IDLE
	runner.ai_direction = Vector2.ZERO


func _physics_process(delta: float) -> void:
	if director == null or not director.defense_enabled or not runner.play_active:
		state = State.IDLE
		runner.ai_direction = Vector2.ZERO
		return
	elapsed += delta
	var ball: Football = director.ball
	if ball.in_flight and runner.global_position.distance_to(ball.global_position) <= reaction_range:
		state = State.INTERCEPT
	elif ball.holder != null and (ball.holder != director.quarterback or assignment == director.quarterback):
		state = State.PURSUIT
	else:
		state = State.MAN_COVERAGE
	if not runner.control_enabled:
		match state:
			State.MAN_COVERAGE:
				_cover()
			State.PURSUIT:
				_pursue(ball.holder)
			State.INTERCEPT:
				_intercept(ball)
	# Selected defenders still attempt pulls automatically when close enough.
	var carrier: FlagPlayer = ball.holder
	if carrier != null and not director.defenders.has(carrier) and not carrier.is_juking:
		if runner.global_position.distance_to(carrier.global_position) <= flag_pull_range:
			flag_pull_requested.emit(runner, carrier)


func _steer(point: Vector2, stopping_distance: float = 4.0) -> void:
	var displacement: Vector2 = point - runner.global_position
	runner.ai_direction = displacement.normalized() * clampf((displacement.length() - stopping_distance) / 18.0, 0.0, 1.0)


func _cover() -> void:
	if is_instance_valid(assignment):
		_steer(assignment.global_position + coverage_offset)


func _pursue(carrier: FlagPlayer) -> void:
	if carrier == director.quarterback and elapsed < rush_delay:
		runner.ai_direction = Vector2.ZERO
		return
	_steer(carrier.global_position + carrier.velocity * 0.12, 0.0)


func _intercept(ball: Football) -> void:
	var point: Vector2 = ball.global_position.move_toward(ball.target_position, ball.flight_speed * 0.12)
	_steer(point, 0.0)
