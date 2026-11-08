class_name AthleteAbilities
extends Node
## Sprint is available to selected athletes; only a live carrier can juke.

signal juke_started

@export var sprint_multiplier: float = 1.45
@export var juke_multiplier: float = 2.1
@export var juke_duration: float = 0.18
@export var juke_cooldown: float = 1.2

var cooldown_remaining: float = 0.0
var duration_remaining: float = 0.0
@onready var runner: FlagPlayer = get_parent() as FlagPlayer


func reset() -> void:
	cooldown_remaining = 0.0
	duration_remaining = 0.0
	runner.is_juking = false
	runner.speed_multiplier = 1.0
	runner.juke_direction = Vector2.ZERO
	runner.queue_redraw()


func try_juke(direction: Vector2) -> bool:
	if not runner.play_active or not runner.control_enabled or not runner.has_ball:
		return false
	if runner.movement_locked or cooldown_remaining > 0.0 or direction.is_zero_approx():
		return false
	cooldown_remaining = juke_cooldown
	duration_remaining = juke_duration
	runner.juke_direction = direction.normalized()
	runner.is_juking = true
	runner.speed_multiplier = juke_multiplier
	runner.queue_redraw()
	juke_started.emit()
	return true


func _physics_process(delta: float) -> void:
	cooldown_remaining = maxf(0.0, cooldown_remaining - delta)
	duration_remaining = maxf(0.0, duration_remaining - delta)
	if not runner.play_active or runner.movement_locked:
		duration_remaining = 0.0
	var was_juking: bool = runner.is_juking
	runner.is_juking = duration_remaining > 0.0
	if was_juking != runner.is_juking:
		runner.queue_redraw()
	if runner.control_enabled and Input.is_action_just_pressed("juke"):
		var direction: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if direction.is_zero_approx():
			direction = runner.velocity.normalized()
		try_juke(direction)
	var sprinting: bool = runner.control_enabled and runner.play_active and Input.is_action_pressed("sprint")
	runner.speed_multiplier = juke_multiplier if runner.is_juking else (sprint_multiplier if sprinting else 1.0)
