extends Camera2D
## Follow only the target's horizontal position, clamped to the field surrounds.

@export var target: Node2D


func _ready() -> void:
	limit_left = FootballField.CAMERA_BOUNDS.position.x
	limit_top = FootballField.CAMERA_BOUNDS.position.y
	limit_right = FootballField.CAMERA_BOUNDS.end.x
	limit_bottom = FootballField.CAMERA_BOUNDS.end.y
	_update_target_position()
	reset_smoothing()


func _process(_delta: float) -> void:
	_update_target_position()


func _update_target_position() -> void:
	if is_instance_valid(target):
		global_position = Vector2(roundf(target.global_position.x), 180.0)
