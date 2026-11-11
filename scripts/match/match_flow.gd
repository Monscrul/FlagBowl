extends Node
## Fixed-tick between-play pacing. Human pre-snap selection has no time limit.

@export var dead_ball_seconds: float = 1.2
@export var possession_seconds: float = 1.0
@export var opponent_snap_seconds: float = 1.5

var elapsed_ticks: int = 0
var _phase: int = -1
@onready var director: Node2D = get_parent()


func reset() -> void:
	elapsed_ticks = 0
	_phase = -1


func _physics_process(_delta: float) -> void:
	if not director.auto_flow_enabled:
		return
	var phase: MatchRules.Phase = director.rules.phase
	if phase != _phase:
		_phase = phase
		elapsed_ticks = 0
	elapsed_ticks += 1
	var rate: int = Engine.physics_ticks_per_second
	if phase == MatchRules.Phase.DEAD_BALL and elapsed_ticks >= ceili(dead_ball_seconds * rate):
		director.advance_play()
	elif phase == MatchRules.Phase.POSSESSION_CHANGE and elapsed_ticks >= ceili(possession_seconds * rate):
		director.advance_play()
	elif phase == MatchRules.Phase.PRE_SNAP and director.is_ai_offense() and elapsed_ticks >= ceili(opponent_snap_seconds * rate):
		director.snap_play()
